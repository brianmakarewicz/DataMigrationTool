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

END DMT_APEX_PAGE_PKG;
/
