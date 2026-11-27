-- =============================================================================
-- Blog v1: owner replies to comments.
--
-- * blog_comments.parent_id: a reply points at the top-level comment it
--   answers. Deleting a comment deletes its replies.
-- * Only users whose profiles.role = 'owner' may write a reply, and replies
--   can't be nested (a reply must answer a top-level comment on the same post).
--   Enforced here in the database, not just in the app.
--
-- Apply with: python backend/blog/apply_hasura.py  (safe to run more than once)
-- =============================================================================

alter table public.blog_comments
  add column if not exists parent_id uuid null
    references public.blog_comments(id) on delete cascade;

create index if not exists blog_comments_parent_id_idx on public.blog_comments(parent_id);

create or replace function public.blog_comments_check_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  settings    jsonb := nullif(current_setting('hasura.user', true), '')::jsonb;
  acting_user text  := settings ->> 'x-hasura-user-id';
  acting_role text  := settings ->> 'x-hasura-role';
  parent      blog_comments;
begin
  if new.parent_id is null then
    return new;
  end if;

  -- Admin secret / console calls have no user session.
  if not (acting_user is null and (acting_role is null or acting_role = 'admin')) then
    if acting_user is null
       or not exists (select 1 from profiles where id::text = acting_user and role = 'owner') then
      raise exception 'blog: only the pastor can reply to comments' using errcode = '42501';
    end if;
  end if;

  select * into parent from blog_comments where id = new.parent_id;
  if parent.id is null then
    raise exception 'blog: the comment you replied to no longer exists' using errcode = '23503';
  end if;
  if parent.parent_id is not null then
    raise exception 'blog: replies can only answer a top-level comment' using errcode = '23514';
  end if;
  if parent.blog_post_id is distinct from new.blog_post_id then
    raise exception 'blog: a reply must be on the same post as its comment' using errcode = '23514';
  end if;

  return new;
end;
$$;

drop trigger if exists blog_comments_check_reply on public.blog_comments;
create trigger blog_comments_check_reply
  before insert or update of parent_id on public.blog_comments
  for each row execute function public.blog_comments_check_reply();
