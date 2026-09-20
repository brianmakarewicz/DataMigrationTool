-- PACKAGE DMT_REQ_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_REQ_RESULTS_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_REQ_RESULTS_PKG
-- Post-load BIP reconciliation for Requisitions — BIP reconciliation
-- report contract v1 (nine columns, keyset pagination, six standard
-- parameters). Reader-code pilot: this package is a verbatim copy of
-- the reference reconciler DMT_GL_RESULTS_PKG, with only the four
-- object-specific swaps (CEMLI code, TFM table, FUSION_ID column,
-- generated-row count table).
--
-- Transport is the shared DMT_UTIL_PKG.RUN_BIP_REPORT (no private
-- UTL_HTTP copy). Outcomes are written to the header TFM table only.
-- CEMLI_CODE: 'Requisitions'
-- ============================================================

    -- GET_PARTITION_KEYS — distinct spawn-per-partition tokens (BATCH_ID) for
    -- one run, STATIC SQL over this object's own requisition-headers transform
    -- table. Called through DMT_QUEUE_WORKER_PKG.invoke_registered (style KEYS);
    -- one child work item per token, treated as opaque by the engine.
    FUNCTION GET_PARTITION_KEYS (
        p_run_id IN NUMBER
    ) RETURN DMT_PARTITION_KEY_TBL;

    -- Main entry point: call after POLL_ESS_JOB completes.
    -- p_load_ess_id: Load ESS job ID. Passed as P_LOAD_REQUEST_ID.
    PROCEDURE RECONCILE_BATCH (
        p_run_id        IN NUMBER,
        p_load_ess_id   IN NUMBER,
        p_import_ess_id IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    );

    -- Run the reconciliation BIP report via the shared transport
    -- (DMT_UTIL_PKG.RUN_BIP_REPORT) with the Contract v1 parameters
    -- P_RUN_ID / P_LOAD_REQUEST_ID / P_IMPORT_ESS_ID / P_PREFIX /
    -- P_CHUNK_SIZE / P_AFTER_KEY. Single-page fetch (empty cursor).
    --   x_report_xml : decoded report data; NULL with x_error_code =
    --                  DMT_UTIL_PKG.C_SUCCESS means zero rows.
    --   x_error_code : DMT_UTIL_PKG.C_SUCCESS / C_ERROR (failure detail
    --                  in DMT_LOG_TBL; exceptions never escape).
    -- Exposed publicly for independent testing.
    PROCEDURE FETCH_BIP_RESULTS (
        p_run_id        IN  NUMBER,
        p_load_ess_id   IN  NUMBER,
        x_report_xml    OUT XMLTYPE,
        x_error_code    OUT NUMBER,
        p_import_ess_id IN  NUMBER DEFAULT NULL
    );

    -- Parse the BIP report data and update the TFM table only.
    -- Exposed publicly so results can be reprocessed without re-calling Fusion.
    PROCEDURE PARSE_AND_UPDATE (
        p_run_id     IN NUMBER,
        p_report_xml IN XMLTYPE
    );

END DMT_REQ_RESULTS_PKG;
/
