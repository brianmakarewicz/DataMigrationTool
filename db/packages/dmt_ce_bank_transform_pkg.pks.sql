-- PACKAGE DMT_CE_BANK_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_CE_BANK_TRANSFORM_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_CE_BANK_TRANSFORM_PKG
-- Transforms Cash Management Banks, Branches, and Accounts
-- from STG to TFM tables. Three-level hierarchy:
-- Bank -> Branch -> Account.
-- ============================================================

    PROCEDURE TRANSFORM_BANKS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    );

    PROCEDURE TRANSFORM_BRANCHES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    );

    PROCEDURE TRANSFORM_ACCOUNTS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    );

END DMT_CE_BANK_TRANSFORM_PKG;
/
