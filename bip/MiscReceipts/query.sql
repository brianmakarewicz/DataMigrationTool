-- MiscReceipts BIP reconciliation query
-- Two-part: LOADED from base table + FAILED from interface table.
-- Match key: SOURCE_CODE='DMT', TRANSACTION_REFERENCE='DMT-{integration_id}', SOURCE_LINE_ID=stg_sequence_id.
--
-- LOADED: rows that reached INV_MATERIAL_TXNS (purged from interface = success).
-- FAILED: rows still in INV_TRANSACTIONS_INTERFACE with PROCESS_FLAG=3 (error).

-- Part 1: Successful rows (base table)
SELECT
    'LOADED'                   AS RESULT_STATUS,
    t.transaction_id           AS FUSION_ID,
    t.source_line_id,
    t.inventory_item_id,
    t.organization_id,
    t.subinventory_code,
    t.transaction_quantity,
    NULL                       AS ERROR_CODE,
    NULL                       AS ERROR_EXPLANATION
FROM   inv_material_txns t
WHERE  t.source_code            = 'DMT'
AND    t.transaction_reference  = :P_BATCH_ID

UNION ALL

-- Part 2: Failed rows (interface table — process_flag=3)
SELECT
    'FAILED'                   AS RESULT_STATUS,
    NULL                       AS FUSION_ID,
    t.source_line_id,
    NULL                       AS INVENTORY_ITEM_ID,
    NULL                       AS ORGANIZATION_ID,
    t.subinventory_code,
    t.transaction_quantity,
    t.error_code,
    t.error_explanation
FROM   inv_transactions_interface t
WHERE  t.source_code            = 'DMT'
AND    t.transaction_reference  = :P_BATCH_ID
AND    t.process_flag           = 3
