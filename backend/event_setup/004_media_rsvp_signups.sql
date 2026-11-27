-- =============================================================================
-- Event Setup v4: pictures, typed-in locations, files, RSVP and sign-up slots.
--
-- * Requests get an optional picture (used on the calendar entry AND on the
--   event's announcement), a free-text location when the room is "Other",
--   an RSVP switch, sign-up slots and files.
-- * Standalone announcements get an optional picture.
-- * At 3/3 approval the publish trigger copies the picture, location, RSVP
--   switch, sign-up slots (-> unified_event_slots) and files
--   (-> event_attachments) onto the calendar entry.
-- * events.rsvp_enabled lets an event turn RSVP off. It defaults to TRUE so
--   every existing event keeps its RSVP section.
--
-- Apply AFTER 003. Easiest: run backend/event_setup/apply_hasura.py (it runs
-- 003 then this file, and updates permissions). Safe to run more than once.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Columns
-- -----------------------------------------------------------------------------

alter table public.event_setup_requests
  add column if not exists image_url      text null,
  -- Shown as the location when room = 'other'.
  add column if not exists location_other text null,
  add column if not exists rsvp_enabled   boolean not null default false,
  -- [{ "title": "Bring a dessert", "max_slots": 10 }, ...]
  add column if not exists signup_slots   jsonb not null default '[]'::jsonb,
  -- [{ "file_name": "...", "file_url": "...", "content_type": "...", "file_size_bytes": 123 }, ...]
  add column if not exists attachments    jsonb not null default '[]'::jsonb;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'event_setup_requests_signup_slots_array') then
    alter table public.event_setup_requests
      add constraint event_setup_requests_signup_slots_array check (jsonb_typeof(signup_slots) = 'array');
  end if;
  if not exists (select 1 from pg_constraint where conname = 'event_setup_requests_attachments_array') then
    alter table public.event_setup_requests
      add constraint event_setup_requests_attachments_array check (jsonb_typeof(attachments) = 'array');
  end if;
end $$;

alter table public.event_setup_announcements
  add column if not exists image_url text null;

alter table public.events
  add column if not exists rsvp_enabled boolean not null default true;

-- -----------------------------------------------------------------------------
-- 2. Helpers
-- -----------------------------------------------------------------------------

create or replace function public.event_setup_location(room text, location_other text)
returns text
language sql immutable
as $$
  select case room
    when 'main_sanctuary'  then 'Main Sanctuary'
    when 'fellowship_hall' then 'Fellowship Hall'
    when 'youth_room'      then 'Youth Room'
    when 'classroom'       then 'Classroom'
    else nullif(trim(coalesce(location_other, '')), '')
  end
$$;

-- -----------------------------------------------------------------------------
-- 3. Announcement fan-out: now copies the picture
-- -----------------------------------------------------------------------------

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
    insert into group_announcements (group_id, title, body, image_url, published_at)
    values (new.group_id, new.title, new.body, new.image_url, new.publish_at)
    returning id into target_id;

    update event_setup_announcements set group_announcement_id = target_id where id = new.id;
  else
    insert into app_announcements (title, body, image_url, published_at, created_by, target_audiences)
    values (new.title, new.body, new.image_url, new.publish_at, new.created_by, new.target_audiences)
    returning id into target_id;

    update event_setup_announcements set app_announcement_id = target_id where id = new.id;
  end if;

  return null;
end;
$$;

-- -----------------------------------------------------------------------------
-- 4. Publish at 3/3: replaces the v2 function (same trigger, same name).
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
      title, description, image_url, event_date, event_end, location, group_id,
      target_audiences, visibility, status, rsvp_enabled
    ) values (
      req.title, req.description, req.image_url, req.event_date, req.event_end,
      event_setup_location(req.room, req.location_other),
      req.group_id, req.target_audiences,
      case when req.group_id is null then 'public_app' else 'group_only' end,
      'approved', req.rsvp_enabled
    )
    returning id into new_event;

    -- Sign-up slots.
    insert into unified_event_slots (event_id, title, max_slots)
    select new_event, trim(s ->> 'title'), greatest(coalesce((s ->> 'max_slots')::int, 1), 1)
    from jsonb_array_elements(req.signup_slots) s
    where length(trim(coalesce(s ->> 'title', ''))) > 0;

    -- Files.
    insert into event_attachments (
      event_id, group_id, file_name, file_url, content_type, file_size_bytes, uploaded_by
    )
    select new_event, req.group_id, a ->> 'file_name', a ->> 'file_url',
           coalesce(a ->> 'content_type', 'application/octet-stream'),
           (a ->> 'file_size_bytes')::int, req.created_by
    from jsonb_array_elements(req.attachments) a
    where coalesce(a ->> 'file_url', '') <> '' and coalesce(a ->> 'file_name', '') <> '';
  end if;

  update event_setup_requests
     set status = 'approved', approved_at = now(), calendar_event_id = new_event
   where id = req.id;

  if req.announce_lead is not null then
    insert into event_setup_announcements (
      request_id, group_id, title, body, image_url, target_audiences, publish_at, created_by
    ) values (
      req.id, req.group_id, req.title, req.description, req.image_url, req.target_audiences,
      greatest(now(), req.event_date - event_setup_lead_interval(req.announce_lead)),
      req.created_by
    );
  end if;

  return null;
end;
$$;

-- -----------------------------------------------------------------------------
-- 5. Edits: track the new fields, sync picture / location / RSVP.
--    Sign-up slots and files can only change while the request is pending;
--    after approval they're managed on the calendar event's page.
-- -----------------------------------------------------------------------------

create or replace function public.event_setup_edited_fields(o public.event_setup_requests, n public.event_setup_requests)
returns jsonb
language sql immutable
as $$
  select coalesce(jsonb_agg(f), '[]'::jsonb) from (
    select 'title' as f where o.title is distinct from n.title
    union all select 'description' where o.description is distinct from n.description
    union all select 'room' where o.room is distinct from n.room
                               or o.location_other is distinct from n.location_other
    union all select 'event_date' where o.event_date is distinct from n.event_date
    union all select 'event_end' where o.event_end is distinct from n.event_end
    union all select 'estimated_attendance' where o.estimated_attendance is distinct from n.estimated_attendance
    union all select 'notes' where o.notes is distinct from n.notes
    union all select 'target_audiences' where o.target_audiences is distinct from n.target_audiences
    union all select 'image_url' where o.image_url is distinct from n.image_url
    union all select 'rsvp_enabled' where o.rsvp_enabled is distinct from n.rsvp_enabled
    union all select 'signup_slots' where o.signup_slots is distinct from n.signup_slots
    union all select 'attachments' where o.attachments is distinct from n.attachments
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

  -- Once published, slots and files live on the calendar event.
  if old.status = 'approved' then
    new.signup_slots := old.signup_slots;
    new.attachments  := old.attachments;
  end if;
  return new;
end;
$$;

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
           image_url        = new.image_url,
           event_date       = new.event_date,
           event_end        = new.event_end,
           target_audiences = new.target_audiences,
           rsvp_enabled     = new.rsvp_enabled,
           location         = coalesce(event_setup_location(new.room, new.location_other), location)
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
       set title = new.title, body = new.description, image_url = new.image_url,
           target_audiences = new.target_audiences, publish_at = new_publish
     where id = ann.id;

    if ann.group_announcement_id is not null then
      update group_announcements
         set title = new.title, body = new.description, image_url = new.image_url,
             published_at = new_publish
       where id = ann.group_announcement_id;
    end if;
    if ann.app_announcement_id is not null then
      update app_announcements
         set title = new.title, body = new.description, image_url = new.image_url,
             published_at = new_publish, target_audiences = new.target_audiences
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
