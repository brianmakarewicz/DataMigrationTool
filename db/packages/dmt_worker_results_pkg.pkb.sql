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

        -- 1. Worker — Contract v1 base-table proof (design section 5).
        -- The per-record HDL error path still runs (real [FUSION_ERROR] rows are
        -- marked FAILED here), but LOADED promotion is DEFERRED to the shared
        -- Contract v1 parser below: a Worker row reaches LOADED only when the
        -- person is positively confirmed in the Fusion base table (PER_ALL_PEOPLE_F)
        -- with a real person id, which the parser stamps into FUSION_PERSON_ID.
        DMT_HDL_UTIL_PKG.RECONCILE_HDL(
            p_run_id => p_run_id,
            p_request_id       => p_request_id,
            p_tfm_table        => 'DMT_WORKER_TFM_TBL',
            p_stg_table        => 'DMT_WORKER_STG_TBL',
            p_key_column       => 'PERSON_NUMBER',
            p_dataset_status   => p_dataset_status,
            p_log_context      => C_CEMLI || ' > Worker',
            p_defer_base_proof => TRUE);

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

        -- Contract v1 base-tier positive proof (design section 5) — the shared
        -- parser. It runs the Workers recon report over BIP, confirms each migrated
        -- worker in the Fusion base table (PER_ALL_PEOPLE_F) by person number, and
        -- marks that Worker TFM row LOADED with the real Fusion person id stamped
        -- into FUSION_PERSON_ID; any BASE/ERROR row is marked FAILED with the real
        -- Fusion error. This REPLACES the bulk LOOKUP_FUSION_IDS positive path for
        -- Workers. The single-record REST "Verify in Fusion" button path is
        -- unchanged. The HDL data set request id is the Contract v1 P_LOAD_REQUEST_ID.
        DMT_RECON_CONTRACT_PKG.RECONCILE(
            p_cemli_code  => C_CEMLI,
            p_run_id      => p_run_id,
            p_load_ess_id => TO_NUMBER(p_request_id));

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
