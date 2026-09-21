-- PACKAGE DMT_PO_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_PO_RESULTS_PKG"
AUTHID DEFINER
AS
-- ============================================================
-- DMT_PO_RESULTS_PKG
-- Post-load reconciliation for PurchaseOrders — Contract v1, MULTI-TIER.
--
-- Reuses the ONE shared Contract v1 fetch DMT_RECON_CONTRACT_PKG.FETCH_ROWS
-- (Option A, owner decision on PR #248), exactly as the Requisitions multi-tier
-- template (PR #364) does. A single fetch runs the PurchaseOrders Contract v1
-- report (nine columns, keyset paginated) over BIP and returns ALL four tiers'
-- rows in one collection; each row's OBJECT_TYPE says which tier it belongs to.
-- The apply is STATIC SQL, one pair of UPDATEs per tier, joined on
-- RECON_KEY = the report RECORD_KEY.
--
--   Tier            OBJECT_TYPE literal            TFM table
--   headers         'PurchaseOrders'               DMT_PO_HEADERS_INT_TFM_TBL
--   lines           'PurchaseOrders.Line'          DMT_PO_LINES_INT_TFM_TBL
--   line-locations  'PurchaseOrders.LineLocation'  DMT_PO_LINE_LOCS_INT_TFM_TBL
--   distributions   'PurchaseOrders.Distribution'  DMT_PO_DISTS_INT_TFM_TBL
--
-- The BIP report path + CONTRACT_VERSION are read from DMT_BIP_REPORT_TBL at
-- runtime by the shared fetch. CEMLI_CODE: 'PurchaseOrders'. These four TFM
-- tables are shared with BlanketPOs and Contracts; this reader touches only its
-- own rows because its report is run with the PurchaseOrders load/import request
-- ids and returns only Standard-PO RECORD_KEYs.
-- ============================================================

    -- Main entry point: call after POLL_ESS_JOB completes. Runs the shared
    -- Contract v1 fetch + per-tier apply. p_load_ess_id is the Contract v1
    -- P_LOAD_REQUEST_ID; p_import_ess_id is P_IMPORT_ESS_ID (the Import Orders
    -- ESS id that stamped the BASE PO rows). p_work_queue_id retained for the
    -- registered-signature contract.
    PROCEDURE RECONCILE_BATCH (
        p_run_id  IN NUMBER,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    );

END DMT_PO_RESULTS_PKG;
/
