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
    FUNCTION FETCH_BIP_RESULTS (p_run_id IN NUMBER, p_load_ess_id IN NUMBER, p_import_ess_id IN NUMBER DEFAULT NULL) RETURN CLOB;
    PROCEDURE PARSE_AND_UPDATE (p_run_id IN NUMBER, p_xml_data IN CLOB, p_import_ess_id IN NUMBER DEFAULT NULL);
END DMT_EXPENDITURE_RESULTS_PKG;
/
