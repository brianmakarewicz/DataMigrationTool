-- PACKAGE BODY DMT_PO_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_PO_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_PO_TRANSFORM_PKG Body
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_PO_TRANSFORM_PKG';

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
    -- TRANSFORM_HEADERS
    -- ============================================================
    PROCEDURE TRANSFORM_HEADERS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_doc_type_filter  IN VARCHAR2 DEFAULT NULL,
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
            p_message        => 'TRANSFORM_HEADERS start. doc_type_filter=' || NVL(p_doc_type_filter, '(none)'),
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_HEADERS');

        l_prefix     := get_prefix(p_run_id);
        l_dep_prefix := get_dep_prefix(p_run_id);


        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_OWNER.DMT_PO_HEADERS_INT_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    FBDI_CSV_ID,
                    INTERFACE_HEADER_KEY,
                    ACTION,
                    BATCH_ID,
                    INTERFACE_SOURCE_CODE,
                    APPROVAL_ACTION,
                    DOCUMENT_NUM,
                    DOCUMENT_TYPE_CODE,
                    STYLE_DISPLAY_NAME,
                    PRC_BU_NAME,
                    REQ_BU_NAME,
                    SOLDTO_LE_NAME,
                    BILLTO_BU_NAME,
                    AGENT_NAME,
                    CURRENCY_CODE,
                    RATE,
                    RATE_TYPE,
                    RATE_DATE,
                    COMMENTS,
                    BILL_TO_LOCATION,
                    SHIP_TO_LOCATION,
                    VENDOR_NAME,
                    VENDOR_NUM,
                    VENDOR_SITE_CODE,
                    VENDOR_CONTACT,
                    VENDOR_DOC_NUM,
                    FOB,
                    FREIGHT_CARRIER,
                    FREIGHT_TERMS,
                    PAY_ON_CODE,
                    PAYMENT_TERMS,
                    ORIGINATOR_ROLE,
                    CHANGE_ORDER_DESC,
                    ACCEPTANCE_REQUIRED_FLAG,
                    ACCEPTANCE_WITHIN_DAYS,
                    SUPPLIER_NOTIF_METHOD,
                    FAX,
                    EMAIL_ADDRESS,
                    CONFIRMING_ORDER_FLAG,
                    NOTE_TO_VENDOR,
                    NOTE_TO_RECEIVER,
                    DEFAULT_TAXATION_COUNTRY,
                    TAX_DOCUMENT_SUBTYPE,
                    ATTRIBUTE_CATEGORY,
                    ATTRIBUTE1,  ATTRIBUTE2,  ATTRIBUTE3,  ATTRIBUTE4,  ATTRIBUTE5,
                    ATTRIBUTE6,  ATTRIBUTE7,  ATTRIBUTE8,  ATTRIBUTE9,  ATTRIBUTE10,
                    ATTRIBUTE11, ATTRIBUTE12, ATTRIBUTE13, ATTRIBUTE14, ATTRIBUTE15,
                    ATTRIBUTE16, ATTRIBUTE17, ATTRIBUTE18, ATTRIBUTE19, ATTRIBUTE20,
                    ATTRIBUTE_DATE1,  ATTRIBUTE_DATE2,  ATTRIBUTE_DATE3,  ATTRIBUTE_DATE4,  ATTRIBUTE_DATE5,
                    ATTRIBUTE_DATE6,  ATTRIBUTE_DATE7,  ATTRIBUTE_DATE8,  ATTRIBUTE_DATE9,  ATTRIBUTE_DATE10,
                    ATTRIBUTE_NUMBER1,  ATTRIBUTE_NUMBER2,  ATTRIBUTE_NUMBER3,  ATTRIBUTE_NUMBER4,  ATTRIBUTE_NUMBER5,
                    ATTRIBUTE_NUMBER6,  ATTRIBUTE_NUMBER7,  ATTRIBUTE_NUMBER8,  ATTRIBUTE_NUMBER9,  ATTRIBUTE_NUMBER10,
                    ATTRIBUTE_TIMESTAMP1,  ATTRIBUTE_TIMESTAMP2,  ATTRIBUTE_TIMESTAMP3,  ATTRIBUTE_TIMESTAMP4,  ATTRIBUTE_TIMESTAMP5,
                    ATTRIBUTE_TIMESTAMP6,  ATTRIBUTE_TIMESTAMP7,  ATTRIBUTE_TIMESTAMP8,  ATTRIBUTE_TIMESTAMP9,  ATTRIBUTE_TIMESTAMP10,
                    AGENT_EMAIL_ADDRESS,
                    MODE_OF_TRANSPORT,
                    SERVICE_LEVEL,
                    FIRST_PTY_REG_NUM,
                    THIRD_PTY_REG_NUM,
                    BUYER_MANAGED_TRANSPORT_FLAG,
                    STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    NULL,
                    TO_CHAR(p_run_id) || '_HDR_' || TO_CHAR(s.STG_SEQUENCE_ID),
                    s.ACTION,
                    TO_CHAR(p_run_id),  -- BATCH_ID = run_id (isolates our rows)
                    s.INTERFACE_SOURCE_CODE,
                    s.APPROVAL_ACTION,
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.DOCUMENT_NUM, 20),
                    s.DOCUMENT_TYPE_CODE,
                    s.STYLE_DISPLAY_NAME,
                    s.PRC_BU_NAME,
                    s.REQ_BU_NAME,
                    s.SOLDTO_LE_NAME,
                    s.BILLTO_BU_NAME,
                    s.AGENT_NAME,
                    s.CURRENCY_CODE,
                    s.RATE,
                    s.RATE_TYPE,
                    s.RATE_DATE,
                    s.COMMENTS,
                    s.BILL_TO_LOCATION,
                    s.SHIP_TO_LOCATION,
                    DMT_UTIL_PKG.PREFIXED(l_dep_prefix, s.VENDOR_NAME, 360),
                    DMT_UTIL_PKG.PREFIXED(l_dep_prefix, s.VENDOR_NUM, 30),
                    DMT_UTIL_PKG.PREFIXED(l_dep_prefix, s.VENDOR_SITE_CODE, 15),
                    s.VENDOR_CONTACT,
                    s.VENDOR_DOC_NUM,
                    s.FOB,
                    s.FREIGHT_CARRIER,
                    s.FREIGHT_TERMS,
                    s.PAY_ON_CODE,
                    s.PAYMENT_TERMS,
                    s.ORIGINATOR_ROLE,
                    s.CHANGE_ORDER_DESC,
                    s.ACCEPTANCE_REQUIRED_FLAG,
                    s.ACCEPTANCE_WITHIN_DAYS,
                    s.SUPPLIER_NOTIF_METHOD,
                    s.FAX,
                    s.EMAIL_ADDRESS,
                    s.CONFIRMING_ORDER_FLAG,
                    s.NOTE_TO_VENDOR,
                    s.NOTE_TO_RECEIVER,
                    s.DEFAULT_TAXATION_COUNTRY,
                    s.TAX_DOCUMENT_SUBTYPE,
                    s.ATTRIBUTE_CATEGORY,
                    s.ATTRIBUTE1,  s.ATTRIBUTE2,  s.ATTRIBUTE3,  s.ATTRIBUTE4,  s.ATTRIBUTE5,
                    s.ATTRIBUTE6,  s.ATTRIBUTE7,  s.ATTRIBUTE8,  s.ATTRIBUTE9,  s.ATTRIBUTE10,
                    s.ATTRIBUTE11, s.ATTRIBUTE12, s.ATTRIBUTE13, s.ATTRIBUTE14, s.ATTRIBUTE15,
                    s.ATTRIBUTE16, s.ATTRIBUTE17, s.ATTRIBUTE18, s.ATTRIBUTE19, s.ATTRIBUTE20,
                    s.ATTRIBUTE_DATE1,  s.ATTRIBUTE_DATE2,  s.ATTRIBUTE_DATE3,  s.ATTRIBUTE_DATE4,  s.ATTRIBUTE_DATE5,
                    s.ATTRIBUTE_DATE6,  s.ATTRIBUTE_DATE7,  s.ATTRIBUTE_DATE8,  s.ATTRIBUTE_DATE9,  s.ATTRIBUTE_DATE10,
                    s.ATTRIBUTE_NUMBER1,  s.ATTRIBUTE_NUMBER2,  s.ATTRIBUTE_NUMBER3,  s.ATTRIBUTE_NUMBER4,  s.ATTRIBUTE_NUMBER5,
                    s.ATTRIBUTE_NUMBER6,  s.ATTRIBUTE_NUMBER7,  s.ATTRIBUTE_NUMBER8,  s.ATTRIBUTE_NUMBER9,  s.ATTRIBUTE_NUMBER10,
                    s.ATTRIBUTE_TIMESTAMP1,  s.ATTRIBUTE_TIMESTAMP2,  s.ATTRIBUTE_TIMESTAMP3,  s.ATTRIBUTE_TIMESTAMP4,  s.ATTRIBUTE_TIMESTAMP5,
                    s.ATTRIBUTE_TIMESTAMP6,  s.ATTRIBUTE_TIMESTAMP7,  s.ATTRIBUTE_TIMESTAMP8,  s.ATTRIBUTE_TIMESTAMP9,  s.ATTRIBUTE_TIMESTAMP10,
                    s.AGENT_EMAIL_ADDRESS,
                    s.MODE_OF_TRANSPORT,
                    s.SERVICE_LEVEL,
                    s.FIRST_PTY_REG_NUM,
                    s.THIRD_PTY_REG_NUM,
                    s.BUYER_MANAGED_TRANSPORT_FLAG,
                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_PO_HEADERS_INT_STG_TBL s
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
            SELECT 1 FROM DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        AND (p_doc_type_filter IS NULL OR s.STYLE_DISPLAY_NAME = p_doc_type_filter)
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_OWNER.DMT_PO_HEADERS_INT_STG_TBL s
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
            SELECT 1 FROM DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_HEADERS complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_HEADERS');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_HEADERS failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_HEADERS',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_HEADERS;


    -- ============================================================
    -- TRANSFORM_LINES
    -- ============================================================
    PROCEDURE TRANSFORM_LINES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_doc_type_filter  IN VARCHAR2 DEFAULT NULL,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_ok_count      NUMBER := 0;
        l_fail_count    NUMBER := 0;

    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_LINES start. doc_type_filter=' || NVL(p_doc_type_filter, '(none)'),
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_LINES');


        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_OWNER.DMT_PO_LINES_INT_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_OWNER.DMT_PO_LINES_INT_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    FBDI_CSV_ID,
                    INTERFACE_LINE_KEY,
                    INTERFACE_HEADER_KEY,
                    ACTION,
                    LINE_NUM,
                    LINE_TYPE,
                    ITEM,
                    ITEM_DESCRIPTION,
                    ITEM_REVISION,
                    CATEGORY,
                    AMOUNT,
                    QUANTITY,
                    UNIT_OF_MEASURE,
                    UNIT_PRICE,
                    SECONDARY_QUANTITY,
                    SECONDARY_UNIT_OF_MEASURE,
                    VENDOR_PRODUCT_NUM,
                    NEGOTIATED_BY_PREPARER_FLAG,
                    HAZARD_CLASS,
                    UN_NUMBER,
                    NOTE_TO_VENDOR,
                    NOTE_TO_RECEIVER,
                    LINE_ATTRIBUTE_CATEGORY_LINES,
                    LINE_ATTRIBUTE1,  LINE_ATTRIBUTE2,  LINE_ATTRIBUTE3,  LINE_ATTRIBUTE4,  LINE_ATTRIBUTE5,
                    LINE_ATTRIBUTE6,  LINE_ATTRIBUTE7,  LINE_ATTRIBUTE8,  LINE_ATTRIBUTE9,  LINE_ATTRIBUTE10,
                    LINE_ATTRIBUTE11, LINE_ATTRIBUTE12, LINE_ATTRIBUTE13, LINE_ATTRIBUTE14, LINE_ATTRIBUTE15,
                    ATTRIBUTE16, ATTRIBUTE17, ATTRIBUTE18, ATTRIBUTE19, ATTRIBUTE20,
                    ATTRIBUTE_DATE1,  ATTRIBUTE_DATE2,  ATTRIBUTE_DATE3,  ATTRIBUTE_DATE4,  ATTRIBUTE_DATE5,
                    ATTRIBUTE_DATE6,  ATTRIBUTE_DATE7,  ATTRIBUTE_DATE8,  ATTRIBUTE_DATE9,  ATTRIBUTE_DATE10,
                    ATTRIBUTE_NUMBER1,  ATTRIBUTE_NUMBER2,  ATTRIBUTE_NUMBER3,  ATTRIBUTE_NUMBER4,  ATTRIBUTE_NUMBER5,
                    ATTRIBUTE_NUMBER6,  ATTRIBUTE_NUMBER7,  ATTRIBUTE_NUMBER8,  ATTRIBUTE_NUMBER9,  ATTRIBUTE_NUMBER10,
                    ATTRIBUTE_TIMESTAMP1,  ATTRIBUTE_TIMESTAMP2,  ATTRIBUTE_TIMESTAMP3,  ATTRIBUTE_TIMESTAMP4,  ATTRIBUTE_TIMESTAMP5,
                    ATTRIBUTE_TIMESTAMP6,  ATTRIBUTE_TIMESTAMP7,  ATTRIBUTE_TIMESTAMP8,  ATTRIBUTE_TIMESTAMP9,  ATTRIBUTE_TIMESTAMP10,
                    UNIT_WEIGHT,
                    WEIGHT_UOM_CODE,
                    WEIGHT_UNIT_OF_MEASURE,
                    UNIT_VOLUME,
                    VOLUME_UOM_CODE,
                    VOLUME_UNIT_OF_MEASURE,
                    TEMPLATE_NAME,
                    ITEM_ATTRIBUTE_CATEGORY,
                    ITEM_ATTRIBUTE1,  ITEM_ATTRIBUTE2,  ITEM_ATTRIBUTE3,  ITEM_ATTRIBUTE4,  ITEM_ATTRIBUTE5,
                    ITEM_ATTRIBUTE6,  ITEM_ATTRIBUTE7,  ITEM_ATTRIBUTE8,  ITEM_ATTRIBUTE9,  ITEM_ATTRIBUTE10,
                    ITEM_ATTRIBUTE11, ITEM_ATTRIBUTE12, ITEM_ATTRIBUTE13, ITEM_ATTRIBUTE14, ITEM_ATTRIBUTE15,
                    SOURCE_AGREEMENT_PRC_BU_NAME,
                    SOURCE_AGREEMENT,
                    SOURCE_AGREEMENT_LINE,
                    STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    NULL,
                    TO_CHAR(p_run_id) || '_LN_' || TO_CHAR(s.STG_SEQUENCE_ID),
                    (SELECT ht.INTERFACE_HEADER_KEY
                     FROM   DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL ht
                     JOIN   DMT_OWNER.DMT_PO_HEADERS_INT_STG_TBL hs
                       ON   hs.STG_SEQUENCE_ID = ht.STG_SEQUENCE_ID
                     WHERE  ht.RUN_ID = p_run_id
                     AND    hs.INTERFACE_HEADER_KEY = s.INTERFACE_HEADER_KEY
                     AND    ROWNUM = 1),
                    s.ACTION,
                    s.LINE_NUM,
                    s.LINE_TYPE,
                    s.ITEM,
                    s.ITEM_DESCRIPTION,
                    s.ITEM_REVISION,
                    s.CATEGORY,
                    s.AMOUNT,
                    s.QUANTITY,
                    s.UNIT_OF_MEASURE,
                    s.UNIT_PRICE,
                    s.SECONDARY_QUANTITY,
                    s.SECONDARY_UNIT_OF_MEASURE,
                    s.VENDOR_PRODUCT_NUM,
                    s.NEGOTIATED_BY_PREPARER_FLAG,
                    s.HAZARD_CLASS,
                    s.UN_NUMBER,
                    s.NOTE_TO_VENDOR,
                    s.NOTE_TO_RECEIVER,
                    s.LINE_ATTRIBUTE_CATEGORY_LINES,
                    s.LINE_ATTRIBUTE1,  s.LINE_ATTRIBUTE2,  s.LINE_ATTRIBUTE3,  s.LINE_ATTRIBUTE4,  s.LINE_ATTRIBUTE5,
                    s.LINE_ATTRIBUTE6,  s.LINE_ATTRIBUTE7,  s.LINE_ATTRIBUTE8,  s.LINE_ATTRIBUTE9,  s.LINE_ATTRIBUTE10,
                    s.LINE_ATTRIBUTE11, s.LINE_ATTRIBUTE12, s.LINE_ATTRIBUTE13, s.LINE_ATTRIBUTE14, s.LINE_ATTRIBUTE15,
                    s.ATTRIBUTE16, s.ATTRIBUTE17, s.ATTRIBUTE18, s.ATTRIBUTE19, s.ATTRIBUTE20,
                    s.ATTRIBUTE_DATE1,  s.ATTRIBUTE_DATE2,  s.ATTRIBUTE_DATE3,  s.ATTRIBUTE_DATE4,  s.ATTRIBUTE_DATE5,
                    s.ATTRIBUTE_DATE6,  s.ATTRIBUTE_DATE7,  s.ATTRIBUTE_DATE8,  s.ATTRIBUTE_DATE9,  s.ATTRIBUTE_DATE10,
                    s.ATTRIBUTE_NUMBER1,  s.ATTRIBUTE_NUMBER2,  s.ATTRIBUTE_NUMBER3,  s.ATTRIBUTE_NUMBER4,  s.ATTRIBUTE_NUMBER5,
                    s.ATTRIBUTE_NUMBER6,  s.ATTRIBUTE_NUMBER7,  s.ATTRIBUTE_NUMBER8,  s.ATTRIBUTE_NUMBER9,  s.ATTRIBUTE_NUMBER10,
                    s.ATTRIBUTE_TIMESTAMP1,  s.ATTRIBUTE_TIMESTAMP2,  s.ATTRIBUTE_TIMESTAMP3,  s.ATTRIBUTE_TIMESTAMP4,  s.ATTRIBUTE_TIMESTAMP5,
                    s.ATTRIBUTE_TIMESTAMP6,  s.ATTRIBUTE_TIMESTAMP7,  s.ATTRIBUTE_TIMESTAMP8,  s.ATTRIBUTE_TIMESTAMP9,  s.ATTRIBUTE_TIMESTAMP10,
                    s.UNIT_WEIGHT,
                    s.WEIGHT_UOM_CODE,
                    s.WEIGHT_UNIT_OF_MEASURE,
                    s.UNIT_VOLUME,
                    s.VOLUME_UOM_CODE,
                    s.VOLUME_UNIT_OF_MEASURE,
                    s.TEMPLATE_NAME,
                    s.ITEM_ATTRIBUTE_CATEGORY,
                    s.ITEM_ATTRIBUTE1,  s.ITEM_ATTRIBUTE2,  s.ITEM_ATTRIBUTE3,  s.ITEM_ATTRIBUTE4,  s.ITEM_ATTRIBUTE5,
                    s.ITEM_ATTRIBUTE6,  s.ITEM_ATTRIBUTE7,  s.ITEM_ATTRIBUTE8,  s.ITEM_ATTRIBUTE9,  s.ITEM_ATTRIBUTE10,
                    s.ITEM_ATTRIBUTE11, s.ITEM_ATTRIBUTE12, s.ITEM_ATTRIBUTE13, s.ITEM_ATTRIBUTE14, s.ITEM_ATTRIBUTE15,
                    s.SOURCE_AGREEMENT_PRC_BU_NAME,
                    s.SOURCE_AGREEMENT,
                    s.SOURCE_AGREEMENT_LINE,
                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_PO_LINES_INT_STG_TBL s
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
            SELECT 1 FROM DMT_OWNER.DMT_PO_LINES_INT_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        AND (p_doc_type_filter IS NULL
             OR EXISTS (
                SELECT 1 FROM DMT_OWNER.DMT_PO_HEADERS_INT_STG_TBL h
                WHERE  h.INTERFACE_HEADER_KEY = s.INTERFACE_HEADER_KEY
                AND    h.STYLE_DISPLAY_NAME   = p_doc_type_filter
                AND    (p_scenario_id IS NULL
                        OR h.SCENARIO_ID = p_scenario_id
                        OR (p_include_untagged = 'Y' AND h.SCENARIO_ID IS NULL))
             ))
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_OWNER.DMT_PO_LINES_INT_STG_TBL s
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
            SELECT 1 FROM DMT_OWNER.DMT_PO_LINES_INT_TFM_TBL t
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
    -- TRANSFORM_LINE_LOCS
    -- ============================================================
    PROCEDURE TRANSFORM_LINE_LOCS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_doc_type_filter  IN VARCHAR2 DEFAULT NULL,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_ok_count      NUMBER := 0;
        l_fail_count    NUMBER := 0;

    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_LINE_LOCS start. doc_type_filter=' || NVL(p_doc_type_filter, '(none)'),
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_LINE_LOCS');


        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_OWNER.DMT_PO_LINE_LOCS_INT_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_OWNER.DMT_PO_LINE_LOCS_INT_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    FBDI_CSV_ID,
                    INTERFACE_LINE_LOCATION_KEY,
                    INTERFACE_LINE_KEY,
                    SHIPMENT_NUM,
                    SHIP_TO_LOCATION,
                    SHIP_TO_ORGANIZATION_CODE,
                    AMOUNT,
                    QUANTITY,
                    NEED_BY_DATE,
                    PROMISED_DATE,
                    SECONDARY_QUANTITY,
                    SECONDARY_UNIT_OF_MEASURE,
                    DESTINATION_TYPE_CODE,
                    ACCRUE_ON_RECEIPT_FLAG,
                    ALLOW_SUBSTITUTE_RECEIPTS_FLAG,
                    ASSESSABLE_VALUE,
                    DAYS_EARLY_RECEIPT_ALLOWED,
                    DAYS_LATE_RECEIPT_ALLOWED,
                    ENFORCE_SHIP_TO_LOCATION_CODE,
                    INSPECTION_REQUIRED_FLAG,
                    RECEIPT_REQUIRED_FLAG,
                    INVOICE_CLOSE_TOLERANCE,
                    RECEIVE_CLOSE_TOLERANCE,
                    QTY_RCV_TOLERANCE,
                    QTY_RCV_EXCEPTION_CODE,
                    RECEIPT_DAYS_EXCEPTION_CODE,
                    RECEIVING_ROUTING,
                    NOTE_TO_RECEIVER,
                    INPUT_TAX_CLASSIFICATION_CODE,
                    LINE_INTENDED_USE,
                    PRODUCT_CATEGORY,
                    PRODUCT_FISC_CLASSIFICATION,
                    PRODUCT_TYPE,
                    TRX_BUSINESS_CATEGORY,
                    USER_DEFINED_FISC_CLASS,
                    ATTRIBUTE_CATEGORY,
                    ATTRIBUTE1,  ATTRIBUTE2,  ATTRIBUTE3,  ATTRIBUTE4,  ATTRIBUTE5,
                    ATTRIBUTE6,  ATTRIBUTE7,  ATTRIBUTE8,  ATTRIBUTE9,  ATTRIBUTE10,
                    ATTRIBUTE11, ATTRIBUTE12, ATTRIBUTE13, ATTRIBUTE14, ATTRIBUTE15,
                    ATTRIBUTE16, ATTRIBUTE17, ATTRIBUTE18, ATTRIBUTE19, ATTRIBUTE20,
                    ATTRIBUTE_DATE1,  ATTRIBUTE_DATE2,  ATTRIBUTE_DATE3,  ATTRIBUTE_DATE4,  ATTRIBUTE_DATE5,
                    ATTRIBUTE_DATE6,  ATTRIBUTE_DATE7,  ATTRIBUTE_DATE8,  ATTRIBUTE_DATE9,  ATTRIBUTE_DATE10,
                    ATTRIBUTE_NUMBER1,  ATTRIBUTE_NUMBER2,  ATTRIBUTE_NUMBER3,  ATTRIBUTE_NUMBER4,  ATTRIBUTE_NUMBER5,
                    ATTRIBUTE_NUMBER6,  ATTRIBUTE_NUMBER7,  ATTRIBUTE_NUMBER8,  ATTRIBUTE_NUMBER9,  ATTRIBUTE_NUMBER10,
                    ATTRIBUTE_TIMESTAMP1,  ATTRIBUTE_TIMESTAMP2,  ATTRIBUTE_TIMESTAMP3,  ATTRIBUTE_TIMESTAMP4,  ATTRIBUTE_TIMESTAMP5,
                    ATTRIBUTE_TIMESTAMP6,  ATTRIBUTE_TIMESTAMP7,  ATTRIBUTE_TIMESTAMP8,  ATTRIBUTE_TIMESTAMP9,  ATTRIBUTE_TIMESTAMP10,
                    FREIGHT_CARRIER,
                    MODE_OF_TRANSPORT,
                    SERVICE_LEVEL,
                    FINAL_DISCHARGE_LOCATION_CODE,
                    REQUESTED_SHIP_DATE,
                    PROMISED_SHIP_DATE,
                    REQUESTED_DELIVERY_DATE,
                    PROMISED_DELIVERY_DATE,
                    STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    NULL,
                    TO_CHAR(p_run_id) || '_LOC_' || TO_CHAR(s.STG_SEQUENCE_ID),
                    (SELECT lt.INTERFACE_LINE_KEY
                     FROM   DMT_OWNER.DMT_PO_LINES_INT_TFM_TBL lt
                     JOIN   DMT_OWNER.DMT_PO_LINES_INT_STG_TBL ls
                       ON   ls.STG_SEQUENCE_ID = lt.STG_SEQUENCE_ID
                     WHERE  lt.RUN_ID = p_run_id
                     AND    ls.INTERFACE_LINE_KEY = s.INTERFACE_LINE_KEY
                     AND    ROWNUM = 1),
                    s.SHIPMENT_NUM,
                    s.SHIP_TO_LOCATION,
                    s.SHIP_TO_ORGANIZATION_CODE,
                    s.AMOUNT,
                    s.QUANTITY,
                    s.NEED_BY_DATE,
                    s.PROMISED_DATE,
                    s.SECONDARY_QUANTITY,
                    s.SECONDARY_UNIT_OF_MEASURE,
                    s.DESTINATION_TYPE_CODE,
                    s.ACCRUE_ON_RECEIPT_FLAG,
                    s.ALLOW_SUBSTITUTE_RECEIPTS_FLAG,
                    s.ASSESSABLE_VALUE,
                    s.DAYS_EARLY_RECEIPT_ALLOWED,
                    s.DAYS_LATE_RECEIPT_ALLOWED,
                    s.ENFORCE_SHIP_TO_LOCATION_CODE,
                    s.INSPECTION_REQUIRED_FLAG,
                    s.RECEIPT_REQUIRED_FLAG,
                    s.INVOICE_CLOSE_TOLERANCE,
                    s.RECEIVE_CLOSE_TOLERANCE,
                    s.QTY_RCV_TOLERANCE,
                    s.QTY_RCV_EXCEPTION_CODE,
                    s.RECEIPT_DAYS_EXCEPTION_CODE,
                    s.RECEIVING_ROUTING,
                    s.NOTE_TO_RECEIVER,
                    s.INPUT_TAX_CLASSIFICATION_CODE,
                    s.LINE_INTENDED_USE,
                    s.PRODUCT_CATEGORY,
                    s.PRODUCT_FISC_CLASSIFICATION,
                    s.PRODUCT_TYPE,
                    s.TRX_BUSINESS_CATEGORY,
                    s.USER_DEFINED_FISC_CLASS,
                    s.ATTRIBUTE_CATEGORY,
                    s.ATTRIBUTE1,  s.ATTRIBUTE2,  s.ATTRIBUTE3,  s.ATTRIBUTE4,  s.ATTRIBUTE5,
                    s.ATTRIBUTE6,  s.ATTRIBUTE7,  s.ATTRIBUTE8,  s.ATTRIBUTE9,  s.ATTRIBUTE10,
                    s.ATTRIBUTE11, s.ATTRIBUTE12, s.ATTRIBUTE13, s.ATTRIBUTE14, s.ATTRIBUTE15,
                    s.ATTRIBUTE16, s.ATTRIBUTE17, s.ATTRIBUTE18, s.ATTRIBUTE19, s.ATTRIBUTE20,
                    s.ATTRIBUTE_DATE1,  s.ATTRIBUTE_DATE2,  s.ATTRIBUTE_DATE3,  s.ATTRIBUTE_DATE4,  s.ATTRIBUTE_DATE5,
                    s.ATTRIBUTE_DATE6,  s.ATTRIBUTE_DATE7,  s.ATTRIBUTE_DATE8,  s.ATTRIBUTE_DATE9,  s.ATTRIBUTE_DATE10,
                    s.ATTRIBUTE_NUMBER1,  s.ATTRIBUTE_NUMBER2,  s.ATTRIBUTE_NUMBER3,  s.ATTRIBUTE_NUMBER4,  s.ATTRIBUTE_NUMBER5,
                    s.ATTRIBUTE_NUMBER6,  s.ATTRIBUTE_NUMBER7,  s.ATTRIBUTE_NUMBER8,  s.ATTRIBUTE_NUMBER9,  s.ATTRIBUTE_NUMBER10,
                    s.ATTRIBUTE_TIMESTAMP1,  s.ATTRIBUTE_TIMESTAMP2,  s.ATTRIBUTE_TIMESTAMP3,  s.ATTRIBUTE_TIMESTAMP4,  s.ATTRIBUTE_TIMESTAMP5,
                    s.ATTRIBUTE_TIMESTAMP6,  s.ATTRIBUTE_TIMESTAMP7,  s.ATTRIBUTE_TIMESTAMP8,  s.ATTRIBUTE_TIMESTAMP9,  s.ATTRIBUTE_TIMESTAMP10,
                    s.FREIGHT_CARRIER,
                    s.MODE_OF_TRANSPORT,
                    s.SERVICE_LEVEL,
                    s.FINAL_DISCHARGE_LOCATION_CODE,
                    s.REQUESTED_SHIP_DATE,
                    s.PROMISED_SHIP_DATE,
                    s.REQUESTED_DELIVERY_DATE,
                    s.PROMISED_DELIVERY_DATE,
                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_PO_LINE_LOCS_INT_STG_TBL s
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
            SELECT 1 FROM DMT_OWNER.DMT_PO_LINE_LOCS_INT_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_OWNER.DMT_PO_LINE_LOCS_INT_STG_TBL s
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
            SELECT 1 FROM DMT_OWNER.DMT_PO_LINE_LOCS_INT_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_LINE_LOCS complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_LINE_LOCS');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_LINE_LOCS failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_LINE_LOCS',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_LINE_LOCS;


    -- ============================================================
    -- TRANSFORM_DISTS
    -- ============================================================
    PROCEDURE TRANSFORM_DISTS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_doc_type_filter  IN VARCHAR2 DEFAULT NULL,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_ok_count      NUMBER := 0;
        l_fail_count    NUMBER := 0;

    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_DISTS start. doc_type_filter=' || NVL(p_doc_type_filter, '(none)'),
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_DISTS');


        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_OWNER.DMT_PO_DISTS_INT_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_OWNER.DMT_PO_DISTS_INT_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    FBDI_CSV_ID,
                    INTERFACE_DISTRIBUTION_KEY,
                    INTERFACE_LINE_LOCATION_KEY,
                    DISTRIBUTION_NUM,
                    DELIVER_TO_LOCATION,
                    DELIVER_TO_PERSON_FULL_NAME,
                    DESTINATION_SUBINVENTORY,
                    AMOUNT_ORDERED,
                    QUANTITY_ORDERED,
                    CHARGE_ACCOUNT_SEGMENT1,  CHARGE_ACCOUNT_SEGMENT2,  CHARGE_ACCOUNT_SEGMENT3,
                    CHARGE_ACCOUNT_SEGMENT4,  CHARGE_ACCOUNT_SEGMENT5,  CHARGE_ACCOUNT_SEGMENT6,
                    CHARGE_ACCOUNT_SEGMENT7,  CHARGE_ACCOUNT_SEGMENT8,  CHARGE_ACCOUNT_SEGMENT9,
                    CHARGE_ACCOUNT_SEGMENT10, CHARGE_ACCOUNT_SEGMENT11, CHARGE_ACCOUNT_SEGMENT12,
                    CHARGE_ACCOUNT_SEGMENT13, CHARGE_ACCOUNT_SEGMENT14, CHARGE_ACCOUNT_SEGMENT15,
                    CHARGE_ACCOUNT_SEGMENT16, CHARGE_ACCOUNT_SEGMENT17, CHARGE_ACCOUNT_SEGMENT18,
                    CHARGE_ACCOUNT_SEGMENT19, CHARGE_ACCOUNT_SEGMENT20, CHARGE_ACCOUNT_SEGMENT21,
                    CHARGE_ACCOUNT_SEGMENT22, CHARGE_ACCOUNT_SEGMENT23, CHARGE_ACCOUNT_SEGMENT24,
                    CHARGE_ACCOUNT_SEGMENT25, CHARGE_ACCOUNT_SEGMENT26, CHARGE_ACCOUNT_SEGMENT27,
                    CHARGE_ACCOUNT_SEGMENT28, CHARGE_ACCOUNT_SEGMENT29, CHARGE_ACCOUNT_SEGMENT30,
                    DESTINATION_CONTEXT,
                    PROJECT,
                    TASK,
                    PJC_EXPENDITURE_ITEM_DATE,
                    EXPENDITURE,
                    EXPENDITURE_ORGANIZATION,
                    PJC_BILLABLE_FLAG,
                    PJC_CAPITALIZABLE_FLAG,
                    PJC_WORK_TYPE,
                    PJC_RESERVED_ATTRIBUTE1,  PJC_RESERVED_ATTRIBUTE2,  PJC_RESERVED_ATTRIBUTE3,
                    PJC_RESERVED_ATTRIBUTE4,  PJC_RESERVED_ATTRIBUTE5,  PJC_RESERVED_ATTRIBUTE6,
                    PJC_RESERVED_ATTRIBUTE7,  PJC_RESERVED_ATTRIBUTE8,  PJC_RESERVED_ATTRIBUTE9,
                    PJC_RESERVED_ATTRIBUTE10,
                    PJC_USER_DEF_ATTRIBUTE1,  PJC_USER_DEF_ATTRIBUTE2,  PJC_USER_DEF_ATTRIBUTE3,
                    PJC_USER_DEF_ATTRIBUTE4,  PJC_USER_DEF_ATTRIBUTE5,  PJC_USER_DEF_ATTRIBUTE6,
                    PJC_USER_DEF_ATTRIBUTE7,  PJC_USER_DEF_ATTRIBUTE8,  PJC_USER_DEF_ATTRIBUTE9,
                    PJC_USER_DEF_ATTRIBUTE10,
                    RATE,
                    RATE_DATE,
                    ATTRIBUTE_CATEGORY,
                    ATTRIBUTE1,  ATTRIBUTE2,  ATTRIBUTE3,  ATTRIBUTE4,
                    -- Note: ATTRIBUTE5 absent per Fusion FBDI spec for distributions
                    ATTRIBUTE6,  ATTRIBUTE7,  ATTRIBUTE8,  ATTRIBUTE9,  ATTRIBUTE10,
                    ATTRIBUTE11, ATTRIBUTE12, ATTRIBUTE13, ATTRIBUTE14, ATTRIBUTE15,
                    ATTRIBUTE16, ATTRIBUTE17, ATTRIBUTE18, ATTRIBUTE19, ATTRIBUTE20,
                    ATTRIBUTE_DATE1,  ATTRIBUTE_DATE2,  ATTRIBUTE_DATE3,  ATTRIBUTE_DATE4,  ATTRIBUTE_DATE5,
                    ATTRIBUTE_DATE6,  ATTRIBUTE_DATE7,  ATTRIBUTE_DATE8,  ATTRIBUTE_DATE9,  ATTRIBUTE_DATE10,
                    ATTRIBUTE_NUMBER1,  ATTRIBUTE_NUMBER2,  ATTRIBUTE_NUMBER3,  ATTRIBUTE_NUMBER4,  ATTRIBUTE_NUMBER5,
                    ATTRIBUTE_NUMBER6,  ATTRIBUTE_NUMBER7,  ATTRIBUTE_NUMBER8,  ATTRIBUTE_NUMBER9,  ATTRIBUTE_NUMBER10,
                    ATTRIBUTE_TIMESTAMP1,  ATTRIBUTE_TIMESTAMP2,  ATTRIBUTE_TIMESTAMP3,  ATTRIBUTE_TIMESTAMP4,  ATTRIBUTE_TIMESTAMP5,
                    ATTRIBUTE_TIMESTAMP6,  ATTRIBUTE_TIMESTAMP7,  ATTRIBUTE_TIMESTAMP8,  ATTRIBUTE_TIMESTAMP9,  ATTRIBUTE_TIMESTAMP10,
                    DELIVER_TO_PERSON_EMAIL_ADDR,
                    BUDGET_DATE,
                    PJC_CONTRACT_NUMBER,
                    PJC_FUNDING_SOURCE,
                    STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    NULL,
                    TO_CHAR(p_run_id) || '_DIST_' || TO_CHAR(s.STG_SEQUENCE_ID),
                    (SELECT llt.INTERFACE_LINE_LOCATION_KEY
                     FROM   DMT_OWNER.DMT_PO_LINE_LOCS_INT_TFM_TBL llt
                     JOIN   DMT_OWNER.DMT_PO_LINE_LOCS_INT_STG_TBL lls
                       ON   lls.STG_SEQUENCE_ID = llt.STG_SEQUENCE_ID
                     WHERE  llt.RUN_ID = p_run_id
                     AND    lls.INTERFACE_LINE_LOCATION_KEY = s.INTERFACE_LINE_LOCATION_KEY
                     AND    ROWNUM = 1),
                    s.DISTRIBUTION_NUM,
                    s.DELIVER_TO_LOCATION,
                    s.DELIVER_TO_PERSON_FULL_NAME,
                    s.DESTINATION_SUBINVENTORY,
                    s.AMOUNT_ORDERED,
                    s.QUANTITY_ORDERED,
                    s.CHARGE_ACCOUNT_SEGMENT1,  s.CHARGE_ACCOUNT_SEGMENT2,  s.CHARGE_ACCOUNT_SEGMENT3,
                    s.CHARGE_ACCOUNT_SEGMENT4,  s.CHARGE_ACCOUNT_SEGMENT5,  s.CHARGE_ACCOUNT_SEGMENT6,
                    s.CHARGE_ACCOUNT_SEGMENT7,  s.CHARGE_ACCOUNT_SEGMENT8,  s.CHARGE_ACCOUNT_SEGMENT9,
                    s.CHARGE_ACCOUNT_SEGMENT10, s.CHARGE_ACCOUNT_SEGMENT11, s.CHARGE_ACCOUNT_SEGMENT12,
                    s.CHARGE_ACCOUNT_SEGMENT13, s.CHARGE_ACCOUNT_SEGMENT14, s.CHARGE_ACCOUNT_SEGMENT15,
                    s.CHARGE_ACCOUNT_SEGMENT16, s.CHARGE_ACCOUNT_SEGMENT17, s.CHARGE_ACCOUNT_SEGMENT18,
                    s.CHARGE_ACCOUNT_SEGMENT19, s.CHARGE_ACCOUNT_SEGMENT20, s.CHARGE_ACCOUNT_SEGMENT21,
                    s.CHARGE_ACCOUNT_SEGMENT22, s.CHARGE_ACCOUNT_SEGMENT23, s.CHARGE_ACCOUNT_SEGMENT24,
                    s.CHARGE_ACCOUNT_SEGMENT25, s.CHARGE_ACCOUNT_SEGMENT26, s.CHARGE_ACCOUNT_SEGMENT27,
                    s.CHARGE_ACCOUNT_SEGMENT28, s.CHARGE_ACCOUNT_SEGMENT29, s.CHARGE_ACCOUNT_SEGMENT30,
                    s.DESTINATION_CONTEXT,
                    s.PROJECT,
                    s.TASK,
                    s.PJC_EXPENDITURE_ITEM_DATE,
                    s.EXPENDITURE,
                    s.EXPENDITURE_ORGANIZATION,
                    s.PJC_BILLABLE_FLAG,
                    s.PJC_CAPITALIZABLE_FLAG,
                    s.PJC_WORK_TYPE,
                    s.PJC_RESERVED_ATTRIBUTE1,  s.PJC_RESERVED_ATTRIBUTE2,  s.PJC_RESERVED_ATTRIBUTE3,
                    s.PJC_RESERVED_ATTRIBUTE4,  s.PJC_RESERVED_ATTRIBUTE5,  s.PJC_RESERVED_ATTRIBUTE6,
                    s.PJC_RESERVED_ATTRIBUTE7,  s.PJC_RESERVED_ATTRIBUTE8,  s.PJC_RESERVED_ATTRIBUTE9,
                    s.PJC_RESERVED_ATTRIBUTE10,
                    s.PJC_USER_DEF_ATTRIBUTE1,  s.PJC_USER_DEF_ATTRIBUTE2,  s.PJC_USER_DEF_ATTRIBUTE3,
                    s.PJC_USER_DEF_ATTRIBUTE4,  s.PJC_USER_DEF_ATTRIBUTE5,  s.PJC_USER_DEF_ATTRIBUTE6,
                    s.PJC_USER_DEF_ATTRIBUTE7,  s.PJC_USER_DEF_ATTRIBUTE8,  s.PJC_USER_DEF_ATTRIBUTE9,
                    s.PJC_USER_DEF_ATTRIBUTE10,
                    s.RATE,
                    s.RATE_DATE,
                    s.ATTRIBUTE_CATEGORY,
                    s.ATTRIBUTE1,  s.ATTRIBUTE2,  s.ATTRIBUTE3,  s.ATTRIBUTE4,
                    s.ATTRIBUTE6,  s.ATTRIBUTE7,  s.ATTRIBUTE8,  s.ATTRIBUTE9,  s.ATTRIBUTE10,
                    s.ATTRIBUTE11, s.ATTRIBUTE12, s.ATTRIBUTE13, s.ATTRIBUTE14, s.ATTRIBUTE15,
                    s.ATTRIBUTE16, s.ATTRIBUTE17, s.ATTRIBUTE18, s.ATTRIBUTE19, s.ATTRIBUTE20,
                    s.ATTRIBUTE_DATE1,  s.ATTRIBUTE_DATE2,  s.ATTRIBUTE_DATE3,  s.ATTRIBUTE_DATE4,  s.ATTRIBUTE_DATE5,
                    s.ATTRIBUTE_DATE6,  s.ATTRIBUTE_DATE7,  s.ATTRIBUTE_DATE8,  s.ATTRIBUTE_DATE9,  s.ATTRIBUTE_DATE10,
                    s.ATTRIBUTE_NUMBER1,  s.ATTRIBUTE_NUMBER2,  s.ATTRIBUTE_NUMBER3,  s.ATTRIBUTE_NUMBER4,  s.ATTRIBUTE_NUMBER5,
                    s.ATTRIBUTE_NUMBER6,  s.ATTRIBUTE_NUMBER7,  s.ATTRIBUTE_NUMBER8,  s.ATTRIBUTE_NUMBER9,  s.ATTRIBUTE_NUMBER10,
                    s.ATTRIBUTE_TIMESTAMP1,  s.ATTRIBUTE_TIMESTAMP2,  s.ATTRIBUTE_TIMESTAMP3,  s.ATTRIBUTE_TIMESTAMP4,  s.ATTRIBUTE_TIMESTAMP5,
                    s.ATTRIBUTE_TIMESTAMP6,  s.ATTRIBUTE_TIMESTAMP7,  s.ATTRIBUTE_TIMESTAMP8,  s.ATTRIBUTE_TIMESTAMP9,  s.ATTRIBUTE_TIMESTAMP10,
                    s.DELIVER_TO_PERSON_EMAIL_ADDR,
                    s.BUDGET_DATE,
                    s.PJC_CONTRACT_NUMBER,
                    s.PJC_FUNDING_SOURCE,
                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_PO_DISTS_INT_STG_TBL s
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
            SELECT 1 FROM DMT_OWNER.DMT_PO_DISTS_INT_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_OWNER.DMT_PO_DISTS_INT_STG_TBL s
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
            SELECT 1 FROM DMT_OWNER.DMT_PO_DISTS_INT_TFM_TBL t
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

END DMT_PO_TRANSFORM_PKG;
/
