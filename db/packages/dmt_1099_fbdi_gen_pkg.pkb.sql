-- PACKAGE BODY DMT_1099_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_1099_FBDI_GEN_PKG" 
AS
    C_PKG CONSTANT VARCHAR2(50) := 'DMT_1099_FBDI_GEN_PKG';

-- ============================================================
-- DMT_1099_FBDI_GEN_PKG body
-- 1099Invoices FBDI zip generation.
-- Shares AP Invoice tables, filters by INVOICE_TYPE_LOOKUP_CODE LIKE '%1099%'.
-- Grouped by OPERATING_UNIT: when p_operating_unit is non-NULL,
-- filters both CSVs to only include rows for that OU.
-- ============================================================

    FUNCTION clob_to_blob(p_clob IN CLOB) RETURN BLOB IS
        l_blob         BLOB;
        l_dest_offset  INTEGER := 1;
        l_src_offset   INTEGER := 1;
        l_lang_context INTEGER := DBMS_LOB.DEFAULT_LANG_CTX;
        l_warning      INTEGER;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_blob, TRUE);
        DBMS_LOB.CONVERTTOBLOB(
            dest_lob     => l_blob,
            src_clob     => p_clob,
            amount       => DBMS_LOB.LOBMAXSIZE,
            dest_offset  => l_dest_offset,
            src_offset   => l_src_offset,
            blob_csid    => DBMS_LOB.DEFAULT_CSID,
            lang_context => l_lang_context,
            warning      => l_warning);
        RETURN l_blob;
    END clob_to_blob;

    -- --------------------------------------------------------
    -- Private: append a delimited CSV field to a CLOB
    -- --------------------------------------------------------
    PROCEDURE append_csv_field (
        p_clob   IN OUT NOCOPY CLOB,
        p_value  IN VARCHAR2,
        p_last   IN BOOLEAN DEFAULT FALSE
    )
    IS
        l_val VARCHAR2(32767);
    BEGIN
        -- Wrap in double-quotes; escape internal double-quotes by doubling them
        l_val := '"' || REPLACE(p_value, '"', '""') || '"';
        DBMS_LOB.WRITEAPPEND(p_clob, LENGTH(l_val), l_val);
        IF NOT p_last THEN
            DBMS_LOB.WRITEAPPEND(p_clob, 1, ',');
        ELSE
            DBMS_LOB.WRITEAPPEND(p_clob, 1, CHR(10));
        END IF;
    END append_csv_field;

    -- --------------------------------------------------------
    -- Private: format DATE as YYYY/MM/DD (Fusion FBDI date format)
    -- --------------------------------------------------------
    FUNCTION fmt_date(p_date IN DATE) RETURN VARCHAR2
    IS
    BEGIN
        RETURN TO_CHAR(p_date, 'YYYY/MM/DD');
    END fmt_date;

    -- --------------------------------------------------------
    -- Private: generate ApInvoicesInterface.csv CLOB
    -- When p_operating_unit is non-NULL, only includes headers for that OU.
    -- Filters by INVOICE_TYPE_LOOKUP_CODE LIKE '%1099%' to isolate 1099 invoices.
    -- Column order matches ApInvoicesInterface.ctl exactly.
    -- --------------------------------------------------------
    FUNCTION gen_headers_csv (
        p_run_id IN NUMBER,
        p_operating_unit IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB
    IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        FOR r IN (
            SELECT
                '"' || NVL(TO_CHAR(INVOICE_ID), '') || '"' || ','
                || '"' || REPLACE(NVL(OPERATING_UNIT,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SOURCE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INVOICE_NUM,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(INVOICE_AMOUNT), '') || '"' || ','
                || '"' || NVL(TO_CHAR(INVOICE_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(VENDOR_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(VENDOR_NUM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(VENDOR_SITE_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INVOICE_CURRENCY_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PAYMENT_CURRENCY_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DESCRIPTION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GROUP_ID,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INVOICE_TYPE_LOOKUP_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LEGAL_ENTITY_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CUST_REGISTRATION_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CUST_REGISTRATION_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(FIRST_PARTY_REGISTRATION_NUM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(THIRD_PARTY_REGISTRATION_NUM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TERMS_NAME,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(TERMS_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(GOODS_RECEIVED_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(INVOICE_RECEIVED_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(GL_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(PAYMENT_METHOD_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PAY_GROUP_LOOKUP_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(EXCLUSIVE_PAYMENT_FLAG,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(AMOUNT_APPLICABLE_TO_DISCOUNT), '') || '"' || ','
                || '"' || REPLACE(NVL(PREPAY_NUM,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(PREPAY_LINE_NUM), '') || '"' || ','
                || '"' || NVL(TO_CHAR(PREPAY_APPLY_AMOUNT), '') || '"' || ','
                || '"' || NVL(TO_CHAR(PREPAY_GL_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(INVOICE_INCLUDES_PREPAY_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(EXCHANGE_RATE_TYPE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(EXCHANGE_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(EXCHANGE_RATE), '') || '"' || ','
                || '"' || REPLACE(NVL(ACCTS_PAY_CODE_CONCATENATED,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DOC_CATEGORY_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(VOUCHER_NUM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(REQUESTER_FIRST_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(REQUESTER_LAST_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(REQUESTER_EMPLOYEE_NUM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DELIVERY_CHANNEL_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(BANK_CHARGE_BEARER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(REMIT_TO_SUPPLIER_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(REMIT_TO_SUPPLIER_NUM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(REMIT_TO_ADDRESS_NAME,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(PAYMENT_PRIORITY), '') || '"' || ','
                || '"' || REPLACE(NVL(SETTLEMENT_PRIORITY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(UNIQUE_REMITTANCE_IDENTIFIER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(URI_CHECK_DIGIT,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PAYMENT_REASON_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PAYMENT_REASON_COMMENTS,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(REMITTANCE_MESSAGE1,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(REMITTANCE_MESSAGE2,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(REMITTANCE_MESSAGE3,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(AWT_GROUP_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SHIP_TO_LOCATION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TAXATION_COUNTRY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DOCUMENT_SUB_TYPE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TAX_INVOICE_INTERNAL_SEQ,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SUPPLIER_TAX_INVOICE_NUMBER,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(TAX_INVOICE_RECORDING_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(SUPPLIER_TAX_INVOICE_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(SUPPLIER_TAX_EXCHANGE_RATE), '') || '"' || ','
                || '"' || REPLACE(NVL(PORT_OF_ENTRY_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CORRECTION_YEAR,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CORRECTION_PERIOD,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(IMPORT_DOCUMENT_NUMBER,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(IMPORT_DOCUMENT_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(CONTROL_AMOUNT), '') || '"' || ','
                || '"' || REPLACE(NVL(CALC_TAX_DURING_IMPORT_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ADD_TAX_TO_INV_AMT_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_CATEGORY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE1,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE2,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE3,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE4,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE5,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE6,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE7,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE8,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE9,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE10,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE11,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE12,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE13,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE14,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE15,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER1), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER2), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER3), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER4), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER5), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE1, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE2, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE3, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE4, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE5, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE_CATEGORY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE1,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE2,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE3,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE4,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE5,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE6,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE7,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE8,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE9,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE10,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE11,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE12,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE13,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE14,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE15,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE16,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE17,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE18,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE19,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE20,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_NUMBER1), '') || '"' || ','
                || '"' || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_NUMBER2), '') || '"' || ','
                || '"' || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_NUMBER3), '') || '"' || ','
                || '"' || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_NUMBER4), '') || '"' || ','
                || '"' || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_NUMBER5), '') || '"' || ','
                || '"' || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_DATE1, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_DATE2, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_DATE3, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_DATE4, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_DATE5, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(IMAGE_DOCUMENT_URI,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(EXTERNAL_BANK_ACCOUNT_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(EXT_BANK_ACCOUNT_IBAN_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(REQUESTER_EMAIL_ADDRESS,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERCOMPANY_CROSSCHARGE_FLAG,''), '"', '""') || '"' || CHR(10) AS csv_line
            FROM   DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id
            AND    t.TFM_STATUS = 'STAGED'
            AND    t.INVOICE_TYPE_LOOKUP_CODE LIKE '%1099%'
            AND    (p_operating_unit IS NULL OR t.OPERATING_UNIT = p_operating_unit)
            ORDER BY t.TFM_SEQUENCE_ID
                    ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;

        RETURN l_csv;
    END gen_headers_csv;

    -- --------------------------------------------------------
    -- Private: generate ApInvoiceLinesInterface.csv CLOB
    -- When p_operating_unit is non-NULL, only includes lines whose
    -- parent header belongs to that OU.
    -- Lines are filtered by joining to headers with INVOICE_TYPE_LOOKUP_CODE LIKE '%1099%'.
    -- Column order matches ApInvoiceLinesInterface.ctl exactly.
    -- --------------------------------------------------------
    FUNCTION gen_lines_csv (
        p_run_id IN NUMBER,
        p_operating_unit IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB
    IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        FOR r IN (
            SELECT
                '"' || NVL(TO_CHAR(INVOICE_ID), '') || '"' || ','
                || '"' || NVL(TO_CHAR(LINE_NUMBER), '') || '"' || ','
                || '"' || REPLACE(NVL(LINE_TYPE_LOOKUP_CODE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(AMOUNT), '') || '"' || ','
                || '"' || NVL(TO_CHAR(QUANTITY_INVOICED), '') || '"' || ','
                || '"' || NVL(TO_CHAR(UNIT_PRICE), '') || '"' || ','
                || '"' || REPLACE(NVL(UNIT_OF_MEAS_LOOKUP_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DESCRIPTION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PO_NUMBER,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(PO_LINE_NUMBER), '') || '"' || ','
                || '"' || NVL(TO_CHAR(PO_SHIPMENT_NUM), '') || '"' || ','
                || '"' || NVL(TO_CHAR(PO_DISTRIBUTION_NUM), '') || '"' || ','
                || '"' || REPLACE(NVL(ITEM_DESCRIPTION,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(RELEASE_NUM), '') || '"' || ','
                || '"' || REPLACE(NVL(PURCHASING_CATEGORY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(RECEIPT_NUMBER,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(RECEIPT_LINE_NUMBER), '') || '"' || ','
                || '"' || REPLACE(NVL(CONSUMPTION_ADVICE_NUMBER,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(CONSUMPTION_ADVICE_LINE_NUMBER), '') || '"' || ','
                || '"' || REPLACE(NVL(PACKING_SLIP,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(FINAL_MATCH_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DIST_CODE_CONCATENATED,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DISTRIBUTION_SET_NAME,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(ACCOUNTING_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(ACCOUNT_SEGMENT,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(BALANCING_SEGMENT,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(COST_CENTER_SEGMENT,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TAX_CLASSIFICATION_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SHIP_TO_LOCATION_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SHIP_FROM_LOCATION_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(FINAL_DISCHARGE_LOCATION_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TRX_BUSINESS_CATEGORY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PRODUCT_FISC_CLASSIFICATION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PRIMARY_INTENDED_USE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(USER_DEFINED_FISC_CLASS,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PRODUCT_TYPE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(ASSESSABLE_VALUE), '') || '"' || ','
                || '"' || REPLACE(NVL(PRODUCT_CATEGORY,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(CONTROL_AMOUNT), '') || '"' || ','
                || '"' || REPLACE(NVL(TAX_REGIME_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TAX,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TAX_STATUS_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TAX_JURISDICTION_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TAX_RATE_CODE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(TAX_RATE), '') || '"' || ','
                || '"' || REPLACE(NVL(AWT_GROUP_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TYPE_1099,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INCOME_TAX_REGION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PRORATE_ACROSS_FLAG,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(LINE_GROUP_NUMBER), '') || '"' || ','
                || '"' || REPLACE(NVL(COST_FACTOR_NAME,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(STAT_AMOUNT), '') || '"' || ','
                || '"' || REPLACE(NVL(ASSETS_TRACKING_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ASSET_BOOK_TYPE_CODE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(ASSET_CATEGORY_ID), '') || '"' || ','
                || '"' || REPLACE(NVL(SERIAL_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(MANUFACTURER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(MODEL_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(WARRANTY_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PRICE_CORRECTION_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PRICE_CORRECT_INV_NUM,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(PRICE_CORRECT_INV_LINE_NUM), '') || '"' || ','
                || '"' || REPLACE(NVL(REQUESTER_FIRST_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(REQUESTER_LAST_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(REQUESTER_EMPLOYEE_NUM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_CATEGORY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE1,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE2,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE3,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE4,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE5,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE6,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE7,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE8,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE9,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE10,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE11,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE12,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE13,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE14,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE15,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER1), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER2), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER3), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER4), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER5), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE1, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE2, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE3, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE4, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE5, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE_CATEGORY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE1,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE2,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE3,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE4,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE5,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE6,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE7,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE8,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE9,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE10,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE11,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE12,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE13,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE14,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE15,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE16,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE17,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE18,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE19,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GLOBAL_ATTRIBUTE20,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_NUMBER1), '') || '"' || ','
                || '"' || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_NUMBER2), '') || '"' || ','
                || '"' || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_NUMBER3), '') || '"' || ','
                || '"' || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_NUMBER4), '') || '"' || ','
                || '"' || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_NUMBER5), '') || '"' || ','
                || '"' || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_DATE1, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_DATE2, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_DATE3, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_DATE4, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_DATE5, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(PJC_PROJECT_ID), '') || '"' || ','
                || '"' || NVL(TO_CHAR(PJC_TASK_ID), '') || '"' || ','
                || '"' || NVL(TO_CHAR(PJC_EXPENDITURE_TYPE_ID), '') || '"' || ','
                || '"' || NVL(TO_CHAR(PJC_EXPENDITURE_ITEM_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(PJC_ORGANIZATION_ID), '') || '"' || ','
                || '"' || REPLACE(NVL(PJC_PROJECT_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_TASK_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_EXPENDITURE_TYPE_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_ORGANIZATION_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_RESERVED_ATTRIBUTE1,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_RESERVED_ATTRIBUTE2,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_RESERVED_ATTRIBUTE3,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_RESERVED_ATTRIBUTE4,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_RESERVED_ATTRIBUTE5,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_RESERVED_ATTRIBUTE6,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_RESERVED_ATTRIBUTE7,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_RESERVED_ATTRIBUTE8,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_RESERVED_ATTRIBUTE9,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_RESERVED_ATTRIBUTE10,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_USER_DEF_ATTRIBUTE1,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_USER_DEF_ATTRIBUTE2,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_USER_DEF_ATTRIBUTE3,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_USER_DEF_ATTRIBUTE4,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_USER_DEF_ATTRIBUTE5,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_USER_DEF_ATTRIBUTE6,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_USER_DEF_ATTRIBUTE7,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_USER_DEF_ATTRIBUTE8,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_USER_DEF_ATTRIBUTE9,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_USER_DEF_ATTRIBUTE10,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(FISCAL_CHARGE_TYPE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(DEF_ACCTG_START_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(DEF_ACCTG_END_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(DEF_ACCRUAL_CODE_CONCATENATED,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_PROJECT_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_TASK_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_WORK_TYPE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_CONTRACT_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_CONTRACT_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_FUNDING_SOURCE_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_FUNDING_SOURCE_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(REQUESTER_EMAIL_ADDRESS,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(RCV_TRANSACTION_ID), '') || '"' || CHR(10) AS csv_line
            FROM   DMT_OWNER.DMT_AP_INVOICE_LINES_INT_TFM_TBL l
            WHERE  l.RUN_ID = p_run_id
            AND    l.TFM_STATUS = 'STAGED'
            AND    l.INVOICE_ID IN (
            SELECT h.INVOICE_ID
            FROM   DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL h
            WHERE  h.RUN_ID = p_run_id
            AND    h.TFM_STATUS IN ('STAGED','GENERATED')
            AND    h.INVOICE_TYPE_LOOKUP_CODE LIKE '%1099%'
            AND    (p_operating_unit IS NULL OR h.OPERATING_UNIT = p_operating_unit))
            ORDER BY l.TFM_SEQUENCE_ID
                    ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;

        RETURN l_csv;
    END gen_lines_csv;

    -- --------------------------------------------------------
    -- Public: GENERATE_FBDI
    -- Builds 2 CSVs, zips them, persists to traceability tables,
    -- marks TFM rows as GENERATED.
    -- When p_operating_unit is non-NULL, only includes rows for that OU.
    -- Only includes invoices with INVOICE_TYPE_LOOKUP_CODE LIKE '%1099%'.
    -- --------------------------------------------------------
    PROCEDURE GENERATE_FBDI (
        p_run_id  IN  NUMBER,
        p_operating_unit  IN  VARCHAR2 DEFAULT NULL,
        x_fbdi_zip        OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_fbdi_csv_id     OUT NUMBER
    )
    IS
        l_zip         BLOB;
        l_hdr_csv     CLOB;
        l_lines_csv   CLOB;
        l_fbdi_csv_id NUMBER;
        l_ou_suffix   VARCHAR2(50);
        l_now         DATE := SYSDATE;
        C_PROC CONSTANT VARCHAR2(30) := 'GENERATE_FBDI';
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => '1099 Invoice FBDI generation start.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        -- Filename: 1099_{GroupValue}_{IntegrationID}.zip
        IF p_operating_unit IS NOT NULL THEN
            l_ou_suffix := '_' || REPLACE(SUBSTR(p_operating_unit, 1, 30), ' ', '');
        END IF;
        x_filename := '1099' || NVL(l_ou_suffix, '_All') || '_' || TO_CHAR(p_run_id) || '.zip';

        -- Generate both CSVs (filtered by OU when provided, and by 1099 type)
        l_hdr_csv   := gen_headers_csv(p_run_id, p_operating_unit);
        l_lines_csv := gen_lines_csv(p_run_id, p_operating_unit);

        -- AD#20: Skip gracefully if no rows generated
        IF (l_hdr_csv IS NULL OR DBMS_LOB.GETLENGTH(l_hdr_csv) = 0)
           AND (l_lines_csv IS NULL OR DBMS_LOB.GETLENGTH(l_lines_csv) = 0) THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'No STAGED 1099 Invoice rows found. Skipping FBDI generation.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            DBMS_LOB.FREETEMPORARY(l_hdr_csv);
            DBMS_LOB.FREETEMPORARY(l_lines_csv);
            x_fbdi_zip := NULL;
            x_filename := NULL;
            x_fbdi_csv_id := NULL;
            RETURN;
        END IF;

        -- Build zip using Anton Scheffer UTL_ZIP
        DBMS_LOB.CREATETEMPORARY(l_zip, TRUE);
        IF DBMS_LOB.GETLENGTH(l_hdr_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'ApInvoicesInterface.csv',
                clob_to_blob(l_hdr_csv));
        END IF;
        IF DBMS_LOB.GETLENGTH(l_lines_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'ApInvoiceLinesInterface.csv',
                clob_to_blob(l_lines_csv));
        END IF;
        DMT_OWNER.UTL_ZIP.finish_zip(l_zip);

        -- Register in DMT_FBDI_CSV_TBL
        SELECT DMT_OWNER.DMT_FBDI_CSV_ID_SEQ.NEXTVAL INTO l_fbdi_csv_id FROM DUAL;
        INSERT INTO DMT_OWNER.DMT_FBDI_CSV_TBL (
            FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME, ROW_COUNT,
            CSV_CONTENT, CREATED_DATE
        ) VALUES (
            l_fbdi_csv_id, p_run_id,
            '1099Invoices',
            x_filename, 0, l_hdr_csv, l_now
        );

        -- Register in DMT_FBDI_ZIP_TBL
        INSERT INTO DMT_OWNER.DMT_FBDI_ZIP_TBL (
            FBDI_ZIP_ID, FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME,
            ZIP_SIZE_BYTES, ZIP_CONTENT, CREATED_DATE
        ) VALUES (
            DMT_OWNER.DMT_FBDI_ZIP_ID_SEQ.NEXTVAL, l_fbdi_csv_id, p_run_id,
            '1099Invoices',
            x_filename,
            DBMS_LOB.GETLENGTH(l_zip), l_zip, l_now
        );

        -- Update TFM rows to GENERATED and stamp FBDI_CSV_ID.
        -- Headers: filter by OPERATING_UNIT and INVOICE_TYPE_LOOKUP_CODE.
        UPDATE DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_fbdi_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED'
        AND    INVOICE_TYPE_LOOKUP_CODE LIKE '%1099%'
        AND    (p_operating_unit IS NULL OR OPERATING_UNIT = p_operating_unit);

        -- Lines: filter via header chain (INVOICE_ID).
        UPDATE DMT_OWNER.DMT_AP_INVOICE_LINES_INT_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_fbdi_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED'
        AND    INVOICE_ID IN (
            SELECT h.INVOICE_ID
            FROM   DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL h
            WHERE  h.RUN_ID = p_run_id
            AND    h.FBDI_CSV_ID = l_fbdi_csv_id);

        -- Free temporary CLOBs
        DBMS_LOB.FREETEMPORARY(l_hdr_csv);
        DBMS_LOB.FREETEMPORARY(l_lines_csv);

        x_fbdi_zip    := l_zip;
        x_fbdi_csv_id := l_fbdi_csv_id;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => '1099 Invoice FBDI generation complete.' ||
                                ' | File: ' || x_filename ||
                                ' | Zip bytes: ' || DBMS_LOB.GETLENGTH(x_fbdi_zip),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => '1099 Invoice FBDI generation failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END GENERATE_FBDI;

END DMT_1099_FBDI_GEN_PKG;
/
