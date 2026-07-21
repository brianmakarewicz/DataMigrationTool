-- PACKAGE DMT_PROJECT_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_PROJECT_RESULTS_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_PROJECT_RESULTS_PKG spec
-- Projects BIP reconciliation — ONE object, four record types
-- (Projects, Tasks, TeamMembers, TxnControls) in one FBDI zip.
--
-- Ported to the accepted architecture 2026-07-09 (matches the
-- Suppliers/GLBalances ports):
--   * Transport is the shared DMT_UTIL_PKG.RUN_BIP_REPORT — no
--     private UTL_HTTP copy (accepted standard: single outbound
--     transport module; no other package references UTL_HTTP).
--   * Contract v1 parameters: P_RUN_ID / P_LOAD_REQUEST_ID /
--     P_IMPORT_ESS_ID / P_PREFIX (P_BATCH_ID is retired).
--   * FETCH_BIP_RESULTS is a PROCEDURE that reports outcome
--     through x_error_code (accepted standard: every procedure
--     returns an error code; exceptions never escape).
--   * Outcomes are written to the TFM tables only — nothing is
--     written back to staging (accepted rule: downstream outcomes
--     are never written back to staging; the TFM row is the sole
--     record of the Fusion outcome).
--
-- Fusion interface tables (Tier 1): PJF_PROJECTS_ALL_XFACE,
-- PJF_PROJ_ELEMENTS_XFACE, PJF_PROJECT_PARTIES_INT,
-- PJC_TXN_CONTROLS_STAGE. Base table (Tier 2): PJF_PROJECTS_ALL_B.
-- ============================================================

    -- Main entry point: called by DMT_LOADER_PKG after POLL_ESS_JOB
    -- completes. Signature is fixed by the loader dispatch and must
    -- not change. p_load_ess_id is passed as P_LOAD_REQUEST_ID.
    PROCEDURE RECONCILE_BATCH (
        p_run_id         IN NUMBER,
        p_load_ess_id    IN NUMBER,
        p_import_ess_id  IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    );

    -- Run the reconciliation BIP report via the shared transport
    -- (DMT_UTIL_PKG.RUN_BIP_REPORT) with the Contract v1 parameters.
    -- PROCEDURE per the accepted procedures-only / error-code contract:
    --   x_report_xml : decoded report data; NULL with x_error_code =
    --                  DMT_UTIL_PKG.C_SUCCESS means zero rows.
    --   x_error_code : DMT_UTIL_PKG.C_SUCCESS / C_ERROR (failure detail
    --                  logged to DMT_LOG_TBL; exceptions never escape).
    -- Exposed publicly for independent testing.
    PROCEDURE FETCH_BIP_RESULTS (
        p_run_id         IN  NUMBER,
        p_load_ess_id    IN  NUMBER,
        x_report_xml     OUT XMLTYPE,
        x_error_code     OUT NUMBER,
        p_import_ess_id  IN  NUMBER DEFAULT NULL
    );

    -- Parse the (already-decoded) BIP report data and update the four
    -- TFM tables. TFM only — nothing is written back to staging.
    -- Exposed publicly so results can be reprocessed without re-calling Fusion.
    PROCEDURE PARSE_AND_UPDATE (
        p_run_id         IN NUMBER,
        p_report_xml     IN XMLTYPE,
        p_import_ess_id  IN NUMBER DEFAULT NULL
    );

END DMT_PROJECT_RESULTS_PKG;
/
