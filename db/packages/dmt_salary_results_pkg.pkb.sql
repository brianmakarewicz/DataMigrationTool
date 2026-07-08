-- PACKAGE BODY DMT_SALARY_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_SALARY_RESULTS_PKG" 
AS
-- ============================================================
-- DMT_SALARY_RESULTS_PKG body
-- Salary HDL reconciliation via DMT_HDL_UTIL_PKG.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_SALARY_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'Salaries';

    -- --------------------------------------------------------
    -- RECONCILE_BATCH
    -- Calls RECONCILE_HDL for the Salary TFM table.
    -- Retrieves HDL error messages and updates
    -- TFM rows to LOADED or FAILED, then echoes to STG.
    -- --------------------------------------------------------
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

        -- 1. Salary
        DMT_HDL_UTIL_PKG.RECONCILE_HDL(
            p_run_id => p_run_id,
            p_request_id     => p_request_id,
            p_tfm_table      => 'DMT_SALARY_TFM_TBL',
            p_stg_table      => 'DMT_SALARY_STG_TBL',
            p_key_column     => 'PERSON_NUMBER',
            p_dataset_status => p_dataset_status,
            p_log_context    => C_CEMLI || ' > Salary');

        -- Post-reconciliation: look up Fusion Salary IDs for LOADED salaries
        DMT_HDL_UTIL_PKG.LOOKUP_FUSION_IDS(
            p_run_id => p_run_id,
            p_object_type    => 'Salary',
            p_log_context    => C_CEMLI || ' > Salary');

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' complete. Salary object type reconciled.',
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

END DMT_SALARY_RESULTS_PKG;
/
