-- PACKAGE DMT_AP_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_AP_VALIDATOR_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_AP_VALIDATOR_PKG
-- Validation for APInvoices staging data.
--
-- Two phases:
--   PRE_TRANSFORM: upstream dependency checks on STG rows
--     - Supplier (VENDOR_NUM with PREFIX) must be LOADED
--       in DMT_POZ_SUPPLIERS_STG_TBL
--     - If header invalid, cascade to all child lines via INVOICE_ID
--   POST_TRANSFORM: data quality checks on TFM rows (after prefix applied)
--
-- Validation always runs even if empty — prevents OIC orchestration changes.
-- ============================================================

    -- Pre-transform validation: check upstream dependencies on STG rows.
    -- Marks headers FAILED + cascades to child lines if supplier not found.
    -- When p_inv_type_filter is non-NULL, only validates headers with
    -- matching INVOICE_TYPE_LOOKUP_CODE (uses LIKE, e.g. '%1099%').
    -- This allows 1099Invoices and APInvoices to share the same tables
    -- but validate independently.
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
