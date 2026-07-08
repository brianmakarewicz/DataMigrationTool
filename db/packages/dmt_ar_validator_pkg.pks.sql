-- PACKAGE DMT_AR_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_AR_VALIDATOR_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_AR_VALIDATOR_PKG
-- Validation for ARInvoices staging data.
--
-- Two phases:
--   PRE_TRANSFORM: upstream dependency checks on STG rows.
--     - Bill-to customer (BILL_CUSTOMER_ACCOUNT_NUMBER) must be
--       LOADED in DMT_HZ_ACCOUNTS_STG_TBL, or present in Fusion.
--     - If line invalid, cascade to child distributions.
--   POST_TRANSFORM: data quality checks on TFM rows.
--
-- Validation always runs even if empty — prevents OIC changes.
-- ============================================================

    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id    IN NUMBER,
        p_dependent_prefix  IN VARCHAR2 DEFAULT NULL
    );

    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    );

END DMT_AR_VALIDATOR_PKG;
/
