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

Pure function only: no database, no file write, no network.

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

print(f"TEST_DEPLOY_SCENARIO: {passed} passed, {failed} failed")
sys.exit(0 if failed == 0 else 1)
