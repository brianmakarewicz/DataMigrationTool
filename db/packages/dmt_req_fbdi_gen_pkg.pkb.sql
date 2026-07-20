-- PACKAGE BODY DMT_REQ_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_REQ_FBDI_GEN_PKG" 
AS
    C_PKG CONSTANT VARCHAR2(50) := 'DMT_REQ_FBDI_GEN_PKG';

-- ============================================================
-- DMT_REQ_FBDI_GEN_PKG body
-- Requisitions FBDI zip generation.
-- ============================================================

    -- --------------------------------------------------------
    -- Private: append a delimited CSV row to a CLOB
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
    -- Private: convert CLOB to BLOB without 32K truncation
    -- --------------------------------------------------------
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
    -- Private: generate PorReqHeadersInterface.csv CLOB
    -- --------------------------------------------------------
    FUNCTION gen_headers_csv (
        p_run_id IN NUMBER,
        p_batch_id IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB
    IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        FOR r IN (
            SELECT
                '"' || REPLACE(NVL(INTERFACE_HEADER_KEY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_SOURCE_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(REQ_BU_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(BATCH_ID,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_SOURCE_LINE_ID,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DOCUMENT_STATUS,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(APPROVER_EMAIL_ADDR,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PREPARER_EMAIL_ADDR,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PRC_BU_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(REQUISITION_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DESCRIPTION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(EMERGENCY_PO_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DEFAULT_TAXATION_COUNTRY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DEFAULT_TAXATION_TERRITORY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DOCUMENT_SUB_TYPE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DOCUMENT_SUB_TYPE_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(JUSTIFICATION,''), '"', '""') || '"' || ','
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
                || '"' || REPLACE(NVL(ATTRIBUTE16,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE17,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE18,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE19,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE20,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_DATE1,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_DATE2,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_DATE3,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_DATE4,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_DATE5,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_DATE6,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_DATE7,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_DATE8,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_DATE9,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_DATE10,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_TIMESTAMP1,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_TIMESTAMP2,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_TIMESTAMP3,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_TIMESTAMP4,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_TIMESTAMP5,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_TIMESTAMP6,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_TIMESTAMP7,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_TIMESTAMP8,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_TIMESTAMP9,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_TIMESTAMP10,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER1), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER2), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER3), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER4), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER5), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER6), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER7), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER8), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER9), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER10), '') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_CATEGORY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SOLDTO_LE_NAME,''), '"', '""') || '"' || ','
                || '"N"' || CHR(10) AS csv_line  -- col 69: EXTERNALLY_MANAGED_FLAG = N
            FROM   DMT_OWNER.DMT_POR_REQ_HEADERS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id
            AND    t.TFM_STATUS = 'STAGED'
            AND    (p_batch_id IS NULL OR t.BATCH_ID = p_batch_id)
            ORDER BY t.TFM_SEQUENCE_ID
        ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;

        RETURN l_csv;
    END gen_headers_csv;

    -- --------------------------------------------------------
    -- Private: generate PorReqLinesInterface.csv CLOB
    -- --------------------------------------------------------
    FUNCTION gen_lines_csv (
        p_run_id IN NUMBER,
        p_batch_id IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB
    IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        FOR r IN (
            SELECT
                '"' || REPLACE(NVL(INTERFACE_LINE_KEY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_HEADER_KEY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GROUP_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DESTINATION_TYPE_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DELIVER_TO_LOCATION_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DESTINATION_ORGANIZATION_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DESTINATION_SUBINVENTORY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(REQUESTER_EMAIL_ADDR,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ITEM_DESCRIPTION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CATEGORY_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(NEED_BY_DATE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ITEM_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ITEM_REVISION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(UOM_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LINE_TYPE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(QUANTITY), '') || '"' || ','
                || '"' || REPLACE(NVL(CURRENCY_CODE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(CURRENCY_UNIT_PRICE), '') || '"' || ','
                || '"' || NVL(TO_CHAR(RATE), '') || '"' || ','
                || '"' || REPLACE(NVL(RATE_DATE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(RATE_TYPE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SECONDARY_UOM_CODE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(SECONDARY_QUANTITY), '') || '"' || ','
                || '"' || NVL(TO_CHAR(CURRENCY_AMOUNT), '') || '"' || ','
                || '"' || REPLACE(NVL(UN_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(HAZARD_CLASS,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PRC_BU_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SOURCE_DOC_HEADER_NUMBER,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(SOURCE_DOC_LINE_NUMBER), '') || '"' || ','
                || '"' || REPLACE(NVL(SUGGESTED_VENDOR_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SUGGESTED_VENDOR_SITE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SUGGESTED_VENDOR_CONTACT,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SUGGESTED_VENDOR_CONTACT_PHONE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SUGGESTED_VENDOR_CONTACT_FAX,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SUGGESTED_VENDOR_CONTACT_EMAIL,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SUGGESTED_SUPPLIER_ITEM_NUM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SUGGESTED_BUYER_EMAIL_ADDR,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(AUTOSOURCE_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(NEGOTIATED_BY_PREPARER_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(NEGOTIATION_REQUIRED_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(URGENT_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(NEW_SUPPLIER_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(NOTE_TO_BUYER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(NOTE_TO_RECEIVER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TRX_BUSINESS_CATEGORY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TRX_BUSINESS_CATEGORY_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PRODUCT_TYPE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PRODUCT_TYPE_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PRODUCT_FISC_CLASSIFICATION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PRODUCT_FISC_CLASS_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PRODUCT_CATEGORY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PRODUCT_CATEGORY_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LINE_INTENDED_USE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LINE_INTENDED_USE_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(USER_DEFINED_FISC_CLASS,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(USER_DEFINED_FISC_CLASS_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TAX_CLASSIFICATION_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TAX_CLASSIFICATION_NAME,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(ASSESSABLE_VALUE), '') || '"' || ','
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
                || '"' || REPLACE(NVL(ATTRIBUTE16,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE17,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE18,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE19,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE20,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_DATE1,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_DATE2,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_DATE3,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_DATE4,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_DATE5,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_DATE6,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_DATE7,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_DATE8,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_DATE9,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_DATE10,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_TIMESTAMP1,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_TIMESTAMP2,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_TIMESTAMP3,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_TIMESTAMP4,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_TIMESTAMP5,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_TIMESTAMP6,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_TIMESTAMP7,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_TIMESTAMP8,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_TIMESTAMP9,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_TIMESTAMP10,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER1), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER2), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER3), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER4), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER5), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER6), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER7), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER8), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER9), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER10), '') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_CATEGORY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(VENDOR_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(FIRST_PTY_REG_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(THIRD_PTY_REG_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(FINAL_DISCHARGE_LOC_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(UNIT_OF_MEASURE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SECONDARY_UNIT_OF_MEASURE,''), '"', '""') || '"' || CHR(10) AS csv_line
            FROM   DMT_OWNER.DMT_POR_REQ_LINES_TFM_TBL l
            WHERE  l.RUN_ID = p_run_id
            AND    l.TFM_STATUS = 'STAGED'
            AND    (p_batch_id IS NULL OR EXISTS (
                        SELECT 1 FROM DMT_OWNER.DMT_POR_REQ_HEADERS_TFM_TBL h
                        WHERE h.RUN_ID = l.RUN_ID
                          AND h.INTERFACE_HEADER_KEY = l.INTERFACE_HEADER_KEY
                          AND h.BATCH_ID = p_batch_id))
            ORDER BY l.TFM_SEQUENCE_ID
        ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;

        RETURN l_csv;
    END gen_lines_csv;

    -- --------------------------------------------------------
    -- Private: generate PorReqDistsInterface.csv CLOB
    -- --------------------------------------------------------
    FUNCTION gen_dists_csv (
        p_run_id IN NUMBER,
        p_batch_id IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB
    IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        FOR r IN (
            SELECT
                '"' || REPLACE(NVL(INTERFACE_DISTRIBUTION_KEY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_KEY,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(PERCENT), '') || '"' || ','
                || '"' || NVL(TO_CHAR(DISTRIBUTION_NUMBER), '') || '"' || ','
                || '"' || NVL(TO_CHAR(DISTRIBUTION_QUANTITY), '') || '"' || ','
                || '"' || NVL(TO_CHAR(DISTRIBUTION_CURRENCY_AMOUNT), '') || '"' || ','
                || '"' || REPLACE(NVL(PJC_PROJECT_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_TASK_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_EXPENDITURE_TYPE_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_EXPENDITURE_ITEM_DATE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_ORGANIZATION_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_BILLABLE_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_CAPITALIZABLE_FLAG,''), '"', '""') || '"' || ','
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
                || '"' || REPLACE(NVL(ATTRIBUTE16,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE17,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE18,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE19,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE20,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_DATE1,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_DATE2,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_DATE3,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_DATE4,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_DATE5,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_DATE6,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_DATE7,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_DATE8,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_DATE9,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_DATE10,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_TIMESTAMP1,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_TIMESTAMP2,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_TIMESTAMP3,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_TIMESTAMP4,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_TIMESTAMP5,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_TIMESTAMP6,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_TIMESTAMP7,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_TIMESTAMP8,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_TIMESTAMP9,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_TIMESTAMP10,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER1), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER2), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER3), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER4), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER5), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER6), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER7), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER8), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER9), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER10), '') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_CATEGORY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CHARGE_ACCOUNT_SEGMENT1,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CHARGE_ACCOUNT_SEGMENT2,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CHARGE_ACCOUNT_SEGMENT3,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CHARGE_ACCOUNT_SEGMENT4,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CHARGE_ACCOUNT_SEGMENT5,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CHARGE_ACCOUNT_SEGMENT6,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CHARGE_ACCOUNT_SEGMENT7,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CHARGE_ACCOUNT_SEGMENT8,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CHARGE_ACCOUNT_SEGMENT9,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CHARGE_ACCOUNT_SEGMENT10,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CHARGE_ACCOUNT_SEGMENT11,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CHARGE_ACCOUNT_SEGMENT12,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CHARGE_ACCOUNT_SEGMENT13,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CHARGE_ACCOUNT_SEGMENT14,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CHARGE_ACCOUNT_SEGMENT15,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CHARGE_ACCOUNT_SEGMENT16,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CHARGE_ACCOUNT_SEGMENT17,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CHARGE_ACCOUNT_SEGMENT18,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CHARGE_ACCOUNT_SEGMENT19,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CHARGE_ACCOUNT_SEGMENT20,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CHARGE_ACCOUNT_SEGMENT21,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CHARGE_ACCOUNT_SEGMENT22,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CHARGE_ACCOUNT_SEGMENT23,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CHARGE_ACCOUNT_SEGMENT24,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CHARGE_ACCOUNT_SEGMENT25,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CHARGE_ACCOUNT_SEGMENT26,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CHARGE_ACCOUNT_SEGMENT27,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CHARGE_ACCOUNT_SEGMENT28,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CHARGE_ACCOUNT_SEGMENT29,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CHARGE_ACCOUNT_SEGMENT30,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_WORK_TYPE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(BUDGET_DATE,''), '"', '""') || '"' || CHR(10) AS csv_line
            FROM   DMT_OWNER.DMT_POR_REQ_DISTS_TFM_TBL d
            WHERE  d.RUN_ID = p_run_id
            AND    d.TFM_STATUS = 'STAGED'
            AND    (p_batch_id IS NULL OR EXISTS (
                        SELECT 1
                        FROM DMT_OWNER.DMT_POR_REQ_LINES_TFM_TBL l
                        JOIN DMT_OWNER.DMT_POR_REQ_HEADERS_TFM_TBL h
                          ON h.RUN_ID = l.RUN_ID
                         AND h.INTERFACE_HEADER_KEY = l.INTERFACE_HEADER_KEY
                        WHERE l.RUN_ID = d.RUN_ID
                          AND l.INTERFACE_LINE_KEY = d.INTERFACE_LINE_KEY
                          AND h.BATCH_ID = p_batch_id))
            ORDER BY d.TFM_SEQUENCE_ID
        ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;

        RETURN l_csv;
    END gen_dists_csv;

    -- --------------------------------------------------------
    -- Public: GENERATE_FBDI
    -- Builds 3 CSVs, zips them, persists to traceability tables,
    -- marks TFM rows as GENERATED.
    -- --------------------------------------------------------
    PROCEDURE GENERATE_FBDI (
        p_run_id IN  NUMBER,
        x_fbdi_zip       OUT BLOB,
        x_filename       OUT VARCHAR2,
        x_fbdi_csv_id    OUT NUMBER,
        p_batch_id       IN  VARCHAR2 DEFAULT NULL
    )
    IS
        l_zip         BLOB;
        l_hdr_csv     CLOB;
        l_lines_csv   CLOB;
        l_dists_csv   CLOB;
        l_fbdi_csv_id NUMBER;   -- primary (headers) csv id, returned to the loader
        l_zip_id      NUMBER;
        l_lines_csv_id NUMBER;
        l_dists_csv_id NUMBER;
        l_bytes       NUMBER;
        l_now         DATE := SYSDATE;
        C_PROC CONSTANT VARCHAR2(30) := 'GENERATE_FBDI';
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Requisition FBDI generation start.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        x_filename := 'REQ_' || TO_CHAR(p_run_id)
                      || CASE WHEN p_batch_id IS NULL THEN '' ELSE '_' || p_batch_id END
                      || '.zip';

        -- Generate all 3 CSVs (filtered to one batch when p_batch_id is passed)
        l_hdr_csv   := gen_headers_csv(p_run_id, p_batch_id);
        l_lines_csv := gen_lines_csv(p_run_id, p_batch_id);
        l_dists_csv := gen_dists_csv(p_run_id, p_batch_id);

        -- AD#20: Skip gracefully if no rows generated
        IF (l_hdr_csv IS NULL OR DBMS_LOB.GETLENGTH(l_hdr_csv) = 0) THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'No STAGED Requisition rows found. Skipping FBDI generation.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            DBMS_LOB.FREETEMPORARY(l_hdr_csv);
            DBMS_LOB.FREETEMPORARY(l_lines_csv);
            DBMS_LOB.FREETEMPORARY(l_dists_csv);
            x_fbdi_zip := NULL;
            x_filename := NULL;
            x_fbdi_csv_id := NULL;
            RETURN;
        END IF;

        -- FBDI CSV<->ZIP remodel: register each physical CSV as its own row, then
        -- build the zip from those persisted rows. One zip owns three CSVs.
        SELECT DMT_OWNER.DMT_FBDI_ZIP_ID_SEQ.NEXTVAL INTO l_zip_id FROM DUAL;
        DMT_UTIL_PKG.REGISTER_CSV(p_run_id, l_zip_id, 1, 'Requisitions', 'PorReqHeadersInterfaceAll.csv', 0, l_hdr_csv, l_fbdi_csv_id);
        DMT_UTIL_PKG.REGISTER_CSV(p_run_id, l_zip_id, 2, 'Requisitions', 'PorReqLinesInterfaceAll.csv',   0, l_lines_csv, l_lines_csv_id);
        DMT_UTIL_PKG.REGISTER_CSV(p_run_id, l_zip_id, 3, 'Requisitions', 'PorReqDistsInterfaceAll.csv',   0, l_dists_csv, l_dists_csv_id);
        DMT_UTIL_PKG.BUILD_ZIP_FROM_CSVS(p_run_id, l_zip_id, 'Requisitions', x_filename, l_zip, l_bytes);

        -- Update TFM rows to GENERATED and stamp EACH file's own FBDI_CSV_ID.
        -- Scoped to the batch (when passed) so one batch's generate only flips
        -- its own rows and does not starve later batches in the same run.
        -- Headers filter by BATCH_ID directly; lines/dists filter through their header.
        -- Work-queue-ID core (2026-07-20): stamp WORK_QUEUE_ID = the generating child
        -- work-queue item's id so reconcile scopes its sweep to this item's rows only.
        UPDATE DMT_OWNER.DMT_POR_REQ_HEADERS_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_fbdi_csv_id,
               WORK_QUEUE_ID = DMT_LOADER_PKG.g_work_queue_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED'
        AND    (p_batch_id IS NULL OR BATCH_ID = p_batch_id);

        -- Lines -> lines csv id
        UPDATE DMT_OWNER.DMT_POR_REQ_LINES_TFM_TBL l
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_lines_csv_id,
               WORK_QUEUE_ID = DMT_LOADER_PKG.g_work_queue_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED'
        AND    (p_batch_id IS NULL OR EXISTS (
                    SELECT 1 FROM DMT_OWNER.DMT_POR_REQ_HEADERS_TFM_TBL h
                    WHERE h.RUN_ID = l.RUN_ID
                      AND h.INTERFACE_HEADER_KEY = l.INTERFACE_HEADER_KEY
                      AND h.BATCH_ID = p_batch_id));

        -- Distributions -> dists csv id
        UPDATE DMT_OWNER.DMT_POR_REQ_DISTS_TFM_TBL d
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_dists_csv_id,
               WORK_QUEUE_ID = DMT_LOADER_PKG.g_work_queue_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED'
        AND    (p_batch_id IS NULL OR EXISTS (
                    SELECT 1
                    FROM DMT_OWNER.DMT_POR_REQ_LINES_TFM_TBL l
                    JOIN DMT_OWNER.DMT_POR_REQ_HEADERS_TFM_TBL h
                      ON h.RUN_ID = l.RUN_ID
                     AND h.INTERFACE_HEADER_KEY = l.INTERFACE_HEADER_KEY
                    WHERE l.RUN_ID = d.RUN_ID
                      AND l.INTERFACE_LINE_KEY = d.INTERFACE_LINE_KEY
                      AND h.BATCH_ID = p_batch_id));

        -- Free temporary CLOBs
        DBMS_LOB.FREETEMPORARY(l_hdr_csv);
        DBMS_LOB.FREETEMPORARY(l_lines_csv);
        DBMS_LOB.FREETEMPORARY(l_dists_csv);

        x_fbdi_zip   := l_zip;
        x_fbdi_csv_id := l_fbdi_csv_id;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Requisition FBDI generation complete.' ||
                                ' | File: ' || x_filename ||
                                ' | Zip bytes: ' || DBMS_LOB.GETLENGTH(x_fbdi_zip),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'Requisition FBDI generation failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END GENERATE_FBDI;

END DMT_REQ_FBDI_GEN_PKG;
/
