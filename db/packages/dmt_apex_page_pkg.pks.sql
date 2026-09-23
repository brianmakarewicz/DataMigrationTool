-- PACKAGE DMT_APEX_PAGE_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_APEX_PAGE_PKG" AS
-- ============================================================
-- DMT_APEX_PAGE_PKG
-- Rendering procedures for APEX drill-through detail pages.
-- All HTML generated via HTP.P. Pages call these procs â€”
-- future changes = recompile package, no page rebuild needed.
-- ============================================================

  -- Page 52: Object Detail
  PROCEDURE RENDER_OBJECT_BREADCRUMB(
    p_run_id      IN NUMBER,
    p_cemli_code  IN VARCHAR2
  );

  PROCEDURE RENDER_OBJECT_BREAKDOWN(
    p_run_id      IN NUMBER,
    p_cemli_code  IN VARCHAR2
  );

  PROCEDURE RENDER_ESS_JOBS(
    p_run_id      IN NUMBER,
    p_cemli_code  IN VARCHAR2
  );

  -- Page 57: Record Detail
  PROCEDURE RENDER_RECORD_HEADER(
    p_run_id      IN NUMBER,
    p_sub_object  IN VARCHAR2,
    p_status      IN VARCHAR2 DEFAULT NULL,
    p_cemli_code  IN VARCHAR2 DEFAULT NULL
  );

  PROCEDURE RENDER_RECORD_TABLE(
    p_run_id      IN NUMBER,
    p_sub_object  IN VARCHAR2,
    p_status      IN VARCHAR2 DEFAULT NULL
  );

  -- ============================================================
  -- Render methods folded in from the former standalone
  -- top-level procedures (backlog #41). Each preserves the exact
  -- HTML the pages depend on; only the container changed.
  -- ============================================================

  -- Page 82: Run Detail status tiles (was procedure DMT_RUN_DETAIL_TILES)
  PROCEDURE RENDER_RUN_TILES(
    p_run_id IN NUMBER
  );

  -- Page 82: Run Detail header bar (was procedure DMT_RUN_DETAIL_HEADER)
  PROCEDURE RENDER_RUN_HEADER(
    p_run_id IN NUMBER
  );

  -- Pages 52/53: Object/ESS detail breadcrumb (was procedure DMT_OBJECT_DETAIL_BREADCRUMB)
  PROCEDURE RENDER_DETAIL_BREADCRUMB(
    p_run_id      IN NUMBER,
    p_cemli_code  IN VARCHAR2
  );

  -- ESS job tree + files (was procedure DMT_ESS_JOB_DETAIL)
  PROCEDURE RENDER_ESS_JOB_DETAIL(
    p_ess_job_id  IN VARCHAR2,
    p_run_id      IN NUMBER,
    p_cemli_code  IN VARCHAR2
  );

  -- Page 8 (Admin): generic view renderer (was procedure DMT_RENDER_VIEW)
  PROCEDURE RENDER_VIEW(
    p_view_name IN VARCHAR2,
    p_title     IN VARCHAR2
  );

  -- Page 84: execution-plan preview (was procedure DMT_PLAN_PREVIEW_HTML)
  PROCEDURE RENDER_PLAN_PREVIEW(
    p_codes IN VARCHAR2
  );

END DMT_APEX_PAGE_PKG;
/
