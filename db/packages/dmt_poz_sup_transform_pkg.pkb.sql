-- PACKAGE BODY DMT_POZ_SUP_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_POZ_SUP_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_POZ_SUP_TRANSFORM_PKG Body
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_POZ_SUP_TRANSFORM_PKG';

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


    -- ============================================================
    -- TRANSFORM_SUPPLIERS
    -- ============================================================
    PROCEDURE TRANSFORM_SUPPLIERS (
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
            p_message        => 'TRANSFORM_SUPPLIERS start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_SUPPLIERS');

        l_prefix := get_prefix(p_run_id);


        -- Accumulate, never overwrite (section 5): ERROR_TEXT is append-only.
        -- The former reprocess-time ERROR_TEXT reset (which was also unscoped —
        -- it hit every FAILED row in the table regardless of scenario) is
        -- removed; the FAILED reselection below stays scenario-scoped via the
        -- shared p_scenario_id predicate.

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_OWNER.DMT_POZ_SUPPLIERS_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    FBDI_CSV_ID,
                    IMPORT_ACTION,
                    VENDOR_NAME,
                    VENDOR_NAME_NEW,
                    SEGMENT1,
                    VENDOR_NAME_ALT,
                    ORGANIZATION_TYPE_LOOKUP_CODE,
                    VENDOR_TYPE_LOOKUP_CODE,
                    END_DATE_ACTIVE,
                    BUSINESS_RELATIONSHIP,
                    PARENT_SUPPLIER_NAME,
                    ALIAS,
                    DUNS_NUMBER,
                    ONE_TIME_FLAG,
                    CUSTOMER_NUM,
                    STANDARD_INDUSTRY_CLASS,
                    NI_NUMBER,
                    CORPORATE_WEBSITE,
                    CHIEF_EXECUTIVE_TITLE,
                    CHIEF_EXECUTIVE_NAME,
                    BC_NOT_APPLICABLE_FLAG,
                    TAX_COUNTRY_CODE,
                    NUM_1099,
                    FEDERAL_REPORTABLE_FLAG,
                    TYPE_1099,
                    STATE_REPORTABLE_FLAG,
                    TAX_REPORTING_NAME,
                    NAME_CONTROL,
                    TAX_VERIFICATION_DATE,
                    ALLOW_AWT_FLAG,
                    AWT_GROUP_NAME,
                    VAT_CODE,
                    VAT_REGISTRATION_NUM,
                    AUTO_TAX_CALC_OVERRIDE,
                    PAYMENT_METHOD_LOOKUP_CODE,
                    DELIVERY_CHANNEL_CODE,
                    BANK_INSTRUCTION1_CODE,
                    BANK_INSTRUCTION2_CODE,
                    BANK_INSTRUCTION_DETAILS,
                    SETTLEMENT_PRIORITY,
                    PAYMENT_TEXT_MESSAGE1,
                    PAYMENT_TEXT_MESSAGE2,
                    PAYMENT_TEXT_MESSAGE3,
                    IBY_BANK_CHARGE_BEARER,
                    PAYMENT_REASON_CODE,
                    PAYMENT_REASON_COMMENTS,
                    PAYMENT_FORMAT_CODE,
                    ATTRIBUTE_CATEGORY,
                    ATTRIBUTE1,  ATTRIBUTE2,  ATTRIBUTE3,  ATTRIBUTE4,  ATTRIBUTE5,
                    ATTRIBUTE6,  ATTRIBUTE7,  ATTRIBUTE8,  ATTRIBUTE9,  ATTRIBUTE10,
                    ATTRIBUTE11, ATTRIBUTE12, ATTRIBUTE13, ATTRIBUTE14, ATTRIBUTE15,
                    ATTRIBUTE16, ATTRIBUTE17, ATTRIBUTE18, ATTRIBUTE19, ATTRIBUTE20,
                    ATTRIBUTE_DATE1,  ATTRIBUTE_DATE2,  ATTRIBUTE_DATE3,  ATTRIBUTE_DATE4,  ATTRIBUTE_DATE5,
                    ATTRIBUTE_DATE6,  ATTRIBUTE_DATE7,  ATTRIBUTE_DATE8,  ATTRIBUTE_DATE9,  ATTRIBUTE_DATE10,
                    ATTRIBUTE_TIMESTAMP1,  ATTRIBUTE_TIMESTAMP2,  ATTRIBUTE_TIMESTAMP3,  ATTRIBUTE_TIMESTAMP4,  ATTRIBUTE_TIMESTAMP5,
                    ATTRIBUTE_TIMESTAMP6,  ATTRIBUTE_TIMESTAMP7,  ATTRIBUTE_TIMESTAMP8,  ATTRIBUTE_TIMESTAMP9,  ATTRIBUTE_TIMESTAMP10,
                    ATTRIBUTE_NUMBER1,  ATTRIBUTE_NUMBER2,  ATTRIBUTE_NUMBER3,  ATTRIBUTE_NUMBER4,  ATTRIBUTE_NUMBER5,
                    ATTRIBUTE_NUMBER6,  ATTRIBUTE_NUMBER7,  ATTRIBUTE_NUMBER8,  ATTRIBUTE_NUMBER9,  ATTRIBUTE_NUMBER10,
                    GLOBAL_ATTRIBUTE_CATEGORY,
                    GLOBAL_ATTRIBUTE1,  GLOBAL_ATTRIBUTE2,  GLOBAL_ATTRIBUTE3,  GLOBAL_ATTRIBUTE4,  GLOBAL_ATTRIBUTE5,
                    GLOBAL_ATTRIBUTE6,  GLOBAL_ATTRIBUTE7,  GLOBAL_ATTRIBUTE8,  GLOBAL_ATTRIBUTE9,  GLOBAL_ATTRIBUTE10,
                    GLOBAL_ATTRIBUTE11, GLOBAL_ATTRIBUTE12, GLOBAL_ATTRIBUTE13, GLOBAL_ATTRIBUTE14, GLOBAL_ATTRIBUTE15,
                    GLOBAL_ATTRIBUTE16, GLOBAL_ATTRIBUTE17, GLOBAL_ATTRIBUTE18, GLOBAL_ATTRIBUTE19, GLOBAL_ATTRIBUTE20,
                    GLOBAL_ATTRIBUTE_DATE1,  GLOBAL_ATTRIBUTE_DATE2,  GLOBAL_ATTRIBUTE_DATE3,  GLOBAL_ATTRIBUTE_DATE4,  GLOBAL_ATTRIBUTE_DATE5,
                    GLOBAL_ATTRIBUTE_DATE6,  GLOBAL_ATTRIBUTE_DATE7,  GLOBAL_ATTRIBUTE_DATE8,  GLOBAL_ATTRIBUTE_DATE9,  GLOBAL_ATTRIBUTE_DATE10,
                    GLOBAL_ATTRIBUTE_TIMESTAMP1,  GLOBAL_ATTRIBUTE_TIMESTAMP2,  GLOBAL_ATTRIBUTE_TIMESTAMP3,  GLOBAL_ATTRIBUTE_TIMESTAMP4,  GLOBAL_ATTRIBUTE_TIMESTAMP5,
                    GLOBAL_ATTRIBUTE_TIMESTAMP6,  GLOBAL_ATTRIBUTE_TIMESTAMP7,  GLOBAL_ATTRIBUTE_TIMESTAMP8,  GLOBAL_ATTRIBUTE_TIMESTAMP9,  GLOBAL_ATTRIBUTE_TIMESTAMP10,
                    GLOBAL_ATTRIBUTE_NUMBER1,  GLOBAL_ATTRIBUTE_NUMBER2,  GLOBAL_ATTRIBUTE_NUMBER3,  GLOBAL_ATTRIBUTE_NUMBER4,  GLOBAL_ATTRIBUTE_NUMBER5,
                    GLOBAL_ATTRIBUTE_NUMBER6,  GLOBAL_ATTRIBUTE_NUMBER7,  GLOBAL_ATTRIBUTE_NUMBER8,  GLOBAL_ATTRIBUTE_NUMBER9,  GLOBAL_ATTRIBUTE_NUMBER10,
                    PARTY_NUMBER,
                    SERVICE_LEVEL_CODE,
                    EXCLUSIVE_PAYMENT_FLAG,
                    REMIT_ADVICE_DELIVERY_METHOD,
                    REMIT_ADVICE_EMAIL,
                    REMIT_ADVICE_FAX,
                    DATAFOX_COMPANY_ID,
                    STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    NULL,
                    s.IMPORT_ACTION,
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.VENDOR_NAME),
                    s.VENDOR_NAME_NEW,
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.SEGMENT1, 25),
                    s.VENDOR_NAME_ALT,
                    s.ORGANIZATION_TYPE_LOOKUP_CODE,
                    s.VENDOR_TYPE_LOOKUP_CODE,
                    s.END_DATE_ACTIVE,
                    s.BUSINESS_RELATIONSHIP,
                    s.PARENT_SUPPLIER_NAME,
                    s.ALIAS,
                    s.DUNS_NUMBER,
                    s.ONE_TIME_FLAG,
                    s.CUSTOMER_NUM,
                    s.STANDARD_INDUSTRY_CLASS,
                    s.NI_NUMBER,
                    s.CORPORATE_WEBSITE,
                    s.CHIEF_EXECUTIVE_TITLE,
                    s.CHIEF_EXECUTIVE_NAME,
                    s.BC_NOT_APPLICABLE_FLAG,
                    s.TAX_COUNTRY_CODE,
                    s.NUM_1099,
                    s.FEDERAL_REPORTABLE_FLAG,
                    s.TYPE_1099,
                    s.STATE_REPORTABLE_FLAG,
                    s.TAX_REPORTING_NAME,
                    s.NAME_CONTROL,
                    s.TAX_VERIFICATION_DATE,
                    s.ALLOW_AWT_FLAG,
                    s.AWT_GROUP_NAME,
                    s.VAT_CODE,
                    s.VAT_REGISTRATION_NUM,
                    s.AUTO_TAX_CALC_OVERRIDE,
                    s.PAYMENT_METHOD_LOOKUP_CODE,
                    s.DELIVERY_CHANNEL_CODE,
                    s.BANK_INSTRUCTION1_CODE,
                    s.BANK_INSTRUCTION2_CODE,
                    s.BANK_INSTRUCTION_DETAILS,
                    s.SETTLEMENT_PRIORITY,
                    s.PAYMENT_TEXT_MESSAGE1,
                    s.PAYMENT_TEXT_MESSAGE2,
                    s.PAYMENT_TEXT_MESSAGE3,
                    s.IBY_BANK_CHARGE_BEARER,
                    s.PAYMENT_REASON_CODE,
                    s.PAYMENT_REASON_COMMENTS,
                    s.PAYMENT_FORMAT_CODE,
                    s.ATTRIBUTE_CATEGORY,
                    s.ATTRIBUTE1,  s.ATTRIBUTE2,  s.ATTRIBUTE3,  s.ATTRIBUTE4,  s.ATTRIBUTE5,
                    s.ATTRIBUTE6,  s.ATTRIBUTE7,  s.ATTRIBUTE8,  s.ATTRIBUTE9,  s.ATTRIBUTE10,
                    s.ATTRIBUTE11, s.ATTRIBUTE12, s.ATTRIBUTE13, s.ATTRIBUTE14, s.ATTRIBUTE15,
                    s.ATTRIBUTE16, s.ATTRIBUTE17, s.ATTRIBUTE18, s.ATTRIBUTE19, s.ATTRIBUTE20,
                    s.ATTRIBUTE_DATE1,  s.ATTRIBUTE_DATE2,  s.ATTRIBUTE_DATE3,  s.ATTRIBUTE_DATE4,  s.ATTRIBUTE_DATE5,
                    s.ATTRIBUTE_DATE6,  s.ATTRIBUTE_DATE7,  s.ATTRIBUTE_DATE8,  s.ATTRIBUTE_DATE9,  s.ATTRIBUTE_DATE10,
                    s.ATTRIBUTE_TIMESTAMP1,  s.ATTRIBUTE_TIMESTAMP2,  s.ATTRIBUTE_TIMESTAMP3,  s.ATTRIBUTE_TIMESTAMP4,  s.ATTRIBUTE_TIMESTAMP5,
                    s.ATTRIBUTE_TIMESTAMP6,  s.ATTRIBUTE_TIMESTAMP7,  s.ATTRIBUTE_TIMESTAMP8,  s.ATTRIBUTE_TIMESTAMP9,  s.ATTRIBUTE_TIMESTAMP10,
                    s.ATTRIBUTE_NUMBER1,  s.ATTRIBUTE_NUMBER2,  s.ATTRIBUTE_NUMBER3,  s.ATTRIBUTE_NUMBER4,  s.ATTRIBUTE_NUMBER5,
                    s.ATTRIBUTE_NUMBER6,  s.ATTRIBUTE_NUMBER7,  s.ATTRIBUTE_NUMBER8,  s.ATTRIBUTE_NUMBER9,  s.ATTRIBUTE_NUMBER10,
                    s.GLOBAL_ATTRIBUTE_CATEGORY,
                    s.GLOBAL_ATTRIBUTE1,  s.GLOBAL_ATTRIBUTE2,  s.GLOBAL_ATTRIBUTE3,  s.GLOBAL_ATTRIBUTE4,  s.GLOBAL_ATTRIBUTE5,
                    s.GLOBAL_ATTRIBUTE6,  s.GLOBAL_ATTRIBUTE7,  s.GLOBAL_ATTRIBUTE8,  s.GLOBAL_ATTRIBUTE9,  s.GLOBAL_ATTRIBUTE10,
                    s.GLOBAL_ATTRIBUTE11, s.GLOBAL_ATTRIBUTE12, s.GLOBAL_ATTRIBUTE13, s.GLOBAL_ATTRIBUTE14, s.GLOBAL_ATTRIBUTE15,
                    s.GLOBAL_ATTRIBUTE16, s.GLOBAL_ATTRIBUTE17, s.GLOBAL_ATTRIBUTE18, s.GLOBAL_ATTRIBUTE19, s.GLOBAL_ATTRIBUTE20,
                    s.GLOBAL_ATTRIBUTE_DATE1,  s.GLOBAL_ATTRIBUTE_DATE2,  s.GLOBAL_ATTRIBUTE_DATE3,  s.GLOBAL_ATTRIBUTE_DATE4,  s.GLOBAL_ATTRIBUTE_DATE5,
                    s.GLOBAL_ATTRIBUTE_DATE6,  s.GLOBAL_ATTRIBUTE_DATE7,  s.GLOBAL_ATTRIBUTE_DATE8,  s.GLOBAL_ATTRIBUTE_DATE9,  s.GLOBAL_ATTRIBUTE_DATE10,
                    s.GLOBAL_ATTRIBUTE_TIMESTAMP1,  s.GLOBAL_ATTRIBUTE_TIMESTAMP2,  s.GLOBAL_ATTRIBUTE_TIMESTAMP3,  s.GLOBAL_ATTRIBUTE_TIMESTAMP4,  s.GLOBAL_ATTRIBUTE_TIMESTAMP5,
                    s.GLOBAL_ATTRIBUTE_TIMESTAMP6,  s.GLOBAL_ATTRIBUTE_TIMESTAMP7,  s.GLOBAL_ATTRIBUTE_TIMESTAMP8,  s.GLOBAL_ATTRIBUTE_TIMESTAMP9,  s.GLOBAL_ATTRIBUTE_TIMESTAMP10,
                    s.GLOBAL_ATTRIBUTE_NUMBER1,  s.GLOBAL_ATTRIBUTE_NUMBER2,  s.GLOBAL_ATTRIBUTE_NUMBER3,  s.GLOBAL_ATTRIBUTE_NUMBER4,  s.GLOBAL_ATTRIBUTE_NUMBER5,
                    s.GLOBAL_ATTRIBUTE_NUMBER6,  s.GLOBAL_ATTRIBUTE_NUMBER7,  s.GLOBAL_ATTRIBUTE_NUMBER8,  s.GLOBAL_ATTRIBUTE_NUMBER9,  s.GLOBAL_ATTRIBUTE_NUMBER10,
                    s.PARTY_NUMBER,
                    s.SERVICE_LEVEL_CODE,
                    s.EXCLUSIVE_PAYMENT_FLAG,
                    s.REMIT_ADVICE_DELIVERY_METHOD,
                    s.REMIT_ADVICE_EMAIL,
                    s.REMIT_ADVICE_FAX,
                    s.DATAFOX_COMPANY_ID,
                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_POZ_SUPPLIERS_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_POZ_SUPPLIERS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_OWNER.DMT_POZ_SUPPLIERS_STG_TBL s
        SET    s.STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_POZ_SUPPLIERS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_SUPPLIERS complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_SUPPLIERS');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_SUPPLIERS failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_SUPPLIERS',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_SUPPLIERS;


    -- ============================================================
    -- TRANSFORM_ADDRESSES
    -- ============================================================
    PROCEDURE TRANSFORM_ADDRESSES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_ok_count   NUMBER := 0;
        l_fail_count NUMBER := 0;
        l_prefix     VARCHAR2(30);

    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_ADDRESSES start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_ADDRESSES');
        l_prefix := get_prefix(p_run_id);


        -- Accumulate, never overwrite (section 5): ERROR_TEXT is append-only.
        -- The former reprocess-time ERROR_TEXT reset (which was also unscoped —
        -- it hit every FAILED row in the table regardless of scenario) is
        -- removed; the FAILED reselection below stays scenario-scoped via the
        -- shared p_scenario_id predicate.

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_OWNER.DMT_POZ_SUP_ADDR_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    FBDI_CSV_ID,
                    IMPORT_ACTION,
                    VENDOR_NAME,
                    PARTY_SITE_NAME,
                    PARTY_SITE_NAME_NEW,
                    COUNTRY,
                    ADDRESS_LINE1,
                    ADDRESS_LINE2,
                    ADDRESS_LINE3,
                    ADDRESS_LINE4,
                    ADDRESS_LINES_PHONETIC,
                    ADDR_ELEMENT_ATTRIBUTE1,
                    ADDR_ELEMENT_ATTRIBUTE2,
                    ADDR_ELEMENT_ATTRIBUTE3,
                    ADDR_ELEMENT_ATTRIBUTE4,
                    ADDR_ELEMENT_ATTRIBUTE5,
                    BUILDING,
                    FLOOR_NUMBER,
                    CITY,
                    STATE,
                    PROVINCE,
                    COUNTY,
                    POSTAL_CODE,
                    POSTAL_PLUS4_CODE,
                    ADDRESSEE,
                    GLOBAL_LOCATION_NUMBER,
                    PARTY_SITE_LANGUAGE,
                    INACTIVE_DATE,
                    PHONE_COUNTRY_CODE,
                    PHONE_AREA_CODE,
                    PHONE,
                    PHONE_EXTENSION,
                    FAX_COUNTRY_CODE,
                    FAX_AREA_CODE,
                    FAX,
                    RFQ_OR_BIDDING_PURPOSE_FLAG,
                    ORDERING_PURPOSE_FLAG,
                    REMIT_TO_PURPOSE_FLAG,
                    ATTRIBUTE_CATEGORY,
                    ATTRIBUTE1,  ATTRIBUTE2,  ATTRIBUTE3,  ATTRIBUTE4,  ATTRIBUTE5,
                    ATTRIBUTE6,  ATTRIBUTE7,  ATTRIBUTE8,  ATTRIBUTE9,  ATTRIBUTE10,
                    ATTRIBUTE11, ATTRIBUTE12, ATTRIBUTE13, ATTRIBUTE14, ATTRIBUTE15,
                    ATTRIBUTE16, ATTRIBUTE17, ATTRIBUTE18, ATTRIBUTE19, ATTRIBUTE20,
                    ATTRIBUTE21, ATTRIBUTE22, ATTRIBUTE23, ATTRIBUTE24, ATTRIBUTE25,
                    ATTRIBUTE26, ATTRIBUTE27, ATTRIBUTE28, ATTRIBUTE29, ATTRIBUTE30,
                    ATTRIBUTE_NUMBER1,  ATTRIBUTE_NUMBER2,  ATTRIBUTE_NUMBER3,  ATTRIBUTE_NUMBER4,  ATTRIBUTE_NUMBER5,
                    ATTRIBUTE_NUMBER6,  ATTRIBUTE_NUMBER7,  ATTRIBUTE_NUMBER8,  ATTRIBUTE_NUMBER9,  ATTRIBUTE_NUMBER10,
                    ATTRIBUTE_NUMBER11, ATTRIBUTE_NUMBER12,
                    ATTRIBUTE_DATE1,  ATTRIBUTE_DATE2,  ATTRIBUTE_DATE3,  ATTRIBUTE_DATE4,  ATTRIBUTE_DATE5,
                    ATTRIBUTE_DATE6,  ATTRIBUTE_DATE7,  ATTRIBUTE_DATE8,  ATTRIBUTE_DATE9,  ATTRIBUTE_DATE10,
                    ATTRIBUTE_DATE11, ATTRIBUTE_DATE12,
                    EMAIL_ADDRESS,
                    DELIVERY_CHANNEL_CODE,
                    BANK_INSTRUCTION1_CODE,
                    BANK_INSTRUCTION2_CODE,
                    BANK_INSTRUCTION_DETAILS,
                    SETTLEMENT_PRIORITY,
                    PAYMENT_TEXT_MESSAGE1,
                    PAYMENT_TEXT_MESSAGE2,
                    PAYMENT_TEXT_MESSAGE3,
                    SERVICE_LEVEL_CODE,
                    EXCLUSIVE_PAYMENT_FLAG,
                    IBY_BANK_CHARGE_BEARER,
                    PAYMENT_REASON_CODE,
                    PAYMENT_REASON_COMMENTS,
                    REMIT_ADVICE_DELIVERY_METHOD,
                    REMIT_ADVICE_EMAIL,
                    REMIT_ADVICE_FAX,
                    STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    NULL,
                    s.IMPORT_ACTION,
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.VENDOR_NAME),
                    s.PARTY_SITE_NAME,
                    s.PARTY_SITE_NAME_NEW,
                    s.COUNTRY,
                    s.ADDRESS_LINE1,
                    s.ADDRESS_LINE2,
                    s.ADDRESS_LINE3,
                    s.ADDRESS_LINE4,
                    s.ADDRESS_LINES_PHONETIC,
                    s.ADDR_ELEMENT_ATTRIBUTE1,
                    s.ADDR_ELEMENT_ATTRIBUTE2,
                    s.ADDR_ELEMENT_ATTRIBUTE3,
                    s.ADDR_ELEMENT_ATTRIBUTE4,
                    s.ADDR_ELEMENT_ATTRIBUTE5,
                    s.BUILDING,
                    s.FLOOR_NUMBER,
                    s.CITY,
                    s.STATE,
                    s.PROVINCE,
                    s.COUNTY,
                    s.POSTAL_CODE,
                    s.POSTAL_PLUS4_CODE,
                    s.ADDRESSEE,
                    s.GLOBAL_LOCATION_NUMBER,
                    s.PARTY_SITE_LANGUAGE,
                    s.INACTIVE_DATE,
                    s.PHONE_COUNTRY_CODE,
                    s.PHONE_AREA_CODE,
                    s.PHONE,
                    s.PHONE_EXTENSION,
                    s.FAX_COUNTRY_CODE,
                    s.FAX_AREA_CODE,
                    s.FAX,
                    s.RFQ_OR_BIDDING_PURPOSE_FLAG,
                    s.ORDERING_PURPOSE_FLAG,
                    s.REMIT_TO_PURPOSE_FLAG,
                    s.ATTRIBUTE_CATEGORY,
                    s.ATTRIBUTE1,  s.ATTRIBUTE2,  s.ATTRIBUTE3,  s.ATTRIBUTE4,  s.ATTRIBUTE5,
                    s.ATTRIBUTE6,  s.ATTRIBUTE7,  s.ATTRIBUTE8,  s.ATTRIBUTE9,  s.ATTRIBUTE10,
                    s.ATTRIBUTE11, s.ATTRIBUTE12, s.ATTRIBUTE13, s.ATTRIBUTE14, s.ATTRIBUTE15,
                    s.ATTRIBUTE16, s.ATTRIBUTE17, s.ATTRIBUTE18, s.ATTRIBUTE19, s.ATTRIBUTE20,
                    s.ATTRIBUTE21, s.ATTRIBUTE22, s.ATTRIBUTE23, s.ATTRIBUTE24, s.ATTRIBUTE25,
                    s.ATTRIBUTE26, s.ATTRIBUTE27, s.ATTRIBUTE28, s.ATTRIBUTE29, s.ATTRIBUTE30,
                    s.ATTRIBUTE_NUMBER1,  s.ATTRIBUTE_NUMBER2,  s.ATTRIBUTE_NUMBER3,  s.ATTRIBUTE_NUMBER4,  s.ATTRIBUTE_NUMBER5,
                    s.ATTRIBUTE_NUMBER6,  s.ATTRIBUTE_NUMBER7,  s.ATTRIBUTE_NUMBER8,  s.ATTRIBUTE_NUMBER9,  s.ATTRIBUTE_NUMBER10,
                    s.ATTRIBUTE_NUMBER11, s.ATTRIBUTE_NUMBER12,
                    s.ATTRIBUTE_DATE1,  s.ATTRIBUTE_DATE2,  s.ATTRIBUTE_DATE3,  s.ATTRIBUTE_DATE4,  s.ATTRIBUTE_DATE5,
                    s.ATTRIBUTE_DATE6,  s.ATTRIBUTE_DATE7,  s.ATTRIBUTE_DATE8,  s.ATTRIBUTE_DATE9,  s.ATTRIBUTE_DATE10,
                    s.ATTRIBUTE_DATE11, s.ATTRIBUTE_DATE12,
                    s.EMAIL_ADDRESS,
                    s.DELIVERY_CHANNEL_CODE,
                    s.BANK_INSTRUCTION1_CODE,
                    s.BANK_INSTRUCTION2_CODE,
                    s.BANK_INSTRUCTION_DETAILS,
                    s.SETTLEMENT_PRIORITY,
                    s.PAYMENT_TEXT_MESSAGE1,
                    s.PAYMENT_TEXT_MESSAGE2,
                    s.PAYMENT_TEXT_MESSAGE3,
                    s.SERVICE_LEVEL_CODE,
                    s.EXCLUSIVE_PAYMENT_FLAG,
                    s.IBY_BANK_CHARGE_BEARER,
                    s.PAYMENT_REASON_CODE,
                    s.PAYMENT_REASON_COMMENTS,
                    s.REMIT_ADVICE_DELIVERY_METHOD,
                    s.REMIT_ADVICE_EMAIL,
                    s.REMIT_ADVICE_FAX,
                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_POZ_SUP_ADDR_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_POZ_SUP_ADDR_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_OWNER.DMT_POZ_SUP_ADDR_STG_TBL s
        SET    s.STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_POZ_SUP_ADDR_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_ADDRESSES complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_ADDRESSES');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_ADDRESSES failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_ADDRESSES',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_ADDRESSES;


    -- ============================================================
    -- TRANSFORM_SITES
    -- ============================================================
    PROCEDURE TRANSFORM_SITES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_ok_count   NUMBER := 0;
        l_fail_count NUMBER := 0;
        l_prefix     VARCHAR2(30);

    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_SITES start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_SITES');
        l_prefix := get_prefix(p_run_id);


        -- Accumulate, never overwrite (section 5): ERROR_TEXT is append-only.
        -- The former reprocess-time ERROR_TEXT reset (which was also unscoped —
        -- it hit every FAILED row in the table regardless of scenario) is
        -- removed; the FAILED reselection below stays scenario-scoped via the
        -- shared p_scenario_id predicate.

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_OWNER.DMT_POZ_SUP_SITE_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    FBDI_CSV_ID,
                    IMPORT_ACTION,
                    VENDOR_NAME,
                    PROCUREMENT_BUSINESS_UNIT_NAME,
                    PARTY_SITE_NAME,
                    VENDOR_SITE_CODE,
                    VENDOR_SITE_CODE_NEW,
                    INACTIVE_DATE,
                    RFQ_ONLY_SITE_FLAG,
                    PURCHASING_SITE_FLAG,
                    PCARD_SITE_FLAG,
                    PAY_SITE_FLAG,
                    PRIMARY_PAY_SITE_FLAG,
                    TAX_REPORTING_SITE_FLAG,
                    VENDOR_SITE_CODE_ALT,
                    CUSTOMER_NUM,
                    B2B_COMM_METHOD_CODE,
                    B2B_SITE_CODE,
                    SUPPLIER_NOTIF_METHOD,
                    EMAIL_ADDRESS,
                    FAX_COUNTRY_CODE,
                    FAX_AREA_CODE,
                    FAX,
                    HOLD_FLAG,
                    PURCHASING_HOLD_REASON,
                    CARRIER,
                    MODE_OF_TRANSPORT_CODE,
                    SERVICE_LEVEL_CODE,
                    FREIGHT_TERMS_LOOKUP_CODE,
                    PAY_ON_CODE,
                    FOB_LOOKUP_CODE,
                    COUNTRY_OF_ORIGIN_CODE,
                    BUYER_MANAGED_TRANSPORT_FLAG,
                    PAY_ON_USE_FLAG,
                    AGING_ONSET_POINT,
                    AGING_PERIOD_DAYS,
                    CONSUMPTION_ADVICE_FREQUENCY,
                    CONSUMPTION_ADVICE_SUMMARY,
                    DEFAULT_PAY_SITE_CODE,
                    PAY_ON_RECEIPT_SUMMARY_CODE,
                    GAPLESS_INV_NUM_FLAG,
                    SELLING_COMPANY_IDENTIFIER,
                    CREATE_DEBIT_MEMO_FLAG,
                    ENFORCE_SHIP_TO_LOCATION_CODE,
                    RECEIVING_ROUTING_ID,
                    QTY_RCV_TOLERANCE,
                    QTY_RCV_EXCEPTION_CODE,
                    DAYS_EARLY_RECEIPT_ALLOWED,
                    DAYS_LATE_RECEIPT_ALLOWED,
                    ALLOW_SUBSTITUTE_RECEIPTS_FLAG,
                    ALLOW_UNORDERED_RECEIPTS_FLAG,
                    RECEIPT_DAYS_EXCEPTION_CODE,
                    INVOICE_CURRENCY_CODE,
                    INVOICE_AMOUNT_LIMIT,
                    MATCH_OPTION,
                    MATCH_APPROVAL_LEVEL,
                    PAYMENT_CURRENCY_CODE,
                    PAYMENT_PRIORITY,
                    PAY_GROUP_LOOKUP_CODE,
                    TOLERANCE_NAME,
                    SERVICES_TOLERANCE,
                    HOLD_ALL_PAYMENTS_FLAG,
                    HOLD_UNMATCHED_INVOICES_FLAG,
                    HOLD_FUTURE_PAYMENTS_FLAG,
                    HOLD_BY,
                    PAYMENT_HOLD_DATE,
                    HOLD_REASON,
                    TERMS_NAME,
                    TERMS_DATE_BASIS,
                    PAY_DATE_BASIS_LOOKUP_CODE,
                    BANK_CHARGE_DEDUCTION_TYPE,
                    ALWAYS_TAKE_DISC_FLAG,
                    EXCLUDE_FREIGHT_FROM_DISCOUNT,
                    EXCLUDE_TAX_FROM_DISCOUNT,
                    AUTO_CALCULATE_INTEREST_FLAG,
                    VAT_CODE,
                    VAT_REGISTRATION_NUM,
                    PAYMENT_METHOD_LOOKUP_CODE,
                    DELIVERY_CHANNEL_CODE,
                    BANK_INSTRUCTION1_CODE,
                    BANK_INSTRUCTION2_CODE,
                    BANK_INSTRUCTION_DETAILS,
                    SETTLEMENT_PRIORITY,
                    PAYMENT_TEXT_MESSAGE1,
                    PAYMENT_TEXT_MESSAGE2,
                    PAYMENT_TEXT_MESSAGE3,
                    IBY_BANK_CHARGE_BEARER,
                    PAYMENT_REASON_CODE,
                    PAYMENT_REASON_COMMENTS,
                    REMIT_ADVICE_DELIVERY_METHOD,
                    REMITTANCE_EMAIL,
                    REMITTANCE_FAX,
                    ATTRIBUTE_CATEGORY,
                    ATTRIBUTE1,  ATTRIBUTE2,  ATTRIBUTE3,  ATTRIBUTE4,  ATTRIBUTE5,
                    ATTRIBUTE6,  ATTRIBUTE7,  ATTRIBUTE8,  ATTRIBUTE9,  ATTRIBUTE10,
                    ATTRIBUTE11, ATTRIBUTE12, ATTRIBUTE13, ATTRIBUTE14, ATTRIBUTE15,
                    ATTRIBUTE16, ATTRIBUTE17, ATTRIBUTE18, ATTRIBUTE19, ATTRIBUTE20,
                    ATTRIBUTE_DATE1,  ATTRIBUTE_DATE2,  ATTRIBUTE_DATE3,  ATTRIBUTE_DATE4,  ATTRIBUTE_DATE5,
                    ATTRIBUTE_DATE6,  ATTRIBUTE_DATE7,  ATTRIBUTE_DATE8,  ATTRIBUTE_DATE9,  ATTRIBUTE_DATE10,
                    ATTRIBUTE_TIMESTAMP1,  ATTRIBUTE_TIMESTAMP2,  ATTRIBUTE_TIMESTAMP3,  ATTRIBUTE_TIMESTAMP4,  ATTRIBUTE_TIMESTAMP5,
                    ATTRIBUTE_TIMESTAMP6,  ATTRIBUTE_TIMESTAMP7,  ATTRIBUTE_TIMESTAMP8,  ATTRIBUTE_TIMESTAMP9,  ATTRIBUTE_TIMESTAMP10,
                    ATTRIBUTE_NUMBER1,  ATTRIBUTE_NUMBER2,  ATTRIBUTE_NUMBER3,  ATTRIBUTE_NUMBER4,  ATTRIBUTE_NUMBER5,
                    ATTRIBUTE_NUMBER6,  ATTRIBUTE_NUMBER7,  ATTRIBUTE_NUMBER8,  ATTRIBUTE_NUMBER9,  ATTRIBUTE_NUMBER10,
                    GLOBAL_ATTRIBUTE_CATEGORY,
                    GLOBAL_ATTRIBUTE1,  GLOBAL_ATTRIBUTE2,  GLOBAL_ATTRIBUTE3,  GLOBAL_ATTRIBUTE4,  GLOBAL_ATTRIBUTE5,
                    GLOBAL_ATTRIBUTE6,  GLOBAL_ATTRIBUTE7,  GLOBAL_ATTRIBUTE8,  GLOBAL_ATTRIBUTE9,  GLOBAL_ATTRIBUTE10,
                    GLOBAL_ATTRIBUTE11, GLOBAL_ATTRIBUTE12, GLOBAL_ATTRIBUTE13, GLOBAL_ATTRIBUTE14, GLOBAL_ATTRIBUTE15,
                    GLOBAL_ATTRIBUTE16, GLOBAL_ATTRIBUTE17, GLOBAL_ATTRIBUTE18, GLOBAL_ATTRIBUTE19, GLOBAL_ATTRIBUTE20,
                    GLOBAL_ATTRIBUTE_DATE1,  GLOBAL_ATTRIBUTE_DATE2,  GLOBAL_ATTRIBUTE_DATE3,  GLOBAL_ATTRIBUTE_DATE4,  GLOBAL_ATTRIBUTE_DATE5,
                    GLOBAL_ATTRIBUTE_DATE6,  GLOBAL_ATTRIBUTE_DATE7,  GLOBAL_ATTRIBUTE_DATE8,  GLOBAL_ATTRIBUTE_DATE9,  GLOBAL_ATTRIBUTE_DATE10,
                    GLOBAL_ATTRIBUTE_TIMESTAMP1,  GLOBAL_ATTRIBUTE_TIMESTAMP2,  GLOBAL_ATTRIBUTE_TIMESTAMP3,  GLOBAL_ATTRIBUTE_TIMESTAMP4,  GLOBAL_ATTRIBUTE_TIMESTAMP5,
                    GLOBAL_ATTRIBUTE_TIMESTAMP6,  GLOBAL_ATTRIBUTE_TIMESTAMP7,  GLOBAL_ATTRIBUTE_TIMESTAMP8,  GLOBAL_ATTRIBUTE_TIMESTAMP9,  GLOBAL_ATTRIBUTE_TIMESTAMP10,
                    GLOBAL_ATTRIBUTE_NUMBER1,  GLOBAL_ATTRIBUTE_NUMBER2,  GLOBAL_ATTRIBUTE_NUMBER3,  GLOBAL_ATTRIBUTE_NUMBER4,  GLOBAL_ATTRIBUTE_NUMBER5,
                    GLOBAL_ATTRIBUTE_NUMBER6,  GLOBAL_ATTRIBUTE_NUMBER7,  GLOBAL_ATTRIBUTE_NUMBER8,  GLOBAL_ATTRIBUTE_NUMBER9,  GLOBAL_ATTRIBUTE_NUMBER10,
                    PO_ACK_REQD_CODE,
                    PO_ACK_REQD_DAYS,
                    INVOICE_CHANNEL,
                    PAYEE_SERVICE_LEVEL_CODE,
                    EXCLUSIVE_PAYMENT_FLAG,
                    OVERRIDE_B2B_COMM_CODE,
                    STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    NULL,
                    s.IMPORT_ACTION,
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.VENDOR_NAME),
                    s.PROCUREMENT_BUSINESS_UNIT_NAME,
                    s.PARTY_SITE_NAME,
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.VENDOR_SITE_CODE, 15),
                    s.VENDOR_SITE_CODE_NEW,
                    s.INACTIVE_DATE,
                    s.RFQ_ONLY_SITE_FLAG,
                    s.PURCHASING_SITE_FLAG,
                    s.PCARD_SITE_FLAG,
                    s.PAY_SITE_FLAG,
                    s.PRIMARY_PAY_SITE_FLAG,
                    s.TAX_REPORTING_SITE_FLAG,
                    s.VENDOR_SITE_CODE_ALT,
                    s.CUSTOMER_NUM,
                    s.B2B_COMM_METHOD_CODE,
                    s.B2B_SITE_CODE,
                    s.SUPPLIER_NOTIF_METHOD,
                    s.EMAIL_ADDRESS,
                    s.FAX_COUNTRY_CODE,
                    s.FAX_AREA_CODE,
                    s.FAX,
                    s.HOLD_FLAG,
                    s.PURCHASING_HOLD_REASON,
                    s.CARRIER,
                    s.MODE_OF_TRANSPORT_CODE,
                    s.SERVICE_LEVEL_CODE,
                    s.FREIGHT_TERMS_LOOKUP_CODE,
                    s.PAY_ON_CODE,
                    s.FOB_LOOKUP_CODE,
                    s.COUNTRY_OF_ORIGIN_CODE,
                    s.BUYER_MANAGED_TRANSPORT_FLAG,
                    s.PAY_ON_USE_FLAG,
                    s.AGING_ONSET_POINT,
                    s.AGING_PERIOD_DAYS,
                    s.CONSUMPTION_ADVICE_FREQUENCY,
                    s.CONSUMPTION_ADVICE_SUMMARY,
                    s.DEFAULT_PAY_SITE_CODE,
                    s.PAY_ON_RECEIPT_SUMMARY_CODE,
                    s.GAPLESS_INV_NUM_FLAG,
                    s.SELLING_COMPANY_IDENTIFIER,
                    s.CREATE_DEBIT_MEMO_FLAG,
                    s.ENFORCE_SHIP_TO_LOCATION_CODE,
                    s.RECEIVING_ROUTING_ID,
                    s.QTY_RCV_TOLERANCE,
                    s.QTY_RCV_EXCEPTION_CODE,
                    s.DAYS_EARLY_RECEIPT_ALLOWED,
                    s.DAYS_LATE_RECEIPT_ALLOWED,
                    s.ALLOW_SUBSTITUTE_RECEIPTS_FLAG,
                    s.ALLOW_UNORDERED_RECEIPTS_FLAG,
                    s.RECEIPT_DAYS_EXCEPTION_CODE,
                    s.INVOICE_CURRENCY_CODE,
                    s.INVOICE_AMOUNT_LIMIT,
                    s.MATCH_OPTION,
                    s.MATCH_APPROVAL_LEVEL,
                    s.PAYMENT_CURRENCY_CODE,
                    s.PAYMENT_PRIORITY,
                    s.PAY_GROUP_LOOKUP_CODE,
                    s.TOLERANCE_NAME,
                    s.SERVICES_TOLERANCE,
                    s.HOLD_ALL_PAYMENTS_FLAG,
                    s.HOLD_UNMATCHED_INVOICES_FLAG,
                    s.HOLD_FUTURE_PAYMENTS_FLAG,
                    s.HOLD_BY,
                    s.PAYMENT_HOLD_DATE,
                    s.HOLD_REASON,
                    s.TERMS_NAME,
                    s.TERMS_DATE_BASIS,
                    s.PAY_DATE_BASIS_LOOKUP_CODE,
                    s.BANK_CHARGE_DEDUCTION_TYPE,
                    s.ALWAYS_TAKE_DISC_FLAG,
                    s.EXCLUDE_FREIGHT_FROM_DISCOUNT,
                    s.EXCLUDE_TAX_FROM_DISCOUNT,
                    s.AUTO_CALCULATE_INTEREST_FLAG,
                    s.VAT_CODE,
                    s.VAT_REGISTRATION_NUM,
                    s.PAYMENT_METHOD_LOOKUP_CODE,
                    s.DELIVERY_CHANNEL_CODE,
                    s.BANK_INSTRUCTION1_CODE,
                    s.BANK_INSTRUCTION2_CODE,
                    s.BANK_INSTRUCTION_DETAILS,
                    s.SETTLEMENT_PRIORITY,
                    s.PAYMENT_TEXT_MESSAGE1,
                    s.PAYMENT_TEXT_MESSAGE2,
                    s.PAYMENT_TEXT_MESSAGE3,
                    s.IBY_BANK_CHARGE_BEARER,
                    s.PAYMENT_REASON_CODE,
                    s.PAYMENT_REASON_COMMENTS,
                    s.REMIT_ADVICE_DELIVERY_METHOD,
                    s.REMITTANCE_EMAIL,
                    s.REMITTANCE_FAX,
                    s.ATTRIBUTE_CATEGORY,
                    s.ATTRIBUTE1,  s.ATTRIBUTE2,  s.ATTRIBUTE3,  s.ATTRIBUTE4,  s.ATTRIBUTE5,
                    s.ATTRIBUTE6,  s.ATTRIBUTE7,  s.ATTRIBUTE8,  s.ATTRIBUTE9,  s.ATTRIBUTE10,
                    s.ATTRIBUTE11, s.ATTRIBUTE12, s.ATTRIBUTE13, s.ATTRIBUTE14, s.ATTRIBUTE15,
                    s.ATTRIBUTE16, s.ATTRIBUTE17, s.ATTRIBUTE18, s.ATTRIBUTE19, s.ATTRIBUTE20,
                    s.ATTRIBUTE_DATE1,  s.ATTRIBUTE_DATE2,  s.ATTRIBUTE_DATE3,  s.ATTRIBUTE_DATE4,  s.ATTRIBUTE_DATE5,
                    s.ATTRIBUTE_DATE6,  s.ATTRIBUTE_DATE7,  s.ATTRIBUTE_DATE8,  s.ATTRIBUTE_DATE9,  s.ATTRIBUTE_DATE10,
                    s.ATTRIBUTE_TIMESTAMP1,  s.ATTRIBUTE_TIMESTAMP2,  s.ATTRIBUTE_TIMESTAMP3,  s.ATTRIBUTE_TIMESTAMP4,  s.ATTRIBUTE_TIMESTAMP5,
                    s.ATTRIBUTE_TIMESTAMP6,  s.ATTRIBUTE_TIMESTAMP7,  s.ATTRIBUTE_TIMESTAMP8,  s.ATTRIBUTE_TIMESTAMP9,  s.ATTRIBUTE_TIMESTAMP10,
                    s.ATTRIBUTE_NUMBER1,  s.ATTRIBUTE_NUMBER2,  s.ATTRIBUTE_NUMBER3,  s.ATTRIBUTE_NUMBER4,  s.ATTRIBUTE_NUMBER5,
                    s.ATTRIBUTE_NUMBER6,  s.ATTRIBUTE_NUMBER7,  s.ATTRIBUTE_NUMBER8,  s.ATTRIBUTE_NUMBER9,  s.ATTRIBUTE_NUMBER10,
                    s.GLOBAL_ATTRIBUTE_CATEGORY,
                    s.GLOBAL_ATTRIBUTE1,  s.GLOBAL_ATTRIBUTE2,  s.GLOBAL_ATTRIBUTE3,  s.GLOBAL_ATTRIBUTE4,  s.GLOBAL_ATTRIBUTE5,
                    s.GLOBAL_ATTRIBUTE6,  s.GLOBAL_ATTRIBUTE7,  s.GLOBAL_ATTRIBUTE8,  s.GLOBAL_ATTRIBUTE9,  s.GLOBAL_ATTRIBUTE10,
                    s.GLOBAL_ATTRIBUTE11, s.GLOBAL_ATTRIBUTE12, s.GLOBAL_ATTRIBUTE13, s.GLOBAL_ATTRIBUTE14, s.GLOBAL_ATTRIBUTE15,
                    s.GLOBAL_ATTRIBUTE16, s.GLOBAL_ATTRIBUTE17, s.GLOBAL_ATTRIBUTE18, s.GLOBAL_ATTRIBUTE19, s.GLOBAL_ATTRIBUTE20,
                    s.GLOBAL_ATTRIBUTE_DATE1,  s.GLOBAL_ATTRIBUTE_DATE2,  s.GLOBAL_ATTRIBUTE_DATE3,  s.GLOBAL_ATTRIBUTE_DATE4,  s.GLOBAL_ATTRIBUTE_DATE5,
                    s.GLOBAL_ATTRIBUTE_DATE6,  s.GLOBAL_ATTRIBUTE_DATE7,  s.GLOBAL_ATTRIBUTE_DATE8,  s.GLOBAL_ATTRIBUTE_DATE9,  s.GLOBAL_ATTRIBUTE_DATE10,
                    s.GLOBAL_ATTRIBUTE_TIMESTAMP1,  s.GLOBAL_ATTRIBUTE_TIMESTAMP2,  s.GLOBAL_ATTRIBUTE_TIMESTAMP3,  s.GLOBAL_ATTRIBUTE_TIMESTAMP4,  s.GLOBAL_ATTRIBUTE_TIMESTAMP5,
                    s.GLOBAL_ATTRIBUTE_TIMESTAMP6,  s.GLOBAL_ATTRIBUTE_TIMESTAMP7,  s.GLOBAL_ATTRIBUTE_TIMESTAMP8,  s.GLOBAL_ATTRIBUTE_TIMESTAMP9,  s.GLOBAL_ATTRIBUTE_TIMESTAMP10,
                    s.GLOBAL_ATTRIBUTE_NUMBER1,  s.GLOBAL_ATTRIBUTE_NUMBER2,  s.GLOBAL_ATTRIBUTE_NUMBER3,  s.GLOBAL_ATTRIBUTE_NUMBER4,  s.GLOBAL_ATTRIBUTE_NUMBER5,
                    s.GLOBAL_ATTRIBUTE_NUMBER6,  s.GLOBAL_ATTRIBUTE_NUMBER7,  s.GLOBAL_ATTRIBUTE_NUMBER8,  s.GLOBAL_ATTRIBUTE_NUMBER9,  s.GLOBAL_ATTRIBUTE_NUMBER10,
                    s.PO_ACK_REQD_CODE,
                    s.PO_ACK_REQD_DAYS,
                    s.INVOICE_CHANNEL,
                    s.PAYEE_SERVICE_LEVEL_CODE,
                    s.EXCLUSIVE_PAYMENT_FLAG,
                    s.OVERRIDE_B2B_COMM_CODE,
                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_POZ_SUP_SITE_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_POZ_SUP_SITE_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_OWNER.DMT_POZ_SUP_SITE_STG_TBL s
        SET    s.STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_POZ_SUP_SITE_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_SITES complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_SITES');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_SITES failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_SITES',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_SITES;


    -- ============================================================
    -- TRANSFORM_SITE_ASSIGNMENTS
    -- ============================================================
    PROCEDURE TRANSFORM_SITE_ASSIGNMENTS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_ok_count   NUMBER := 0;
        l_fail_count NUMBER := 0;
        l_prefix     VARCHAR2(30);

    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_SITE_ASSIGNMENTS start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_SITE_ASSIGNMENTS');
        l_prefix := get_prefix(p_run_id);


        -- Accumulate, never overwrite (section 5): ERROR_TEXT is append-only.
        -- The former reprocess-time ERROR_TEXT reset (which was also unscoped —
        -- it hit every FAILED row in the table regardless of scenario) is
        -- removed; the FAILED reselection below stays scenario-scoped via the
        -- shared p_scenario_id predicate.

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_OWNER.DMT_POZ_SUP_SITE_ASSN_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    FBDI_CSV_ID,
                    IMPORT_ACTION,
                    VENDOR_NAME,
                    VENDOR_SITE_CODE,
                    PROCUREMENT_BUSINESS_UNIT_NAME,
                    BUSINESS_UNIT_NAME,
                    BILL_TO_BU_NAME,
                    SHIP_TO_LOCATION_CODE,
                    BILL_TO_LOCATION_CODE,
                    ALLOW_AWT_FLAG,
                    AWT_GROUP_NAME,
                    ACCTS_PAY_CONCAT_SEGMENTS,
                    PREPAY_CONCAT_SEGMENTS,
                    FUTURE_DATED_CONCAT_SEGMENTS,
                    DISTRIBUTION_SET_NAME,
                    INACTIVE_DATE,
                    STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    NULL,
                    s.IMPORT_ACTION,
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.VENDOR_NAME),
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.VENDOR_SITE_CODE, 15),
                    s.PROCUREMENT_BUSINESS_UNIT_NAME,
                    s.BUSINESS_UNIT_NAME,
                    NVL(s.BILL_TO_BU_NAME, s.BUSINESS_UNIT_NAME),
                    s.SHIP_TO_LOCATION_CODE,
                    s.BILL_TO_LOCATION_CODE,
                    s.ALLOW_AWT_FLAG,
                    s.AWT_GROUP_NAME,
                    s.ACCTS_PAY_CONCAT_SEGMENTS,
                    s.PREPAY_CONCAT_SEGMENTS,
                    s.FUTURE_DATED_CONCAT_SEGMENTS,
                    s.DISTRIBUTION_SET_NAME,
                    s.INACTIVE_DATE,
                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_POZ_SUP_SITE_ASSN_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_POZ_SUP_SITE_ASSN_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_OWNER.DMT_POZ_SUP_SITE_ASSN_STG_TBL s
        SET    s.STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_POZ_SUP_SITE_ASSN_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_SITE_ASSIGNMENTS complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_SITE_ASSIGNMENTS');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_SITE_ASSIGNMENTS failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_SITE_ASSIGNMENTS',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_SITE_ASSIGNMENTS;


    -- ============================================================
    -- TRANSFORM_CONTACTS
    -- ============================================================
    PROCEDURE TRANSFORM_CONTACTS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_ok_count   NUMBER := 0;
        l_fail_count NUMBER := 0;
        l_prefix     VARCHAR2(30);

    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_CONTACTS start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_CONTACTS');
        l_prefix := get_prefix(p_run_id);


        -- Accumulate, never overwrite (section 5): ERROR_TEXT is append-only.
        -- The former reprocess-time ERROR_TEXT reset (which was also unscoped —
        -- it hit every FAILED row in the table regardless of scenario) is
        -- removed; the FAILED reselection below stays scenario-scoped via the
        -- shared p_scenario_id predicate.

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_OWNER.DMT_POZ_SUP_CONTACTS_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    FBDI_CSV_ID,
                    IMPORT_ACTION,
                    VENDOR_NAME,
                    PREFIX,
                    FIRST_NAME,
                    FIRST_NAME_NEW,
                    MIDDLE_NAME,
                    LAST_NAME,
                    LAST_NAME_NEW,
                    TITLE,
                    PRIMARY_ADMIN_CONTACT,
                    EMAIL_ADDRESS,
                    EMAIL_ADDRESS_NEW,
                    PHONE_COUNTRY_CODE,
                    AREA_CODE,
                    PHONE,
                    PHONE_EXTENSION,
                    FAX_COUNTRY_CODE,
                    FAX_AREA_CODE,
                    FAX,
                    MOBILE_COUNTRY_CODE,
                    MOBILE_AREA_CODE,
                    MOBILE,
                    INACTIVE_DATE,
                    ATTRIBUTE_CATEGORY,
                    ATTRIBUTE1,  ATTRIBUTE2,  ATTRIBUTE3,  ATTRIBUTE4,  ATTRIBUTE5,
                    ATTRIBUTE6,  ATTRIBUTE7,  ATTRIBUTE8,  ATTRIBUTE9,  ATTRIBUTE10,
                    ATTRIBUTE11, ATTRIBUTE12, ATTRIBUTE13, ATTRIBUTE14, ATTRIBUTE15,
                    ATTRIBUTE16, ATTRIBUTE17, ATTRIBUTE18, ATTRIBUTE19, ATTRIBUTE20,
                    ATTRIBUTE21, ATTRIBUTE22, ATTRIBUTE23, ATTRIBUTE24, ATTRIBUTE25,
                    ATTRIBUTE26, ATTRIBUTE27, ATTRIBUTE28, ATTRIBUTE29, ATTRIBUTE30,
                    ATTRIBUTE_NUMBER1,  ATTRIBUTE_NUMBER2,  ATTRIBUTE_NUMBER3,  ATTRIBUTE_NUMBER4,  ATTRIBUTE_NUMBER5,
                    ATTRIBUTE_NUMBER6,  ATTRIBUTE_NUMBER7,  ATTRIBUTE_NUMBER8,  ATTRIBUTE_NUMBER9,  ATTRIBUTE_NUMBER10,
                    ATTRIBUTE_NUMBER11, ATTRIBUTE_NUMBER12,
                    ATTRIBUTE_DATE1,  ATTRIBUTE_DATE2,  ATTRIBUTE_DATE3,  ATTRIBUTE_DATE4,  ATTRIBUTE_DATE5,
                    ATTRIBUTE_DATE6,  ATTRIBUTE_DATE7,  ATTRIBUTE_DATE8,  ATTRIBUTE_DATE9,  ATTRIBUTE_DATE10,
                    ATTRIBUTE_DATE11, ATTRIBUTE_DATE12,
                    USER_ACCOUNT_ACTION,
                    ROLE1,  ROLE2,  ROLE3,  ROLE4,  ROLE5,
                    ROLE6,  ROLE7,  ROLE8,  ROLE9,  ROLE10,
                    STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    NULL,
                    s.IMPORT_ACTION,
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.VENDOR_NAME),
                    s.PREFIX,
                    s.FIRST_NAME,
                    s.FIRST_NAME_NEW,
                    s.MIDDLE_NAME,
                    s.LAST_NAME,
                    s.LAST_NAME_NEW,
                    s.TITLE,
                    s.PRIMARY_ADMIN_CONTACT,
                    s.EMAIL_ADDRESS,
                    s.EMAIL_ADDRESS_NEW,
                    s.PHONE_COUNTRY_CODE,
                    s.AREA_CODE,
                    s.PHONE,
                    s.PHONE_EXTENSION,
                    s.FAX_COUNTRY_CODE,
                    s.FAX_AREA_CODE,
                    s.FAX,
                    s.MOBILE_COUNTRY_CODE,
                    s.MOBILE_AREA_CODE,
                    s.MOBILE,
                    s.INACTIVE_DATE,
                    s.ATTRIBUTE_CATEGORY,
                    s.ATTRIBUTE1,  s.ATTRIBUTE2,  s.ATTRIBUTE3,  s.ATTRIBUTE4,  s.ATTRIBUTE5,
                    s.ATTRIBUTE6,  s.ATTRIBUTE7,  s.ATTRIBUTE8,  s.ATTRIBUTE9,  s.ATTRIBUTE10,
                    s.ATTRIBUTE11, s.ATTRIBUTE12, s.ATTRIBUTE13, s.ATTRIBUTE14, s.ATTRIBUTE15,
                    s.ATTRIBUTE16, s.ATTRIBUTE17, s.ATTRIBUTE18, s.ATTRIBUTE19, s.ATTRIBUTE20,
                    s.ATTRIBUTE21, s.ATTRIBUTE22, s.ATTRIBUTE23, s.ATTRIBUTE24, s.ATTRIBUTE25,
                    s.ATTRIBUTE26, s.ATTRIBUTE27, s.ATTRIBUTE28, s.ATTRIBUTE29, s.ATTRIBUTE30,
                    s.ATTRIBUTE_NUMBER1,  s.ATTRIBUTE_NUMBER2,  s.ATTRIBUTE_NUMBER3,  s.ATTRIBUTE_NUMBER4,  s.ATTRIBUTE_NUMBER5,
                    s.ATTRIBUTE_NUMBER6,  s.ATTRIBUTE_NUMBER7,  s.ATTRIBUTE_NUMBER8,  s.ATTRIBUTE_NUMBER9,  s.ATTRIBUTE_NUMBER10,
                    s.ATTRIBUTE_NUMBER11, s.ATTRIBUTE_NUMBER12,
                    s.ATTRIBUTE_DATE1,  s.ATTRIBUTE_DATE2,  s.ATTRIBUTE_DATE3,  s.ATTRIBUTE_DATE4,  s.ATTRIBUTE_DATE5,
                    s.ATTRIBUTE_DATE6,  s.ATTRIBUTE_DATE7,  s.ATTRIBUTE_DATE8,  s.ATTRIBUTE_DATE9,  s.ATTRIBUTE_DATE10,
                    s.ATTRIBUTE_DATE11, s.ATTRIBUTE_DATE12,
                    s.USER_ACCOUNT_ACTION,
                    s.ROLE1,  s.ROLE2,  s.ROLE3,  s.ROLE4,  s.ROLE5,
                    s.ROLE6,  s.ROLE7,  s.ROLE8,  s.ROLE9,  s.ROLE10,
                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_POZ_SUP_CONTACTS_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_POZ_SUP_CONTACTS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_OWNER.DMT_POZ_SUP_CONTACTS_STG_TBL s
        SET    s.STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_POZ_SUP_CONTACTS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_CONTACTS complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_CONTACTS');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_CONTACTS failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_CONTACTS',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_CONTACTS;

END DMT_POZ_SUP_TRANSFORM_PKG;
/
