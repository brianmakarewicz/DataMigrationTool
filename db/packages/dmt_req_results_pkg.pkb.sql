-- PACKAGE BODY DMT_REQ_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_REQ_RESULTS_PKG"
AS
-- ============================================================
-- DMT_REQ_RESULTS_PKG body
-- Requisitions post-load reconciliation — Contract v1, MULTI-TIER template.
--
-- This is the multi-tier pilot (supersedes PR #362). It reuses the ONE shared
-- Contract v1 fetch, DMT_RECON_CONTRACT_PKG.FETCH_ROWS, exactly as the Workers
-- template does (DMT_WORKER_RESULTS_PKG). A single FETCH_ROWS call runs the
-- Requisitions Contract v1 report (nine columns, keyset paginated) over BIP and
-- returns ALL three tiers' rows in one collection; each row's OBJECT_TYPE says
-- which tier it belongs to.
--
-- The APPLY is STATIC SQL against the compile-time-known TFM tables (Option A,
-- owner decision on PR #248): one MERGE-style pair PER TIER, filtering the report
-- rows by OBJECT_TYPE and joining that tier's TFM table on RECON_KEY = RECORD_KEY.
--
--   Tier         OBJECT_TYPE literal          TFM table                    FUSION_ID column
--   ----------   --------------------------   --------------------------   ----------------------------
--   headers      'Requisitions'               DMT_POR_REQ_HEADERS_TFM_TBL  FUSION_REQUISITION_HEADER_ID
--   lines        'Requisitions.Line'          DMT_POR_REQ_LINES_TFM_TBL    FUSION_REQUISITION_LINE_ID
--   distributions'Requisitions.Distribution'  DMT_POR_REQ_DISTS_TFM_TBL    FUSION_DISTRIBUTION_ID
--
-- Per tier the rule is the shared Contract v1 apply rule:
--   * BASE / SUCCESS / FUSION_ID NOT NULL -> LOADED, stamp FUSION_ID.
--   * FUSION_STATUS = ERROR with a real ERROR_MESSAGE -> FAILED, message
--     appended as '[FUSION_ERROR] ' || message (never composed).
--   * Everything else is left GENERATED for the shared unaccounted sweep;
--     INTERFACE/SUCCESS corroborates but is never sufficient for LOADED.
--
-- The RECON_KEY on each tier's TFM row is stamped by DMT_REQ_TRANSFORM_PKG to
-- equal that tier's report RECORD_KEY (headers = prefixed REQUISITION_NUMBER;
-- lines = INTERFACE_LINE_KEY; dists = INTERFACE_LINE_KEY||':DIST:'||number). That
-- coupling is what makes the join hit — its absence is why the earlier pilot got
-- 0 LOADED.
--
-- After the three tiers settle, outcomes are echoed back to all three STG tables
-- (unchanged from the prior reader). Each tier has its own BASE and INTERFACE
-- rows in the report, so each tier accounts for itself directly. Then
-- PROPAGATE_DOCUMENT_ERRORS quotes each rejected row's real Fusion error onto the
-- other rows of the same requisition, which Requisition Import rejects with it
-- but writes no error for (design section 5, whole-document rejection).
--
-- REVISIONS:
--   2026-10-07  BM  Cross-grain propagation (PROPAGATE_DOCUMENT_ERRORS): the
--                   requisition (INTERFACE_HEADER_KEY) is the document.
--   2026-10-07  BM  Report V2: called per work item with its own load + import
--                   ids; rows found by job id, never by prefix / run id.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_REQ_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'Requisitions';

    -- Cross-grain propagation (PROPAGATE_DOCUMENT_ERRORS).
    -- Working set: "the requisition DOC_KEY carries the source row SOURCE_SEQ (a
    -- header, line or distribution with its own real Fusion error), so every other
    -- row of that requisition must carry QUOTED_ERROR".
    TYPE T_DOC_PAIR IS RECORD (
        DOC_KEY      DMT_POR_REQ_HEADERS_TFM_TBL.INTERFACE_HEADER_KEY%TYPE,  -- the requisition
        SOURCE_KIND  VARCHAR2(4),      -- 'HDR' | 'LINE' | 'DIST'
        SOURCE_SEQ   NUMBER,           -- TFM_SEQUENCE_ID in the source's own table
        QUOTED_ERROR VARCHAR2(4000)    -- DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR(...)
    );
    TYPE T_DOC_PAIR_TBL IS TABLE OF T_DOC_PAIR;

    -- --------------------------------------------------------
    -- GET_PARTITION_KEYS — distinct BATCH_ID tokens for one run, STATIC SQL
    -- over the requisition-headers transform table (this object's own table).
    -- Spawn-per-partition (work-queue-ID core, 2026-07-20): one child work item
    -- per batch. Called through invoke_registered (style KEYS). Unchanged.
    -- --------------------------------------------------------
    FUNCTION GET_PARTITION_KEYS (
        p_run_id IN NUMBER
    ) RETURN DMT_PARTITION_KEY_TBL IS
        l_keys DMT_PARTITION_KEY_TBL;
    BEGIN
        SELECT DISTINCT JSON_OBJECT('BATCH_ID' VALUE TO_CHAR(BATCH_ID))
        BULK COLLECT INTO l_keys
        FROM   DMT_POR_REQ_HEADERS_TFM_TBL
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'STAGED'
        AND    BATCH_ID IS NOT NULL;
        RETURN l_keys;
    END GET_PARTITION_KEYS;

    -- --------------------------------------------------------
    -- APPLY_CONTRACT_V1_REQUISITIONS (private)
    -- The Contract v1 apply for all three Requisitions tiers, Option A shape.
    -- One shared FETCH_ROWS call returns every tier's rows; the apply is STATIC
    -- SQL, one pair of UPDATEs per tier, discriminated by OBJECT_TYPE and joined
    -- on RECON_KEY = RECORD_KEY. This is the copy-template for the other multi-tier
    -- FBDI objects (AP, AR, MiscReceipts, Assets, PO family, Projects, Grants).
    -- --------------------------------------------------------
    PROCEDURE APPLY_CONTRACT_V1_REQUISITIONS (
        p_run_id        IN NUMBER,
        p_request_id    IN VARCHAR2,
        p_import_ess_id IN NUMBER
    ) IS
        C_PROC      CONSTANT VARCHAR2(40) := 'APPLY_CONTRACT_V1_REQUISITIONS';
        l_gen_count NUMBER := 0;
        l_rows      DMT_RECON_CONTRACT_PKG.T_RECON_TBL;
        l_err_code  NUMBER;
        l_hdr_loaded  NUMBER := 0;  l_hdr_failed  NUMBER := 0;
        l_line_loaded NUMBER := 0;  l_line_failed NUMBER := 0;
        l_dist_loaded NUMBER := 0;  l_dist_failed NUMBER := 0;
        l_rc        NUMBER := 0;    -- backlog #65: rows matched by the current tier
        l_dff_seq   NUMBER;          -- backlog #65 tier 2: TFM_SEQUENCE_ID from DFF_KEY
        l_tier      VARCHAR2(10);    -- backlog #65: which tier matched (audit log)
    BEGIN
        -- Generated-row count across all three tiers drives the shared fetch's
        -- keyset page-count cap. Done statically here (not in the shared pkg).
        SELECT (SELECT COUNT(*) FROM DMT_POR_REQ_HEADERS_TFM_TBL WHERE RUN_ID = p_run_id)
             + (SELECT COUNT(*) FROM DMT_POR_REQ_LINES_TFM_TBL   WHERE RUN_ID = p_run_id)
             + (SELECT COUNT(*) FROM DMT_POR_REQ_DISTS_TFM_TBL   WHERE RUN_ID = p_run_id)
        INTO   l_gen_count
        FROM   dual;

        -- Report V2 (owner decision 2026-10-07) finds rows only by this work
        -- item's Fusion job ids: base rows by the import job's REQUEST_ID,
        -- interface rows and errors by the load request id and the import
        -- request. Both ids are the work item's own (one batch = one load =
        -- one Requisition Import), so the report is called once per work item.
        DMT_RECON_CONTRACT_PKG.FETCH_ROWS(
            p_cemli_code    => C_CEMLI,
            p_run_id        => p_run_id,
            p_load_ess_id   => TO_NUMBER(p_request_id),
            p_import_ess_id => p_import_ess_id,
            p_row_cap       => l_gen_count,
            x_rows          => l_rows,
            x_error_code    => l_err_code);

        -- A transport / SOAP failure raises loudly (design section 5: never a
        -- silent retry, never a zero-row "success"); the fetch already logged detail.
        IF l_err_code <> DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20094,
                C_PROC || ': Contract v1 fetch failed for Requisitions '
                || '(detail in DMT_LOG_TBL).');
        END IF;

        IF l_rows.COUNT = 0 THEN
            -- Zero report rows is never success (design section 5): leave the
            -- remaining GENERATED rows for the existing unaccounted sweep.
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ': Requisitions recon report returned zero rows; '
                               || 'GENERATED rows left for the unaccounted sweep '
                               || '(never a silent success).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
        ELSE
            FOR i IN 1 .. l_rows.COUNT LOOP
                -- ===== TIER: HEADERS (OBJECT_TYPE = 'Requisitions') =====
                IF l_rows(i).OBJECT_TYPE = 'Requisitions' THEN
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
                        UPDATE DMT_POR_REQ_HEADERS_TFM_TBL
                        SET    TFM_STATUS           = 'LOADED',
                               FUSION_REQUISITION_HEADER_ID = l_rows(i).FUSION_ID,
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
                                UPDATE DMT_POR_REQ_HEADERS_TFM_TBL
                                SET    TFM_STATUS           = 'LOADED',
                                       FUSION_REQUISITION_HEADER_ID = l_rows(i).FUSION_ID,
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
                            UPDATE DMT_POR_REQ_HEADERS_TFM_TBL
                            SET    TFM_STATUS           = 'LOADED',
                                   FUSION_REQUISITION_HEADER_ID = l_rows(i).FUSION_ID,
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
                                C_PROC || ': matched a LOADED Requisition header via ' || l_tier ||
                                ' fallback (tier 1 stamped ref did not resolve). FUSION_ID '
                                || l_rows(i).FUSION_ID || '.', 'INFO', C_PKG, C_PROC);
                        END IF;
                    ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                          AND l_rows(i).ERROR_MESSAGE IS NOT NULL THEN
                        UPDATE DMT_POR_REQ_HEADERS_TFM_TBL
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

                -- ===== TIER: LINES (OBJECT_TYPE = 'Requisitions.Line') =====
                ELSIF l_rows(i).OBJECT_TYPE = 'Requisitions.Line' THEN
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
                        UPDATE DMT_POR_REQ_LINES_TFM_TBL
                        SET    TFM_STATUS           = 'LOADED',
                               FUSION_REQUISITION_LINE_ID = l_rows(i).FUSION_ID,
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
                                UPDATE DMT_POR_REQ_LINES_TFM_TBL
                                SET    TFM_STATUS           = 'LOADED',
                                       FUSION_REQUISITION_LINE_ID = l_rows(i).FUSION_ID,
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
                            UPDATE DMT_POR_REQ_LINES_TFM_TBL
                            SET    TFM_STATUS           = 'LOADED',
                                   FUSION_REQUISITION_LINE_ID = l_rows(i).FUSION_ID,
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
                                C_PROC || ': matched a LOADED Requisition line via ' || l_tier ||
                                ' fallback (tier 1 stamped ref did not resolve). FUSION_ID '
                                || l_rows(i).FUSION_ID || '.', 'INFO', C_PKG, C_PROC);
                        END IF;
                    ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                          AND l_rows(i).ERROR_MESSAGE IS NOT NULL THEN
                        UPDATE DMT_POR_REQ_LINES_TFM_TBL
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

                -- ===== TIER: DISTRIBUTIONS (OBJECT_TYPE = 'Requisitions.Distribution') =====
                ELSIF l_rows(i).OBJECT_TYPE = 'Requisitions.Distribution' THEN
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
                        UPDATE DMT_POR_REQ_DISTS_TFM_TBL
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
                                UPDATE DMT_POR_REQ_DISTS_TFM_TBL
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
                            UPDATE DMT_POR_REQ_DISTS_TFM_TBL
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
                                C_PROC || ': matched a LOADED Requisition distribution via ' || l_tier ||
                                ' fallback (tier 1 stamped ref did not resolve). FUSION_ID '
                                || l_rows(i).FUSION_ID || '.', 'INFO', C_PKG, C_PROC);
                        END IF;
                    ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                          AND l_rows(i).ERROR_MESSAGE IS NOT NULL THEN
                        UPDATE DMT_POR_REQ_DISTS_TFM_TBL
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
        -- Echo tier outcomes back to the three STG tables (unchanged behaviour).
        -- ============================================================
        -- Headers
        UPDATE DMT_POR_REQ_HEADERS_STG_TBL stg
        SET    stg.STG_STATUS = 'LOADED', stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_POR_REQ_HEADERS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');
        UPDATE DMT_POR_REQ_HEADERS_STG_TBL stg
        SET    stg.STG_STATUS = 'FAILED',
               stg.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_POR_REQ_HEADERS_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_POR_REQ_HEADERS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');

        -- Lines
        UPDATE DMT_POR_REQ_LINES_STG_TBL stg
        SET    stg.STG_STATUS = 'LOADED', stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_POR_REQ_LINES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');
        UPDATE DMT_POR_REQ_LINES_STG_TBL stg
        SET    stg.STG_STATUS = 'FAILED',
               stg.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_POR_REQ_LINES_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_POR_REQ_LINES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');

        -- Distributions
        UPDATE DMT_POR_REQ_DISTS_STG_TBL stg
        SET    stg.STG_STATUS = 'LOADED', stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_POR_REQ_DISTS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');
        UPDATE DMT_POR_REQ_DISTS_STG_TBL stg
        SET    stg.STG_STATUS = 'FAILED',
               stg.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_POR_REQ_DISTS_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_POR_REQ_DISTS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');

        -- NO COMMIT — orchestrator controls transaction boundaries.

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Report rows: ' || l_rows.COUNT
                           || ' | headers LOADED/FAILED: ' || l_hdr_loaded || '/' || l_hdr_failed
                           || ' | lines LOADED/FAILED: '   || l_line_loaded || '/' || l_line_failed
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
    END APPLY_CONTRACT_V1_REQUISITIONS;

    -- --------------------------------------------------------
    -- PROPAGATE_DOCUMENT_ERRORS (private)
    -- Design section 5, "Whole-document rejection carries the real error to every
    -- grain" (decided 2026-10-07). Requisition Import is all-or-nothing per
    -- requisition: when the header, any line or any distribution of a requisition
    -- has an error, Fusion sets EVERY interface row of that requisition to
    -- FAILED/ERROR but writes POR_REQ_IMPORT_ERRORS only for the row that failed
    -- (run 238: BADLINE / BADDIST headers, BADHDR line + dist, BADLINE dist;
    -- docs/findings/run238_Reqs_POs_unaccounted.md).
    --
    -- The document is the requisition as Fusion builds it: one header interface
    -- row and the lines that carry its INTERFACE_HEADER_KEY, each line's
    -- distributions by INTERFACE_LINE_KEY. DMT always sends the header, so the
    -- header key decides the requisition; the import's Group By argument (NONE)
    -- and the line GROUP_CODE only group lines that arrive WITHOUT a header, so
    -- two DMT requisitions are never merged. A requisition never spans two work
    -- items (the BATCH_ID partition is a header value), so the key is
    -- RUN_ID + INTERFACE_HEADER_KEY, and every row is scoped to the work item the
    -- way the shared sweep scopes it.
    --
    -- Sources: headers, lines and distributions of this run and work item with
    --   TFM_STATUS = 'FAILED' carrying their OWN real Fusion error -- ERROR_TEXT
    --   contains '[FUSION_ERROR]' and does NOT contain C_DOC_ERROR_MARKER (a quote
    --   is never re-quoted, so quotes never chain). A distribution's requisition
    --   comes through its line.
    -- Targets: every OTHER header / line / distribution row of the same
    --   requisition that Fusion received (FBDI_CSV_ID stamped at generation, not
    --   STAGED) and that is not LOADED (LOADED rows are never touched), and that
    --   does not already carry the exact quote. The quote is appended
    --   (APPEND_ERROR, never overwrite) and the row set FAILED. A requisition with
    --   no source error is untouched -- its rows fall to the shared UNACCOUNTED
    --   sweep.
    -- Idempotent: the "already carries the exact quote" guard means a second
    --   reconcile pass adds nothing.
    -- One collection of (requisition, source, quote) pairs is built by ONE static
    -- SELECT, then ONE static bulk UPDATE (FORALL) per target table: a MERGE
    -- cannot read a PL/SQL record collection through TABLE() (ORA-00902, AR run
    -- 248). NO dynamic SQL; NO COMMIT (caller owns the txn).
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
        l_dists  NUMBER := 0;
        l_step   VARCHAR2(200);
    BEGIN
        l_step := 'collecting same-requisition (source, quote) pairs for run ' || p_run_id;
        WITH scoped_hdrs AS (
            SELECT h.*
            FROM   DMT_POR_REQ_HEADERS_TFM_TBL h
            WHERE  h.RUN_ID = p_run_id
            -- Work-item scope, as the shared sweep scopes it: rows stamped with
            -- another work item are excluded; unstamped rows are run-scoped.
            AND    (p_work_queue_id IS NULL OR h.WORK_QUEUE_ID IS NULL
                    OR h.WORK_QUEUE_ID = p_work_queue_id)
        ),
        scoped_lines AS (
            SELECT l.*
            FROM   DMT_POR_REQ_LINES_TFM_TBL l
            WHERE  l.RUN_ID = p_run_id
            AND    (p_work_queue_id IS NULL OR l.WORK_QUEUE_ID IS NULL
                    OR l.WORK_QUEUE_ID = p_work_queue_id)
        ),
        scoped_dists AS (
            SELECT d.*
            FROM   DMT_POR_REQ_DISTS_TFM_TBL d
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
        FROM   scoped_hdrs h
        WHERE  h.TFM_STATUS = 'FAILED'
        AND    DBMS_LOB.INSTR(h.ERROR_TEXT, C_TAG) > 0
        AND    DBMS_LOB.INSTR(h.ERROR_TEXT, l_marker) = 0
        AND    h.INTERFACE_HEADER_KEY IS NOT NULL
        UNION ALL
        -- A line with its own real Fusion error rejects its requisition.
        SELECT l.INTERFACE_HEADER_KEY,
               'LINE',
               l.TFM_SEQUENCE_ID,
               DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR(
                   'line', l.RECON_KEY,
                   DBMS_LOB.SUBSTR(l.ERROR_TEXT, 3800, DBMS_LOB.INSTR(l.ERROR_TEXT, C_TAG)))
        FROM   scoped_lines l
        WHERE  l.TFM_STATUS = 'FAILED'
        AND    DBMS_LOB.INSTR(l.ERROR_TEXT, C_TAG) > 0
        AND    DBMS_LOB.INSTR(l.ERROR_TEXT, l_marker) = 0
        AND    l.INTERFACE_HEADER_KEY IS NOT NULL
        UNION ALL
        -- A distribution with its own real Fusion error rejects its line, and
        -- therefore that line's requisition: the requisition comes through the line.
        SELECT l.INTERFACE_HEADER_KEY,
               'DIST',
               d.TFM_SEQUENCE_ID,
               DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR(
                   'distribution', d.RECON_KEY,
                   DBMS_LOB.SUBSTR(d.ERROR_TEXT, 3800, DBMS_LOB.INSTR(d.ERROR_TEXT, C_TAG)))
        FROM   scoped_dists d
        JOIN   scoped_lines l ON l.INTERFACE_LINE_KEY = d.INTERFACE_LINE_KEY
        WHERE  d.TFM_STATUS = 'FAILED'
        AND    DBMS_LOB.INSTR(d.ERROR_TEXT, C_TAG) > 0
        AND    DBMS_LOB.INSTR(d.ERROR_TEXT, l_marker) = 0
        AND    l.INTERFACE_HEADER_KEY IS NOT NULL;

        -- One bulk UPDATE per target table (FORALL over the pairs). Each pair
        -- appends its quote only when the row does not already carry it, so a row
        -- quoted by several sources gets each quote once and a second reconcile
        -- pass adds nothing. The source row itself is never quoted onto itself.
        l_step := 'appending quoted document errors to requisition headers';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_POR_REQ_HEADERS_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    (p_work_queue_id IS NULL OR t.WORK_QUEUE_ID IS NULL
                    OR t.WORK_QUEUE_ID = p_work_queue_id)
            AND    t.INTERFACE_HEADER_KEY = l_pairs(i).DOC_KEY
            AND    NOT (l_pairs(i).SOURCE_KIND = 'HDR' AND l_pairs(i).SOURCE_SEQ = t.TFM_SEQUENCE_ID)
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    l_pairs(i).QUOTED_ERROR IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_hdrs := SQL%ROWCOUNT;

        l_step := 'appending quoted document errors to requisition lines';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_POR_REQ_LINES_TFM_TBL t
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

        l_step := 'appending quoted document errors to requisition distributions';
        -- A distribution belongs to the requisition of its line (same run).
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_POR_REQ_DISTS_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    (p_work_queue_id IS NULL OR t.WORK_QUEUE_ID IS NULL
                    OR t.WORK_QUEUE_ID = p_work_queue_id)
            AND    t.INTERFACE_LINE_KEY IN (
                       SELECT l.INTERFACE_LINE_KEY
                       FROM   DMT_POR_REQ_LINES_TFM_TBL l
                       WHERE  l.RUN_ID = p_run_id
                       AND    l.INTERFACE_HEADER_KEY = l_pairs(i).DOC_KEY)
            AND    NOT (l_pairs(i).SOURCE_KIND = 'DIST' AND l_pairs(i).SOURCE_SEQ = t.TFM_SEQUENCE_ID)
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    l_pairs(i).QUOTED_ERROR IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_dists := SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Rejected requisition sources: ' || l_pairs.COUNT
                           || ' | rows given a quoted document error: headers ' || l_hdrs
                           || ', lines ' || l_lines || ', distributions ' || l_dists || '.',
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
    -- Contract v1 apply once for ONE work item (one batch): the load ESS id is
    -- the Contract v1 P_LOAD_REQUEST_ID and the import ESS id is
    -- P_IMPORT_ESS_ID. The report finds rows only by these two job ids; the run
    -- prefix and run id are never search values.
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
            p_message        => C_PROC || ' start. load_ess_id: ' || p_load_ess_id ||
                                ' | import_ess_id: ' || NVL(TO_CHAR(p_import_ess_id), 'NULL'),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        APPLY_CONTRACT_V1_REQUISITIONS(p_run_id, TO_CHAR(p_load_ess_id), p_import_ess_id);

        -- Whole-document rejection (design section 5): rows Requisition Import
        -- rejected with their requisition carry the real error of the row that
        -- caused it. Runs after the per-row apply and BEFORE the shared
        -- unaccounted sweep (DMT_QUEUE_WORKER_PKG.RECONCILE_ONE).
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
    -- compile-time-known Requisitions TFM table(s). Flips this run's UNACCOUNTED rows
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
        UPDATE DMT_POR_REQ_HEADERS_TFM_TBL
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
        l_reset := l_reset + SQL%ROWCOUNT;
        UPDATE DMT_POR_REQ_LINES_TFM_TBL
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
        l_reset := l_reset + SQL%ROWCOUNT;
        UPDATE DMT_POR_REQ_DISTS_TFM_TBL
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
        l_reset := l_reset + SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ': reset ' || l_reset || ' UNACCOUNTED Requisitions row(s) to GENERATED '
            || 'for re-reconcile.',
            'INFO', C_PKG, C_PROC);
        -- NO COMMIT -- the caller (RERUN_RUN) owns the transaction.
    END RESET_UNACCOUNTED;

END DMT_REQ_RESULTS_PKG;
/
