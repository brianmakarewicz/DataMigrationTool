-- PACKAGE BODY DMT_WORK_SCHED_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_WORK_SCHED_RESULTS_PKG" 
AS
-- ============================================================
-- DMT_WORK_SCHED_RESULTS_PKG body
-- WorkSchedule HDL reconciliation via DMT_HDL_UTIL_PKG.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_WORK_SCHED_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'WorkSchedules';

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


        -- 1. WorkSchedule
        DMT_HDL_UTIL_PKG.RECONCILE_HDL(
            p_run_id => p_run_id,
            p_request_id     => p_request_id,
            p_tfm_table      => 'DMT_WORK_SCHED_TFM_TBL',
            p_stg_table      => 'DMT_WORK_SCHED_STG_TBL',
            p_key_column     => 'WORK_SCHEDULE_NAME',
            p_dataset_status => p_dataset_status,
            p_log_context    => C_CEMLI || ' > WorkSchedule');


        -- 2. WorkScheduleShift
        DMT_HDL_UTIL_PKG.RECONCILE_HDL(
            p_run_id => p_run_id,
            p_request_id     => p_request_id,
            p_tfm_table      => 'DMT_WORK_SCHED_DTL_TFM_TBL',
            p_stg_table      => 'DMT_WORK_SCHED_DTL_STG_TBL',
            p_key_column     => 'WORK_SCHEDULE_NAME',
            p_dataset_status => p_dataset_status,
            p_log_context    => C_CEMLI || ' > WorkScheduleShift');

        -- Post-reconciliation: capture the Fusion schedule id on each LOADED
        -- row (design section 7 rule). Blocked object today.
        DMT_HDL_UTIL_PKG.LOOKUP_FUSION_IDS(
            p_run_id => p_run_id,
            p_object_type    => 'WorkSchedules',
            p_log_context    => C_CEMLI || ' > WorkSchedule');


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

END DMT_WORK_SCHED_RESULTS_PKG;
/
