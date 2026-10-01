-- PACKAGE DMT_POZ_SUP_SITE_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_POZ_SUP_SITE_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_POZ_SUP_SITE_TRANSFORM_PKG
-- One supplier-family object (coding standard: one transform
-- package per object). Procedure body relocated verbatim from the
-- former shared DMT_POZ_SUP_TRANSFORM_PKG (behavior-preserving
-- split, backlog #43). Called by DMT_LOADER_PKG before FBDI gen.
-- ============================================================

    PROCEDURE TRANSFORM_SITES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

END DMT_POZ_SUP_SITE_TRANSFORM_PKG;
/
