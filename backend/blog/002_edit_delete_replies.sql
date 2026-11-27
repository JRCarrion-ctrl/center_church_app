-- =============================================================================
-- Blog v2: owners can edit and delete replies.
--
-- * blog_comments.edited_at: set automatically when a comment's text changes,
--   so the app can show "(edited)".
-- * Only owners may edit or delete a reply. Enforced here as well as in Hasura
--   permissions. A reply removed because its parent comment was deleted
--   (ON DELETE CASCADE) is always allowed.
--
-- Apply with: python backend/blog/apply_hasura.py  (safe to run more than once)
-- =============================================================================

alter table public.blog_comments
  add column if not exists edited_at timestamptz null;

create or replace function public.blog_session_is_owner_or_admin()
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  settings    jsonb := nullif(current_setting('hasura.user', true), '')::jsonb;
  acting_user text  := settings ->> 'x-hasura-user-id';
  acting_role text  := settings ->> 'x-hasura-role';
begin
  -- Admin secret / console calls have no user session.
  if acting_user is null and (acting_role is null or acting_role = 'admin') then
    return true;
  end if;
  return acting_user is not null
     and exists (select 1 from profiles where id::text = acting_user and role = 'owner');
end;
$$;

create or replace function public.blog_comments_before_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.content is distinct from old.content then
    if old.parent_id is not null and not blog_session_is_owner_or_admin() then
      raise exception 'blog: only the pastor can edit replies' using errcode = '42501';
    end if;
    new.edited_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists blog_comments_before_update on public.blog_comments;
create trigger blog_comments_before_update
  before update on public.blog_comments
  for each row execute function public.blog_comments_before_update();

create or replace function public.blog_comments_before_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.parent_id is not null
     and exists (select 1 from blog_comments where id = old.parent_id)  -- not a cascade
     and not blog_session_is_owner_or_admin() then
    raise exception 'blog: only the pastor can delete replies' using errcode = '42501';
  end if;
  return old;
end;
$$;

drop trigger if exists blog_comments_before_delete on public.blog_comments;
create trigger blog_comments_before_delete
  before delete on public.blog_comments
  for each row execute function public.blog_comments_before_delete();
