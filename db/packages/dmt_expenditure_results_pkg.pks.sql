-- PACKAGE DMT_EXPENDITURE_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_EXPENDITURE_RESULTS_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_EXPENDITURE_RESULTS_PKG spec
-- Expenditures BIP reconciliation. CEMLI_CODE: 'Expenditures'
-- Two-tier: interface table (PJC_TXN_XFACE_STAGE_ALL) + base table (PJC_EXP_ITEMS_ALL)
-- Single table, no cascade.
-- ============================================================
    -- Spawn-per-partition (work-queue-ID core): one child work item per distinct
    -- (USER_TRANSACTION_SOURCE, DOCUMENT_NAME) group. Composite two-column key.
    FUNCTION GET_PARTITION_KEYS (p_run_id IN NUMBER) RETURN DMT_PARTITION_KEY_TBL;
    PROCEDURE RECONCILE_BATCH (p_run_id IN NUMBER, p_load_ess_id IN NUMBER, p_import_ess_id IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL);
    PROCEDURE PARSE_AND_UPDATE (p_run_id IN NUMBER, p_xml IN XMLTYPE, p_import_ess_id IN NUMBER DEFAULT NULL);
    -- RESET_UNACCOUNTED -- re-run-reconcile recovery (backlog #95). Static UPDATE
    -- over this object's OWN literally-named TFM table(s): flip this run's
    -- UNACCOUNTED rows back to GENERATED and strip the bare [UNACCOUNTED] tag so
    -- the next reconcile pass re-examines them. Dispatched by the queue worker
    -- through the sanctioned invoke_registered site (INVOKE_RESET, RECON style);
    -- the ESS-id args are ignored. NO dynamic SQL; NO COMMIT (caller owns the txn).
    PROCEDURE RESET_UNACCOUNTED (p_run_id IN NUMBER, p_load_ess_id IN NUMBER DEFAULT NULL,
        p_import_ess_id IN NUMBER DEFAULT NULL, p_work_queue_id IN NUMBER DEFAULT NULL);

END DMT_EXPENDITURE_RESULTS_PKG;
/
