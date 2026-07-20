-- PACKAGE DMT_EGP_ITEM_CAT_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_EGP_ITEM_CAT_RESULTS_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_EGP_ITEM_CAT_RESULTS_PKG
-- Post-load BIP reconciliation for Item Categories.
--
-- RECONCILE_BATCH: called by run_one_object_type after ESS
--   import completes. Calls BIP report to match imported rows
--   against EGP_ITEM_CATEGORIES_INTERFACE status, then updates
--   TFM/STG rows to LOADED or FAILED.
--
-- LOAD_AND_RECONCILE: standalone runner path (ESS-only).
--   Retained for dev/test but not used by the production pipeline.
--
-- BIP report path read from DMT_BIP_REPORT_TBL at runtime.
-- CEMLI_CODE: 'ItemCategories'
-- ============================================================

    PROCEDURE RECONCILE_BATCH (
        p_run_id IN NUMBER,
        p_load_ess_id    IN NUMBER,
        p_import_ess_id  IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    );

    FUNCTION FETCH_BIP_RESULTS (
        p_run_id IN NUMBER,
        p_load_ess_id    IN NUMBER,
        p_import_ess_id  IN NUMBER DEFAULT NULL
    ) RETURN CLOB;

    PROCEDURE PARSE_AND_UPDATE (
        p_run_id IN NUMBER,
        p_xml_data       IN CLOB
    );

    PROCEDURE LOAD_AND_RECONCILE (
        p_run_id IN NUMBER,
        p_fbdi_zip       IN BLOB,
        p_filename       IN VARCHAR2
    );

END DMT_EGP_ITEM_CAT_RESULTS_PKG;
/
