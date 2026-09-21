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
-- After the transaction tier settles, lot detail is accounted by its parent
-- transaction's verdict (found outcome via the parent, not a fabricated verdict),
-- then all outcomes are echoed back to the STG table. Serial detail carries no
-- stored parent-transaction key in the TFM table and is left for the honest sweep.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_MISC_RECEIPT_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'MiscReceipts';

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
    BEGIN
        -- Generated-row count drives the shared fetch's keyset page-count cap.
        -- Done statically here (not in the shared pkg).
        SELECT COUNT(*) INTO l_gen_count
        FROM   DMT_INV_TRX_TFM_TBL
        WHERE  RUN_ID = p_run_id;

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
                -- ===== TIER: TRANSACTIONS (OBJECT_TYPE = 'MiscReceipts') =====
                IF l_rows(i).OBJECT_TYPE = 'MiscReceipts' THEN
                    IF l_rows(i).SOURCE_TYPE = 'BASE'
                       AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                       AND l_rows(i).FUSION_ID IS NOT NULL THEN
                        -- Positive proof: transaction found in INV_MATERIAL_TXNS
                        -- with a real TRANSACTION_ID. The ONLY path to LOADED.
                        UPDATE DMT_INV_TRX_TFM_TBL
                        SET    TFM_STATUS           = 'LOADED',
                               FUSION_ID            = TO_CHAR(l_rows(i).FUSION_ID),
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_loaded := l_loaded + SQL%ROWCOUNT;

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
                END IF;
            END LOOP;
        END IF;

        -- Cascade transaction outcome to its lot detail. A lot line is child
        -- detail of an inventory transaction and loads with it in the same FBDI,
        -- linked by the lot/serial interface number. A lot whose transaction is
        -- base-confirmed LOADED is LOADED; whose transaction was rejected is
        -- FAILED carrying the transaction's real error. Found outcome via the
        -- parent, not a fabricated verdict. (Serial detail carries no stored
        -- parent-transaction key in the TFM table and cannot be linked here
        -- without a transform change; it is left for the honest sweep.)
        UPDATE DMT_INV_TRX_LOTS_TFM_TBL l
        SET    l.TFM_STATUS='LOADED', l.RESULTS_UPDATED_DATE=SYSDATE, l.LAST_UPDATED_DATE=SYSDATE
        WHERE  l.RUN_ID=p_run_id AND l.TFM_STATUS NOT IN ('LOADED','FAILED')
        AND    EXISTS (SELECT 1 FROM DMT_INV_TRX_TFM_TBL t WHERE t.RUN_ID=p_run_id
                       AND t.INV_LOTSERIAL_INTERFACE_NUM=l.INVENTORY_LOT_INTERFACE_NUMBER
                       AND t.TFM_STATUS='LOADED');
        UPDATE DMT_INV_TRX_LOTS_TFM_TBL l
        SET    l.TFM_STATUS='FAILED',
               l.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(l.ERROR_TEXT,
                   '[FUSION_ERROR] Lot not created; its inventory transaction was rejected by Fusion: ' ||
                   (SELECT t.ERROR_TEXT FROM DMT_INV_TRX_TFM_TBL t WHERE t.RUN_ID=p_run_id
                    AND t.INV_LOTSERIAL_INTERFACE_NUM=l.INVENTORY_LOT_INTERFACE_NUMBER
                    AND t.TFM_STATUS='FAILED' AND ROWNUM=1)),
               l.RESULTS_UPDATED_DATE=SYSDATE, l.LAST_UPDATED_DATE=SYSDATE
        WHERE  l.RUN_ID=p_run_id AND l.TFM_STATUS NOT IN ('LOADED','FAILED')
        AND    EXISTS (SELECT 1 FROM DMT_INV_TRX_TFM_TBL t WHERE t.RUN_ID=p_run_id
                       AND t.INV_LOTSERIAL_INTERFACE_NUM=l.INVENTORY_LOT_INTERFACE_NUMBER
                       AND t.TFM_STATUS='FAILED');

        -- Echo to STG
        UPDATE DMT_INV_TRX_STG_TBL stg
        SET    stg.STG_STATUS = 'LOADED', stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_INV_TRX_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');

        UPDATE DMT_INV_TRX_STG_TBL stg
        SET    stg.STG_STATUS     = 'FAILED',
               stg.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_INV_TRX_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                    AND    t.RUN_ID  = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_INV_TRX_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Report rows: ' || l_rows.COUNT
                           || ' | LOADED: ' || l_loaded
                           || ' | FAILED: ' || l_failed
                           || ' | lot detail accounted by parent transaction verdict.',
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
            C_PKG, C_PROC);

        APPLY_CONTRACT_V1_MISC_RECEIPTS(p_run_id, TO_CHAR(p_load_ess_id));

        -- Unresolved records are intentionally left GENERATED (unaccounted).
        -- No fabricated FAILED: the accounting gate reports the object not-DONE
        -- and the funnel surfaces these as UNRECONCILED.

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete.', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RECONCILE_BATCH;

END DMT_MISC_RECEIPT_RESULTS_PKG;
/
