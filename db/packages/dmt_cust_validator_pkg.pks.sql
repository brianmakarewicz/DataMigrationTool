-- PACKAGE DMT_CUST_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_CUST_VALIDATOR_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_CUST_VALIDATOR_PKG
-- Validation for Customers staging data.
--
-- Two phases:
--   PRE_TRANSFORM: data quality checks on STG rows.
--     Customers are master data — no upstream dependency.
--     Validates: PARTY_TYPE is set, ORGANIZATION_NAME present
--     for orgs, PERSON_LAST_NAME present for persons.
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

END DMT_CUST_VALIDATOR_PKG;
/
