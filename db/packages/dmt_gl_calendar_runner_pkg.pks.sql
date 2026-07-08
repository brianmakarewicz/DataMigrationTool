-- PACKAGE DMT_GL_CALENDAR_RUNNER_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_GL_CALENDAR_RUNNER_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_GL_CALENDAR_RUNNER_PKG
-- Orchestrates the GL Accounting Calendar pipeline:
-- Pre-validate -> Transform -> Post-validate -> Generate FBL
-- -> Log manual setup requirement (no automated load path)
-- ============================================================

    PROCEDURE RUN (
        p_run_id   IN NUMBER,
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW',
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N'
    );

END DMT_GL_CALENDAR_RUNNER_PKG;
/
