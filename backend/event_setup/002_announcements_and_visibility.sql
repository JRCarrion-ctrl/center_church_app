-- =============================================================================
-- Event Setup v2: announcements hub, announce timing, optional calendar entry,
-- ministry-scoped visibility and ministry-leader creators.
--
-- Apply AFTER 001_event_setup.sql (Hasura console: Data -> SQL, leave "Track
-- this" UNCHECKED), track the new table under Data -> public, then update
-- permissions per hasura_permissions.md.
--
-- Who sees what (enforced by Hasura row filters, see hasura_permissions.md):
--   * Staff = owner, supervisor, or anyone holding an approval permission
--     (administrator / security / cleaning). Staff see every request and
--     announcement in the Event Setup tab, for every ministry.
--   * Ministry leaders (group_memberships.role admin/leader/supervisor/owner)
--     see and create only for the ministries they lead.
--   * Regular members never see Event Setup. They see the published result in
--     the normal places, scoped to the ministry:
--       - announcement -> group_announcements (members of that ministry) or
--         app_announcements (church-wide, when no ministry is chosen)
--       - calendar     -> events with visibility 'group_only' for a ministry,
--         or 'public_app' when church-wide.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. New request options
-- -----------------------------------------------------------------------------

alter table public.event_setup_requests
  -- Public description: used for the calendar entry and the announcement body.
  -- `notes` stays internal (setup/equipment) and is never published.
  add column if not exists description     text null,
  add column if not exists add_to_calendar boolean not null default true,
  -- NULL = don't announce. Otherwise how long before the event to post it.
  add column if not exists announce_lead   text null
    check (announce_lead is null or announce_lead in ('asap', '1_day', '3_days', '1_week', '2_weeks'));

-- -----------------------------------------------------------------------------
-- 2. Announcements hub
--    One row per announcement made from Event Setup (standalone, or generated
--    from an approved event). An AFTER INSERT trigger copies it into the table
--    members already read, with published_at = publish_at, so scheduling works
--    with the existing "published_at <= now" filters on Home and in Groups.
-- -----------------------------------------------------------------------------

create table if not exists public.event_setup_announcements (
  id                     uuid primary key default gen_random_uuid(),
  -- Set only by the publish trigger for event announcements; not client-insertable.
  request_id             uuid null references public.event_setup_requests(id) on delete cascade,
  -- NULL = church-wide.
  group_id               uuid null references public.groups(id) on delete cascade,
  title                  text not null check (length(trim(title)) > 0),
  body                   text null,
  target_audiences       text[] not null default array['english', 'spanish'],
  publish_at             timestamptz not null default now(),
  created_by             text not null references public.profiles(id) on delete cascade,
  created_at             timestamptz not null default now(),
  group_announcement_id  uuid null references public.group_announcements(id) on delete set null,
  app_announcement_id    uuid null references public.app_announcements(id) on delete set null
);

create index if not exists event_setup_announcements_publish_idx
  on public.event_setup_announcements (publish_at desc);

create unique index if not exists event_setup_announcements_one_per_request
  on public.event_setup_announcements (request_id) where request_id is not null;

-- -----------------------------------------------------------------------------
-- 3. Helpers
-- -----------------------------------------------------------------------------

create or replace function public.event_setup_lead_interval(lead text)
returns interval
language sql immutable
as $$
  select case lead
    when '1_day'   then interval '1 day'
    when '3_days'  then interval '3 days'
    when '1_week'  then interval '7 days'
    when '2_weeks' then interval '14 days'
    else interval '0'
  end
$$;

-- True when `uid` leads ministry `gid`.
create or replace function public.event_setup_leads_group(uid text, gid uuid)
returns boolean
language sql stable
security definer
set search_path = public
as $$
  select gid is not null and exists (
    select 1 from group_memberships m
    where m.user_id = uid
      and m.group_id = gid
      and m.status = 'approved'
      and m.role in ('admin', 'leader', 'supervisor', 'owner')
  )
$$;

-- Owners/supervisors may create for any ministry (or church-wide; church-wide
-- announcements are further limited to owners by the triggers below);
-- ministry leaders only for ministries they lead.
create or replace function public.event_setup_can_create(uid text, gid uuid)
returns boolean
language sql stable
security definer
set search_path = public
as $$
  select
    exists (select 1 from profiles p where p.id = uid and p.role in ('owner', 'supervisor'))
    or event_setup_leads_group(uid, gid)
$$;

create or replace function public.event_setup_is_owner(uid text)
returns boolean
language sql stable
security definer
set search_path = public
as $$
  select exists (select 1 from profiles p where p.id = uid and p.role = 'owner')
$$;

-- -----------------------------------------------------------------------------
-- 4. Request creation guard (BEFORE INSERT)
-- -----------------------------------------------------------------------------

create or replace function public.event_setup_validate_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  acting_user text := event_setup_session_var('x-hasura-user-id');
  acting_role text := event_setup_session_var('x-hasura-role');
begin
  if acting_user is null and (acting_role is null or acting_role = 'admin') then
    return new;
  end if;

  if acting_user is null then
    raise exception 'event_setup: missing user session' using errcode = '42501';
  end if;

  if not event_setup_can_create(acting_user, new.group_id) then
    raise exception 'event_setup: not allowed to create events for this ministry'
      using errcode = '42501';
  end if;

  -- A church-wide event's announcement goes to everyone: owners only.
  if new.group_id is null and new.announce_lead is not null and not event_setup_is_owner(acting_user) then
    raise exception 'event_setup: only owners can make church-wide announcements'
      using errcode = '42501';
  end if;

  new.created_by := acting_user;
  return new;
end;
$$;

drop trigger if exists event_setup_validate_request on public.event_setup_requests;
create trigger event_setup_validate_request
  before insert on public.event_setup_requests
  for each row execute function public.event_setup_validate_request();

-- -----------------------------------------------------------------------------
-- 5. Announcement guard (BEFORE INSERT) and fan-out (AFTER INSERT / DELETE)
-- -----------------------------------------------------------------------------

create or replace function public.event_setup_validate_announcement()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  acting_user text := event_setup_session_var('x-hasura-user-id');
  acting_role text := event_setup_session_var('x-hasura-role');
begin
  new.publish_at := greatest(coalesce(new.publish_at, now()), now());

  -- Event announcements come from the publish trigger (request_id isn't a
  -- client-insertable column), so only standalone ones are checked here.
  if new.request_id is not null then
    return new;
  end if;

  if acting_user is null and (acting_role is null or acting_role = 'admin') then
    return new;
  end if;

  if acting_user is null then
    raise exception 'event_setup: missing user session' using errcode = '42501';
  end if;

  if not event_setup_can_create(acting_user, new.group_id) then
    raise exception 'event_setup: not allowed to announce to this ministry'
      using errcode = '42501';
  end if;

  if new.group_id is null and not event_setup_is_owner(acting_user) then
    raise exception 'event_setup: only owners can make church-wide announcements'
      using errcode = '42501';
  end if;

  new.created_by := acting_user;
  return new;
end;
$$;

drop trigger if exists event_setup_validate_announcement on public.event_setup_announcements;
create trigger event_setup_validate_announcement
  before insert on public.event_setup_announcements
  for each row execute function public.event_setup_validate_announcement();

create or replace function public.event_setup_fan_out_announcement()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_id uuid;
begin
  if new.group_id is not null then
    insert into group_announcements (group_id, title, body, published_at)
    values (new.group_id, new.title, new.body, new.publish_at)
    returning id into target_id;

    update event_setup_announcements set group_announcement_id = target_id where id = new.id;
  else
    insert into app_announcements (title, body, published_at, created_by, target_audiences)
    values (new.title, new.body, new.publish_at, new.created_by, new.target_audiences)
    returning id into target_id;

    update event_setup_announcements set app_announcement_id = target_id where id = new.id;
  end if;

  return null;
end;
$$;

drop trigger if exists event_setup_fan_out_announcement on public.event_setup_announcements;
create trigger event_setup_fan_out_announcement
  after insert on public.event_setup_announcements
  for each row execute function public.event_setup_fan_out_announcement();

create or replace function public.event_setup_remove_announcement()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.group_announcement_id is not null then
    delete from group_announcements where id = old.group_announcement_id;
  end if;
  if old.app_announcement_id is not null then
    delete from app_announcements where id = old.app_announcement_id;
  end if;
  return old;
end;
$$;

drop trigger if exists event_setup_remove_announcement on public.event_setup_announcements;
create trigger event_setup_remove_announcement
  after delete on public.event_setup_announcements
  for each row execute function public.event_setup_remove_announcement();

-- -----------------------------------------------------------------------------
-- 6. Publish at 3/3: replaces the v1 function (same trigger, same name).
--    * Calendar entry only when add_to_calendar; ministry events are
--      'group_only' so other ministries don't see them.
--    * Announcement only when announce_lead is set, posted at
--      max(now, event start - lead). It never goes out before approval.
-- -----------------------------------------------------------------------------

create or replace function public.event_setup_publish_when_complete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  req        event_setup_requests;
  done_count integer;
  new_event  uuid;
begin
  select * into req from event_setup_requests where id = new.request_id for update;
  if req.status <> 'pending' then
    return null;
  end if;

  select count(distinct department) into done_count
  from event_setup_signoffs where request_id = req.id;

  if done_count < 3 then
    return null;
  end if;

  if req.add_to_calendar then
    -- Internal setup notes are intentionally NOT copied to the calendar.
    insert into events (
      title, description, event_date, event_end, location, group_id,
      target_audiences, visibility, status
    ) values (
      req.title, req.description, req.event_date, req.event_end,
      case req.room
        when 'main_sanctuary'  then 'Main Sanctuary'
        when 'fellowship_hall' then 'Fellowship Hall'
        when 'youth_room'      then 'Youth Room'
        when 'classroom'       then 'Classroom'
        else null
      end,
      req.group_id, req.target_audiences,
      case when req.group_id is null then 'public_app' else 'group_only' end,
      'approved'
    )
    returning id into new_event;
  end if;

  update event_setup_requests
     set status = 'approved', approved_at = now(), calendar_event_id = new_event
   where id = req.id;

  if req.announce_lead is not null then
    insert into event_setup_announcements (
      request_id, group_id, title, body, target_audiences, publish_at, created_by
    ) values (
      req.id, req.group_id, req.title, req.description, req.target_audiences,
      greatest(now(), req.event_date - event_setup_lead_interval(req.announce_lead)),
      req.created_by
    );
  end if;

  return null;
end;
$$;
