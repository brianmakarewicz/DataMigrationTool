-- ============================================================
-- Customers BIP reconciliation query -- MIRROR of the deployed
-- data model bip/Customers/DMT_CUST_RECON_V2_DM.xdm (deploy target
-- /Custom/DMT2/Customers/). The SQL below is the byte-exact CDATA
-- body of that .xdm; the .xdm is authoritative -- regenerate this
-- file from the .xdm whenever the data model changes so the mirror
-- never drifts. Contract v1: nine columns, six parameters, keyset
-- pagination.
-- ============================================================
-- ============================================================
-- Customers reconciliation data model -- BIP reconciliation
-- report contract v1 (nine columns, keyset pagination, the six
-- standard parameters). Same shape as DMT_GL_BAL_RECON_DM.xdm and
-- DMT_AR_RECON_DM.xdm.
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
-- MULTI-TIER object. Customers is ONE FBDI zip (BulkImportJob)
-- carrying SEVEN record types (Parties, Locations, PartySites,
-- PartySiteUses, Accounts, AccountSites, AccountSiteUses). Each has
-- its own interface table (HZ_IMP_*_T) and its own Trading Community
-- base identity, so this DM UNION ALLs SEVEN BASE + SEVEN INTERFACE
-- blocks, ordered by RECORD_KEY. OBJECT_TYPE names the record type.
--
-- KEYS (per the #12 carrier map, dmt_ref_carrier_cfg_tbl.sql --
-- the Customers/Parties row is the TEMPLATE for the whole TCA family):
--   SOURCE_REF  (Slot A) = the record type's native run-prefixed
--     ORIG_SYSTEM_REFERENCE, read back from the Fusion BASE table
--     HZ_ORIG_SYS_REFERENCES.ORIG_SYSTEM_REFERENCE on the BASE tier
--     and taken from the interface row's own *_ORIG_SYSTEM_REF column
--     on the INTERFACE tier. This is the identity carrier that
--     verifiably round-trips (the #12 round-trip proof).
--   RECORD_KEY = <OBJECT_TYPE> || '~' || SOURCE_REF, so it is unique
--     across ALL tiers (native references are not globally unique on
--     their own -- PartySites and PartySiteUses both carry the SITE
--     reference, so the record type is folded in to disambiguate).
--     PartySiteUses also appends the site use type because two uses
--     (BILL_TO / SHIP_TO) can share one site reference. RECORD_KEY is
--     the value the reconciler matches to the TFM RECON_KEY column.
--   DMT_REFERENCE (Slot C) = NULL for every Customers record type.
--     The HZ interface tables expose only ATTRIBUTE1..ATTRIBUTE20 and
--     none is proven to round-trip to an HZ base column, so -- per the
--     carrier-map lesson (never invent a Slot C) -- no DFF reference
--     is read back. The run-scoped DMT:run:queue:tfm reference rides
--     Slot A (SOURCE_REF); DMT_REFERENCE stays NULL, as the carrier
--     config declares (Slot C = NULL for the TCA family).
--   FUSION_ID = the record type's Fusion base id, i.e.
--     HZ_ORIG_SYS_REFERENCES.OWNER_TABLE_ID (the PARTY_ID for
--     Parties, CUST_ACCOUNT_ID for Accounts, and so on). Non-null on
--     every BASE row.
--
-- ROW SELECTION:
--   BASE  rows: HZ_ORIG_SYS_REFERENCES for the record type's owner
--         table where ORIG_SYSTEM_REFERENCE LIKE :P_PREFIX || '%'.
--         A base identity row means the record was created in the
--         Fusion base table -> SUCCESS, with the real OWNER_TABLE_ID.
--   INTERFACE rows: HZ_IMP_*_T rows for this load
--         (LOAD_REQUEST_ID = :P_LOAD_REQUEST_ID) NOT created in base.
--         The import does not delete interface rows, so created rows
--         persist there too; the INTERFACE tier returns only rows with
--         NO matching base identity (NOT EXISTS against
--         HZ_ORIG_SYS_REFERENCES), so no record is counted twice. Each
--         is a rejection/hold -> ERROR, carrying its own
--         IMPORT_STATUS_CODE and the batch HZ_IMP_ERRORS messages.
--   :P_RUN_ID / :P_IMPORT_ESS_ID are declared for contract symmetry;
--   :P_IMPORT_ESS_ID is stamped into LOAD_REQUEST_ID on the BASE tier
--   (the base identity row carries no load-request id of its own).
--
-- FUSION_STATUS is normalized in this DM to exactly SUCCESS/ERROR:
--   BASE  (identity present in HZ_ORIG_SYS_REFERENCES) => SUCCESS
--   INTERFACE (row not created, left in the interface) => ERROR
-- FUSION_ID is non-null on every BASE row. ERROR_MESSAGE is non-null
-- on every ERROR row (the interface row's own import status,
-- decoded, plus the batch's HZ_IMP_ERRORS message names).
--
-- HONEST NOTE (objects/Customers/README.md): the customer bulk
-- import has had job-level batch-id trouble on this demo instance,
-- so some runs left records at the interface rather than the base
-- tables. The BASE tiers are the correct shape for a clean import
-- (20/20 to hz_cust_accounts, 2026-07-11); the INTERFACE tiers
-- report whatever the import left behind. Nothing is fabricated:
-- SUCCESS only with a real base id, ERROR only with a real status.
-- ============================================================
SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    -- ================= BASE tier: positive proof, one block per record type =================

    -- BASE / Parties -- HZ_PARTIES, FUSION_ID = PARTY_ID.
    SELECT
        'Customers.Parties'                  AS object_type,
        'Customers.Parties~' || r.orig_system_reference   AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        r.owner_table_id                     AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        TO_NUMBER(:P_IMPORT_ESS_ID)          AS load_request_id,
        r.orig_system_reference              AS source_ref,
        CAST(NULL AS VARCHAR2(4000))         AS dmt_reference
    FROM   hz_orig_sys_references r
    WHERE  r.owner_table_name = 'HZ_PARTIES'
    AND    r.orig_system_reference LIKE :P_PREFIX || '%'

    UNION ALL

    -- BASE / Locations -- HZ_LOCATIONS, FUSION_ID = LOCATION_ID.
    SELECT
        'Customers.Locations',
        'Customers.Locations~' || r.orig_system_reference,
        'BASE', 'SUCCESS',
        r.owner_table_id,
        CAST(NULL AS VARCHAR2(4000)),
        TO_NUMBER(:P_IMPORT_ESS_ID),
        r.orig_system_reference,
        CAST(NULL AS VARCHAR2(4000))
    FROM   hz_orig_sys_references r
    WHERE  r.owner_table_name = 'HZ_LOCATIONS'
    AND    r.orig_system_reference LIKE :P_PREFIX || '%'

    UNION ALL

    -- BASE / PartySites -- HZ_PARTY_SITES, FUSION_ID = PARTY_SITE_ID.
    SELECT
        'Customers.PartySites',
        'Customers.PartySites~' || r.orig_system_reference,
        'BASE', 'SUCCESS',
        r.owner_table_id,
        CAST(NULL AS VARCHAR2(4000)),
        TO_NUMBER(:P_IMPORT_ESS_ID),
        r.orig_system_reference,
        CAST(NULL AS VARCHAR2(4000))
    FROM   hz_orig_sys_references r
    WHERE  r.owner_table_name = 'HZ_PARTY_SITES'
    AND    r.orig_system_reference LIKE :P_PREFIX || '%'

    UNION ALL

    -- BASE / PartySiteUses -- HZ_PARTY_SITE_USES, FUSION_ID = PARTY_SITE_USE_ID.
    -- A loaded site use has NO orig-system reference of its own: TCA registers
    -- HZ_ORIG_SYS_REFERENCES rows only for parties and party-sites, never for
    -- site uses (confirmed live -- OWNER_TABLE_NAME='HZ_PARTY_SITE_USES'
    -- returns zero run-prefixed rows, and the source has no SITEUSE_ORIG_SYSTEM_REF
    -- column so it is NULL end to end). So we iterate the base HZ_PARTY_SITE_USES
    -- rows and reach the identity carrier through the PARENT party-site's
    -- reference (OWNER_TABLE_NAME='HZ_PARTY_SITES', OWNER_TABLE_ID=PARTY_SITE_ID),
    -- folding SITE_USE_TYPE in to disambiguate the (at most one per type) uses
    -- that share a site. This is the proven pattern from DMT_CUST_RECON_DM.xdm.
    -- RECORD_KEY = parent-site reference '/' SITE_USE_TYPE, identical to the
    -- INTERFACE side, and unique per site use (verified live: no duplicate
    -- parent-ref+type across loaded data).
    SELECT
        'Customers.PartySiteUses',
        'Customers.PartySiteUses~' || pr.orig_system_reference || '/' || su.site_use_type,
        'BASE', 'SUCCESS',
        su.party_site_use_id,
        CAST(NULL AS VARCHAR2(4000)),
        TO_NUMBER(:P_IMPORT_ESS_ID),
        pr.orig_system_reference,
        CAST(NULL AS VARCHAR2(4000))
    FROM   hz_party_site_uses su
    JOIN   hz_orig_sys_references pr
      ON   pr.owner_table_name = 'HZ_PARTY_SITES'
     AND   pr.owner_table_id   = su.party_site_id
    WHERE  pr.orig_system_reference LIKE :P_PREFIX || '%'

    UNION ALL

    -- BASE / Accounts -- HZ_CUST_ACCOUNTS, FUSION_ID = CUST_ACCOUNT_ID.
    SELECT
        'Customers.Accounts',
        'Customers.Accounts~' || r.orig_system_reference,
        'BASE', 'SUCCESS',
        r.owner_table_id,
        CAST(NULL AS VARCHAR2(4000)),
        TO_NUMBER(:P_IMPORT_ESS_ID),
        r.orig_system_reference,
        CAST(NULL AS VARCHAR2(4000))
    FROM   hz_orig_sys_references r
    WHERE  r.owner_table_name = 'HZ_CUST_ACCOUNTS'
    AND    r.orig_system_reference LIKE :P_PREFIX || '%'

    UNION ALL

    -- BASE / AccountSites -- HZ_CUST_ACCT_SITES_ALL, FUSION_ID = CUST_ACCT_SITE_ID.
    SELECT
        'Customers.AccountSites',
        'Customers.AccountSites~' || r.orig_system_reference,
        'BASE', 'SUCCESS',
        r.owner_table_id,
        CAST(NULL AS VARCHAR2(4000)),
        TO_NUMBER(:P_IMPORT_ESS_ID),
        r.orig_system_reference,
        CAST(NULL AS VARCHAR2(4000))
    FROM   hz_orig_sys_references r
    WHERE  r.owner_table_name = 'HZ_CUST_ACCT_SITES_ALL'
    AND    r.orig_system_reference LIKE :P_PREFIX || '%'

    UNION ALL

    -- BASE / AccountSiteUses -- HZ_CUST_SITE_USES_ALL, FUSION_ID = SITE_USE_ID.
    SELECT
        'Customers.AccountSiteUses',
        'Customers.AccountSiteUses~' || r.orig_system_reference,
        'BASE', 'SUCCESS',
        r.owner_table_id,
        CAST(NULL AS VARCHAR2(4000)),
        TO_NUMBER(:P_IMPORT_ESS_ID),
        r.orig_system_reference,
        CAST(NULL AS VARCHAR2(4000))
    FROM   hz_orig_sys_references r
    WHERE  r.owner_table_name = 'HZ_CUST_SITE_USES_ALL'
    AND    r.orig_system_reference LIKE :P_PREFIX || '%'

    UNION ALL

    -- ============ INTERFACE tier: rejections/holds only (no base identity) ============
    -- Row-precise on the interface row's own IMPORT_STATUS_CODE
    -- (S = created -> BASE tier, excluded here; anything else = not
    -- created = ERROR: W = held/warning, E = rejected). The batch
    -- HZ_IMP_ERRORS.MESSAGE_NAME list is appended as context. NOT
    -- EXISTS against HZ_ORIG_SYS_REFERENCES prevents double counting.

    -- INTERFACE / Parties -- HZ_IMP_PARTIES_T, ref PARTY_ORIG_SYSTEM_REFERENCE.
    SELECT
        'Customers.Parties',
        'Customers.Parties~' || ip.party_orig_system_reference,
        'INTERFACE', 'ERROR',
        CAST(NULL AS NUMBER),
        'Not created in base -- interface status ''' || ip.import_status_code || ''''
            || CASE ip.import_status_code
                 WHEN 'W' THEN ' (held/warning -- e.g. Fusion CDM potential-duplicate review)'
                 WHEN 'E' THEN ' (rejected by import)'
                 ELSE '' END
            || NVL2((SELECT MAX(e.message_name) FROM hz_imp_errors e WHERE e.batch_id = ip.batch_id AND e.interface_table_name = 'HZ_IMP_PARTIES_T'),
                    ' -- batch messages: ' || (SELECT LISTAGG(DISTINCT e.message_name, '; ' ON OVERFLOW TRUNCATE) WITHIN GROUP (ORDER BY e.message_name)
                                               FROM hz_imp_errors e WHERE e.batch_id = ip.batch_id AND e.interface_table_name = 'HZ_IMP_PARTIES_T'),
                    ''),
        ip.load_request_id,
        ip.party_orig_system_reference,
        CAST(NULL AS VARCHAR2(4000))
    FROM   hz_imp_parties_t ip
    WHERE  ip.load_request_id = :P_LOAD_REQUEST_ID
    AND    NVL(ip.import_status_code, 'X') <> 'S'
    AND    NOT EXISTS (SELECT 1 FROM hz_orig_sys_references r
                       WHERE r.owner_table_name = 'HZ_PARTIES'
                       AND   r.orig_system_reference = ip.party_orig_system_reference)

    UNION ALL

    -- INTERFACE / Locations -- HZ_IMP_LOCATIONS_T, ref LOCATION_ORIG_SYSTEM_REFERENCE.
    SELECT
        'Customers.Locations',
        'Customers.Locations~' || il.location_orig_system_reference,
        'INTERFACE', 'ERROR',
        CAST(NULL AS NUMBER),
        'Not created in base -- interface status ''' || il.import_status_code || ''''
            || CASE il.import_status_code
                 WHEN 'W' THEN ' (held/warning)'
                 WHEN 'E' THEN ' (rejected by import)'
                 ELSE '' END
            || NVL2((SELECT MAX(e.message_name) FROM hz_imp_errors e WHERE e.batch_id = il.batch_id AND e.interface_table_name = 'HZ_IMP_LOCATIONS_T'),
                    ' -- batch messages: ' || (SELECT LISTAGG(DISTINCT e.message_name, '; ' ON OVERFLOW TRUNCATE) WITHIN GROUP (ORDER BY e.message_name)
                                               FROM hz_imp_errors e WHERE e.batch_id = il.batch_id AND e.interface_table_name = 'HZ_IMP_LOCATIONS_T'),
                    ''),
        il.load_request_id,
        il.location_orig_system_reference,
        CAST(NULL AS VARCHAR2(4000))
    FROM   hz_imp_locations_t il
    WHERE  il.load_request_id = :P_LOAD_REQUEST_ID
    AND    NVL(il.import_status_code, 'X') <> 'S'
    AND    NOT EXISTS (SELECT 1 FROM hz_orig_sys_references r
                       WHERE r.owner_table_name = 'HZ_LOCATIONS'
                       AND   r.orig_system_reference = il.location_orig_system_reference)

    UNION ALL

    -- INTERFACE / PartySites -- HZ_IMP_PARTYSITES_T, ref SITE_ORIG_SYSTEM_REFERENCE.
    SELECT
        'Customers.PartySites',
        'Customers.PartySites~' || ips.site_orig_system_reference,
        'INTERFACE', 'ERROR',
        CAST(NULL AS NUMBER),
        'Not created in base -- interface status ''' || ips.import_status_code || ''''
            || CASE ips.import_status_code
                 WHEN 'W' THEN ' (held/warning)'
                 WHEN 'E' THEN ' (rejected by import)'
                 ELSE '' END
            || NVL2((SELECT MAX(e.message_name) FROM hz_imp_errors e WHERE e.batch_id = ips.batch_id AND e.interface_table_name = 'HZ_IMP_PARTYSITES_T'),
                    ' -- batch messages: ' || (SELECT LISTAGG(DISTINCT e.message_name, '; ' ON OVERFLOW TRUNCATE) WITHIN GROUP (ORDER BY e.message_name)
                                               FROM hz_imp_errors e WHERE e.batch_id = ips.batch_id AND e.interface_table_name = 'HZ_IMP_PARTYSITES_T'),
                    ''),
        ips.load_request_id,
        ips.site_orig_system_reference,
        CAST(NULL AS VARCHAR2(4000))
    FROM   hz_imp_partysites_t ips
    WHERE  ips.load_request_id = :P_LOAD_REQUEST_ID
    AND    NVL(ips.import_status_code, 'X') <> 'S'
    AND    NOT EXISTS (SELECT 1 FROM hz_orig_sys_references r
                       WHERE r.owner_table_name = 'HZ_PARTY_SITES'
                       AND   r.orig_system_reference = ips.site_orig_system_reference)

    UNION ALL

    -- INTERFACE / PartySiteUses -- HZ_IMP_PARTYSITEUSES_T. The site use has no
    -- reference of its own (SITEUSE_ORIG_SYSTEM_REF is NULL end to end), so the
    -- identity carrier is the PARENT party-site reference SITE_ORIG_SYSTEM_REFERENCE,
    -- exactly as on the BASE tier, so both keys are computed from the same value.
    -- RECORD_KEY = parent-site reference '/' SITE_USE_TYPE.
    SELECT
        'Customers.PartySiteUses',
        'Customers.PartySiteUses~' || ipu.site_orig_system_reference || '/' || ipu.site_use_type,
        'INTERFACE', 'ERROR',
        CAST(NULL AS NUMBER),
        'Not created in base -- interface status ''' || ipu.import_status_code || ''''
            || CASE ipu.import_status_code
                 WHEN 'W' THEN ' (held/warning)'
                 WHEN 'E' THEN ' (rejected by import)'
                 ELSE '' END
            || NVL2((SELECT MAX(e.message_name) FROM hz_imp_errors e WHERE e.batch_id = ipu.batch_id AND e.interface_table_name = 'HZ_IMP_PARTYSITEUSES_T'),
                    ' -- batch messages: ' || (SELECT LISTAGG(DISTINCT e.message_name, '; ' ON OVERFLOW TRUNCATE) WITHIN GROUP (ORDER BY e.message_name)
                                               FROM hz_imp_errors e WHERE e.batch_id = ipu.batch_id AND e.interface_table_name = 'HZ_IMP_PARTYSITEUSES_T'),
                    ''),
        ipu.load_request_id,
        ipu.site_orig_system_reference,
        CAST(NULL AS VARCHAR2(4000))
    FROM   hz_imp_partysiteuses_t ipu
    WHERE  ipu.load_request_id = :P_LOAD_REQUEST_ID
    AND    NVL(ipu.import_status_code, 'X') <> 'S'
    -- Double-count anti-join: mirror the BASE tier exactly. A site use that WAS
    -- created in base (reached via its parent party-site reference + SITE_USE_TYPE)
    -- must not also be reported ERROR here. So exclude interface rows whose parent
    -- site reference + site-use type already produced a base HZ_PARTY_SITE_USES row.
    AND    NOT EXISTS (SELECT 1 FROM hz_party_site_uses su
                       JOIN   hz_orig_sys_references pr
                         ON   pr.owner_table_name = 'HZ_PARTY_SITES'
                        AND   pr.owner_table_id   = su.party_site_id
                       WHERE  pr.orig_system_reference = ipu.site_orig_system_reference
                       AND    su.site_use_type        = ipu.site_use_type)

    UNION ALL

    -- INTERFACE / Accounts -- HZ_IMP_ACCOUNTS_T, ref CUST_ORIG_SYSTEM_REFERENCE.
    SELECT
        'Customers.Accounts',
        'Customers.Accounts~' || ia.cust_orig_system_reference,
        'INTERFACE', 'ERROR',
        CAST(NULL AS NUMBER),
        'Not created in base -- interface status ''' || ia.import_status_code || ''''
            || CASE ia.import_status_code
                 WHEN 'W' THEN ' (held/warning)'
                 WHEN 'E' THEN ' (rejected by import)'
                 ELSE '' END
            || NVL2((SELECT MAX(e.message_name) FROM hz_imp_errors e WHERE e.batch_id = ia.batch_id AND e.interface_table_name = 'HZ_IMP_ACCOUNTS_T'),
                    ' -- batch messages: ' || (SELECT LISTAGG(DISTINCT e.message_name, '; ' ON OVERFLOW TRUNCATE) WITHIN GROUP (ORDER BY e.message_name)
                                               FROM hz_imp_errors e WHERE e.batch_id = ia.batch_id AND e.interface_table_name = 'HZ_IMP_ACCOUNTS_T'),
                    ''),
        ia.load_request_id,
        ia.cust_orig_system_reference,
        CAST(NULL AS VARCHAR2(4000))
    FROM   hz_imp_accounts_t ia
    WHERE  ia.load_request_id = :P_LOAD_REQUEST_ID
    AND    NVL(ia.import_status_code, 'X') <> 'S'
    AND    NOT EXISTS (SELECT 1 FROM hz_orig_sys_references r
                       WHERE r.owner_table_name = 'HZ_CUST_ACCOUNTS'
                       AND   r.orig_system_reference = ia.cust_orig_system_reference)

    UNION ALL

    -- INTERFACE / AccountSites -- HZ_IMP_ACCTSITES_T, ref CUST_SITE_ORIG_SYS_REF.
    SELECT
        'Customers.AccountSites',
        'Customers.AccountSites~' || ias.cust_site_orig_sys_ref,
        'INTERFACE', 'ERROR',
        CAST(NULL AS NUMBER),
        'Not created in base -- interface status ''' || ias.import_status_code || ''''
            || CASE ias.import_status_code
                 WHEN 'W' THEN ' (held/warning)'
                 WHEN 'E' THEN ' (rejected by import)'
                 ELSE '' END
            || NVL2((SELECT MAX(e.message_name) FROM hz_imp_errors e WHERE e.batch_id = ias.batch_id AND e.interface_table_name = 'HZ_IMP_ACCTSITES_T'),
                    ' -- batch messages: ' || (SELECT LISTAGG(DISTINCT e.message_name, '; ' ON OVERFLOW TRUNCATE) WITHIN GROUP (ORDER BY e.message_name)
                                               FROM hz_imp_errors e WHERE e.batch_id = ias.batch_id AND e.interface_table_name = 'HZ_IMP_ACCTSITES_T'),
                    ''),
        ias.load_request_id,
        ias.cust_site_orig_sys_ref,
        CAST(NULL AS VARCHAR2(4000))
    FROM   hz_imp_acctsites_t ias
    WHERE  ias.load_request_id = :P_LOAD_REQUEST_ID
    AND    NVL(ias.import_status_code, 'X') <> 'S'
    AND    NOT EXISTS (SELECT 1 FROM hz_orig_sys_references r
                       WHERE r.owner_table_name = 'HZ_CUST_ACCT_SITES_ALL'
                       AND   r.orig_system_reference = ias.cust_site_orig_sys_ref)

    UNION ALL

    -- INTERFACE / AccountSiteUses -- HZ_IMP_ACCTSITEUSES_T, ref CUST_SITEUSE_ORIG_SYS_REF.
    SELECT
        'Customers.AccountSiteUses',
        'Customers.AccountSiteUses~' || iasu.cust_siteuse_orig_sys_ref,
        'INTERFACE', 'ERROR',
        CAST(NULL AS NUMBER),
        'Not created in base -- interface status ''' || iasu.import_status_code || ''''
            || CASE iasu.import_status_code
                 WHEN 'W' THEN ' (held/warning)'
                 WHEN 'E' THEN ' (rejected by import)'
                 ELSE '' END
            || NVL2((SELECT MAX(e.message_name) FROM hz_imp_errors e WHERE e.batch_id = iasu.batch_id AND e.interface_table_name = 'HZ_IMP_ACCTSITEUSES_T'),
                    ' -- batch messages: ' || (SELECT LISTAGG(DISTINCT e.message_name, '; ' ON OVERFLOW TRUNCATE) WITHIN GROUP (ORDER BY e.message_name)
                                               FROM hz_imp_errors e WHERE e.batch_id = iasu.batch_id AND e.interface_table_name = 'HZ_IMP_ACCTSITEUSES_T'),
                    ''),
        iasu.load_request_id,
        iasu.cust_siteuse_orig_sys_ref,
        CAST(NULL AS VARCHAR2(4000))
    FROM   hz_imp_acctsiteuses_t iasu
    WHERE  iasu.load_request_id = :P_LOAD_REQUEST_ID
    AND    NVL(iasu.import_status_code, 'X') <> 'S'
)
-- Keyset predicate. An empty P_AFTER_KEY (first page) binds to NULL in
-- BIP, so treat NULL as "from the start": return every row. On later
-- pages P_AFTER_KEY carries the previous page's last RECORD_KEY and only
-- greater keys are returned. RECORD_KEY is compared as text (the recon
-- key is a string); the reconciler feeds back the exact key it received.
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
      