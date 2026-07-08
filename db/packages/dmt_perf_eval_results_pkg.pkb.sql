-- PACKAGE BODY DMT_PERF_EVAL_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_PERF_EVAL_RESULTS_PKG" 
AS
-- ============================================================
-- DMT_PERF_EVAL_RESULTS_PKG body
-- PerformanceDocument HDL reconciliation via DMT_HDL_UTIL_PKG.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_PERF_EVAL_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'PerformanceDocuments';

    PROCEDURE RECONCILE_BATCH (
        p_run_id IN NUMBER,
        p_request_id     IN VARCHAR2,
        p_dataset_status IN VARCHAR2 DEFAULT NULL
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RECONCILE_BATCH';
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' start. RequestId: ' || p_request_id,
            p_package        => C_PKG,
            p_procedure      => C_PROC);


        -- 1. PerformanceDocument
        DMT_HDL_UTIL_PKG.RECONCILE_HDL(
            p_run_id => p_run_id,
            p_request_id     => p_request_id,
            p_tfm_table      => 'DMT_PERF_EVAL_TFM_TBL',
            p_stg_table      => 'DMT_PERF_EVAL_STG_TBL',
            p_key_column     => 'PERSON_NUMBER',
            p_dataset_status => p_dataset_status,
            p_log_context    => C_CEMLI || ' > PerformanceDocument');


        -- 2. PerformanceRating
        DMT_HDL_UTIL_PKG.RECONCILE_HDL(
            p_run_id => p_run_id,
            p_request_id     => p_request_id,
            p_tfm_table      => 'DMT_PERF_EVAL_RATING_TFM_TBL',
            p_stg_table      => 'DMT_PERF_EVAL_RATING_STG_TBL',
            p_key_column     => 'PERSON_NUMBER',
            p_dataset_status => p_dataset_status,
            p_log_context    => C_CEMLI || ' > PerformanceRating');


        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' complete. All 2 object type(s) reconciled.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => C_PROC || ' failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END RECONCILE_BATCH;

END DMT_PERF_EVAL_RESULTS_PKG;
/
