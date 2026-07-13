-- ============================================================
-- SupplierAddresses BIP reconciliation query -- MIRROR of the deployed
-- data model bip/SupplierAddresses/SUP_ADDR_DM.xdm (deploy target
-- /Custom/DMT2/SupplierAddresses/). The SQL below is the byte-exact
-- CDATA body of that .xdm; regenerate this file from the .xdm
-- whenever the data model changes -- the mirror must never drift.
-- Contract v1 parameters (design section 5): P_RUN_ID,
-- P_LOAD_REQUEST_ID (the selection key -- LOAD_REQUEST_ID is
-- populated even when the chained import job errors),
-- P_IMPORT_ESS_ID, P_PREFIX. P_BATCH_ID is retired.
-- ============================================================
-- BASE-tier confirmation: an address is LOADED only when its party site
-- positively exists in HZ_PARTY_SITES (joined on the party_site_id the import
-- stamps on the interface row). STATUS is derived from base-table presence, not
-- the interface's own import_status; PARTY_SITE_ID is the base-table id. Rule #1.
SELECT
    i.address_interface_id,
    b.party_site_id,
    i.vendor_name,
    i.party_site_name,
    CASE WHEN b.party_site_id IS NOT NULL THEN 'PROCESSED' ELSE 'REJECTED' END AS status,
    i.load_request_id,
    (
        SELECT LISTAGG(
                   CASE
                       WHEN r.attribute IS NOT NULL
                       THEN r.reject_lookup_code || ' [' || r.attribute || ']'
                       ELSE r.reject_lookup_code
                   END, '; ')
               WITHIN GROUP (ORDER BY r.rejection_id)
        FROM   poz_supplier_int_rejections r
        WHERE  r.parent_table = 'POZ_SUP_ADDRESSES_INT'
        AND    r.parent_id    = i.address_interface_id
    ) AS error_message
FROM   poz_sup_addresses_int i
LEFT JOIN hz_party_sites b ON b.party_site_id = i.party_site_id
WHERE   i.load_request_id = :P_LOAD_REQUEST_ID
      
