-- ============================================================
-- APInvoices BIP reconciliation query -- MIRROR of the deployed
-- data model bip/APInvoices/AP_DM.xdm (deploy target
-- /Custom/DMT2/APInvoices/). The SQL below is the byte-exact
-- CDATA body of that .xdm; regenerate this file from the .xdm
-- whenever the data model changes -- the mirror must never drift.
-- Selection key: P_BATCH_ID = the load ESS request id, matched to
-- ap_invoices_interface.load_request_id (populated even when the
-- chained import job errors).
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
    NVL(
        (SELECT LISTAGG(NVL(r.rejection_message, r.reject_lookup_code), '; ')
                WITHIN GROUP (ORDER BY r.reject_lookup_code)
         FROM   ap_interface_rejections r
         WHERE  r.parent_id = h.invoice_id
         AND    r.parent_table = 'AP_INVOICES_INTERFACE'),
        (SELECT LISTAGG(NVL(r2.rejection_message, r2.reject_lookup_code), '; ')
                WITHIN GROUP (ORDER BY r2.reject_lookup_code)
         FROM   ap_invoice_lines_interface l
         JOIN   ap_interface_rejections r2
                ON r2.parent_id = l.invoice_line_id
                AND r2.parent_table = 'AP_INVOICE_LINES_INTERFACE'
         WHERE  l.invoice_id = h.invoice_id)
    ) AS error_message
FROM   ap_invoices_interface h
LEFT JOIN ap_invoices_all b ON b.invoice_num = h.invoice_num
WHERE  h.load_request_id = :P_BATCH_ID
