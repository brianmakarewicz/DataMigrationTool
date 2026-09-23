-- ============================================================
-- APInvoices reconciliation data model -- BIP reconciliation
-- report contract v1 (nine columns, keyset pagination, the six
-- standard parameters). Same shape as DMT_REQ_RECON_DM.xdm and
-- DMT_GL_BAL_RECON_DM.xdm.
--
-- NINE response columns, in contract order:
--   OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE, FUSION_STATUS,
--   FUSION_ID, ERROR_MESSAGE, LOAD_REQUEST_ID, SOURCE_REF,
--   DMT_REFERENCE.
--
-- SIX parameters (Contract v1): P_RUN_ID, P_LOAD_REQUEST_ID,
--   P_IMPORT_ESS_ID, P_PREFIX, P_CHUNK_SIZE, P_AFTER_KEY.
--   No P_OFFSET / P_LIMIT.
--
-- KEYSET pagination: rows are ordered by RECORD_KEY and only rows
-- whose RECORD_KEY sorts AFTER :P_AFTER_KEY are returned, at most
-- :P_CHUNK_SIZE of them. The reconciler's shared fetch loop calls
-- with an empty cursor first, then passes the last RECORD_KEY it
-- received on each next call, until a page returns fewer than
-- P_CHUNK_SIZE rows. An empty :P_AFTER_KEY selects from the start
-- (every non-null RECORD_KEY sorts after the empty string).
--
-- MULTI-TIER object. APInvoices is one FBDI zip carrying two
-- record types -- headers and lines. Each has its own interface
-- table and its own base table. OBJECT_TYPE discriminates the tier
-- and the four SELECT blocks (headers/lines x BASE/INTERFACE) are
-- UNION ALL-ed, then ordered by RECORD_KEY.
--
-- READ-BACK KEYS (confirmed live against ap_invoices_all /
-- ap_invoice_lines_all on the demo instance, 2026-09-20):
--   Header business key  = AP_INVOICES_ALL.INVOICE_NUM (run-prefixed).
--       No interface key survives on the base header (AP has no
--       stamped interface_key column that persists to base), so the
--       prefixed invoice number is the read-back key -- exactly the
--       key DMT_AP_RESULTS_PKG.PARSE_AND_UPDATE matches on. This
--       mirrors the Requisitions BASE header tier.
--   Line business key    = INVOICE_NUM || ':LINE:' || LINE_NUMBER.
--       AP_INVOICE_LINES_ALL carries no independent line surrogate
--       id -- a base line is identified by (INVOICE_ID, LINE_NUMBER)
--       -- so the deterministic, parent-traceable RECORD_KEY is the
--       parent's prefixed invoice number plus the base line number.
--
-- Row selection (grounded in live schema, 2026-09-20):
--   BASE  header rows: AP_INVOICES_ALL where INVOICE_NUM LIKE
--         :P_PREFIX || '%' (prefixed number = TFM business key).
--   BASE  line rows:   AP_INVOICE_LINES_ALL joined to the base
--         header by INVOICE_ID; selected through the parent's
--         prefixed invoice number (the base line carries no key of
--         its own, so it is confirmed transitively through its
--         loaded parent header -- same pattern as Requisitions base
--         distributions).
--   INTERFACE rows: the rejections that did NOT import. The AP
--         interface tables persist ALL rows -- both PROCESSED and
--         REJECTED -- so the SUCCESS rows are handled only by the
--         BASE tiers and the INTERFACE tiers return rejections only:
--         no row is counted twice. A HEADER is a rejection when its
--         AP_INVOICES_INTERFACE.STATUS <> 'PROCESSED'. A LINE has no
--         status column of its own, so a LINE is a rejection when a
--         real rejection row exists for its INVOICE_LINE_ID in
--         AP_INTERFACE_REJECTIONS. Interface rows are selected by
--         their LOAD_REQUEST_ID = :P_LOAD_REQUEST_ID (the load ESS
--         request id, reliably stamped on every interface row) OR,
--         as a run-scoped fallback, their prefixed INVOICE_NUM (the
--         line interface has no invoice_num, so it is joined back to
--         its interface header on the interface-local INVOICE_ID).
--   :P_RUN_ID / :P_IMPORT_ESS_ID are declared for contract symmetry;
--   :P_IMPORT_ESS_ID is stamped into LOAD_REQUEST_ID on BASE rows
--   for traceability (the base tables retain no load id of their own).
--
-- FUSION_STATUS is normalized in this DM to exactly SUCCESS/ERROR:
--   BASE  (row present in a Fusion base table)  => SUCCESS
--   INTERFACE (rejection left in the interface) => ERROR
-- FUSION_ID is non-null on every BASE row (the Fusion surrogate id:
--   base INVOICE_ID for both header and line tiers -- the line has
--   no id of its own, so its parent invoice id is reported).
-- ERROR_MESSAGE is non-null on every ERROR row. On this instance the
--   Fusion rejection text lives in AP_INTERFACE_REJECTIONS.
--   REJECT_LOOKUP_CODE (e.g. 'DUPLICATE INVOICE NUMBER',
--   'INVALID TERMS', 'ACCT DATE NOT IN OPEN PD'); REJECTION_MESSAGE
--   is null for every rejection here, so the real code is the error
--   text -- surfaced via NVL(rejection_message, reject_lookup_code),
--   the same convention as the deployed AP_DM.xdm.
--
-- SOURCE_REF / DMT_REFERENCE honesty note: the contract asks for
--   SOURCE_REF = REFERENCE_KEY1 (native read-back) and DMT_REFERENCE
--   = the DFF attribute that lands in base. On this demo instance,
--   the AP loads leave REFERENCE_KEY1, ATTRIBUTE1 and
--   ATTRIBUTE_CATEGORY EMPTY on ap_invoices_all (verified against the
--   13 most recent DMT-loaded invoices). Those columns are selected
--   verbatim so that when a future load DOES populate them the report
--   carries them through unchanged -- but they will render empty for
--   the currently loaded data. This is reported, not fabricated.
-- ============================================================
SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    -- ========== BASE tier: positive proof from Fusion base tables ==========

    -- BASE / headers. RECORD_KEY = prefixed invoice number (the base
    -- header persists no interface key, so the prefixed number is the
    -- read-back key = the TFM business key the reconciler matches on).
    SELECT
        'APInvoices'                         AS object_type,
        h.invoice_num                        AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        h.invoice_id                         AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        TO_NUMBER(:P_IMPORT_ESS_ID)          AS load_request_id,
        h.reference_key1                     AS source_ref,
        h.attribute1                         AS dmt_reference
    FROM   ap_invoices_all h
    WHERE  h.invoice_num LIKE :P_PREFIX || '%'

    UNION ALL

    -- BASE / lines. RECORD_KEY = prefixed invoice number + base line
    -- number. The base line carries no id of its own, so it is
    -- confirmed transitively through its loaded parent header and
    -- FUSION_ID reports the parent base invoice id.
    SELECT
        'APInvoices.Line'                    AS object_type,
        h.invoice_num || ':LINE:' || l.line_number  AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        l.invoice_id                         AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        TO_NUMBER(:P_IMPORT_ESS_ID)          AS load_request_id,
        h.reference_key1                     AS source_ref,
        l.attribute1                         AS dmt_reference
    FROM   ap_invoice_lines_all l
    JOIN   ap_invoices_all h
           ON h.invoice_id = l.invoice_id
    WHERE  h.invoice_num LIKE :P_PREFIX || '%'

    UNION ALL

    -- ========== INTERFACE tier: rejections only (STATUS <> PROCESSED) ==========

    -- INTERFACE / headers. RECORD_KEY = prefixed interface invoice
    -- number (the same business key the base header would carry, so a
    -- rejected header sorts alongside its would-be base row). Error
    -- text is the real Fusion rejection(s) for this interface header,
    -- from AP_INTERFACE_REJECTIONS (parent_table = AP_INVOICES_INTERFACE).
    SELECT
        'APInvoices'                         AS object_type,
        h.invoice_num                        AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        '[HDR] ' || NVL(
            (SELECT LISTAGG(NVL(r.rejection_message, r.reject_lookup_code), ' | ')
                    WITHIN GROUP (ORDER BY r.reject_lookup_code)
             FROM   ap_interface_rejections r
             WHERE  r.parent_id    = h.invoice_id
             AND    r.parent_table = 'AP_INVOICES_INTERFACE'),
            'Rejected by Payables Import (status=' || NVL(h.status,'NULL')
            || '; no rejection row written -- e.g. header rejected pre-validation).')
                                             AS error_message,
        h.load_request_id                    AS load_request_id,
        h.invoice_num                        AS source_ref,
        h.attribute1                         AS dmt_reference
    FROM   ap_invoices_interface h
    WHERE  NVL(h.status,'X') <> 'PROCESSED'
    AND    (  h.load_request_id = TO_NUMBER(:P_LOAD_REQUEST_ID)
           OR h.invoice_num LIKE :P_PREFIX || '%' )

    UNION ALL

    -- INTERFACE / lines. RECORD_KEY = prefixed invoice number +
    -- interface line number. AP_INVOICE_LINES_INTERFACE has NO status
    -- column of its own and NO invoice_num column, so (a) the invoice
    -- number is obtained by joining back to the interface header on the
    -- interface-local INVOICE_ID, and (b) a line is treated as a
    -- rejection when a real rejection row exists for it in
    -- AP_INTERFACE_REJECTIONS (parent_table = AP_INVOICE_LINES_INTERFACE,
    -- parent_id = the interface line's INVOICE_LINE_ID). That guarantees
    -- ERROR_MESSAGE is a real Fusion reason for every row this tier
    -- returns, and it never double-counts a successfully imported line.
    SELECT
        'APInvoices.Line'                    AS object_type,
        h.invoice_num || ':LINE:' || l.line_number  AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        '[LINE] ' ||
            (SELECT LISTAGG(NVL(r.rejection_message, r.reject_lookup_code), ' | ')
                    WITHIN GROUP (ORDER BY r.reject_lookup_code)
             FROM   ap_interface_rejections r
             WHERE  r.parent_id    = l.invoice_line_id
             AND    r.parent_table = 'AP_INVOICE_LINES_INTERFACE')
                                             AS error_message,
        l.load_request_id                    AS load_request_id,
        h.invoice_num                        AS source_ref,
        l.attribute1                         AS dmt_reference
    FROM   ap_invoice_lines_interface l
    JOIN   ap_invoices_interface h
           ON h.invoice_id = l.invoice_id
    WHERE  EXISTS (
               SELECT 1 FROM ap_interface_rejections r
               WHERE  r.parent_id    = l.invoice_line_id
               AND    r.parent_table = 'AP_INVOICE_LINES_INTERFACE' )
    AND    (  l.load_request_id = TO_NUMBER(:P_LOAD_REQUEST_ID)
           OR h.invoice_num LIKE :P_PREFIX || '%' )

    UNION ALL

    -- INTERFACE / lines -- PARENT-HEADER-INHERITED rejections. When an
    -- invoice header is rejected (e.g. INVALID SUPPLIER), Payables writes
    -- the rejection at the HEADER level (parent_table = AP_INVOICES_INTERFACE,
    -- parent_id = INVOICE_ID) and never imports the header, so NO base line
    -- and often NO per-line rejection row is ever written. Its lines would
    -- otherwise match no tier and come back UNACCOUNTED. This tier emits an
    -- ERROR row for each such line, carrying the REAL header rejection reason
    -- (clearly marked as inherited), so every line is honestly accounted.
    -- Guards against double-counting:
    --   (a) the line's parent interface header must itself be a rejection
    --       (STATUS <> PROCESSED, or a header-level rejection row exists);
    --   (b) NO per-line rejection row exists for this line (tier above owns
    --       those -- avoids emitting the same line twice);
    --   (c) NO base line exists for this invoice_num + line_number (a line
    --       that did land is LOADED from the BASE tier only, never ERROR here).
    SELECT
        'APInvoices.Line'                    AS object_type,
        h.invoice_num || ':LINE:' || l.line_number  AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        '[LINE] Parent invoice rejected: ' || NVL(
            (SELECT LISTAGG(NVL(r.rejection_message, r.reject_lookup_code), ' | ')
                    WITHIN GROUP (ORDER BY r.reject_lookup_code)
             FROM   ap_interface_rejections r
             WHERE  r.parent_id    = h.invoice_id
             AND    r.parent_table = 'AP_INVOICES_INTERFACE'),
            'Rejected by Payables Import (status=' || NVL(h.status,'NULL')
            || '; no rejection row written -- e.g. header rejected pre-validation).')
                                             AS error_message,
        l.load_request_id                    AS load_request_id,
        h.invoice_num                        AS source_ref,
        l.attribute1                         AS dmt_reference
    FROM   ap_invoice_lines_interface l
    JOIN   ap_invoices_interface h
           ON h.invoice_id = l.invoice_id
    WHERE  ( NVL(h.status,'X') <> 'PROCESSED'
             OR EXISTS ( SELECT 1 FROM ap_interface_rejections rh
                         WHERE  rh.parent_id    = h.invoice_id
                         AND    rh.parent_table = 'AP_INVOICES_INTERFACE' ) )
    AND    NOT EXISTS (
               SELECT 1 FROM ap_interface_rejections r
               WHERE  r.parent_id    = l.invoice_line_id
               AND    r.parent_table = 'AP_INVOICE_LINES_INTERFACE' )
    AND    NOT EXISTS (
               SELECT 1
               FROM   ap_invoice_lines_all bl
               JOIN   ap_invoices_all      bh ON bh.invoice_id = bl.invoice_id
               WHERE  bh.invoice_num = h.invoice_num
               AND    bl.line_number = l.line_number )
    AND    (  l.load_request_id = TO_NUMBER(:P_LOAD_REQUEST_ID)
           OR h.invoice_num LIKE :P_PREFIX || '%' )
)
-- Keyset predicate. An empty P_AFTER_KEY (first page) binds to NULL in
-- BIP, so treat NULL as "from the start": return every row. On later
-- pages P_AFTER_KEY carries the previous page's last RECORD_KEY and only
-- greater keys are returned. RECORD_KEY is compared as text (the recon
-- key is a string); the reconciler feeds back the exact key it received.
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
      
