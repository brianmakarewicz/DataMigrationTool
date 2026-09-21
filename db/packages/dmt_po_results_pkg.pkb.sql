-- PACKAGE BODY DMT_PO_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_PO_RESULTS_PKG"
AS
-- ============================================================
-- DMT_PO_RESULTS_PKG body
-- PurchaseOrders post-load reconciliation — Contract v1, MULTI-TIER.
--
-- Reuses the ONE shared Contract v1 fetch DMT_RECON_CONTRACT_PKG.FETCH_ROWS
-- (Option A, owner decision on PR #248), exactly as the Requisitions multi-tier
-- template (PR #364) and the Workers template do. A single fetch runs the
-- PurchaseOrders Contract v1 report (nine columns, keyset paginated) over BIP
-- and returns ALL four tiers' rows in one collection; each row's OBJECT_TYPE
-- says which tier it belongs to. The apply is STATIC SQL, one pair of UPDATEs
-- per tier, joined on RECON_KEY = the report RECORD_KEY.
--
--   Tier          OBJECT_TYPE literal              TFM table                       FUSION_ID column
--   headers       'PurchaseOrders'                 DMT_PO_HEADERS_INT_TFM_TBL      FUSION_PO_HEADER_ID
--   lines         'PurchaseOrders.Line'            DMT_PO_LINES_INT_TFM_TBL        FUSION_PO_LINE_ID
--   line-locations'PurchaseOrders.LineLocation'    DMT_PO_LINE_LOCS_INT_TFM_TBL    FUSION_LINE_LOCATION_ID
--   distributions 'PurchaseOrders.Distribution'    DMT_PO_DISTS_INT_TFM_TBL        FUSION_DISTRIBUTION_ID
--
-- Per tier the rule is the shared Contract v1 apply rule:
--   * BASE / SUCCESS / FUSION_ID NOT NULL -> LOADED, stamp FUSION_ID.
--   * FUSION_STATUS = ERROR with a real ERROR_MESSAGE (!= '#IMPORT_REPORT#')
--     -> FAILED, message appended as '[FUSION_ERROR] ' || message (never composed).
--   * Everything else is left GENERATED for the shared unaccounted sweep;
--     INTERFACE/SUCCESS corroborates but is never sufficient for LOADED.
-- Every UPDATE is guarded with TFM_STATUS NOT IN ('LOADED','FAILED').
--
-- Doc-type scoping: PurchaseOrders, BlanketPOs and Contracts share these four
-- TFM tables. This reader touches only its OWN rows because it runs its OWN
-- Contract v1 report (with the PurchaseOrders ImportSPOJob load + import request
-- ids), which returns only Standard-PO RECORD_KEYs; RECON_KEY = SEGMENT1
-- (prefixed DOCUMENT_NUM) is unique per physical document, so a Blanket or
-- Contract row can never be matched here.
--
-- RECON_KEY on each tier's TFM row is stamped by DMT_PO_TRANSFORM_PKG to equal
-- that tier's report RECORD_KEY (headers = DOCUMENT_NUM; lines/locs/dists = the
-- parent DOCUMENT_NUM composed with LINE/SHIPMENT/DISTRIBUTION numbers). That
-- coupling is what makes the join hit.
--
-- No STG echo (removed 2026-07-13, design section 5: STG carries a forward-only
-- status; LOADED is a TFM-only status). No parent/child cascade: each tier has
-- its own BASE and INTERFACE rows in the report, so each tier accounts for itself.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_PO_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'PurchaseOrders';

    -- --------------------------------------------------------
    -- APPLY_CONTRACT_V1_PURCHASE_ORDERS (private)
    -- The Contract v1 apply for all four PurchaseOrders tiers, Option A shape.
    -- One shared FETCH_ROWS call returns every tier's rows; the apply is STATIC
    -- SQL, one pair of UPDATEs per tier, discriminated by OBJECT_TYPE and joined
    -- on RECON_KEY = RECORD_KEY.
    -- --------------------------------------------------------
    PROCEDURE APPLY_CONTRACT_V1_PURCHASE_ORDERS (
        p_run_id        IN NUMBER,
        p_load_ess_id   IN NUMBER,
        p_import_ess_id IN NUMBER DEFAULT NULL
    ) IS
        C_PROC      CONSTANT VARCHAR2(40) := 'APPLY_CONTRACT_V1_PURCHASE_ORDERS';
        l_gen_count NUMBER := 0;
        l_rows      DMT_RECON_CONTRACT_PKG.T_RECON_TBL;
        l_err_code  NUMBER;
        l_hdr_loaded  NUMBER := 0;  l_hdr_failed  NUMBER := 0;
        l_line_loaded NUMBER := 0;  l_line_failed NUMBER := 0;
        l_loc_loaded  NUMBER := 0;  l_loc_failed  NUMBER := 0;
        l_dist_loaded NUMBER := 0;  l_dist_failed NUMBER := 0;
    BEGIN
        -- Generated-row count across all four tiers drives the shared fetch's
        -- keyset page-count cap. Done statically here (not in the shared pkg).
        SELECT (SELECT COUNT(*) FROM DMT_PO_HEADERS_INT_TFM_TBL   WHERE RUN_ID = p_run_id)
             + (SELECT COUNT(*) FROM DMT_PO_LINES_INT_TFM_TBL     WHERE RUN_ID = p_run_id)
             + (SELECT COUNT(*) FROM DMT_PO_LINE_LOCS_INT_TFM_TBL WHERE RUN_ID = p_run_id)
             + (SELECT COUNT(*) FROM DMT_PO_DISTS_INT_TFM_TBL     WHERE RUN_ID = p_run_id)
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

        -- A transport / SOAP failure raises loudly (design section 5: never a
        -- silent retry, never a zero-row "success"); the fetch already logged detail.
        IF l_err_code <> DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20094,
                C_PROC || ': Contract v1 fetch failed for PurchaseOrders '
                || '(detail in DMT_LOG_TBL).');
        END IF;

        IF l_rows.COUNT = 0 THEN
            -- Zero report rows is never success (design section 5): leave the
            -- remaining GENERATED rows for the existing unaccounted sweep.
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ': PurchaseOrders recon report returned zero rows; '
                               || 'GENERATED rows left for the unaccounted sweep '
                               || '(never a silent success).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
        ELSE
            FOR i IN 1 .. l_rows.COUNT LOOP
                -- ===== TIER: HEADERS (OBJECT_TYPE = 'PurchaseOrders') =====
                IF l_rows(i).OBJECT_TYPE = 'PurchaseOrders' THEN
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

                -- ===== TIER: LINES (OBJECT_TYPE = 'PurchaseOrders.Line') =====
                ELSIF l_rows(i).OBJECT_TYPE = 'PurchaseOrders.Line' THEN
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

                -- ===== TIER: LINE-LOCATIONS (OBJECT_TYPE = 'PurchaseOrders.LineLocation') =====
                ELSIF l_rows(i).OBJECT_TYPE = 'PurchaseOrders.LineLocation' THEN
                    IF l_rows(i).SOURCE_TYPE = 'BASE'
                       AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                       AND l_rows(i).FUSION_ID IS NOT NULL THEN
                        UPDATE DMT_PO_LINE_LOCS_INT_TFM_TBL
                        SET    TFM_STATUS              = 'LOADED',
                               FUSION_LINE_LOCATION_ID = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE    = SYSDATE,
                               LAST_UPDATED_DATE       = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_loc_loaded := l_loc_loaded + SQL%ROWCOUNT;
                    ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                          AND l_rows(i).ERROR_MESSAGE IS NOT NULL
                          AND l_rows(i).ERROR_MESSAGE != '#IMPORT_REPORT#' THEN
                        UPDATE DMT_PO_LINE_LOCS_INT_TFM_TBL
                        SET    TFM_STATUS           = 'FAILED',
                               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(
                                                        ERROR_TEXT,
                                                        '[FUSION_ERROR] ' || l_rows(i).ERROR_MESSAGE),
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_loc_failed := l_loc_failed + SQL%ROWCOUNT;
                    END IF;

                -- ===== TIER: DISTRIBUTIONS (OBJECT_TYPE = 'PurchaseOrders.Distribution') =====
                ELSIF l_rows(i).OBJECT_TYPE = 'PurchaseOrders.Distribution' THEN
                    IF l_rows(i).SOURCE_TYPE = 'BASE'
                       AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                       AND l_rows(i).FUSION_ID IS NOT NULL THEN
                        UPDATE DMT_PO_DISTS_INT_TFM_TBL
                        SET    TFM_STATUS            = 'LOADED',
                               FUSION_DISTRIBUTION_ID = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE   = SYSDATE,
                               LAST_UPDATED_DATE      = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_dist_loaded := l_dist_loaded + SQL%ROWCOUNT;
                    ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                          AND l_rows(i).ERROR_MESSAGE IS NOT NULL
                          AND l_rows(i).ERROR_MESSAGE != '#IMPORT_REPORT#' THEN
                        UPDATE DMT_PO_DISTS_INT_TFM_TBL
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

        -- NO COMMIT — orchestrator controls transaction boundaries.

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Report rows: ' || l_rows.COUNT
                           || ' | headers LOADED/FAILED: ' || l_hdr_loaded || '/' || l_hdr_failed
                           || ' | lines LOADED/FAILED: '   || l_line_loaded || '/' || l_line_failed
                           || ' | locs LOADED/FAILED: '    || l_loc_loaded || '/' || l_loc_failed
                           || ' | dists LOADED/FAILED: '   || l_dist_loaded || '/' || l_dist_failed
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
    END APPLY_CONTRACT_V1_PURCHASE_ORDERS;

    -- --------------------------------------------------------
    -- RECONCILE_BATCH — entry point (signature unchanged). Calls the shared
    -- Contract v1 apply. p_load_ess_id is the Contract v1 P_LOAD_REQUEST_ID;
    -- p_import_ess_id is P_IMPORT_ESS_ID (the Import Orders ESS id that stamped
    -- the BASE PO rows). The report's run-scoped selectors pick up the whole run.
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

        APPLY_CONTRACT_V1_PURCHASE_ORDERS(p_run_id, p_load_ess_id, p_import_ess_id);

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

END DMT_PO_RESULTS_PKG;
/
