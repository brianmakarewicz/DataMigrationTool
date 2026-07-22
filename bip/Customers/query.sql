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
    -- ---- INTERFACE tier: LOADED-only, from the interface row's own real Fusion id.
    -- HARD RULE (owner override 2026-07-22, DMT_DESIGN.html section 5): we do NOT
    -- compose an error message from a bare IMPORT_STATUS_CODE. HZ_IMP_ERRORS is
    -- batch-level (no per-row key) and its resolved ERROR_MSG_TEXT is empty on this
    -- pod, so there is NO real, row-attributable Fusion message to attach -- a status
    -- code (E/W) is not a message. So the interface tier emits ONLY the one honest,
    -- non-composed signal it has: a created site use (import_status_code 'S') carries
    -- the real Fusion PARTY_SITE_USE_ID on its interface row, and TCA does not register
    -- it in HZ_ORIG_SYS_REFERENCES so the base tier above cannot see it. Return that
    -- real id => LOADED (a base id, not a message). Every other interface row (E/W and
    -- non-'S' statuses) returns nothing here and stays UNACCOUNTED via the shared sweep,
    -- which is the honest signal to extend the report or fix the load path later.
    SELECT 'PartySiteUses',
           ipu.site_orig_system_reference || '/' || ipu.site_use_type,
           ipu.party_site_use_id,
           CAST(NULL AS VARCHAR2(4000))
    FROM   hz_imp_partysiteuses_t ipu
    WHERE  ipu.load_request_id = :P_LOAD_REQUEST_ID
    AND    ipu.import_status_code = 'S'
    AND    ipu.party_site_use_id IS NOT NULL
)
WHERE  fusion_id IS NOT NULL OR error_message IS NOT NULL
      