-- ============================================================
-- ARInvoices BIP Reconciliation Query
-- Data source: ApplicationDB_FSCM
-- Interface table: RA_INTERFACE_LINES_ALL
-- Error table: RA_INTERFACE_ERRORS_ALL (correlated subquery via INTERFACE_LINE_ID)
-- Parameter: :P_BATCH_ID = Load ESS request ID (LOAD_REQUEST_ID)
--
-- AR AutoInvoice loads lines + distributions in one ESS job.
-- RA_INTERFACE_LINES_ALL is the primary interface table.
--
-- Key columns:
--   INTERFACE_LINE_ATTRIBUTE1 — user-supplied key, matches TFM table
--   INTERFACE_STATUS: NULL = pending, 'P' = Processed (success)
--   CUSTOMER_TRX_ID — Fusion internal transaction ID (on success)
--   TRX_NUMBER — Fusion-assigned transaction number
--
-- AD#19 compliant: uses real MESSAGE_TEXT from RA_INTERFACE_ERRORS_ALL
-- via correlated subquery with LISTAGG. No CAST(NULL) for error_message.
-- No separate Tier 2 needed — AR AutoInvoice does not purge interface rows.
-- ============================================================
SELECT
    l.interface_line_context,
    l.interface_line_attribute1,
    l.interface_line_attribute2,
    l.interface_line_attribute3,
    l.trx_number,
    l.customer_trx_id,
    l.interface_status,
    l.batch_source_name,
    l.line_type,
    l.amount,
    (
        SELECT LISTAGG(e.message_text, '; ')
               WITHIN GROUP (ORDER BY e.interface_line_id)
        FROM   ra_interface_errors_all e
        WHERE  e.interface_line_id = l.interface_line_id
        AND    ROWNUM <= 10
    ) AS error_message
FROM   ra_interface_lines_all l
WHERE  l.load_request_id = :P_BATCH_ID
AND    l.line_type = 'LINE'
