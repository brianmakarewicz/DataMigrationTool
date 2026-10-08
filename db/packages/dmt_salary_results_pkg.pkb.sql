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
    -- APPLY_CONTRACT_V1_SALARIES (private)
    -- The Contract v1 base-tier positive proof for the Salary record (design
    -- section 5), mirroring APPLY_CONTRACT_V1_WORKERS. The shared package
    -- DMT_RECON_CONTRACT_PKG.FETCH_ROWS runs the Salaries recon report over BIP and
    -- returns the parsed rows (no dynamic SQL, no TFM reference there); the APPLY
    -- here is STATIC SQL against the compile-time-known Salary TFM table. It confirms
    -- each migrated salary in the Fusion base table (CMP_SALARY, via the load's
    -- HRC_INTEGRATION_KEY_MAP row) by its SourceSystemId and marks that Salary TFM
    -- row LOADED with the real Fusion salary id stamped into FUSION_SALARY_ID; any
    -- ERROR row is marked FAILED with the real Fusion error. This REPLACES the bulk
    -- LOOKUP_FUSION_IDS positive path for Salaries. The single-record REST
    -- "Verify in Fusion" button path is unchanged. The HDL data set request id is the
    -- Contract v1 P_LOAD_REQUEST_ID.
    -- --------------------------------------------------------
    PROCEDURE APPLY_CONTRACT_V1_SALARIES (
        p_run_id     IN NUMBER,
        p_request_id IN VARCHAR2
    ) IS
        C_PROC      CONSTANT VARCHAR2(30) := 'APPLY_CONTRACT_V1_SALARIES';
        l_gen_count NUMBER := 0;
        l_rows      DMT_RECON_CONTRACT_PKG.T_RECON_TBL;
        l_err_code  NUMBER;
        l_loaded    NUMBER := 0;
        l_failed    NUMBER := 0;
    BEGIN
        -- Generated-row count is done statically here (not in the shared pkg),
        -- and drives the shared fetch's keyset page-count cap.
        SELECT COUNT(*) INTO l_gen_count
        FROM   DMT_SALARY_TFM_TBL
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
                'APPLY_CONTRACT_V1_SALARIES: Contract v1 fetch failed for Salaries '
                || '(detail in DMT_LOG_TBL).');
        END IF;

        IF l_rows.COUNT = 0 THEN
            -- Zero report rows is never success (design section 5): leave the
            -- remaining GENERATED rows for the existing unaccounted sweep.
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ': Salaries recon report returned zero rows; '
                               || 'GENERATED rows left for the unaccounted sweep '
                               || '(never a silent success).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
        ELSE
            FOR i IN 1 .. l_rows.COUNT LOOP
                IF l_rows(i).SOURCE_TYPE = 'BASE'
                   AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                   AND l_rows(i).FUSION_ID IS NOT NULL THEN
                    -- Positive proof: salary found in CMP_SALARY with a real id, by
                    -- the request-id report (V2, backlog #291). The ONLY path to LOADED.
                    -- Matched on the exact SourceSystemId the generator wrote
                    -- (PERSON_NUMBER || '_SAL'), never on RECON_KEY: the BAD row's
                    -- RECON_KEY carries the run prefix its unprefixed PERSON_NUMBER
                    -- (and so its SourceSystemId) does not. Static UPDATE.
                    UPDATE DMT_SALARY_TFM_TBL
                    SET    TFM_STATUS           = 'LOADED',
                           FUSION_SALARY_ID     = l_rows(i).FUSION_ID,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID    = p_run_id
                    AND    PERSON_NUMBER || '_SAL' = l_rows(i).RECORD_KEY
                    AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                    l_loaded := l_loaded + SQL%ROWCOUNT;

                ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                      AND l_rows(i).ERROR_MESSAGE IS NOT NULL THEN
                    -- A real, specific Fusion error -> FAILED on the exact
                    -- message (never composed). Static UPDATE.
                    UPDATE DMT_SALARY_TFM_TBL
                    SET    TFM_STATUS           = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(
                                                    ERROR_TEXT,
                                                    '[FUSION_ERROR] ' || l_rows(i).ERROR_MESSAGE),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID    = p_run_id
                    AND    PERSON_NUMBER || '_SAL' = l_rows(i).RECORD_KEY
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
    END APPLY_CONTRACT_V1_SALARIES;

    -- --------------------------------------------------------
    -- APPLY_HDL_ERRORS (private, backlog #288)
    -- Per-record HDL errors, static SQL. DMT_HDL_UTIL_PKG.STAGE_HDL_MESSAGES has
    -- already staged every page of this data set's error messages in
    -- DMT_HDL_MESSAGE_GTT. A GENERATED row is marked FAILED only when a message
    -- names EXACTLY the SourceSystemId its generator wrote for it (never LIKE,
    -- never a prefix), and it gets that message, named:
    --   [FUSION_ERROR] <SourceSystemId> (<file> line <n>): <Fusion message>
    -- Replaces the dynamic-SQL DMT_HDL_UTIL_PKG.RECONCILE_HDL.
    -- --------------------------------------------------------
    PROCEDURE APPLY_HDL_ERRORS (
        p_run_id     IN NUMBER,
        p_request_id IN VARCHAR2
    ) IS
        C_PROC    CONSTANT VARCHAR2(30) := 'APPLY_HDL_ERRORS';
        l_request NUMBER := TO_NUMBER(p_request_id);
        l_failed  NUMBER := 0;
    BEGIN
        -- DMT_SALARY_TFM_TBL: SourceSystemId = PERSON_NUMBER || '_SAL'
        UPDATE DMT_SALARY_TFM_TBL t
        SET    t.TFM_STATUS           = 'FAILED',
               t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT,
                                            DMT_HDL_UTIL_PKG.ROW_ERRORS(p_request_id, t.PERSON_NUMBER || '_SAL')),
               t.RESULTS_UPDATED_DATE = SYSDATE,
               t.LAST_UPDATED_DATE    = SYSDATE
        WHERE  t.RUN_ID     = p_run_id
        AND    t.TFM_STATUS = 'GENERATED'
        AND    EXISTS (SELECT 1
                       FROM   DMT_HDL_MESSAGE_GTT m
                       WHERE  m.REQUEST_ID       = l_request
                       AND    m.SOURCE_SYSTEM_ID IN (t.PERSON_NUMBER || '_SAL'));
        l_failed := l_failed + SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Rows FAILED on their own named HDL error: ' || l_failed || '.',
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
    END APPLY_HDL_ERRORS;

    -- --------------------------------------------------------
    -- APPLY_FILE_ERRORS (private, backlog #288)
    -- Whole-file rejections, static SQL. Messages that name no record (no
    -- SourceSystemId: an invalid METADATA line, an unknown file, a data-set
    -- message) reject every record of their .dat file. They are applied LAST,
    -- after the per-record errors and the base-table proof, and only to rows
    -- still GENERATED, so a row proven LOADED or already FAILED on its own error
    -- is never touched. The text is Fusion's own, named with the file and line.
    -- --------------------------------------------------------
    PROCEDURE APPLY_FILE_ERRORS (
        p_run_id     IN NUMBER,
        p_request_id IN VARCHAR2
    ) IS
        C_PROC   CONSTANT VARCHAR2(30) := 'APPLY_FILE_ERRORS';
        l_text   VARCHAR2(4000);
        l_failed NUMBER := 0;
    BEGIN
        -- DMT_SALARY_TFM_TBL: whole-file messages of Salary.dat
        l_text := DMT_HDL_UTIL_PKG.FILE_LEVEL_ERRORS(p_request_id, 'Salary.dat');
        IF l_text IS NOT NULL THEN
            UPDATE DMT_SALARY_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_text),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID     = p_run_id
            AND    t.TFM_STATUS = 'GENERATED';
            l_failed := l_failed + SQL%ROWCOUNT;
        END IF;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Rows FAILED by a whole-file HDL error: ' || l_failed || '.',
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
    END APPLY_FILE_ERRORS;

    -- --------------------------------------------------------
    -- RECONCILE_BATCH
    -- Stages the data set's HDL error messages (all pages), applies each one
    -- to the row whose SourceSystemId it names exactly, applies the base-table
    -- proof (the only path to LOADED), then the whole-file rejections.
    -- --------------------------------------------------------
    PROCEDURE RECONCILE_BATCH (
        p_run_id IN NUMBER,
        p_request_id     IN VARCHAR2,
        p_dataset_status IN VARCHAR2 DEFAULT NULL
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RECONCILE_BATCH';
        l_msg_count NUMBER;  -- HDL error messages staged for this data set
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' start. RequestId: ' || p_request_id,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        -- Per-record HDL errors (backlog #288): stage every page of this data
        -- set's error messages, then mark FAILED only the rows a message names
        -- exactly. LOADED comes only from base-table proof; there is no
        -- data-set-status promotion and no write-back to the STG table.
        DMT_HDL_UTIL_PKG.STAGE_HDL_MESSAGES(
            p_run_id        => p_run_id,
            p_request_id    => p_request_id,
            p_log_context   => C_CEMLI,
            x_message_count => l_msg_count);
        APPLY_HDL_ERRORS(p_run_id, p_request_id);

        -- Contract v1 base-tier positive proof (design section 5), Option A shape:
        -- the shared package fetches the parsed report rows (no dynamic SQL, no TFM
        -- reference there) and the APPLY is done here as STATIC SQL against the
        -- compile-time-known Salary TFM table. Extracted into its own private
        -- procedure (one BEGIN/END per procedure).
        APPLY_CONTRACT_V1_SALARIES(p_run_id, p_request_id);

        -- Whole-file HDL rejections last, only on rows still open (backlog #288).
        APPLY_FILE_ERRORS(p_run_id, p_request_id);

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
