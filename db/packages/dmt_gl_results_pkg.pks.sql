-- PACKAGE DMT_GL_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_GL_RESULTS_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_GL_RESULTS_PKG
-- Post-load BIP reconciliation for GL Balances - Two-Tier pattern.
-- Tier 1: GL_INTERFACE (INTERFACE rows: status P = LOADED, else FAILED)
-- Tier 2: GL_JE_HEADERS/GL_JE_LINES (BASE rows: positive confirmation)
-- No absence=LOADED fallback. Every row gets positive verification or
-- is marked FAILED with a reconciliation error.
-- CEMLI_CODE: 'GLBalances'
--
-- Transport is the shared DMT_UTIL_PKG.RUN_BIP_REPORT (no private
-- UTL_HTTP copy, no raw envelope logging - the shared transport never
-- logs the request envelope, which carries credentials). Outcomes are
-- written to the TFM table only: nothing is written back to staging;
-- the TFM row is the sole record of the Fusion outcome (design
-- section 2 STG_STATUS: terminal from staging's point of view).
-- ============================================================

    -- Main entry point: call after POLL_ESS_JOB completes.
    -- p_load_ess_id: Load ESS job ID. Passed as P_LOAD_REQUEST_ID.
    PROCEDURE RECONCILE_BATCH (
        p_run_id        IN NUMBER,
        p_load_ess_id   IN NUMBER,
        p_import_ess_id IN NUMBER DEFAULT NULL
    );

    -- Run the reconciliation BIP report via the shared transport
    -- (DMT_UTIL_PKG.RUN_BIP_REPORT) with the Contract v1 parameters
    -- P_RUN_ID / P_LOAD_REQUEST_ID / P_IMPORT_ESS_ID / P_PREFIX
    -- (P_BATCH_ID is retired - design section 5 / Contract v1).
    -- PROCEDURE per the section 7 procedures-only contract (network call):
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

END DMT_GL_RESULTS_PKG;
/
