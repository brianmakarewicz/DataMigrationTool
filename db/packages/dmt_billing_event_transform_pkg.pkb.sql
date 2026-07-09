-- PACKAGE BODY DMT_BILLING_EVENT_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_BILLING_EVENT_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_BILLING_EVENT_TRANSFORM_PKG Body
-- Billing Events transformation: STG -> TFM with prefix application.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_BILLING_EVENT_TRANSFORM_PKG';

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
    -- TRANSFORM_EVENTS
    -- ============================================================
    PROCEDURE TRANSFORM_EVENTS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_dep_prefix    VARCHAR2(30);
        l_prefix        VARCHAR2(30);
        l_ok_count      NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_EVENTS start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_EVENTS');

        l_dep_prefix := get_dep_prefix(p_run_id);

        -- Read main prefix for SOURCEREF (business key for reconciliation)
        BEGIN
            SELECT PREFIX INTO l_prefix
            FROM   DMT_OWNER.DMT_PIPELINE_RUN_TBL
            WHERE  RUN_ID = p_run_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN l_prefix := NULL;
        END;

        -- Bulk INSERT into TFM from eligible STG rows
        INSERT INTO DMT_OWNER.DMT_PJB_BILL_EVENTS_TFM_TBL (
            TFM_SEQUENCE_ID,
            STG_SEQUENCE_ID,
            RUN_ID,
            FBDI_CSV_ID,
            SOURCENAME,
            SOURCEREF,
            ORGANIZATION_NAME,
            CONTRACT_TYPE_NAME,
            CONTRACT_NUMBER,
            CONTRACT_LINE_NUMBER,
            EVENT_TYPE_NAME,
            EVENT_DESC,
            COMPLETION_DATE,
            BILL_TRNS_CURRENCY_CODE,
            BILL_TRNS_AMOUNT,
            PROJECT_NUMBER,
            TASK_NUMBER,
            BILL_HOLD_FLAG,
            REVENUE_HOLD_FLAG,
            ATTRIBUTE_CATEGORY,
            ATTRIBUTE1,  ATTRIBUTE2,  ATTRIBUTE3,  ATTRIBUTE4,  ATTRIBUTE5,
            ATTRIBUTE6,  ATTRIBUTE7,  ATTRIBUTE8,  ATTRIBUTE9,  ATTRIBUTE10,
            ATTRIBUTE_CHAR11, ATTRIBUTE_CHAR12, ATTRIBUTE_CHAR13, ATTRIBUTE_CHAR14, ATTRIBUTE_CHAR15,
            ATTRIBUTE_CHAR16, ATTRIBUTE_CHAR17, ATTRIBUTE_CHAR18, ATTRIBUTE_CHAR19, ATTRIBUTE_CHAR20,
            ATTRIBUTE_CHAR21, ATTRIBUTE_CHAR22, ATTRIBUTE_CHAR23, ATTRIBUTE_CHAR24, ATTRIBUTE_CHAR25,
            ATTRIBUTE_CHAR26, ATTRIBUTE_CHAR27, ATTRIBUTE_CHAR28, ATTRIBUTE_CHAR29, ATTRIBUTE_CHAR30,
            ATTRIBUTE_NUMBER1,  ATTRIBUTE_NUMBER2,  ATTRIBUTE_NUMBER3,  ATTRIBUTE_NUMBER4,  ATTRIBUTE_NUMBER5,
            ATTRIBUTE_NUMBER6,  ATTRIBUTE_NUMBER7,  ATTRIBUTE_NUMBER8,  ATTRIBUTE_NUMBER9,  ATTRIBUTE_NUMBER10,
            ATTRIBUTE_DATE1,  ATTRIBUTE_DATE2,  ATTRIBUTE_DATE3,  ATTRIBUTE_DATE4,  ATTRIBUTE_DATE5,
            ATTRIBUTE_DATE6,  ATTRIBUTE_DATE7,  ATTRIBUTE_DATE8,  ATTRIBUTE_DATE9,  ATTRIBUTE_DATE10,
            ATTRIBUTE_TIMESTAMP1, ATTRIBUTE_TIMESTAMP2, ATTRIBUTE_TIMESTAMP3, ATTRIBUTE_TIMESTAMP4, ATTRIBUTE_TIMESTAMP5,
            REVERSE_ACCRUAL_FLAG,
            ITEM_EVENT_FLAG,
            QUANTITY,
            ITEM_NUMBER,
            UNIT_OF_MEASURE,
            UNIT_PRICE,
            PREPAYMENT_REQ_EVENT_NUM,
            TFM_STATUS,
            LAST_UPDATED_DATE
        )
        SELECT
            DMT_OWNER.DMT_PJB_BILL_EVENTS_TFM_SEQ.NEXTVAL,
            s.STG_SEQUENCE_ID,
            p_run_id,
            NULL,  -- FBDI_CSV_ID: populated by FBDI generator
            s.SOURCENAME,
            DMT_UTIL_PKG.PREFIXED(l_prefix, s.SOURCEREF),
            s.ORGANIZATION_NAME,
            s.CONTRACT_TYPE_NAME,
            s.CONTRACT_NUMBER,
            s.CONTRACT_LINE_NUMBER,
            s.EVENT_TYPE_NAME,
            s.EVENT_DESC,
            s.COMPLETION_DATE,
            s.BILL_TRNS_CURRENCY_CODE,
            s.BILL_TRNS_AMOUNT,
            DMT_UTIL_PKG.PREFIXED(l_dep_prefix, s.PROJECT_NUMBER, 25),
            s.TASK_NUMBER,
            s.BILL_HOLD_FLAG,
            s.REVENUE_HOLD_FLAG,
            s.ATTRIBUTE_CATEGORY,
            s.ATTRIBUTE1,  s.ATTRIBUTE2,  s.ATTRIBUTE3,  s.ATTRIBUTE4,  s.ATTRIBUTE5,
            s.ATTRIBUTE6,  s.ATTRIBUTE7,  s.ATTRIBUTE8,  s.ATTRIBUTE9,  s.ATTRIBUTE10,
            s.ATTRIBUTE_CHAR11, s.ATTRIBUTE_CHAR12, s.ATTRIBUTE_CHAR13, s.ATTRIBUTE_CHAR14, s.ATTRIBUTE_CHAR15,
            s.ATTRIBUTE_CHAR16, s.ATTRIBUTE_CHAR17, s.ATTRIBUTE_CHAR18, s.ATTRIBUTE_CHAR19, s.ATTRIBUTE_CHAR20,
            s.ATTRIBUTE_CHAR21, s.ATTRIBUTE_CHAR22, s.ATTRIBUTE_CHAR23, s.ATTRIBUTE_CHAR24, s.ATTRIBUTE_CHAR25,
            s.ATTRIBUTE_CHAR26, s.ATTRIBUTE_CHAR27, s.ATTRIBUTE_CHAR28, s.ATTRIBUTE_CHAR29, s.ATTRIBUTE_CHAR30,
            s.ATTRIBUTE_NUMBER1,  s.ATTRIBUTE_NUMBER2,  s.ATTRIBUTE_NUMBER3,  s.ATTRIBUTE_NUMBER4,  s.ATTRIBUTE_NUMBER5,
            s.ATTRIBUTE_NUMBER6,  s.ATTRIBUTE_NUMBER7,  s.ATTRIBUTE_NUMBER8,  s.ATTRIBUTE_NUMBER9,  s.ATTRIBUTE_NUMBER10,
            s.ATTRIBUTE_DATE1,  s.ATTRIBUTE_DATE2,  s.ATTRIBUTE_DATE3,  s.ATTRIBUTE_DATE4,  s.ATTRIBUTE_DATE5,
            s.ATTRIBUTE_DATE6,  s.ATTRIBUTE_DATE7,  s.ATTRIBUTE_DATE8,  s.ATTRIBUTE_DATE9,  s.ATTRIBUTE_DATE10,
            s.ATTRIBUTE_TIMESTAMP1, s.ATTRIBUTE_TIMESTAMP2, s.ATTRIBUTE_TIMESTAMP3, s.ATTRIBUTE_TIMESTAMP4, s.ATTRIBUTE_TIMESTAMP5,
            s.REVERSE_ACCRUAL_FLAG,
            s.ITEM_EVENT_FLAG,
            s.QUANTITY,
            s.ITEM_NUMBER,
            s.UNIT_OF_MEASURE,
            s.UNIT_PRICE,
            s.PREPAYMENT_REQ_EVENT_NUM,
            'STAGED',
            SYSDATE
        FROM DMT_OWNER.DMT_PJB_BILL_EVENTS_STG_TBL s
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
            SELECT 1
            FROM   DMT_OWNER.DMT_PJB_BILL_EVENTS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        l_ok_count := SQL%ROWCOUNT;

        -- Update STG stg_status to TRANSFORMED for rows that were inserted into TFM
        UPDATE DMT_OWNER.DMT_PJB_BILL_EVENTS_STG_TBL
        SET    STG_STATUS = 'TRANSFORMED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (
            SELECT STG_SEQUENCE_ID
            FROM   DMT_OWNER.DMT_PJB_BILL_EVENTS_TFM_TBL
            WHERE  RUN_ID = p_run_id
        )
        AND (
            (p_run_mode = 'NEW' AND STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL' AND STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_reprocess_errors AND STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_EVENTS complete. Rows transformed: ' || l_ok_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_EVENTS');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_EVENTS failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_EVENTS');
            RAISE;
    END TRANSFORM_EVENTS;

END DMT_BILLING_EVENT_TRANSFORM_PKG;
/
