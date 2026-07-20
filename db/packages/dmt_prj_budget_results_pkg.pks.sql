-- PACKAGE DMT_PRJ_BUDGET_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_PRJ_BUDGET_RESULTS_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_PRJ_BUDGET_RESULTS_PKG spec
-- Project Budgets BIP reconciliation. CEMLI_CODE: 'ProjectBudgets'
-- Two-tier: interface table (PJO_PLAN_VERSIONS_XFACE) + base table (PJO_PLAN_VERSIONS_B)
-- Match key: SRC_BUDGET_LINE_REFERENCE
-- ============================================================
    PROCEDURE RECONCILE_BATCH (p_run_id IN NUMBER, p_load_ess_id IN NUMBER, p_import_ess_id IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL);
    FUNCTION FETCH_BIP_RESULTS (p_run_id IN NUMBER, p_load_ess_id IN NUMBER, p_import_ess_id IN NUMBER DEFAULT NULL) RETURN CLOB;
    PROCEDURE PARSE_AND_UPDATE (p_run_id IN NUMBER, p_xml_data IN CLOB);
END DMT_PRJ_BUDGET_RESULTS_PKG;
/
