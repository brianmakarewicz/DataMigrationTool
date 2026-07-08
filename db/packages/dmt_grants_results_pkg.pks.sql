-- PACKAGE DMT_GRANTS_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_GRANTS_RESULTS_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_GRANTS_RESULTS_PKG spec
-- Grants BIP reconciliation. CEMLI_CODE: 'Grants'
-- Two-tier: interface table (GMS_AWARD_HEADERS_INT) + base table (GMS_AWARDS_B)
-- Cascade from headers to all 14 child TFM tables via AWARD_NUMBER.
-- Echo back to all 15 STG tables.
-- ============================================================
    PROCEDURE RECONCILE_BATCH (p_run_id IN NUMBER, p_load_ess_id IN NUMBER, p_import_ess_id IN NUMBER DEFAULT NULL);
    FUNCTION FETCH_BIP_RESULTS (p_run_id IN NUMBER, p_load_ess_id IN NUMBER, p_import_ess_id IN NUMBER DEFAULT NULL) RETURN CLOB;
    PROCEDURE PARSE_AND_UPDATE (p_run_id IN NUMBER, p_xml_data IN CLOB);
END DMT_GRANTS_RESULTS_PKG;
/
