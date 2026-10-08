-- PACKAGE DMT_TALENT_PROF_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_TALENT_PROF_TRANSFORM_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_TALENT_PROF_TRANSFORM_PKG
-- Transforms staged TalentProfile HDL records into the transformed table(s).
-- Called by DMT_LOADER_PKG before HDL generation.
-- ============================================================

    -- Profile type of every profile this object loads: worker talent profiles are
    -- person profiles (the TalentProfile line carries PersonId). With the section
    -- name it forms the PROFILE_SECTION_NAME_TO_SECTION_ID lookup key
    -- (<profile type code>~<section name>, backlog #451). Read by the validator
    -- (reject a missing or ambiguous section) and the transform (resolve the id).
    C_PROFILE_TYPE_CODE CONSTANT VARCHAR2(30) := 'PERSON';

    PROCEDURE TRANSFORM_TALENTPROFILES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

END DMT_TALENT_PROF_TRANSFORM_PKG;
/
