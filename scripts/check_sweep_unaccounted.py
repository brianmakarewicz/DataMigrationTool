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

EXTENDED 2026-10-07 -- CONFIG RECONCILERS AND THREE MORE RULES
------------------------------------------------------------
The scan set now also covers the CONFIGURATION-object reconcilers, which the
RECONCILE_BATCH filter used to skip: the six *_results_pkg bodies without
RECONCILE_BATCH (dmt_ap_pay_term, dmt_ce_bank, dmt_fnd_lookup, dmt_fnd_vs,
dmt_inv_uom, dmt_zx -- they load by REST / FBDI and reconcile in their own
procedures) and every *_runner_pkg body (the config objects' orchestration). Rules 1-3
above run over the whole extended set, plus:

  4. SWEEP-TAG -- only sanctioned ERROR_TEXT stage tags are WRITTEN. A string literal
     that starts with a stage tag ('[XYZ]...') and is not a read (INSTR / LIKE search)
     is a write. Reconciler and runner bodies may write only [FUSION_ERROR] and
     [IMPORT_REPORT]; dmt_queue_worker_pkg additionally [UNACCOUNTED] (the shared
     sweep); dmt_hdl_util_pkg only [FUSION_ERROR]. Anything else -- [PARENT_FAILED],
     [BATCH_REJECTED], the retired [RECONCILE_ERROR], a reconciler-written [LOAD_ERROR]
     -- is a fabricated tag. Design doc section 5, "ERROR_TEXT tag convention" (the tag
     table: [LOAD_ERROR] is written only by DMT_LOADER_PKG's synchronous load path;
     [RECONCILE_ERROR] is retired, "Do not write [RECONCILE_ERROR]"; [UNACCOUNTED] is
     written ONLY by the shared sweep) and the "Whole-document rejection carries the
     real error to every grain" bullet ("a generic 'parent failed' or 'rejected by
     import' string is not acceptable").
  5. SWEEP-FUSION-ERROR-FORM -- a '[FUSION_ERROR]' literal is the tag followed by
     nothing but a space, OR one of the sanctioned fixed prefixes: the related-record
     form 'The parent record has the following Fusion error: ' (also child /
     parent/child) or the whole-document form ' Rejected with document: '. No status
     code, HTTP code or our own observation may be composed around it ("HTTP 404: ",
     "transport failed: ", "SUBMIT_LOAD failed: "), and outside the whole-document form
     the next concatenated operand may not be another string literal. Design doc
     section 5, tag table, the [FUSION_ERROR] row ("The single permitted construction
     is '[FUSION_ERROR]' || l_fusion_error ... No status code, observation, or
     'cannot verify'-style sentence may ever accompany this tag") and the whole-document
     bullet's "[FUSION_ERROR] Rejected with document: ..." format.
  6. SWEEP-EXPIRED -- our own poll timeout is never treated as a failure. A code path
     that is reached when an ESS poll status is 'EXPIRED' (an IF / ELSIF branch whose
     condition names 'EXPIRED' or C_STATUS_EXPIRED, plus the statements that follow it
     in the same block when the branch does not RETURN / RAISE; or the ELSE branch of
     an IF on a POLL_ESS_JOB x_fusion_status variable whose conditions do not mention
     EXPIRED) may not write ERROR_TEXT (APPEND_ERROR) or set a status to 'FAILED'.
     Design doc section 2, "Timeouts" ("A timeout is a trigger for the failure path,
     never a verdict ... the file's GENERATED rows are left GENERATED (unaccounted) --
     we do not fabricate a [LOAD_ERROR] timeout failure") and section 5, the
     [LOAD_ERROR] tag row (the async poll-timeout path no longer emits the tag).

NOT CHECKED (declared, per the "Checker fidelity" standard in section 7):
  * NOT CHECKED: tags written through a variable built elsewhere (only literals are
    seen); the EXPIRED rule follows one level of variable indirection only by
    covering the whole branch body and the rest of its block.
  * NOT CHECKED: whether the error text a reconciler copies is the RIGHT row's error
    (runtime; regression scenario). The BIP report side is checked by
    scripts/check_bip_recon_reports.py.

KNOWN VIOLATIONS: violations that existed when a rule was introduced are listed in
scripts/standards_known_violations.json with their docs/backlog.html item; only a NEW
violation fails the run (scripts/standards_known_violations.py).

Comments are stripped before scanning, so a comment that merely DESCRIBES a removed
anti-pattern (e.g. "previously stamped '... no row-level error matched'") does not
trip the checker — only real code (SQL literals actually written) can.

A green run means: no reconciler (and neither shared engine body) fabricates a FAILED
or a composed-message UNACCOUNTED for an unresolved record, and the honest sweep writes
only the bare tag.

Exit code 0 = no NEW violation; non-zero = at least one new violation.
Run from the repo root:  python scripts/check_sweep_unaccounted.py
"""

import os
import re
import sys
import glob

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import standards_known_violations as known          # noqa: E402
import standards_sql_lineage as lineage             # noqa: E402

CHECKER = "check_sweep_unaccounted"

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


# Every reconciler package (anything whose body carries RECONCILE_BATCH), the
# CONFIGURATION-object reconcilers (the *_results_pkg bodies WITHOUT RECONCILE_BATCH --
# they reconcile in their own procedures) and every *_runner_pkg body (config-object
# orchestration). We scan by glob so a newly added reconciler is covered automatically,
# then add the two shared engine bodies explicitly.
def scan_files():
    out = []
    for path in sorted(glob.glob(os.path.join(PKG_DIR, "*_results_pkg.pkb.sql"))):
        out.append(path)
    for path in sorted(glob.glob(os.path.join(PKG_DIR, "*_runner_pkg.pkb.sql"))):
        out.append(path)
    for name in EXTRA_SCAN_FILES:
        p = os.path.join(PKG_DIR, name)
        if os.path.exists(p):
            out.append(p)
    return out


def is_config_reconciler(path):
    """A *_results_pkg body without RECONCILE_BATCH (config objects) or a runner."""
    base = os.path.basename(path)
    if base.endswith("_runner_pkg.pkb.sql"):
        return True
    if base.endswith("_results_pkg.pkb.sql"):
        with open(path, encoding="utf-8", errors="replace") as fh:
            return "RECONCILE_BATCH" not in fh.read()
    return False


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


# --------------------------------------------------------------------------
# Rule 4: SWEEP-TAG -- only sanctioned stage tags are written
# --------------------------------------------------------------------------
TAG_LIT_RE = re.compile(r"'{1,2}(\[[A-Z][A-Z_]*\])")
ALLOWED_TAGS = {
    "dmt_queue_worker_pkg.pkb.sql": {"[FUSION_ERROR]", "[IMPORT_REPORT]", "[UNACCOUNTED]"},
    "dmt_hdl_util_pkg.pkb.sql": {"[FUSION_ERROR]"},
}
DEFAULT_ALLOWED_TAGS = {"[FUSION_ERROR]", "[IMPORT_REPORT]"}


def _is_read_context(text, start):
    """True when the literal at `start` is a search value (INSTR / LIKE), not a write."""
    before = text[max(0, start - 160):start]
    return re.search(r"(\bLIKE\s*'?%?|\bINSTR\s*\([^;]*,\s*)$", before, re.I | re.S) \
        is not None


def check_tags(path, text):
    base = os.path.basename(path)
    allowed = ALLOWED_TAGS.get(base, DEFAULT_ALLOWED_TAGS)
    out, seen = [], set()
    for m in TAG_LIT_RE.finditer(text):
        tag = m.group(1)
        if tag in allowed or tag in seen or _is_read_context(text, m.start()):
            continue
        seen.add(tag)
        line = text.count("\n", 0, m.start()) + 1
        out.append(("SWEEP-TAG|%s|%s" % (base, tag),
                    "line %d: writes the unsanctioned ERROR_TEXT tag %s (allowed here: %s)"
                    % (line, tag, ", ".join(sorted(allowed)))))
    return out


# --------------------------------------------------------------------------
# Rule 5: SWEEP-FUSION-ERROR-FORM -- '[FUSION_ERROR]' || <real error>, nothing composed
# --------------------------------------------------------------------------
# A '[FUSION_ERROR]...' literal, either plain ('...') or inside a dynamic-SQL string
# where quotes are doubled (''...''). Group 1 = the opening quote(s), group 2 = text.
FE_LIT_RE = re.compile(r"(?<!')('|'')\[FUSION_ERROR\]((?:(?!\1)[^']|'''')*)\1(?!')")
FE_RELATED_RE = re.compile(r"^ ?The (parent|child|parent/child) record has the following "
                           r"Fusion error: $")
FE_DOCUMENT = " Rejected with document: "


def check_fusion_error_form(path, text):
    base = os.path.basename(path)
    out, seen = [], set()
    for m in FE_LIT_RE.finditer(text):
        rest = m.group(2)
        if _is_read_context(text, m.start()) or rest.startswith(FE_DOCUMENT):
            continue                       # a search, or the whole-document form
        line = text.count("\n", 0, m.start()) + 1
        item = None
        if rest not in ("", " ") and not FE_RELATED_RE.match(rest):
            item = "composed '[FUSION_ERROR]%s'" % rest
        else:
            nxt = re.match(r"\s*\|\|\s*'((?:[^']|'')*)'", text[m.end():])
            if nxt:
                item = "literal after tag '%s'" % nxt.group(1)
        if item is None:
            continue
        item = re.sub(r"\s+", " ", item).strip()[:80]
        key = "SWEEP-FUSION-ERROR-FORM|%s|%s" % (base, item)
        if key in seen:
            continue
        seen.add(key)
        out.append((key, "line %d: [FUSION_ERROR] must be followed only by the real Fusion "
                         "error (or a sanctioned prefix); found %s" % (line, item)))
    return out


# --------------------------------------------------------------------------
# Rule 6: SWEEP-EXPIRED -- our poll timeout is never a failure
# --------------------------------------------------------------------------
def _is_opener(toks, i):
    t = toks[i]
    if t.kind != "ident":
        return False
    if t.val in ("if", "loop", "case"):
        return not (i > 0 and toks[i - 1].kw("end"))
    return t.val == "begin"


def _closer_span(toks, i):
    """END [IF|LOOP|CASE] -> index just after the closer."""
    if i + 1 < len(toks) and toks[i + 1].kw("if", "loop", "case"):
        return i + 2
    return i + 1


def _chain(toks, if_i):
    """Parts of the IF statement at if_i: [(kind, cond_start, cond_end, body_start,
    body_end)] for its IF / ELSIF / ELSE arms, and the index after its END IF."""
    parts = []
    depth = 0
    i = if_i + 1
    kind, cstart, cend, bstart = "if", if_i + 1, None, None
    while i < len(toks):
        t = toks[i]
        if depth == 0 and cend is None and t.kw("then"):
            cend, bstart = i, i + 1
        elif _is_opener(toks, i):
            depth += 1
        elif t.kw("end"):
            if depth == 0:
                parts.append((kind, cstart, cend, bstart, i))
                return parts, _closer_span(toks, i)
            depth -= 1
            i = _closer_span(toks, i) - 1
        elif depth == 0 and t.kw("elsif", "else") and bstart is not None:
            parts.append((kind, cstart, cend, bstart, i))
            kind, cstart, cend, bstart = t.val, i + 1, None, None
            if t.val == "else":
                cend, bstart = i, i + 1
        i += 1
    return parts, len(toks)


def _block_end(toks, start):
    """Index of the END that closes the block enclosing position `start`."""
    depth = 0
    i = start
    while i < len(toks):
        if _is_opener(toks, i):
            depth += 1
        elif toks[i].kw("end"):
            if depth == 0:
                return i
            depth -= 1
            i = _closer_span(toks, i) - 1
        i += 1
    return len(toks)


def _writes(toks, a, b):
    for i in range(a, min(b, len(toks))):
        t = toks[i]
        if t.kind == "ident" and t.val.split(".")[-1] == "append_error":
            return "ERROR_TEXT (APPEND_ERROR)"
        if t.kind == "ident" and t.val.split(".")[-1].endswith("status") \
                and i + 2 < len(toks) and toks[i + 1].kind == "op" \
                and toks[i + 1].val == "=" and toks[i + 2].kind == "str" \
                and toks[i + 2].val == "FAILED" and i > 0 \
                and (toks[i - 1].kw("set") or (toks[i - 1].kind == "op"
                                               and toks[i - 1].val == ",")):
            return "%s = 'FAILED'" % t.val.upper()
    return None


def _exits(toks, a, b):
    return any(toks[i].kw("return", "raise", "goto")
               or (toks[i].kind == "ident" and toks[i].val.endswith("raise_application_error"))
               for i in range(a, min(b, len(toks))))


def _mentions_expired(toks, a, b):
    return any((t.kind == "str" and t.val == "EXPIRED")
               or (t.kind == "ident" and t.val.split(".")[-1] == "c_status_expired")
               for t in toks[a:b])


def _proc_at(toks, i):
    for j in range(i, -1, -1):
        if toks[j].kw("procedure", "function") and j + 1 < len(toks) \
                and toks[j + 1].kind == "ident":
            return toks[j + 1].val.upper()
    return "?"


def check_expired(path, text):
    base = os.path.basename(path)
    toks = lineage.tokenize(text)
    # variables that receive a POLL_ESS_JOB status (x_fusion_status => l_var)
    poll_vars = set()
    for i, t in enumerate(toks):
        if t.kind == "ident" and t.val == "x_fusion_status" and i + 2 < len(toks) \
                and toks[i + 1].kind == "op" and toks[i + 1].val == "=>" \
                and toks[i + 2].kind == "ident":
            poll_vars.add(toks[i + 2].val)
    hits = {}
    for i, t in enumerate(toks):
        if not t.kw("if") or (i > 0 and toks[i - 1].kw("end")):
            continue
        parts, after = _chain(toks, i)
        # (a) an arm whose condition names EXPIRED (plus what follows the IF when the
        #     arm falls through)
        for kind, cs, ce, bs, be in parts:
            if kind != "else" and ce is not None and _mentions_expired(toks, cs, ce):
                w = _writes(toks, bs, be)
                if not w and not _exits(toks, bs, be):
                    w = _writes(toks, after, _block_end(toks, after))
                if w:
                    hits.setdefault(_proc_at(toks, i), w)
        # (b) the ELSE of an IF on a poll-status variable that never names EXPIRED --
        #     EXPIRED falls into that ELSE
        if parts and parts[0][2] is not None and poll_vars:
            cond = toks[parts[0][1]:parts[0][2]]
            names_expired = any(_mentions_expired(toks, p[1], p[2]) for p in parts
                                if p[0] != "else" and p[2] is not None)
            if cond and cond[0].kind == "ident" and cond[0].val in poll_vars \
                    and not names_expired:
                for kind, cs, ce, bs, be in parts:
                    if kind == "else":
                        w = _writes(toks, bs, be)
                        if w:
                            hits.setdefault(_proc_at(toks, i), w)
    out = []
    for proc, w in sorted(hits.items()):
        out.append(("SWEEP-EXPIRED|%s|%s" % (base, proc),
                    "%s: the path taken when the ESS poll returns our own EXPIRED timeout "
                    "writes %s -- a timeout must leave rows GENERATED (unaccounted) for "
                    "reconciliation, never fail them" % (proc, w)))
    return out


def main():
    print("Honest-accounting conformance check (no fabricated FAILED; honest UNACCOUNTED "
          "sweep only; sanctioned tags; no EXPIRED-as-failure)")
    print("=" * 76)

    files = scan_files()
    if not files:
        print("ERROR: no *_results_pkg.pkb.sql reconcilers found under " + PKG_DIR)
        return 2

    found = []
    for path in files:
        base = os.path.basename(path)
        with open(path, encoding="utf-8", errors="replace") as fh:
            # quote-aware comment strip: a '--' inside a string literal is text, not
            # a comment (the regex strip used by rules 1-3 would cut the literal).
            text = lineage.strip_comments(fh.read())
        f = []
        for p in check_fabricated(path):
            f.append(("SWEEP-FABRICATED|%s|%s" % (base, p.split(": ", 1)[-1][:80]), p))
        for p in check_honest_sweep(path):
            f.append(("SWEEP-HONEST|%s|%s" % (base, p[:80]), p))
        f += check_tags(path, text)
        f += check_fusion_error_form(path, text)
        f += check_expired(path, text)
        label = "config" if is_config_reconciler(path) else "      "
        print("  %-4s %s %s" % ("OK" if not f else "VIOL", label, base))
        found += f

    print("\nNOT CHECKED: tags or messages built in a variable elsewhere (literals only)")
    print("NOT CHECKED: whether a copied Fusion error belongs to the RIGHT row (runtime)")
    print("NOT CHECKED: the BIP report SQL itself -- see scripts/check_bip_recon_reports.py")
    rc = known.report(CHECKER, found)
    print("=" * 76)
    if rc:
        print("RESULT: FAIL -- a NEW fabricated FAILED, unsanctioned tag, composed "
              "[FUSION_ERROR] or EXPIRED-as-failure path was found. A reconciler may write "
              "only LOADED (base-confirmed) or FAILED (real Fusion error); still-GENERATED "
              "rows are swept to the honest terminal status UNACCOUNTED with the bare "
              "'[UNACCOUNTED]' tag only -- never an invented reason.")
        return 1
    print("RESULT: PASS -- %d files checked (FBDI + config reconcilers, runners, shared "
          "engine bodies); no new violations." % len(files))
    return 0


if __name__ == "__main__":
    sys.exit(main())
