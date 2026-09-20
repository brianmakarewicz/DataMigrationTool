-- PACKAGE DMT_CE_BANK_RUNNER_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_CE_BANK_RUNNER_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_CE_BANK_RUNNER_PKG
-- Orchestrates the Cash Management Banks pipeline:
-- Pre-validate -> Transform Banks -> Transform Branches
-- -> Transform Accounts -> Post-validate -> Generate FBL
-- -> Load & Reconcile
-- ============================================================

    PROCEDURE RUN (
        p_run_id   IN NUMBER,
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    );

    -- Queue-dispatch entry point (EXEC contract, LOCAL mode). Registered in
    -- DMT_PIPELINE_DEF_TBL for CEMLI_CODE 'CashBanks'. Extra args accepted for
    -- contract conformance and ignored; delegates to RUN.
    PROCEDURE RUN_STANDARD (
        p_run_id          IN NUMBER,
        p_scenario_name   IN VARCHAR2 DEFAULT NULL,
        p_run_mode        IN VARCHAR2 DEFAULT 'NEW',
        p_skip_bu_refresh IN BOOLEAN  DEFAULT FALSE
    );

END DMT_CE_BANK_RUNNER_PKG;
/
