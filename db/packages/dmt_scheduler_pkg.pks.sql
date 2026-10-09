-- PACKAGE DMT_SCHEDULER_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_SCHEDULER_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_SCHEDULER_PKG (v2 â€” work queue model)
-- Creates PIPELINE_RUN + WORK_QUEUE rows.
-- No per-run DBMS_SCHEDULER job. The poller (DMT_QUEUE_PKG)
-- handles execution.
-- ============================================================

    -- Submit one or more pipelines (CSV: 'P2P,O2C,Financials').
    -- Creates queue rows for all CEMLIs across all selected pipelines.
    -- Returns RUN_ID immediately.
    -- p_dependent_prefix / p_validate_upstream (Backlog #142): the two
    -- page-84 run parameters, persisted on DMT_PIPELINE_RUN_TBL and
    -- honored by the object validators. p_dependent_prefix NULL =
    -- automatic (use the run's own prefix); p_validate_upstream 'N'
    -- (default) = skip the upstream pre-validation, 'Y' = enforce it.
    PROCEDURE SUBMIT_PIPELINE (
        p_pipeline_codes   IN  VARCHAR2,
        p_scenario_name    IN  VARCHAR2 DEFAULT NULL,
        p_run_mode         IN  VARCHAR2 DEFAULT 'NEW',
        p_on_failure       IN  VARCHAR2 DEFAULT 'HALT',
        p_submitted_by     IN  VARCHAR2 DEFAULT NULL,
        p_dependent_prefix IN  VARCHAR2 DEFAULT NULL,
        p_validate_upstream IN VARCHAR2 DEFAULT 'N',
        x_run_id           OUT NUMBER
    );

    -- Submit individual objects (pipe-delimited: 'Workers|Requisitions').
    PROCEDURE SUBMIT_OBJECTS (
        p_objects          IN  VARCHAR2,
        p_scenario_name    IN  VARCHAR2 DEFAULT NULL,
        p_run_mode         IN  VARCHAR2 DEFAULT 'NEW',
        p_on_failure       IN  VARCHAR2 DEFAULT 'HALT',
        p_submitted_by     IN  VARCHAR2 DEFAULT NULL,
        p_dependent_prefix IN  VARCHAR2 DEFAULT NULL,
        p_validate_upstream IN VARCHAR2 DEFAULT 'N',
        x_run_id           OUT NUMBER
    );

    -- To cancel a run that can never finish, use DMT_QUEUE_PKG.CANCEL_RUN
    -- (owner-approved 2026-10-08, backlog #635).

    -- Returns ordered CSV of CEMLI codes for a pipeline.
    FUNCTION GET_CEMLI_SEQUENCE (p_pipeline_code IN VARCHAR2) RETURN VARCHAR2;

    -- Returns DEPENDS_ON CSV for a CEMLI within a pipeline.
    FUNCTION GET_CEMLI_DEPENDENCIES (p_pipeline_code IN VARCHAR2, p_cemli_code IN VARCHAR2) RETURN VARCHAR2;

    -- Preview a pipeline run without committing.
    -- Returns proposed queue rows as a REF CURSOR for display in APEX.
    -- Columns: SORT_ORDER, PIPELINE, CEMLI_CODE, DEPENDS_ON, INITIAL_STATUS
    FUNCTION PLAN_RUN (
        p_pipeline_codes   IN  VARCHAR2
    ) RETURN SYS_REFCURSOR;

END DMT_SCHEDULER_PKG;
/
