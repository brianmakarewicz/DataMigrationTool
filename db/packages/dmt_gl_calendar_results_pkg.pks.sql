-- PACKAGE DMT_GL_CALENDAR_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_GL_CALENDAR_RESULTS_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_GL_CALENDAR_RESULTS_PKG
-- GL Calendar reconciliation stub.
-- GL Calendar has no confirmed FBDI template or REST endpoint
-- for automated creation. Calendars are configured via Setup
-- and Maintenance > Manage Accounting Calendars. The generated
-- FBL file serves as a reference for manual setup.
-- ============================================================

    PROCEDURE RECONCILE_BATCH (
        p_run_id IN NUMBER
    );

END DMT_GL_CALENDAR_RESULTS_PKG;
/
