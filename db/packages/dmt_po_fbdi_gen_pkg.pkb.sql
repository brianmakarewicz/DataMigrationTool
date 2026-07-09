-- PACKAGE BODY DMT_PO_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_PO_FBDI_GEN_PKG" 
AS
    C_PKG CONSTANT VARCHAR2(50) := 'DMT_PO_FBDI_GEN_PKG';

-- ============================================================
-- DMT_PO_FBDI_GEN_PKG body
-- PurchaseOrders FBDI zip generation.
-- Multi-BU: when p_prc_bu_name is non-NULL, filters all 4 CSVs
-- to only include rows for that Procurement BU.
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
    -- Private: generate PoHeadersInterfaceOrder.csv CLOB
    -- When p_prc_bu_name is non-NULL, only includes headers for that BU.
    -- --------------------------------------------------------
    FUNCTION gen_headers_csv (
        p_run_id IN NUMBER,
        p_prc_bu_name    IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB
    IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        FOR r IN (
            SELECT
                '"' || REPLACE(NVL(INTERFACE_HEADER_KEY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ACTION,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(BATCH_ID), '') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_SOURCE_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(APPROVAL_ACTION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DOCUMENT_NUM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DOCUMENT_TYPE_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(STYLE_DISPLAY_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PRC_BU_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(REQ_BU_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SOLDTO_LE_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(BILLTO_BU_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(AGENT_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CURRENCY_CODE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(RATE), '') || '"' || ','
                || '"' || REPLACE(NVL(RATE_TYPE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(RATE_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(COMMENTS,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(BILL_TO_LOCATION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SHIP_TO_LOCATION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(VENDOR_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(VENDOR_NUM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(VENDOR_SITE_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(VENDOR_CONTACT,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(VENDOR_DOC_NUM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(FOB,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(FREIGHT_CARRIER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(FREIGHT_TERMS,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PAY_ON_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PAYMENT_TERMS,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ORIGINATOR_ROLE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CHANGE_ORDER_DESC,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ACCEPTANCE_REQUIRED_FLAG,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(ACCEPTANCE_WITHIN_DAYS), '') || '"' || ','
                || '"' || REPLACE(NVL(SUPPLIER_NOTIF_METHOD,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(FAX,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(EMAIL_ADDRESS,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CONFIRMING_ORDER_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(NOTE_TO_VENDOR,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(NOTE_TO_RECEIVER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DEFAULT_TAXATION_COUNTRY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TAX_DOCUMENT_SUBTYPE,''), '"', '""') || '"' || ','
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
                || '"' || REPLACE(NVL(ATTRIBUTE16,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE17,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE18,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE19,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE20,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE1, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE2, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE3, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE4, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE5, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE6, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE7, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE8, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE9, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE10, 'YYYY/MM/DD'), '') || '"' || ','
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
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP1, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP2, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP3, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP4, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP5, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP6, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP7, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP8, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP9, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP10, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(AGENT_EMAIL_ADDRESS,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(MODE_OF_TRANSPORT,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SERVICE_LEVEL,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(FIRST_PTY_REG_NUM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(THIRD_PTY_REG_NUM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(BUYER_MANAGED_TRANSPORT_FLAG,''), '"', '""') || '"' || CHR(10) AS csv_line
            FROM   DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id
            AND    t.TFM_STATUS = 'STAGED'
            AND    (p_prc_bu_name IS NULL OR t.PRC_BU_NAME = p_prc_bu_name)
            ORDER BY t.TFM_SEQUENCE_ID
        ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;

        RETURN l_csv;
    END gen_headers_csv;

    -- --------------------------------------------------------
    -- Private: generate PoLinesInterfaceOrder.csv CLOB
    -- When p_prc_bu_name is non-NULL, only includes lines whose
    -- parent header belongs to that BU.
    -- --------------------------------------------------------
    FUNCTION gen_lines_csv (
        p_run_id IN NUMBER,
        p_prc_bu_name    IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB
    IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        FOR r IN (
            SELECT
                '"' || REPLACE(NVL(INTERFACE_LINE_KEY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_HEADER_KEY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ACTION,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(LINE_NUM), '') || '"' || ','
                || '"' || REPLACE(NVL(LINE_TYPE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ITEM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ITEM_DESCRIPTION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ITEM_REVISION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CATEGORY,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(AMOUNT), '') || '"' || ','
                || '"' || NVL(TO_CHAR(QUANTITY), '') || '"' || ','
                || '"' || REPLACE(NVL(UNIT_OF_MEASURE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(UNIT_PRICE), '') || '"' || ','
                || '"' || NVL(TO_CHAR(SECONDARY_QUANTITY), '') || '"' || ','
                || '"' || REPLACE(NVL(SECONDARY_UNIT_OF_MEASURE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(VENDOR_PRODUCT_NUM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(NEGOTIATED_BY_PREPARER_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(HAZARD_CLASS,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(UN_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(NOTE_TO_VENDOR,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(NOTE_TO_RECEIVER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LINE_ATTRIBUTE_CATEGORY_LINES,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LINE_ATTRIBUTE1,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LINE_ATTRIBUTE2,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LINE_ATTRIBUTE3,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LINE_ATTRIBUTE4,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LINE_ATTRIBUTE5,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LINE_ATTRIBUTE6,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LINE_ATTRIBUTE7,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LINE_ATTRIBUTE8,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LINE_ATTRIBUTE9,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LINE_ATTRIBUTE10,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LINE_ATTRIBUTE11,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LINE_ATTRIBUTE12,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LINE_ATTRIBUTE13,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LINE_ATTRIBUTE14,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LINE_ATTRIBUTE15,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE16,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE17,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE18,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE19,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE20,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE1, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE2, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE3, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE4, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE5, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE6, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE7, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE8, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE9, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE10, 'YYYY/MM/DD'), '') || '"' || ','
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
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP1, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP2, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP3, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP4, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP5, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP6, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP7, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP8, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP9, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP10, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(UNIT_WEIGHT), '') || '"' || ','
                || '"' || REPLACE(NVL(WEIGHT_UOM_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(WEIGHT_UNIT_OF_MEASURE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(UNIT_VOLUME), '') || '"' || ','
                || '"' || REPLACE(NVL(VOLUME_UOM_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(VOLUME_UNIT_OF_MEASURE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TEMPLATE_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ITEM_ATTRIBUTE_CATEGORY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ITEM_ATTRIBUTE1,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ITEM_ATTRIBUTE2,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ITEM_ATTRIBUTE3,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ITEM_ATTRIBUTE4,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ITEM_ATTRIBUTE5,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ITEM_ATTRIBUTE6,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ITEM_ATTRIBUTE7,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ITEM_ATTRIBUTE8,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ITEM_ATTRIBUTE9,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ITEM_ATTRIBUTE10,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ITEM_ATTRIBUTE11,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ITEM_ATTRIBUTE12,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ITEM_ATTRIBUTE13,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ITEM_ATTRIBUTE14,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ITEM_ATTRIBUTE15,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SOURCE_AGREEMENT_PRC_BU_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SOURCE_AGREEMENT,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(SOURCE_AGREEMENT_LINE), '') || '"' || CHR(10) AS csv_line
            FROM   DMT_OWNER.DMT_PO_LINES_INT_TFM_TBL l
            WHERE  l.RUN_ID = p_run_id
            AND    l.TFM_STATUS = 'STAGED'
            AND    (p_prc_bu_name IS NULL OR l.INTERFACE_HEADER_KEY IN (
            SELECT h.INTERFACE_HEADER_KEY
            FROM   DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL h
            WHERE  h.RUN_ID = p_run_id
            AND    h.TFM_STATUS IN ('STAGED','GENERATED')
            AND    h.PRC_BU_NAME = p_prc_bu_name))
            ORDER BY l.TFM_SEQUENCE_ID
        ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;

        RETURN l_csv;
    END gen_lines_csv;

    -- --------------------------------------------------------
    -- Private: generate PoLineLocationsInterfaceOrder.csv CLOB
    -- When p_prc_bu_name is non-NULL, filters via line -> header chain.
    -- --------------------------------------------------------
    FUNCTION gen_line_locs_csv (
        p_run_id IN NUMBER,
        p_prc_bu_name    IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB
    IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        FOR r IN (
            SELECT
                '"' || REPLACE(NVL(INTERFACE_LINE_LOCATION_KEY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_KEY,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(SHIPMENT_NUM), '') || '"' || ','
                || '"' || REPLACE(NVL(SHIP_TO_LOCATION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SHIP_TO_ORGANIZATION_CODE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(AMOUNT), '') || '"' || ','
                || '"' || NVL(TO_CHAR(QUANTITY), '') || '"' || ','
                || '"' || NVL(TO_CHAR(NEED_BY_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(PROMISED_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(SECONDARY_QUANTITY), '') || '"' || ','
                || '"' || REPLACE(NVL(SECONDARY_UNIT_OF_MEASURE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DESTINATION_TYPE_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ACCRUE_ON_RECEIPT_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ALLOW_SUBSTITUTE_RECEIPTS_FLAG,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(ASSESSABLE_VALUE), '') || '"' || ','
                || '"' || NVL(TO_CHAR(DAYS_EARLY_RECEIPT_ALLOWED), '') || '"' || ','
                || '"' || NVL(TO_CHAR(DAYS_LATE_RECEIPT_ALLOWED), '') || '"' || ','
                || '"' || REPLACE(NVL(ENFORCE_SHIP_TO_LOCATION_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INSPECTION_REQUIRED_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(RECEIPT_REQUIRED_FLAG,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(INVOICE_CLOSE_TOLERANCE), '') || '"' || ','
                || '"' || NVL(TO_CHAR(RECEIVE_CLOSE_TOLERANCE), '') || '"' || ','
                || '"' || NVL(TO_CHAR(QTY_RCV_TOLERANCE), '') || '"' || ','
                || '"' || REPLACE(NVL(QTY_RCV_EXCEPTION_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(RECEIPT_DAYS_EXCEPTION_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(RECEIVING_ROUTING,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(NOTE_TO_RECEIVER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INPUT_TAX_CLASSIFICATION_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LINE_INTENDED_USE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PRODUCT_CATEGORY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PRODUCT_FISC_CLASSIFICATION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PRODUCT_TYPE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TRX_BUSINESS_CATEGORY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(USER_DEFINED_FISC_CLASS,''), '"', '""') || '"' || ','
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
                || '"' || REPLACE(NVL(ATTRIBUTE16,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE17,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE18,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE19,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE20,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE1, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE2, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE3, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE4, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE5, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE6, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE7, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE8, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE9, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE10, 'YYYY/MM/DD'), '') || '"' || ','
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
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP1, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP2, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP3, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP4, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP5, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP6, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP7, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP8, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP9, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP10, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(FREIGHT_CARRIER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(MODE_OF_TRANSPORT,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SERVICE_LEVEL,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(FINAL_DISCHARGE_LOCATION_CODE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(REQUESTED_SHIP_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(PROMISED_SHIP_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(REQUESTED_DELIVERY_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(PROMISED_DELIVERY_DATE, 'YYYY/MM/DD'), '') || '"' || CHR(10) AS csv_line
            FROM   DMT_OWNER.DMT_PO_LINE_LOCS_INT_TFM_TBL ll
            WHERE  ll.RUN_ID = p_run_id
            AND    ll.TFM_STATUS = 'STAGED'
            AND    (p_prc_bu_name IS NULL OR ll.INTERFACE_LINE_KEY IN (
            SELECT l.INTERFACE_LINE_KEY
            FROM   DMT_OWNER.DMT_PO_LINES_INT_TFM_TBL l
            WHERE  l.RUN_ID = p_run_id
            AND    l.TFM_STATUS IN ('STAGED','GENERATED')
            AND    l.INTERFACE_HEADER_KEY IN (
            SELECT h.INTERFACE_HEADER_KEY
            FROM   DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL h
            WHERE  h.RUN_ID = p_run_id
            AND    h.TFM_STATUS IN ('STAGED','GENERATED')
            AND    h.PRC_BU_NAME = p_prc_bu_name)))
            ORDER BY ll.TFM_SEQUENCE_ID
        ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;

        RETURN l_csv;
    END gen_line_locs_csv;

    -- --------------------------------------------------------
    -- Private: generate PoDistributionsInterfaceOrder.csv CLOB
    -- When p_prc_bu_name is non-NULL, filters via loc -> line -> header chain.
    -- --------------------------------------------------------
    FUNCTION gen_dists_csv (
        p_run_id IN NUMBER,
        p_prc_bu_name    IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB
    IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        FOR r IN (
            SELECT
                '"' || REPLACE(NVL(INTERFACE_DISTRIBUTION_KEY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERFACE_LINE_LOCATION_KEY,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(DISTRIBUTION_NUM), '') || '"' || ','
                || '"' || REPLACE(NVL(DELIVER_TO_LOCATION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DELIVER_TO_PERSON_FULL_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DESTINATION_SUBINVENTORY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(AMOUNT_ORDERED,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(QUANTITY_ORDERED), '') || '"' || ','
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
                || '"' || REPLACE(NVL(DESTINATION_CONTEXT,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PROJECT,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TASK,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(PJC_EXPENDITURE_ITEM_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(EXPENDITURE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(EXPENDITURE_ORGANIZATION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_BILLABLE_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_CAPITALIZABLE_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_WORK_TYPE,''), '"', '""') || '"' || ','
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
                || '"' || NVL(TO_CHAR(RATE), '') || '"' || ','
                || '"' || NVL(TO_CHAR(RATE_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_CATEGORY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE1,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE2,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE3,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE4,''), '"', '""') || '"' || ','
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
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE1, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE2, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE3, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE4, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE5, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE6, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE7, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE8, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE9, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE10, 'YYYY/MM/DD'), '') || '"' || ','
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
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP1, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP2, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP3, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP4, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP5, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP6, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP7, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP8, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP9, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP10, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(DELIVER_TO_PERSON_EMAIL_ADDR,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(BUDGET_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(PJC_CONTRACT_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PJC_FUNDING_SOURCE,''), '"', '""') || '"' || CHR(10) AS csv_line
            FROM   DMT_OWNER.DMT_PO_DISTS_INT_TFM_TBL d
            WHERE  d.RUN_ID = p_run_id
            AND    d.TFM_STATUS = 'STAGED'
            AND    (p_prc_bu_name IS NULL OR d.INTERFACE_LINE_LOCATION_KEY IN (
            SELECT ll.INTERFACE_LINE_LOCATION_KEY
            FROM   DMT_OWNER.DMT_PO_LINE_LOCS_INT_TFM_TBL ll
            WHERE  ll.RUN_ID = p_run_id
            AND    ll.TFM_STATUS IN ('STAGED','GENERATED')
            AND    ll.INTERFACE_LINE_KEY IN (
            SELECT l.INTERFACE_LINE_KEY
            FROM   DMT_OWNER.DMT_PO_LINES_INT_TFM_TBL l
            WHERE  l.RUN_ID = p_run_id
            AND    l.TFM_STATUS IN ('STAGED','GENERATED')
            AND    l.INTERFACE_HEADER_KEY IN (
            SELECT h.INTERFACE_HEADER_KEY
            FROM   DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL h
            WHERE  h.RUN_ID = p_run_id
            AND    h.TFM_STATUS IN ('STAGED','GENERATED')
            AND    h.PRC_BU_NAME = p_prc_bu_name))))
            ORDER BY d.TFM_SEQUENCE_ID
        ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;

        RETURN l_csv;
    END gen_dists_csv;

    -- --------------------------------------------------------
    -- Public: GENERATE_FBDI
    -- Builds 4 CSVs, zips them, persists to traceability tables,
    -- marks TFM rows as GENERATED.
    -- When p_prc_bu_name is non-NULL, only includes rows for that BU.
    -- --------------------------------------------------------
    PROCEDURE GENERATE_FBDI (
        p_run_id IN  NUMBER,
        p_prc_bu_name    IN  VARCHAR2 DEFAULT NULL,
        x_fbdi_zip       OUT BLOB,
        x_filename       OUT VARCHAR2,
        x_fbdi_csv_id    OUT NUMBER
    )
    IS
        l_zip         BLOB;
        l_hdr_csv     CLOB;
        l_lines_csv   CLOB;
        l_locs_csv    CLOB;
        l_dists_csv   CLOB;
        l_fbdi_csv_id NUMBER;
        l_bu_suffix   VARCHAR2(50);
        l_now         DATE := SYSDATE;
        C_PROC CONSTANT VARCHAR2(30) := 'GENERATE_FBDI';
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Purchase Order FBDI generation start.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        -- Filename: {Object}_{GroupValue}_{IntegrationID}.zip
        -- GroupValue is the distinct key (e.g. BU name with spaces removed).
        IF p_prc_bu_name IS NOT NULL THEN
            l_bu_suffix := '_' || REPLACE(SUBSTR(p_prc_bu_name, 1, 30), ' ', '');
        END IF;
        x_filename := 'PO' || l_bu_suffix || '_' || TO_CHAR(p_run_id) || '.zip';

        -- Generate all 4 CSVs (filtered by BU when provided)
        l_hdr_csv   := gen_headers_csv(p_run_id, p_prc_bu_name);
        l_lines_csv := gen_lines_csv(p_run_id, p_prc_bu_name);
        l_locs_csv  := gen_line_locs_csv(p_run_id, p_prc_bu_name);
        l_dists_csv := gen_dists_csv(p_run_id, p_prc_bu_name);

        -- AD#20: Skip gracefully if no rows generated
        IF (l_hdr_csv IS NULL OR DBMS_LOB.GETLENGTH(l_hdr_csv) = 0) THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'No STAGED PO rows found. Skipping FBDI generation.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            DBMS_LOB.FREETEMPORARY(l_hdr_csv);
            DBMS_LOB.FREETEMPORARY(l_lines_csv);
            DBMS_LOB.FREETEMPORARY(l_locs_csv);
            DBMS_LOB.FREETEMPORARY(l_dists_csv);
            x_fbdi_zip := NULL;
            x_filename := NULL;
            x_fbdi_csv_id := NULL;
            RETURN;
        END IF;

        -- Build zip using Anton Scheffer UTL_ZIP
        DBMS_LOB.CREATETEMPORARY(l_zip, TRUE);
        DMT_OWNER.UTL_ZIP.add1file(l_zip, 'PoHeadersInterfaceOrder.csv',
            clob_to_blob(l_hdr_csv));
        DMT_OWNER.UTL_ZIP.add1file(l_zip, 'PoLinesInterfaceOrder.csv',
            clob_to_blob(l_lines_csv));
        DMT_OWNER.UTL_ZIP.add1file(l_zip, 'PoLineLocationsInterfaceOrder.csv',
            clob_to_blob(l_locs_csv));
        DMT_OWNER.UTL_ZIP.add1file(l_zip, 'PoDistributionsInterfaceOrder.csv',
            clob_to_blob(l_dists_csv));
        DMT_OWNER.UTL_ZIP.finish_zip(l_zip);

        -- Register in DMT_FBDI_CSV_TBL
        SELECT DMT_OWNER.DMT_FBDI_CSV_ID_SEQ.NEXTVAL INTO l_fbdi_csv_id FROM DUAL;
        INSERT INTO DMT_OWNER.DMT_FBDI_CSV_TBL (
            FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME, ROW_COUNT,
            CSV_CONTENT, CREATED_DATE
        ) VALUES (
            l_fbdi_csv_id, p_run_id,
            'PurchaseOrders',
            x_filename, 0, l_hdr_csv, l_now
        );

        -- Register in DMT_FBDI_ZIP_TBL
        INSERT INTO DMT_OWNER.DMT_FBDI_ZIP_TBL (
            FBDI_ZIP_ID, FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME,
            ZIP_SIZE_BYTES, ZIP_CONTENT, CREATED_DATE
        ) VALUES (
            DMT_OWNER.DMT_FBDI_ZIP_ID_SEQ.NEXTVAL, l_fbdi_csv_id, p_run_id,
            'PurchaseOrders',
            x_filename,
            DBMS_LOB.GETLENGTH(l_zip), l_zip, l_now
        );

        -- Update TFM rows to GENERATED and stamp FBDI_CSV_ID.
        -- Headers: filter directly by PRC_BU_NAME.
        UPDATE DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_fbdi_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED'
        AND    (p_prc_bu_name IS NULL OR PRC_BU_NAME = p_prc_bu_name);

        -- Lines: filter via header chain.
        UPDATE DMT_OWNER.DMT_PO_LINES_INT_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_fbdi_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED'
        AND    (p_prc_bu_name IS NULL OR INTERFACE_HEADER_KEY IN (
            SELECT h.INTERFACE_HEADER_KEY
            FROM   DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL h
            WHERE  h.RUN_ID = p_run_id
            AND    h.FBDI_CSV_ID = l_fbdi_csv_id));

        -- Line locations: filter via line -> header chain.
        UPDATE DMT_OWNER.DMT_PO_LINE_LOCS_INT_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_fbdi_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED'
        AND    (p_prc_bu_name IS NULL OR INTERFACE_LINE_KEY IN (
            SELECT l.INTERFACE_LINE_KEY
            FROM   DMT_OWNER.DMT_PO_LINES_INT_TFM_TBL l
            WHERE  l.RUN_ID = p_run_id
            AND    l.FBDI_CSV_ID = l_fbdi_csv_id));

        -- Distributions: filter via loc -> line -> header chain.
        UPDATE DMT_OWNER.DMT_PO_DISTS_INT_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_fbdi_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED'
        AND    (p_prc_bu_name IS NULL OR INTERFACE_LINE_LOCATION_KEY IN (
            SELECT ll.INTERFACE_LINE_LOCATION_KEY
            FROM   DMT_OWNER.DMT_PO_LINE_LOCS_INT_TFM_TBL ll
            WHERE  ll.RUN_ID = p_run_id
            AND    ll.FBDI_CSV_ID = l_fbdi_csv_id));

        -- Free temporary CLOBs (accumulate across multi-BU loop if not freed)
        DBMS_LOB.FREETEMPORARY(l_hdr_csv);
        DBMS_LOB.FREETEMPORARY(l_lines_csv);
        DBMS_LOB.FREETEMPORARY(l_locs_csv);
        DBMS_LOB.FREETEMPORARY(l_dists_csv);

        x_fbdi_zip   := l_zip;
        x_fbdi_csv_id := l_fbdi_csv_id;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Purchase Order FBDI generation complete.' ||
                                ' | File: ' || x_filename ||
                                ' | Zip bytes: ' || DBMS_LOB.GETLENGTH(x_fbdi_zip),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'Purchase Order FBDI generation failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END GENERATE_FBDI;

END DMT_PO_FBDI_GEN_PKG;
/
