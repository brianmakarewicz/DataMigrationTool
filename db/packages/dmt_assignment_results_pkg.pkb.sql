-- PACKAGE BODY DMT_ASSIGNMENT_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_ASSIGNMENT_RESULTS_PKG" 
AS
-- ============================================================
-- DMT_ASSIGNMENT_RESULTS_PKG body
-- Worker Assignment HDL reconciliation via DMT_HDL_UTIL_PKG.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_ASSIGNMENT_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'WorkerAssignments';

    -- --------------------------------------------------------
    -- RECONCILE_BATCH
    -- Calls RECONCILE_HDL for each of the 2 Worker Assignment TFM tables.
    -- Each call retrieves HDL error messages and updates
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

        -- 1. WorkRelationship
        DMT_HDL_UTIL_PKG.RECONCILE_HDL(
            p_run_id => p_run_id,
            p_request_id     => p_request_id,
            p_tfm_table      => 'DMT_WORK_REL_TFM_TBL',
            p_stg_table      => 'DMT_WORK_REL_STG_TBL',
            p_key_column     => 'PERSON_NUMBER',
            p_dataset_status => p_dataset_status,
            p_log_context    => C_CEMLI || ' > WorkRelationship');

        -- 2. Assignment
        --    Both the employment-terms and assignment records this run loads are
        --    keyed by the source ASSIGNMENT_NUMBER, not the person: the generator
        --    emits SourceSystemId '<ASSIGNMENT_NUMBER>_TRM' (WorkTerms) and
        --    '<ASSIGNMENT_NUMBER>_ASG' (Assignment). Fusion returns per-row errors
        --    under those same ids (e.g. 'ET-RT-WKR-G1_TRM'), which do NOT start
        --    with a PERSON_NUMBER, so a PERSON_NUMBER key matched nothing. Match on
        --    ASSIGNMENT_NUMBER with the exact '_TRM'/'_ASG' suffixes so each real
        --    error ties to its own assignment row (and 'G1' cannot absorb 'G1B').
        DMT_HDL_UTIL_PKG.RECONCILE_HDL(
            p_run_id => p_run_id,
            p_request_id     => p_request_id,
            p_tfm_table      => 'DMT_ASSIGNMENT_TFM_TBL',
            p_stg_table      => 'DMT_ASSIGNMENT_STG_TBL',
            p_key_column     => 'ASSIGNMENT_NUMBER',
            p_dataset_status => p_dataset_status,
            p_log_context    => C_CEMLI || ' > Assignment',
            p_key_suffixes   => '_TRM,_ASG');

        -- Post-reconciliation: look up Fusion Assignment IDs for LOADED assignments
        DMT_HDL_UTIL_PKG.LOOKUP_FUSION_IDS(
            p_run_id => p_run_id,
            p_object_type    => 'Assignment',
            p_log_context    => C_CEMLI || ' > Assignment');

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' complete. All 2 object types reconciled.',
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

END DMT_ASSIGNMENT_RESULTS_PKG;
/
