-- PACKAGE DMT_REQ_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_REQ_VALIDATOR_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_REQ_VALIDATOR_PKG
-- Validation for Requisitions staging data.
--
-- Two phases:
--   PRE_TRANSFORM: upstream dependency checks on STG rows
--     - Requisitions are standalone (no upstream dependencies).
--       Stub — returns immediately.
--   POST_TRANSFORM: data quality checks on TFM rows (after prefix applied)
--     - Stub — no rules implemented yet.
--
-- Validation always runs even if empty — prevents OIC orchestration changes.
-- ============================================================

    -- Pre-transform validation: check upstream dependencies on STG rows.
    -- Requisitions have no upstream dependencies — stub that returns immediately.
    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id    IN NUMBER
    );

    -- Post-transform validation: data quality checks on TFM rows.
    -- Called after transformation proc has applied prefix and built TFM rows.
    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    );

END DMT_REQ_VALIDATOR_PKG;
/
