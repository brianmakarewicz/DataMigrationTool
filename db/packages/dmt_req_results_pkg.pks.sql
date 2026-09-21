-- PACKAGE DMT_REQ_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_REQ_RESULTS_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_REQ_RESULTS_PKG
-- Post-load reconciliation for Requisitions — Contract v1, MULTI-TIER template.
--
-- Reuses the ONE shared Contract v1 fetch DMT_RECON_CONTRACT_PKG.FETCH_ROWS
-- (Option A, owner decision on PR #248), exactly as the Workers template does.
-- A single fetch runs the Requisitions Contract v1 report (nine columns, keyset
-- paginated) over BIP and returns ALL three tiers' rows in one collection; each
-- row's OBJECT_TYPE says which tier it belongs to. The apply is STATIC SQL, one
-- pair of UPDATEs per tier, joined on RECON_KEY = the report RECORD_KEY.
--
--   Tier          OBJECT_TYPE literal           TFM table
--   headers       'Requisitions'                DMT_POR_REQ_HEADERS_TFM_TBL
--   lines         'Requisitions.Line'           DMT_POR_REQ_LINES_TFM_TBL
--   distributions 'Requisitions.Distribution'   DMT_POR_REQ_DISTS_TFM_TBL
--
-- The BIP report path + CONTRACT_VERSION are read from DMT_BIP_REPORT_TBL at
-- runtime by the shared fetch. CEMLI_CODE: 'Requisitions'.
-- ============================================================

    -- GET_PARTITION_KEYS — distinct spawn-per-partition tokens (BATCH_ID) for
    -- one run, STATIC SQL over this object's own requisition-headers transform
    -- table. Called through DMT_QUEUE_WORKER_PKG.invoke_registered (style KEYS);
    -- one child work item per token, treated as opaque by the engine.
    FUNCTION GET_PARTITION_KEYS (
        p_run_id IN NUMBER
    ) RETURN DMT_PARTITION_KEY_TBL;

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

END DMT_REQ_RESULTS_PKG;
/
