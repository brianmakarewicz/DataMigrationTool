-- ============================================================
-- PurchaseOrders BIP Reconciliation Query
-- Data source: ApplicationDB_FSCM
-- Interface table: PO_HEADERS_INTERFACE
-- Parameter: :P_BATCH_ID = Load ESS request ID (LOAD_REQUEST_ID)
--
-- PO FBDI loads all 4 object types in one ESS job. PO_HEADERS_INTERFACE
-- is the primary interface table — its PROCESS_CODE tells us whether
-- the header (and its children) loaded successfully.
--
-- Error details come from PO_INTERFACE_ERRORS joined on
-- INTERFACE_HEADER_ID. Errors are prefixed with the level:
--   [HDR]  — header-level error
--   [LINE] — line-level error
--   [LLOC] — line location-level error
--   [DIST] — distribution-level error
-- ============================================================
SELECT
    h.interface_header_key,
    h.document_num,
    h.po_header_id,
    h.process_code,
    h.vendor_name,
    h.vendor_num,
    (
        SELECT LISTAGG(
                   CASE
                       WHEN e.interface_line_location_id IS NOT NULL THEN '[LLOC] '
                       WHEN e.interface_distribution_id IS NOT NULL THEN '[DIST] '
                       WHEN e.interface_line_id IS NOT NULL THEN '[LINE] '
                       ELSE '[HDR] '
                   END || e.error_message || ' [' || e.table_name || '.' || e.column_name || ']', '; ')
               WITHIN GROUP (ORDER BY e.interface_transaction_id)
        FROM   po_interface_errors e
        WHERE  e.interface_header_id = h.interface_header_id
    ) AS error_message
FROM   po_headers_interface h
WHERE  h.load_request_id = :P_BATCH_ID
