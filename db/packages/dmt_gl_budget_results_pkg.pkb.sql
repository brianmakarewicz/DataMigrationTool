-- PACKAGE BODY DMT_GL_BUDGET_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_GL_BUDGET_RESULTS_PKG" AS
-- ============================================================
-- GL Budget Balances reconciliation (cell-grain, run-start window).
-- See package spec for the reconciliation model.
--
-- Change history:
--   2026-10-08  BM  Cross-grain propagation (PROPAGATE_DOCUMENT_ERRORS, backlog
--                   #174): cells left VALIDATED because another cell of the same
--                   budget run FAILED now end FAILED quoting that cell's real
--                   error instead of UNACCOUNTED.
-- ============================================================
    C_PKG        CONSTANT VARCHAR2(50) := 'DMT_GL_BUDGET_RESULTS_PKG';
    C_CEMLI      CONSTANT VARCHAR2(30) := 'GLBudgets';
    -- Clock-skew buffer applied to run-start so a small ATP<->Fusion time
    -- offset never excludes cells our own run just wrote. Pre-existing budget
    -- data is months old, so a few hours is safe.
    C_SKEW_HOURS CONSTANT NUMBER := 4;
    C_AMT_TOL    CONSTANT NUMBER := 0.01;   -- DR/CR match tolerance

    -- Cross-grain propagation (PROPAGATE_DOCUMENT_ERRORS, backlog #174).
    -- Working set: "budget run DOC_KEY (RUN_NAME) has cell SOURCE_SEQ with its own
    -- real Fusion error, so every other cell of that budget run must carry
    -- QUOTED_ERROR".
    TYPE T_DOC_PAIR IS RECORD (
        DOC_KEY      VARCHAR2(240),     -- RUN_NAME
        SOURCE_SEQ   NUMBER,            -- the source cell's TFM_SEQUENCE_ID
        QUOTED_ERROR VARCHAR2(4000)     -- DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR(...)
    );
    TYPE T_DOC_PAIR_TBL IS TABLE OF T_DOC_PAIR;

    -- (bip_soap_post + FETCH_BIP_RESULTS + PARSE_AND_UPDATE removed — together
    --  with their cell-key helper and cell-keyed map types. These implemented the
    --  old P_RUN_START / P_LEDGER_ID run-start / cell-key reconciliation with a
    --  PRIVATE BIP SOAP transport. That path was retired when the GLBudgets data
    --  model was rewritten to the nine-column Contract v1 shape (PR #360): the old
    --  parameters and the REC_TYPE / ACCOUNT_KEY columns the parser read no longer
    --  exist, and RECONCILE_BATCH stopped invoking them. The sole reconciliation
    --  path is now APPLY_CONTRACT_V1_GLBUDGETS via the shared
    --  DMT_RECON_CONTRACT_PKG.FETCH_ROWS (which itself uses the shared transport
    --  DMT_UTIL_PKG.RUN_BIP_REPORT). Removing the dead code deletes the last
    --  private BIP SOAP copy in this package.)

    -- --------------------------------------------------------
    -- APPLY_CONTRACT_V1_GLBUDGETS (private)
    -- The Contract v1 base-tier positive proof for GLBudgets — the SINGLE-TIER
    -- template proven for Expenditures (PR #363). The shared package
    -- DMT_RECON_CONTRACT_PKG.FETCH_ROWS runs the GLBudgets nine-column recon
    -- report over BIP (keyset paged, scoped to this run's load request id) and
    -- returns the parsed rows -- no dynamic SQL, no TFM reference there. The APPLY
    -- here is STATIC SQL against the compile-time-known GL Budget TFM table:
    --   * BASE / SUCCESS / FUSION_ID NOT NULL  -> LOADED, stamp FUSION_ID into
    --       FUSION_BUDGET_VERSION_ID. The ONLY path to LOADED.
    --   * FUSION_STATUS = ERROR with a real message -> FAILED, message appended as
    --       '[FUSION_ERROR] ' || message (never composed).
    --   * everything else left for the existing run-start / cell-key harvest
    --       (PARSE_AND_UPDATE) and the shared unaccounted sweep.
    --
    -- GLBudgets is structurally unlike a transaction object (budgets are CELLS):
    -- GL_BUDGET_BALANCES has no surrogate id, run id, request id or prefix, so the
    -- report's RECORD_KEY IS the composite cell key
    --   ledger|budget|period|currency|seg1..seg30 (~ NULL as '#')
    -- and the TFM's RECON_KEY is stamped to exactly that string by the transform.
    -- GL_BUDGET_VERSIONS.BUDGET_VERSION_ID is VPD-blocked on the demo instance
    -- (live SELECT -> ORA-00942, reconfirmed 2026-09-30), so there is no reachable
    -- Fusion surrogate id for a cell. The honest, non-null proof of load the report
    -- returns is therefore the cell's own NATURAL composite key built from base-table
    -- values (backlog #87): ledger~budget~period~code_combination_id (all four parts
    -- proven queryable as the reporting user). That composite is what the report's
    -- FUSION_ID column now carries and what lands in FUSION_BUDGET_VERSION_ID (the
    -- TFM's Fusion-id column, retyped NUMBER->VARCHAR2 for the composite). Rows
    -- already terminal (LOADED/FAILED) are never touched, so this runs safely
    -- alongside PARSE_AND_UPDATE without double-counting; whichever proves a cell
    -- first wins and the other's guard skips it.
    -- --------------------------------------------------------
    PROCEDURE APPLY_CONTRACT_V1_GLBUDGETS (
        p_run_id        IN NUMBER,
        p_request_id    IN VARCHAR2,
        p_import_ess_id IN NUMBER DEFAULT NULL
    ) IS
        C_PROC      CONSTANT VARCHAR2(30) := 'APPLY_CONTRACT_V1_GLBUDGETS';
        l_gen_count NUMBER := 0;
        l_rows      DMT_RECON_CONTRACT_PKG.T_RECON_TBL;
        l_err_code  NUMBER;
        l_loaded    NUMBER := 0;
        l_failed    NUMBER := 0;
        l_unaccounted NUMBER := 0;
        l_rc        NUMBER := 0;    -- backlog #65: rows matched by the current tier
        l_dff_seq   NUMBER;          -- backlog #65 tier 2: TFM_SEQUENCE_ID from DFF_KEY
        l_tier      VARCHAR2(10);    -- backlog #65: which tier matched (audit log)
    BEGIN
        -- Generated-row count (static, this object's own table) drives the shared
        -- fetch's keyset page-count cap.
        SELECT COUNT(*) INTO l_gen_count
        FROM   DMT_GL_BUDGET_INT_TFM_TBL
        WHERE  RUN_ID = p_run_id;

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
            RAISE_APPLICATION_ERROR(-20096,
                'APPLY_CONTRACT_V1_GLBUDGETS: Contract v1 fetch failed for '
                || 'GLBudgets (detail in DMT_LOG_TBL).');
        END IF;

        IF l_rows.COUNT = 0 THEN
            -- Zero report rows is never success (design section 5): leave the
            -- remaining GENERATED rows for the existing unaccounted sweep.
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ': GLBudgets recon report returned zero rows; '
                               || 'GENERATED rows left for the unaccounted sweep '
                               || '(never a silent success).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
        ELSE
            FOR i IN 1 .. l_rows.COUNT LOOP
                l_rc   := 0;       -- backlog #65: reset per row so a prior row's tier
                l_tier := NULL;    -- cannot mislabel this row's audit log line.
                IF l_rows(i).SOURCE_TYPE = 'BASE'
                   AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                   AND l_rows(i).FUSION_ID IS NOT NULL THEN
                    -- Positive proof: cell present in GL_BUDGET_BALANCES. FUSION_ID
                    -- is the cell's natural composite key
                    -- ledger~budget~period~code_combination_id (backlog #87) --
                    -- real base-table values, no VPD-blocked version id. The ONLY
                    -- path to LOADED.
                    --
                    -- Backlog #65 three-tier match (owner order on PR #481). Tier 1 is
                    -- the stamped Slot A reference (RECON_KEY = RECORD_KEY, exactly as
                    -- before -- for GLBudgets that is the composite cell key
                    -- ledger|budget|period|currency|seg1..seg30). Only if tier 1 matches
                    -- NO TFM row (SQL%ROWCOUNT = 0) do we fall to tier 2 (the Slot C DFF
                    -- stamp: TFM_SEQUENCE_ID = the trailing segment of DFF_KEY) and then
                    -- tier 3 (the business key: RECON_KEY = BUSINESS_KEY -- for GLBudgets
                    -- the report's SOURCE_REF IS the same composite cell key as
                    -- RECORD_KEY, so tier 3 is the same key and safely degenerate). The
                    -- composite cell key itself is unchanged; the three-tier fall-through
                    -- only wraps the match. Because every tier-1 hit short-circuits,
                    -- loaded outcomes are identical to before. Static UPDATEs.
                    UPDATE DMT_GL_BUDGET_INT_TFM_TBL
                    SET    TFM_STATUS               = 'LOADED',
                           FUSION_BUDGET_VERSION_ID = l_rows(i).FUSION_ID,
                           RESULTS_UPDATED_DATE     = SYSDATE,
                           LAST_UPDATED_DATE        = SYSDATE
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
                            UPDATE DMT_GL_BUDGET_INT_TFM_TBL
                            SET    TFM_STATUS               = 'LOADED',
                                   FUSION_BUDGET_VERSION_ID = l_rows(i).FUSION_ID,
                                   RESULTS_UPDATED_DATE     = SYSDATE,
                                   LAST_UPDATED_DATE        = SYSDATE
                            WHERE  RUN_ID    = p_run_id
                            AND    TFM_SEQUENCE_ID = l_dff_seq
                            AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                            l_rc := SQL%ROWCOUNT;
                            IF l_rc > 0 THEN l_tier := 'TIER2'; END IF;
                        END IF;
                    END IF;

                    -- Tier 3 (business key): last resort, only when tiers 1 and 2 both
                    -- matched nothing. GLBudgets' business key is the composite cell key,
                    -- equal to RECON_KEY, so this matches RECON_KEY = BUSINESS_KEY.
                    IF l_rc = 0 AND l_rows(i).BUSINESS_KEY IS NOT NULL THEN
                        UPDATE DMT_GL_BUDGET_INT_TFM_TBL
                        SET    TFM_STATUS               = 'LOADED',
                               FUSION_BUDGET_VERSION_ID = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE     = SYSDATE,
                               LAST_UPDATED_DATE        = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).BUSINESS_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_rc := SQL%ROWCOUNT;
                        IF l_rc > 0 THEN l_tier := 'TIER3'; END IF;
                    END IF;

                    l_loaded := l_loaded + l_rc;
                    IF l_tier IN ('TIER2','TIER3') THEN
                        DMT_UTIL_PKG.LOG(p_run_id,
                            C_PROC || ': matched a LOADED GLBudgets cell via ' || l_tier ||
                            ' fallback (tier 1 stamped ref did not resolve). FUSION_ID '
                            || l_rows(i).FUSION_ID || '.', 'INFO', C_PKG, C_PROC);
                    END IF;

                ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                      AND l_rows(i).ERROR_MESSAGE IS NOT NULL THEN
                    -- A real, specific Fusion error -> FAILED on the exact message
                    -- (never composed). Static UPDATE keyed on RECON_KEY.
                    UPDATE DMT_GL_BUDGET_INT_TFM_TBL
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

        -- Outcomes stay on the TFM rows only. Nothing is copied back to STG (backlog #310):
        -- a FAILED-mode rerun finds these rows through DMT_UTIL_PKG.FAILED_RETRY_SELECTED.

        -- Residual accounting: how many of this run's cells are STILL GENERATED
        -- (unaccounted) after this pass. This is the number that let the run-119
        -- cells sit unnoticed after that run's transient recon-report outage --
        -- the completion log previously reported only LOADED/FAILED and never the
        -- residual, so a partial or aborted reconcile left no loud, per-run signal
        -- of how many records remained unaccounted. Surface it explicitly and, when
        -- nonzero, log it at WARN so a stranded cell is visible in the run log at
        -- the point it happens -- never a silent gap (design section 5).
        SELECT COUNT(*) INTO l_unaccounted
        FROM   DMT_GL_BUDGET_INT_TFM_TBL
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'GENERATED';

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Report rows: ' || l_rows.COUNT
                           || ' | LOADED: ' || l_loaded
                           || ' | FAILED: ' || l_failed
                           || ' | still UNACCOUNTED (GENERATED): ' || l_unaccounted || '.',
            p_log_type  => CASE WHEN l_unaccounted > 0
                                THEN DMT_UTIL_PKG.C_LOG_WARN
                                ELSE DMT_UTIL_PKG.C_LOG_INFO END,
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
    END APPLY_CONTRACT_V1_GLBUDGETS;

    -- --------------------------------------------------------
    -- PROPAGATE_DOCUMENT_ERRORS (private, backlog #174). Validate and Load Budgets
    -- loads a budget run (RUN_NAME) all or nothing: when any cell fails
    -- validation, that cell is left in GL_BUDGET_INTERFACE as FAILED with its real
    -- error and every other cell of the run is left VALIDATED and never loaded
    -- (live evidence: one FAILED cell "The account has parent values..." beside
    -- 592 VALIDATED cells of the same run). The recon report returns only the
    -- FAILED cell, so the other cells would otherwise end UNACCOUNTED. This quotes
    -- the failed cell's real Fusion error onto every other not-LOADED cell DMT sent
    -- with the same RUN_NAME in this run and work item (design section 5,
    -- "Whole-document rejection carries the real error to every grain"), in the
    -- shared format
    -- '[FUSION_ERROR] Rejected with document: budget run <RUN_NAME> cell <account>: <msg>'.
    -- Only a cell whose own error is a real [FUSION_ERROR] (not itself a quote) is
    -- a source. Idempotent: a cell already carrying the quote is skipped. LOADED
    -- cells are never touched. Static SQL; NO COMMIT.
    -- --------------------------------------------------------
    PROCEDURE PROPAGATE_DOCUMENT_ERRORS (
        p_run_id        IN NUMBER,
        p_work_queue_id IN NUMBER
    ) IS
        C_PROC   CONSTANT VARCHAR2(30) := 'PROPAGATE_DOCUMENT_ERRORS';
        C_TAG    CONSTANT VARCHAR2(20) := '[FUSION_ERROR]';
        l_marker VARCHAR2(30) := DMT_UTIL_PKG.C_DOC_ERROR_MARKER;
        l_pairs  T_DOC_PAIR_TBL;
        l_cells  NUMBER := 0;
        l_step   VARCHAR2(200);
    BEGIN
        l_step := 'collecting rejected cells for run ' || p_run_id;
        SELECT c.RUN_NAME,
               c.TFM_SEQUENCE_ID,
               -- Names the budget run and the cell (its account combination) that
               -- actually failed: 'budget run <RUN_NAME> cell <account>: <msg>'.
               DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR(
                   'budget run',
                   c.RUN_NAME || ' cell ' || c.SEGMENT1
                   || NVL2(c.SEGMENT2, '-' || c.SEGMENT2, NULL)
                   || NVL2(c.SEGMENT3, '-' || c.SEGMENT3, NULL)
                   || NVL2(c.SEGMENT4, '-' || c.SEGMENT4, NULL)
                   || NVL2(c.SEGMENT5, '-' || c.SEGMENT5, NULL)
                   || NVL2(c.SEGMENT6, '-' || c.SEGMENT6, NULL)
                   || NVL2(c.SEGMENT7, '-' || c.SEGMENT7, NULL)
                   || NVL2(c.SEGMENT8, '-' || c.SEGMENT8, NULL)
                   || ' ' || c.PERIOD_NAME,
                   DBMS_LOB.SUBSTR(c.ERROR_TEXT, 3800, DBMS_LOB.INSTR(c.ERROR_TEXT, C_TAG)))
        BULK COLLECT INTO l_pairs
        FROM   DMT_GL_BUDGET_INT_TFM_TBL c
        WHERE  c.RUN_ID = p_run_id
        AND    (p_work_queue_id IS NULL OR c.WORK_QUEUE_ID IS NULL
                OR c.WORK_QUEUE_ID = p_work_queue_id)
        AND    c.TFM_STATUS = 'FAILED'
        AND    DBMS_LOB.INSTR(c.ERROR_TEXT, C_TAG) > 0
        AND    DBMS_LOB.INSTR(c.ERROR_TEXT, l_marker) = 0
        AND    c.RUN_NAME IS NOT NULL;

        l_step := 'appending quoted cell errors to the other cells of the budget run';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_GL_BUDGET_INT_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    (p_work_queue_id IS NULL OR t.WORK_QUEUE_ID IS NULL
                    OR t.WORK_QUEUE_ID = p_work_queue_id)
            AND    t.RUN_NAME = l_pairs(i).DOC_KEY
            AND    t.TFM_SEQUENCE_ID <> l_pairs(i).SOURCE_SEQ
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    l_pairs(i).QUOTED_ERROR IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_cells := SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Rejected cells: ' || l_pairs.COUNT
                           || ' | other cells of their budget run given a quoted error: '
                           || l_cells || '.',
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

    -- ============================================================
    PROCEDURE RECONCILE_BATCH (
        p_run_id        IN NUMBER,
        p_load_ess_id   IN NUMBER,
        p_import_ess_id IN NUMBER    DEFAULT NULL,
        p_run_start     IN TIMESTAMP DEFAULT NULL,
        p_ledger_id     IN NUMBER    DEFAULT NULL,
        p_work_queue_id IN NUMBER    DEFAULT NULL
    ) IS
    BEGIN
        -- Contract v1 base-tier positive proof (single-tier FBDI template, PR #363):
        -- the shared fetch returns the nine-column recon report rows and the APPLY is
        -- STATIC SQL against this object's TFM table, keyed on RECON_KEY. This is now
        -- the SOLE reconciliation path for GLBudgets: it stamps
        -- FUSION_BUDGET_VERSION_ID on cells positively confirmed in
        -- GL_BUDGET_BALANCES, marks FAILED cells left in GL_BUDGET_INTERFACE with the
        -- real error, and leaves the rest GENERATED for the shared unaccounted sweep.
        -- The load ESS id feeds the report's LOAD_REQUEST_ID, which is how the
        -- nine-column report scopes cells to THIS run (budgets carry no run id/prefix
        -- of their own).
        --
        -- The former two-parameter run-start / cell-key path (FETCH_BIP_RESULTS +
        -- PARSE_AND_UPDATE, params P_RUN_START / P_LEDGER_ID) is RETIRED: the
        -- GLBudgets data model was rewritten to the nine-column Contract v1 shape
        -- (PR #360), so those old parameters and the REC_TYPE/ACCOUNT_KEY columns the
        -- old parser read no longer exist. Those two procedures — and their private
        -- BIP SOAP transport (bip_soap_post) — have now been removed from the
        -- package. p_run_start / p_ledger_id are still accepted for signature
        -- compatibility with the loader dispatch and are intentionally not used.
        APPLY_CONTRACT_V1_GLBUDGETS(
            p_run_id        => p_run_id,
            p_request_id    => TO_CHAR(p_load_ess_id),
            p_import_ess_id => p_import_ess_id);
        -- Cells rejected with their budget run (Validate and Load Budgets loads a
        -- RUN_NAME all or nothing) carry the real error of the cell that caused it.
        -- Runs after the per-row apply and BEFORE the shared unaccounted sweep
        -- (DMT_QUEUE_WORKER_PKG.RECONCILE_ONE).
        PROPAGATE_DOCUMENT_ERRORS(p_run_id, p_work_queue_id);
        -- Unresolved records intentionally left GENERATED (unaccounted).
        -- No fabricated FAILED: the accounting gate reports the object
        -- not-DONE and the funnel surfaces these as UNRECONCILED.
    EXCEPTION WHEN OTHERS THEN
        DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'RECONCILE_BATCH failed.', SQLERRM, C_PKG, 'RECONCILE_BATCH'); RAISE;
    END RECONCILE_BATCH;


    -- --------------------------------------------------------
    -- RESET_UNACCOUNTED (backlog #95) -- see spec. Static UPDATE(s) over the
    -- compile-time-known GLBudgets TFM table(s). Flips this run's UNACCOUNTED rows
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
        UPDATE DMT_GL_BUDGET_INT_TFM_TBL
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
            C_PROC || ': reset ' || l_reset || ' UNACCOUNTED GLBudgets row(s) to GENERATED '
            || 'for re-reconcile.',
            'INFO', C_PKG, C_PROC);
        -- NO COMMIT -- the caller (RERUN_RUN) owns the transaction.
    END RESET_UNACCOUNTED;

END DMT_GL_BUDGET_RESULTS_PKG;
/
