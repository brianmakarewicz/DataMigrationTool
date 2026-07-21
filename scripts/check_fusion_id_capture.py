#!/usr/bin/env python3
"""
check_fusion_id_capture.py -- conformance checker for the DMT_DESIGN.html
section 7 rule "Reconciliation captures the Fusion base-table id":

    A reconciler may not mark a record TFM_STATUS='LOADED' without, in the
    same UPDATE statement, also assigning that object's FUSION_<entity>_ID
    column (the mirror of the "no FAILED without ERROR_TEXT" rule). HCM/HDL
    objects capture the id through DMT_HDL_UTIL_PKG.LOOKUP_FUSION_IDS instead.

WHAT THIS CHECKS (per the "Checker fidelity" standard -- everything the rule
states is asserted, or explicitly declared NOT CHECKED):

The rule is scoped to each object's DESIGNATED Fusion-id-bearing TFM table --
the one row the section-5 source map assigns it (the header / primary record).
Child / cascade TFM tables (PO lines, req lines, AR distributions, asset books,
grant-award children, ...) inherit LOADED from their parent's status and are NOT
the object's Fusion-id record; the source map lists no Fusion id for them, so
they are exempt (declared below).

FBDI / base-confirming reconcilers (REQUIRED_FBDI):
  For the object's designated TFM table, every UPDATE whose SET clause writes
  TFM_STATUS='LOADED' must, in the same SET clause, also assign the object's
  FUSION_%_ID column (the exact column from the source map). A LOADED update on
  the designated table that omits the column FAILS -- unless it is a DECLARED
  known deviation (KNOWN_IDLESS_LOADED), which prints as WARN with its reason.

HCM/HDL reconcilers (REQUIRED_HDL):
  The reconciler package must call DMT_HDL_UTIL_PKG.LOOKUP_FUSION_IDS (capture
  happens there, in a separate REST-driven statement, not in the LOADED update).

NOT CHECKED (declared):
  - Child / cascade TFM tables (they carry no object Fusion id per the source map).
  - Whether LOOKUP_FUSION_IDS actually populated a row at runtime for a blocked
    HCM object (those objects do not load to their base table on the demo
    instance today; the wiring is asserted statically, the population is not).
  - The BIP recon report actually returning the id (a live-Fusion property);
    the automated PR reviewer and the object's live proof cover that.
  - STG echo-back updates (they set STG_STATUS, not the row's own Fusion id).

Exit code 0 = all designated reconcilers conform (WARNs allowed); non-zero =
at least one undeclared failure. Run from the repo root:
    python scripts/check_fusion_id_capture.py
"""

import os
import re
import sys

PKG_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                       "db", "packages")

# ---------------------------------------------------------------------------
# The section-5 Fusion-id source map, code side: for each FBDI / base-confirming
# reconciler package, the object's DESIGNATED Fusion-id-bearing TFM table(s) and
# the exact FUSION_%_ID column its LOADED update must set. The supplier family
# and Customers own several designated tables (each a distinct object / record).
# ---------------------------------------------------------------------------
REQUIRED_FBDI = {
    "dmt_po_results_pkg":          [("DMT_PO_HEADERS_INT_TFM_TBL", "FUSION_PO_HEADER_ID")],
    "dmt_blanket_po_results_pkg":  [("DMT_PO_HEADERS_INT_TFM_TBL", "FUSION_PO_HEADER_ID")],
    "dmt_contract_results_pkg":    [("DMT_PO_HEADERS_INT_TFM_TBL", "FUSION_PO_HEADER_ID")],
    "dmt_ap_results_pkg":          [("DMT_AP_INVOICES_INT_TFM_TBL", "FUSION_INVOICE_ID")],
    "dmt_req_results_pkg":         [("DMT_POR_REQ_HEADERS_TFM_TBL", "FUSION_REQUISITION_HEADER_ID")],
    "dmt_gl_results_pkg":          [("DMT_GL_INTERFACE_TFM_TBL", "FUSION_JE_HEADER_ID")],
    "dmt_egp_item_results_pkg":    [("DMT_EGP_ITEM_TFM_TBL", "FUSION_INVENTORY_ITEM_ID")],
    "dmt_fa_asset_results_pkg":    [("DMT_FA_ASSET_HDR_TFM_TBL", "FUSION_ASSET_ID")],
    "dmt_expenditure_results_pkg": [("DMT_PJC_EXPENDITURES_TFM_TBL", "FUSION_EXPENDITURE_ITEM_ID")],
    "dmt_billing_event_results_pkg":[("DMT_PJB_BILL_EVENTS_TFM_TBL", "FUSION_EVENT_ID")],
    "dmt_prj_budget_results_pkg":  [("DMT_PRJ_BUDGET_TFM_TBL", "FUSION_BUDGET_VERSION_ID")],
    "dmt_grants_results_pkg":      [("DMT_GMS_AWD_HEADERS_TFM_TBL", "FUSION_AWARD_ID")],
    "dmt_project_results_pkg":     [("DMT_PJF_PROJECTS_TFM_TBL", "FUSION_PROJECT_ID")],
    "dmt_ar_results_pkg":          [("DMT_RA_LINES_TFM_TBL", "FUSION_CUSTOMER_TRX_ID")],
    "dmt_misc_receipt_results_pkg":[("DMT_INV_TRX_TFM_TBL", "FUSION_ID")],
    "dmt_cust_results_pkg": [
        ("DMT_HZ_PARTIES_TFM_TBL",          "FUSION_PARTY_ID"),
        ("DMT_HZ_LOCATIONS_TFM_TBL",        "FUSION_LOCATION_ID"),
        ("DMT_HZ_PARTY_SITES_TFM_TBL",      "FUSION_PARTY_SITE_ID"),
        ("DMT_HZ_PARTY_SITE_USES_TFM_TBL",  "FUSION_PARTY_SITE_USE_ID"),
        ("DMT_HZ_ACCOUNTS_TFM_TBL",         "FUSION_CUST_ACCOUNT_ID"),
        ("DMT_HZ_ACCT_SITES_TFM_TBL",       "FUSION_CUST_ACCT_SITE_ID"),
        ("DMT_HZ_ACCT_SITE_USES_TFM_TBL",   "FUSION_SITE_USE_ID"),
    ],
    "dmt_poz_sup_results_pkg": [
        ("DMT_POZ_SUPPLIERS_TFM_TBL",     "FUSION_VENDOR_ID"),
        ("DMT_POZ_SUP_ADDR_TFM_TBL",      "FUSION_PARTY_SITE_ID"),
        ("DMT_POZ_SUP_SITE_TFM_TBL",      "FUSION_VENDOR_SITE_ID"),
        ("DMT_POZ_SUP_SITE_ASSN_TFM_TBL", "FUSION_ASSIGNMENT_ID"),
        ("DMT_POZ_SUP_CONTACTS_TFM_TBL",  "FUSION_CONTACT_ID"),
    ],
}

# DECLARED deviations: N LOADED updates on a designated table that legitimately
# cannot set the Fusion id because it is unavailable on that code path. Printed
# as WARN (not FAIL) with the reason -- real, pre-existing gaps to resolve
# separately, never a silent pass. Keyed by package -> (idless_count, reason).
KNOWN_IDLESS_LOADED = {
    # BillingEvents Tier-3 fallback: when the recon BIP report cannot confirm a
    # row, PARSE_AND_UPDATE downloads the ESS *import report* and marks a
    # COMPLETE row LOADED from its interface status. That import report returns
    # interface status only -- no PJB_BILLING_EVENTS.EVENT_ID -- so this one
    # fallback LOADED cannot carry the id. Resolve separately (either stop the
    # fallback confirming LOADED without base proof per Rule #1, or extend the
    # import report to return the event id). The primary recon-report BASE and
    # INTERFACE tiers DO set FUSION_EVENT_ID.
    "dmt_billing_event_results_pkg": (1,
        "Tier-3 ESS import-report fallback marks LOADED from interface status; "
        "that import report carries no EVENT_ID"),
}

# HCM / HDL reconcilers -- capture happens via DMT_HDL_UTIL_PKG.LOOKUP_FUSION_IDS
# (a separate REST-driven UPDATE), not in the LOADED update. Assert the call.
REQUIRED_HDL = [
    "dmt_worker_results_pkg", "dmt_assignment_results_pkg", "dmt_salary_results_pkg",
    "dmt_pay_rel_results_pkg", "dmt_talent_prof_results_pkg", "dmt_absence_results_pkg",
    "dmt_tax_card_results_pkg", "dmt_w2_bal_results_pkg", "dmt_work_sched_results_pkg",
    "dmt_perf_eval_results_pkg", "dmt_ben_partic_results_pkg", "dmt_ben_benfy_results_pkg",
    "dmt_ben_depend_results_pkg",
]

# Reconcilers with no positive base-table LOADED path yet (config / not-live):
# no Fusion-id capture to assert. Declared so a green run is honest.
NOT_CHECKED = [
    # GLBudgets -- fetch-then-store deferred. The section-5 source
    # (GL_BUDGET_VERSIONS.BUDGET_VERSION_ID) does not hold on the live instance:
    # GL_BUDGET_VERSIONS does not exist (ORA-00942) and GL_BUDGET_BALANCES (the
    # recon DM's source) has no budget_version_id column. Needs a real source
    # decision (BUDGET_VERSION_ID lives on GL_BALANCES) before it can capture.
    "dmt_gl_budget_results_pkg",
    "dmt_egp_item_cat_results_pkg",  # ItemCategories -- no Fusion-id row in the source map
    "dmt_sal_basis_results_pkg",     # SalaryBasis -- config-tier, not live
    "dmt_gl_calendar_results_pkg",   # GL calendar -- config-tier, not live
    "dmt_ap_pay_term_results_pkg", "dmt_ce_bank_results_pkg",
    "dmt_fnd_lookup_results_pkg", "dmt_fnd_vs_results_pkg",
]

# A statement-terminating UPDATE (stops at the first ';').
STMT = re.compile(r"UPDATE\s+(?:DMT_OWNER\.)?(\w+)(.*?);", re.IGNORECASE | re.DOTALL)


def _set_clause(rest):
    """The text between the table name and the first clause-level WHERE."""
    w = re.search(r"\bWHERE\b", rest, re.IGNORECASE)
    return rest[:w.start()] if w else rest


def _loaded_updates_for(text, table):
    """SET clauses of every UPDATE on `table` whose SET writes LOADED."""
    out = []
    for m in STMT.finditer(text):
        if m.group(1).upper() != table.upper():
            continue
        setc = _set_clause(m.group(2))
        if re.search(r"TFM_STATUS\s*=\s*'LOADED'", setc, re.IGNORECASE):
            out.append(setc)
    return out


def check_fbdi(base, targets):
    """Return (fails, warns) for one FBDI reconciler package."""
    path = os.path.join(PKG_DIR, base + ".pkb.sql")
    if not os.path.exists(path):
        return (["file not found: " + path], [])
    text = open(path, encoding="utf-8", errors="replace").read()
    fails, warns = [], []
    idless = 0
    for table, col in targets:
        loaded = _loaded_updates_for(text, table)
        if not loaded:
            fails.append("no LOADED update found on designated table %s "
                         "(expected the object's success UPDATE)" % table)
            continue
        for setc in loaded:
            if not re.search(r"\b" + re.escape(col) + r"\s*=", setc, re.IGNORECASE):
                idless += 1

    allowed, reason = KNOWN_IDLESS_LOADED.get(base, (0, None))
    if idless > allowed:
        fails.append("%d LOADED update(s) on the designated table omit the "
                     "Fusion id (%d declared as known)" % (idless, allowed))
    elif idless == allowed and allowed > 0:
        warns.append("%d LOADED update(s) intentionally id-less: %s" % (allowed, reason))
    elif allowed > 0 and idless < allowed:
        warns.append("declared %d known id-less LOADED update(s) but found %d "
                     "-- update KNOWN_IDLESS_LOADED if a path was fixed" % (allowed, idless))
    return (fails, warns)


def check_hdl(base):
    path = os.path.join(PKG_DIR, base + ".pkb.sql")
    if not os.path.exists(path):
        return ["file not found: " + path]
    text = open(path, encoding="utf-8", errors="replace").read()
    if not re.search(r"\bLOOKUP_FUSION_IDS\s*\(", text, re.IGNORECASE):
        return ["does not call DMT_HDL_UTIL_PKG.LOOKUP_FUSION_IDS "
                "(HCM/HDL objects capture the Fusion id there)"]
    return []


def main():
    print("Fusion-id capture conformance check (DMT_DESIGN section 7)")
    print("=" * 64)
    any_fail = False

    print("\nREQUIRED (FBDI / base-confirming -- LOADED update must set FUSION_%_ID):")
    for base in sorted(REQUIRED_FBDI):
        fails, warns = check_fbdi(base, REQUIRED_FBDI[base])
        if fails:
            any_fail = True
            print("  FAIL  " + base)
            for p in fails:
                print("          - " + p)
        else:
            print("  PASS  " + base)
        for w in warns:
            print("          WARN: " + w)

    print("\nREQUIRED (HCM/HDL -- must call LOOKUP_FUSION_IDS):")
    for base in REQUIRED_HDL:
        problems = check_hdl(base)
        if problems:
            any_fail = True
            print("  FAIL  " + base)
            for p in problems:
                print("          - " + p)
        else:
            print("  PASS  " + base)

    print("\nNOT CHECKED (declared):")
    print("  - child / cascade TFM tables (no object Fusion id per the source map)")
    print("  - runtime population for blocked HCM objects (wiring asserted, not population)")
    print("  - the BIP report actually returning the id (a live-Fusion property)")
    for base in NOT_CHECKED:
        print("  NOT CHECKED  " + base)

    print("=" * 64)
    if any_fail:
        print("RESULT: FAIL -- at least one reconciler marks LOADED without its Fusion id.")
        return 1
    print("RESULT: PASS -- every designated reconciler captures its Fusion base-table id "
          "(declared WARNs excepted).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
