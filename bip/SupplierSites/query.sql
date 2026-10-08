-- BASE-tier confirmation: a site is LOADED only when it positively exists in the
-- base table POZ_SUPPLIER_SITES_ALL_M. The interface leaves VENDOR_SITE_ID NULL
-- even for PROCESSED rows, so the base row is resolved by business key
-- (vendor_id + vendor_site_code). STATUS is derived from base-table presence, and
-- VENDOR_SITE_ID is the real base id -- which also retires the prior "interface
-- returned NULL vendor_site_id" residue note. Rule #1: positive base confirmation.
SELECT
    i.vendor_site_interface_id,
    b.vendor_site_id,
    i.vendor_name,
    i.vendor_site_code,
    CASE WHEN b.vendor_site_id IS NOT NULL THEN 'PROCESSED' ELSE 'REJECTED' END AS status,
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
LEFT JOIN poz_supplier_sites_all_m b
       ON b.vendor_id = i.vendor_id AND b.vendor_site_code = i.vendor_site_code
WHERE  i.load_request_id = :P_LOAD_REQUEST_ID
