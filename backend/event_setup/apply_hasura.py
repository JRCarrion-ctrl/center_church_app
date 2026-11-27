"""
Event Setup: one-command Hasura setup.

Runs 003_edits_and_notifications.sql and 004_media_rsvp_signups.sql (001 and
002 are already applied), then tracks the Event Setup tables, adds their
relationships and (re)creates every permission described in
hasura_permissions.md. Outside the five event_setup_* tables, the only metadata
change is adding the new `events.rsvp_enabled` column to roles that can already
select from `events` (so the app can tell whether an event takes RSVPs).

Usage (PowerShell). The admin secret stays in your terminal and is never
written anywhere:

    $env:HASURA_ADMIN_SECRET = "<your admin secret>"
    python backend/event_setup/apply_hasura.py            # apply
    python backend/event_setup/apply_hasura.py --dry-run  # only print the plan

Optional: $env:HASURA_URL (default https://api.ccfapp.com).
Safe to run again: existing tables/relationships are skipped, and Event Setup
permissions are dropped and recreated so they always match this file.
"""

import json
import os
import sys
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
URL = os.environ.get("HASURA_URL", "https://api.ccfapp.com").rstrip("/")
SECRET = os.environ.get("HASURA_ADMIN_SECRET")
DRY = "--dry-run" in sys.argv
SKIP_SQL = "--skip-sql" in sys.argv

STAFF_ROLES = ["owner", "supervisor"]
# Roles that exist in most installs; any other role found in metadata is added.
DEFAULT_OTHER_ROLES = ["member", "leader", "group_admin", "nursery_staff", "user"]

ME = "X-Hasura-User-Id"
STAFF = {
    "_exists": {
        "_table": {"schema": "public", "name": "event_setup_approval_permissions"},
        "_where": {"user_id": {"_eq": ME}},
    }
}
LEADS = {
    "group": {
        "group_memberships": {
            "user_id": {"_eq": ME},
            "status": {"_eq": "approved"},
            "role": {"_in": ["admin", "leader", "supervisor", "owner"]},
        }
    }
}
MINE = {"created_by": {"_eq": ME}}
VISIBLE = {"_or": [STAFF, LEADS, MINE]}
PENDING = {"status": {"_eq": "pending"}}

MEDIA_COLS = ["image_url", "location_other", "rsvp_enabled", "signup_slots", "attachments"]
REQ_INSERT_COLS = [
    "title", "group_id", "room", "event_date", "event_end", "estimated_attendance",
    "notes", "description", "add_to_calendar", "announce_lead", "target_audiences",
] + MEDIA_COLS
REQ_EDIT_COLS = [
    "title", "description", "room", "event_date", "event_end",
    "estimated_attendance", "notes", "target_audiences",
] + MEDIA_COLS
ANN_INSERT_COLS = ["group_id", "title", "body", "image_url", "target_audiences", "publish_at"]
SQL_FILES = ["003_edits_and_notifications.sql", "004_media_rsvp_signups.sql"]

T_REQ = "event_setup_requests"
T_SIG = "event_setup_signoffs"
T_PERM = "event_setup_approval_permissions"
T_ANN = "event_setup_announcements"
T_NOTE = "event_setup_notifications"
TABLES = [T_REQ, T_SIG, T_PERM, T_ANN, T_NOTE]

# (table, name, kind, using)
RELATIONSHIPS = [
    (T_REQ, "group", "object", {"foreign_key_constraint_on": "group_id"}),
    (T_REQ, "creator", "object", {"foreign_key_constraint_on": "created_by"}),
    (T_REQ, "signoffs", "array",
     {"foreign_key_constraint_on": {"table": {"schema": "public", "name": T_SIG}, "column": "request_id"}}),
    (T_SIG, "approver", "object", {"foreign_key_constraint_on": "approved_by"}),
    (T_SIG, "request", "object", {"foreign_key_constraint_on": "request_id"}),
    (T_PERM, "profile", "object", {"foreign_key_constraint_on": "user_id"}),
    (T_PERM, "group", "object", {"foreign_key_constraint_on": "group_id"}),
    (T_ANN, "group", "object", {"foreign_key_constraint_on": "group_id"}),
    (T_ANN, "creator", "object", {"foreign_key_constraint_on": "created_by"}),
    (T_ANN, "request", "object", {"foreign_key_constraint_on": "request_id"}),
    (T_NOTE, "request", "object", {"foreign_key_constraint_on": "request_id"}),
    (T_NOTE, "actor", "object", {"foreign_key_constraint_on": "actor_id"}),
]


def permissions(other_roles):
    """Returns a list of (table, op, role, permission)."""
    out = []

    def add(table, op, roles, perm):
        for r in roles:
            out.append((table, op, r, perm))

    everyone = STAFF_ROLES + other_roles

    # --- requests ---
    add(T_REQ, "select", STAFF_ROLES, {"columns": "*", "filter": {}})
    add(T_REQ, "select", other_roles, {"columns": "*", "filter": VISIBLE})
    add(T_REQ, "insert", STAFF_ROLES, {"columns": REQ_INSERT_COLS, "check": {}, "set": {"created_by": ME}})
    add(T_REQ, "insert", other_roles, {"columns": REQ_INSERT_COLS, "check": LEADS, "set": {"created_by": ME}})
    add(T_REQ, "update", ["owner"], {"columns": REQ_EDIT_COLS, "filter": {}, "check": {}})
    add(T_REQ, "update", ["supervisor"] + other_roles, {"columns": REQ_EDIT_COLS, "filter": MINE, "check": MINE})
    add(T_REQ, "delete", ["owner"], {"filter": PENDING})
    add(T_REQ, "delete", ["supervisor"] + other_roles, {"filter": {"_and": [MINE, PENDING]}})

    # --- sign-offs ---
    req_pending = {"request": PENDING}
    add(T_SIG, "select", STAFF_ROLES, {"columns": "*", "filter": {}})
    add(T_SIG, "select", other_roles, {"columns": "*", "filter": {"request": VISIBLE}})
    add(T_SIG, "insert", STAFF_ROLES, {"columns": ["request_id", "department"], "check": {}, "set": {"approved_by": ME}})
    add(T_SIG, "insert", other_roles, {"columns": ["request_id", "department"], "check": STAFF, "set": {"approved_by": ME}})
    add(T_SIG, "delete", STAFF_ROLES, {"filter": req_pending})
    add(T_SIG, "delete", other_roles, {"filter": {"_and": [STAFF, req_pending]}})

    # --- approval permissions ---
    add(T_PERM, "select", STAFF_ROLES, {"columns": "*", "filter": {}})
    add(T_PERM, "select", other_roles, {"columns": "*", "filter": {"user_id": {"_eq": ME}}})
    add(T_PERM, "insert", ["owner"], {"columns": ["user_id", "department", "group_id"], "check": {}, "set": {"created_by": ME}})
    add(T_PERM, "update", ["owner"], {"columns": ["department", "group_id"], "filter": {}, "check": {}})
    add(T_PERM, "delete", ["owner"], {"filter": {}})

    # --- announcements ---
    add(T_ANN, "select", STAFF_ROLES, {"columns": "*", "filter": {}})
    add(T_ANN, "select", other_roles, {"columns": "*", "filter": VISIBLE})
    add(T_ANN, "insert", ["owner"], {"columns": ANN_INSERT_COLS, "check": {}, "set": {"created_by": ME}})
    add(T_ANN, "insert", ["supervisor"], {"columns": ANN_INSERT_COLS, "check": {"group_id": {"_is_null": False}}, "set": {"created_by": ME}})
    add(T_ANN, "insert", other_roles, {"columns": ANN_INSERT_COLS, "check": LEADS, "set": {"created_by": ME}})
    add(T_ANN, "delete", STAFF_ROLES, {"filter": {}})
    add(T_ANN, "delete", other_roles, {"filter": MINE})

    # --- notifications (everyone sees only their own) ---
    own = {"user_id": {"_eq": ME}}
    add(T_NOTE, "select", everyone, {"columns": "*", "filter": own})
    add(T_NOTE, "update", everyone, {"columns": ["read_at"], "filter": own, "check": own})
    add(T_NOTE, "delete", everyone, {"filter": own})
    return out


def call(path, body, ok_errors=()):
    req = urllib.request.Request(
        URL + path,
        data=json.dumps(body).encode(),
        headers={
            "Content-Type": "application/json",
            "X-Hasura-Admin-Secret": SECRET,
            # Cloudflare blocks the default Python-urllib user agent (error 1010).
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) ccf-admin-script/1.0",
            "Accept": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read() or b"null")
    except urllib.error.HTTPError as e:
        text = e.read().decode(errors="replace")
        try:
            err = json.loads(text)
        except ValueError:
            err = {"error": text}
        code = err.get("code", "")
        if code in ok_errors or any(s in text for s in ok_errors):
            return None
        raise SystemExit(f"\nHasura error on {body.get('type')}: {text}")


def meta(type_, args, ok_errors=()):
    if DRY:
        print(f"  [dry-run] {type_} {json.dumps(args)[:160]}")
        return None
    return call("/v1/metadata", {"type": type_, "args": args}, ok_errors)


def main():
    if not SECRET:
        raise SystemExit("Set HASURA_ADMIN_SECRET first (see the top of this file).")

    print(f"Hasura: {URL}")
    md = call("/v1/metadata", {"type": "export_metadata", "args": {}})
    source = None
    roles = set()
    for s in md.get("sources", []):
        for t in s.get("tables", []):
            if t["table"].get("name") == "profiles":
                source = s["name"]
            for key in ("select_permissions", "insert_permissions", "update_permissions", "delete_permissions"):
                for p in t.get(key, []):
                    roles.add(p["role"])
    if source is None:
        raise SystemExit("Couldn't find the database that has the profiles table.")
    other_roles = sorted((roles | set(DEFAULT_OTHER_ROLES)) - set(STAFF_ROLES) - {"admin"})
    print(f"Database source: {source}")
    print(f"Roles: staff={STAFF_ROLES} others={other_roles}")

    # 1. SQL, in order: 004 replaces functions that 003 defines.
    if not SKIP_SQL:
        print("\n1. Running SQL")
        for name in SQL_FILES:
            sql = open(os.path.join(HERE, name), encoding="utf-8").read()
            if DRY:
                print(f"  [dry-run] run_sql {name}")
            else:
                call("/v2/query", {"type": "run_sql", "args": {"source": source, "sql": sql, "cascade": False}})
                print(f"  {name}")

    # 2. Track tables
    print("\n2. Tracking tables")
    for t in TABLES:
        meta("pg_track_table", {"source": source, "table": {"schema": "public", "name": t}},
             ok_errors=("already-tracked", "already-exists", "already tracked"))
        print(f"  {t}")

    # 3. Relationships
    print("\n3. Relationships")
    for table, name, kind, using in RELATIONSHIPS:
        meta(f"pg_create_{kind}_relationship",
             {"source": source, "table": {"schema": "public", "name": table}, "name": name, "using": using},
             ok_errors=("already-exists", "already exists"))
        print(f"  {table}.{name}")

    # 4. Permissions: drop then create, so they match exactly.
    print("\n4. Permissions")
    for table, op, role, perm in permissions(other_roles):
        tbl = {"schema": "public", "name": table}
        meta(f"pg_drop_{op}_permission", {"source": source, "table": tbl, "role": role},
             ok_errors=("",))  # missing permission is fine
        meta(f"pg_create_{op}_permission", {"source": source, "table": tbl, "role": role, "permission": perm})
    print(f"  {len(permissions(other_roles))} permissions set")

    # 5. events.rsvp_enabled: add to every existing events select permission
    #    that lists columns explicitly. Filters and other settings are kept.
    print("\n5. events.rsvp_enabled")
    for s in md.get("sources", []):
        if s["name"] != source:
            continue
        for t in s.get("tables", []):
            if t["table"].get("name") != "events" or t["table"].get("schema", "public") != "public":
                continue
            for p in t.get("select_permissions", []):
                perm = p["permission"]
                cols = perm.get("columns")
                if cols == "*" or (isinstance(cols, list) and "rsvp_enabled" in cols):
                    print(f"  {p['role']}: already has it")
                    continue
                perm = dict(perm, columns=list(cols or []) + ["rsvp_enabled"])
                tbl = {"schema": "public", "name": "events"}
                meta("pg_drop_select_permission", {"source": source, "table": tbl, "role": p["role"]})
                meta("pg_create_select_permission",
                     {"source": source, "table": tbl, "role": p["role"], "permission": perm})
                print(f"  {p['role']}: added")

    print("\nAll done. Pull to refresh the Events tab in the app.")


if __name__ == "__main__":
    main()
