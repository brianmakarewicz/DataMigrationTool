-- PACKAGE DMT_SALARY_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_SALARY_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_SALARY_TRANSFORM_PKG
-- Transforms staged Salary HDL records into the transformed table.
-- Applies run prefix to PERSON_NUMBER and ASSIGNMENT_NUMBER (if non-null).
-- All other columns copied verbatim from STG.
--
-- One object type: Salary.
-- Called by DMT_LOADER_PKG before HDL generation.
--
-- Staging STATUS lifecycle managed here:
--   NEW / RETRY  -> TRANSFORMED (success) or FAILED (exception)
--
-- TFM STATUS set on insert:
--   STAGED (ready for HDL generation)
-- ============================================================

    -- Transform eligible Salary staging rows for this run.
    -- Applies run prefix to PERSON_NUMBER and ASSIGNMENT_NUMBER.
    PROCEDURE TRANSFORM_SALARIES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

END DMT_SALARY_TRANSFORM_PKG;
/
