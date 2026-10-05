#!/usr/bin/env python
"""
dmt_apex_url_target.py — the single URL knob for all DMT2 APEX verification.

Every page/link verification tool in this repo (the HTTP smoke sweep in
scripts/dmt_apex_smoke.py and the Playwright browser drill in
test/playwright/) resolves its target through this one helper, so pointing
the whole suite at a different environment is a single URL find-and-replace.

A "target" is fully described by ONE base ORDS URL plus the app id and the
friendly-URL app path (alias):

    base_url   e.g. http://localhost:8182/ords   (NO trailing /r/..., just /ords)
    app_id     e.g. 501
    app_path   e.g. r/dmt/livedmt2                (workspace-path/app-alias)

Everything else (the APEX workspace name and the DB schema used only for the
metadata/activity-log queries in the HTTP smoke) is DERIVED from the base URL
by matching connections.json, never special-cased by instance or app NAME.
Switch environments by changing the base URL; the matching app id, alias,
workspace, schema and the DMT_SMOKE end-user credentials come along with it.

Default target: the LOCAL Docker console (app 501) at
    http://localhost:8182/ords/r/dmt/livedmt2/
with end-user login DMT_SMOKE, whose password lives in connections.json at
    local_docker.containers.dmt2-local.console
DMT_SMOKE is an end-user (NON-admin) account, so using it satisfies the
no-admin-login guard — never log in as DMTADMIN/DMT2_OWNER from automation.

Resolution order for every field (first hit wins):
    1. explicit CLI argument / function argument,
    2. environment variable (DMT2_UI_BASE, DMT2_UI_APPID, DMT2_UI_APP,
       DMT2_UI_USER, DMT2_UI_PASS, DMT2_WORKSPACE, DMT2_SCHEMA),
    3. the connections.json entry whose console/app_url matches the base URL,
    4. the built-in local-console default.

Credentials are NEVER hardcoded here — DMT_SMOKE's password is read from
connections.json (or $DMT2_UI_PASS). The password string does not appear in
this file or in any committed script.
"""
import json
import os
import re
import sys

CONNECTIONS = os.environ.get(
    "DMT2_CONNECTIONS", r"C:\Users\Monroe\workspace\connections.json")

# Built-in default: the local Docker console. Base URL is the ONE knob; the
# rest below is what that URL resolves to in connections.json today.
DEFAULT_BASE = "http://localhost:8182/ords"
DEFAULT_APP_ID = "501"
DEFAULT_APP_PATH = "r/dmt/livedmt2"
DEFAULT_WORKSPACE = "DMT"
DEFAULT_SCHEMA = "DMT_OWNER"
DEFAULT_SMOKE_USER = "DMT_SMOKE"


def _load_connections():
    try:
        with open(CONNECTIONS, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return {}


def _norm(url):
    """Normalise an ORDS base to '.../ords' with no trailing slash, dropping
    any friendly-URL tail (/r/workspace/app/...) and any /apex or /f?p tail."""
    if not url:
        return ""
    u = url.strip().rstrip("/")
    # cut everything from the first /r/ , /f? or /apex — keep the .../ords stem
    u = re.split(r"/(?:r/|f\?|apex\b)", u, maxsplit=1)[0]
    return u.rstrip("/")


def _iter_console_entries(conns):
    """Yield every console descriptor found anywhere in connections.json,
    regardless of nesting, so matching is URL-driven not path-driven."""
    def walk(node):
        if isinstance(node, dict):
            if "app_url" in node and ("app_id" in node or "app_alias" in node):
                yield node
            for v in node.values():
                yield from walk(v)
        elif isinstance(node, list):
            for v in node:
                yield from walk(v)
    yield from walk(conns)


def _match_console(base_url, conns):
    """Find the console entry whose app_url has the same ORDS stem as base_url."""
    want = _norm(base_url)
    for entry in _iter_console_entries(conns):
        if _norm(entry.get("app_url", "")) == want:
            return entry
    return None


def _smoke_password(console, user):
    """Resolve the end-user password for `user` from a matched console entry,
    else env $DMT2_UI_PASS. Never returns a hardcoded value."""
    if console:
        users = console.get("app_users", {}) or {}
        # case-insensitive match on the user name
        for name, info in users.items():
            if name.upper() == user.upper() and isinstance(info, dict):
                pw = info.get("password")
                if pw:
                    return pw
    return os.environ.get("DMT2_UI_PASS")


def _app_path_from_console(console):
    """Derive r/<workspace_path>/<alias> from a console entry's own fields,
    falling back to parsing its app_url."""
    if not console:
        return None
    wp = console.get("workspace_path")
    alias = console.get("app_alias")
    if wp and alias:
        return f"r/{wp.strip('/')}/{alias}".lower()
    url = console.get("app_url", "")
    m = re.search(r"/(r/[\w\-]+/[\w\-]+)", url)
    return m.group(1).lower() if m else None


def _workspace_from_path(app_path):
    # r/<workspace_path>/<alias> — the middle token is the workspace path,
    # which equals the APEX workspace name for these apps.
    parts = app_path.strip("/").split("/")
    if len(parts) >= 3 and parts[0] == "r":
        return parts[1].upper()
    return None


def resolve(base_url=None, app_id=None, app_path=None, user=None,
            password=None, workspace=None, schema=None):
    """Resolve a full target from a base URL (+ optional overrides).

    Returns a dict:
      base_url, app_id, app_path, login_url, fp_base,
      user, password, workspace, schema, source
    `source` says where the match came from (connections.json / default / env).
    """
    conns = _load_connections()

    base_url = base_url or os.environ.get("DMT2_UI_BASE") or DEFAULT_BASE
    base_url = _norm(base_url)

    console = _match_console(base_url, conns)
    source = "connections.json" if console else "default/env"

    app_id = (app_id or os.environ.get("DMT2_UI_APPID")
              or (console or {}).get("app_id") or DEFAULT_APP_ID)
    app_id = str(app_id)

    app_path = (app_path or os.environ.get("DMT2_UI_APP")
                or _app_path_from_console(console) or DEFAULT_APP_PATH)
    app_path = app_path.strip("/")

    workspace = (workspace or os.environ.get("DMT2_WORKSPACE")
                 or (console or {}).get("workspace")
                 or _workspace_from_path(app_path) or DEFAULT_WORKSPACE)

    schema = (schema or os.environ.get("DMT2_SCHEMA")
              or (console or {}).get("schema") or DEFAULT_SCHEMA)

    user = user or os.environ.get("DMT2_UI_USER") or DEFAULT_SMOKE_USER
    password = password or _smoke_password(console, user)

    return {
        "base_url": base_url,
        "app_id": app_id,
        "app_path": app_path,
        "login_url": f"{base_url}/{app_path}/login",
        "fp_base": f"{base_url}/f?p={app_id}",
        "user": user,
        "password": password,
        "workspace": workspace,
        "schema": schema,
        "source": source,
    }


if __name__ == "__main__":
    # Quick introspection: print the resolved target (password masked).
    t = resolve(base_url=sys.argv[1] if len(sys.argv) > 1 else None)
    shown = dict(t)
    shown["password"] = "<set>" if t["password"] else "<MISSING>"
    print(json.dumps(shown, indent=2))
