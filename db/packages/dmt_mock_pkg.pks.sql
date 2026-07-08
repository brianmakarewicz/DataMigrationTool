-- PACKAGE DMT_MOCK_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_MOCK_PKG"
AUTHID DEFINER
AS
-- ============================================================
-- DMT_MOCK_PKG — engine-test stubs (Stage C task 3)
--
-- MockObject / MockChild are registered in DMT_PIPELINE_DEF_TBL
-- (TEST pipeline, EXEC_MODE = LOCAL) and DMT_CEMLI_CATALOG_TBL.
-- Their stubs prove the queue engine end-to-end with no Fusion:
-- each stage (VALIDATE / TRANSFORM / GENERATE / RECONCILE) writes
-- a DMT_LOG_TBL marker row (PACKAGE_NAME = 'DMT_MOCK_PKG',
-- PROCEDURE_NAME = the stage, MESSAGE = 'DMT_MOCK <code> <stage> ran')
-- and flips no real data.
--
-- Failure injection (DMT_CONFIG_TBL):
--   MOCK_FAIL_STAGE  = NONE | VALIDATE | TRANSFORM | GENERATE | RECONCILE
--   MOCK_FAIL_OBJECT = the CEMLI code the injection applies to
--                      (default MockObject)
-- When the running mock's code matches MOCK_FAIL_OBJECT and the
-- stage matches MOCK_FAIL_STAGE, the stub raises ORA-20990 with a
-- stage-tagged message ('[TRANSFORM_ERROR] …') and the queue
-- worker's handler must land the work item in FAILED — never hung.
--
-- RUN_MOCK_OBJECT / RUN_MOCK_CHILD share the DMT_LOADER_PKG.RUN_*
-- dispatch signature (that is the registry contract EXEC_PROC
-- procedures are invoked with). RECONCILE_BATCH uses the
-- p_cemli_code form (RECON_HAS_CEMLI_ARG = 'Y').
-- ============================================================

    PROCEDURE RUN_MOCK_OBJECT (
        p_run_id           IN NUMBER,
        p_scenario_name    IN VARCHAR2 DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N',
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW',
        p_skip_bu_refresh  IN BOOLEAN  DEFAULT FALSE
    );

    PROCEDURE RUN_MOCK_CHILD (
        p_run_id           IN NUMBER,
        p_scenario_name    IN VARCHAR2 DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N',
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW',
        p_skip_bu_refresh  IN BOOLEAN  DEFAULT FALSE
    );

    PROCEDURE RECONCILE_BATCH (
        p_run_id        IN NUMBER,
        p_cemli_code    IN VARCHAR2,
        p_load_ess_id   IN NUMBER,
        p_import_ess_id IN NUMBER DEFAULT NULL
    );

END DMT_MOCK_PKG;
/
