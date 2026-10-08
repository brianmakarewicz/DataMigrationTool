-- bip/APInvoices/query.sql -- EXACT SQL text of the deployed data model
-- /Custom/DMT2/APInvoices/DMT_AP_RECON_V2_DM.xdm (the CDATA body of
-- bip/APInvoices/DMT_AP_RECON_V2_DM.xdm). Regenerate from the .xdm whenever
-- the data model changes; never edit separately.
-- ============================================================
-- DMT_AP_RECON_V2_DM (2026-10-07), deployed ALONGSIDE V1
-- DMT_AP_RECON_DM (never overwritten). APInvoices reconciliation
-- data model, BIP reconciliation report contract v1 (nine columns,
-- keyset pagination, the six standard parameters).
--
-- Changes from V1 (backlog #166):
--   1. Rows are found by Fusion job id only, never by the run prefix:
--      BASE rows by the Payables Import request id
--      (AP_INVOICES_ALL.REQUEST_ID / AP_INVOICE_LINES_ALL.REQUEST_ID
--      = :P_IMPORT_ESS_ID, verified live for run 238: request 10070887
--      on both imported invoices and their imported lines; the tax
--      lines Payables adds itself carry no request id and are not
--      returned). INTERFACE rows and their rejections by
--      LOAD_REQUEST_ID = :P_LOAD_REQUEST_ID. The prefixed invoice
--      number is used only as the RECORD_KEY that matches a returned
--      row back to its TFM row.
--   2. Rejections are scoped to this load. Fusion reuses interface
--      INVOICE_IDs across loads, so AP_INTERFACE_REJECTIONS can hold an
--      older load's rejection under the same PARENT_ID (live: interface
--      invoice 100000346 carried NO INVOICE LINES from load 9989786 of
--      2026-09-18 and the real line rejections from load 10070879 of
--      run 238). V1 reported the stale rejection as the header's own
--      error.
--   3. Only real Fusion error text is returned. V1 composed
--      "Rejected by Payables Import (status=...)" when a rejected
--      header had no rejection row, and "[LINE] Parent invoice
--      rejected: ..." on lines of a rejected header. Both are gone:
--      a header or line is an ERROR row only when Payables wrote a
--      rejection for it in this load. A row Payables rejected only
--      because another row of the same invoice failed is not returned
--      here; DMT_AP_RESULTS_PKG.PROPAGATE_DOCUMENT_ERRORS quotes the
--      failing row's real error onto it (design section 5,
--      whole-document rejection).
--   4. Keyset ordering and comparison pinned to BINARY.
--
-- MULTI-TIER: OBJECT_TYPE 'APInvoices' (headers) and
-- 'APInvoices.Line' (lines). RECORD_KEY: headers = prefixed
-- INVOICE_NUM; lines = prefixed INVOICE_NUM || ':LINE:' || LINE_NUMBER.
-- FUSION_ID: headers = base INVOICE_ID; lines = the line-grain
-- composite INVOICE_ID~LINE_NUMBER.
-- ERROR_MESSAGE: NVL(REJECTION_MESSAGE, REJECT_LOOKUP_CODE) from
-- AP_INTERFACE_REJECTIONS (REJECTION_MESSAGE is empty on this
-- instance, so the reject code is the real text), tagged [HDR]/[LINE].
-- ============================================================
SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    -- BASE / headers imported by this Payables Import request.
    SELECT
        'APInvoices'                         AS object_type,
        h.invoice_num                        AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        TO_CHAR(h.invoice_id)                AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        h.request_id                         AS load_request_id,
        h.reference_key1                     AS source_ref,
        h.attribute1                         AS dmt_reference
    FROM   ap_invoices_all h
    WHERE  h.request_id = TO_NUMBER(:P_IMPORT_ESS_ID)

    UNION ALL

    -- BASE / lines imported by this Payables Import request.
    SELECT
        'APInvoices.Line'                    AS object_type,
        h.invoice_num || ':LINE:' || l.line_number  AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        l.invoice_id || '~' || l.line_number AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        l.request_id                         AS load_request_id,
        h.reference_key1                     AS source_ref,
        l.attribute1                         AS dmt_reference
    FROM   ap_invoice_lines_all l
    JOIN   ap_invoices_all h
           ON h.invoice_id = l.invoice_id
    WHERE  l.request_id = TO_NUMBER(:P_IMPORT_ESS_ID)

    UNION ALL

    -- INTERFACE / headers of this load that were not imported and carry
    -- their own rejection(s) from this load.
    SELECT
        'APInvoices'                         AS object_type,
        h.invoice_num                        AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS VARCHAR2(100))          AS fusion_id,
        '[HDR] ' || rj.reject_text           AS error_message,
        h.load_request_id                    AS load_request_id,
        h.invoice_num                        AS source_ref,
        h.attribute1                         AS dmt_reference
    FROM   ap_invoices_interface h
    JOIN   (SELECT r.parent_id,
                   LISTAGG(NVL(r.rejection_message, r.reject_lookup_code), ' | ')
                       WITHIN GROUP (ORDER BY r.reject_lookup_code) AS reject_text
            FROM   ap_interface_rejections r
            WHERE  r.parent_table    = 'AP_INVOICES_INTERFACE'
            AND    r.load_request_id = TO_NUMBER(:P_LOAD_REQUEST_ID)
            GROUP BY r.parent_id) rj
           ON rj.parent_id = h.invoice_id
    WHERE  h.load_request_id = TO_NUMBER(:P_LOAD_REQUEST_ID)
    AND    NVL(h.status, 'X') <> 'PROCESSED'

    UNION ALL

    -- INTERFACE / lines of this load that carry their own rejection(s)
    -- from this load. The line interface has no INVOICE_NUM, so the key
    -- comes from its interface header (same load).
    SELECT
        'APInvoices.Line'                    AS object_type,
        h.invoice_num || ':LINE:' || l.line_number  AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS VARCHAR2(100))          AS fusion_id,
        '[LINE] ' || rj.reject_text          AS error_message,
        l.load_request_id                    AS load_request_id,
        h.invoice_num                        AS source_ref,
        l.attribute1                         AS dmt_reference
    FROM   ap_invoice_lines_interface l
    JOIN   ap_invoices_interface h
           ON  h.invoice_id      = l.invoice_id
           AND h.load_request_id = l.load_request_id
    JOIN   (SELECT r.parent_id,
                   LISTAGG(NVL(r.rejection_message, r.reject_lookup_code), ' | ')
                       WITHIN GROUP (ORDER BY r.reject_lookup_code) AS reject_text
            FROM   ap_interface_rejections r
            WHERE  r.parent_table    = 'AP_INVOICE_LINES_INTERFACE'
            AND    r.load_request_id = TO_NUMBER(:P_LOAD_REQUEST_ID)
            GROUP BY r.parent_id) rj
           ON rj.parent_id = l.invoice_line_id
    WHERE  l.load_request_id = TO_NUMBER(:P_LOAD_REQUEST_ID)
)
-- Keyset predicate. An empty P_AFTER_KEY (first page) binds to NULL in
-- BIP, so treat NULL as "from the start". Ordering and the comparison
-- are pinned to BINARY so they agree regardless of the session NLS_SORT.
WHERE  (:P_AFTER_KEY IS NULL
        OR NLSSORT(record_key, 'NLS_SORT=BINARY') > NLSSORT(:P_AFTER_KEY, 'NLS_SORT=BINARY'))
ORDER BY NLSSORT(record_key, 'NLS_SORT=BINARY')
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
      
