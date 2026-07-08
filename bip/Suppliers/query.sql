-- ============================================================
-- Suppliers BIP Reconciliation Query
-- Data source: ApplicationDB_FSCM
-- Interface table: POZ_SUPPLIERS_INT
-- Error table: POZ_SUPPLIER_INT_REJECTIONS
-- Parameter: :P_BATCH_ID = ESS import request ID (IMPORT_REQUEST_ID)
--
-- Verified against Fusion 25B on 2026-03-09:
--   - IMPORT_REQUEST_ID = ESS request ID submitted via SOAP
--   - STATUS: 'REJECTED' = failed, 'PROCESSED' = success
--   - BATCH_ID is NULL (not set by import process — do not use as filter)
--   - Error text: POZ_SUPPLIER_INT_REJECTIONS.reject_lookup_code + attribute
--   - Join: POZ_SUPPLIER_INT_REJECTIONS.parent_id = POZ_SUPPLIERS_INT.vendor_interface_id
-- ============================================================
SELECT
    i.vendor_interface_id,
    i.vendor_name,
    i.segment1,
    i.status,
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
        AND    r.request_id   = i.import_request_id
    ) AS error_message
FROM   poz_suppliers_int i
WHERE  i.import_request_id = :P_BATCH_ID
