-- PACKAGE DMT_CONTRACT_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_CONTRACT_RESULTS_PKG" AUTHID DEFINER AS
-- Contracts post-load reconciliation — Contract v1 (headers only). Reuses the
-- shared DMT_RECON_CONTRACT_PKG.FETCH_ROWS; the apply is static per-tier SQL
-- joined on RECON_KEY = report RECORD_KEY. CEMLI_CODE: 'Contracts'. Tier:
-- 'Contracts' (DMT_PO_HEADERS_INT_TFM_TBL). The header TFM table is shared with
-- the PO family; this reader touches only its own rows via its own report.
    PROCEDURE RECONCILE_BATCH (p_run_id IN NUMBER, p_load_ess_id IN NUMBER, p_import_ess_id IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL);
END DMT_CONTRACT_RESULTS_PKG;
/
