-- ============================================================
-- Customers BIP reconciliation query -- MIRROR of the deployed
-- data model bip/Customers/DMT_CUST_RECON_V2_DM.xdm (deploy target
-- /Custom/DMT2/Customers/). The SQL below is the byte-exact
-- CDATA body of that .xdm; regenerate this file from the .xdm
-- whenever the data model changes -- the mirror must never drift.
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
                     || NVL2((SELECT MAX(e.message_name) FROM hz_imp_errors e WHERE e.batch_id = ip.batch_id AND e.interface_table_name = 'HZ_IMP_PARTIES_T'),
                             ' -- batch messages: ' || (SELECT LISTAGG(DISTINCT e.message_name, '; ' ON OVERFLOW TRUNCATE) WITHIN GROUP (ORDER BY e.message_name)
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
                     || NVL2((SELECT MAX(e.message_name) FROM hz_imp_errors e WHERE e.batch_id = ia.batch_id AND e.interface_table_name = 'HZ_IMP_ACCOUNTS_T'),
                             ' -- batch messages: ' || (SELECT LISTAGG(DISTINCT e.message_name, '; ' ON OVERFLOW TRUNCATE) WITHIN GROUP (ORDER BY e.message_name)
                                                        FROM hz_imp_errors e WHERE e.batch_id = ia.batch_id AND e.interface_table_name = 'HZ_IMP_ACCOUNTS_T'),
                             '')
           END
    FROM   hz_imp_accounts_t ia
    WHERE  ia.load_request_id = :P_LOAD_REQUEST_ID
    UNION ALL
    -- Locations: interface HZ_IMP_LOCATIONS_T, keyed on LOCATION_ORIG_SYSTEM_REFERENCE
    -- (the reconciler's Locations FAILED branch matches this column).
    SELECT 'Locations', il.location_orig_system_reference, CAST(NULL AS NUMBER),
           CASE WHEN il.import_status_code = 'S' THEN NULL
                ELSE 'Not created in base -- interface status ''' || il.import_status_code || ''''
                     || CASE il.import_status_code
                          WHEN 'W' THEN ' (held/warning)'
                          WHEN 'E' THEN ' (rejected by import)'
                          ELSE '' END
                     || NVL2((SELECT MAX(e.message_name) FROM hz_imp_errors e WHERE e.batch_id = il.batch_id AND e.interface_table_name = 'HZ_IMP_LOCATIONS_T'),
                             ' -- batch messages: ' || (SELECT LISTAGG(DISTINCT e.message_name, '; ' ON OVERFLOW TRUNCATE) WITHIN GROUP (ORDER BY e.message_name)
                                                        FROM hz_imp_errors e WHERE e.batch_id = il.batch_id AND e.interface_table_name = 'HZ_IMP_LOCATIONS_T'),
                             '')
           END
    FROM   hz_imp_locations_t il
    WHERE  il.load_request_id = :P_LOAD_REQUEST_ID
    UNION ALL
    -- PartySites: interface HZ_IMP_PARTYSITES_T, keyed on SITE_ORIG_SYSTEM_REFERENCE
    -- (the reconciler's PartySites FAILED branch matches this column).
    SELECT 'PartySites', ips.site_orig_system_reference, CAST(NULL AS NUMBER),
           CASE WHEN ips.import_status_code = 'S' THEN NULL
                ELSE 'Not created in base -- interface status ''' || ips.import_status_code || ''''
                     || CASE ips.import_status_code
                          WHEN 'W' THEN ' (held/warning)'
                          WHEN 'E' THEN ' (rejected by import)'
                          ELSE '' END
                     || NVL2((SELECT MAX(e.message_name) FROM hz_imp_errors e WHERE e.batch_id = ips.batch_id AND e.interface_table_name = 'HZ_IMP_PARTYSITES_T'),
                             ' -- batch messages: ' || (SELECT LISTAGG(DISTINCT e.message_name, '; ' ON OVERFLOW TRUNCATE) WITHIN GROUP (ORDER BY e.message_name)
                                                        FROM hz_imp_errors e WHERE e.batch_id = ips.batch_id AND e.interface_table_name = 'HZ_IMP_PARTYSITES_T'),
                             '')
           END
    FROM   hz_imp_partysites_t ips
    WHERE  ips.load_request_id = :P_LOAD_REQUEST_ID
    UNION ALL
    -- PartySiteUses: interface HZ_IMP_PARTYSITEUSES_T. The site use's own
    -- SITEUSE_ORIG_SYSTEM_REF is written NULL into Fusion, so key on the parent
    -- site reference + site_use_type interim key the reconciler matches
    -- (SITE_ORIG_SYSTEM_REFERENCE || '/' || SITE_USE_TYPE). Also, TCA does not
    -- register the site use in HZ_ORIG_SYS_REFERENCES, so the base tier above can
    -- never confirm it -- but the interface row carries the real Fusion
    -- PARTY_SITE_USE_ID once created (import_status_code 'S'). Return that as the
    -- fusion_id on 'S' so a created site use is honestly LOADED with a real base id;
    -- non-'S' returns the interface-status error text.
    SELECT 'PartySiteUses',
           ipu.site_orig_system_reference || '/' || ipu.site_use_type,
           CASE WHEN ipu.import_status_code = 'S' THEN ipu.party_site_use_id ELSE CAST(NULL AS NUMBER) END,
           CASE WHEN ipu.import_status_code = 'S' THEN NULL
                ELSE 'Not created in base -- interface status ''' || ipu.import_status_code || ''''
                     || CASE ipu.import_status_code
                          WHEN 'W' THEN ' (held/warning)'
                          WHEN 'E' THEN ' (rejected by import)'
                          ELSE '' END
                     || NVL2((SELECT MAX(e.message_name) FROM hz_imp_errors e WHERE e.batch_id = ipu.batch_id AND e.interface_table_name = 'HZ_IMP_PARTYSITEUSES_T'),
                             ' -- batch messages: ' || (SELECT LISTAGG(DISTINCT e.message_name, '; ' ON OVERFLOW TRUNCATE) WITHIN GROUP (ORDER BY e.message_name)
                                                        FROM hz_imp_errors e WHERE e.batch_id = ipu.batch_id AND e.interface_table_name = 'HZ_IMP_PARTYSITEUSES_T'),
                             '')
           END
    FROM   hz_imp_partysiteuses_t ipu
    WHERE  ipu.load_request_id = :P_LOAD_REQUEST_ID
    UNION ALL
    -- AccountSites: interface HZ_IMP_ACCTSITES_T, keyed on CUST_SITE_ORIG_SYS_REF
    -- (the reconciler's AccountSites FAILED branch matches this column). This is
    -- the tier the finding named -- held (W) / rejected (E) account sites now
    -- report their real interface status + batch messages instead of the sweep.
    SELECT 'AccountSites', ias.cust_site_orig_sys_ref, CAST(NULL AS NUMBER),
           CASE WHEN ias.import_status_code = 'S' THEN NULL
                ELSE 'Not created in base -- interface status ''' || ias.import_status_code || ''''
                     || CASE ias.import_status_code
                          WHEN 'W' THEN ' (held/warning)'
                          WHEN 'E' THEN ' (rejected by import)'
                          ELSE '' END
                     || NVL2((SELECT MAX(e.message_name) FROM hz_imp_errors e WHERE e.batch_id = ias.batch_id AND e.interface_table_name = 'HZ_IMP_ACCTSITES_T'),
                             ' -- batch messages: ' || (SELECT LISTAGG(DISTINCT e.message_name, '; ' ON OVERFLOW TRUNCATE) WITHIN GROUP (ORDER BY e.message_name)
                                                        FROM hz_imp_errors e WHERE e.batch_id = ias.batch_id AND e.interface_table_name = 'HZ_IMP_ACCTSITES_T'),
                             '')
           END
    FROM   hz_imp_acctsites_t ias
    WHERE  ias.load_request_id = :P_LOAD_REQUEST_ID
    UNION ALL
    -- AccountSiteUses: interface HZ_IMP_ACCTSITEUSES_T, keyed on CUST_SITEUSE_ORIG_SYS_REF
    -- (the reconciler's AccountSiteUses FAILED branch matches this column).
    SELECT 'AccountSiteUses', iasu.cust_siteuse_orig_sys_ref, CAST(NULL AS NUMBER),
           CASE WHEN iasu.import_status_code = 'S' THEN NULL
                ELSE 'Not created in base -- interface status ''' || iasu.import_status_code || ''''
                     || CASE iasu.import_status_code
                          WHEN 'W' THEN ' (held/warning)'
                          WHEN 'E' THEN ' (rejected by import)'
                          ELSE '' END
                     || NVL2((SELECT MAX(e.message_name) FROM hz_imp_errors e WHERE e.batch_id = iasu.batch_id AND e.interface_table_name = 'HZ_IMP_ACCTSITEUSES_T'),
                             ' -- batch messages: ' || (SELECT LISTAGG(DISTINCT e.message_name, '; ' ON OVERFLOW TRUNCATE) WITHIN GROUP (ORDER BY e.message_name)
                                                        FROM hz_imp_errors e WHERE e.batch_id = iasu.batch_id AND e.interface_table_name = 'HZ_IMP_ACCTSITEUSES_T'),
                             '')
           END
    FROM   hz_imp_acctsiteuses_t iasu
    WHERE  iasu.load_request_id = :P_LOAD_REQUEST_ID
)
WHERE  fusion_id IS NOT NULL OR error_message IS NOT NULL
      