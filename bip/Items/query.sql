-- Items BIP reconciliation query -- MIRROR of the deployed data model
-- bip/Items/ITEM_DM.xdm (deploy target /Custom/DMT2/Items/). The SQL below is
-- the byte-exact CDATA body of that .xdm; regenerate this file from the .xdm
-- whenever the data model changes -- the mirror must never drift.
-- Isolated by LOAD_REQUEST_ID (the load ESS request id), which is unique per
-- batch submission. The interface BATCH_ID column carries the USER batch id
-- (not the run id), so it is NOT a filter here.
-- BASE-tier confirmation: an item is LOADED only when it positively exists in
-- the item master base table EGP_SYSTEM_ITEMS_B (joined on the inventory_item_id
-- + organization_id the import stamps on the interface row). STATUS is derived
-- from base-table presence, not from the interface's own process_status, and
-- INVENTORY_ITEM_ID is the base-table id. Rows still in the interface with no
-- base row are REJECTED -- Rule #1: positive base confirmation, not interface
-- inference. Validated live 2026-07-14: of process_status=7 ("success") rows,
-- some carried an interface inventory_item_id yet never reached the base table;
-- some process_status=3 ("validation error") rows DID reach the base table.
-- The base join reports both correctly where the raw flag would not.
-- Excludes preprocessing rows (organization_code IS NULL).
SELECT
    i.item_number,
    i.organization_code,
    b.inventory_item_id,
    i.process_status AS process_flag,
    i.transaction_type,
    CASE WHEN b.inventory_item_id IS NOT NULL THEN 'PROCESSED' ELSE 'REJECTED' END AS status,
    NULL AS error_message
FROM   egp_system_items_interface i
LEFT JOIN egp_system_items_b b
       ON b.inventory_item_id = i.inventory_item_id
      AND b.organization_id   = i.organization_id
WHERE  i.load_request_id = :P_LOAD_REQUEST_ID
AND    i.organization_code IS NOT NULL
