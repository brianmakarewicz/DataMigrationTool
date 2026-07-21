-- PACKAGE DMT_MOCK_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_MOCK_PKG"
AUTHID DEFINER
AS
-- ============================================================
-- DMT_MOCK_PKG — engine-test stubs (Stage C tasks 3 + 4)
--
-- MockObject / MockChild are registered in DMT_PIPELINE_DEF_TBL
-- (TEST pipeline, EXEC_MODE = LOCAL) and DMT_CEMLI_CATALOG_TBL
-- by the TEST-SETUP seed test/unit/setup_mock_objects.sql — the
-- registrations are NOT part of the production install (E1,
-- 2026-07-08), so the mocks are never dispatchable in production.
-- This package and DMT_MOCK_TFM_TBL are installed (the package
-- must compile), but are inert without the registration rows.
--
-- Each stage (VALIDATE / TRANSFORM / GENERATE / RECONCILE) writes
-- a DMT_LOG_TBL marker row (PACKAGE_NAME = 'DMT_MOCK_PKG',
-- PROCEDURE_NAME = the stage). The data phase also writes
-- MOCK_ROW_COUNT rows (config, default 2) into DMT_MOCK_TFM_TBL
-- as GENERATED, so the accounting gate and the run rollup count
-- real rows (design section 5 "Object-tfm_status accounting").
--
-- Failure injection (DMT_CONFIG_TBL, seeded by the test setup):
--   MOCK_FAIL_STAGE  = NONE | VALIDATE | TRANSFORM | GENERATE
--                      | RECONCILE
--   MOCK_FAIL_OBJECT = the CEMLI code the injection applies to
-- Injected raises carry section-5 ERROR_TEXT tags only where the
-- tag table defines one: VALIDATE → [PRE_VALIDATION], TRANSFORM →
-- [TRANSFORM_ERROR], RECONCILE → [RECONCILE_ERROR]. GENERATE has
-- no section-5 tag (generation failures are infrastructure
-- exceptions that fail the work item via EXECUTE_ONE's handler),
-- so its injected message is deliberately untagged — no invented
-- vocabulary (E1, 2026-07-08).
--
-- Reconcile outcome injection (DMT_CONFIG_TBL):
--   MOCK_RECON_OUTCOME = LOADED        (default: GENERATED → LOADED
--                                       — every row accounted, DONE)
--                      | FAILED_ERROR  (GENERATED → FAILED +
--                                       [FUSION_ERROR] text — every
--                                       row accounted, item DONE,
--                                       run COMPLETED_ERRORS)
--                      | UNACCOUNTED   (rows left GENERATED — the
--                                       accounting rule must FAIL
--                                       the item)
--
-- RUN_MOCK_OBJECT / RUN_MOCK_CHILD share the DMT_LOADER_PKG.RUN_*
-- dispatch signature (the registry contract EXEC_PROC procedures
-- are invoked with). RECONCILE_BATCH uses the p_cemli_code form
-- (RECON_HAS_CEMLI_ARG = 'Y').
-- ============================================================

    PROCEDURE RUN_MOCK_OBJECT (
        p_run_id           IN NUMBER,
        p_scenario_name    IN VARCHAR2 DEFAULT NULL,
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW',
        p_skip_bu_refresh  IN BOOLEAN  DEFAULT FALSE
    );

    PROCEDURE RUN_MOCK_CHILD (
        p_run_id           IN NUMBER,
        p_scenario_name    IN VARCHAR2 DEFAULT NULL,
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW',
        p_skip_bu_refresh  IN BOOLEAN  DEFAULT FALSE
    );

    PROCEDURE RECONCILE_BATCH (
        p_run_id        IN NUMBER,
        p_cemli_code    IN VARCHAR2,
        p_load_ess_id   IN NUMBER,
        p_import_ess_id IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL  -- work-queue-ID core: match the
        -- sanctioned RECON_CEMLI dispatch shape (invoke_registered passes it to
        -- every reconciler). The mock ignores it; real reconcilers scope by it.
    );

END DMT_MOCK_PKG;
/
