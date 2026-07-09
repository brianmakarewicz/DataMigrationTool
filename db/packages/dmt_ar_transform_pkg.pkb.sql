-- PACKAGE BODY DMT_AR_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_AR_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_AR_TRANSFORM_PKG Body
-- ARInvoices transformation.
-- Applies run prefix to TRX_NUMBER.
-- Applies dependent prefix to customer account numbers.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_AR_TRANSFORM_PKG';

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
    -- TRANSFORM_LINES
    -- ============================================================
    PROCEDURE TRANSFORM_LINES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_prefix        VARCHAR2(30);
        l_dep_prefix    VARCHAR2(30);
        l_ok_count      NUMBER := 0;
        l_fail_count    NUMBER := 0;

    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_LINES start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_LINES');

        l_prefix     := get_prefix(p_run_id);
        l_dep_prefix := get_dep_prefix(p_run_id);


        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_OWNER.DMT_RA_LINES_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_OWNER.DMT_RA_LINES_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    FBDI_CSV_ID,
                    ORG_ID,
                    BATCH_SOURCE_NAME,
                    CUST_TRX_TYPE_NAME,
                    TERM_NAME,
                    TRX_DATE,
                    GL_DATE,
                    TRX_NUMBER,
                    ORIG_SYSTEM_BILL_CUSTOMER_REF,
                    ORIG_SYSTEM_BILL_ADDRESS_REF,
                    ORIG_SYSTEM_BILL_CONTACT_REF,
                    ORIG_SYS_SHIP_PARTY_REF,
                    ORIG_SYS_SHIP_PARTY_SITE_REF,
                    ORIG_SYS_SHIP_PTY_CONTACT_REF,
                    ORIG_SYSTEM_SHIP_CUSTOMER_REF,
                    ORIG_SYSTEM_SHIP_ADDRESS_REF,
                    ORIG_SYSTEM_SHIP_CONTACT_REF,
                    ORIG_SYS_SOLD_PARTY_REF,
                    ORIG_SYSTEM_SOLD_CUSTOMER_REF,
                    BILL_CUSTOMER_ACCOUNT_NUMBER,
                    BILL_CUSTOMER_SITE_NUMBER,
                    BILL_CONTACT_PARTY_NUMBER,
                    SHIP_CUSTOMER_ACCOUNT_NUMBER,
                    SHIP_CUSTOMER_SITE_NUMBER,
                    SHIP_CONTACT_PARTY_NUMBER,
                    SOLD_CUSTOMER_ACCOUNT_NUMBER,
                    LINE_TYPE,
                    DESCRIPTION,
                    CURRENCY_CODE,
                    CONVERSION_TYPE,
                    CONVERSION_DATE,
                    CONVERSION_RATE,
                    AMOUNT,
                    QUANTITY,
                    QUANTITY_ORDERED,
                    UNIT_SELLING_PRICE,
                    UNIT_STANDARD_PRICE,
                    INTERFACE_LINE_CONTEXT,
                    INTERFACE_LINE_ATTRIBUTE1,
                    INTERFACE_LINE_ATTRIBUTE2,
                    INTERFACE_LINE_ATTRIBUTE3,
                    INTERFACE_LINE_ATTRIBUTE4,
                    INTERFACE_LINE_ATTRIBUTE5,
                    INTERFACE_LINE_ATTRIBUTE6,
                    INTERFACE_LINE_ATTRIBUTE7,
                    INTERFACE_LINE_ATTRIBUTE8,
                    INTERFACE_LINE_ATTRIBUTE9,
                    INTERFACE_LINE_ATTRIBUTE10,
                    INTERFACE_LINE_ATTRIBUTE11,
                    INTERFACE_LINE_ATTRIBUTE12,
                    INTERFACE_LINE_ATTRIBUTE13,
                    INTERFACE_LINE_ATTRIBUTE14,
                    INTERFACE_LINE_ATTRIBUTE15,
                    PRIMARY_SALESREP_NUMBER,
                    TAX_CODE,
                    LEGAL_ENTITY_IDENTIFIER,
                    ACCTD_AMOUNT,
                    SALES_ORDER,
                    SALES_ORDER_DATE,
                    SHIP_DATE_ACTUAL,
                    WAREHOUSE_CODE,
                    UOM_CODE,
                    UOM_NAME,
                    INVOICING_RULE_NAME,
                    ACCOUNTING_RULE_NAME,
                    ACCOUNTING_RULE_DURATION,
                    RULE_START_DATE,
                    RULE_END_DATE,
                    REASON_CODE_MEANING,
                    LAST_PERIOD_TO_CREDIT,
                    TRX_BUSINESS_CATEGORY,
                    PRODUCT_FISC_CLASSIFICATION,
                    PRODUCT_CATEGORY,
                    PRODUCT_TYPE,
                    LINE_INTENDED_USE,
                    ASSESSABLE_VALUE,
                    DOCUMENT_SUB_TYPE,
                    DEFAULT_TAXATION_COUNTRY,
                    USER_DEFINED_FISC_CLASS,
                    TAX_INVOICE_NUMBER,
                    TAX_INVOICE_DATE,
                    TAX_REGIME_CODE,
                    TAX,
                    TAX_STATUS_CODE,
                    TAX_RATE_CODE,
                    TAX_JURISDICTION_CODE,
                    FIRST_PTY_REG_NUM,
                    THIRD_PTY_REG_NUM,
                    FINAL_DISCHARGE_LOCATION_CODE,
                    TAXABLE_AMOUNT,
                    TAXABLE_FLAG,
                    TAX_EXEMPT_FLAG,
                    TAX_EXEMPT_REASON_CODE,
                    TAX_EXEMPT_REASON_CODE_MEANING,
                    TAX_EXEMPT_NUMBER,
                    AMOUNT_INCLUDES_TAX_FLAG,
                    TAX_PRECEDENCE,
                    CREDIT_METHOD_FOR_ACCT_RULE,
                    CREDIT_METHOD_FOR_INSTALLMENTS,
                    REASON_CODE,
                    TAX_RATE,
                    FOB_POINT,
                    SHIP_VIA,
                    WAYBILL_NUMBER,
                    SALES_ORDER_LINE,
                    SALES_ORDER_SOURCE,
                    SALES_ORDER_REVISION,
                    PURCHASE_ORDER,
                    PURCHASE_ORDER_REVISION,
                    PURCHASE_ORDER_DATE,
                    AGREEMENT_NAME,
                    MEMO_LINE_NAME,
                    DOCUMENT_NUMBER,
                    ORIG_SYSTEM_BATCH_NAME,
                    LINK_TO_LINE_CONTEXT,
                    LINK_TO_LINE_ATTRIBUTE1,
                    LINK_TO_LINE_ATTRIBUTE2,
                    LINK_TO_LINE_ATTRIBUTE3,
                    LINK_TO_LINE_ATTRIBUTE4,
                    LINK_TO_LINE_ATTRIBUTE5,
                    LINK_TO_LINE_ATTRIBUTE6,
                    RECEIPT_METHOD_NAME,
                    PRINTING_OPTION,
                    RELATED_BATCH_SOURCE_NAME,
                    RELATED_TRX_NUMBER,
                    TRANSLATED_DESCRIPTION,
                    CONS_BILLING_NUMBER,
                    PROMISED_COMMITMENT_AMOUNT,
                    PAYMENT_SET_ID,
                    ORIGINAL_GL_DATE,
                    INVOICED_LINE_ACCTG_LEVEL,
                    OVERRIDE_AUTO_ACCOUNTING_FLAG,
                    HISTORICAL_FLAG,
                    DEFERRAL_EXCLUSION_FLAG,
                    BILLING_DATE,
                    ATTRIBUTE_CATEGORY,
                    ATTRIBUTE1,  ATTRIBUTE2,  ATTRIBUTE3,  ATTRIBUTE4,  ATTRIBUTE5,
                    ATTRIBUTE6,  ATTRIBUTE7,  ATTRIBUTE8,  ATTRIBUTE9,  ATTRIBUTE10,
                    ATTRIBUTE11, ATTRIBUTE12, ATTRIBUTE13, ATTRIBUTE14, ATTRIBUTE15,
                    HEADER_ATTRIBUTE_CATEGORY,
                    HEADER_ATTRIBUTE1,  HEADER_ATTRIBUTE2,  HEADER_ATTRIBUTE3,
                    HEADER_ATTRIBUTE4,  HEADER_ATTRIBUTE5,  HEADER_ATTRIBUTE6,
                    HEADER_ATTRIBUTE7,  HEADER_ATTRIBUTE8,  HEADER_ATTRIBUTE9,
                    HEADER_ATTRIBUTE10, HEADER_ATTRIBUTE11, HEADER_ATTRIBUTE12,
                    HEADER_ATTRIBUTE13, HEADER_ATTRIBUTE14, HEADER_ATTRIBUTE15,
                    BU_NAME,
                    COMMENTS,
                    INTERNAL_NOTES,
                    RESET_TRX_DATE_FLAG,
                    TFM_STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    NULL,
                    s.ORG_ID,
                    s.BATCH_SOURCE_NAME,
                    s.CUST_TRX_TYPE_NAME,
                    s.TERM_NAME,
                    s.TRX_DATE,
                    s.GL_DATE,
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.TRX_NUMBER, 30),
                    s.ORIG_SYSTEM_BILL_CUSTOMER_REF,
                    s.ORIG_SYSTEM_BILL_ADDRESS_REF,
                    s.ORIG_SYSTEM_BILL_CONTACT_REF,
                    s.ORIG_SYS_SHIP_PARTY_REF,
                    s.ORIG_SYS_SHIP_PARTY_SITE_REF,
                    s.ORIG_SYS_SHIP_PTY_CONTACT_REF,
                    s.ORIG_SYSTEM_SHIP_CUSTOMER_REF,
                    s.ORIG_SYSTEM_SHIP_ADDRESS_REF,
                    s.ORIG_SYSTEM_SHIP_CONTACT_REF,
                    s.ORIG_SYS_SOLD_PARTY_REF,
                    s.ORIG_SYSTEM_SOLD_CUSTOMER_REF,

                    CASE WHEN s.BILL_CUSTOMER_ACCOUNT_NUMBER IS NOT NULL
                         THEN DMT_UTIL_PKG.PREFIXED(l_dep_prefix, s.BILL_CUSTOMER_ACCOUNT_NUMBER, 30)
                    END,
                    s.BILL_CUSTOMER_SITE_NUMBER,
                    s.BILL_CONTACT_PARTY_NUMBER,
                    CASE WHEN s.SHIP_CUSTOMER_ACCOUNT_NUMBER IS NOT NULL
                         THEN DMT_UTIL_PKG.PREFIXED(l_dep_prefix, s.SHIP_CUSTOMER_ACCOUNT_NUMBER, 30)
                    END,
                    s.SHIP_CUSTOMER_SITE_NUMBER,
                    s.SHIP_CONTACT_PARTY_NUMBER,
                    CASE WHEN s.SOLD_CUSTOMER_ACCOUNT_NUMBER IS NOT NULL
                         THEN DMT_UTIL_PKG.PREFIXED(l_dep_prefix, s.SOLD_CUSTOMER_ACCOUNT_NUMBER, 30)
                    END,
                    s.LINE_TYPE,
                    s.DESCRIPTION,
                    s.CURRENCY_CODE,


                    NVL(s.CONVERSION_TYPE, 'User'),
                    s.CONVERSION_DATE,
                    s.CONVERSION_RATE,
                    s.AMOUNT,
                    s.QUANTITY,
                    s.QUANTITY_ORDERED,
                    s.UNIT_SELLING_PRICE,
                    s.UNIT_STANDARD_PRICE,



                    NVL(s.INTERFACE_LINE_CONTEXT, 'DMT Migration'),
                    NVL(s.INTERFACE_LINE_ATTRIBUTE1, DMT_UTIL_PKG.PREFIXED(l_prefix, s.TRX_NUMBER, 30)),

                    NVL(s.INTERFACE_LINE_ATTRIBUTE2, TO_CHAR(s.STG_SEQUENCE_ID)),
                    s.INTERFACE_LINE_ATTRIBUTE3,
                    s.INTERFACE_LINE_ATTRIBUTE4,
                    s.INTERFACE_LINE_ATTRIBUTE5,
                    s.INTERFACE_LINE_ATTRIBUTE6,
                    s.INTERFACE_LINE_ATTRIBUTE7,
                    s.INTERFACE_LINE_ATTRIBUTE8,
                    s.INTERFACE_LINE_ATTRIBUTE9,
                    s.INTERFACE_LINE_ATTRIBUTE10,
                    s.INTERFACE_LINE_ATTRIBUTE11,
                    s.INTERFACE_LINE_ATTRIBUTE12,
                    s.INTERFACE_LINE_ATTRIBUTE13,
                    s.INTERFACE_LINE_ATTRIBUTE14,
                    s.INTERFACE_LINE_ATTRIBUTE15,
                    s.PRIMARY_SALESREP_NUMBER,
                    s.TAX_CODE,
                    s.LEGAL_ENTITY_IDENTIFIER,
                    s.ACCTD_AMOUNT,
                    s.SALES_ORDER,
                    s.SALES_ORDER_DATE,
                    s.SHIP_DATE_ACTUAL,
                    s.WAREHOUSE_CODE,
                    s.UOM_CODE,
                    s.UOM_NAME,
                    s.INVOICING_RULE_NAME,
                    s.ACCOUNTING_RULE_NAME,
                    s.ACCOUNTING_RULE_DURATION,
                    s.RULE_START_DATE,
                    s.RULE_END_DATE,
                    s.REASON_CODE_MEANING,
                    s.LAST_PERIOD_TO_CREDIT,
                    s.TRX_BUSINESS_CATEGORY,
                    s.PRODUCT_FISC_CLASSIFICATION,
                    s.PRODUCT_CATEGORY,
                    s.PRODUCT_TYPE,
                    s.LINE_INTENDED_USE,
                    s.ASSESSABLE_VALUE,
                    s.DOCUMENT_SUB_TYPE,
                    s.DEFAULT_TAXATION_COUNTRY,
                    s.USER_DEFINED_FISC_CLASS,
                    s.TAX_INVOICE_NUMBER,
                    s.TAX_INVOICE_DATE,
                    s.TAX_REGIME_CODE,
                    s.TAX,
                    s.TAX_STATUS_CODE,
                    s.TAX_RATE_CODE,
                    s.TAX_JURISDICTION_CODE,
                    s.FIRST_PTY_REG_NUM,
                    s.THIRD_PTY_REG_NUM,
                    s.FINAL_DISCHARGE_LOCATION_CODE,
                    s.TAXABLE_AMOUNT,
                    s.TAXABLE_FLAG,
                    s.TAX_EXEMPT_FLAG,
                    s.TAX_EXEMPT_REASON_CODE,
                    s.TAX_EXEMPT_REASON_CODE_MEANING,
                    s.TAX_EXEMPT_NUMBER,
                    s.AMOUNT_INCLUDES_TAX_FLAG,
                    s.TAX_PRECEDENCE,
                    s.CREDIT_METHOD_FOR_ACCT_RULE,
                    s.CREDIT_METHOD_FOR_INSTALLMENTS,
                    s.REASON_CODE,
                    s.TAX_RATE,
                    s.FOB_POINT,
                    s.SHIP_VIA,
                    s.WAYBILL_NUMBER,
                    s.SALES_ORDER_LINE,
                    s.SALES_ORDER_SOURCE,
                    s.SALES_ORDER_REVISION,
                    s.PURCHASE_ORDER,
                    s.PURCHASE_ORDER_REVISION,
                    s.PURCHASE_ORDER_DATE,
                    s.AGREEMENT_NAME,
                    s.MEMO_LINE_NAME,
                    s.DOCUMENT_NUMBER,
                    s.ORIG_SYSTEM_BATCH_NAME,
                    s.LINK_TO_LINE_CONTEXT,
                    s.LINK_TO_LINE_ATTRIBUTE1,
                    s.LINK_TO_LINE_ATTRIBUTE2,
                    s.LINK_TO_LINE_ATTRIBUTE3,
                    s.LINK_TO_LINE_ATTRIBUTE4,
                    s.LINK_TO_LINE_ATTRIBUTE5,
                    s.LINK_TO_LINE_ATTRIBUTE6,
                    s.RECEIPT_METHOD_NAME,
                    s.PRINTING_OPTION,
                    s.RELATED_BATCH_SOURCE_NAME,
                    s.RELATED_TRX_NUMBER,
                    s.TRANSLATED_DESCRIPTION,
                    s.CONS_BILLING_NUMBER,
                    s.PROMISED_COMMITMENT_AMOUNT,
                    s.PAYMENT_SET_ID,
                    s.ORIGINAL_GL_DATE,
                    s.INVOICED_LINE_ACCTG_LEVEL,
                    s.OVERRIDE_AUTO_ACCOUNTING_FLAG,
                    s.HISTORICAL_FLAG,
                    s.DEFERRAL_EXCLUSION_FLAG,
                    s.BILLING_DATE,
                    s.ATTRIBUTE_CATEGORY,
                    s.ATTRIBUTE1,  s.ATTRIBUTE2,  s.ATTRIBUTE3,  s.ATTRIBUTE4,  s.ATTRIBUTE5,
                    s.ATTRIBUTE6,  s.ATTRIBUTE7,  s.ATTRIBUTE8,  s.ATTRIBUTE9,  s.ATTRIBUTE10,
                    s.ATTRIBUTE11, s.ATTRIBUTE12, s.ATTRIBUTE13, s.ATTRIBUTE14, s.ATTRIBUTE15,
                    s.HEADER_ATTRIBUTE_CATEGORY,
                    s.HEADER_ATTRIBUTE1,  s.HEADER_ATTRIBUTE2,  s.HEADER_ATTRIBUTE3,
                    s.HEADER_ATTRIBUTE4,  s.HEADER_ATTRIBUTE5,  s.HEADER_ATTRIBUTE6,
                    s.HEADER_ATTRIBUTE7,  s.HEADER_ATTRIBUTE8,  s.HEADER_ATTRIBUTE9,
                    s.HEADER_ATTRIBUTE10, s.HEADER_ATTRIBUTE11, s.HEADER_ATTRIBUTE12,
                    s.HEADER_ATTRIBUTE13, s.HEADER_ATTRIBUTE14, s.HEADER_ATTRIBUTE15,
                    s.BU_NAME,
                    s.COMMENTS,
                    s.INTERNAL_NOTES,
                    s.RESET_TRX_DATE_FLAG,
                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_RA_LINES_STG_TBL s
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
            SELECT 1 FROM DMT_OWNER.DMT_RA_LINES_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_OWNER.DMT_RA_LINES_STG_TBL s
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
            SELECT 1 FROM DMT_OWNER.DMT_RA_LINES_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_LINES complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_LINES');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_LINES failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_LINES',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_LINES;


    -- ============================================================
    -- TRANSFORM_DISTS
    -- ============================================================
    PROCEDURE TRANSFORM_DISTS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_ok_count      NUMBER := 0;
        l_fail_count    NUMBER := 0;

    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_DISTS start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_DISTS');


        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_OWNER.DMT_RA_DISTS_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_OWNER.DMT_RA_DISTS_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    FBDI_CSV_ID,
                    ORG_ID,
                    ACCOUNT_CLASS,
                    AMOUNT,
                    PERCENT,
                    ACCTD_AMOUNT,
                    INTERFACE_LINE_CONTEXT,
                    INTERFACE_LINE_ATTRIBUTE1,
                    INTERFACE_LINE_ATTRIBUTE2,
                    INTERFACE_LINE_ATTRIBUTE3,
                    INTERFACE_LINE_ATTRIBUTE4,
                    INTERFACE_LINE_ATTRIBUTE5,
                    INTERFACE_LINE_ATTRIBUTE6,
                    INTERFACE_LINE_ATTRIBUTE7,
                    INTERFACE_LINE_ATTRIBUTE8,
                    INTERFACE_LINE_ATTRIBUTE9,
                    INTERFACE_LINE_ATTRIBUTE10,
                    INTERFACE_LINE_ATTRIBUTE11,
                    INTERFACE_LINE_ATTRIBUTE12,
                    INTERFACE_LINE_ATTRIBUTE13,
                    INTERFACE_LINE_ATTRIBUTE14,
                    INTERFACE_LINE_ATTRIBUTE15,
                    SEGMENT1,  SEGMENT2,  SEGMENT3,  SEGMENT4,  SEGMENT5,
                    SEGMENT6,  SEGMENT7,  SEGMENT8,  SEGMENT9,  SEGMENT10,
                    SEGMENT11, SEGMENT12, SEGMENT13, SEGMENT14, SEGMENT15,
                    SEGMENT16, SEGMENT17, SEGMENT18, SEGMENT19, SEGMENT20,
                    SEGMENT21, SEGMENT22, SEGMENT23, SEGMENT24, SEGMENT25,
                    SEGMENT26, SEGMENT27, SEGMENT28, SEGMENT29, SEGMENT30,
                    COMMENTS,
                    ATTRIBUTE_CATEGORY,
                    ATTRIBUTE1,  ATTRIBUTE2,  ATTRIBUTE3,  ATTRIBUTE4,  ATTRIBUTE5,
                    ATTRIBUTE6,  ATTRIBUTE7,  ATTRIBUTE8,  ATTRIBUTE9,  ATTRIBUTE10,
                    ATTRIBUTE11, ATTRIBUTE12, ATTRIBUTE13, ATTRIBUTE14, ATTRIBUTE15,
                    BU_NAME,
                    TFM_STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    NULL,
                    s.ORG_ID,
                    s.ACCOUNT_CLASS,
                    s.AMOUNT,
                    s.PERCENT,
                    s.ACCTD_AMOUNT,

                    s.INTERFACE_LINE_CONTEXT,
                    s.INTERFACE_LINE_ATTRIBUTE1,
                    s.INTERFACE_LINE_ATTRIBUTE2,
                    s.INTERFACE_LINE_ATTRIBUTE3,
                    s.INTERFACE_LINE_ATTRIBUTE4,
                    s.INTERFACE_LINE_ATTRIBUTE5,
                    s.INTERFACE_LINE_ATTRIBUTE6,
                    s.INTERFACE_LINE_ATTRIBUTE7,
                    s.INTERFACE_LINE_ATTRIBUTE8,
                    s.INTERFACE_LINE_ATTRIBUTE9,
                    s.INTERFACE_LINE_ATTRIBUTE10,
                    s.INTERFACE_LINE_ATTRIBUTE11,
                    s.INTERFACE_LINE_ATTRIBUTE12,
                    s.INTERFACE_LINE_ATTRIBUTE13,
                    s.INTERFACE_LINE_ATTRIBUTE14,
                    s.INTERFACE_LINE_ATTRIBUTE15,
                    s.SEGMENT1,  s.SEGMENT2,  s.SEGMENT3,  s.SEGMENT4,  s.SEGMENT5,
                    s.SEGMENT6,  s.SEGMENT7,  s.SEGMENT8,  s.SEGMENT9,  s.SEGMENT10,
                    s.SEGMENT11, s.SEGMENT12, s.SEGMENT13, s.SEGMENT14, s.SEGMENT15,
                    s.SEGMENT16, s.SEGMENT17, s.SEGMENT18, s.SEGMENT19, s.SEGMENT20,
                    s.SEGMENT21, s.SEGMENT22, s.SEGMENT23, s.SEGMENT24, s.SEGMENT25,
                    s.SEGMENT26, s.SEGMENT27, s.SEGMENT28, s.SEGMENT29, s.SEGMENT30,
                    s.COMMENTS,
                    s.ATTRIBUTE_CATEGORY,
                    s.ATTRIBUTE1,  s.ATTRIBUTE2,  s.ATTRIBUTE3,  s.ATTRIBUTE4,  s.ATTRIBUTE5,
                    s.ATTRIBUTE6,  s.ATTRIBUTE7,  s.ATTRIBUTE8,  s.ATTRIBUTE9,  s.ATTRIBUTE10,
                    s.ATTRIBUTE11, s.ATTRIBUTE12, s.ATTRIBUTE13, s.ATTRIBUTE14, s.ATTRIBUTE15,
                    s.BU_NAME,
                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_RA_DISTS_STG_TBL s
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
            SELECT 1 FROM DMT_OWNER.DMT_RA_DISTS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_OWNER.DMT_RA_DISTS_STG_TBL s
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
            SELECT 1 FROM DMT_OWNER.DMT_RA_DISTS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_DISTS complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_DISTS');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_DISTS failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_DISTS',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_DISTS;

END DMT_AR_TRANSFORM_PKG;
/
