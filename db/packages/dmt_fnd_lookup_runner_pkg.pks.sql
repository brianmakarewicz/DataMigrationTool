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

    -- Queue-dispatch entry point. Conforms to the EXEC dispatch contract
    -- (invoke_registered style EXEC): p_run_id, p_scenario_name, p_run_mode,
    -- p_skip_bu_refresh. Resolves the scenario name to its id and delegates to
    -- RUN. Registered as EXEC_PROC in DMT_PIPELINE_DEF_TBL for Lookups (LOCAL).
    PROCEDURE RUN_STANDARD (
        p_run_id          IN NUMBER,
        p_scenario_name   IN VARCHAR2 DEFAULT NULL,
        p_run_mode        IN VARCHAR2 DEFAULT 'NEW',
        p_skip_bu_refresh IN BOOLEAN  DEFAULT FALSE
    );

END DMT_FND_LOOKUP_RUNNER_PKG;
/
