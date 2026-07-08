-- ItemCategories BIP reconciliation query
-- EGP_ITEM_CATEGORIES_INTERFACE: PROCESS_FLAG null/0 = success, 7 = error
SELECT
    ic.item_number,
    ic.organization_code,
    ic.category_set_name,
    ic.category_code,
    ic.process_flag,
    ic.error_message
FROM   egp_item_categories_interface ic
WHERE  ic.batch_id = :P_BATCH_ID;
