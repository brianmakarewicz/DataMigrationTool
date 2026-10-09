-- PACKAGE DMT_POZ_SUP_SITE_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_POZ_SUP_SITE_RESULTS_PKG"
AUTHID DEFINER
AS
-- ============================================================
-- DMT_POZ_SUP_SITE_RESULTS_PKG
-- Post-load reconciliation for the SupplierSites supplier-family object
-- (coding standard: one results/reconciler package per object).
-- Contract v1 (backlog #217, 2026-10-09): reads the nine-column report
-- DMT_SUP_SITE_RECON_V2_DM through the shared fetch DMT_RECON_CONTRACT_PKG.FETCH_ROWS and
-- applies it with static SQL to DMT_POZ_SUP_SITE_TFM_TBL.
-- The p_cemli_code signature is retained: the pipeline registry
-- dispatches RECON_PROC / reset by name (RECON_HAS_CEMLI_ARG='Y') and
-- always passes 'SupplierSites' to this package.
-- ============================================================

    PROCEDURE RECONCILE_BATCH (
        p_run_id        IN NUMBER,
        p_cemli_code    IN VARCHAR2,
        p_load_ess_id   IN NUMBER,
        p_import_ess_id IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    );

    PROCEDURE RESET_UNACCOUNTED (
        p_run_id        IN NUMBER,
        p_cemli_code    IN VARCHAR2,
        p_load_ess_id   IN NUMBER DEFAULT NULL,
        p_import_ess_id IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    );

END DMT_POZ_SUP_SITE_RESULTS_PKG;
/
