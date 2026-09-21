-- ============================================================
-- Requisitions BIP reconciliation query -- BIP reconciliation
-- report contract v1 (nine columns, keyset pagination).
-- Data source: ApplicationDB_FSCM. This mirrors the SQL embedded
-- in DMT_REQ_RECON_DM.xdm for review; the .xdm is authoritative.
--
-- NINE columns, in contract order:
--   OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE, FUSION_STATUS,
--   FUSION_ID, ERROR_MESSAGE, LOAD_REQUEST_ID, SOURCE_REF,
--   DMT_REFERENCE
--
-- SIX parameters: P_RUN_ID, P_LOAD_REQUEST_ID, P_IMPORT_ESS_ID,
--   P_PREFIX, P_CHUNK_SIZE, P_AFTER_KEY. No P_OFFSET / P_LIMIT.
--
-- Keyset: ORDER BY RECORD_KEY, only rows whose RECORD_KEY sorts
-- after :P_AFTER_KEY, at most :P_CHUNK_SIZE per page.
--
-- MULTI-TIER (headers / lines / distributions). OBJECT_TYPE
-- discriminates the tier; six blocks UNION ALL-ed then ordered by
-- RECORD_KEY. Stamped recon keys read back from Fusion:
--   header  <run_id>_RQHDR_<seq>   base header keyed on prefixed REQUISITION_NUMBER
--   line    <run_id>_RQLN_<seq>    persisted on base line as INTERFACE_LINE_KEY
--   dist    <run_id>_RQDIST_<seq>  interface only; base dist confirmed via parent line
--
-- Row selection: run-scoped by the stamped key prefix (:P_RUN_ID)
-- and the number prefix (:P_PREFIX), both shared by every batch of
-- the run -- Requisitions submits one load per work-queue batch, so
-- :P_LOAD_REQUEST_ID / :P_IMPORT_ESS_ID alone cannot select a whole
-- multi-batch run. INTERFACE tiers return rejections only
-- (PROCESS_FLAG <> 'SUCCESS'); SUCCESS rows are covered by the BASE
-- tiers, so nothing is counted twice.
--
-- FUSION_STATUS normalized SUCCESS/ERROR in the DM:
--   BASE (present in base table) => SUCCESS; INTERFACE (rejection) => ERROR.
-- FUSION_ID non-null on every BASE row; ERROR_MESSAGE non-null on every
-- ERROR row (real Fusion text from POR_REQ_IMPORT_ERRORS, joined per
-- tier on INTERFACE_TYPE + INTERFACE_KEY = the row's own stamped key).
-- ============================================================
SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    -- BASE / headers -- RECORD_KEY = prefixed requisition number
    SELECT
        'Requisitions'                       AS object_type,
        rh.requisition_number                AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        rh.requisition_header_id             AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        TO_NUMBER(:P_IMPORT_ESS_ID)          AS load_request_id,
        rh.interface_source_code             AS source_ref,
        rh.attribute1                        AS dmt_reference
    FROM   por_requisition_headers_all rh
    WHERE  rh.requisition_number LIKE :P_PREFIX || '%'

    UNION ALL

    -- BASE / lines -- RECORD_KEY = stamped line key persisted on base line
    SELECT
        'Requisitions.Line'                  AS object_type,
        rl.interface_line_key                AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        rl.requisition_line_id               AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        TO_NUMBER(:P_IMPORT_ESS_ID)          AS load_request_id,
        rl.interface_line_key                AS source_ref,
        rh.attribute1                        AS dmt_reference
    FROM   por_requisition_lines_all rl
    JOIN   por_requisition_headers_all rh
           ON rh.requisition_header_id = rl.requisition_header_id
    WHERE  rl.interface_line_key LIKE :P_RUN_ID || '\_RQLN\_%' ESCAPE '\'

    UNION ALL

    -- BASE / distributions -- confirmed via loaded parent line;
    -- RECORD_KEY derived from parent stamped line key + dist number
    SELECT
        'Requisitions.Distribution'          AS object_type,
        rl.interface_line_key || ':DIST:' || rd.distribution_number  AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        rd.distribution_id                   AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        TO_NUMBER(:P_IMPORT_ESS_ID)          AS load_request_id,
        rl.interface_line_key                AS source_ref,
        rh.attribute1                        AS dmt_reference
    FROM   por_req_distributions_all rd
    JOIN   por_requisition_lines_all rl
           ON rl.requisition_line_id = rd.requisition_line_id
    JOIN   por_requisition_headers_all rh
           ON rh.requisition_header_id = rl.requisition_header_id
    WHERE  rl.interface_line_key LIKE :P_RUN_ID || '\_RQLN\_%' ESCAPE '\'

    UNION ALL

    -- INTERFACE / headers -- rejections only
    SELECT
        'Requisitions'                       AS object_type,
        h.requisition_number                 AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        '[HDR] ' || NVL(he.error_message,
             'Rejected by Requisition Import (process_flag=' || NVL(h.process_flag,'NULL')
             || '; no error row written -- e.g. header rejected pre-validation).')
                                             AS error_message,
        h.load_request_id                    AS load_request_id,
        h.interface_header_key               AS source_ref,
        h.attribute1                         AS dmt_reference
    FROM   por_req_headers_interface_all h
    LEFT   JOIN (
        SELECT e.interface_key,
               -- Skip fully-blank error rows and collapse an all-blank
               -- aggregation to NULL so the NVL fallback fires.
               NULLIF(LISTAGG(
                   CASE WHEN e.column_name IS NULL AND e.column_value IS NULL AND e.text_line IS NULL
                        THEN NULL
                        ELSE e.column_name || '=' || e.column_value || ': ' || e.text_line END,
                   ' | ') WITHIN GROUP (ORDER BY e.req_import_error_id), '') AS error_message
        FROM   por_req_import_errors e
        WHERE  e.interface_type = 'HEADER'
        GROUP BY e.interface_key
    ) he ON he.interface_key = h.interface_header_key
    WHERE  h.interface_header_key LIKE :P_RUN_ID || '\_RQHDR\_%' ESCAPE '\'
    AND    NVL(h.process_flag,'X') <> 'SUCCESS'

    UNION ALL

    -- INTERFACE / lines -- rejections only
    SELECT
        'Requisitions.Line'                  AS object_type,
        l.interface_line_key                 AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        '[LINE] ' || NVL(le.error_message,
             'Rejected by Requisition Import (process_flag=' || NVL(l.process_flag,'NULL')
             || '; line not created in base table).')
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
        WHERE  e.interface_type = 'LINE'
        GROUP BY e.interface_key
    ) le ON le.interface_key = l.interface_line_key
    WHERE  l.interface_line_key LIKE :P_RUN_ID || '\_RQLN\_%' ESCAPE '\'
    AND    NVL(l.process_flag,'X') <> 'SUCCESS'

    UNION ALL

    -- INTERFACE / distributions -- rejections only
    SELECT
        'Requisitions.Distribution'          AS object_type,
        d.interface_line_key || ':DIST:' || d.distribution_number  AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        '[DIST] ' || NVL(de.error_message,
             'Rejected by Requisition Import (process_flag=' || NVL(d.process_flag,'NULL')
             || '; distribution not created in base table).')
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
        WHERE  e.interface_type = 'DISTRIBUTION'
        GROUP BY e.interface_key
    ) de ON de.interface_key = d.interface_distribution_key
    WHERE  d.interface_distribution_key LIKE :P_RUN_ID || '\_RQDIST\_%' ESCAPE '\'
    AND    NVL(d.process_flag,'X') <> 'SUCCESS'
)
-- Keyset predicate. An empty P_AFTER_KEY (first page) binds to NULL in
-- BIP, so treat NULL as "from the start". On later pages it carries the
-- previous page's last RECORD_KEY; only greater keys are returned.
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
