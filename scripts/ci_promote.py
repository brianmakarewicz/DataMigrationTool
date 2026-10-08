#!/usr/bin/env python3
"""
ci_promote.py - DMT2 CI/CD promotion pipeline (script-first).

The deterministic regression is the gate. Nothing reaches prod (ATP) until the
branch passes the same regression on local (TEST).

Pipeline (owner design 2026-09-17; promotion gate added 2026-10-07):
  1. deploy-local       - install the working tree's db/ into local Docker (idempotent).
  2. regression-local   - run the full deterministic regression on local.
  3. clickthrough-local - Playwright console click-through for that same run id.
     (test-local = steps 1-3 in one go.)
  4. merge              - merge the PR to main (only after test-local passes).
  5. deploy-prod        - deploy committed db/ (+ APEX) to ATP (gold). REFUSES to
                          run unless the promotion gate passes (see below).
  6. test-prod          - run the SAME regression on ATP, then the click-through
                          against the ATP console for that ATP run.

THE PROMOTION GATE (scripts/promotion_gate.py). Steps 1-3 each record evidence
(git commit SHA, tree SHA, run id, verdict, time) in the gitignored
.ci_evidence/promotion_evidence.json, and every record and every gate decision
is appended to .ci_evidence/promotion_log.jsonl. deploy-prod refuses unless that
evidence shows, for the exact code being promoted: a clean local deploy, a FULL
local regression with no NEW failures or review items (exit 0, verdict PASS or
'PASS (no new failures; N known)': owner decision 2026-10-08, "change the gate - so
that there are no NEW failures"; known items are listed in
scripts/regression_known_issues.json) that finished within the last 24h,
and a PASS click-through for that same run id, run after the regression.
`python scripts/ci_promote.py gate` checks without deploying.

The only exception is the OWNER OVERRIDE, for the owner personally:
  python scripts/ci_promote.py deploy-prod --yes --owner-override "<reason>"
It waives only regression / click-through failures (local deploy evidence is still
required), needs a non-empty reason, refuses unless stdin is an interactive TTY,
and asks the person to type the commit's short SHA. Every attempt is printed
loudly and logged to .ci_evidence/promotion_log.jsonl. AGENTS AND CI MUST NEVER
USE IT: when the gate refuses, report the refusal to the owner.

Prefix sync (so local and prod never push duplicate records to the shared Fusion
pod). Owner rule 2026-10-08: "make sure you update the prefix WITHOUT WASTING THEM.
don't 'grab a few extra'. Grab the next one. If you need to move back to local or
run another test on ATP, you can always re-update." Immediately before every
regression submission, sync_prefix_for(target) computes N = max(highest prefix
ever used on local, highest ever used on ATP) + 1 ("used" = numeric PREFIX /
DEPENDENT_PREFIX in DMT_PIPELINE_RUN_TBL) and sets ONLY that target's
DMT_RUN_PREFIX_SEQ so its very next NEXTVAL is exactly N (ALTER SEQUENCE ...
RESTART START WITH N as the schema owner; no probe draws, nothing skipped). The
other instance is not touched: when work moves back there, its next run re-syncs.
After the run, assert_prefix_unique() fails the regression loudly if the run's
prefix was used on the other instance.

Instances (from ~/workspace/connections.json; never hardcode creds):
  local (TEST) : dmt_owner  @ //localhost:1523/FREEPDB1   (Oracle Free 23ai + APEX 24.2)
  atp   (GOLD) : DMT2_OWNER @ queryapp_tp                 (ATP + APEX 26.1)

Examples:
  python scripts/ci_promote.py test-local                 # deploy local + full regression + click-through
  python scripts/ci_promote.py gate                       # show whether HEAD may be promoted
  python scripts/ci_promote.py runtime-config --target atp --yes   # Fusion passwords + ACL on ATP
  python scripts/ci_promote.py clickthrough-atp --run-id 412   # click-through against ATP
  python scripts/ci_promote.py promote --pr 281           # full pipeline for a PR
  python scripts/ci_promote.py test-prod                  # re-verify prod only
  python scripts/ci_promote.py deploy-local               # just sync local from the tree

Safety: prod-affecting stages (deploy-prod, test-prod) require --yes (or the
PROMOTE_YES=1 env) so they never fire unattended by accident. test-prod and
test-local both write prefixed test records to the real Fusion demo pod — that
is what the regression does; the prefix sync keeps them from colliding.
"""
import argparse, glob, json, os, re, subprocess, sys, tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
WS   = Path.home() / "workspace"
sys.path.insert(0, str(WS))
sys.path.insert(0, str(REPO / "scripts"))
import promotion_gate as gate            # the hard gate in front of deploy-prod
import dmt_apex_url_target as urltarget  # the one console URL knob

JDK  = "C:/Users/Monroe/tools/jdk-21.0.11+10"
SQLCL= "C:/Users/Monroe/tools/sqlcl/bin/sql.exe"

# ---------------------------------------------------------------- connections
def _conns():
    return json.loads((WS / "connections.json").read_text(encoding="utf-8"))

def _local():
    cfg = _conns()
    pw = (cfg.get("dmt2_local", {}) or {}).get("schemas", {}) \
             .get("DMT_OWNER", {}).get("password", "DmtLocal#2026")
    return {"schema": "DMT_OWNER", "pw": pw,
            "dsn": "//localhost:1523/FREEPDB1", "tns": None,
            "connstr": f"dmt_owner/{pw}@//localhost:1523/FREEPDB1"}

def _atp():
    q = _conns()["atp_queryapp"]
    pw = q["schemas"]["DMT2_OWNER"]["password"]
    return {"schema": "DMT2_OWNER", "pw": pw,
            "dsn": q["dsn"], "tns": q["wallet_dir"],
            "connstr": f"DMT2_OWNER/{pw}@{q['dsn']}"}

TARGET = {"local": _local, "atp": _atp}

# ---------------------------------------------------------------- sqlcl helper
def _sqlcl(target, script_text):
    env = dict(os.environ)
    env["JAVA_HOME"] = JDK
    env["PATH"] = f"{JDK}/bin:{os.path.dirname(SQLCL)}:" + env.get("PATH", "")
    t = TARGET[target]()
    if t["tns"]:
        env["TNS_ADMIN"] = t["tns"]
    if not script_text.rstrip().endswith("exit"):
        script_text += "\nexit\n"
    p = subprocess.run([SQLCL, "-s", t["connstr"]],
                       input=script_text, capture_output=True, text=True, env=env)
    return p.stdout + p.stderr

def _oracle(target):
    import oracledb
    t = TARGET[target]()
    kw = {}
    if t["tns"]:
        kw["config_dir"] = t["tns"]; kw["wallet_location"] = t["tns"]
        kw["wallet_password"] = _conns()["atp_queryapp"]["wallet_password"]
    return oracledb.connect(user=t["schema"], password=t["pw"], dsn=t["dsn"], **kw)

# ---------------------------------------------------------------- DB deploy
def deploy_db(target):
    """Idempotent sync of the working tree's db/ into an existing instance:
    tables (idempotent add_col/exception-wrapped), types, package specs, bodies,
    views, procedures, seeds - all continue-on-error - then recompile and assert
    0 invalid.
    (install.sql is fresh-install only: it exits on the first 'already exists'.)"""
    order = []
    for pat in ("db/tables/*.sql", "db/types/*.sql",
                "db/packages/*.pks.sql", "db/packages/*.pkb.sql",
                "db/views/*.sql", "db/procedures/*.sql", "db/seed/*.sql"):
        order += sorted((REPO / p).as_posix() for p in
                        [q.relative_to(REPO).as_posix() for q in REPO.glob(pat)])
    # Backlog #80: run every db/migrations file (sorted chronological filename)
    # AFTER seed. These are the MODIFY-width / guarded-DROP convergence steps that
    # bring an existing instance's schema in line with the git create scripts (fresh
    # installs are already correct). They are written idempotent / guarded, so a
    # re-run on an already-migrated instance is a no-op — safe on every promotion.
    migrations = sorted((REPO / q.relative_to(REPO)).as_posix()
                        for q in REPO.glob("db/migrations/*.sql"))
    order += migrations
    lines = ["whenever sqlerror continue", "set define off", "set serveroutput off"]
    lines += [f"@@{f}" for f in order]
    lines += [
        "declare begin",
        "  for r in (select object_name,object_type from user_objects where status='INVALID') loop",
        "    begin",
        "      if r.object_type='PACKAGE BODY' then execute immediate 'alter package '||r.object_name||' compile body';",
        "      else execute immediate 'alter '||r.object_type||' '||r.object_name||' compile'; end if;",
        "    exception when others then null; end;",
        "  end loop;",
        "end;", "/",
        "set heading off",
        "select 'INVALID_AFTER_DEPLOY='||count(*) from user_objects where status='INVALID';",
        "exit",
    ]
    out = _sqlcl(target, "\n".join(lines) + "\n")
    m = re.search(r"INVALID_AFTER_DEPLOY=(\d+)", out)
    n = int(m.group(1)) if m else -1
    print(f"[deploy-db:{target}] invalid objects after deploy: {n}")
    if n != 0:
        print(out[-2000:])
    return n == 0

def deploy_apex(target):
    """APEX deploy from the git split baseline (apex/f500). Local APEX was upgraded
    to 26.1 (2026-09-17) to match ATP, so import works on both targets now."""
    rc = subprocess.run([sys.executable, str(REPO / "scripts" / "apex_deploy.py"),
                         "import", "--target", target]).returncode
    print(f"[deploy-apex:{target}] {'OK' if rc == 0 else 'FAILED'}")
    return rc == 0

# ---------------------------------------------------------------- prefix sync
PREFIX_SEQ = "DMT_RUN_PREFIX_SEQ"
PREFIX_MAX = 99999      # the sequence's MAXVALUE (db/sequences/dmt_run_prefix_seq.sql)

def max_used_prefix(target):
    """Highest numeric prefix ever used on `target`. DMT_PIPELINE_RUN_TBL is the
    permanent registry of issued prefixes: every NEXTVAL of DMT_RUN_PREFIX_SEQ in
    the packages (DMT_PIPELINE_INIT_PKG and the six DMT_LOADER_PKG entry points)
    is inserted there as PREFIX in the same block. DEPENDENT_PREFIX only names a
    prefix an earlier run already used; it is included so the result can never be
    below a referenced prefix. Non-numeric values are ignored. Reads only."""
    con = _oracle(target); cur = con.cursor()
    cur.execute("select greatest("
                "nvl(max(to_number(prefix default null on conversion error)), 0), "
                "nvl(max(to_number(dependent_prefix default null on conversion error)), 0)) "
                "from DMT_PIPELINE_RUN_TBL")
    v = int(cur.fetchone()[0]); con.close()
    return v

def _seq_state(cur):
    """(LAST_NUMBER, CACHE_SIZE, INCREMENT_BY) of DMT_RUN_PREFIX_SEQ, read from
    USER_SEQUENCES without consuming a value. With NOCACHE (both instances) and
    no draw since a RESTART, LAST_NUMBER is exactly the value NEXTVAL returns."""
    cur.execute("select last_number, cache_size, increment_by from user_sequences "
                "where sequence_name = :s", s=PREFIX_SEQ)
    row = cur.fetchone()
    if not row:
        raise SystemExit(f"[prefix] {PREFIX_SEQ} not found in USER_SEQUENCES; refusing to guess")
    return int(row[0]), int(row[1] or 0), int(row[2])

def _set_next(cur, n):
    """Make the sequence's very next NEXTVAL return exactly n, drawing nothing.
    Primary: ALTER SEQUENCE ... RESTART START WITH n (Oracle 23ai/26ai, both
    instances). Fallback when RESTART is rejected: the INCREMENT BY trick with one
    draw that lands exactly on n-1 (a value at or below the highest used, so
    nothing above n is discarded), then INCREMENT BY 1 again."""
    try:
        cur.execute(f"alter sequence {PREFIX_SEQ} restart start with {int(n)}")
        return "restart"
    except Exception as e:  # noqa: BLE001 - any ORA- here means RESTART unsupported
        print(f"[prefix] RESTART START WITH rejected ({e}); using the INCREMENT BY trick")
    last, cache, inc = _seq_state(cur)
    if cache:
        raise SystemExit(f"[prefix] {PREFIX_SEQ} is CACHE {cache}; the INCREMENT BY trick "
                         f"cannot land exactly. Refusing (no prefix wasted).")
    # NOCACHE: LAST_NUMBER = last issued + INCREMENT_BY, and NEXTVAL with a new
    # increment returns last issued + step; choose step so that draw is n - 1.
    step = (int(n) - 1) - (last - inc)
    if step == 0:
        # last issued is already n - 1: only the increment needs restoring
        cur.execute(f"alter sequence {PREFIX_SEQ} increment by 1")
        return "increment reset"
    cur.execute(f"alter sequence {PREFIX_SEQ} increment by {step}")
    try:
        cur.execute(f"select {PREFIX_SEQ}.NEXTVAL from dual")
        landed = int(cur.fetchone()[0])
    finally:
        cur.execute(f"alter sequence {PREFIX_SEQ} increment by 1")
    if landed != int(n) - 1:
        raise SystemExit(f"[prefix] INCREMENT BY trick landed on {landed}, expected {int(n) - 1}")
    return "increment"

def sync_prefix_for(target):
    """Set ONLY `target`'s DMT_RUN_PREFIX_SEQ so its very next NEXTVAL is exactly
    N = max(highest prefix ever used on local, highest ever used on ATP) + 1.

    Owner rule (2026-10-08): "make sure you update the prefix WITHOUT WASTING THEM.
    don't 'grab a few extra'. Grab the next one. If you need to move back to local
    or run another test on ATP, you can always re-update." So: no probe draws, no
    skipping ahead, and the other instance is never touched - the next run there
    calls this for that instance and re-syncs it. Called immediately before every
    regression submission (regression-local -> local, test-prod -> atp).

    History: replaces next_prefix_from_atp() (backlog #450, drew ATP NEXTVAL until
    above local) and reserve_atp_prefix_above_local() (backlog #520/#521, skipped
    ATP past local's used and next-to-issue values), both of which discarded
    numbers. ATP run 178 / local run 310 (both 93364) is the collision this and
    assert_prefix_unique() prevent.

    DDL runs on the target's own connection, which is the schema owner
    (DMT_OWNER local / DMT2_OWNER ATP), never ADMIN. Idempotent: when the target
    already issues N next, nothing is altered. Returns N."""
    n = max(max_used_prefix("local"), max_used_prefix("atp")) + 1
    if n > PREFIX_MAX:
        raise SystemExit(f"[prefix] next prefix {n} exceeds {PREFIX_SEQ} MAXVALUE {PREFIX_MAX}")
    con = _oracle(target); cur = con.cursor()
    try:
        last, cache, inc = _seq_state(cur)
        if last == n and cache == 0 and inc == 1:
            how = "already set"
        else:
            how = _set_next(cur, n)
            last, cache, inc = _seq_state(cur)
            if last != n or inc != 1:
                raise SystemExit(f"[prefix] {target} {PREFIX_SEQ} reads LAST_NUMBER={last} "
                                 f"INCREMENT_BY={inc} after sync, expected {n}/1")
    finally:
        con.close()
    print(f"[prefix] {target} {PREFIX_SEQ} will issue {n} next ({how}; N = max used on "
          f"local and ATP + 1; the other instance is not touched)")
    return n

def prefix_used_on(target, prefix, exclude_run_id=None):
    """Run ids on `target` that already used `prefix` (other than exclude_run_id)."""
    con = _oracle(target); cur = con.cursor()
    cur.execute("select run_id from DMT_PIPELINE_RUN_TBL where prefix = :p "
                "and (:r is null or run_id <> :r) order by run_id",
                p=str(prefix), r=exclude_run_id)
    ids = [int(r[0]) for r in cur]; con.close()
    return ids

def run_prefix(target, run_id):
    con = _oracle(target); cur = con.cursor()
    cur.execute("select prefix from DMT_PIPELINE_RUN_TBL where run_id = :r", r=run_id)
    row = cur.fetchone(); con.close()
    return row[0] if row else None

def assert_prefix_unique(target, run_id):
    """True when the run's prefix was used by no run on the OTHER instance. Both
    instances write to the same Fusion pod, so a shared prefix means duplicate
    records and a meaningless result; the run is then reported as not passing."""
    other = "local" if target == "atp" else "atp"
    p = run_prefix(target, run_id)
    clash = prefix_used_on(other, p) if p else []
    if clash:
        print(f"[prefix] FAIL: {target} run {run_id} used prefix {p}, which {other} run(s) "
              f"{clash} already sent to the shared Fusion pod. Its results are not valid.")
        return False
    print(f"[prefix] ok: {target} run {run_id} prefix {p} is not used on {other}")
    return True

# ---------------------------------------------------------------- regression
def _known_issues_sha():
    """sha256 of scripts/regression_known_issues.json, or None if unreadable."""
    import hashlib
    try:
        return hashlib.sha256((REPO / "scripts" / "regression_known_issues.json")
                              .read_bytes()).hexdigest()
    except OSError:
        return None


def run_regression(target, pipelines=None):
    """Run the deterministic regression against the target.

    Returns a dict: ok (True only on exit 0 with a passing verdict, i.e. no NEW
    failures or review items), run_id, verdict, known/new failure and review counts,
    exit_code, pipelines, started_at, finished_at. The run id and verdict come
    from the harness's own --json summary, never from guessing.
    pipelines: optional subset (e.g. 'HCM') passed to dmt_regression_run.py."""
    env = dict(os.environ)
    t = TARGET[target]()
    env["DMT2_CONN"] = f"{t['schema']}/{t['pw']}@{t['dsn'].replace('//','')}" \
        if target == "local" else f"{t['schema']}/{t['pw']}@{t['dsn']}"
    if t["tns"]:
        # dmt_regression_run.py reads the wallet from DMT2_WALLET / DMT2_WALLET_PW
        # (not TNS_ADMIN); set both so the ATP (prod) regression can connect.
        env["TNS_ADMIN"] = t["tns"]
        env["DMT2_WALLET"] = t["tns"]
        env["DMT2_WALLET_PW"] = _conns()["atp_queryapp"]["wallet_password"]
    fd, json_path = tempfile.mkstemp(prefix="dmt2_regression_", suffix=".json")
    os.close(fd)
    cmd = [sys.executable, str(REPO / "scripts" / "dmt_regression_run.py"),
           "--json", json_path]
    if pipelines:
        cmd += ["--pipelines", pipelines]
    print(f"[regression:{target}] launching deterministic regression "
          f"({pipelines or 'ALL pipelines'}) ...")
    started = gate._iso(gate._now())
    rc = subprocess.run(cmd, env=env).returncode
    finished = gate._iso(gate._now())
    summary = {}
    try:
        summary = json.loads(Path(json_path).read_text(encoding="utf-8") or "{}")
    except (OSError, ValueError):
        summary = {}
    finally:
        try:
            os.remove(json_path)
        except OSError:
            pass
    res = {"ok": rc == 0 and gate.regression_verdict_passes(summary.get("verdict")),
           "run_id": summary.get("run_id"),
           "verdict": summary.get("verdict") or "UNKNOWN (no JSON summary)",
           "exit_code": rc,
           "known_failures": len(summary.get("known_failures") or []),
           "new_failures": len(summary.get("new_failures") or []),
           "known_review": len(summary.get("known_review") or []),
           "new_review": len(summary.get("new_review") or []),
           # Pin the exact known-issues list this verdict relied on, so any change
           # to that list is visible in the evidence and the promotion log.
           "known_issues_file_sha256": _known_issues_sha(),
           "pipelines": summary.get("pipeline_codes") or pipelines or gate.FULL_PIPELINES,
           "target": target, "started_at": started, "finished_at": finished}
    print(f"[regression:{target}] run {res['run_id']}: "
          f"{'PASS' if res['ok'] else 'FAIL'} (verdict {res['verdict']}, exit {rc}, "
          f"new: {res['new_failures']} failure(s) / {res['new_review']} review; "
          f"known: {res['known_failures']} failure(s) / {res['known_review']} review)")
    return res

# ---------------------------------------------------------------- click-through
def console_base(target):
    """ORDS base URL of the DMT2 console on the target. Local is the built-in
    default of the URL knob; ATP comes from connections.json."""
    if target == "local":
        return urltarget.DEFAULT_BASE
    url = _conns()["atp_queryapp"]["apex_workspaces"]["DMT2"]["app_url"]
    return urltarget._norm(url)

def run_clickthrough(target, run_id):
    """Run the Playwright console click-through (test/playwright/
    dmt_console_verify.py) for run_id against the target console. Returns a
    dict with ok/verdict/exit_code/steps; ok only on verdict PASS and exit 0."""
    base = console_base(target)
    fd, json_path = tempfile.mkstemp(prefix="dmt2_clickthrough_", suffix=".json")
    os.close(fd)
    cmd = [sys.executable, str(REPO / "test" / "playwright" / "dmt_console_verify.py"),
           "--base-url", base, "--run-id", str(run_id), "--json-out", json_path]
    print(f"[clickthrough:{target}] {base} drilling run {run_id} ...")
    rc = subprocess.run(cmd).returncode
    out = {}
    try:
        out = json.loads(Path(json_path).read_text(encoding="utf-8") or "{}")
    except (OSError, ValueError):
        out = {}
    finally:
        try:
            os.remove(json_path)
        except OSError:
            pass
    steps = out.get("steps") or []
    res = {"ok": rc == 0 and out.get("verdict") == "PASS",
           "run_id": run_id, "base_url": base, "exit_code": rc,
           "verdict": out.get("verdict") or "UNKNOWN (no JSON result)",
           "steps_total": len(steps),
           "steps_passed": sum(1 for x in steps if x.get("ok")),
           "failed_steps": [x.get("name") for x in steps if not x.get("ok")][:20]}
    print(f"[clickthrough:{target}] run {run_id}: "
          f"{'PASS' if res['ok'] else 'FAIL'} ({res['steps_passed']}/{res['steps_total']} steps)")
    return res

# ---------------------------------------------------------------- stages
def stage_deploy_local():
    """Deploy the working tree to local, then re-assert the Fusion credentials
    (the seeds a deploy re-runs can leave them masked or stale)."""
    ident = gate.code_identity()
    ok = deploy_db("local") and deploy_apex("local") and stage_runtime_config("local")
    gate.record("deploy_local", {"ok": ok}, ident)
    return ok

def stage_regression_local(pipelines=None):
    """Full regression on local, with the prefix sync, recorded as
    promotion evidence. A --pipelines subset is recorded too, but the gate only
    accepts the full pipeline set."""
    ident = gate.code_identity()
    sync_prefix_for("local")   # owner rule 2026-10-08: next = max used (local, ATP) + 1, no waste
    res = run_regression("local", pipelines)
    if res["run_id"] and not assert_prefix_unique("local", res["run_id"]):
        res["ok"] = False
    gate.record("regression", res, ident)
    return res["ok"]

def stage_clickthrough_local(run_id=None):
    """Click-through of the local console for the recorded regression run
    (or an explicit --run-id), recorded as promotion evidence."""
    ident = gate.code_identity()
    if not run_id:
        reg = (gate.load_evidence() or {}).get("regression") or {}
        run_id = reg.get("run_id")
        if not run_id:
            print("[clickthrough-local] no regression run recorded; run "
                  "regression-local first or pass --run-id"); return False
    res = run_clickthrough("local", run_id)
    gate.record("clickthrough_local", res, ident)
    return res["ok"]

def stage_clickthrough_atp(run_id):
    """Post-promotion click-through of the ATP console. Logged durably; it
    does not feed the gate (the gate is about what was proven locally)."""
    if not run_id:
        print("[clickthrough-atp] --run-id is required (an ATP run id)"); return False
    ident = gate.code_identity()
    res = run_clickthrough("atp", run_id)
    gate.record("clickthrough_atp", res, ident)
    return res["ok"]

def stage_runtime_config(target):
    """Fill the Fusion passwords (global + per-object overrides such as Grants'
    ppm_impl) and the Fusion network ACL on the target, from connections.json,
    via db/tools/setup_runtime_config.py. Secrets never live in git, so a deploy
    can leave these masked or stale; run this after every deploy."""
    t = TARGET[target]()
    env = dict(os.environ)
    env["DMT2_CONN"] = f"{t['schema']}/{t['pw']}@{t['dsn'].replace('//','')}" \
        if target == "local" else f"{t['schema']}/{t['pw']}@{t['dsn']}"
    if t["tns"]:
        env["DMT2_WALLET"] = t["tns"]
        env["DMT2_WALLET_PW"] = _conns()["atp_queryapp"]["wallet_password"]
    rc = subprocess.run([sys.executable, str(REPO / "db" / "tools" / "setup_runtime_config.py")],
                        env=env).returncode
    print(f"[runtime-config:{target}] {'OK' if rc == 0 else 'FAILED'}")
    return rc == 0

def stage_test_local(pipelines=None):
    if not stage_deploy_local():
        print("[test-local] deploy failed; not running regression"); return False
    if not stage_regression_local(pipelines):
        print("[test-local] regression did not pass; not running the click-through"); return False
    return stage_clickthrough_local()

def stage_merge(pr, wait_min=15):
    """Respect the mandated review gate. CLAUDE.md: the pr-review.yml GitHub Action
    is the binding reviewer and auto-merges clean PRs; we NEVER bypass it. So this
    stage waits for that reviewer: success only when the PR actually reaches MERGED
    (or is APPROVED and then merged through normal branch protection - no --admin,
    no bypass). CHANGES_REQUESTED or timeout -> fail, so promote stops before prod."""
    if not pr:
        print("[merge] no --pr given; skipping (pr-review.yml merges the branch)"); return True
    import time
    deadline = wait_min * 60
    waited = 0
    while waited <= deadline:
        j = subprocess.run(["gh", "pr", "view", str(pr), "--json",
                            "state,reviewDecision,mergeStateStatus"],
                           capture_output=True, text=True)
        try:
            info = json.loads(j.stdout)
        except Exception:
            info = {}
        state = info.get("state"); decision = info.get("reviewDecision")
        if state == "MERGED":
            print(f"[merge] PR #{pr} merged by the automated reviewer."); return True
        if decision == "CHANGES_REQUESTED":
            print(f"[merge] PR #{pr} has CHANGES_REQUESTED - not merging, stopping before prod.")
            return False
        if decision == "APPROVED":
            # Approved by pr-review.yml; merge through normal protection (NO --admin).
            rc = subprocess.run(["gh", "pr", "merge", str(pr), "--squash"]).returncode
            print(f"[merge] PR #{pr} approved; merge {'ok' if rc == 0 else 'FAILED'}")
            return rc == 0
        print(f"[merge] waiting for pr-review.yml on PR #{pr} "
              f"(state={state}, review={decision})... {waited}s/{deadline}s")
        if waited == deadline:
            break
        time.sleep(min(30, deadline - waited)); waited += 30
    print(f"[merge] timed out after {wait_min} min waiting for the automated review; "
          f"not merging (run again once pr-review.yml has approved).")
    return False

def stage_deploy_prod(yes, owner_override=None):
    if not yes:
        print("[deploy-prod] refusing without --yes (prod-affecting)"); return False
    subprocess.run(["git", "checkout", "main"], cwd=REPO)
    subprocess.run(["git", "pull", "--ff-only"], cwd=REPO)
    # THE GATE: checked against the exact commit about to be deployed (main
    # HEAD after the pull). owner_override is the owner-only escape hatch (TTY +
    # typed SHA + logged); it never waives missing local deploy evidence.
    if not gate.enforce(stage="deploy-prod", owner_override=owner_override):
        print("[deploy-prod] NOT deploying to ATP: the promotion gate refused.")
        return False
    return deploy_db("atp") and deploy_apex("atp") and stage_runtime_config("atp")

def stage_test_prod(yes, pipelines=None):
    """Regression on ATP, then the console click-through against ATP for that
    same ATP run. Passes only if both pass."""
    if not yes:
        print("[test-prod] refusing without --yes (writes test data to Fusion from prod)"); return False
    sync_prefix_for("atp")     # owner rule 2026-10-08: next = max used (local, ATP) + 1, no waste
    res = run_regression("atp", pipelines)  # SUBMIT_PIPELINE draws exactly that value
    if res["run_id"] and not assert_prefix_unique("atp", res["run_id"]):
        res["ok"] = False
    gate.log_event({"event": "record", "step": "regression_atp", **res})
    if not res["run_id"]:
        print("[test-prod] no ATP run id came back; cannot run the ATP click-through")
        return False
    ct_ok = stage_clickthrough_atp(res["run_id"])
    return res["ok"] and ct_ok

def main():
    ap = argparse.ArgumentParser(description="DMT2 CI/CD promotion pipeline")
    ap.add_argument("stage", choices=["deploy-local", "runtime-config", "regression-local",
                                      "clickthrough-local", "test-local", "gate",
                                      "merge", "deploy-prod", "test-prod",
                                      "clickthrough-atp", "promote"])
    ap.add_argument("--pr", type=int, help="PR number to merge in the promote flow")
    ap.add_argument("--yes", action="store_true",
                    help="authorize prod-affecting stages (or set PROMOTE_YES=1)")
    ap.add_argument("--pipelines", help="regression pipeline subset, e.g. HCM (default: all; "
                                        "a subset is never accepted by the promotion gate)")
    ap.add_argument("--run-id", type=int, help="run id for clickthrough-local / clickthrough-atp")
    ap.add_argument("--target", choices=["local", "atp"], default="local",
                    help="instance for runtime-config (default local)")
    ap.add_argument("--owner-override", metavar="REASON",
                    help="deploy-prod only. OWNER ONLY, never agents or CI: waive "
                         "regression/click-through gate failures. Needs a reason, an "
                         "interactive terminal and the typed commit short SHA; logged.")
    a = ap.parse_args()
    yes = a.yes or os.environ.get("PROMOTE_YES") == "1"
    if a.owner_override is not None and a.stage != "deploy-prod":
        print("[ci_promote] --owner-override is only accepted by deploy-prod")
        sys.exit(1)

    if a.stage == "deploy-local":       sys.exit(0 if stage_deploy_local() else 1)
    if a.stage == "runtime-config":
        if a.target == "atp" and not yes:
            print("[runtime-config] refusing to write ATP config without --yes"); sys.exit(1)
        sys.exit(0 if stage_runtime_config(a.target) else 1)
    if a.stage == "regression-local":   sys.exit(0 if stage_regression_local(a.pipelines) else 1)
    if a.stage == "clickthrough-local": sys.exit(0 if stage_clickthrough_local(a.run_id) else 1)
    if a.stage == "test-local":         sys.exit(0 if stage_test_local(a.pipelines) else 1)
    if a.stage == "gate":               sys.exit(0 if gate.enforce(stage="gate (check only)") else 1)
    if a.stage == "merge":              sys.exit(0 if stage_merge(a.pr) else 1)
    if a.stage == "deploy-prod":        sys.exit(0 if stage_deploy_prod(yes, a.owner_override) else 1)
    if a.stage == "test-prod":          sys.exit(0 if stage_test_prod(yes, a.pipelines) else 1)
    if a.stage == "clickthrough-atp":   sys.exit(0 if stage_clickthrough_atp(a.run_id) else 1)

    # promote: full pipeline with the deterministic gate
    print("=== PROMOTE: test-local (regression + click-through) -> merge -> "
          "deploy-prod (gate) -> test-prod (ATP regression + click-through) ===")
    if not stage_test_local(a.pipelines):
        sys.exit("GATE FAILED on local regression / click-through - not merging, not deploying.")
    if not stage_merge(a.pr):
        sys.exit("Merge failed - stopping before prod.")
    if not stage_deploy_prod(yes):
        sys.exit("Prod deploy refused or failed.")
    if not stage_test_prod(yes, a.pipelines):
        sys.exit("PROD REGRESSION OR ATP CLICK-THROUGH FAILED after deploy - investigate immediately.")
    print("=== PROMOTE complete: local regression + click-through passed, merged, "
          "deployed to ATP, ATP regression + click-through passed. ===")

if __name__ == "__main__":
    main()
