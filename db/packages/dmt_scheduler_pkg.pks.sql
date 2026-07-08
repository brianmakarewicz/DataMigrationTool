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
    PROCEDURE SUBMIT_PIPELINE (
        p_pipeline_codes   IN  VARCHAR2,
        p_scenario_name    IN  VARCHAR2 DEFAULT NULL,
        p_run_mode         IN  VARCHAR2 DEFAULT 'NEW',
        p_on_failure       IN  VARCHAR2 DEFAULT 'HALT',
        p_submitted_by     IN  VARCHAR2 DEFAULT NULL,
        x_run_id           OUT NUMBER
    );

    -- Submit individual objects (pipe-delimited: 'Workers|Requisitions').
    PROCEDURE SUBMIT_OBJECTS (
        p_objects          IN  VARCHAR2,
        p_scenario_name    IN  VARCHAR2 DEFAULT NULL,
        p_run_mode         IN  VARCHAR2 DEFAULT 'NEW',
        p_on_failure       IN  VARCHAR2 DEFAULT 'HALT',
        p_submitted_by     IN  VARCHAR2 DEFAULT NULL,
        x_run_id           OUT NUMBER
    );

    -- (A8, 2026-07-08) CANCEL_RUN REMOVED — design section 2: "There is
    -- no cancellation (decided 2026-07-07) — runs always execute to their
    -- terminal state. If something goes wrong mid-flight ... the fix is an
    -- ALL-mode re-run of the scenario under a new prefix."

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
