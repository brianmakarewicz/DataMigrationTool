-- PACKAGE DMT_FA_ASSET_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_FA_ASSET_RESULTS_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_FA_ASSET_RESULTS_PKG
-- Post-load BIP reconciliation for Assets — Two-Tier pattern.
-- Tier 1: FA_MASS_ADDITIONS (interface table, POSTED/errors)
-- Tier 2: FA_ADDITIONS_B (base table, positive confirmation)
-- CEMLI_CODE: 'Assets'
-- ============================================================
    PROCEDURE RECONCILE_BATCH (p_run_id IN NUMBER, p_load_ess_id IN NUMBER, p_import_ess_id IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL);
    FUNCTION FETCH_BIP_RESULTS (p_run_id IN NUMBER, p_load_ess_id IN NUMBER, p_import_ess_id IN NUMBER DEFAULT NULL) RETURN CLOB;
    PROCEDURE PARSE_AND_UPDATE (p_run_id IN NUMBER, p_xml_data IN CLOB);
END DMT_FA_ASSET_RESULTS_PKG;
/
