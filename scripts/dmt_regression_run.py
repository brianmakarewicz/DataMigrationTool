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
       - rows whose DISPLAY_KEY carries a bad-seed marker, or that were
         rejected before transform (a [PRE_VALIDATION] orphan skip), are
         BAD-row outcomes -> must be FAILED (never counted good-failed)
       - all other rows                                   -> must be LOADED
       - every FAILED row must have non-empty ERROR_TEXT
       - rows the scenario lists in scripts/regression_scenario.json
         "expected_outcomes" are judged against that list instead of the
         key markers: LOADED, FAILED (own error), or FAILED_WITH_DOCUMENT
         (FAILED because Fusion rejected its whole document; ERROR_TEXT must
         contain "Rejected with document:" -- design section 5, whole-document
         rejection). LOADED / UNACCOUNTED / missing marker for such a row fails.
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

Exit codes: 0 = no NEW issues (verdict PASS, or 'PASS (no new failures; N known)' when
every failure and review item is a known pre-existing one listed in
scripts/regression_known_issues.json - owner decision 2026-10-08), 1 = NEW hard
failures, 2 = no new failures but NEW review items (log errors / warnings needing triage).

Submission goes only through DMT_SCHEDULER_PKG.SUBMIT_PIPELINE (bounded connect,
90s call timeout), so the one-active-run-per-object guard (ORA-20105) and every
other submit check always apply. The old inline-insert fallback was removed
(backlog #637): in 68 logged submissions it never fired on a hang, only on three
ORA-20105 refusals, each of which it bypassed (runs 318, 325, 332). A refusal or
timeout now stops the harness; it never creates a run by itself.
"""
import argparse
import datetime
import io
import json
import re
import sys
import time

import os
import oracledb

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dmt_db_connect import connect_with_retry, retry_db  # noqa: E402

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace',
                              line_buffering=True)
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace',
                              line_buffering=True)

DEFAULT_PIPELINES = 'P2P,O2C,FINANCIALS,PROJECTS,HCM'   # run 113 reference set


def _current_scenario():
    """The current write-once regression scenario, read from the git-tracked
    pointer scripts/regression_scenario.json (written by deploy_scenario.py).
    We ALWAYS run the current write-once scenario with a new prefix; we never
    reseed. Falls back to the legacy 'RegressionTest' only if the pointer is
    missing (e.g. a brand-new checkout before the first deploy). Scenario 1
    ('RegressionTest') is the permanently-polluted, abandoned scenario -- the
    pointer keeps runs off it. See docs / never_reseed_writeonce_scenarios."""
    try:
        p = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                         'regression_scenario.json')
        with open(p, encoding='utf-8') as f:
            name = json.load(f).get('current_scenario')
        return name or 'RegressionTest'
    except Exception:
        return 'RegressionTest'


SCENARIO = _current_scenario()

# Expected outcome vocabulary for rows listed in regression_scenario.json
# "expected_outcomes" (per scenario -> sub-object -> STG SOURCE_ID).
EXPECT_LOADED = 'LOADED'
EXPECT_FAILED = 'FAILED'
EXPECT_DOC = 'FAILED_WITH_DOCUMENT'
EXPECTED_VALUES = (EXPECT_LOADED, EXPECT_FAILED, EXPECT_DOC)
# The fixed text DMT_UTIL_PKG.C_DOC_ERROR_MARKER puts in a quoted document error.
DOC_ERROR_MARKER = 'Rejected with document:'
_STG_IDENT = re.compile(r'^DMT_[A-Z0-9_]+_STG_TBL$')
_COL_IDENT = re.compile(r'^[A-Z][A-Z0-9_]{0,29}$')


def _key_col(d):
    """The STG column a listed sub-object's rows are keyed by: 'key_col' when the
    spec gives one (a child whose SOURCE_ID is its parent link, e.g. MiscReceipts
    lots/serials), else SOURCE_ID."""
    return d.get('key_col') or 'SOURCE_ID'


def load_expected_outcomes(scenario):
    """{sub_object: {'stg_table': ..., 'rows': {SOURCE_ID: outcome}}} for the
    scenario, from scripts/regression_scenario.json "expected_outcomes". Empty
    when the scenario lists none (then the key-marker heuristic decides)."""
    p = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'regression_scenario.json')
    try:
        with open(p, encoding='utf-8') as f:
            spec = (json.load(f).get('expected_outcomes') or {}).get(scenario) or {}
    except (OSError, ValueError):
        return {}
    for sub, d in spec.items():
        if not _STG_IDENT.match(d.get('stg_table', '')):
            sys.exit(f"regression_scenario.json: bad stg_table for {sub!r}: {d.get('stg_table')!r}")
        if not _COL_IDENT.match(_key_col(d)):
            sys.exit(f"regression_scenario.json: bad key_col for {sub!r}: {d.get('key_col')!r}")
        for src, outcome in d.get('rows', {}).items():
            if outcome not in EXPECTED_VALUES:
                sys.exit(f"regression_scenario.json: {sub}/{src}: outcome {outcome!r} "
                         f"not one of {EXPECTED_VALUES}")
    return spec


def resolve_expectations(cur, spec, records):
    """Map (SUB_OBJECT, STG_SEQUENCE_ID) -> (SOURCE_ID, expected outcome) for the
    run's records (tuples: cemli, sub_object, ..., stg_sequence_id at index 5),
    reading SOURCE_ID (or the spec's key_col) from each listed STG table. Also returns the listed rows
    of sub-objects present in the run that have no record in it."""
    exp, missing = {}, []
    present_subs = {r[1] for r in records}
    for sub, d in spec.items():
        if sub not in present_subs:
            continue
        seqs = [r[5] for r in records if r[1] == sub and r[5] is not None]
        found = set()
        for i in range(0, len(seqs), 500):
            chunk = seqs[i:i + 500]
            binds = ','.join(f':{n + 1}' for n in range(len(chunk)))
            cur.execute(f"SELECT STG_SEQUENCE_ID, {_key_col(d)} FROM {d['stg_table']} "
                        f"WHERE STG_SEQUENCE_ID IN ({binds})", chunk)
            for seq, src in cur.fetchall():
                if src in d['rows']:
                    exp[(sub, seq)] = (src, d['rows'][src])
                    found.add(src)
        missing += [f"{sub} / {src}" for src in d['rows'] if src not in found]
    return exp, missing
# CANCELLED restored 2026-10-08 (backlog #635): DMT_QUEUE_PKG.CANCEL_RUN ends a run
# and its open work items CANCELLED. Terminal, but never a pass (evaluate() fails
# any run that is not COMPLETED / COMPLETED_ERRORS and any CANCELLED work item).
TERMINAL_RUN_STATUSES = {'COMPLETED', 'COMPLETED_ERRORS', 'FAILED', 'NO_ROWS_PROCESSED', 'CANCELLED'}
TERMINAL_QUEUE_STATUSES = {'DONE', 'FAILED', 'SKIPPED', 'CANCELLED'}
KNOWN_LOG_TYPES = {'INFO', 'WARN', 'ERROR', 'DEBUG'}

# Markers identifying intentionally-bad seed rows in DISPLAY_KEY. The seed
# script (insert_regression_test_data.py) names bad rows with 'BAD' in the
# business key, but some objects use other conventions: descriptive keys
# ('DOES NOT EXIST SUPPLIER - Ghost HQ' for [BAD-UPS]), FAKE_* lookup values,
# or -B{n} / -G{n} suffixes (Items: DMT-PLAIN-B6 = bad, DMT-PLAIN-G6 = good).
BAD_KEY_MARKERS = ('BAD', 'DOES NOT EXIST', 'GHOST', 'NONEXIST', 'INVALID', 'FAKE')
BAD_KEY_REGEX = re.compile(r'-B\d+\b')

# A row rejected before it ever reached a transform table is surfaced by
# DMT_RECORD_DETAIL_V with a synthesized DISPLAY_KEY of the form
# '<Sub Object> STG#<n>' that carries NO business key, so the bad-seed marker
# that normally lives in the key is not present. Such rows are intentional
# pre-validation skips (e.g. a supplier Address/Site/Contact whose parent
# supplier has no LOADED TFM row -- the classic intentional-orphan bad seed,
# or a child orphaned by a failed parent). They are always a BAD/expected
# FAILED outcome, never a good row that should have loaded, so they must bucket
# BAD regardless of the DISPLAY_KEY. They are recognized by their ERROR_TEXT
# category, which is the bracketed token at the start of the message
# (e.g. '[PRE_VALIDATION] Supplier ... has no LOADED TFM row ... skipped.').
PREVALIDATION_BAD_CATEGORIES = ('PRE_VALIDATION',)


def connect(call_timeout_ms=120_000):
    """Connect with a bounded connect (tcp_connect_timeout + overall deadline),
    keepalive (expire_time), retries with backoff, and a finite call_timeout.
    Runs 293 and 338 hung forever in an unbounded python-oracledb connect."""
    # DMT2 is Docker-only (CLAUDE.md: no ATP yet). Honor DMT2_CONN
    # (user/password@host:port/service) like scripts/deploy_recon_bip_reports.py;
    # fall back to the local Docker instance. The old connect_atp('queryapp')
    # target is the frozen stack's ATP and is wrong for DMT2.
    conn_str = os.environ.get('DMT2_CONN', 'dmt_owner/DmtLocal#2026@localhost:1523/FREEPDB1')
    m = re.match(r'^([^/]+)/(.+)@(?://)?(.+)$', conn_str)
    if not m:
        sys.exit(f"Cannot parse DMT2_CONN: {conn_str!r}")
    user, password, dsn = m.groups()
    import os as _os
    _w = _os.environ.get('DMT2_WALLET')
    _kw = dict(config_dir=_w, wallet_location=_w, wallet_password=_os.environ.get('DMT2_WALLET_PW')) if _w else {}
    return connect_with_retry(call_timeout_ms=call_timeout_ms,
                              user=user, password=password, dsn=dsn, **_kw)


def is_bad_key(display_key):
    k = (display_key or '').upper()
    return any(m in k for m in BAD_KEY_MARKERS) or bool(BAD_KEY_REGEX.search(k))


def is_bad_row(display_key, error_text=None):
    """True when a row is an intentional BAD-seed / expected-failure outcome.

    Classification (either is sufficient):
      1. the DISPLAY_KEY carries a bad-seed marker (the normal case), or
      2. the row was rejected before transform (its ERROR_TEXT category is
         [PRE_VALIDATION]): an intentional orphan or a child cascaded off a
         parent that never loaded. A child is skipped pre-transform ONLY
         because its parent has no LOADED TFM row, so this is always an
         expected FAILED outcome, never a good row that should have loaded.
         (If the parent failed because of a real regression, the parent's own
         row carries that regression, so no signal is lost by trusting the
         child skip as BAD.)

    We deliberately do NOT scan the free-form ERROR_TEXT for the bad-seed
    markers: words like INVALID / BAD / DOES NOT EXIST appear in real Fusion
    rejection messages for genuinely-good rows, so matching them in the error
    text would reclassify a real good-row failure as BAD and hide a true
    regression. The bad-seed markers are only trusted inside the DISPLAY_KEY
    (a short synthetic key we control). The orphan case the markers were meant
    to rescue is already covered by the [PRE_VALIDATION] category above.
    """
    if is_bad_key(display_key):
        return True
    cat = re.match(r'\s*\[([^\]]+)\]', (error_text or '').upper())
    return bool(cat and cat.group(1).strip() in PREVALIDATION_BAD_CATEGORIES)


# ---------------------------------------------------------------------------
# Submit
# ---------------------------------------------------------------------------

def submit_run(pipelines, scenario, run_mode, on_failure):
    """Submit via DMT_SCHEDULER_PKG.SUBMIT_PIPELINE only (backlog #637).

    The package is the single submission path, so its one-active-run-per-object
    guard (ORA-20105, design section 2) and its other checks always apply. Any
    error stops the harness: a refusal names the run that holds the object, and
    a timeout is never followed by a second, hand-built run (the call may have
    committed; check DMT_PIPELINE_RUN_TBL before resubmitting)."""
    conn = connect(90_000)  # ms - bounded connect + finite call timeout (#705)
    cur = conn.cursor()
    run_id_var = cur.var(oracledb.NUMBER)
    try:
        # Keyword binds (position-independent): SUBMIT_PIPELINE gained the two
        # Backlog #142 IN params (p_dependent_prefix, p_validate_upstream) ahead
        # of the OUT x_run_id, so a positional 6-arg call would bind run_id_var to
        # p_dependent_prefix and leave x_run_id unbound. The harness takes the
        # package defaults for both new params (dependent-prefix auto, upstream
        # validation off), exactly as the regression always ran.
        cur.callproc('DMT_SCHEDULER_PKG.SUBMIT_PIPELINE',
                     keyword_parameters={
                         'p_pipeline_codes': pipelines,
                         'p_scenario_name': scenario,
                         'p_run_mode': run_mode,
                         'p_on_failure': on_failure,
                         'p_submitted_by': 'REGRESSION_AGENT',
                         'x_run_id': run_id_var,
                     })
        run_id = int(run_id_var.getvalue())
        print(f"  SUBMIT_PIPELINE ok -> RUN_ID={run_id}")
    except Exception as e:
        msg = ' '.join(str(e).split())
        if 'ORA-20105' in msg:
            raise SystemExit(f"SUBMIT_PIPELINE refused the run: {msg[:300]}. "
                             f"Wait for (or cancel with DMT_QUEUE_PKG.CANCEL_RUN) the run "
                             f"that holds the object; the harness never bypasses this guard.")
        raise SystemExit(f"SUBMIT_PIPELINE failed: {msg[:300]}. "
                         f"No run was created by the harness. If this was a timeout, check "
                         f"DMT_PIPELINE_RUN_TBL for a REGRESSION_AGENT run before resubmitting.")
    finally:
        try:
            conn.close()
        except Exception:
            pass
    # The run exists now: a poller problem is retried by ensure_poller, never
    # answered with a second run. Never call_timeout=0.
    ensure_poller()
    return run_id


def ensure_poller():
    """Enable the queue poller on a fresh connection with a finite call
    timeout, retried on a DB error / timeout."""
    def _once():
        conn = connect(120_000)
        try:
            conn.cursor().callproc('DMT_QUEUE_PKG.ENSURE_POLLER_RUNNING')
        finally:
            conn.close()
    retry_db(_once, what='ENSURE_POLLER_RUNNING')
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
    poll_errors = 0
    while time.time() < deadline:
        try:
            run_status, cur_cemli, cur_step, qmap = _poll_once(run_id)
            poll_errors = 0
        except Exception as e:
            # One failed poll (connect timeout, call timeout, dropped session)
            # is retried on the next tick, never fatal; the deadline still ends it.
            poll_errors += 1
            stamp = datetime.datetime.now().strftime('%H:%M:%S')
            print(f"  [{stamp}] poll failed ({poll_errors} in a row): {str(e)[:160]} — retrying",
                  flush=True)
            time.sleep(min(45, 10 * poll_errors))
            continue

        snapshot = (run_status, tuple(sorted(qmap.items())))
        stamp = datetime.datetime.now().strftime('%H:%M:%S')
        if snapshot != last_snapshot:
            qtxt = ' '.join(f"{k}={v}" for k, v in sorted(qmap.items()))
            step = f" @ {cur_cemli}/{cur_step}" if cur_cemli else ''
            print(f"  [{stamp}] {run_status}{step} | {qtxt}", flush=True)
            last_snapshot, last_change = snapshot, time.time()
        elif time.time() - last_change > stall_min * 60:
            print(f"  [{stamp}] WARNING: no state change in {stall_min} min "
                  f"(status={run_status}) — possible stall", flush=True)
            last_change = time.time()  # only warn once per stall interval

        non_terminal_q = sum(v for k, v in qmap.items() if k not in TERMINAL_QUEUE_STATUSES)
        if run_status in TERMINAL_RUN_STATUSES and non_terminal_q == 0:
            final_status = run_status
            break
        time.sleep(45)
    return final_status


def _poll_once(run_id):
    """One status read on a fresh, time-bounded connection."""
    conn = connect(60_000)
    try:
        cur = conn.cursor()
        cur.execute("""SELECT RUN_STATUS, CURRENT_CEMLI, CURRENT_STEP
                       FROM DMT_PIPELINE_RUN_TBL WHERE RUN_ID = :1""", [run_id])
        row = cur.fetchone()
        run_status, cur_cemli, cur_step = row if row else ('MISSING', None, None)
        cur.execute("""SELECT WORK_STATUS, COUNT(*) FROM DMT_WORK_QUEUE_TBL
                       WHERE RUN_ID = :1 GROUP BY WORK_STATUS ORDER BY 1""", [run_id])
        qmap = dict(cur.fetchall())
    finally:
        conn.close()
    return run_status, cur_cemli, cur_step, qmap


# ---------------------------------------------------------------------------
# Evaluate
# ---------------------------------------------------------------------------

def rest_spot_check(cur, run_id, result):
    """Step 6 — replicate the page-57 "Verify in Fusion" button, once per object.

    Mirrors exactly what the UI does when a user clicks Verify on a Record
    Detail row (app process QUERY_FUSION_REST):

        1. Take the object display catalog (DMT_V_CEMLI_TFM_TABLES) — the list
           of objects and the TFM table behind each sub-object.
        2. For each, take the most recent successful (LOADED) row in this run.
        3. Call the SAME API the button calls —
           DMT_REST_QUERY_PKG.QUERY_FUSION_RECORD(sub_object, display_key,
           tfm_seq_id, lookup_key||display_key) — which makes a live REST call
           to the demo Fusion instance and returns the record.

    This is one live read-back per object/TFM-table, not per-row reconciliation:
    bulk per-row confirmation that every migrated row reached a Fusion base
    table is the BIP reconciler's job (it sets each TFM row LOADED/FAILED). A
    non-FOUND here is recorded as a REVIEW item, not a hard failure, because it
    can mean the REST lookup for that object is unconfigured or misconfigured
    (e.g. the button passes the sub-object label while DMT_REST_LOOKUP_TBL is
    keyed by object code) rather than a migration defect — surfacing exactly
    that is the point."""
    print("\n[6] REST verify spot-check — same call as the page-57 button, one per object/TFM table")
    cur.execute("""
        WITH latest AS (
            SELECT rd.CEMLI_CODE, rd.SUB_OBJECT, rd.DISPLAY_KEY, rd.LOOKUP_KEY,
                   rd.TFM_SEQUENCE_ID,
                   ROW_NUMBER() OVER (PARTITION BY rd.CEMLI_CODE, rd.SUB_OBJECT
                                      ORDER BY rd.RUN_ID DESC, rd.TFM_SEQUENCE_ID DESC) rn
            FROM   DMT_RECORD_DETAIL_V rd
            WHERE  (:rid IS NULL OR rd.RUN_ID = :rid)
              AND  rd.TFM_STATUS = 'LOADED'
        )
        SELECT c.CEMLI_CODE, c.DISPLAY_NAME AS sub_object, c.TFM_TABLE,
               l.DISPLAY_KEY, l.LOOKUP_KEY, l.TFM_SEQUENCE_ID
        FROM   DMT_V_CEMLI_TFM_TABLES c
        JOIN   latest l
               ON  l.CEMLI_CODE = c.CEMLI_CODE
               AND l.SUB_OBJECT = c.DISPLAY_NAME
               AND l.rn = 1
        ORDER BY c.CEMLI_CODE, c.SORT_ORDER
    """, rid=run_id)
    targets = cur.fetchall()
    spot = []
    result['rest_spotcheck'] = spot
    if not targets:
        print("    (no object/TFM table has a LOADED row in this run to verify)")
        return
    for cemli, sub_object, tfm_table, display_key, lookup_key, tfm_seq in targets:
        x04 = lookup_key or display_key          # button: x04 = lookupKey || dispKey
        status, detail = 'ERROR', None
        try:
            cur.execute(
                "SELECT DMT_REST_QUERY_PKG.QUERY_FUSION_RECORD(:1, :2, :3, :4) FROM DUAL",
                [sub_object, display_key, int(tfm_seq) if tfm_seq is not None else None, x04])
            raw = cur.fetchone()[0]
            doc_str = raw.read() if hasattr(raw, 'read') else raw
            try:
                doc = json.loads(doc_str) if doc_str else {}
            except Exception:
                doc = {}
            if doc.get('status') == 'ok' and doc.get('rows'):
                status, detail = 'FOUND', f"{len(doc['rows'])} field(s) from Fusion"
            elif doc.get('status') == 'not_applicable':
                # The registry records (with the proof in its reason) that Fusion
                # exposes no REST read resource for this object; BIP reconciliation
                # is the record-level proof. Reported, never a review item.
                status, detail = 'NOT_APPLICABLE', str(doc.get('message') or '')[:180]
            elif doc.get('status') == 'ok':
                status, detail = 'NO_DATA', 'Fusion returned no matching record'
            else:
                msg = str(doc.get('message') or doc_str or '')
                low = msg.lower()
                if 'no rest lookup' in low:
                    status = 'NOT_CONFIGURED'
                elif '404' in low or 'not found' in low or 'no rows' in low or 'no record' in low:
                    status = 'NOT_FOUND'
                else:
                    status = 'ERROR'
                detail = msg[:180]
        except Exception as e:
            status, detail = 'ERROR', str(e)[:180]
        spot.append({'cemli_code': cemli, 'sub_object': sub_object, 'tfm_table': tfm_table,
                     'key': x04, 'tfm_seq_id': int(tfm_seq) if tfm_seq is not None else None,
                     'status': status, 'detail': detail})
        flag = 'ok  ' if status == 'FOUND' else ('n/a ' if status == 'NOT_APPLICABLE' else 'MISS')
        print(f"    {flag} {cemli:<16} {sub_object:<22} {status:<14} key={x04}"
              + (f"  - {detail}" if detail else ''))
        if status not in ('FOUND', 'NOT_APPLICABLE'):
            result['review'].append(
                f"REST verify {cemli}/{sub_object}: {status}"
                + (f" ({detail})" if detail else ''))
    n_found = sum(1 for s in spot if s['status'] == 'FOUND')
    n_na = sum(1 for s in spot if s['status'] == 'NOT_APPLICABLE')
    print(f"    {n_found}/{len(spot) - n_na} object/TFM table(s) read back from Fusion via the button's REST call"
          + (f" ({n_na} not applicable: no Fusion REST read resource)" if n_na else ""))
    # Per-object roll-up: an object is "verified" if any of its sub-objects read back.
    # NOT_APPLICABLE sub-objects (no Fusion REST read resource) are left out of it.
    objs = {}
    for s in spot:
        if s['status'] == 'NOT_APPLICABLE':
            continue
        objs.setdefault(s['cemli_code'], False)
        if s['status'] == 'FOUND':
            objs[s['cemli_code']] = True
    verified = sorted(o for o, ok in objs.items() if ok)
    unverified = sorted(o for o, ok in objs.items() if not ok)
    print(f"    per-object: {len(verified)}/{len(objs)} verified in Fusion"
          + (f" | not yet: {', '.join(unverified)}" if unverified else ""))
    result['rest_verified_objects'] = verified
    result['rest_unverified_objects'] = unverified


def evaluate(run_id, baseline_arg):
    conn = connect(120_000)
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
        if wstatus in ('FAILED', 'CANCELLED'):
            result['failures'].append(f"queue {wstatus}: {cemli} — {werr or '(no error message)'}")
            print(f"    FAIL  {cemli}: {wstatus} — {str(werr)[:120]}")
        elif wstatus not in TERMINAL_QUEUE_STATUSES:
            result['failures'].append(f"queue stuck: {cemli} left in {wstatus}")
            print(f"    FAIL  {cemli}: stuck in {wstatus}")
        elif wstatus == 'SKIPPED':
            result['review'].append(f"queue SKIPPED: {cemli} (dependency failed upstream)")
            print(f"    warn  {cemli}: SKIPPED")

    # ---- 2. record-level verdicts ---------------------------------------
    cur.execute("""SELECT CEMLI_CODE, SUB_OBJECT, DISPLAY_KEY, TFM_STATUS,
                          DBMS_LOB.SUBSTR(ERROR_TEXT, 300, 1), STG_SEQUENCE_ID,
                          NVL(DBMS_LOB.INSTR(ERROR_TEXT, :marker), 0)
                   FROM DMT_RECORD_DETAIL_V WHERE RUN_ID = :run_id""", {"run_id": run_id, "marker": DOC_ERROR_MARKER})
    records = cur.fetchall()
    spec = load_expected_outcomes(scenario)
    expected, missing = resolve_expectations(cur, spec, records)
    if spec:
        print(f"\n[2a] Expected outcomes (scripts/regression_scenario.json, {scenario}): "
              f"{len(expected)} listed row(s) found in this run")
    if run_mode == 'FAILED':
        # FAILED mode retries only the rows whose latest earlier attempt ended
        # FAILED / UNACCOUNTED or died before TFM (backlog #310). A listed row that
        # is absent is correct when its latest earlier attempt LOADED; check the
        # selection itself against DMT_UTIL_PKG.FAILED_RETRY_SELECTED.
        missing = check_failed_mode_selection(cur, run_id, scenario, spec, records, missing, result)
    for m in missing:
        result['failures'].append(f"expected row not in run: {m}")
    expect_fail = {}
    per_obj = {}
    for cemli, sub, key, status, err, stg_seq, doc_pos in records:
        s = per_obj.setdefault(sub, {'cemli': cemli, 'LOADED': 0, 'FAILED': 0, 'OTHER': 0,
                                     'good_loaded': 0, 'good_failed': 0,
                                     'bad_loaded': 0, 'bad_failed': 0,
                                     'bad_loaded_keys': {}, 'good_failed_keys': {},
                                     'no_error_keys': {}, 'other_keys': {}})
        err_txt = ' '.join(str(err or '').split())  # collapse newlines
        exp = expected.get((sub, stg_seq))
        if exp:
            # A listed row: the scenario's expected outcome replaces the key-marker
            # heuristic, and its own check runs here.
            src, outcome = exp
            bad = outcome != EXPECT_LOADED
            problem = None
            if outcome == EXPECT_LOADED and status != 'LOADED':
                problem = f"expected LOADED, got {status}"
            elif outcome == EXPECT_FAILED and status != 'FAILED':
                problem = f"expected FAILED (own Fusion error), got {status}"
            elif outcome == EXPECT_DOC and status != 'FAILED':
                problem = f"expected FAILED with its document, got {status}"
            elif outcome == EXPECT_DOC and not doc_pos:
                problem = f"expected '{DOC_ERROR_MARKER}' in ERROR_TEXT, not found"
            if problem:
                expect_fail.setdefault(sub, []).append(f"{src}: {problem}")
        else:
            bad = is_bad_row(key, err_txt)
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

    for sub in sorted(expect_fail):
        result['failures'].append(f"EXPECTED OUTCOME not met: {sub}: " + '; '.join(expect_fail[sub]))
        print(f"    FAIL  expected outcome not met: {sub}: " + '; '.join(expect_fail[sub]))
    if spec and not expect_fail and not missing:
        print(f"    OK    all {len(expected)} listed row(s) met their expected outcome")

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
    if baseline_id and run_mode == 'FAILED':
        # A FAILED-mode run retries only the earlier failures, so its LOADED count
        # is not comparable with a full run; [2b] checked the selection instead.
        print(f"\n[5] Baseline diff skipped (FAILED-mode run: only earlier failures are "
              f"retried; selection checked in [2b])")
        baseline_id = None
    if baseline_id:
        print(f"\n[5] Baseline diff vs RUN_ID={baseline_id} (GOOD/BAD-aware: a regression is "
              f"fewer good rows loading, more good rows failing, or more bad rows loading)")
        cur.execute("""SELECT CEMLI_CODE, SUB_OBJECT, DISPLAY_KEY, TFM_STATUS,
                              DBMS_LOB.SUBSTR(ERROR_TEXT, 300, 1), STG_SEQUENCE_ID
                       FROM DMT_RECORD_DETAIL_V WHERE RUN_ID = :1""", [baseline_id])
        base_rows = cur.fetchall()
        base_expected, _ = resolve_expectations(cur, spec, base_rows)
        base = {}
        for _cemli, sub, key, status, err, stg_seq in base_rows:
            b = base.setdefault(sub, {'good_loaded': 0, 'good_failed': 0,
                                      'bad_loaded': 0, 'bad_failed': 0, 'total': 0})
            b['total'] += 1
            bexp = base_expected.get((sub, stg_seq))
            bad = (bexp[1] != EXPECT_LOADED) if bexp else is_bad_row(key, err)
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
    elif run_mode != 'FAILED':
        print("\n[5] Baseline diff skipped (no comparable prior run)")

    # ---- 6. REST spot-check: one live Fusion lookup per object type -------
    try:
        rest_spot_check(cur, run_id, result)
    except Exception as e:
        result['review'].append(f"REST spot-check could not run: {str(e)[:180]}")
        print(f"\n[6] REST spot-check skipped: {str(e)[:180]}")

    conn.close()
    return result


def check_failed_mode_selection(cur, run_id, scenario, spec, records, missing, result):
    """[2b] FAILED-mode selection check (backlog #310). For every sub-object the
    scenario lists (it names the STG table), the run's rows must be exactly the
    scenario's STG rows for which DMT_UTIL_PKG.FAILED_RETRY_SELECTED(run_id, ...)
    = 'Y' (latest attempt in an earlier run FAILED / UNACCOUNTED / pre-TFM error).
    Returns the listed-but-absent rows that SHOULD have been retried."""
    cur.execute("SELECT SCENARIO_ID FROM DMT_SCENARIO_TBL WHERE SCENARIO_NAME = :1", [scenario])
    row = cur.fetchone()
    print("\n[2b] FAILED-mode selection (must equal the rows whose latest earlier attempt failed)")
    if not row:
        result['failures'].append(f"FAILED-mode check: scenario {scenario} not found")
        return missing
    scen_id = row[0]
    still_missing = []
    present_subs = {r[1] for r in records}
    for sub, d in spec.items():
        if sub not in present_subs and not any(m.startswith(sub + ' / ') for m in missing):
            continue
        tbl = d['stg_table']
        cur.execute(f"SELECT STG_SEQUENCE_ID, {_key_col(d)}, "
                    f"DMT_UTIL_PKG.FAILED_RETRY_SELECTED(:r, :t, STG_SEQUENCE_ID) "
                    f"FROM {tbl} WHERE SCENARIO_ID = :s", {"r": run_id, "t": tbl, "s": scen_id})
        rows = cur.fetchall()
        want = {seq for seq, _src, pick in rows if pick == 'Y'}
        src_of = {seq: src for seq, src, _p in rows}
        got = {r[5] for r in records if r[1] == sub and r[5] is not None}
        extra, lacking = got - want, want - got
        print(f"    {'FAIL ' if (extra or lacking) else 'OK   '}{sub:35s} retry set {len(want)}, "
              f"in run {len(got)}, not-retried (latest earlier attempt LOADED or in flight) "
              f"{len(rows) - len(want)}")
        for seq in sorted(extra):
            result['failures'].append(f"FAILED mode picked a row whose latest earlier attempt "
                                      f"did not fail: {sub} / {src_of.get(seq, seq)}")
        for seq in sorted(lacking):
            result['failures'].append(f"FAILED mode skipped a row whose latest earlier attempt "
                                      f"failed: {sub} / {src_of.get(seq, seq)}")
        lacking_src = {f"{sub} / {src_of.get(s)}" for s in lacking}
        still_missing += [m for m in missing if m.startswith(sub + ' / ') and m in lacking_src]
    return still_missing


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
# Known pre-existing issues. Owner decision 2026-10-08: "change the gate - so that
# there are no NEW failures". scripts/regression_known_issues.json lists failures and
# review items that were already there and are accepted for now, matched on a stable
# category + object (+ sub) (+ key) only, never on volatile text (run prefixes, HTTP
# details, counts). Anything that cannot be keyed, or is not listed, is NEW and blocks.
# A sub-object that regressed against the step [5] baseline run is always NEW.

KNOWN_ISSUES_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                 'regression_known_issues.json')

# (category, regex, groups) - groups name what each regex group holds.
_ISSUE_PATTERNS = [
    ('ZERO_RECORDS',      r'DONE with zero records: (\S+)',                    ('object',)),
    ('REST_VERIFY',       r'REST verify ([^/:]+)/(.+?): [A-Z_]+\b',             ('object', 'sub')),
    ('QUEUE_FAILED',      r'queue FAILED: (\S+)',                              ('object',)),
    ('QUEUE_STUCK',       r'queue stuck: (\S+) left in ',                      ('object',)),
    ('EXPECTED_OUTCOME',  r'EXPECTED OUTCOME not met: (.+?): ',                ('sub',)),
    ('GOOD_ROWS_FAILED',  r'GOOD rows FAILED: (.+?) \(\d+ rows',               ('sub',)),
    ('BAD_ROWS_LOADED',   r'BAD rows LOADED \(validation gap\): (.+?): ',      ('sub',)),
    ('EMPTY_ERROR_TEXT',  r'FAILED rows with EMPTY error text: (.+?): ',       ('sub',)),
    ('NON_TERMINAL_ROW',  r'row in non-terminal status \S+: (.+?) / (.+)$',    ('sub', 'key')),
]


def issue_key(item, prefix=None):
    """dict(category, object, sub, key) for a failure/review string, or None when it
    has no stable key (e.g. baseline regressions, run status) - those are always NEW.
    A row key has the run prefix stripped so it is stable across runs."""
    for cat, rx, groups in _ISSUE_PATTERNS:
        m = re.match(rx, item)
        if m:
            k = {'category': cat, 'object': None, 'sub': None, 'key': None}
            k.update(zip(groups, m.groups()))
            if k['key'] and prefix and k['key'].startswith(str(prefix)):
                k['key'] = k['key'][len(str(prefix)):]
            return k
    return None


def _regressed_subs(baseline_regressions):
    """Sub-object names step [5] reported as regressed ("<sub>: good LOADED 3->1")."""
    return {r.split(': ', 1)[0] for r in (baseline_regressions or [])}


def classify_issues(items, kind, prefix=None, regressed_subs=(), entries=None):
    """Split failures (kind 'FAIL') or review items (kind 'REVIEW') into
    (known, new, matched_entry_indexes). An entry matches when its kind and category
    agree and every one of object/sub/key it names is equal; it must name at least
    an object or a sub. A known item whose sub-object regressed vs the baseline is NEW."""
    if entries is None:
        entries = load_known_issues()
    known, new, hit = [], [], set()
    for it in items:
        k = issue_key(it, prefix)
        idx = []
        if k is not None and not (k['sub'] and k['sub'] in regressed_subs):
            for i, e in enumerate(entries):
                if (e.get('kind', 'REVIEW') == kind and e.get('category') == k['category']
                        and (e.get('object') or e.get('sub'))
                        and all(e.get(f) is None or e.get(f) == k[f]
                                for f in ('object', 'sub', 'key'))):
                    idx.append(i)
        (known if idx else new).append(it)
        hit.update(idx)
    return known, new, hit


def known_issue_in_run(entry, run_objects, run_subs):
    """True when a known-issues entry is about something this run contained:
    its object is one of the run's queue objects, or (an entry naming only a
    sub-object) that sub-object has records in the run."""
    if entry.get('object'):
        return entry['object'] in run_objects
    return bool(entry.get('sub')) and entry['sub'] in run_subs


def cleared_known_issues(entries, hit, result):
    """Entries no item of this run matched, limited to objects the run contained
    (backlog #553): a subset run says nothing about objects it did not run, so
    their entries are never reported as cleared."""
    run_objects = set(result.get('objects') or ())
    run_subs = set(result.get('record_rollup') or ())
    return [e for i, e in enumerate(entries)
            if i not in hit and known_issue_in_run(e, run_objects, run_subs)]


def load_known_issues():
    """The known_issues list; an unreadable file means nothing is known (fails closed)."""
    try:
        with open(KNOWN_ISSUES_FILE, encoding='utf-8') as f:
            return json.load(f).get('known_issues') or []
    except (OSError, ValueError) as e:
        print(f"WARNING: cannot read {KNOWN_ISSUES_FILE} ({e}); every failure and "
              f"review item counts as NEW")
        return []


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
    ap.add_argument('--rest-only', action='store_true',
                    help='skip submit/evaluate; run only the REST verify spot-check '
                         '(step 6) against the most recent LOADED record of every object')
    args = ap.parse_args()

    if args.rest_only:
        conn = connect(180_000)
        cur = conn.cursor()
        result = {'failures': [], 'review': []}
        rest_spot_check(cur, None, result)
        conn.close()
        sys.exit(0)

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

    # A DB error / timeout during evaluation retries the whole (read-only)
    # evaluation on a fresh connection instead of killing the run's verdict.
    result = retry_db(lambda: evaluate(run_id, args.baseline), what='evaluation')

    print(f"\n{'=' * 70}")
    n_fail, n_rev = len(result['failures']), len(result['review'])
    entries = load_known_issues()
    regressed = _regressed_subs(result.get('baseline_regressions'))
    kf, nf, hit_f = classify_issues(result['failures'], 'FAIL', result.get('prefix'), regressed, entries)
    kr, nr, hit_r = classify_issues(result['review'], 'REVIEW', result.get('prefix'), regressed, entries)
    cleared = cleared_known_issues(entries, hit_f | hit_r, result)
    n_known = len(kf) + len(kr)
    if n_fail == 0 and n_rev == 0:
        verdict = 'PASS'
    elif not nf and not nr:
        verdict = f'PASS (no new failures; {n_known} known)'
    else:
        verdict = 'FAIL' if nf else 'PASS (with review items)'
    print(f"VERDICT: {verdict} — RUN_ID={run_id}: {n_fail} failure(s) ({len(nf)} new), "
          f"{n_rev} review item(s) ({len(nr)} new)")
    print('=' * 70)
    if nf or nr:
        print(f"  NEW issues ({len(nf) + len(nr)}) - these block promotion:")
    for f in nf:
        print(f"  FAIL    {f}")
    for r in nr:
        print(f"  REVIEW  {r}")
    if n_known:
        print(f"  KNOWN pre-existing issues ({n_known}) - listed in "
              f"scripts/regression_known_issues.json, non-blocking:")
    for f in kf:
        print(f"  KNOWN FAIL    {f}")
    for r in kr:
        print(f"  KNOWN REVIEW  {r}")
    for e in cleared:
        what = ' '.join(str(e[f]) for f in ('kind', 'category', 'object', 'sub', 'key') if e.get(f))
        print(f"  KNOWN item cleared: {what} — remove it from regression_known_issues.json")
    result['verdict'] = verdict
    result['known_failures'], result['new_failures'] = kf, nf
    result['known_review'], result['new_review'] = kr, nr
    result['known_issues_cleared'] = cleared

    if args.json:
        with open(args.json, 'w', encoding='utf-8') as fh:
            json.dump(result, fh, indent=2, default=str)
        print(f"\nJSON summary written to {args.json}")

    sys.exit(0 if not nf and not nr else (1 if nf else 2))


if __name__ == '__main__':
    main()
