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
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    );

    -- Queue-dispatch entry point (EXEC contract, EXEC_MODE=LOCAL). Matches the
    -- signature the scheduler calls for a LOCAL exec proc; delegates to RUN.
    -- p_scenario_name / p_skip_bu_refresh are accepted for contract conformance
    -- (Payment Terms has no scenario filter or business-unit refresh).
    PROCEDURE RUN_STANDARD (
        p_run_id          IN NUMBER,
        p_scenario_name   IN VARCHAR2 DEFAULT NULL,
        p_run_mode        IN VARCHAR2 DEFAULT 'NEW',
        p_skip_bu_refresh IN BOOLEAN  DEFAULT FALSE
    );

END DMT_AP_PAY_TERM_RUNNER_PKG;
/
