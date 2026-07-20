-- PACKAGE BODY DMT_REQ_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_REQ_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_REQ_TRANSFORM_PKG Body
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_REQ_TRANSFORM_PKG';

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


    -- ============================================================
    -- TRANSFORM_HEADERS
    -- ============================================================
    PROCEDURE TRANSFORM_HEADERS (
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
            p_message        => 'TRANSFORM_HEADERS start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_HEADERS');

        l_prefix := get_prefix(p_run_id);


        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_OWNER.DMT_POR_REQ_HEADERS_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_OWNER.DMT_POR_REQ_HEADERS_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    FBDI_CSV_ID,
                    INTERFACE_HEADER_KEY,
                    INTERFACE_SOURCE_CODE,
                    REQ_BU_NAME,
                    BATCH_ID,
                    INTERFACE_SOURCE_LINE_ID,
                    DOCUMENT_STATUS,
                    APPROVER_EMAIL_ADDR,
                    PREPARER_EMAIL_ADDR,
                    PRC_BU_NAME,
                    REQUISITION_NUMBER,
                    DESCRIPTION,
                    EMERGENCY_PO_NUMBER,
                    DEFAULT_TAXATION_COUNTRY,
                    DEFAULT_TAXATION_TERRITORY,
                    DOCUMENT_SUB_TYPE,
                    DOCUMENT_SUB_TYPE_NAME,
                    JUSTIFICATION,
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
                    ATTRIBUTE_CATEGORY,
                    SOLDTO_LE_NAME,
                    TFM_STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    NULL,
                    TO_CHAR(p_run_id) || '_RQHDR_' || TO_CHAR(s.STG_SEQUENCE_ID),
                    'DMT',
                    s.REQ_BU_NAME,
                    -- Carry the user's batch id through (partition key + ESS
                    -- BatchId arg); fall back to the run id for isolation when
                    -- the source supplies none. No hardcode / no overwrite (§7).
                    NVL(TO_CHAR(s.BATCH_ID), TO_CHAR(DMT_LOADER_PKG.g_work_queue_id)),  -- work-queue-ID core: source BATCH_ID first; work-queue-item id fallback, never the prefix
                    s.INTERFACE_SOURCE_LINE_ID,
                    CASE WHEN s.DOCUMENT_STATUS = 'APPROVED'
                              AND s.APPROVER_EMAIL_ADDR IS NULL
                         THEN 'INCOMPLETE'
                         ELSE s.DOCUMENT_STATUS
                    END,
                    s.APPROVER_EMAIL_ADDR,
                    s.PREPARER_EMAIL_ADDR,
                    s.PRC_BU_NAME,
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.REQUISITION_NUMBER, 64),
                    s.DESCRIPTION,
                    s.EMERGENCY_PO_NUMBER,
                    s.DEFAULT_TAXATION_COUNTRY,
                    s.DEFAULT_TAXATION_TERRITORY,
                    s.DOCUMENT_SUB_TYPE,
                    s.DOCUMENT_SUB_TYPE_NAME,
                    s.JUSTIFICATION,
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
                    s.ATTRIBUTE_CATEGORY,
                    s.SOLDTO_LE_NAME,
                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_POR_REQ_HEADERS_STG_TBL s
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
            SELECT 1 FROM DMT_OWNER.DMT_POR_REQ_HEADERS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_OWNER.DMT_POR_REQ_HEADERS_STG_TBL s
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
            SELECT 1 FROM DMT_OWNER.DMT_POR_REQ_HEADERS_TFM_TBL t
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
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_ok_count      NUMBER := 0;
        l_fail_count    NUMBER := 0;

    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_LINES start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_LINES');


        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_OWNER.DMT_POR_REQ_LINES_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_OWNER.DMT_POR_REQ_LINES_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    FBDI_CSV_ID,
                    INTERFACE_LINE_KEY,
                    INTERFACE_HEADER_KEY,
                    GROUP_CODE,
                    DESTINATION_TYPE_CODE,
                    DELIVER_TO_LOCATION_CODE,
                    DESTINATION_ORGANIZATION_CODE,
                    DESTINATION_SUBINVENTORY,
                    REQUESTER_EMAIL_ADDR,
                    ITEM_DESCRIPTION,
                    CATEGORY_NAME,
                    NEED_BY_DATE,
                    ITEM_NUMBER,
                    ITEM_REVISION,
                    UOM_CODE,
                    LINE_TYPE,
                    QUANTITY,
                    CURRENCY_CODE,
                    CURRENCY_UNIT_PRICE,
                    RATE,
                    RATE_DATE,
                    RATE_TYPE,
                    SECONDARY_UOM_CODE,
                    SECONDARY_QUANTITY,
                    CURRENCY_AMOUNT,
                    UN_NUMBER,
                    HAZARD_CLASS,
                    PRC_BU_NAME,
                    SOURCE_DOC_HEADER_NUMBER,
                    SOURCE_DOC_LINE_NUMBER,
                    SUGGESTED_VENDOR_NAME,
                    SUGGESTED_VENDOR_SITE,
                    SUGGESTED_VENDOR_CONTACT,
                    SUGGESTED_VENDOR_CONTACT_PHONE,
                    SUGGESTED_VENDOR_CONTACT_FAX,
                    SUGGESTED_VENDOR_CONTACT_EMAIL,
                    SUGGESTED_SUPPLIER_ITEM_NUM,
                    SUGGESTED_BUYER_EMAIL_ADDR,
                    AUTOSOURCE_FLAG,
                    NEGOTIATED_BY_PREPARER_FLAG,
                    NEGOTIATION_REQUIRED_FLAG,
                    URGENT_FLAG,
                    NEW_SUPPLIER_FLAG,
                    NOTE_TO_BUYER,
                    NOTE_TO_RECEIVER,
                    TRX_BUSINESS_CATEGORY,
                    TRX_BUSINESS_CATEGORY_NAME,
                    PRODUCT_TYPE,
                    PRODUCT_TYPE_NAME,
                    PRODUCT_FISC_CLASSIFICATION,
                    PRODUCT_FISC_CLASS_NAME,
                    PRODUCT_CATEGORY,
                    PRODUCT_CATEGORY_NAME,
                    LINE_INTENDED_USE,
                    LINE_INTENDED_USE_NAME,
                    USER_DEFINED_FISC_CLASS,
                    USER_DEFINED_FISC_CLASS_NAME,
                    TAX_CLASSIFICATION_CODE,
                    TAX_CLASSIFICATION_NAME,
                    ASSESSABLE_VALUE,
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
                    ATTRIBUTE_CATEGORY,
                    VENDOR_NUMBER,
                    FIRST_PTY_REG_NUMBER,
                    THIRD_PTY_REG_NUMBER,
                    FINAL_DISCHARGE_LOC_CODE,
                    UNIT_OF_MEASURE,
                    SECONDARY_UNIT_OF_MEASURE,
                    TFM_STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    NULL,
                    TO_CHAR(p_run_id) || '_RQLN_' || TO_CHAR(s.STG_SEQUENCE_ID),
                    (SELECT ht.INTERFACE_HEADER_KEY
                     FROM   DMT_OWNER.DMT_POR_REQ_HEADERS_TFM_TBL ht
                     JOIN   DMT_OWNER.DMT_POR_REQ_HEADERS_STG_TBL hs
                       ON   hs.STG_SEQUENCE_ID = ht.STG_SEQUENCE_ID
                     WHERE  ht.RUN_ID = p_run_id
                     AND    hs.INTERFACE_HEADER_KEY = s.INTERFACE_HEADER_KEY
                     AND    ROWNUM = 1),
                    s.GROUP_CODE,
                    s.DESTINATION_TYPE_CODE,
                    s.DELIVER_TO_LOCATION_CODE,
                    s.DESTINATION_ORGANIZATION_CODE,
                    s.DESTINATION_SUBINVENTORY,
                    s.REQUESTER_EMAIL_ADDR,
                    s.ITEM_DESCRIPTION,
                    s.CATEGORY_NAME,
                    s.NEED_BY_DATE,
                    s.ITEM_NUMBER,
                    s.ITEM_REVISION,
                    s.UOM_CODE,
                    s.LINE_TYPE,
                    s.QUANTITY,
                    s.CURRENCY_CODE,
                    s.CURRENCY_UNIT_PRICE,
                    s.RATE,
                    s.RATE_DATE,
                    s.RATE_TYPE,
                    s.SECONDARY_UOM_CODE,
                    s.SECONDARY_QUANTITY,
                    s.CURRENCY_AMOUNT,
                    s.UN_NUMBER,
                    s.HAZARD_CLASS,
                    s.PRC_BU_NAME,
                    s.SOURCE_DOC_HEADER_NUMBER,
                    s.SOURCE_DOC_LINE_NUMBER,
                    s.SUGGESTED_VENDOR_NAME,
                    s.SUGGESTED_VENDOR_SITE,
                    s.SUGGESTED_VENDOR_CONTACT,
                    s.SUGGESTED_VENDOR_CONTACT_PHONE,
                    s.SUGGESTED_VENDOR_CONTACT_FAX,
                    s.SUGGESTED_VENDOR_CONTACT_EMAIL,
                    s.SUGGESTED_SUPPLIER_ITEM_NUM,
                    s.SUGGESTED_BUYER_EMAIL_ADDR,
                    s.AUTOSOURCE_FLAG,
                    s.NEGOTIATED_BY_PREPARER_FLAG,
                    s.NEGOTIATION_REQUIRED_FLAG,
                    s.URGENT_FLAG,
                    s.NEW_SUPPLIER_FLAG,
                    s.NOTE_TO_BUYER,
                    s.NOTE_TO_RECEIVER,
                    s.TRX_BUSINESS_CATEGORY,
                    s.TRX_BUSINESS_CATEGORY_NAME,
                    s.PRODUCT_TYPE,
                    s.PRODUCT_TYPE_NAME,
                    s.PRODUCT_FISC_CLASSIFICATION,
                    s.PRODUCT_FISC_CLASS_NAME,
                    s.PRODUCT_CATEGORY,
                    s.PRODUCT_CATEGORY_NAME,
                    s.LINE_INTENDED_USE,
                    s.LINE_INTENDED_USE_NAME,
                    s.USER_DEFINED_FISC_CLASS,
                    s.USER_DEFINED_FISC_CLASS_NAME,
                    s.TAX_CLASSIFICATION_CODE,
                    s.TAX_CLASSIFICATION_NAME,
                    s.ASSESSABLE_VALUE,
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
                    s.ATTRIBUTE_CATEGORY,
                    s.VENDOR_NUMBER,
                    s.FIRST_PTY_REG_NUMBER,
                    s.THIRD_PTY_REG_NUMBER,
                    s.FINAL_DISCHARGE_LOC_CODE,
                    s.UNIT_OF_MEASURE,
                    s.SECONDARY_UNIT_OF_MEASURE,
                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_POR_REQ_LINES_STG_TBL s
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
            SELECT 1 FROM DMT_OWNER.DMT_POR_REQ_LINES_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_OWNER.DMT_POR_REQ_LINES_STG_TBL s
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
            SELECT 1 FROM DMT_OWNER.DMT_POR_REQ_LINES_TFM_TBL t
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
            UPDATE DMT_OWNER.DMT_POR_REQ_DISTS_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_OWNER.DMT_POR_REQ_DISTS_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    FBDI_CSV_ID,
                    INTERFACE_DISTRIBUTION_KEY,
                    INTERFACE_LINE_KEY,
                    PERCENT,
                    DISTRIBUTION_NUMBER,
                    DISTRIBUTION_QUANTITY,
                    DISTRIBUTION_CURRENCY_AMOUNT,
                    PJC_PROJECT_NAME,
                    PJC_TASK_NAME,
                    PJC_EXPENDITURE_TYPE_NAME,
                    PJC_EXPENDITURE_ITEM_DATE,
                    PJC_ORGANIZATION_NAME,
                    PJC_BILLABLE_FLAG,
                    PJC_CAPITALIZABLE_FLAG,
                    PJC_RESERVED_ATTRIBUTE1,  PJC_RESERVED_ATTRIBUTE2,  PJC_RESERVED_ATTRIBUTE3,
                    PJC_RESERVED_ATTRIBUTE4,  PJC_RESERVED_ATTRIBUTE5,  PJC_RESERVED_ATTRIBUTE6,
                    PJC_RESERVED_ATTRIBUTE7,  PJC_RESERVED_ATTRIBUTE8,  PJC_RESERVED_ATTRIBUTE9,
                    PJC_RESERVED_ATTRIBUTE10,
                    PJC_USER_DEF_ATTRIBUTE1,  PJC_USER_DEF_ATTRIBUTE2,  PJC_USER_DEF_ATTRIBUTE3,
                    PJC_USER_DEF_ATTRIBUTE4,  PJC_USER_DEF_ATTRIBUTE5,  PJC_USER_DEF_ATTRIBUTE6,
                    PJC_USER_DEF_ATTRIBUTE7,  PJC_USER_DEF_ATTRIBUTE8,  PJC_USER_DEF_ATTRIBUTE9,
                    PJC_USER_DEF_ATTRIBUTE10,
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
                    ATTRIBUTE_CATEGORY,
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
                    PJC_WORK_TYPE,
                    BUDGET_DATE,
                    TFM_STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    NULL,
                    TO_CHAR(p_run_id) || '_RQDIST_' || TO_CHAR(s.STG_SEQUENCE_ID),
                    (SELECT lt.INTERFACE_LINE_KEY
                     FROM   DMT_OWNER.DMT_POR_REQ_LINES_TFM_TBL lt
                     JOIN   DMT_OWNER.DMT_POR_REQ_LINES_STG_TBL ls
                       ON   ls.STG_SEQUENCE_ID = lt.STG_SEQUENCE_ID
                     WHERE  lt.RUN_ID = p_run_id
                     AND    ls.INTERFACE_LINE_KEY = s.INTERFACE_LINE_KEY
                     AND    ROWNUM = 1),
                    s.PERCENT,
                    s.DISTRIBUTION_NUMBER,
                    s.DISTRIBUTION_QUANTITY,
                    s.DISTRIBUTION_CURRENCY_AMOUNT,
                    s.PJC_PROJECT_NAME,
                    s.PJC_TASK_NAME,
                    s.PJC_EXPENDITURE_TYPE_NAME,
                    s.PJC_EXPENDITURE_ITEM_DATE,
                    s.PJC_ORGANIZATION_NAME,
                    s.PJC_BILLABLE_FLAG,
                    s.PJC_CAPITALIZABLE_FLAG,
                    s.PJC_RESERVED_ATTRIBUTE1,  s.PJC_RESERVED_ATTRIBUTE2,  s.PJC_RESERVED_ATTRIBUTE3,
                    s.PJC_RESERVED_ATTRIBUTE4,  s.PJC_RESERVED_ATTRIBUTE5,  s.PJC_RESERVED_ATTRIBUTE6,
                    s.PJC_RESERVED_ATTRIBUTE7,  s.PJC_RESERVED_ATTRIBUTE8,  s.PJC_RESERVED_ATTRIBUTE9,
                    s.PJC_RESERVED_ATTRIBUTE10,
                    s.PJC_USER_DEF_ATTRIBUTE1,  s.PJC_USER_DEF_ATTRIBUTE2,  s.PJC_USER_DEF_ATTRIBUTE3,
                    s.PJC_USER_DEF_ATTRIBUTE4,  s.PJC_USER_DEF_ATTRIBUTE5,  s.PJC_USER_DEF_ATTRIBUTE6,
                    s.PJC_USER_DEF_ATTRIBUTE7,  s.PJC_USER_DEF_ATTRIBUTE8,  s.PJC_USER_DEF_ATTRIBUTE9,
                    s.PJC_USER_DEF_ATTRIBUTE10,
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
                    s.ATTRIBUTE_CATEGORY,
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
                    s.PJC_WORK_TYPE,
                    s.BUDGET_DATE,
                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_POR_REQ_DISTS_STG_TBL s
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
            SELECT 1 FROM DMT_OWNER.DMT_POR_REQ_DISTS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_OWNER.DMT_POR_REQ_DISTS_STG_TBL s
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
            SELECT 1 FROM DMT_OWNER.DMT_POR_REQ_DISTS_TFM_TBL t
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

END DMT_REQ_TRANSFORM_PKG;
/
