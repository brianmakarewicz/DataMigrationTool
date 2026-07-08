-- PACKAGE DMT_PROJECT_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_PROJECT_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_PROJECT_TRANSFORM_PKG spec
-- Projects transformation: STG -> TFM with prefix application.
-- 4 object types: Projects, Tasks, Team Members, Txn Controls.
-- ============================================================
    PROCEDURE TRANSFORM_PROJECTS (p_run_id IN NUMBER, p_reprocess_errors IN BOOLEAN DEFAULT FALSE, p_scenario_id IN NUMBER DEFAULT NULL, p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW');
    PROCEDURE TRANSFORM_TASKS (p_run_id IN NUMBER, p_reprocess_errors IN BOOLEAN DEFAULT FALSE, p_scenario_id IN NUMBER DEFAULT NULL, p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW');
    PROCEDURE TRANSFORM_TEAM_MEMBERS (p_run_id IN NUMBER, p_reprocess_errors IN BOOLEAN DEFAULT FALSE, p_scenario_id IN NUMBER DEFAULT NULL, p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW');
    PROCEDURE TRANSFORM_TXN_CONTROLS (p_run_id IN NUMBER, p_reprocess_errors IN BOOLEAN DEFAULT FALSE, p_scenario_id IN NUMBER DEFAULT NULL, p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW');
END DMT_PROJECT_TRANSFORM_PKG;
/
