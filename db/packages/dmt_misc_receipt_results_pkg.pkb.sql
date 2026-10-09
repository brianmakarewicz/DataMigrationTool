-- PACKAGE BODY DMT_MISC_RECEIPT_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_MISC_RECEIPT_RESULTS_PKG"
AS
-- ============================================================
-- DMT_MISC_RECEIPT_RESULTS_PKG body
-- MiscReceipts post-load reconciliation — Contract v1, SINGLE-TIER.
--
-- Reuses the ONE shared Contract v1 fetch DMT_RECON_CONTRACT_PKG.FETCH_ROWS
-- (Option A, owner decision on PR #248), exactly as the Workers/Requisitions
-- templates do. A single fetch runs the MiscReceipts Contract v1 report (nine
-- columns, keyset paginated) over BIP and returns all rows in one collection;
-- OBJECT_TYPE is 'MiscReceipts' on every row (this object is single-tier).
--
-- The apply is STATIC SQL against the compile-time-known transaction TFM table,
-- one MERGE-style UPDATE pair, filtered by OBJECT_TYPE = 'MiscReceipts' and
-- joined on RECON_KEY = report RECORD_KEY.
--
--   Tier          OBJECT_TYPE literal   TFM table               FUSION_ID column
--   ----------    -------------------   --------------------    ----------------
--   transactions  'MiscReceipts'        DMT_INV_TRX_TFM_TBL     FUSION_ID
--
-- The rule is the shared Contract v1 apply rule:
--   * BASE / SUCCESS / FUSION_ID NOT NULL -> LOADED, stamp FUSION_ID (the base
--     table INV_MATERIAL_TXNS.TRANSACTION_ID).
--   * FUSION_STATUS = ERROR with a real ERROR_MESSAGE -> FAILED, message appended
--     as '[FUSION_ERROR] ' || message (never composed). The MiscReceipts DM
--     carries the real Fusion rejection inline from INV_TRANSACTIONS_INTERFACE
--     (ERROR_CODE + ERROR_EXPLANATION at PROCESS_FLAG = 3), so ERROR rows have a
--     real message; there is no '#IMPORT_REPORT#' marker to guard against.
--   * Everything else is left GENERATED for the shared unaccounted sweep;
--     INTERFACE/SUCCESS corroborates but is never sufficient for LOADED.
--
-- The RECON_KEY on each transaction TFM row is stamped by
-- DMT_MISC_RECEIPT_TRANSFORM_PKG to equal that row's report RECORD_KEY
-- (= TO_CHAR(SOURCE_LINE_ID) = TO_CHAR(the TFM STG_SEQUENCE_ID)). That coupling is
-- what makes the join hit.
--
-- After the transaction tier settles, a lot of a base-confirmed transaction is
-- LOADED with it (found outcome via the parent, not a fabricated verdict), and
-- outcomes stay on the TFM rows (no STG write, backlog #310). Serials prove
-- themselves LOADED through their own base tier.
--
-- Then PROPAGATE_DOCUMENT_ERRORS (backlog #167) quotes a rejected transaction's
-- real Fusion error onto every not-LOADED lot and serial row of that transaction
-- (a transaction and its lot/serial detail stand or fall together in
-- INV_TRANSACTIONS_INTERFACE), naming the transaction's SOURCE_LINE_ID:
-- '[FUSION_ERROR] Rejected with document: transaction <SOURCE_LINE_ID>: <real msg>'
-- (design section 5, "Whole-document rejection carries the real error to every
-- grain"). A lot/serial defect is written by Fusion inline on the transaction row
-- (the recon report returns it as the transaction's own error), so the same quote
-- carries a child-grain defect to the other children of that transaction.
--
-- Change history:
--   2026-10-08  BM  Cross-grain propagation (PROPAGATE_DOCUMENT_ERRORS, backlog
--                   #167): serials of a rejected transaction no longer end
--                   UNACCOUNTED; the lot cascade quotes the transaction's real
--                   error in the shared FORMAT_DOCUMENT_ERROR format.
--   2026-10-09  BM  Backlog #552: the lot LOADED cascade and the document
--                   roll-up both find a child's transaction by the parent TFM
--                   id the child carries in SOURCE_LINE_ID (one parent link).
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_MISC_RECEIPT_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'MiscReceipts';

    -- Cross-grain propagation (PROPAGATE_DOCUMENT_ERRORS, backlog #167).
    -- Working set: "the transaction PARENT_TFM_SEQ was rejected with its own real
    -- Fusion error, so every not-LOADED lot and serial whose SOURCE_LINE_ID points
    -- at it must carry QUOTED_ERROR".
    TYPE T_DOC_PAIR IS RECORD (
        PARENT_TFM_SEQ NUMBER,           -- the transaction's TFM_SEQUENCE_ID
        QUOTED_ERROR   VARCHAR2(4000)    -- DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR(...)
    );
    TYPE T_DOC_PAIR_TBL IS TABLE OF T_DOC_PAIR;

    -- --------------------------------------------------------
    -- APPLY_CONTRACT_V1_MISC_RECEIPTS (private)
    -- The Contract v1 apply for the single MiscReceipts tier, Option A shape.
    -- The shared package fetches the parsed report rows (no dynamic SQL, no TFM
    -- reference there); the apply here is STATIC SQL against the compile-time-known
    -- transaction TFM table, joined on RECON_KEY = report RECORD_KEY.
    -- --------------------------------------------------------
    PROCEDURE APPLY_CONTRACT_V1_MISC_RECEIPTS (
        p_run_id     IN NUMBER,
        p_request_id IN VARCHAR2
    ) IS
        C_PROC      CONSTANT VARCHAR2(40) := 'APPLY_CONTRACT_V1_MISC_RECEIPTS';
        l_gen_count NUMBER := 0;
        l_rows      DMT_RECON_CONTRACT_PKG.T_RECON_TBL;
        l_err_code  NUMBER;
        l_loaded    NUMBER := 0;
        l_failed    NUMBER := 0;
        l_rc        NUMBER := 0;    -- backlog #65: rows matched by the current tier
        l_dff_seq   NUMBER;          -- backlog #65 tier 2: TFM_SEQUENCE_ID from DFF_KEY
        l_tier      VARCHAR2(10);    -- backlog #65: which tier matched (audit log)
    BEGIN
        -- Generated-row count drives the shared fetch's keyset page-count cap
        -- (a safety page limit, not an exact total). Done statically here (not in
        -- the shared pkg). The DM now returns the transactions tier plus the
        -- backlog #11 serial tier ('MiscReceipts Serial'), so the transaction
        -- count plus the serial-child count bounds the rows the report can return.
        SELECT (SELECT COUNT(*) FROM DMT_INV_TRX_TFM_TBL        WHERE RUN_ID = p_run_id)
             + (SELECT COUNT(*) FROM DMT_INV_TRX_SERIALS_TFM_TBL WHERE RUN_ID = p_run_id)
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
                C_PROC || ': Contract v1 fetch failed for MiscReceipts '
                || '(detail in DMT_LOG_TBL).');
        END IF;

        IF l_rows.COUNT = 0 THEN
            -- Zero report rows is never success (design section 5): leave the
            -- remaining GENERATED rows for the existing unaccounted sweep.
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ': MiscReceipts recon report returned zero rows; '
                               || 'GENERATED rows left for the unaccounted sweep '
                               || '(never a silent success).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
        ELSE
            FOR i IN 1 .. l_rows.COUNT LOOP
                l_rc   := 0;       -- backlog #65: reset per row so a prior row's tier
                l_tier := NULL;    -- cannot mislabel this row's audit log line.
                -- ===== TIER: TRANSACTIONS (OBJECT_TYPE = 'MiscReceipts') =====
                IF l_rows(i).OBJECT_TYPE = 'MiscReceipts' THEN
                    IF l_rows(i).SOURCE_TYPE = 'BASE'
                       AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                       AND l_rows(i).FUSION_ID IS NOT NULL THEN
                        -- Positive proof: transaction found in INV_MATERIAL_TXNS
                        -- with a real TRANSACTION_ID. The ONLY path to LOADED.
                        --
                        -- Backlog #65 three-tier match (owner order on PR #481). Tier 1
                        -- is the stamped Slot A reference (RECON_KEY = RECORD_KEY, exactly
                        -- as before -- TO_CHAR(SOURCE_LINE_ID)). Only if tier 1 matches NO
                        -- TFM row (SQL%ROWCOUNT = 0) do we fall to tier 2 (the Slot C DFF
                        -- stamp: TFM_SEQUENCE_ID = the trailing segment of DFF_KEY) and
                        -- then tier 3 (the business key: TRANSACTION_REFERENCE =
                        -- BUSINESS_KEY -- for MiscReceipts the report's SOURCE_REF is the
                        -- transaction's TRANSACTION_REFERENCE). Because every tier-1 hit
                        -- short-circuits, loaded outcomes are identical to before. Static
                        -- UPDATEs.
                        UPDATE DMT_INV_TRX_TFM_TBL
                        SET    TFM_STATUS           = 'LOADED',
                               FUSION_ID            = TO_CHAR(l_rows(i).FUSION_ID),
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_rc := SQL%ROWCOUNT;
                        l_tier := CASE WHEN l_rc > 0 THEN 'TIER1' END;

                        -- Tier 2 (DFF): only when tier 1 matched nothing and a DFF stamp
                        -- is present. The trailing ':'/'~'-delimited segment of the DMT
                        -- ref is TFM_SEQUENCE_ID (DMT_REF_ID_PKG.BUILD_REF).
                        IF l_rc = 0 AND l_rows(i).DFF_KEY IS NOT NULL THEN
                            l_dff_seq := TO_NUMBER(
                                REGEXP_SUBSTR(l_rows(i).DFF_KEY, '[0-9]+$') DEFAULT NULL ON CONVERSION ERROR);
                            IF l_dff_seq IS NOT NULL THEN
                                UPDATE DMT_INV_TRX_TFM_TBL
                                SET    TFM_STATUS           = 'LOADED',
                                       FUSION_ID            = TO_CHAR(l_rows(i).FUSION_ID),
                                       RESULTS_UPDATED_DATE = SYSDATE,
                                       LAST_UPDATED_DATE    = SYSDATE
                                WHERE  RUN_ID    = p_run_id
                                AND    TFM_SEQUENCE_ID = l_dff_seq
                                AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                                l_rc := SQL%ROWCOUNT;
                                IF l_rc > 0 THEN l_tier := 'TIER2'; END IF;
                            END IF;
                        END IF;

                        -- Tier 3 (business key): last resort, only when tiers 1 and 2
                        -- both matched nothing. The transaction's business key is its
                        -- TRANSACTION_REFERENCE, equal to the report's SOURCE_REF.
                        IF l_rc = 0 AND l_rows(i).BUSINESS_KEY IS NOT NULL THEN
                            UPDATE DMT_INV_TRX_TFM_TBL
                            SET    TFM_STATUS           = 'LOADED',
                                   FUSION_ID            = TO_CHAR(l_rows(i).FUSION_ID),
                                   RESULTS_UPDATED_DATE = SYSDATE,
                                   LAST_UPDATED_DATE    = SYSDATE
                            WHERE  RUN_ID    = p_run_id
                            AND    TRANSACTION_REFERENCE = l_rows(i).BUSINESS_KEY
                            AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                            l_rc := SQL%ROWCOUNT;
                            IF l_rc > 0 THEN l_tier := 'TIER3'; END IF;
                        END IF;

                        l_loaded := l_loaded + l_rc;
                        IF l_tier IN ('TIER2','TIER3') THEN
                            DMT_UTIL_PKG.LOG(p_run_id,
                                C_PROC || ': matched a LOADED MiscReceipts transaction via '
                                || l_tier || ' fallback (tier 1 stamped ref did not resolve). '
                                || 'FUSION_ID ' || l_rows(i).FUSION_ID || '.', 'INFO', C_PKG, C_PROC);
                        END IF;

                    ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                          AND l_rows(i).ERROR_MESSAGE IS NOT NULL THEN
                        -- A real, specific Fusion rejection -> FAILED on the exact
                        -- message (never composed).
                        UPDATE DMT_INV_TRX_TFM_TBL
                        SET    TFM_STATUS           = 'FAILED',
                               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(
                                                        ERROR_TEXT,
                                                        '[FUSION_ERROR] ' || l_rows(i).ERROR_MESSAGE),
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_failed := l_failed + SQL%ROWCOUNT;

                    ELSE
                        -- INTERFACE/SUCCESS (corroborating, never sufficient) or a
                        -- non-terminal status with no real error: leave the row for
                        -- the existing unaccounted sweep. Never fabricate.
                        NULL;
                    END IF;

                -- ===== TIER: SERIAL detail (OBJECT_TYPE = 'MiscReceipts Serial') =====
                -- Backlog #11: the serial line has its OWN Fusion base id
                -- (INV_SERIAL_NUMBERS.GEN_OBJECT_ID), returned here as FUSION_ID and
                -- keyed by the run-prefixed serial number (= the serials TFM
                -- FM_SERIAL_NUMBER). Finding the serial in its base table is positive
                -- proof the serial loaded, so this marks the serial row LOADED and
                -- stamps its own FUSION_SERIAL_ID. This is the ONLY positive proof for
                -- a serial (the lot/serial detail carries no stored parent-transaction
                -- key, so the transaction cascade could not reach it before).
                ELSIF l_rows(i).OBJECT_TYPE = 'MiscReceipts Serial' THEN
                    IF l_rows(i).SOURCE_TYPE = 'BASE'
                       AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                       AND l_rows(i).FUSION_ID IS NOT NULL THEN
                        -- Backlog #65 three-tier match, applied consistently to the
                        -- serial tier. Tier 1 is the stamped Slot A reference
                        -- (FM_SERIAL_NUMBER = RECORD_KEY, exactly as before -- the
                        -- run-prefixed serial number). Only if tier 1 matches NO serial
                        -- TFM row (SQL%ROWCOUNT = 0) do we fall to tier 2 (the Slot C DFF
                        -- stamp: TFM_SEQUENCE_ID = the trailing segment of DFF_KEY; serial
                        -- rows have no DFF carrier so this is normally a no-op, kept
                        -- uniform) and then tier 3 (the business key: FM_SERIAL_NUMBER =
                        -- BUSINESS_KEY -- the serial number the report returns as
                        -- SOURCE_REF, the same serial number, safely degenerate). Every
                        -- tier-1 hit short-circuits, so loaded outcomes are identical to
                        -- before. Static UPDATEs.
                        UPDATE DMT_INV_TRX_SERIALS_TFM_TBL
                        SET    TFM_STATUS           = 'LOADED',
                               FUSION_SERIAL_ID     = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID = p_run_id
                        AND    FM_SERIAL_NUMBER = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_rc := SQL%ROWCOUNT;
                        l_tier := CASE WHEN l_rc > 0 THEN 'TIER1' END;

                        IF l_rc = 0 AND l_rows(i).DFF_KEY IS NOT NULL THEN
                            l_dff_seq := TO_NUMBER(
                                REGEXP_SUBSTR(l_rows(i).DFF_KEY, '[0-9]+$') DEFAULT NULL ON CONVERSION ERROR);
                            IF l_dff_seq IS NOT NULL THEN
                                UPDATE DMT_INV_TRX_SERIALS_TFM_TBL
                                SET    TFM_STATUS           = 'LOADED',
                                       FUSION_SERIAL_ID     = l_rows(i).FUSION_ID,
                                       RESULTS_UPDATED_DATE = SYSDATE,
                                       LAST_UPDATED_DATE    = SYSDATE
                                WHERE  RUN_ID = p_run_id
                                AND    TFM_SEQUENCE_ID = l_dff_seq
                                AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                                l_rc := SQL%ROWCOUNT;
                                IF l_rc > 0 THEN l_tier := 'TIER2'; END IF;
                            END IF;
                        END IF;

                        IF l_rc = 0 AND l_rows(i).BUSINESS_KEY IS NOT NULL THEN
                            UPDATE DMT_INV_TRX_SERIALS_TFM_TBL
                            SET    TFM_STATUS           = 'LOADED',
                                   FUSION_SERIAL_ID     = l_rows(i).FUSION_ID,
                                   RESULTS_UPDATED_DATE = SYSDATE,
                                   LAST_UPDATED_DATE    = SYSDATE
                            WHERE  RUN_ID = p_run_id
                            AND    FM_SERIAL_NUMBER = l_rows(i).BUSINESS_KEY
                            AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                            l_rc := SQL%ROWCOUNT;
                            IF l_rc > 0 THEN l_tier := 'TIER3'; END IF;
                        END IF;

                        l_loaded := l_loaded + l_rc;
                        IF l_tier IN ('TIER2','TIER3') THEN
                            DMT_UTIL_PKG.LOG(p_run_id,
                                C_PROC || ': matched a LOADED MiscReceipts serial via '
                                || l_tier || ' fallback (tier 1 stamped ref did not resolve). '
                                || 'FUSION_SERIAL_ID ' || l_rows(i).FUSION_ID || '.', 'INFO', C_PKG, C_PROC);
                        END IF;
                    END IF;
                END IF;
            END LOOP;
        END IF;

        -- Cascade a base-confirmed transaction to its lot detail. A lot line is
        -- child detail of an inventory transaction and loads with it in the same
        -- FBDI, linked to it by the parent's TFM_SEQUENCE_ID the lot carries in
        -- SOURCE_LINE_ID (backlog #552: the one parent link the generator and
        -- PROPAGATE_DOCUMENT_ERRORS use too). A lot whose transaction
        -- is base-confirmed LOADED is LOADED (found outcome via the parent, not a
        -- fabricated verdict). A lot or serial whose transaction was rejected is
        -- FAILED by PROPAGATE_DOCUMENT_ERRORS, quoting the transaction's real error.
        -- A lot line loaded with its parent transaction, so it carries that
        -- transaction's confirmed Fusion transaction id (backlog #11: a LOADED row
        -- must store its Fusion base id for the audit trail). FUSION_TRANSACTION_ID
        -- is stamped from the parent transaction's already-captured FUSION_ID (a
        -- VARCHAR2 id column converted to the child's NUMBER column), not fabricated.
        UPDATE DMT_INV_TRX_LOTS_TFM_TBL l
        SET    l.TFM_STATUS='LOADED',
               l.FUSION_TRANSACTION_ID=(
                   SELECT TO_NUMBER(t.FUSION_ID) FROM DMT_INV_TRX_TFM_TBL t
                   WHERE  t.RUN_ID=p_run_id
                   AND    t.TFM_SEQUENCE_ID=l.SOURCE_LINE_ID
                   AND    t.TFM_STATUS='LOADED' AND ROWNUM=1),
               l.RESULTS_UPDATED_DATE=SYSDATE, l.LAST_UPDATED_DATE=SYSDATE
        WHERE  l.RUN_ID=p_run_id AND l.TFM_STATUS NOT IN ('LOADED','FAILED')
        AND    EXISTS (SELECT 1 FROM DMT_INV_TRX_TFM_TBL t WHERE t.RUN_ID=p_run_id
                       AND t.TFM_SEQUENCE_ID=l.SOURCE_LINE_ID
                       AND t.TFM_STATUS='LOADED');

        -- Outcomes stay on the TFM rows only. Nothing is copied back to STG (backlog #310):
        -- a FAILED-mode rerun finds these rows through DMT_UTIL_PKG.FAILED_RETRY_SELECTED.

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Report rows: ' || l_rows.COUNT
                           || ' | LOADED: ' || l_loaded
                           || ' | FAILED: ' || l_failed
                           || ' | lots of LOADED transactions marked LOADED.',
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
    END APPLY_CONTRACT_V1_MISC_RECEIPTS;

    -- --------------------------------------------------------
    -- PROPAGATE_DOCUMENT_ERRORS (private, backlog #167). Inventory transaction
    -- import rejects a transaction together with its lot and serial detail: the
    -- transaction stays in INV_TRANSACTIONS_INTERFACE at PROCESS_FLAG 3 carrying
    -- the real error (a lot/serial defect included -- Fusion writes it inline on
    -- the transaction row), and the children never post. This quotes the rejected
    -- transaction's real Fusion error onto every not-LOADED lot and serial row of
    -- that transaction (design section 5, "Whole-document rejection carries the
    -- real error to every grain"), in the shared format
    -- '[FUSION_ERROR] Rejected with document: transaction <SOURCE_LINE_ID>: <msg>'.
    -- Child-to-parent link (backlog #552): the child's SOURCE_LINE_ID is the
    -- parent transaction's TFM_SEQUENCE_ID, stamped by the transform -- the same
    -- join DMT_MISC_RECEIPT_FBDI_GEN_PKG uses to write the lot and serial CSVs and
    -- the lot LOADED cascade above uses. Only a transaction whose own error is a real [FUSION_ERROR] (not
    -- itself a quote) is a source. Idempotent: a row already carrying the quote is
    -- skipped. LOADED rows are never touched. Scoped to the run and work item;
    -- static SQL; NO COMMIT.
    -- --------------------------------------------------------
    PROCEDURE PROPAGATE_DOCUMENT_ERRORS (
        p_run_id        IN NUMBER,
        p_work_queue_id IN NUMBER
    ) IS
        C_PROC   CONSTANT VARCHAR2(30) := 'PROPAGATE_DOCUMENT_ERRORS';
        C_TAG    CONSTANT VARCHAR2(20) := '[FUSION_ERROR]';
        l_marker VARCHAR2(30) := DMT_UTIL_PKG.C_DOC_ERROR_MARKER;
        l_pairs  T_DOC_PAIR_TBL;
        l_lots   NUMBER := 0;
        l_sers   NUMBER := 0;
        l_step   VARCHAR2(200);
    BEGIN
        l_step := 'collecting rejected transactions for run ' || p_run_id;
        SELECT t.TFM_SEQUENCE_ID,
               -- Names the transaction by its SOURCE_LINE_ID (its RECON_KEY) so a
               -- reader of the lot or serial row sees which transaction failed.
               DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR(
                   'transaction', TO_CHAR(t.SOURCE_LINE_ID),
                   DBMS_LOB.SUBSTR(t.ERROR_TEXT, 3800, DBMS_LOB.INSTR(t.ERROR_TEXT, C_TAG)))
        BULK COLLECT INTO l_pairs
        FROM   DMT_INV_TRX_TFM_TBL t
        WHERE  t.RUN_ID = p_run_id
        AND    (p_work_queue_id IS NULL OR t.WORK_QUEUE_ID IS NULL
                OR t.WORK_QUEUE_ID = p_work_queue_id)
        AND    t.TFM_STATUS = 'FAILED'
        AND    DBMS_LOB.INSTR(t.ERROR_TEXT, C_TAG) > 0
        AND    DBMS_LOB.INSTR(t.ERROR_TEXT, l_marker) = 0;

        l_step := 'appending quoted transaction errors to its lots';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_INV_TRX_LOTS_TFM_TBL l
            SET    l.TFM_STATUS           = 'FAILED',
                   l.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(l.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   l.RESULTS_UPDATED_DATE = SYSDATE,
                   l.LAST_UPDATED_DATE    = SYSDATE
            WHERE  l.RUN_ID = p_run_id
            AND    l.TFM_STATUS <> 'LOADED'
            AND    l_pairs(i).QUOTED_ERROR IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(l.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0
            AND    l.SOURCE_LINE_ID = l_pairs(i).PARENT_TFM_SEQ;
        l_lots := SQL%ROWCOUNT;

        l_step := 'appending quoted transaction errors to its serials';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_INV_TRX_SERIALS_TFM_TBL s
            SET    s.TFM_STATUS           = 'FAILED',
                   s.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(s.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   s.RESULTS_UPDATED_DATE = SYSDATE,
                   s.LAST_UPDATED_DATE    = SYSDATE
            WHERE  s.RUN_ID = p_run_id
            AND    s.TFM_STATUS <> 'LOADED'
            AND    l_pairs(i).QUOTED_ERROR IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(s.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0
            AND    s.SOURCE_LINE_ID = l_pairs(i).PARENT_TFM_SEQ;
        l_sers := SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Rejected transactions: ' || l_pairs.COUNT
                           || ' | lots given a quoted error: ' || l_lots
                           || ' | serials given a quoted error: ' || l_sers || '.',
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
    -- Contract v1 apply. The MiscReceipts load ESS id is the Contract v1
    -- P_LOAD_REQUEST_ID; the report's run-scoped selector (P_RUN_ID, via the
    -- batch key 'DMT-'||run) picks up the whole run.
    -- --------------------------------------------------------
    PROCEDURE RECONCILE_BATCH (
        p_run_id  IN NUMBER,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RECONCILE_BATCH';
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' start. run_id: ' || p_run_id,
            'INFO',
            C_PKG, C_PROC);

        APPLY_CONTRACT_V1_MISC_RECEIPTS(p_run_id, TO_CHAR(p_load_ess_id));

        -- Lots and serials rejected with their transaction carry the transaction's
        -- real error. Runs after the per-row apply and BEFORE the shared unaccounted
        -- sweep (DMT_QUEUE_WORKER_PKG.RECONCILE_ONE).
        PROPAGATE_DOCUMENT_ERRORS(p_run_id, p_work_queue_id);

        -- Unresolved records are intentionally left GENERATED (unaccounted).
        -- No fabricated FAILED: the accounting gate reports the object not-DONE
        -- and the funnel surfaces these as UNRECONCILED.

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RECONCILE_BATCH;


    -- --------------------------------------------------------
    -- RESET_UNACCOUNTED (backlog #95) -- see spec. Static UPDATE(s) over the
    -- compile-time-known MiscReceipts TFM table(s). Flips this run's UNACCOUNTED rows
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
        UPDATE DMT_INV_TRX_TFM_TBL
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
        UPDATE DMT_INV_TRX_LOTS_TFM_TBL
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
        UPDATE DMT_INV_TRX_SERIALS_TFM_TBL
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
            C_PROC || ': reset ' || l_reset || ' UNACCOUNTED MiscReceipts row(s) to GENERATED '
            || 'for re-reconcile.',
            'INFO', C_PKG, C_PROC);
        -- NO COMMIT -- the caller (RERUN_RUN) owns the transaction.
    END RESET_UNACCOUNTED;

END DMT_MISC_RECEIPT_RESULTS_PKG;
/
