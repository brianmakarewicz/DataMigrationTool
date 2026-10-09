#!/usr/bin/env python3
"""
dmt_deploy_guard.py - the shared-database deploy rule, built into the deploy tools
(backlog #641; owner decision 2026-10-08, approved for tooling 2026-10-09).

Several agents share one database. Runs 317, 319 and 320 got stuck because
DMT_QUEUE_WORKER_PKG was redeployed while their DMT_WQ_ / DMT_PF_ child jobs were
starting (ORA-04063). The rule (CLAUDE.md, "Shared local DB deploy rule"):

  1. Never deploy while any DMT child job is running. Before deploying, read
     USER_SCHEDULER_RUNNING_JOBS and WAIT until no DMT_WQ_ / DMT_PF_ / DMT_PL_ /
     DMT_RC_ job is listed. The wait is bounded: past the timeout the deploy is
     REFUSED (never forced) with the job names still running.
  2. Right after deploying, confirm 0 invalid objects in the schema, and fail
     loudly (with their names) when there are any.

The persistent poller job is not in those families, so it never blocks a deploy.

Used by scripts/ci_promote.py (deploy-local, deploy-prod) and scripts/apex_deploy.py
(import). Every function takes a connection factory (and, for the wait, a sleep and
a clock) so the unit test drives it with fakes: test/unit/test_deploy_guard.py.

Env knobs:
  DMT_DEPLOY_GUARD_TIMEOUT_S  how long to wait for running jobs (default 2700 = 45 min)
  DMT_DEPLOY_GUARD_POLL_S     seconds between checks (default 20)
"""
import os
import time

JOB_FAMILIES = ("DMT_WQ_", "DMT_PF_", "DMT_PL_", "DMT_RC_")
DEFAULT_TIMEOUT_S = int(os.environ.get("DMT_DEPLOY_GUARD_TIMEOUT_S", "2700"))
DEFAULT_POLL_S = int(os.environ.get("DMT_DEPLOY_GUARD_POLL_S", "20"))

# LIKE patterns are bound, never concatenated; "_" is a LIKE wildcard, so escape it.
_RUNNING_SQL = (
    "SELECT job_name FROM user_scheduler_running_jobs "
    "WHERE job_name LIKE :p1 ESCAPE '\\' OR job_name LIKE :p2 ESCAPE '\\' "
    "OR job_name LIKE :p3 ESCAPE '\\' OR job_name LIKE :p4 ESCAPE '\\' "
    "ORDER BY job_name")
_INVALID_SQL = (
    "SELECT object_type, object_name FROM user_objects "
    "WHERE status = 'INVALID' ORDER BY object_type, object_name")


def _like(prefix):
    return prefix.replace("_", "\\_") + "%"


def running_dmt_jobs(con):
    """Names of the DMT child jobs (the four families) running right now."""
    cur = con.cursor()
    cur.execute(_RUNNING_SQL, {f"p{i}": _like(p) for i, p in enumerate(JOB_FAMILIES, 1)})
    return [r[0] for r in cur.fetchall()]


def invalid_objects(con):
    """(object_type, object_name) of every INVALID object in the schema."""
    cur = con.cursor()
    cur.execute(_INVALID_SQL)
    return [(r[0], r[1]) for r in cur.fetchall()]


def wait_until_no_dmt_jobs(connect, label, timeout_s=None, poll_s=None,
                           sleep=time.sleep, clock=time.monotonic, log=print):
    """Block until no DMT child job runs on the target, or refuse after timeout_s.

    connect() returns a fresh connection; one is opened per check and closed, so
    a long wait never holds a session. Returns True when the database is idle
    (deploy may go ahead), False when the timeout passed with jobs still running
    or the check itself failed (deploy must NOT go ahead)."""
    timeout_s = DEFAULT_TIMEOUT_S if timeout_s is None else timeout_s
    poll_s = DEFAULT_POLL_S if poll_s is None else poll_s
    start = clock()
    first = True
    while True:
        try:
            con = connect()
            try:
                jobs = running_dmt_jobs(con)
            finally:
                con.close()
        except Exception as e:  # noqa: BLE001 - any failure means "not proven idle"
            log(f"[deploy-guard:{label}] could not read USER_SCHEDULER_RUNNING_JOBS "
                f"({str(e)[:200]}); NOT deploying.")
            return False
        if not jobs:
            if first:
                log(f"[deploy-guard:{label}] no DMT_WQ_/DMT_PF_/DMT_PL_/DMT_RC_ job is "
                    f"running; deploy may proceed.")
            else:
                log(f"[deploy-guard:{label}] the running DMT jobs have finished after "
                    f"{int(clock() - start)}s; deploy may proceed.")
            return True
        elapsed = clock() - start
        shown = ", ".join(jobs[:8]) + (f" (+{len(jobs) - 8} more)" if len(jobs) > 8 else "")
        if elapsed >= timeout_s:
            log(f"[deploy-guard:{label}] REFUSING to deploy: {len(jobs)} DMT job(s) still "
                f"running after waiting {int(elapsed)}s (timeout {timeout_s}s): {shown}. "
                f"Deploying now could invalidate a package under a running job "
                f"(ORA-04063). Re-run once the run has finished.")
            return False
        log(f"[deploy-guard:{label}] waiting: {len(jobs)} DMT job(s) running: {shown} "
            f"({int(elapsed)}s of {timeout_s}s; next check in {poll_s}s)")
        first = False
        sleep(poll_s)


def assert_no_invalid(connect, label, log=print):
    """True when the schema has 0 invalid objects right after a deploy. Otherwise
    lists them (up to 30) and returns False; a failed check also returns False."""
    try:
        con = connect()
        try:
            bad = invalid_objects(con)
        finally:
            con.close()
    except Exception as e:  # noqa: BLE001
        log(f"[deploy-guard:{label}] could not count invalid objects ({str(e)[:200]}); "
            f"treating the deploy as NOT verified.")
        return False
    if not bad:
        log(f"[deploy-guard:{label}] 0 invalid objects after deploy.")
        return True
    log(f"[deploy-guard:{label}] {len(bad)} INVALID object(s) after deploy - fix them "
        f"before moving on:")
    for t, n in bad[:30]:
        log(f"    {t} {n}")
    if len(bad) > 30:
        log(f"    ... and {len(bad) - 30} more")
    return False
