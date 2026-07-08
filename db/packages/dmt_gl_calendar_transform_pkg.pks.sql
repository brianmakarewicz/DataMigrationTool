-- PACKAGE DMT_GL_CALENDAR_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_GL_CALENDAR_TRANSFORM_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_GL_CALENDAR_TRANSFORM_PKG
-- Transforms GL Accounting Calendar from STG to TFM.
-- Standalone object, no parent/child relationship.
-- ============================================================

    PROCEDURE TRANSFORM (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N',
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    );

END DMT_GL_CALENDAR_TRANSFORM_PKG;
/
