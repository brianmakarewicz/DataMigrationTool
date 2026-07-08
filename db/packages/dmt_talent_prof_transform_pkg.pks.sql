-- PACKAGE DMT_TALENT_PROF_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_TALENT_PROF_TRANSFORM_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_TALENT_PROF_TRANSFORM_PKG
-- Transforms staged TalentProfile HDL records into the transformed table(s).
-- Called by DMT_LOADER_PKG before HDL generation.
-- ============================================================

    PROCEDURE TRANSFORM_TALENTPROFILES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

END DMT_TALENT_PROF_TRANSFORM_PKG;
/
