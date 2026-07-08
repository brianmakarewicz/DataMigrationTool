-- PACKAGE DMT_FND_LOOKUP_RUNNER_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_FND_LOOKUP_RUNNER_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_FND_LOOKUP_RUNNER_PKG
-- Orchestrates the Lookup Types + Values pipeline:
-- Pre-validate -> Transform -> Post-validate -> Generate FBL
-- -> (Load -> Reconcile: future)
-- ============================================================

    PROCEDURE RUN (
        p_run_id   IN NUMBER,
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW',
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N'
    );

END DMT_FND_LOOKUP_RUNNER_PKG;
/
