-- PACKAGE BODY DMT_POZ_SUP_ADDR_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_POZ_SUP_ADDR_RESULTS_PKG" AS
-- ============================================================
-- NAME:    DMT_POZ_SUP_ADDR_RESULTS_PKG
-- PURPOSE: Post-load reconciliation for the SupplierAddresses object -- Contract v1.
--
-- Reuses the ONE shared Contract v1 fetch DMT_RECON_CONTRACT_PKG.FETCH_ROWS
-- (Option A, owner decision on PR #248). The fetch runs the nine-column
-- report DMT_SUP_ADDR_RECON_V2_DM (keyset paginated) over BIP; the apply below is STATIC
-- SQL against DMT_POZ_SUP_ADDR_TFM_TBL.
--
--   OBJECT_TYPE   'SupplierAddresses'
--   TFM table     DMT_POZ_SUP_ADDR_TFM_TBL
--   FUSION_ID     FUSION_PARTY_SITE_ID (the HZ_PARTY_SITES id)
--   RECORD_KEY    the business key VENDOR_NAME~PARTY_SITE_NAME as sent in the FBDI,
--                 matched to VENDOR_NAME || '~' || PARTY_SITE_NAME on the TFM row
--                 (DMT_BIP_REPORT_TBL.RECON_KEY_SQL). The report selects its
--                 rows by the load job id only; the key only matches a returned
--                 row back to its TFM row.
--
-- Apply rule (shared Contract v1):
--   * BASE / SUCCESS / FUSION_ID NOT NULL -> LOADED, stamp FUSION_PARTY_SITE_ID.
--   * FUSION_STATUS = ERROR with a real ERROR_MESSAGE (!= '#IMPORT_REPORT#')
--     -> FAILED, message appended as '[FUSION_ERROR] ' || message. A Fusion
--     error is always an error (design rule 2026-09-15): an "already exists"
--     rejection is never promoted to LOADED.
--   * Everything else is left GENERATED for the shared unaccounted sweep.
-- Every UPDATE is guarded TFM_STATUS NOT IN ('LOADED','FAILED'), so a proven
-- LOADED row is never flipped (report row order is not guaranteed). The apply
-- is scoped to the run, exactly as before: the object runs as ONE work item per
-- run, and the supplier transform does not stamp WORK_QUEUE_ID on its TFM rows
-- (it is NULL on every supplier row; tracked as its own backlog item), so a
-- work-item predicate here would match nothing.
-- REVISIONS:
--   1.0  2026-07-08  Split from the shared supplier results package (#43).
--   2.0  2026-10-09  Contract v1 nine-column report via FETCH_ROWS (#217).
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_POZ_SUP_ADDR_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'SupplierAddresses';

    -- --------------------------------------------------------
    -- CHECK_CEMLI (private): this package reconciles only its own object.
    -- --------------------------------------------------------
    PROCEDURE CHECK_CEMLI (p_proc IN VARCHAR2, p_cemli_code IN VARCHAR2) IS
    BEGIN
        IF p_cemli_code IS NULL OR p_cemli_code != C_CEMLI THEN
            RAISE_APPLICATION_ERROR(-20037,
                p_proc || ': Unknown CEMLI_CODE = ''' || p_cemli_code ||
                '''. ' || C_PKG || ' handles only ' || C_CEMLI || '.');
        END IF;
    END CHECK_CEMLI;

    -- --------------------------------------------------------
    -- APPLY_CONTRACT_V1 (private): fetch the nine-column report and apply it.
    -- --------------------------------------------------------
    PROCEDURE APPLY_CONTRACT_V1 (
        p_run_id        IN NUMBER,
        p_load_ess_id   IN NUMBER,
        p_import_ess_id IN NUMBER
    ) IS
        C_PROC      CONSTANT VARCHAR2(30) := 'APPLY_CONTRACT_V1';
        l_step      VARCHAR2(500);
        l_gen_count NUMBER := 0;
        l_rows      DMT_RECON_CONTRACT_PKG.T_RECON_TBL;
        l_err_code  NUMBER;
        l_loaded    NUMBER := 0;
        l_failed    NUMBER := 0;
    BEGIN
        l_step := 'counting this run''s rows (keyset page-count cap)';
        SELECT COUNT(*)
        INTO   l_gen_count
        FROM   DMT_POZ_SUP_ADDR_TFM_TBL
        WHERE  RUN_ID = p_run_id;

        l_step := 'fetching the Contract v1 report for ' || C_CEMLI;
        DMT_RECON_CONTRACT_PKG.FETCH_ROWS(
            p_cemli_code    => C_CEMLI,
            p_run_id        => p_run_id,
            p_load_ess_id   => p_load_ess_id,
            p_import_ess_id => p_import_ess_id,
            p_row_cap       => l_gen_count,
            x_rows          => l_rows,
            x_error_code    => l_err_code);

        IF l_err_code <> DMT_UTIL_PKG.C_SUCCESS THEN
            -- RECONCILE_BATCH's contract with the queue engine is exception
            -- based: a fetch failure fails the work item loudly, never a
            -- silent zero-row success (design section 5).
            RAISE_APPLICATION_ERROR(-20038,
                C_PROC || ': Contract v1 fetch failed for ' || C_CEMLI
                || ' (detail in DMT_LOG_TBL).');
        END IF;

        IF l_rows.COUNT = 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ': ' || C_CEMLI || ' recon report returned zero rows; '
                               || 'GENERATED rows left for the unaccounted sweep '
                               || '(never a silent success).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
        END IF;

        l_step := 'applying the report rows to DMT_POZ_SUP_ADDR_TFM_TBL';
        FOR i IN 1 .. l_rows.COUNT LOOP
            IF l_rows(i).OBJECT_TYPE = C_CEMLI
               AND l_rows(i).SOURCE_TYPE = 'BASE'
               AND l_rows(i).FUSION_STATUS = 'SUCCESS'
               AND l_rows(i).FUSION_ID IS NOT NULL THEN
                UPDATE DMT_POZ_SUP_ADDR_TFM_TBL
                SET    TFM_STATUS           = 'LOADED',
                       FUSION_PARTY_SITE_ID = l_rows(i).FUSION_ID,
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID = p_run_id
                AND    VENDOR_NAME || '~' || PARTY_SITE_NAME = l_rows(i).RECORD_KEY
                AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                l_loaded := l_loaded + SQL%ROWCOUNT;
            ELSIF l_rows(i).OBJECT_TYPE = C_CEMLI
                  AND l_rows(i).FUSION_STATUS = 'ERROR'
                  AND l_rows(i).ERROR_MESSAGE IS NOT NULL
                  AND l_rows(i).ERROR_MESSAGE != '#IMPORT_REPORT#' THEN
                UPDATE DMT_POZ_SUP_ADDR_TFM_TBL
                SET    TFM_STATUS           = 'FAILED',
                       ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(
                                                ERROR_TEXT,
                                                '[FUSION_ERROR] ' || l_rows(i).ERROR_MESSAGE),
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID = p_run_id
                AND    VENDOR_NAME || '~' || PARTY_SITE_NAME = l_rows(i).RECORD_KEY
                AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                l_failed := l_failed + SQL%ROWCOUNT;
            END IF;
        END LOOP;

        -- NO COMMIT: the orchestrator owns the transaction.
        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. CEMLI: ' || C_CEMLI
                           || ' | report rows: ' || l_rows.COUNT
                           || ' | LOADED: ' || l_loaded || ' | FAILED: ' || l_failed
                           || '. Unmatched rows left for the unaccounted sweep.',
            p_package   => C_PKG,
            p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ' failed while ' || l_step,
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE;
    END APPLY_CONTRACT_V1;

    PROCEDURE RECONCILE_BATCH (
        p_run_id        IN NUMBER,
        p_cemli_code    IN VARCHAR2,
        p_load_ess_id   IN NUMBER,
        p_import_ess_id IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RECONCILE_BATCH';
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' start. CEMLI: ' || p_cemli_code
                           || ' | Load ESS ID: ' || p_load_ess_id
                           || ' | Import ESS ID: ' || NVL(TO_CHAR(p_import_ess_id), 'NULL'),
            p_package   => C_PKG,
            p_procedure => C_PROC);

        CHECK_CEMLI(C_PROC, p_cemli_code);
        APPLY_CONTRACT_V1(p_run_id, p_load_ess_id, p_import_ess_id);

        -- Unresolved records intentionally left GENERATED (unaccounted).
        -- No fabricated FAILED: the accounting gate reports the object
        -- not-DONE and the funnel surfaces these as UNRECONCILED.
        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. CEMLI: ' || p_cemli_code,
            p_package   => C_PKG,
            p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ' failed. CEMLI: ' || p_cemli_code,
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE;
    END RECONCILE_BATCH;

    -- --------------------------------------------------------
    -- RESET_UNACCOUNTED (backlog #95): flips this run's UNACCOUNTED rows back
    -- to GENERATED and strips the trailing [UNACCOUNTED] tag from ERROR_TEXT
    -- (CLOB-safe REGEXP_REPLACE), preserving any prior real error. Scoped by
    -- run, and by work item when given. Static SQL; NO COMMIT.
    -- --------------------------------------------------------
    PROCEDURE RESET_UNACCOUNTED (
        p_run_id        IN NUMBER,
        p_cemli_code    IN VARCHAR2,
        p_load_ess_id   IN NUMBER   DEFAULT NULL,
        p_import_ess_id IN NUMBER   DEFAULT NULL,
        p_work_queue_id IN NUMBER   DEFAULT NULL
    ) IS
        C_PROC  CONSTANT VARCHAR2(30) := 'RESET_UNACCOUNTED';
        l_reset NUMBER := 0;
    BEGIN
        CHECK_CEMLI(C_PROC, p_cemli_code);

        UPDATE DMT_POZ_SUP_ADDR_TFM_TBL
        SET    TFM_STATUS = 'GENERATED',
               ERROR_TEXT = CASE
                              WHEN DBMS_LOB.GETLENGTH(
                                     REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')) > 0
                              THEN REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')
                              ELSE NULL
                            END,
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'UNACCOUNTED'
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id);
        l_reset := SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ': reset ' || l_reset || ' UNACCOUNTED ' || p_cemli_code ||
            ' row(s) to GENERATED for re-reconcile.',
            'INFO', C_PKG, C_PROC);
        -- NO COMMIT -- the caller (RERUN_RUN) owns the transaction.
    END RESET_UNACCOUNTED;

END DMT_POZ_SUP_ADDR_RESULTS_PKG;
/
