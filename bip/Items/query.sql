-- Items BIP reconciliation query
-- EGP_SYSTEM_ITEMS_INTERFACE: PROCESS_STATUS 1=pending, 7=error, 3=validation error, null/0/5=success
-- Filters by BATCH_ID + LOAD_REQUEST_ID to isolate this specific pipeline run
-- Excludes preprocessing rows (organization_code IS NULL)
SELECT
    i.item_number,
    i.organization_code,
    i.inventory_item_id,
    i.process_status AS process_flag,
    i.transaction_type,
    NULL AS error_message
FROM   egp_system_items_interface i
WHERE  i.batch_id = :P_BATCH_ID
AND    i.load_request_id = :P_LOAD_REQUEST_ID
AND    i.organization_code IS NOT NULL;
