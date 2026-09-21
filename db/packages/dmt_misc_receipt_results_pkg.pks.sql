-- PACKAGE DMT_MISC_RECEIPT_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_MISC_RECEIPT_RESULTS_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_MISC_RECEIPT_RESULTS_PKG
-- Post-load reconciliation for MiscReceipts (On Hand Qty) — Contract v1,
-- SINGLE-TIER.
--
-- Reuses the ONE shared Contract v1 fetch DMT_RECON_CONTRACT_PKG.FETCH_ROWS
-- (Option A, owner decision on PR #248), exactly as the Workers/Requisitions
-- templates do. A single fetch runs the MiscReceipts Contract v1 report (nine
-- columns, keyset paginated) over BIP and returns all rows in one collection;
-- OBJECT_TYPE is 'MiscReceipts' on every row. The apply is STATIC SQL against the
-- compile-time-known transaction TFM table (DMT_INV_TRX_TFM_TBL), joined on
-- RECON_KEY = report RECORD_KEY (= TO_CHAR(SOURCE_LINE_ID)); FUSION_ID column is
-- FUSION_ID.
--
-- The BIP report path + CONTRACT_VERSION are read from DMT_BIP_REPORT_TBL at
-- runtime by the shared fetch. CEMLI_CODE: 'MiscReceipts'.
-- ============================================================

    PROCEDURE RECONCILE_BATCH (
        p_run_id IN NUMBER,
        p_load_ess_id    IN NUMBER,
        p_import_ess_id  IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    );

END DMT_MISC_RECEIPT_RESULTS_PKG;
/
