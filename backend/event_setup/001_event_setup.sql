-- =============================================================================
-- Event Setup: requests, 3-department sign-offs, owner-managed approval
-- permissions, server-side enforcement, and automatic calendar publishing.
--
-- Apply with the Hasura console (Data -> SQL, leave "Track this" UNCHECKED: the
-- helper functions here cannot be tracked) or as a Hasura CLI migration. Then
-- track the new tables under Data -> public and apply hasura_permissions.md.
--
-- NOTE: profiles.id is a text column (Zitadel subject id), so every user
-- reference here is `text`, not `uuid`.
-- =============================================================================

create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- 1. Tables
-- -----------------------------------------------------------------------------

create table if not exists public.event_setup_requests (
  id                    uuid primary key default gen_random_uuid(),
  title                 text not null check (length(trim(title)) > 0),
  group_id              uuid null references public.groups(id) on delete set null,
  room                  text not null check (room in (
                          'main_sanctuary', 'fellowship_hall', 'youth_room',
                          'classroom', 'other')),
  event_date            timestamptz not null,
  event_end             timestamptz not null,
  estimated_attendance  integer null check (estimated_attendance is null or estimated_attendance >= 0),
  notes                 text null,
  target_audiences      text[] not null default array['english', 'spanish'],
  status                text not null default 'pending' check (status in ('pending', 'approved')),
  created_by            text not null references public.profiles(id) on delete cascade,
  created_at            timestamptz not null default now(),
  approved_at           timestamptz null,
  calendar_event_id     uuid null references public.events(id) on delete set null,
  constraint event_setup_requests_end_after_start check (event_end > event_date)
);

create index if not exists event_setup_requests_status_idx
  on public.event_setup_requests (status, event_date);

create table if not exists public.event_setup_signoffs (
  id           uuid primary key default gen_random_uuid(),
  request_id   uuid not null references public.event_setup_requests(id) on delete cascade,
  department   text not null check (department in ('administrator', 'security', 'cleaning')),
  approved_by  text not null references public.profiles(id) on delete cascade,
  approved_at  timestamptz not null default now(),
  constraint event_setup_signoffs_one_per_department unique (request_id, department)
);

create table if not exists public.event_setup_approval_permissions (
  id          uuid primary key default gen_random_uuid(),
  user_id     text not null references public.profiles(id) on delete cascade,
  department  text not null check (department in ('administrator', 'security', 'cleaning')),
  -- NULL = All Ministries; otherwise only events submitted under this group.
  group_id    uuid null references public.groups(id) on delete cascade,
  created_by  text null references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now()
);

create unique index if not exists event_setup_approval_permissions_unique_rule
  on public.event_setup_approval_permissions (
    user_id, department,
    coalesce(group_id, '00000000-0000-0000-0000-000000000000'::uuid)
  );

-- -----------------------------------------------------------------------------
-- 2. Helpers
-- -----------------------------------------------------------------------------

-- Hasura sets `hasura.user` (JSON of session variables) for every mutation.
-- Returns NULL for requests that carry no user (admin secret / console).
create or replace function public.event_setup_session_var(var text)
returns text
language sql stable
as $$
  select nullif(current_setting('hasura.user', true), '')::json ->> var
$$;

-- True when `uid` may sign off `dept` for an event in `gid`.
create or replace function public.event_setup_can_approve(uid text, dept text, gid uuid)
returns boolean
language sql stable
security definer
set search_path = public
as $$
  select
    exists (select 1 from profiles p where p.id = uid and p.role = 'owner')
    or exists (
      select 1
      from event_setup_approval_permissions ap
      where ap.user_id = uid
        and ap.department = dept
        and (ap.group_id is null or ap.group_id = gid)
    )
$$;

-- -----------------------------------------------------------------------------
-- 3. Sign-off validation (BEFORE INSERT OR DELETE)
-- -----------------------------------------------------------------------------

create or replace function public.event_setup_validate_signoff()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  acting_user text := event_setup_session_var('x-hasura-user-id');
  acting_role text := event_setup_session_var('x-hasura-role');
  sig         event_setup_signoffs;
  req         event_setup_requests;
begin
  if tg_op = 'DELETE' then
    sig := old;
  else
    sig := new;
  end if;

  select * into req from event_setup_requests where id = sig.request_id;

  -- Cascading deletes from a removed request don't need validation.
  if req.id is null then
    return case when tg_op = 'DELETE' then old else new end;
  end if;

  -- Hasura admin secret / direct DB maintenance: no session user.
  if acting_user is null and (acting_role is null or acting_role = 'admin') then
    return case when tg_op = 'DELETE' then old else new end;
  end if;

  if acting_user is null then
    raise exception 'event_setup: missing user session' using errcode = '42501';
  end if;

  if req.status <> 'pending' then
    raise exception 'event_setup: request is already approved and scheduled'
      using errcode = '42501';
  end if;

  if not event_setup_can_approve(acting_user, sig.department, req.group_id) then
    raise exception 'event_setup: not authorized to sign off % for this ministry', sig.department
      using errcode = '42501';
  end if;

  if tg_op = 'INSERT' then
    -- Never trust a client-supplied approver.
    new.approved_by := acting_user;
    new.approved_at := now();
    return new;
  end if;

  return old;
end;
$$;

drop trigger if exists event_setup_validate_signoff on public.event_setup_signoffs;
create trigger event_setup_validate_signoff
  before insert or delete on public.event_setup_signoffs
  for each row execute function public.event_setup_validate_signoff();

-- Sign-offs are immutable: toggle off = delete, toggle on = insert.
create or replace function public.event_setup_block_signoff_update()
returns trigger
language plpgsql
as $$
begin
  raise exception 'event_setup: sign-offs cannot be edited' using errcode = '42501';
end;
$$;

drop trigger if exists event_setup_block_signoff_update on public.event_setup_signoffs;
create trigger event_setup_block_signoff_update
  before update on public.event_setup_signoffs
  for each row execute function public.event_setup_block_signoff_update();

-- -----------------------------------------------------------------------------
-- 4. Automatic calendar sync at 3/3 (AFTER INSERT)
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

  -- Internal setup notes are intentionally NOT copied to the public calendar.
  insert into events (
    title, event_date, event_end, location, group_id,
    target_audiences, visibility, status
  ) values (
    req.title, req.event_date, req.event_end,
    case req.room
      when 'main_sanctuary'  then 'Main Sanctuary'
      when 'fellowship_hall' then 'Fellowship Hall'
      when 'youth_room'      then 'Youth Room'
      when 'classroom'       then 'Classroom'
      else null
    end,
    req.group_id, req.target_audiences, 'public_app', 'approved'
  )
  returning id into new_event;

  update event_setup_requests
     set status = 'approved', approved_at = now(), calendar_event_id = new_event
   where id = req.id;

  return null;
end;
$$;

drop trigger if exists event_setup_publish_when_complete on public.event_setup_signoffs;
create trigger event_setup_publish_when_complete
  after insert on public.event_setup_signoffs
  for each row execute function public.event_setup_publish_when_complete();

-- -----------------------------------------------------------------------------
-- 5. Approval permissions: stamp created_by from the session
-- -----------------------------------------------------------------------------

create or replace function public.event_setup_stamp_permission_creator()
returns trigger
language plpgsql
as $$
begin
  new.created_by := coalesce(event_setup_session_var('x-hasura-user-id'), new.created_by);
  return new;
end;
$$;

drop trigger if exists event_setup_stamp_permission_creator on public.event_setup_approval_permissions;
create trigger event_setup_stamp_permission_creator
  before insert on public.event_setup_approval_permissions
  for each row execute function public.event_setup_stamp_permission_creator();

-- -----------------------------------------------------------------------------
-- 6. Notification recipients (used by the webhook, see notifications_webhook.md)
-- -----------------------------------------------------------------------------

create or replace function public.event_setup_notification_recipients(p_request_id uuid)
returns table (user_id text, department text)
language sql stable
security definer
set search_path = public
as $$
  select distinct ap.user_id, ap.department
  from event_setup_requests r
  join event_setup_approval_permissions ap
    on ap.group_id is null or ap.group_id = r.group_id
  where r.id = p_request_id
$$;
