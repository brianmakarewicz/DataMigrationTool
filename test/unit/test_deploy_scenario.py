#!/usr/bin/env python3
"""
test_deploy_scenario.py - offline proof of deploy_scenario.register_scenario()
(backlog #506, #507, #514).

What it proves:
  * Default flow (the owner's): the pointer keys (current_scenario, scenario_id,
    seed_sha256, target, created) move to the new scenario, every other key of the
    state file survives, and the new scenario's expected outcomes start as a copy
    of the current scenario's.
  * --keep-pointer: the pointer keys are byte-identical to before; the new
    scenario is recorded under "minted_scenarios" and still gets the copy.
  * --expect-from picks the copy source; an existing entry for the new name is
    never overwritten; no source entry means nothing is copied.
  * The copy is a deep copy (editing the new scenario's outcomes never changes
    the source scenario's), and the input state is never mutated.

Also (backlog #652, owner decision 2026-10-09): the scenario is REGISTERED (its
DMT_SCENARIO_TBL row created and the state file saved with a pending entry) BEFORE
any record is inserted; a connection dropped after the insert leaves it registered,
and --resume finishes it without inserting again.

No database, no file write, no network: main() runs against stubs.

    python test/unit/test_deploy_scenario.py

Exit 0 when every case passes, 1 otherwise.
"""
import copy
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "scripts"))
import deploy_scenario as ds  # noqa: E402

BASE = {
    "current_scenario": "RegressionTest2610081244",
    "scenario_id": 521,
    "seed_sha256": "old-sha",
    "target": "local",
    "created": "2026-10-08 12:45",
    "expected_outcomes_note": "note",
    "expected_outcomes": {
        "RegressionTest2610081244": {
            "AR Lines": {"stg_table": "DMT_RA_LINES_STG_TBL",
                         "rows": {"RT-AR-KG-BAD1": "FAILED"}}},
        "RegressionTest2610071705": {
            "Projects": {"stg_table": "DMT_PJF_PROJECTS_STG_TBL",
                         "rows": {"RTPRJ-BAD1": "FAILED"}}},
    },
}
POINTER = ("current_scenario", "scenario_id", "seed_sha256", "target", "created")

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


# 1. Default flow advances the pointer and carries the expected outcomes.
state = copy.deepcopy(BASE)
new, src = ds.register_scenario(state, "RegressionTest2610082000", 600, "new-sha",
                                "local", "2026-10-08 20:00")
check(new["current_scenario"] == "RegressionTest2610082000" and new["scenario_id"] == 600
      and new["seed_sha256"] == "new-sha" and new["created"] == "2026-10-08 20:00",
      "default: pointer moves to the new scenario")
check(src == "RegressionTest2610081244"
      and new["expected_outcomes"]["RegressionTest2610082000"]
      == BASE["expected_outcomes"]["RegressionTest2610081244"],
      "default: expected outcomes copied from the current scenario (#506)")
check(new["expected_outcomes_note"] == "note"
      and "RegressionTest2610071705" in new["expected_outcomes"],
      "default: every other key and every older scenario's outcomes survive")
check(list(new)[:5] == list(POINTER), "default: pointer keys lead the file, as before")
check(state == BASE, "default: the input state is not mutated")

# 2. Deep copy: editing the new scenario's outcomes leaves the source alone.
new["expected_outcomes"]["RegressionTest2610082000"]["AR Lines"]["rows"]["X"] = "LOADED"
check("X" not in new["expected_outcomes"]["RegressionTest2610081244"]["AR Lines"]["rows"],
      "the copy is deep (source scenario unaffected by edits to the new one)")

# 3. --keep-pointer leaves the pointer untouched and records the scenario.
new, src = ds.register_scenario(copy.deepcopy(BASE), "RegressionTest2610082001", 601,
                                "obj-sha", "local", "2026-10-08 20:01",
                                keep_pointer=True)
check(all(new[k] == BASE[k] for k in POINTER),
      "keep-pointer: current_scenario, scenario_id, seed_sha256, target, created unchanged (#507/#514)")
check(new["minted_scenarios"]["RegressionTest2610082001"]
      == {"scenario_id": 601, "seed_sha256": "obj-sha", "target": "local",
          "created": "2026-10-08 20:01"},
      "keep-pointer: new scenario recorded under minted_scenarios")
check(src == "RegressionTest2610081244"
      and "RegressionTest2610082001" in new["expected_outcomes"],
      "keep-pointer: new scenario still gets its expected-outcome copy")

# 4. A second keep-pointer mint keeps the first record.
new2, _ = ds.register_scenario(new, "RegressionTest2610082002", 602, "obj-sha2",
                               "local", "2026-10-08 20:02", keep_pointer=True)
check(set(new2["minted_scenarios"]) == {"RegressionTest2610082001", "RegressionTest2610082002"},
      "keep-pointer: earlier minted scenarios are kept")

# 5. --expect-from chooses the copy source.
new, src = ds.register_scenario(copy.deepcopy(BASE), "RegressionTest2610082003", 603,
                                "s", "local", "c", expect_from="RegressionTest2610071705")
check(src == "RegressionTest2610071705"
      and new["expected_outcomes"]["RegressionTest2610082003"]
      == BASE["expected_outcomes"]["RegressionTest2610071705"],
      "expect-from: outcomes copied from the named scenario")

# 6. An existing entry for the new name is never overwritten.
seeded = copy.deepcopy(BASE)
seeded["expected_outcomes"]["RegressionTest2610082004"] = {"Mine": {"rows": {}}}
new, src = ds.register_scenario(seeded, "RegressionTest2610082004", 604, "s", "local", "c")
check(src is None and new["expected_outcomes"]["RegressionTest2610082004"] == {"Mine": {"rows": {}}},
      "existing expected outcomes for the new name are not overwritten")

# 7. Nothing to copy: no expected_outcomes at all -> no key invented.
bare = {k: BASE[k] for k in POINTER}
new, src = ds.register_scenario(bare, "RegressionTest2610082005", 605, "s", "local", "c")
check(src is None and "expected_outcomes" not in new
      and new["current_scenario"] == "RegressionTest2610082005",
      "no source outcomes: nothing copied, pointer still advances")

# 8. First-ever scenario (empty state file).
new, src = ds.register_scenario({}, "RegressionTest2610082006", 606, "s", "local", "c")
check(src is None and new["current_scenario"] == "RegressionTest2610082006",
      "empty state: first scenario becomes the pointer")

# 9. Names carry seconds: two mints in the same minute get different names.
from datetime import datetime  # noqa: E402
n1 = ds.new_scenario_name(datetime(2026, 10, 8, 18, 49, 5))
n2 = ds.new_scenario_name(datetime(2026, 10, 8, 18, 49, 41))
check(n1 == "RegressionTest261008184905" and n1 != n2,
      "scenario names include seconds (same-minute mints never collide)")

# 10. A name the state file already knows is refused (write-once, no reuse).
check(ds.name_clash(BASE, "RegressionTest2610081244")
      and ds.name_clash(BASE, "RegressionTest2610071705")
      and ds.name_clash({"minted_scenarios": {"X": {}}}, "X")
      and not ds.name_clash(BASE, n1),
      "a scenario name already in the state file is a clash")


class FakeCon:
    def __init__(self, names):
        self.names = names

    def cursor(self):
        con = self

        class C:
            def execute(self, sql, binds):
                self.n = 1 if binds[0] in con.names else 0

            def fetchone(self):
                return (self.n,)
        return C()


check(ds.scenario_exists(FakeCon({"RegressionTest2610081849"}), "RegressionTest2610081849")
      and not ds.scenario_exists(FakeCon(set()), "RegressionTest2610081849"),
      "an existing database scenario of that name is detected (refused before insert)")

# ---------------------------------------------------------------------------
# REGISTER FIRST, THEN INSERT (owner decision 2026-10-09, backlog #652).

# 11. register_pending records the scenario without touching the pointer.
pend = ds.register_pending(copy.deepcopy(BASE), "RegressionTest261009100000", 700, "sha7",
                           "local", "2026-10-09 10:00", keep_pointer=False)
check(all(pend[k] == BASE[k] for k in POINTER)
      and pend["pending_scenarios"]["RegressionTest261009100000"]
      == {"scenario_id": 700, "seed_sha256": "sha7", "target": "local",
          "created": "2026-10-09 10:00", "keep_pointer": False, "expect_from": None,
          "status": "REGISTERED"}
      and "RegressionTest261009100000" not in pend["expected_outcomes"],
      "register-first: pending entry REGISTERED, pointer and outcomes untouched until verified")
check(ds.name_clash(pend, "RegressionTest261009100000"),
      "a pending (registered, unverified) name is a clash: never minted twice")

# 12. finalize_scenario = the old registration, and the pending entry is gone.
fin, src = ds.finalize_scenario(pend, "RegressionTest261009100000")
check(fin["current_scenario"] == "RegressionTest261009100000" and fin["scenario_id"] == 700
      and "pending_scenarios" not in fin and src == "RegressionTest2610081244"
      and fin["expected_outcomes"]["RegressionTest261009100000"]
      == BASE["expected_outcomes"]["RegressionTest2610081244"],
      "finalize (default): pointer moves, outcomes carried over, pending entry removed")
pk = ds.register_pending(copy.deepcopy(BASE), "RegressionTest261009100001", 701, "sha8",
                         "local", "c", keep_pointer=True, expect_from="RegressionTest2610071705")
fin, src = ds.finalize_scenario(pk, "RegressionTest261009100001")
check(all(fin[k] == BASE[k] for k in POINTER)
      and fin["minted_scenarios"]["RegressionTest261009100001"]
      == {"scenario_id": 701, "seed_sha256": "sha8", "target": "local", "created": "c"}
      and src == "RegressionTest2610071705",
      "finalize (--keep-pointer, --expect-from): flags kept from registration time")

# 13. mark_pending keeps the entry (write-once) with the failure status.
mk = ds.mark_pending(pend, "RegressionTest261009100000", "INSERT_FAILED")
check(mk["pending_scenarios"]["RegressionTest261009100000"]["status"] == "INSERT_FAILED"
      and pend["pending_scenarios"]["RegressionTest261009100000"]["status"] == "REGISTERED",
      "mark_pending sets the status and does not mutate its input")


# 14. main(): the order of events, and a dropped connection after the insert.
class Stub:
    """Replaces deploy_scenario's I/O so main() runs with no database."""

    def __init__(self, drop_after_insert, insert_rc=0):
        self.events = []
        self.saved = []
        self.state = copy.deepcopy(BASE)
        self.drop_after_insert = drop_after_insert
        self.insert_rc = insert_rc
        self.inserted = False
        self.sid = None

    def install(self):
        stub = self
        ds.load_state = lambda: copy.deepcopy(stub.state)
        ds.seed_sha = lambda: "brand-new-sha"

        def save_state(st):
            pend_txt = ",".join(f"{k}={v['status']}"
                                for k, v in (st.get("pending_scenarios") or {}).items())
            stub.events.append(f"save:{pend_txt}|ptr={st.get('current_scenario')}")
            stub.saved.append(copy.deepcopy(st))
            stub.state = copy.deepcopy(st)
        ds.save_state = save_state

        class Con:
            def cursor(self):
                class C:
                    def execute(self, sql, binds=None):
                        self.sql = sql

                    def fetchone(self):
                        return (stub.sid,)
                return C()

            def close(self):
                pass

        def connect(target):
            if stub.inserted and stub.drop_after_insert:
                stub.drop_after_insert = False   # only the first post-insert connect drops
                stub.events.append("connect-dropped")
                raise OSError("DPY-4011: the database or network closed the connection")
            return Con()
        ds.connect = connect
        ds.scenario_exists = lambda con, name: False

        def create_row(con, name):
            stub.sid = 777
            stub.events.append("create-row")
            return 777
        ds.create_scenario_row = create_row

        class Proc:
            returncode = stub.insert_rc

        class Sub:
            @staticmethod
            def run(cmd, env=None):
                stub.events.append("insert")
                stub.inserted = True
                return Proc()
        ds.subprocess = Sub
        ds.stg_row_counts = lambda con, sid: {"DMT_POZ_SUPPLIERS_STG_TBL": 5}

        def no_dups(con, sid):
            stub.events.append("dup-check")
            return []
        ds.verify_no_duplicates = no_dups


def run_main(argv):
    old = sys.argv
    sys.argv = ["deploy_scenario.py"] + argv
    try:
        return ds.main()
    except SystemExit as e:
        return ("exit", e.code)
    except OSError as e:
        return ("oserror", str(e))
    finally:
        sys.argv = old


saved_funcs = {k: getattr(ds, k) for k in (
    "load_state", "save_state", "seed_sha", "connect", "scenario_exists",
    "create_scenario_row", "subprocess", "stg_row_counts", "verify_no_duplicates")}
try:
    st = Stub(drop_after_insert=False)
    st.install()
    rc = run_main(["--force"])
    order = ["save" if e.startswith("save") else e for e in st.events]
    check(rc == 0 and order == ["create-row", "save", "insert", "dup-check", "save"],
          "main: scenario row created and state saved BEFORE the insert; verify; finalize")
    check(st.events[1].count("=REGISTERED") == 1
          and st.events[1].endswith("|ptr=RegressionTest2610081244"),
          "main: the pre-insert save is the REGISTERED entry with the pointer unchanged")
    final = st.saved[-1]
    check("pending_scenarios" not in final and final["scenario_id"] == 777
          and final["current_scenario"] in final["expected_outcomes"],
          "main: after verification the pointer moves and outcomes are carried over")

    # Connection drops after the insert: the scenario is still registered.
    st = Stub(drop_after_insert=True)
    st.install()
    rc = run_main(["--force", "--keep-pointer"])
    name = next(iter(st.state.get("pending_scenarios") or {}), None)
    entry = (st.state.get("pending_scenarios") or {}).get(name) or {}
    check(isinstance(rc, tuple) and "insert" in st.events and "connect-dropped" in st.events
          and entry.get("status") == "REGISTERED" and entry.get("scenario_id") == 777
          and entry.get("keep_pointer") is True,
          "dropped connection after the insert: scenario stays REGISTERED with its id + flags")

    # --resume finishes it without inserting again.
    st.events.clear()
    rc = run_main(["--resume", name])
    check(rc == 0 and "insert" not in st.events and "dup-check" in st.events
          and "pending_scenarios" not in st.state
          and st.state["minted_scenarios"][name]["scenario_id"] == 777
          and st.state["current_scenario"] == "RegressionTest2610081244",
          "--resume: duplicate check + registration, nothing re-inserted, keep-pointer honoured")
    check(run_main(["--resume", name]) != 0,
          "--resume of a name that is no longer pending is refused")

    # A failed insert leaves the entry as INSERT_FAILED, and --resume refuses it.
    st = Stub(drop_after_insert=False, insert_rc=3)
    st.install()
    rc = run_main(["--force"])
    name = next(iter(st.state["pending_scenarios"]))
    check(isinstance(rc, tuple)
          and st.state["pending_scenarios"][name]["status"] == "INSERT_FAILED"
          and st.state["current_scenario"] == "RegressionTest2610081244",
          "failed insert: entry kept as INSERT_FAILED, pointer not moved")
    check(run_main(["--resume", name]) != 0, "--resume refuses an INSERT_FAILED scenario")
finally:
    for k, v in saved_funcs.items():
        setattr(ds, k, v)

print(f"TEST_DEPLOY_SCENARIO: {passed} passed, {failed} failed")
sys.exit(0 if failed == 0 else 1)
