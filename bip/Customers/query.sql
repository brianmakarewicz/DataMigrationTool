-- ============================================================
-- Customers BIP Reconciliation Query
-- Data source: ApplicationDB_FSCM
-- Interface table: HZ_IMP_PARTIES_T
-- Error view: HZ_IMP_ERRORS (joined via ERROR_ID)
-- Parameter: :P_BATCH_ID = Load ESS request ID (LOAD_REQUEST_ID)
--
-- Key columns:
--   INTERFACE_STATUS: 'S' = success, NULL = pending/error
--   ERROR_ID: FK to HZ_IMP_ERRORS view (one error per party row)
--   IMPORT_STATUS_CODE: 'S' = success
--
-- HZ_IMP_ERRORS contains:
--   ERROR_MSG_TEXT — full error description
--   MESSAGE_NAME — error message code
--   INTERFACE_TABLE_NAME — which interface table the error belongs to
-- ============================================================
SELECT
    p.party_orig_system_reference,
    p.party_number,
    p.party_id,
    p.organization_name,
    p.import_status_code                AS import_status,
    p.interface_status,
    p.batch_id,
    (
        SELECT LISTAGG(e.error_msg_text, '; ')
               WITHIN GROUP (ORDER BY e.error_seq_id)
        FROM   hz_imp_errors e
        WHERE  e.error_id = p.error_id
        AND    e.interface_table_name = 'HZ_IMP_PARTIES_T'
        AND    ROWNUM <= 10
    ) AS error_message
FROM   hz_imp_parties_t p
WHERE  p.load_request_id = :P_BATCH_ID
