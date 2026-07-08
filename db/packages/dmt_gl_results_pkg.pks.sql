-- PACKAGE DMT_GL_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_GL_RESULTS_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_GL_RESULTS_PKG
-- Post-load BIP reconciliation for GL Balances — Two-Tier pattern.
-- Tier 1: GL_INTERFACE (inverse: rows still present = FAILED)
-- Tier 2: GL_JE_HEADERS/GL_JE_LINES (base table, positive confirmation)
-- CEMLI_CODE: 'GLBalances'
-- ============================================================
    PROCEDURE RECONCILE_BATCH (p_run_id IN NUMBER, p_load_ess_id IN NUMBER, p_import_ess_id IN NUMBER DEFAULT NULL);
    FUNCTION FETCH_BIP_RESULTS (p_run_id IN NUMBER, p_load_ess_id IN NUMBER, p_import_ess_id IN NUMBER DEFAULT NULL) RETURN CLOB;
    PROCEDURE PARSE_AND_UPDATE (p_run_id IN NUMBER, p_xml_data IN CLOB);
END DMT_GL_RESULTS_PKG;
/
