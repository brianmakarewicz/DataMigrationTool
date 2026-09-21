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
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_FA_ASSET_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'Assets';

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
    -- carried down); the STG echo is unchanged.
    -- --------------------------------------------------------
    PROCEDURE APPLY_CONTRACT_V1_ASSETS (
        p_run_id     IN NUMBER,
        p_request_id IN VARCHAR2
    ) IS
        C_PROC      CONSTANT VARCHAR2(40) := 'APPLY_CONTRACT_V1_ASSETS';
        l_gen_count NUMBER := 0;
        l_rows      DMT_RECON_CONTRACT_PKG.T_RECON_TBL;
        l_err_code  NUMBER;
        l_hdr_loaded NUMBER := 0;  l_hdr_failed NUMBER := 0;
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
                        -- The assign child RECON_KEY is the bare asset number; the
                        -- distribution row's RECORD_KEY is that plus the '#DIST'
                        -- suffix, so strip the last 5 characters to match. (The
                        -- shared recon record exposes no SOURCE_REF field.)
                        UPDATE DMT_FA_ASSET_ASSIGN_TFM_TBL
                        SET    FUSION_DISTRIBUTION_ID = l_rows(i).FUSION_ID,
                               LAST_UPDATED_DATE      = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = SUBSTR(l_rows(i).RECORD_KEY, 1,
                                                  LENGTH(l_rows(i).RECORD_KEY) - 5)
                        AND    FUSION_DISTRIBUTION_ID IS NULL;
                    END IF;
                ELSIF l_rows(i).SOURCE_TYPE = 'BASE'
                   AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                   AND l_rows(i).FUSION_ID IS NOT NULL THEN
                    -- HEADER tier.
                    UPDATE DMT_FA_ASSET_HDR_TFM_TBL
                    SET    TFM_STATUS           = 'LOADED',
                           FUSION_ASSET_ID      = l_rows(i).FUSION_ID,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID    = p_run_id
                    AND    RECON_KEY = l_rows(i).RECORD_KEY
                    AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                    l_hdr_loaded := l_hdr_loaded + SQL%ROWCOUNT;
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
        -- for the audit trail). FUSION_ASSET_ID is stamped from the header's
        -- already-captured id, not fabricated.
        UPDATE DMT_FA_ASSET_BOOK_TFM_TBL bk
        SET    bk.TFM_STATUS         = 'LOADED',
               bk.FUSION_ASSET_ID    = (
                   SELECT hdr.FUSION_ASSET_ID FROM DMT_FA_ASSET_HDR_TFM_TBL hdr
                   WHERE  hdr.RUN_ID       = bk.RUN_ID
                   AND    hdr.ASSET_NUMBER = bk.ASSET_NUMBER
                   AND    hdr.TFM_STATUS   = 'LOADED'
                   AND    ROWNUM = 1),
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
        UPDATE DMT_FA_ASSET_ASSIGN_TFM_TBL asn
        SET    asn.TFM_STATUS        = 'LOADED',
               asn.LAST_UPDATED_DATE = SYSDATE
        WHERE  asn.RUN_ID     = p_run_id
        AND    asn.TFM_STATUS = 'GENERATED'
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

        -- Echo outcomes back to STG (headers).
        UPDATE DMT_FA_ASSET_HDR_STG_TBL stg
        SET    stg.STG_STATUS        = 'LOADED',
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_FA_ASSET_HDR_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');
        UPDATE DMT_FA_ASSET_HDR_STG_TBL stg
        SET    stg.STG_STATUS = 'FAILED',
               stg.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_FA_ASSET_HDR_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                    AND    t.RUN_ID  = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_FA_ASSET_HDR_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');

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
    -- assets in the SAME book carry a generic "batch rejected" FAILED. It is
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
    --       we add only the generic verdict to the good assets left unposted.
    -- --------------------------------------------------------
    PROCEDURE ACCOUNT_ALL_OR_NOTHING (
        p_run_id        IN NUMBER,
        p_load_ess_id   IN NUMBER,
        p_work_queue_id IN NUMBER
    ) IS
        C_PROC     CONSTANT VARCHAR2(30) := 'ACCOUNT_ALL_OR_NOTHING';
        C_GENERIC  CONSTANT VARCHAR2(400) :=
            '[BATCH_REJECTED] Not loaded: another asset in this book batch was '
            || 'rejected by Fusion. The Fixed Assets interface load/post is '
            || 'all-or-nothing per book, so no assets in this book were committed.';
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
        l_marked     NUMBER := 0;
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
        -- indeterminate cases are never fabricated into a [BATCH_REJECTED] verdict.
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
        -- Record N misattribute to the wrong asset) and attribute ONLY rejections
        -- on table FA_MASS_ADDITIONS. A distributions/rates rejection has no
        -- header CSV position, so its asset falls into the generic [BATCH_REJECTED]
        -- pass (b) below rather than being mapped to a wrong header row.
        IF l_failed_bip = 0 THEN
            FOR c IN (
                SELECT REQUEST_ID FROM DMT_ESS_JOB_TBL
                WHERE  RUN_ID = p_run_id
                AND    PARENT_REQUEST_ID = p_load_ess_id
                AND    UPPER(JOB_SHORT_NAME) LIKE '%SQLLDR%'
                ORDER BY REQUEST_ID
            ) LOOP
                BEGIN
                    l_one := DMT_ESS_UTIL_PKG.GET_ESS_OUTPUT_TEXT(c.REQUEST_ID);
                EXCEPTION WHEN OTHERS THEN l_one := NULL;  -- a missing child log is not fatal
                END;
                -- Skip children that did not load FA_MASS_ADDITIONS: their record
                -- numbers do not map to the header/book CSV.
                IF l_one IS NULL OR INSTR(UPPER(l_one), 'FA_MASS_ADDITIONS') = 0 THEN
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
                    -- Only FA_MASS_ADDITIONS rejections map to a header row.
                    IF INSTR(UPPER(l_chunk), 'FA_MASS_ADDITIONS') = 0 THEN
                        l_start := l_next;
                        CONTINUE;
                    END IF;
                    -- real Fusion error = the "Error on table..." line + first ORA- line
                    l_err := TRIM(REGEXP_REPLACE(
                                REGEXP_SUBSTR(l_chunk, 'Error on table[^'||CHR(10)||']*') || ' ' ||
                                REGEXP_SUBSTR(l_chunk, 'ORA-[0-9]+[^'||CHR(10)||']*'),
                                '[[:space:]]+', ' '));

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

        -- (b) both stages: every remaining un-accounted asset in this book was
        -- not individually rejected but still did not load, because the batch is
        -- all-or-nothing. Mark it FAILED with the generic batch message.
        UPDATE DMT_FA_ASSET_HDR_TFM_TBL h
        SET    h.TFM_STATUS = 'FAILED',
               h.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(h.ERROR_TEXT, C_GENERIC),
               h.RESULTS_UPDATED_DATE = SYSDATE, h.LAST_UPDATED_DATE = SYSDATE
        WHERE  h.RUN_ID = p_run_id
        AND    h.TFM_STATUS NOT IN ('LOADED','FAILED')
        AND    (l_book IS NULL OR EXISTS (
                   SELECT 1 FROM DMT_FA_ASSET_BOOK_TFM_TBL b
                   WHERE b.RUN_ID = h.RUN_ID AND b.ASSET_NUMBER = h.ASSET_NUMBER
                   AND   b.BOOK_TYPE_CODE = l_book));
        l_marked := SQL%ROWCOUNT;

        -- Cascade the new header FAILEDs to book + assignment + STG echo, using
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

        UPDATE DMT_FA_ASSET_HDR_STG_TBL stg
        SET    stg.STG_STATUS = 'FAILED',
               stg.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_FA_ASSET_HDR_TFM_TBL t
                    WHERE t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_STATUS NOT IN ('LOADED','FAILED')
        AND    stg.STG_SEQUENCE_ID IN (
                   SELECT t.STG_SEQUENCE_ID FROM DMT_FA_ASSET_HDR_TFM_TBL t
                   WHERE t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message => C_PROC || ' book=' || NVL(l_book,'(all)') ||
                         ' all-or-nothing: ' || l_remaining || ' unaccounted, ' ||
                         l_marked || ' marked generic FAILED.',
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
    -- Contract v1 apply, then the Assets-only all-or-nothing SQL*Loader log path.
    -- The Assets load ESS id is the Contract v1 P_LOAD_REQUEST_ID; the report's
    -- run-scoped selectors (P_RUN_ID, P_PREFIX) pick up the whole run.
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

        APPLY_CONTRACT_V1_ASSETS(p_run_id, TO_CHAR(p_load_ess_id));

        -- Assets-ONLY exception: Fixed Assets loads/posts a book atomically, so
        -- a single rejected asset leaves the whole book unposted and the BIP
        -- reconcile above confirms nothing. Give those rows a real verdict
        -- (real Fusion error on the rejected asset(s), generic on the rest)
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

END DMT_FA_ASSET_RESULTS_PKG;
/
