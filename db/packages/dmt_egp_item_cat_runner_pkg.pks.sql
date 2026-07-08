-- PACKAGE DMT_EGP_ITEM_CAT_RUNNER_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_EGP_ITEM_CAT_RUNNER_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_EGP_ITEM_CAT_RUNNER_PKG
-- Orchestrates the Item Categories pipeline:
-- Pre-validate -> Transform -> Post-validate -> Generate FBDI
-- -> Load via FBDI + Reconcile via ESS
-- ============================================================

    PROCEDURE RUN (
        p_run_id   IN NUMBER,
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW',
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N'
    );

END DMT_EGP_ITEM_CAT_RUNNER_PKG;
/
