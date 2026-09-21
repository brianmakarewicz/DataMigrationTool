-- PACKAGE DMT_AP_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_AP_RESULTS_PKG"
AUTHID DEFINER
AS
-- ============================================================
-- DMT_AP_RESULTS_PKG
-- Post-load reconciliation for APInvoices — Contract v1, MULTI-TIER template.
--
-- Reuses the ONE shared Contract v1 fetch DMT_RECON_CONTRACT_PKG.FETCH_ROWS
-- (Option A, owner decision on PR #248), exactly as the Requisitions template
-- does (DMT_REQ_RESULTS_PKG). A single fetch runs the APInvoices Contract v1
-- report (nine columns, keyset paginated) over BIP and returns BOTH tiers' rows
-- in one collection; each row's OBJECT_TYPE says which tier it belongs to. The
-- apply is STATIC SQL, one pair of UPDATEs per tier, joined on
-- RECON_KEY = the report RECORD_KEY.
--
--   Tier      OBJECT_TYPE literal      TFM table                          FUSION_ID
--   -------   ----------------------   --------------------------------   ---------------------
--   headers   'APInvoices'             DMT_AP_INVOICES_INT_TFM_TBL        FUSION_INVOICE_ID
--   lines     'APInvoices.Line'        DMT_AP_INVOICE_LINES_INT_TFM_TBL   (no line surrogate id)
--
-- The base invoice line carries no independent surrogate id (a base line is
-- identified by INVOICE_ID + LINE_NUMBER), so the line tier reports the parent
-- invoice id as its FUSION_ID for traceability but there is no line-id TFM column
-- to stamp — the line reaches LOADED on its own BASE/SUCCESS report row.
--
-- RECON_KEY per tier (stamped by DMT_AP_TRANSFORM_PKG = each tier's report
-- RECORD_KEY): headers = INVOICE_NUM (prefixed);
-- lines = INVOICE_NUM (prefixed parent) || ':LINE:' || LINE_NUMBER.
--
-- The BIP report path + CONTRACT_VERSION are read from DMT_BIP_REPORT_TBL at
-- runtime by the shared fetch. CEMLI_CODE: 'APInvoices'.
-- ============================================================

    -- Main entry point: call after POLL_ESS_JOB completes. Runs the shared
    -- Contract v1 fetch + per-tier apply. p_load_ess_id is the Contract v1
    -- P_LOAD_REQUEST_ID; the report's run-scoped selectors (P_RUN_ID, P_PREFIX)
    -- pick up the whole run. p_import_ess_id / p_work_queue_id retained for the
    -- registered-signature contract.
    PROCEDURE RECONCILE_BATCH (
        p_run_id  IN NUMBER,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    );

END DMT_AP_RESULTS_PKG;
/
