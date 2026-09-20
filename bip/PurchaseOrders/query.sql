-- ============================================================
-- PurchaseOrders reconciliation query -- BIP reconciliation report
-- contract v1 (nine columns, keyset pagination, six parameters).
-- Standalone copy of the SQL embedded in DMT_PO_RECON_DM.xdm; keep the
-- two in sync. Covers PurchaseOrders / BlanketPOs / Contracts (one
-- shared FBDI zip, interface + base tables, transformer and DM).
--
-- Bind variables (Contract v1, six):
--   :P_RUN_ID          pipeline run id -- prefixes every stamped key
--   :P_LOAD_REQUEST_ID Import Orders load id -- per-batch INTERFACE selector
--   :P_IMPORT_ESS_ID   Import Orders ESS request id -- BASE selector (REQUEST_ID)
--   :P_PREFIX          run prefix -- declared for symmetry, not used here
--   :P_CHUNK_SIZE      keyset page size
--   :P_AFTER_KEY       keyset cursor (previous page's last RECORD_KEY)
--
-- Nine columns, in contract order:
--   OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE, FUSION_STATUS, FUSION_ID,
--   ERROR_MESSAGE, LOAD_REQUEST_ID, SOURCE_REF, DMT_REFERENCE
--
-- Eight tiers = 4 record types (headers/lines/line-locations/
-- distributions) x BASE + INTERFACE, UNION ALL-ed, ordered by RECORD_KEY.
--   BASE      = row present in a Fusion base table  => SUCCESS, FUSION_ID set.
--   INTERFACE = rejection left in the interface     => ERROR, real Fusion text.
-- See the DM header for the full row-selection rationale and the live
-- facts each tier was proven against.
-- ============================================================
SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    -- ========== BASE tier: positive proof, one block per record type ==========

    -- BASE / headers. RECORD_KEY = base SEGMENT1 (prefixed DOCUMENT_NUM
    -- = TFM business key; the base header does not persist the stamped key).
    SELECT
        'PurchaseOrders'                     AS object_type,
        h.segment1                           AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        h.po_header_id                       AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        TO_NUMBER(:P_IMPORT_ESS_ID)          AS load_request_id,
        h.segment1                           AS source_ref,
        h.interface_source_code              AS dmt_reference
    FROM   po_headers_all h
    WHERE  h.request_id = :P_IMPORT_ESS_ID
    AND    :P_IMPORT_ESS_ID IS NOT NULL

    UNION ALL

    -- BASE / lines. RECORD_KEY derived from parent segment1 + LINE_NUM.
    SELECT
        'PurchaseOrders.Line'                AS object_type,
        h.segment1 || ':LN:' || l.line_num   AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        l.po_line_id                         AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        TO_NUMBER(:P_IMPORT_ESS_ID)          AS load_request_id,
        h.segment1                           AS source_ref,
        h.interface_source_code              AS dmt_reference
    FROM   po_lines_all l
    JOIN   po_headers_all h ON h.po_header_id = l.po_header_id
    WHERE  l.request_id = :P_IMPORT_ESS_ID
    AND    :P_IMPORT_ESS_ID IS NOT NULL

    UNION ALL

    -- BASE / line-locations. RECORD_KEY = segment1 + LINE_NUM + SHIPMENT_NUM.
    SELECT
        'PurchaseOrders.LineLocation'        AS object_type,
        h.segment1 || ':LN:' || l.line_num || ':LOC:' || ll.shipment_num  AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        ll.line_location_id                  AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        TO_NUMBER(:P_IMPORT_ESS_ID)          AS load_request_id,
        h.segment1                           AS source_ref,
        h.interface_source_code              AS dmt_reference
    FROM   po_line_locations_all ll
    JOIN   po_lines_all   l ON l.po_line_id   = ll.po_line_id
    JOIN   po_headers_all h ON h.po_header_id = ll.po_header_id
    WHERE  ll.request_id = :P_IMPORT_ESS_ID
    AND    :P_IMPORT_ESS_ID IS NOT NULL

    UNION ALL

    -- BASE / distributions. PO_DISTRIBUTIONS_ALL does not stamp REQUEST_ID
    -- on this pod, so the distribution is confirmed transitively through
    -- its loaded parent line-location. RECORD_KEY = segment1 + LINE_NUM +
    -- SHIPMENT_NUM + DISTRIBUTION_NUM.
    SELECT
        'PurchaseOrders.Distribution'        AS object_type,
        h.segment1 || ':LN:' || l.line_num || ':LOC:' || ll.shipment_num
                     || ':DIST:' || d.distribution_num  AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        d.po_distribution_id                 AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        TO_NUMBER(:P_IMPORT_ESS_ID)          AS load_request_id,
        h.segment1                           AS source_ref,
        h.interface_source_code              AS dmt_reference
    FROM   po_distributions_all d
    JOIN   po_line_locations_all ll ON ll.line_location_id = d.line_location_id
    JOIN   po_lines_all   l ON l.po_line_id   = d.po_line_id
    JOIN   po_headers_all h ON h.po_header_id = d.po_header_id
    WHERE  ll.request_id = :P_IMPORT_ESS_ID
    AND    :P_IMPORT_ESS_ID IS NOT NULL

    UNION ALL

    -- ========== INTERFACE tier: rejections only (PROCESS_CODE <> ACCEPTED) ==========

    -- INTERFACE / headers. RECORD_KEY = stamped header key; error from
    -- PO_INTERFACE_ERRORS at the header level (no deeper interface id).
    SELECT
        'PurchaseOrders'                     AS object_type,
        h.interface_header_key               AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        '[HDR] ' || NVL(he.error_message,
             'Rejected by Import Orders (process_code=' || NVL(h.process_code,'NULL')
             || '; no header error row written -- e.g. rejected pre-validation).')
                                             AS error_message,
        h.load_request_id                    AS load_request_id,
        h.interface_header_key               AS source_ref,
        h.interface_source_code              AS dmt_reference
    FROM   po_headers_interface h
    LEFT   JOIN (
        SELECT e.interface_header_id,
               NULLIF(LISTAGG(
                   e.column_name || ': ' || e.error_message,
                   ' | ') WITHIN GROUP (ORDER BY e.interface_transaction_id), '') AS error_message
        FROM   po_interface_errors e
        WHERE  e.interface_header_id IS NOT NULL
        AND    e.interface_line_id   IS NULL
        AND    e.interface_line_location_id IS NULL
        AND    e.interface_distribution_id  IS NULL
        GROUP BY e.interface_header_id
    ) he ON he.interface_header_id = h.interface_header_id
    WHERE  h.load_request_id = :P_LOAD_REQUEST_ID
    AND    h.interface_header_key LIKE :P_RUN_ID || '\_HDR\_%' ESCAPE '\'
    AND    NVL(h.process_code,'X') <> 'ACCEPTED'

    UNION ALL

    -- INTERFACE / lines. RECORD_KEY = stamped line key; line-level error.
    SELECT
        'PurchaseOrders.Line'                AS object_type,
        l.interface_line_key                 AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        '[LINE] ' || NVL(le.error_message,
             'Rejected by Import Orders (process_code=' || NVL(l.process_code,'NULL')
             || '; line not created in base table).')
                                             AS error_message,
        l.load_request_id                    AS load_request_id,
        l.interface_line_key                 AS source_ref,
        CAST(NULL AS VARCHAR2(240))          AS dmt_reference
    FROM   po_lines_interface l
    LEFT   JOIN (
        SELECT e.interface_line_id,
               NULLIF(LISTAGG(
                   e.column_name || ': ' || e.error_message,
                   ' | ') WITHIN GROUP (ORDER BY e.interface_transaction_id), '') AS error_message
        FROM   po_interface_errors e
        WHERE  e.interface_line_id IS NOT NULL
        AND    e.interface_line_location_id IS NULL
        AND    e.interface_distribution_id  IS NULL
        GROUP BY e.interface_line_id
    ) le ON le.interface_line_id = l.interface_line_id
    WHERE  l.load_request_id = :P_LOAD_REQUEST_ID
    AND    l.interface_line_key LIKE :P_RUN_ID || '\_LN\_%' ESCAPE '\'
    AND    NVL(l.process_code,'X') <> 'ACCEPTED'

    UNION ALL

    -- INTERFACE / line-locations. RECORD_KEY = stamped location key.
    SELECT
        'PurchaseOrders.LineLocation'        AS object_type,
        ll.interface_line_location_key       AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        '[LLOC] ' || NVL(loce.error_message,
             'Rejected by Import Orders (process_code=' || NVL(ll.process_code,'NULL')
             || '; line location not created in base table).')
                                             AS error_message,
        ll.load_request_id                   AS load_request_id,
        ll.interface_line_location_key       AS source_ref,
        CAST(NULL AS VARCHAR2(240))          AS dmt_reference
    FROM   po_line_locations_interface ll
    LEFT   JOIN (
        SELECT e.interface_line_location_id,
               NULLIF(LISTAGG(
                   e.column_name || ': ' || e.error_message,
                   ' | ') WITHIN GROUP (ORDER BY e.interface_transaction_id), '') AS error_message
        FROM   po_interface_errors e
        WHERE  e.interface_line_location_id IS NOT NULL
        AND    e.interface_distribution_id  IS NULL
        GROUP BY e.interface_line_location_id
    ) loce ON loce.interface_line_location_id = ll.interface_line_location_id
    WHERE  ll.load_request_id = :P_LOAD_REQUEST_ID
    AND    ll.interface_line_location_key LIKE :P_RUN_ID || '\_LOC\_%' ESCAPE '\'
    AND    NVL(ll.process_code,'X') <> 'ACCEPTED'

    UNION ALL

    -- INTERFACE / distributions. RECORD_KEY = stamped dist key.
    SELECT
        'PurchaseOrders.Distribution'        AS object_type,
        d.interface_distribution_key         AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        '[DIST] ' || NVL(de.error_message,
             'Rejected by Import Orders (process_code=' || NVL(d.process_code,'NULL')
             || '; distribution not created in base table).')
                                             AS error_message,
        d.load_request_id                    AS load_request_id,
        d.interface_distribution_key         AS source_ref,
        CAST(NULL AS VARCHAR2(240))          AS dmt_reference
    FROM   po_distributions_interface d
    LEFT   JOIN (
        SELECT e.interface_distribution_id,
               NULLIF(LISTAGG(
                   e.column_name || ': ' || e.error_message,
                   ' | ') WITHIN GROUP (ORDER BY e.interface_transaction_id), '') AS error_message
        FROM   po_interface_errors e
        WHERE  e.interface_distribution_id IS NOT NULL
        GROUP BY e.interface_distribution_id
    ) de ON de.interface_distribution_id = d.interface_distribution_id
    WHERE  d.load_request_id = :P_LOAD_REQUEST_ID
    AND    d.interface_distribution_key LIKE :P_RUN_ID || '\_DIST\_%' ESCAPE '\'
    AND    NVL(d.process_code,'X') <> 'ACCEPTED'
)
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
