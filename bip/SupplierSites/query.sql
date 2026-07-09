-- ============================================================
-- SupplierSites BIP reconciliation query -- MIRROR of the deployed
-- data model bip/SupplierSites/SUP_SITE_DM.xdm (deploy target
-- /Custom/DMT2/SupplierSites/). The SQL below is the byte-exact
-- CDATA body of that .xdm; regenerate this file from the .xdm
-- whenever the data model changes -- the mirror must never drift.
-- Contract v1 parameters (design section 5): P_RUN_ID,
-- P_LOAD_REQUEST_ID (the selection key -- LOAD_REQUEST_ID is
-- populated even when the chained import job errors),
-- P_IMPORT_ESS_ID, P_PREFIX. P_BATCH_ID is retired.
-- ============================================================
SELECT
    i.vendor_site_interface_id,
    i.vendor_site_id,
    i.vendor_name,
    i.vendor_site_code,
    i.status,
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
        WHERE  r.parent_table = 'POZ_SUPPLIER_SITES_INT'
        AND    r.parent_id    = i.vendor_site_interface_id
    ) AS error_message
FROM   poz_supplier_sites_int i
WHERE  i.load_request_id = :P_LOAD_REQUEST_ID
      
