-- PACKAGE DMT_GL_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_GL_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_GL_TRANSFORM_PKG
-- Transforms staged GL Balance records into the
-- transformed table. Applies run prefix to REFERENCE1 (batch ref).
-- ============================================================

    PROCEDURE TRANSFORM (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

END DMT_GL_TRANSFORM_PKG;
/
