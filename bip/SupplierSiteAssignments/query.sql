-- ============================================================
-- SupplierSiteAssignments BIP Reconciliation Query
-- Data source: ApplicationDB_FSCM
-- Interface table: POZ_SITE_ASSIGNMENTS_INT
-- Error table: POZ_SUPPLIER_INT_REJECTIONS
-- Parameter: :P_BATCH_ID = ESS load request ID (LOAD_REQUEST_ID)
--
-- Natural keys for PARSE_AND_UPDATE match:
--   VENDOR_NAME + VENDOR_SITE_CODE + BUSINESS_UNIT_NAME
--
-- Pattern mirrors confirmed Suppliers query (2026-03-13).
-- STATUS: 'PROCESSED' = success, 'REJECTED' = failed.
-- LOAD_REQUEST_ID filter confirmed correct (not BATCH_ID or IMPORT_REQUEST_ID).
-- 2026-07-03: interface PK column is ASSIGNMENT_INTERFACE_ID (not
-- SITE_ASSIGN_INTERFACE_ID — ORA-00904). ASSIGNMENT_ID comes from the base
-- table via VENDOR_SITE_ID + BU name so LOADED rows carry a real Fusion ID
-- (the INT table's own ASSIGNMENT_ID column stays null on this instance).
-- ============================================================
SELECT
    i.assignment_interface_id,
    i.vendor_name,
    i.vendor_site_code,
    i.business_unit_name,
    i.status,
    i.load_request_id,
    (
        SELECT MAX(a.assignment_id)
        FROM   poz_site_assignments_all_m a,
               fun_all_business_units_v b
        WHERE  a.vendor_site_id = i.vendor_site_id
        AND    b.bu_id          = a.bu_id
        AND    b.bu_name        = i.business_unit_name
        AND    a.inactive_date IS NULL
    ) AS assignment_id,
    (
        SELECT LISTAGG(
                   CASE
                       WHEN r.attribute IS NOT NULL
                       THEN r.reject_lookup_code || ' [' || r.attribute || ']'
                       ELSE r.reject_lookup_code
                   END, '; ')
               WITHIN GROUP (ORDER BY r.rejection_id)
        FROM   poz_supplier_int_rejections r
        WHERE  r.parent_table = 'POZ_SITE_ASSIGNMENTS_INT'
        AND    r.parent_id    = i.assignment_interface_id
    ) AS error_message
FROM   poz_site_assignments_int i
WHERE  i.load_request_id = :P_BATCH_ID
