-- PACKAGE BODY DMT_BEN_DEPEND_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_BEN_DEPEND_RESULTS_PKG" 
AS
-- ============================================================
-- DMT_BEN_DEPEND_RESULTS_PKG body
-- DependentEnrollment HDL reconciliation via DMT_HDL_UTIL_PKG.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_BEN_DEPEND_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'DependentEnrollments';

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


        -- 1. DependentEnrollment
        DMT_HDL_UTIL_PKG.RECONCILE_HDL(
            p_run_id => p_run_id,
            p_request_id     => p_request_id,
            p_tfm_table      => 'DMT_BEN_DEPEND_TFM_TBL',
            p_stg_table      => 'DMT_BEN_DEPEND_STG_TBL',
            p_key_column     => 'PERSON_NUMBER',
            p_dataset_status => p_dataset_status,
            p_log_context    => C_CEMLI || ' > DependentEnrollment');


        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' complete. All 1 object type(s) reconciled.',
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

END DMT_BEN_DEPEND_RESULTS_PKG;
/
