-- 1099Invoices BIP reconciliation query
-- Run against Fusion to verify before building DM
-- Replace :P_BATCH_ID with actual load_request_id
-- Same query as APInvoices — both share AP_INVOICES_INTERFACE.
-- Differentiation happens at the DMT side (separate CEMLI_CODE in DMT_BIP_REPORT_TBL).
SELECT
    h.invoice_num,
    h.invoice_id,
    h.import_status,
    h.vendor_name,
    h.vendor_num,
    (
        SELECT LISTAGG(e.reject_lookup_code || ': ' || e.parent_table || '.' || e.column_name, '; ')
               WITHIN GROUP (ORDER BY e.interface_line_id)
        FROM   ap_interface_rejections e
        WHERE  e.parent_id = h.invoice_id
        AND    e.parent_table = 'AP_INVOICES_INTERFACE'
    ) AS error_message
FROM   ap_invoices_interface h
WHERE  h.load_request_id = :P_BATCH_ID;
