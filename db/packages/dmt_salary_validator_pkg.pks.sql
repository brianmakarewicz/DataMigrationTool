-- PACKAGE DMT_SALARY_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_SALARY_VALIDATOR_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_SALARY_VALIDATOR_PKG
-- Validation for Salary HDL staging data.
--
-- Two phases:
--   PRE_TRANSFORM: upstream dependency checks on STG rows
--   POST_TRANSFORM: data quality checks on TFM rows (after prefix applied)
--
-- Stub implementation — no validation rules yet.
-- Validation always runs even if empty — prevents OIC orchestration changes.
-- ============================================================

    -- Pre-transform validation: check upstream dependencies on STG rows.
    -- Stub — no rules implemented yet. Logs start/complete only.
    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id IN NUMBER
    );

    -- Post-transform validation: data quality checks on TFM rows.
    -- Stub — no rules implemented yet. Logs start/complete only.
    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    );

END DMT_SALARY_VALIDATOR_PKG;
/
