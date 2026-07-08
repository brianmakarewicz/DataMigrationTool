-- PACKAGE DMT_EGP_ITEM_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_EGP_ITEM_RESULTS_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_EGP_ITEM_RESULTS_PKG
-- Post-load BIP reconciliation for Items.
--
-- RECONCILE_BATCH: called by run_one_object_type after ESS
--   import completes. Calls BIP report to match imported rows
--   against EGP_SYSTEM_ITEMS_INTERFACE status, then updates
--   TFM/STG rows to LOADED or FAILED.
--
-- LOAD_AND_RECONCILE: standalone runner path (ESS-only, no BIP).
--   Retained for dev/test but not used by the production pipeline.
--
-- BIP report path read from DMT_BIP_REPORT_TBL at runtime.
-- CEMLI_CODE: 'Items'
-- ============================================================

    -- Main entry point for pipeline: call after POLL_ESS_JOB completes.
    PROCEDURE RECONCILE_BATCH (
        p_run_id IN NUMBER,
        p_load_ess_id    IN NUMBER,
        p_import_ess_id  IN NUMBER DEFAULT NULL
    );

    -- Call Fusion BIP v2 SOAP runReport and return raw XML response.
    FUNCTION FETCH_BIP_RESULTS (
        p_run_id IN NUMBER,
        p_load_ess_id    IN NUMBER,
        p_import_ess_id  IN NUMBER DEFAULT NULL
    ) RETURN CLOB;

    -- Parse BIP XML response and update TFM + STG tables.
    PROCEDURE PARSE_AND_UPDATE (
        p_run_id IN NUMBER,
        p_xml_data       IN CLOB
    );

    -- Standalone runner path (ESS-only, retained for dev/test).
    PROCEDURE LOAD_AND_RECONCILE (
        p_run_id IN NUMBER,
        p_fbdi_zip       IN BLOB,
        p_filename       IN VARCHAR2
    );

END DMT_EGP_ITEM_RESULTS_PKG;
/
