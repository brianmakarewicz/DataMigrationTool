-- ============================================================
-- 1099Invoices BIP reconciliation query -- MIRROR of the deployed
-- data model bip/1099Invoices/AP_1099_DM.xdm (deploy target
-- /Custom/DMT2/1099Invoices/). The SQL below is the byte-exact
-- CDATA body of that .xdm; regenerate this file from the .xdm
-- whenever the data model changes -- the mirror must never drift.
-- Selection key: P_BATCH_ID = the load ESS request id, matched to
-- ap_invoices_interface.load_request_id.
-- 1099 invoices are part of the AP family: they flow through the
-- same AP_INVOICES_INTERFACE and land in the same AP_INVOICES_ALL
-- base table. Differentiation is by DMT CEMLI_CODE in DMT_BIP_REPORT_TBL.
-- ============================================================
-- BASE-tier confirmation: an invoice is LOADED only when it positively exists in
-- the base table AP_INVOICES_ALL. The interface's own invoice_id is an
-- interface-local id -- NOT the base id -- so the base row is resolved by business
-- key (invoice_num) and INVOICE_ID is reported as the real base invoice_id.
-- IMPORT_STATUS is derived from base-table presence ('PROCESSED' when a base row
-- exists, 'REJECTED' when it does not), not from the interface's own status.
-- The DMT reconciler maps 'PROCESSED' -> LOADED and stamps FUSION_INVOICE_ID from
-- the base INVOICE_ID. Rule #1: positive base confirmation, not interface inference.
SELECT
    h.invoice_num,
    b.invoice_id,
    h.vendor_name,
    h.vendor_num,
    CASE WHEN b.invoice_id IS NOT NULL THEN 'PROCESSED' ELSE 'REJECTED' END AS import_status,
    (
        SELECT LISTAGG(e.reject_lookup_code || ': ' || e.parent_table || '.' || e.column_name, '; ')
               WITHIN GROUP (ORDER BY e.reject_lookup_code)
        FROM   ap_interface_rejections e
        WHERE  e.parent_id = h.invoice_id
        AND    e.parent_table = 'AP_INVOICES_INTERFACE'
    ) AS error_message
FROM   ap_invoices_interface h
LEFT JOIN ap_invoices_all b ON b.invoice_num = h.invoice_num
WHERE  h.load_request_id = :P_BATCH_ID
