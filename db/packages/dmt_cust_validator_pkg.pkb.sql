-- PACKAGE BODY DMT_CUST_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_CUST_VALIDATOR_PKG"
AS
-- ============================================================
-- DMT_CUST_VALIDATOR_PKG body
-- Customers pre- and post-transform validation.
-- Customers are top-level master data — no upstream dependency.
--
-- Pre-validation rejections are recorded in the run-stamped error table
-- DMT_OWNER.DMT_STG_TFM_ERROR_TBL (design §7); the STG rows keep their
-- status only (no message) and are flagged FAILED afterwards by the
-- standard FLAG_STG_FAILED helper. No validator writes ERROR_TEXT on a
-- *_STG_TBL row. The child cascades identify a failed parent by the
-- presence of its error row this run, not by a STG message.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_CUST_VALIDATOR_PKG';

    -- ============================================================
    -- FLAG_STG_FAILED — STANDARD helper (design §7). Marks every STG row FAILED
    -- (status only, no message) that has a DMT_STG_TFM_ERROR_TBL row for this run.
    -- The pre-validation checks record WHY in the error table; this sets the STG
    -- status so FAILED-mode reruns select on it. Byte-identical across validator
    -- packages except the STG table name(s) and the SUB_OBJECT filter (tagged EDIT
    -- regions), like SWEEP_UNACCOUNTED. Does NOT commit — the caller owns the txn.
    -- ============================================================
    PROCEDURE FLAG_STG_FAILED (p_run_id IN NUMBER) IS
    BEGIN
        -- <<EDIT-TABLE — the object's STG table. Repeat this whole UPDATE block
        --   (EDIT-TABLE through the ';') once per STG table the object owns.>>
        UPDATE DMT_OWNER.DMT_HZ_PARTIES_STG_TBL
        -- <<END EDIT-TABLE — everything below is FIXED until EDIT-SCOPE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','RETRY')
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE — this table's SUB_OBJECT>>
                                   AND SUB_OBJECT = 'Parties'
        -- <<END EDIT-SCOPE — nothing below this changes>>
                                  );

        -- <<EDIT-TABLE>>
        UPDATE DMT_OWNER.DMT_HZ_LOCATIONS_STG_TBL
        -- <<END EDIT-TABLE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','RETRY')
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE>>
                                   AND SUB_OBJECT = 'Locations'
        -- <<END EDIT-SCOPE>>
                                  );

        -- <<EDIT-TABLE>>
        UPDATE DMT_OWNER.DMT_HZ_PARTY_SITES_STG_TBL
        -- <<END EDIT-TABLE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','RETRY')
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE>>
                                   AND SUB_OBJECT = 'Party Sites'
        -- <<END EDIT-SCOPE>>
                                  );

        -- <<EDIT-TABLE>>
        UPDATE DMT_OWNER.DMT_HZ_PARTY_SITE_USES_STG_TBL
        -- <<END EDIT-TABLE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','RETRY')
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE>>
                                   AND SUB_OBJECT = 'Party Site Uses'
        -- <<END EDIT-SCOPE>>
                                  );

        -- <<EDIT-TABLE>>
        UPDATE DMT_OWNER.DMT_HZ_ACCOUNTS_STG_TBL
        -- <<END EDIT-TABLE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','RETRY')
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE>>
                                   AND SUB_OBJECT = 'Accounts'
        -- <<END EDIT-SCOPE>>
                                  );

        -- <<EDIT-TABLE>>
        UPDATE DMT_OWNER.DMT_HZ_ACCT_SITES_STG_TBL
        -- <<END EDIT-TABLE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','RETRY')
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE>>
                                   AND SUB_OBJECT = 'Account Sites'
        -- <<END EDIT-SCOPE>>
                                  );

        -- <<EDIT-TABLE>>
        UPDATE DMT_OWNER.DMT_HZ_ACCT_SITE_USES_STG_TBL
        -- <<END EDIT-TABLE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','RETRY')
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE>>
                                   AND SUB_OBJECT = 'Account Site Uses'
        -- <<END EDIT-SCOPE>>
                                  );
    END FLAG_STG_FAILED;

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
        INSERT INTO DMT_OWNER.DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'Customers', 'Parties', p.STG_SEQUENCE_ID,
               '[PRE_VALIDATION] PARTY_TYPE is required.'
        FROM   DMT_OWNER.DMT_HZ_PARTIES_STG_TBL p
        WHERE  p.STG_STATUS IN ('NEW', 'RETRY')
        AND    p.PARTY_TYPE IS NULL;
        l_party_failed := l_party_failed + SQL%ROWCOUNT;

        -- Step 1b: ORGANIZATION_NAME required when PARTY_TYPE = 'ORGANIZATION'.
        INSERT INTO DMT_OWNER.DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'Customers', 'Parties', p.STG_SEQUENCE_ID,
               '[PRE_VALIDATION] ORGANIZATION_NAME is required when PARTY_TYPE is ''ORGANIZATION''.'
        FROM   DMT_OWNER.DMT_HZ_PARTIES_STG_TBL p
        WHERE  p.STG_STATUS IN ('NEW', 'RETRY')
        AND    UPPER(p.PARTY_TYPE) = 'ORGANIZATION'
        AND    p.ORGANIZATION_NAME IS NULL;
        l_party_failed := l_party_failed + SQL%ROWCOUNT;

        -- Step 1c: PERSON_LAST_NAME required when PARTY_TYPE = 'PERSON'.
        INSERT INTO DMT_OWNER.DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'Customers', 'Parties', p.STG_SEQUENCE_ID,
               '[PRE_VALIDATION] PERSON_LAST_NAME is required when PARTY_TYPE is ''PERSON''.'
        FROM   DMT_OWNER.DMT_HZ_PARTIES_STG_TBL p
        WHERE  p.STG_STATUS IN ('NEW', 'RETRY')
        AND    UPPER(p.PARTY_TYPE) = 'PERSON'
        AND    p.PERSON_LAST_NAME IS NULL;
        l_party_failed := l_party_failed + SQL%ROWCOUNT;

        -- Step 1d: PARTY_ORIG_SYSTEM_REFERENCE is required (linking key).
        INSERT INTO DMT_OWNER.DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'Customers', 'Parties', p.STG_SEQUENCE_ID,
               '[PRE_VALIDATION] PARTY_ORIG_SYSTEM_REFERENCE is required.'
        FROM   DMT_OWNER.DMT_HZ_PARTIES_STG_TBL p
        WHERE  p.STG_STATUS IN ('NEW', 'RETRY')
        AND    p.PARTY_ORIG_SYSTEM_REFERENCE IS NULL;
        l_party_failed := l_party_failed + SQL%ROWCOUNT;

        -- Step 1e: BATCH_ID is required (customer batch / partition key). The
        -- loader partitions Customers by BATCH_ID and sends it as the first
        -- value of the BulkImportJob ParameterList; a row with no batch id
        -- can neither be split nor loaded.
        INSERT INTO DMT_OWNER.DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'Customers', 'Parties', p.STG_SEQUENCE_ID,
               '[PRE_VALIDATION] BATCH_ID is required (customer batch / partition key).'
        FROM   DMT_OWNER.DMT_HZ_PARTIES_STG_TBL p
        WHERE  p.STG_STATUS IN ('NEW', 'RETRY')
        AND    p.BATCH_ID IS NULL;
        l_party_failed := l_party_failed + SQL%ROWCOUNT;

        -- Step 1f: on EVERY non-Parties customer staging table, BATCH_ID must be
        -- present AND must match a Parties BATCH_ID in the same batch (scenario).
        -- Each table carries its own BATCH_ID independently to TFM, and the
        -- loader partitions strictly on the PARTIES BATCH_IDs while the generator
        -- filters children by BATCH_ID = <that party batch>. A child whose
        -- BATCH_ID is NULL -- or non-NULL but matching no Parties batch in the
        -- run -- would be excluded from every FBDI and never marked FAILED: a
        -- silent third outcome that violates Rule #1. Fail such rows here so the
        -- batch id can never diverge into an orphan. (Rows whose child ref points
        -- at the wrong party still reach Fusion and error there -- not silent.)
        INSERT INTO DMT_OWNER.DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'Customers', 'Locations', x.STG_SEQUENCE_ID,
               '[PRE_VALIDATION] BATCH_ID is required and must match a customer (party) BATCH_ID in the same batch.'
        FROM   DMT_OWNER.DMT_HZ_LOCATIONS_STG_TBL x
        WHERE  x.STG_STATUS IN ('NEW','RETRY')
        AND    (x.BATCH_ID IS NULL OR NOT EXISTS (SELECT 1 FROM DMT_OWNER.DMT_HZ_PARTIES_STG_TBL p WHERE p.SCENARIO_ID = x.SCENARIO_ID AND p.BATCH_ID = x.BATCH_ID));
        l_loc_failed := l_loc_failed + SQL%ROWCOUNT;

        INSERT INTO DMT_OWNER.DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'Customers', 'Party Sites', x.STG_SEQUENCE_ID,
               '[PRE_VALIDATION] BATCH_ID is required and must match a customer (party) BATCH_ID in the same batch.'
        FROM   DMT_OWNER.DMT_HZ_PARTY_SITES_STG_TBL x
        WHERE  x.STG_STATUS IN ('NEW','RETRY')
        AND    (x.BATCH_ID IS NULL OR NOT EXISTS (SELECT 1 FROM DMT_OWNER.DMT_HZ_PARTIES_STG_TBL p WHERE p.SCENARIO_ID = x.SCENARIO_ID AND p.BATCH_ID = x.BATCH_ID));
        l_ps_failed := l_ps_failed + SQL%ROWCOUNT;

        INSERT INTO DMT_OWNER.DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'Customers', 'Party Site Uses', x.STG_SEQUENCE_ID,
               '[PRE_VALIDATION] BATCH_ID is required and must match a customer (party) BATCH_ID in the same batch.'
        FROM   DMT_OWNER.DMT_HZ_PARTY_SITE_USES_STG_TBL x
        WHERE  x.STG_STATUS IN ('NEW','RETRY')
        AND    (x.BATCH_ID IS NULL OR NOT EXISTS (SELECT 1 FROM DMT_OWNER.DMT_HZ_PARTIES_STG_TBL p WHERE p.SCENARIO_ID = x.SCENARIO_ID AND p.BATCH_ID = x.BATCH_ID));
        l_psu_failed := l_psu_failed + SQL%ROWCOUNT;

        INSERT INTO DMT_OWNER.DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'Customers', 'Accounts', x.STG_SEQUENCE_ID,
               '[PRE_VALIDATION] BATCH_ID is required and must match a customer (party) BATCH_ID in the same batch.'
        FROM   DMT_OWNER.DMT_HZ_ACCOUNTS_STG_TBL x
        WHERE  x.STG_STATUS IN ('NEW','RETRY')
        AND    (x.BATCH_ID IS NULL OR NOT EXISTS (SELECT 1 FROM DMT_OWNER.DMT_HZ_PARTIES_STG_TBL p WHERE p.SCENARIO_ID = x.SCENARIO_ID AND p.BATCH_ID = x.BATCH_ID));
        l_acct_failed := l_acct_failed + SQL%ROWCOUNT;

        INSERT INTO DMT_OWNER.DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'Customers', 'Account Sites', x.STG_SEQUENCE_ID,
               '[PRE_VALIDATION] BATCH_ID is required and must match a customer (party) BATCH_ID in the same batch.'
        FROM   DMT_OWNER.DMT_HZ_ACCT_SITES_STG_TBL x
        WHERE  x.STG_STATUS IN ('NEW','RETRY')
        AND    (x.BATCH_ID IS NULL OR NOT EXISTS (SELECT 1 FROM DMT_OWNER.DMT_HZ_PARTIES_STG_TBL p WHERE p.SCENARIO_ID = x.SCENARIO_ID AND p.BATCH_ID = x.BATCH_ID));
        l_as_failed := l_as_failed + SQL%ROWCOUNT;

        INSERT INTO DMT_OWNER.DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'Customers', 'Account Site Uses', x.STG_SEQUENCE_ID,
               '[PRE_VALIDATION] BATCH_ID is required and must match a customer (party) BATCH_ID in the same batch.'
        FROM   DMT_OWNER.DMT_HZ_ACCT_SITE_USES_STG_TBL x
        WHERE  x.STG_STATUS IN ('NEW','RETRY')
        AND    (x.BATCH_ID IS NULL OR NOT EXISTS (SELECT 1 FROM DMT_OWNER.DMT_HZ_PARTIES_STG_TBL p WHERE p.SCENARIO_ID = x.SCENARIO_ID AND p.BATCH_ID = x.BATCH_ID));
        l_asu_failed := l_asu_failed + SQL%ROWCOUNT;

        -- Step 2: Cascade failures to locations for any failed party.
        -- Locations link to parties via PARTY_ORIG_SYSTEM_REFERENCE stored
        -- in related party_sites. For simplicity, locations are validated
        -- independently — they do not cascade from parties.

        -- Step 3: Cascade to party sites for any party rejected this run.
        -- A failed parent is one that has an error row for this run (§7);
        -- the cascade reads the error table, never a STG message.
        INSERT INTO DMT_OWNER.DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'Customers', 'Party Sites', ps.STG_SEQUENCE_ID,
               '[PRE_VALIDATION] Parent party ''' || ps.PARTY_ORIG_SYSTEM_REFERENCE ||
               ''' failed validation — party site skipped.'
        FROM   DMT_OWNER.DMT_HZ_PARTY_SITES_STG_TBL ps
        WHERE  ps.STG_STATUS IN ('NEW', 'RETRY')
        AND    NOT EXISTS (SELECT 1 FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL e0
                           WHERE e0.RUN_ID = p_run_id AND e0.SUB_OBJECT = 'Party Sites'
                           AND   e0.STG_SEQUENCE_ID = ps.STG_SEQUENCE_ID)
        AND    EXISTS (
                   SELECT 1
                   FROM   DMT_OWNER.DMT_HZ_PARTIES_STG_TBL p
                   JOIN   DMT_OWNER.DMT_STG_TFM_ERROR_TBL e
                          ON e.STG_SEQUENCE_ID = p.STG_SEQUENCE_ID
                         AND e.RUN_ID          = p_run_id
                         AND e.SUB_OBJECT      = 'Parties'
                   WHERE  p.PARTY_ORIG_SYSTEM_REFERENCE = ps.PARTY_ORIG_SYSTEM_REFERENCE
               );
        l_ps_failed := l_ps_failed + SQL%ROWCOUNT;

        -- Step 4: Cascade to party site uses for any party site rejected this run.
        INSERT INTO DMT_OWNER.DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'Customers', 'Party Site Uses', psu.STG_SEQUENCE_ID,
               '[PRE_VALIDATION] Parent party site ''' || psu.SITE_ORIG_SYSTEM_REFERENCE ||
               ''' failed validation — party site use skipped.'
        FROM   DMT_OWNER.DMT_HZ_PARTY_SITE_USES_STG_TBL psu
        WHERE  psu.STG_STATUS IN ('NEW', 'RETRY')
        AND    NOT EXISTS (SELECT 1 FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL e0
                           WHERE e0.RUN_ID = p_run_id AND e0.SUB_OBJECT = 'Party Site Uses'
                           AND   e0.STG_SEQUENCE_ID = psu.STG_SEQUENCE_ID)
        AND    EXISTS (
                   SELECT 1
                   FROM   DMT_OWNER.DMT_HZ_PARTY_SITES_STG_TBL ps
                   JOIN   DMT_OWNER.DMT_STG_TFM_ERROR_TBL e
                          ON e.STG_SEQUENCE_ID = ps.STG_SEQUENCE_ID
                         AND e.RUN_ID          = p_run_id
                         AND e.SUB_OBJECT      = 'Party Sites'
                   WHERE  ps.SITE_ORIG_SYSTEM_REFERENCE = psu.SITE_ORIG_SYSTEM_REFERENCE
               );
        l_psu_failed := l_psu_failed + SQL%ROWCOUNT;

        -- Step 5: Cascade to accounts for any party rejected this run.
        INSERT INTO DMT_OWNER.DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'Customers', 'Accounts', a.STG_SEQUENCE_ID,
               '[PRE_VALIDATION] Parent party ''' || a.PARTY_ORIG_SYSTEM_REFERENCE ||
               ''' failed validation — account skipped.'
        FROM   DMT_OWNER.DMT_HZ_ACCOUNTS_STG_TBL a
        WHERE  a.STG_STATUS IN ('NEW', 'RETRY')
        AND    NOT EXISTS (SELECT 1 FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL e0
                           WHERE e0.RUN_ID = p_run_id AND e0.SUB_OBJECT = 'Accounts'
                           AND   e0.STG_SEQUENCE_ID = a.STG_SEQUENCE_ID)
        AND    EXISTS (
                   SELECT 1
                   FROM   DMT_OWNER.DMT_HZ_PARTIES_STG_TBL p
                   JOIN   DMT_OWNER.DMT_STG_TFM_ERROR_TBL e
                          ON e.STG_SEQUENCE_ID = p.STG_SEQUENCE_ID
                         AND e.RUN_ID          = p_run_id
                         AND e.SUB_OBJECT      = 'Parties'
                   WHERE  p.PARTY_ORIG_SYSTEM_REFERENCE = a.PARTY_ORIG_SYSTEM_REFERENCE
               );
        l_acct_failed := l_acct_failed + SQL%ROWCOUNT;

        -- Step 6: Cascade to account sites for any account rejected this run.
        INSERT INTO DMT_OWNER.DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'Customers', 'Account Sites', acs.STG_SEQUENCE_ID,
               '[PRE_VALIDATION] Parent account ''' || acs.CUST_ORIG_SYSTEM_REFERENCE ||
               ''' failed validation — account site skipped.'
        FROM   DMT_OWNER.DMT_HZ_ACCT_SITES_STG_TBL acs
        WHERE  acs.STG_STATUS IN ('NEW', 'RETRY')
        AND    NOT EXISTS (SELECT 1 FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL e0
                           WHERE e0.RUN_ID = p_run_id AND e0.SUB_OBJECT = 'Account Sites'
                           AND   e0.STG_SEQUENCE_ID = acs.STG_SEQUENCE_ID)
        AND    EXISTS (
                   SELECT 1
                   FROM   DMT_OWNER.DMT_HZ_ACCOUNTS_STG_TBL a
                   JOIN   DMT_OWNER.DMT_STG_TFM_ERROR_TBL e
                          ON e.STG_SEQUENCE_ID = a.STG_SEQUENCE_ID
                         AND e.RUN_ID          = p_run_id
                         AND e.SUB_OBJECT      = 'Accounts'
                   WHERE  a.CUST_ORIG_SYSTEM_REFERENCE = acs.CUST_ORIG_SYSTEM_REFERENCE
               );
        l_as_failed := l_as_failed + SQL%ROWCOUNT;

        -- Step 7: Cascade to account site uses for any account site rejected this run.
        INSERT INTO DMT_OWNER.DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'Customers', 'Account Site Uses', asu.STG_SEQUENCE_ID,
               '[PRE_VALIDATION] Parent account site ''' || asu.CUST_SITE_ORIG_SYS_REF ||
               ''' failed validation — account site use skipped.'
        FROM   DMT_OWNER.DMT_HZ_ACCT_SITE_USES_STG_TBL asu
        WHERE  asu.STG_STATUS IN ('NEW', 'RETRY')
        AND    NOT EXISTS (SELECT 1 FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL e0
                           WHERE e0.RUN_ID = p_run_id AND e0.SUB_OBJECT = 'Account Site Uses'
                           AND   e0.STG_SEQUENCE_ID = asu.STG_SEQUENCE_ID)
        AND    EXISTS (
                   SELECT 1
                   FROM   DMT_OWNER.DMT_HZ_ACCT_SITES_STG_TBL acs
                   JOIN   DMT_OWNER.DMT_STG_TFM_ERROR_TBL e
                          ON e.STG_SEQUENCE_ID = acs.STG_SEQUENCE_ID
                         AND e.RUN_ID          = p_run_id
                         AND e.SUB_OBJECT      = 'Account Sites'
                   WHERE  acs.CUST_SITE_ORIG_SYS_REF = asu.CUST_SITE_ORIG_SYS_REF
               );
        l_asu_failed := l_asu_failed + SQL%ROWCOUNT;

        -- Standard final step: flag the STG rows FAILED from the recorded error
        -- rows (status only, no message) so FAILED-mode reruns select on them (§7).
        FLAG_STG_FAILED(p_run_id);

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
