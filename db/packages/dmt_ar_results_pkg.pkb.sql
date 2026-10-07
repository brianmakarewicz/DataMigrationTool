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
-- equal that tier's report RECORD_KEY:
--   * LINES stamp RECON_KEY = INTERFACE_LINE_ATTRIBUTE1 (the prefixed TRX_NUMBER).
--     AutoInvoice persists INTERFACE_LINE_ATTRIBUTE1 onto the base line, so the
--     base line is keyed directly on the stamped key.
--   * DISTRIBUTIONS stamp RECON_KEY = INTERFACE_LINE_ATTRIBUTE1 || ':' ||
--     ACCOUNT_CLASS. The base distribution carries no interface key of its own,
--     so it is confirmed TRANSITIVELY through its parent line; the data model
--     emits the parent line's stamped key, the distribution's ACCOUNT_CLASS, and a
--     DETERMINISTIC per-line ordinal as the distribution RECORD_KEY. The ordinal is
--     required as a per-distribution discriminator (PR #371 review, second round):
--     a real AR line commonly carries 2+ distributions of the SAME ACCOUNT_CLASS
--     (888 such lines exist in the live demo base table), so parent-line-key ||
--     account_class alone is NOT unique -- without the ordinal, sibling
--     distributions would share one key, dropping rows at a keyset page boundary
--     and stamping one sibling's FUSION_ID onto another. The ordinal is
--     ROW_NUMBER() OVER (PARTITION BY parent_line_key, account_class ORDER BY
--     amount, acctd_amount, percent, <dist id>), computed IDENTICALLY in the TFM
--     stamp (DMT_AR_TRANSFORM_PKG) and both data model distribution blocks; leading
--     the ORDER BY with the business amounts AutoInvoice copies verbatim from the
--     interface distribution onto the base distribution keeps the ordinal in
--     agreement across all three sides. That coupling is what makes the per-tier
--     join hit exactly one TFM row.
--
-- After the two tiers settle, outcomes are echoed back to both STG tables. Each
-- tier has its own BASE and INTERFACE rows in the report, so each tier accounts
-- for itself directly (a distribution transitively via its parent line's key).
-- Then PROPAGATE_DOCUMENT_ERRORS quotes each rejected row's real Fusion error onto
-- the other lines/distributions of the same Fusion invoice (AutoInvoice grouping),
-- which AutoInvoice holds back without an error of their own (design section 5).
--
-- REVISIONS:
--   2026-10-07  BM  Cross-grain propagation (PROPAGATE_DOCUMENT_ERRORS); line
--                   tier pinned by INTERFACE_LINE_ATTRIBUTE2 (report DMT_REFERENCE).
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
        l_rc        NUMBER := 0;    -- backlog #65: rows matched by the current tier
        l_dff_seq   NUMBER;          -- backlog #65 tier 2: TFM_SEQUENCE_ID from DFF_KEY
        l_tier      VARCHAR2(10);    -- backlog #65: which tier matched (audit log)
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
                l_rc   := 0;     -- backlog #65: reset per row so a prior row's tier
                l_tier := NULL;  -- cannot mislabel this row's audit log line.
                -- ===== TIER: LINES (OBJECT_TYPE = 'ARInvoices') =====
                IF l_rows(i).OBJECT_TYPE = 'ARInvoices' THEN
                    IF l_rows(i).SOURCE_TYPE = 'BASE'
                       AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                       AND l_rows(i).FUSION_ID IS NOT NULL THEN
                        -- Backlog #65 three-tier match (owner order on PR #481). Tier 1 is
                        -- the stamped recon key (RECON_KEY = RECORD_KEY, exactly as before).
                        -- Tier 2 (the Slot C DFF stamp: TFM_SEQUENCE_ID = the trailing numeric
                        -- segment of DFF_KEY) is kept uniform with the shared template; AR's
                        -- DMT_REFERENCE is the line's INTERFACE_LINE_ATTRIBUTE2 reference
                        -- string, not a numeric carrier, so tier 2 is normally a no-op. There
                        -- is NO tier 3 for AR lines: the recon DM returns SOURCE_REF (the
                        -- business key) on the line as INTERFACE_LINE_ATTRIBUTE1 -- the SAME
                        -- unprefixed value it emits as RECORD_KEY -- so a business-key
                        -- fall-through would match on exactly the RECON_KEY column again,
                        -- byte-redundant with tier 1 (the prefixed TRX_NUMBER column is a
                        -- different value and is NOT what the report returns). Every tier-1 hit
                        -- short-circuits, so loaded outcomes are identical to before. Static
                        -- UPDATEs.
                        -- Line grain: RECON_KEY (ATTRIBUTE1) is shared by every line
                        -- of one DMT source invoice, so the line is pinned by its
                        -- ATTRIBUTE2 too -- the report returns it as DMT_REFERENCE
                        -- (DFF_KEY) on both BASE and INTERFACE line rows. Without it a
                        -- multi-line invoice stamps one line's outcome on its siblings.
                        UPDATE DMT_RA_LINES_TFM_TBL
                        SET    TFM_STATUS             = 'LOADED',
                               FUSION_CUSTOMER_TRX_ID = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE   = SYSDATE,
                               LAST_UPDATED_DATE      = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    (l_rows(i).DFF_KEY IS NULL
                                OR INTERFACE_LINE_ATTRIBUTE2 = l_rows(i).DFF_KEY)
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_rc := SQL%ROWCOUNT;
                        l_tier := CASE WHEN l_rc > 0 THEN 'TIER1' END;

                        IF l_rc = 0 AND l_rows(i).DFF_KEY IS NOT NULL THEN
                            l_dff_seq := TO_NUMBER(
                                REGEXP_SUBSTR(l_rows(i).DFF_KEY, '[0-9]+$') DEFAULT NULL ON CONVERSION ERROR);
                            IF l_dff_seq IS NOT NULL THEN
                                UPDATE DMT_RA_LINES_TFM_TBL
                                SET    TFM_STATUS             = 'LOADED',
                                       FUSION_CUSTOMER_TRX_ID = l_rows(i).FUSION_ID,
                                       RESULTS_UPDATED_DATE   = SYSDATE,
                                       LAST_UPDATED_DATE      = SYSDATE
                                WHERE  RUN_ID    = p_run_id
                                AND    TFM_SEQUENCE_ID = l_dff_seq
                                AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                                l_rc := SQL%ROWCOUNT;
                                IF l_rc > 0 THEN l_tier := 'TIER2'; END IF;
                            END IF;
                        END IF;

                        l_line_loaded := l_line_loaded + l_rc;
                        IF l_tier = 'TIER2' THEN
                            DMT_UTIL_PKG.LOG(p_run_id,
                                C_PROC || ': matched a LOADED AR line via TIER2 '
                                || 'fallback (tier 1 stamped key did not resolve). CUSTOMER_TRX_ID '
                                || l_rows(i).FUSION_ID || '.', 'INFO', C_PKG, C_PROC);
                        END IF;
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
                        AND    (l_rows(i).DFF_KEY IS NULL
                                OR INTERFACE_LINE_ATTRIBUTE2 = l_rows(i).DFF_KEY)
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_line_failed := l_line_failed + SQL%ROWCOUNT;
                    END IF;

                -- ===== TIER: DISTRIBUTIONS (OBJECT_TYPE = 'ARInvoices.Distribution') =====
                ELSIF l_rows(i).OBJECT_TYPE = 'ARInvoices.Distribution' THEN
                    IF l_rows(i).SOURCE_TYPE = 'BASE'
                       AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                       AND l_rows(i).FUSION_ID IS NOT NULL THEN
                        -- Backlog #65 three-tier match. Tier 1 is the stamped recon key
                        -- (RECON_KEY = RECORD_KEY, exactly as before). Tier 2 (DFF numeric
                        -- segment -> TFM_SEQUENCE_ID) is kept uniform with the shared
                        -- template; AR carries no numeric DFF carrier so it is normally a
                        -- no-op. There is NO tier 3 for distributions: a base distribution
                        -- carries no source-side business key of its own (its only identity
                        -- is the composite parent-line/account-class/ordinal recon key, so a
                        -- business-key fall-through would be redundant with tier 1). Every
                        -- tier-1 hit short-circuits, so loaded outcomes are identical to
                        -- before. Static UPDATEs.
                        UPDATE DMT_RA_DISTS_TFM_TBL
                        SET    TFM_STATUS                     = 'LOADED',
                               FUSION_CUST_TRX_LINE_GL_DIST_ID = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE           = SYSDATE,
                               LAST_UPDATED_DATE              = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_rc := SQL%ROWCOUNT;
                        l_tier := CASE WHEN l_rc > 0 THEN 'TIER1' END;

                        IF l_rc = 0 AND l_rows(i).DFF_KEY IS NOT NULL THEN
                            l_dff_seq := TO_NUMBER(
                                REGEXP_SUBSTR(l_rows(i).DFF_KEY, '[0-9]+$') DEFAULT NULL ON CONVERSION ERROR);
                            IF l_dff_seq IS NOT NULL THEN
                                UPDATE DMT_RA_DISTS_TFM_TBL
                                SET    TFM_STATUS                     = 'LOADED',
                                       FUSION_CUST_TRX_LINE_GL_DIST_ID = l_rows(i).FUSION_ID,
                                       RESULTS_UPDATED_DATE           = SYSDATE,
                                       LAST_UPDATED_DATE              = SYSDATE
                                WHERE  RUN_ID    = p_run_id
                                AND    TFM_SEQUENCE_ID = l_dff_seq
                                AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                                l_rc := SQL%ROWCOUNT;
                                IF l_rc > 0 THEN l_tier := 'TIER2'; END IF;
                            END IF;
                        END IF;

                        l_dist_loaded := l_dist_loaded + l_rc;
                        IF l_tier = 'TIER2' THEN
                            DMT_UTIL_PKG.LOG(p_run_id,
                                C_PROC || ': matched a LOADED AR distribution via TIER2 '
                                || 'fallback (tier 1 stamped key did not resolve). '
                                || 'CUST_TRX_LINE_GL_DIST_ID ' || l_rows(i).FUSION_ID || '.',
                                'INFO', C_PKG, C_PROC);
                        END IF;
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
    -- PROPAGATE_DOCUMENT_ERRORS (private)
    -- Design section 5, "Whole-document rejection carries the real error to every
    -- grain" (decided 2026-10-07), AR note (decided 2026-10-07, owner): the AR
    -- document is the FUSION invoice AutoInvoice builds by its grouping rule, NOT
    -- the DMT source invoice. The transaction source's invalid-line rule is
    -- "Reject invoice": when one line (or one of its distributions) is rejected,
    -- AutoInvoice holds back every other line it would have grouped onto that
    -- invoice and writes NO error for them (Fusion 10073725 / 10073734,
    -- docs/findings/known_good_ARInvoices.md). Grouping does not look at
    -- INTERFACE_LINE_ATTRIBUTE1, so lines of DIFFERENT DMT source invoices merge
    -- into one Fusion invoice (probes 97732-97734 -> customer_trx_id 1585948), and
    -- an error crosses DMT invoice boundaries the same way.
    --
    -- Sources: AR lines and distributions of this run (and work item) with
    --   TFM_STATUS = 'FAILED' carrying their OWN real Fusion error -- ERROR_TEXT
    --   contains '[FUSION_ERROR]' and does NOT contain C_DOC_ERROR_MARKER (a quote
    --   is never re-quoted, so quotes never chain).
    -- Targets: every OTHER line / distribution of the same Fusion invoice (same
    --   run, work item, BU, batch source and grouping attributes) that is not
    --   LOADED (LOADED rows are never touched) and was sent (not STAGED), and does
    --   not already carry the exact quote. The quote is appended (APPEND_ERROR,
    --   never overwrite) and the row set FAILED. A document with no source error
    --   is untouched -- its rows fall to the shared UNACCOUNTED sweep.
    -- Idempotent: the "already carries the exact quote" guard means a second
    --   reconcile pass adds nothing.
    -- One collection of (target line, source, quote) pairs is built by ONE static
    -- SELECT (the only place the grouping attributes are listed), then ONE static
    -- MERGE per target table. NO dynamic SQL; NO COMMIT (caller owns the txn).
    -- --------------------------------------------------------
    PROCEDURE PROPAGATE_DOCUMENT_ERRORS (
        p_run_id        IN NUMBER,
        p_work_queue_id IN NUMBER
    ) IS
        C_PROC     CONSTANT VARCHAR2(30) := 'PROPAGATE_DOCUMENT_ERRORS';
        C_TAG      CONSTANT VARCHAR2(20) := '[FUSION_ERROR]';
        C_NULL     CONSTANT VARCHAR2(1)  := '~';   -- NULL = NULL, as AutoInvoice groups
        C_DATE_FMT CONSTANT VARCHAR2(10) := 'YYYY/MM/DD';  -- as written to the FBDI CSV
        l_marker   VARCHAR2(30) := DMT_UTIL_PKG.C_DOC_ERROR_MARKER;
        l_pairs    T_DOC_PAIR_TBL;
        l_lines    NUMBER := 0;
        l_dists    NUMBER := 0;
        l_step     VARCHAR2(200);
    BEGIN
        l_step := 'collecting same-invoice (source, target) pairs for run ' || p_run_id;
        WITH scoped_lines AS (
            SELECT l.*
            FROM   DMT_RA_LINES_TFM_TBL l
            WHERE  l.RUN_ID = p_run_id
            -- Work-item scope, as the shared sweep scopes it: rows stamped with
            -- another work item are excluded; unstamped rows are run-scoped.
            AND    (p_work_queue_id IS NULL OR l.WORK_QUEUE_ID IS NULL
                    OR l.WORK_QUEUE_ID = p_work_queue_id)
        ),
        sources AS (
            -- A line with its own real Fusion error.
            SELECT l.TFM_SEQUENCE_ID AS SOURCE_LINE_SEQ,
                   'LINE'            AS SOURCE_KIND,
                   l.TFM_SEQUENCE_ID AS SOURCE_SEQ,
                   DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR(
                       'line',
                       l.INTERFACE_LINE_ATTRIBUTE1 || '/' || l.INTERFACE_LINE_ATTRIBUTE2,
                       DBMS_LOB.SUBSTR(l.ERROR_TEXT, 3800,
                                       DBMS_LOB.INSTR(l.ERROR_TEXT, C_TAG))) AS QUOTED_ERROR
            FROM   scoped_lines l
            WHERE  l.TFM_STATUS = 'FAILED'
            AND    DBMS_LOB.INSTR(l.ERROR_TEXT, C_TAG) > 0
            AND    DBMS_LOB.INSTR(l.ERROR_TEXT, l_marker) = 0
            UNION ALL
            -- A distribution with its own real Fusion error rejects its line, and
            -- therefore that line's invoice: it is placed on its parent line.
            SELECT l.TFM_SEQUENCE_ID,
                   'DIST',
                   d.TFM_SEQUENCE_ID,
                   DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR(
                       'distribution',
                       d.INTERFACE_LINE_ATTRIBUTE1 || '/' || d.INTERFACE_LINE_ATTRIBUTE2
                           || '/' || d.ACCOUNT_CLASS,
                       DBMS_LOB.SUBSTR(d.ERROR_TEXT, 3800,
                                       DBMS_LOB.INSTR(d.ERROR_TEXT, C_TAG)))
            FROM   DMT_RA_DISTS_TFM_TBL d
            JOIN   scoped_lines l
                   ON  NVL(l.INTERFACE_LINE_CONTEXT, C_NULL)    = NVL(d.INTERFACE_LINE_CONTEXT, C_NULL)
                   AND NVL(l.INTERFACE_LINE_ATTRIBUTE1, C_NULL) = NVL(d.INTERFACE_LINE_ATTRIBUTE1, C_NULL)
                   AND NVL(l.INTERFACE_LINE_ATTRIBUTE2, C_NULL) = NVL(d.INTERFACE_LINE_ATTRIBUTE2, C_NULL)
            WHERE  d.RUN_ID = p_run_id
            AND    d.TFM_STATUS = 'FAILED'
            AND    DBMS_LOB.INSTR(d.ERROR_TEXT, C_TAG) > 0
            AND    DBMS_LOB.INSTR(d.ERROR_TEXT, l_marker) = 0
        )
        SELECT tgt.TFM_SEQUENCE_ID, s.SOURCE_KIND, s.SOURCE_SEQ, s.QUOTED_ERROR
        BULK COLLECT INTO l_pairs
        FROM   sources s
        JOIN   scoped_lines src ON src.TFM_SEQUENCE_ID = s.SOURCE_LINE_SEQ
        -- ============================================================
        -- THE AR DOCUMENT KEY -- the AutoInvoice grouping key, listed ONLY here.
        -- Oracle's MANDATORY grouping attributes (cannot be removed from any
        -- grouping rule): https://docs.oracle.com/cd/E36909_01/fusionapps.1111/
        -- e20375/F569968AN7911F.htm . This pod's External Source uses "EXTERNAL
        -- SOURCE GROUPING RULE", which adds only SALES_ORDER (classes I and C);
        -- the rule is NOT read at runtime. Each attribute is compared on the TFM
        -- value DMT wrote to the FBDI file (dates in the CSV's YYYY/MM/DD form),
        -- NULL equal to NULL. Within one run, work item, BU and batch source.
        -- Mandatory attributes DMT never populates (no TFM column, nothing sent)
        -- are left out: CUSTOMER_BANK_ACCOUNT_ID, DOCUMENT_NUMBER_SEQUENCE_ID,
        -- HEADER_GDF_ATTRIBUTE1-30, INITIAL_CUSTOMER_TRX_ID,
        -- PAYMENT_SERVER_ORDER_ID, PREVIOUS_CUSTOMER_TRX_ID, TERRITORY_ID;
        -- SET_OF_BOOKS_ID is implied by BU_NAME. Ids AutoInvoice derives (bill /
        -- ship / sold customer, address, contact, type, term, salesrep, receipt
        -- method, invoicing rule, related transaction) are compared through every
        -- source column DMT sends for them (the ORIG_SYSTEM_*_REF and the
        -- *_NUMBER / *_NAME forms).
        -- ============================================================
        JOIN   scoped_lines tgt
               ON  NVL(tgt.WORK_QUEUE_ID, -1) = NVL(src.WORK_QUEUE_ID, -1)
               AND NVL(tgt.BU_NAME, C_NULL)                        = NVL(src.BU_NAME, C_NULL)
               AND NVL(tgt.BATCH_SOURCE_NAME, C_NULL)              = NVL(src.BATCH_SOURCE_NAME, C_NULL)
               AND NVL(tgt.TRX_NUMBER, C_NULL)                     = NVL(src.TRX_NUMBER, C_NULL)
               AND NVL(tgt.CURRENCY_CODE, C_NULL)                  = NVL(src.CURRENCY_CODE, C_NULL)
               AND NVL(tgt.CUST_TRX_TYPE_NAME, C_NULL)             = NVL(src.CUST_TRX_TYPE_NAME, C_NULL)
               AND NVL(TO_CHAR(tgt.TRX_DATE, C_DATE_FMT), C_NULL)  = NVL(TO_CHAR(src.TRX_DATE, C_DATE_FMT), C_NULL)
               AND NVL(TO_CHAR(tgt.GL_DATE, C_DATE_FMT), C_NULL)   = NVL(TO_CHAR(src.GL_DATE, C_DATE_FMT), C_NULL)
               AND NVL(tgt.TERM_NAME, C_NULL)                      = NVL(src.TERM_NAME, C_NULL)
               AND NVL(tgt.ORIG_SYSTEM_BILL_CUSTOMER_REF, C_NULL)  = NVL(src.ORIG_SYSTEM_BILL_CUSTOMER_REF, C_NULL)
               AND NVL(tgt.ORIG_SYSTEM_BILL_ADDRESS_REF, C_NULL)   = NVL(src.ORIG_SYSTEM_BILL_ADDRESS_REF, C_NULL)
               AND NVL(tgt.ORIG_SYSTEM_BILL_CONTACT_REF, C_NULL)   = NVL(src.ORIG_SYSTEM_BILL_CONTACT_REF, C_NULL)
               AND NVL(tgt.BILL_CUSTOMER_ACCOUNT_NUMBER, C_NULL)   = NVL(src.BILL_CUSTOMER_ACCOUNT_NUMBER, C_NULL)
               AND NVL(tgt.BILL_CUSTOMER_SITE_NUMBER, C_NULL)      = NVL(src.BILL_CUSTOMER_SITE_NUMBER, C_NULL)
               AND NVL(tgt.BILL_CONTACT_PARTY_NUMBER, C_NULL)      = NVL(src.BILL_CONTACT_PARTY_NUMBER, C_NULL)
               AND NVL(tgt.ORIG_SYSTEM_SHIP_CUSTOMER_REF, C_NULL)  = NVL(src.ORIG_SYSTEM_SHIP_CUSTOMER_REF, C_NULL)
               AND NVL(tgt.ORIG_SYSTEM_SHIP_CONTACT_REF, C_NULL)   = NVL(src.ORIG_SYSTEM_SHIP_CONTACT_REF, C_NULL)
               AND NVL(tgt.SHIP_CUSTOMER_ACCOUNT_NUMBER, C_NULL)   = NVL(src.SHIP_CUSTOMER_ACCOUNT_NUMBER, C_NULL)
               AND NVL(tgt.SHIP_CONTACT_PARTY_NUMBER, C_NULL)      = NVL(src.SHIP_CONTACT_PARTY_NUMBER, C_NULL)
               AND NVL(tgt.ORIG_SYSTEM_SOLD_CUSTOMER_REF, C_NULL)  = NVL(src.ORIG_SYSTEM_SOLD_CUSTOMER_REF, C_NULL)
               AND NVL(tgt.SOLD_CUSTOMER_ACCOUNT_NUMBER, C_NULL)   = NVL(src.SOLD_CUSTOMER_ACCOUNT_NUMBER, C_NULL)
               AND NVL(tgt.PURCHASE_ORDER, C_NULL)                 = NVL(src.PURCHASE_ORDER, C_NULL)
               AND NVL(TO_CHAR(tgt.PURCHASE_ORDER_DATE, C_DATE_FMT), C_NULL)
                                                                   = NVL(TO_CHAR(src.PURCHASE_ORDER_DATE, C_DATE_FMT), C_NULL)
               AND NVL(tgt.PURCHASE_ORDER_REVISION, C_NULL)        = NVL(src.PURCHASE_ORDER_REVISION, C_NULL)
               AND NVL(tgt.COMMENTS, C_NULL)                       = NVL(src.COMMENTS, C_NULL)
               AND NVL(tgt.INTERNAL_NOTES, C_NULL)                 = NVL(src.INTERNAL_NOTES, C_NULL)
               AND NVL(tgt.HEADER_ATTRIBUTE_CATEGORY, C_NULL)      = NVL(src.HEADER_ATTRIBUTE_CATEGORY, C_NULL)
               AND NVL(tgt.HEADER_ATTRIBUTE1, C_NULL)              = NVL(src.HEADER_ATTRIBUTE1, C_NULL)
               AND NVL(tgt.HEADER_ATTRIBUTE2, C_NULL)              = NVL(src.HEADER_ATTRIBUTE2, C_NULL)
               AND NVL(tgt.HEADER_ATTRIBUTE3, C_NULL)              = NVL(src.HEADER_ATTRIBUTE3, C_NULL)
               AND NVL(tgt.HEADER_ATTRIBUTE4, C_NULL)              = NVL(src.HEADER_ATTRIBUTE4, C_NULL)
               AND NVL(tgt.HEADER_ATTRIBUTE5, C_NULL)              = NVL(src.HEADER_ATTRIBUTE5, C_NULL)
               AND NVL(tgt.HEADER_ATTRIBUTE6, C_NULL)              = NVL(src.HEADER_ATTRIBUTE6, C_NULL)
               AND NVL(tgt.HEADER_ATTRIBUTE7, C_NULL)              = NVL(src.HEADER_ATTRIBUTE7, C_NULL)
               AND NVL(tgt.HEADER_ATTRIBUTE8, C_NULL)              = NVL(src.HEADER_ATTRIBUTE8, C_NULL)
               AND NVL(tgt.HEADER_ATTRIBUTE9, C_NULL)              = NVL(src.HEADER_ATTRIBUTE9, C_NULL)
               AND NVL(tgt.HEADER_ATTRIBUTE10, C_NULL)             = NVL(src.HEADER_ATTRIBUTE10, C_NULL)
               AND NVL(tgt.HEADER_ATTRIBUTE11, C_NULL)             = NVL(src.HEADER_ATTRIBUTE11, C_NULL)
               AND NVL(tgt.HEADER_ATTRIBUTE12, C_NULL)             = NVL(src.HEADER_ATTRIBUTE12, C_NULL)
               AND NVL(tgt.HEADER_ATTRIBUTE13, C_NULL)             = NVL(src.HEADER_ATTRIBUTE13, C_NULL)
               AND NVL(tgt.HEADER_ATTRIBUTE14, C_NULL)             = NVL(src.HEADER_ATTRIBUTE14, C_NULL)
               AND NVL(tgt.HEADER_ATTRIBUTE15, C_NULL)             = NVL(src.HEADER_ATTRIBUTE15, C_NULL)
               AND NVL(tgt.PRIMARY_SALESREP_NUMBER, C_NULL)        = NVL(src.PRIMARY_SALESREP_NUMBER, C_NULL)
               AND NVL(tgt.RECEIPT_METHOD_NAME, C_NULL)            = NVL(src.RECEIPT_METHOD_NAME, C_NULL)
               AND NVL(tgt.CONVERSION_TYPE, C_NULL)                = NVL(src.CONVERSION_TYPE, C_NULL)
               AND NVL(TO_CHAR(tgt.CONVERSION_DATE, C_DATE_FMT), C_NULL)
                                                                   = NVL(TO_CHAR(src.CONVERSION_DATE, C_DATE_FMT), C_NULL)
               AND NVL(TO_CHAR(tgt.CONVERSION_RATE), C_NULL)       = NVL(TO_CHAR(src.CONVERSION_RATE), C_NULL)
               AND NVL(tgt.CREDIT_METHOD_FOR_ACCT_RULE, C_NULL)    = NVL(src.CREDIT_METHOD_FOR_ACCT_RULE, C_NULL)
               AND NVL(tgt.CREDIT_METHOD_FOR_INSTALLMENTS, C_NULL) = NVL(src.CREDIT_METHOD_FOR_INSTALLMENTS, C_NULL)
               AND NVL(tgt.INVOICING_RULE_NAME, C_NULL)            = NVL(src.INVOICING_RULE_NAME, C_NULL)
               AND NVL(tgt.REASON_CODE, C_NULL)                    = NVL(src.REASON_CODE, C_NULL)
               AND NVL(tgt.REASON_CODE_MEANING, C_NULL)            = NVL(src.REASON_CODE_MEANING, C_NULL)
               AND NVL(tgt.ORIG_SYSTEM_BATCH_NAME, C_NULL)         = NVL(src.ORIG_SYSTEM_BATCH_NAME, C_NULL)
               AND NVL(tgt.DOCUMENT_NUMBER, C_NULL)                = NVL(src.DOCUMENT_NUMBER, C_NULL)
               AND NVL(tgt.CONS_BILLING_NUMBER, C_NULL)            = NVL(src.CONS_BILLING_NUMBER, C_NULL)
               AND NVL(TO_CHAR(tgt.PAYMENT_SET_ID), C_NULL)        = NVL(TO_CHAR(src.PAYMENT_SET_ID), C_NULL)
               AND NVL(tgt.PRINTING_OPTION, C_NULL)                = NVL(src.PRINTING_OPTION, C_NULL)
               AND NVL(tgt.RELATED_TRX_NUMBER, C_NULL)             = NVL(src.RELATED_TRX_NUMBER, C_NULL)
               AND NVL(tgt.RELATED_BATCH_SOURCE_NAME, C_NULL)      = NVL(src.RELATED_BATCH_SOURCE_NAME, C_NULL)
               AND NVL(tgt.SALES_ORDER, C_NULL)                    = NVL(src.SALES_ORDER, C_NULL)  -- pod rule
        WHERE  s.QUOTED_ERROR IS NOT NULL;

        l_step := 'appending quoted document errors to AR lines';
        MERGE INTO DMT_RA_LINES_TFM_TBL t
        USING (
            SELECT p.TARGET_LINE_SEQ,
                   LISTAGG(DISTINCT p.QUOTED_ERROR, ' | ' ON OVERFLOW TRUNCATE '...' WITHOUT COUNT)
                       WITHIN GROUP (ORDER BY p.QUOTED_ERROR) AS NEW_ERRORS
            FROM   TABLE(l_pairs) p
            JOIN   DMT_RA_LINES_TFM_TBL tl ON tl.TFM_SEQUENCE_ID = p.TARGET_LINE_SEQ
            WHERE  NOT (p.SOURCE_KIND = 'LINE' AND p.SOURCE_SEQ = p.TARGET_LINE_SEQ)
            AND    tl.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    NVL(DBMS_LOB.INSTR(tl.ERROR_TEXT, p.QUOTED_ERROR), 0) = 0
            GROUP BY p.TARGET_LINE_SEQ
        ) s
        ON (t.TFM_SEQUENCE_ID = s.TARGET_LINE_SEQ)
        WHEN MATCHED THEN UPDATE
        SET    t.TFM_STATUS           = 'FAILED',
               t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, s.NEW_ERRORS),
               t.RESULTS_UPDATED_DATE = SYSDATE,
               t.LAST_UPDATED_DATE    = SYSDATE
        WHERE  t.TFM_STATUS NOT IN ('LOADED', 'STAGED');
        l_lines := SQL%ROWCOUNT;

        l_step := 'appending quoted document errors to AR distributions';
        MERGE INTO DMT_RA_DISTS_TFM_TBL t
        USING (
            SELECT d.TFM_SEQUENCE_ID,
                   LISTAGG(DISTINCT p.QUOTED_ERROR, ' | ' ON OVERFLOW TRUNCATE '...' WITHOUT COUNT)
                       WITHIN GROUP (ORDER BY p.QUOTED_ERROR) AS NEW_ERRORS
            FROM   DMT_RA_DISTS_TFM_TBL d
            -- The distribution's document comes through its line.
            JOIN   DMT_RA_LINES_TFM_TBL l
                   ON  l.RUN_ID = d.RUN_ID
                   AND NVL(l.INTERFACE_LINE_CONTEXT, C_NULL)    = NVL(d.INTERFACE_LINE_CONTEXT, C_NULL)
                   AND NVL(l.INTERFACE_LINE_ATTRIBUTE1, C_NULL) = NVL(d.INTERFACE_LINE_ATTRIBUTE1, C_NULL)
                   AND NVL(l.INTERFACE_LINE_ATTRIBUTE2, C_NULL) = NVL(d.INTERFACE_LINE_ATTRIBUTE2, C_NULL)
            JOIN   TABLE(l_pairs) p ON p.TARGET_LINE_SEQ = l.TFM_SEQUENCE_ID
            WHERE  d.RUN_ID = p_run_id
            AND    (p_work_queue_id IS NULL OR d.WORK_QUEUE_ID IS NULL
                    OR d.WORK_QUEUE_ID = p_work_queue_id)
            AND    NOT (p.SOURCE_KIND = 'DIST' AND p.SOURCE_SEQ = d.TFM_SEQUENCE_ID)
            AND    d.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    NVL(DBMS_LOB.INSTR(d.ERROR_TEXT, p.QUOTED_ERROR), 0) = 0
            GROUP BY d.TFM_SEQUENCE_ID
        ) s
        ON (t.TFM_SEQUENCE_ID = s.TFM_SEQUENCE_ID)
        WHEN MATCHED THEN UPDATE
        SET    t.TFM_STATUS           = 'FAILED',
               t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, s.NEW_ERRORS),
               t.RESULTS_UPDATED_DATE = SYSDATE,
               t.LAST_UPDATED_DATE    = SYSDATE
        WHERE  t.TFM_STATUS NOT IN ('LOADED', 'STAGED');
        l_dists := SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Same-invoice pairs: ' || l_pairs.COUNT
                           || ' | lines given a quoted document error: ' || l_lines
                           || ' | distributions: ' || l_dists || '.',
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

        -- Whole-document rejection (design section 5): rows AutoInvoice held back
        -- or rejected with their Fusion invoice carry the real error of the row
        -- that caused it. Runs after the per-row apply and BEFORE the shared
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
    -- compile-time-known ARInvoices TFM table(s). Flips this run's UNACCOUNTED rows
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
        UPDATE DMT_RA_LINES_TFM_TBL
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
        UPDATE DMT_RA_DISTS_TFM_TBL
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
            C_PROC || ': reset ' || l_reset || ' UNACCOUNTED ARInvoices row(s) to GENERATED '
            || 'for re-reconcile.',
            'INFO', C_PKG, C_PROC);
        -- NO COMMIT -- the caller (RERUN_RUN) owns the transaction.
    END RESET_UNACCOUNTED;

END DMT_AR_RESULTS_PKG;
/
