-- ============================================================
-- Customers reconciliation data model V6 -- BIP reconciliation
-- report contract v1 (nine columns, keyset pagination) plus one
-- object parameter, P_FUSION_BATCH_ID. Deployed ALONGSIDE V5..V2
-- (never overwrite a BIP object); DMT_BIP_REPORT_TBL row 100000012
-- points the reconciler here.
--
-- WHY V6 (owner rule 2026-10-07, design section 5: reports find
-- rows by Fusion job or batch id, never by prefix or run-id text):
-- V5 selected every BASE tier by a run-prefix pattern match on
--   hz_orig_sys_references.orig_system_reference.
-- V6 selects BASE rows by an EXACT match on the Fusion import batch
-- id this load sent. DMT sends the run prefix followed by the source
-- BATCH_ID (e.g. 93311 + 5001 = 933115001), and the customer bulk
-- import copies that batch id into REQUEST_ID on every HZ base row
-- (verified 2026-10-07 on HZ_PARTIES, HZ_LOCATIONS, HZ_PARTY_SITES,
-- HZ_PARTY_SITE_USES, HZ_CUST_ACCOUNTS, HZ_CUST_ACCT_SITES_ALL and
-- HZ_CUST_SITE_USES_ALL, all NUMBER(18)). Each base table is
-- selected by its OWN REQUEST_ID, so no tier is reached through a
-- parent. The orig-system reference is used only to build the
-- RECORD_KEY that matches a returned row to its TFM row.
-- Everything else (INTERFACE tier, error text, keys, keyset) is V5
-- unchanged.
--
-- V5 = V4 minus one composed string ('(no message text found in
-- FND_NEW_MESSAGES)'); V4 returned an INTERFACE/ERROR row ONLY when
-- the interface row has its OWN Fusion error (HZ_IMP_ERRORS joined
-- exactly on error_id + batch_id, full FND_NEW_MESSAGES text with
-- tokens substituted). A row Fusion held with NO error of its own is
-- not returned; DMT_CUST_RESULTS_PKG.PROPAGATE_DOCUMENT_ERRORS quotes
-- the real error of the row that held it, else the shared sweep marks
-- it UNACCOUNTED. Nothing is composed in this report.
--
-- NINE response columns, in contract order:
--   OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE, FUSION_STATUS,
--   FUSION_ID, ERROR_MESSAGE, LOAD_REQUEST_ID, SOURCE_REF,
--   DMT_REFERENCE.
-- PARAMETERS: the six of Contract v1 (P_RUN_ID, P_LOAD_REQUEST_ID,
--   P_IMPORT_ESS_ID, P_PREFIX, P_CHUNK_SIZE, P_AFTER_KEY) plus
--   P_FUSION_BATCH_ID (sent by DMT_RECON_CONTRACT_PKG.FETCH_ROWS).
--   P_PREFIX and P_RUN_ID select nothing.
-- KEYSET pagination on RECORD_KEY exactly as V2..V5.
--
-- KEYS (unchanged, the #12 carrier map):
--   SOURCE_REF (Slot A) = the record type's run-prefixed native
--     ORIG_SYSTEM_REFERENCE. RECORD_KEY = <OBJECT_TYPE> '~' SOURCE_REF
--     (PartySiteUses append '/' SITE_USE_TYPE). DMT_REFERENCE NULL.
--   FUSION_ID = the base table's own id on BASE rows.
--
-- ROW SELECTION:
--   BASE rows: each HZ base table where REQUEST_ID =
--     :P_FUSION_BATCH_ID (exact), joined to HZ_ORIG_SYS_REFERENCES
--     for its reference (PartySiteUses: the parent party site's
--     reference + SITE_USE_TYPE) -> SUCCESS with the real base id.
--   INTERFACE rows: HZ_IMP_*_T rows of this load
--     (LOAD_REQUEST_ID = :P_LOAD_REQUEST_ID, the load ESS id) with
--     IMPORT_STATUS_CODE <> 'S', NO base identity, and at least one
--     HZ_IMP_ERRORS row of their own -> ERROR with that real text.
-- FUSION_STATUS is exactly SUCCESS/ERROR. ERROR_MESSAGE is non-null on
-- every ERROR row by construction (own_msg IS NOT NULL filter).
-- ============================================================
WITH
-- ld: every interface row of THIS load, all seven record types,
-- normalized to one shape. REF is the identity other rows use to name
-- this row as a parent; P1/P2 are this row's parent references,
-- carried for diagnosis only (V5 builds no message from them).
ld AS (
    SELECT 'PARTY' tier, 'Customers.Parties' object_type,
           'Customers.Parties~' || t.party_orig_system_reference record_key,
           t.party_orig_system_reference ref, t.party_orig_system_reference source_ref,
           CAST(NULL AS VARCHAR2(30)) use_type,
           t.import_status_code st, t.error_id, t.batch_id, t.load_request_id,
           CAST(NULL AS VARCHAR2(30)) p1_tier, CAST(NULL AS VARCHAR2(255)) p1_ref,
           CAST(NULL AS VARCHAR2(30)) p2_tier, CAST(NULL AS VARCHAR2(255)) p2_ref
    FROM   hz_imp_parties_t t
    WHERE  t.load_request_id = :P_LOAD_REQUEST_ID
    UNION ALL
    SELECT 'LOCATION', 'Customers.Locations',
           'Customers.Locations~' || t.location_orig_system_reference,
           t.location_orig_system_reference, t.location_orig_system_reference,
           NULL, t.import_status_code, t.error_id, t.batch_id, t.load_request_id,
           NULL, NULL, NULL, NULL
    FROM   hz_imp_locations_t t
    WHERE  t.load_request_id = :P_LOAD_REQUEST_ID
    UNION ALL
    SELECT 'PARTYSITE', 'Customers.PartySites',
           'Customers.PartySites~' || t.site_orig_system_reference,
           t.site_orig_system_reference, t.site_orig_system_reference,
           NULL, t.import_status_code, t.error_id, t.batch_id, t.load_request_id,
           'PARTY', t.party_orig_system_reference,
           'LOCATION', t.location_orig_system_reference
    FROM   hz_imp_partysites_t t
    WHERE  t.load_request_id = :P_LOAD_REQUEST_ID
    UNION ALL
    SELECT 'PARTYSITEUSE', 'Customers.PartySiteUses',
           'Customers.PartySiteUses~' || t.site_orig_system_reference || '/' || t.site_use_type,
           t.site_orig_system_reference || '/' || t.site_use_type, t.site_orig_system_reference,
           t.site_use_type, t.import_status_code, t.error_id, t.batch_id, t.load_request_id,
           'PARTYSITE', t.site_orig_system_reference,
           'PARTY', t.party_orig_system_reference
    FROM   hz_imp_partysiteuses_t t
    WHERE  t.load_request_id = :P_LOAD_REQUEST_ID
    UNION ALL
    SELECT 'ACCOUNT', 'Customers.Accounts',
           'Customers.Accounts~' || t.cust_orig_system_reference,
           t.cust_orig_system_reference, t.cust_orig_system_reference,
           NULL, t.import_status_code, t.error_id, t.batch_id, t.load_request_id,
           'PARTY', t.party_orig_system_reference, NULL, NULL
    FROM   hz_imp_accounts_t t
    WHERE  t.load_request_id = :P_LOAD_REQUEST_ID
    UNION ALL
    SELECT 'ACCTSITE', 'Customers.AccountSites',
           'Customers.AccountSites~' || t.cust_site_orig_sys_ref,
           t.cust_site_orig_sys_ref, t.cust_site_orig_sys_ref,
           NULL, t.import_status_code, t.error_id, t.batch_id, t.load_request_id,
           'ACCOUNT', t.cust_orig_system_reference,
           'PARTYSITE', t.site_orig_system_reference
    FROM   hz_imp_acctsites_t t
    WHERE  t.load_request_id = :P_LOAD_REQUEST_ID
    UNION ALL
    SELECT 'ACCTSITEUSE', 'Customers.AccountSiteUses',
           'Customers.AccountSiteUses~' || t.cust_siteuse_orig_sys_ref,
           t.cust_siteuse_orig_sys_ref, t.cust_siteuse_orig_sys_ref,
           NULL, t.import_status_code, t.error_id, t.batch_id, t.load_request_id,
           'ACCTSITE', t.cust_site_orig_sys_ref, NULL, NULL
    FROM   hz_imp_acctsiteuses_t t
    WHERE  t.load_request_id = :P_LOAD_REQUEST_ID
),
-- errline: one line per OWN error row of this load's interface rows,
-- joined exactly on error_id + batch_id (never batch-wide). Full text
-- from ERROR_MSG_TEXT, else FND_NEW_MESSAGES (US) with tokens
-- substituted into the {TOKEN} placeholders Fusion messages use.
errline AS (
    SELECT e.error_id, e.batch_id, e.error_seq_id,
           SUBSTR(e.message_name ||
             CASE WHEN COALESCE(e.error_msg_text, m.message_text) IS NOT NULL
                  THEN ': ' ||
                    NVL(e.error_msg_text,
                      REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(m.message_text,
                        '{' || e.token1_name || '}', e.token1_value),
                        '{' || e.token2_name || '}', e.token2_value),
                        '{' || e.token3_name || '}', e.token3_value),
                        '{' || e.token4_name || '}', e.token4_value),
                        '{' || e.token5_name || '}', e.token5_value))
             END,
             1, 1800) AS line
    FROM   hz_imp_errors e
    JOIN   (SELECT DISTINCT error_id, batch_id FROM ld WHERE error_id IS NOT NULL) k
      ON   k.error_id = e.error_id
     AND   k.batch_id = e.batch_id
    LEFT JOIN (SELECT message_name, MAX(message_text) AS message_text
               FROM   fnd_new_messages
               WHERE  language_code = 'US'
               GROUP BY message_name) m
      ON   m.message_name = e.message_name
),
ownerr AS (
    SELECT error_id, batch_id,
           LISTAGG(line, ' | ' ON OVERFLOW TRUNCATE) WITHIN GROUP (ORDER BY error_seq_id) AS msg
    FROM   errline
    GROUP BY error_id, batch_id
),
node AS (
    SELECT ld.*, o.msg AS own_msg
    FROM   ld
    LEFT JOIN ownerr o
      ON   o.error_id = ld.error_id
     AND   o.batch_id = ld.batch_id
)
SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    -- ================= BASE tier: positive proof =================
    -- Every branch selects its base table by REQUEST_ID = the Fusion
    -- import batch id this load sent (exact). The reference join only
    -- supplies the RECORD_KEY / SOURCE_REF used to match the TFM row.

    -- BASE / Parties -- HZ_PARTIES, FUSION_ID = PARTY_ID.
    SELECT
        'Customers.Parties'                  AS object_type,
        'Customers.Parties~' || r.orig_system_reference   AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        p.party_id                           AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        TO_NUMBER(:P_IMPORT_ESS_ID)          AS load_request_id,
        r.orig_system_reference              AS source_ref,
        CAST(NULL AS VARCHAR2(4000))         AS dmt_reference
    FROM   hz_parties p
    JOIN   hz_orig_sys_references r
      ON   r.owner_table_name = 'HZ_PARTIES'
     AND   r.owner_table_id   = p.party_id
    WHERE  p.request_id = TO_NUMBER(:P_FUSION_BATCH_ID)

    UNION ALL

    -- BASE / Locations -- HZ_LOCATIONS, FUSION_ID = LOCATION_ID.
    SELECT
        'Customers.Locations',
        'Customers.Locations~' || r.orig_system_reference,
        'BASE', 'SUCCESS',
        l.location_id,
        CAST(NULL AS VARCHAR2(4000)),
        TO_NUMBER(:P_IMPORT_ESS_ID),
        r.orig_system_reference,
        CAST(NULL AS VARCHAR2(4000))
    FROM   hz_locations l
    JOIN   hz_orig_sys_references r
      ON   r.owner_table_name = 'HZ_LOCATIONS'
     AND   r.owner_table_id   = l.location_id
    WHERE  l.request_id = TO_NUMBER(:P_FUSION_BATCH_ID)

    UNION ALL

    -- BASE / PartySites -- HZ_PARTY_SITES, FUSION_ID = PARTY_SITE_ID.
    SELECT
        'Customers.PartySites',
        'Customers.PartySites~' || r.orig_system_reference,
        'BASE', 'SUCCESS',
        ps.party_site_id,
        CAST(NULL AS VARCHAR2(4000)),
        TO_NUMBER(:P_IMPORT_ESS_ID),
        r.orig_system_reference,
        CAST(NULL AS VARCHAR2(4000))
    FROM   hz_party_sites ps
    JOIN   hz_orig_sys_references r
      ON   r.owner_table_name = 'HZ_PARTY_SITES'
     AND   r.owner_table_id   = ps.party_site_id
    WHERE  ps.request_id = TO_NUMBER(:P_FUSION_BATCH_ID)

    UNION ALL

    -- BASE / PartySiteUses -- HZ_PARTY_SITE_USES, FUSION_ID = PARTY_SITE_USE_ID.
    -- Selected by the site use's OWN REQUEST_ID. A site use has no
    -- orig-system reference of its own, so its key is the PARENT party
    -- site's reference + SITE_USE_TYPE (as in V2..V5).
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
    WHERE  su.request_id = TO_NUMBER(:P_FUSION_BATCH_ID)

    UNION ALL

    -- BASE / Accounts -- HZ_CUST_ACCOUNTS, FUSION_ID = CUST_ACCOUNT_ID.
    SELECT
        'Customers.Accounts',
        'Customers.Accounts~' || r.orig_system_reference,
        'BASE', 'SUCCESS',
        a.cust_account_id,
        CAST(NULL AS VARCHAR2(4000)),
        TO_NUMBER(:P_IMPORT_ESS_ID),
        r.orig_system_reference,
        CAST(NULL AS VARCHAR2(4000))
    FROM   hz_cust_accounts a
    JOIN   hz_orig_sys_references r
      ON   r.owner_table_name = 'HZ_CUST_ACCOUNTS'
     AND   r.owner_table_id   = a.cust_account_id
    WHERE  a.request_id = TO_NUMBER(:P_FUSION_BATCH_ID)

    UNION ALL

    -- BASE / AccountSites -- HZ_CUST_ACCT_SITES_ALL, FUSION_ID = CUST_ACCT_SITE_ID.
    SELECT
        'Customers.AccountSites',
        'Customers.AccountSites~' || r.orig_system_reference,
        'BASE', 'SUCCESS',
        cas.cust_acct_site_id,
        CAST(NULL AS VARCHAR2(4000)),
        TO_NUMBER(:P_IMPORT_ESS_ID),
        r.orig_system_reference,
        CAST(NULL AS VARCHAR2(4000))
    FROM   hz_cust_acct_sites_all cas
    JOIN   hz_orig_sys_references r
      ON   r.owner_table_name = 'HZ_CUST_ACCT_SITES_ALL'
     AND   r.owner_table_id   = cas.cust_acct_site_id
    WHERE  cas.request_id = TO_NUMBER(:P_FUSION_BATCH_ID)

    UNION ALL

    -- BASE / AccountSiteUses -- HZ_CUST_SITE_USES_ALL, FUSION_ID = SITE_USE_ID.
    SELECT
        'Customers.AccountSiteUses',
        'Customers.AccountSiteUses~' || r.orig_system_reference,
        'BASE', 'SUCCESS',
        csu.site_use_id,
        CAST(NULL AS VARCHAR2(4000)),
        TO_NUMBER(:P_IMPORT_ESS_ID),
        r.orig_system_reference,
        CAST(NULL AS VARCHAR2(4000))
    FROM   hz_cust_site_uses_all csu
    JOIN   hz_orig_sys_references r
      ON   r.owner_table_name = 'HZ_CUST_SITE_USES_ALL'
     AND   r.owner_table_id   = csu.site_use_id
    WHERE  csu.request_id = TO_NUMBER(:P_FUSION_BATCH_ID)

    UNION ALL

    -- ============ INTERFACE tier: rows with their OWN Fusion error only ============
    -- Every record type in ONE block over the normalized load (ld/node).
    -- ERROR_MESSAGE is the row's OWN HZ_IMP_ERRORS text, nothing else.
    -- A row with no error of its own is not returned (left for the
    -- shared unaccounted sweep) -- never a composed sentence.
    SELECT
        n.object_type,
        n.record_key,
        'INTERFACE', 'ERROR',
        CAST(NULL AS NUMBER),
        CAST(SUBSTR(n.own_msg, 1, 3900) AS VARCHAR2(4000)),
        n.load_request_id,
        n.source_ref,
        CAST(NULL AS VARCHAR2(4000))
    FROM   node n
    WHERE  NVL(n.st, 'X') <> 'S'
    AND    n.own_msg IS NOT NULL
    -- Double-count anti-join: a record that IS in the base is reported by
    -- the BASE tier only. PartySiteUses mirror their BASE tier exactly
    -- (parent party-site reference + SITE_USE_TYPE); every other record
    -- type checks its own reference in HZ_ORIG_SYS_REFERENCES.
    AND    NOT EXISTS (
             SELECT 1 FROM hz_orig_sys_references r
             WHERE  n.tier <> 'PARTYSITEUSE'
             AND    r.orig_system_reference = n.ref
             AND    r.owner_table_name = DECODE(n.tier,
                      'PARTY',       'HZ_PARTIES',
                      'LOCATION',    'HZ_LOCATIONS',
                      'PARTYSITE',   'HZ_PARTY_SITES',
                      'ACCOUNT',     'HZ_CUST_ACCOUNTS',
                      'ACCTSITE',    'HZ_CUST_ACCT_SITES_ALL',
                      'ACCTSITEUSE', 'HZ_CUST_SITE_USES_ALL'))
    AND    NOT EXISTS (
             SELECT 1 FROM hz_party_site_uses su
             JOIN   hz_orig_sys_references pr
               ON   pr.owner_table_name = 'HZ_PARTY_SITES'
              AND   pr.owner_table_id   = su.party_site_id
             WHERE  n.tier = 'PARTYSITEUSE'
             AND    pr.orig_system_reference = n.source_ref
             AND    su.site_use_type        = n.use_type)
)
-- Keyset predicate (unchanged from V2..V5). An empty P_AFTER_KEY (first page)
-- binds to NULL in BIP: return every row; later pages return keys after it.
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
