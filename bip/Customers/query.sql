-- ============================================================
-- Customers BIP reconciliation query -- MIRROR of the deployed
-- data model bip/Customers/DMT_CUST_RECON_DM.xdm (deploy target
-- /Custom/DMT2/Customers/). The SQL below is the byte-exact
-- CDATA body of that .xdm; regenerate this file from the .xdm
-- whenever the data model changes -- the mirror must never drift.
--
-- TWO-TIER, fail-CLOSED (same shape as GLBalances Contract v1):
-- every submitted row gets POSITIVE proof from a Fusion BASE table
-- or a reportable ERROR from HZ_IMP_ERRORS -- absence is never LOADED.
--
--   BASE tier  : HZ_ORIG_SYS_REFERENCES (ORIG_SYSTEM='DMT', one
--                OWNER_TABLE_NAME per record type) gives the real
--                Fusion id (OWNER_TABLE_ID). A row here = the record
--                genuinely landed in the base table. FUSION_ID set,
--                ERROR_MESSAGE NULL.
--   ERROR tier : the two source-ref-bearing interface tables
--                (HZ_IMP_PARTIES_T, HZ_IMP_ACCOUNTS_T), filtered by
--                :P_LOAD_REQUEST_ID, LEFT JOIN HZ_IMP_ERRORS on
--                BATCH_ID. A row here with ERROR_MESSAGE set = the
--                record was rejected by Fusion (the BAD row). FUSION_ID
--                NULL, ERROR_MESSAGE set.
--
-- The reconciler (DMT_CUST_RESULTS_PKG.PARSE_AND_UPDATE) marks a TFM
-- row LOADED only when a BASE row carries a non-null FUSION_ID for its
-- ORIG_SYSTEM_REFERENCE, and FAILED when an ERROR row carries text.
-- Rows with neither are left un-LOADED and swept to FAILED.
--
-- Per-row shape: RECORD_TYPE, ORIG_SYSTEM_REFERENCE (source key,
-- prefix applied by transform), FUSION_ID (NULL if not loaded),
-- ERROR_MESSAGE (NULL if none).
--
-- Contract v1 parameters (design section 5): P_RUN_ID,
-- P_LOAD_REQUEST_ID (the interface selection key), P_IMPORT_ESS_ID,
-- P_PREFIX. Transform sets every *_ORIG_SYSTEM = 'DMT' and prefixes
-- every *_ORIG_SYSTEM_REFERENCE, so the BASE join keys on
-- ORIG_SYSTEM='DMT' + the prefixed reference.
-- ============================================================
SELECT record_type, orig_system_reference, fusion_id, error_message
FROM (
    -- ---- BASE tier: positive proof, one block per record type ----
    SELECT 'Parties'         AS record_type, r.orig_system_reference, r.owner_table_id AS fusion_id, CAST(NULL AS VARCHAR2(4000)) AS error_message
    FROM   hz_orig_sys_references r
    WHERE  r.owner_table_name = 'HZ_PARTIES'
    AND    r.orig_system_reference LIKE :P_PREFIX || '%'
    UNION ALL
    SELECT 'Locations', r.orig_system_reference, r.owner_table_id, NULL
    FROM   hz_orig_sys_references r
    WHERE  r.owner_table_name = 'HZ_LOCATIONS'
    AND    r.orig_system_reference LIKE :P_PREFIX || '%'
    UNION ALL
    SELECT 'PartySites', r.orig_system_reference, r.owner_table_id, NULL
    FROM   hz_orig_sys_references r
    WHERE  r.owner_table_name = 'HZ_PARTY_SITES'
    AND    r.orig_system_reference LIKE :P_PREFIX || '%'
    UNION ALL
    SELECT 'PartySiteUses', r.orig_system_reference, r.owner_table_id, NULL
    FROM   hz_orig_sys_references r
    WHERE  r.owner_table_name = 'HZ_PARTY_SITE_USES'
    AND    r.orig_system_reference LIKE :P_PREFIX || '%'
    UNION ALL
    SELECT 'Accounts', r.orig_system_reference, r.owner_table_id, NULL
    FROM   hz_orig_sys_references r
    WHERE  r.owner_table_name = 'HZ_CUST_ACCOUNTS'
    AND    r.orig_system_reference LIKE :P_PREFIX || '%'
    UNION ALL
    SELECT 'AccountSites', r.orig_system_reference, r.owner_table_id, NULL
    FROM   hz_orig_sys_references r
    WHERE  r.owner_table_name = 'HZ_CUST_ACCT_SITES_ALL'
    AND    r.orig_system_reference LIKE :P_PREFIX || '%'
    UNION ALL
    SELECT 'AccountSiteUses', r.orig_system_reference, r.owner_table_id, NULL
    FROM   hz_orig_sys_references r
    WHERE  r.owner_table_name = 'HZ_CUST_SITE_USES_ALL'
    AND    r.orig_system_reference LIKE :P_PREFIX || '%'
    UNION ALL
    -- ---- NOT-LOADED tier: EVERY interface row not created in the base table is
    -- surfaced as REJECTED, keyed ROW-PRECISE on its own IMPORT_STATUS_CODE
    -- (the interface table is per-row; HZ_IMP_ERRORS is only batch-level and its
    -- resolved text is empty, so we report the row's own status, not the batch).
    -- S = created (handled by BASE tier, NULL here); anything else = not good =
    -- BAD and MUST be reportable: W = held/warning (e.g. potential-duplicate
    -- review), E = rejected by import. No row is silently dropped.
    -- HZ_IMP_ERRORS.MESSAGE_NAME (batch-level, best-effort) is appended as context.
    SELECT 'Parties', ip.party_orig_system_reference, CAST(NULL AS NUMBER),
           CASE WHEN ip.import_status_code = 'S' THEN NULL
                ELSE 'Not created in base -- interface status ''' || ip.import_status_code || ''''
                     || CASE ip.import_status_code
                          WHEN 'W' THEN ' (held/warning -- e.g. Fusion CDM potential-duplicate review)'
                          WHEN 'E' THEN ' (rejected by import)'
                          ELSE '' END
                     || NVL2((SELECT LISTAGG(DISTINCT e.message_name, '; ') WITHIN GROUP (ORDER BY e.message_name)
                              FROM hz_imp_errors e WHERE e.batch_id = ip.batch_id AND e.interface_table_name = 'HZ_IMP_PARTIES_T'),
                             ' -- batch messages: ' || (SELECT LISTAGG(DISTINCT e.message_name, '; ') WITHIN GROUP (ORDER BY e.message_name)
                                                        FROM hz_imp_errors e WHERE e.batch_id = ip.batch_id AND e.interface_table_name = 'HZ_IMP_PARTIES_T'),
                             '')
           END
    FROM   hz_imp_parties_t ip
    WHERE  ip.load_request_id = :P_LOAD_REQUEST_ID
    UNION ALL
    SELECT 'Accounts', ia.cust_orig_system_reference, CAST(NULL AS NUMBER),
           CASE WHEN ia.import_status_code = 'S' THEN NULL
                ELSE 'Not created in base -- interface status ''' || ia.import_status_code || ''''
                     || CASE ia.import_status_code
                          WHEN 'W' THEN ' (held/warning)'
                          WHEN 'E' THEN ' (rejected by import)'
                          ELSE '' END
                     || NVL2((SELECT LISTAGG(DISTINCT e.message_name, '; ') WITHIN GROUP (ORDER BY e.message_name)
                              FROM hz_imp_errors e WHERE e.batch_id = ia.batch_id AND e.interface_table_name = 'HZ_IMP_ACCOUNTS_T'),
                             ' -- batch messages: ' || (SELECT LISTAGG(DISTINCT e.message_name, '; ') WITHIN GROUP (ORDER BY e.message_name)
                                                        FROM hz_imp_errors e WHERE e.batch_id = ia.batch_id AND e.interface_table_name = 'HZ_IMP_ACCOUNTS_T'),
                             '')
           END
    FROM   hz_imp_accounts_t ia
    WHERE  ia.load_request_id = :P_LOAD_REQUEST_ID
)
WHERE  fusion_id IS NOT NULL OR error_message IS NOT NULL
