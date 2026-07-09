-- ============================================================
-- SupplierSiteAssignments BIP reconciliation query -- MIRROR of the deployed
-- data model bip/SupplierSiteAssignments/SUP_SITE_ASSN_DM.xdm (deploy target
-- /Custom/DMT2/SupplierSiteAssignments/). The SQL below is the byte-exact
-- CDATA body of that .xdm; regenerate this file from the .xdm
-- whenever the data model changes -- the mirror must never drift.
-- Parameter: :P_BATCH_ID = load ESS request id (LOAD_REQUEST_ID --
-- populated even when the chained import job errors).
-- ============================================================

SELECT
    i.assignment_interface_id,
    -- INT.ASSIGNMENT_ID stays null on this instance even for PROCESSED rows;
    -- resolve the real Fusion id from the base table (proof-of-load, RULE #1).
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
        WHERE  r.parent_table = 'POZ_SITE_ASSIGNMENTS_INT'
        AND    r.parent_id    = i.assignment_interface_id
    ) AS error_message
FROM   poz_site_assignments_int i
WHERE  i.load_request_id = :P_BATCH_ID
