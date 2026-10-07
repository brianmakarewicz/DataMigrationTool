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
-- status; LOADED is a TFM-only status). Each tier has its own BASE and INTERFACE
-- rows in the report, so each tier accounts for itself. Then
-- PROPAGATE_DOCUMENT_ERRORS quotes each rejected row's real Fusion error onto the
-- other rows of the same purchase order, which Import Orders rejects with it but
-- writes no error for (design section 5, whole-document rejection).
--
-- REVISIONS:
--   2026-10-07  BM  Cross-grain propagation (PROPAGATE_DOCUMENT_ERRORS): the
--                   purchase order (INTERFACE_HEADER_KEY) is the document.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_PO_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'PurchaseOrders';

    -- This object's rows in the four shared PO TFM tables (the catalog ROW_FILTER
    -- for PurchaseOrders): headers whose STYLE_DISPLAY_NAME is the Standard-PO style.
    C_STYLE CONSTANT VARCHAR2(30) := 'Purchase Order';

    -- Cross-grain propagation (PROPAGATE_DOCUMENT_ERRORS).
    -- Working set: "the purchase order DOC_KEY carries the source row SOURCE_SEQ
    -- (a header, line, line location or distribution with its own real Fusion
    -- error), so every other row of that purchase order must carry QUOTED_ERROR".
    TYPE T_DOC_PAIR IS RECORD (
        DOC_KEY      DMT_PO_HEADERS_INT_TFM_TBL.INTERFACE_HEADER_KEY%TYPE,  -- the purchase order
        SOURCE_KIND  VARCHAR2(4),      -- 'HDR' | 'LINE' | 'LLOC' | 'DIST'
        SOURCE_SEQ   NUMBER,           -- TFM_SEQUENCE_ID in the source's own table
        QUOTED_ERROR VARCHAR2(4000)    -- DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR(...)
    );
    TYPE T_DOC_PAIR_TBL IS TABLE OF T_DOC_PAIR;

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
        l_rc        NUMBER := 0;    -- backlog #65: rows matched by the current tier
        l_dff_seq   NUMBER;          -- backlog #65 tier 2: TFM_SEQUENCE_ID from DFF_KEY
        l_tier      VARCHAR2(10);    -- backlog #65: which tier matched (audit log)
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
                        -- Backlog #65 three-tier match. Tier 1 is the stamped Slot A
                        -- reference (RECON_KEY = RECORD_KEY, exactly as before). Only
                        -- if tier 1 matches NO TFM row do we fall through: tier 2 (the
                        -- Slot C DFF stamp: TFM_SEQUENCE_ID = trailing segment of
                        -- DFF_KEY) and then tier 3 (the business key: RECON_KEY =
                        -- BUSINESS_KEY -- the per-record SOURCE_REF equals RECON_KEY, so
                        -- tier 3 is the same key and safely degenerate). Every tier-1
                        -- hit short-circuits, so loaded outcomes are identical to before.
                        l_rc := 0; l_tier := NULL;
                        UPDATE DMT_PO_HEADERS_INT_TFM_TBL
                        SET    TFM_STATUS           = 'LOADED',
                               FUSION_PO_HEADER_ID  = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_rc := SQL%ROWCOUNT;
                        l_tier := CASE WHEN l_rc > 0 THEN 'TIER1' END;

                        IF l_rc = 0 AND l_rows(i).DFF_KEY IS NOT NULL THEN
                            l_dff_seq := TO_NUMBER(
                                REGEXP_SUBSTR(l_rows(i).DFF_KEY, '[0-9]+$') DEFAULT NULL ON CONVERSION ERROR);
                            IF l_dff_seq IS NOT NULL THEN
                                UPDATE DMT_PO_HEADERS_INT_TFM_TBL
                                SET    TFM_STATUS           = 'LOADED',
                                       FUSION_PO_HEADER_ID  = l_rows(i).FUSION_ID,
                                       RESULTS_UPDATED_DATE = SYSDATE,
                                       LAST_UPDATED_DATE    = SYSDATE
                                WHERE  RUN_ID    = p_run_id
                                AND    TFM_SEQUENCE_ID = l_dff_seq
                                AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                                l_rc := SQL%ROWCOUNT;
                                IF l_rc > 0 THEN l_tier := 'TIER2'; END IF;
                            END IF;
                        END IF;

                        IF l_rc = 0 AND l_rows(i).BUSINESS_KEY IS NOT NULL THEN
                            UPDATE DMT_PO_HEADERS_INT_TFM_TBL
                            SET    TFM_STATUS           = 'LOADED',
                                   FUSION_PO_HEADER_ID  = l_rows(i).FUSION_ID,
                                   RESULTS_UPDATED_DATE = SYSDATE,
                                   LAST_UPDATED_DATE    = SYSDATE
                            WHERE  RUN_ID    = p_run_id
                            AND    RECON_KEY = l_rows(i).BUSINESS_KEY
                            AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                            l_rc := SQL%ROWCOUNT;
                            IF l_rc > 0 THEN l_tier := 'TIER3'; END IF;
                        END IF;

                        l_hdr_loaded := l_hdr_loaded + l_rc;
                        IF l_tier IN ('TIER2','TIER3') THEN
                            DMT_UTIL_PKG.LOG(p_run_id,
                                C_PROC || ': matched a LOADED PO header via ' || l_tier ||
                                ' fallback (tier 1 stamped ref did not resolve). FUSION_ID '
                                || l_rows(i).FUSION_ID || '.', 'INFO', C_PKG, C_PROC);
                        END IF;
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
                        -- Backlog #65 three-tier match. Tier 1 is the stamped Slot A reference
                        -- (RECON_KEY = RECORD_KEY, exactly as before). Only if tier 1 matches NO
                        -- TFM row do we fall through: tier 2 (the Slot C DFF stamp: TFM_SEQUENCE_ID
                        -- = trailing segment of DFF_KEY) and then tier 3 (the business key:
                        -- RECON_KEY = BUSINESS_KEY -- the per-record SOURCE_REF equals RECON_KEY, so
                        -- tier 3 is the same key and safely degenerate). Every tier-1 hit short-
                        -- circuits, so loaded outcomes are identical to before.
                        l_rc := 0; l_tier := NULL;
                        UPDATE DMT_PO_LINES_INT_TFM_TBL
                        SET    TFM_STATUS           = 'LOADED',
                               FUSION_PO_LINE_ID    = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_rc := SQL%ROWCOUNT;
                        l_tier := CASE WHEN l_rc > 0 THEN 'TIER1' END;

                        IF l_rc = 0 AND l_rows(i).DFF_KEY IS NOT NULL THEN
                            l_dff_seq := TO_NUMBER(
                                REGEXP_SUBSTR(l_rows(i).DFF_KEY, '[0-9]+$') DEFAULT NULL ON CONVERSION ERROR);
                            IF l_dff_seq IS NOT NULL THEN
                                UPDATE DMT_PO_LINES_INT_TFM_TBL
                                SET    TFM_STATUS           = 'LOADED',
                                       FUSION_PO_LINE_ID    = l_rows(i).FUSION_ID,
                                       RESULTS_UPDATED_DATE = SYSDATE,
                                       LAST_UPDATED_DATE    = SYSDATE
                                WHERE  RUN_ID    = p_run_id
                                AND    TFM_SEQUENCE_ID = l_dff_seq
                                AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                                l_rc := SQL%ROWCOUNT;
                                IF l_rc > 0 THEN l_tier := 'TIER2'; END IF;
                            END IF;
                        END IF;

                        IF l_rc = 0 AND l_rows(i).BUSINESS_KEY IS NOT NULL THEN
                            UPDATE DMT_PO_LINES_INT_TFM_TBL
                            SET    TFM_STATUS           = 'LOADED',
                                   FUSION_PO_LINE_ID    = l_rows(i).FUSION_ID,
                                   RESULTS_UPDATED_DATE = SYSDATE,
                                   LAST_UPDATED_DATE    = SYSDATE
                            WHERE  RUN_ID    = p_run_id
                            AND    RECON_KEY = l_rows(i).BUSINESS_KEY
                            AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                            l_rc := SQL%ROWCOUNT;
                            IF l_rc > 0 THEN l_tier := 'TIER3'; END IF;
                        END IF;

                        l_line_loaded := l_line_loaded + l_rc;
                        IF l_tier IN ('TIER2','TIER3') THEN
                            DMT_UTIL_PKG.LOG(p_run_id,
                                C_PROC || ': matched a LOADED PO line via ' || l_tier ||
                                ' fallback (tier 1 stamped ref did not resolve). FUSION_ID '
                                || l_rows(i).FUSION_ID || '.', 'INFO', C_PKG, C_PROC);
                        END IF;
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
                        -- Backlog #65 three-tier match. Tier 1 is the stamped Slot A reference
                        -- (RECON_KEY = RECORD_KEY, exactly as before). Only if tier 1 matches NO
                        -- TFM row do we fall through: tier 2 (the Slot C DFF stamp: TFM_SEQUENCE_ID
                        -- = trailing segment of DFF_KEY) and then tier 3 (the business key:
                        -- RECON_KEY = BUSINESS_KEY -- the per-record SOURCE_REF equals RECON_KEY, so
                        -- tier 3 is the same key and safely degenerate). Every tier-1 hit short-
                        -- circuits, so loaded outcomes are identical to before.
                        l_rc := 0; l_tier := NULL;
                        UPDATE DMT_PO_LINE_LOCS_INT_TFM_TBL
                        SET    TFM_STATUS           = 'LOADED',
                               FUSION_LINE_LOCATION_ID = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_rc := SQL%ROWCOUNT;
                        l_tier := CASE WHEN l_rc > 0 THEN 'TIER1' END;

                        IF l_rc = 0 AND l_rows(i).DFF_KEY IS NOT NULL THEN
                            l_dff_seq := TO_NUMBER(
                                REGEXP_SUBSTR(l_rows(i).DFF_KEY, '[0-9]+$') DEFAULT NULL ON CONVERSION ERROR);
                            IF l_dff_seq IS NOT NULL THEN
                                UPDATE DMT_PO_LINE_LOCS_INT_TFM_TBL
                                SET    TFM_STATUS           = 'LOADED',
                                       FUSION_LINE_LOCATION_ID = l_rows(i).FUSION_ID,
                                       RESULTS_UPDATED_DATE = SYSDATE,
                                       LAST_UPDATED_DATE    = SYSDATE
                                WHERE  RUN_ID    = p_run_id
                                AND    TFM_SEQUENCE_ID = l_dff_seq
                                AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                                l_rc := SQL%ROWCOUNT;
                                IF l_rc > 0 THEN l_tier := 'TIER2'; END IF;
                            END IF;
                        END IF;

                        IF l_rc = 0 AND l_rows(i).BUSINESS_KEY IS NOT NULL THEN
                            UPDATE DMT_PO_LINE_LOCS_INT_TFM_TBL
                            SET    TFM_STATUS           = 'LOADED',
                                   FUSION_LINE_LOCATION_ID = l_rows(i).FUSION_ID,
                                   RESULTS_UPDATED_DATE = SYSDATE,
                                   LAST_UPDATED_DATE    = SYSDATE
                            WHERE  RUN_ID    = p_run_id
                            AND    RECON_KEY = l_rows(i).BUSINESS_KEY
                            AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                            l_rc := SQL%ROWCOUNT;
                            IF l_rc > 0 THEN l_tier := 'TIER3'; END IF;
                        END IF;

                        l_loc_loaded := l_loc_loaded + l_rc;
                        IF l_tier IN ('TIER2','TIER3') THEN
                            DMT_UTIL_PKG.LOG(p_run_id,
                                C_PROC || ': matched a LOADED PO line-location via ' || l_tier ||
                                ' fallback (tier 1 stamped ref did not resolve). FUSION_ID '
                                || l_rows(i).FUSION_ID || '.', 'INFO', C_PKG, C_PROC);
                        END IF;
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
                        -- Backlog #65 three-tier match. Tier 1 is the stamped Slot A reference
                        -- (RECON_KEY = RECORD_KEY, exactly as before). Only if tier 1 matches NO
                        -- TFM row do we fall through: tier 2 (the Slot C DFF stamp: TFM_SEQUENCE_ID
                        -- = trailing segment of DFF_KEY) and then tier 3 (the business key:
                        -- RECON_KEY = BUSINESS_KEY -- the per-record SOURCE_REF equals RECON_KEY, so
                        -- tier 3 is the same key and safely degenerate). Every tier-1 hit short-
                        -- circuits, so loaded outcomes are identical to before.
                        l_rc := 0; l_tier := NULL;
                        UPDATE DMT_PO_DISTS_INT_TFM_TBL
                        SET    TFM_STATUS           = 'LOADED',
                               FUSION_DISTRIBUTION_ID = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_rc := SQL%ROWCOUNT;
                        l_tier := CASE WHEN l_rc > 0 THEN 'TIER1' END;

                        IF l_rc = 0 AND l_rows(i).DFF_KEY IS NOT NULL THEN
                            l_dff_seq := TO_NUMBER(
                                REGEXP_SUBSTR(l_rows(i).DFF_KEY, '[0-9]+$') DEFAULT NULL ON CONVERSION ERROR);
                            IF l_dff_seq IS NOT NULL THEN
                                UPDATE DMT_PO_DISTS_INT_TFM_TBL
                                SET    TFM_STATUS           = 'LOADED',
                                       FUSION_DISTRIBUTION_ID = l_rows(i).FUSION_ID,
                                       RESULTS_UPDATED_DATE = SYSDATE,
                                       LAST_UPDATED_DATE    = SYSDATE
                                WHERE  RUN_ID    = p_run_id
                                AND    TFM_SEQUENCE_ID = l_dff_seq
                                AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                                l_rc := SQL%ROWCOUNT;
                                IF l_rc > 0 THEN l_tier := 'TIER2'; END IF;
                            END IF;
                        END IF;

                        IF l_rc = 0 AND l_rows(i).BUSINESS_KEY IS NOT NULL THEN
                            UPDATE DMT_PO_DISTS_INT_TFM_TBL
                            SET    TFM_STATUS           = 'LOADED',
                                   FUSION_DISTRIBUTION_ID = l_rows(i).FUSION_ID,
                                   RESULTS_UPDATED_DATE = SYSDATE,
                                   LAST_UPDATED_DATE    = SYSDATE
                            WHERE  RUN_ID    = p_run_id
                            AND    RECON_KEY = l_rows(i).BUSINESS_KEY
                            AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                            l_rc := SQL%ROWCOUNT;
                            IF l_rc > 0 THEN l_tier := 'TIER3'; END IF;
                        END IF;

                        l_dist_loaded := l_dist_loaded + l_rc;
                        IF l_tier IN ('TIER2','TIER3') THEN
                            DMT_UTIL_PKG.LOG(p_run_id,
                                C_PROC || ': matched a LOADED PO distribution via ' || l_tier ||
                                ' fallback (tier 1 stamped ref did not resolve). FUSION_ID '
                                || l_rows(i).FUSION_ID || '.', 'INFO', C_PKG, C_PROC);
                        END IF;
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
    -- PROPAGATE_DOCUMENT_ERRORS (private)
    -- Design section 5, "Whole-document rejection carries the real error to every
    -- grain" (decided 2026-10-07). Import Orders is all-or-nothing per purchase
    -- order: when the header, a line, a line location (schedule) or a distribution
    -- has an error, Fusion sets EVERY interface row of that PO to REJECTED but
    -- writes PO_INTERFACE_ERRORS only for the row that failed (run 238: the
    -- RT-PO-BAD1 line, location and distribution; live, STANDARD headers REJECTED
    -- with no error of their own where a line carried it;
    -- docs/findings/run238_Reqs_POs_unaccounted.md).
    --
    -- The document is the purchase order as Fusion builds it: one header
    -- interface row (INTERFACE_HEADER_KEY), the lines carrying that key, each
    -- line's locations (INTERFACE_LINE_KEY) and each location's distributions
    -- (INTERFACE_LINE_LOCATION_KEY). Import Orders never merges two header rows,
    -- so two DMT purchase orders are never one Fusion document. Keys are
    -- run-prefixed, so the key is RUN_ID + INTERFACE_HEADER_KEY. Only this
    -- object's rows are read or written: headers of the Standard-PO style
    -- (C_STYLE, the catalog ROW_FILTER) and their children, so a Blanket or
    -- Contract document in the same shared tables is never touched. Every row is
    -- scoped to the work item the way the shared sweep scopes it.
    --
    -- Sources: rows of this run, work item and style with TFM_STATUS = 'FAILED'
    --   carrying their OWN real Fusion error -- ERROR_TEXT contains '[FUSION_ERROR]'
    --   and does NOT contain C_DOC_ERROR_MARKER (quotes never chain). A child's
    --   purchase order comes through its parents.
    -- Targets: every OTHER header / line / location / distribution of the same
    --   purchase order that Fusion received (FBDI_CSV_ID stamped at generation, not
    --   STAGED) and that is not LOADED (LOADED rows are never touched), and that
    --   does not already carry the exact quote. The quote is appended
    --   (APPEND_ERROR, never overwrite) and the row set FAILED. A purchase order
    --   with no source error is untouched -- its rows fall to the shared
    --   UNACCOUNTED sweep.
    -- Idempotent: the "already carries the exact quote" guard means a second
    --   reconcile pass adds nothing.
    -- One collection of (purchase order, source, quote) pairs is built by ONE
    -- static SELECT, then ONE static bulk UPDATE (FORALL) per target table: a
    -- MERGE cannot read a PL/SQL record collection through TABLE() (ORA-00902, AR
    -- run 248). NO dynamic SQL; NO COMMIT (caller owns the txn).
    -- --------------------------------------------------------
    PROCEDURE PROPAGATE_DOCUMENT_ERRORS (
        p_run_id        IN NUMBER,
        p_work_queue_id IN NUMBER
    ) IS
        C_PROC   CONSTANT VARCHAR2(30) := 'PROPAGATE_DOCUMENT_ERRORS';
        C_TAG    CONSTANT VARCHAR2(20) := '[FUSION_ERROR]';
        l_marker VARCHAR2(30) := DMT_UTIL_PKG.C_DOC_ERROR_MARKER;
        l_pairs  T_DOC_PAIR_TBL;
        l_hdrs   NUMBER := 0;
        l_lines  NUMBER := 0;
        l_locs   NUMBER := 0;
        l_dists  NUMBER := 0;
        l_step   VARCHAR2(200);
    BEGIN
        l_step := 'collecting same-purchase-order (source, quote) pairs for run ' || p_run_id;
        WITH po_hdrs AS (
            SELECT h.*
            FROM   DMT_PO_HEADERS_INT_TFM_TBL h
            WHERE  h.RUN_ID = p_run_id
            AND    h.STYLE_DISPLAY_NAME = C_STYLE
            -- Work-item scope, as the shared sweep scopes it: rows stamped with
            -- another work item are excluded; unstamped rows are run-scoped.
            AND    (p_work_queue_id IS NULL OR h.WORK_QUEUE_ID IS NULL
                    OR h.WORK_QUEUE_ID = p_work_queue_id)
        ),
        po_lines AS (
            SELECT l.*, h.INTERFACE_HEADER_KEY AS DOC_KEY
            FROM   DMT_PO_LINES_INT_TFM_TBL l
            JOIN   po_hdrs h ON h.INTERFACE_HEADER_KEY = l.INTERFACE_HEADER_KEY
            WHERE  l.RUN_ID = p_run_id
            AND    (p_work_queue_id IS NULL OR l.WORK_QUEUE_ID IS NULL
                    OR l.WORK_QUEUE_ID = p_work_queue_id)
        ),
        po_locs AS (
            SELECT ll.*, l.DOC_KEY
            FROM   DMT_PO_LINE_LOCS_INT_TFM_TBL ll
            JOIN   po_lines l ON l.INTERFACE_LINE_KEY = ll.INTERFACE_LINE_KEY
            WHERE  ll.RUN_ID = p_run_id
            AND    (p_work_queue_id IS NULL OR ll.WORK_QUEUE_ID IS NULL
                    OR ll.WORK_QUEUE_ID = p_work_queue_id)
        ),
        po_dists AS (
            SELECT d.*, ll.DOC_KEY
            FROM   DMT_PO_DISTS_INT_TFM_TBL d
            JOIN   po_locs ll ON ll.INTERFACE_LINE_LOCATION_KEY = d.INTERFACE_LINE_LOCATION_KEY
            WHERE  d.RUN_ID = p_run_id
            AND    (p_work_queue_id IS NULL OR d.WORK_QUEUE_ID IS NULL
                    OR d.WORK_QUEUE_ID = p_work_queue_id)
        )
        -- A header with its own real Fusion error.
        SELECT h.INTERFACE_HEADER_KEY,
               'HDR',
               h.TFM_SEQUENCE_ID,
               DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR(
                   'header', h.RECON_KEY,
                   DBMS_LOB.SUBSTR(h.ERROR_TEXT, 3800, DBMS_LOB.INSTR(h.ERROR_TEXT, C_TAG)))
        BULK COLLECT INTO l_pairs
        FROM   po_hdrs h
        WHERE  h.TFM_STATUS = 'FAILED'
        AND    DBMS_LOB.INSTR(h.ERROR_TEXT, C_TAG) > 0
        AND    DBMS_LOB.INSTR(h.ERROR_TEXT, l_marker) = 0
        UNION ALL
        -- A line with its own real Fusion error rejects its purchase order.
        SELECT l.DOC_KEY,
               'LINE',
               l.TFM_SEQUENCE_ID,
               DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR(
                   'line', l.RECON_KEY,
                   DBMS_LOB.SUBSTR(l.ERROR_TEXT, 3800, DBMS_LOB.INSTR(l.ERROR_TEXT, C_TAG)))
        FROM   po_lines l
        WHERE  l.TFM_STATUS = 'FAILED'
        AND    DBMS_LOB.INSTR(l.ERROR_TEXT, C_TAG) > 0
        AND    DBMS_LOB.INSTR(l.ERROR_TEXT, l_marker) = 0
        UNION ALL
        -- A line location (schedule) with its own real Fusion error.
        SELECT ll.DOC_KEY,
               'LLOC',
               ll.TFM_SEQUENCE_ID,
               DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR(
                   'line location', ll.RECON_KEY,
                   DBMS_LOB.SUBSTR(ll.ERROR_TEXT, 3800, DBMS_LOB.INSTR(ll.ERROR_TEXT, C_TAG)))
        FROM   po_locs ll
        WHERE  ll.TFM_STATUS = 'FAILED'
        AND    DBMS_LOB.INSTR(ll.ERROR_TEXT, C_TAG) > 0
        AND    DBMS_LOB.INSTR(ll.ERROR_TEXT, l_marker) = 0
        UNION ALL
        -- A distribution with its own real Fusion error.
        SELECT d.DOC_KEY,
               'DIST',
               d.TFM_SEQUENCE_ID,
               DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR(
                   'distribution', d.RECON_KEY,
                   DBMS_LOB.SUBSTR(d.ERROR_TEXT, 3800, DBMS_LOB.INSTR(d.ERROR_TEXT, C_TAG)))
        FROM   po_dists d
        WHERE  d.TFM_STATUS = 'FAILED'
        AND    DBMS_LOB.INSTR(d.ERROR_TEXT, C_TAG) > 0
        AND    DBMS_LOB.INSTR(d.ERROR_TEXT, l_marker) = 0;

        -- One bulk UPDATE per target table (FORALL over the pairs). Each pair
        -- appends its quote only when the row does not already carry it, so a row
        -- quoted by several sources gets each quote once and a second reconcile
        -- pass adds nothing. The source row itself is never quoted onto itself.
        -- DOC_KEY is always a Standard-PO header key (see the collection above),
        -- so these updates never reach a Blanket or Contract document.
        l_step := 'appending quoted document errors to PO headers';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_PO_HEADERS_INT_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    t.STYLE_DISPLAY_NAME = C_STYLE
            AND    (p_work_queue_id IS NULL OR t.WORK_QUEUE_ID IS NULL
                    OR t.WORK_QUEUE_ID = p_work_queue_id)
            AND    t.INTERFACE_HEADER_KEY = l_pairs(i).DOC_KEY
            AND    NOT (l_pairs(i).SOURCE_KIND = 'HDR' AND l_pairs(i).SOURCE_SEQ = t.TFM_SEQUENCE_ID)
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    l_pairs(i).QUOTED_ERROR IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_hdrs := SQL%ROWCOUNT;

        l_step := 'appending quoted document errors to PO lines';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_PO_LINES_INT_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    (p_work_queue_id IS NULL OR t.WORK_QUEUE_ID IS NULL
                    OR t.WORK_QUEUE_ID = p_work_queue_id)
            AND    t.INTERFACE_HEADER_KEY = l_pairs(i).DOC_KEY
            AND    NOT (l_pairs(i).SOURCE_KIND = 'LINE' AND l_pairs(i).SOURCE_SEQ = t.TFM_SEQUENCE_ID)
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    l_pairs(i).QUOTED_ERROR IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_lines := SQL%ROWCOUNT;

        l_step := 'appending quoted document errors to PO line locations';
        -- A location belongs to the purchase order of its line (same run).
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_PO_LINE_LOCS_INT_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    (p_work_queue_id IS NULL OR t.WORK_QUEUE_ID IS NULL
                    OR t.WORK_QUEUE_ID = p_work_queue_id)
            AND    t.INTERFACE_LINE_KEY IN (
                       SELECT l.INTERFACE_LINE_KEY
                       FROM   DMT_PO_LINES_INT_TFM_TBL l
                       WHERE  l.RUN_ID = p_run_id
                       AND    l.INTERFACE_HEADER_KEY = l_pairs(i).DOC_KEY)
            AND    NOT (l_pairs(i).SOURCE_KIND = 'LLOC' AND l_pairs(i).SOURCE_SEQ = t.TFM_SEQUENCE_ID)
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    l_pairs(i).QUOTED_ERROR IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_locs := SQL%ROWCOUNT;

        l_step := 'appending quoted document errors to PO distributions';
        -- A distribution belongs to the purchase order of its location's line.
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_PO_DISTS_INT_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    (p_work_queue_id IS NULL OR t.WORK_QUEUE_ID IS NULL
                    OR t.WORK_QUEUE_ID = p_work_queue_id)
            AND    t.INTERFACE_LINE_LOCATION_KEY IN (
                       SELECT ll.INTERFACE_LINE_LOCATION_KEY
                       FROM   DMT_PO_LINE_LOCS_INT_TFM_TBL ll
                       JOIN   DMT_PO_LINES_INT_TFM_TBL l
                              ON  l.RUN_ID = ll.RUN_ID
                              AND l.INTERFACE_LINE_KEY = ll.INTERFACE_LINE_KEY
                       WHERE  ll.RUN_ID = p_run_id
                       AND    l.INTERFACE_HEADER_KEY = l_pairs(i).DOC_KEY)
            AND    NOT (l_pairs(i).SOURCE_KIND = 'DIST' AND l_pairs(i).SOURCE_SEQ = t.TFM_SEQUENCE_ID)
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    l_pairs(i).QUOTED_ERROR IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_dists := SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Rejected purchase-order sources: ' || l_pairs.COUNT
                           || ' | rows given a quoted document error: headers ' || l_hdrs
                           || ', lines ' || l_lines || ', line locations ' || l_locs
                           || ', distributions ' || l_dists || '.',
            p_package   => C_PKG,
            p_procedure => C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ' failed while ' || l_step || '.',
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE;
    END PROPAGATE_DOCUMENT_ERRORS;

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

        -- Whole-document rejection (design section 5): rows Import Orders rejected
        -- with their purchase order carry the real error of the row that caused it.
        -- Runs after the per-row apply and BEFORE the shared unaccounted sweep
        -- (DMT_QUEUE_WORKER_PKG.RECONCILE_ONE).
        PROPAGATE_DOCUMENT_ERRORS(p_run_id, p_work_queue_id);

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


    -- --------------------------------------------------------
    -- RESET_UNACCOUNTED (backlog #95) -- see spec. Static UPDATE(s) over the
    -- compile-time-known PurchaseOrders TFM table(s). Flips this run's UNACCOUNTED rows
    -- back to GENERATED and strips the trailing [UNACCOUNTED] tag from ERROR_TEXT
    -- (CLOB-safe REGEXP_REPLACE -- plain REPLACE raises ORA-22849), preserving any
    -- prior real error. Scoped by run, and by work-queue item when given. NO
    -- dynamic SQL; NO COMMIT.
    -- --------------------------------------------------------
    PROCEDURE RESET_UNACCOUNTED (
        p_run_id        IN NUMBER,
        p_load_ess_id   IN NUMBER   DEFAULT NULL,
        p_import_ess_id IN NUMBER   DEFAULT NULL,
        p_work_queue_id IN NUMBER   DEFAULT NULL
    ) IS
        C_PROC  CONSTANT VARCHAR2(30) := 'RESET_UNACCOUNTED';
        l_reset NUMBER := 0;
    BEGIN
        UPDATE DMT_PO_HEADERS_INT_TFM_TBL
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
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id)
        AND    (STYLE_DISPLAY_NAME = 'Purchase Order');
        l_reset := l_reset + SQL%ROWCOUNT;
        UPDATE DMT_PO_LINES_INT_TFM_TBL
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
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id)
        AND    (INTERFACE_HEADER_KEY IN (SELECT INTERFACE_HEADER_KEY FROM DMT_PO_HEADERS_INT_TFM_TBL WHERE STYLE_DISPLAY_NAME = 'Purchase Order'));
        l_reset := l_reset + SQL%ROWCOUNT;
        UPDATE DMT_PO_LINE_LOCS_INT_TFM_TBL
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
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id)
        AND    (INTERFACE_LINE_KEY IN (SELECT INTERFACE_LINE_KEY FROM DMT_PO_LINES_INT_TFM_TBL WHERE INTERFACE_HEADER_KEY IN (SELECT INTERFACE_HEADER_KEY FROM DMT_PO_HEADERS_INT_TFM_TBL WHERE STYLE_DISPLAY_NAME = 'Purchase Order')));
        l_reset := l_reset + SQL%ROWCOUNT;
        UPDATE DMT_PO_DISTS_INT_TFM_TBL
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
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id)
        AND    (INTERFACE_LINE_LOCATION_KEY IN (SELECT INTERFACE_LINE_LOCATION_KEY FROM DMT_PO_LINE_LOCS_INT_TFM_TBL WHERE INTERFACE_LINE_KEY IN (SELECT INTERFACE_LINE_KEY FROM DMT_PO_LINES_INT_TFM_TBL WHERE INTERFACE_HEADER_KEY IN (SELECT INTERFACE_HEADER_KEY FROM DMT_PO_HEADERS_INT_TFM_TBL WHERE STYLE_DISPLAY_NAME = 'Purchase Order'))));
        l_reset := l_reset + SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ': reset ' || l_reset || ' UNACCOUNTED PurchaseOrders row(s) to GENERATED '
            || 'for re-reconcile.',
            'INFO', C_PKG, C_PROC);
        -- NO COMMIT -- the caller (RERUN_RUN) owns the transaction.
    END RESET_UNACCOUNTED;

END DMT_PO_RESULTS_PKG;
/
