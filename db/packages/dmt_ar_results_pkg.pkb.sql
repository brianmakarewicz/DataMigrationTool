-- PACKAGE BODY DMT_AR_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_AR_RESULTS_PKG"
AS
-- ============================================================
-- DMT_AR_RESULTS_PKG body
-- ARInvoices post-load reconciliation — Contract v1, MULTI-TIER template.
--
-- Reuses the ONE shared Contract v1 fetch, DMT_RECON_CONTRACT_PKG.FETCH_ROWS,
-- exactly as the Workers and Requisitions templates do. A single FETCH_ROWS call
-- runs the ARInvoices Contract v1 report (nine columns, keyset paginated) over
-- BIP and returns BOTH tiers' rows in one collection; each row's OBJECT_TYPE says
-- which tier it belongs to.
--
-- The APPLY is STATIC SQL against the compile-time-known TFM tables (Option A,
-- owner decision on PR #248): one UPDATE pair PER TIER, filtering the report rows
-- by OBJECT_TYPE and joining that tier's TFM table on RECON_KEY = RECORD_KEY.
--
--   Tier           OBJECT_TYPE literal          TFM table               FUSION_ID column
--   ----------     --------------------------   ---------------------   ------------------------------
--   lines          'ARInvoices'                 DMT_RA_LINES_TFM_TBL     FUSION_CUSTOMER_TRX_ID
--   distributions  'ARInvoices.Distribution'    DMT_RA_DISTS_TFM_TBL     FUSION_CUST_TRX_LINE_GL_DIST_ID
--
-- Per tier the rule is the shared Contract v1 apply rule:
--   * BASE / SUCCESS / FUSION_ID NOT NULL -> LOADED, stamp FUSION_ID.
--   * FUSION_STATUS = ERROR with a real ERROR_MESSAGE -> FAILED, message
--     appended as '[FUSION_ERROR] ' || message (never composed). A '#IMPORT_REPORT#'
--     marker row is NOT a real message: it is left for the import-report harvest,
--     so the marker rows are skipped here.
--   * Everything else is left GENERATED for the shared unaccounted sweep;
--     INTERFACE/SUCCESS corroborates but is never sufficient for LOADED.
--
-- The RECON_KEY on each tier's TFM row is stamped by DMT_AR_TRANSFORM_PKG to
-- equal that tier's report RECORD_KEY. BOTH tiers stamp
-- RECON_KEY = INTERFACE_LINE_ATTRIBUTE1 (the prefixed TRX_NUMBER): AutoInvoice
-- persists INTERFACE_LINE_ATTRIBUTE1 onto the base line, and the base distribution
-- (which carries no interface key of its own) is confirmed TRANSITIVELY through
-- its parent line — the data model emits the parent line's stamped key as the
-- distribution RECORD_KEY. That coupling is what makes the join hit.
--
-- After the two tiers settle, outcomes are echoed back to both STG tables. No
-- composed parent/child roll-up is needed: each tier has its own BASE and
-- INTERFACE rows in the report, so each tier accounts for itself directly (a
-- distribution transitively via its parent line's key).
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_AR_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'ARInvoices';

    -- Import-report marker: an ERROR row carrying this exact ERROR_MESSAGE is a
    -- placeholder for the separate import-report harvest, not a real Fusion error.
    -- Guard against it so a marker never produces a FAILED with fake text.
    C_IMPORT_MARKER CONSTANT VARCHAR2(30) := '#IMPORT_REPORT#';

    -- --------------------------------------------------------
    -- APPLY_CONTRACT_V1_ARINVOICES (private)
    -- The Contract v1 apply for both ARInvoices tiers, Option A shape. One shared
    -- FETCH_ROWS call returns every tier's rows; the apply is STATIC SQL, one pair
    -- of UPDATEs per tier, discriminated by OBJECT_TYPE and joined on
    -- RECON_KEY = RECORD_KEY.
    -- --------------------------------------------------------
    PROCEDURE APPLY_CONTRACT_V1_ARINVOICES (
        p_run_id     IN NUMBER,
        p_request_id IN VARCHAR2
    ) IS
        C_PROC      CONSTANT VARCHAR2(40) := 'APPLY_CONTRACT_V1_ARINVOICES';
        l_gen_count NUMBER := 0;
        l_rows      DMT_RECON_CONTRACT_PKG.T_RECON_TBL;
        l_err_code  NUMBER;
        l_line_loaded NUMBER := 0;  l_line_failed NUMBER := 0;
        l_dist_loaded NUMBER := 0;  l_dist_failed NUMBER := 0;
    BEGIN
        -- Generated-row count across both tiers drives the shared fetch's keyset
        -- page-count cap. Done statically here (not in the shared pkg).
        SELECT (SELECT COUNT(*) FROM DMT_RA_LINES_TFM_TBL WHERE RUN_ID = p_run_id)
             + (SELECT COUNT(*) FROM DMT_RA_DISTS_TFM_TBL WHERE RUN_ID = p_run_id)
        INTO   l_gen_count
        FROM   dual;

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
                C_PROC || ': Contract v1 fetch failed for ARInvoices '
                || '(detail in DMT_LOG_TBL).');
        END IF;

        IF l_rows.COUNT = 0 THEN
            -- Zero report rows is never success (design section 5): leave the
            -- remaining GENERATED rows for the existing unaccounted sweep.
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ': ARInvoices recon report returned zero rows; '
                               || 'GENERATED rows left for the unaccounted sweep '
                               || '(never a silent success).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
        ELSE
            FOR i IN 1 .. l_rows.COUNT LOOP
                -- ===== TIER: LINES (OBJECT_TYPE = 'ARInvoices') =====
                IF l_rows(i).OBJECT_TYPE = 'ARInvoices' THEN
                    IF l_rows(i).SOURCE_TYPE = 'BASE'
                       AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                       AND l_rows(i).FUSION_ID IS NOT NULL THEN
                        UPDATE DMT_RA_LINES_TFM_TBL
                        SET    TFM_STATUS             = 'LOADED',
                               FUSION_CUSTOMER_TRX_ID = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE   = SYSDATE,
                               LAST_UPDATED_DATE      = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_line_loaded := l_line_loaded + SQL%ROWCOUNT;
                    ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                          AND l_rows(i).ERROR_MESSAGE IS NOT NULL
                          AND l_rows(i).ERROR_MESSAGE != C_IMPORT_MARKER THEN
                        UPDATE DMT_RA_LINES_TFM_TBL
                        SET    TFM_STATUS           = 'FAILED',
                               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(
                                                        ERROR_TEXT,
                                                        '[FUSION_ERROR] ' || l_rows(i).ERROR_MESSAGE),
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_line_failed := l_line_failed + SQL%ROWCOUNT;
                    END IF;

                -- ===== TIER: DISTRIBUTIONS (OBJECT_TYPE = 'ARInvoices.Distribution') =====
                ELSIF l_rows(i).OBJECT_TYPE = 'ARInvoices.Distribution' THEN
                    IF l_rows(i).SOURCE_TYPE = 'BASE'
                       AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                       AND l_rows(i).FUSION_ID IS NOT NULL THEN
                        UPDATE DMT_RA_DISTS_TFM_TBL
                        SET    TFM_STATUS                     = 'LOADED',
                               FUSION_CUST_TRX_LINE_GL_DIST_ID = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE           = SYSDATE,
                               LAST_UPDATED_DATE              = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_dist_loaded := l_dist_loaded + SQL%ROWCOUNT;
                    ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                          AND l_rows(i).ERROR_MESSAGE IS NOT NULL
                          AND l_rows(i).ERROR_MESSAGE != C_IMPORT_MARKER THEN
                        UPDATE DMT_RA_DISTS_TFM_TBL
                        SET    TFM_STATUS           = 'FAILED',
                               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(
                                                        ERROR_TEXT,
                                                        '[FUSION_ERROR] ' || l_rows(i).ERROR_MESSAGE),
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_dist_failed := l_dist_failed + SQL%ROWCOUNT;
                    END IF;
                END IF;
            END LOOP;
        END IF;

        -- ============================================================
        -- Echo tier outcomes back to the two STG tables.
        -- ============================================================
        -- Lines
        UPDATE DMT_RA_LINES_STG_TBL stg
        SET    stg.STG_STATUS = 'LOADED', stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_RA_LINES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');
        UPDATE DMT_RA_LINES_STG_TBL stg
        SET    stg.STG_STATUS = 'FAILED',
               stg.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_RA_LINES_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_RA_LINES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');

        -- Distributions
        UPDATE DMT_RA_DISTS_STG_TBL stg
        SET    stg.STG_STATUS = 'LOADED', stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_RA_DISTS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');
        UPDATE DMT_RA_DISTS_STG_TBL stg
        SET    stg.STG_STATUS = 'FAILED',
               stg.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_RA_DISTS_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_RA_DISTS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');

        -- NO COMMIT — orchestrator controls transaction boundaries.

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Report rows: ' || l_rows.COUNT
                           || ' | lines LOADED/FAILED: ' || l_line_loaded || '/' || l_line_failed
                           || ' | dists LOADED/FAILED: '  || l_dist_loaded || '/' || l_dist_failed
                           || '. Unmatched rows left for the unaccounted sweep.',
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
    END APPLY_CONTRACT_V1_ARINVOICES;

    -- --------------------------------------------------------
    -- RECONCILE_BATCH — entry point (signature unchanged). Calls the shared
    -- Contract v1 apply. The ARInvoices load ESS id is the Contract v1
    -- P_LOAD_REQUEST_ID; the report's run-scoped selectors pick up the whole run
    -- regardless of how many batches it submitted (AR is grouped by BU+BatchSource).
    -- --------------------------------------------------------
    PROCEDURE RECONCILE_BATCH (
        p_run_id  IN NUMBER,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RECONCILE_BATCH';
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' start. load_ess_id: ' || p_load_ess_id,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        APPLY_CONTRACT_V1_ARINVOICES(p_run_id, TO_CHAR(p_load_ess_id));

        -- Unresolved records are intentionally left GENERATED (unaccounted).
        -- No fabricated FAILED: the accounting gate reports the object not-DONE
        -- and the funnel surfaces these as UNRECONCILED.

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' complete.',
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

END DMT_AR_RESULTS_PKG;
/
