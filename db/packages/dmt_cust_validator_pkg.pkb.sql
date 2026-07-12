-- PACKAGE BODY DMT_CUST_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_CUST_VALIDATOR_PKG" 
AS
-- ============================================================
-- DMT_CUST_VALIDATOR_PKG body
-- Customers pre- and post-transform validation.
-- Customers are top-level master data — no upstream dependency.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_CUST_VALIDATOR_PKG';

    -- --------------------------------------------------------
    -- VALIDATE_PRE_TRANSFORM
    -- Basic data quality on STG party rows.
    -- No upstream dependency check — customers are master data.
    -- Validates: PARTY_TYPE required, ORGANIZATION_NAME required
    -- for orgs, PERSON_LAST_NAME required for persons.
    -- Failed parties cascade to all child tables via
    -- PARTY_ORIG_SYSTEM_REFERENCE linkage.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id    IN NUMBER,
        p_dependent_prefix  IN VARCHAR2 DEFAULT NULL
    )
    IS
        l_party_failed    NUMBER := 0;
        l_loc_failed      NUMBER := 0;
        l_ps_failed       NUMBER := 0;
        l_psu_failed      NUMBER := 0;
        l_acct_failed     NUMBER := 0;
        l_as_failed       NUMBER := 0;
        l_asu_failed      NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_PRE_TRANSFORM start.',
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_PRE_TRANSFORM');

        -- Step 1a: PARTY_TYPE is required.
        UPDATE DMT_OWNER.DMT_HZ_PARTIES_STG_TBL p
        SET    STG_STATUS            = 'FAILED',
               ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(
                                       ERROR_TEXT,
                                       '[PRE_VALIDATION] PARTY_TYPE is required.'),
               LAST_UPDATED_DATE = SYSDATE
        WHERE  p.STG_STATUS IN ('NEW', 'RETRY')
        AND    p.PARTY_TYPE IS NULL;
        l_party_failed := l_party_failed + SQL%ROWCOUNT;

        -- Step 1b: ORGANIZATION_NAME required when PARTY_TYPE = 'ORGANIZATION'.
        UPDATE DMT_OWNER.DMT_HZ_PARTIES_STG_TBL p
        SET    STG_STATUS            = 'FAILED',
               ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(
                                       ERROR_TEXT,
                                       '[PRE_VALIDATION] ORGANIZATION_NAME is required when PARTY_TYPE is ''ORGANIZATION''.'),
               LAST_UPDATED_DATE = SYSDATE
        WHERE  p.STG_STATUS IN ('NEW', 'RETRY')
        AND    UPPER(p.PARTY_TYPE) = 'ORGANIZATION'
        AND    p.ORGANIZATION_NAME IS NULL;
        l_party_failed := l_party_failed + SQL%ROWCOUNT;

        -- Step 1c: PERSON_LAST_NAME required when PARTY_TYPE = 'PERSON'.
        UPDATE DMT_OWNER.DMT_HZ_PARTIES_STG_TBL p
        SET    STG_STATUS            = 'FAILED',
               ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(
                                       ERROR_TEXT,
                                       '[PRE_VALIDATION] PERSON_LAST_NAME is required when PARTY_TYPE is ''PERSON''.'),
               LAST_UPDATED_DATE = SYSDATE
        WHERE  p.STG_STATUS IN ('NEW', 'RETRY')
        AND    UPPER(p.PARTY_TYPE) = 'PERSON'
        AND    p.PERSON_LAST_NAME IS NULL;
        l_party_failed := l_party_failed + SQL%ROWCOUNT;

        -- Step 1d: PARTY_ORIG_SYSTEM_REFERENCE is required (linking key).
        UPDATE DMT_OWNER.DMT_HZ_PARTIES_STG_TBL p
        SET    STG_STATUS            = 'FAILED',
               ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(
                                       ERROR_TEXT,
                                       '[PRE_VALIDATION] PARTY_ORIG_SYSTEM_REFERENCE is required.'),
               LAST_UPDATED_DATE = SYSDATE
        WHERE  p.STG_STATUS IN ('NEW', 'RETRY')
        AND    p.PARTY_ORIG_SYSTEM_REFERENCE IS NULL;
        l_party_failed := l_party_failed + SQL%ROWCOUNT;

        -- Step 1e: BATCH_ID is required (customer batch / partition key). The
        -- loader partitions Customers by BATCH_ID and sends it as the first
        -- value of the BulkImportJob ParameterList; a row with no batch id
        -- can neither be split nor loaded.
        UPDATE DMT_OWNER.DMT_HZ_PARTIES_STG_TBL p
        SET    STG_STATUS        = 'FAILED',
               ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(
                                       ERROR_TEXT,
                                       '[PRE_VALIDATION] BATCH_ID is required (customer batch / partition key).'),
               LAST_UPDATED_DATE = SYSDATE
        WHERE  p.STG_STATUS IN ('NEW', 'RETRY')
        AND    p.BATCH_ID IS NULL;
        l_party_failed := l_party_failed + SQL%ROWCOUNT;

        -- Step 2: Cascade failures to locations for any failed party.
        -- Locations link to parties via PARTY_ORIG_SYSTEM_REFERENCE stored
        -- in related party_sites. For simplicity, locations are validated
        -- independently — they do not cascade from parties.

        -- Step 3: Cascade to party sites for any failed party.
        UPDATE DMT_OWNER.DMT_HZ_PARTY_SITES_STG_TBL ps
        SET    STG_STATUS            = 'FAILED',
               ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(
                                       ERROR_TEXT,
                                       '[PRE_VALIDATION] Parent party ''' ||
                                       ps.PARTY_ORIG_SYSTEM_REFERENCE ||
                                       ''' failed validation — party site skipped.'),
               LAST_UPDATED_DATE = SYSDATE
        WHERE  ps.STG_STATUS IN ('NEW', 'RETRY')
        AND    EXISTS (
                   SELECT 1
                   FROM   DMT_OWNER.DMT_HZ_PARTIES_STG_TBL p
                   WHERE  p.PARTY_ORIG_SYSTEM_REFERENCE = ps.PARTY_ORIG_SYSTEM_REFERENCE
                   AND    p.STG_STATUS = 'FAILED'
                   AND    p.ERROR_TEXT LIKE '%[PRE_VALIDATION]%'
               );
        l_ps_failed := SQL%ROWCOUNT;

        -- Step 4: Cascade to party site uses for any failed party site.
        UPDATE DMT_OWNER.DMT_HZ_PARTY_SITE_USES_STG_TBL psu
        SET    STG_STATUS            = 'FAILED',
               ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(
                                       ERROR_TEXT,
                                       '[PRE_VALIDATION] Parent party site ''' ||
                                       psu.SITE_ORIG_SYSTEM_REFERENCE ||
                                       ''' failed validation — party site use skipped.'),
               LAST_UPDATED_DATE = SYSDATE
        WHERE  psu.STG_STATUS IN ('NEW', 'RETRY')
        AND    EXISTS (
                   SELECT 1
                   FROM   DMT_OWNER.DMT_HZ_PARTY_SITES_STG_TBL ps
                   WHERE  ps.SITE_ORIG_SYSTEM_REFERENCE = psu.SITE_ORIG_SYSTEM_REFERENCE
                   AND    ps.STG_STATUS = 'FAILED'
                   AND    ps.ERROR_TEXT LIKE '%[PRE_VALIDATION]%'
               );
        l_psu_failed := SQL%ROWCOUNT;

        -- Step 5: Cascade to accounts for any failed party.
        UPDATE DMT_OWNER.DMT_HZ_ACCOUNTS_STG_TBL a
        SET    STG_STATUS            = 'FAILED',
               ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(
                                       ERROR_TEXT,
                                       '[PRE_VALIDATION] Parent party ''' ||
                                       a.PARTY_ORIG_SYSTEM_REFERENCE ||
                                       ''' failed validation — account skipped.'),
               LAST_UPDATED_DATE = SYSDATE
        WHERE  a.STG_STATUS IN ('NEW', 'RETRY')
        AND    EXISTS (
                   SELECT 1
                   FROM   DMT_OWNER.DMT_HZ_PARTIES_STG_TBL p
                   WHERE  p.PARTY_ORIG_SYSTEM_REFERENCE = a.PARTY_ORIG_SYSTEM_REFERENCE
                   AND    p.STG_STATUS = 'FAILED'
                   AND    p.ERROR_TEXT LIKE '%[PRE_VALIDATION]%'
               );
        l_acct_failed := SQL%ROWCOUNT;

        -- Step 6: Cascade to account sites for any failed account.
        UPDATE DMT_OWNER.DMT_HZ_ACCT_SITES_STG_TBL acs
        SET    STG_STATUS            = 'FAILED',
               ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(
                                       ERROR_TEXT,
                                       '[PRE_VALIDATION] Parent account ''' ||
                                       acs.CUST_ORIG_SYSTEM_REFERENCE ||
                                       ''' failed validation — account site skipped.'),
               LAST_UPDATED_DATE = SYSDATE
        WHERE  acs.STG_STATUS IN ('NEW', 'RETRY')
        AND    EXISTS (
                   SELECT 1
                   FROM   DMT_OWNER.DMT_HZ_ACCOUNTS_STG_TBL a
                   WHERE  a.CUST_ORIG_SYSTEM_REFERENCE = acs.CUST_ORIG_SYSTEM_REFERENCE
                   AND    a.STG_STATUS = 'FAILED'
                   AND    a.ERROR_TEXT LIKE '%[PRE_VALIDATION]%'
               );
        l_as_failed := SQL%ROWCOUNT;

        -- Step 7: Cascade to account site uses for any failed account site.
        UPDATE DMT_OWNER.DMT_HZ_ACCT_SITE_USES_STG_TBL asu
        SET    STG_STATUS            = 'FAILED',
               ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(
                                       ERROR_TEXT,
                                       '[PRE_VALIDATION] Parent account site ''' ||
                                       asu.CUST_SITE_ORIG_SYS_REF ||
                                       ''' failed validation — account site use skipped.'),
               LAST_UPDATED_DATE = SYSDATE
        WHERE  asu.STG_STATUS IN ('NEW', 'RETRY')
        AND    EXISTS (
                   SELECT 1
                   FROM   DMT_OWNER.DMT_HZ_ACCT_SITES_STG_TBL acs
                   WHERE  acs.CUST_SITE_ORIG_SYS_REF = asu.CUST_SITE_ORIG_SYS_REF
                   AND    acs.STG_STATUS = 'FAILED'
                   AND    acs.ERROR_TEXT LIKE '%[PRE_VALIDATION]%'
               );
        l_asu_failed := SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_PRE_TRANSFORM complete. Pre-validation failures — ' ||
                                'Parties: ' || l_party_failed ||
                                ' | Locations: ' || l_loc_failed ||
                                ' | Party Sites: ' || l_ps_failed ||
                                ' | Party Site Uses: ' || l_psu_failed ||
                                ' | Accounts: ' || l_acct_failed ||
                                ' | Acct Sites: ' || l_as_failed ||
                                ' | Acct Site Uses: ' || l_asu_failed,
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_PRE_TRANSFORM');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'VALIDATE_PRE_TRANSFORM failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'VALIDATE_PRE_TRANSFORM');
            RAISE;
    END VALIDATE_PRE_TRANSFORM;


    -- --------------------------------------------------------
    -- VALIDATE_POST_TRANSFORM
    -- Data quality checks on TFM rows after transformation.
    -- Stub — no rules implemented yet.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    )
    IS
    BEGIN
        -- No post-transform validations implemented yet.
        -- Future: check COUNTRY required on locations, valid PARTY_TYPE values, etc.
        NULL;
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'VALIDATE_POST_TRANSFORM failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'VALIDATE_POST_TRANSFORM');
            RAISE;
    END VALIDATE_POST_TRANSFORM;

END DMT_CUST_VALIDATOR_PKG;
/
