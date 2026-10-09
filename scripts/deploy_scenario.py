#!/usr/bin/env python3
"""
deploy_scenario.py - the ONE sanctioned way to put regression test data in place.

Enforces the regression-data rules (owner decision 2026-09-18):
  * We NEVER update/reseed records. Data enters only via the committed insert
    script (scripts/insert_regression_test_data.py), which is the source of truth.
  * Each distinct data version is a WRITE-ONCE, timestamp-named scenario
    (RegressionTestYYMMDDHHMMSS). You reuse the current scenario run-after-run with
    a NEW PREFIX; you only mint a new scenario when the data actually changes.
  * Before minting a new scenario this tool checks the seed actually changed
    (sha256 of the insert script). If it didn't, it tells you to keep using the
    current scenario with a new prefix - it does NOT create a redundant one.
  * The new name must be brand new: if a scenario of that name already exists in
    the target database (or in the state file) the tool REFUSES before inserting
    anything, because the insert script's get-or-create would otherwise add a
    second seed to the existing scenario (scenario 601 held two seeds after two
    agents minted RegressionTest2610081849 in the same minute). Names carry
    seconds for the same reason.
  * REGISTER FIRST, THEN INSERT (owner decision 2026-10-09, backlog #652). The
    DMT_SCENARIO_TBL row is created and committed, and the scenario is recorded in
    the state file under "pending_scenarios" (status REGISTERED), BEFORE a single
    record is inserted. A connection that drops after the insert can therefore
    never leave an unregistered scenario: the name, id, seed hash and the flags it
    was minted with are already on disk. Finish such a scenario, without
    re-inserting, with --resume NAME (duplicate check, then the pointer update).
  * After the insert it VERIFIES there are zero duplicate rows in the new
    scenario. Any duplicate is a hard failure and the current-scenario pointer is
    NOT advanced (the pending entry is kept with status REJECTED_DUPLICATES; a
    failed insert leaves status INSERT_FAILED). Only a verified scenario leaves
    "pending_scenarios" and moves the pointer (or joins "minted_scenarios").

The current scenario + the seed hash live in git (scripts/regression_scenario.json)
- no database metadata is updated, nothing existing is touched.

Expected outcomes (backlog #506): a new scenario starts with a COPY of the
current scenario's "expected_outcomes" entry (or of --expect-from SCENARIO), so
intentionally BAD rows keep their expected verdict instead of reading as GOOD rows
that failed. An entry that already exists for the new name is never overwritten.

Per-object scenarios (backlog #507/#514): --keep-pointer mints and verifies the
scenario exactly as above but does NOT move the pointer (current_scenario,
scenario_id, seed_sha256, target, created stay as they were). The new scenario is
recorded under "minted_scenarios" with its id, seed hash and target, and gets its
expected-outcome copy. Use it when proving one object; the default (no flag) is
the owner's flow and always advances the pointer.

Usage:
  python scripts/deploy_scenario.py                 # deploy to local if seed changed
  python scripts/deploy_scenario.py --force         # deploy even if seed unchanged
  python scripts/deploy_scenario.py --target atp    # deploy to ATP (gold)
  python scripts/deploy_scenario.py --check-only     # just report current scenario / drift
  python scripts/deploy_scenario.py --keep-pointer  # per-object scenario; pointer unchanged
  python scripts/deploy_scenario.py --resume RegressionTestYYMMDDHHMMSS
                                                    # finish a registered scenario whose
                                                    # run stopped after the insert
"""
import argparse, copy, hashlib, json, os, re, subprocess, sys
from datetime import datetime
from pathlib import Path
import oracledb

REPO   = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "scripts"))
WS     = Path.home() / "workspace"
SEED   = REPO / "scripts" / "insert_regression_test_data.py"
STATE  = REPO / "scripts" / "regression_scenario.json"

def conn_for(target):
    if target == "local":
        return "dmt_owner/DmtLocal#2026@localhost:1523/FREEPDB1", {}
    cfg = json.loads((WS / "connections.json").read_text(encoding="utf-8"))["atp_queryapp"]
    pw = cfg["schemas"]["DMT2_OWNER"]["password"]
    kw = {"config_dir": cfg["wallet_dir"], "wallet_location": cfg["wallet_dir"],
          "wallet_password": cfg["wallet_password"]}
    return f"DMT2_OWNER/{pw}@{cfg['dsn']}", kw

def connect(target):
    """Bounded, retried connect (scripts/dmt_db_connect.py): a dropped or stalled
    connection is retried with backoff instead of killing the mint (#652)."""
    from dmt_db_connect import connect_with_retry
    cs, kw = conn_for(target)
    u, p, dsn = re.match(r'^([^/]+)/(.+)@(?://)?(.+)$', cs).groups()
    return connect_with_retry(call_timeout_ms=600_000, user=u, password=p, dsn=dsn, **kw)

def seed_sha():
    return hashlib.sha256(SEED.read_bytes()).hexdigest()

def load_state():
    return json.loads(STATE.read_text(encoding="utf-8")) if STATE.exists() else {}

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

def new_scenario_name(now):
    """RegressionTestYYMMDDHHMMSS - seconds included so two mints in the same
    minute never share a name."""
    return "RegressionTest" + now.strftime("%y%m%d%H%M%S")

def name_clash(state, name):
    """True when the state file already knows this scenario name."""
    return (name == state.get("current_scenario")
            or name in (state.get("expected_outcomes") or {})
            or name in (state.get("minted_scenarios") or {})
            or name in (state.get("pending_scenarios") or {}))

def save_state(state):
    """Write the state file atomically (temp file + replace), so a crash mid-write
    can never leave a truncated registry."""
    tmp = STATE.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(state, indent=2), encoding="utf-8")
    os.replace(tmp, STATE)

def create_scenario_row(con, name):
    """Create the DMT_SCENARIO_TBL row for a brand-new name through the same
    procedure the insert script uses (DMT_UTIL_PKG.GET_OR_CREATE_SCENARIO), COMMIT
    it, and return its id. Called BEFORE any record is inserted. Refuses when the
    scenario already holds staging rows (another creator won a race for the name)."""
    import oracledb as _odb
    cur = con.cursor()
    sid_v = cur.var(_odb.NUMBER)
    err_v = cur.var(_odb.NUMBER)
    cur.execute("""BEGIN
                     DMT_UTIL_PKG.GET_OR_CREATE_SCENARIO(
                       p_scenario_name => :n, x_scenario_id => :sid, x_error_code => :err);
                   END;""", n=name, sid=sid_v, err=err_v)
    one = lambda v: v[0] if isinstance(v, list) else v
    err = one(err_v.getvalue())
    if err is None or int(err) != 0:
        raise RuntimeError(f"GET_OR_CREATE_SCENARIO failed for {name} (x_error_code={err})")
    con.commit()
    sid = int(one(sid_v.getvalue()))
    rows = stg_row_counts(con, sid)
    if rows:
        raise RuntimeError(f"scenario {name} (id {sid}) already holds staging rows "
                           f"({sum(rows.values())}); another creator used this name")
    return sid

def stg_row_counts(con, scenario_id):
    """{STG table: row count} for every staging table holding rows of the scenario."""
    cur = con.cursor()
    cur.execute("""SELECT table_name FROM user_tab_columns
                   WHERE column_name='SCENARIO_ID' AND table_name LIKE '%\\_STG\\_TBL' ESCAPE '\\'
                   GROUP BY table_name ORDER BY table_name""")
    counts = {}
    for (t,) in cur.fetchall():
        cur.execute("SELECT COUNT(*) FROM " + t + " WHERE scenario_id=:s", [scenario_id])
        n = cur.fetchone()[0]
        if n:
            counts[t] = n
    return counts

def register_pending(state, new_name, sid, sha, target, created,
                     keep_pointer=False, expect_from=None):
    """Step 1 of a mint (pure): record the just-created scenario under
    "pending_scenarios" with status REGISTERED, BEFORE any record is inserted.
    The pointer, minted_scenarios and expected_outcomes are untouched until the
    scenario is verified (finalize_scenario). The flags it was minted with are
    kept so --resume finishes it exactly as the original run would have."""
    new_state = copy.deepcopy(state)
    pend = new_state.setdefault("pending_scenarios", {})
    pend[new_name] = {"scenario_id": sid, "seed_sha256": sha, "target": target,
                      "created": created, "keep_pointer": bool(keep_pointer),
                      "expect_from": expect_from, "status": "REGISTERED"}
    return new_state

def mark_pending(state, name, status):
    """Pure: set a pending scenario's status (INSERT_FAILED, REJECTED_DUPLICATES).
    The entry stays, so the name is never reused (write-once)."""
    new_state = copy.deepcopy(state)
    new_state["pending_scenarios"][name]["status"] = status
    return new_state

def finalize_scenario(state, name):
    """Step 2 of a mint (pure), only after the insert and the duplicate check
    passed: remove the pending entry and register the scenario for good, exactly
    as before (pointer move, or minted_scenarios with --keep-pointer, plus the
    expected-outcome carry-over). Returns (new_state, copied_from)."""
    base = copy.deepcopy(state)
    entry = base["pending_scenarios"].pop(name)
    if not base["pending_scenarios"]:
        base.pop("pending_scenarios")
    return register_scenario(base, name, entry["scenario_id"], entry["seed_sha256"],
                             entry["target"], entry["created"],
                             keep_pointer=entry.get("keep_pointer", False),
                             expect_from=entry.get("expect_from"))

def scenario_exists(con, name):
    cur = con.cursor()
    cur.execute("SELECT COUNT(*) FROM dmt_scenario_tbl WHERE scenario_name = :n", [name])
    return cur.fetchone()[0] > 0

POINTER_KEYS = ("current_scenario", "scenario_id", "seed_sha256", "target", "created")

def register_scenario(state, new_name, sid, sha, target, created,
                      keep_pointer=False, expect_from=None):
    """Return (new_state, copied_from) for a freshly minted, verified scenario.

    Pure (no I/O) so the unit test can prove it. Every key of the old state is
    kept. Default: the pointer keys move to the new scenario. keep_pointer: the
    pointer keys are left exactly as they were and the scenario is recorded under
    "minted_scenarios" instead. Either way the new scenario's expected outcomes
    start as a deep copy of expect_from (default: the current scenario), unless
    the new name already has an entry, which is never overwritten.
    copied_from is the source scenario name, or None when nothing was copied."""
    new_state = copy.deepcopy(state)
    if keep_pointer:
        minted = new_state.setdefault("minted_scenarios", {})
        minted[new_name] = {"scenario_id": sid, "seed_sha256": sha,
                            "target": target, "created": created}
    else:
        for k in POINTER_KEYS:
            new_state.pop(k, None)
        pointer = {"current_scenario": new_name, "scenario_id": sid,
                   "seed_sha256": sha, "target": target, "created": created}
        # pointer keys first, the rest of the state after, as the file always read
        new_state = {**pointer, **new_state}

    source = expect_from or state.get("current_scenario")
    outcomes = new_state.get("expected_outcomes") or {}
    copied_from = None
    if new_name not in outcomes and source and outcomes.get(source):
        outcomes[new_name] = copy.deepcopy(outcomes[source])
        new_state["expected_outcomes"] = outcomes
        copied_from = source
    return new_state, copied_from

def main():
    ap = argparse.ArgumentParser(description="Deploy a write-once regression scenario")
    ap.add_argument("--target", default="local", choices=["local", "atp"])
    ap.add_argument("--force", action="store_true", help="deploy even if the seed is unchanged")
    ap.add_argument("--check-only", action="store_true")
    ap.add_argument("--keep-pointer", action="store_true",
                    help="mint a per-object scenario without moving current_scenario")
    ap.add_argument("--expect-from", metavar="SCENARIO",
                    help="copy expected outcomes from this scenario "
                         "(default: the current scenario)")
    ap.add_argument("--resume", metavar="SCENARIO",
                    help="finish a REGISTERED scenario whose run stopped after the insert "
                         "(duplicate check + pointer update; nothing is re-inserted)")
    a = ap.parse_args()
    if a.resume:
        state = load_state()
        entry = (state.get("pending_scenarios") or {}).get(a.resume)
        if not entry:
            sys.exit(f"--resume {a.resume}: not a pending scenario in {STATE.name}.")
        if entry.get("status") != "REGISTERED":
            sys.exit(f"--resume {a.resume}: status is {entry.get('status')}, not REGISTERED; "
                     f"it is never reused (write-once). Mint a new scenario.")
        print(f"Resuming {a.resume} (id {entry['scenario_id']}, target {entry['target']}); "
              f"nothing will be inserted.")
        return verify_and_finalize(state, a.resume, state.get("current_scenario"))
    if a.expect_from and a.expect_from not in (load_state().get("expected_outcomes") or {}):
        sys.exit(f"--expect-from {a.expect_from}: no expected outcomes recorded for it.")

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

    new_name = new_scenario_name(datetime.now())
    clash = name_clash(state, new_name)
    if not clash:
        chk = connect(a.target)
        clash = scenario_exists(chk, new_name)
        chk.close()
    if clash:
        sys.exit(f"Scenario name {new_name} already exists; REFUSING to reuse it "
                 f"(write-once). Wait a second and run again.")
    print(f"\nSeed changed (or --force). Deploying write-once scenario: {new_name}  -> {a.target}")

    # 1) REGISTER FIRST (owner decision 2026-10-09): create + commit the
    # DMT_SCENARIO_TBL row and record the scenario in the state file as
    # REGISTERED before a single record is inserted.
    con = connect(a.target)
    try:
        sid = create_scenario_row(con, new_name)
    except RuntimeError as e:
        sys.exit(f"Could not register {new_name}: {e}. Nothing inserted.")
    finally:
        con.close()
    state = register_pending(state, new_name, sid, sha, a.target,
                             datetime.now().strftime("%Y-%m-%d %H:%M"),
                             keep_pointer=a.keep_pointer, expect_from=a.expect_from)
    save_state(state)
    print(f"Registered {new_name} (id {sid}) in DMT_SCENARIO_TBL and in "
          f"{STATE.name} (pending) BEFORE inserting any record.")

    # 2) run the committed insert script into the registered scenario
    cs, _ = conn_for(a.target)
    env = dict(os.environ, DMT2_CONN=cs, DMT_SCENARIO_NAME=new_name)
    if a.target == "atp":
        w = json.loads((WS / "connections.json").read_text(encoding="utf-8"))["atp_queryapp"]
        env["DMT2_WALLET"] = w["wallet_dir"]; env["DMT2_WALLET_PW"] = w["wallet_password"]
    rc = subprocess.run([sys.executable, str(SEED)], env=env).returncode
    if rc != 0:
        save_state(mark_pending(state, new_name, "INSERT_FAILED"))
        sys.exit(f"Insert script failed (rc={rc}); {new_name} stays registered as "
                 f"INSERT_FAILED (never reused). Mint a new scenario once fixed.")

    # 3) verify + finalize (also what --resume does). A connection lost here
    # leaves the scenario REGISTERED (already on disk); say how to finish it.
    try:
        return verify_and_finalize(state, new_name, cur_scn)
    except (oracledb.Error, OSError) as e:
        print(f"\nConnection lost after the insert ({str(e)[:200]}). {new_name} "
              f"(id {sid}) is REGISTERED, not lost. Finish it, without re-inserting, with:\n"
              f"  python scripts/deploy_scenario.py --resume {new_name}", file=sys.stderr)
        raise


def verify_and_finalize(state, name, cur_scn):
    """Duplicate-check a registered scenario and register it for good. Shared by
    the normal mint and --resume, so a scenario whose run stopped after the
    insert is finished exactly as the original run would have finished it."""
    entry = state["pending_scenarios"][name]
    sid = entry["scenario_id"]
    con = connect(entry["target"]); cur = con.cursor()
    cur.execute("SELECT scenario_id FROM dmt_scenario_tbl WHERE scenario_name=:n", [name])
    row = cur.fetchone()
    if not row or int(row[0]) != int(sid):
        sys.exit(f"{name}: DMT_SCENARIO_TBL id {row[0] if row else '(none)'} does not "
                 f"match the registered id {sid}; aborting.")
    rows = stg_row_counts(con, sid)
    if not rows:
        sys.exit(f"{name} (id {sid}) holds no staging rows: the insert never completed. "
                 f"It stays registered (pending); mint a new scenario.")
    print(f"{name} (id {sid}): {sum(rows.values())} staging rows in {len(rows)} table(s).")
    problems = verify_no_duplicates(con, sid)
    con.close()
    if problems:
        save_state(mark_pending(state, name, "REJECTED_DUPLICATES"))
        print("\nDUPLICATE ROWS FOUND - scenario REJECTED, pointer NOT advanced:")
        for t, g, n in problems:
            print(f"  {t}: {g} duplicated key group(s) across {n} rows")
        sys.exit("Duplicate check FAILED.")
    print(f"\nVerified: 0 duplicate rows across all staging tables in {name} (id {sid}).")

    # 4) register for good: advance the pointer (default) or leave it alone
    # (--keep-pointer), and give the scenario its starting expected outcomes.
    keep_pointer = entry.get("keep_pointer", False)
    new_state, copied_from = finalize_scenario(state, name)
    save_state(new_state)
    if copied_from:
        print(f"Expected outcomes for {name} copied from {copied_from} "
              f"({len(new_state['expected_outcomes'][name])} sub-object(s)); "
              f"edit them for any row this scenario changed.")
    else:
        print(f"No expected outcomes to copy; {name} starts with none.")
    if keep_pointer:
        print(f"Pointer NOT moved: current_scenario stays {cur_scn}. "
              f"Run the object with --scenario {name}.")
    else:
        print(f"Pointer updated: current_scenario = {name}. "
              f"Run the regression with --scenario {name}.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
