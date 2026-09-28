CREATE OR REPLACE PACKAGE DMT_GL_COMPARE_PKG AS
    -- Post-run comparison for the two GL objects. Both are money-bearing
    -- (FUSION_MONEY_AVAILABLE='Y') but use different key paths per discovery:
    --   GLBalances — STAMPED_REF: the DMT RUN_ID is stamped into
    --     GL_JE_BATCHES.GROUP_ID at transform time and survives Journal
    --     Import; the live query is keyed on GROUP_ID = p_run_id, never a
    --     prefix or a timestamp window. Success is decided by journal-header
    --     balance (running_total_dr = running_total_cr), not by mere
    --     presence in gl_je_lines -- an unbalanced journal imports but will
    --     not post and is honestly FAILED even though the row exists.
    --   GLBudgets — CAPTURED_ID: a loaded budget cell carries no run id,
    --     request id, batch id, or stamped reference of any kind, so the
    --     production-valid key is the exact CODE_COMBINATION_ID list DMT
    --     already captured on this run's LOADED TFM rows (stored, as a
    --     documented misnomer, in FUSION_BUDGET_VERSION_ID) plus the budget
    --     name -- with NO time window (LAST_UPDATE_DATE scoping was proven
    --     unreliable in discovery and is never used here).
    -- Read-only; never queries Fusion by prefix or by a LAST_UPDATE_DATE
    -- window. No dynamic SQL -- both functions are pure static SQL.
    FUNCTION GET_BALANCES_COMPARISON(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ;
    FUNCTION GET_BUDGETS_COMPARISON(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ;
END DMT_GL_COMPARE_PKG;
/
