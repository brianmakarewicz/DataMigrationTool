#!/usr/bin/env python3
"""
test_ci_promote_prefix.py - offline proof of ci_promote.sync_prefix_for().

Owner rule (2026-10-08): "make sure you update the prefix WITHOUT WASTING THEM.
don't 'grab a few extra'. Grab the next one." Before every regression the target
instance's DMT_RUN_PREFIX_SEQ is set so its very next NEXTVAL is exactly
max(highest prefix used on local, highest used on ATP) + 1, with no probe draws,
and the other instance is left alone.

Never backwards (backlog #725): when the sequence already issues N or higher next
(a run drew a prefix whose run row is not committed yet), it is left untouched,
and concurrent syncs of one instance are serialized by a row lock held in a
second session.

Uses FAKE connections (ci_promote._oracle is replaced); never touches a real
database or sequence. Needs no network.

    python test/unit/test_ci_promote_prefix.py

Exit 0 when every scenario passes, 1 otherwise.
"""
import re
import sys
import threading
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "scripts"))
import ci_promote as cp  # noqa: E402


class FakeDB:
    """One instance: DMT_PIPELINE_RUN_TBL max prefix + DMT_RUN_PREFIX_SEQ state,
    with Oracle NOCACHE semantics (LAST_NUMBER = the value NEXTVAL returns)."""

    def __init__(self, name, max_prefix, last_number, restart_supported=True,
                 max_dependent=0):
        self.name = name
        self.max_prefix = max_prefix
        self.max_dependent = max_dependent
        self.increment = 1
        self.last_issued = last_number - 1   # an already-drawn NOCACHE sequence
        self.restart_at = None                # set by RESTART: next NEXTVAL returns it
        self.restart_supported = restart_supported
        self.nextval_draws = []
        self.ddl = []
        self.cache = 0
        self.row_lock = threading.Lock()   # the PREFIX_SYNC_LOCK row of DMT_CONFIG_TBL
        self.lock_row_exists = False
        self.events = []                   # (event, thread name) in order
        self.on_state_read = None          # test hook, called on each USER_SEQUENCES read

    @property
    def last_number(self):
        # USER_SEQUENCES.LAST_NUMBER for NOCACHE: the value NEXTVAL would return
        # with the current increment.
        return self.restart_at if self.restart_at is not None else self.last_issued + self.increment

    def nextval(self):
        if self.restart_at is not None:
            v, self.restart_at = self.restart_at, None
        else:
            v = self.last_issued + self.increment
        self.last_issued = v
        self.nextval_draws.append(v)
        return v


class FakeCursor:
    def __init__(self, db, conn):
        self.db = db
        self.conn = conn
        self._row = None

    def execute(self, sql, **binds):
        s = " ".join(sql.split()).lower()
        db = self.db
        if s.startswith("merge into dmt_config_tbl"):
            db.lock_row_exists = True
            self._row = None
        elif "from dmt_config_tbl" in s and "for update" in s:
            assert db.lock_row_exists, "lock row must exist before FOR UPDATE"
            if not self.conn.holds_lock:
                db.row_lock.acquire()
                self.conn.holds_lock = True
                db.events.append(("lock", threading.current_thread().name))
            self._row = ("LOCK",)
        elif "from dmt_pipeline_run_tbl" in s:
            # Emulate the real SQL: DEPENDENT_PREFIX only counts if the query reads it.
            self._row = (max(db.max_prefix, db.max_dependent) if "dependent_prefix" in s
                         else db.max_prefix,)
        elif "from user_sequences" in s:
            db.events.append(("read", threading.current_thread().name))
            if db.on_state_read:
                db.on_state_read(db)
            self._row = (db.last_number, db.cache, db.increment)
        elif ".nextval" in s:
            self._row = (db.nextval(),)
        elif s.startswith("alter sequence"):
            db.ddl.append(s)
            db.events.append(("ddl", threading.current_thread().name))
            m = re.search(r"restart start with (\d+)", s)
            if m:
                if not db.restart_supported:
                    raise RuntimeError("ORA-02286: no options specified for ALTER SEQUENCE")
                db.restart_at = int(m.group(1))
                return
            m = re.search(r"increment by (-?\d+)", s)
            if m:
                db.increment = int(m.group(1))
                return
            raise AssertionError(f"unexpected DDL {s}")
        else:
            raise AssertionError(f"unexpected SQL {s}")

    def fetchone(self):
        return self._row


class FakeConn:
    def __init__(self, db):
        self.db = db
        self.holds_lock = False

    def cursor(self):
        return FakeCursor(self.db, self)

    def _release(self):
        # COMMIT, ROLLBACK or disconnect ends the transaction and frees the row lock
        if self.holds_lock:
            self.holds_lock = False
            self.db.events.append(("unlock", threading.current_thread().name))
            self.db.row_lock.release()

    def commit(self):
        self._release()

    def rollback(self):
        self._release()

    def close(self):
        self._release()


def install(local, atp):
    dbs = {"local": local, "atp": atp}
    cp._oracle = lambda target: FakeConn(dbs[target])


FAILS = []


def check(cond, msg):
    print(("  ok   " if cond else "  FAIL ") + msg)
    if not cond:
        FAILS.append(msg)


def scenario(title, target, restart=True):
    print(f"\n{title}")
    # local used up to 93367 and its sequence would issue 93368; ATP used up to
    # 93364 and its sequence would issue 93365.
    local = FakeDB("local", 93367, 93368, restart_supported=restart)
    atp = FakeDB("atp", 93364, 93365, restart_supported=restart)
    install(local, atp)
    tgt, other = (local, atp) if target == "local" else (atp, local)
    before_other = (other.last_number, other.increment)

    n = cp.sync_prefix_for(target)
    check(n == 93368, f"returns N = 93368 (got {n})")
    check(tgt.last_number == 93368 and tgt.increment == 1,
          f"{target} sequence issues 93368 next (LAST_NUMBER {tgt.last_number}, INCREMENT {tgt.increment})")
    if restart:
        check(tgt.nextval_draws == [], f"no NEXTVAL draws on {target} (drew {tgt.nextval_draws})")
    else:
        check(tgt.nextval_draws in ([], [93367]),
              f"fallback drew at most one value, exactly N-1 = 93367 (drew {tgt.nextval_draws})")
    check(other.nextval_draws == [] and other.ddl == []
          and (other.last_number, other.increment) == before_other,
          f"the other instance ({other.name}) is not touched")

    ddl_before, draws_before = list(tgt.ddl), list(tgt.nextval_draws)
    n2 = cp.sync_prefix_for(target)
    check(n2 == 93368 and tgt.last_number == 93368, f"second call still N = 93368 (got {n2})")
    check(tgt.ddl == ddl_before and tgt.nextval_draws == draws_before,
          "second call is a no-op (no DDL, no draw)")

    v = tgt.nextval()
    check(v == 93368, f"the run's NEXTVAL on {target} returns 93368 (got {v})")


def never_backwards_tests():
    print("\n(a) sequence already ahead of N -> untouched")
    # The #725 incident: max used on both instances is 93401, so N = 93402, but
    # run 355 has already drawn 93402 (row not committed): the sequence issues 93403.
    local = FakeDB("local", 93401, 93403)
    atp = FakeDB("atp", 93398, 93399)
    install(local, atp)
    nxt = cp.sync_prefix_for("local")
    check(local.ddl == [] and local.nextval_draws == [],
          f"no DDL and no draw on local (ddl {local.ddl}, drew {local.nextval_draws})")
    check(local.last_number == 93403, f"local still issues 93403 next (got {local.last_number})")
    check(nxt == 93403, f"returns the real next value 93403, not N (got {nxt})")
    check(local.nextval() == 93403, "the next run (356) gets 93403, not 93402 again")
    check(not local.row_lock.locked(), "row lock released")

    print("\n(b) sequence behind -> restarted to exactly N")
    local = FakeDB("local", 93401, 93380)
    atp = FakeDB("atp", 93410, 93411)
    install(local, atp)
    nxt = cp.sync_prefix_for("local")
    check(nxt == 93411, f"returns N = 93411 (got {nxt})")
    check(local.ddl == ["alter sequence dmt_run_prefix_seq restart start with 93411"],
          f"one RESTART START WITH 93411 (ddl {local.ddl})")
    check(local.nextval_draws == [] and local.last_number == 93411,
          f"no draws; issues exactly 93411 next (LAST_NUMBER {local.last_number})")
    check(atp.ddl == [] and atp.nextval_draws == [], "ATP untouched")
    check(not local.row_lock.locked(), "row lock released")

    print("\n(c) concurrent syncs: serialized, and a draw between them is never undone")
    # Local is behind, so the first sync must restart it to N = 93402. While sync A
    # holds the lock, sync B starts and must wait. After A finishes, run 355 draws
    # 93402 (its run row not committed, so max used still reads 93401); B then
    # computes N = 93402 again and must NOT restart the sequence back to it.
    local = FakeDB("local", 93401, 93380)
    atp = FakeDB("atp", 93398, 93399)
    install(local, atp)
    results = {}
    a_done = threading.Event()
    run_drawn = threading.Event()
    waited = {}

    def sync(name):
        try:
            results[name] = cp.sync_prefix_for("local")
        except BaseException as e:  # noqa: BLE001
            results[name] = e

    def on_read(db):
        me = threading.current_thread().name
        if me == "A" and "b_blocked" not in waited:
            tb.start()                       # B starts while A is mid-sync (first read)
            time.sleep(0.2)
            waited["b_blocked"] = ("lock", "B") not in db.events
        elif me == "B":
            run_drawn.wait(5)                # make the run's draw land before B's read

    def run_355():
        a_done.wait(5)
        results["355"] = local.nextval()
        run_drawn.set()

    local.on_state_read = on_read
    tb = threading.Thread(target=lambda: sync("B"), name="B")
    ta = threading.Thread(target=lambda: (sync("A"), a_done.set()), name="A")
    tr = threading.Thread(target=run_355, name="R")
    tr.start(); ta.start()
    ta.join(5); tr.join(5); tb.join(5)
    local.on_state_read = None
    check(waited.get("b_blocked") is True, "sync B waited on the row lock while A was mid-sync")
    check(results.get("A") == 93402, f"sync A set next = N = 93402 (got {results.get('A')})")
    check(results.get("355") == 93402, f"run 355 drew 93402 (got {results.get('355')})")
    check(results.get("B") == 93403, f"sync B left it alone: next is 93403 (got {results.get('B')})")
    check(local.last_number == 93403, f"sequence issues 93403 next (LAST_NUMBER {local.last_number})")
    check(local.nextval() == 93403, "run 356 gets 93403: no duplicate prefix")
    restarts = [d for d in local.ddl if "restart" in d]
    check(restarts == ["alter sequence dmt_run_prefix_seq restart start with 93402"],
          f"exactly one RESTART in total (ddl {local.ddl})")
    ev = [e for e in local.events if e[0] in ("lock", "unlock")]
    check(ev == [("lock", "A"), ("unlock", "A"), ("lock", "B"), ("unlock", "B")],
          f"locks do not interleave ({ev})")
    a_ops = [i for i, e in enumerate(local.events) if e[1] == "A" and e[0] in ("read", "ddl")]
    b_ops = [i for i, e in enumerate(local.events) if e[1] == "B" and e[0] in ("read", "ddl")]
    check(bool(a_ops) and bool(b_ops) and max(a_ops) < min(b_ops),
          "every sequence read/DDL of sync A happens before any of sync B")

    print("\nCACHE sequence refuses (LAST_NUMBER would not be exact)")
    local = FakeDB("local", 93401, 93380)
    local.cache = 20
    install(local, FakeDB("atp", 10, 11))
    try:
        cp.sync_prefix_for("local")
        check(False, "refused a CACHE sequence")
    except SystemExit:
        check(local.ddl == [], "refused a CACHE sequence with no DDL")
    check(not local.row_lock.locked(), "row lock released after a refusal")


def main():
    scenario("target local, RESTART supported", "local")
    scenario("target ATP, RESTART supported", "atp")
    scenario("target ATP, RESTART rejected -> INCREMENT BY fallback", "atp", restart=False)
    scenario("target local, RESTART rejected -> INCREMENT BY fallback", "local", restart=False)

    print("\nDEPENDENT_PREFIX is a reference, not an issued prefix: ignored")
    # Local runs 178/182 carry DEPENDENT_PREFIX='99999' (a placeholder override);
    # before the fix this made N = 100000 and test-prod aborted past MAXVALUE.
    local = FakeDB("local", 93367, 93368, max_dependent=99999)
    atp = FakeDB("atp", 93364, 93365)
    install(local, atp)
    try:
        n = cp.sync_prefix_for("atp")
        check(n == 93368, f"DEPENDENT_PREFIX 99999 does not affect N (N = 93368, got {n})")
        check(atp.last_number == 93368 and atp.nextval_draws == [],
              "ATP issues 93368 next with nothing drawn (no-waste rule intact)")
    except SystemExit as e:
        check(False, f"DEPENDENT_PREFIX 99999 must not abort the sync ({e})")

    print("\nabove MAXVALUE refuses")
    install(FakeDB("local", 99999, 99999), FakeDB("atp", 10, 11))
    try:
        cp.sync_prefix_for("local")
        check(False, "refused past MAXVALUE")
    except SystemExit:
        check(True, "refused past MAXVALUE")

    never_backwards_tests()

    print(f"\n{'PASS' if not FAILS else 'FAIL'}: {len(FAILS)} failure(s)")
    return 0 if not FAILS else 1


if __name__ == "__main__":
    sys.exit(main())
