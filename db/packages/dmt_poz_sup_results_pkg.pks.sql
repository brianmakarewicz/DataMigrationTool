-- PACKAGE DMT_POZ_SUP_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_POZ_SUP_RESULTS_PKG"
AUTHID DEFINER
AS
-- ============================================================
-- DMT_POZ_SUP_RESULTS_PKG
-- Post-load BIP reconciliation for Supplier FBDI batches.
--
-- Handles all 5 supplier object types via p_cemli_code:
--   Suppliers, SupplierAddresses, SupplierSites,
--   SupplierSiteAssignments, SupplierContacts
--
-- Call pattern (per object type, after ESS job completes):
--   1. RECONCILE_BATCH calls FETCH_BIP_RESULTS then PARSE_AND_UPDATE
--   2. FETCH_BIP_RESULTS delegates to DMT_UTIL_PKG.RUN_BIP_REPORT
--      (the shared BIP SOAP transport) with the Contract v1
--      parameters P_RUN_ID / P_LOAD_REQUEST_ID / P_IMPORT_ESS_ID /
--      P_PREFIX (P_BATCH_ID is retired — design section 5)
--   3. PARSE_AND_UPDATE updates the TFM tables only — nothing is
--      written back to staging; the TFM row is the sole record of
--      the Fusion outcome.
--
-- BIP report paths are read from DMT_BIP_REPORT_TBL at runtime.
-- ============================================================

    -- Main entry point: call per CEMLI after POLL_ESS_JOB completes.
    -- p_load_ess_id: Load ESS job ID (from loadAndImportData). Passed as
    --   P_LOAD_REQUEST_ID; the reports filter POZ_*_INT by LOAD_REQUEST_ID.
    --   LOAD_REQUEST_ID is always populated regardless of import job outcome,
    --   making it reliable even when the import job errors and IMPORT_REQUEST_ID is NULL.
    PROCEDURE RECONCILE_BATCH (
        p_run_id  IN NUMBER,
        p_cemli_code      IN VARCHAR2,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL
    );

    -- Run the reconciliation BIP report via the shared transport
    -- (DMT_UTIL_PKG.RUN_BIP_REPORT) with the Contract v1 parameters.
    -- PROCEDURE per the section 7 procedures-only contract (network call):
    --   x_report_xml : decoded report data; NULL with x_error_code =
    --                  DMT_UTIL_PKG.C_SUCCESS means zero rows.
    --   x_error_code : DMT_UTIL_PKG.C_SUCCESS / C_ERROR (failure detail
    --                  in DMT_LOG_TBL; exceptions never escape).
    -- Exposed publicly for independent testing.
    PROCEDURE FETCH_BIP_RESULTS (
        p_run_id  IN NUMBER,
        p_cemli_code      IN VARCHAR2,
        p_load_ess_id     IN NUMBER,
        x_report_xml      OUT XMLTYPE,
        x_error_code      OUT NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL
    );

    -- Parse the BIP report data and update the appropriate TFM table.
    -- Exposed publicly so results can be reprocessed without re-calling Fusion.
    PROCEDURE PARSE_AND_UPDATE (
        p_run_id IN NUMBER,
        p_cemli_code     IN VARCHAR2,
        p_report_xml     IN XMLTYPE
    );

END DMT_POZ_SUP_RESULTS_PKG;
/
