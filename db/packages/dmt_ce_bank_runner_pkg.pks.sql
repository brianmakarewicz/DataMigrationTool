-- PACKAGE DMT_CE_BANK_RUNNER_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_CE_BANK_RUNNER_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_CE_BANK_RUNNER_PKG
-- Orchestrates the Cash Management Banks pipeline:
-- Pre-validate -> Transform Banks -> Transform Branches
-- -> Transform Accounts -> Post-validate -> Generate (promote
-- STAGED TFM rows to GENERATED) -> REST Load & base-table Reconcile.
-- Loads over the Cash Management REST resources (cashBanks /
-- cashBankBranches / cashBankAccounts); the old FBL flat-file path
-- is retired (backlog #39).
-- ============================================================

    PROCEDURE RUN (
        p_run_id   IN NUMBER,
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW',
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N'
    );

    -- Queue-dispatch entry point (EXEC contract, LOCAL mode). Registered in
    -- DMT_PIPELINE_DEF_TBL for CEMLI_CODE 'CashBanks'. Resolves the scenario name
    -- to its id and delegates to RUN so STG selection is scoped to the run's
    -- scenario. p_skip_bu_refresh is accepted for contract conformance.
    PROCEDURE RUN_STANDARD (
        p_run_id          IN NUMBER,
        p_scenario_name   IN VARCHAR2 DEFAULT NULL,
        p_run_mode        IN VARCHAR2 DEFAULT 'NEW',
        p_skip_bu_refresh IN BOOLEAN  DEFAULT FALSE
    );

END DMT_CE_BANK_RUNNER_PKG;
/
