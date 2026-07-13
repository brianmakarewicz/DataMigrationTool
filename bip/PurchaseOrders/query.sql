-- ============================================================
-- PurchaseOrders BIP Reconciliation Query (Two-Tier)
-- Data source: ApplicationDB_FSCM
-- Parameters: :P_BATCH_ID       = Load ESS request ID (LOAD_REQUEST_ID)
--             :P_IMPORT_ESS_ID  = Import Orders ESS request ID (base-table lookup)
--
-- Tier 1 (INTERFACE): rows still in PO_HEADERS_INTERFACE after the import ran.
--   A row left in the interface did NOT reach the base table -- i.e. it failed
--   (or is mid-flight). PROCESS_CODE tells the outcome; errors come from
--   PO_INTERFACE_ERRORS joined on INTERFACE_HEADER_ID, prefixed by level:
--     [HDR] header · [LINE] line · [LLOC] line location · [DIST] distribution.
--
-- Tier 2 (BASE): rows that reached the base table PO_HEADERS_ALL, positively
--   confirmed as loaded into Fusion. Linked via REQUEST_ID = the Import Orders
--   ESS job id (verified live: successful POs carry the import request id, e.g.
--   segment1 10073RT-PO-001 -> po_header_id 674875, request_id = import ESS).
--   The business key SEGMENT1 equals the prefixed DOCUMENT_NUM the loader wrote,
--   so the reconciler matches BASE rows to their TFM record on DOCUMENT_NUM.
-- ============================================================
SELECT
    h.interface_header_key,
    h.document_num,
    h.po_header_id,
    'INTERFACE'                         AS source_type,
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

UNION ALL

SELECT
    CAST(NULL AS VARCHAR2(50))          AS interface_header_key,
    b.segment1                          AS document_num,
    b.po_header_id,
    'BASE'                              AS source_type,
    'SUCCESS'                           AS process_code,
    CAST(NULL AS VARCHAR2(240))         AS vendor_name,
    CAST(NULL AS VARCHAR2(30))          AS vendor_num,
    CAST(NULL AS VARCHAR2(4000))        AS error_message
FROM   po_headers_all b
WHERE  b.request_id = :P_IMPORT_ESS_ID
AND    :P_IMPORT_ESS_ID IS NOT NULL
