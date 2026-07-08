-- PACKAGE DMT_FND_VS_RUNNER_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_FND_VS_RUNNER_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_FND_VS_RUNNER_PKG
-- Orchestrates the Value Set + Values pipeline:
-- Pre-validate -> Transform Sets -> Transform Values ->
-- Post-validate -> Generate FBL -> Load & Reconcile
-- ============================================================

    PROCEDURE RUN (
        p_run_id   IN NUMBER,
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW',
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N'
    );

END DMT_FND_VS_RUNNER_PKG;
/
