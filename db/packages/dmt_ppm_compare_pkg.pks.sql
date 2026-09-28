CREATE OR REPLACE PACKAGE DMT_PPM_COMPARE_PKG AS
    -- Post-run comparison for the five Projects/PPM objects (Projects,
    -- ProjectBudgets, Expenditures, BillingEvents, Grants). Each function
    -- returns one DMT_CMP_ROW_OBJ for the run, mirroring
    -- DMT_PO_COMPARE_PKG.GET_COMPARISON's shape: staged vs transform-errors
    -- vs live Fusion successes. Read-only; never queries Fusion by prefix or
    -- timestamp window -- each function keys off the per-object key settled
    -- by discovery run 132 (docs/superpowers/specs/discovery/{Projects,
    -- ProjectBudgets,Expenditures,BillingEvents,Grants}.md). Pure static SQL,
    -- no EXECUTE IMMEDIATE (rule #66) -- only DMT_RUN_COMPARE_PKG.BUILD_ROWS
    -- dispatches dynamically.
    --
    -- Money semantics differ per object -- see each function's header comment:
    --   GET_PROJECTS_CMP        count-only (no money grain exists on Projects)
    --   GET_PROJECT_BUDGETS_CMP money (TOTAL_TC_RAW_COST); 0 LOADED this run
    --   GET_EXPENDITURES_CMP    money (DENOM_RAW_COST); Fusion RECOMPUTES cost
    --                           at import, so the money variance is honestly
    --                           NONZERO by design even though count balances
    --   GET_BILLING_EVENTS_CMP  money (BILL_TRNS_AMOUNT); balances on both
    --   GET_GRANTS_CMP          count-only (FT_AMOUNT not populated); 0 LOADED
    FUNCTION GET_PROJECTS_CMP(p_run_id IN NUMBER)        RETURN DMT_CMP_ROW_OBJ;
    FUNCTION GET_PROJECT_BUDGETS_CMP(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ;
    FUNCTION GET_EXPENDITURES_CMP(p_run_id IN NUMBER)    RETURN DMT_CMP_ROW_OBJ;
    FUNCTION GET_BILLING_EVENTS_CMP(p_run_id IN NUMBER)  RETURN DMT_CMP_ROW_OBJ;
    FUNCTION GET_GRANTS_CMP(p_run_id IN NUMBER)          RETURN DMT_CMP_ROW_OBJ;
END DMT_PPM_COMPARE_PKG;
/
