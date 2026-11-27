-- =============================================================================
-- Event Setup v3: editing a submitted event + in-app notifications.
--
-- * The person who submitted an event (or an owner) can edit it at any time.
--   Edits do NOT reset the department sign-offs.
-- * An edit to an approved event updates its calendar entry and its
--   announcement (title, text, and the scheduled post time if it hasn't
--   gone out yet).
-- * Every edit notifies Cleaning and Security approvers for that ministry plus
--   every owner, through event_setup_notifications (shown in the Events tab).
--   A Hasura event trigger on that table can also send a push; see
--   notifications_webhook.md.
--
-- Apply AFTER 002. Easiest: run backend/event_setup/apply_hasura.py, which runs
-- this file and sets up tracking, relationships and permissions. Manually:
-- Hasura console → Data → SQL, leave "Track this" UNCHECKED.
-- Safe to run more than once.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Notifications table
-- -----------------------------------------------------------------------------

create table if not exists public.event_setup_notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     text not null references public.profiles(id) on delete cascade,
  request_id  uuid null references public.event_setup_requests(id) on delete cascade,
  kind        text not null default 'edited' check (kind in ('edited')),
  title       text not null,
  -- Names of the fields that changed, e.g. ["event_date", "room"].
  changes     jsonb not null default '[]'::jsonb,
  actor_id    text null references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now(),
  read_at     timestamptz null
);

create index if not exists event_setup_notifications_user_idx
  on public.event_setup_notifications (user_id, read_at, created_at desc);

-- -----------------------------------------------------------------------------
-- 2. Edit guard (BEFORE UPDATE)
--    Hasura column permissions already limit which columns a client can set;
--    this re-checks who may edit and pins the columns that must not move.
-- -----------------------------------------------------------------------------

create or replace function public.event_setup_edited_fields(o public.event_setup_requests, n public.event_setup_requests)
returns jsonb
language sql immutable
as $$
  select coalesce(jsonb_agg(f), '[]'::jsonb) from (
    select 'title' as f where o.title is distinct from n.title
    union all select 'description' where o.description is distinct from n.description
    union all select 'room' where o.room is distinct from n.room
    union all select 'event_date' where o.event_date is distinct from n.event_date
    union all select 'event_end' where o.event_end is distinct from n.event_end
    union all select 'estimated_attendance' where o.estimated_attendance is distinct from n.estimated_attendance
    union all select 'notes' where o.notes is distinct from n.notes
    union all select 'target_audiences' where o.target_audiences is distinct from n.target_audiences
  ) x
$$;

create or replace function public.event_setup_validate_edit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  acting_user text := event_setup_session_var('x-hasura-user-id');
  acting_role text := event_setup_session_var('x-hasura-role');
begin
  -- Status updates from the publish trigger don't touch editable fields.
  if event_setup_edited_fields(old, new) = '[]'::jsonb then
    return new;
  end if;

  if acting_user is null and (acting_role is null or acting_role = 'admin') then
    return new;
  end if;

  if acting_user is null then
    raise exception 'event_setup: missing user session' using errcode = '42501';
  end if;

  if acting_user <> old.created_by and not event_setup_is_owner(acting_user) then
    raise exception 'event_setup: only the person who submitted this event can edit it'
      using errcode = '42501';
  end if;

  -- Never changed by an edit.
  new.created_by        := old.created_by;
  new.group_id          := old.group_id;
  new.status            := old.status;
  new.approved_at       := old.approved_at;
  new.calendar_event_id := old.calendar_event_id;
  new.add_to_calendar   := old.add_to_calendar;
  new.announce_lead     := old.announce_lead;
  return new;
end;
$$;

drop trigger if exists event_setup_validate_edit on public.event_setup_requests;
create trigger event_setup_validate_edit
  before update on public.event_setup_requests
  for each row execute function public.event_setup_validate_edit();

-- -----------------------------------------------------------------------------
-- 3. After an edit: sync the calendar entry + announcement, notify staff
-- -----------------------------------------------------------------------------

create or replace function public.event_setup_after_edit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  changed     jsonb := event_setup_edited_fields(old, new);
  acting_user text  := event_setup_session_var('x-hasura-user-id');
  ann         event_setup_announcements;
  new_publish timestamptz;
begin
  if changed = '[]'::jsonb then
    return null;
  end if;

  -- Calendar entry (approved events only).
  if new.calendar_event_id is not null then
    update events
       set title            = new.title,
           description      = new.description,
           event_date       = new.event_date,
           event_end        = new.event_end,
           target_audiences = new.target_audiences,
           location         = case new.room
                                when 'main_sanctuary'  then 'Main Sanctuary'
                                when 'fellowship_hall' then 'Fellowship Hall'
                                when 'youth_room'      then 'Youth Room'
                                when 'classroom'       then 'Classroom'
                                else location
                              end
     where id = new.calendar_event_id;
  end if;

  -- Announcement made from this event (exists once it's approved).
  select * into ann from event_setup_announcements where request_id = new.id;
  if ann.id is not null then
    -- Only move the post time if it hasn't gone out yet.
    new_publish := case
      when ann.publish_at > now() and new.announce_lead is not null
        then greatest(now(), new.event_date - event_setup_lead_interval(new.announce_lead))
      else ann.publish_at
    end;

    update event_setup_announcements
       set title = new.title, body = new.description,
           target_audiences = new.target_audiences, publish_at = new_publish
     where id = ann.id;

    if ann.group_announcement_id is not null then
      update group_announcements
         set title = new.title, body = new.description, published_at = new_publish
       where id = ann.group_announcement_id;
    end if;
    if ann.app_announcement_id is not null then
      update app_announcements
         set title = new.title, body = new.description, published_at = new_publish,
             target_audiences = new.target_audiences
       where id = ann.app_announcement_id;
    end if;
  end if;

  -- Notify Cleaning + Security for this ministry, and every owner.
  insert into event_setup_notifications (user_id, request_id, kind, title, changes, actor_id)
  select distinct r.uid, new.id, 'edited', new.title, changed, acting_user
  from (
    select ap.user_id as uid
      from event_setup_approval_permissions ap
     where ap.department in ('cleaning', 'security')
       and (ap.group_id is null or ap.group_id = new.group_id)
    union
    select p.id from profiles p where p.role = 'owner'
  ) r
  where r.uid is distinct from acting_user;

  return null;
end;
$$;

drop trigger if exists event_setup_after_edit on public.event_setup_requests;
create trigger event_setup_after_edit
  after update on public.event_setup_requests
  for each row execute function public.event_setup_after_edit();
