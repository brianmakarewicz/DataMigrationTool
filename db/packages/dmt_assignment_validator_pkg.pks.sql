-- PACKAGE DMT_ASSIGNMENT_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_ASSIGNMENT_VALIDATOR_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_ASSIGNMENT_VALIDATOR_PKG
-- Validation for Worker Assignment HDL staging data.
--
-- Two phases:
--   PRE_TRANSFORM: upstream dependency checks on STG rows
--   POST_TRANSFORM: data quality checks on TFM rows (after prefix applied)
--
-- Stub implementation — no validation rules yet.
-- Validation always runs even if empty — prevents OIC orchestration changes.
-- ============================================================

    -- Pre-transform validation: check upstream dependencies on STG rows.
    -- Future: verify PERSON_NUMBER exists in DMT_WORKER_STG_TBL with STATUS = LOADED.
    -- Stub — no rules implemented yet. Logs start/complete only.
    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id IN NUMBER
    );

    -- Post-transform validation: data quality checks on TFM rows.
    -- Future: check ACTION_CODE valid, WORKER_TYPE valid, dates logical, etc.
    -- Stub — no rules implemented yet. Logs start/complete only.
    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    );

END DMT_ASSIGNMENT_VALIDATOR_PKG;
/
