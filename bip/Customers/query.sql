-- ============================================================
-- Customers BIP reconciliation query -- MIRROR of the deployed
-- data model bip/Customers/DMT_CUST_RECON_DM.xdm (deploy target
-- /Custom/DMT2/Customers/). The SQL below is the byte-exact
-- CDATA body of that .xdm; regenerate this file from the .xdm
-- whenever the data model changes -- the mirror must never drift.
-- Contract v1 parameters (design section 5): P_RUN_ID,
-- P_LOAD_REQUEST_ID (the selection key -- HZ_IMP_PARTIES_T carries
-- LOAD_REQUEST_ID, populated even when the chained import job
-- errors), P_IMPORT_ESS_ID, P_PREFIX. P_BATCH_ID is retired.
-- Primary interface table: HZ_IMP_PARTIES_T; errors from
-- HZ_IMP_ERRORS joined via ERROR_ID.
-- ============================================================
SELECT
    p.party_orig_system_reference,
    p.party_number,
    p.party_id,
    p.organization_name,
    p.import_status_code                AS import_status,
    p.interface_status,
    p.load_request_id,
    (
        SELECT LISTAGG(e.error_msg_text, '; ')
               WITHIN GROUP (ORDER BY e.error_seq_id)
        FROM   hz_imp_errors e
        WHERE  e.error_id = p.error_id
        AND    e.interface_table_name = 'HZ_IMP_PARTIES_T'
        AND    ROWNUM <= 10
    ) AS error_message
FROM   hz_imp_parties_t p
WHERE  p.load_request_id = :P_LOAD_REQUEST_ID
