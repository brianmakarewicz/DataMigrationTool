-- PACKAGE BODY DMT_CUST_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_CUST_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_CUST_TRANSFORM_PKG Body
-- Customers: 7 transform procedures (one per object type).
-- Applies run prefix to PARTY_NUMBER, ACCOUNT_NUMBER, and
-- all ORIG_SYSTEM_REFERENCE values. Sets BATCH_ID = run_id.
-- Sets PARTY_ORIG_SYSTEM = 'DMT'.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_CUST_TRANSFORM_PKG';

    -- --------------------------------------------------------
    -- Private: read run prefix from CONVERSION_MASTER
    -- --------------------------------------------------------
    FUNCTION get_prefix (p_run_id IN NUMBER) RETURN VARCHAR2 IS
        l_prefix VARCHAR2(30);
    BEGIN
        SELECT PREFIX
        INTO   l_prefix
        FROM   DMT_OWNER.DMT_PIPELINE_RUN_TBL
        WHERE  RUN_ID = p_run_id;
        RETURN l_prefix;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001,
                'RUN_ID ' || p_run_id || ' not found in DMT_PIPELINE_RUN_TBL');
    END get_prefix;

    -- --------------------------------------------------------
    -- Private: read dependent prefix from CONVERSION_MASTER
    -- --------------------------------------------------------
    FUNCTION get_dep_prefix (p_run_id IN NUMBER) RETURN VARCHAR2 IS
        l_dep_prefix VARCHAR2(30);
    BEGIN
        SELECT PREFIX
        INTO   l_dep_prefix
        FROM   DMT_OWNER.DMT_PIPELINE_RUN_TBL
        WHERE  RUN_ID = p_run_id;
        RETURN l_dep_prefix;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001,
                'RUN_ID ' || p_run_id || ' not found in DMT_PIPELINE_RUN_TBL');
    END get_dep_prefix;


    -- ============================================================
    -- TRANSFORM_PARTIES
    -- ============================================================
    PROCEDURE TRANSFORM_PARTIES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_prefix        VARCHAR2(30);
        l_ok_count      NUMBER := 0;
        l_fail_count    NUMBER := 0;

    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_PARTIES start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_PARTIES');

        l_prefix := get_prefix(p_run_id);


        -- Accumulate, never overwrite (design section 5): ERROR_TEXT is
        -- append-only. The former reprocess-time ERROR_TEXT reset -- a write
        -- back to staging that also blanked accumulated errors -- is removed
        -- (mirrors the Stage D Suppliers transform conformance fix). The
        -- FAILED reselection below stays scenario-scoped via p_scenario_id.

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_OWNER.DMT_HZ_PARTIES_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    FBDI_CSV_ID,
                    BATCH_ID,
                    PARTY_ORIG_SYSTEM,
                    PARTY_ORIG_SYSTEM_REFERENCE,
                    INSERT_UPDATE_FLAG,
                    PARTY_TYPE,
                    PARTY_NUMBER,
                    SALUTATION,
                    PARTY_USAGE_CODE,
                    JGZZ_FISCAL_CODE,
                    ORGANIZATION_NAME,
                    DUNS_NUMBER_C,
                    PERSON_FIRST_NAME,
                    PERSON_LAST_NAME,
                    PERSON_LAST_NAME_PREFIX,
                    PERSON_SECOND_LAST_NAME,
                    PERSON_MIDDLE_NAME,
                    PERSON_NAME_SUFFIX,
                    PERSON_TITLE,
                    ATTRIBUTE_CATEGORY,
                    ATTRIBUTE1,  ATTRIBUTE2,  ATTRIBUTE3,  ATTRIBUTE4,  ATTRIBUTE5,
                    ATTRIBUTE6,  ATTRIBUTE7,  ATTRIBUTE8,  ATTRIBUTE9,  ATTRIBUTE10,
                    ATTRIBUTE11, ATTRIBUTE12, ATTRIBUTE13, ATTRIBUTE14, ATTRIBUTE15,
                    ATTRIBUTE16, ATTRIBUTE17, ATTRIBUTE18, ATTRIBUTE19, ATTRIBUTE20,
                    TFM_STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    NULL,
                    p_run_id,
                    'DMT',
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.PARTY_ORIG_SYSTEM_REFERENCE),
                    s.INSERT_UPDATE_FLAG,
                    s.PARTY_TYPE,
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.PARTY_NUMBER, 30),
                    s.SALUTATION,
                    s.PARTY_USAGE_CODE,
                    s.JGZZ_FISCAL_CODE,
                    s.ORGANIZATION_NAME,
                    s.DUNS_NUMBER_C,
                    s.PERSON_FIRST_NAME,
                    s.PERSON_LAST_NAME,
                    s.PERSON_LAST_NAME_PREFIX,
                    s.PERSON_SECOND_LAST_NAME,
                    s.PERSON_MIDDLE_NAME,
                    s.PERSON_NAME_SUFFIX,
                    s.PERSON_TITLE,
                    s.ATTRIBUTE_CATEGORY,
                    s.ATTRIBUTE1,  s.ATTRIBUTE2,  s.ATTRIBUTE3,  s.ATTRIBUTE4,  s.ATTRIBUTE5,
                    s.ATTRIBUTE6,  s.ATTRIBUTE7,  s.ATTRIBUTE8,  s.ATTRIBUTE9,  s.ATTRIBUTE10,
                    s.ATTRIBUTE11, s.ATTRIBUTE12, s.ATTRIBUTE13, s.ATTRIBUTE14, s.ATTRIBUTE15,
                    s.ATTRIBUTE16, s.ATTRIBUTE17, s.ATTRIBUTE18, s.ATTRIBUTE19, s.ATTRIBUTE20,
                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_HZ_PARTIES_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_HZ_PARTIES_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_OWNER.DMT_HZ_PARTIES_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_HZ_PARTIES_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_PARTIES complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_PARTIES');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_PARTIES failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_PARTIES',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_PARTIES;


    -- ============================================================
    -- TRANSFORM_LOCATIONS
    -- ============================================================
    PROCEDURE TRANSFORM_LOCATIONS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_prefix        VARCHAR2(30);
        l_ok_count      NUMBER := 0;
        l_fail_count    NUMBER := 0;

    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_LOCATIONS start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_LOCATIONS');

        l_prefix := get_prefix(p_run_id);


        -- Accumulate, never overwrite (design section 5): ERROR_TEXT is
        -- append-only. The former reprocess-time ERROR_TEXT reset -- a write
        -- back to staging that also blanked accumulated errors -- is removed
        -- (mirrors the Stage D Suppliers transform conformance fix). The
        -- FAILED reselection below stays scenario-scoped via p_scenario_id.

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_OWNER.DMT_HZ_LOCATIONS_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    FBDI_CSV_ID,
                    BATCH_ID,
                    LOCATION_ORIG_SYSTEM,
                    LOCATION_ORIG_SYSTEM_REFERENCE,
                    INSERT_UPDATE_FLAG,
                    COUNTRY,
                    ADDRESS1,
                    ADDRESS2,
                    ADDRESS3,
                    ADDRESS4,
                    CITY,
                    STATE,
                    PROVINCE,
                    COUNTY,
                    POSTAL_CODE,
                    POSTAL_PLUS4_CODE,
                    LOCATION_LANGUAGE,
                    DESCRIPTION,
                    SHORT_DESCRIPTION,
                    SALES_TAX_GEOCODE,
                    SALES_TAX_INSIDE_CITY_LIMITS,
                    TIMEZONE_CODE,
                    ADDRESS1_STD,
                    ADAPTER_CONTENT_SOURCE,
                    ADDR_VALID_STATUS_CODE,
                    DATE_VALIDATED,
                    ADDRESS_EFFECTIVE_DATE,
                    ADDRESS_EXPIRATION_DATE,
                    VALIDATED_FLAG,
                    DO_NOT_VALIDATE_FLAG,
                    ATTRIBUTE_CATEGORY,
                    ATTRIBUTE1,  ATTRIBUTE2,  ATTRIBUTE3,  ATTRIBUTE4,  ATTRIBUTE5,
                    ATTRIBUTE6,  ATTRIBUTE7,  ATTRIBUTE8,  ATTRIBUTE9,  ATTRIBUTE10,
                    ATTRIBUTE11, ATTRIBUTE12, ATTRIBUTE13, ATTRIBUTE14, ATTRIBUTE15,
                    ATTRIBUTE16, ATTRIBUTE17, ATTRIBUTE18, ATTRIBUTE19, ATTRIBUTE20,
                    TFM_STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    NULL,
                    p_run_id,
                    'DMT',
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.LOCATION_ORIG_SYSTEM_REFERENCE),
                    s.INSERT_UPDATE_FLAG,
                    s.COUNTRY,
                    s.ADDRESS1,
                    s.ADDRESS2,
                    s.ADDRESS3,
                    s.ADDRESS4,
                    s.CITY,
                    s.STATE,
                    s.PROVINCE,
                    s.COUNTY,
                    s.POSTAL_CODE,
                    s.POSTAL_PLUS4_CODE,
                    s.LOCATION_LANGUAGE,
                    s.DESCRIPTION,
                    s.SHORT_DESCRIPTION,
                    s.SALES_TAX_GEOCODE,
                    s.SALES_TAX_INSIDE_CITY_LIMITS,
                    s.TIMEZONE_CODE,
                    s.ADDRESS1_STD,
                    s.ADAPTER_CONTENT_SOURCE,
                    s.ADDR_VALID_STATUS_CODE,
                    s.DATE_VALIDATED,
                    s.ADDRESS_EFFECTIVE_DATE,
                    s.ADDRESS_EXPIRATION_DATE,
                    s.VALIDATED_FLAG,
                    s.DO_NOT_VALIDATE_FLAG,
                    s.ATTRIBUTE_CATEGORY,
                    s.ATTRIBUTE1,  s.ATTRIBUTE2,  s.ATTRIBUTE3,  s.ATTRIBUTE4,  s.ATTRIBUTE5,
                    s.ATTRIBUTE6,  s.ATTRIBUTE7,  s.ATTRIBUTE8,  s.ATTRIBUTE9,  s.ATTRIBUTE10,
                    s.ATTRIBUTE11, s.ATTRIBUTE12, s.ATTRIBUTE13, s.ATTRIBUTE14, s.ATTRIBUTE15,
                    s.ATTRIBUTE16, s.ATTRIBUTE17, s.ATTRIBUTE18, s.ATTRIBUTE19, s.ATTRIBUTE20,
                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_HZ_LOCATIONS_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_HZ_LOCATIONS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_OWNER.DMT_HZ_LOCATIONS_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_HZ_LOCATIONS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_LOCATIONS complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_LOCATIONS');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_LOCATIONS failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_LOCATIONS',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_LOCATIONS;


    -- ============================================================
    -- TRANSFORM_PARTY_SITES
    -- ============================================================
    PROCEDURE TRANSFORM_PARTY_SITES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_prefix        VARCHAR2(30);
        l_ok_count      NUMBER := 0;
        l_fail_count    NUMBER := 0;

    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_PARTY_SITES start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_PARTY_SITES');

        l_prefix := get_prefix(p_run_id);


        -- Accumulate, never overwrite (design section 5): ERROR_TEXT is
        -- append-only. The former reprocess-time ERROR_TEXT reset -- a write
        -- back to staging that also blanked accumulated errors -- is removed
        -- (mirrors the Stage D Suppliers transform conformance fix). The
        -- FAILED reselection below stays scenario-scoped via p_scenario_id.

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_OWNER.DMT_HZ_PARTY_SITES_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    FBDI_CSV_ID,
                    BATCH_ID,
                    PARTY_ORIG_SYSTEM,
                    PARTY_ORIG_SYSTEM_REFERENCE,
                    SITE_ORIG_SYSTEM,
                    SITE_ORIG_SYSTEM_REFERENCE,
                    LOCATION_ORIG_SYSTEM,
                    LOCATION_ORIG_SYSTEM_REFERENCE,
                    INSERT_UPDATE_FLAG,
                    PARTY_SITE_NAME,
                    PARTY_SITE_NUMBER,
                    START_DATE_ACTIVE,
                    END_DATE_ACTIVE,
                    MAILSTOP,
                    IDENTIFYING_ADDRESS_FLAG,
                    PARTY_SITE_LANGUAGE,
                    REL_ORIG_SYSTEM,
                    REL_ORIG_SYSTEM_REFERENCE,
                    ATTRIBUTE_CATEGORY,
                    ATTRIBUTE1,  ATTRIBUTE2,  ATTRIBUTE3,  ATTRIBUTE4,  ATTRIBUTE5,
                    ATTRIBUTE6,  ATTRIBUTE7,  ATTRIBUTE8,  ATTRIBUTE9,  ATTRIBUTE10,
                    ATTRIBUTE11, ATTRIBUTE12, ATTRIBUTE13, ATTRIBUTE14, ATTRIBUTE15,
                    ATTRIBUTE16, ATTRIBUTE17, ATTRIBUTE18, ATTRIBUTE19, ATTRIBUTE20,
                    TFM_STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    NULL,
                    p_run_id,
                    'DMT',
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.PARTY_ORIG_SYSTEM_REFERENCE),
                    'DMT',
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.SITE_ORIG_SYSTEM_REFERENCE),
                    'DMT',
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.LOCATION_ORIG_SYSTEM_REFERENCE),
                    s.INSERT_UPDATE_FLAG,
                    s.PARTY_SITE_NAME,
                    s.PARTY_SITE_NUMBER,
                    s.START_DATE_ACTIVE,
                    s.END_DATE_ACTIVE,
                    s.MAILSTOP,
                    s.IDENTIFYING_ADDRESS_FLAG,
                    s.PARTY_SITE_LANGUAGE,
                    s.REL_ORIG_SYSTEM,
                    s.REL_ORIG_SYSTEM_REFERENCE,
                    s.ATTRIBUTE_CATEGORY,
                    s.ATTRIBUTE1,  s.ATTRIBUTE2,  s.ATTRIBUTE3,  s.ATTRIBUTE4,  s.ATTRIBUTE5,
                    s.ATTRIBUTE6,  s.ATTRIBUTE7,  s.ATTRIBUTE8,  s.ATTRIBUTE9,  s.ATTRIBUTE10,
                    s.ATTRIBUTE11, s.ATTRIBUTE12, s.ATTRIBUTE13, s.ATTRIBUTE14, s.ATTRIBUTE15,
                    s.ATTRIBUTE16, s.ATTRIBUTE17, s.ATTRIBUTE18, s.ATTRIBUTE19, s.ATTRIBUTE20,
                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_HZ_PARTY_SITES_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_HZ_PARTY_SITES_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_OWNER.DMT_HZ_PARTY_SITES_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_HZ_PARTY_SITES_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_PARTY_SITES complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_PARTY_SITES');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_PARTY_SITES failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_PARTY_SITES',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_PARTY_SITES;


    -- ============================================================
    -- TRANSFORM_PARTY_SITE_USES
    -- ============================================================
    PROCEDURE TRANSFORM_PARTY_SITE_USES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_prefix        VARCHAR2(30);
        l_ok_count      NUMBER := 0;
        l_fail_count    NUMBER := 0;

    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_PARTY_SITE_USES start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_PARTY_SITE_USES');

        l_prefix := get_prefix(p_run_id);


        -- Accumulate, never overwrite (design section 5): ERROR_TEXT is
        -- append-only. The former reprocess-time ERROR_TEXT reset -- a write
        -- back to staging that also blanked accumulated errors -- is removed
        -- (mirrors the Stage D Suppliers transform conformance fix). The
        -- FAILED reselection below stays scenario-scoped via p_scenario_id.

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_OWNER.DMT_HZ_PARTY_SITE_USES_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    FBDI_CSV_ID,
                    BATCH_ID,
                    PARTY_ORIG_SYSTEM,
                    PARTY_ORIG_SYSTEM_REFERENCE,
                    SITE_ORIG_SYSTEM,
                    SITE_ORIG_SYSTEM_REFERENCE,
                    SITE_USE_TYPE,
                    PRIMARY_FLAG,
                    INSERT_UPDATE_FLAG,
                    START_DATE,
                    END_DATE,
                    SITEUSE_ORIG_SYSTEM,
                    SITEUSE_ORIG_SYSTEM_REF,
                    ATTRIBUTE_CATEGORY,
                    ATTRIBUTE1,  ATTRIBUTE2,  ATTRIBUTE3,  ATTRIBUTE4,  ATTRIBUTE5,
                    ATTRIBUTE6,  ATTRIBUTE7,  ATTRIBUTE8,  ATTRIBUTE9,  ATTRIBUTE10,
                    ATTRIBUTE11, ATTRIBUTE12, ATTRIBUTE13, ATTRIBUTE14, ATTRIBUTE15,
                    ATTRIBUTE16, ATTRIBUTE17, ATTRIBUTE18, ATTRIBUTE19, ATTRIBUTE20,
                    TFM_STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    NULL,
                    p_run_id,
                    'DMT',
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.PARTY_ORIG_SYSTEM_REFERENCE),
                    'DMT',
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.SITE_ORIG_SYSTEM_REFERENCE),
                    s.SITE_USE_TYPE,
                    s.PRIMARY_FLAG,
                    s.INSERT_UPDATE_FLAG,
                    s.START_DATE,
                    s.END_DATE,
                    'DMT',
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.SITEUSE_ORIG_SYSTEM_REF),
                    s.ATTRIBUTE_CATEGORY,
                    s.ATTRIBUTE1,  s.ATTRIBUTE2,  s.ATTRIBUTE3,  s.ATTRIBUTE4,  s.ATTRIBUTE5,
                    s.ATTRIBUTE6,  s.ATTRIBUTE7,  s.ATTRIBUTE8,  s.ATTRIBUTE9,  s.ATTRIBUTE10,
                    s.ATTRIBUTE11, s.ATTRIBUTE12, s.ATTRIBUTE13, s.ATTRIBUTE14, s.ATTRIBUTE15,
                    s.ATTRIBUTE16, s.ATTRIBUTE17, s.ATTRIBUTE18, s.ATTRIBUTE19, s.ATTRIBUTE20,
                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_HZ_PARTY_SITE_USES_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_HZ_PARTY_SITE_USES_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_OWNER.DMT_HZ_PARTY_SITE_USES_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_HZ_PARTY_SITE_USES_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_PARTY_SITE_USES complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_PARTY_SITE_USES');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_PARTY_SITE_USES failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_PARTY_SITE_USES',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_PARTY_SITE_USES;


    -- ============================================================
    -- TRANSFORM_ACCOUNTS
    -- ============================================================
    PROCEDURE TRANSFORM_ACCOUNTS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_prefix        VARCHAR2(30);
        l_ok_count      NUMBER := 0;
        l_fail_count    NUMBER := 0;

    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_ACCOUNTS start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_ACCOUNTS');

        l_prefix := get_prefix(p_run_id);


        -- Accumulate, never overwrite (design section 5): ERROR_TEXT is
        -- append-only. The former reprocess-time ERROR_TEXT reset -- a write
        -- back to staging that also blanked accumulated errors -- is removed
        -- (mirrors the Stage D Suppliers transform conformance fix). The
        -- FAILED reselection below stays scenario-scoped via p_scenario_id.

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_OWNER.DMT_HZ_ACCOUNTS_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    FBDI_CSV_ID,
                    BATCH_ID,
                    CUST_ORIG_SYSTEM,
                    CUST_ORIG_SYSTEM_REFERENCE,
                    PARTY_ORIG_SYSTEM,
                    PARTY_ORIG_SYSTEM_REFERENCE,
                    ACCOUNT_NUMBER,
                    INSERT_UPDATE_FLAG,
                    CUSTOMER_TYPE,
                    CUSTOMER_CLASS_CODE,
                    ACCOUNT_NAME,
                    ACCOUNT_ESTABLISHED_DATE,
                    ATTRIBUTE_CATEGORY,
                    ATTRIBUTE1,  ATTRIBUTE2,  ATTRIBUTE3,  ATTRIBUTE4,  ATTRIBUTE5,
                    ATTRIBUTE6,  ATTRIBUTE7,  ATTRIBUTE8,  ATTRIBUTE9,  ATTRIBUTE10,
                    ATTRIBUTE11, ATTRIBUTE12, ATTRIBUTE13, ATTRIBUTE14, ATTRIBUTE15,
                    ATTRIBUTE16, ATTRIBUTE17, ATTRIBUTE18, ATTRIBUTE19, ATTRIBUTE20,
                    ACCOUNT_TERMINATION_DATE,
                    TFM_STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    NULL,
                    p_run_id,
                    'DMT',
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.CUST_ORIG_SYSTEM_REFERENCE),
                    'DMT',
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.PARTY_ORIG_SYSTEM_REFERENCE),
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.ACCOUNT_NUMBER, 30),
                    s.INSERT_UPDATE_FLAG,
                    s.CUSTOMER_TYPE,
                    s.CUSTOMER_CLASS_CODE,
                    s.ACCOUNT_NAME,
                    s.ACCOUNT_ESTABLISHED_DATE,
                    s.ATTRIBUTE_CATEGORY,
                    s.ATTRIBUTE1,  s.ATTRIBUTE2,  s.ATTRIBUTE3,  s.ATTRIBUTE4,  s.ATTRIBUTE5,
                    s.ATTRIBUTE6,  s.ATTRIBUTE7,  s.ATTRIBUTE8,  s.ATTRIBUTE9,  s.ATTRIBUTE10,
                    s.ATTRIBUTE11, s.ATTRIBUTE12, s.ATTRIBUTE13, s.ATTRIBUTE14, s.ATTRIBUTE15,
                    s.ATTRIBUTE16, s.ATTRIBUTE17, s.ATTRIBUTE18, s.ATTRIBUTE19, s.ATTRIBUTE20,
                    s.ACCOUNT_TERMINATION_DATE,
                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_HZ_ACCOUNTS_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_HZ_ACCOUNTS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_OWNER.DMT_HZ_ACCOUNTS_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_HZ_ACCOUNTS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_ACCOUNTS complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_ACCOUNTS');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_ACCOUNTS failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_ACCOUNTS',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_ACCOUNTS;


    -- ============================================================
    -- TRANSFORM_ACCT_SITES
    -- ============================================================
    PROCEDURE TRANSFORM_ACCT_SITES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_prefix        VARCHAR2(30);
        l_ok_count      NUMBER := 0;
        l_fail_count    NUMBER := 0;

    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_ACCT_SITES start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_ACCT_SITES');

        l_prefix := get_prefix(p_run_id);


        -- Accumulate, never overwrite (design section 5): ERROR_TEXT is
        -- append-only. The former reprocess-time ERROR_TEXT reset -- a write
        -- back to staging that also blanked accumulated errors -- is removed
        -- (mirrors the Stage D Suppliers transform conformance fix). The
        -- FAILED reselection below stays scenario-scoped via p_scenario_id.

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_OWNER.DMT_HZ_ACCT_SITES_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    FBDI_CSV_ID,
                    BATCH_ID,
                    CUST_ORIG_SYSTEM,
                    CUST_ORIG_SYSTEM_REFERENCE,
                    CUST_SITE_ORIG_SYSTEM,
                    CUST_SITE_ORIG_SYS_REF,
                    SITE_ORIG_SYSTEM,
                    SITE_ORIG_SYSTEM_REFERENCE,
                    ACCT_SITE_LANGUAGE,
                    INSERT_UPDATE_FLAG,
                    CUSTOMER_CATEGORY_CODE,
                    TRANSLATED_CUSTOMER_NAME,
                    SET_CODE,
                    START_DATE,
                    END_DATE,
                    KEY_ACCOUNT_FLAG,
                    ACCOUNT_NUMBER,
                    PARTY_SITE_NUMBER,
                    ATTRIBUTE_CATEGORY,
                    ATTRIBUTE1,  ATTRIBUTE2,  ATTRIBUTE3,  ATTRIBUTE4,  ATTRIBUTE5,
                    ATTRIBUTE6,  ATTRIBUTE7,  ATTRIBUTE8,  ATTRIBUTE9,  ATTRIBUTE10,
                    ATTRIBUTE11, ATTRIBUTE12, ATTRIBUTE13, ATTRIBUTE14, ATTRIBUTE15,
                    ATTRIBUTE16, ATTRIBUTE17, ATTRIBUTE18, ATTRIBUTE19, ATTRIBUTE20,
                    TFM_STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    NULL,
                    p_run_id,
                    'DMT',
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.CUST_ORIG_SYSTEM_REFERENCE),
                    'DMT',
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.CUST_SITE_ORIG_SYS_REF),
                    'DMT',
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.SITE_ORIG_SYSTEM_REFERENCE),
                    s.ACCT_SITE_LANGUAGE,
                    s.INSERT_UPDATE_FLAG,
                    s.CUSTOMER_CATEGORY_CODE,
                    s.TRANSLATED_CUSTOMER_NAME,
                    s.SET_CODE,
                    s.START_DATE,
                    s.END_DATE,
                    s.KEY_ACCOUNT_FLAG,
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.ACCOUNT_NUMBER, 30),
                    s.PARTY_SITE_NUMBER,
                    s.ATTRIBUTE_CATEGORY,
                    s.ATTRIBUTE1,  s.ATTRIBUTE2,  s.ATTRIBUTE3,  s.ATTRIBUTE4,  s.ATTRIBUTE5,
                    s.ATTRIBUTE6,  s.ATTRIBUTE7,  s.ATTRIBUTE8,  s.ATTRIBUTE9,  s.ATTRIBUTE10,
                    s.ATTRIBUTE11, s.ATTRIBUTE12, s.ATTRIBUTE13, s.ATTRIBUTE14, s.ATTRIBUTE15,
                    s.ATTRIBUTE16, s.ATTRIBUTE17, s.ATTRIBUTE18, s.ATTRIBUTE19, s.ATTRIBUTE20,
                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_HZ_ACCT_SITES_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_HZ_ACCT_SITES_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_OWNER.DMT_HZ_ACCT_SITES_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_HZ_ACCT_SITES_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_ACCT_SITES complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_ACCT_SITES');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_ACCT_SITES failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_ACCT_SITES',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_ACCT_SITES;


    -- ============================================================
    -- TRANSFORM_ACCT_SITE_USES
    -- ============================================================
    PROCEDURE TRANSFORM_ACCT_SITE_USES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_prefix        VARCHAR2(30);
        l_ok_count      NUMBER := 0;
        l_fail_count    NUMBER := 0;

    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_ACCT_SITE_USES start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_ACCT_SITE_USES');

        l_prefix := get_prefix(p_run_id);


        -- Accumulate, never overwrite (design section 5): ERROR_TEXT is
        -- append-only. The former reprocess-time ERROR_TEXT reset -- a write
        -- back to staging that also blanked accumulated errors -- is removed
        -- (mirrors the Stage D Suppliers transform conformance fix). The
        -- FAILED reselection below stays scenario-scoped via p_scenario_id.

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_OWNER.DMT_HZ_ACCT_SITE_USES_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    FBDI_CSV_ID,
                    BATCH_ID,
                    CUST_SITE_ORIG_SYSTEM,
                    CUST_SITE_ORIG_SYS_REF,
                    CUST_SITEUSE_ORIG_SYSTEM,
                    CUST_SITEUSE_ORIG_SYS_REF,
                    SITE_USE_CODE,
                    PRIMARY_FLAG,
                    INSERT_UPDATE_FLAG,
                    LOCATION,
                    SET_CODE,
                    START_DATE,
                    END_DATE,
                    ACCOUNT_NUMBER,
                    PARTY_SITE_NUMBER,
                    ATTRIBUTE_CATEGORY,
                    ATTRIBUTE1,  ATTRIBUTE2,  ATTRIBUTE3,  ATTRIBUTE4,  ATTRIBUTE5,
                    ATTRIBUTE6,  ATTRIBUTE7,  ATTRIBUTE8,  ATTRIBUTE9,  ATTRIBUTE10,
                    ATTRIBUTE11, ATTRIBUTE12, ATTRIBUTE13, ATTRIBUTE14, ATTRIBUTE15,
                    ATTRIBUTE16, ATTRIBUTE17, ATTRIBUTE18, ATTRIBUTE19, ATTRIBUTE20,
                    TFM_STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    NULL,
                    p_run_id,
                    'DMT',
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.CUST_SITE_ORIG_SYS_REF),
                    'DMT',
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.CUST_SITEUSE_ORIG_SYS_REF),
                    s.SITE_USE_CODE,
                    s.PRIMARY_FLAG,
                    s.INSERT_UPDATE_FLAG,
                    s.LOCATION,
                    s.SET_CODE,
                    s.START_DATE,
                    s.END_DATE,
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.ACCOUNT_NUMBER, 30),
                    s.PARTY_SITE_NUMBER,
                    s.ATTRIBUTE_CATEGORY,
                    s.ATTRIBUTE1,  s.ATTRIBUTE2,  s.ATTRIBUTE3,  s.ATTRIBUTE4,  s.ATTRIBUTE5,
                    s.ATTRIBUTE6,  s.ATTRIBUTE7,  s.ATTRIBUTE8,  s.ATTRIBUTE9,  s.ATTRIBUTE10,
                    s.ATTRIBUTE11, s.ATTRIBUTE12, s.ATTRIBUTE13, s.ATTRIBUTE14, s.ATTRIBUTE15,
                    s.ATTRIBUTE16, s.ATTRIBUTE17, s.ATTRIBUTE18, s.ATTRIBUTE19, s.ATTRIBUTE20,
                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_HZ_ACCT_SITE_USES_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_HZ_ACCT_SITE_USES_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_OWNER.DMT_HZ_ACCT_SITE_USES_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_HZ_ACCT_SITE_USES_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_ACCT_SITE_USES complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_ACCT_SITE_USES');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_ACCT_SITE_USES failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_ACCT_SITE_USES',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_ACCT_SITE_USES;

END DMT_CUST_TRANSFORM_PKG;
/
