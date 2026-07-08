-- ============================================================
-- Requisitions BIP Reconciliation Query (Two-Tier)
-- Data source: ApplicationDB_FSCM
-- Parameters: :P_BATCH_ID = Load ESS request ID (LOAD_REQUEST_ID)
--             :P_IMPORT_ESS_ID = Import ESS request ID (for base table lookup)
--
-- Tier 1 (INTERFACE): Rows still in POR_REQ_HEADERS_INTERFACE_ALL after import.
--   Errors from three sources using NUMERIC join keys:
--   1. por_req_import_errors.interface_id = h.req_header_interface_id (header-level)
--   2. por_req_import_errors.interface_id = l.req_line_interface_id (line-level, rolled up)
--   3. por_req_import_errors.interface_id = d.req_dist_interface_id (dist-level, rolled up via line)
--   Error messages prefixed with [HDR], [LINE], or [DIST] to distinguish the source.
--
-- Tier 2 (BASE): Rows that reached the base table POR_REQUISITION_HEADERS_ALL.
--   Positively confirmed as loaded into Fusion.
--   Linked via REQUEST_ID = Import ESS job ID.
-- ============================================================
SELECT
    h.interface_header_key,
    h.requisition_number,
    'INTERFACE'                         AS source_type,
    h.process_flag                      AS process_code,
    CAST(NULL AS NUMBER)                AS fusion_id,
    SUBSTR(
        CASE WHEN hdr_err.error_message IS NOT NULL
             THEN '[HDR] ' || hdr_err.error_message END
     || CASE WHEN hdr_err.error_message IS NOT NULL AND line_tbl_err.error_message IS NOT NULL
             THEN ' | ' END
     || CASE WHEN line_tbl_err.error_message IS NOT NULL
             THEN '[LINE] ' || line_tbl_err.error_message END
     || CASE WHEN (hdr_err.error_message IS NOT NULL OR line_tbl_err.error_message IS NOT NULL)
                  AND dist_err.error_message IS NOT NULL
             THEN ' | ' END
     || CASE WHEN dist_err.error_message IS NOT NULL
             THEN '[DIST] ' || dist_err.error_message END
    , 1, 4000)                          AS error_message
FROM   por_req_headers_interface_all h
/* Source 1: errors joined on header numeric ID */
LEFT OUTER JOIN (
    SELECT e.interface_id,
           e.load_request_id,
           LISTAGG(e.column_name || '=' || e.column_value || ': ' || e.text_line, ' | ')
               WITHIN GROUP (ORDER BY e.req_import_error_id) AS error_message
    FROM   por_req_import_errors e
    GROUP BY e.load_request_id, e.interface_id
) hdr_err ON  hdr_err.load_request_id = h.load_request_id
          AND hdr_err.interface_id     = h.req_header_interface_id
/* Source 2: errors joined on line numeric ID, rolled up to header */
LEFT OUTER JOIN (
    SELECT l.interface_header_key,
           l.load_request_id,
           LISTAGG(e.column_name || '=' || e.column_value || ': ' || e.text_line, ' | ')
               WITHIN GROUP (ORDER BY e.req_import_error_id) AS error_message
    FROM   por_req_lines_interface_all l
    JOIN   por_req_import_errors e
           ON  e.load_request_id = l.load_request_id
           AND e.interface_id    = l.req_line_interface_id
    GROUP BY l.interface_header_key, l.load_request_id
) line_tbl_err ON  line_tbl_err.load_request_id     = h.load_request_id
               AND line_tbl_err.interface_header_key = h.interface_header_key
/* Source 3: errors joined on dist numeric ID, rolled up to header via line */
LEFT OUTER JOIN (
    SELECT l.interface_header_key,
           d.load_request_id,
           LISTAGG(e.column_name || '=' || e.column_value || ': ' || e.text_line, ' | ')
               WITHIN GROUP (ORDER BY e.req_import_error_id) AS error_message
    FROM   por_req_dists_interface_all d
    JOIN   por_req_lines_interface_all l
           ON  l.req_line_interface_id = d.req_line_interface_id
           AND l.load_request_id       = d.load_request_id
    JOIN   por_req_import_errors e
           ON  e.load_request_id = d.load_request_id
           AND e.interface_id    = d.req_dist_interface_id
    GROUP BY l.interface_header_key, d.load_request_id
) dist_err ON  dist_err.load_request_id     = h.load_request_id
           AND dist_err.interface_header_key = h.interface_header_key

WHERE  h.load_request_id = :P_BATCH_ID

UNION ALL

SELECT
    CAST(NULL AS VARCHAR2(50))          AS interface_header_key,
    rh.requisition_number,
    'BASE'                              AS source_type,
    'SUCCESS'                           AS process_code,
    rh.requisition_header_id            AS fusion_id,
    CAST(NULL AS VARCHAR2(4000))        AS error_message
FROM   por_requisition_headers_all rh
WHERE  rh.request_id = :P_IMPORT_ESS_ID
AND    :P_IMPORT_ESS_ID IS NOT NULL
;
