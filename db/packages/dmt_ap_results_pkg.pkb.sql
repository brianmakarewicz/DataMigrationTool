-- PACKAGE BODY DMT_AP_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_AP_RESULTS_PKG"
AS
-- ============================================================
-- DMT_AP_RESULTS_PKG body
-- APInvoices post-load reconciliation — Contract v1, MULTI-TIER template.
--
-- Reuses the ONE shared Contract v1 fetch, DMT_RECON_CONTRACT_PKG.FETCH_ROWS,
-- exactly as the Requisitions template does (DMT_REQ_RESULTS_PKG). A single
-- FETCH_ROWS call runs the APInvoices Contract v1 report (nine columns, keyset
-- paginated) over BIP and returns BOTH tiers' rows in one collection; each row's
-- OBJECT_TYPE says which tier it belongs to.
--
-- The APPLY is STATIC SQL against the compile-time-known TFM tables (Option A,
-- owner decision on PR #248): one MERGE-style pair PER TIER, filtering the report
-- rows by OBJECT_TYPE and joining that tier's TFM table on RECON_KEY = RECORD_KEY.
--
--   Tier      OBJECT_TYPE literal      TFM table                          FUSION_ID column
--   -------   ----------------------   --------------------------------   ---------------------
--   headers   'APInvoices'             DMT_AP_INVOICES_INT_TFM_TBL        FUSION_INVOICE_ID
--   lines     'APInvoices.Line'        DMT_AP_INVOICE_LINES_INT_TFM_TBL   FUSION_INVOICE_LINE_NUMBER
--                                       (line-grain composite INVOICE_ID~LINE_NUMBER)
--
-- Per tier the rule is the shared Contract v1 apply rule:
--   * BASE / SUCCESS / FUSION_ID NOT NULL -> LOADED (headers stamp FUSION_ID).
--   * FUSION_STATUS = ERROR with a real ERROR_MESSAGE (not the #IMPORT_REPORT#
--     marker) -> FAILED, message appended as '[FUSION_ERROR] ' || message.
--   * Everything else is left GENERATED for the shared unaccounted sweep;
--     INTERFACE/SUCCESS corroborates but is never sufficient for LOADED.
--
-- The base invoice line carries no independent surrogate id (a base line is
-- identified by INVOICE_ID + LINE_NUMBER), so the report reports the line-grain
-- composite INVOICE_ID~LINE_NUMBER as the line tier's FUSION_ID. On LOADED the
-- reconciler stamps that composite into FUSION_INVOICE_LINE_NUMBER (VARCHAR2) as
-- positive proof of load at line grain — two lines of one invoice get DIFFERENT
-- proof values (grain-fix, backlog #84; same tilde convention as GLBalances).
--
-- The RECON_KEY on each tier's TFM row is stamped by DMT_AP_TRANSFORM_PKG to
-- equal that tier's report RECORD_KEY (headers = prefixed INVOICE_NUM; lines =
-- prefixed parent INVOICE_NUM || ':LINE:' || LINE_NUMBER). That coupling is what
-- makes the join hit.
--
-- Outcomes stay on the TFM rows; nothing is copied back to STG (backlog #310).
-- Then PROPAGATE_DOCUMENT_ERRORS quotes the real Fusion error of a rejected
-- header or line onto every other row of the same invoice that Payables Import
-- rejected with it (design section 5, whole-document rejection).
--
-- REVISIONS:
--   2026-10-07  BM  Cross-grain propagation (PROPAGATE_DOCUMENT_ERRORS) and the
--                   V2 recon report (rows by Fusion job id, real rejection text
--                   only; backlog #166).
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_AP_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'APInvoices';

    -- Cross-grain propagation (PROPAGATE_DOCUMENT_ERRORS).
    -- Working set: "invoice DOC_KEY has a SOURCE_KIND row SOURCE_SEQ with its own
    -- real Fusion error, so every other row of that invoice must carry QUOTED_ERROR".
    TYPE T_DOC_PAIR IS RECORD (
        DOC_KEY      DMT_AP_INVOICES_INT_TFM_TBL.INVOICE_ID%TYPE,  -- the invoice
        SOURCE_KIND  VARCHAR2(4),      -- 'HDR' or 'LINE'
        SOURCE_SEQ   NUMBER,           -- the source row's TFM_SEQUENCE_ID
        QUOTED_ERROR VARCHAR2(4000)    -- DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR(...)
    );
    TYPE T_DOC_PAIR_TBL IS TABLE OF T_DOC_PAIR;

    -- --------------------------------------------------------
    -- APPLY_CONTRACT_V1_APINVOICES (private)
    -- The Contract v1 apply for both APInvoices tiers, Option A shape.
    -- One shared FETCH_ROWS call returns both tiers' rows; the apply is STATIC
    -- SQL, one pair of UPDATEs per tier, discriminated by OBJECT_TYPE and joined
    -- on RECON_KEY = RECORD_KEY.
    -- --------------------------------------------------------
    PROCEDURE APPLY_CONTRACT_V1_APINVOICES (
        p_run_id     IN NUMBER,
        p_request_id IN VARCHAR2,
        p_import_id  IN VARCHAR2
    ) IS
        C_PROC      CONSTANT VARCHAR2(40) := 'APPLY_CONTRACT_V1_APINVOICES';
        l_gen_count NUMBER := 0;
        l_rows      DMT_RECON_CONTRACT_PKG.T_RECON_TBL;
        l_err_code  NUMBER;
        l_hdr_loaded  NUMBER := 0;  l_hdr_failed  NUMBER := 0;
        l_line_loaded NUMBER := 0;  l_line_failed NUMBER := 0;
        l_rc        NUMBER := 0;    -- backlog #65: rows matched by the current tier
        l_dff_seq   NUMBER;          -- backlog #65 tier 2: TFM_SEQUENCE_ID from DFF_KEY
        l_tier      VARCHAR2(10);    -- backlog #65: which tier matched (audit log)
    BEGIN
        -- Generated-row count across both tiers drives the shared fetch's keyset
        -- page-count cap. Done statically here (not in the shared pkg).
        SELECT (SELECT COUNT(*) FROM DMT_AP_INVOICES_INT_TFM_TBL      WHERE RUN_ID = p_run_id)
             + (SELECT COUNT(*) FROM DMT_AP_INVOICE_LINES_INT_TFM_TBL WHERE RUN_ID = p_run_id)
        INTO   l_gen_count
        FROM   dual;

        DMT_RECON_CONTRACT_PKG.FETCH_ROWS(
            p_cemli_code    => C_CEMLI,
            p_run_id        => p_run_id,
            p_load_ess_id   => TO_NUMBER(p_request_id),
            p_import_ess_id => TO_NUMBER(p_import_id),
            p_row_cap       => l_gen_count,
            x_rows          => l_rows,
            x_error_code    => l_err_code);

        -- A transport / SOAP failure raises loudly (design section 5: never a
        -- silent retry, never a zero-row "success"); the fetch already logged detail.
        IF l_err_code <> DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20094,
                C_PROC || ': Contract v1 fetch failed for APInvoices '
                || '(detail in DMT_LOG_TBL).');
        END IF;

        IF l_rows.COUNT = 0 THEN
            -- Zero report rows is never success (design section 5): leave the
            -- remaining GENERATED rows for the existing unaccounted sweep.
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ': APInvoices recon report returned zero rows; '
                               || 'GENERATED rows left for the unaccounted sweep '
                               || '(never a silent success).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
        ELSE
            FOR i IN 1 .. l_rows.COUNT LOOP
                -- ===== TIER: HEADERS (OBJECT_TYPE = 'APInvoices') =====
                IF l_rows(i).OBJECT_TYPE = 'APInvoices' THEN
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
                        UPDATE DMT_AP_INVOICES_INT_TFM_TBL
                        SET    TFM_STATUS           = 'LOADED',
                               FUSION_INVOICE_ID    = l_rows(i).FUSION_ID,
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
                                UPDATE DMT_AP_INVOICES_INT_TFM_TBL
                                SET    TFM_STATUS           = 'LOADED',
                                       FUSION_INVOICE_ID    = l_rows(i).FUSION_ID,
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
                            UPDATE DMT_AP_INVOICES_INT_TFM_TBL
                            SET    TFM_STATUS           = 'LOADED',
                                   FUSION_INVOICE_ID    = l_rows(i).FUSION_ID,
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
                                C_PROC || ': matched a LOADED AP invoice header via ' || l_tier ||
                                ' fallback (tier 1 stamped ref did not resolve). FUSION_ID '
                                || l_rows(i).FUSION_ID || '.', 'INFO', C_PKG, C_PROC);
                        END IF;
                    ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                          AND l_rows(i).ERROR_MESSAGE IS NOT NULL
                          AND l_rows(i).ERROR_MESSAGE != '#IMPORT_REPORT#' THEN
                        UPDATE DMT_AP_INVOICES_INT_TFM_TBL
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

                -- ===== TIER: LINES (OBJECT_TYPE = 'APInvoices.Line') =====
                ELSIF l_rows(i).OBJECT_TYPE = 'APInvoices.Line' THEN
                    IF l_rows(i).SOURCE_TYPE = 'BASE'
                       AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                       AND l_rows(i).FUSION_ID IS NOT NULL THEN
                        -- The base line has no surrogate id of its own (identified
                        -- by INVOICE_ID + LINE_NUMBER), so the report reports the
                        -- line-grain composite INVOICE_ID~LINE_NUMBER and we stamp
                        -- it into FUSION_INVOICE_LINE_NUMBER as positive proof of
                        -- load AT LINE GRAIN. Two lines of one invoice get DIFFERENT
                        -- composites; a bare parent invoice id would repeat and fail
                        -- a per-line uniqueness check (grain-fix, backlog #84).
                        -- Backlog #65 three-tier match. Tier 1 is the stamped Slot A reference
                        -- (RECON_KEY = RECORD_KEY, exactly as before). Only if tier 1 matches NO
                        -- TFM row do we fall through: tier 2 (the Slot C DFF stamp: TFM_SEQUENCE_ID
                        -- = trailing segment of DFF_KEY) and then tier 3 (the business key:
                        -- RECON_KEY = BUSINESS_KEY -- the per-record SOURCE_REF equals RECON_KEY, so
                        -- tier 3 is the same key and safely degenerate). Every tier-1 hit short-
                        -- circuits, so loaded outcomes are identical to before.
                        l_rc := 0; l_tier := NULL;
                        UPDATE DMT_AP_INVOICE_LINES_INT_TFM_TBL
                        SET    TFM_STATUS           = 'LOADED',
                               FUSION_INVOICE_LINE_NUMBER = l_rows(i).FUSION_ID,
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
                                UPDATE DMT_AP_INVOICE_LINES_INT_TFM_TBL
                                SET    TFM_STATUS           = 'LOADED',
                                       FUSION_INVOICE_LINE_NUMBER = l_rows(i).FUSION_ID,
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
                            UPDATE DMT_AP_INVOICE_LINES_INT_TFM_TBL
                            SET    TFM_STATUS           = 'LOADED',
                                   FUSION_INVOICE_LINE_NUMBER = l_rows(i).FUSION_ID,
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
                                C_PROC || ': matched a LOADED AP invoice line via ' || l_tier ||
                                ' fallback (tier 1 stamped ref did not resolve). FUSION_ID '
                                || l_rows(i).FUSION_ID || '.', 'INFO', C_PKG, C_PROC);
                        END IF;
                    ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                          AND l_rows(i).ERROR_MESSAGE IS NOT NULL
                          AND l_rows(i).ERROR_MESSAGE != '#IMPORT_REPORT#' THEN
                        UPDATE DMT_AP_INVOICE_LINES_INT_TFM_TBL
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

        -- Outcomes stay on the TFM rows only. Nothing is copied back to STG (backlog #310):
        -- a FAILED-mode rerun finds these rows through DMT_UTIL_PKG.FAILED_RETRY_SELECTED.

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
    END APPLY_CONTRACT_V1_APINVOICES;

    -- --------------------------------------------------------
    -- PROPAGATE_DOCUMENT_ERRORS (private)
    -- Design section 5, "Whole-document rejection carries the real error to every
    -- grain" (decided 2026-10-07). Payables Import rejects the whole invoice when
    -- the header or any line fails, but writes AP_INTERFACE_REJECTIONS only for
    -- the row that failed (live, run 238: header 93294RT-APINV-BAD1 rejected with
    -- INVALID SUPPLIER and its line REJECTED with no rejection of its own; header
    -- 93294RT-1099-G1 REJECTED with no rejection of its own in that load while
    -- its only line carried INVALID DISTRIBUTION ACCT | INVALID TYPE 1099; no base
    -- row was created for either invoice). The AP FBDI has no distributions file
    -- (Payables builds distributions from the line), so the grains are header and
    -- line, and every direction applies: header -> lines, line -> header, line ->
    -- sibling lines.
    --
    -- The document is the invoice: one header TFM row and the lines carrying its
    -- INVOICE_ID (the join the transform and generator use). An invoice never
    -- spans two work items, so the key is RUN_ID + INVOICE_ID, and every row is
    -- scoped to the work item the way the shared sweep scopes it.
    --
    -- Sources: headers and lines of this run and work item with TFM_STATUS =
    --   'FAILED' carrying their OWN real Fusion error ('[FUSION_ERROR]', no
    --   C_DOC_ERROR_MARKER: a quote is never re-quoted, so quotes never chain).
    -- Targets: every OTHER header / line row of the same invoice that Fusion
    --   received (FBDI_CSV_ID set, not STAGED) and that is not LOADED (LOADED rows
    --   are never touched), and that does not already carry the exact quote. The
    --   quote is appended (APPEND_ERROR, never overwrite) and the row set FAILED.
    --   An invoice with no source error is untouched; its rows fall to the shared
    --   UNACCOUNTED sweep.
    -- Idempotent: the "already carries the exact quote" guard means a second
    --   reconcile pass adds nothing.
    -- One collection of (invoice, source, quote) pairs by ONE static SELECT, then
    -- ONE static bulk UPDATE (FORALL) per target table: a MERGE cannot read a
    -- PL/SQL record collection through TABLE() (ORA-00902, AR run 248). NO
    -- dynamic SQL; NO STG write; NO COMMIT (caller owns the txn).
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
        l_step   VARCHAR2(200);
    BEGIN
        l_step := 'collecting same-invoice (source, quote) pairs for run ' || p_run_id;
        -- A header with its own real Fusion error rejects its invoice.
        SELECT h.INVOICE_ID,
               'HDR',
               h.TFM_SEQUENCE_ID,
               DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR(
                   'header', h.RECON_KEY,
                   DBMS_LOB.SUBSTR(h.ERROR_TEXT, 3800, DBMS_LOB.INSTR(h.ERROR_TEXT, C_TAG)))
        BULK COLLECT INTO l_pairs
        FROM   DMT_AP_INVOICES_INT_TFM_TBL h
        WHERE  h.RUN_ID = p_run_id
        -- Work-item scope, as the shared sweep scopes it: rows stamped with
        -- another work item are excluded; unstamped rows are run-scoped.
        AND    (p_work_queue_id IS NULL OR h.WORK_QUEUE_ID IS NULL
                OR h.WORK_QUEUE_ID = p_work_queue_id)
        AND    h.TFM_STATUS = 'FAILED'
        AND    DBMS_LOB.INSTR(h.ERROR_TEXT, C_TAG) > 0
        AND    DBMS_LOB.INSTR(h.ERROR_TEXT, l_marker) = 0
        AND    h.INVOICE_ID IS NOT NULL
        UNION ALL
        -- A line with its own real Fusion error rejects its invoice.
        SELECT l.INVOICE_ID,
               'LINE',
               l.TFM_SEQUENCE_ID,
               DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR(
                   'line', l.RECON_KEY,
                   DBMS_LOB.SUBSTR(l.ERROR_TEXT, 3800, DBMS_LOB.INSTR(l.ERROR_TEXT, C_TAG)))
        FROM   DMT_AP_INVOICE_LINES_INT_TFM_TBL l
        WHERE  l.RUN_ID = p_run_id
        AND    (p_work_queue_id IS NULL OR l.WORK_QUEUE_ID IS NULL
                OR l.WORK_QUEUE_ID = p_work_queue_id)
        AND    l.TFM_STATUS = 'FAILED'
        AND    DBMS_LOB.INSTR(l.ERROR_TEXT, C_TAG) > 0
        AND    DBMS_LOB.INSTR(l.ERROR_TEXT, l_marker) = 0
        AND    l.INVOICE_ID IS NOT NULL;

        -- One bulk UPDATE per target table (FORALL over the pairs). Each pair
        -- appends its quote only when the row does not already carry it, so a row
        -- quoted by several sources gets each quote once and a second reconcile
        -- pass adds nothing. The source row itself is never quoted onto itself.
        l_step := 'appending quoted document errors to invoice headers';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_AP_INVOICES_INT_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    (p_work_queue_id IS NULL OR t.WORK_QUEUE_ID IS NULL
                    OR t.WORK_QUEUE_ID = p_work_queue_id)
            AND    t.INVOICE_ID = l_pairs(i).DOC_KEY
            AND    NOT (l_pairs(i).SOURCE_KIND = 'HDR' AND l_pairs(i).SOURCE_SEQ = t.TFM_SEQUENCE_ID)
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    l_pairs(i).QUOTED_ERROR IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_hdrs := SQL%ROWCOUNT;

        l_step := 'appending quoted document errors to invoice lines';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_AP_INVOICE_LINES_INT_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    (p_work_queue_id IS NULL OR t.WORK_QUEUE_ID IS NULL
                    OR t.WORK_QUEUE_ID = p_work_queue_id)
            AND    t.INVOICE_ID = l_pairs(i).DOC_KEY
            AND    NOT (l_pairs(i).SOURCE_KIND = 'LINE' AND l_pairs(i).SOURCE_SEQ = t.TFM_SEQUENCE_ID)
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    l_pairs(i).QUOTED_ERROR IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_lines := SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Rejected invoice sources: ' || l_pairs.COUNT
                           || ' | rows given a quoted document error: headers ' || l_hdrs
                           || ', lines ' || l_lines || '.',
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
    -- Contract v1 apply. The APInvoices load ESS id is the Contract v1
    -- P_LOAD_REQUEST_ID; the import ESS id is P_IMPORT_ESS_ID. The V2 report
    -- finds base rows by the import REQUEST_ID and interface rows and their
    -- rejections by LOAD_REQUEST_ID (never by the run prefix), so each work
    -- item reconciles exactly the rows its own Fusion jobs processed.
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

        APPLY_CONTRACT_V1_APINVOICES(
            p_run_id     => p_run_id,
            p_request_id => TO_CHAR(p_load_ess_id),
            p_import_id  => TO_CHAR(NVL(p_import_ess_id, p_load_ess_id)));

        -- Whole-document rejection (design section 5): rows Payables Import
        -- rejected with their invoice carry the real error of the row that
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
    -- compile-time-known APInvoices TFM table(s). Flips this run's UNACCOUNTED rows
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
        UPDATE DMT_AP_INVOICES_INT_TFM_TBL
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
        UPDATE DMT_AP_INVOICE_LINES_INT_TFM_TBL
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
            C_PROC || ': reset ' || l_reset || ' UNACCOUNTED APInvoices row(s) to GENERATED '
            || 'for re-reconcile.',
            'INFO', C_PKG, C_PROC);
        -- NO COMMIT -- the caller (RERUN_RUN) owns the transaction.
    END RESET_UNACCOUNTED;

END DMT_AP_RESULTS_PKG;
/
