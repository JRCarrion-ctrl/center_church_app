# Event Setup — Hasura metadata & permissions

Apply after `001_event_setup.sql`. Track all three tables in the Hasura console
(Data → public → Track), then configure the relationships and permissions below.
Only the `owner` and `supervisor` roles get any access. Every other role
(`member`, `leader`, `group_admin`, `nursery_staff`, `user`, anonymous) has **no
permission rows at all**, so the API rejects any query or mutation from them.

Postgres triggers back up these permission rules:

| Rule | Enforced by |
| --- | --- |
| Approver must be `owner` or hold a matching approval permission for the department + ministry | `event_setup_validate_signoff` (BEFORE INSERT OR DELETE) |
| `approved_by` is always the session user | `event_setup_validate_signoff` overwrites it |
| No sign-off changes after a request is approved | `event_setup_validate_signoff` |
| Sign-offs are never edited in place | `event_setup_block_signoff_update` |
| 3/3 → status `approved` + row inserted into `events` | `event_setup_publish_when_complete` (AFTER INSERT) |
| `created_by` on permission rules = session user | `event_setup_stamp_permission_creator` |

## Relationships

| Table | Name | Type | Mapping |
| --- | --- | --- | --- |
| `event_setup_requests` | `group` | object | `group_id → groups.id` |
| `event_setup_requests` | `creator` | object | `created_by → profiles.id` |
| `event_setup_requests` | `signoffs` | array | `event_setup_signoffs.request_id → id` |
| `event_setup_signoffs` | `approver` | object | `approved_by → profiles.id` |
| `event_setup_approval_permissions` | `profile` | object | `user_id → profiles.id` |
| `event_setup_approval_permissions` | `group` | object | `group_id → groups.id` |

## `event_setup_requests`

| Op | Role | Row check / filter | Columns | Presets |
| --- | --- | --- | --- | --- |
| select | owner, supervisor | `{}` | all | — |
| insert | owner, supervisor | `{}` | `title, group_id, room, event_date, event_end, estimated_attendance, notes, target_audiences` | `created_by = X-Hasura-User-Id` |
| update | — | *none* (status changes only through the trigger) | — | — |
| delete | owner | `{ "status": { "_eq": "pending" } }` | — | — |

`status`, `approved_at` and `calendar_event_id` are **not** insertable, so a
client can't create a request that is already approved.

## `event_setup_signoffs`

| Op | Role | Row check / filter | Columns | Presets |
| --- | --- | --- | --- | --- |
| select | owner, supervisor | `{}` | all | — |
| insert | owner, supervisor | `{}` | `request_id, department` | `approved_by = X-Hasura-User-Id` |
| update | — | *none* | — | — |
| delete | owner, supervisor | `{ "request": { "status": { "_eq": "pending" } } }` | — | — |

(Add an object relationship `request: request_id → event_setup_requests.id` on
`event_setup_signoffs` for the delete filter. The insert check is intentionally
`{}`: the validation trigger already rejects sign-offs on approved requests, and
a relationship check there could see the status flip to `approved` that the
3/3 publish trigger makes in the same statement.)

Department authority is checked per row by the trigger, not by Hasura. For
example, a supervisor who only holds a `security` rule for Youth Ministry gets a
`42501` error if they try to insert or delete the `cleaning` sign-off, or a
`security` sign-off on another ministry's event.

## `event_setup_approval_permissions`

| Op | Role | Row check / filter | Columns | Presets |
| --- | --- | --- | --- | --- |
| select | owner, supervisor | `{}` | all | — |
| insert | owner | `{}` | `user_id, department, group_id` | `created_by = X-Hasura-User-Id` |
| update | owner | `{}` | `department, group_id` | — |
| delete | owner | `{}` | — | — |

## Existing tables the feature reads

The roles also need read access to these existing tables. They probably have it already:

- `groups`: `id, name, archived` for `owner` and `supervisor` (ministry dropdowns).
- `profiles`: `id, display_name, email` for `owner` (member picker on the
  Approval Permissions page) and for `supervisor` (approver names on cards).

## Event trigger (notifications)

Create the event trigger `event_setup_request_created` on `event_setup_requests`,
operation **Insert**, pointing at the webhook described in
[notifications_webhook.md](notifications_webhook.md).

---

# v2: announcements, ministry visibility, leader creators (`002_announcements_and_visibility.sql`)

Track the new table `event_setup_announcements`, then make the changes below.
v2 opens Event Setup beyond owner/supervisor, so the rules below apply to
**every signed-in role** (`member`, `leader`, `group_admin`, `nursery_staff`,
`user`). Owner and supervisor keep `{}` everywhere from v1.

## Shared filters

**Staff**: anyone with an approval permission (administrator, security or
cleaning) sees every ministry:

```json
{ "_exists": {
    "_table": { "schema": "public", "name": "event_setup_approval_permissions" },
    "_where": { "user_id": { "_eq": "X-Hasura-User-Id" } } } }
```

**Leads this ministry**: used through the row's `group` relationship:

```json
{ "group": { "group_memberships": {
    "user_id": { "_eq": "X-Hasura-User-Id" },
    "status":  { "_eq": "approved" },
    "role":    { "_in": ["admin", "leader", "supervisor", "owner"] } } } }
```

`VISIBLE` below means `{ "_or": [ <Staff>, <Leads this ministry> ] }`.

## Relationships (new)

| Table | Name | Type | Mapping |
| --- | --- | --- | --- |
| `event_setup_announcements` | `group` | object | `group_id → groups.id` |
| `event_setup_announcements` | `creator` | object | `created_by → profiles.id` |
| `event_setup_announcements` | `request` | object | `request_id → event_setup_requests.id` |

## `event_setup_requests` (other roles)

| Op | Role | Row check / filter | Columns | Presets |
| --- | --- | --- | --- | --- |
| select | all other roles | `VISIBLE` | all | — |
| insert | all other roles | `<Leads this ministry>` | `title, group_id, room, event_date, event_end, estimated_attendance, notes, description, add_to_calendar, announce_lead, target_audiences` | `created_by = X-Hasura-User-Id` |

Also add `description, add_to_calendar, announce_lead` to the owner/supervisor
insert columns. The `event_setup_validate_request` trigger re-checks every
insert: a leader can't submit for a ministry they don't lead, and only
owners/supervisors can submit church-wide (no ministry).

## `event_setup_signoffs` (other roles)

| Op | Role | Row check / filter | Columns | Presets |
| --- | --- | --- | --- | --- |
| select | all other roles | `{ "request": VISIBLE }` | all | — |
| insert | all other roles | `<Staff>` | `request_id, department` | `approved_by = X-Hasura-User-Id` |
| delete | all other roles | `{ "_and": [ <Staff>, { "request": { "status": { "_eq": "pending" } } } ] }` | — | — |

This lets cleaning/security approvers whose app role is `member` sign off.
The v1 trigger still checks the department and ministry for every sign-off.

## `event_setup_approval_permissions` (other roles)

| Op | Role | Row check / filter | Columns |
| --- | --- | --- | --- |
| select | all other roles | `{ "user_id": { "_eq": "X-Hasura-User-Id" } }` | all |

The app uses this to decide whether to show the Event Setup tab.

## `event_setup_announcements`

| Op | Role | Row check / filter | Columns | Presets |
| --- | --- | --- | --- | --- |
| select | owner, supervisor | `{}` | all | — |
| select | all other roles | `VISIBLE` | all | — |
| insert | owner | `{}` | `group_id, title, body, target_audiences, publish_at` | `created_by = X-Hasura-User-Id` |
| insert | supervisor | `{ "group_id": { "_is_null": false } }` | same | same |
| insert | all other roles | `<Leads this ministry>` | same | same |
| update | — | *none* (delete and re-post instead) | — | — |
| delete | owner, supervisor | `{}` | — | — |
| delete | all other roles | `{ "created_by": { "_eq": "X-Hasura-User-Id" } }` | — | — |

Only owners can post church-wide (no ministry). The triggers enforce this too,
including the announcement of a church-wide event.

`request_id`, `group_announcement_id` and `app_announcement_id` are never
client-insertable. Triggers copy each row into `group_announcements` (ministry)
or `app_announcements` (church-wide) and delete the copy when the hub row is
deleted.

## Existing tables: check member-facing filters

The ministry boundary for regular members is enforced on the existing tables,
not on the Event Setup tables. Confirm these filters exist for member roles
(the client already filters this way, but CLAUDE.md requires server enforcement):

- `group_announcements` select: `{ "group": { "group_memberships": { "user_id": { "_eq": "X-Hasura-User-Id" }, "status": { "_eq": "approved" } } } }`
- `events` select: `{ "_or": [ { "visibility": { "_eq": "public_app" } }, { "group": { "group_memberships": { "user_id": { "_eq": "X-Hasura-User-Id" }, "status": { "_eq": "approved" } } } } ] }`

If `events` currently allows `{}` for members, a Worship `group_only` event is
still hidden in the app UI but readable through the API.

## Roles that read `groups` / `profiles`

Leaders and approvers need `groups { id name }` and
`profiles { display_name }` (creator and approver names on cards). Most member
roles already have these.

---

# v3: editing submitted events + notifications (`003_edits_and_notifications.sql`)

**Easiest:** run [apply_hasura.py](apply_hasura.py). It runs the 003 SQL, tracks
all five Event Setup tables, adds every relationship above and recreates every
Event Setup permission (v1 + v2 + v3) in one go:

```powershell
$env:HASURA_ADMIN_SECRET = "<admin secret>"
python backend/event_setup/apply_hasura.py --dry-run   # preview
python backend/event_setup/apply_hasura.py
```

What v3 adds:

| Table | Op | Role | Filter | Columns |
| --- | --- | --- | --- | --- |
| `event_setup_requests` | update | owner | `{}` | `title, description, room, event_date, event_end, estimated_attendance, notes, target_audiences` |
| `event_setup_requests` | update | everyone else | `{ "created_by": { "_eq": "X-Hasura-User-Id" } }` | same |
| `event_setup_notifications` | select / delete | every role | `{ "user_id": { "_eq": "X-Hasura-User-Id" } }` | all |
| `event_setup_notifications` | update | every role | same | `read_at` |

Relationships on `event_setup_notifications`: `request` (request_id) and
`actor` (actor_id → profiles).

Edits never reset sign-offs. The `event_setup_after_edit` trigger copies the
change to the calendar entry and announcement, and inserts one
`event_setup_notifications` row for each Cleaning/Security approver of that
ministry and each owner (not the person who made the edit).

---

# v4: pictures, typed-in locations, files, RSVP, sign-up slots (`004_media_rsvp_signups.sql`)

Run [apply_hasura.py](apply_hasura.py) again. It runs 003 then 004 and updates
the permissions below.

New columns:

| Table | Column | Notes |
| --- | --- | --- |
| `event_setup_requests` | `image_url` | Copied to the calendar entry and to the event's announcement |
| `event_setup_requests` | `location_other` | Used as the location when `room = 'other'` |
| `event_setup_requests` | `rsvp_enabled` | Copied to `events.rsvp_enabled` |
| `event_setup_requests` | `signup_slots` (jsonb) | `[{title, max_slots}]` → `unified_event_slots` at approval |
| `event_setup_requests` | `attachments` (jsonb) | `[{file_name, file_url, content_type, file_size_bytes}]` → `event_attachments` at approval |
| `event_setup_announcements` | `image_url` | Copied to `group_announcements` / `app_announcements` |
| `events` | `rsvp_enabled` (default `true`) | Existing events keep RSVP |

Permission changes:

- `event_setup_requests` insert + update: add `image_url, location_other,
  rsvp_enabled, signup_slots, attachments`.
- `event_setup_announcements` insert: add `image_url`.
- `events` select: `rsvp_enabled` is appended to every role whose select
  permission lists columns explicitly. The app reads it in its own small query
  and treats a failure as "RSVP on", so the calendar keeps working even before
  this runs.

After approval, `signup_slots` and `attachments` on the request are frozen by
`event_setup_validate_edit`; they're managed on the calendar event's page.
