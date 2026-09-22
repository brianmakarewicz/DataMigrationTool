-- PACKAGE BODY DMT_GL_BUDGET_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_GL_BUDGET_RESULTS_PKG" AS
-- ============================================================
-- GL Budget Balances reconciliation (cell-grain, run-start window).
-- See package spec for the reconciliation model.
-- ============================================================
    C_PKG        CONSTANT VARCHAR2(50) := 'DMT_GL_BUDGET_RESULTS_PKG';
    C_CEMLI      CONSTANT VARCHAR2(30) := 'GLBudgets';
    -- Clock-skew buffer applied to run-start so a small ATP<->Fusion time
    -- offset never excludes cells our own run just wrote. Pre-existing budget
    -- data is months old, so a few hours is safe.
    C_SKEW_HOURS CONSTANT NUMBER := 4;
    C_AMT_TOL    CONSTANT NUMBER := 0.01;   -- DR/CR match tolerance

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
    -- (live SELECT -> ORA-00942), so the honest, non-null Fusion base-table id the
    -- report returns is the cell's GL_CODE_COMBINATIONS.CODE_COMBINATION_ID; that
    -- is what lands in FUSION_BUDGET_VERSION_ID (the TFM's Fusion-id column). Rows
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
                IF l_rows(i).SOURCE_TYPE = 'BASE'
                   AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                   AND l_rows(i).FUSION_ID IS NOT NULL THEN
                    -- Positive proof: cell present in GL_BUDGET_BALANCES resolving
                    -- to a real code combination id. The ONLY path to LOADED.
                    -- Static UPDATE keyed on RECON_KEY (= the cell key).
                    UPDATE DMT_GL_BUDGET_INT_TFM_TBL
                    SET    TFM_STATUS               = 'LOADED',
                           FUSION_BUDGET_VERSION_ID = l_rows(i).FUSION_ID,
                           RESULTS_UPDATED_DATE     = SYSDATE,
                           LAST_UPDATED_DATE        = SYSDATE
                    WHERE  RUN_ID    = p_run_id
                    AND    RECON_KEY = l_rows(i).RECORD_KEY
                    AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                    l_loaded := l_loaded + SQL%ROWCOUNT;

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

        -- Fan cell outcome back to the STG source rows for the cells this pass
        -- turned terminal (same echo PARSE_AND_UPDATE does; safe to repeat).
        UPDATE DMT_GL_BUDGET_INT_STG_TBL SET STG_STATUS='LOADED', LAST_UPDATED_DATE=SYSDATE
        WHERE STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_GL_BUDGET_INT_TFM_TBL
                                  WHERE RUN_ID=p_run_id AND TFM_STATUS='LOADED');
        UPDATE DMT_GL_BUDGET_INT_STG_TBL SET STG_STATUS='FAILED', LAST_UPDATED_DATE=SYSDATE
        WHERE STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_GL_BUDGET_INT_TFM_TBL
                                  WHERE RUN_ID=p_run_id AND TFM_STATUS='FAILED');

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
    END APPLY_CONTRACT_V1_GLBUDGETS;

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
        -- Unresolved records intentionally left GENERATED (unaccounted).
        -- No fabricated FAILED: the accounting gate reports the object
        -- not-DONE and the funnel surfaces these as UNRECONCILED.
    EXCEPTION WHEN OTHERS THEN
        DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'RECONCILE_BATCH failed.', SQLERRM, C_PKG, 'RECONCILE_BATCH'); RAISE;
    END RECONCILE_BATCH;

END DMT_GL_BUDGET_RESULTS_PKG;
/
