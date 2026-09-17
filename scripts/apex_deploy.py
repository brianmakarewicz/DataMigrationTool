#!/usr/bin/env python3
"""
apex_deploy.py - Git-first APEX deploy for the DMT2 Data Migration Console (app 500).

Treats the split export under apex/f500/ as the single source of truth (exactly
like db/ for the database). You NEVER edit an instance directly and hope it
matches git; you import the committed export into the target.

Workflow this enforces:
  1. Make app changes in the LOCAL (TEST) instance.
  2. Re-export:   python scripts/apex_deploy.py export --target local
  3. Commit + PR the apex/f500/ diff.
  4. On merge, promote to ATP (gold):
                  python scripts/apex_deploy.py import --target atp

Connections come from ~/workspace/connections.json (never hardcode creds).
SQLcl (+ JDK 21) must be on PATH; TNS_ADMIN is set from the wallet for ATP.

Usage:
  python scripts/apex_deploy.py export --target atp     # refresh git baseline from ATP
  python scripts/apex_deploy.py export --target local   # capture local TEST state
  python scripts/apex_deploy.py import --target local   # deploy git -> local TEST
  python scripts/apex_deploy.py import --target atp      # promote git -> ATP gold

This is a thin SQLcl wrapper (a dev/ops shim), not pipeline logic.
"""
import argparse, json, os, subprocess, sys, tempfile
from pathlib import Path

REPO   = Path(__file__).resolve().parents[1]
APPID  = 500
SPLIT  = REPO / "apex" / f"f{APPID}"
CONN   = Path.home() / "workspace" / "connections.json"

# Target -> (schema, dsn-key or literal dsn, wallet-needed)
TARGETS = {
    # ATP gold: DMT2_OWNER parses app 500 in workspace DMT2 on the queryapp ATP.
    "atp":   {"instance": "atp_queryapp", "schema": "DMT2_OWNER"},
    # Local TEST: Oracle Free Docker on 1523. Requires APEX + a DMT2 workspace
    # to exist locally (one-time setup) before import will succeed.
    "local": {"dsn": "//localhost:1523/FREEPDB1", "schema": "DMT_OWNER"},
}


def _cfg():
    return json.loads(CONN.read_text())


def _resolve(target):
    """Return (schema, password, dsn, tns_admin_or_None) for the target."""
    t = TARGETS[target]
    cfg = _cfg()
    if target == "atp":
        q = cfg["atp_queryapp"]
        schema = t["schema"]
        pw = q["schemas"][schema]["password"]
        return schema, pw, q["dsn"], q["wallet_dir"]
    # local
    # local password lives under a local block if present; fall back to the
    # documented Docker dev password.
    schema = t["schema"]
    pw = (cfg.get("dmt2_local", {}) or {}).get("schemas", {}).get(schema, {}).get(
        "password", "DmtLocal#2026")
    return schema, pw, t["dsn"], None


def _sqlcl(schema, pw, dsn, tns_admin, script):
    env = dict(os.environ)
    if tns_admin:
        env["TNS_ADMIN"] = tns_admin
    cmd = ["sql", "-s", f"{schema}/{pw}@{dsn}"]
    p = subprocess.run(cmd, input=script, capture_output=True, text=True, env=env)
    sys.stdout.write(p.stdout)
    if p.stderr.strip():
        sys.stderr.write(p.stderr)
    return p.returncode, p.stdout


def do_export(target):
    schema, pw, dsn, tns = _resolve(target)
    # Export straight into apex/f500 (split). Clear the old tree first so deletes
    # of removed pages/components show up as git deletions.
    staging = REPO / "apex" / f"_export_{target}"
    if staging.exists():
        for f in sorted(staging.rglob("*"), reverse=True):
            f.unlink() if f.is_file() else f.rmdir()
    staging.mkdir(parents=True, exist_ok=True)
    script = f"apex export -applicationid {APPID} -split -dir {staging.as_posix()}\nexit\n"
    rc, out = _sqlcl(schema, pw, dsn, tns, script)
    if rc != 0 or not (staging / f"f{APPID}" / "install.sql").exists():
        print(f"[apex_deploy] export FAILED from {target}", file=sys.stderr)
        return 2
    print(f"[apex_deploy] exported app {APPID} from {target} -> {staging}")
    print("[apex_deploy] review, then replace apex/f500 with the new tree and commit.")
    return 0


def do_import(target):
    schema, pw, dsn, tns = _resolve(target)
    installer = SPLIT / "install.sql"
    if not installer.exists():
        print(f"[apex_deploy] missing {installer}; nothing to import", file=sys.stderr)
        return 2
    script = f"@{installer.as_posix()}\nexit\n"
    rc, out = _sqlcl(schema, pw, dsn, tns, script)
    ok = rc == 0 and "ORA-" not in out
    print(f"[apex_deploy] import to {target}: {'OK' if ok else 'FAILED'}")
    return 0 if ok else 2


def main():
    ap = argparse.ArgumentParser(description="Git-first APEX deploy for DMT2 app 500")
    ap.add_argument("action", choices=["export", "import"])
    ap.add_argument("--target", required=True, choices=list(TARGETS))
    a = ap.parse_args()
    return do_export(a.target) if a.action == "export" else do_import(a.target)


if __name__ == "__main__":
    sys.exit(main())
