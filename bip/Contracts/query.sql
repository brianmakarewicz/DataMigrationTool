-- Contracts BIP reconciliation query
SELECT
    h.interface_header_key, h.document_num, h.po_header_id,
    h.process_code, h.vendor_name, h.vendor_num,
    (SELECT LISTAGG(e.error_message || ' [' || e.table_name || '.' || e.column_name || ']', '; ')
            WITHIN GROUP (ORDER BY e.interface_transaction_id)
     FROM   po_interface_errors e
     WHERE  e.interface_header_id = h.interface_header_id) AS error_message
FROM   po_headers_interface h
WHERE  h.load_request_id = :P_BATCH_ID;
