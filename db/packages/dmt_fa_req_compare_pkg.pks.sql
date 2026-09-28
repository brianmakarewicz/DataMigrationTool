CREATE OR REPLACE PACKAGE DMT_FA_REQ_COMPARE_PKG AS
    -- Post-run comparison functions for two money-bearing objects rolled out
    -- onto the proven PurchaseOrders walking-skeleton template (run 132
    -- discovery: docs/superpowers/specs/discovery/{Assets,Requisitions}.md).
    -- Each returns one DMT_CMP_ROW_OBJ for the run: STG total, TFM errors, and
    -- the LIVE Fusion success aggregate read through the shared BIP transport
    -- (DMT_UTIL_PKG.RUN_BIP_REPORT). Both objects carry money
    -- (FUSION_MONEY_AVAILABLE = 'Y'); balance is checked on count AND money.
    -- Pure static SQL -- no dynamic SQL here (rule #66: only
    -- DMT_RUN_COMPARE_PKG.BUILD_ROWS dispatches).
    FUNCTION GET_ASSETS_CMP(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ;
    FUNCTION GET_REQUISITIONS_CMP(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ;
END DMT_FA_REQ_COMPARE_PKG;
/
