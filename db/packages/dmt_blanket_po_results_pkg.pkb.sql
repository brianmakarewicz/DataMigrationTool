-- PACKAGE BODY DMT_BLANKET_PO_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_BLANKET_PO_RESULTS_PKG"
AS
-- ============================================================
-- DMT_BLANKET_PO_RESULTS_PKG body
-- BlanketPOs post-load reconciliation — Contract v1, MULTI-TIER.
--
-- Reuses the ONE shared Contract v1 fetch DMT_RECON_CONTRACT_PKG.FETCH_ROWS
-- (Option A, owner decision on PR #248), exactly as the Requisitions multi-tier
-- template (PR #364) does. A single fetch runs the BlanketPOs Contract v1 report
-- (nine columns, keyset paginated) over BIP and returns BOTH tiers' rows in one
-- collection; each row's OBJECT_TYPE says which tier. The apply is STATIC SQL,
-- one pair of UPDATEs per tier, joined on RECON_KEY = the report RECORD_KEY.
--
--   Tier      OBJECT_TYPE literal    TFM table                    FUSION_ID column
--   headers   'BlanketPOs'           DMT_PO_HEADERS_INT_TFM_TBL   FUSION_PO_HEADER_ID
--   lines     'BlanketPOs.Line'      DMT_PO_LINES_INT_TFM_TBL     FUSION_PO_LINE_ID
--
-- (The Blanket Purchase Agreement FBDI carries only header + line record types,
-- so there are no line-location or distribution tiers.)
--
-- Per tier the rule is the shared Contract v1 apply rule:
--   * BASE / SUCCESS / FUSION_ID NOT NULL -> LOADED, stamp FUSION_ID.
--   * FUSION_STATUS = ERROR with a real ERROR_MESSAGE (!= '#IMPORT_REPORT#')
--     -> FAILED, message appended as '[FUSION_ERROR] ' || message.
--   * Everything else is left GENERATED for the shared unaccounted sweep.
-- Every UPDATE is guarded with TFM_STATUS NOT IN ('LOADED','FAILED').
--
-- Doc-type scoping: PurchaseOrders, BlanketPOs and Contracts share these TFM
-- tables. This reader touches only its OWN rows because it runs its OWN Contract
-- v1 report (with the BlanketPOs ImportBPAJob load + import request ids), whose
-- BASE tier is filtered to TYPE_LOOKUP_CODE = 'BLANKET' and whose RECORD_KEYs are
-- unique per physical document (RECON_KEY = SEGMENT1 = prefixed DOCUMENT_NUM).
--
-- RECON_KEY on each tier's TFM row is stamped by DMT_PO_TRANSFORM_PKG to equal
-- that tier's report RECORD_KEY (headers = DOCUMENT_NUM; lines = DOCUMENT_NUM ||
-- ':LN:' || LINE_NUM). No STG echo, no parent/child cascade.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_BLANKET_PO_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'BlanketPOs';

    -- --------------------------------------------------------
    -- APPLY_CONTRACT_V1_BLANKET_POS (private)
    -- The Contract v1 apply for both BlanketPOs tiers, Option A shape.
    -- --------------------------------------------------------
    PROCEDURE APPLY_CONTRACT_V1_BLANKET_POS (
        p_run_id        IN NUMBER,
        p_load_ess_id   IN NUMBER,
        p_import_ess_id IN NUMBER DEFAULT NULL
    ) IS
        C_PROC      CONSTANT VARCHAR2(40) := 'APPLY_CONTRACT_V1_BLANKET_POS';
        l_gen_count NUMBER := 0;
        l_rows      DMT_RECON_CONTRACT_PKG.T_RECON_TBL;
        l_err_code  NUMBER;
        l_hdr_loaded  NUMBER := 0;  l_hdr_failed  NUMBER := 0;
        l_line_loaded NUMBER := 0;  l_line_failed NUMBER := 0;
    BEGIN
        -- Generated-row count across both tiers drives the keyset page-count cap.
        SELECT (SELECT COUNT(*) FROM DMT_PO_HEADERS_INT_TFM_TBL WHERE RUN_ID = p_run_id)
             + (SELECT COUNT(*) FROM DMT_PO_LINES_INT_TFM_TBL   WHERE RUN_ID = p_run_id)
        INTO   l_gen_count
        FROM   dual;

        DMT_RECON_CONTRACT_PKG.FETCH_ROWS(
            p_cemli_code    => C_CEMLI,
            p_run_id        => p_run_id,
            p_load_ess_id   => p_load_ess_id,
            p_import_ess_id => p_import_ess_id,
            p_row_cap       => l_gen_count,
            x_rows          => l_rows,
            x_error_code    => l_err_code);

        IF l_err_code <> DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20094,
                C_PROC || ': Contract v1 fetch failed for BlanketPOs '
                || '(detail in DMT_LOG_TBL).');
        END IF;

        IF l_rows.COUNT = 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ': BlanketPOs recon report returned zero rows; '
                               || 'GENERATED rows left for the unaccounted sweep '
                               || '(never a silent success).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
        ELSE
            FOR i IN 1 .. l_rows.COUNT LOOP
                -- ===== TIER: HEADERS (OBJECT_TYPE = 'BlanketPOs') =====
                IF l_rows(i).OBJECT_TYPE = 'BlanketPOs' THEN
                    IF l_rows(i).SOURCE_TYPE = 'BASE'
                       AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                       AND l_rows(i).FUSION_ID IS NOT NULL THEN
                        UPDATE DMT_PO_HEADERS_INT_TFM_TBL
                        SET    TFM_STATUS           = 'LOADED',
                               FUSION_PO_HEADER_ID  = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_hdr_loaded := l_hdr_loaded + SQL%ROWCOUNT;
                    ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                          AND l_rows(i).ERROR_MESSAGE IS NOT NULL
                          AND l_rows(i).ERROR_MESSAGE != '#IMPORT_REPORT#' THEN
                        UPDATE DMT_PO_HEADERS_INT_TFM_TBL
                        SET    TFM_STATUS           = 'FAILED',
                               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(
                                                        ERROR_TEXT,
                                                        '[FUSION_ERROR] ' || l_rows(i).ERROR_MESSAGE),
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_hdr_failed := l_hdr_failed + SQL%ROWCOUNT;
                    END IF;

                -- ===== TIER: LINES (OBJECT_TYPE = 'BlanketPOs.Line') =====
                ELSIF l_rows(i).OBJECT_TYPE = 'BlanketPOs.Line' THEN
                    IF l_rows(i).SOURCE_TYPE = 'BASE'
                       AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                       AND l_rows(i).FUSION_ID IS NOT NULL THEN
                        UPDATE DMT_PO_LINES_INT_TFM_TBL
                        SET    TFM_STATUS           = 'LOADED',
                               FUSION_PO_LINE_ID    = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_line_loaded := l_line_loaded + SQL%ROWCOUNT;
                    ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                          AND l_rows(i).ERROR_MESSAGE IS NOT NULL
                          AND l_rows(i).ERROR_MESSAGE != '#IMPORT_REPORT#' THEN
                        UPDATE DMT_PO_LINES_INT_TFM_TBL
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
                END IF;
            END LOOP;
        END IF;

        -- NO COMMIT — orchestrator controls transaction boundaries.

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Report rows: ' || l_rows.COUNT
                           || ' | headers LOADED/FAILED: ' || l_hdr_loaded || '/' || l_hdr_failed
                           || ' | lines LOADED/FAILED: '   || l_line_loaded || '/' || l_line_failed
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
    END APPLY_CONTRACT_V1_BLANKET_POS;

    -- --------------------------------------------------------
    -- RECONCILE_BATCH — entry point (signature unchanged).
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
            p_message        => C_PROC || ' start. load_ess_id: ' || p_load_ess_id
                                || ' | import_ess_id: ' || NVL(TO_CHAR(p_import_ess_id), 'NULL'),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        APPLY_CONTRACT_V1_BLANKET_POS(p_run_id, p_load_ess_id, p_import_ess_id);

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

END DMT_BLANKET_PO_RESULTS_PKG;
/
