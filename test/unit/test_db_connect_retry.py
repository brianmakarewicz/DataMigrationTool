#!/usr/bin/env python3
"""Offline test of the hardened DB connect used by the CI scripts.

Local regression runs 293 and 338 hung forever after the pipeline had finished:
scripts/dmt_regression_run.py called oracledb.connect() with no connect timeout,
so a stalled connect blocked indefinitely. Proves, with fakes and no database:
a connect that raises on the first attempt is retried and succeeds; a connect
that hangs is abandoned at its deadline and retried; connect timeouts and a
finite call_timeout are always passed/set; call_timeout 0 is refused; one failed
status poll in wait_for_run is retried, not fatal; ci_promote's connections use
the same hardened path; the installed python-oracledb accepts the keyword names.

    python test/unit/test_db_connect_retry.py
"""
import sys
import threading
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "scripts"))
import oracledb  # noqa: E402
import dmt_db_connect as dbc  # noqa: E402
import dmt_regression_run as reg  # noqa: E402


class FakeConn:
    def __init__(self):
        self.call_timeout = None
        self.closed = False

    def close(self):
        self.closed = True


class FlakyConnect:
    """Raises (or hangs) on the first `fail` calls, then returns a FakeConn."""

    def __init__(self, fail=1, hang=False):
        self.fail, self.hang, self.calls, self.kwargs = fail, hang, 0, []
        self.release = threading.Event()

    def __call__(self, **kw):
        self.calls += 1
        self.kwargs.append(kw)
        if self.calls <= self.fail:
            if self.hang:
                self.release.wait(5)
                return FakeConn()
            raise oracledb.OperationalError("DPY-6005: cannot connect to database (fake)")
        return FakeConn()


def main():
    checks = []
    quiet = dict(log=lambda *_: None)
    sleeps = []

    # 1. raises on first connect -> retried, succeeds, finite call_timeout, timeouts passed
    fake = FlakyConnect(fail=1)
    conn = dbc.connect_with_retry(connect_fn=fake, sleep=sleeps.append, call_timeout_ms=60_000,
                                  user='u', password='p', dsn='d', **quiet)
    checks.append(("connect raising on attempt 1 is retried and succeeds on attempt 2",
                   isinstance(conn, FakeConn) and fake.calls == 2))
    checks.append(("backoff sleep happened once between the attempts", sleeps == [dbc.BACKOFF_S]))
    checks.append(("returned connection has the finite call_timeout", conn.call_timeout == 60_000))
    checks.append(("tcp_connect_timeout and expire_time are passed to every attempt",
                   all(k.get('tcp_connect_timeout') == dbc.TCP_CONNECT_TIMEOUT_S
                       and k.get('expire_time') == dbc.EXPIRE_TIME_MIN for k in fake.kwargs)))

    # 2. hanging connect -> abandoned at the deadline, retried
    fake = FlakyConnect(fail=1, hang=True)
    t0 = time.time()
    conn = dbc.connect_with_retry(connect_fn=fake, sleep=lambda s: None, deadline_s=0.3, **quiet)
    fake.release.set()
    checks.append(("a hung connect is abandoned at its deadline and the retry succeeds",
                   isinstance(conn, FakeConn) and fake.calls == 2 and time.time() - t0 < 3))

    # 3. persistent failure -> raises after `attempts`, does not loop forever
    fake = FlakyConnect(fail=99)
    try:
        dbc.connect_with_retry(connect_fn=fake, sleep=lambda s: None, attempts=3, **quiet)
        raised = False
    except oracledb.Error:
        raised = True
    checks.append(("a persistent failure raises after the attempt limit", raised and fake.calls == 3))

    # 4. call_timeout 0 (= wait forever) is refused
    try:
        dbc.connect_with_retry(connect_fn=FlakyConnect(fail=0), call_timeout_ms=0, **quiet)
        refused = False
    except ValueError:
        refused = True
    checks.append(("call_timeout_ms=0 is refused", refused))
    src = (REPO / "scripts" / "dmt_regression_run.py").read_text(encoding="utf-8")
    checks.append(("dmt_regression_run.py never sets call_timeout = 0 or calls oracledb.connect",
                   "call_timeout = 0" not in src and "oracledb.connect(" not in src))

    # 5. reg.connect() goes through the hardened path (fake raises on first connect)
    fake = FlakyConnect(fail=1)
    real_connect = oracledb.connect
    oracledb.connect = fake
    try:
        orig_default_sleep = dbc.connect_with_retry.__kwdefaults__['sleep']
        dbc.connect_with_retry.__kwdefaults__['sleep'] = lambda s: None
        dbc.connect_with_retry.__kwdefaults__['log'] = lambda *_: None
        conn = reg.connect(45_000)
        checks.append(("dmt_regression_run.connect() retries a failed first connect",
                       isinstance(conn, FakeConn) and fake.calls == 2 and conn.call_timeout == 45_000))

        # 6. ci_promote._oracle uses the same hardened path
        import ci_promote as ci
        fake2 = FlakyConnect(fail=1)
        oracledb.connect = fake2
        saved = ci.TARGET
        ci.TARGET = {"local": lambda: {"schema": "s", "pw": "p", "dsn": "d", "tns": None}}
        try:
            c2 = ci._oracle("local")
        finally:
            ci.TARGET = saved
        checks.append(("ci_promote._oracle() retries, passes connect timeouts, sets call_timeout",
                       isinstance(c2, FakeConn) and fake2.calls == 2 and c2.call_timeout > 0
                       and fake2.kwargs[0].get('tcp_connect_timeout') == dbc.TCP_CONNECT_TIMEOUT_S))
    finally:
        oracledb.connect = real_connect
        dbc.connect_with_retry.__kwdefaults__['sleep'] = orig_default_sleep
        dbc.connect_with_retry.__kwdefaults__['log'] = print

    # 7. wait_for_run: one failed poll is retried, not fatal
    polls = {'n': 0}

    def flaky_poll(run_id):
        polls['n'] += 1
        if polls['n'] == 1:
            raise oracledb.OperationalError("DPY-4024: call timeout of 60000 ms exceeded (fake)")
        return 'COMPLETED', None, None, {'DONE': 44}

    real_poll, real_reg_sleep = reg._poll_once, reg.time.sleep
    reg._poll_once, reg.time.sleep = flaky_poll, (lambda s: None)
    try:
        status = reg.wait_for_run(338, timeout_min=1, stall_min=20)
    finally:
        reg._poll_once, reg.time.sleep = real_poll, real_reg_sleep
    checks.append(("wait_for_run survives a failed poll and returns the terminal status",
                   status == 'COMPLETED' and polls['n'] == 2))

    # 8. retry_db retries a DB error once then returns
    calls = {'n': 0}

    def flaky_eval():
        calls['n'] += 1
        if calls['n'] == 1:
            raise oracledb.DatabaseError("ORA-03113: end-of-file on communication channel (fake)")
        return {'ok': True}
    out = dbc.retry_db(flaky_eval, sleep=lambda s: None, **quiet)
    checks.append(("retry_db (used for evaluation) retries a DB error", out == {'ok': True}
                   and calls['n'] == 2))

    # 9. the installed python-oracledb accepts the keyword names (refused port, no real DB)
    try:
        dbc.connect_with_retry(user='x', password='y', dsn='127.0.0.1:1/none', attempts=1, **quiet)
        kw_ok = False
    except TypeError:
        kw_ok = False
    except Exception as e:  # expected: connection refused, not an unknown-keyword error
        kw_ok = 'unexpected keyword' not in str(e)
    checks.append((f"python-oracledb {oracledb.__version__} accepts tcp_connect_timeout/expire_time",
                   kw_ok))

    bad = 0
    for name, ok in checks:
        bad += 0 if ok else 1
        print(f"[{'PASS' if ok else 'FAIL'}] {name}")
    print(f"\n{len(checks) - bad}/{len(checks)} checks passed")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
