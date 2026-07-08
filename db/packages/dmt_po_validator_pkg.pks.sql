-- PACKAGE DMT_PO_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_PO_VALIDATOR_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_PO_VALIDATOR_PKG
-- Validation for PurchaseOrders staging data.
--
-- Two phases:
--   PRE_TRANSFORM: upstream dependency checks on STG rows
--     - Supplier (VENDOR_NUM with PREFIX) must be LOADED
--       in DMT_POZ_SUPPLIERS_STG_TBL, or present in Fusion via REST
--     - If header invalid, cascade to all child lines / locs / dists
--   POST_TRANSFORM: data quality checks on TFM rows (after prefix applied)
--
-- Validation always runs even if empty — prevents OIC orchestration changes.
-- ============================================================

    -- Pre-transform validation: check upstream dependencies on STG rows.
    -- Marks headers FAILED + cascades to child rows if supplier not found.
    -- When p_doc_type_filter is non-NULL, only validates headers with matching
    -- STYLE_DISPLAY_NAME and cascades only to their child rows.
    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id    IN NUMBER,
        p_dependent_prefix  IN VARCHAR2 DEFAULT NULL,
        p_doc_type_filter   IN VARCHAR2 DEFAULT NULL
    );

    -- Post-transform validation: data quality checks on TFM rows.
    -- Called after transformation proc has applied prefix and built TFM rows.
    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    );

END DMT_PO_VALIDATOR_PKG;
/
