-- APInvoices BIP reconciliation query
-- Run against Fusion to verify before building DM
-- Replace :P_BATCH_ID with actual load_request_id
SELECT
    h.invoice_num,
    h.invoice_id,
    NVL(h.status, 'NEW') AS import_status,
    h.vendor_name,
    h.vendor_num,
    (
        SELECT LISTAGG(
                   CASE
                       WHEN e.column_name IS NOT NULL
                       THEN e.reject_lookup_code || ' [' || e.parent_table || '.' || e.column_name || ']'
                       ELSE e.reject_lookup_code
                   END, '; ')
               WITHIN GROUP (ORDER BY e.reject_lookup_code)
        FROM   ap_interface_rejections e
        WHERE  e.parent_id = h.invoice_id
        AND    e.parent_table = 'AP_INVOICES_INTERFACE'
    ) AS error_message
FROM   ap_invoices_interface h
WHERE  h.load_request_id = :P_BATCH_ID;
