-- ============================================================
-- CashBanks BIP reconciliation query -- BIP reconciliation report
-- contract v1 (nine columns, keyset pagination). This mirrors the SQL
-- embedded in DMT_CEBANK_RECON_DM.xdm for review; the .xdm is authoritative.
-- Regenerate this file from the .xdm whenever the data model changes -- the
-- mirror must never drift.
--
-- NINE columns, in contract order:
--   OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE, FUSION_STATUS,
--   FUSION_ID, ERROR_MESSAGE, LOAD_REQUEST_ID, SOURCE_REF,
--   DMT_REFERENCE
--
-- SIX parameters: P_RUN_ID, P_LOAD_REQUEST_ID, P_IMPORT_ESS_ID,
--   P_PREFIX, P_CHUNK_SIZE, P_AFTER_KEY. No P_OFFSET / P_LIMIT.
--
-- Keyset: ORDER BY RECORD_KEY, only rows whose RECORD_KEY sorts after
-- :P_AFTER_KEY, at most :P_CHUNK_SIZE per page. RECORD_KEY is a
-- tier-prefixed composite so the single cursor is globally unique across
-- the three tiers.
--
-- THREE tiers (UNION ALL), one OBJECT_TYPE each, all producing the nine
-- contract columns. A row present in the Fusion base view/table is positive
-- proof the record loaded:
--   Bank        -> CE_BANKS_V         FUSION_ID = BANK_PARTY_ID,   key BANK_NAME
--   BankBranch  -> CE_BANK_BRANCHES_V FUSION_ID = BRANCH_PARTY_ID, key BANK_BRANCH_NAME
--   BankAccount -> CE_BANK_ACCOUNTS   FUSION_ID = BANK_ACCOUNT_ID, key BANK_ACCOUNT_NAME
-- Only positive proof is returned, so FUSION_STATUS is always SUCCESS and
-- ERROR_MESSAGE is always null; rejections never reach the base tables and
-- are handled by the reconciler.
--
-- Run-scoping: banks/branches are TCA parties -- SOURCE_REF is the natural
-- name (reconciler match key); DMT_REFERENCE is the run reference from
-- HZ_ORIG_SYS_REFERENCES.ORIG_SYSTEM_REFERENCE (LEFT-joined by party id) or
-- HZ_PARTIES.ATTRIBUTE1, and CE_BANK_ACCOUNTS.ATTRIBUTE1 for accounts. When
-- :P_RUN_ID is supplied each tier is scoped with the DMT reference LIKE
-- 'DMT:'||:P_RUN_ID||':%'; when :P_RUN_ID is empty (standalone shape
-- validation, or seed data with no DMT reference) every base row is returned
-- and the reconciler matches by SOURCE_REF.
-- ============================================================
SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    -- Tier: Bank -- CE_BANKS_V, one row per confirmed bank.
    SELECT
        'Bank'                                       AS object_type,
        'Bank|' || b.bank_name                       AS record_key,
        'BASE'                                        AS source_type,
        'SUCCESS'                                     AS fusion_status,
        b.bank_party_id                              AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))                 AS error_message,
        TO_NUMBER(:P_LOAD_REQUEST_ID)                AS load_request_id,
        b.bank_name                                  AS source_ref,
        NVL(osr.orig_system_reference, hp.attribute1) AS dmt_reference
    FROM   ce_banks_v b
    LEFT   JOIN hz_parties hp
           ON hp.party_id = b.bank_party_id
    LEFT   JOIN hz_orig_sys_references osr
           ON osr.owner_table_name = 'HZ_PARTIES'
          AND osr.owner_table_id   = b.bank_party_id
          AND osr.orig_system_reference LIKE 'DMT:' || :P_RUN_ID || ':%'
    WHERE  ( :P_RUN_ID IS NULL
             OR osr.orig_system_reference IS NOT NULL
             OR hp.attribute1 LIKE 'DMT:' || :P_RUN_ID || ':%' )

    UNION ALL

    -- Tier: BankBranch -- CE_BANK_BRANCHES_V, one row per confirmed branch.
    SELECT
        'BankBranch'                                 AS object_type,
        'BankBranch|' || br.bank_name || '/' || br.bank_branch_name AS record_key,
        'BASE'                                        AS source_type,
        'SUCCESS'                                     AS fusion_status,
        br.branch_party_id                           AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))                 AS error_message,
        TO_NUMBER(:P_LOAD_REQUEST_ID)                AS load_request_id,
        br.bank_branch_name                          AS source_ref,
        NVL(osr.orig_system_reference, hp.attribute1) AS dmt_reference
    FROM   ce_bank_branches_v br
    LEFT   JOIN hz_parties hp
           ON hp.party_id = br.branch_party_id
    LEFT   JOIN hz_orig_sys_references osr
           ON osr.owner_table_name = 'HZ_PARTIES'
          AND osr.owner_table_id   = br.branch_party_id
          AND osr.orig_system_reference LIKE 'DMT:' || :P_RUN_ID || ':%'
    WHERE  ( :P_RUN_ID IS NULL
             OR osr.orig_system_reference IS NOT NULL
             OR hp.attribute1 LIKE 'DMT:' || :P_RUN_ID || ':%' )

    UNION ALL

    -- Tier: BankAccount -- CE_BANK_ACCOUNTS, one row per confirmed account.
    SELECT
        'BankAccount'                                AS object_type,
        'BankAccount|' || a.bank_account_name        AS record_key,
        'BASE'                                        AS source_type,
        'SUCCESS'                                     AS fusion_status,
        a.bank_account_id                            AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))                 AS error_message,
        TO_NUMBER(:P_LOAD_REQUEST_ID)                AS load_request_id,
        a.bank_account_name                          AS source_ref,
        a.attribute1                                 AS dmt_reference
    FROM   ce_bank_accounts a
    WHERE  ( :P_RUN_ID IS NULL
             OR a.attribute1 LIKE 'DMT:' || :P_RUN_ID || ':%' )
)
-- Keyset predicate. An empty P_AFTER_KEY (first page) binds to NULL in BIP,
-- so treat NULL as "from the start". On later pages it carries the previous
-- page's last RECORD_KEY; only greater keys are returned.
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
