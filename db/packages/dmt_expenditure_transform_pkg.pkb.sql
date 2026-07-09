-- PACKAGE BODY DMT_EXPENDITURE_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_EXPENDITURE_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_EXPENDITURE_TRANSFORM_PKG Body
-- Expenditures transformation: STG -> TFM with prefix application.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_EXPENDITURE_TRANSFORM_PKG';

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
    -- TRANSFORM_EXPENDITURES
    -- ============================================================
    PROCEDURE TRANSFORM_EXPENDITURES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_dep_prefix    VARCHAR2(30);
        l_ok_count      NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_EXPENDITURES start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_EXPENDITURES');

        l_dep_prefix := get_dep_prefix(p_run_id);

        -- Bulk INSERT into TFM from eligible STG rows
        INSERT INTO DMT_OWNER.DMT_PJC_EXPENDITURES_TFM_TBL (
            TFM_SEQUENCE_ID,
            STG_SEQUENCE_ID,
            RUN_ID,
            FBDI_CSV_ID,
            TRANSACTION_TYPE,
            BUSINESS_UNIT,
            ORG_ID,
            USER_TRANSACTION_SOURCE,
            TRANSACTION_SOURCE_ID,
            DOCUMENT_NAME,
            DOCUMENT_ID,
            DOC_ENTRY_NAME,
            DOC_ENTRY_ID,
            BATCH_NAME,
            BATCH_ENDING_DATE,
            BATCH_DESCRIPTION,
            EXPENDITURE_ITEM_DATE,
            PERSON_NUMBER,
            PERSON_NAME,
            PERSON_ID,
            HCM_ASSIGNMENT_NAME,
            HCM_ASSIGNMENT_ID,
            PROJECT_NUMBER,
            PROJECT_NAME,
            PROJECT_ID,
            TASK_NUMBER,
            TASK_NAME,
            TASK_ID,
            EXPENDITURE_TYPE,
            EXPENDITURE_TYPE_ID,
            ORGANIZATION_NAME,
            ORGANIZATION_ID,
            NON_LABOR_RESOURCE,
            NON_LABOR_RESOURCE_ID,
            NON_LABOR_RESOURCE_ORG,
            NON_LABOR_RESOURCE_ORG_ID,
            QUANTITY,
            UNIT_OF_MEASURE_NAME,
            UNIT_OF_MEASURE,
            WORK_TYPE,
            WORK_TYPE_ID,
            BILLABLE_FLAG,
            CAPITALIZABLE_FLAG,
            ACCRUAL_FLAG,
            SUPPLIER_NUMBER,
            SUPPLIER_NAME,
            VENDOR_ID,
            INVENTORY_ITEM_NAME,
            INVENTORY_ITEM_ID,
            ORIG_TRANSACTION_REFERENCE,
            UNMATCHED_NEGATIVE_TXN_FLAG,
            REVERSED_ORIG_TXN_REFERENCE,
            EXPENDITURE_COMMENT,
            GL_DATE,
            DENOM_CURRENCY_CODE,
            DENOM_CURRENCY,
            DENOM_RAW_COST,
            DENOM_BURDENED_COST,
            RAW_COST_CR_CCID,
            RAW_COST_CR_ACCOUNT,
            RAW_COST_DR_CCID,
            RAW_COST_DR_ACCOUNT,
            BURDENED_COST_CR_CCID,
            BURDENED_COST_CR_ACCOUNT,
            BURDENED_COST_DR_CCID,
            BURDENED_COST_DR_ACCOUNT,
            BURDEN_COST_CR_CCID,
            BURDEN_COST_CR_ACCOUNT,
            BURDEN_COST_DR_CCID,
            BURDEN_COST_DR_ACCOUNT,
            ACCT_CURRENCY_CODE,
            ACCT_CURRENCY,
            ACCT_RAW_COST,
            ACCT_BURDENED_COST,
            ACCT_RATE_TYPE,
            ACCT_RATE_DATE,
            ACCT_RATE_DATE_TYPE,
            ACCT_EXCHANGE_RATE,
            ACCT_EXCHANGE_ROUNDING_LIMIT,
            RECEIPT_CURRENCY_CODE,
            RECEIPT_CURRENCY,
            RECEIPT_CURRENCY_AMOUNT,
            RECEIPT_EXCHANGE_RATE,
            CONVERTED_FLAG,
            CONTEXT_CATEGORY,
            USER_DEF_ATTRIBUTE1,  USER_DEF_ATTRIBUTE2,  USER_DEF_ATTRIBUTE3,  USER_DEF_ATTRIBUTE4,  USER_DEF_ATTRIBUTE5,
            USER_DEF_ATTRIBUTE6,  USER_DEF_ATTRIBUTE7,  USER_DEF_ATTRIBUTE8,  USER_DEF_ATTRIBUTE9,  USER_DEF_ATTRIBUTE10,
            RESERVED_ATTRIBUTE1,  RESERVED_ATTRIBUTE2,  RESERVED_ATTRIBUTE3,  RESERVED_ATTRIBUTE4,  RESERVED_ATTRIBUTE5,
            RESERVED_ATTRIBUTE6,  RESERVED_ATTRIBUTE7,  RESERVED_ATTRIBUTE8,  RESERVED_ATTRIBUTE9,  RESERVED_ATTRIBUTE10,
            ATTRIBUTE_CATEGORY,
            ATTRIBUTE1,  ATTRIBUTE2,  ATTRIBUTE3,  ATTRIBUTE4,  ATTRIBUTE5,
            ATTRIBUTE6,  ATTRIBUTE7,  ATTRIBUTE8,  ATTRIBUTE9,  ATTRIBUTE10,
            CONTRACT_NUMBER,
            CONTRACT_NAME,
            CONTRACT_ID,
            FUNDING_SOURCE_NUMBER,
            FUNDING_SOURCE_NAME,
            PROJECT_ROLE_NAME,
            PROJECT_ROLE_ID,
            TFM_STATUS,
            LAST_UPDATED_DATE
        )
        SELECT
            DMT_OWNER.DMT_PJC_EXPENDITURES_TFM_SEQ.NEXTVAL,
            s.STG_SEQUENCE_ID,
            p_run_id,
            NULL,  -- FBDI_CSV_ID: populated by FBDI generator
            s.TRANSACTION_TYPE,
            s.BUSINESS_UNIT,
            s.ORG_ID,
            s.USER_TRANSACTION_SOURCE,
            s.TRANSACTION_SOURCE_ID,
            s.DOCUMENT_NAME,
            s.DOCUMENT_ID,
            s.DOC_ENTRY_NAME,
            s.DOC_ENTRY_ID,
            s.BATCH_NAME,
            s.BATCH_ENDING_DATE,
            s.BATCH_DESCRIPTION,
            s.EXPENDITURE_ITEM_DATE,
            s.PERSON_NUMBER,
            s.PERSON_NAME,
            s.PERSON_ID,
            s.HCM_ASSIGNMENT_NAME,
            s.HCM_ASSIGNMENT_ID,
            DMT_UTIL_PKG.PREFIXED(l_dep_prefix, s.PROJECT_NUMBER, 25),
            s.PROJECT_NAME,
            s.PROJECT_ID,
            s.TASK_NUMBER,
            s.TASK_NAME,
            s.TASK_ID,
            s.EXPENDITURE_TYPE,
            s.EXPENDITURE_TYPE_ID,
            s.ORGANIZATION_NAME,
            s.ORGANIZATION_ID,
            s.NON_LABOR_RESOURCE,
            s.NON_LABOR_RESOURCE_ID,
            s.NON_LABOR_RESOURCE_ORG,
            s.NON_LABOR_RESOURCE_ORG_ID,
            s.QUANTITY,
            s.UNIT_OF_MEASURE_NAME,
            s.UNIT_OF_MEASURE,
            s.WORK_TYPE,
            s.WORK_TYPE_ID,
            s.BILLABLE_FLAG,
            s.CAPITALIZABLE_FLAG,
            s.ACCRUAL_FLAG,
            -- Apply dependent prefix to SUPPLIER_NUMBER if present
            CASE WHEN s.SUPPLIER_NUMBER IS NOT NULL
                 THEN DMT_UTIL_PKG.PREFIXED(l_dep_prefix, s.SUPPLIER_NUMBER)
                 ELSE NULL
            END,
            s.SUPPLIER_NAME,
            s.VENDOR_ID,
            s.INVENTORY_ITEM_NAME,
            s.INVENTORY_ITEM_ID,
            s.ORIG_TRANSACTION_REFERENCE,
            s.UNMATCHED_NEGATIVE_TXN_FLAG,
            s.REVERSED_ORIG_TXN_REFERENCE,
            s.EXPENDITURE_COMMENT,
            s.GL_DATE,
            s.DENOM_CURRENCY_CODE,
            s.DENOM_CURRENCY,
            s.DENOM_RAW_COST,
            s.DENOM_BURDENED_COST,
            s.RAW_COST_CR_CCID,
            s.RAW_COST_CR_ACCOUNT,
            s.RAW_COST_DR_CCID,
            s.RAW_COST_DR_ACCOUNT,
            s.BURDENED_COST_CR_CCID,
            s.BURDENED_COST_CR_ACCOUNT,
            s.BURDENED_COST_DR_CCID,
            s.BURDENED_COST_DR_ACCOUNT,
            s.BURDEN_COST_CR_CCID,
            s.BURDEN_COST_CR_ACCOUNT,
            s.BURDEN_COST_DR_CCID,
            s.BURDEN_COST_DR_ACCOUNT,
            s.ACCT_CURRENCY_CODE,
            s.ACCT_CURRENCY,
            s.ACCT_RAW_COST,
            s.ACCT_BURDENED_COST,
            s.ACCT_RATE_TYPE,
            s.ACCT_RATE_DATE,
            s.ACCT_RATE_DATE_TYPE,
            s.ACCT_EXCHANGE_RATE,
            s.ACCT_EXCHANGE_ROUNDING_LIMIT,
            s.RECEIPT_CURRENCY_CODE,
            s.RECEIPT_CURRENCY,
            s.RECEIPT_CURRENCY_AMOUNT,
            s.RECEIPT_EXCHANGE_RATE,
            s.CONVERTED_FLAG,
            s.CONTEXT_CATEGORY,
            s.USER_DEF_ATTRIBUTE1,  s.USER_DEF_ATTRIBUTE2,  s.USER_DEF_ATTRIBUTE3,  s.USER_DEF_ATTRIBUTE4,  s.USER_DEF_ATTRIBUTE5,
            s.USER_DEF_ATTRIBUTE6,  s.USER_DEF_ATTRIBUTE7,  s.USER_DEF_ATTRIBUTE8,  s.USER_DEF_ATTRIBUTE9,  s.USER_DEF_ATTRIBUTE10,
            s.RESERVED_ATTRIBUTE1,  s.RESERVED_ATTRIBUTE2,  s.RESERVED_ATTRIBUTE3,  s.RESERVED_ATTRIBUTE4,  s.RESERVED_ATTRIBUTE5,
            s.RESERVED_ATTRIBUTE6,  s.RESERVED_ATTRIBUTE7,  s.RESERVED_ATTRIBUTE8,  s.RESERVED_ATTRIBUTE9,  s.RESERVED_ATTRIBUTE10,
            s.ATTRIBUTE_CATEGORY,
            s.ATTRIBUTE1,  s.ATTRIBUTE2,  s.ATTRIBUTE3,  s.ATTRIBUTE4,  s.ATTRIBUTE5,
            s.ATTRIBUTE6,  s.ATTRIBUTE7,  s.ATTRIBUTE8,  s.ATTRIBUTE9,  s.ATTRIBUTE10,
            s.CONTRACT_NUMBER,
            s.CONTRACT_NAME,
            s.CONTRACT_ID,
            s.FUNDING_SOURCE_NUMBER,
            s.FUNDING_SOURCE_NAME,
            s.PROJECT_ROLE_NAME,
            s.PROJECT_ROLE_ID,
            'STAGED',
            SYSDATE
        FROM DMT_OWNER.DMT_PJC_EXPENDITURES_STG_TBL s
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
            FROM   DMT_OWNER.DMT_PJC_EXPENDITURES_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        l_ok_count := SQL%ROWCOUNT;

        -- Update STG stg_status to TRANSFORMED for rows that were inserted into TFM
        UPDATE DMT_OWNER.DMT_PJC_EXPENDITURES_STG_TBL
        SET    STG_STATUS = 'TRANSFORMED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (
            SELECT STG_SEQUENCE_ID
            FROM   DMT_OWNER.DMT_PJC_EXPENDITURES_TFM_TBL
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
            p_message        => 'TRANSFORM_EXPENDITURES complete. Rows transformed: ' || l_ok_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_EXPENDITURES');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_EXPENDITURES failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_EXPENDITURES');
            RAISE;
    END TRANSFORM_EXPENDITURES;

END DMT_EXPENDITURE_TRANSFORM_PKG;
/
