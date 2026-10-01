#!/usr/bin/env python3
"""check_transform_error.py — conformance checker for the transformer
[TRANSFORM_ERROR] accounting path (DMT2 backlog #14).

WHY THIS EXISTS
---------------
DMT_STG_TFM_ERROR_TBL is the table the record-detail view reads to surface rows that
never reached a TFM table as FAILED records carrying their real reason. A transformer
that just RAISEs on failure (the old default) crashes the whole object "unaccounted"
instead of recording the bad row(s). Backlog #14 gave every set-based STG->TFM
transformer the same inline WHEN OTHERS handler the proven PO transformer uses: on
failure it records a '[TRANSFORM_ERROR] ' || SQLERRM row per in-scope, not-yet-TFM,
not-already-recorded STG row, flips those STG rows to FAILED (status only), then
re-RAISEs to preserve job-level behavior.

This script stops a NEW transformer from silently shipping without that handler.

WHAT THIS CHECKS
----------------
For every *_transform_pkg.pkb.sql under db/packages/ that owns a set-based STG->TFM
INSERT (i.e. contains both `INSERT INTO <...>_TFM_TBL` and reads `FROM <...>_STG_TBL`):

  1. The body writes at least one '[TRANSFORM_ERROR] ' tag into DMT_STG_TFM_ERROR_TBL
     (the handler is present), AND
  2. Every distinct TFM table the body INSERTs into is covered by a matching
     [TRANSFORM_ERROR] INSERT ... INTO DMT_STG_TFM_ERROR_TBL (so a multi-tier
     transformer cannot wire only some of its tiers).

Comments are NOT stripped for the presence check (the tag only ever appears as a real
SQL literal in these bodies), but the TFM-table inventory is taken from code.

Exit code 0 = every transformer with a set-based STG->TFM INSERT has the handler for
every tier; non-zero = at least one transformer (or tier) is missing it.
Run from the repo root:  python scripts/check_transform_error.py
"""

import os
import re
import sys
import glob

PKG_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                       "db", "packages")

# The tag every conforming transformer writes onto its error rows.
TRANSFORM_ERROR_TAG = "[TRANSFORM_ERROR]"


def strip_sql_comments(text):
    """Remove /* */ block and -- line comments so a stray ';' inside a comment (e.g.
    the '/* ... RETRY retired; */' note) cannot truncate the INSERT block we scan, and
    so a comment that merely mentions the tag cannot falsely satisfy the presence check.
    Mirrors scripts/check_sweep_unaccounted.py."""
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    text = re.sub(r"--[^\n]*", " ", text)
    return text


def tfm_targets(text):
    """Distinct real TFM tables this body INSERTs into (excluding the error table)."""
    targets = set()
    for m in re.finditer(r"INSERT\s+INTO\s+(DMT_[A-Z0-9_]+_TFM_TBL)", text, re.I):
        targets.add(m.group(1).upper())
    return targets


def error_covered_tfm(text):
    """TFM tables that have a [TRANSFORM_ERROR] accounting block guarding them.

    A conforming block is an INSERT INTO DMT_STG_TFM_ERROR_TBL whose SELECT writes the
    '[TRANSFORM_ERROR] ' tag and whose NOT EXISTS guard references a specific TFM table.
    We collect the TFM tables referenced inside each such block so a multi-tier proc is
    only credited for the tiers it actually wired.
    """
    covered = set()
    for m in re.finditer(
        r"INSERT\s+INTO\s+DMT_STG_TFM_ERROR_TBL.*?;", text, re.I | re.S
    ):
        block = m.group(0)
        if TRANSFORM_ERROR_TAG not in block:
            continue
        for t in re.finditer(r"(DMT_[A-Z0-9_]+_TFM_TBL)", block, re.I):
            covered.add(t.group(1).upper())
    return covered


def scan_files():
    out = []
    for path in sorted(glob.glob(os.path.join(PKG_DIR, "*_transform_pkg.pkb.sql"))):
        with open(path, encoding="utf-8", errors="replace") as fh:
            text = strip_sql_comments(fh.read())
        # Only transformers that own a set-based STG->TFM INSERT are in scope.
        if re.search(r"INSERT\s+INTO\s+DMT_[A-Z0-9_]+_TFM_TBL", text, re.I) and \
           re.search(r"FROM\s+DMT_[A-Z0-9_]+_STG_TBL", text, re.I):
            out.append((path, text))
    return out


def check(path, text):
    problems = []
    if TRANSFORM_ERROR_TAG not in text:
        problems.append("no '[TRANSFORM_ERROR]' handler found — transformer RAISEs "
                        "on failure instead of recording its bad rows (backlog #14)")
        return problems
    targets = tfm_targets(text)
    covered = error_covered_tfm(text)
    missing = sorted(targets - covered)
    for t in missing:
        problems.append("TFM tier %s has a set-based INSERT but no matching "
                        "[TRANSFORM_ERROR] accounting block" % t)
    return problems


def main():
    print("Transformer [TRANSFORM_ERROR] accounting-path conformance check (backlog #14)")
    print("=" * 76)
    files = scan_files()
    if not files:
        print("ERROR: no *_transform_pkg.pkb.sql with a set-based STG->TFM INSERT "
              "found under " + PKG_DIR)
        return 2

    any_fail = False
    for path, text in files:
        base = os.path.basename(path)
        problems = check(path, text)
        if problems:
            any_fail = True
            print("  FAIL  " + base)
            for p in problems:
                print("          - " + p)
        else:
            print("  PASS  " + base)

    print("=" * 76)
    if any_fail:
        print("RESULT: FAIL — a transformer with a set-based STG->TFM INSERT is missing "
              "the [TRANSFORM_ERROR] handler for one or more tiers. Add the inline "
              "WHEN OTHERS handler the proven dmt_po_transform_pkg uses so a failure "
              "records the bad rows as FAILED (with the real reason) instead of "
              "crashing the whole object unaccounted.")
        return 1
    print("RESULT: PASS — %d transformers checked; each set-based STG->TFM INSERT tier "
          "records a [TRANSFORM_ERROR] row on failure." % len(files))
    return 0


if __name__ == "__main__":
    sys.exit(main())
