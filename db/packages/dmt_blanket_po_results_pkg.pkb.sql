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
-- ':LN:' || LINE_NUM). No STG echo. After the per-row apply,
-- PROPAGATE_DOCUMENT_ERRORS quotes a rejected header's real Fusion error onto the
-- lines Import Blanket Agreements rejected with it (design section 5,
-- whole-document rejection; header -> lines only, see the procedure).
--
-- REVISIONS:
--   2026-10-07  BM  Cross-grain propagation (PROPAGATE_DOCUMENT_ERRORS): a
--                   rejected blanket header's error reaches its lines.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_BLANKET_PO_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'BlanketPOs';

    -- This object's rows in the shared PO TFM tables (the catalog ROW_FILTER for
    -- BlanketPOs): headers whose STYLE_DISPLAY_NAME is the blanket style.
    C_STYLE CONSTANT VARCHAR2(30) := 'Blanket Purchase Agreement';

    -- Cross-grain propagation (PROPAGATE_DOCUMENT_ERRORS).
    -- Working set: "the blanket agreement DOC_KEY has a header SOURCE_SEQ with its
    -- own real Fusion error, so its lines must carry QUOTED_ERROR".
    TYPE T_DOC_PAIR IS RECORD (
        DOC_KEY      DMT_PO_HEADERS_INT_TFM_TBL.INTERFACE_HEADER_KEY%TYPE,  -- the agreement
        SOURCE_SEQ   NUMBER,           -- the header's TFM_SEQUENCE_ID
        QUOTED_ERROR VARCHAR2(4000)    -- DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR(...)
    );
    TYPE T_DOC_PAIR_TBL IS TABLE OF T_DOC_PAIR;

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
        l_rc        NUMBER := 0;    -- backlog #65: rows matched by the current tier
        l_dff_seq   NUMBER;          -- backlog #65 tier 2: TFM_SEQUENCE_ID from DFF_KEY
        l_tier      VARCHAR2(10);    -- backlog #65: which tier matched (audit log)
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
                        -- Backlog #65 three-tier match. Tier 1 is the stamped Slot A reference
                        -- (RECON_KEY = RECORD_KEY, exactly as before). Only if tier 1 matches NO
                        -- TFM row do we fall through: tier 2 (the Slot C DFF stamp: TFM_SEQUENCE_ID
                        -- = trailing segment of DFF_KEY) and then tier 3 (the business key:
                        -- RECON_KEY = BUSINESS_KEY -- the per-record SOURCE_REF equals RECON_KEY, so
                        -- tier 3 is the same key and safely degenerate). Every tier-1 hit short-
                        -- circuits, so loaded outcomes are identical to before.
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
                                C_PROC || ': matched a LOADED Blanket PO header via ' || l_tier ||
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

                -- ===== TIER: LINES (OBJECT_TYPE = 'BlanketPOs.Line') =====
                ELSIF l_rows(i).OBJECT_TYPE = 'BlanketPOs.Line' THEN
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
                                C_PROC || ': matched a LOADED Blanket PO line via ' || l_tier ||
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
    -- PROPAGATE_DOCUMENT_ERRORS (private)
    -- Design section 5, "Whole-document rejection carries the real error to every
    -- grain" (decided 2026-10-07), applied in the direction Fusion actually
    -- rejects. Import Blanket Agreements rejects every line of an agreement whose
    -- HEADER is rejected, writing PO_INTERFACE_ERRORS only on the header (live:
    -- 16 BLANKET documents with a REJECTED header + error and REJECTED lines with
    -- none). It does NOT reject the header when only a line fails: it accepts the
    -- agreement and rejects that line alone (live: 7 ACCEPTED headers beside a
    -- REJECTED line; docs/findings/cross_grain_conformance_review.md). So the only
    -- whole-document case is header -> lines; a line's own error stays on that
    -- line, and its header and sibling lines keep their own outcomes.
    --
    -- The document is the agreement: one header interface row
    -- (INTERFACE_HEADER_KEY) and the lines carrying that key; keys are
    -- run-prefixed, so the key is RUN_ID + INTERFACE_HEADER_KEY. Only this object's
    -- rows are read or written: headers of the blanket style (C_STYLE, the
    -- catalog ROW_FILTER) and their lines, so a Standard PO or Contract in the
    -- same shared tables is never touched. Rows are scoped to the work item the
    -- way the shared sweep scopes it.
    --
    -- Sources: blanket headers of this run and work item with TFM_STATUS =
    --   'FAILED' carrying their OWN real Fusion error ('[FUSION_ERROR]', no
    --   C_DOC_ERROR_MARKER).
    -- Targets: the lines of that agreement that Fusion received (FBDI_CSV_ID set,
    --   not STAGED) and that are not LOADED (LOADED rows are never touched), and
    --   that do not already carry the exact quote. The quote is appended
    --   (APPEND_ERROR, never overwrite) and the line set FAILED.
    -- Idempotent: the "already carries the exact quote" guard means a second
    --   reconcile pass adds nothing.
    -- One collection of (agreement, header, quote) pairs by ONE static SELECT,
    -- then ONE static bulk UPDATE (FORALL): a MERGE cannot read a PL/SQL record
    -- collection through TABLE() (ORA-00902, AR run 248). NO dynamic SQL; NO
    -- COMMIT (caller owns the txn).
    -- --------------------------------------------------------
    PROCEDURE PROPAGATE_DOCUMENT_ERRORS (
        p_run_id        IN NUMBER,
        p_work_queue_id IN NUMBER
    ) IS
        C_PROC   CONSTANT VARCHAR2(30) := 'PROPAGATE_DOCUMENT_ERRORS';
        C_TAG    CONSTANT VARCHAR2(20) := '[FUSION_ERROR]';
        l_marker VARCHAR2(30) := DMT_UTIL_PKG.C_DOC_ERROR_MARKER;
        l_pairs  T_DOC_PAIR_TBL;
        l_lines  NUMBER := 0;
        l_step   VARCHAR2(200);
    BEGIN
        l_step := 'collecting rejected blanket headers for run ' || p_run_id;
        SELECT h.INTERFACE_HEADER_KEY,
               h.TFM_SEQUENCE_ID,
               DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR(
                   'header', h.RECON_KEY,
                   DBMS_LOB.SUBSTR(h.ERROR_TEXT, 3800, DBMS_LOB.INSTR(h.ERROR_TEXT, C_TAG)))
        BULK COLLECT INTO l_pairs
        FROM   DMT_PO_HEADERS_INT_TFM_TBL h
        WHERE  h.RUN_ID = p_run_id
        AND    h.STYLE_DISPLAY_NAME = C_STYLE
        -- Work-item scope, as the shared sweep scopes it: rows stamped with
        -- another work item are excluded; unstamped rows are run-scoped.
        AND    (p_work_queue_id IS NULL OR h.WORK_QUEUE_ID IS NULL
                OR h.WORK_QUEUE_ID = p_work_queue_id)
        AND    h.TFM_STATUS = 'FAILED'
        AND    DBMS_LOB.INSTR(h.ERROR_TEXT, C_TAG) > 0
        AND    DBMS_LOB.INSTR(h.ERROR_TEXT, l_marker) = 0;

        l_step := 'appending quoted document errors to blanket lines';
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
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    l_pairs(i).QUOTED_ERROR IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_lines := SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Rejected blanket headers: ' || l_pairs.COUNT
                           || ' | lines given a quoted document error: ' || l_lines || '.',
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

        -- Whole-document rejection (design section 5): lines Import Blanket
        -- Agreements rejected with their header carry the header's real error.
        -- Runs after the per-row apply and BEFORE the shared unaccounted sweep
        -- (DMT_QUEUE_WORKER_PKG.RECONCILE_ONE).
        PROPAGATE_DOCUMENT_ERRORS(p_run_id, p_work_queue_id);

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
    -- compile-time-known BlanketPOs TFM table(s). Flips this run's UNACCOUNTED rows
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
        AND    (STYLE_DISPLAY_NAME = 'Blanket Purchase Agreement');
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
        AND    (INTERFACE_HEADER_KEY IN (SELECT INTERFACE_HEADER_KEY FROM DMT_PO_HEADERS_INT_TFM_TBL WHERE STYLE_DISPLAY_NAME = 'Blanket Purchase Agreement'));
        l_reset := l_reset + SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ': reset ' || l_reset || ' UNACCOUNTED BlanketPOs row(s) to GENERATED '
            || 'for re-reconcile.',
            'INFO', C_PKG, C_PROC);
        -- NO COMMIT -- the caller (RERUN_RUN) owns the transaction.
    END RESET_UNACCOUNTED;

END DMT_BLANKET_PO_RESULTS_PKG;
/
