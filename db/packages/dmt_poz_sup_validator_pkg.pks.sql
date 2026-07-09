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
    -- Rows that pass are left untouched (STATUS stays NEW or RETRY).
    PROCEDURE VALIDATE_UPSTREAM (p_run_id IN NUMBER);

    -- Individual object-type checks (called by VALIDATE_UPSTREAM).
    PROCEDURE VALIDATE_SUPPLIERS        (p_run_id IN NUMBER);
    PROCEDURE VALIDATE_ADDRESSES        (p_run_id IN NUMBER);
    PROCEDURE VALIDATE_SITES            (p_run_id IN NUMBER);
    PROCEDURE VALIDATE_SITE_ASSIGNMENTS (p_run_id IN NUMBER);
    PROCEDURE VALIDATE_CONTACTS         (p_run_id IN NUMBER);

END DMT_POZ_SUP_VALIDATOR_PKG;
/
