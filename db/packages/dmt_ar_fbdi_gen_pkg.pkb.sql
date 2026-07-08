-- PACKAGE BODY DMT_AR_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_AR_FBDI_GEN_PKG" 
AS
    C_PKG CONSTANT VARCHAR2(50) := 'DMT_AR_FBDI_GEN_PKG';

-- ============================================================
-- DMT_AR_FBDI_GEN_PKG body
-- ARInvoices FBDI zip generation.
-- ONE zip with 2 CSVs: RaInterfaceLinesAll.csv + RaInterfaceDistributionsAll.csv
-- When p_bu_name is non-NULL, filters both CSVs to that Business Unit.
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
    -- Private: generate RaInterfaceLinesAll.csv CLOB
    -- When p_bu_name is non-NULL, only includes lines for that BU.
    -- --------------------------------------------------------
    FUNCTION gen_lines_csv (
        p_run_id    IN NUMBER,
        p_bu_name           IN VARCHAR2 DEFAULT NULL,
        p_batch_source_name IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB
    IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        FOR r IN (
            SELECT
                '"' || REPLACE(NVL(ORG_ID,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(BATCH_SOURCE_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CUST_TRX_TYPE_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TERM_NAME,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(TRX_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(GL_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(TRX_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ORIG_SYSTEM_BILL_CUSTOMER_REF,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ORIG_SYSTEM_BILL_ADDRESS_REF,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ORIG_SYSTEM_BILL_CONTACT_REF,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ORIG_SYS_SHIP_PARTY_REF,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ORIG_SYS_SHIP_PARTY_SITE_REF,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ORIG_SYS_SHIP_PTY_CONTACT_REF,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ORIG_SYSTEM_SHIP_CUSTOMER_REF,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ORIG_SYSTEM_SHIP_ADDRESS_REF,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ORIG_SYSTEM_SHIP_CONTACT_REF,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ORIG_SYS_SOLD_PARTY_REF,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ORIG_SYSTEM_SOLD_CUSTOMER_REF,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(BILL_CUSTOMER_ACCOUNT_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(BILL_CUSTOMER_SITE_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(BILL_CONTACT_PARTY_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SHIP_CUSTOMER_ACCOUNT_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SHIP_CUSTOMER_SITE_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SHIP_CONTACT_PARTY_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SOLD_CUSTOMER_ACCOUNT_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LINE_TYPE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DESCRIPTION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CURRENCY_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CONVERSION_TYPE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(CONVERSION_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(CONVERSION_RATE), '') || '"' || ','
                || '"' || NVL(TO_CHAR(AMOUNT), '') || '"' || ','
                || '"' || NVL(TO_CHAR(QUANTITY), '') || '"' || ','
                || '"' || NVL(TO_CHAR(QUANTITY_ORDERED), '') || '"' || ','
                || '"' || NVL(TO_CHAR(UNIT_SELLING_PRICE), '') || '"' || ','
                || '"' || NVL(TO_CHAR(UNIT_STANDARD_PRICE), '') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_CONTEXT,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_ATTRIBUTE1,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_ATTRIBUTE2,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_ATTRIBUTE3,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_ATTRIBUTE4,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_ATTRIBUTE5,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_ATTRIBUTE6,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_ATTRIBUTE7,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_ATTRIBUTE8,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_ATTRIBUTE9,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_ATTRIBUTE10,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_ATTRIBUTE11,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_ATTRIBUTE12,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_ATTRIBUTE13,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_ATTRIBUTE14,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_ATTRIBUTE15,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PRIMARY_SALESREP_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TAX_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LEGAL_ENTITY_IDENTIFIER,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(ACCTD_AMOUNT), '') || '"' || ','
                || '"' || REPLACE(NVL(SALES_ORDER,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(SALES_ORDER_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(SHIP_DATE_ACTUAL, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(WAREHOUSE_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(UOM_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(UOM_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INVOICING_RULE_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ACCOUNTING_RULE_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ACCOUNTING_RULE_DURATION,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(RULE_START_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(RULE_END_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(REASON_CODE_MEANING,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(LAST_PERIOD_TO_CREDIT), '') || '"' || ','
                || '"' || REPLACE(NVL(TRX_BUSINESS_CATEGORY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PRODUCT_FISC_CLASSIFICATION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PRODUCT_CATEGORY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PRODUCT_TYPE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LINE_INTENDED_USE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(ASSESSABLE_VALUE), '') || '"' || ','
                || '"' || REPLACE(NVL(DOCUMENT_SUB_TYPE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DEFAULT_TAXATION_COUNTRY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(USER_DEFINED_FISC_CLASS,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TAX_INVOICE_NUMBER,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(TAX_INVOICE_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(TAX_REGIME_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TAX,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TAX_STATUS_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TAX_RATE_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TAX_JURISDICTION_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(FIRST_PTY_REG_NUM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(THIRD_PTY_REG_NUM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(FINAL_DISCHARGE_LOCATION_CODE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(TAXABLE_AMOUNT), '') || '"' || ','
                || '"' || REPLACE(NVL(TAXABLE_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TAX_EXEMPT_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TAX_EXEMPT_REASON_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TAX_EXEMPT_REASON_CODE_MEANING,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TAX_EXEMPT_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(AMOUNT_INCLUDES_TAX_FLAG,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(TAX_PRECEDENCE), '') || '"' || ','
                || '"' || REPLACE(NVL(CREDIT_METHOD_FOR_ACCT_RULE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CREDIT_METHOD_FOR_INSTALLMENTS,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(REASON_CODE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(TAX_RATE), '') || '"' || ','
                || '"' || REPLACE(NVL(FOB_POINT,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SHIP_VIA,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(WAYBILL_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SALES_ORDER_LINE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SALES_ORDER_SOURCE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(SALES_ORDER_REVISION), '') || '"' || ','
                || '"' || REPLACE(NVL(PURCHASE_ORDER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PURCHASE_ORDER_REVISION,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(PURCHASE_ORDER_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(AGREEMENT_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(MEMO_LINE_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DOCUMENT_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ORIG_SYSTEM_BATCH_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LINK_TO_LINE_CONTEXT,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LINK_TO_LINE_ATTRIBUTE1,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LINK_TO_LINE_ATTRIBUTE2,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LINK_TO_LINE_ATTRIBUTE3,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LINK_TO_LINE_ATTRIBUTE4,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LINK_TO_LINE_ATTRIBUTE5,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LINK_TO_LINE_ATTRIBUTE6,''), '"', '""') || '"' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '"' || REPLACE(NVL(RECEIPT_METHOD_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PRINTING_OPTION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(RELATED_BATCH_SOURCE_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(RELATED_TRX_NUMBER,''), '"', '""') || '"' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '"' || REPLACE(NVL(TRANSLATED_DESCRIPTION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CONS_BILLING_NUMBER,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(PROMISED_COMMITMENT_AMOUNT), '') || '"' || ','
                || '"' || NVL(TO_CHAR(PAYMENT_SET_ID), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ORIGINAL_GL_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(INVOICED_LINE_ACCTG_LEVEL,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(OVERRIDE_AUTO_ACCOUNTING_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(HISTORICAL_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DEFERRAL_EXCLUSION_FLAG,''), '"', '""') || '"' || ','
                || '""' || ','
                || '"' || NVL(TO_CHAR(BILLING_DATE, 'YYYY/MM/DD'), '') || '"' || ','
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
                || '"' || REPLACE(NVL(HEADER_ATTRIBUTE_CATEGORY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(HEADER_ATTRIBUTE1,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(HEADER_ATTRIBUTE2,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(HEADER_ATTRIBUTE3,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(HEADER_ATTRIBUTE4,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(HEADER_ATTRIBUTE5,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(HEADER_ATTRIBUTE6,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(HEADER_ATTRIBUTE7,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(HEADER_ATTRIBUTE8,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(HEADER_ATTRIBUTE9,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(HEADER_ATTRIBUTE10,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(HEADER_ATTRIBUTE11,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(HEADER_ATTRIBUTE12,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(HEADER_ATTRIBUTE13,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(HEADER_ATTRIBUTE14,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(HEADER_ATTRIBUTE15,''), '"', '""') || '"' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '"' || REPLACE(NVL(BU_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(COMMENTS,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERNAL_NOTES,''), '"', '""') || '"' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || CHR(10) AS csv_line
            FROM   DMT_OWNER.DMT_RA_LINES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id
            AND    t.STATUS = 'STAGED'
            AND    (p_bu_name IS NULL OR t.BU_NAME = p_bu_name)
            AND    (p_batch_source_name IS NULL OR t.BATCH_SOURCE_NAME = p_batch_source_name)
            ORDER BY t.TFM_SEQUENCE_ID
                    ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;

        RETURN l_csv;
    END gen_lines_csv;

    -- --------------------------------------------------------
    -- Private: generate RaInterfaceDistributionsAll.csv CLOB
    -- When p_bu_name is non-NULL, filters via INTERFACE_LINE_ATTRIBUTE
    -- chain to lines for that BU.
    -- --------------------------------------------------------
    FUNCTION gen_dists_csv (
        p_run_id    IN NUMBER,
        p_bu_name           IN VARCHAR2 DEFAULT NULL,
        p_batch_source_name IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB
    IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        FOR r IN (
            SELECT
                '"' || REPLACE(NVL(ORG_ID,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ACCOUNT_CLASS,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(AMOUNT), '') || '"' || ','
                || '"' || NVL(TO_CHAR(PERCENT), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ACCTD_AMOUNT), '') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_CONTEXT,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_ATTRIBUTE1,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_ATTRIBUTE2,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_ATTRIBUTE3,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_ATTRIBUTE4,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_ATTRIBUTE5,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_ATTRIBUTE6,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_ATTRIBUTE7,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_ATTRIBUTE8,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_ATTRIBUTE9,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_ATTRIBUTE10,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_ATTRIBUTE11,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_ATTRIBUTE12,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_ATTRIBUTE13,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_ATTRIBUTE14,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_ATTRIBUTE15,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT1,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT2,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT3,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT4,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT5,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT6,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT7,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT8,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT9,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT10,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT11,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT12,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT13,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT14,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT15,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT16,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT17,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT18,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT19,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT20,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT21,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT22,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT23,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT24,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT25,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT26,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT27,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT28,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT29,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT30,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(COMMENTS,''), '"', '""') || '"' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
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
                || '"' || REPLACE(NVL(BU_NAME,''), '"', '""') || '"' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || CHR(10) AS csv_line
            FROM   DMT_OWNER.DMT_RA_DISTS_TFM_TBL d
            WHERE  d.RUN_ID = p_run_id
            AND    d.STATUS = 'STAGED'
            AND    (p_bu_name IS NULL OR d.BU_NAME = p_bu_name)
            AND    (p_batch_source_name IS NULL OR EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_RA_LINES_TFM_TBL l
            WHERE  l.RUN_ID        = d.RUN_ID
            AND    l.INTERFACE_LINE_CONTEXT = d.INTERFACE_LINE_CONTEXT
            AND    l.INTERFACE_LINE_ATTRIBUTE1 = d.INTERFACE_LINE_ATTRIBUTE1
            AND    l.INTERFACE_LINE_ATTRIBUTE2 = d.INTERFACE_LINE_ATTRIBUTE2
            AND    l.BATCH_SOURCE_NAME      = p_batch_source_name
            AND    l.BU_NAME                = d.BU_NAME))
            ORDER BY d.TFM_SEQUENCE_ID
                    ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;

        RETURN l_csv;
    END gen_dists_csv;

    -- --------------------------------------------------------
    -- Public: GENERATE_FBDI
    -- Builds 2 CSVs, zips them, persists to traceability tables,
    -- marks TFM rows as GENERATED.
    -- When p_bu_name is non-NULL, only includes rows for that BU.
    -- --------------------------------------------------------
    PROCEDURE GENERATE_FBDI (
        p_run_id    IN  NUMBER,
        p_bu_name           IN  VARCHAR2 DEFAULT NULL,
        p_batch_source_name IN  VARCHAR2 DEFAULT NULL,
        x_fbdi_zip          OUT BLOB,
        x_filename          OUT VARCHAR2,
        x_fbdi_csv_id       OUT NUMBER
    )
    IS
        l_zip         BLOB;
        l_lines_csv   CLOB;
        l_dists_csv   CLOB;
        l_fbdi_csv_id NUMBER;
        l_group_suffix VARCHAR2(100);
        l_now         DATE := SYSDATE;
        C_PROC CONSTANT VARCHAR2(30) := 'GENERATE_FBDI';
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'AR Invoice FBDI generation start.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        -- Filename: ARInvoices_{BU}_{Source}_{IntegrationID}.zip
        IF p_bu_name IS NOT NULL THEN
            l_group_suffix := '_' || REPLACE(SUBSTR(p_bu_name, 1, 20), ' ', '');
            IF p_batch_source_name IS NOT NULL THEN
                l_group_suffix := l_group_suffix || '_' || REPLACE(SUBSTR(p_batch_source_name, 1, 20), ' ', '');
            END IF;
        END IF;
        x_filename := 'ARInvoices' || NVL(l_group_suffix, '_ALL') || '_' || TO_CHAR(p_run_id) || '.zip';

        -- Generate both CSVs (filtered by BU + Transaction Source when provided)
        l_lines_csv := gen_lines_csv(p_run_id, p_bu_name, p_batch_source_name);
        l_dists_csv := gen_dists_csv(p_run_id, p_bu_name, p_batch_source_name);

        -- AD#20: Skip gracefully if no rows generated
        IF (l_lines_csv IS NULL OR DBMS_LOB.GETLENGTH(l_lines_csv) = 0) THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'No STAGED AR Invoice rows found. Skipping FBDI generation.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            DBMS_LOB.FREETEMPORARY(l_lines_csv);
            DBMS_LOB.FREETEMPORARY(l_dists_csv);
            x_fbdi_zip := NULL;
            x_filename := NULL;
            x_fbdi_csv_id := NULL;
            RETURN;
        END IF;

        -- Build zip using Anton Scheffer UTL_ZIP
        DBMS_LOB.CREATETEMPORARY(l_zip, TRUE);
        DMT_OWNER.UTL_ZIP.add1file(l_zip, 'RaInterfaceLinesAll.csv',
            clob_to_blob(l_lines_csv));
        -- Only add distributions CSV if it has content (distributions are optional in AR FBDI)
        IF l_dists_csv IS NOT NULL AND DBMS_LOB.GETLENGTH(l_dists_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'RaInterfaceDistributionsAll.csv',
                clob_to_blob(l_dists_csv));
        END IF;
        DMT_OWNER.UTL_ZIP.finish_zip(l_zip);

        DECLARE
            l_obj_type VARCHAR2(200) := 'ARInvoices';
        BEGIN

            -- Register in DMT_FBDI_CSV_TBL
            SELECT DMT_OWNER.DMT_FBDI_CSV_ID_SEQ.NEXTVAL INTO l_fbdi_csv_id FROM DUAL;
            INSERT INTO DMT_OWNER.DMT_FBDI_CSV_TBL (
                FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME, ROW_COUNT,
                CSV_CONTENT, CREATED_DATE
            ) VALUES (
                l_fbdi_csv_id, p_run_id, l_obj_type,
                x_filename, 0, l_lines_csv, l_now
            );

            -- Register in DMT_FBDI_ZIP_TBL
            INSERT INTO DMT_OWNER.DMT_FBDI_ZIP_TBL (
                FBDI_ZIP_ID, FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME,
                ZIP_SIZE_BYTES, ZIP_CONTENT, CREATED_DATE
            ) VALUES (
                DMT_OWNER.DMT_FBDI_ZIP_ID_SEQ.NEXTVAL, l_fbdi_csv_id, p_run_id,
                l_obj_type, x_filename,
                DBMS_LOB.GETLENGTH(l_zip), l_zip, l_now
            );
        END;

        -- Update lines TFM rows to GENERATED and stamp FBDI_CSV_ID.
        UPDATE DMT_OWNER.DMT_RA_LINES_TFM_TBL
        SET    STATUS = 'GENERATED', FBDI_CSV_ID = l_fbdi_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND STATUS = 'STAGED'
        AND    (p_bu_name IS NULL OR BU_NAME = p_bu_name)
        AND    (p_batch_source_name IS NULL OR BATCH_SOURCE_NAME = p_batch_source_name);

        -- Update dists TFM rows to GENERATED and stamp FBDI_CSV_ID.
        UPDATE DMT_OWNER.DMT_RA_DISTS_TFM_TBL
        SET    STATUS = 'GENERATED', FBDI_CSV_ID = l_fbdi_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND STATUS = 'STAGED'
        AND    (p_bu_name IS NULL OR BU_NAME = p_bu_name)
        AND    (p_batch_source_name IS NULL OR EXISTS (
                   SELECT 1 FROM DMT_OWNER.DMT_RA_LINES_TFM_TBL l
                   WHERE  l.RUN_ID        = DMT_RA_DISTS_TFM_TBL.RUN_ID
                   AND    l.INTERFACE_LINE_CONTEXT = DMT_RA_DISTS_TFM_TBL.INTERFACE_LINE_CONTEXT
                   AND    l.INTERFACE_LINE_ATTRIBUTE1 = DMT_RA_DISTS_TFM_TBL.INTERFACE_LINE_ATTRIBUTE1
                   AND    l.INTERFACE_LINE_ATTRIBUTE2 = DMT_RA_DISTS_TFM_TBL.INTERFACE_LINE_ATTRIBUTE2
                   AND    l.BATCH_SOURCE_NAME      = p_batch_source_name
                   AND    l.BU_NAME                = DMT_RA_DISTS_TFM_TBL.BU_NAME));

        -- Free temporary CLOBs
        DBMS_LOB.FREETEMPORARY(l_lines_csv);
        DBMS_LOB.FREETEMPORARY(l_dists_csv);

        x_fbdi_zip    := l_zip;
        x_fbdi_csv_id := l_fbdi_csv_id;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'AR Invoice FBDI generation complete.' ||
                                ' | File: ' || x_filename ||
                                ' | Zip bytes: ' || DBMS_LOB.GETLENGTH(x_fbdi_zip),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'AR Invoice FBDI generation failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END GENERATE_FBDI;

END DMT_AR_FBDI_GEN_PKG;
/
