#!/usr/bin/env python3
"""
check_flag_stg_failed.py — conformance checker for the standard pre-validation
STG-failure flag (DMT_DESIGN.html section 7, "Every validator package that owns an
STG table defines and calls the standard FLAG_STG_FAILED procedure").

WHAT THIS CHECKS (per the "Checker fidelity" standard — everything the rule states
is asserted, or explicitly declared NOT CHECKED):

For every REQUIRED validator package (those that own one or more STG tables and use
the named-helper form):
  1. It defines a procedure  PROCEDURE FLAG_STG_FAILED (p_run_id IN NUMBER)
  2. Its pre-validation entry procedure calls it — a  FLAG_STG_FAILED(p_run_id)
     invocation exists that is NOT the definition line.
  3. Every UPDATE block inside the helper is BYTE-IDENTICAL to the template's fixed
     region: only the STG table name (EDIT-TABLE) and the SUB_OBJECT literal
     (EDIT-SCOPE) may vary; the SET / WHERE / sub-select lines between them must
     match the template character-for-character.
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

Exit code 0 = all REQUIRED packages conform; non-zero = at least one failure.
Run from the repo root:  python scripts/check_flag_stg_failed.py
"""

import os
import re
import sys

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
# An UPDATE block runs from "UPDATE DMT_OWNER.<table>" through its closing ");".
# Lines that may vary (dropped before comparison):
#   * the UPDATE DMT_OWNER.<STG table> line          (EDIT-TABLE)
#   * the   AND SUB_OBJECT = '<display name>'  line   (EDIT-SCOPE)
FIXED_BLOCK_LINES = [
    "        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE",
    "        WHERE  STG_STATUS IN ('NEW','RETRY')",
    "        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL",
    "                                   WHERE RUN_ID = p_run_id",
    "                                  );",
]


def _helper_body(text):
    """Return the source of the FLAG_STG_FAILED procedure, or None."""
    m = re.search(r"PROCEDURE\s+FLAG_STG_FAILED\b", text, re.IGNORECASE)
    if not m:
        return None
    start = m.start()
    end = re.search(r"END\s+FLAG_STG_FAILED\s*;", text[start:], re.IGNORECASE)
    if not end:
        return text[start:]        # unterminated — downstream checks flag it
    return text[start:start + end.end()]


def _fixed_lines_of_blocks(body):
    """Extract, for each UPDATE block, its lines with the two variable lines and all
    comment lines removed — what remains must equal FIXED_BLOCK_LINES exactly."""
    blocks = []
    cur = None
    for raw in body.splitlines():
        if re.match(r"\s*UPDATE\s+DMT_OWNER\.", raw):
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

    # (2) the entry procedure must call it: FLAG_STG_FAILED(p_run_id) that is not
    #     the PROCEDURE definition line.
    calls = [ln for ln in text.splitlines()
             if re.search(r"\bFLAG_STG_FAILED\s*\(\s*p_run_id", ln, re.IGNORECASE)
             and not re.search(r"\bPROCEDURE\b", ln, re.IGNORECASE)]
    if not calls:
        fails.append("FLAG_STG_FAILED is defined but never called with p_run_id "
                     "(expected a call as the last step of the pre-validation entry "
                     "procedure)")

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

    print("=" * 60)
    if any_fail:
        print("RESULT: FAIL — at least one required validator is missing/incorrect.")
        return 1
    print("RESULT: PASS — all %d required validators carry the standard "
          "FLAG_STG_FAILED helper, byte-identical and COMMIT-free." % len(REQUIRED))
    return 0


if __name__ == "__main__":
    sys.exit(main())
