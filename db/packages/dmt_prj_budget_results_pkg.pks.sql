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
    -- RESET_UNACCOUNTED — re-run-reconcile recovery (backlog #95). Static UPDATE
    -- over this object's OWN literally-named TFM table: flip this run's
    -- UNACCOUNTED rows back to GENERATED and strip the bare [UNACCOUNTED] tag so
    -- the next reconcile pass re-examines them. Dispatched by the queue worker
    -- through the sanctioned invoke_registered site (INVOKE_RESET, RECON style);
    -- the ESS-id args are ignored. NO dynamic SQL; NO COMMIT (caller owns the txn).
    PROCEDURE RESET_UNACCOUNTED (p_run_id IN NUMBER, p_load_ess_id IN NUMBER DEFAULT NULL,
        p_import_ess_id IN NUMBER DEFAULT NULL, p_work_queue_id IN NUMBER DEFAULT NULL);
END DMT_PRJ_BUDGET_RESULTS_PKG;
/
