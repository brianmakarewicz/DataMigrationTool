-- ============================================================
-- Suppliers BIP reconciliation query -- MIRROR of the deployed
-- data model bip/Suppliers/SUP_DM.xdm (deploy target
-- /Custom/DMT2/Suppliers/). The SQL below is the byte-exact
-- CDATA body of that .xdm; regenerate this file from the .xdm
-- whenever the data model changes -- the mirror must never drift.
-- Parameter: :P_BATCH_ID = load ESS request id (LOAD_REQUEST_ID --
-- populated even when the chained import job errors).
-- ============================================================

SELECT
    i.vendor_interface_id,
    i.vendor_id,
    i.vendor_name,
    i.segment1,
    i.status,
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
WHERE  i.load_request_id = :P_BATCH_ID
