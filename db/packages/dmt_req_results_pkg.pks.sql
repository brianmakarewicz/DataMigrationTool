-- PACKAGE DMT_REQ_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_REQ_RESULTS_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_REQ_RESULTS_PKG
-- Post-load BIP reconciliation for Requisitions — Two-Tier pattern.
--
-- Tier 1: POR_REQ_HEADERS_INTERFACE_ALL (interface table, errors/status)
-- Tier 2: POR_REQUISITION_HEADERS_ALL (base table, positive confirmation)
-- No absence=LOADED fallback. Every row gets positive verification
-- or is marked FAILED with a reconciliation error.
--
-- Reconciles headers, cascades to lines and distributions TFM,
-- then echoes back to all 3 STG tables.
--
-- BIP report path read from DMT_BIP_REPORT_TBL at runtime.
-- CEMLI_CODE: 'Requisitions'
-- ============================================================

    -- GET_PARTITION_KEYS — distinct spawn-per-partition tokens (BATCH_ID) for
    -- one run, STATIC SQL over this object's own requisition-headers transform
    -- table. Called through DMT_QUEUE_WORKER_PKG.invoke_registered (style KEYS);
    -- one child work item per token, treated as opaque by the engine.
    FUNCTION GET_PARTITION_KEYS (
        p_run_id IN NUMBER
    ) RETURN DMT_OWNER.DMT_PARTITION_KEY_TBL;

    -- Main entry point: call after POLL_ESS_JOB completes.
    -- p_load_ess_id: the ESS job ID used as P_BATCH_ID in the BIP report
    -- p_import_ess_id: the Import ESS job ID for base table lookup
    PROCEDURE RECONCILE_BATCH (
        p_run_id  IN NUMBER,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    );

    -- Call Fusion BIP v2 SOAP runReport and return raw XML response.
    FUNCTION FETCH_BIP_RESULTS (
        p_run_id  IN NUMBER,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL
    ) RETURN CLOB;

    -- Parse BIP XML response and update all 3 TFM + STG tables.
    PROCEDURE PARSE_AND_UPDATE (
        p_run_id IN NUMBER,
        p_xml_data       IN CLOB
    );

END DMT_REQ_RESULTS_PKG;
/
