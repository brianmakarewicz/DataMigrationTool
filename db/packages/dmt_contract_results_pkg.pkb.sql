-- PACKAGE BODY DMT_CONTRACT_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_CONTRACT_RESULTS_PKG"
AS
-- ============================================================
-- DMT_CONTRACT_RESULTS_PKG body
-- Contracts post-load reconciliation — Contract v1 (headers only).
--
-- Reuses the ONE shared Contract v1 fetch DMT_RECON_CONTRACT_PKG.FETCH_ROWS
-- (Option A, owner decision on PR #248), exactly as the Requisitions multi-tier
-- template (PR #364) does. A single fetch runs the Contracts Contract v1 report
-- (nine columns, keyset paginated) over BIP and returns the header tier's rows;
-- the apply is STATIC SQL, one pair of UPDATEs, joined on RECON_KEY = the report
-- RECORD_KEY.
--
--   Tier      OBJECT_TYPE literal    TFM table                    FUSION_ID column
--   headers   'Contracts'            DMT_PO_HEADERS_INT_TFM_TBL   FUSION_PO_HEADER_ID
--
-- (The Contract Purchase Agreement FBDI carries only the header record type, so
-- there is a single tier.)
--
-- Apply rule (shared Contract v1):
--   * BASE / SUCCESS / FUSION_ID NOT NULL -> LOADED, stamp FUSION_ID.
--   * FUSION_STATUS = ERROR with a real ERROR_MESSAGE (!= '#IMPORT_REPORT#')
--     -> FAILED, message appended as '[FUSION_ERROR] ' || message.
--   * Everything else is left GENERATED for the shared unaccounted sweep.
-- The UPDATE is guarded with TFM_STATUS NOT IN ('LOADED','FAILED').
--
-- Doc-type scoping: PurchaseOrders, BlanketPOs and Contracts share the header
-- TFM table. This reader touches only its OWN rows because it runs its OWN
-- Contract v1 report (with the Contracts ImportCPAJob load + import request ids),
-- whose BASE tier is filtered to TYPE_LOOKUP_CODE = 'CONTRACT' and whose
-- RECORD_KEYs are unique per physical document (RECON_KEY = SEGMENT1 = prefixed
-- DOCUMENT_NUM).
--
-- RECON_KEY on the header TFM row is stamped by DMT_PO_TRANSFORM_PKG to equal the
-- report RECORD_KEY (DOCUMENT_NUM). No STG echo, no parent/child cascade.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_CONTRACT_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'Contracts';

    -- --------------------------------------------------------
    -- APPLY_CONTRACT_V1_CONTRACTS (private)
    -- The Contract v1 apply for the single Contracts header tier, Option A shape.
    -- --------------------------------------------------------
    PROCEDURE APPLY_CONTRACT_V1_CONTRACTS (
        p_run_id        IN NUMBER,
        p_load_ess_id   IN NUMBER,
        p_import_ess_id IN NUMBER DEFAULT NULL
    ) IS
        C_PROC      CONSTANT VARCHAR2(40) := 'APPLY_CONTRACT_V1_CONTRACTS';
        l_gen_count NUMBER := 0;
        l_rows      DMT_RECON_CONTRACT_PKG.T_RECON_TBL;
        l_err_code  NUMBER;
        l_hdr_loaded NUMBER := 0;  l_hdr_failed NUMBER := 0;
    BEGIN
        -- Generated-row count (header tier only) drives the keyset page-count cap.
        SELECT COUNT(*)
        INTO   l_gen_count
        FROM   DMT_PO_HEADERS_INT_TFM_TBL
        WHERE  RUN_ID = p_run_id;

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
                C_PROC || ': Contract v1 fetch failed for Contracts '
                || '(detail in DMT_LOG_TBL).');
        END IF;

        IF l_rows.COUNT = 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ': Contracts recon report returned zero rows; '
                               || 'GENERATED rows left for the unaccounted sweep '
                               || '(never a silent success).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
        ELSE
            FOR i IN 1 .. l_rows.COUNT LOOP
                -- ===== TIER: HEADERS (OBJECT_TYPE = 'Contracts') =====
                IF l_rows(i).OBJECT_TYPE = 'Contracts' THEN
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
                END IF;
            END LOOP;
        END IF;

        -- NO COMMIT — orchestrator controls transaction boundaries.

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Report rows: ' || l_rows.COUNT
                           || ' | headers LOADED/FAILED: ' || l_hdr_loaded || '/' || l_hdr_failed
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
    END APPLY_CONTRACT_V1_CONTRACTS;

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

        APPLY_CONTRACT_V1_CONTRACTS(p_run_id, p_load_ess_id, p_import_ess_id);

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

END DMT_CONTRACT_RESULTS_PKG;
/
