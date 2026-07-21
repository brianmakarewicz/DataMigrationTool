-- PACKAGE DMT_FA_ASSET_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_FA_ASSET_RESULTS_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_FA_ASSET_RESULTS_PKG
-- Post-load BIP reconciliation for Assets — Two-Tier pattern.
-- Tier 1: FA_MASS_ADDITIONS (interface table, POSTED/errors)
-- Tier 2: FA_ADDITIONS_B (base table, positive confirmation)
-- CEMLI_CODE: 'Assets'
-- ============================================================
    -- GET_PARTITION_KEYS — distinct spawn-per-partition tokens (BOOK_TYPE_CODE)
    -- for one run, STATIC SQL over this object's own asset-book transform table.
    -- Called through DMT_QUEUE_WORKER_PKG.invoke_registered (style KEYS); one
    -- child work item is spawned per token, which the engine treats as opaque.
    FUNCTION GET_PARTITION_KEYS (p_run_id IN NUMBER) RETURN DMT_OWNER.DMT_PARTITION_KEY_TBL;
    PROCEDURE RECONCILE_BATCH (p_run_id IN NUMBER, p_load_ess_id IN NUMBER, p_import_ess_id IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL);
    FUNCTION FETCH_BIP_RESULTS (p_run_id IN NUMBER, p_load_ess_id IN NUMBER, p_import_ess_id IN NUMBER DEFAULT NULL) RETURN CLOB;
    PROCEDURE PARSE_AND_UPDATE (p_run_id IN NUMBER, p_xml_data IN CLOB);
END DMT_FA_ASSET_RESULTS_PKG;
/
