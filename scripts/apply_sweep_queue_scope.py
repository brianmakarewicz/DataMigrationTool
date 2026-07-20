#!/usr/bin/env python3
"""
One-shot codemod (2026-07-20, work-queue-ID core): add a nullable
p_work_queue_id argument to the standard SWEEP_UNACCOUNTED helper and its
RECONCILE_BATCH caller across every FBDI/base-confirming reconciler package,
and scope the sweep's UPDATE to that work-queue id when it is supplied.

Uniform, mechanical edit. NULL default = no queue filter, so single-batch
objects, the supplier multi-object reconciler, and the direct Items-category
call keep working unchanged. Idempotent: re-running is a no-op.

Not committed as pipeline logic -- it is a dev codemod; its OUTPUT (the edited
.pkb/.pks files) is the deliverable.
"""
import os
import re
import sys

PKG_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                       "db", "packages")

# 18 with the 1-arg sweep + 3-arg reconcile; suppliers handled specially below.
STD = [
    "dmt_po_results_pkg", "dmt_gl_results_pkg", "dmt_blanket_po_results_pkg",
    "dmt_contract_results_pkg", "dmt_ap_results_pkg", "dmt_expenditure_results_pkg",
    "dmt_req_results_pkg", "dmt_egp_item_results_pkg", "dmt_egp_item_cat_results_pkg",
    "dmt_gl_budget_results_pkg", "dmt_grants_results_pkg", "dmt_billing_event_results_pkg",
    "dmt_prj_budget_results_pkg", "dmt_cust_results_pkg", "dmt_ar_results_pkg",
    "dmt_project_results_pkg", "dmt_fa_asset_results_pkg", "dmt_misc_receipt_results_pkg",
]
SUPPLIER = "dmt_poz_sup_results_pkg"

NEW_PARAM = "p_work_queue_id IN NUMBER DEFAULT NULL"
SCOPE_LINE = ("        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id)"
              "  -- work-queue-ID core: sweep only this item's rows")
PREDICATE = "AND    TFM_STATUS NOT IN ('LOADED','FAILED')"


def edit_body(base, supplier=False):
    path = os.path.join(PKG_DIR, base + ".pkb.sql")
    with open(path, encoding="utf-8") as fh:
        txt = fh.read()
    orig = txt

    # 1. Sweep signature.
    if supplier:
        txt = txt.replace(
            "PROCEDURE SWEEP_UNACCOUNTED (p_run_id IN NUMBER, p_cemli_code IN VARCHAR2) IS",
            "PROCEDURE SWEEP_UNACCOUNTED (p_run_id IN NUMBER, p_cemli_code IN VARCHAR2, "
            + NEW_PARAM + ") IS")
    else:
        txt = txt.replace(
            "PROCEDURE SWEEP_UNACCOUNTED (p_run_id IN NUMBER) IS",
            "PROCEDURE SWEEP_UNACCOUNTED (p_run_id IN NUMBER, " + NEW_PARAM + ") IS")

    # 2. Scope predicate: add the queue filter right after the fixed status
    #    predicate, but only where it is not already present.
    def add_scope(m):
        block = m.group(0)
        if "p_work_queue_id IS NULL OR WORK_QUEUE_ID" in block:
            return block
        return block + "\n" + SCOPE_LINE
    # Attach to each occurrence of the predicate line (some packages sweep
    # several TFM tables; each UPDATE ends with the same predicate).
    txt = re.sub(re.escape(PREDICATE), add_scope, txt)

    # 3. Sweep call inside RECONCILE_BATCH.
    if supplier:
        txt = txt.replace("SWEEP_UNACCOUNTED(p_run_id, p_cemli_code);",
                          "SWEEP_UNACCOUNTED(p_run_id, p_cemli_code, p_work_queue_id);")
    else:
        txt = txt.replace("SWEEP_UNACCOUNTED(p_run_id);",
                          "SWEEP_UNACCOUNTED(p_run_id, p_work_queue_id);")

    if txt != orig:
        with open(path, "w", encoding="utf-8", newline="") as fh:
            fh.write(txt)
        return True
    return False


def edit_reconcile_sig(base):
    """Add p_work_queue_id (DEFAULT NULL) to RECONCILE_BATCH in both .pks and
    .pkb -- after the p_import_ess_id parameter."""
    changed = False
    for ext in (".pks.sql", ".pkb.sql"):
        path = os.path.join(PKG_DIR, base + ext)
        if not os.path.exists(path):
            continue
        with open(path, encoding="utf-8") as fh:
            txt = fh.read()
        orig = txt
        if "p_work_queue_id" in txt.split("RECONCILE_BATCH", 1)[-1][:400]:
            continue  # already has it near RECONCILE_BATCH

        # One-line spec form: PROCEDURE RECONCILE_BATCH (... p_import_ess_id IN NUMBER DEFAULT NULL);
        txt = re.sub(
            r"(PROCEDURE RECONCILE_BATCH \([^;]*?p_import_ess_id IN NUMBER DEFAULT NULL)(\s*\)\s*;)",
            r"\1,\n        p_work_queue_id IN NUMBER DEFAULT NULL\2",
            txt, flags=re.DOTALL)

        # Multi-line body/spec form:
        #     p_import_ess_id   IN NUMBER DEFAULT NULL
        #   ) IS   /   ) ;
        txt = re.sub(
            r"(PROCEDURE RECONCILE_BATCH \([^;]*?p_import_ess_id\s+IN NUMBER DEFAULT NULL)(\s*\n\s*\)\s*(IS|;))",
            r"\1,\n        p_work_queue_id IN NUMBER DEFAULT NULL\2",
            txt, flags=re.DOTALL)

        if txt != orig:
            with open(path, "w", encoding="utf-8", newline="") as fh:
                fh.write(txt)
            changed = True
    return changed


def main():
    for base in STD:
        b = edit_body(base, supplier=False)
        s = edit_reconcile_sig(base)
        print(("edited " if (b or s) else "nochg  ") + base)
    b = edit_body(SUPPLIER, supplier=True)
    s = edit_reconcile_sig(SUPPLIER)
    print(("edited " if (b or s) else "nochg  ") + SUPPLIER)


if __name__ == "__main__":
    sys.exit(main())
