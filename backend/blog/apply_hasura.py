"""
Blog: owner replies to comments — one-command Hasura setup.

1. Runs 001_comment_replies.sql (adds blog_comments.parent_id and the trigger
   that only lets owners reply).
2. Adds `parent_id` to every blog_comments SELECT permission that lists
   columns, so everyone can see which comments are replies.
3. Adds `parent_id` to the blog_comments INSERT permission of the `owner` role
   only. Other roles can't set it, so they can only post top-level comments.
   (The database trigger enforces this too.)
4. Runs 002_edit_delete_replies.sql (edited_at + edit/delete guards), adds
   `edited_at` to every SELECT permission, and lets the `owner` role UPDATE
   (`content` only) and DELETE replies. Any existing owner update/delete
   access is kept; replies are added to it with an OR.

Filters, presets and other settings of existing permissions are kept.

Usage (PowerShell). The admin secret stays in your terminal:

    $env:HASURA_ADMIN_SECRET = "<your admin secret>"
    python backend/blog/apply_hasura.py            # apply
    python backend/blog/apply_hasura.py --dry-run  # only print the plan

Optional: $env:HASURA_URL (default https://api.ccfapp.com). Safe to run again.
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

TABLE = "blog_comments"
REPLY_ROLES = {"owner"}
SQL_FILES = ["001_comment_replies.sql", "002_edit_delete_replies.sql"]
IS_REPLY = {"parent_id": {"_is_null": False}}


def call(path, body):
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
        raise SystemExit(f"\nHasura error on {body.get('type')}: {e.read().decode(errors='replace')}")


def meta(type_, args):
    if DRY:
        print(f"  [dry-run] {type_} {json.dumps(args)[:160]}")
        return None
    return call("/v1/metadata", {"type": type_, "args": args})


def replace_permission(source, op, role, perm):
    tbl = {"schema": "public", "name": TABLE}
    meta(f"pg_drop_{op}_permission", {"source": source, "table": tbl, "role": role})
    meta(f"pg_create_{op}_permission", {"source": source, "table": tbl, "role": role, "permission": perm})


def with_columns(perm, wanted):
    """Returns the permission with `wanted` columns added, or None if already allowed."""
    cols = perm.get("columns")
    if cols == "*":
        return None
    missing = [c for c in wanted if c not in (cols or [])]
    if not missing:
        return None
    return dict(perm, columns=list(cols or []) + missing)


def with_parent_id(perm):
    return with_columns(perm, ["parent_id"])


def or_replies(filter_):
    """Widens a row filter so it also matches replies. None if it already does."""
    if not filter_ or filter_ == IS_REPLY:
        return None  # {} already matches every row
    if IS_REPLY in filter_.get("_or", []):
        return None
    return {"_or": [filter_, IS_REPLY]}


def owner_permission(table_md, op):
    for p in table_md.get(f"{op}_permissions", []):
        if p["role"] == "owner":
            return p["permission"]
    return None


def main():
    if not SECRET:
        raise SystemExit("Set HASURA_ADMIN_SECRET first (see the top of this file).")

    print(f"Hasura: {URL}")
    md = call("/v1/metadata", {"type": "export_metadata", "args": {}})
    source, table_md = None, None
    for s in md.get("sources", []):
        for t in s.get("tables", []):
            if t["table"].get("name") == TABLE and t["table"].get("schema", "public") == "public":
                source, table_md = s["name"], t
    if table_md is None:
        raise SystemExit(f"Couldn't find the tracked table public.{TABLE}.")
    print(f"Database source: {source}")

    print("\n1. Running SQL")
    for name in SQL_FILES:
        sql = open(os.path.join(HERE, name), encoding="utf-8").read()
        if DRY:
            print(f"  [dry-run] run_sql {name}")
        else:
            call("/v2/query", {"type": "run_sql", "args": {"source": source, "sql": sql, "cascade": False}})
            print(f"  {name}")

    print("\n2. Select permissions (everyone sees parent_id and edited_at)")
    for p in table_md.get("select_permissions", []):
        perm = with_columns(p["permission"], ["parent_id", "edited_at"])
        if perm is None:
            print(f"  {p['role']}: already has them")
            continue
        replace_permission(source, "select", p["role"], perm)
        print(f"  {p['role']}: added")

    print("\n3. Insert permissions (only owners may set parent_id)")
    owner_done = False
    for p in table_md.get("insert_permissions", []):
        role = p["role"]
        if role in REPLY_ROLES:
            owner_done = True
            perm = with_parent_id(p["permission"])
            if perm is None:
                print(f"  {role}: already has it")
            else:
                replace_permission(source, "insert", role, perm)
                print(f"  {role}: added")
        elif p["permission"].get("columns") == "*":
            print(f"  WARNING {role}: insert allows all columns, so it could set parent_id."
                  " The database trigger still blocks non-owner replies.")
    if not owner_done:
        print("  WARNING: the owner role has no insert permission on blog_comments."
              " Add one in the Hasura console (include parent_id), then run this again.")

    print("\n4. Owner can edit and delete replies")
    upd = owner_permission(table_md, "update")
    if upd is None:
        upd_new = {"columns": ["content"], "filter": IS_REPLY, "check": {}}
    else:
        filt = or_replies(upd.get("filter", {}))
        cols = with_columns(upd, ["content"])
        if filt is None and cols is None:
            upd_new = None
        else:
            upd_new = dict(cols or upd)
            if filt is not None:
                upd_new["filter"] = filt
    if upd_new is None:
        print("  update: already allowed")
    else:
        replace_permission(source, "update", "owner", upd_new)
        print("  update: set")

    dele = owner_permission(table_md, "delete")
    if dele is None:
        del_new = {"filter": IS_REPLY}
    else:
        filt = or_replies(dele.get("filter", {}))
        del_new = None if filt is None else dict(dele, filter=filt)
    if del_new is None:
        print("  delete: already allowed")
    else:
        replace_permission(source, "delete", "owner", del_new)
        print("  delete: set")

    print("\nAll done. Reopen the blog post in the app.")


if __name__ == "__main__":
    main()
