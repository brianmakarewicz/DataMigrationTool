#!/usr/bin/env python3
"""Offline test of the known-review classifier in scripts/dmt_regression_run.py.

Feeds the 11 review items that full regression run 300 still reports on main
5aa506a (after the REST lookup fix #669), all pre-existing and never passed, and
checks they classify as KNOWN with zero NEW, while volatile text (prefixes, keys, HTTP detail) does not affect matching
and anything unlisted is NEW. No database or network needed.

    python test/unit/test_regression_known_review.py
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


def main():
    run300 = ([f"DONE with zero records: {o} (no staged regression data?)" for o in ZERO]
              + [f"REST verify {o}/{s}: NOT_FOUND (Record not found in Fusion for {s} = 93354RT-X)"
                 for o, s in REST])
    checks = []

    known, new, cleared = reg.classify_review(run300)
    checks.append(("run 300's 11 items are all KNOWN, 0 NEW, 0 cleared",
                   (len(known), len(new), len(cleared)) == (11, 0, 0)))

    volatile = ["REST verify BillingEvents/Billing Events: ERROR (REST call failed: ORA-20003: HTTP GET "
                "failed. Status: 403 | URL: https://x/y?q=99999RT)"]
    k, n, c = reg.classify_review(volatile)
    checks.append(("different status/prefix/HTTP detail still matches", (len(k), len(n)) == (1, 0)))
    checks.append(("10 known items not seen are reported as cleared", len(c) == 10))

    unlisted = ["REST verify Customers/Parties: NOT_FOUND (x)",
                "REST verify Assets/Asset Books: NOT_FOUND (x)",
                "DONE with zero records: Workers (no staged regression data?)",
                "LOG ERROR x3: DMT_X_PKG.RUN: boom",
                "queue SKIPPED: SalaryBases (dependency failed upstream)"]
    k, n, _ = reg.classify_review(unlisted)
    checks.append(("unlisted sub, unlisted object, log errors, skips are NEW",
                   (len(k), len(n)) == (0, 5)))

    entries = json.loads((REPO / "scripts" / "regression_known_review.json")
                         .read_text(encoding="utf-8"))["known_review"]
    checks.append(("every entry has category, object, backlog, reason",
                   all(e.get("category") in ("ZERO_RECORDS", "REST_VERIFY") and e.get("object")
                       and e.get("backlog") and e.get("reason")
                       and (e["category"] != "REST_VERIFY" or e.get("sub")) for e in entries)))

    bad = 0
    for name, ok in checks:
        bad += 0 if ok else 1
        print(f"[{'PASS' if ok else 'FAIL'}] {name}")
    print(f"\n{len(checks) - bad}/{len(checks)} checks passed")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
