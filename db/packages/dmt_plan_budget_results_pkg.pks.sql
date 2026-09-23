-- PACKAGE DMT_PLAN_BUDGET_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_PLAN_BUDGET_RESULTS_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_PLAN_BUDGET_RESULTS_PKG
-- Post-load BIP reconciliation for Planning Budgets.
-- CEMLI_CODE: 'PlanningBudgets'
-- The BIP runReport transport is the shared DMT_UTIL_PKG.RUN_BIP_REPORT
-- (backlog item #20 -- one BIP call path). PARSE_AND_UPDATE takes the
-- decoded report XMLTYPE that RUN_BIP_REPORT returns.
-- ============================================================
    PROCEDURE RECONCILE_BATCH (p_run_id IN NUMBER, p_load_ess_id IN NUMBER, p_import_ess_id IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL);
    PROCEDURE PARSE_AND_UPDATE (p_run_id IN NUMBER, p_xml_data IN XMLTYPE,
        p_work_queue_id IN NUMBER DEFAULT NULL);
END DMT_PLAN_BUDGET_RESULTS_PKG;
/
