-- ============================================================
-- SupplierAddresses BIP Reconciliation Query
-- Data source: ApplicationDB_FSCM
-- Interface table: POZ_SUP_ADDRESSES_INT
-- Error table: POZ_SUPPLIER_INT_REJECTIONS
-- Parameter: :P_BATCH_ID = ESS load request ID (LOAD_REQUEST_ID)
--
-- Natural keys for PARSE_AND_UPDATE match:
--   VENDOR_NAME + PARTY_SITE_NAME
--
-- Pattern mirrors confirmed Suppliers query (2026-03-13).
-- STATUS: 'PROCESSED' = success, 'REJECTED' = failed.
-- LOAD_REQUEST_ID filter confirmed correct (not BATCH_ID or IMPORT_REQUEST_ID).
-- ============================================================
SELECT
    i.address_interface_id,
    i.vendor_name,
    i.party_site_name,
    i.import_status AS status,
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
WHERE  i.load_request_id = :P_BATCH_ID
