-- PACKAGE DMT_ASSIGNMENT_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_ASSIGNMENT_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_ASSIGNMENT_TRANSFORM_PKG
-- Transforms staged Worker Assignment HDL records into the
-- transformed tables. Applies run prefix to PERSON_NUMBER
-- (and MANAGER_PERSON_NUMBER for Assignment).
-- All other columns copied verbatim from STG.
--
-- Two object types: WorkRelationship, Assignment.
-- Called by DMT_LOADER_PKG before HDL generation.
--
-- Staging STATUS lifecycle managed here:
--   NEW / RETRY  -> TRANSFORMED (success) or FAILED (exception)
--
-- TFM STATUS set on insert:
--   STAGED (ready for HDL generation)
-- ============================================================

    -- Transform eligible WorkRelationship staging rows for this run.
    -- Applies run prefix to PERSON_NUMBER.
    PROCEDURE TRANSFORM_WORK_RELS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

    -- Transform eligible Assignment staging rows for this run.
    -- Applies run prefix to PERSON_NUMBER and MANAGER_PERSON_NUMBER.
    PROCEDURE TRANSFORM_ASSIGNMENTS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

END DMT_ASSIGNMENT_TRANSFORM_PKG;
/
