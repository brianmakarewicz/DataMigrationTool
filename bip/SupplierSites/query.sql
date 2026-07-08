-- ============================================================
-- SupplierSites BIP Reconciliation Query
-- Data source: ApplicationDB_FSCM
-- Interface table: POZ_SUPPLIER_SITES_INT
-- Error table: POZ_SUPPLIER_INT_REJECTIONS
-- Parameter: :P_BATCH_ID = ESS load request ID (LOAD_REQUEST_ID)
--
-- Natural keys for PARSE_AND_UPDATE match:
--   VENDOR_NAME + VENDOR_SITE_CODE
--
-- Pattern mirrors confirmed Suppliers query (2026-03-13).
-- STATUS: 'PROCESSED' = success, 'REJECTED' = failed.
-- LOAD_REQUEST_ID filter confirmed correct (not BATCH_ID or IMPORT_REQUEST_ID).
-- ============================================================
SELECT
    i.site_interface_id,
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
        AND    r.parent_id    = i.site_interface_id
    ) AS error_message
FROM   poz_supplier_sites_int i
WHERE  i.load_request_id = :P_BATCH_ID
