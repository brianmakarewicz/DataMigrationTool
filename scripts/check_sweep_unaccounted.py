#!/usr/bin/env python3
"""check_sweep_unaccounted.py — conformance checker for the honest-accounting rule
(DMT_DESIGN.html section 7, "A reconciler never fabricates a FAILED — unresolved
records stay UNACCOUNTED").

HISTORY / WHY THIS INVERTED, THEN EVOLVED
-----------------------------------------
This script originally REQUIRED every FBDI reconciler to define and call a standard
SWEEP_UNACCOUNTED procedure that marked every non-terminal TFM row FAILED with a
generic '[RECONCILE_ERROR] ... not confirmed in Fusion ...' message. That generic
message was a FABRICATED fallback: it asserted "failed" when we had only failed to
find the record. It hid unaccounted items behind a false FAILED.

The rule was reversed (owner-directed, 2026-07-20): a reconciler may mark a record
LOADED (real base-table confirmation) or FAILED (with a REAL Fusion per-record error)
only. It must never fabricate a failure — never invent a message asserting an outcome
it did not observe. That BAN ON FABRICATION STILL STANDS and is what this script
enforces.

What changed after that (PR #218/#219/#220): unresolved rows no longer merely REST at
GENERATED. After reconciliation, one shared honest sweep —
DMT_QUEUE_WORKER_PKG.SWEEP_UNACCOUNTED (the repurposed former
MARK_GENERATED_ROWS_FAILED) — flips every still-GENERATED row to the new STORED
TERMINAL status TFM_STATUS='UNACCOUNTED' and appends ONLY the bare '[UNACCOUNTED]'
tag. This is NOT a fabricated failure: UNACCOUNTED is a real, countable, honest status
(not FAILED), and the tag carries NO composed reason. GENERATED is now purely
in-flight. So the honest SWEEP_UNACCOUNTED is ALLOWED; what remains banned is any
composed-message FAILED (or composed-message UNACCOUNTED).

WHAT THIS CHECKS NOW
--------------------
Across every reconciler package (all *_RESULTS_PKG that carry RECONCILE_BATCH) AND the
two shared engine bodies that also write terminal TFM outcomes
(dmt_queue_worker_pkg.pkb.sql, dmt_hdl_util_pkg.pkb.sql):

  1. NO fabricated reconcile-fallback message text — the generic "we could not find
     it, so we call it failed" family that asserted a failure we never observed.
  2. The honest sweep is permitted: the mere NAME SWEEP_UNACCOUNTED and calls to it are
     NO LONGER banned (that was the old fabricating sweep; the new one is honest).
  3. Positive check on the honest sweep: the single UNACCOUNTED write in
     DMT_QUEUE_WORKER_PKG.SWEEP_UNACCOUNTED must append ONLY the bare '[UNACCOUNTED]'
     tag — no other text may be concatenated into that UNACCOUNTED ERROR_TEXT write.

Comments are stripped before scanning, so a comment that merely DESCRIBES a removed
anti-pattern (e.g. "previously stamped '... no row-level error matched'") does not
trip the checker — only real code (SQL literals actually written) can.

A green run means: no reconciler (and neither shared engine body) fabricates a FAILED
or a composed-message UNACCOUNTED for an unresolved record, and the honest sweep writes
only the bare tag.

Exit code 0 = conforms; non-zero = at least one fabricating site remains.
Run from the repo root:  python scripts/check_sweep_unaccounted.py
"""

import os
import re
import sys
import glob

PKG_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                       "db", "packages")

# The two shared engine bodies that also write terminal TFM outcomes and therefore
# must be scanned for fabricated messages, closing the blind spot where a fabricated
# FAILED could hide outside the *_results_pkg reconcilers.
EXTRA_SCAN_FILES = [
    "dmt_queue_worker_pkg.pkb.sql",
    "dmt_hdl_util_pkg.pkb.sql",
]


def strip_sql_comments(text):
    """Remove -- line comments and /* */ block comments so that a comment which merely
    DESCRIBES a removed fabricated message (e.g. quoting the old banned string to
    explain why it is gone) does not trip the fabricated-phrase patterns. Only real
    code — actual SQL literals written onto rows — should be able to fail this check."""
    # Block comments first (non-greedy, across newlines).
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    # Then line comments to end of line.
    text = re.sub(r"--[^\n]*", " ", text)
    return text


# Fabricated-fallback signatures that must never reappear as CODE in a reconciler or
# shared engine body. These are the generic "we could not find it, so we call it
# failed" strings that only ever appeared as fabricated ERROR_TEXT written onto a
# FAILED row.
#
# NOTE — what is intentionally NOT here:
#   * The procedure name SWEEP_UNACCOUNTED and calls to it are NO LONGER banned: the
#     current SWEEP_UNACCOUNTED is the honest sweep (writes the real terminal status
#     UNACCOUNTED + bare tag), not the old fabricating one.
#   * A legitimate LOG line may truthfully say "BIP returned 0 rows" before an
#     import-report fallback, so the bare phrase is not banned; only the fabricated
#     "0 rows ... Parent ... not reconciled" cascade is.
#   * A work-queue transient-retry cap that sets WORK_STATUS='FAILED' with "could not
#     be verified after N attempts" is a truthful work-item message about a transport
#     failure, not a fabricated per-record TFM outcome, so the bare "could not be
#     verified" phrase is not banned — only the compound
#     "not confirmed in Fusion ... could not be verified" fabrication is.
FABRICATED_PATTERNS = [
    re.compile(r"not confirmed in Fusion.*could not be verified", re.I | re.S),
    re.compile(r"import outcome could not be verified", re.I),
    re.compile(r"no row-level error matched", re.I),
    re.compile(r"Cannot verify Fusion outcome", re.I),
    re.compile(r"No reconciliation data returned", re.I),
    re.compile(r"BIP returned 0 rows\.\s*Parent header not reconciled", re.I),
    # Composed sentences removed 2026-07-21 (reconciler-composed-to-unaccounted).
    # These asserted an outcome the tool did not observe from a real Fusion error,
    # and are now the honest sweep's job (row -> UNACCOUNTED), never a FAILED.
    re.compile(r"In interface but not created in base", re.I),
    re.compile(r"import did not post it", re.I),
    # The Expenditure-family "(status <expr>) -- import ..." composed template.
    re.compile(r"\(status\s*'\s*\|\|.*?\|\|\s*'\)\s*--\s*import", re.I | re.S),
    re.compile(r"was not loaded", re.I),
    re.compile(r"did not process this invoice", re.I),
    # "No <thing> mapping found" composed observations (TermId/BankPartyId/etc.).
    re.compile(r"No \w+ mapping found", re.I),
    # A composed "Interface status: X" label used as ERROR_TEXT — whether written
    # directly ('[FUSION_ERROR] Interface status: ' || status) or as the NVL
    # fallback (NVL(error_msg, 'Interface status: ' || status)) where a NULL Fusion
    # message would make the composed status label the entire stored message. Both
    # are now converted: a NULL message leaves the row GENERATED for the sweep.
    re.compile(r"'\s*Interface status:\s*'\s*\|\|", re.I),
]


# Every reconciler package (anything whose body carries RECONCILE_BATCH). We scan by
# glob so a newly added reconciler is covered automatically, then add the two shared
# engine bodies explicitly.
def scan_files():
    out = []
    for path in sorted(glob.glob(os.path.join(PKG_DIR, "*_results_pkg.pkb.sql"))):
        with open(path, encoding="utf-8", errors="replace") as fh:
            if "RECONCILE_BATCH" in fh.read():
                out.append(path)
    for name in EXTRA_SCAN_FILES:
        p = os.path.join(PKG_DIR, name)
        if os.path.exists(p):
            out.append(p)
    return out


def check_fabricated(path):
    fails = []
    with open(path, encoding="utf-8", errors="replace") as fh:
        raw = fh.read()
    text = strip_sql_comments(raw)

    for pat in FABRICATED_PATTERNS:
        m = pat.search(text)
        if m:
            line = text.count("\n", 0, m.start()) + 1
            snippet = m.group(0).replace("\n", " ")[:80]
            fails.append("line %d: fabricated-fallback message found in code: %s"
                         % (line, snippet))
    return fails


# Positive check on the honest sweep: within DMT_QUEUE_WORKER_PKG.SWEEP_UNACCOUNTED the
# UNACCOUNTED write must append ONLY the bare '[UNACCOUNTED]' tag. We isolate the
# procedure body, find where it sets a status column to 'UNACCOUNTED', and confirm the
# ERROR_TEXT it writes on that same UPDATE appends the bare tag and nothing else (no
# other quoted literal concatenated into that UNACCOUNTED write).
def check_honest_sweep(path):
    fails = []
    with open(path, encoding="utf-8", errors="replace") as fh:
        raw = fh.read()
    text = strip_sql_comments(raw)

    m = re.search(r"PROCEDURE\s+SWEEP_UNACCOUNTED\b", text, re.I)
    if not m:
        # No sweep in this file — nothing to assert here.
        return fails
    # Body runs to END SWEEP_UNACCOUNTED.
    end = re.search(r"END\s+SWEEP_UNACCOUNTED\b", text[m.end():], re.I)
    body = text[m.end(): m.end() + end.start()] if end else text[m.end():]

    # It must actually set the status to 'UNACCOUNTED'.
    if not re.search(r"=\s*''UNACCOUNTED''", body):
        fails.append("SWEEP_UNACCOUNTED does not set a status to 'UNACCOUNTED' "
                     "(expected the honest terminal write)")
        return fails

    # The APPEND_ERROR call in the sweep must carry only the bare '[UNACCOUNTED]' tag.
    appends = re.findall(r"APPEND_ERROR\s*\([^)]*\)", body, re.I | re.S)
    if not appends:
        fails.append("SWEEP_UNACCOUNTED sets 'UNACCOUNTED' but appends no "
                     "'[UNACCOUNTED]' tag")
        return fails
    for call in appends:
        # Collect quoted literals inside the APPEND_ERROR argument list. In the
        # doubled-quote dynamic-SQL string these appear as ''[UNACCOUNTED]''.
        lits = re.findall(r"''([^']*)''", call)
        extra = [lit for lit in lits if lit != "[UNACCOUNTED]"]
        if "[UNACCOUNTED]" not in lits:
            fails.append("SWEEP_UNACCOUNTED APPEND_ERROR does not write the bare "
                         "'[UNACCOUNTED]' tag: " + call.replace("\n", " ")[:100])
        if extra:
            fails.append("SWEEP_UNACCOUNTED composes extra text into the UNACCOUNTED "
                         "write (only the bare '[UNACCOUNTED]' tag is allowed): "
                         + ", ".join(repr(e) for e in extra))
    return fails


def main():
    print("Honest-accounting conformance check "
          "(no fabricated FAILED; honest UNACCOUNTED sweep only)")
    print("=" * 64)
    any_fail = False

    files = scan_files()
    if not files:
        print("ERROR: no *_results_pkg.pkb.sql reconcilers found under " + PKG_DIR)
        return 2

    for path in files:
        base = os.path.basename(path)
        problems = check_fabricated(path)
        problems += check_honest_sweep(path)
        if problems:
            any_fail = True
            print("  FAIL  " + base)
            for p in problems:
                print("          - " + p)
        else:
            print("  PASS  " + base)

    print("=" * 64)
    if any_fail:
        print("RESULT: FAIL — a fabricated FAILED (or a composed-message UNACCOUNTED) "
              "was found. A reconciler may write only LOADED (base-confirmed) or "
              "FAILED (real Fusion error); still-GENERATED rows are swept to the "
              "honest terminal status UNACCOUNTED with the bare '[UNACCOUNTED]' tag "
              "only — never an invented reason.")
        return 1
    print("RESULT: PASS — %d files checked (reconcilers + shared engine bodies); none "
          "fabricate a FAILED or compose an UNACCOUNTED message; the honest sweep "
          "writes only the bare '[UNACCOUNTED]' tag." % len(files))
    return 0


if __name__ == "__main__":
    sys.exit(main())
