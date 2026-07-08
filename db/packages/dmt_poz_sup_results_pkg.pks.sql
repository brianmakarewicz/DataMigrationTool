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
--   2. FETCH_BIP_RESULTS calls BIP v2 SOAP runReport with P_BATCH_ID
--   3. PARSE_AND_UPDATE updates the appropriate staging table
--
-- BIP report paths are read from DMT_BIP_REPORT_TBL at runtime.
-- ============================================================

    -- Main entry point: call per CEMLI after POLL_ESS_JOB completes.
    -- p_load_ess_id: Load ESS job ID (from loadAndImportData). Used as P_BATCH_ID
    --   in the BIP report, which filters POZ_*_INT by LOAD_REQUEST_ID.
    --   LOAD_REQUEST_ID is always populated regardless of import job outcome,
    --   making it reliable even when the import job errors and IMPORT_REQUEST_ID is NULL.
    PROCEDURE RECONCILE_BATCH (
        p_run_id  IN NUMBER,
        p_cemli_code      IN VARCHAR2,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL
    );

    -- Call the Fusion BIP v2 SOAP runReport and return raw XML response.
    -- Exposed publicly for independent testing from APEX.
    FUNCTION FETCH_BIP_RESULTS (
        p_run_id  IN NUMBER,
        p_cemli_code      IN VARCHAR2,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL
    ) RETURN CLOB;

    -- Parse the BIP XML response and update the appropriate staging table.
    -- Exposed publicly so results can be reprocessed without re-calling Fusion.
    PROCEDURE PARSE_AND_UPDATE (
        p_run_id IN NUMBER,
        p_cemli_code     IN VARCHAR2,
        p_xml_data       IN CLOB
    );

END DMT_POZ_SUP_RESULTS_PKG;
/
