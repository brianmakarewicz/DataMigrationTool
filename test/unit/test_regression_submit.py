#!/usr/bin/env python3
"""Offline test of the regression harness submit path (backlog #637).

scripts/dmt_regression_run.py used to answer any SUBMIT_PIPELINE error with an
inline insert of the run and queue rows. In 68 logged submissions that fallback
never fired on a hang, only on three ORA-20105 refusals (objects held by active
runs 294 and 317), and each time it created an overlapping run (318, 325, 332).
Proves, with fakes and no database: a refusal stops the harness, naming the
guard, with no SQL beyond the one package call and no poller start; a call
timeout stops it the same way (never a second, hand-built run); a successful
submit returns the package's run id and starts the poller; the fallback is gone.

    python test/unit/test_regression_submit.py
"""
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "scripts"))
import oracledb  # noqa: E402
import dmt_regression_run as reg  # noqa: E402


class FakeVar:
    def __init__(self):
        self.value = None

    def getvalue(self):
        return self.value


class FakeCursor:
    def __init__(self, conn):
        self.conn = conn

    def var(self, _type):
        v = FakeVar()
        self.conn.vars.append(v)
        return v

    def callproc(self, name, keyword_parameters=None):
        self.conn.calls.append(name)
        if self.conn.error:
            raise self.conn.error
        keyword_parameters['x_run_id'].value = 4242

    def execute(self, sql, *a, **kw):
        self.conn.calls.append('EXECUTE ' + sql.split()[0])

    def executemany(self, sql, *a, **kw):
        self.conn.calls.append('EXECUTEMANY ' + sql.split()[0])


class FakeConn:
    def __init__(self, error=None):
        self.error, self.calls, self.vars, self.closed = error, [], [], False

    def cursor(self):
        return FakeCursor(self)

    def commit(self):
        self.calls.append('COMMIT')

    def close(self):
        self.closed = True


def attempt(error):
    """Run submit_run against a fake connection; returns (conn, run_id or SystemExit, pollers)."""
    conn = FakeConn(error)
    connects, pollers = [], []

    def fake_connect(call_timeout_ms=120_000):
        connects.append(call_timeout_ms)
        return conn

    orig_connect, orig_poller = reg.connect, reg.ensure_poller
    reg.connect, reg.ensure_poller = fake_connect, lambda: pollers.append(1)
    try:
        out = reg.submit_run('STANDALONE:MiscReceipts', 'S', 'ALL', 'CONTINUE')
    except SystemExit as e:
        out = e
    finally:
        reg.connect, reg.ensure_poller = orig_connect, orig_poller
    return conn, connects, out, pollers


def main():
    checks = []

    refusal = oracledb.DatabaseError(
        "ORA-20105: Object MiscReceipts is already part of active run #317. An object "
        "may be part of only one active run at a time; wait for that run to finish.")
    conn, connects, out, pollers = attempt(refusal)
    checks.append(("a refusal (ORA-20105) stops the harness with the guard's message",
                   isinstance(out, SystemExit) and 'ORA-20105' in str(out.code)
                   and 'run #317' in str(out.code)))
    checks.append(("a refusal runs no SQL beyond SUBMIT_PIPELINE (no inline run/queue insert)",
                   conn.calls == ['DMT_SCHEDULER_PKG.SUBMIT_PIPELINE'] and len(connects) == 1))
    checks.append(("a refusal starts no poller and closes its connection",
                   pollers == [] and conn.closed))

    timeout = oracledb.OperationalError("DPY-4024: call timeout of 90000 ms exceeded")
    conn, connects, out, pollers = attempt(timeout)
    checks.append(("a call timeout stops the harness, never creates a second run",
                   isinstance(out, SystemExit) and 'DMT_PIPELINE_RUN_TBL' in str(out.code)
                   and conn.calls == ['DMT_SCHEDULER_PKG.SUBMIT_PIPELINE'] and pollers == []))

    conn, connects, out, pollers = attempt(None)
    checks.append(("a successful submit returns the package's RUN_ID and starts the poller",
                   out == 4242 and pollers == [1] and conn.closed))
    checks.append(("the submit connection has a finite call timeout",
                   connects and all(c and c > 0 for c in connects)))

    checks.append(("the inline fallback is gone",
                   not hasattr(reg, 'fallback_submit')
                   and 'INSERT INTO DMT_PIPELINE_RUN_TBL' not in
                   (REPO / "scripts" / "dmt_regression_run.py").read_text(encoding="utf-8")))

    bad = 0
    for name, ok in checks:
        bad += 0 if ok else 1
        print(f"[{'PASS' if ok else 'FAIL'}] {name}")
    print(f"\n{len(checks) - bad}/{len(checks)} checks passed")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
