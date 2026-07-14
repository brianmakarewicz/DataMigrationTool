-- ============================================================
-- SupplierSiteAssignments BIP reconciliation query -- MIRROR of the deployed
-- data model bip/SupplierSiteAssignments/SUP_SITE_ASSN_DM.xdm (deploy target
-- /Custom/DMT2/SupplierSiteAssignments/). The SQL below is the byte-exact
-- CDATA body of that .xdm; regenerate this file from the .xdm
-- whenever the data model changes -- the mirror must never drift.
-- Contract v1 parameters (design section 5): P_RUN_ID,
-- P_LOAD_REQUEST_ID (the selection key -- LOAD_REQUEST_ID is
-- populated even when the chained import job errors),
-- P_IMPORT_ESS_ID, P_PREFIX. P_BATCH_ID is retired.
-- ============================================================
-- BASE-tier confirmation: an assignment is LOADED only when it positively exists
-- in the base table POZ_SITE_ASSIGNMENTS_ALL_M. The interface ASSIGNMENT_ID stays
-- NULL even for PROCESSED rows, so the base id is resolved by business key
-- (vendor_site_id + BU). STATUS is derived from that resolved id being non-null
-- (was: the interface's own i.status). ASSIGNMENT_ID is the real base id. Rule #1.
SELECT
    q.assignment_interface_id,
    q.assignment_id,
    q.vendor_name,
    q.vendor_site_code,
    q.business_unit_name,
    CASE WHEN q.assignment_id IS NOT NULL THEN 'PROCESSED' ELSE 'REJECTED' END AS status,
    q.load_request_id,
    q.error_message
FROM (
    SELECT
        i.assignment_interface_id,
        (
            SELECT MAX(a.assignment_id)
            FROM   poz_site_assignments_all_m a,
                   fun_all_business_units_v b
            WHERE  a.vendor_site_id = i.vendor_site_id
            AND    b.bu_id          = a.bu_id
            AND    b.bu_name        = i.business_unit_name
            AND    a.inactive_date IS NULL
        ) AS assignment_id,
        i.vendor_name,
        i.vendor_site_code,
        i.business_unit_name,
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
            WHERE  r.parent_table = 'POZ_SITE_ASSIGNMENTS_INT'
            AND    r.parent_id    = i.assignment_interface_id
        ) AS error_message
    FROM   poz_site_assignments_int i
    WHERE  i.load_request_id = :P_LOAD_REQUEST_ID
) q
      
