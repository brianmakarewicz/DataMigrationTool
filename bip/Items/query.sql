-- Items BIP reconciliation query
-- EGP_SYSTEM_ITEMS_INTERFACE: PROCESS_STATUS 1=pending, 7=error, 3=validation error, null/0/5=success
-- Isolated by LOAD_REQUEST_ID (the load ESS request id), which is unique per batch
-- submission. The interface BATCH_ID column now carries the USER batch id (not the
-- run id), so it is NOT a filter here -- load_request_id alone selects this batch's
-- rows. A non-null INVENTORY_ITEM_ID = the item genuinely reached the base table.
-- Excludes preprocessing rows (organization_code IS NULL)
SELECT
    i.item_number,
    i.organization_code,
    i.inventory_item_id,
    i.process_status AS process_flag,
    i.transaction_type,
    NULL AS error_message
FROM   egp_system_items_interface i
WHERE  i.load_request_id = :P_LOAD_REQUEST_ID
AND    i.organization_code IS NOT NULL;
