-- PACKAGE DMT_ZX_RUNNER_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_ZX_RUNNER_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_ZX_RUNNER_PKG
-- Orchestrates the Tax Regime + Rate pipeline:
-- Pre-validate -> Transform Regimes -> Transform Rates ->
-- Post-validate -> Generate FBL -> Load & Reconcile
-- ============================================================

    PROCEDURE RUN (
        p_run_id   IN NUMBER,
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW',
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N'
    );

    -- Queue-dispatch entry point (EXEC contract, LOCAL mode). The scheduler
    -- calls this with named notation (p_run_id, p_scenario_name, p_run_mode,
    -- p_skip_bu_refresh => TRUE). Taxes has no business-unit refresh, so the
    -- extra arguments are accepted for contract conformance; delegates to RUN.
    PROCEDURE RUN_STANDARD (
        p_run_id          IN NUMBER,
        p_scenario_name   IN VARCHAR2 DEFAULT NULL,
        p_run_mode        IN VARCHAR2 DEFAULT 'NEW',
        p_skip_bu_refresh IN BOOLEAN  DEFAULT FALSE
    );

END DMT_ZX_RUNNER_PKG;
/
