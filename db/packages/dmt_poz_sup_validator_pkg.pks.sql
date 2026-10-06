-- PACKAGE DMT_POZ_SUP_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_POZ_SUP_VALIDATOR_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_POZ_SUP_VALIDATOR_PKG
-- Pre-transform validator: upstream dependency checks on staging rows.
-- Runs BEFORE the transformation proc.
--
-- Checks that all upstream parent records have TFM_STATUS = 'LOADED'
-- before allowing a row to proceed to transformation.
-- Rows that fail are marked STATUS = 'FAILED' with an
-- [PRE_VALIDATION] prefix on ERROR_TEXT.
--
-- Object type dependency chain:
--   Suppliers         — no upstream dependency
--   Addresses         — parent Supplier must be LOADED
--   Sites             — parent Supplier must be LOADED
--   Site Assignments  — parent Site must be LOADED
--   Contacts          — parent Supplier must be LOADED
--
-- This package is always called even when no rules are active,
-- so rules can be added later without changing the pipeline flow.
-- ============================================================

    -- Pre-transform upstream dependency check for all 5 supplier object types.
    -- Marks failing rows STATUS = 'FAILED', ERROR_TEXT = '[PRE_VALIDATION] ...'.
    -- Rows that pass are left untouched (STATUS stays NEW).
    PROCEDURE VALIDATE_PRE_TRANSFORM (p_run_id IN NUMBER, p_scenario_id IN NUMBER DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW');

    -- Individual object-type checks (called by VALIDATE_PRE_TRANSFORM).
    PROCEDURE VALIDATE_SUPPLIERS        (p_run_id IN NUMBER, p_scenario_id IN NUMBER DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW');
    PROCEDURE VALIDATE_ADDRESSES        (p_run_id IN NUMBER, p_scenario_id IN NUMBER DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW');
    PROCEDURE VALIDATE_SITES            (p_run_id IN NUMBER, p_scenario_id IN NUMBER DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW');
    PROCEDURE VALIDATE_SITE_ASSIGNMENTS (p_run_id IN NUMBER, p_scenario_id IN NUMBER DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW');
    PROCEDURE VALIDATE_CONTACTS         (p_run_id IN NUMBER, p_scenario_id IN NUMBER DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW');

    -- Per-object STG-FAILED flaggers. Each flips ONLY its own STG table's rows
    -- (those with a recorded error row for this run) to STG_STATUS = 'FAILED'.
    -- A per-object supplier runner calls its matching VALIDATE_<type> then its
    -- FLAG_<type>_STG_FAILED, so it validates and flags only its own object.
    -- FLAG_STG_FAILED (below) calls all five in sequence; it is retained so the
    -- VALIDATE_PRE_TRANSFORM orchestrator path is unchanged.
    PROCEDURE FLAG_SUPPLIERS_STG_FAILED        (p_run_id IN NUMBER, p_scenario_id IN NUMBER DEFAULT NULL);
    PROCEDURE FLAG_ADDRESSES_STG_FAILED        (p_run_id IN NUMBER, p_scenario_id IN NUMBER DEFAULT NULL);
    PROCEDURE FLAG_SITES_STG_FAILED            (p_run_id IN NUMBER, p_scenario_id IN NUMBER DEFAULT NULL);
    PROCEDURE FLAG_SITE_ASSIGNMENTS_STG_FAILED (p_run_id IN NUMBER, p_scenario_id IN NUMBER DEFAULT NULL);
    PROCEDURE FLAG_CONTACTS_STG_FAILED         (p_run_id IN NUMBER, p_scenario_id IN NUMBER DEFAULT NULL);

    -- Flags all five supplier STG tables FAILED from their recorded error rows.
    -- Called by VALIDATE_PRE_TRANSFORM (orchestrator path). Delegates to the five
    -- per-object flaggers above.
    PROCEDURE FLAG_STG_FAILED (p_run_id IN NUMBER, p_scenario_id IN NUMBER DEFAULT NULL);

END DMT_POZ_SUP_VALIDATOR_PKG;
/
