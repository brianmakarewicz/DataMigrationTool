#!/usr/bin/env python3
"""
test_deploy_guard.py - offline proof of the shared-database deploy rule built into
the deploy tools (backlog #641; owner decision 2026-10-08).

What it proves, with FAKE connections, a fake clock and a fake sleep (no database,
no network, no real waiting):
  * scripts/dmt_deploy_guard.py
      - an idle database lets the deploy go ahead at once, with no sleep;
      - running DMT_WQ_/DMT_PF_/DMT_PL_/DMT_RC_ jobs make it wait, polling at the
        configured interval, and it goes ahead as soon as they finish;
      - jobs still running at the timeout make it REFUSE, naming the jobs;
      - a failed check (connection error) refuses rather than assuming idle;
      - the running-jobs query binds the four families with "_" escaped and asks
        USER_SCHEDULER_RUNNING_JOBS (so the poller and other jobs never block);
      - the invalid-object check passes on 0 and fails, listing them, otherwise.
  * scripts/ci_promote.py guarded_deploy (used by deploy-local and deploy-prod):
      refused -> the deploy function is never called; idle -> deploy runs, then the
      invalid check runs; invalid objects after the deploy -> failure.
  * scripts/apex_deploy.py do_import: refused -> exit 3 and no import; clean
      import -> 0; invalid objects after the import -> exit 4.

    python test/unit/test_deploy_guard.py

Exit 0 when every case passes, 1 otherwise.
"""
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "scripts"))
import dmt_deploy_guard as guard  # noqa: E402
import ci_promote as cp           # noqa: E402
import apex_deploy as ad          # noqa: E402

passed = 0
failed = 0


def check(cond, name):
    global passed, failed
    if cond:
        passed += 1
        print(f"PASS  {name}")
    else:
        failed += 1
        print(f"FAIL  {name}")


class FakeDB:
    """running: a list of job-name lists, one per check (the last one repeats).
    invalid: list of (type, name) returned by the invalid-object query."""

    def __init__(self, running=None, invalid=None, fail_connect=False):
        self.running = running or [[]]
        self.invalid = invalid or []
        self.fail_connect = fail_connect
        self.checks = 0
        self.sql = []
        self.binds = []
        self.closed = 0

    def connect(self):
        if self.fail_connect:
            raise OSError("DPY-6005: cannot connect to database")
        db = self

        class Con:
            def cursor(self):
                class Cur:
                    def execute(self, sql, binds=None):
                        db.sql.append(sql)
                        db.binds.append(binds)
                        if "user_scheduler_running_jobs" in sql:
                            i = min(db.checks, len(db.running) - 1)
                            db.checks += 1
                            self.rows = [(n,) for n in db.running[i]]
                        else:
                            self.rows = list(db.invalid)

                    def fetchall(self):
                        return self.rows
                return Cur()

            def close(self):
                db.closed += 1
        return Con()


class Clock:
    def __init__(self):
        self.t = 0.0
        self.sleeps = []

    def now(self):
        return self.t

    def sleep(self, s):
        self.sleeps.append(s)
        self.t += s


def quiet_log():
    lines = []
    return lines, lines.append


# 1. Idle database: go ahead at once.
db, c = FakeDB(), Clock()
lines, log = quiet_log()
ok = guard.wait_until_no_dmt_jobs(db.connect, "t", timeout_s=600, poll_s=20,
                                  sleep=c.sleep, clock=c.now, log=log)
check(ok and c.sleeps == [] and db.checks == 1 and db.closed == 1,
      "idle database: deploy may proceed immediately, no waiting, connection closed")

# 2. Jobs running for two checks, then finished: waits, then proceeds.
db, c = FakeDB(running=[["DMT_WQ_123", "DMT_PF_9"], ["DMT_WQ_123"], []]), Clock()
lines, log = quiet_log()
ok = guard.wait_until_no_dmt_jobs(db.connect, "t", timeout_s=600, poll_s=20,
                                  sleep=c.sleep, clock=c.now, log=log)
check(ok and c.sleeps == [20, 20] and db.checks == 3,
      "running DMT jobs: waits at the poll interval and proceeds once they finish")
check(any("DMT_WQ_123" in l and "waiting" in l for l in lines),
      "while waiting it names the running jobs")

# 3. Jobs never finish: refuse at the timeout, naming them.
db, c = FakeDB(running=[["DMT_RC_77"]]), Clock()
lines, log = quiet_log()
ok = guard.wait_until_no_dmt_jobs(db.connect, "t", timeout_s=60, poll_s=20,
                                  sleep=c.sleep, clock=c.now, log=log)
check(not ok and sum(c.sleeps) == 60 and db.checks == 4,
      "jobs still running at the timeout: deploy REFUSED (bounded wait)")
check(any("REFUSING" in l and "DMT_RC_77" in l for l in lines),
      "the refusal message names the job still running")

# 4. The check itself fails: refuse, never assume idle.
db, c = FakeDB(fail_connect=True), Clock()
lines, log = quiet_log()
ok = guard.wait_until_no_dmt_jobs(db.connect, "t", timeout_s=60, poll_s=20,
                                  sleep=c.sleep, clock=c.now, log=log)
check(not ok and c.sleeps == [] and any("NOT deploying" in l for l in lines),
      "a failed job check refuses the deploy instead of assuming idle")

# 5. The query: USER_SCHEDULER_RUNNING_JOBS, four families, "_" escaped.
db = FakeDB()
guard.running_dmt_jobs(db.connect())
check("user_scheduler_running_jobs" in db.sql[0]
      and sorted(db.binds[0].values()) == sorted(
          ["DMT\\_WQ\\_%", "DMT\\_PF\\_%", "DMT\\_PL\\_%", "DMT\\_RC\\_%"])
      and "ESCAPE" in db.sql[0],
      "running-jobs query reads USER_SCHEDULER_RUNNING_JOBS for the four DMT families only")

# 6. Invalid objects after deploy.
lines, log = quiet_log()
check(guard.assert_no_invalid(FakeDB().connect, "t", log=log)
      and any("0 invalid" in l for l in lines),
      "0 invalid objects after deploy: verified")
lines, log = quiet_log()
bad = FakeDB(invalid=[("PACKAGE BODY", "DMT_QUEUE_WORKER_PKG")])
check(not guard.assert_no_invalid(bad.connect, "t", log=log)
      and any("DMT_QUEUE_WORKER_PKG" in l for l in lines),
      "invalid objects after deploy: failure, and they are listed")
lines, log = quiet_log()
check(not guard.assert_no_invalid(FakeDB(fail_connect=True).connect, "t", log=log),
      "a failed invalid-object count is not treated as verified")

# 7. ci_promote.guarded_deploy (deploy-local / deploy-prod).
calls = []


def fake_deploy():
    calls.append("deploy")
    return True


orig_oracle = cp._oracle
try:
    db = FakeDB(running=[["DMT_PL_5"]])
    cp._oracle = lambda target: db.connect()
    ok = cp.guarded_deploy("local", fake_deploy, timeout_s=0)
    check(not ok and calls == [],
          "ci_promote: running DMT job at the timeout -> deploy function never called")

    db = FakeDB()
    cp._oracle = lambda target: db.connect()
    ok = cp.guarded_deploy("atp", fake_deploy, timeout_s=0)
    check(ok and calls == ["deploy"]
          and any("user_objects" in s and "INVALID" in s for s in db.sql),
          "ci_promote: idle -> deploy runs, then the 0-invalid check runs")

    calls.clear()
    db = FakeDB(invalid=[("VIEW", "DMT_X_V")])
    cp._oracle = lambda target: db.connect()
    check(not cp.guarded_deploy("local", fake_deploy, timeout_s=0) and calls == ["deploy"],
          "ci_promote: invalid objects right after the deploy -> stage fails")
finally:
    cp._oracle = orig_oracle

check("guarded_deploy(\"local\"" in (REPO / "scripts" / "ci_promote.py").read_text(encoding="utf-8")
      and "guarded_deploy(\"atp\"" in (REPO / "scripts" / "ci_promote.py").read_text(encoding="utf-8"),
      "ci_promote: deploy-local and deploy-prod both go through guarded_deploy")

# 8. apex_deploy.do_import.
imports = []


def fake_import(target):
    imports.append(target)
    return 0


rc = ad.do_import("local", connect=FakeDB(running=[["DMT_WQ_1"]]).connect,
                  guard_timeout_s=0, importer=fake_import)
check(rc == 3 and imports == [], "apex_deploy: running DMT job -> exit 3, nothing imported")
rc = ad.do_import("local", connect=FakeDB().connect, guard_timeout_s=0, importer=fake_import)
check(rc == 0 and imports == ["local"], "apex_deploy: idle + clean -> imported, exit 0")
rc = ad.do_import("atp", connect=FakeDB(invalid=[("PACKAGE", "DMT_APEX_PAGE_PKG")]).connect,
                  guard_timeout_s=0, importer=fake_import)
check(rc == 4, "apex_deploy: invalid objects right after the import -> exit 4")

print(f"TEST_DEPLOY_GUARD: {passed} passed, {failed} failed")
sys.exit(0 if failed == 0 else 1)
