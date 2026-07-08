-- PACKAGE DMT_WORKER_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_WORKER_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_WORKER_TRANSFORM_PKG
-- Transforms staged Worker HDL records into the transformed tables.
-- Applies run prefix to PERSON_NUMBER.
-- All other columns copied verbatim from STG.
--
-- Seven object types: Worker, PersonName, PersonEmail, PersonPhone,
-- PersonAddress, PersonNationalIdentifier, PersonLegislativeData.
-- Called by DMT_LOADER_PKG before HDL generation.
--
-- Staging STATUS lifecycle managed here:
--   NEW / RETRY  -> TRANSFORMED (success) or FAILED (exception)
--
-- TFM STATUS set on insert:
--   STAGED (ready for HDL generation)
-- ============================================================

    -- Transform eligible Worker staging rows for this run.
    -- Applies run prefix to PERSON_NUMBER.
    PROCEDURE TRANSFORM_WORKERS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

    -- Transform eligible PersonName staging rows for this run.
    -- PERSON_NUMBER gets prefix applied to link to parent Worker.
    PROCEDURE TRANSFORM_PERSON_NAMES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

    -- Transform eligible PersonEmail staging rows for this run.
    PROCEDURE TRANSFORM_PERSON_EMAILS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

    -- Transform eligible PersonPhone staging rows for this run.
    PROCEDURE TRANSFORM_PERSON_PHONES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

    -- Transform eligible PersonAddress staging rows for this run.
    PROCEDURE TRANSFORM_PERSON_ADDRESSES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

    -- Transform eligible PersonNationalIdentifier staging rows for this run.
    PROCEDURE TRANSFORM_PERSON_NIDS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

    -- Transform eligible PersonLegislativeData staging rows for this run.
    PROCEDURE TRANSFORM_PERSON_LEGISL (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

END DMT_WORKER_TRANSFORM_PKG;
/
