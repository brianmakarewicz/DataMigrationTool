-- PACKAGE BODY DMT_ASSIGNMENT_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_ASSIGNMENT_RESULTS_PKG"
AS
-- ============================================================
-- DMT_ASSIGNMENT_RESULTS_PKG body
-- Worker Assignment HDL reconciliation via DMT_HDL_UTIL_PKG.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_ASSIGNMENT_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'WorkerAssignments';
    -- Contract v1 registration CEMLI (design section 5): the DMT_BIP_REPORT_TBL
    -- row for the Assignments recon report is keyed 'Assignments' (its report
    -- catalog path is resolved by RUN_BIP_REPORT). This is the value passed to
    -- DMT_RECON_CONTRACT_PKG.FETCH_ROWS.
    C_RECON_CEMLI CONSTANT VARCHAR2(30) := 'Assignments';

    -- --------------------------------------------------------
    -- APPLY_CONTRACT_V1_ASSIGNMENTS (private)
    -- The Contract v1 base-tier positive proof for the Assignments object (design
    -- section 5), mirroring APPLY_CONTRACT_V1_SALARIES. The shared package
    -- DMT_RECON_CONTRACT_PKG.FETCH_ROWS runs the Assignments recon report over BIP
    -- and returns the parsed rows (no dynamic SQL, no TFM reference there); the
    -- APPLY here is STATIC SQL against the TWO compile-time-known Assignment TFM
    -- tables. Assignments loads two record types, so the ONE report returns two
    -- base tiers discriminated by OBJECT_TYPE, applied to the matching TFM table:
    --
    --   OBJECT_TYPE='WorkRelationship' -> DMT_WORK_REL_TFM_TBL, confirmed in
    --       PER_PERIODS_OF_SERVICE (via HRC_INTEGRATION_KEY_MAP), FUSION_ID = the
    --       real PERSON_ID stamped into FUSION_PERSON_ID. RECON_KEY =
    --       '<prefixed PERSON_NUMBER>_POS'.
    --   OBJECT_TYPE='Assignment'       -> DMT_ASSIGNMENT_TFM_TBL, confirmed in
    --       PER_ALL_ASSIGNMENTS_M (via HRC_INTEGRATION_KEY_MAP), FUSION_ID = the
    --       real ASSIGNMENT_ID stamped into FUSION_ASSIGNMENT_ID. RECON_KEY =
    --       '<ASSIGNMENT_NUMBER>_ASG' (the report also returns the '_TRM'
    --       work-terms sibling; that key never matches an assignment TFM row's
    --       RECON_KEY, so it corroborates only and is left for the sweep).
    --
    -- BASE/SUCCESS/FUSION_ID-not-null is the ONLY path to LOADED. An ERROR row
    -- with a real message -> FAILED on the exact message. This REPLACES the bulk
    -- LOOKUP_FUSION_IDS positive path. The HDL data set request id is the
    -- Contract v1 P_LOAD_REQUEST_ID.
    -- --------------------------------------------------------
    PROCEDURE APPLY_CONTRACT_V1_ASSIGNMENTS (
        p_run_id     IN NUMBER,
        p_request_id IN VARCHAR2
    ) IS
        C_PROC      CONSTANT VARCHAR2(30) := 'APPLY_CONTRACT_V1_ASSIGNMENTS';
        l_gen_count NUMBER := 0;
        l_rows      DMT_RECON_CONTRACT_PKG.T_RECON_TBL;
        l_err_code  NUMBER;
        l_loaded    NUMBER := 0;
        l_failed    NUMBER := 0;
    BEGIN
        -- Generated-row count across BOTH TFM tables drives the shared fetch's
        -- keyset page-count cap. Done statically here (not in the shared pkg).
        SELECT (SELECT COUNT(*) FROM DMT_WORK_REL_TFM_TBL    WHERE RUN_ID = p_run_id)
             + (SELECT COUNT(*) FROM DMT_ASSIGNMENT_TFM_TBL  WHERE RUN_ID = p_run_id)
        INTO   l_gen_count
        FROM   DUAL;

        DMT_RECON_CONTRACT_PKG.FETCH_ROWS(
            p_cemli_code  => C_RECON_CEMLI,
            p_run_id      => p_run_id,
            p_load_ess_id => TO_NUMBER(p_request_id),
            p_row_cap     => l_gen_count,
            x_rows        => l_rows,
            x_error_code  => l_err_code);

        -- A transport / SOAP failure raises loudly (design section 5: never a
        -- silent retry, never a zero-row "success"); the fetch already logged detail.
        IF l_err_code <> DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20095,
                'APPLY_CONTRACT_V1_ASSIGNMENTS: Contract v1 fetch failed for '
                || 'Assignments (detail in DMT_LOG_TBL).');
        END IF;

        IF l_rows.COUNT = 0 THEN
            -- Zero report rows is never success (design section 5): leave the
            -- remaining GENERATED rows for the existing unaccounted sweep.
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ': Assignments recon report returned zero '
                               || 'rows; GENERATED rows left for the unaccounted '
                               || 'sweep (never a silent success).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
        ELSE
            FOR i IN 1 .. l_rows.COUNT LOOP
                IF l_rows(i).SOURCE_TYPE = 'BASE'
                   AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                   AND l_rows(i).FUSION_ID IS NOT NULL THEN
                    -- Positive proof: base row found with a real id. The ONLY
                    -- path to LOADED. Static UPDATE against the matching TFM
                    -- table by OBJECT_TYPE.
                    IF l_rows(i).OBJECT_TYPE = 'WorkRelationship' THEN
                        UPDATE DMT_WORK_REL_TFM_TBL
                        SET    TFM_STATUS           = 'LOADED',
                               FUSION_PERSON_ID     = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_loaded := l_loaded + SQL%ROWCOUNT;

                    ELSIF l_rows(i).OBJECT_TYPE = 'Assignment' THEN
                        UPDATE DMT_ASSIGNMENT_TFM_TBL
                        SET    TFM_STATUS           = 'LOADED',
                               FUSION_ASSIGNMENT_ID = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_loaded := l_loaded + SQL%ROWCOUNT;
                    END IF;

                ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                      AND l_rows(i).ERROR_MESSAGE IS NOT NULL THEN
                    -- A real, specific Fusion error -> FAILED on the exact
                    -- message (never composed). Static UPDATE against the
                    -- matching TFM table by OBJECT_TYPE.
                    IF l_rows(i).OBJECT_TYPE = 'WorkRelationship' THEN
                        UPDATE DMT_WORK_REL_TFM_TBL
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

                    ELSIF l_rows(i).OBJECT_TYPE = 'Assignment' THEN
                        UPDATE DMT_ASSIGNMENT_TFM_TBL
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
                    END IF;

                ELSE
                    -- INTERFACE/SUCCESS (corroborating, never sufficient), the
                    -- '_TRM' work-terms sibling key (no TFM row of its own), or a
                    -- non-terminal status with no real error: leave for the
                    -- existing unaccounted sweep. Never fabricate an outcome.
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
    END APPLY_CONTRACT_V1_ASSIGNMENTS;

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

        -- 1. WorkRelationship — Contract v1 base-table proof (design section 5).
        --    The per-record HDL error path still runs (real [FUSION_ERROR] rows
        --    are marked FAILED here), but LOADED promotion is DEFERRED to the
        --    shared Contract v1 parser below: a WorkRelationship row reaches
        --    LOADED only when the period of service is positively confirmed in the
        --    Fusion base table (PER_PERIODS_OF_SERVICE) with a real person id.
        DMT_HDL_UTIL_PKG.RECONCILE_HDL(
            p_run_id => p_run_id,
            p_request_id       => p_request_id,
            p_tfm_table        => 'DMT_WORK_REL_TFM_TBL',
            p_stg_table        => 'DMT_WORK_REL_STG_TBL',
            p_key_column       => 'PERSON_NUMBER',
            p_dataset_status   => p_dataset_status,
            p_log_context      => C_CEMLI || ' > WorkRelationship',
            p_defer_base_proof => TRUE);

        -- 2. Assignment — Contract v1 base-table proof (design section 5).
        --    Both the employment-terms and assignment records this run loads are
        --    keyed by the source ASSIGNMENT_NUMBER, not the person: the generator
        --    emits SourceSystemId '<ASSIGNMENT_NUMBER>_TRM' (WorkTerms) and
        --    '<ASSIGNMENT_NUMBER>_ASG' (Assignment). Fusion returns per-row errors
        --    under those same ids (e.g. 'ET-RT-WKR-G1_TRM'), which do NOT start
        --    with a PERSON_NUMBER, so a PERSON_NUMBER key matched nothing. Match on
        --    ASSIGNMENT_NUMBER with the exact '_TRM'/'_ASG' suffixes so each real
        --    error ties to its own assignment row (and 'G1' cannot absorb 'G1B').
        --    LOADED promotion is DEFERRED to the shared Contract v1 parser below.
        DMT_HDL_UTIL_PKG.RECONCILE_HDL(
            p_run_id => p_run_id,
            p_request_id       => p_request_id,
            p_tfm_table        => 'DMT_ASSIGNMENT_TFM_TBL',
            p_stg_table        => 'DMT_ASSIGNMENT_STG_TBL',
            p_key_column       => 'ASSIGNMENT_NUMBER',
            p_dataset_status   => p_dataset_status,
            p_log_context      => C_CEMLI || ' > Assignment',
            p_key_suffixes     => '_TRM,_ASG',
            p_defer_base_proof => TRUE);

        -- Contract v1 base-tier positive proof (design section 5), Option A shape:
        -- the shared package fetches the parsed report rows (no dynamic SQL, no TFM
        -- reference there) and the APPLY is done here as STATIC SQL against the two
        -- compile-time-known Assignment TFM tables. Extracted into its own private
        -- procedure (one BEGIN/END per procedure). This REPLACES the former
        -- LOOKUP_FUSION_IDS positive path for Assignments.
        APPLY_CONTRACT_V1_ASSIGNMENTS(p_run_id, p_request_id);

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
