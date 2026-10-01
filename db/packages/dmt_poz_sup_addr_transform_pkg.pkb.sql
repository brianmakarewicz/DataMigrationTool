-- PACKAGE BODY DMT_POZ_SUP_ADDR_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_POZ_SUP_ADDR_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_POZ_SUP_ADDR_TRANSFORM_PKG Body
-- One supplier-family object. Procedure relocated verbatim from
-- the former shared DMT_POZ_SUP_TRANSFORM_PKG (backlog #43).
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_POZ_SUP_ADDR_TRANSFORM_PKG';

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
        INSERT INTO DMT_POZ_SUP_ADDR_TFM_TBL (
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
                    TFM_STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    NULL,
                    s.IMPORT_ACTION,
                    -- Cross-object reference to the parent Supplier. Resolve to the
                    -- supplier's actual Fusion value (this run's prefix, a prior run's,
                    -- or unprefixed if pre-existing) so this child runs standalone.
                    DMT_XREF_PKG.SUPPLIER_NAME(s.VENDOR_NAME),
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
        FROM DMT_POZ_SUP_ADDR_STG_TBL s
        WHERE (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
            /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1 FROM DMT_POZ_SUP_ADDR_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        -- Deterministic identity assignment: order the INSERT..SELECT by the
        -- STG PK so the TFM PK (GENERATED identity) is assigned in staging order.
        -- The generator emits rows ORDER BY TFM_SEQUENCE_ID, so this keeps the
        -- generated file's row order reproducible (byte-stable golden compare).
        ORDER BY s.STG_SEQUENCE_ID;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_POZ_SUP_ADDR_STG_TBL s
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
            SELECT 1 FROM DMT_POZ_SUP_ADDR_TFM_TBL t
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
            -- Record [TRANSFORM_ERROR] for this proc's in-scope STG rows so the
            -- record-detail anti-join surfaces them as FAILED instead of leaving
            -- the object unaccounted. SQLERRM captured to a local first (not a
            -- valid SQL identifier inside INSERT..SELECT). Backlog #14.
            DECLARE
                l_errm VARCHAR2(4000) := SUBSTR(SQLERRM, 1, 3900);
            BEGIN
                INSERT INTO DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, 'SupplierAddresses', 'Supplier Addresses', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_POZ_SUP_ADDR_STG_TBL s
                WHERE  ( DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
                         OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED','TRANSFORM_FAILED')) )
                AND    (p_scenario_id IS NULL OR s.SCENARIO_ID = p_scenario_id
                        OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_POZ_SUP_ADDR_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Supplier Addresses');
                UPDATE DMT_POZ_SUP_ADDR_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Supplier Addresses')
                AND    STG_STATUS IN ('NEW','TRANSFORMED');
            EXCEPTION WHEN OTHERS THEN NULL;  -- fail-path diagnostics must never throw
            END;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_ADDRESSES failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_ADDRESSES',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_ADDRESSES;

END DMT_POZ_SUP_ADDR_TRANSFORM_PKG;
/
