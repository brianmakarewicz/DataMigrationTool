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

END DMT_ZX_RUNNER_PKG;
/
