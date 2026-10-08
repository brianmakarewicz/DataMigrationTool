#!/usr/bin/env python3
"""
check_flag_stg_failed.py — conformance checker for the standard pre-validation
STG-failure flag (DMT_DESIGN.html section 7, "Every validator package that owns an
STG table defines and calls the standard FLAG_STG_FAILED procedure").

WHAT THIS CHECKS (per the "Checker fidelity" standard — everything the rule states
is asserted, or explicitly declared NOT CHECKED):

For every REQUIRED validator package (those that own one or more STG tables and use
the named-helper form):
  1. It defines  PROCEDURE FLAG_STG_FAILED (p_run_id IN NUMBER,
     p_scenario_id IN NUMBER DEFAULT NULL)  — the helper is scenario-scoped.
  2. Its pre-validation entry procedure calls it — a
     FLAG_STG_FAILED(p_run_id, p_scenario_id)  invocation exists that is NOT the
     definition line (a bare FLAG_STG_FAILED(p_run_id) would flag other
     scenarios' rows and fails the check).
  3. Every UPDATE block inside the helper (or, for the supplier template, inside
     its per-object FLAG_<type>_STG_FAILED helpers) is BYTE-IDENTICAL to the
     template's fixed region: only the STG table name (EDIT-TABLE) and the
     SUB_OBJECT literal (EDIT-SCOPE) may vary; the SET / WHERE / scenario / sub-select
     lines between them must match the template character-for-character. The
     scenario line keeps the flag from touching any other scenario's STG rows.
  4. The helper body contains NO  COMMIT  (the caller owns the transaction).

The template is DMT_POZ_SUP_VALIDATOR_PKG (the first object to carry the helper).

EXEMPT (declared, NOT CHECKED here — a green run stays honest):
  * The 8 "inline-pattern" validators (dmt_ar, dmt_billing_event, dmt_cust,
    dmt_expenditure, dmt_grants, dmt_po, dmt_prj_budget, dmt_worker) reject rows by
    setting STG_STATUS='FAILED' directly in the rule UPDATE rather than through a
    separate FLAG_STG_FAILED helper. They own STG tables but predate the helper
    convention. When one is refactored to the named helper, move it to REQUIRED.
  * dmt_plan_budget owns DMT_PLAN_BUDGET_STG_TBL but its object (PlanningBudgets) is
    out of scope and has no row in dmt_cemli_catalog_tbl.sql, so there is no catalog
    SUB_OBJECT to key the helper on. Excluded until PlanningBudgets is in scope.

PART 2 -- NO RECONCILE / FUSION OUTCOME WRITTEN BACK TO STG (rule STG-WRITEBACK)
-------------------------------------------------------------------------------
DMT_DESIGN.html section 7 ("STG rows carry status only, never an error message";
"Reporting derives success from TFM ... never from STG"; the STG-status rule that
names "the illegal staging write-back"). The outcome of a load lives on the TFM row,
which is run-stamped. STG has no RUN_ID, so an outcome copied onto it cannot be tied
to a run, is overwritten by the next run, and (when ERROR_TEXT is appended) grows on
every reconcile rerun -- the Requisitions defect found in PR #627.

The only STG writes the pipeline may make are pre-TFM: the pre-validation flag
(FLAG_STG_FAILED / the inline validator rule UPDATEs), the transformer's
NEW -> TRANSFORMED / transform-failure marks, and the CSV upload's SCENARIO_ID stamp.

Every UPDATE of a *_STG_TBL in db/packages/*.pkb.sql -- static SQL, and dynamic SQL
built as 'UPDATE ' || <variable whose name contains STG> -- is a WRITE-BACK when ANY
of these holds:
  a. it sets STG_STATUS to a load-outcome value ('LOADED', 'GENERATED',
     'UNACCOUNTED');
  b. it sets STG_STATUS from a sub-select (copying TFM_STATUS);
  c. it reads TFM_STATUS anywhere (its rows or values are chosen by a TFM load
     outcome -- e.g. "STG_STATUS='FAILED' WHERE ... TFM_STATUS='FAILED'");
  d. it sets a FUSION_* column, REQUEST_ID or LOAD_REQUEST_ID (Fusion ids);
  e. it sets ERROR_TEXT from a *_TFM_TBL sub-select;
  f. it lives in a reconcile package (any *_results_pkg, dmt_hdl_util_pkg,
     dmt_recon_engine_pkg, dmt_recon_contract_pkg, dmt_queue_worker_pkg,
     dmt_loader_pkg) -- those packages run after the load and have no pre-TFM
     reason to touch STG at all.
Comments are stripped first, so prose that mentions an old write-back cannot trip it.

Key (stable, no line numbers):
    STG-WRITEBACK|<package>|<procedure>|<STG table or dynamic variable>|<SET columns>
Every write-back that existed when the rule was introduced is listed in
scripts/standards_known_violations.json under checker "check_flag_stg_failed", tied
to the backlog item that removes it. Only a NEW write-back fails the run; a listed one
that disappears is reported RESOLVED (delete its entry).

NOT CHECKED: MERGE INTO a *_STG_TBL (none exist today), writes from outside
db/packages, and dynamic SQL whose target-table variable name does not contain "STG".

Exit code 0 = all REQUIRED packages conform AND no NEW write-back; non-zero otherwise.
Run from the repo root:  python scripts/check_flag_stg_failed.py
"""

import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import standards_known_violations as known          # noqa: E402

CHECKER = "check_flag_stg_failed"

PKG_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                       "db", "packages")

TEMPLATE = "dmt_poz_sup_validator_pkg"

# Validator packages that own an STG table AND use the named-helper form.
REQUIRED = [
    "dmt_poz_sup_validator_pkg",        # template
    "dmt_poz_sup_addr_validator_pkg",   "dmt_poz_sup_site_validator_pkg",
    "dmt_poz_sup_site_assn_validator_pkg","dmt_poz_sup_cont_validator_pkg",
    "dmt_ap_validator_pkg",             "dmt_ap_pay_term_validator_pkg",
    "dmt_req_validator_pkg",            "dmt_misc_receipt_validator_pkg",
    "dmt_gl_validator_pkg",             "dmt_gl_budget_validator_pkg",
    "dmt_gl_calendar_validator_pkg",    "dmt_fa_asset_validator_pkg",
    "dmt_project_validator_pkg",        "dmt_egp_item_validator_pkg",
    "dmt_egp_item_cat_validator_pkg",   "dmt_inv_uom_validator_pkg",
    "dmt_fnd_lookup_validator_pkg",     "dmt_fnd_vs_validator_pkg",
    "dmt_zx_validator_pkg",             "dmt_ce_bank_validator_pkg",
    "dmt_assignment_validator_pkg",     "dmt_salary_validator_pkg",
    "dmt_sal_basis_validator_pkg",      "dmt_pay_rel_validator_pkg",
    "dmt_tax_card_validator_pkg",       "dmt_w2_bal_validator_pkg",
    "dmt_absence_validator_pkg",        "dmt_talent_prof_validator_pkg",
    "dmt_perf_eval_validator_pkg",      "dmt_work_sched_validator_pkg",
    "dmt_ben_partic_validator_pkg",     "dmt_ben_depend_validator_pkg",
    "dmt_ben_benfy_validator_pkg",
]

# Own STG tables but do NOT use the named helper — see the module docstring.
EXEMPT = [
    "dmt_ar_validator_pkg",       "dmt_billing_event_validator_pkg",
    "dmt_cust_validator_pkg",     "dmt_expenditure_validator_pkg",
    "dmt_grants_validator_pkg",   "dmt_po_validator_pkg",
    "dmt_prj_budget_validator_pkg","dmt_worker_validator_pkg",
    "dmt_plan_budget_validator_pkg",
]

# The template's fixed UPDATE-block region, with the two variable lines removed.
# An UPDATE block runs from "UPDATE <table>" through its closing ");".
# Lines that may vary (dropped before comparison):
#   * the UPDATE <STG table> line          (EDIT-TABLE)
#   * the   AND SUB_OBJECT = '<display name>'  line   (EDIT-SCOPE)
FIXED_BLOCK_LINES = [
    "        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE",
    "        WHERE  STG_STATUS IN ('NEW','TRANSFORMED')",
    "        AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id)",
    "        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL",
    "                                   WHERE RUN_ID = p_run_id",
    "                                  );",
]

SIGNATURE_RE = re.compile(
    r"PROCEDURE\s+FLAG_STG_FAILED\s*\(\s*p_run_id\s+IN\s+NUMBER\s*,\s*"
    r"p_scenario_id\s+IN\s+NUMBER\s+DEFAULT\s+NULL\s*\)", re.IGNORECASE)


def _helper_body(text):
    """Return the source of every FLAG_*STG_FAILED procedure (the standard helper
    plus, for the supplier template, its per-object flaggers), or None."""
    bodies = []
    for m in re.finditer(r"PROCEDURE\s+(FLAG_\w*STG_FAILED)\b", text, re.IGNORECASE):
        start = m.start()
        end = re.search(r"END\s+" + m.group(1) + r"\s*;", text[start:], re.IGNORECASE)
        bodies.append(text[start:] if not end else text[start:start + end.end()])
    if not any(re.match(r"PROCEDURE\s+FLAG_STG_FAILED\b", b, re.IGNORECASE) for b in bodies):
        return None
    return "\n".join(bodies)


def _fixed_lines_of_blocks(body):
    """Extract, for each UPDATE block, its lines with the two variable lines and all
    comment lines removed — what remains must equal FIXED_BLOCK_LINES exactly."""
    blocks = []
    cur = None
    for raw in body.splitlines():
        if re.match(r"\s*UPDATE\s+(DMT_OWNER\.)?DMT_\w+_STG_TBL\b", raw):
            if cur is not None:
                blocks.append(cur)
            cur = []
            continue                       # drop the variable UPDATE line
        if cur is None:
            continue
        s = raw.strip()
        if s.startswith("--"):
            continue                       # drop tag/comment lines
        if re.match(r"\s*AND SUB_OBJECT = '", raw):
            continue                       # drop the variable SUB_OBJECT line
        cur.append(raw)
        if s.endswith(");"):
            blocks.append(cur)
            cur = None
    if cur is not None:
        blocks.append(cur)
    return blocks


def check_pkg(base):
    path = os.path.join(PKG_DIR, base + ".pkb.sql")
    if not os.path.exists(path):
        return ["file not found: " + path]
    with open(path, encoding="utf-8", errors="replace") as fh:
        text = fh.read()

    body = _helper_body(text)
    if body is None:
        return ["no PROCEDURE FLAG_STG_FAILED defined"]

    fails = []

    # (1) scenario-scoped signature
    if not SIGNATURE_RE.search(text):
        fails.append("FLAG_STG_FAILED is not declared as (p_run_id IN NUMBER, "
                     "p_scenario_id IN NUMBER DEFAULT NULL)")

    # (2) the entry procedure must call it with the scenario:
    #     FLAG_STG_FAILED(p_run_id, p_scenario_id) that is not the definition line.
    #     A bare FLAG_STG_FAILED(p_run_id) call is an unscoped flag and fails.
    code_lines = [ln for ln in text.splitlines()
                  if not ln.strip().startswith("--")
                  and not re.search(r"\bPROCEDURE\b", ln, re.IGNORECASE)]
    calls = [ln for ln in code_lines
             if re.search(r"\bFLAG_STG_FAILED\s*\(\s*p_run_id\s*,\s*p_scenario_id\s*\)",
                          ln, re.IGNORECASE)]
    bare = [ln for ln in code_lines
            if re.search(r"\bFLAG_STG_FAILED\s*\(\s*p_run_id\s*\)", ln, re.IGNORECASE)]
    if not calls:
        fails.append("FLAG_STG_FAILED is defined but never called with "
                     "(p_run_id, p_scenario_id) (expected a call as the last step of "
                     "the pre-validation entry procedure)")
    if bare:
        fails.append("FLAG_STG_FAILED(p_run_id) is called without p_scenario_id "
                     "(an unscoped flag would mark other scenarios' STG rows FAILED)")

    # (3) byte-identical fixed region for every UPDATE block
    blocks = _fixed_lines_of_blocks(body)
    if not blocks:
        fails.append("helper defines no UPDATE block")
    for idx, blk in enumerate(blocks, start=1):
        if blk != FIXED_BLOCK_LINES:
            fails.append("UPDATE block #%d fixed region differs from the template "
                         "(only the STG table name and the SUB_OBJECT literal may "
                         "vary)" % idx)

    # (4) no COMMIT inside the helper
    if re.search(r"\bCOMMIT\b", body, re.IGNORECASE):
        fails.append("helper body contains a COMMIT (the caller must own the "
                     "transaction)")
    return fails


# ---------------------------------------------------------------------------
# PART 2 -- STG-WRITEBACK
# ---------------------------------------------------------------------------

# Packages that run after the load; any STG UPDATE in them is a write-back (rule f).
RECONCILE_PKG_RE = re.compile(
    r"^(dmt_\w+_results_pkg|dmt_hdl_util_pkg|dmt_recon_engine_pkg|"
    r"dmt_recon_contract_pkg|dmt_queue_worker_pkg|dmt_loader_pkg)$")

STATIC_UPD_RE = re.compile(r"\bUPDATE\s+(?:DMT_OWNER\.)?(DMT_\w*_STG_TBL)\b", re.I)
DYNAMIC_UPD_RE = re.compile(r"'\s*UPDATE\s*'\s*\|\|\s*(\w*STG\w*)", re.I)
PROC_RE = re.compile(r"^\s*(?:PROCEDURE|FUNCTION)\s+(\w+)", re.I | re.M)


def _strip_comments_keep_lines(text):
    """Blank out -- and /* */ comments (outside string literals), keeping every
    newline so line numbers still match the file."""
    out = []
    i, n = 0, len(text)
    in_str = False
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if c == "'":
                in_str = False
            i += 1
            continue
        if c == "'":
            in_str = True
            out.append(c)
            i += 1
        elif text.startswith("--", i):
            j = text.find("\n", i)
            j = n if j < 0 else j
            out.append(" " * (j - i))
            i = j
        elif text.startswith("/*", i):
            j = text.find("*/", i + 2)
            j = n if j < 0 else j + 2
            out.append(re.sub(r"[^\n]", " ", text[i:j]))
            i = j
        else:
            out.append(c)
            i += 1
    return "".join(out)


def _stmt_end(text, start):
    """Index of the ';' that ends the statement starting at start (outside quotes)."""
    in_str = False
    for k in range(start, len(text)):
        c = text[k]
        if c == "'":
            in_str = not in_str
        elif c == ";" and not in_str:
            return k
    return len(text)


def _split_depth0(s, sep_re):
    """Find the first depth-0 match of sep_re in s; return its start or -1."""
    depth = 0
    for k, c in enumerate(s):
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
        elif depth == 0:
            m = sep_re.match(s, k)
            if m and (k == 0 or not (s[k - 1].isalnum() or s[k - 1] == "_")):
                return k
    return -1


def _set_assignments(stmt):
    """Return [(column, rhs)] of the statement's SET clause (depth-0 commas)."""
    m = re.search(r"\bSET\b", stmt, re.I)
    if not m:
        return []
    body = stmt[m.end():]
    w = _split_depth0(body, re.compile(r"WHERE\b", re.I))
    if w >= 0:
        body = body[:w]
    parts, depth, cur = [], 0, []
    for c in body:
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
        if c == "," and depth == 0:
            parts.append("".join(cur))
            cur = []
        else:
            cur.append(c)
    parts.append("".join(cur))
    out = []
    for p in parts:
        mm = re.match(r"\s*(?:\w+\.)?(\w+)\s*=\s*(.*)$", p, re.S)
        if mm:
            out.append((mm.group(1).upper(), mm.group(2).strip()))
    return out


def _proc_at(text, pos):
    name = "<package>"
    for m in PROC_RE.finditer(text, 0, pos):
        name = m.group(1).upper()
    return name


def _classify(pkg, stmt):
    """Return (set_signature, [reasons]) -- reasons empty means not a write-back."""
    up = stmt.upper()
    sets = _set_assignments(stmt)
    reasons = []
    sig = []
    for col, rhs in sets:
        if col == "LAST_UPDATED_DATE":
            continue
        rhs_u = rhs.upper()
        if col == "STG_STATUS":
            lit = re.match(r"'([A-Z_]+)'", rhs_u)
            if lit:
                sig.append("STG_STATUS=" + lit.group(1))
                if lit.group(1) in ("LOADED", "GENERATED", "UNACCOUNTED"):
                    reasons.append("sets STG_STATUS='%s' (a load outcome)" % lit.group(1))
            elif rhs_u.startswith("("):
                sig.append("STG_STATUS=<subselect>")
                reasons.append("copies STG_STATUS from a sub-select (TFM outcome)")
            else:
                sig.append("STG_STATUS=<expr>")
        else:
            sig.append(col)
            if col.startswith("FUSION_") or col in ("REQUEST_ID", "LOAD_REQUEST_ID"):
                reasons.append("sets Fusion id column %s" % col)
            if col == "ERROR_TEXT" and re.search(r"\w+_TFM_TBL\b", rhs_u):
                reasons.append("copies ERROR_TEXT from a TFM row")
    if re.search(r"\bTFM_STATUS\b", up):
        reasons.append("is driven by TFM_STATUS (a load outcome)")
    if RECONCILE_PKG_RE.match(pkg):
        reasons.append("is in a reconcile package")
    return ",".join(sig) or "<none>", reasons


def scan_stg_writebacks(pkg_dir=PKG_DIR):
    """Return [(key, message)] for every STG write-back in db/packages."""
    found = []
    seen = {}
    for path in sorted(glob.glob(os.path.join(pkg_dir, "*.pkb.sql"))):
        pkg = os.path.basename(path)[:-len(".pkb.sql")]
        with open(path, encoding="utf-8", errors="replace") as fh:
            text = _strip_comments_keep_lines(fh.read())
        hits = []
        for m in STATIC_UPD_RE.finditer(text):
            hits.append((m.start(), m.group(1).upper(), text[m.start():_stmt_end(text, m.start())]))
        for m in DYNAMIC_UPD_RE.finditer(text):
            # dynamic SQL: the literal quotes are doubled inside the string
            end = _stmt_end(text, m.end())
            raw = text[m.start():end]
            stmt = re.sub(r"'\s*\|\|\s*'", "", raw).replace("''", "'")
            stmt = re.split(r"\bUSING\b", stmt, flags=re.I)[0]
            hits.append((m.start(), m.group(1).lower(), stmt))
        for pos, target, stmt in sorted(hits):
            sig, reasons = _classify(pkg, stmt)
            if not reasons:
                continue
            line = text.count("\n", 0, pos) + 1
            proc = _proc_at(text, pos)
            base = "STG-WRITEBACK|%s|%s|%s|%s" % (pkg, proc, target, sig)
            seen[base] = seen.get(base, 0) + 1
            key = base if seen[base] == 1 else "%s#%d" % (base, seen[base])
            msg = ("db/packages/%s.pkb.sql:%d %s.%s UPDATE %s SET %s -- %s"
                   % (pkg, line, pkg.upper(), proc, target, sig, "; ".join(reasons)))
            found.append((key, msg))
    return found


def main():
    print("FLAG_STG_FAILED conformance check")
    print("=" * 60)
    any_fail = False

    print("\nREQUIRED (validators that own an STG table, named-helper form):")
    for base in REQUIRED:
        problems = check_pkg(base)
        if problems:
            any_fail = True
            print("  FAIL  " + base)
            for p in problems:
                print("          - " + p)
        else:
            print("  PASS  " + base)

    print("\nEXEMPT (own an STG table but do NOT use the named helper — the 8 inline-")
    print("pattern validators reject rows in the rule UPDATE itself, and dmt_plan_budget")
    print("has no in-scope catalog SUB_OBJECT; move to REQUIRED when refactored):")
    for base in EXEMPT:
        print("  EXEMPT  " + base)

    print("\n" + "=" * 60)
    print("STG-WRITEBACK: no reconcile / Fusion outcome written back to a *_STG_TBL")
    wb = scan_stg_writebacks()
    wb_rc = known.report(CHECKER, wb)

    print("=" * 60)
    if any_fail:
        print("RESULT: FAIL -- at least one required validator is missing/incorrect.")
    if wb_rc:
        print("RESULT: FAIL -- a NEW STG write-back exists (the load outcome belongs "
              "on the TFM row only; see DMT_DESIGN.html section 7).")
    if any_fail or wb_rc:
        return 1
    print("RESULT: PASS -- all %d required validators carry the standard "
          "FLAG_STG_FAILED helper, byte-identical and COMMIT-free; no new STG "
          "write-back." % len(REQUIRED))
    return 0


if __name__ == "__main__":
    sys.exit(main())
