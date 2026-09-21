-- PACKAGE DMT_PROJECT_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_PROJECT_RESULTS_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_PROJECT_RESULTS_PKG spec
-- Post-load reconciliation for Projects — Contract v1, MULTI-TIER template.
-- ONE object, four record types (Projects, Tasks, TeamMembers, TxnControls)
-- in one FBDI zip / one Import ESS job.
--
-- Reuses the ONE shared Contract v1 fetch DMT_RECON_CONTRACT_PKG.FETCH_ROWS
-- (Option A, owner decision on PR #248), exactly as the Requisitions (PR #364)
-- and Workers templates do. A single fetch runs the Projects Contract v1 report
-- (nine columns, keyset paginated) over BIP and returns ALL four tiers' rows in
-- one collection; each row's OBJECT_TYPE says which tier it belongs to. The apply
-- is STATIC SQL, one pair of UPDATEs per tier, joined on RECON_KEY = the report
-- RECORD_KEY.
--
--   Tier          OBJECT_TYPE literal   TFM table
--   -----------   -------------------   ----------------------------
--   Projects      'Projects'            DMT_PJF_PROJECTS_TFM_TBL
--   Tasks         'Tasks'               DMT_PJF_TASKS_TFM_TBL
--   TeamMembers   'TeamMembers'         DMT_PJF_TEAM_MEMBERS_TFM_TBL
--   TxnControls   'TxnControls'         DMT_PJC_TXN_CONTROLS_TFM_TBL
--
-- The Projects interface tables carry NO error-text column, so the Contract v1
-- report emits the literal marker '#IMPORT_REPORT#' on ERROR rows. The apply
-- leaves those marker rows GENERATED; RECONCILE_BATCH then runs the import-report
-- harvest (child ImportProjectReportJob XML) to overlay the real per-row Fusion
-- message. That harvest is the ONLY source of real error text for Projects.
--
-- The BIP report path + CONTRACT_VERSION are read from DMT_BIP_REPORT_TBL at
-- runtime by the shared fetch. CEMLI_CODE: 'Projects'.
-- ============================================================

    -- Main entry point: called by DMT_LOADER_PKG after POLL_ESS_JOB completes.
    -- Signature is fixed by the loader dispatch and must not change.
    -- p_load_ess_id is the Contract v1 P_LOAD_REQUEST_ID; the report's run-scoped
    -- selectors (P_RUN_ID, P_PREFIX) pick up the whole run. p_import_ess_id drives
    -- the import-report harvest. p_work_queue_id retained for the registered
    -- signature contract.
    PROCEDURE RECONCILE_BATCH (
        p_run_id         IN NUMBER,
        p_load_ess_id    IN NUMBER,
        p_import_ess_id  IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    );

END DMT_PROJECT_RESULTS_PKG;
/
