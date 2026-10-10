-- PACKAGE DMT_GRANTS_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_GRANTS_RESULTS_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_GRANTS_RESULTS_PKG spec  --  Grants reconciliation, Contract v1.
-- CEMLI_CODE: 'Grants'
--
-- Award headers are reconciled through the ONE shared Contract v1 fetch
-- (DMT_RECON_CONTRACT_PKG.FETCH_ROWS) against the nine-column Grants recon
-- report (DMT_GRANT_RECON_DM.xdm / DMT_GRANT_RECON_RPT.xdo), exactly as the
-- Requisitions and Workers readers do. The report reconciles the AWARD HEADER
-- tier ONLY (GMS_AWARD_HEADERS_B for LOADED; GMS_AWARD_HEADERS_INT for the
-- structurally-empty interface tier). Each of the 14 award children is
-- accounted on its OWN Fusion evidence (backlog #568): LOADED only when the
-- Award Batch Import Report of this import job lists that child row as
-- imported under a base-confirmed award, or (backlog #671, report V4) when
-- the recon report returns the child's own base row under a confirmed award
-- (keywords, terms, certifications, CFDAs, references, task burden
-- schedules, each stored with its own Fusion id); FAILED with its own error
-- when the report lists it as rejected; otherwise left for the unaccounted
-- sweep. A child is never LOADED by inheritance from its award.
--
-- The Award Batch Import Report fallback (ImportAwardReportJob /
-- AwardBatchImportReportDm, parsed by apply_award_import_report) is RETAINED:
-- Fusion purges the award interface tables right after every import, so real
-- per-award rejection messages survive only in that separate child report.
-- ============================================================
    PROCEDURE RECONCILE_BATCH (p_run_id IN NUMBER, p_load_ess_id IN NUMBER, p_import_ess_id IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL);
    -- RESET_UNACCOUNTED -- re-run-reconcile recovery (backlog #95). Static UPDATE
    -- over this object's OWN literally-named TFM table(s): flip this run's
    -- UNACCOUNTED rows back to GENERATED and strip the bare [UNACCOUNTED] tag so
    -- the next reconcile pass re-examines them. Dispatched by the queue worker
    -- through the sanctioned invoke_registered site (INVOKE_RESET, RECON style);
    -- the ESS-id args are ignored. NO dynamic SQL; NO COMMIT (caller owns the txn).
    PROCEDURE RESET_UNACCOUNTED (p_run_id IN NUMBER, p_load_ess_id IN NUMBER DEFAULT NULL,
        p_import_ess_id IN NUMBER DEFAULT NULL, p_work_queue_id IN NUMBER DEFAULT NULL);
    -- APPLY_AWARD_REPORT_XML -- the report half of RECONCILE_BATCH on a payload
    -- the caller supplies (backlog #568; transport and parse are separable,
    -- design section 7). Applies an Award Batch Import Report XML to this run's
    -- TFM rows exactly as the reconcile does after its base-table pass: child
    -- and award rejections FAILED with their own error, children of LOADED
    -- awards LOADED only on their own success line, then the whole-document
    -- quote onto the other rows of each rejected award. Used by the unit test
    -- test/unit/test_grants_child_accounting.sql. NO COMMIT.
    -- x_error_code = DMT_UTIL_PKG.C_SUCCESS / C_ERROR (failure logged).
    PROCEDURE APPLY_AWARD_REPORT_XML (
        p_run_id      IN  NUMBER,
        p_report_xml  IN  CLOB,
        x_rows_failed OUT NUMBER,
        x_rows_loaded OUT NUMBER,
        x_error_code  OUT NUMBER
    );
    -- APPLY_AWARD_CHILD_ROWS -- the child-tier half of the reconcile (backlog
    -- #671). Takes the parsed Grants recon report rows (V4) and, for every
    -- BASE / SUCCESS row of the six child tiers (Grants.Keyword, Grants.Term,
    -- Grants.Certification, Grants.Cfda, Grants.Reference, Grants.TaskBurden),
    -- sets ONE child TFM row of this run LOADED and stores the row's own Fusion
    -- id in its FUSION_*_ID column. The row is matched on the award number plus
    -- the business key DMT sent (the same '~'-joined key the report builds), is
    -- the lowest TFM_SEQUENCE_ID still awaiting a verdict, and only when its
    -- award header is already LOADED. A Fusion id already stored on a row of
    -- this run is never stored again. Other report rows are ignored. Called by
    -- RECONCILE_BATCH after the award-header pass; public so the unit test
    -- test/unit/test_grants_child_base_ids.sql can drive it. NO COMMIT.
    -- x_error_code = DMT_UTIL_PKG.C_SUCCESS / C_ERROR (failure logged).
    PROCEDURE APPLY_AWARD_CHILD_ROWS (
        p_run_id      IN  NUMBER,
        p_rows        IN  DMT_RECON_CONTRACT_PKG.T_RECON_TBL,
        x_rows_loaded OUT NUMBER,
        x_error_code  OUT NUMBER
    );

END DMT_GRANTS_RESULTS_PKG;
/
