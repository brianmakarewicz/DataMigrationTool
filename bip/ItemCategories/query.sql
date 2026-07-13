-- ItemCategories BIP reconciliation query (mirror of ITEM_CAT_DM.xdm)
-- EGP_ITEM_CATEGORIES_INTERFACE.PROCESS_STATUS: 7 = processed OK, 3 = validation error
-- Isolated by LOAD_REQUEST_ID (unique per batch submission); the interface BATCH_ID
-- now carries the USER batch id (not run id), so it is NOT a filter here.
SELECT
    ic.item_number,
    ic.organization_code,
    ic.category_set_name,
    ic.category_code,
    ic.process_status AS process_flag,
    ic.error_message
FROM   egp_item_categories_interface ic
WHERE  ic.load_request_id = :P_LOAD_REQUEST_ID;
