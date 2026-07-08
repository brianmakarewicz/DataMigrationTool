-- PACKAGE DMT_PERF_EVAL_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_PERF_EVAL_RESULTS_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_PERF_EVAL_RESULTS_PKG
-- Post-load HDL reconciliation for PerformanceDocuments.
-- Calls DMT_HDL_UTIL_PKG.RECONCILE_HDL for each TFM table.
--
-- CEMLI_CODE: 'PerformanceDocuments'
-- ============================================================

    PROCEDURE RECONCILE_BATCH (
        p_run_id IN NUMBER,
        p_request_id     IN VARCHAR2,
        p_dataset_status IN VARCHAR2 DEFAULT NULL
    );

END DMT_PERF_EVAL_RESULTS_PKG;
/
