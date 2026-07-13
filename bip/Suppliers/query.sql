-- ============================================================
-- Suppliers BIP reconciliation query -- MIRROR of the deployed
-- data model bip/Suppliers/SUP_DM.xdm (deploy target
-- /Custom/DMT2/Suppliers/). The SQL below is the byte-exact
-- CDATA body of that .xdm; regenerate this file from the .xdm
-- whenever the data model changes -- the mirror must never drift.
-- Contract v1 parameters (design section 5): P_RUN_ID,
-- P_LOAD_REQUEST_ID (the selection key -- LOAD_REQUEST_ID is
-- populated even when the chained import job errors),
-- P_IMPORT_ESS_ID, P_PREFIX. P_BATCH_ID is retired.
-- ============================================================
-- BASE-tier confirmation: a supplier is LOADED only when it positively exists
-- in the base table POZ_SUPPLIERS (joined on the vendor_id the import stamps on
-- the interface row). STATUS is derived from base-table presence, not the
-- interface's own i.status, and VENDOR_ID is the base-table id. Rows still in the
-- interface with no base row are REJECTED (with the rejection reason) -- Rule #1:
-- positive base confirmation, not interface inference.
SELECT
    i.vendor_interface_id,
    b.vendor_id,
    i.vendor_name,
    i.segment1,
    CASE WHEN b.vendor_id IS NOT NULL THEN 'PROCESSED' ELSE 'REJECTED' END AS status,
    i.load_request_id,
    i.import_request_id,
    (
        SELECT LISTAGG(
                   CASE
                       WHEN r.attribute IS NOT NULL
                       THEN r.reject_lookup_code || ' [' || r.attribute || ']'
                       ELSE r.reject_lookup_code
                   END, '; ')
               WITHIN GROUP (ORDER BY r.rejection_id)
        FROM   poz_supplier_int_rejections r
        WHERE  r.parent_table = 'POZ_SUPPLIERS_INT'
        AND    r.parent_id    = i.vendor_interface_id
    ) AS error_message
FROM   poz_suppliers_int i
LEFT JOIN poz_suppliers b ON b.vendor_id = i.vendor_id
WHERE  i.load_request_id = :P_LOAD_REQUEST_ID
      
