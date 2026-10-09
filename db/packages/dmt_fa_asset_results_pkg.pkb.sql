-- PACKAGE BODY DMT_FA_ASSET_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_FA_ASSET_RESULTS_PKG" AS
-- ============================================================
-- DMT_FA_ASSET_RESULTS_PKG body
-- Assets post-load reconciliation — Contract v1 (nine-column report).
--
-- Reuses the ONE shared Contract v1 fetch DMT_RECON_CONTRACT_PKG.FETCH_ROWS, the
-- same template as Requisitions (PR #364) and Workers. A single FETCH_ROWS call
-- runs the Assets Contract v1 report over BIP and returns its rows in one
-- collection; the apply is STATIC SQL against the compile-time-known header TFM
-- table, joined on RECON_KEY = the report RECORD_KEY.
--
-- Assets emits ONE apply tier (the ASSET/header). The Contract v1 data model
-- reports one BASE row per ASSET_NUMBER from FA_ADDITIONS_B and one INTERFACE row
-- per rejected asset from FA_MASS_ADDITIONS. Because the book is folded into
-- OBJECT_TYPE for readability ('Assets' or 'Assets [<BOOK>]'), the apply matches
-- on the OBJECT_TYPE prefix 'Assets', not one exact literal. Book and assignment
-- outcomes are NOT reported as their own tiers; they inherit the header's outcome
-- via the cascade below (unchanged behaviour from the prior two-tier reader).
--
-- Per the shared Contract v1 apply rule:
--   * BASE / SUCCESS / FUSION_ID NOT NULL -> LOADED, stamp FUSION_ASSET_ID.
--   * FUSION_STATUS = ERROR with a real ERROR_MESSAGE -> FAILED, message appended
--     as '[FUSION_ERROR] ' || message (never composed).
--   * Everything else is left GENERATED; INTERFACE/SUCCESS corroborates but is
--     never sufficient for LOADED. Guarded on TFM_STATUS NOT IN ('LOADED','FAILED').
--
-- ALL-OR-NOTHING (Assets-only, PRESERVED verbatim): the SQL*Loader LOAD stage is
-- atomic per book. When a whole book's load genuinely failed and nothing reached
-- the interface, the report confirms nothing; ACCOUNT_ALL_OR_NOTHING then reads
-- the SQL*Loader log to give those rows a real verdict. That log-based path is
-- untouched by the Contract v1 migration.
--
-- REVISIONS:
--   2026-10-07  BM  Report V2: called per work item with its own load + import
--                   ids; rows found by the load job id, never by the prefix.
--   2026-10-08  BM  Cross-grain propagation (PROPAGATE_DOCUMENT_ERRORS, backlog
--                   #175): assets rolled back with a rejected book batch now
--                   quote the rejected asset's real error ('Rejected with
--                   document: book batch <book> asset <num>: <error>') instead
--                   of the generic batch-rejected text.
--   2026-10-09  BM  Backlog #571: a SQL*Loader rejection in the distributions
--                   file now fails that distribution row with its real error
--                   (record mapped to the row, line breaks counted) and is
--                   quoted onto its own header and the rest of the book batch.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_FA_ASSET_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'Assets';

    -- Cross-grain propagation (PROPAGATE_DOCUMENT_ERRORS, backlog #175).
    -- Working set: "asset SOURCE_ASSET of this book batch has its own real
    -- Fusion / SQL*Loader error, so every other asset of the batch that did not
    -- load must carry QUOTED_ERROR".
    TYPE T_DOC_PAIR IS RECORD (
        SOURCE_ASSET VARCHAR2(30),      -- the rejected asset's ASSET_NUMBER
        QUOTED_ERROR VARCHAR2(4000)     -- DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR(...)
    );
    TYPE T_DOC_PAIR_TBL IS TABLE OF T_DOC_PAIR;

    -- --------------------------------------------------------
    -- GET_PARTITION_KEYS — distinct BOOK_TYPE_CODE tokens for one run,
    -- STATIC SQL over the asset-book transform table (this object's own
    -- table). Spawn-per-partition (work-queue-ID core, 2026-07-20): one child
    -- work item per book. Called through invoke_registered (style KEYS). Unchanged.
    -- --------------------------------------------------------
    FUNCTION GET_PARTITION_KEYS (
        p_run_id IN NUMBER
    ) RETURN DMT_PARTITION_KEY_TBL IS
        l_keys DMT_PARTITION_KEY_TBL;
    BEGIN
        SELECT DISTINCT JSON_OBJECT('BOOK_TYPE_CODE' VALUE TO_CHAR(BOOK_TYPE_CODE))
        BULK COLLECT INTO l_keys
        FROM   DMT_FA_ASSET_BOOK_TFM_TBL
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'STAGED'
        AND    BOOK_TYPE_CODE IS NOT NULL;
        RETURN l_keys;
    END GET_PARTITION_KEYS;

    -- --------------------------------------------------------
    -- APPLY_CONTRACT_V1_ASSETS (private)
    -- The Contract v1 apply for the Assets header tier, Option A shape. One
    -- shared FETCH_ROWS call returns the report's rows; the apply is STATIC SQL,
    -- one pair of UPDATEs, discriminated by the OBJECT_TYPE prefix 'Assets' and
    -- joined on RECON_KEY = RECORD_KEY. Book and assignment TFM rows inherit the
    -- header outcome via the cascade at the end (LOADED down, real Fusion error
    -- carried down). Nothing is copied back to STG (backlog #310).
    -- --------------------------------------------------------
    PROCEDURE APPLY_CONTRACT_V1_ASSETS (
        p_run_id        IN NUMBER,
        p_request_id    IN VARCHAR2,
        p_import_ess_id IN NUMBER
    ) IS
        C_PROC      CONSTANT VARCHAR2(40) := 'APPLY_CONTRACT_V1_ASSETS';
        l_gen_count NUMBER := 0;
        l_rows      DMT_RECON_CONTRACT_PKG.T_RECON_TBL;
        l_err_code  NUMBER;
        l_hdr_loaded NUMBER := 0;  l_hdr_failed NUMBER := 0;
        l_rc        NUMBER := 0;    -- backlog #65: rows matched by the current tier
        l_dff_seq   NUMBER;          -- backlog #65 tier 2: TFM_SEQUENCE_ID from DFF_KEY
        l_tier      VARCHAR2(10);    -- backlog #65: which tier matched (audit log)
    BEGIN
        -- Generated-row count drives the shared fetch's keyset page-count cap
        -- (a safety page limit, not an exact total). Done statically here (not in
        -- the shared pkg). The DM now returns two BASE tiers -- the header and the
        -- backlog #11 'Assets Distribution' tier (one row per asset that has an
        -- active distribution) -- so the header count plus the assign-child count
        -- bounds the rows the report can return.
        SELECT (SELECT COUNT(*) FROM DMT_FA_ASSET_HDR_TFM_TBL    WHERE RUN_ID = p_run_id)
             + (SELECT COUNT(*) FROM DMT_FA_ASSET_ASSIGN_TFM_TBL WHERE RUN_ID = p_run_id)
        INTO   l_gen_count
        FROM   dual;

        -- Report V2 (owner decision 2026-10-07) finds rows only by this work
        -- item's load job id: base assets and distributions through their POSTED
        -- FA_MASS_ADDITIONS row (FA_ADDITIONS_B carries no request id), interface
        -- rejections by LOAD_REQUEST_ID. One book = one load, so the report is
        -- called once per work item with that item's own ids; the import id is
        -- passed for contract symmetry.
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
                C_PROC || ': Contract v1 fetch failed for Assets '
                || '(detail in DMT_LOG_TBL).');
        END IF;

        IF l_rows.COUNT = 0 THEN
            -- Zero report rows is never success (design section 5): leave the
            -- remaining GENERATED rows for the all-or-nothing path / unaccounted
            -- sweep. A genuinely-failed book load reaches ACCOUNT_ALL_OR_NOTHING.
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ': Assets recon report returned zero rows; '
                               || 'GENERATED rows left for the all-or-nothing path / '
                               || 'unaccounted sweep (never a silent success).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
        ELSE
            FOR i IN 1 .. l_rows.COUNT LOOP
                l_rc   := 0;       -- backlog #65: reset per row so a prior row's tier
                l_tier := NULL;    -- cannot mislabel this row's audit log line.
                -- Two apply tiers, discriminated by exact OBJECT_TYPE equality
                -- (exact '=', not the prohibited LIKE): the asset HEADER tier
                -- ('Assets' / 'Assets [<BOOK>]') and the backlog #11 DISTRIBUTION
                -- tier ('Assets Distribution'), which carries the assignment
                -- child's own Fusion base id (FA_DISTRIBUTION_HISTORY
                -- .DISTRIBUTION_ID). The header RECON_KEY is the asset number; the
                -- distribution row's RECORD_KEY is the asset number + '#DIST', its
                -- SOURCE_REF is the bare asset number (= the assign child RECON_KEY).
                IF l_rows(i).OBJECT_TYPE = 'Assets Distribution' THEN
                    -- DISTRIBUTION tier: stamp the assign child's own Fusion id.
                    -- Never sets status (the cascade below owns the assign verdict);
                    -- only back-fills the real distribution id onto the assign row.
                    IF l_rows(i).SOURCE_TYPE = 'BASE'
                       AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                       AND l_rows(i).FUSION_ID IS NOT NULL THEN
                        -- The assign child is keyed by its (prefixed) ASSET_NUMBER
                        -- -- the assets transform does NOT stamp RECON_KEY on the
                        -- assign TFM (it is blank), so the match is on ASSET_NUMBER.
                        -- The distribution row's RECORD_KEY is the asset number plus
                        -- the '#DIST' suffix, so strip the last 5 characters to
                        -- recover the bare asset number. (The shared recon record
                        -- exposes no SOURCE_REF field.)
                        UPDATE DMT_FA_ASSET_ASSIGN_TFM_TBL
                        SET    FUSION_DISTRIBUTION_ID = l_rows(i).FUSION_ID,
                               LAST_UPDATED_DATE      = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    ASSET_NUMBER = SUBSTR(l_rows(i).RECORD_KEY, 1,
                                                     LENGTH(l_rows(i).RECORD_KEY) - 5)
                        AND    FUSION_DISTRIBUTION_ID IS NULL;
                    END IF;
                ELSIF l_rows(i).SOURCE_TYPE = 'BASE'
                   AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                   AND l_rows(i).FUSION_ID IS NOT NULL THEN
                    -- HEADER tier.
                    --
                    -- Backlog #65 three-tier match (owner order on PR #481). Tier 1 is
                    -- the stamped Slot A reference (RECON_KEY = RECORD_KEY, exactly as
                    -- before -- the asset number). Only if tier 1 matches NO TFM row
                    -- (SQL%ROWCOUNT = 0) do we fall to tier 2 (the Slot C DFF stamp:
                    -- TFM_SEQUENCE_ID = the trailing segment of DFF_KEY) and then tier 3
                    -- (the business key: ASSET_NUMBER = BUSINESS_KEY -- for Assets the
                    -- report's SOURCE_REF is the bare asset number, which is this header
                    -- row's own ASSET_NUMBER). Because every tier-1 hit short-circuits,
                    -- loaded outcomes are identical to before. Static UPDATEs.
                    UPDATE DMT_FA_ASSET_HDR_TFM_TBL
                    SET    TFM_STATUS           = 'LOADED',
                           FUSION_ASSET_ID      = l_rows(i).FUSION_ID,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID    = p_run_id
                    AND    RECON_KEY = l_rows(i).RECORD_KEY
                    AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                    l_rc := SQL%ROWCOUNT;
                    l_tier := CASE WHEN l_rc > 0 THEN 'TIER1' END;

                    -- Tier 2 (DFF): only when tier 1 matched nothing and a DFF stamp is
                    -- present. The trailing ':'/'~'-delimited segment of the DMT ref is
                    -- TFM_SEQUENCE_ID (DMT_REF_ID_PKG.BUILD_REF).
                    IF l_rc = 0 AND l_rows(i).DFF_KEY IS NOT NULL THEN
                        l_dff_seq := TO_NUMBER(
                            REGEXP_SUBSTR(l_rows(i).DFF_KEY, '[0-9]+$') DEFAULT NULL ON CONVERSION ERROR);
                        IF l_dff_seq IS NOT NULL THEN
                            UPDATE DMT_FA_ASSET_HDR_TFM_TBL
                            SET    TFM_STATUS           = 'LOADED',
                                   FUSION_ASSET_ID      = l_rows(i).FUSION_ID,
                                   RESULTS_UPDATED_DATE = SYSDATE,
                                   LAST_UPDATED_DATE    = SYSDATE
                            WHERE  RUN_ID    = p_run_id
                            AND    TFM_SEQUENCE_ID = l_dff_seq
                            AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                            l_rc := SQL%ROWCOUNT;
                            IF l_rc > 0 THEN l_tier := 'TIER2'; END IF;
                        END IF;
                    END IF;

                    -- Tier 3 (business key): last resort, only when tiers 1 and 2 both
                    -- matched nothing. The asset's business key is its ASSET_NUMBER,
                    -- equal to the bare asset number the report returns as BUSINESS_KEY.
                    IF l_rc = 0 AND l_rows(i).BUSINESS_KEY IS NOT NULL THEN
                        UPDATE DMT_FA_ASSET_HDR_TFM_TBL
                        SET    TFM_STATUS           = 'LOADED',
                               FUSION_ASSET_ID      = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    ASSET_NUMBER = l_rows(i).BUSINESS_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_rc := SQL%ROWCOUNT;
                        IF l_rc > 0 THEN l_tier := 'TIER3'; END IF;
                    END IF;

                    l_hdr_loaded := l_hdr_loaded + l_rc;
                    IF l_tier IN ('TIER2','TIER3') THEN
                        DMT_UTIL_PKG.LOG(p_run_id,
                            C_PROC || ': matched a LOADED Asset header via ' || l_tier ||
                            ' fallback (tier 1 stamped ref did not resolve). FUSION_ASSET_ID '
                            || l_rows(i).FUSION_ID || '.', 'INFO', C_PKG, C_PROC);
                    END IF;
                ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                      AND l_rows(i).ERROR_MESSAGE IS NOT NULL THEN
                    UPDATE DMT_FA_ASSET_HDR_TFM_TBL
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
            END LOOP;
        END IF;

        -- ============================================================
        -- Cascade header outcomes to book + assignment TFM (unchanged behaviour:
        -- book/assignment have no report tier of their own, so they inherit the
        -- header's terminal status. A GENERATED header leaves its children
        -- GENERATED — correct: unaccounted, not failed).
        -- ============================================================
        <<cascade_and_echo>>
        -- Cascade to book TFM — LOADED under a LOADED header. The book row belongs
        -- to the same asset as its header, so it carries the header's confirmed
        -- Fusion asset id (backlog #11: a LOADED row must store its Fusion base id
        -- for the audit trail). The book table is per-asset-per-BOOK grained, so it
        -- stores the per-BOOK composite FUSION_ASSET_ID~BOOK_TYPE_CODE (backlog #139)
        -- rather than the bare header id: a corporate book and a tax book of the
        -- same asset then carry DIFFERENT proof values, so the Fusion-id auditor's
        -- UNIQUE check is valid at book grain (mirrors GLBalances
        -- JE_HEADER_ID~JE_LINE_NUM). Both parts are already-captured real values
        -- (the header's confirmed base-table ASSET_ID and this book row's own
        -- BOOK_TYPE_CODE), never fabricated.
        UPDATE DMT_FA_ASSET_BOOK_TFM_TBL bk
        SET    bk.TFM_STATUS         = 'LOADED',
               -- The scalar subquery is never NULL on an updated row: the outer
               -- WHERE EXISTS below requires a LOADED header for the same asset,
               -- so the composite is always '<real asset_id>~<book>'. Keep this
               -- subquery and that EXISTS in sync if either is ever edited.
               bk.FUSION_ASSET_ID    = (
                   SELECT hdr.FUSION_ASSET_ID FROM DMT_FA_ASSET_HDR_TFM_TBL hdr
                   WHERE  hdr.RUN_ID       = bk.RUN_ID
                   AND    hdr.ASSET_NUMBER = bk.ASSET_NUMBER
                   AND    hdr.TFM_STATUS   = 'LOADED'
                   AND    ROWNUM = 1) || '~' || bk.BOOK_TYPE_CODE,
               bk.LAST_UPDATED_DATE  = SYSDATE
        WHERE  bk.RUN_ID     = p_run_id
        AND    bk.TFM_STATUS = 'GENERATED'
        AND    EXISTS (
            SELECT 1 FROM DMT_FA_ASSET_HDR_TFM_TBL hdr
            WHERE  hdr.RUN_ID       = bk.RUN_ID
            AND    hdr.ASSET_NUMBER = bk.ASSET_NUMBER
            AND    hdr.TFM_STATUS   = 'LOADED');

        -- The parent header only reaches FAILED with a real Fusion error, so the
        -- book row carries that same real parent error in the linked-record form.
        UPDATE DMT_FA_ASSET_BOOK_TFM_TBL bk
        SET    bk.TFM_STATUS = 'FAILED',
               bk.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(bk.ERROR_TEXT,
                   '[FUSION_ERROR]The parent record has the following Fusion error: ' ||
                   (SELECT hdr.ERROR_TEXT FROM DMT_FA_ASSET_HDR_TFM_TBL hdr
                    WHERE  hdr.RUN_ID = bk.RUN_ID
                    AND    hdr.ASSET_NUMBER = bk.ASSET_NUMBER
                    AND    hdr.TFM_STATUS = 'FAILED'
                    AND    ROWNUM = 1)),
               bk.LAST_UPDATED_DATE = SYSDATE
        WHERE  bk.RUN_ID     = p_run_id
        AND    bk.TFM_STATUS = 'GENERATED'
        AND    EXISTS (
            SELECT 1 FROM DMT_FA_ASSET_HDR_TFM_TBL hdr
            WHERE  hdr.RUN_ID       = bk.RUN_ID
            AND    hdr.ASSET_NUMBER = bk.ASSET_NUMBER
            AND    hdr.TFM_STATUS   = 'FAILED');

        -- Cascade to assignment TFM — LOADED under a LOADED header.
        -- Standard LOADED-promotion shape: the assign child has its OWN registered
        -- Fusion id (FUSION_DISTRIBUTION_ID, FA_DISTRIBUTION_HISTORY.DISTRIBUTION_ID),
        -- back-filled above by the 'Assets Distribution' report tier. A row is
        -- promoted to LOADED ONLY once that id is present -- the static
        -- asn.FUSION_DISTRIBUTION_ID IS NOT NULL guard -- so an assign row whose
        -- distribution id the report did not return is left GENERATED (surfaced by
        -- the unaccounted sweep), never marked LOADED without its captured id.
        UPDATE DMT_FA_ASSET_ASSIGN_TFM_TBL asn
        SET    asn.TFM_STATUS        = 'LOADED',
               asn.LAST_UPDATED_DATE = SYSDATE
        WHERE  asn.RUN_ID     = p_run_id
        AND    asn.TFM_STATUS = 'GENERATED'
        AND    asn.FUSION_DISTRIBUTION_ID IS NOT NULL
        AND    EXISTS (
            SELECT 1 FROM DMT_FA_ASSET_HDR_TFM_TBL hdr
            WHERE  hdr.RUN_ID       = asn.RUN_ID
            AND    hdr.ASSET_NUMBER = asn.ASSET_NUMBER
            AND    hdr.TFM_STATUS   = 'LOADED');

        -- The parent header only reaches FAILED with a real Fusion error, so the
        -- assignment row carries that same real parent error in the linked-record form.
        UPDATE DMT_FA_ASSET_ASSIGN_TFM_TBL asn
        SET    asn.TFM_STATUS = 'FAILED',
               asn.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(asn.ERROR_TEXT,
                   '[FUSION_ERROR]The parent record has the following Fusion error: ' ||
                   (SELECT hdr.ERROR_TEXT FROM DMT_FA_ASSET_HDR_TFM_TBL hdr
                    WHERE  hdr.RUN_ID = asn.RUN_ID
                    AND    hdr.ASSET_NUMBER = asn.ASSET_NUMBER
                    AND    hdr.TFM_STATUS = 'FAILED'
                    AND    ROWNUM = 1)),
               asn.LAST_UPDATED_DATE = SYSDATE
        WHERE  asn.RUN_ID     = p_run_id
        AND    asn.TFM_STATUS = 'GENERATED'
        AND    EXISTS (
            SELECT 1 FROM DMT_FA_ASSET_HDR_TFM_TBL hdr
            WHERE  hdr.RUN_ID       = asn.RUN_ID
            AND    hdr.ASSET_NUMBER = asn.ASSET_NUMBER
            AND    hdr.TFM_STATUS   = 'FAILED');

        -- Outcomes stay on the TFM rows only. Nothing is copied back to STG (backlog #310):
        -- a FAILED-mode rerun finds these rows through DMT_UTIL_PKG.FAILED_RETRY_SELECTED.

        -- NO COMMIT — orchestrator controls transaction boundaries.

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Report rows: ' || l_rows.COUNT
                           || ' | headers LOADED/FAILED: ' || l_hdr_loaded || '/' || l_hdr_failed
                           || '. Book/assignment cascaded; unmatched rows left for the '
                           || 'all-or-nothing path / unaccounted sweep.',
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
    END APPLY_CONTRACT_V1_ASSETS;

    -- --------------------------------------------------------
    -- PROPAGATE_DOCUMENT_ERRORS (private, backlog #175). The Fixed Assets
    -- SQL*Loader load is all or nothing per book batch: when one asset row is
    -- rejected, SQL*Loader commits nothing for the book, so the other assets of
    -- the batch never reach FA_MASS_ADDITIONS. ACCOUNT_ALL_OR_NOTHING has already
    -- given the rejected asset(s) their own real error (parsed from the
    -- SQL*Loader log, or from the report at the post stage). This quotes that
    -- real error onto every other asset header of the same book batch that did
    -- not load (design section 5, "Whole-document rejection carries the real
    -- error to every grain"), in the shared format
    -- '[FUSION_ERROR] Rejected with document: book batch <book> asset <num>: <msg>'.
    -- The book and assignment rows of those assets then inherit it through the
    -- cascade in ACCOUNT_ALL_OR_NOTHING.
    -- Only a header whose own error is a real [FUSION_ERROR] (not itself a quote)
    -- is a source. A target is a header of the same book that is neither LOADED
    -- nor STAGED and does not carry its own real error (it is unaccounted, or
    -- FAILED only with quotes, so a second rejected asset in the batch is quoted
    -- too). Idempotent: a header already carrying a quote is skipped. LOADED rows
    -- are never touched. A distribution (assignment) row with its own real error
    -- -- a FaMassaddDistributions rejection, backlog #571 -- is a source too:
    -- its error is quoted onto every asset header of the batch, its OWN header
    -- included (design section 5: "When a distribution errors, its real Fusion
    -- error is added to its line and to the header"), named
    -- 'book batch <book> asset <num> distribution: <msg>'. An assignment row
    -- that only carries its parent header's error is not a source. Static SQL;
    -- NO COMMIT.
    -- --------------------------------------------------------
    PROCEDURE PROPAGATE_DOCUMENT_ERRORS (
        p_run_id IN NUMBER,
        p_book   IN VARCHAR2
    ) IS
        C_PROC   CONSTANT VARCHAR2(30) := 'PROPAGATE_DOCUMENT_ERRORS';
        C_TAG    CONSTANT VARCHAR2(20) := '[FUSION_ERROR]';
        -- The linked-record form the cascades write onto a child of a FAILED header.
        C_PARENT_ERR CONSTANT VARCHAR2(80) := '[FUSION_ERROR]The parent record has the following Fusion error: ';
        l_marker VARCHAR2(30) := DMT_UTIL_PKG.C_DOC_ERROR_MARKER;
        l_pairs  T_DOC_PAIR_TBL;
        l_quoted NUMBER := 0;
        l_step   VARCHAR2(200);
    BEGIN
        l_step := 'collecting rejected assets and distributions of book ' || NVL(p_book, '(all)');
        SELECT SOURCE_ASSET, QUOTED_ERROR
        BULK COLLECT INTO l_pairs
        FROM (
            SELECT h.ASSET_NUMBER AS SOURCE_ASSET,
                   -- Names the book batch and the asset that was actually rejected.
                   DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR(
                       'book batch',
                       NVL(p_book, '(all books)') || ' asset ' || h.ASSET_NUMBER,
                       DBMS_LOB.SUBSTR(h.ERROR_TEXT, 3800, DBMS_LOB.INSTR(h.ERROR_TEXT, C_TAG))) AS QUOTED_ERROR,
                   1 AS SRC_ORDER, h.TFM_SEQUENCE_ID AS SRC_SEQ
            FROM   DMT_FA_ASSET_HDR_TFM_TBL h
            WHERE  h.RUN_ID = p_run_id
            AND    h.TFM_STATUS = 'FAILED'
            AND    DBMS_LOB.INSTR(h.ERROR_TEXT, C_TAG) > 0
            AND    DBMS_LOB.INSTR(h.ERROR_TEXT, l_marker) = 0
            AND    (p_book IS NULL OR EXISTS (
                       SELECT 1 FROM DMT_FA_ASSET_BOOK_TFM_TBL b
                       WHERE  b.RUN_ID = h.RUN_ID AND b.ASSET_NUMBER = h.ASSET_NUMBER
                       AND    b.BOOK_TYPE_CODE = p_book))
            UNION ALL
            -- Backlog #571: a distribution rejected with its own real error.
            -- SOURCE_ASSET is NULL so its own header is a target as well.
            SELECT NULL,
                   DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR(
                       'book batch',
                       NVL(p_book, '(all books)') || ' asset ' || d.ASSET_NUMBER || ' distribution',
                       DBMS_LOB.SUBSTR(d.ERROR_TEXT, 3800, DBMS_LOB.INSTR(d.ERROR_TEXT, C_TAG))),
                   2, d.TFM_SEQUENCE_ID
            FROM   DMT_FA_ASSET_ASSIGN_TFM_TBL d
            WHERE  d.RUN_ID = p_run_id
            AND    d.TFM_STATUS = 'FAILED'
            AND    DBMS_LOB.INSTR(d.ERROR_TEXT, C_TAG) > 0
            AND    DBMS_LOB.INSTR(d.ERROR_TEXT, l_marker) = 0
            AND    DBMS_LOB.INSTR(d.ERROR_TEXT, C_PARENT_ERR) = 0
            AND    (p_book IS NULL OR EXISTS (
                       SELECT 1 FROM DMT_FA_ASSET_BOOK_TFM_TBL b
                       WHERE  b.RUN_ID = d.RUN_ID AND b.ASSET_NUMBER = d.ASSET_NUMBER
                       AND    b.BOOK_TYPE_CODE = p_book)))
        ORDER BY SRC_ORDER, SRC_SEQ;

        l_step := 'appending quoted asset errors to the other assets of the book batch';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_FA_ASSET_HDR_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    (l_pairs(i).SOURCE_ASSET IS NULL OR t.ASSET_NUMBER <> l_pairs(i).SOURCE_ASSET)
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    (t.TFM_STATUS <> 'FAILED'
                    OR NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_marker), 0) > 0)
            AND    l_pairs(i).QUOTED_ERROR IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0
            AND    (p_book IS NULL OR EXISTS (
                       SELECT 1 FROM DMT_FA_ASSET_BOOK_TFM_TBL b
                       WHERE  b.RUN_ID = t.RUN_ID AND b.ASSET_NUMBER = t.ASSET_NUMBER
                       AND    b.BOOK_TYPE_CODE = p_book));
        l_quoted := SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' book=' || NVL(p_book, '(all)')
                           || ' complete. Rejected assets: ' || l_pairs.COUNT
                           || ' | other assets of the book batch given a quoted error: '
                           || l_quoted || '.',
            p_log_type  => CASE WHEN l_pairs.COUNT = 0 THEN DMT_UTIL_PKG.C_LOG_WARN
                                ELSE 'INFO' END,
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
    -- ACCOUNT_ALL_OR_NOTHING — Assets-ONLY exception (DMT_DESIGN section 5,
    -- "Fixed Assets load-stage batch-failure accounting").
    --
    -- Assets posts PER-ROW at Post Mass Additions (verified run 258: good assets
    -- reach FA_ADDITIONS_B = LOADED, a bad asset fails with its real Fusion error)
    -- -- that shape is handled by the Contract v1 nine-column apply above, NOT
    -- here. The all-or-nothing behavior is only at the SQL*LOADER LOAD stage: a
    -- load-file reject makes SQL*Loader return WARNING (= zero rows committed) and
    -- the load controller ERROR, so the whole book's records never reach the
    -- interface table, the BIP reconcile confirms nothing, and every asset in the
    -- book would be left UNACCOUNTED. This routine gives those a real verdict: the
    -- genuinely-rejected assets carry their actual Fusion error, and any remaining
    -- assets in the SAME book quote that real error through
    -- PROPAGATE_DOCUMENT_ERRORS (backlog #175; no generic text). It is
    -- scoped to ONE book partition (p_work_queue_id) and fires ONLY when no asset
    -- in that book loaded AND the load process genuinely failed.
    --
    -- THIS PATTERN IS FORBIDDEN FOR EVERY OTHER OBJECT. All other objects account
    -- per-row and MUST leave genuinely-unknown rows UNACCOUNTED rather than
    -- blanket-failing a batch. Assets is the sole exception, and only because its
    -- SQL*Loader LOAD stage is atomic per book (a WARNING commits zero rows).
    --
    -- Two error sources, matching the two failure stages:
    --   (a) LOAD stage: SQL*Loader rejected rows, so nothing reached
    --       FA_MASS_ADDITIONS and the BIP report was empty. The real per-record
    --       errors live in the load job's SQL*Loader log; we parse each
    --       "Record N: Rejected ... ORA-#### ..." and map record N to the Nth
    --       CSV row using the generator's exact join + ORDER BY b.TFM_SEQUENCE_ID.
    --   (b) POST stage: rows loaded to the interface but Post Mass Additions
    --       rejected the batch; the real error came back in the report and
    --       APPLY_CONTRACT_V1_ASSETS already marked the bad asset(s) FAILED. Here
    --       the assets left unposted only quote that real error.
    -- --------------------------------------------------------
    PROCEDURE ACCOUNT_ALL_OR_NOTHING (
        p_run_id        IN NUMBER,
        p_load_ess_id   IN NUMBER,
        p_work_queue_id IN NUMBER
    ) IS
        C_PROC     CONSTANT VARCHAR2(30) := 'ACCOUNT_ALL_OR_NOTHING';
        l_book       VARCHAR2(240);
        l_remaining  NUMBER := 0;
        l_loaded     NUMBER := 0;
        l_failed_bip NUMBER := 0;
        l_proc_failed NUMBER := 0;
        l_one        CLOB;
        l_start      PLS_INTEGER;
        l_next       PLS_INTEGER;
        l_recno      NUMBER;
        l_chunk      VARCHAR2(4000);
        l_err        VARCHAR2(2000);
        l_asset      VARCHAR2(100);
        l_reason     VARCHAR2(2000);
        l_dist_seq   NUMBER;
        l_marked     NUMBER := 0;
        l_left       NUMBER := 0;
    BEGIN
        -- Book partition for this work item (NULL if somehow unpartitioned).
        IF p_work_queue_id IS NOT NULL THEN
            BEGIN
                SELECT PARTITION_LABEL INTO l_book
                FROM   DMT_WORK_QUEUE_TBL WHERE QUEUE_ID = p_work_queue_id;
            EXCEPTION WHEN NO_DATA_FOUND THEN l_book := NULL;
            END;
        END IF;

        -- Assets in this book still without a verdict.
        SELECT COUNT(*) INTO l_remaining
        FROM   DMT_FA_ASSET_HDR_TFM_TBL h
        WHERE  h.RUN_ID = p_run_id
        AND    h.TFM_STATUS NOT IN ('LOADED','FAILED')
        AND    (l_book IS NULL OR EXISTS (
                   SELECT 1 FROM DMT_FA_ASSET_BOOK_TFM_TBL b
                   WHERE b.RUN_ID = h.RUN_ID AND b.ASSET_NUMBER = h.ASSET_NUMBER
                   AND   b.BOOK_TYPE_CODE = l_book));
        IF l_remaining = 0 THEN
            RETURN;   -- every asset in this book already accounted; nothing to do
        END IF;

        -- How many assets in this book actually LOADED?
        SELECT COUNT(*) INTO l_loaded
        FROM   DMT_FA_ASSET_HDR_TFM_TBL h
        WHERE  h.RUN_ID = p_run_id
        AND    h.TFM_STATUS = 'LOADED'
        AND    (l_book IS NULL OR EXISTS (
                   SELECT 1 FROM DMT_FA_ASSET_BOOK_TFM_TBL b
                   WHERE b.RUN_ID = h.RUN_ID AND b.ASSET_NUMBER = h.ASSET_NUMBER
                   AND   b.BOOK_TYPE_CODE = l_book));

        -- If ANY asset in the book loaded, this was NOT an all-or-nothing batch
        -- failure. Do not fabricate failures for the rest -- leave them
        -- UNACCOUNTED for honest reporting. (Assets is atomic per book, so this
        -- branch is a safety net, not the expected path.)
        IF l_loaded > 0 THEN
            RETURN;
        END IF;

        -- Assets in this book already marked FAILED from the report (post-stage).
        SELECT COUNT(*) INTO l_failed_bip
        FROM   DMT_FA_ASSET_HDR_TFM_TBL h
        WHERE  h.RUN_ID = p_run_id
        AND    h.TFM_STATUS = 'FAILED'
        AND    (l_book IS NULL OR EXISTS (
                   SELECT 1 FROM DMT_FA_ASSET_BOOK_TFM_TBL b
                   WHERE b.RUN_ID = h.RUN_ID AND b.ASSET_NUMBER = h.ASSET_NUMBER
                   AND   b.BOOK_TYPE_CODE = l_book));

        -- Poll the FAILED process before deciding this is an all-or-nothing
        -- failure. Nothing loaded can mean either (i) the load/post genuinely
        -- failed -- an atomic-batch rejection we must account -- or (ii) the load
        -- succeeded and the base rows simply have not appeared yet (lag), or (iii)
        -- the load succeeded and a row failed at the POST stage. The accepted
        -- DMT_DESIGN section 7 carve-out authorizes the all-or-nothing exception
        -- ONLY for a genuinely failed LOAD process (captured load controller
        -- ERROR, or a SQL*Loader child WARNING/reject).
        SELECT COUNT(*) INTO l_proc_failed
        FROM   DMT_ESS_JOB_TBL
        WHERE  RUN_ID = p_run_id
        AND    (REQUEST_ID = p_load_ess_id OR PARENT_REQUEST_ID = p_load_ess_id)
        AND    (UPPER(STATE_TEXT) IN ('ERROR','WARNING')
                OR STATE IN (10, 11));   -- 10=ERROR, 11=WARNING (SQL*Loader reject); Fusion emits SUCCEEDED/WARNING/ERROR

        -- Gate the ENTIRE exception on a genuinely-failed LOAD process. If the
        -- load shows no failure (l_proc_failed = 0) we do NOT batch-reject -- even
        -- when a row was individually FAILED at the POST stage (l_failed_bip > 0):
        -- Post Mass Additions is PER-ROW (proven run 258), so good rows load and
        -- any remainder stays UNACCOUNTED via the normal path. Post-stage / lag /
        -- indeterminate cases are never fabricated into a batch-rejected verdict.
        IF l_proc_failed = 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message => C_PROC || ' book=' || NVL(l_book,'(all)') ||
                    ': load process shows no failure -- all-or-nothing exception '
                    || 'not applied (post stage is per-row); unresolved rows left '
                    || 'UNACCOUNTED, not fabricating a verdict.',
                p_log_type => DMT_UTIL_PKG.C_LOG_WARN,
                p_package => C_PKG, p_procedure => C_PROC);
            RETURN;
        END IF;

        -- (a) LOAD-STAGE: nothing accounted at all -> the load failed before the
        -- interface. Pull the real per-record errors from the SQL*Loader log.
        -- Assets loads THREE interface tables from three control files (headers/
        -- books -> FA_MASS_ADDITIONS, distributions, rates), each its own
        -- SQL*Loader child whose "Record N" numbering RESTARTS at 1. Only the
        -- FA_MASS_ADDITIONS child's record order matches the header/book CSV
        -- (ROW_NUMBER OVER (ORDER BY b.TFM_SEQUENCE_ID)), so we parse each child
        -- log ALONE (never concatenated -- that would let a distributions/rates
        -- Record N misattribute to the wrong asset). A FA_MASS_ADDITIONS
        -- rejection maps to the header at that header/book CSV position; a
        -- FA_MASSADD_DISTRIBUTIONS rejection maps to the assignment row at that
        -- position of this work item's distributions CSV (backlog #571), which
        -- then becomes the source pass (b) quotes. The rates file is not
        -- generated, so it has no rejections to map.
        IF l_failed_bip = 0 THEN
            FOR c IN (
                SELECT REQUEST_ID FROM DMT_ESS_JOB_TBL
                WHERE  RUN_ID = p_run_id
                AND    PARENT_REQUEST_ID = p_load_ess_id
                AND    UPPER(JOB_SHORT_NAME) LIKE '%SQLLDR%'
                ORDER BY REQUEST_ID
            ) LOOP
                BEGIN
                    l_one := DMT_ESS_UTIL_PKG.GET_ESS_OUTPUT_TEXT(p_request_id => c.REQUEST_ID, p_cemli_code => C_CEMLI);
                EXCEPTION WHEN OTHERS THEN l_one := NULL;  -- a missing child log is not fatal
                END;
                -- Skip children that loaded neither FA_MASS_ADDITIONS nor
                -- FA_MASSADD_DISTRIBUTIONS (the rates file is not generated).
                IF l_one IS NULL
                   OR (INSTR(UPPER(l_one), 'FA_MASS_ADDITIONS') = 0
                       AND INSTR(UPPER(l_one), 'FA_MASSADD_DISTRIBUTIONS') = 0) THEN
                    CONTINUE;
                END IF;

                -- Walk each "Record N: Rejected ..." in THIS log alone.
                l_start := 1;
                LOOP
                    l_start := REGEXP_INSTR(l_one, 'Record [0-9]+: Rejected', l_start);
                    EXIT WHEN l_start = 0;
                    l_recno := TO_NUMBER(REGEXP_SUBSTR(l_one, 'Record ([0-9]+):', l_start, 1, NULL, 1));
                    l_next  := REGEXP_INSTR(l_one, 'Record [0-9]+:', l_start + 1);
                    IF l_next = 0 THEN l_next := DBMS_LOB.GETLENGTH(l_one) + 1; END IF;
                    l_chunk := DBMS_LOB.SUBSTR(l_one, LEAST(l_next - l_start, 3999), l_start);
                    -- real error = the "Error on table..." line + the first ORA- line;
                    -- a SQL*Loader-level rejection (for example "second enclosure
                    -- string not present") has no ORA- line, so the reason is the
                    -- line that follows "Error on table...".
                    l_reason := REGEXP_SUBSTR(l_chunk, 'ORA-[0-9]+[^'||CHR(10)||']*');
                    IF l_reason IS NULL THEN
                        l_reason := REGEXP_SUBSTR(l_chunk,
                                        'Error on table[^'||CHR(10)||']*'||CHR(10)
                                        ||'[[:space:]]*([^'||CHR(10)||']+)', 1, 1, NULL, 1);
                    END IF;
                    l_err := TRIM(REGEXP_REPLACE(
                                REGEXP_SUBSTR(l_chunk, 'Error on table[^'||CHR(10)||']*') || ' ' ||
                                l_reason,
                                '[[:space:]]+', ' '));

                    -- Backlog #571: a FaMassaddDistributions rejection belongs to the
                    -- assignment (distribution) row at that position of THIS work
                    -- item's distributions CSV (generator order: TFM_SEQUENCE_ID).
                    -- SQL*Loader numbers PHYSICAL lines, so a value carrying a line
                    -- break spans several records: each row's first record is 1 +
                    -- the records of the rows before it, and a record inside that
                    -- span still belongs to the same row. The row gets its own real
                    -- error; PROPAGATE_DOCUMENT_ERRORS then quotes it onto its own
                    -- header and the other assets of the book batch.
                    IF INSTR(UPPER(l_chunk), 'FA_MASSADD_DISTRIBUTIONS') > 0 THEN
                        BEGIN
                            SELECT TFM_SEQUENCE_ID INTO l_dist_seq FROM (
                                SELECT x.TFM_SEQUENCE_ID, x.NL,
                                       1 + NVL(SUM(x.NL + 1) OVER (
                                               ORDER BY x.TFM_SEQUENCE_ID
                                               ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING), 0) FIRST_REC
                                FROM (
                                    SELECT d.TFM_SEQUENCE_ID,
                                           NVL(REGEXP_COUNT(
                                               d.LOCATION_SEGMENT1 || d.LOCATION_SEGMENT2 || d.LOCATION_SEGMENT3
                                               || d.LOCATION_SEGMENT4 || d.LOCATION_SEGMENT5 || d.LOCATION_SEGMENT6
                                               || d.LOCATION_SEGMENT7
                                               || d.EXPENSE_ACCOUNT_SEGMENT1 || d.EXPENSE_ACCOUNT_SEGMENT2
                                               || d.EXPENSE_ACCOUNT_SEGMENT3 || d.EXPENSE_ACCOUNT_SEGMENT4
                                               || d.EXPENSE_ACCOUNT_SEGMENT5 || d.EXPENSE_ACCOUNT_SEGMENT6
                                               || d.EXPENSE_ACCOUNT_SEGMENT7 || d.EXPENSE_ACCOUNT_SEGMENT8
                                               || d.EXPENSE_ACCOUNT_SEGMENT9 || d.EXPENSE_ACCOUNT_SEGMENT10,
                                               CHR(10)), 0) NL
                                    FROM   DMT_FA_ASSET_ASSIGN_TFM_TBL d
                                    WHERE  d.RUN_ID = p_run_id
                                    AND    d.FBDI_CSV_ID IS NOT NULL
                                    AND    ((p_work_queue_id IS NOT NULL AND d.WORK_QUEUE_ID = p_work_queue_id)
                                            OR (p_work_queue_id IS NULL AND (l_book IS NULL OR EXISTS (
                                                    SELECT 1 FROM DMT_FA_ASSET_BOOK_TFM_TBL b
                                                    WHERE  b.RUN_ID = d.RUN_ID AND b.ASSET_NUMBER = d.ASSET_NUMBER
                                                    AND    b.BOOK_TYPE_CODE = l_book))))) x)
                            WHERE l_recno BETWEEN FIRST_REC AND FIRST_REC + NL;
                        EXCEPTION WHEN NO_DATA_FOUND THEN l_dist_seq := NULL;
                        END;
                        IF l_dist_seq IS NOT NULL AND l_err IS NOT NULL THEN
                            UPDATE DMT_FA_ASSET_ASSIGN_TFM_TBL
                            SET    TFM_STATUS = 'FAILED',
                                   ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT, '[FUSION_ERROR] ' || l_err),
                                   LAST_UPDATED_DATE = SYSDATE
                            WHERE  RUN_ID = p_run_id AND TFM_SEQUENCE_ID = l_dist_seq
                            AND    TFM_STATUS NOT IN ('LOADED','FAILED');
                        END IF;
                        l_start := l_next;
                        CONTINUE;
                    END IF;

                    -- Otherwise only FA_MASS_ADDITIONS rejections map to a header row.
                    IF INSTR(UPPER(l_chunk), 'FA_MASS_ADDITIONS') = 0 THEN
                        l_start := l_next;
                        CONTINUE;
                    END IF;

                    -- the asset at CSV position l_recno for this book
                    BEGIN
                        SELECT ASSET_NUMBER INTO l_asset FROM (
                            SELECT h.ASSET_NUMBER,
                                   ROW_NUMBER() OVER (ORDER BY b.TFM_SEQUENCE_ID) rn
                            FROM   DMT_FA_ASSET_HDR_TFM_TBL h
                            JOIN   DMT_FA_ASSET_BOOK_TFM_TBL b
                              ON   b.ASSET_NUMBER = h.ASSET_NUMBER AND b.RUN_ID = h.RUN_ID
                            WHERE  h.RUN_ID = p_run_id
                            AND    (l_book IS NULL OR b.BOOK_TYPE_CODE = l_book))
                        WHERE rn = l_recno;
                    EXCEPTION WHEN NO_DATA_FOUND THEN l_asset := NULL;
                    END;

                    IF l_asset IS NOT NULL AND l_err IS NOT NULL THEN
                        UPDATE DMT_FA_ASSET_HDR_TFM_TBL
                        SET    TFM_STATUS = 'FAILED',
                               ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT, '[FUSION_ERROR] ' || l_err),
                               RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                        WHERE  RUN_ID = p_run_id AND ASSET_NUMBER = l_asset
                        AND    TFM_STATUS NOT IN ('LOADED','FAILED');
                    END IF;
                    l_start := l_next;
                END LOOP;
            END LOOP;
        END IF;

        -- (b) both stages: every remaining asset in this book was not itself
        -- rejected but still did not load, because the batch is all or nothing.
        -- It quotes the real error of the asset(s) that were rejected (design
        -- section 5, whole-document rejection; backlog #175).
        PROPAGATE_DOCUMENT_ERRORS(p_run_id, l_book);

        SELECT COUNT(CASE WHEN DBMS_LOB.INSTR(h.ERROR_TEXT, DMT_UTIL_PKG.C_DOC_ERROR_MARKER) > 0
                          THEN 1 END),
               COUNT(CASE WHEN h.TFM_STATUS NOT IN ('LOADED','FAILED') THEN 1 END)
        INTO   l_marked, l_left
        FROM   DMT_FA_ASSET_HDR_TFM_TBL h
        WHERE  h.RUN_ID = p_run_id
        AND    (l_book IS NULL OR EXISTS (
                   SELECT 1 FROM DMT_FA_ASSET_BOOK_TFM_TBL b
                   WHERE b.RUN_ID = h.RUN_ID AND b.ASSET_NUMBER = h.ASSET_NUMBER
                   AND   b.BOOK_TYPE_CODE = l_book));

        -- Cascade the new header FAILEDs to book + assignment, using
        -- the same linked-record wording as APPLY_CONTRACT_V1_ASSETS.
        UPDATE DMT_FA_ASSET_BOOK_TFM_TBL bk
        SET    bk.TFM_STATUS = 'FAILED',
               bk.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(bk.ERROR_TEXT,
                   '[FUSION_ERROR]The parent record has the following Fusion error: ' ||
                   (SELECT h.ERROR_TEXT FROM DMT_FA_ASSET_HDR_TFM_TBL h
                    WHERE h.RUN_ID = bk.RUN_ID AND h.ASSET_NUMBER = bk.ASSET_NUMBER
                    AND h.TFM_STATUS = 'FAILED' AND ROWNUM = 1)),
               bk.LAST_UPDATED_DATE = SYSDATE
        WHERE  bk.RUN_ID = p_run_id AND bk.TFM_STATUS NOT IN ('LOADED','FAILED')
        AND    EXISTS (SELECT 1 FROM DMT_FA_ASSET_HDR_TFM_TBL h
                       WHERE h.RUN_ID = bk.RUN_ID AND h.ASSET_NUMBER = bk.ASSET_NUMBER
                       AND h.TFM_STATUS = 'FAILED');

        UPDATE DMT_FA_ASSET_ASSIGN_TFM_TBL asn
        SET    asn.TFM_STATUS = 'FAILED',
               asn.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(asn.ERROR_TEXT,
                   '[FUSION_ERROR]The parent record has the following Fusion error: ' ||
                   (SELECT h.ERROR_TEXT FROM DMT_FA_ASSET_HDR_TFM_TBL h
                    WHERE h.RUN_ID = asn.RUN_ID AND h.ASSET_NUMBER = asn.ASSET_NUMBER
                    AND h.TFM_STATUS = 'FAILED' AND ROWNUM = 1)),
               asn.LAST_UPDATED_DATE = SYSDATE
        WHERE  asn.RUN_ID = p_run_id AND asn.TFM_STATUS NOT IN ('LOADED','FAILED')
        AND    EXISTS (SELECT 1 FROM DMT_FA_ASSET_HDR_TFM_TBL h
                       WHERE h.RUN_ID = asn.RUN_ID AND h.ASSET_NUMBER = asn.ASSET_NUMBER
                       AND h.TFM_STATUS = 'FAILED');


        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message => C_PROC || ' book=' || NVL(l_book,'(all)') ||
                         ' all-or-nothing: ' || l_remaining || ' unaccounted before, ' ||
                         l_marked || ' quoting a rejected asset, ' || l_left ||
                         ' still unaccounted (no rejected asset to quote).',
            p_package => C_PKG, p_procedure => C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id, p_message => C_PROC || ' failed.',
                p_sqlerrm => SQLERRM, p_package => C_PKG, p_procedure => C_PROC);
            RAISE;
    END ACCOUNT_ALL_OR_NOTHING;

    -- --------------------------------------------------------
    -- RECONCILE_BATCH — entry point (signature unchanged). Runs the shared
    -- Contract v1 apply once for ONE work item (one book = one load), then the
    -- Assets-only all-or-nothing SQL*Loader log path. The load ESS id is the
    -- Contract v1 P_LOAD_REQUEST_ID and the import ESS id P_IMPORT_ESS_ID; the
    -- report finds rows only by the load job id, never by the run prefix.
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

        APPLY_CONTRACT_V1_ASSETS(p_run_id, TO_CHAR(p_load_ess_id), p_import_ess_id);

        -- Assets-ONLY exception: Fixed Assets loads/posts a book atomically, so
        -- a single rejected asset leaves the whole book unposted and the BIP
        -- reconcile above confirms nothing. Give those rows a real verdict
        -- (real Fusion error on the rejected asset(s); the rest of the book
        -- batch quote it via PROPAGATE_DOCUMENT_ERRORS, backlog #175)
        -- instead of leaving the book UNACCOUNTED. Fires only on a genuinely
        -- failed load process; a still-lagging load leaves rows UNACCOUNTED.
        -- See DMT_DESIGN section 5 (Fixed Assets all-or-nothing accounting).
        ACCOUNT_ALL_OR_NOTHING(p_run_id, p_load_ess_id, p_work_queue_id);

        -- Any records still unresolved are intentionally left GENERATED
        -- (unaccounted); the accounting gate reports the object not-DONE and the
        -- funnel surfaces these as UNRECONCILED.

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
    -- compile-time-known Assets TFM table(s). Flips this run's UNACCOUNTED rows
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
        UPDATE DMT_FA_ASSET_HDR_TFM_TBL
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
        UPDATE DMT_FA_ASSET_BOOK_TFM_TBL
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
        UPDATE DMT_FA_ASSET_ASSIGN_TFM_TBL
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
            C_PROC || ': reset ' || l_reset || ' UNACCOUNTED Assets row(s) to GENERATED '
            || 'for re-reconcile.',
            'INFO', C_PKG, C_PROC);
        -- NO COMMIT -- the caller (RERUN_RUN) owns the transaction.
    END RESET_UNACCOUNTED;

END DMT_FA_ASSET_RESULTS_PKG;
/
