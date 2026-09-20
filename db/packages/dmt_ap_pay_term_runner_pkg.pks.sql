-- PACKAGE DMT_AP_PAY_TERM_RUNNER_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_AP_PAY_TERM_RUNNER_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_AP_PAY_TERM_RUNNER_PKG
-- Orchestrates the Payment Terms pipeline:
-- Pre-validate -> Transform Headers -> Transform Lines
-- -> Post-validate -> Generate FBL -> Load & Reconcile
-- ============================================================

    PROCEDURE RUN (
        p_run_id   IN NUMBER,
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW',
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N'
    );

    -- Queue-dispatch entry point (EXEC contract, EXEC_MODE=LOCAL). Matches the
    -- signature the scheduler calls for a LOCAL exec proc; resolves the scenario
    -- name to its id and delegates to RUN so STG selection is scoped to the run's
    -- scenario. p_skip_bu_refresh is accepted for contract conformance (Payment
    -- Terms has no business-unit refresh).
    PROCEDURE RUN_STANDARD (
        p_run_id          IN NUMBER,
        p_scenario_name   IN VARCHAR2 DEFAULT NULL,
        p_run_mode        IN VARCHAR2 DEFAULT 'NEW',
        p_skip_bu_refresh IN BOOLEAN  DEFAULT FALSE
    );

END DMT_AP_PAY_TERM_RUNNER_PKG;
/
