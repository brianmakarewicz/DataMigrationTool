#!/usr/bin/env python3
"""
apex_deploy.py - Git-first APEX deploy for the DMT2 Data Migration Console.

The app is version-controlled in APEXLang (.apx) source under
apex/f501src/livedmt2/ (an app "root" directory with application.apx,
pages/, shared-components/, page-groups.apx). That committed source is the
single source of truth, exactly like db/ is for the schema. You NEVER edit an
instance directly and hope it matches git; you import the committed source.

Two instances, one source:
  * LOCAL (dev/TEST) : app 501, workspace DMT,  schema DMT_OWNER,  Docker 1523.
  * ATP  (gold/prod) : app 500, workspace DMT2, schema DMT2_OWNER, queryapp ATP.
Both run APEX 26.1, so APEXLang import/export round-trips cleanly on both.

Stable friendly URL: every import re-points the ONE generic alias LIVEDMT2 to
the app it just imported (freeing it from any prior holder first), so
  LOCAL: http://localhost:8182/ords/r/dmt/livedmt2/
  ATP  : https://<atp-ords>/ords/r/dmt2/livedmt2/
never drift to a stale app or 404. Done via the sanctioned APEX admin API, not
raw wwv_flow_imp. See feedback_apex_stable_alias.

Workflow this enforces:
  1. Make app changes in the LOCAL (TEST) builder (app 501).
  2. Re-export:   python scripts/apex_deploy.py export --target local
     then sync the exported tree into apex/f501src/livedmt2/ and commit the diff.
  3. Commit + PR the apex/f501src/ diff (one file per page/component).
  4. On merge, promote to ATP gold (app 500):
                  python scripts/apex_deploy.py import --target atp

Connections come from ~/workspace/connections.json (never hardcode creds).
SQLcl (+ JDK 21) must be on PATH; TNS_ADMIN is set from the wallet for ATP.

Usage:
  python scripts/apex_deploy.py export --target atp     # refresh git baseline from ATP app 500
  python scripts/apex_deploy.py export --target local   # capture local TEST app 501
  python scripts/apex_deploy.py import --target local   # deploy git -> local TEST app 501
  python scripts/apex_deploy.py import --target atp      # promote git -> ATP gold app 500

This is a thin SQLcl wrapper (a dev/ops shim), not pipeline logic.

--- CRLF gotcha (handled automatically on import) ---
The committed .apx files are LF, but this Windows checkout has core.autocrlf=true
and there is no .gitattributes forcing LF, so the working-tree copies are CRLF.
SQLcl's APEXLang parser rejects CRLF and imports fail spuriously. Before every
import this script stages the source into a temp directory with .apx normalised
to LF (binary assets copied verbatim) and imports that staged copy. The
committed source under apex/f501src/ is never modified.
"""
import argparse, json, os, shutil, subprocess, sys, tempfile
from pathlib import Path

REPO   = Path(__file__).resolve().parents[1]
# APEXLang source "root" directory (contains application.apx, pages/, etc.).
SRC    = REPO / "apex" / "f501src" / "livedmt2"
CONN   = Path.home() / "workspace" / "connections.json"

# The ONE stable, generic friendly-URL alias for the DMT2 console. Every import
# re-points this alias to the app it just imported, so /ords/r/<ws>/livedmt2/
# always resolves to the current console regardless of app id. See the
# apex_stable_alias discipline (memory feedback_apex_stable_alias). Deliberately
# generic (no version/"Recon" suffix) so it never has to be repointed by hand.
STABLE_ALIAS = "LIVEDMT2"

# Target -> instance + the app id / workspace / schema that source imports as.
TARGETS = {
    # ATP gold: DMT2_OWNER owns app 500 in workspace DMT2 on the queryapp ATP.
    "atp":   {"instance": "atp", "app_id": 500, "workspace": "DMT2",
              "schema": "DMT2_OWNER"},
    # Local TEST: Oracle Free Docker on 1523, app 501 in workspace DMT.
    "local": {"instance": "local", "app_id": 501, "workspace": "DMT",
              "dsn": "//localhost:1523/FREEPDB1", "schema": "DMT_OWNER"},
}


def _cfg():
    return json.loads(CONN.read_text(encoding="utf-8"))


def _resolve(target):
    """Return (schema, password, dsn, tns_admin_or_None) for the target."""
    t = TARGETS[target]
    cfg = _cfg()
    if target == "atp":
        q = cfg["atp_queryapp"]
        schema = t["schema"]
        pw = q["schemas"][schema]["password"]
        return schema, pw, q["dsn"], q["wallet_dir"]
    # local: password lives under a local block if present; fall back to the
    # documented Docker dev password.
    schema = t["schema"]
    pw = (cfg.get("dmt2_local", {}) or {}).get("schemas", {}).get(schema, {}).get(
        "password", "DmtLocal#2026")
    return schema, pw, t["dsn"], None


def _win(path: Path) -> str:
    """Native path string for SQLcl. SQLcl mishandles POSIX-style paths on
    Windows (it writes to a bogus relative location), so hand it the OS-native
    form, e.g. C:\\Users\\...  ."""
    return os.fspath(path)


def _sqlcl(schema, pw, dsn, tns_admin, script):
    env = dict(os.environ)
    if tns_admin:
        env["TNS_ADMIN"] = tns_admin
    # Stop Git-Bash / MSYS from rewriting the "/nolog"-style tokens or DSN.
    env["MSYS_NO_PATHCONV"] = "1"
    cmd = ["sql", "-s", f"{schema}/{pw}@{dsn}"]
    p = subprocess.run(cmd, input=script, capture_output=True, text=True, env=env)
    sys.stdout.write(p.stdout)
    if p.stderr.strip():
        sys.stderr.write(p.stderr)
    return p.returncode, p.stdout


def _stage_lf(src: Path, dst: Path):
    """Copy the APEXLang source tree to dst, normalising every .apx to LF.
    Binary assets (images, json) are copied byte-for-byte. This exists solely
    to defeat the Windows CRLF checkout; the committed source is untouched."""
    for root, _dirs, files in os.walk(src):
        rel = Path(root).relative_to(src)
        out_dir = dst / rel
        out_dir.mkdir(parents=True, exist_ok=True)
        for name in files:
            s = Path(root) / name
            d = out_dir / name
            if name.endswith(".apx"):
                data = s.read_bytes().replace(b"\r\n", b"\n")
                d.write_bytes(data)
            else:
                shutil.copy2(s, d)


def do_export(target):
    t = TARGETS[target]
    schema, pw, dsn, tns = _resolve(target)
    app_id = t["app_id"]
    # Export APEXLang into a staging dir; the user then syncs it into
    # apex/f501src/livedmt2/ so removed pages show up as git deletions.
    staging = REPO / "apex" / f"_export_{target}"
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir(parents=True, exist_ok=True)
    script = (
        f"apex export -applicationid {app_id} -exptype APEXLANG "
        f"-dir {_win(staging)}\nexit\n"
    )
    rc, out = _sqlcl(schema, pw, dsn, tns, script)
    produced = list(staging.rglob("application.apx"))
    if rc != 0 or not produced:
        print(f"[apex_deploy] export FAILED from {target} (app {app_id})",
              file=sys.stderr)
        return 2
    app_root = produced[0].parent
    print(f"[apex_deploy] exported app {app_id} from {target} -> {app_root}")
    print("[apex_deploy] review, then sync the tree into "
          "apex/f501src/livedmt2/ and commit.")
    return 0


def _repoint_stable_alias(schema, pw, dsn, tns, workspace, app_id):
    """Make the imported app the sole holder of STABLE_ALIAS.

    An APEX alias must be unique within a workspace, so any OLD app still
    carrying STABLE_ALIAS would block the import (or strand the friendly URL on
    a stale app). This frees the alias from every other app first, then sets it
    on the app we just imported. Uses only the sanctioned APEX admin API
    (apex_application_admin.set_application_alias) inside the workspace security
    group -- never raw wwv_flow_imp (cowork_ui_only rule).

    Returns True on success. Any ORA-/error text in the output is treated as a
    failure so an import can never silently leave the stable URL pointing at
    nothing.
    """
    plsql = f"""set serveroutput on
DECLARE
  v_ws NUMBER;
BEGIN
  SELECT workspace_id INTO v_ws FROM apex_workspaces
   WHERE workspace = '{workspace}';
  apex_util.set_security_group_id(v_ws);
  -- 1. Free the stable alias from any OTHER app that still holds it.
  FOR r IN (SELECT application_id
              FROM apex_applications
             WHERE workspace_id = v_ws
               AND UPPER(alias) = '{STABLE_ALIAS}'
               AND application_id <> {app_id}) LOOP
    apex_application_admin.set_application_alias(
      r.application_id, 'FREED_' || r.application_id);
    dbms_output.put_line('freed ' || '{STABLE_ALIAS}' ||
                         ' from app ' || r.application_id);
  END LOOP;
  -- 2. Point the stable alias at the app we just imported (positional args:
  --    this APEX build's set_application_alias has no p_* named parameters).
  apex_application_admin.set_application_alias({app_id}, '{STABLE_ALIAS}');
  COMMIT;
  dbms_output.put_line('{STABLE_ALIAS} now on app ' || {app_id});
END;
/
exit
"""
    rc, out = _sqlcl(schema, pw, dsn, tns, plsql)
    ok = rc == 0 and "ORA-" not in out and "PLS-" not in out
    return ok


def do_import(target):
    t = TARGETS[target]
    schema, pw, dsn, tns = _resolve(target)
    app_id = t["app_id"]
    workspace = t["workspace"]
    app_file = SRC / "application.apx"
    if not app_file.exists():
        print(f"[apex_deploy] missing {app_file}; nothing to import",
              file=sys.stderr)
        return 2
    # Stage a CRLF-normalised copy so SQLcl's APEXLang parser accepts it.
    tmp = Path(tempfile.mkdtemp(prefix="apx_import_"))
    try:
        staged = tmp / "livedmt2"
        _stage_lf(SRC, staged)
        script = (
            f"apex import -input {_win(staged)} -id {app_id} "
            f"-workspace {workspace}\nexit\n"
        )
        rc, out = _sqlcl(schema, pw, dsn, tns, script)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    ok = rc == 0 and "ORA-" not in out and "APEXLANG-" not in out
    print(f"[apex_deploy] import to {target} (app {app_id}): "
          f"{'OK' if ok else 'FAILED'}")
    if not ok:
        return 2
    # Stable-alias discipline: EVERY import re-points the generic friendly-URL
    # alias to the app just imported, so /ords/r/<ws>/livedmt2/ never drifts.
    if _repoint_stable_alias(schema, pw, dsn, tns, workspace, app_id):
        print(f"[apex_deploy] {STABLE_ALIAS} -> app {app_id} on {target} "
              f"(/ords/r/{workspace.lower()}/{STABLE_ALIAS.lower()}/)")
        return 0
    print(f"[apex_deploy] WARNING: import OK but failed to set {STABLE_ALIAS} "
          f"alias on app {app_id} ({target})", file=sys.stderr)
    return 2


def main():
    ap = argparse.ArgumentParser(
        description="Git-first APEXLang deploy for the DMT2 console")
    ap.add_argument("action", choices=["export", "import"])
    ap.add_argument("--target", required=True, choices=list(TARGETS))
    a = ap.parse_args()
    return do_export(a.target) if a.action == "export" else do_import(a.target)


if __name__ == "__main__":
    sys.exit(main())
