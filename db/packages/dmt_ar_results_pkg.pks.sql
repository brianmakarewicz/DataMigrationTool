-- PACKAGE DMT_AR_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_AR_RESULTS_PKG"
AUTHID DEFINER
AS
-- ============================================================
-- DMT_AR_RESULTS_PKG
-- Post-load reconciliation for ARInvoices — Contract v1, MULTI-TIER.
--
-- Reuses the ONE shared Contract v1 fetch DMT_RECON_CONTRACT_PKG.FETCH_ROWS
-- (Option A, owner decision on PR #248), exactly as the Workers and Requisitions
-- templates do. A single fetch runs the ARInvoices Contract v1 report (nine
-- columns, keyset paginated) over BIP and returns BOTH tiers' rows in one
-- collection; each row's OBJECT_TYPE says which tier it belongs to. The apply is
-- STATIC SQL, one pair of UPDATEs per tier, joined on RECON_KEY = report
-- RECORD_KEY.
--
--   Tier           OBJECT_TYPE literal          TFM table               FUSION_ID column
--   lines          'ARInvoices'                 DMT_RA_LINES_TFM_TBL     FUSION_CUSTOMER_TRX_ID
--   distributions  'ARInvoices.Distribution'    DMT_RA_DISTS_TFM_TBL     FUSION_CUST_TRX_LINE_GL_DIST_ID
--
-- RECON_KEY per tier (stamped by DMT_AR_TRANSFORM_PKG, = each tier's report
-- RECORD_KEY): BOTH tiers = INTERFACE_LINE_ATTRIBUTE1 (the prefixed TRX_NUMBER).
-- The AR base distribution carries no interface key of its own, so a distribution
-- is confirmed TRANSITIVELY through its parent line: the data model emits the
-- parent line's stamped key as the distribution RECORD_KEY, and a BASE
-- distribution row for that key is positive proof the line's distributions
-- landed.
--
-- The BIP report path + CONTRACT_VERSION are read from DMT_BIP_REPORT_TBL at
-- runtime by the shared fetch. CEMLI_CODE: 'ARInvoices'.
-- ============================================================

    -- Main entry point: call after POLL_ESS_JOB completes. Runs the shared
    -- Contract v1 fetch + per-tier apply. p_load_ess_id is the Contract v1
    -- P_LOAD_REQUEST_ID; the report's run-scoped selectors (P_PREFIX) pick up the
    -- whole run. p_import_ess_id / p_work_queue_id retained for the
    -- registered-signature contract.
    PROCEDURE RECONCILE_BATCH (
        p_run_id  IN NUMBER,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    );

END DMT_AR_RESULTS_PKG;
/
