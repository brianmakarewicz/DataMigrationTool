-- PACKAGE DMT_PLAN_BUDGET_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_PLAN_BUDGET_RESULTS_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_PLAN_BUDGET_RESULTS_PKG
-- Post-load BIP reconciliation for Planning Budgets.
-- CEMLI_CODE: 'PlanningBudgets'
-- ============================================================
    PROCEDURE RECONCILE_BATCH (p_run_id IN NUMBER, p_load_ess_id IN NUMBER, p_import_ess_id IN NUMBER DEFAULT NULL);
    FUNCTION FETCH_BIP_RESULTS (p_run_id IN NUMBER, p_load_ess_id IN NUMBER, p_import_ess_id IN NUMBER DEFAULT NULL) RETURN CLOB;
    PROCEDURE PARSE_AND_UPDATE (p_run_id IN NUMBER, p_xml_data IN CLOB);
END DMT_PLAN_BUDGET_RESULTS_PKG;
/
