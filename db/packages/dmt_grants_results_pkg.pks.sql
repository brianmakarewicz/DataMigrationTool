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
-- structurally-empty interface tier); the 14 award children have no persistent
-- Fusion base/interface tables on this pod, so they are accounted by the
-- parent award's verdict (cascade by AWARD_NUMBER), unchanged from the prior
-- reader.
--
-- The Award Batch Import Report fallback (ImportAwardReportJob /
-- AwardBatchImportReportDm, parsed by apply_award_import_report) is RETAINED:
-- Fusion purges the award interface tables right after every import, so real
-- per-award rejection messages survive only in that separate child report.
-- ============================================================
    PROCEDURE RECONCILE_BATCH (p_run_id IN NUMBER, p_load_ess_id IN NUMBER, p_import_ess_id IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL);
END DMT_GRANTS_RESULTS_PKG;
/
