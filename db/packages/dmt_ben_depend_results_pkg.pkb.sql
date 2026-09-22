-- PACKAGE BODY DMT_BEN_DEPEND_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_BEN_DEPEND_RESULTS_PKG"
AS
-- ============================================================
-- DMT_BEN_DEPEND_RESULTS_PKG body
-- BenDependent HDL reconciliation via DMT_HDL_UTIL_PKG.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_BEN_DEPEND_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'BenDependent';

    -- --------------------------------------------------------
    -- APPLY_CONTRACT_V1_BENDEPENDENT (private)
    -- The Contract v1 base-tier positive proof for the BenDependent record (design
    -- section 5), Option A shape (owner decision on PR #248), mirroring
    -- APPLY_CONTRACT_V1_WORKERS. The shared package DMT_RECON_CONTRACT_PKG.FETCH_ROWS
    -- runs the BenDependent recon report over BIP and returns the parsed rows (no
    -- dynamic SQL, no TFM reference there); the APPLY here is STATIC SQL against the
    -- compile-time-known BenDependent TFM table. It confirms each migrated dependent
    -- designation by its DesignateDependent HRC_INTEGRATION_KEY_MAP row
    -- (OBJECT_NAME='DesignateDependent', written by the DependentEnrollment HDL
    -- load) matched on SourceSystemId, and marks that BenDependent TFM row LOADED
    -- with the real Fusion designation id (SURROGATE_ID) stamped into
    -- FUSION_DEPENDENT_ID; any ERROR row is marked FAILED with the real Fusion
    -- error. This REPLACES the bulk LOOKUP_FUSION_IDS positive path for
    -- BenDependent. The HDL data set request id is the Contract v1
    -- P_LOAD_REQUEST_ID.
    -- --------------------------------------------------------
    PROCEDURE APPLY_CONTRACT_V1_BENDEPENDENT (
        p_run_id     IN NUMBER,
        p_request_id IN VARCHAR2
    ) IS
        C_PROC      CONSTANT VARCHAR2(30) := 'APPLY_CONTRACT_V1_BENDEP';
        l_gen_count NUMBER := 0;
        l_rows      DMT_RECON_CONTRACT_PKG.T_RECON_TBL;
        l_err_code  NUMBER;
        l_loaded    NUMBER := 0;
        l_failed    NUMBER := 0;
    BEGIN
        -- Generated-row count is done statically here (not in the shared pkg),
        -- and drives the shared fetch's keyset page-count cap.
        SELECT COUNT(*) INTO l_gen_count
        FROM   DMT_BEN_DEPEND_TFM_TBL
        WHERE  RUN_ID = p_run_id;

        DMT_RECON_CONTRACT_PKG.FETCH_ROWS(
            p_cemli_code  => C_CEMLI,
            p_run_id      => p_run_id,
            p_load_ess_id => TO_NUMBER(p_request_id),
            p_row_cap     => l_gen_count,
            x_rows        => l_rows,
            x_error_code  => l_err_code);

        -- A transport / SOAP failure raises loudly (design section 5: never a
        -- silent retry, never a zero-row "success"); the fetch already logged detail.
        IF l_err_code <> DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20094,
                'APPLY_CONTRACT_V1_BENDEPENDENT: Contract v1 fetch failed for '
                || 'BenDependent (detail in DMT_LOG_TBL).');
        END IF;

        IF l_rows.COUNT = 0 THEN
            -- Zero report rows is never success (design section 5): leave the
            -- remaining GENERATED rows for the existing unaccounted sweep.
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ': BenDependent recon report returned zero '
                               || 'rows; GENERATED rows left for the unaccounted sweep '
                               || '(never a silent success).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
        ELSE
            FOR i IN 1 .. l_rows.COUNT LOOP
                IF l_rows(i).SOURCE_TYPE = 'BASE'
                   AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                   AND l_rows(i).FUSION_ID IS NOT NULL THEN
                    -- Positive proof: dependent designation confirmed by its
                    -- DesignateDependent key-map row with a real Fusion id. The
                    -- ONLY path to LOADED. Static UPDATE.
                    UPDATE DMT_BEN_DEPEND_TFM_TBL
                    SET    TFM_STATUS           = 'LOADED',
                           FUSION_DEPENDENT_ID  = l_rows(i).FUSION_ID,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID    = p_run_id
                    AND    RECON_KEY = l_rows(i).RECORD_KEY
                    AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                    l_loaded := l_loaded + SQL%ROWCOUNT;

                ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                      AND l_rows(i).ERROR_MESSAGE IS NOT NULL THEN
                    -- A real, specific Fusion error -> FAILED on the exact
                    -- message (never composed). Static UPDATE.
                    UPDATE DMT_BEN_DEPEND_TFM_TBL
                    SET    TFM_STATUS           = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(
                                                    ERROR_TEXT,
                                                    '[FUSION_ERROR] ' || l_rows(i).ERROR_MESSAGE),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID    = p_run_id
                    AND    RECON_KEY = l_rows(i).RECORD_KEY
                    AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                    l_failed := l_failed + SQL%ROWCOUNT;

                ELSE
                    -- INTERFACE/SUCCESS (corroborating, never sufficient) or a
                    -- non-terminal status with no real error: leave the row for
                    -- the existing unaccounted sweep. Never fabricate an outcome.
                    NULL;
                END IF;
            END LOOP;
        END IF;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Report rows: ' || l_rows.COUNT
                           || ' | LOADED: ' || l_loaded
                           || ' | FAILED: ' || l_failed || '.',
            p_package   => C_PKG,
            p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ' failed.',
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE;
    END APPLY_CONTRACT_V1_BENDEPENDENT;

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


        -- 1. BenDependent — Contract v1 base-table proof (design section 5).
        -- The per-record HDL error path still runs (real [FUSION_ERROR] rows are
        -- marked FAILED here), but LOADED promotion is DEFERRED to the shared
        -- Contract v1 parser below: a BenDependent row reaches LOADED only when the
        -- dependent designation is positively confirmed by its DesignateDependent
        -- HRC_INTEGRATION_KEY_MAP row with a real Fusion designation id, which the
        -- parser stamps into FUSION_DEPENDENT_ID.
        DMT_HDL_UTIL_PKG.RECONCILE_HDL(
            p_run_id => p_run_id,
            p_request_id       => p_request_id,
            p_tfm_table        => 'DMT_BEN_DEPEND_TFM_TBL',
            p_stg_table        => 'DMT_BEN_DEPEND_STG_TBL',
            p_key_column       => 'PERSON_NUMBER',
            p_dataset_status   => p_dataset_status,
            p_log_context      => C_CEMLI || ' > DependentEnrollment',
            p_defer_base_proof => TRUE);

        -- Contract v1 base-tier positive proof (design section 5), Option A shape
        -- (owner decision on PR #248): the shared package fetches the parsed report
        -- rows (no dynamic SQL, no TFM reference there) and the APPLY is done here
        -- as STATIC SQL against the compile-time-known BenDependent TFM table. This
        -- REPLACES the prior LOOKUP_FUSION_IDS positive path for BenDependent.
        APPLY_CONTRACT_V1_BENDEPENDENT(p_run_id, p_request_id);


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
