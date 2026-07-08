-- PACKAGE DMT_PROJECT_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_PROJECT_RESULTS_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_PROJECT_RESULTS_PKG spec
-- Projects BIP reconciliation — Two-Tier pattern.
-- CEMLI_CODE: 'Projects'
-- Fusion interface table: PJF_PROJECTS_ALL_XFACE (status column: IMPORT_STATUS)
-- Fusion base table: PJF_PROJECTS_ALL_B (positive confirmation)
-- ============================================================
    PROCEDURE RECONCILE_BATCH (p_run_id IN NUMBER, p_load_ess_id IN NUMBER, p_import_ess_id IN NUMBER DEFAULT NULL);
    FUNCTION FETCH_BIP_RESULTS (p_run_id IN NUMBER, p_load_ess_id IN NUMBER, p_import_ess_id IN NUMBER DEFAULT NULL) RETURN CLOB;
    PROCEDURE PARSE_AND_UPDATE (p_run_id IN NUMBER, p_xml_data IN CLOB, p_import_ess_id IN NUMBER DEFAULT NULL);
END DMT_PROJECT_RESULTS_PKG;
/
