-- ============================================================
-- Requisitions BIP reconciliation query -- BIP reconciliation
-- report contract v1 (nine columns, keyset pagination), V2.
-- Data source: ApplicationDB_FSCM. This mirrors the SQL embedded
-- in DMT_REQ_RECON_V2_DM.xdm for review; the .xdm is authoritative.
-- V2 (2026-10-07) is deployed ALONGSIDE DMT_REQ_RECON_DM (V1);
-- BIP objects are never overwritten.
--
-- NINE columns, in contract order:
--   OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE, FUSION_STATUS,
--   FUSION_ID, ERROR_MESSAGE, LOAD_REQUEST_ID, SOURCE_REF,
--   DMT_REFERENCE
--
-- SIX parameters: P_RUN_ID, P_LOAD_REQUEST_ID, P_IMPORT_ESS_ID,
--   P_PREFIX, P_CHUNK_SIZE, P_AFTER_KEY. No P_OFFSET / P_LIMIT.
--
-- Row selection (owner decision 2026-10-07): rows are FOUND only
-- by the Fusion job ids of ONE work item (one batch = one load =
-- one Requisition Import). The reconciler calls this report once
-- per work item with that item's own ids.
--   BASE headers and lines: REQUEST_ID = :P_IMPORT_ESS_ID (Fusion
--     stamps the import job id on POR_REQUISITION_HEADERS_ALL and
--     POR_REQUISITION_LINES_ALL).
--   BASE distributions: through their loaded line (the line's
--     REQUEST_ID = :P_IMPORT_ESS_ID).
--   INTERFACE rows and POR_REQ_IMPORT_ERRORS: LOAD_REQUEST_ID =
--     :P_LOAD_REQUEST_ID AND REQUEST_ID = :P_IMPORT_ESS_ID.
-- The run prefix and run id are never used to select rows (no
-- LIKE anywhere). P_RUN_ID and P_PREFIX are declared for contract
-- symmetry only. The stamped keys (requisition number, interface
-- line key) are used only as RECORD_KEY, to match a row Fusion
-- returned back to its TFM row.
--
-- INTERFACE tiers return rejections only (PROCESS_FLAG <>
-- 'SUCCESS'); SUCCESS rows are covered by the BASE tiers, so
-- nothing is counted twice.
--
-- RECORD_KEY (unique per row within one work item):
--   header  prefixed REQUISITION_NUMBER (= header TFM RECON_KEY)
--   line    INTERFACE_LINE_KEY <run_id>_RQLN_<seq>
--   dist    INTERFACE_LINE_KEY || ':DIST:' || DISTRIBUTION_NUMBER
-- Keyset: ORDER BY RECORD_KEY (pinned to BINARY so the ordering
-- and the > comparison agree), only rows whose RECORD_KEY sorts
-- after :P_AFTER_KEY, at most :P_CHUNK_SIZE per page.
--
-- FUSION_STATUS normalized SUCCESS/ERROR in the DM:
--   BASE (present in base table) => SUCCESS; INTERFACE (rejection) => ERROR.
-- FUSION_ID non-null on every BASE row; ERROR_MESSAGE is the real
-- Fusion text from POR_REQ_IMPORT_ERRORS, joined per tier on
-- INTERFACE_TYPE + INTERFACE_KEY = the row's own stamped key, or
-- NULL (the reconciler leaves such a row for the cross-grain
-- propagation or the UNACCOUNTED sweep).
-- ============================================================
SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    -- BASE / headers -- found by the import job's REQUEST_ID
    SELECT
        'Requisitions'                       AS object_type,
        rh.requisition_number                AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        rh.requisition_header_id             AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        rh.request_id                        AS load_request_id,
        rh.interface_source_code             AS source_ref,
        rh.attribute1                        AS dmt_reference
    FROM   por_requisition_headers_all rh
    WHERE  rh.request_id = TO_NUMBER(:P_IMPORT_ESS_ID)

    UNION ALL

    -- BASE / lines -- found by the import job's REQUEST_ID
    SELECT
        'Requisitions.Line'                  AS object_type,
        rl.interface_line_key                AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        rl.requisition_line_id               AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        rl.request_id                        AS load_request_id,
        rl.interface_line_key                AS source_ref,
        rh.attribute1                        AS dmt_reference
    FROM   por_requisition_lines_all rl
    JOIN   por_requisition_headers_all rh
           ON rh.requisition_header_id = rl.requisition_header_id
    WHERE  rl.request_id = TO_NUMBER(:P_IMPORT_ESS_ID)

    UNION ALL

    -- BASE / distributions -- through their loaded line (the line's
    -- REQUEST_ID); RECORD_KEY = parent stamped line key + dist number
    SELECT
        'Requisitions.Distribution'          AS object_type,
        rl.interface_line_key || ':DIST:' || rd.distribution_number  AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        rd.distribution_id                   AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        rl.request_id                        AS load_request_id,
        rl.interface_line_key                AS source_ref,
        rh.attribute1                        AS dmt_reference
    FROM   por_req_distributions_all rd
    JOIN   por_requisition_lines_all rl
           ON rl.requisition_line_id = rd.requisition_line_id
    JOIN   por_requisition_headers_all rh
           ON rh.requisition_header_id = rl.requisition_header_id
    WHERE  rl.request_id = TO_NUMBER(:P_IMPORT_ESS_ID)

    UNION ALL

    -- INTERFACE / headers -- rejections of this load + import only
    SELECT
        'Requisitions'                       AS object_type,
        h.requisition_number                 AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        CASE WHEN he.error_message IS NOT NULL
             THEN '[HDR] ' || he.error_message END
                                             AS error_message,
        h.load_request_id                    AS load_request_id,
        h.interface_header_key               AS source_ref,
        h.attribute1                         AS dmt_reference
    FROM   por_req_headers_interface_all h
    LEFT   JOIN (
        SELECT e.interface_key,
               -- Skip fully-blank error rows and collapse an all-blank
               -- aggregation to NULL.
               NULLIF(LISTAGG(
                   CASE WHEN e.column_name IS NULL AND e.column_value IS NULL AND e.text_line IS NULL
                        THEN NULL
                        ELSE e.column_name || '=' || e.column_value || ': ' || e.text_line END,
                   ' | ') WITHIN GROUP (ORDER BY e.req_import_error_id), '') AS error_message
        FROM   por_req_import_errors e
        WHERE  e.interface_type  = 'HEADER'
        AND    e.load_request_id = TO_NUMBER(:P_LOAD_REQUEST_ID)
        AND    e.request_id      = TO_NUMBER(:P_IMPORT_ESS_ID)
        GROUP BY e.interface_key
    ) he ON he.interface_key = h.interface_header_key
    WHERE  h.load_request_id = TO_NUMBER(:P_LOAD_REQUEST_ID)
    AND    h.request_id      = TO_NUMBER(:P_IMPORT_ESS_ID)
    AND    NVL(h.process_flag,'X') <> 'SUCCESS'

    UNION ALL

    -- INTERFACE / lines -- rejections of this load + import only
    SELECT
        'Requisitions.Line'                  AS object_type,
        l.interface_line_key                 AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        CASE WHEN le.error_message IS NOT NULL
             THEN '[LINE] ' || le.error_message END
                                             AS error_message,
        l.load_request_id                    AS load_request_id,
        l.interface_line_key                 AS source_ref,
        l.attribute1                         AS dmt_reference
    FROM   por_req_lines_interface_all l
    LEFT   JOIN (
        SELECT e.interface_key,
               NULLIF(LISTAGG(
                   CASE WHEN e.column_name IS NULL AND e.column_value IS NULL AND e.text_line IS NULL
                        THEN NULL
                        ELSE e.column_name || '=' || e.column_value || ': ' || e.text_line END,
                   ' | ') WITHIN GROUP (ORDER BY e.req_import_error_id), '') AS error_message
        FROM   por_req_import_errors e
        WHERE  e.interface_type  = 'LINE'
        AND    e.load_request_id = TO_NUMBER(:P_LOAD_REQUEST_ID)
        AND    e.request_id      = TO_NUMBER(:P_IMPORT_ESS_ID)
        GROUP BY e.interface_key
    ) le ON le.interface_key = l.interface_line_key
    WHERE  l.load_request_id = TO_NUMBER(:P_LOAD_REQUEST_ID)
    AND    l.request_id      = TO_NUMBER(:P_IMPORT_ESS_ID)
    AND    NVL(l.process_flag,'X') <> 'SUCCESS'

    UNION ALL

    -- INTERFACE / distributions -- rejections of this load + import only
    SELECT
        'Requisitions.Distribution'          AS object_type,
        d.interface_line_key || ':DIST:' || d.distribution_number  AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        CASE WHEN de.error_message IS NOT NULL
             THEN '[DIST] ' || de.error_message END
                                             AS error_message,
        d.load_request_id                    AS load_request_id,
        d.interface_distribution_key         AS source_ref,
        d.attribute1                         AS dmt_reference
    FROM   por_req_dists_interface_all d
    LEFT   JOIN (
        SELECT e.interface_key,
               NULLIF(LISTAGG(
                   CASE WHEN e.column_name IS NULL AND e.column_value IS NULL AND e.text_line IS NULL
                        THEN NULL
                        ELSE e.column_name || '=' || e.column_value || ': ' || e.text_line END,
                   ' | ') WITHIN GROUP (ORDER BY e.req_import_error_id), '') AS error_message
        FROM   por_req_import_errors e
        WHERE  e.interface_type  = 'DISTRIBUTION'
        AND    e.load_request_id = TO_NUMBER(:P_LOAD_REQUEST_ID)
        AND    e.request_id      = TO_NUMBER(:P_IMPORT_ESS_ID)
        GROUP BY e.interface_key
    ) de ON de.interface_key = d.interface_distribution_key
    WHERE  d.load_request_id = TO_NUMBER(:P_LOAD_REQUEST_ID)
    AND    d.request_id      = TO_NUMBER(:P_IMPORT_ESS_ID)
    AND    NVL(d.process_flag,'X') <> 'SUCCESS'
)
-- Keyset predicate. An empty P_AFTER_KEY (first page) binds to NULL in
-- BIP, so treat NULL as "from the start". On later pages it carries the
-- previous page's last RECORD_KEY; only greater keys are returned. The
-- ordering and the comparison are both pinned to BINARY so they agree.
WHERE  (:P_AFTER_KEY IS NULL
        OR NLSSORT(record_key, 'NLS_SORT=BINARY') > NLSSORT(:P_AFTER_KEY, 'NLS_SORT=BINARY'))
ORDER BY NLSSORT(record_key, 'NLS_SORT=BINARY')
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
