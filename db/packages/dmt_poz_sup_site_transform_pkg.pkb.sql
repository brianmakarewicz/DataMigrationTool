-- PACKAGE BODY DMT_POZ_SUP_SITE_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_POZ_SUP_SITE_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_POZ_SUP_SITE_TRANSFORM_PKG Body
-- One supplier-family object. Procedure relocated verbatim from
-- the former shared DMT_POZ_SUP_TRANSFORM_PKG (backlog #43).
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_POZ_SUP_SITE_TRANSFORM_PKG';

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
        INSERT INTO DMT_POZ_SUP_SITE_TFM_TBL (
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
                    TFM_STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    NULL,
                    s.IMPORT_ACTION,
                    -- Cross-object reference to the parent Supplier: resolve via xref
                    -- so this site can load against a supplier from any prior run.
                    DMT_XREF_PKG.SUPPLIER_NAME(s.VENDOR_NAME),
                    s.PROCUREMENT_BUSINESS_UNIT_NAME,
                    s.PARTY_SITE_NAME,
                    -- The site's OWN business key: stays PREFIXED (own-key, not a ref).
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
        FROM DMT_POZ_SUP_SITE_STG_TBL s
        WHERE (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
            /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1 FROM DMT_POZ_SUP_SITE_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        -- Honor pre-validation rejections in EVERY run mode (mirrors Suppliers).
        -- ALL/FAILED modes do not filter on STG_STATUS, so without this a row the
        -- validator rejected (parent supplier has no LOADED row) would still be
        -- transformed and sent to Fusion, and its TFM row would hide the
        -- [PRE_VALIDATION] error in the record view. STG_SEQUENCE_ID restarts per
        -- STG table and the supplier objects can share a RUN_ID, so scope to this
        -- object's SUB_OBJECT.
        AND NOT EXISTS (
            SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
            WHERE  e.RUN_ID          = p_run_id
            AND    e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    e.SUB_OBJECT      = 'Supplier Sites'
            AND    e.ERROR_TEXT LIKE '[PRE_VALIDATION]%'
        )
        -- Deterministic identity assignment: order the INSERT..SELECT by the
        -- STG PK so the TFM PK (GENERATED identity) is assigned in staging order.
        -- The generator emits rows ORDER BY TFM_SEQUENCE_ID, so this keeps the
        -- generated file's row order reproducible (byte-stable golden compare).
        ORDER BY s.STG_SEQUENCE_ID;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_POZ_SUP_SITE_STG_TBL s
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
            SELECT 1 FROM DMT_POZ_SUP_SITE_TFM_TBL t
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
            -- Record [TRANSFORM_ERROR] for this proc's in-scope STG rows so the
            -- record-detail anti-join surfaces them as FAILED instead of leaving
            -- the object unaccounted. SQLERRM captured to a local first (not a
            -- valid SQL identifier inside INSERT..SELECT). Backlog #14.
            DECLARE
                l_errm VARCHAR2(4000) := SUBSTR(SQLERRM, 1, 3900);
            BEGIN
                INSERT INTO DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, 'SupplierSites', 'Supplier Sites', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_POZ_SUP_SITE_STG_TBL s
                WHERE  ( DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
                         OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED','TRANSFORM_FAILED')) )
                AND    (p_scenario_id IS NULL OR s.SCENARIO_ID = p_scenario_id
                        OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_POZ_SUP_SITE_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Supplier Sites');
                UPDATE DMT_POZ_SUP_SITE_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Supplier Sites')
                AND    STG_STATUS IN ('NEW','TRANSFORMED')
                AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                        OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));
            EXCEPTION WHEN OTHERS THEN NULL;  -- fail-path diagnostics must never throw
            END;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_SITES failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_SITES',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_SITES;

END DMT_POZ_SUP_SITE_TRANSFORM_PKG;
/
