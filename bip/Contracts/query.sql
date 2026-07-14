-- Contracts BIP reconciliation query (Two-Tier)
-- Tier 1 (INTERFACE): rows still in PO_HEADERS_INTERFACE after the import ran.
-- Tier 2 (BASE): rows that reached PO_HEADERS_ALL, positively confirmed as loaded.
--   Linked via REQUEST_ID = the Import Orders ESS job id; discriminated to
--   Contract Purchase Agreements via TYPE_LOOKUP_CODE = 'CONTRACT'. The business
--   key SEGMENT1 equals the prefixed DOCUMENT_NUM the loader wrote, so the
--   reconciler matches BASE rows to their TFM record on DOCUMENT_NUM.
SELECT
    h.interface_header_key, h.document_num, h.po_header_id,
    'INTERFACE'                         AS source_type,
    h.process_code, h.vendor_name, h.vendor_num,
    (SELECT LISTAGG(e.error_message || ' [' || e.table_name || '.' || e.column_name || ']', '; ')
            WITHIN GROUP (ORDER BY e.interface_transaction_id)
     FROM   po_interface_errors e
     WHERE  e.interface_header_id = h.interface_header_id) AS error_message
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
AND    b.type_lookup_code = 'CONTRACT'
