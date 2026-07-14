-- ============================================================
-- ARInvoices BIP reconciliation query -- BASE-tier confirmed, MIRROR of the
-- deployed data model bip/ARInvoices/AR_DM.xdm (deploy target
-- /Custom/DMT2/ARInvoices/). The SQL below is the byte-exact CDATA body of that
-- .xdm; regenerate this file from the .xdm whenever the data model changes --
-- the mirror must never drift.
--
-- Data source: ApplicationDB_FSCM
-- Anchor (selection key): RA_INTERFACE_LINES_ALL keyed on :P_BATCH_ID (the load
--   ESS request id). AutoInvoice does NOT purge interface rows, so every line the
--   run submitted -- loaded or failed -- is still visible here. INTERFACE_LINE_ATTRIBUTE1
--   is the reconciler's match key (= the prefixed TRX_NUMBER the transform wrote).
--
-- BASE-tier confirmation (Rule #1): an AR invoice line is reported PROCESSED only
--   when it positively exists in the Fusion base table RA_CUSTOMER_TRX_ALL. The link
--   is CUSTOMER_TRX_ID: AutoInvoice stamps RA_INTERFACE_LINES_ALL.CUSTOMER_TRX_ID on
--   each line it successfully loads, and that value is the base row's primary key
--   (verified live: interface CUSTOMER_TRX_ID == RA_CUSTOMER_TRX_ALL.CUSTOMER_TRX_ID).
--   We do NOT key the base table on TRX_NUMBER -- the AR batch source uses automatic
--   transaction numbering, so the base TRX_NUMBER is Fusion-assigned and the DMT run
--   prefix is not present on it. STATUS is derived from base-row presence (b.customer_trx_id
--   IS NOT NULL), never from the interface's own status flag. CUSTOMER_TRX_ID returned is
--   the real base id.
--
-- Error tier: RA_INTERFACE_ERRORS_ALL reject text (with invalid_value enrichment),
--   correlated by INTERFACE_LINE_ID. A line with no base row and error text is REJECTED.
--
-- The reconciler (DMT_AR_RESULTS_PKG.PARSE_AND_UPDATE) is unchanged: it matches TFM
-- rows on INTERFACE_LINE_ATTRIBUTE1 and treats a non-null CUSTOMER_TRX_ID (now sourced
-- from the base table) plus INTERFACE_STATUS='P' as LOADED, ERROR_MESSAGE set as FAILED.
-- INTERFACE_STATUS is forced to 'P' when the base row exists so the existing reconciler
-- LOADED test is satisfied by positive base presence, not by the interface flag.
-- AR groups by BU + BatchSource -- BATCH_SOURCE_NAME is preserved from the interface row.
-- ============================================================
SELECT
    l.interface_line_context,
    l.interface_line_attribute1,
    l.interface_line_attribute2,
    l.interface_line_attribute3,
    l.trx_number,
    TO_CHAR(b.customer_trx_id) AS customer_trx_id,
    CASE WHEN b.customer_trx_id IS NOT NULL THEN 'P' ELSE l.interface_status END AS interface_status,
    l.batch_source_name,
    l.line_type,
    TO_CHAR(l.amount) AS amount,
    (
        SELECT LISTAGG(
                   CASE
                       WHEN e.invalid_value IS NOT NULL
                       THEN e.message_text || ' [value=' || e.invalid_value || ']'
                       ELSE e.message_text
                   END, '; ')
               WITHIN GROUP (ORDER BY e.interface_line_id)
        FROM   ra_interface_errors_all e
        WHERE  e.interface_line_id = l.interface_line_id
    ) AS error_message
FROM   ra_interface_lines_all l
LEFT JOIN ra_customer_trx_all b ON b.customer_trx_id = l.customer_trx_id
WHERE  l.load_request_id = :P_BATCH_ID
AND    l.line_type = 'LINE'
