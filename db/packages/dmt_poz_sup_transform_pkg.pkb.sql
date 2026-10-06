-- PACKAGE BODY DMT_POZ_SUP_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_POZ_SUP_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_POZ_SUP_TRANSFORM_PKG Body
-- One supplier-family object. Procedure relocated verbatim from
-- the former shared DMT_POZ_SUP_TRANSFORM_PKG (backlog #43).
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_POZ_SUP_TRANSFORM_PKG';

    -- --------------------------------------------------------
    -- Private: read run prefix from DMT_PIPELINE_RUN_TBL
    -- --------------------------------------------------------
    FUNCTION get_prefix (p_run_id IN NUMBER) RETURN VARCHAR2 IS
        l_prefix VARCHAR2(30);
    BEGIN
        SELECT PREFIX
        INTO   l_prefix
        FROM   DMT_PIPELINE_RUN_TBL
        WHERE  RUN_ID = p_run_id;
        RETURN l_prefix;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001,
                'RUN_ID ' || p_run_id || ' not found in DMT_PIPELINE_RUN_TBL');
    END get_prefix;


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
        INSERT INTO DMT_POZ_SUPPLIERS_TFM_TBL (
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
                    TFM_STATUS,
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
        FROM DMT_POZ_SUPPLIERS_STG_TBL s
        WHERE (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
            /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1 FROM DMT_POZ_SUPPLIERS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        -- Honor pre-validation rejections in EVERY run mode. ALL/FAILED modes do
        -- not filter on STG_STATUS, so without this a row the validator rejected
        -- (e.g. missing mandatory VENDOR_NAME) would still be transformed and
        -- abort the set-based INSERT (ORA-01400). Excluding rows that have a
        -- [PRE_VALIDATION] error for this run keeps a bad row out of TFM and the
        -- object from crashing. (Scoped fix of the ALL-mode-bypass item, §12.)
        AND NOT EXISTS (
            SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
            WHERE  e.RUN_ID          = p_run_id
            AND    e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            -- STG_SEQUENCE_ID is polymorphic (a different STG table per SUB_OBJECT)
            -- and all 5 supplier objects share one RUN_ID, so scope to this object
            -- or a colliding child id would wrongly drop a valid supplier row.
            AND    e.SUB_OBJECT      = 'Suppliers'
            AND    e.ERROR_TEXT LIKE '[PRE_VALIDATION]%'
        )
        -- Deterministic identity assignment: order the INSERT..SELECT by the
        -- STG PK so the TFM PK (GENERATED identity) is assigned in staging order.
        -- The generator emits rows ORDER BY TFM_SEQUENCE_ID, so this keeps the
        -- generated file's row order reproducible (byte-stable golden compare).
        ORDER BY s.STG_SEQUENCE_ID;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_POZ_SUPPLIERS_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
            /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    EXISTS (
            SELECT 1 FROM DMT_POZ_SUPPLIERS_TFM_TBL t
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
            -- Record [TRANSFORM_ERROR] for this proc's in-scope STG rows so the
            -- record-detail anti-join surfaces them as FAILED instead of leaving
            -- the object unaccounted. SQLERRM captured to a local first (not a
            -- valid SQL identifier inside INSERT..SELECT). Backlog #14.
            DECLARE
                l_errm VARCHAR2(4000) := SUBSTR(SQLERRM, 1, 3900);
            BEGIN
                INSERT INTO DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, 'Suppliers', 'Suppliers', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_POZ_SUPPLIERS_STG_TBL s
                WHERE  ( DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
                         OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED','TRANSFORM_FAILED')) )
                AND    (p_scenario_id IS NULL OR s.SCENARIO_ID = p_scenario_id
                        OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_POZ_SUPPLIERS_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Suppliers');
                UPDATE DMT_POZ_SUPPLIERS_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Suppliers')
                AND    STG_STATUS IN ('NEW','TRANSFORMED')
                AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                        OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));
            EXCEPTION WHEN OTHERS THEN NULL;  -- fail-path diagnostics must never throw
            END;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_SUPPLIERS failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_SUPPLIERS',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_SUPPLIERS;

END DMT_POZ_SUP_TRANSFORM_PKG;
/
