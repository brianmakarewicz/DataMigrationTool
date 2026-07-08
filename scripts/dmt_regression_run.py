#!/usr/bin/env python
"""
DMT full-regression runner (queue-based pipeline architecture).

Submits the RegressionTest scenario through the real production path
(DMT_SCHEDULER_PKG -> DMT_WORK_QUEUE_TBL -> DMT_QUEUE_POLLER), waits for the
run to reach a terminal state, then evaluates it against the project's
pass criteria (RULE #1: GOOD rows must reach LOADED in Fusion base tables,
BAD rows must reach FAILED with reportable error text).

Checks performed after the run:
  1. Run terminal status + queue rollup (no FAILED / stuck queue rows).
  2. Record-level verdicts from DMT_RECORD_DETAIL_V:
       - rows whose DISPLAY_KEY carries a bad-seed marker -> must be FAILED
       - all other rows                                   -> must be LOADED
       - every FAILED row must have non-empty ERROR_TEXT
       - every DONE queue object must have >= 1 record (no DONE-with-zero)
  3. DMT_LOG_TBL sweep for the run: ERROR rows, WARN rows, malformed
     LOG_TYPE values (log calls with swapped arguments), plus ERROR rows
     logged with NULL run_id during the run window.
  4. DBMS_SCHEDULER sweep: DMT_% job failures during the run window
     (uncaught exceptions in poller / child jobs).
  5. Baseline diff: per-sub-object LOADED/FAILED counts vs the previous
     completed run of the same scenario+pipelines -> separates pre-existing
     failures from NEW failures introduced by the change under test.

Usage:
  python scripts/dmt_regression_run.py                          # full submit + wait + evaluate
  python scripts/dmt_regression_run.py --pipelines P2P,O2C      # subset
  python scripts/dmt_regression_run.py --status-only 113        # evaluate an existing run
  python scripts/dmt_regression_run.py --json out.json          # machine-readable summary

Exit codes: 0 = pass, 1 = hard failures, 2 = structurally passed but has
review items (log errors / warnings needing triage).

SUBMIT_PIPELINE hang workaround: the package call is attempted first with a
90s call timeout; on timeout the run+queue rows are created inline as one
pure-SQL transaction (documented workaround, see
memory/project_dmt_pipeline_launch_gotchas.md), then the poller is enabled.
"""
import argparse
import datetime
import io
import json
import re
import sys
import time

sys.path.insert(0, r'C:\Users\Monroe\workspace')
from conn_helper import connect_atp
import oracledb

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace',
                              line_buffering=True)
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace',
                              line_buffering=True)

DEFAULT_PIPELINES = 'P2P,O2C,FINANCIALS,PROJECTS,HCM'   # run 113 reference set
SCENARIO = 'RegressionTest'
# CANCELLED removed 2026-07-08 (A8): no cancellation — Overview run-status table.
TERMINAL_RUN_STATUSES = {'COMPLETED', 'COMPLETED_ERRORS', 'FAILED', 'NO_ROWS_PROCESSED'}
TERMINAL_QUEUE_STATUSES = {'DONE', 'FAILED', 'SKIPPED'}
KNOWN_LOG_TYPES = {'INFO', 'WARN', 'ERROR', 'DEBUG'}

# Markers identifying intentionally-bad seed rows in DISPLAY_KEY. The seed
# script (insert_regression_test_data.py) names bad rows with 'BAD' in the
# business key, but some objects use other conventions: descriptive keys
# ('DOES NOT EXIST SUPPLIER - Ghost HQ' for [BAD-UPS]), FAKE_* lookup values,
# or -B{n} / -G{n} suffixes (Items: DMT-PLAIN-B6 = bad, DMT-PLAIN-G6 = good).
BAD_KEY_MARKERS = ('BAD', 'DOES NOT EXIST', 'GHOST', 'NONEXIST', 'INVALID', 'FAKE')
BAD_KEY_REGEX = re.compile(r'-B\d+\b')


def connect():
    return connect_atp('queryapp', 'DMT_OWNER')


def is_bad_key(display_key):
    k = (display_key or '').upper()
    return any(m in k for m in BAD_KEY_MARKERS) or bool(BAD_KEY_REGEX.search(k))


# ---------------------------------------------------------------------------
# Submit
# ---------------------------------------------------------------------------

def submit_run(pipelines, scenario, run_mode, on_failure):
    """Submit via SUBMIT_PIPELINE with a call timeout; fall back to the
    documented inline-insert workaround if the package call hangs."""
    conn = connect()
    conn.call_timeout = 90_000  # ms — SUBMIT_PIPELINE has hung indefinitely before
    cur = conn.cursor()
    run_id_var = cur.var(oracledb.NUMBER)
    try:
        cur.callproc('DMT_OWNER.DMT_SCHEDULER_PKG.SUBMIT_PIPELINE',
                     [pipelines, scenario, run_mode, on_failure, 'REGRESSION_AGENT', run_id_var])
        run_id = int(run_id_var.getvalue())
        print(f"  SUBMIT_PIPELINE ok -> RUN_ID={run_id}")
        conn.call_timeout = 0
        ensure_poller(conn)
        conn.close()
        return run_id
    except Exception as e:
        print(f"  SUBMIT_PIPELINE failed/hung ({str(e)[:120]}) — using inline fallback")
        try:
            conn.close()
        except Exception:
            pass
        return fallback_submit(pipelines, scenario, run_mode, on_failure)


def fallback_submit(pipelines, scenario, run_mode, on_failure):
    """Replicate create_run_and_queue as one pure-SQL transaction.
    GET_CEMLI_SEQUENCE / GET_CEMLI_DEPENDENCIES are instant public functions;
    only the inserts run inside the long transaction."""
    conn = connect()
    conn.call_timeout = 30_000
    cur = conn.cursor()

    plan = []          # (pipeline_label, cemli, depends_on, is_split)
    all_cemlis = []
    for code in [p.strip() for p in pipelines.split(',') if p.strip()]:
        if code.upper().startswith('STANDALONE:'):
            seq, label = code[11:], 'STANDALONE'
        else:
            seq = cur.callfunc('DMT_OWNER.DMT_SCHEDULER_PKG.GET_CEMLI_SEQUENCE',
                               oracledb.STRING, [code])
            label = code.upper()
            if not seq:
                raise SystemExit(f"Unknown pipeline code: {code}")
        for cemli in [c.strip() for c in seq.split(',') if c.strip()]:
            deps = cur.callfunc('DMT_OWNER.DMT_SCHEDULER_PKG.GET_CEMLI_DEPENDENCIES',
                                oracledb.STRING, [label, cemli])
            cur.execute("SELECT COUNT(*) FROM DMT_OWNER.DMT_CEMLI_SPLIT_CFG WHERE CEMLI_CODE = :1", [cemli])
            is_split = cur.fetchone()[0] > 0
            plan.append((label, cemli, deps, is_split))
            all_cemlis.append(cemli)

    cur.execute("SELECT TO_CHAR(DMT_OWNER.DMT_RUN_PREFIX_SEQ.NEXTVAL) FROM DUAL")
    prefix = cur.fetchone()[0]

    run_id_var = cur.var(oracledb.NUMBER)
    cur.execute("""
        INSERT INTO DMT_OWNER.DMT_PIPELINE_RUN_TBL (
            PIPELINE_CODES, RUN_TYPE, SUBMITTED_BY,
            CEMLI_SEQUENCE, SCENARIO_NAME, RUN_MODE, PREFIX, ON_FAILURE_POLICY
        ) VALUES (:pc, 'PIPELINE', 'REGRESSION_AGENT', :seq, :sc, :rm, :pfx, :onf)
        RETURNING RUN_ID INTO :rid
    """, pc=pipelines, seq=','.join(all_cemlis), sc=scenario, rm=run_mode,
         pfx=prefix, onf=on_failure, rid=run_id_var)
    run_id = int(run_id_var.getvalue()[0])

    cur.executemany("""
        INSERT INTO DMT_OWNER.DMT_WORK_QUEUE_TBL (
            RUN_ID, PIPELINE, CEMLI_CODE, SORT_ORDER, DEPENDS_ON,
            WORK_STATUS, PARTITION_KEY, PARTITION_LABEL
        ) VALUES (:1, :2, :3, :4, :5, :6, :7, :8)
    """, [
        (run_id, label, cemli, i + 1, deps,
         'PENDING' if deps else 'READY',
         'ALL' if is_split else None,
         'All Groups' if is_split else None)
        for i, (label, cemli, deps, is_split) in enumerate(plan)
    ])
    conn.commit()
    print(f"  Inline fallback created RUN_ID={run_id} prefix={prefix} ({len(plan)} queue rows)")
    ensure_poller(conn)
    conn.close()
    return run_id


def ensure_poller(conn):
    cur = conn.cursor()
    cur.callproc('DMT_OWNER.DMT_QUEUE_PKG.ENSURE_POLLER_RUNNING')
    print("  Poller enabled (DMT_QUEUE_POLLER).")


# ---------------------------------------------------------------------------
# Poll
# ---------------------------------------------------------------------------

def wait_for_run(run_id, timeout_min, stall_min):
    """Poll until terminal. Terminal = RUN_STATUS terminal AND all queue rows
    terminal. Returns final run status ('' if timed out)."""
    deadline = time.time() + timeout_min * 60
    last_snapshot, last_change = None, time.time()
    final_status = ''
    while time.time() < deadline:
        conn = connect()
        conn.call_timeout = 60_000
        cur = conn.cursor()
        try:
            cur.execute("""SELECT RUN_STATUS, CURRENT_CEMLI, CURRENT_STEP
                           FROM DMT_PIPELINE_RUN_TBL WHERE RUN_ID = :1""", [run_id])
            row = cur.fetchone()
            run_status, cur_cemli, cur_step = row if row else ('MISSING', None, None)
            cur.execute("""SELECT WORK_STATUS, COUNT(*) FROM DMT_WORK_QUEUE_TBL
                           WHERE RUN_ID = :1 GROUP BY WORK_STATUS ORDER BY 1""", [run_id])
            qmap = dict(cur.fetchall())
        finally:
            conn.close()

        snapshot = (run_status, tuple(sorted(qmap.items())))
        stamp = datetime.datetime.now().strftime('%H:%M:%S')
        if snapshot != last_snapshot:
            qtxt = ' '.join(f"{k}={v}" for k, v in sorted(qmap.items()))
            step = f" @ {cur_cemli}/{cur_step}" if cur_cemli else ''
            print(f"  [{stamp}] {run_status}{step} | {qtxt}")
            last_snapshot, last_change = snapshot, time.time()
        elif time.time() - last_change > stall_min * 60:
            print(f"  [{stamp}] WARNING: no state change in {stall_min} min "
                  f"(status={run_status}) — possible stall")
            last_change = time.time()  # only warn once per stall interval

        non_terminal_q = sum(v for k, v in qmap.items() if k not in TERMINAL_QUEUE_STATUSES)
        if run_status in TERMINAL_RUN_STATUSES and non_terminal_q == 0:
            final_status = run_status
            break
        time.sleep(45)
    return final_status


# ---------------------------------------------------------------------------
# Evaluate
# ---------------------------------------------------------------------------

def evaluate(run_id, baseline_arg):
    conn = connect()
    conn.call_timeout = 120_000
    cur = conn.cursor()
    result = {'run_id': run_id, 'failures': [], 'review': [], 'objects': {}, 'baseline': None}

    cur.execute("""SELECT RUN_STATUS, PIPELINE_CODES, SCENARIO_NAME, RUN_MODE, PREFIX,
                          ERROR_MESSAGE, SUBMITTED_DATE, NVL(COMPLETED_DATE, SYSTIMESTAMP)
                   FROM DMT_PIPELINE_RUN_TBL WHERE RUN_ID = :1""", [run_id])
    row = cur.fetchone()
    if not row:
        result['failures'].append(f"RUN_ID {run_id} not found in DMT_PIPELINE_RUN_TBL")
        return result
    run_status, pipeline_codes, scenario, run_mode, prefix, run_err, t_start, t_end = row
    result.update(run_status=run_status, pipeline_codes=pipeline_codes,
                  scenario=scenario, run_mode=run_mode, prefix=prefix)
    print(f"\n=== Evaluating RUN_ID={run_id} ({pipeline_codes} / {scenario} / {run_mode} / prefix {prefix}) ===")
    print(f"  RUN_STATUS = {run_status}")

    if run_status not in ('COMPLETED', 'COMPLETED_ERRORS'):
        result['failures'].append(f"RUN_STATUS={run_status}"
                                  + (f" | {str(run_err)[:200]}" if run_err else ''))

    # ---- 1. queue rollup -------------------------------------------------
    cur.execute("""SELECT CEMLI_CODE, WORK_STATUS, SUBSTR(ERROR_MESSAGE,1,300)
                   FROM DMT_WORK_QUEUE_TBL WHERE RUN_ID = :1 ORDER BY SORT_ORDER""", [run_id])
    queue = cur.fetchall()
    print(f"\n[1] Queue: {len(queue)} objects")
    for cemli, wstatus, werr in queue:
        result['objects'][cemli] = {'queue_status': wstatus, 'queue_error': werr}
        if wstatus == 'FAILED':
            result['failures'].append(f"queue FAILED: {cemli} — {werr or '(no error message)'}")
            print(f"    FAIL  {cemli}: {wstatus} — {str(werr)[:120]}")
        elif wstatus not in TERMINAL_QUEUE_STATUSES:
            result['failures'].append(f"queue stuck: {cemli} left in {wstatus}")
            print(f"    FAIL  {cemli}: stuck in {wstatus}")
        elif wstatus == 'SKIPPED':
            result['review'].append(f"queue SKIPPED: {cemli} (dependency failed upstream)")
            print(f"    warn  {cemli}: SKIPPED")

    # ---- 2. record-level verdicts ---------------------------------------
    cur.execute("""SELECT CEMLI_CODE, SUB_OBJECT, DISPLAY_KEY, STATUS,
                          DBMS_LOB.SUBSTR(ERROR_TEXT, 300, 1)
                   FROM DMT_RECORD_DETAIL_V WHERE RUN_ID = :1""", [run_id])
    records = cur.fetchall()
    per_obj = {}
    for cemli, sub, key, status, err in records:
        s = per_obj.setdefault(sub, {'cemli': cemli, 'LOADED': 0, 'FAILED': 0, 'OTHER': 0,
                                     'good_loaded': 0, 'good_failed': 0,
                                     'bad_loaded': 0, 'bad_failed': 0,
                                     'bad_loaded_keys': {}, 'good_failed_keys': {},
                                     'no_error_keys': {}, 'other_keys': {}})
        bad = is_bad_key(key)
        err_txt = ' '.join(str(err or '').split())  # collapse newlines
        if status == 'LOADED':
            s['LOADED'] += 1
            s['bad_loaded' if bad else 'good_loaded'] += 1
            if bad:
                s['bad_loaded_keys'][key] = s['bad_loaded_keys'].get(key, 0) + 1
        elif status == 'FAILED':
            s['FAILED'] += 1
            s['bad_failed' if bad else 'good_failed'] += 1
            if not err_txt:
                s['no_error_keys'][key] = s['no_error_keys'].get(key, 0) + 1
            if not bad:
                prev = s['good_failed_keys'].get(key)
                s['good_failed_keys'][key] = (prev[0] + 1, prev[1]) if prev else (1, err_txt[:160])
        else:
            s['OTHER'] += 1
            s['other_keys'][key] = status

    print(f"\n[2] Records: {len(records)} rows across {len(per_obj)} sub-objects "
          f"(good rows must LOAD, bad-marker rows must FAIL)")
    for sub in sorted(per_obj):
        s = per_obj[sub]
        flags = []
        if s['good_failed']:
            flags.append(f"{s['good_failed']} GOOD-FAILED")
        if s['bad_loaded']:
            flags.append(f"{s['bad_loaded']} BAD-LOADED")
        if s['no_error_keys']:
            flags.append(f"{sum(s['no_error_keys'].values())} no-error-text")
        marker = 'FAIL ' if flags else '     '
        print(f"    {marker}{sub:35s} {s['LOADED']}L/{s['FAILED']}F"
              + (f"/{s['OTHER']}other" if s['OTHER'] else '')
              + ('   <- ' + ', '.join(flags) if flags else ''))

    # aggregate failures: one entry per sub-object per category, samples inline
    def sample(d, n=3):
        items = list(d.items())[:n]
        more = f" (+{len(d) - n} more keys)" if len(d) > n else ''
        return '; '.join(f"{k} x{v[0]} — {v[1]}" if isinstance(v, tuple) else f"{k} x{v}"
                         for k, v in items) + more

    for sub in sorted(per_obj):
        s = per_obj[sub]
        if s['good_failed_keys']:
            result['failures'].append(
                f"GOOD rows FAILED: {sub} ({s['good_failed']} rows, "
                f"{len(s['good_failed_keys'])} keys): {sample(s['good_failed_keys'])}")
        if s['bad_loaded_keys']:
            result['failures'].append(
                f"BAD rows LOADED (validation gap): {sub}: {sample(s['bad_loaded_keys'])}")
        if s['no_error_keys']:
            result['failures'].append(
                f"FAILED rows with EMPTY error text: {sub}: {sample(s['no_error_keys'])}")
        for key, status in s['other_keys'].items():
            result['failures'].append(f"row in non-terminal status {status}: {sub} / {key}")
    result['record_rollup'] = {
        k: {x: v[x] for x in ('LOADED', 'FAILED', 'OTHER',
                              'good_loaded', 'good_failed', 'bad_loaded', 'bad_failed')}
        for k, v in per_obj.items()}
    result['record_detail'] = {
        k: {'good_failed_keys': {kk: list(vv) for kk, vv in v['good_failed_keys'].items()},
            'bad_loaded_keys': v['bad_loaded_keys']}
        for k, v in per_obj.items()
        if v['good_failed_keys'] or v['bad_loaded_keys']}

    # DONE queue objects with zero records
    cemlis_with_records = {v['cemli'] for v in per_obj.values()}
    for cemli, wstatus, _ in queue:
        if wstatus == 'DONE' and cemli not in cemlis_with_records:
            result['review'].append(f"DONE with zero records: {cemli} (no staged regression data?)")
            print(f"    warn  {cemli}: DONE but no records in DMT_RECORD_DETAIL_V")

    # ---- 3. log sweep -----------------------------------------------------
    print(f"\n[3] DMT_LOG_TBL sweep for run {run_id}")
    cur.execute("""SELECT LOG_TYPE, PACKAGE_NAME, PROCEDURE_NAME,
                          DBMS_LOB.SUBSTR(MESSAGE, 250, 1), SUBSTR(SQLERRM_TEXT,1,200)
                   FROM DMT_LOG_TBL WHERE RUN_ID = :1 AND LOG_TYPE <> 'INFO'
                   ORDER BY LOG_ID""", [run_id])
    log_errors = log_warns = malformed = 0
    err_groups, malformed_groups = {}, {}
    for ltype, pkg, proc, msg, sqlerrm in cur.fetchall():
        loc = f"{pkg}.{proc}"
        msg1 = ' '.join(str(msg or '').split())
        if ltype == 'ERROR':
            log_errors += 1
            gkey = (loc, msg1[:100])
            g = err_groups.setdefault(gkey, [0, sqlerrm])
            g[0] += 1
        elif ltype == 'WARN':
            log_warns += 1
        elif ltype not in KNOWN_LOG_TYPES:
            # LOG() called with swapped arguments — package name landed in LOG_TYPE
            malformed += 1
            g = malformed_groups.setdefault(ltype, [0, f"{loc}: {msg1[:80]}"])
            g[0] += 1
    for (loc, msg1), (n, sqlerrm) in err_groups.items():
        result['review'].append(f"LOG ERROR x{n}: {loc}: {msg1}"
                                + (f" | {' '.join(str(sqlerrm).split())}" if sqlerrm else ''))
    for ltype, (n, samp) in malformed_groups.items():
        result['review'].append(f"LOG malformed LOG_TYPE '{ltype}' x{n} (swapped LOG args) e.g. {samp}")
    # ERROR rows written without a run_id during the run window
    cur.execute("""SELECT COUNT(*) FROM DMT_LOG_TBL
                   WHERE RUN_ID IS NULL AND LOG_TYPE = 'ERROR'
                     AND LOG_DATE BETWEEN CAST(:1 AS DATE) AND CAST(:2 AS DATE)""",
                [t_start, t_end])
    orphan_errors = cur.fetchone()[0]
    if orphan_errors:
        result['review'].append(f"{orphan_errors} ERROR log rows with NULL run_id during the run window")
    print(f"    {log_errors} ERROR, {log_warns} WARN, {malformed} malformed LOG_TYPE, "
          f"{orphan_errors} orphan ERRORs in window")
    result['log_counts'] = {'error': log_errors, 'warn': log_warns,
                            'malformed': malformed, 'orphan_error': orphan_errors}

    # ---- 4. scheduler job failures (uncaught exceptions) -------------------
    print(f"\n[4] DBMS_SCHEDULER failures in run window")
    cur.execute("""SELECT JOB_NAME, STATUS, SUBSTR(ADDITIONAL_INFO,1,250)
                   FROM USER_SCHEDULER_JOB_RUN_DETAILS
                   WHERE JOB_NAME LIKE 'DMT%' AND STATUS <> 'SUCCEEDED'
                     AND LOG_DATE BETWEEN :1 AND :2""", [t_start, t_end])
    job_fails = cur.fetchall()
    for jname, jstatus, jinfo in job_fails:
        result['failures'].append(f"scheduler job {jname} {jstatus}: {jinfo}")
        print(f"    FAIL  {jname}: {jstatus} — {str(jinfo)[:120]}")
    if not job_fails:
        print("    OK    no failed DMT jobs in window")

    # ---- 5. baseline diff ---------------------------------------------------
    baseline_id = resolve_baseline(cur, run_id, baseline_arg, scenario, pipeline_codes)
    if baseline_id:
        print(f"\n[5] Baseline diff vs RUN_ID={baseline_id} (GOOD/BAD-aware: a regression is "
              f"fewer good rows loading, more good rows failing, or more bad rows loading)")
        cur.execute("""SELECT SUB_OBJECT, DISPLAY_KEY, STATUS FROM DMT_RECORD_DETAIL_V
                       WHERE RUN_ID = :1""", [baseline_id])
        base = {}
        for sub, key, status in cur.fetchall():
            b = base.setdefault(sub, {'good_loaded': 0, 'good_failed': 0,
                                      'bad_loaded': 0, 'bad_failed': 0, 'total': 0})
            b['total'] += 1
            bad = is_bad_key(key)
            if status == 'LOADED':
                b['bad_loaded' if bad else 'good_loaded'] += 1
            elif status == 'FAILED':
                b['bad_failed' if bad else 'good_failed'] += 1
        result['baseline'] = baseline_id
        regressions = []
        for sub in sorted(set(per_obj) | set(base)):
            was = base.get(sub)
            if not was or was['total'] == 0:
                continue  # no baseline coverage — new data is not a regression
            now = per_obj.get(sub, {'good_loaded': 0, 'good_failed': 0, 'bad_loaded': 0})
            deltas = []
            if now['good_loaded'] < was['good_loaded']:
                deltas.append(f"good LOADED {was['good_loaded']}->{now['good_loaded']}")
            if now['good_failed'] > was['good_failed']:
                deltas.append(f"good FAILED {was['good_failed']}->{now['good_failed']}")
            if now['bad_loaded'] > was['bad_loaded']:
                deltas.append(f"bad LOADED {was['bad_loaded']}->{now['bad_loaded']}")
            if deltas:
                regressions.append(f"{sub}: " + ', '.join(deltas))
                print(f"    REGRESSION  {sub}: " + ', '.join(deltas))
        for r in regressions:
            result['failures'].append(f"baseline regression vs run {baseline_id}: {r}")
        if not regressions:
            print(f"    OK    no sub-object regressed vs run {baseline_id}")
        result['baseline_regressions'] = regressions
    else:
        print("\n[5] Baseline diff skipped (no comparable prior run)")

    conn.close()
    return result


def resolve_baseline(cur, run_id, baseline_arg, scenario, pipeline_codes):
    if baseline_arg == 'none':
        return None
    if baseline_arg and baseline_arg != 'auto':
        return int(baseline_arg)
    cur.execute("""SELECT MAX(RUN_ID) FROM DMT_PIPELINE_RUN_TBL
                   WHERE RUN_ID < :1 AND SCENARIO_NAME = :2 AND PIPELINE_CODES = :3
                     AND RUN_STATUS IN ('COMPLETED', 'COMPLETED_ERRORS')""",
                [run_id, scenario, pipeline_codes])
    row = cur.fetchone()
    return int(row[0]) if row and row[0] else None


# ---------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description='DMT full-regression runner')
    ap.add_argument('--pipelines', default=DEFAULT_PIPELINES)
    ap.add_argument('--scenario', default=SCENARIO)
    ap.add_argument('--run-mode', default='ALL', choices=['ALL', 'NEW', 'FAILED'])
    ap.add_argument('--on-failure', default='CONTINUE', choices=['CONTINUE', 'HALT'])
    ap.add_argument('--timeout-min', type=int, default=90)
    ap.add_argument('--stall-min', type=int, default=20)
    ap.add_argument('--status-only', type=int, metavar='RUN_ID',
                    help='skip submit/wait; evaluate an existing run')
    ap.add_argument('--baseline', default='auto',
                    help="'auto' (default), 'none', or an explicit RUN_ID")
    ap.add_argument('--json', metavar='PATH', help='write machine-readable summary')
    args = ap.parse_args()

    if args.status_only:
        run_id = args.status_only
    else:
        print(f"Submitting regression run: pipelines={args.pipelines} "
              f"scenario={args.scenario} mode={args.run_mode} on_failure={args.on_failure}")
        run_id = submit_run(args.pipelines, args.scenario, args.run_mode, args.on_failure)
        print(f"\nWaiting for RUN_ID={run_id} (timeout {args.timeout_min} min)...")
        final = wait_for_run(run_id, args.timeout_min, args.stall_min)
        if not final:
            print(f"\nTIMED OUT after {args.timeout_min} min — evaluating partial state")

    result = evaluate(run_id, args.baseline)

    print(f"\n{'=' * 70}")
    n_fail, n_rev = len(result['failures']), len(result['review'])
    verdict = 'PASS' if n_fail == 0 and n_rev == 0 else \
              ('PASS (with review items)' if n_fail == 0 else 'FAIL')
    print(f"VERDICT: {verdict} — RUN_ID={run_id}: {n_fail} failure(s), {n_rev} review item(s)")
    print('=' * 70)
    for f in result['failures']:
        print(f"  FAIL    {f}")
    for r in result['review']:
        print(f"  REVIEW  {r}")
    result['verdict'] = verdict

    if args.json:
        with open(args.json, 'w', encoding='utf-8') as fh:
            json.dump(result, fh, indent=2, default=str)
        print(f"\nJSON summary written to {args.json}")

    sys.exit(0 if n_fail == 0 and n_rev == 0 else (2 if n_fail == 0 else 1))


if __name__ == '__main__':
    main()
