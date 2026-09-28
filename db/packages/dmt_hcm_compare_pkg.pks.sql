CREATE OR REPLACE PACKAGE DMT_HCM_COMPARE_PKG AS
    -- Post-run comparison for the final HCM family: Workers, Salaries,
    -- TalentProfiles. Each function returns one DMT_CMP_ROW_OBJ for the run,
    -- mirroring DMT_PO_COMPARE_PKG.GET_COMPARISON's shape: staged vs
    -- transform-errors vs live Fusion successes. Read-only; pure static SQL,
    -- no EXECUTE IMMEDIATE (rule #66) -- only DMT_RUN_COMPARE_PKG.BUILD_ROWS
    -- dispatches dynamically.
    --
    -- HDL specifics (this family loads via HCM Data Loader, not FBDI): there
    -- is no import ESS request id to key Fusion on. The tie-back is the HDL
    -- key map HRC_INTEGRATION_KEY_MAP: SOURCE_SYSTEM_ID (= the TFM RECON_KEY
    -- of each LOADED record) maps to SURROGATE_ID (= the base-table PK).
    -- KEY_TYPE = 'STAMPED_REF' for all three -- the batch bind is the exact
    -- per-record RECON_KEY list of this run's LOADED TFM rows, matched
    -- verbatim (IN-list), never a prefix LIKE-wildcard or a timestamp window.
    --
    -- Money semantics per object (see each function's header comment):
    --   GET_WORKERS_CMP         count-only (no money grain on Workers)
    --   GET_SALARIES_CMP        money (SALARY_AMOUNT); balances on both
    --                           count and money
    --   GET_TALENT_PROFILES_CMP count-only (no money grain); 0 LOADED run 132
    --                           (whole-file HDL rejection) -- honest 0-loaded,
    --                           designed and built for a future run
    FUNCTION GET_WORKERS_CMP(p_run_id IN NUMBER)          RETURN DMT_CMP_ROW_OBJ;
    FUNCTION GET_SALARIES_CMP(p_run_id IN NUMBER)         RETURN DMT_CMP_ROW_OBJ;
    FUNCTION GET_TALENT_PROFILES_CMP(p_run_id IN NUMBER)  RETURN DMT_CMP_ROW_OBJ;
END DMT_HCM_COMPARE_PKG;
/
