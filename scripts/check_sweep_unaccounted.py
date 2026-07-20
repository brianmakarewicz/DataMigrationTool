#!/usr/bin/env python3
"""check_sweep_unaccounted.py — conformance checker for the honest-accounting rule
(DMT_DESIGN.html section 7, "Reconcilers never fabricate a FAILED — unresolved
records stay UNACCOUNTED").

HISTORY / WHY THIS INVERTED
---------------------------
This script used to REQUIRE every FBDI reconciler to define and call a standard
SWEEP_UNACCOUNTED procedure that marked every non-terminal TFM row FAILED with a
generic '[RECONCILE_ERROR] ... not confirmed in Fusion ...' message. That generic
message was a FABRICATED fallback: it asserted "failed" when we had only failed to
find the record. It hid unaccounted items behind a false FAILED. The rule was
reversed (owner-directed, 2026-07-20): a reconciler may mark a record LOADED (real
base-table confirmation) or FAILED (with a REAL Fusion per-record error) only. If it
can determine neither, the record is LEFT UNACCOUNTED — it stays GENERATED. The
accounting gate then reports the object not-DONE and the funnel view surfaces these
in its UNRECONCILED lane. No fabricated FAILED anywhere.

WHAT THIS CHECKS NOW
--------------------
For every reconciler package (all *_RESULTS_PKG that carry RECONCILE_BATCH):
  1. It defines NO  PROCEDURE SWEEP_UNACCOUNTED  (the fabricating sweep is removed).
  2. It contains NO call to SWEEP_UNACCOUNTED(...).
  3. It contains NO fabricated reconcile-fallback message text — the generic
     "not confirmed in Fusion ... could not be verified" family that asserted a
     failure we never observed.

A green run means no reconciler fabricates a FAILED for an unresolved record.

Exit code 0 = all packages conform; non-zero = at least one fabricating site remains.
Run from the repo root:  python scripts/check_sweep_unaccounted.py
"""

import os
import re
import sys
import glob

PKG_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                       "db", "packages")


# Every reconciler package (anything whose body carries RECONCILE_BATCH). We scan by
# glob so a newly added reconciler is covered automatically.
def reconciler_files():
    out = []
    for path in sorted(glob.glob(os.path.join(PKG_DIR, "*_results_pkg.pkb.sql"))):
        with open(path, encoding="utf-8", errors="replace") as fh:
            if "RECONCILE_BATCH" in fh.read():
                out.append(path)
    return out


# Fabricated-fallback signatures that must never reappear in a reconciler. These are
# the generic "we could not find it, so we call it failed" strings, plus any trace of
# the removed fabricating sweep.
#
# Note on the BIP-0-rows family: a legitimate LOG line may truthfully say "BIP
# returned 0 rows" before handing off to an import-report fallback, so the bare
# phrase is NOT banned. What IS banned is asserting an outcome we never observed —
# "Cannot verify Fusion outcome", "No reconciliation data returned", and the
# "0 rows ... Parent ... not reconciled" cascade — which only ever appeared as
# fabricated ERROR_TEXT written onto a FAILED row.
FABRICATED_PATTERNS = [
    re.compile(r"PROCEDURE\s+SWEEP_UNACCOUNTED\b", re.I),
    re.compile(r"\bSWEEP_UNACCOUNTED\s*\(", re.I),
    re.compile(r"not confirmed in Fusion.*could not be verified", re.I | re.S),
    re.compile(r"import outcome could not be verified", re.I),
    re.compile(r"no row-level error matched", re.I),
    re.compile(r"Cannot verify Fusion outcome", re.I),
    re.compile(r"No reconciliation data returned", re.I),
    re.compile(r"BIP returned 0 rows\.\s*Parent header not reconciled", re.I),
]


def check_pkg(path):
    fails = []
    with open(path, encoding="utf-8", errors="replace") as fh:
        text = fh.read()

    for pat in FABRICATED_PATTERNS:
        m = pat.search(text)
        if m:
            line = text.count("\n", 0, m.start()) + 1
            snippet = m.group(0).replace("\n", " ")[:80]
            fails.append("line %d: fabricated-fallback pattern found: %s"
                         % (line, snippet))
    return fails


def main():
    print("Honest-accounting conformance check (no fabricated FAILED)")
    print("=" * 64)
    any_fail = False

    files = reconciler_files()
    if not files:
        print("ERROR: no *_results_pkg.pkb.sql reconcilers found under " + PKG_DIR)
        return 2

    for path in files:
        base = os.path.basename(path)
        problems = check_pkg(path)
        if problems:
            any_fail = True
            print("  FAIL  " + base)
            for p in problems:
                print("          - " + p)
        else:
            print("  PASS  " + base)

    print("=" * 64)
    if any_fail:
        print("RESULT: FAIL — a reconciler still fabricates a FAILED for an "
              "unresolved record. Unresolved records must stay GENERATED "
              "(unaccounted); only LOADED (base-confirmed) or FAILED (real Fusion "
              "error) may be written.")
        return 1
    print("RESULT: PASS — %d reconcilers checked; none fabricate a FAILED. "
          "Unresolved records are left GENERATED (unaccounted)." % len(files))
    return 0


if __name__ == "__main__":
    sys.exit(main())
