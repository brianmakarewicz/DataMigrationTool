-- Repo mirror of the SQL embedded in DMT_PO_RECON_V2_DM.xdm (the .xdm is authoritative;
-- scripts/check_bip_recon_reports.py rule BIP-MIRROR keeps the two equal).
-- ============================================================
-- PurchaseOrders BIP reconciliation query -- BIP reconciliation
-- report contract v1 (nine columns, keyset pagination), V2.
-- Data source: ApplicationDB_FSCM. The repo mirror of this SQL is
-- bip/PurchaseOrders/query.sql.
-- V2 (2026-10-07) is deployed ALONGSIDE DMT_PO_RECON_DM (V1);
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
-- Row selection (owner decision 2026-10-07, backlog #264): rows
-- are FOUND only by the Fusion job ids of ONE work item (one
-- procurement-BU cycle = one load = one Import Orders run), and by
-- the document style, because PurchaseOrders, BlanketPOs and
-- Contracts share the PO interface and base tables.
--   BASE headers, lines, schedules: REQUEST_ID = :P_IMPORT_ESS_ID
--     (Import Orders stamps its own request id on PO_HEADERS_ALL,
--     PO_LINES_ALL and PO_LINE_LOCATIONS_ALL), header
--     TYPE_LOOKUP_CODE = 'STANDARD'.
--   BASE distributions: through their loaded schedule (the
--     schedule's REQUEST_ID = :P_IMPORT_ESS_ID); PO_DISTRIBUTIONS_ALL
--     does not stamp REQUEST_ID on this pod.
--   INTERFACE headers: LOAD_REQUEST_ID = :P_LOAD_REQUEST_ID AND
--     REQUEST_ID = :P_IMPORT_ESS_ID AND DOCUMENT_TYPE_CODE =
--     'STANDARD'.
--   INTERFACE lines, schedules, distributions: LOAD_REQUEST_ID =
--     :P_LOAD_REQUEST_ID, under a header selected as above, joined on
--     the Fusion interface ids (INTERFACE_HEADER_ID / LINE_ID /
--     LINE_LOCATION_ID). Fusion leaves REQUEST_ID NULL on the child
--     interface rows, so the import job is applied through the header.
--   PO_INTERFACE_ERRORS: REQUEST_ID = :P_IMPORT_ESS_ID, joined per
--     tier on the numeric interface id.
-- The run prefix and run id are never used to select rows (no LIKE
-- anywhere). P_RUN_ID and P_PREFIX are declared for contract
-- symmetry only. The document number and line, schedule and
-- distribution numbers are used only as RECORD_KEY, to match a row
-- Fusion returned back to its TFM row.
--
-- INTERFACE tiers return rejections only (PROCESS_CODE <>
-- 'ACCEPTED'); accepted rows are covered by the BASE tiers, so
-- nothing is counted twice.
--
-- RECORD_KEY (= each tier's TFM RECON_KEY, stamped by
-- DMT_PO_TRANSFORM_PKG; BASE and INTERFACE emit the same key):
--   header    prefixed DOCUMENT_NUM (= base SEGMENT1)
--   line      DOCUMENT_NUM || ':LN:' || LINE_NUM
--   schedule  ... || ':LOC:' || SHIPMENT_NUM
--   dist      ... || ':DIST:' || DISTRIBUTION_NUM
-- Keyset: ORDER BY RECORD_KEY (pinned to BINARY so the ordering
-- and the > comparison agree), only rows whose RECORD_KEY sorts
-- after :P_AFTER_KEY, at most :P_CHUNK_SIZE per page.
--
-- FUSION_STATUS normalized SUCCESS/ERROR in the DM:
--   BASE (present in base table) => SUCCESS; INTERFACE (rejection) => ERROR.
-- FUSION_ID non-null on every BASE row; ERROR_MESSAGE is the real
-- Fusion text from PO_INTERFACE_ERRORS for that tier's own row, or
-- NULL (the reconciler leaves such a row for the cross-grain
-- propagation or the UNACCOUNTED sweep).
-- ============================================================
SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    -- BASE / headers -- found by the import job's REQUEST_ID, Standard style.
    SELECT
        'PurchaseOrders'                     AS object_type,
        h.segment1                           AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        h.po_header_id                       AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        h.request_id                         AS load_request_id,
        h.segment1                           AS source_ref,
        h.interface_source_code              AS dmt_reference
    FROM   po_headers_all h
    WHERE  h.request_id       = TO_NUMBER(:P_IMPORT_ESS_ID)
    AND    h.type_lookup_code = 'STANDARD'

    UNION ALL

    -- BASE / lines -- found by the import job's REQUEST_ID, Standard style.
    SELECT
        'PurchaseOrders.Line'                AS object_type,
        h.segment1 || ':LN:' || l.line_num   AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        l.po_line_id                         AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        l.request_id                         AS load_request_id,
        h.segment1                           AS source_ref,
        h.interface_source_code              AS dmt_reference
    FROM   po_lines_all l
    JOIN   po_headers_all h ON h.po_header_id = l.po_header_id
    WHERE  l.request_id       = TO_NUMBER(:P_IMPORT_ESS_ID)
    AND    h.type_lookup_code = 'STANDARD'

    UNION ALL

    -- BASE / schedules (line locations) -- found by the import job's
    -- REQUEST_ID, Standard style.
    SELECT
        'PurchaseOrders.LineLocation'        AS object_type,
        h.segment1 || ':LN:' || l.line_num || ':LOC:' || ll.shipment_num  AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        ll.line_location_id                  AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        ll.request_id                        AS load_request_id,
        h.segment1                           AS source_ref,
        h.interface_source_code              AS dmt_reference
    FROM   po_line_locations_all ll
    JOIN   po_lines_all   l ON l.po_line_id   = ll.po_line_id
    JOIN   po_headers_all h ON h.po_header_id = ll.po_header_id
    WHERE  ll.request_id      = TO_NUMBER(:P_IMPORT_ESS_ID)
    AND    h.type_lookup_code = 'STANDARD'

    UNION ALL

    -- BASE / distributions -- through their loaded schedule (the
    -- schedule's REQUEST_ID = the import job), Standard style.
    SELECT
        'PurchaseOrders.Distribution'        AS object_type,
        h.segment1 || ':LN:' || l.line_num || ':LOC:' || ll.shipment_num
                     || ':DIST:' || d.distribution_num  AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        d.po_distribution_id                 AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        ll.request_id                        AS load_request_id,
        h.segment1                           AS source_ref,
        h.interface_source_code              AS dmt_reference
    FROM   po_distributions_all d
    JOIN   po_line_locations_all ll ON ll.line_location_id = d.line_location_id
    JOIN   po_lines_all   l ON l.po_line_id   = d.po_line_id
    JOIN   po_headers_all h ON h.po_header_id = d.po_header_id
    WHERE  ll.request_id      = TO_NUMBER(:P_IMPORT_ESS_ID)
    AND    h.type_lookup_code = 'STANDARD'

    UNION ALL

    -- INTERFACE / headers -- found by the load and import job ids,
    -- Standard style. Error = PO_INTERFACE_ERRORS rows of the import
    -- job on this header that carry no deeper interface id.
    SELECT
        'PurchaseOrders'                     AS object_type,
        h.document_num                       AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        CASE WHEN he.error_message IS NOT NULL
             THEN '[HDR] ' || he.error_message END
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
        WHERE  e.request_id = TO_NUMBER(:P_IMPORT_ESS_ID)
        AND    e.interface_header_id IS NOT NULL
        AND    e.interface_line_id   IS NULL
        AND    e.interface_line_location_id IS NULL
        AND    e.interface_distribution_id  IS NULL
        GROUP BY e.interface_header_id
    ) he ON he.interface_header_id = h.interface_header_id
    WHERE  h.load_request_id    = TO_NUMBER(:P_LOAD_REQUEST_ID)
    AND    h.request_id         = TO_NUMBER(:P_IMPORT_ESS_ID)
    AND    h.document_type_code = 'STANDARD'
    AND    NVL(h.process_code,'X') <> 'ACCEPTED'

    UNION ALL

    -- INTERFACE / lines -- found by the load job id, under a header of
    -- this load and import (Standard style), joined on the Fusion
    -- interface header id. Error = PO_INTERFACE_ERRORS of the import
    -- job at the line level.
    SELECT
        'PurchaseOrders.Line'                AS object_type,
        lh.document_num || ':LN:' || l.line_num  AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        CASE WHEN le.error_message IS NOT NULL
             THEN '[LINE] ' || le.error_message END
                                             AS error_message,
        l.load_request_id                    AS load_request_id,
        l.interface_line_key                 AS source_ref,
        CAST(NULL AS VARCHAR2(240))          AS dmt_reference
    FROM   po_lines_interface l
    JOIN   po_headers_interface lh
           ON lh.interface_header_id = l.interface_header_id
    LEFT   JOIN (
        SELECT e.interface_line_id,
               NULLIF(LISTAGG(
                   e.column_name || ': ' || e.error_message,
                   ' | ') WITHIN GROUP (ORDER BY e.interface_transaction_id), '') AS error_message
        FROM   po_interface_errors e
        WHERE  e.request_id = TO_NUMBER(:P_IMPORT_ESS_ID)
        AND    e.interface_line_id IS NOT NULL
        AND    e.interface_line_location_id IS NULL
        AND    e.interface_distribution_id  IS NULL
        GROUP BY e.interface_line_id
    ) le ON le.interface_line_id = l.interface_line_id
    WHERE  l.load_request_id     = TO_NUMBER(:P_LOAD_REQUEST_ID)
    AND    lh.load_request_id    = TO_NUMBER(:P_LOAD_REQUEST_ID)
    AND    lh.request_id         = TO_NUMBER(:P_IMPORT_ESS_ID)
    AND    lh.document_type_code = 'STANDARD'
    AND    NVL(l.process_code,'X') <> 'ACCEPTED'

    UNION ALL

    -- INTERFACE / schedules -- found by the load job id, under a header
    -- of this load and import (Standard style), joined on the Fusion
    -- interface ids. Error = PO_INTERFACE_ERRORS of the import job at
    -- the schedule level.
    SELECT
        'PurchaseOrders.LineLocation'        AS object_type,
        llh.document_num || ':LN:' || lll.line_num
            || ':LOC:' || ll.shipment_num    AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        CASE WHEN loce.error_message IS NOT NULL
             THEN '[LLOC] ' || loce.error_message END
                                             AS error_message,
        ll.load_request_id                   AS load_request_id,
        ll.interface_line_location_key       AS source_ref,
        CAST(NULL AS VARCHAR2(240))          AS dmt_reference
    FROM   po_line_locations_interface ll
    JOIN   po_lines_interface   lll ON lll.interface_line_id   = ll.interface_line_id
    JOIN   po_headers_interface llh ON llh.interface_header_id = lll.interface_header_id
    LEFT   JOIN (
        SELECT e.interface_line_location_id,
               NULLIF(LISTAGG(
                   e.column_name || ': ' || e.error_message,
                   ' | ') WITHIN GROUP (ORDER BY e.interface_transaction_id), '') AS error_message
        FROM   po_interface_errors e
        WHERE  e.request_id = TO_NUMBER(:P_IMPORT_ESS_ID)
        AND    e.interface_line_location_id IS NOT NULL
        AND    e.interface_distribution_id  IS NULL
        GROUP BY e.interface_line_location_id
    ) loce ON loce.interface_line_location_id = ll.interface_line_location_id
    WHERE  ll.load_request_id     = TO_NUMBER(:P_LOAD_REQUEST_ID)
    AND    llh.load_request_id    = TO_NUMBER(:P_LOAD_REQUEST_ID)
    AND    llh.request_id         = TO_NUMBER(:P_IMPORT_ESS_ID)
    AND    llh.document_type_code = 'STANDARD'
    AND    NVL(ll.process_code,'X') <> 'ACCEPTED'

    UNION ALL

    -- INTERFACE / distributions -- found by the load job id, under a
    -- header of this load and import (Standard style), joined on the
    -- Fusion interface ids. Error = PO_INTERFACE_ERRORS of the import
    -- job at the distribution level.
    SELECT
        'PurchaseOrders.Distribution'        AS object_type,
        dh.document_num || ':LN:' || dl.line_num
            || ':LOC:' || dll.shipment_num
            || ':DIST:' || d.distribution_num  AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        CASE WHEN de.error_message IS NOT NULL
             THEN '[DIST] ' || de.error_message END
                                             AS error_message,
        d.load_request_id                    AS load_request_id,
        d.interface_distribution_key         AS source_ref,
        CAST(NULL AS VARCHAR2(240))          AS dmt_reference
    FROM   po_distributions_interface d
    JOIN   po_line_locations_interface dll ON dll.interface_line_location_id = d.interface_line_location_id
    JOIN   po_lines_interface          dl  ON dl.interface_line_id           = dll.interface_line_id
    JOIN   po_headers_interface        dh  ON dh.interface_header_id         = dl.interface_header_id
    LEFT   JOIN (
        SELECT e.interface_distribution_id,
               NULLIF(LISTAGG(
                   e.column_name || ': ' || e.error_message,
                   ' | ') WITHIN GROUP (ORDER BY e.interface_transaction_id), '') AS error_message
        FROM   po_interface_errors e
        WHERE  e.request_id = TO_NUMBER(:P_IMPORT_ESS_ID)
        AND    e.interface_distribution_id IS NOT NULL
        GROUP BY e.interface_distribution_id
    ) de ON de.interface_distribution_id = d.interface_distribution_id
    WHERE  d.load_request_id     = TO_NUMBER(:P_LOAD_REQUEST_ID)
    AND    dh.load_request_id    = TO_NUMBER(:P_LOAD_REQUEST_ID)
    AND    dh.request_id         = TO_NUMBER(:P_IMPORT_ESS_ID)
    AND    dh.document_type_code = 'STANDARD'
    AND    NVL(d.process_code,'X') <> 'ACCEPTED'
)
-- Keyset predicate. An empty P_AFTER_KEY (first page) binds to NULL
-- in BIP, so NULL means "from the start". The ordering and the
-- comparison are both pinned to BINARY so they agree.
WHERE  (:P_AFTER_KEY IS NULL
        OR NLSSORT(record_key, 'NLS_SORT=BINARY') > NLSSORT(:P_AFTER_KEY, 'NLS_SORT=BINARY'))
ORDER BY NLSSORT(record_key, 'NLS_SORT=BINARY')
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
