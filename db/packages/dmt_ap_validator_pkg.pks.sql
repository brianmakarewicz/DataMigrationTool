-- PACKAGE DMT_AP_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_AP_VALIDATOR_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_AP_VALIDATOR_PKG
-- Validation for APInvoices staging data.
--
-- Two phases:
--   PRE_TRANSFORM: NO supplier-dependency check (see the package body header).
--     AP invoices reference PRE-EXISTING Fusion suppliers, not suppliers migrated
--     in this run, so there is nothing upstream to pre-check — Fusion validates the
--     supplier at load and the reconciler reports any rejection. The procedure now
--     only logs; the old "supplier must be LOADED / cascade to child lines" check
--     was removed (proven live in run 130). The durable replacement is the
--     parameterized upstream-validation standard tracked in the design doc.
--   POST_TRANSFORM: data quality checks on TFM rows (after prefix applied)
--
-- Validation always runs even if empty — prevents OIC orchestration changes.
-- ============================================================

    -- Pre-transform validation: no-op for AP beyond logging (no supplier check —
    -- see the package body header for the full rationale). p_inv_type_filter is
    -- retained in the signature (echoed to the log) so 1099Invoices and APInvoices
    -- can keep sharing these tables and calling independently without a signature
    -- change; it no longer drives any row-failing logic.
    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id    IN NUMBER,
        p_dependent_prefix  IN VARCHAR2 DEFAULT NULL,
        p_inv_type_filter   IN VARCHAR2 DEFAULT NULL
    );

    -- Post-transform validation: data quality checks on TFM rows.
    -- Called after transformation proc has applied prefix and built TFM rows.
    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    );

END DMT_AP_VALIDATOR_PKG;
/
