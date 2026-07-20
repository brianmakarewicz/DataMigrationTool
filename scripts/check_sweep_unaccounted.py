#!/usr/bin/env python3
"""
check_sweep_unaccounted.py — conformance checker for the standard reconcile-error
sweep (DMT_DESIGN.html section 7, "Every reconciler package defines and calls the
standard SWEEP_UNACCOUNTED procedure").

WHAT THIS CHECKS (per the "Checker fidelity" standard — everything the rule states
is asserted, or explicitly declared NOT CHECKED):

For every REQUIRED reconciler package (the FBDI / base-confirming reconcilers):
  1. It defines a procedure  PROCEDURE SWEEP_UNACCOUNTED (...)
  2. RECONCILE_BATCH calls it — a  SWEEP_UNACCOUNTED(p_run_id...  invocation exists
     that is NOT the definition line.
  3. The sweep body uses the fixed status predicate  TFM_STATUS NOT IN ('LOADED','FAILED')
  4. The sweep body tags failures with the literal  [RECONCILE_ERROR]
  5. The sweep procedure body contains NO  COMMIT  (RECONCILE_BATCH owns the txn).
  6. The sweep takes a p_work_queue_id argument and scopes its UPDATE by it
     (work-queue-ID core, 2026-07-20): the signature carries p_work_queue_id, and
     the body carries the scope predicate
       (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id)
     so each work-queue item sweeps only its own partition's rows. This is what
     makes batch N's reconcile stop failing batch N+1's still-STAGED rows.

DEFERRED packages (HCM / HDL reconcilers, and config reconcilers) do NOT yet carry
the sweep — they reconcile via a REST/HDL model that does not positively confirm
base-table LOADED (the separate "Contract v1 reports for the 14 HDL objects"
backlog item). They are listed and printed as NOT CHECKED so a green run is honest.
When an HDL/config object gains base-tier reconciliation, move it from DEFERRED to
REQUIRED here in the same PR that adds its SWEEP_UNACCOUNTED.

NOT CHECKED (declared): byte-for-byte identity of the fixed regions across packages
(the tagged EDIT-region diff) — this checker asserts the load-bearing fixed lines
above but does not diff every fixed character; the automated PR reviewer covers the
rest. The EDIT-SCOPE == catalog ROW_FILTER equality for shared-table objects is
NOT CHECKED here (only the PO family shares tables; verified by review).

Exit code 0 = all REQUIRED packages conform; non-zero = at least one failure.
Run from the repo root:  python scripts/check_sweep_unaccounted.py
"""

import os
import re
import sys

PKG_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                       "db", "packages")

# FBDI / base-confirming reconcilers — MUST carry the standard sweep.
# (dmt_poz_sup_results_pkg is the documented multi-CEMLI exception: its sweep is
#  SWEEP_UNACCOUNTED(p_run_id, p_cemli_code). The checks below accept that form.)
REQUIRED = [
    "dmt_po_results_pkg",        "dmt_gl_results_pkg",
    "dmt_blanket_po_results_pkg","dmt_contract_results_pkg",
    "dmt_ap_results_pkg",        "dmt_expenditure_results_pkg",
    "dmt_req_results_pkg",       "dmt_egp_item_results_pkg",
    "dmt_egp_item_cat_results_pkg","dmt_gl_budget_results_pkg",
    "dmt_grants_results_pkg",    "dmt_billing_event_results_pkg",
    "dmt_prj_budget_results_pkg","dmt_cust_results_pkg",
    "dmt_ar_results_pkg",        "dmt_project_results_pkg",
    "dmt_fa_asset_results_pkg",  "dmt_misc_receipt_results_pkg",
    "dmt_poz_sup_results_pkg",
]

# HCM/HDL + config reconcilers — sweep deferred until base-tier reconciliation exists.
DEFERRED = [
    "dmt_worker_results_pkg",    "dmt_salary_results_pkg",
    "dmt_sal_basis_results_pkg", "dmt_assignment_results_pkg",
    "dmt_talent_prof_results_pkg","dmt_absence_results_pkg",
    "dmt_pay_rel_results_pkg",   "dmt_perf_eval_results_pkg",
    "dmt_tax_card_results_pkg",  "dmt_w2_bal_results_pkg",
    "dmt_work_sched_results_pkg","dmt_ben_benfy_results_pkg",
    "dmt_ben_depend_results_pkg","dmt_ben_partic_results_pkg",
    "dmt_gl_calendar_results_pkg",
]


def _sweep_body(text):
    """Return the source of the SWEEP_UNACCOUNTED procedure body, or None."""
    m = re.search(r"PROCEDURE\s+SWEEP_UNACCOUNTED\b", text, re.IGNORECASE)
    if not m:
        return None
    start = m.start()
    end = re.search(r"END\s+SWEEP_UNACCOUNTED\s*;", text[start:], re.IGNORECASE)
    if not end:
        return text[start:]        # unterminated — let downstream checks flag it
    return text[start:start + end.end()]


def check_pkg(base):
    path = os.path.join(PKG_DIR, base + ".pkb.sql")
    fails = []
    if not os.path.exists(path):
        return ["file not found: " + path]
    with open(path, encoding="utf-8", errors="replace") as fh:
        text = fh.read()

    body = _sweep_body(text)
    if body is None:
        return ["no PROCEDURE SWEEP_UNACCOUNTED defined"]

    # (2) RECONCILE_BATCH must call it: a SWEEP_UNACCOUNTED(p_run_id...) that is
    #     not the PROCEDURE definition line.
    calls = [ln for ln in text.splitlines()
             if re.search(r"\bSWEEP_UNACCOUNTED\s*\(\s*p_run_id", ln, re.IGNORECASE)
             and not re.search(r"\bPROCEDURE\b", ln, re.IGNORECASE)]
    if not calls:
        fails.append("SWEEP_UNACCOUNTED is defined but never called with p_run_id "
                     "(expected a call in RECONCILE_BATCH)")

    # (3) fixed status predicate
    if "TFM_STATUS NOT IN ('LOADED','FAILED')" not in body:
        fails.append("sweep body missing the fixed predicate "
                     "TFM_STATUS NOT IN ('LOADED','FAILED')")

    # (4) reportable tag
    if "[RECONCILE_ERROR]" not in body:
        fails.append("sweep body missing the [RECONCILE_ERROR] tag")

    # (5) no COMMIT inside the sweep
    if re.search(r"\bCOMMIT\b", body, re.IGNORECASE):
        fails.append("sweep body contains a COMMIT (RECONCILE_BATCH must own the "
                     "transaction)")

    # (6) work-queue-ID core: queue-scoped signature + predicate.
    sig = re.search(r"PROCEDURE\s+SWEEP_UNACCOUNTED\s*\(([^)]*)\)", body,
                    re.IGNORECASE | re.DOTALL)
    if not sig or "p_work_queue_id" not in sig.group(1).lower():
        fails.append("SWEEP_UNACCOUNTED signature missing the p_work_queue_id argument "
                     "(work-queue-ID core)")
    if "p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id" not in body:
        fails.append("sweep body missing the queue-scope predicate "
                     "(p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id)")

    # RECONCILE_BATCH must pass p_work_queue_id through to the sweep.
    calls = [ln for ln in text.splitlines()
             if re.search(r"\bSWEEP_UNACCOUNTED\s*\(\s*p_run_id", ln, re.IGNORECASE)
             and not re.search(r"\bPROCEDURE\b", ln, re.IGNORECASE)]
    if calls and not any("p_work_queue_id" in ln.lower() for ln in calls):
        fails.append("RECONCILE_BATCH calls SWEEP_UNACCOUNTED without passing "
                     "p_work_queue_id")
    return fails


def main():
    print("SWEEP_UNACCOUNTED conformance check")
    print("=" * 60)
    any_fail = False

    print("\nREQUIRED (FBDI / base-confirming reconcilers):")
    for base in REQUIRED:
        problems = check_pkg(base)
        if problems:
            any_fail = True
            print("  FAIL  " + base)
            for p in problems:
                print("          - " + p)
        else:
            print("  PASS  " + base)

    print("\nNOT CHECKED (HCM/HDL + config reconcilers — sweep deferred until their")
    print("base-tier reconciliation is built; move to REQUIRED when it is):")
    for base in DEFERRED:
        print("  NOT CHECKED  " + base)

    print("\nNOT CHECKED (declared): byte-for-byte identity of the tagged fixed")
    print("  regions across packages, and EDIT-SCOPE == catalog ROW_FILTER for the")
    print("  PO family — covered by the automated PR reviewer.")

    print("=" * 60)
    if any_fail:
        print("RESULT: FAIL — at least one required reconciler is missing/incorrect.")
        return 1
    print("RESULT: PASS — all %d required reconcilers carry the standard sweep." %
          len(REQUIRED))
    return 0


if __name__ == "__main__":
    sys.exit(main())
