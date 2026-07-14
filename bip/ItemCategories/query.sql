-- ItemCategories BIP reconciliation query -- MIRROR of the deployed data model
-- bip/ItemCategories/ITEM_CAT_DM.xdm (deploy target /Custom/DMT2/ItemCategories/).
-- The SQL below is the byte-exact CDATA body of that .xdm; regenerate this file
-- from the .xdm whenever the data model changes -- the mirror must never drift.
-- Isolated by LOAD_REQUEST_ID (unique per batch submission); the interface
-- BATCH_ID carries the USER batch id (not the run id), so it is NOT a filter here.
-- BASE-tier confirmation: a category assignment is LOADED only when it positively
-- exists in the base table EGP_ITEM_CATEGORIES (joined on the four resolved ids the
-- import stamps on the interface row: inventory_item_id + organization_id +
-- category_id + category_set_id). STATUS is derived from base-table presence, not
-- from the interface's own process_status. The base id is EGP_ITEM_CATEGORIES.
-- ITEM_CATEGORY_ASSIGNMENT_ID (the assignment table's surrogate key — there is no
-- ITEM_CATEGORY_ID column on that table; using it 500'd the report); it is aliased
-- back to ITEM_CATEGORY_ID so the report's output element/contract is unchanged.
-- Rows still in the interface with no base row are REJECTED -- Rule #1: positive
-- base confirmation, not interface inference. Validated live 2026-07-14: a
-- process_status=3 ("validation error") interface row was found present in
-- EGP_ITEM_CATEGORIES, so process_status alone is not a reliable loaded/failed
-- signal; base presence is.
SELECT
    ic.item_number,
    ic.organization_code,
    ic.category_set_name,
    ic.category_code,
    ic.process_status AS process_flag,
    b.item_category_assignment_id AS item_category_id,
    CASE WHEN b.item_category_assignment_id IS NOT NULL THEN 'PROCESSED' ELSE 'REJECTED' END AS status,
    NULL AS error_message
FROM   egp_item_categories_interface ic
LEFT JOIN egp_item_categories b
       ON b.inventory_item_id = ic.inventory_item_id
      AND b.organization_id   = ic.organization_id
      AND b.category_id       = ic.category_id
      AND b.category_set_id   = ic.category_set_id
WHERE  ic.load_request_id = :P_LOAD_REQUEST_ID
