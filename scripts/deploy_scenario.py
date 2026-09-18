#!/usr/bin/env python3
"""
deploy_scenario.py - the ONE sanctioned way to put regression test data in place.

Enforces the regression-data rules (owner decision 2026-09-18):
  * We NEVER update/reseed records. Data enters only via the committed insert
    script (scripts/insert_regression_test_data.py), which is the source of truth.
  * Each distinct data version is a WRITE-ONCE, timestamp-named scenario
    (RegressionTestYYMMDDHHMM). You reuse the current scenario run-after-run with
    a NEW PREFIX; you only mint a new scenario when the data actually changes.
  * Before minting a new scenario this tool checks the seed actually changed
    (sha256 of the insert script). If it didn't, it tells you to keep using the
    current scenario with a new prefix - it does NOT create a redundant one.
  * After the insert it VERIFIES there are zero duplicate rows in the new
    scenario. Any duplicate is a hard failure and the current-scenario pointer is
    NOT advanced.

The current scenario + the seed hash live in git (scripts/regression_scenario.json)
- no database metadata is updated, nothing existing is touched.

Usage:
  python scripts/deploy_scenario.py                 # deploy to local if seed changed
  python scripts/deploy_scenario.py --force         # deploy even if seed unchanged
  python scripts/deploy_scenario.py --target atp    # deploy to ATP (gold)
  python scripts/deploy_scenario.py --check-only     # just report current scenario / drift
"""
import argparse, hashlib, json, os, re, subprocess, sys
from datetime import datetime
from pathlib import Path
import oracledb

REPO   = Path(__file__).resolve().parents[1]
WS     = Path.home() / "workspace"
SEED   = REPO / "scripts" / "insert_regression_test_data.py"
STATE  = REPO / "scripts" / "regression_scenario.json"

def conn_for(target):
    if target == "local":
        return "dmt_owner/DmtLocal#2026@localhost:1523/FREEPDB1", {}
    cfg = json.loads((WS / "connections.json").read_text())["atp_queryapp"]
    pw = cfg["schemas"]["DMT2_OWNER"]["password"]
    kw = {"config_dir": cfg["wallet_dir"], "wallet_location": cfg["wallet_dir"],
          "wallet_password": cfg["wallet_password"]}
    return f"DMT2_OWNER/{pw}@{cfg['dsn']}", kw

def connect(target):
    cs, kw = conn_for(target)
    u, p, dsn = re.match(r'^([^/]+)/(.+)@(?://)?(.+)$', cs).groups()
    return oracledb.connect(user=u, password=p, dsn=dsn, **kw)

def seed_sha():
    return hashlib.sha256(SEED.read_bytes()).hexdigest()

def load_state():
    return json.loads(STATE.read_text()) if STATE.exists() else {}

def verify_no_duplicates(con, scenario_id):
    """For every STG table with rows in this scenario, fail if any business-key
    group has >1 row. Business key = all columns except the identity STG_SEQUENCE_ID
    and audit columns; CLOB/BLOB columns are excluded (can't GROUP BY a LOB)."""
    cur = con.cursor()
    cur.execute("""SELECT table_name FROM user_tab_columns
                   WHERE column_name='SCENARIO_ID' AND table_name LIKE '%\\_STG\\_TBL' ESCAPE '\\'
                   GROUP BY table_name ORDER BY table_name""")
    tables = [r[0] for r in cur.fetchall()]
    problems = []
    for t in tables:
        cur.execute("SELECT COUNT(*) FROM " + t + " WHERE scenario_id=:s", [scenario_id])
        if cur.fetchone()[0] == 0:
            continue
        cur.execute("""SELECT column_name FROM user_tab_columns
                       WHERE table_name=:t AND data_type NOT IN ('CLOB','BLOB','NCLOB')
                       AND column_name NOT IN ('STG_SEQUENCE_ID','CREATED_DATE',
                            'LAST_UPDATED_DATE','STAGE_DATE','CREATED_BY','LAST_UPDATED_BY')
                       ORDER BY column_id""", {"t": t})
        cols = ",".join(r[0] for r in cur.fetchall())
        cur.execute(f"SELECT COUNT(*) FROM (SELECT {cols} FROM {t} "
                    f"WHERE scenario_id=:s GROUP BY {cols} HAVING COUNT(*)>1)", [scenario_id])
        dup_groups = cur.fetchone()[0]
        if dup_groups:
            cur.execute(f"SELECT COUNT(*) FROM {t} WHERE scenario_id=:s", [scenario_id])
            problems.append((t, dup_groups, cur.fetchone()[0]))
    return problems

def main():
    ap = argparse.ArgumentParser(description="Deploy a write-once regression scenario")
    ap.add_argument("--target", default="local", choices=["local", "atp"])
    ap.add_argument("--force", action="store_true", help="deploy even if the seed is unchanged")
    ap.add_argument("--check-only", action="store_true")
    a = ap.parse_args()

    sha = seed_sha()
    state = load_state()
    cur_scn = state.get("current_scenario")
    print(f"seed sha256 : {sha[:16]}...")
    print(f"current     : {cur_scn or '(none)'}  (seed {state.get('seed_sha256','?')[:16]}...)")

    if a.check_only:
        return 0

    if cur_scn and sha == state.get("seed_sha256") and not a.force:
        print(f"\nNo seed change. KEEP USING '{cur_scn}' with a NEW PREFIX. "
              f"(Use --force to redeploy anyway.)")
        return 0

    new_name = "RegressionTest" + datetime.now().strftime("%y%m%d%H%M")
    print(f"\nSeed changed (or --force). Deploying write-once scenario: {new_name}  -> {a.target}")

    # 1) run the committed insert script into the fresh, named scenario
    cs, _ = conn_for(a.target)
    env = dict(os.environ, DMT2_CONN=cs, DMT_SCENARIO_NAME=new_name)
    if a.target == "atp":
        w = json.loads((WS / "connections.json").read_text())["atp_queryapp"]
        env["DMT2_WALLET"] = w["wallet_dir"]; env["DMT2_WALLET_PW"] = w["wallet_password"]
    rc = subprocess.run([sys.executable, str(SEED)], env=env).returncode
    if rc != 0:
        sys.exit(f"Insert script failed (rc={rc}); scenario NOT registered.")

    # 2) verify no duplicates in the new scenario
    con = connect(a.target); cur = con.cursor()
    cur.execute("SELECT scenario_id FROM dmt_scenario_tbl WHERE scenario_name=:n", [new_name])
    row = cur.fetchone()
    if not row:
        sys.exit("Scenario was not created; aborting.")
    sid = row[0]
    problems = verify_no_duplicates(con, sid)
    if problems:
        print("\nDUPLICATE ROWS FOUND - scenario REJECTED, pointer NOT advanced:")
        for t, g, n in problems:
            print(f"  {t}: {g} duplicated key group(s) across {n} rows")
        sys.exit("Duplicate check FAILED.")
    print(f"\nVerified: 0 duplicate rows across all staging tables in {new_name} (id {sid}).")

    # 3) advance the git-tracked pointer (no DB record is updated)
    STATE.write_text(json.dumps(
        {"current_scenario": new_name, "scenario_id": sid, "seed_sha256": sha,
         "target": a.target, "created": datetime.now().strftime("%Y-%m-%d %H:%M")}, indent=2))
    print(f"Pointer updated: current_scenario = {new_name}. "
          f"Run the regression with --scenario {new_name}.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
