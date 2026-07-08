-- PACKAGE BODY DMT_WORKER_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_WORKER_RESULTS_PKG" 
AS
-- ============================================================
-- DMT_WORKER_RESULTS_PKG body
-- Worker HDL reconciliation via DMT_HDL_UTIL_PKG.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_WORKER_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'Workers';

    -- --------------------------------------------------------
    -- RECONCILE_BATCH
    -- Calls RECONCILE_HDL for each of the 7 Worker TFM tables.
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

        -- 1. Worker
        DMT_HDL_UTIL_PKG.RECONCILE_HDL(
            p_run_id => p_run_id,
            p_request_id     => p_request_id,
            p_tfm_table      => 'DMT_WORKER_TFM_TBL',
            p_stg_table      => 'DMT_WORKER_STG_TBL',
            p_key_column     => 'PERSON_NUMBER',
            p_dataset_status => p_dataset_status,
            p_log_context    => C_CEMLI || ' > Worker');

        -- 2. PersonName
        DMT_HDL_UTIL_PKG.RECONCILE_HDL(
            p_run_id => p_run_id,
            p_request_id     => p_request_id,
            p_tfm_table      => 'DMT_PERSON_NAME_TFM_TBL',
            p_stg_table      => 'DMT_PERSON_NAME_STG_TBL',
            p_key_column     => 'PERSON_NUMBER',
            p_dataset_status => p_dataset_status,
            p_log_context    => C_CEMLI || ' > PersonName');

        -- 3. PersonEmail
        DMT_HDL_UTIL_PKG.RECONCILE_HDL(
            p_run_id => p_run_id,
            p_request_id     => p_request_id,
            p_tfm_table      => 'DMT_PERSON_EMAIL_TFM_TBL',
            p_stg_table      => 'DMT_PERSON_EMAIL_STG_TBL',
            p_key_column     => 'PERSON_NUMBER',
            p_dataset_status => p_dataset_status,
            p_log_context    => C_CEMLI || ' > PersonEmail');

        -- 4. PersonPhone
        DMT_HDL_UTIL_PKG.RECONCILE_HDL(
            p_run_id => p_run_id,
            p_request_id     => p_request_id,
            p_tfm_table      => 'DMT_PERSON_PHONE_TFM_TBL',
            p_stg_table      => 'DMT_PERSON_PHONE_STG_TBL',
            p_key_column     => 'PERSON_NUMBER',
            p_dataset_status => p_dataset_status,
            p_log_context    => C_CEMLI || ' > PersonPhone');

        -- 5. PersonAddress
        DMT_HDL_UTIL_PKG.RECONCILE_HDL(
            p_run_id => p_run_id,
            p_request_id     => p_request_id,
            p_tfm_table      => 'DMT_PERSON_ADDR_TFM_TBL',
            p_stg_table      => 'DMT_PERSON_ADDR_STG_TBL',
            p_key_column     => 'PERSON_NUMBER',
            p_dataset_status => p_dataset_status,
            p_log_context    => C_CEMLI || ' > PersonAddress');

        -- 6. PersonNationalIdentifier
        DMT_HDL_UTIL_PKG.RECONCILE_HDL(
            p_run_id => p_run_id,
            p_request_id     => p_request_id,
            p_tfm_table      => 'DMT_PERSON_NID_TFM_TBL',
            p_stg_table      => 'DMT_PERSON_NID_STG_TBL',
            p_key_column     => 'PERSON_NUMBER',
            p_dataset_status => p_dataset_status,
            p_log_context    => C_CEMLI || ' > PersonNationalIdentifier');

        -- 7. PersonLegislativeData
        DMT_HDL_UTIL_PKG.RECONCILE_HDL(
            p_run_id => p_run_id,
            p_request_id     => p_request_id,
            p_tfm_table      => 'DMT_PERSON_LEGISL_TFM_TBL',
            p_stg_table      => 'DMT_PERSON_LEGISL_STG_TBL',
            p_key_column     => 'PERSON_NUMBER',
            p_dataset_status => p_dataset_status,
            p_log_context    => C_CEMLI || ' > PersonLegislativeData');

        -- Post-reconciliation: look up Fusion Person IDs for LOADED workers
        DMT_HDL_UTIL_PKG.LOOKUP_FUSION_IDS(
            p_run_id => p_run_id,
            p_object_type    => 'Worker',
            p_log_context    => C_CEMLI || ' > Worker');

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' complete. All 7 object types reconciled.',
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

END DMT_WORKER_RESULTS_PKG;
/
