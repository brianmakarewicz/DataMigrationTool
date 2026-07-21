-- PACKAGE DMT_MISC_RECEIPT_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_MISC_RECEIPT_RESULTS_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_MISC_RECEIPT_RESULTS_PKG
-- Post-load BIP reconciliation for MiscReceipts (On Hand Qty).
--
-- INV_TRANSACTIONS_INTERFACE: successful rows are PURGED and
-- moved to MTL_MATERIAL_TRANSACTIONS. Only error rows remain.
-- So: rows found in BIP = FAILED, rows NOT found = LOADED.
--
-- Match key: SOURCE_CODE='DMT' + SOURCE_HEADER_ID=run_id
-- Per-row match: SOURCE_LINE_ID = STG_SEQUENCE_ID
-- CEMLI_CODE: 'MiscReceipts'
-- ============================================================

    PROCEDURE RECONCILE_BATCH (
        p_run_id IN NUMBER,
        p_load_ess_id    IN NUMBER,
        p_import_ess_id  IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    );

    FUNCTION FETCH_BIP_RESULTS (
        p_run_id IN NUMBER,
        p_load_ess_id    IN NUMBER,
        p_import_ess_id  IN NUMBER DEFAULT NULL
    ) RETURN CLOB;

    PROCEDURE PARSE_AND_UPDATE (
        p_run_id IN NUMBER,
        p_xml_data       IN CLOB
    );

END DMT_MISC_RECEIPT_RESULTS_PKG;
/
