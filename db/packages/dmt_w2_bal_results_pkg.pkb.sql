-- PACKAGE BODY DMT_W2_BAL_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_W2_BAL_RESULTS_PKG"
AS
-- ============================================================
-- DMT_W2_BAL_RESULTS_PKG body
-- Balance Initialization HDL reconciliation via DMT_HDL_UTIL_PKG.
--
-- CORRECTED MODEL (2026-09-17): W2Balances loads as the "Balance Initialization"
-- HDL object -- two objects in one zip, InitializeBalanceBatchHeader and
-- InitializeBalanceBatchLine, keyed by BatchName (run prefix || work-queue id,
-- backlog #413). The batch
-- header lands in PAY_BAL_BATCH_HEADERS; the reconciler confirms LOADED from that
-- base table matched on BATCH_NAME = the run's BatchName = the TFM RECON_KEY,
-- selected by that exact value (report V2, P_FUSION_BATCH_ID).
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_W2_BAL_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'W2Balances';

    -- --------------------------------------------------------
    -- APPLY_CONTRACT_V1_W2BALANCES (private)
    -- The Contract v1 base-tier positive proof for the W2Balances record (design
    -- section 5), Option A shape (owner decision on PR #248). The shared package
    -- DMT_RECON_CONTRACT_PKG.FETCH_ROWS runs the W2Balances recon report over BIP
    -- and returns the parsed rows (no dynamic SQL, no TFM reference there); the APPLY
    -- here is STATIC SQL against the compile-time-known W2Balances TFM table. It
    -- confirms each migrated balance-initialization batch in the Fusion payroll
    -- balance base table PAY_BAL_BATCH_HEADERS by the BatchName business key
    -- (PAY_BAL_BATCH_HEADERS.BATCH_NAME = the run's BatchName = RECON_KEY) and
    -- marks that W2Balances TFM row LOADED with the real Fusion BATCH_ID stamped
    -- into FUSION_BALANCE_ID; any ERROR row is marked
    -- FAILED with the real Fusion error. This REPLACES the bulk LOOKUP_FUSION_IDS
    -- positive path for W2Balances. The HDL data set request id is the Contract v1
    -- P_LOAD_REQUEST_ID. Mirrors the Workers template (DMT_WORKER_RESULTS_PKG).
    -- --------------------------------------------------------
    PROCEDURE APPLY_CONTRACT_V1_W2BALANCES (
        p_run_id     IN NUMBER,
        p_request_id IN VARCHAR2
    ) IS
        C_PROC      CONSTANT VARCHAR2(30) := 'APPLY_CONTRACT_V1_W2B';
        l_gen_count NUMBER := 0;
        l_rows      DMT_RECON_CONTRACT_PKG.T_RECON_TBL;
        l_err_code  NUMBER;
        l_loaded    NUMBER := 0;
        l_failed    NUMBER := 0;
        l_rc        NUMBER := 0;    -- backlog #65: rows matched by the current tier
        l_dff_seq   NUMBER;          -- backlog #65 tier 2: TFM_SEQUENCE_ID from DFF_KEY
        l_tier      VARCHAR2(10);    -- backlog #65: which tier matched (audit log)
        l_batch_name DMT_W2_BAL_TFM_TBL.RECON_KEY%TYPE;  -- backlog #413: exact BatchName
    BEGIN
        -- Generated-row count is done statically here (not in the shared pkg),
        -- and drives the shared fetch's keyset page-count cap.
        SELECT COUNT(*) INTO l_gen_count
        FROM   DMT_W2_BAL_TFM_TBL
        WHERE  RUN_ID = p_run_id;

        -- Backlog #413: the report finds the batch by the EXACT BatchName this
        -- run's generator wrote (the TFM RECON_KEY: run prefix || work-queue id),
        -- never by a prefix pattern. PAY_BAL_BATCH_HEADERS carries no request id,
        -- so the name is the only exact selector. Sent as P_FUSION_BATCH_ID.
        SELECT MAX(RECON_KEY) INTO l_batch_name
        FROM   DMT_W2_BAL_TFM_TBL
        WHERE  RUN_ID = p_run_id;

        DMT_RECON_CONTRACT_PKG.FETCH_ROWS(
            p_cemli_code      => C_CEMLI,
            p_run_id          => p_run_id,
            p_load_ess_id     => TO_NUMBER(p_request_id),
            p_row_cap         => l_gen_count,
            x_rows            => l_rows,
            x_error_code      => l_err_code,
            p_fusion_batch_id => TO_NUMBER(l_batch_name DEFAULT NULL ON CONVERSION ERROR));

        -- A transport / SOAP failure raises loudly (design section 5: never a
        -- silent retry, never a zero-row "success"); the fetch already logged detail.
        IF l_err_code <> DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20094,
                'APPLY_CONTRACT_V1_W2BALANCES: Contract v1 fetch failed for '
                || 'W2Balances (detail in DMT_LOG_TBL).');
        END IF;

        IF l_rows.COUNT = 0 THEN
            -- Zero report rows is never success (design section 5): leave the
            -- remaining GENERATED rows for the existing unaccounted sweep.
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ': W2Balances recon report returned zero '
                               || 'rows; GENERATED rows left for the unaccounted sweep '
                               || '(never a silent success).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
        ELSE
            FOR i IN 1 .. l_rows.COUNT LOOP
                l_rc   := 0;     -- backlog #65: reset per row so a prior row's tier
                l_tier := NULL;  -- cannot mislabel this row's audit log line.
                IF l_rows(i).SOURCE_TYPE = 'BASE'
                   AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                   AND l_rows(i).FUSION_ID IS NOT NULL THEN
                    -- Positive proof: balance batch found in PAY_BAL_BATCH_HEADERS
                    -- with a real BATCH_ID. The ONLY path to LOADED.
                    --
                    -- Backlog #65 three-tier match (owner order on PR #481), mirroring
                    -- APPLY_CONTRACT_V1_WORKERS exactly. Tier 1 is the stamped Slot A
                    -- reference (RECON_KEY = RECORD_KEY, exactly as before). Only if
                    -- tier 1 matches NO TFM row do we fall through: tier 2 (the Slot C
                    -- DFF stamp: TFM_SEQUENCE_ID = the trailing segment of DFF_KEY) --
                    -- this recon DM emits DMT_REFERENCE as CAST(NULL), so DFF_KEY is
                    -- null and tier 2 is a runtime no-op, kept uniform with the shared
                    -- template -- and then tier 3 (the business key: the report's
                    -- SOURCE_REF, returned as BUSINESS_KEY, which for this object is the
                    -- same stamped value as RECORD_KEY, so it matches the TFM RECON_KEY).
                    -- Every tier-1 hit short-circuits, so loaded outcomes are identical
                    -- to before. Static UPDATEs.
                    UPDATE DMT_W2_BAL_TFM_TBL
                    SET    TFM_STATUS           = 'LOADED',
                           FUSION_BALANCE_ID    = l_rows(i).FUSION_ID,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID    = p_run_id
                    AND    RECON_KEY = l_rows(i).RECORD_KEY
                    AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                    l_rc := SQL%ROWCOUNT;
                    l_tier := CASE WHEN l_rc > 0 THEN 'TIER1' END;

                    -- Tier 2 (DFF): only when tier 1 matched nothing and a DFF stamp is
                    -- present. This object has no DFF carrier, so this is normally a
                    -- no-op; kept uniform with the shared three-tier template.
                    IF l_rc = 0 AND l_rows(i).DFF_KEY IS NOT NULL THEN
                        l_dff_seq := TO_NUMBER(
                            REGEXP_SUBSTR(l_rows(i).DFF_KEY, '[0-9]+$') DEFAULT NULL ON CONVERSION ERROR);
                        IF l_dff_seq IS NOT NULL THEN
                            UPDATE DMT_W2_BAL_TFM_TBL
                            SET    TFM_STATUS           = 'LOADED',
                                   FUSION_BALANCE_ID    = l_rows(i).FUSION_ID,
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
                    -- matched nothing. The business key is the report's SOURCE_REF
                    -- (returned as BUSINESS_KEY), equal to the stamped RECON_KEY value.
                    IF l_rc = 0 AND l_rows(i).BUSINESS_KEY IS NOT NULL THEN
                        UPDATE DMT_W2_BAL_TFM_TBL
                        SET    TFM_STATUS           = 'LOADED',
                               FUSION_BALANCE_ID    = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).BUSINESS_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_rc := SQL%ROWCOUNT;
                        IF l_rc > 0 THEN l_tier := 'TIER3'; END IF;
                    END IF;

                    l_loaded := l_loaded + l_rc;
                    IF l_tier IN ('TIER2','TIER3') THEN
                        DMT_UTIL_PKG.LOG(p_run_id,
                            C_PROC || ': matched a LOADED W2Balance via ' || l_tier ||
                            ' fallback (tier 1 stamped ref did not resolve). FUSION_ID '
                            || l_rows(i).FUSION_ID || '.', 'INFO', C_PKG, C_PROC);
                    END IF;

                ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                      AND l_rows(i).ERROR_MESSAGE IS NOT NULL THEN
                    -- A real, specific Fusion error -> FAILED on the exact
                    -- message (never composed). Static UPDATE.
                    UPDATE DMT_W2_BAL_TFM_TBL
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
                    -- the existing unaccounted sweep. Never fabricate an outcome.
                    NULL;
                END IF;
            END LOOP;
        END IF;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Report rows: ' || l_rows.COUNT
                           || ' | LOADED: ' || l_loaded
                           || ' | FAILED: ' || l_failed || '.',
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
    END APPLY_CONTRACT_V1_W2BALANCES;

    -- --------------------------------------------------------
    -- APPLY_HDL_ERRORS (private, backlog #288)
    -- Per-record HDL errors, static SQL. This object's generator writes NO
    -- SourceSystemId, so no message can be tied to one record exactly (and a
    -- prefix guess is never made). Its messages reach the rows only through
    -- APPLY_FILE_ERRORS (messages that name no record). Kept so every HCM
    -- results package has the same shape; the per-object backlog item gives the
    -- generator a SourceSystemId.
    -- --------------------------------------------------------
    PROCEDURE APPLY_HDL_ERRORS (
        p_run_id     IN NUMBER,
        p_request_id IN VARCHAR2
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'APPLY_HDL_ERRORS';
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. No SourceSystemId is written for this object; nothing to match.',
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
    END APPLY_HDL_ERRORS;

    -- --------------------------------------------------------
    -- APPLY_FILE_ERRORS (private, backlog #288)
    -- Whole-file rejections, static SQL. Messages that name no record (no
    -- SourceSystemId: an invalid METADATA line, an unknown file, a data-set
    -- message) reject every record of their .dat file. They are applied LAST,
    -- after the per-record errors and the base-table proof, and only to rows
    -- still GENERATED, so a row proven LOADED or already FAILED on its own error
    -- is never touched. The text is Fusion's own, named with the file and line.
    -- --------------------------------------------------------
    PROCEDURE APPLY_FILE_ERRORS (
        p_run_id     IN NUMBER,
        p_request_id IN VARCHAR2
    ) IS
        C_PROC   CONSTANT VARCHAR2(30) := 'APPLY_FILE_ERRORS';
        l_text   VARCHAR2(4000);
        l_failed NUMBER := 0;
    BEGIN
        -- DMT_W2_BAL_TFM_TBL: whole-file messages of InitializeBalanceBatchHeader.dat
        l_text := DMT_HDL_UTIL_PKG.FILE_LEVEL_ERRORS(p_request_id, 'InitializeBalanceBatchHeader.dat');
        IF l_text IS NOT NULL THEN
            UPDATE DMT_W2_BAL_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_text),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID     = p_run_id
            AND    t.TFM_STATUS = 'GENERATED';
            l_failed := l_failed + SQL%ROWCOUNT;
        END IF;

        -- DMT_W2_BAL_DTL_TFM_TBL: whole-file messages of InitializeBalanceBatchLine.dat
        l_text := DMT_HDL_UTIL_PKG.FILE_LEVEL_ERRORS(p_request_id, 'InitializeBalanceBatchLine.dat');
        IF l_text IS NOT NULL THEN
            UPDATE DMT_W2_BAL_DTL_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_text),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID     = p_run_id
            AND    t.TFM_STATUS = 'GENERATED';
            l_failed := l_failed + SQL%ROWCOUNT;
        END IF;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Rows FAILED by a whole-file HDL error: ' || l_failed || '.',
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
    END APPLY_FILE_ERRORS;

    PROCEDURE RECONCILE_BATCH (
        p_run_id IN NUMBER,
        p_request_id     IN VARCHAR2,
        p_dataset_status IN VARCHAR2 DEFAULT NULL
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RECONCILE_BATCH';
        l_msg_count NUMBER;  -- HDL error messages staged for this data set
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' start. RequestId: ' || p_request_id,
            p_package        => C_PKG,
            p_procedure      => C_PROC);


        -- Per-record HDL errors (backlog #288): stage every page of this data
        -- set's error messages, then mark FAILED only the rows a message names
        -- exactly. LOADED comes only from base-table proof; there is no
        -- data-set-status promotion and no write-back to the STG table.
        DMT_HDL_UTIL_PKG.STAGE_HDL_MESSAGES(
            p_run_id        => p_run_id,
            p_request_id    => p_request_id,
            p_log_context   => C_CEMLI,
            x_message_count => l_msg_count,
            p_cemli_code     => C_CEMLI);
        APPLY_HDL_ERRORS(p_run_id, p_request_id);

        -- Contract v1 base-tier positive proof (design section 5), Option A shape
        -- (owner decision on PR #248): the shared package fetches the parsed report
        -- rows (no dynamic SQL, no TFM reference there) and the APPLY is done here
        -- as STATIC SQL against the compile-time-known W2Balances TFM table. This
        -- REPLACES the prior LOOKUP_FUSION_IDS positive path for W2Balances.
        APPLY_CONTRACT_V1_W2BALANCES(p_run_id, p_request_id);


        -- Whole-file HDL rejections last, only on rows still open (backlog #288).
        APPLY_FILE_ERRORS(p_run_id, p_request_id);

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' complete. All 2 object type(s) reconciled.',
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

END DMT_W2_BAL_RESULTS_PKG;
/
