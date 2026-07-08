-- PACKAGE DMT_GRANTS_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_GRANTS_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_GRANTS_TRANSFORM_PKG spec
-- Grants transformation: STG -> TFM with prefix application.
-- 15 object types matching the 15 CSVs in the Grants FBDI.
-- Prefix applied to AWARD_NUMBER (all) and PROJECT_NUMBER (where present).
-- ============================================================
    PROCEDURE TRANSFORM_HEADERS         (p_run_id IN NUMBER, p_reprocess_errors IN BOOLEAN DEFAULT FALSE, p_scenario_id IN NUMBER DEFAULT NULL, p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW');
    PROCEDURE TRANSFORM_FUNDING         (p_run_id IN NUMBER, p_reprocess_errors IN BOOLEAN DEFAULT FALSE, p_scenario_id IN NUMBER DEFAULT NULL, p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW');
    PROCEDURE TRANSFORM_PROJECTS        (p_run_id IN NUMBER, p_reprocess_errors IN BOOLEAN DEFAULT FALSE, p_scenario_id IN NUMBER DEFAULT NULL, p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW');
    PROCEDURE TRANSFORM_PERSONNEL       (p_run_id IN NUMBER, p_reprocess_errors IN BOOLEAN DEFAULT FALSE, p_scenario_id IN NUMBER DEFAULT NULL, p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW');
    PROCEDURE TRANSFORM_FUND_SOURCES    (p_run_id IN NUMBER, p_reprocess_errors IN BOOLEAN DEFAULT FALSE, p_scenario_id IN NUMBER DEFAULT NULL, p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW');
    PROCEDURE TRANSFORM_PRJ_FUND_SRCS   (p_run_id IN NUMBER, p_reprocess_errors IN BOOLEAN DEFAULT FALSE, p_scenario_id IN NUMBER DEFAULT NULL, p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW');
    PROCEDURE TRANSFORM_KEYWORDS        (p_run_id IN NUMBER, p_reprocess_errors IN BOOLEAN DEFAULT FALSE, p_scenario_id IN NUMBER DEFAULT NULL, p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW');
    PROCEDURE TRANSFORM_BUDGET_PERIODS  (p_run_id IN NUMBER, p_reprocess_errors IN BOOLEAN DEFAULT FALSE, p_scenario_id IN NUMBER DEFAULT NULL, p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW');
    PROCEDURE TRANSFORM_CERTS           (p_run_id IN NUMBER, p_reprocess_errors IN BOOLEAN DEFAULT FALSE, p_scenario_id IN NUMBER DEFAULT NULL, p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW');
    PROCEDURE TRANSFORM_CFDAS           (p_run_id IN NUMBER, p_reprocess_errors IN BOOLEAN DEFAULT FALSE, p_scenario_id IN NUMBER DEFAULT NULL, p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW');
    PROCEDURE TRANSFORM_FUND_ALLOCS     (p_run_id IN NUMBER, p_reprocess_errors IN BOOLEAN DEFAULT FALSE, p_scenario_id IN NUMBER DEFAULT NULL, p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW');
    PROCEDURE TRANSFORM_ORG_CREDITS     (p_run_id IN NUMBER, p_reprocess_errors IN BOOLEAN DEFAULT FALSE, p_scenario_id IN NUMBER DEFAULT NULL, p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW');
    PROCEDURE TRANSFORM_PRJ_TASK_BURDEN (p_run_id IN NUMBER, p_reprocess_errors IN BOOLEAN DEFAULT FALSE, p_scenario_id IN NUMBER DEFAULT NULL, p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW');
    PROCEDURE TRANSFORM_REFERENCES      (p_run_id IN NUMBER, p_reprocess_errors IN BOOLEAN DEFAULT FALSE, p_scenario_id IN NUMBER DEFAULT NULL, p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW');
    PROCEDURE TRANSFORM_TERMS           (p_run_id IN NUMBER, p_reprocess_errors IN BOOLEAN DEFAULT FALSE, p_scenario_id IN NUMBER DEFAULT NULL, p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW');
END DMT_GRANTS_TRANSFORM_PKG;
/
