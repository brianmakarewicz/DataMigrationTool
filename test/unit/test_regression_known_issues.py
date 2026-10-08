#!/usr/bin/env python3
"""Offline test of the known-issues classifier in scripts/dmt_regression_run.py.

Owner decision 2026-10-08: "change the gate - so that there are no NEW failures".
Proves: the 11 review items run 300 reports classify as KNOWN with zero NEW; an
unlisted failure is NEW (blocks) while a listed one is KNOWN (does not); volatile
text (run prefix, HTTP detail, counts) does not affect matching; a listed item
whose sub-object regressed against the baseline run is NEW. No database needed.

    python test/unit/test_regression_known_issues.py
"""
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "scripts"))
import dmt_regression_run as reg  # noqa: E402

ZERO = ["SalaryBases", "TaxCards", "W2Balances", "BenParticipant", "BenDependent",
        "BenBeneficiary", "Absences", "PerfEvaluations", "WorkSchedules"]
REST = [("BillingEvents", "Billing Events"), ("Customers", "Locations")]

# A listed FAIL entry used only by this test (the committed list has none today).
FAIL_ENTRIES = [
    {"kind": "FAIL", "category": "GOOD_ROWS_FAILED", "sub": "GL Budget Lines",
     "backlog": "test", "reason": "test"},
    {"kind": "FAIL", "category": "NON_TERMINAL_ROW", "sub": "Item Master",
     "key": "DMT-RT-SERIAL-001", "backlog": "test", "reason": "test"},
]


def main():
    checks = []
    run300 = ([f"DONE with zero records: {o} (no staged regression data?)" for o in ZERO]
              + [f"REST verify {o}/{s}: NOT_FOUND (Record not found in Fusion for {s} = 1)"
                 for o, s in REST])
    entries = reg.load_known_issues()
    k, n, hit = reg.classify_issues(run300, 'REVIEW', '93354', (), entries)
    checks.append(("run 300's 11 review items are all KNOWN, 0 NEW, every entry used",
                   (len(k), len(n), len(hit)) == (11, 0, len(entries))))

    k, n, _ = reg.classify_issues(
        ["REST verify BillingEvents/Billing Events: ERROR (ORA-20003 Status: 403 | URL x?q=99999RT)"],
        'REVIEW', '99999', (), entries)
    checks.append(("different status/HTTP detail still matches", (len(k), len(n)) == (1, 0)))

    k, n, _ = reg.classify_issues(
        ["REST verify Customers/Parties: NOT_FOUND (x)",
         "DONE with zero records: Workers (no staged regression data?)",
         "LOG ERROR x3: DMT_X_PKG.RUN: boom"], 'REVIEW', None, (), entries)
    checks.append(("unlisted review items are NEW", (len(k), len(n)) == (0, 3)))

    k, n, _ = reg.classify_issues(["DONE with zero records: SalaryBases (x)"], 'FAIL',
                                  None, (), entries)
    checks.append(("a REVIEW entry never excuses a FAIL of the same shape", len(n) == 1))

    fails = ["GOOD rows FAILED: GL Budget Lines (2 rows, 2 keys): 93354RT-GLB-1 x1 — boom",
             "row in non-terminal status UNACCOUNTED: Item Master / 93354DMT-RT-SERIAL-001",
             "GOOD rows FAILED: AP Invoice Lines (1 rows, 1 keys): 93354RT-AP-1 x1 — boom",
             "row in non-terminal status UNACCOUNTED: Item Master / 93354DMT-RT-LOT-001",
             "queue FAILED: Suppliers — ORA-00001",
             "baseline regression vs run 299: GL Budget Lines: good LOADED 3->1"]
    k, n, _ = reg.classify_issues(fails, 'FAIL', '93354', (), FAIL_ENTRIES)
    checks.append(("listed failures are KNOWN (incl. row key with run prefix stripped)",
                   k == fails[:2]))
    checks.append(("unlisted failures, other row keys, baseline regressions are NEW (block)",
                   n == fails[2:]))

    k, n, _ = reg.classify_issues(fails[:1], 'FAIL', '93354', {"GL Budget Lines"}, FAIL_ENTRIES)
    checks.append(("a listed failure whose sub-object regressed vs baseline is NEW",
                   (len(k), len(n)) == (0, 1)))

    k, n, _ = reg.classify_issues(fails[:1], 'FAIL', None, (),
                                  [{"kind": "FAIL", "category": "GOOD_ROWS_FAILED"}])
    checks.append(("an entry naming no object or sub matches nothing", (len(k), len(n)) == (0, 1)))

    raw = json.loads((REPO / "scripts" / "regression_known_issues.json").read_text(encoding="utf-8"))
    checks.append(("every committed entry has kind, category, object/sub, backlog, reason",
                   all(e.get("kind") in ("FAIL", "REVIEW") and e.get("category")
                       and (e.get("object") or e.get("sub")) and e.get("backlog") and e.get("reason")
                       for e in raw["known_issues"])))

    bad = 0
    for name, ok in checks:
        bad += 0 if ok else 1
        print(f"[{'PASS' if ok else 'FAIL'}] {name}")
    print(f"\n{len(checks) - bad}/{len(checks)} checks passed")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
