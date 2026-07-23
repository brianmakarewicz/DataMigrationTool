-- PACKAGE BODY DMT_AP_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_AP_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_AP_TRANSFORM_PKG Body
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_AP_TRANSFORM_PKG';

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


    -- --------------------------------------------------------
    -- Private: look up the prefix used by the most recent
    -- successful run of an upstream CEMLI in this scenario.
    -- Returns NULL if USE_PREFIX='N', no prior run found, or
    -- the upstream CEMLI was never run in this scenario.
    -- --------------------------------------------------------
    FUNCTION get_upstream_prefix (
        p_run_id IN NUMBER,
        p_cemli_code     IN VARCHAR2
    ) RETURN VARCHAR2 IS
        l_prefix    VARCHAR2(30);
        l_use_pfx   VARCHAR2(10);
        l_orch_code VARCHAR2(100);
    BEGIN
        l_use_pfx := DMT_UTIL_PKG.GET_CONFIG('USE_PREFIX');
        IF NVL(l_use_pfx, 'N') != 'Y' THEN RETURN NULL; END IF;

        -- Check if THIS run is part of a composite pipeline.
        -- If standalone (ORCHESTRATION_CODE = 'APInvoices' etc.), don't prefix
        -- upstream refs — they reference pre-existing Fusion data.
        -- If inside P2P, use this run's own prefix (suppliers were created
        -- with the same prefix in the same run).
        BEGIN
            SELECT PIPELINE_CODES, PREFIX
            INTO   l_orch_code, l_prefix
            FROM   DMT_OWNER.DMT_PIPELINE_RUN_TBL
            WHERE  RUN_ID = p_run_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN RETURN NULL;
        END;

        IF l_orch_code = 'ProcureToPay' THEN
            -- Running inside P2P: upstream CEMLIs share this prefix
            RETURN l_prefix;
        ELSE
            -- Standalone: don't prefix upstream refs
            RETURN NULL;
        END IF;
    END get_upstream_prefix;

    -- ============================================================
    -- TRANSFORM_HEADERS
    -- ============================================================
    PROCEDURE TRANSFORM_HEADERS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_inv_type_filter  IN VARCHAR2 DEFAULT NULL,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_prefix        VARCHAR2(30);
        l_dep_prefix    VARCHAR2(30);
        l_sup_prefix    VARCHAR2(30);  -- upstream supplier prefix (NULL if standalone)
        l_ok_count      NUMBER := 0;
        l_fail_count    NUMBER := 0;
        l_err           VARCHAR2(512);
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_HEADERS start. inv_type_filter=' || NVL(p_inv_type_filter, '(none)'),
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_HEADERS');

        l_prefix     := get_prefix(p_run_id);
        l_dep_prefix := get_dep_prefix(p_run_id);

        -- Resolve upstream supplier prefix dynamically.
        -- If running inside P2P, use this run's prefix (suppliers share it).
        -- If standalone, don't prefix vendor refs (pre-existing in Fusion).
        l_sup_prefix := get_upstream_prefix(p_run_id, 'Suppliers');

        -- Bulk INSERT into TFM from eligible STG rows
        INSERT INTO DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL (
            TFM_SEQUENCE_ID,
            STG_SEQUENCE_ID,
            RUN_ID,
            FBDI_CSV_ID,
            -- Core identification
            INVOICE_ID,
            OPERATING_UNIT,
            SOURCE,
            INVOICE_NUM,
            INVOICE_AMOUNT,
            INVOICE_DATE,
            VENDOR_NAME,
            VENDOR_NUM,
            VENDOR_SITE_CODE,
            INVOICE_CURRENCY_CODE,
            PAYMENT_CURRENCY_CODE,
            DESCRIPTION,
            GROUP_ID,
            INVOICE_TYPE_LOOKUP_CODE,
            LEGAL_ENTITY_NAME,
            CUST_REGISTRATION_NUMBER,
            CUST_REGISTRATION_CODE,
            FIRST_PARTY_REGISTRATION_NUM,
            THIRD_PARTY_REGISTRATION_NUM,
            -- Payment terms
            TERMS_NAME,
            TERMS_DATE,
            GOODS_RECEIVED_DATE,
            INVOICE_RECEIVED_DATE,
            GL_DATE,
            PAYMENT_METHOD_CODE,
            PAY_GROUP_LOOKUP_CODE,
            EXCLUSIVE_PAYMENT_FLAG,
            AMOUNT_APPLICABLE_TO_DISCOUNT,
            -- Prepayment
            PREPAY_NUM,
            PREPAY_LINE_NUM,
            PREPAY_APPLY_AMOUNT,
            PREPAY_GL_DATE,
            INVOICE_INCLUDES_PREPAY_FLAG,
            -- Exchange
            EXCHANGE_RATE_TYPE,
            EXCHANGE_DATE,
            EXCHANGE_RATE,
            -- Accounting
            ACCTS_PAY_CODE_CONCATENATED,
            DOC_CATEGORY_CODE,
            VOUCHER_NUM,
            -- Requester
            REQUESTER_FIRST_NAME,
            REQUESTER_LAST_NAME,
            REQUESTER_EMPLOYEE_NUM,
            -- Payment details
            DELIVERY_CHANNEL_CODE,
            BANK_CHARGE_BEARER,
            REMIT_TO_SUPPLIER_NAME,
            REMIT_TO_SUPPLIER_NUM,
            REMIT_TO_ADDRESS_NAME,
            PAYMENT_PRIORITY,
            SETTLEMENT_PRIORITY,
            UNIQUE_REMITTANCE_IDENTIFIER,
            URI_CHECK_DIGIT,
            PAYMENT_REASON_CODE,
            PAYMENT_REASON_COMMENTS,
            REMITTANCE_MESSAGE1,
            REMITTANCE_MESSAGE2,
            REMITTANCE_MESSAGE3,
            AWT_GROUP_NAME,
            SHIP_TO_LOCATION,
            -- Tax
            TAXATION_COUNTRY,
            DOCUMENT_SUB_TYPE,
            TAX_INVOICE_INTERNAL_SEQ,
            SUPPLIER_TAX_INVOICE_NUMBER,
            TAX_INVOICE_RECORDING_DATE,
            SUPPLIER_TAX_INVOICE_DATE,
            SUPPLIER_TAX_EXCHANGE_RATE,
            PORT_OF_ENTRY_CODE,
            CORRECTION_YEAR,
            CORRECTION_PERIOD,
            IMPORT_DOCUMENT_NUMBER,
            IMPORT_DOCUMENT_DATE,
            CONTROL_AMOUNT,
            CALC_TAX_DURING_IMPORT_FLAG,
            ADD_TAX_TO_INV_AMT_FLAG,
            -- DFF
            ATTRIBUTE_CATEGORY,
            ATTRIBUTE1,  ATTRIBUTE2,  ATTRIBUTE3,  ATTRIBUTE4,  ATTRIBUTE5,
            ATTRIBUTE6,  ATTRIBUTE7,  ATTRIBUTE8,  ATTRIBUTE9,  ATTRIBUTE10,
            ATTRIBUTE11, ATTRIBUTE12, ATTRIBUTE13, ATTRIBUTE14, ATTRIBUTE15,
            ATTRIBUTE_NUMBER1,  ATTRIBUTE_NUMBER2,  ATTRIBUTE_NUMBER3,  ATTRIBUTE_NUMBER4,  ATTRIBUTE_NUMBER5,
            ATTRIBUTE_DATE1,  ATTRIBUTE_DATE2,  ATTRIBUTE_DATE3,  ATTRIBUTE_DATE4,  ATTRIBUTE_DATE5,
            -- Global DFF
            GLOBAL_ATTRIBUTE_CATEGORY,
            GLOBAL_ATTRIBUTE1,  GLOBAL_ATTRIBUTE2,  GLOBAL_ATTRIBUTE3,  GLOBAL_ATTRIBUTE4,  GLOBAL_ATTRIBUTE5,
            GLOBAL_ATTRIBUTE6,  GLOBAL_ATTRIBUTE7,  GLOBAL_ATTRIBUTE8,  GLOBAL_ATTRIBUTE9,  GLOBAL_ATTRIBUTE10,
            GLOBAL_ATTRIBUTE11, GLOBAL_ATTRIBUTE12, GLOBAL_ATTRIBUTE13, GLOBAL_ATTRIBUTE14, GLOBAL_ATTRIBUTE15,
            GLOBAL_ATTRIBUTE16, GLOBAL_ATTRIBUTE17, GLOBAL_ATTRIBUTE18, GLOBAL_ATTRIBUTE19, GLOBAL_ATTRIBUTE20,
            GLOBAL_ATTRIBUTE_NUMBER1,  GLOBAL_ATTRIBUTE_NUMBER2,  GLOBAL_ATTRIBUTE_NUMBER3,  GLOBAL_ATTRIBUTE_NUMBER4,  GLOBAL_ATTRIBUTE_NUMBER5,
            GLOBAL_ATTRIBUTE_DATE1,  GLOBAL_ATTRIBUTE_DATE2,  GLOBAL_ATTRIBUTE_DATE3,  GLOBAL_ATTRIBUTE_DATE4,  GLOBAL_ATTRIBUTE_DATE5,
            -- Additional
            IMAGE_DOCUMENT_URI,
            EXTERNAL_BANK_ACCOUNT_NUMBER,
            EXT_BANK_ACCOUNT_IBAN_NUMBER,
            REQUESTER_EMAIL_ADDRESS,
            INTERCOMPANY_CROSSCHARGE_FLAG,
            -- Pipeline columns
            TFM_STATUS,
            LAST_UPDATED_DATE
        )
        SELECT
            DMT_OWNER.DMT_AP_INVOICES_INT_TFM_SEQ.NEXTVAL,
            s.STG_SEQUENCE_ID,
            p_run_id,
            NULL,  -- FBDI_CSV_ID: populated by FBDI generator
            -- INVOICE_ID: use from STG if provided, else derive
            NVL(s.INVOICE_ID, p_run_id * 10000 + s.STG_SEQUENCE_ID),
            s.OPERATING_UNIT,
            s.SOURCE,
            DMT_UTIL_PKG.PREFIXED(l_prefix, s.INVOICE_NUM, 50),
            s.INVOICE_AMOUNT,
            s.INVOICE_DATE,
            CASE WHEN l_sup_prefix IS NOT NULL THEN DMT_UTIL_PKG.PREFIXED(l_sup_prefix, s.VENDOR_NAME, 360) ELSE s.VENDOR_NAME END,
            CASE WHEN l_sup_prefix IS NOT NULL THEN DMT_UTIL_PKG.PREFIXED(l_sup_prefix, s.VENDOR_NUM, 30) ELSE s.VENDOR_NUM END,
            CASE WHEN l_sup_prefix IS NOT NULL THEN DMT_UTIL_PKG.PREFIXED(l_sup_prefix, s.VENDOR_SITE_CODE, 15) ELSE s.VENDOR_SITE_CODE END,
            s.INVOICE_CURRENCY_CODE,
            s.PAYMENT_CURRENCY_CODE,
            s.DESCRIPTION,
            TO_CHAR(p_run_id),  -- GROUP_ID = run_id (isolates our rows for APXIIMPT)
            s.INVOICE_TYPE_LOOKUP_CODE,
            s.LEGAL_ENTITY_NAME,
            s.CUST_REGISTRATION_NUMBER,
            s.CUST_REGISTRATION_CODE,
            s.FIRST_PARTY_REGISTRATION_NUM,
            s.THIRD_PARTY_REGISTRATION_NUM,
            s.TERMS_NAME,
            s.TERMS_DATE,
            s.GOODS_RECEIVED_DATE,
            s.INVOICE_RECEIVED_DATE,
            s.GL_DATE,
            s.PAYMENT_METHOD_CODE,
            s.PAY_GROUP_LOOKUP_CODE,
            s.EXCLUSIVE_PAYMENT_FLAG,
            s.AMOUNT_APPLICABLE_TO_DISCOUNT,
            s.PREPAY_NUM,
            s.PREPAY_LINE_NUM,
            s.PREPAY_APPLY_AMOUNT,
            s.PREPAY_GL_DATE,
            s.INVOICE_INCLUDES_PREPAY_FLAG,
            s.EXCHANGE_RATE_TYPE,
            s.EXCHANGE_DATE,
            s.EXCHANGE_RATE,
            s.ACCTS_PAY_CODE_CONCATENATED,
            s.DOC_CATEGORY_CODE,
            s.VOUCHER_NUM,
            s.REQUESTER_FIRST_NAME,
            s.REQUESTER_LAST_NAME,
            s.REQUESTER_EMPLOYEE_NUM,
            s.DELIVERY_CHANNEL_CODE,
            s.BANK_CHARGE_BEARER,
            s.REMIT_TO_SUPPLIER_NAME,
            s.REMIT_TO_SUPPLIER_NUM,
            s.REMIT_TO_ADDRESS_NAME,
            s.PAYMENT_PRIORITY,
            s.SETTLEMENT_PRIORITY,
            s.UNIQUE_REMITTANCE_IDENTIFIER,
            s.URI_CHECK_DIGIT,
            s.PAYMENT_REASON_CODE,
            s.PAYMENT_REASON_COMMENTS,
            s.REMITTANCE_MESSAGE1,
            s.REMITTANCE_MESSAGE2,
            s.REMITTANCE_MESSAGE3,
            s.AWT_GROUP_NAME,
            s.SHIP_TO_LOCATION,
            s.TAXATION_COUNTRY,
            s.DOCUMENT_SUB_TYPE,
            s.TAX_INVOICE_INTERNAL_SEQ,
            s.SUPPLIER_TAX_INVOICE_NUMBER,
            s.TAX_INVOICE_RECORDING_DATE,
            s.SUPPLIER_TAX_INVOICE_DATE,
            s.SUPPLIER_TAX_EXCHANGE_RATE,
            s.PORT_OF_ENTRY_CODE,
            s.CORRECTION_YEAR,
            s.CORRECTION_PERIOD,
            s.IMPORT_DOCUMENT_NUMBER,
            s.IMPORT_DOCUMENT_DATE,
            s.CONTROL_AMOUNT,
            s.CALC_TAX_DURING_IMPORT_FLAG,
            s.ADD_TAX_TO_INV_AMT_FLAG,
            s.ATTRIBUTE_CATEGORY,
            s.ATTRIBUTE1,  s.ATTRIBUTE2,  s.ATTRIBUTE3,  s.ATTRIBUTE4,  s.ATTRIBUTE5,
            s.ATTRIBUTE6,  s.ATTRIBUTE7,  s.ATTRIBUTE8,  s.ATTRIBUTE9,  s.ATTRIBUTE10,
            s.ATTRIBUTE11, s.ATTRIBUTE12, s.ATTRIBUTE13, s.ATTRIBUTE14, s.ATTRIBUTE15,
            s.ATTRIBUTE_NUMBER1,  s.ATTRIBUTE_NUMBER2,  s.ATTRIBUTE_NUMBER3,  s.ATTRIBUTE_NUMBER4,  s.ATTRIBUTE_NUMBER5,
            s.ATTRIBUTE_DATE1,  s.ATTRIBUTE_DATE2,  s.ATTRIBUTE_DATE3,  s.ATTRIBUTE_DATE4,  s.ATTRIBUTE_DATE5,
            s.GLOBAL_ATTRIBUTE_CATEGORY,
            s.GLOBAL_ATTRIBUTE1,  s.GLOBAL_ATTRIBUTE2,  s.GLOBAL_ATTRIBUTE3,  s.GLOBAL_ATTRIBUTE4,  s.GLOBAL_ATTRIBUTE5,
            s.GLOBAL_ATTRIBUTE6,  s.GLOBAL_ATTRIBUTE7,  s.GLOBAL_ATTRIBUTE8,  s.GLOBAL_ATTRIBUTE9,  s.GLOBAL_ATTRIBUTE10,
            s.GLOBAL_ATTRIBUTE11, s.GLOBAL_ATTRIBUTE12, s.GLOBAL_ATTRIBUTE13, s.GLOBAL_ATTRIBUTE14, s.GLOBAL_ATTRIBUTE15,
            s.GLOBAL_ATTRIBUTE16, s.GLOBAL_ATTRIBUTE17, s.GLOBAL_ATTRIBUTE18, s.GLOBAL_ATTRIBUTE19, s.GLOBAL_ATTRIBUTE20,
            s.GLOBAL_ATTRIBUTE_NUMBER1,  s.GLOBAL_ATTRIBUTE_NUMBER2,  s.GLOBAL_ATTRIBUTE_NUMBER3,  s.GLOBAL_ATTRIBUTE_NUMBER4,  s.GLOBAL_ATTRIBUTE_NUMBER5,
            s.GLOBAL_ATTRIBUTE_DATE1,  s.GLOBAL_ATTRIBUTE_DATE2,  s.GLOBAL_ATTRIBUTE_DATE3,  s.GLOBAL_ATTRIBUTE_DATE4,  s.GLOBAL_ATTRIBUTE_DATE5,
            s.IMAGE_DOCUMENT_URI,
            s.EXTERNAL_BANK_ACCOUNT_NUMBER,
            s.EXT_BANK_ACCOUNT_IBAN_NUMBER,
            s.REQUESTER_EMAIL_ADDRESS,
            s.INTERCOMPANY_CROSSCHARGE_FLAG,
            'STAGED',
            SYSDATE
        FROM DMT_OWNER.DMT_AP_INVOICES_INT_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND (p_inv_type_filter IS NULL OR s.INVOICE_TYPE_LOOKUP_CODE LIKE p_inv_type_filter)
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL e
            WHERE  e.RUN_ID = p_run_id
            AND    e.SUB_OBJECT = 'AP Invoice Headers'
            AND    e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID)
        AND NOT EXISTS (
            SELECT 1
            FROM   DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        l_ok_count := SQL%ROWCOUNT;

        -- Update STG stg_status to TRANSFORMED for rows that were inserted into TFM
        UPDATE DMT_OWNER.DMT_AP_INVOICES_INT_STG_TBL
        SET    STG_STATUS = 'TRANSFORMED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (
            SELECT STG_SEQUENCE_ID
            FROM   DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL
            WHERE  RUN_ID = p_run_id
        )
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL e
            WHERE  e.RUN_ID = p_run_id
            AND    e.SUB_OBJECT = 'AP Invoice Headers'
            AND    e.STG_SEQUENCE_ID = STG_SEQUENCE_ID)
        AND (
            (p_run_mode = 'NEW' AND STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL' AND STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_reprocess_errors AND STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_HEADERS complete. Rows transformed: ' || l_ok_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_HEADERS');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_HEADERS failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_HEADERS');
            RAISE;
    END TRANSFORM_HEADERS;


    -- ============================================================
    -- TRANSFORM_LINES
    -- ============================================================
    PROCEDURE TRANSFORM_LINES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_inv_type_filter  IN VARCHAR2 DEFAULT NULL,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_ok_count      NUMBER := 0;
        l_po_prefix     VARCHAR2(30);  -- upstream PO prefix (NULL if standalone)
    BEGIN
        -- Resolve upstream PO prefix for PO_NUMBER references.
        -- If running inside P2P, use this run's prefix. If standalone, don't prefix.
        l_po_prefix := get_upstream_prefix(p_run_id, 'PurchaseOrders');
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_LINES start. inv_type_filter=' || NVL(p_inv_type_filter, '(none)'),
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_LINES');

        -- Bulk INSERT into TFM from eligible STG rows
        INSERT INTO DMT_OWNER.DMT_AP_INVOICE_LINES_INT_TFM_TBL (
            TFM_SEQUENCE_ID,
            STG_SEQUENCE_ID,
            RUN_ID,
            FBDI_CSV_ID,
            -- Core identification
            INVOICE_ID,
            LINE_NUMBER,
            LINE_TYPE_LOOKUP_CODE,
            AMOUNT,
            QUANTITY_INVOICED,
            UNIT_PRICE,
            UNIT_OF_MEAS_LOOKUP_CODE,
            DESCRIPTION,
            -- PO matching
            PO_NUMBER,
            PO_LINE_NUMBER,
            PO_SHIPMENT_NUM,
            PO_DISTRIBUTION_NUM,
            ITEM_DESCRIPTION,
            RELEASE_NUM,
            PURCHASING_CATEGORY,
            RECEIPT_NUMBER,
            RECEIPT_LINE_NUMBER,
            CONSUMPTION_ADVICE_NUMBER,
            CONSUMPTION_ADVICE_LINE_NUMBER,
            PACKING_SLIP,
            FINAL_MATCH_FLAG,
            -- Accounting
            DIST_CODE_CONCATENATED,
            DISTRIBUTION_SET_NAME,
            ACCOUNTING_DATE,
            ACCOUNT_SEGMENT,
            BALANCING_SEGMENT,
            COST_CENTER_SEGMENT,
            -- Tax
            TAX_CLASSIFICATION_CODE,
            SHIP_TO_LOCATION_CODE,
            SHIP_FROM_LOCATION_CODE,
            FINAL_DISCHARGE_LOCATION_CODE,
            TRX_BUSINESS_CATEGORY,
            PRODUCT_FISC_CLASSIFICATION,
            PRIMARY_INTENDED_USE,
            USER_DEFINED_FISC_CLASS,
            PRODUCT_TYPE,
            ASSESSABLE_VALUE,
            PRODUCT_CATEGORY,
            CONTROL_AMOUNT,
            TAX_REGIME_CODE,
            TAX,
            TAX_STATUS_CODE,
            TAX_JURISDICTION_CODE,
            TAX_RATE_CODE,
            TAX_RATE,
            AWT_GROUP_NAME,
            TYPE_1099,
            INCOME_TAX_REGION,
            PRORATE_ACROSS_FLAG,
            LINE_GROUP_NUMBER,
            COST_FACTOR_NAME,
            STAT_AMOUNT,
            -- Assets
            ASSETS_TRACKING_FLAG,
            ASSET_BOOK_TYPE_CODE,
            ASSET_CATEGORY_ID,
            SERIAL_NUMBER,
            MANUFACTURER,
            MODEL_NUMBER,
            WARRANTY_NUMBER,
            -- Price correction
            PRICE_CORRECTION_FLAG,
            PRICE_CORRECT_INV_NUM,
            PRICE_CORRECT_INV_LINE_NUM,
            -- Requester
            REQUESTER_FIRST_NAME,
            REQUESTER_LAST_NAME,
            REQUESTER_EMPLOYEE_NUM,
            -- DFF
            ATTRIBUTE_CATEGORY,
            ATTRIBUTE1,  ATTRIBUTE2,  ATTRIBUTE3,  ATTRIBUTE4,  ATTRIBUTE5,
            ATTRIBUTE6,  ATTRIBUTE7,  ATTRIBUTE8,  ATTRIBUTE9,  ATTRIBUTE10,
            ATTRIBUTE11, ATTRIBUTE12, ATTRIBUTE13, ATTRIBUTE14, ATTRIBUTE15,
            ATTRIBUTE_NUMBER1,  ATTRIBUTE_NUMBER2,  ATTRIBUTE_NUMBER3,  ATTRIBUTE_NUMBER4,  ATTRIBUTE_NUMBER5,
            ATTRIBUTE_DATE1,  ATTRIBUTE_DATE2,  ATTRIBUTE_DATE3,  ATTRIBUTE_DATE4,  ATTRIBUTE_DATE5,
            -- Global DFF
            GLOBAL_ATTRIBUTE_CATEGORY,
            GLOBAL_ATTRIBUTE1,  GLOBAL_ATTRIBUTE2,  GLOBAL_ATTRIBUTE3,  GLOBAL_ATTRIBUTE4,  GLOBAL_ATTRIBUTE5,
            GLOBAL_ATTRIBUTE6,  GLOBAL_ATTRIBUTE7,  GLOBAL_ATTRIBUTE8,  GLOBAL_ATTRIBUTE9,  GLOBAL_ATTRIBUTE10,
            GLOBAL_ATTRIBUTE11, GLOBAL_ATTRIBUTE12, GLOBAL_ATTRIBUTE13, GLOBAL_ATTRIBUTE14, GLOBAL_ATTRIBUTE15,
            GLOBAL_ATTRIBUTE16, GLOBAL_ATTRIBUTE17, GLOBAL_ATTRIBUTE18, GLOBAL_ATTRIBUTE19, GLOBAL_ATTRIBUTE20,
            GLOBAL_ATTRIBUTE_NUMBER1,  GLOBAL_ATTRIBUTE_NUMBER2,  GLOBAL_ATTRIBUTE_NUMBER3,  GLOBAL_ATTRIBUTE_NUMBER4,  GLOBAL_ATTRIBUTE_NUMBER5,
            GLOBAL_ATTRIBUTE_DATE1,  GLOBAL_ATTRIBUTE_DATE2,  GLOBAL_ATTRIBUTE_DATE3,  GLOBAL_ATTRIBUTE_DATE4,  GLOBAL_ATTRIBUTE_DATE5,
            -- Project
            PJC_PROJECT_ID,
            PJC_TASK_ID,
            PJC_EXPENDITURE_TYPE_ID,
            PJC_EXPENDITURE_ITEM_DATE,
            PJC_ORGANIZATION_ID,
            PJC_PROJECT_NUMBER,
            PJC_TASK_NUMBER,
            PJC_EXPENDITURE_TYPE_NAME,
            PJC_ORGANIZATION_NAME,
            PJC_RESERVED_ATTRIBUTE1,  PJC_RESERVED_ATTRIBUTE2,  PJC_RESERVED_ATTRIBUTE3,  PJC_RESERVED_ATTRIBUTE4,  PJC_RESERVED_ATTRIBUTE5,
            PJC_RESERVED_ATTRIBUTE6,  PJC_RESERVED_ATTRIBUTE7,  PJC_RESERVED_ATTRIBUTE8,  PJC_RESERVED_ATTRIBUTE9,  PJC_RESERVED_ATTRIBUTE10,
            PJC_USER_DEF_ATTRIBUTE1,  PJC_USER_DEF_ATTRIBUTE2,  PJC_USER_DEF_ATTRIBUTE3,  PJC_USER_DEF_ATTRIBUTE4,  PJC_USER_DEF_ATTRIBUTE5,
            PJC_USER_DEF_ATTRIBUTE6,  PJC_USER_DEF_ATTRIBUTE7,  PJC_USER_DEF_ATTRIBUTE8,  PJC_USER_DEF_ATTRIBUTE9,  PJC_USER_DEF_ATTRIBUTE10,
            -- Deferred accounting
            FISCAL_CHARGE_TYPE,
            DEF_ACCTG_START_DATE,
            DEF_ACCTG_END_DATE,
            DEF_ACCRUAL_CODE_CONCATENATED,
            -- Project names
            PJC_PROJECT_NAME,
            PJC_TASK_NAME,
            PJC_WORK_TYPE,
            PJC_CONTRACT_NAME,
            PJC_CONTRACT_NUMBER,
            PJC_FUNDING_SOURCE_NAME,
            PJC_FUNDING_SOURCE_NUMBER,
            -- Additional
            REQUESTER_EMAIL_ADDRESS,
            RCV_TRANSACTION_ID,
            -- Pipeline columns
            TFM_STATUS,
            LAST_UPDATED_DATE
        )
        SELECT
            DMT_OWNER.DMT_AP_INVOICE_LINES_INT_TFM_SEQ.NEXTVAL,
            s.STG_SEQUENCE_ID,
            p_run_id,
            NULL,  -- FBDI_CSV_ID: populated by FBDI generator
            s.INVOICE_ID,
            s.LINE_NUMBER,
            s.LINE_TYPE_LOOKUP_CODE,
            s.AMOUNT,
            s.QUANTITY_INVOICED,
            s.UNIT_PRICE,
            s.UNIT_OF_MEAS_LOOKUP_CODE,
            s.DESCRIPTION,
            CASE WHEN l_po_prefix IS NOT NULL AND s.PO_NUMBER IS NOT NULL THEN DMT_UTIL_PKG.PREFIXED(l_po_prefix, s.PO_NUMBER, 50) ELSE s.PO_NUMBER END,
            s.PO_LINE_NUMBER,
            s.PO_SHIPMENT_NUM,
            s.PO_DISTRIBUTION_NUM,
            s.ITEM_DESCRIPTION,
            s.RELEASE_NUM,
            s.PURCHASING_CATEGORY,
            s.RECEIPT_NUMBER,
            s.RECEIPT_LINE_NUMBER,
            s.CONSUMPTION_ADVICE_NUMBER,
            s.CONSUMPTION_ADVICE_LINE_NUMBER,
            s.PACKING_SLIP,
            s.FINAL_MATCH_FLAG,
            s.DIST_CODE_CONCATENATED,
            s.DISTRIBUTION_SET_NAME,
            s.ACCOUNTING_DATE,
            s.ACCOUNT_SEGMENT,
            s.BALANCING_SEGMENT,
            s.COST_CENTER_SEGMENT,
            s.TAX_CLASSIFICATION_CODE,
            s.SHIP_TO_LOCATION_CODE,
            s.SHIP_FROM_LOCATION_CODE,
            s.FINAL_DISCHARGE_LOCATION_CODE,
            s.TRX_BUSINESS_CATEGORY,
            s.PRODUCT_FISC_CLASSIFICATION,
            s.PRIMARY_INTENDED_USE,
            s.USER_DEFINED_FISC_CLASS,
            s.PRODUCT_TYPE,
            s.ASSESSABLE_VALUE,
            s.PRODUCT_CATEGORY,
            s.CONTROL_AMOUNT,
            s.TAX_REGIME_CODE,
            s.TAX,
            s.TAX_STATUS_CODE,
            s.TAX_JURISDICTION_CODE,
            s.TAX_RATE_CODE,
            s.TAX_RATE,
            s.AWT_GROUP_NAME,
            s.TYPE_1099,
            s.INCOME_TAX_REGION,
            s.PRORATE_ACROSS_FLAG,
            s.LINE_GROUP_NUMBER,
            s.COST_FACTOR_NAME,
            s.STAT_AMOUNT,
            s.ASSETS_TRACKING_FLAG,
            s.ASSET_BOOK_TYPE_CODE,
            s.ASSET_CATEGORY_ID,
            s.SERIAL_NUMBER,
            s.MANUFACTURER,
            s.MODEL_NUMBER,
            s.WARRANTY_NUMBER,
            s.PRICE_CORRECTION_FLAG,
            s.PRICE_CORRECT_INV_NUM,
            s.PRICE_CORRECT_INV_LINE_NUM,
            s.REQUESTER_FIRST_NAME,
            s.REQUESTER_LAST_NAME,
            s.REQUESTER_EMPLOYEE_NUM,
            s.ATTRIBUTE_CATEGORY,
            s.ATTRIBUTE1,  s.ATTRIBUTE2,  s.ATTRIBUTE3,  s.ATTRIBUTE4,  s.ATTRIBUTE5,
            s.ATTRIBUTE6,  s.ATTRIBUTE7,  s.ATTRIBUTE8,  s.ATTRIBUTE9,  s.ATTRIBUTE10,
            s.ATTRIBUTE11, s.ATTRIBUTE12, s.ATTRIBUTE13, s.ATTRIBUTE14, s.ATTRIBUTE15,
            s.ATTRIBUTE_NUMBER1,  s.ATTRIBUTE_NUMBER2,  s.ATTRIBUTE_NUMBER3,  s.ATTRIBUTE_NUMBER4,  s.ATTRIBUTE_NUMBER5,
            s.ATTRIBUTE_DATE1,  s.ATTRIBUTE_DATE2,  s.ATTRIBUTE_DATE3,  s.ATTRIBUTE_DATE4,  s.ATTRIBUTE_DATE5,
            s.GLOBAL_ATTRIBUTE_CATEGORY,
            s.GLOBAL_ATTRIBUTE1,  s.GLOBAL_ATTRIBUTE2,  s.GLOBAL_ATTRIBUTE3,  s.GLOBAL_ATTRIBUTE4,  s.GLOBAL_ATTRIBUTE5,
            s.GLOBAL_ATTRIBUTE6,  s.GLOBAL_ATTRIBUTE7,  s.GLOBAL_ATTRIBUTE8,  s.GLOBAL_ATTRIBUTE9,  s.GLOBAL_ATTRIBUTE10,
            s.GLOBAL_ATTRIBUTE11, s.GLOBAL_ATTRIBUTE12, s.GLOBAL_ATTRIBUTE13, s.GLOBAL_ATTRIBUTE14, s.GLOBAL_ATTRIBUTE15,
            s.GLOBAL_ATTRIBUTE16, s.GLOBAL_ATTRIBUTE17, s.GLOBAL_ATTRIBUTE18, s.GLOBAL_ATTRIBUTE19, s.GLOBAL_ATTRIBUTE20,
            s.GLOBAL_ATTRIBUTE_NUMBER1,  s.GLOBAL_ATTRIBUTE_NUMBER2,  s.GLOBAL_ATTRIBUTE_NUMBER3,  s.GLOBAL_ATTRIBUTE_NUMBER4,  s.GLOBAL_ATTRIBUTE_NUMBER5,
            s.GLOBAL_ATTRIBUTE_DATE1,  s.GLOBAL_ATTRIBUTE_DATE2,  s.GLOBAL_ATTRIBUTE_DATE3,  s.GLOBAL_ATTRIBUTE_DATE4,  s.GLOBAL_ATTRIBUTE_DATE5,
            s.PJC_PROJECT_ID,
            s.PJC_TASK_ID,
            s.PJC_EXPENDITURE_TYPE_ID,
            s.PJC_EXPENDITURE_ITEM_DATE,
            s.PJC_ORGANIZATION_ID,
            s.PJC_PROJECT_NUMBER,
            s.PJC_TASK_NUMBER,
            s.PJC_EXPENDITURE_TYPE_NAME,
            s.PJC_ORGANIZATION_NAME,
            s.PJC_RESERVED_ATTRIBUTE1,  s.PJC_RESERVED_ATTRIBUTE2,  s.PJC_RESERVED_ATTRIBUTE3,  s.PJC_RESERVED_ATTRIBUTE4,  s.PJC_RESERVED_ATTRIBUTE5,
            s.PJC_RESERVED_ATTRIBUTE6,  s.PJC_RESERVED_ATTRIBUTE7,  s.PJC_RESERVED_ATTRIBUTE8,  s.PJC_RESERVED_ATTRIBUTE9,  s.PJC_RESERVED_ATTRIBUTE10,
            s.PJC_USER_DEF_ATTRIBUTE1,  s.PJC_USER_DEF_ATTRIBUTE2,  s.PJC_USER_DEF_ATTRIBUTE3,  s.PJC_USER_DEF_ATTRIBUTE4,  s.PJC_USER_DEF_ATTRIBUTE5,
            s.PJC_USER_DEF_ATTRIBUTE6,  s.PJC_USER_DEF_ATTRIBUTE7,  s.PJC_USER_DEF_ATTRIBUTE8,  s.PJC_USER_DEF_ATTRIBUTE9,  s.PJC_USER_DEF_ATTRIBUTE10,
            s.FISCAL_CHARGE_TYPE,
            s.DEF_ACCTG_START_DATE,
            s.DEF_ACCTG_END_DATE,
            s.DEF_ACCRUAL_CODE_CONCATENATED,
            s.PJC_PROJECT_NAME,
            s.PJC_TASK_NAME,
            s.PJC_WORK_TYPE,
            s.PJC_CONTRACT_NAME,
            s.PJC_CONTRACT_NUMBER,
            s.PJC_FUNDING_SOURCE_NAME,
            s.PJC_FUNDING_SOURCE_NUMBER,
            s.REQUESTER_EMAIL_ADDRESS,
            s.RCV_TRANSACTION_ID,
            'STAGED',
            SYSDATE
        FROM DMT_OWNER.DMT_AP_INVOICE_LINES_INT_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND (p_inv_type_filter IS NULL OR EXISTS (
                SELECT 1
                FROM   DMT_OWNER.DMT_AP_INVOICES_INT_STG_TBL h
                WHERE  h.INVOICE_ID = s.INVOICE_ID
                AND    h.INVOICE_TYPE_LOOKUP_CODE LIKE p_inv_type_filter
            ))
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL e
            WHERE  e.RUN_ID = p_run_id
            AND    e.SUB_OBJECT = 'AP Invoice Lines'
            AND    e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID)
        AND NOT EXISTS (
            SELECT 1
            FROM   DMT_OWNER.DMT_AP_INVOICE_LINES_INT_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        l_ok_count := SQL%ROWCOUNT;

        -- Update STG stg_status to TRANSFORMED for rows that were inserted into TFM
        UPDATE DMT_OWNER.DMT_AP_INVOICE_LINES_INT_STG_TBL
        SET    STG_STATUS = 'TRANSFORMED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (
            SELECT STG_SEQUENCE_ID
            FROM   DMT_OWNER.DMT_AP_INVOICE_LINES_INT_TFM_TBL
            WHERE  RUN_ID = p_run_id
        )
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL e
            WHERE  e.RUN_ID = p_run_id
            AND    e.SUB_OBJECT = 'AP Invoice Lines'
            AND    e.STG_SEQUENCE_ID = STG_SEQUENCE_ID)
        AND (
            (p_run_mode = 'NEW' AND STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL' AND STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_reprocess_errors AND STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_LINES complete. Rows transformed: ' || l_ok_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_LINES');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_LINES failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_LINES');
            RAISE;
    END TRANSFORM_LINES;

END DMT_AP_TRANSFORM_PKG;
/
