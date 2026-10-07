-- PACKAGE BODY DMT_GL_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_GL_RESULTS_PKG" AS
-- ============================================================
-- DMT_GL_RESULTS_PKG body — BIP reconciliation, Contract v1, Option A.
--
-- GLBalances reconciles through the ONE shared Contract v1 parser
-- DMT_RECON_CONTRACT_PKG.FETCH_ROWS (the Workers / Absences / AP
-- template, owner decision Option A on PR #248 — backlog #92
-- conformance migration). The shape:
--
--   1. FETCH (shared): DMT_RECON_CONTRACT_PKG.FETCH_ROWS runs the
--      nine-column recon report over BIP, keyset-pages it, parses every
--      page, and returns one collection of the seven Contract v1
--      response fields. No GL-specific reader; no paging loop here.
--   2. APPLY (STATIC): a single FOR loop over the returned collection
--      marks LOADED (capturing the per-line composite FUSION_ID) for
--      BASE/SUCCESS rows and FAILED (capturing the real Fusion error) for
--      ERROR rows, via STATIC UPDATEs against the literally-named TFM
--      table keyed on RECON_KEY — exactly the Absences / AP template.
--      (FETCH_ROWS returns a PL/SQL-only INDEX BY collection, so the
--      apply is a row loop, not a TABLE() MERGE.)
--
-- GL two-tier semantics (FUSION_STATUS is normalized in the DM to
-- SUCCESS/ERROR, so the APPLY is object-agnostic):
--   BASE  + SUCCESS (balanced/postable)          => LOADED
--   BASE  + ERROR   (unbalanced; report V2 returns NO message, since
--                    Fusion records no error for it) => left GENERATED,
--                    settled UNACCOUNTED by the shared sweep
--   INTERFACE + ERROR + message (Journal Import rejection, the message
--                    is GL_INTERFACE.STATUS: STATUS_DESCRIPTION) => FAILED
--   INTERFACE with no error is corroborating only, never LOADED on its
--   own (LOADED requires a BASE/FUSION_ID row).
-- Rows with no match and no error STAY GENERATED (unaccounted) — the
-- shared unaccounted sweep, never this reconciler, marks them.
--
-- Transport is the shared DMT_UTIL_PKG.RUN_BIP_REPORT (via FETCH_ROWS;
-- no private UTL_HTTP copy). Outcomes are written to the TFM table only;
-- nothing is written back to staging.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_GL_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'GLBalances';

    -- --------------------------------------------------------
    -- APPLY_CONTRACT_V1_GL_BALANCES (private) — the Contract v1 apply.
    -- Calls the ONE shared Contract v1 fetch, then a single FOR loop marks
    -- each row with STATIC UPDATEs against the compile-time-known TFM table.
    -- --------------------------------------------------------
    PROCEDURE APPLY_CONTRACT_V1_GL_BALANCES (
        p_run_id        IN NUMBER,
        p_load_ess_id   IN NUMBER,
        p_import_ess_id IN NUMBER,
        p_work_queue_id IN NUMBER
    ) IS
        C_PROC      CONSTANT VARCHAR2(40) := 'APPLY_CONTRACT_V1_GL_BALANCES';
        l_gen_count NUMBER := 0;
        l_rows      DMT_RECON_CONTRACT_PKG.T_RECON_TBL;
        l_err_code  NUMBER;
        l_loaded    NUMBER := 0;
        l_failed    NUMBER := 0;
        l_rc        NUMBER := 0;    -- rows matched by the current tier
        l_dff_seq   NUMBER;          -- backlog #65 tier 2: TFM_SEQUENCE_ID from DFF_KEY
        l_tier      VARCHAR2(10);    -- backlog #65: which tier matched (audit log)
    BEGIN
        -- Generated-row count drives the shared fetch's keyset page-count cap.
        -- Done statically here (not in the shared pkg); scoped to a child item
        -- when a spawn-per-partition child owns this reconcile.
        SELECT COUNT(*) INTO l_gen_count
        FROM   DMT_GL_INTERFACE_TFM_TBL
        WHERE  RUN_ID = p_run_id
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id);

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
            RAISE_APPLICATION_ERROR(-20038,
                C_PROC || ': Contract v1 fetch failed for CEMLI ' || C_CEMLI
                || ' (detail in DMT_LOG_TBL).');
        END IF;

        IF l_rows.COUNT = 0 THEN
            -- Zero report rows is never success (Contract v1). The GENERATED
            -- rows stay unaccounted; the accounting gate reports not-DONE.
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': report returned zero rows. GENERATED rows left '
                || 'unaccounted (not marked FAILED).',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
            RETURN;
        END IF;

        FOR i IN 1 .. l_rows.COUNT LOOP
            l_rc   := 0;       -- backlog #65: reset per row so a prior row's tier
            l_tier := NULL;    -- cannot mislabel this row's audit log line.
            IF l_rows(i).SOURCE_TYPE = 'BASE'
               AND l_rows(i).FUSION_STATUS = 'SUCCESS'
               AND l_rows(i).FUSION_ID IS NOT NULL THEN
                -- Positive proof: journal line found in the Fusion base tables
                -- with a real id. The ONLY path to LOADED. FUSION_ID is the
                -- per-line composite JE_HEADER_ID~JE_LINE_NUM, stamped into
                -- FUSION_JE_HEADER_ID as line-grain proof (two lines of one
                -- journal get DIFFERENT ids). RECON_KEY is unique per TFM line.
                --
                -- Backlog #65 three-tier match (owner order on PR #481). Tier 1 is
                -- the stamped Slot A reference (RECON_KEY = RECORD_KEY, exactly as
                -- before). Only if tier 1 matches NO TFM row (SQL%ROWCOUNT = 0) do we
                -- fall to tier 2 (the Slot C DFF stamp: TFM_SEQUENCE_ID = the trailing
                -- segment of DFF_KEY) and then tier 3 (the business key: RECON_KEY =
                -- BUSINESS_KEY -- for GL the per-line SOURCE_REF equals RECON_KEY, so
                -- tier 3 is the same key and safely degenerate). Because every tier-1
                -- hit short-circuits, loaded outcomes are identical to before.
                -- Static UPDATEs, scoped to RUN_ID + (optional) WORK_QUEUE_ID.
                UPDATE DMT_GL_INTERFACE_TFM_TBL
                SET    TFM_STATUS           = 'LOADED',
                       FUSION_JE_HEADER_ID  = l_rows(i).FUSION_ID,
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID    = p_run_id
                AND    RECON_KEY = l_rows(i).RECORD_KEY
                AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id)
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
                        UPDATE DMT_GL_INTERFACE_TFM_TBL
                        SET    TFM_STATUS           = 'LOADED',
                               FUSION_JE_HEADER_ID  = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    TFM_SEQUENCE_ID = l_dff_seq
                        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id)
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_rc := SQL%ROWCOUNT;
                        IF l_rc > 0 THEN l_tier := 'TIER2'; END IF;
                    END IF;
                END IF;

                -- Tier 3 (business key): last resort, only when tiers 1 and 2 both
                -- matched nothing. GL's business key is the per-line reference, equal
                -- to RECON_KEY, so this matches RECON_KEY = BUSINESS_KEY.
                IF l_rc = 0 AND l_rows(i).BUSINESS_KEY IS NOT NULL THEN
                    UPDATE DMT_GL_INTERFACE_TFM_TBL
                    SET    TFM_STATUS           = 'LOADED',
                           FUSION_JE_HEADER_ID  = l_rows(i).FUSION_ID,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID    = p_run_id
                    AND    RECON_KEY = l_rows(i).BUSINESS_KEY
                    AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id)
                    AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                    l_rc := SQL%ROWCOUNT;
                    IF l_rc > 0 THEN l_tier := 'TIER3'; END IF;
                END IF;

                l_loaded := l_loaded + l_rc;
                IF l_tier IN ('TIER2','TIER3') THEN
                    DMT_UTIL_PKG.LOG(p_run_id,
                        C_PROC || ': matched a LOADED GL line via ' || l_tier ||
                        ' fallback (tier 1 stamped ref did not resolve). FUSION_ID '
                        || l_rows(i).FUSION_ID || '.', 'INFO', C_PKG, C_PROC);
                END IF;

            ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                  AND l_rows(i).ERROR_MESSAGE IS NOT NULL THEN
                -- A real, specific Fusion error (a Journal Import rejection:
                -- STATUS: STATUS_DESCRIPTION) -> FAILED on the exact message (never composed),
                -- appended tagged [FUSION_ERROR]; never overwrite. Static UPDATE.
                UPDATE DMT_GL_INTERFACE_TFM_TBL
                SET    TFM_STATUS           = 'FAILED',
                       ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(
                                                ERROR_TEXT,
                                                '[FUSION_ERROR] ' || l_rows(i).ERROR_MESSAGE),
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID    = p_run_id
                AND    RECON_KEY = l_rows(i).RECORD_KEY
                AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id)
                AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                l_failed := l_failed + SQL%ROWCOUNT;

            ELSE
                -- INTERFACE/SUCCESS (corroborating, never sufficient) or a
                -- non-terminal status with no real error: leave the row for the
                -- existing unaccounted sweep. Never fabricate an outcome.
                NULL;
            END IF;
        END LOOP;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. Report rows: ' || l_rows.COUNT ||
            ' | LOADED: ' || l_loaded || ', FAILED: ' || l_failed ||
            '. Unmatched/no-error rows left GENERATED (unaccounted).',
            'INFO', C_PKG, C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed. CEMLI: ' || C_CEMLI,
                SQLERRM, C_PKG, C_PROC);
            RAISE;
    END APPLY_CONTRACT_V1_GL_BALANCES;

    -- --------------------------------------------------------
    -- RECONCILE_BATCH — the reconcile entry point (RECON dispatch style).
    -- Delegates straight to the Contract v1 apply. The load ESS id is the
    -- Contract v1 P_LOAD_REQUEST_ID; the import ESS id is P_IMPORT_ESS_ID.
    -- NO COMMIT — the orchestrator controls transaction boundaries.
    -- --------------------------------------------------------
    PROCEDURE RECONCILE_BATCH (
        p_run_id        IN NUMBER,
        p_load_ess_id   IN NUMBER,
        p_import_ess_id IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RECONCILE_BATCH';
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' start. load_ess_id: ' || p_load_ess_id ||
            ' | import_ess_id: ' || NVL(TO_CHAR(p_import_ess_id), 'NULL'),
            'INFO', C_PKG, C_PROC);

        APPLY_CONTRACT_V1_GL_BALANCES(
            p_run_id        => p_run_id,
            p_load_ess_id   => p_load_ess_id,
            p_import_ess_id => p_import_ess_id,
            p_work_queue_id => p_work_queue_id);

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
    -- compile-time-known GLBalances TFM table(s). Flips this run's UNACCOUNTED rows
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
        UPDATE DMT_GL_INTERFACE_TFM_TBL
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
            C_PROC || ': reset ' || l_reset || ' UNACCOUNTED GLBalances row(s) to GENERATED '
            || 'for re-reconcile.',
            'INFO', C_PKG, C_PROC);
        -- NO COMMIT -- the caller (RERUN_RUN) owns the transaction.
    END RESET_UNACCOUNTED;

END DMT_GL_RESULTS_PKG;
/
