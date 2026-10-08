#!/usr/bin/env python3
"""
test_ci_promote_prefix.py - offline proof of ci_promote.sync_prefix_for().

Owner rule (2026-10-08): "make sure you update the prefix WITHOUT WASTING THEM.
don't 'grab a few extra'. Grab the next one." Before every regression the target
instance's DMT_RUN_PREFIX_SEQ is set so its very next NEXTVAL is exactly
max(highest prefix used on local, highest used on ATP) + 1, with no probe draws,
and the other instance is left alone.

Uses FAKE connections (ci_promote._oracle is replaced); never touches a real
database or sequence. Needs no network.

    python test/unit/test_ci_promote_prefix.py

Exit 0 when every scenario passes, 1 otherwise.
"""
import re
import sys
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
    def __init__(self, db):
        self.db = db
        self._row = None

    def execute(self, sql, **binds):
        s = " ".join(sql.split()).lower()
        db = self.db
        if "from dmt_pipeline_run_tbl" in s:
            # Emulate the real SQL: DEPENDENT_PREFIX only counts if the query reads it.
            self._row = (max(db.max_prefix, db.max_dependent) if "dependent_prefix" in s
                         else db.max_prefix,)
        elif "from user_sequences" in s:
            self._row = (db.last_number, 0, db.increment)
        elif ".nextval" in s:
            self._row = (db.nextval(),)
        elif s.startswith("alter sequence"):
            db.ddl.append(s)
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

    def cursor(self):
        return FakeCursor(self.db)

    def close(self):
        pass


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

    print(f"\n{'PASS' if not FAILS else 'FAIL'}: {len(FAILS)} failure(s)")
    return 0 if not FAILS else 1


if __name__ == "__main__":
    sys.exit(main())
