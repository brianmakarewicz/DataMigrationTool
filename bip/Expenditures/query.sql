-- ============================================================
-- Expenditures BIP Reconciliation Query (Two-Tier)
-- Data source: ApplicationDB_FSCM
-- Parameters: :P_BATCH_ID = Load ESS request ID (LOAD_REQUEST_ID)
--             :P_IMPORT_ESS_ID = Import ESS request ID (for base table lookup)
--
-- Tier 1 (INTERFACE): Rows in PJC_TXN_XFACE_STAGE_ALL after import.
--   TRANSACTION_STATUS_CODE: 'P' = Processed (success), others = error.
--
-- Tier 2 (BASE): Rows that reached PJC_EXP_ITEMS_ALL.
--   Linked via REQUEST_ID = Import ESS job ID.
--
-- AD#19 note: PJC_TXN_XFACE_STAGE_ALL has NO error message column (verified:
-- no %MSG%, %ERR%, %DETAIL% columns exist). Error detail comes from
-- Import Report XML via DMT_IMPORT_REPORT_PKG.PARSE_ERRORS in the results
-- package. The BIP query returns status only.
-- ============================================================
SELECT
    e.orig_transaction_reference,
    e.project_number,
    e.task_number,
    e.expenditure_type,
    'INTERFACE'                         AS source_type,
    e.transaction_status_code           AS fusion_status,
    CAST(NULL AS NUMBER)                AS fusion_id,
    CAST(NULL AS VARCHAR2(4000))        AS error_message
FROM   pjc_txn_xface_stage_all e
WHERE  e.load_request_id = :P_BATCH_ID

UNION ALL

SELECT
    ei.orig_transaction_reference,
    CAST(NULL AS VARCHAR2(25))          AS project_number,
    CAST(NULL AS VARCHAR2(100))         AS task_number,
    CAST(NULL AS VARCHAR2(240))         AS expenditure_type,
    'BASE'                              AS source_type,
    'SUCCESS'                           AS fusion_status,
    ei.expenditure_item_id              AS fusion_id,
    CAST(NULL AS VARCHAR2(4000))        AS error_message
FROM   pjc_exp_items_all ei
WHERE  ei.request_id = :P_IMPORT_ESS_ID
AND    :P_IMPORT_ESS_ID IS NOT NULL
