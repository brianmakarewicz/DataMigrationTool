-- PACKAGE DMT_PERF_EVAL_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_PERF_EVAL_RESULTS_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_PERF_EVAL_RESULTS_PKG
-- Post-load HDL reconciliation for PerfEvaluations (loaded via HDL as GoalPlan).
-- Calls DMT_HDL_UTIL_PKG.RECONCILE_HDL for each TFM table, then applies the shared
-- Contract v1 base-table positive proof (HRG_GOAL_PLANS_VL) via
-- DMT_RECON_CONTRACT_PKG.FETCH_ROWS + a private static APPLY.
--
-- CEMLI_CODE: 'PerfEvaluations'
-- ============================================================

    PROCEDURE RECONCILE_BATCH (
        p_run_id IN NUMBER,
        p_request_id     IN VARCHAR2,
        p_dataset_status IN VARCHAR2 DEFAULT NULL
    );

END DMT_PERF_EVAL_RESULTS_PKG;
/
