-- PACKAGE BODY DMT_PROJECT_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_PROJECT_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_PROJECT_TRANSFORM_PKG Body
-- Projects transformation: STG -> TFM with prefix application.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_PROJECT_TRANSFORM_PKG';

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
    -- TRANSFORM_PROJECTS
    -- ============================================================
    PROCEDURE TRANSFORM_PROJECTS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_prefix     VARCHAR2(30);
        l_ok_count   NUMBER := 0;
        l_fail_count NUMBER := 0;

    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_PROJECTS start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_PROJECTS');

        l_prefix := get_prefix(p_run_id);


        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_OWNER.DMT_PJF_PROJECTS_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    FBDI_CSV_ID,
                    -- Business columns
                    PROJECT_NAME,
                    PROJECT_NUMBER,
                    SOURCE_TEMPLATE_NUMBER,
                    SOURCE_APPLICATION_CODE,
                    SOURCE_PROJECT_REFERENCE,
                    ORGANIZATION_NAME,
                    LEGAL_ENTITY_NAME,
                    DESCRIPTION,
                    PROJECT_MANAGER_NUMBER,
                    PROJECT_MANAGER_NAME,
                    PROJECT_MANAGER_EMAIL,
                    PROJECT_START_DATE,
                    PROJECT_FINISH_DATE,
                    CLOSED_DATE,
                    PROJECT_STATUS_NAME,
                    PROJECT_PRIORITY_CODE,
                    OUTLINE_DISPLAY_LEVEL,
                    PLANNING_PROJECT_FLAG,
                    SERVICE_TYPE_CODE,
                    WORK_TYPE_NAME,
                    LIMIT_TO_TXN_CONTROLS_CODE,
                    PROJECT_CURRENCY_CODE,
                    CURRENCY_CONV_RATE_TYPE,
                    CURRENCY_CONV_DATE_TYPE_CODE,
                    CURRENCY_CONV_DATE,
                    CINT_ELIGIBLE_FLAG,
                    CINT_RATE_SCH_NAME,
                    CINT_STOP_DATE,
                    ASSET_ALLOCATION_METHOD_CODE,
                    CAPITAL_EVENT_PROCESSING_CODE,
                    ALLOW_CROSS_CHARGE_FLAG,
                    CC_PROCESS_LABOR_FLAG,
                    LABOR_TP_SCHEDULE_NAME,
                    LABOR_TP_FIXED_DATE,
                    CC_PROCESS_NL_FLAG,
                    NL_TP_SCHEDULE_NAME,
                    NL_TP_FIXED_DATE,
                    BURDEN_SCHEDULE_NAME,
                    BURDEN_SCH_FIXED_DATED,
                    KPI_NOTIFICATION_ENABLED,
                    KPI_NOTIFICATION_RECIPIENTS,
                    KPI_NOTIFICATION_INCLUDE_NOTES,
                    -- Copy flags
                    COPY_TEAM_MEMBERS_FLAG,
                    COPY_PROJECT_CLASSES_FLAG,
                    COPY_ATTACHMENTS_FLAG,
                    COPY_DFF_FLAG,
                    COPY_GROUP_SPACE_FLAG,
                    COPY_TASKS_FLAG,
                    COPY_TASK_ATTACHMENTS_FLAG,
                    COPY_TASK_DFF_FLAG,
                    COPY_TASK_ASSIGNMENTS_FLAG,
                    COPY_TRANSACTION_CONTROLS_FLAG,
                    COPY_ASSETS_FLAG,
                    COPY_ASSET_ASSIGNMENTS_FLAG,
                    COPY_COST_OVERRIDES_FLAG,
                    -- DFF attributes
                    ATTRIBUTE_CATEGORY,
                    ATTRIBUTE1,  ATTRIBUTE2,  ATTRIBUTE3,  ATTRIBUTE4,  ATTRIBUTE5,
                    ATTRIBUTE6,  ATTRIBUTE7,  ATTRIBUTE8,  ATTRIBUTE9,  ATTRIBUTE10,
                    ATTRIBUTE11, ATTRIBUTE12, ATTRIBUTE13, ATTRIBUTE14, ATTRIBUTE15,
                    ATTRIBUTE16, ATTRIBUTE17, ATTRIBUTE18, ATTRIBUTE19, ATTRIBUTE20,
                    ATTRIBUTE21, ATTRIBUTE22, ATTRIBUTE23, ATTRIBUTE24, ATTRIBUTE25,
                    ATTRIBUTE26, ATTRIBUTE27, ATTRIBUTE28, ATTRIBUTE29, ATTRIBUTE30,
                    ATTRIBUTE31, ATTRIBUTE32, ATTRIBUTE33, ATTRIBUTE34, ATTRIBUTE35,
                    ATTRIBUTE36, ATTRIBUTE37, ATTRIBUTE38, ATTRIBUTE39, ATTRIBUTE40,
                    ATTRIBUTE41, ATTRIBUTE42, ATTRIBUTE43, ATTRIBUTE44, ATTRIBUTE45,
                    ATTRIBUTE46, ATTRIBUTE47, ATTRIBUTE48, ATTRIBUTE49, ATTRIBUTE50,
                    ATTRIBUTE1_NUMBER,  ATTRIBUTE2_NUMBER,  ATTRIBUTE3_NUMBER,  ATTRIBUTE4_NUMBER,  ATTRIBUTE5_NUMBER,
                    ATTRIBUTE6_NUMBER,  ATTRIBUTE7_NUMBER,  ATTRIBUTE8_NUMBER,  ATTRIBUTE9_NUMBER,  ATTRIBUTE10_NUMBER,
                    ATTRIBUTE11_NUMBER, ATTRIBUTE12_NUMBER, ATTRIBUTE13_NUMBER, ATTRIBUTE14_NUMBER, ATTRIBUTE15_NUMBER,
                    ATTRIBUTE1_DATE,  ATTRIBUTE2_DATE,  ATTRIBUTE3_DATE,  ATTRIBUTE4_DATE,  ATTRIBUTE5_DATE,
                    ATTRIBUTE6_DATE,  ATTRIBUTE7_DATE,  ATTRIBUTE8_DATE,  ATTRIBUTE9_DATE,  ATTRIBUTE10_DATE,
                    ATTRIBUTE11_DATE, ATTRIBUTE12_DATE, ATTRIBUTE13_DATE, ATTRIBUTE14_DATE, ATTRIBUTE15_DATE,
                    -- Schedule/EPS
                    SCHEDULE_NAME,
                    EPS_NAME,
                    PROJECT_PLAN_VIEW_ACCESS,
                    SCHEDULE_TYPE,
                    -- Opportunity fields
                    OPPORTUNITY_ID,
                    OPPORTUNITY_NUMBER,
                    OPPORTUNITY_CUSTOMER_NUMBER,
                    OPPORTUNITY_CUSTOMER_ID,
                    OPPORTUNITY_AMT,
                    OPPORTUNITY_CURRCODE,
                    OPPORTUNITY_WIN_CONF_PERCENT,
                    OPPORTUNITY_NAME,
                    OPPORTUNITY_DESC,
                    OPPORTUNITY_CUSTOMER_NAME,
                    OPPORTUNITY_STATUS,
                    -- Baseline
                    PRJ_PLAN_BASELINE_NAME,
                    PRJ_PLAN_BASELINE_DESC,
                    PRJ_PLAN_BASELINE_DATE,
                    -- Other
                    BUDGETARY_CONTROL_FLAG,
                    SOURCE_TEMPLATE_NAME,
                    CASCADE_OPTION,
                    -- Pipeline columns
                    STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    NULL,

                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.PROJECT_NAME, 240),
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.PROJECT_NUMBER, 25),
                    s.SOURCE_TEMPLATE_NUMBER,
                    s.SOURCE_APPLICATION_CODE,
                    s.SOURCE_PROJECT_REFERENCE,
                    s.ORGANIZATION_NAME,
                    s.LEGAL_ENTITY_NAME,
                    s.DESCRIPTION,
                    s.PROJECT_MANAGER_NUMBER,
                    s.PROJECT_MANAGER_NAME,
                    s.PROJECT_MANAGER_EMAIL,
                    s.PROJECT_START_DATE,
                    s.PROJECT_FINISH_DATE,
                    s.CLOSED_DATE,
                    s.PROJECT_STATUS_NAME,
                    s.PROJECT_PRIORITY_CODE,
                    s.OUTLINE_DISPLAY_LEVEL,
                    s.PLANNING_PROJECT_FLAG,
                    s.SERVICE_TYPE_CODE,
                    s.WORK_TYPE_NAME,
                    s.LIMIT_TO_TXN_CONTROLS_CODE,
                    s.PROJECT_CURRENCY_CODE,
                    s.CURRENCY_CONV_RATE_TYPE,
                    s.CURRENCY_CONV_DATE_TYPE_CODE,
                    s.CURRENCY_CONV_DATE,
                    s.CINT_ELIGIBLE_FLAG,
                    s.CINT_RATE_SCH_NAME,
                    s.CINT_STOP_DATE,
                    s.ASSET_ALLOCATION_METHOD_CODE,
                    s.CAPITAL_EVENT_PROCESSING_CODE,
                    s.ALLOW_CROSS_CHARGE_FLAG,
                    s.CC_PROCESS_LABOR_FLAG,
                    s.LABOR_TP_SCHEDULE_NAME,
                    s.LABOR_TP_FIXED_DATE,
                    s.CC_PROCESS_NL_FLAG,
                    s.NL_TP_SCHEDULE_NAME,
                    s.NL_TP_FIXED_DATE,
                    s.BURDEN_SCHEDULE_NAME,
                    s.BURDEN_SCH_FIXED_DATED,
                    s.KPI_NOTIFICATION_ENABLED,
                    s.KPI_NOTIFICATION_RECIPIENTS,
                    s.KPI_NOTIFICATION_INCLUDE_NOTES,

                    s.COPY_TEAM_MEMBERS_FLAG,
                    s.COPY_PROJECT_CLASSES_FLAG,
                    s.COPY_ATTACHMENTS_FLAG,
                    s.COPY_DFF_FLAG,
                    s.COPY_GROUP_SPACE_FLAG,
                    s.COPY_TASKS_FLAG,
                    s.COPY_TASK_ATTACHMENTS_FLAG,
                    s.COPY_TASK_DFF_FLAG,
                    s.COPY_TASK_ASSIGNMENTS_FLAG,
                    s.COPY_TRANSACTION_CONTROLS_FLAG,
                    s.COPY_ASSETS_FLAG,
                    s.COPY_ASSET_ASSIGNMENTS_FLAG,
                    s.COPY_COST_OVERRIDES_FLAG,

                    s.ATTRIBUTE_CATEGORY,
                    s.ATTRIBUTE1,  s.ATTRIBUTE2,  s.ATTRIBUTE3,  s.ATTRIBUTE4,  s.ATTRIBUTE5,
                    s.ATTRIBUTE6,  s.ATTRIBUTE7,  s.ATTRIBUTE8,  s.ATTRIBUTE9,  s.ATTRIBUTE10,
                    s.ATTRIBUTE11, s.ATTRIBUTE12, s.ATTRIBUTE13, s.ATTRIBUTE14, s.ATTRIBUTE15,
                    s.ATTRIBUTE16, s.ATTRIBUTE17, s.ATTRIBUTE18, s.ATTRIBUTE19, s.ATTRIBUTE20,
                    s.ATTRIBUTE21, s.ATTRIBUTE22, s.ATTRIBUTE23, s.ATTRIBUTE24, s.ATTRIBUTE25,
                    s.ATTRIBUTE26, s.ATTRIBUTE27, s.ATTRIBUTE28, s.ATTRIBUTE29, s.ATTRIBUTE30,
                    s.ATTRIBUTE31, s.ATTRIBUTE32, s.ATTRIBUTE33, s.ATTRIBUTE34, s.ATTRIBUTE35,
                    s.ATTRIBUTE36, s.ATTRIBUTE37, s.ATTRIBUTE38, s.ATTRIBUTE39, s.ATTRIBUTE40,
                    s.ATTRIBUTE41, s.ATTRIBUTE42, s.ATTRIBUTE43, s.ATTRIBUTE44, s.ATTRIBUTE45,
                    s.ATTRIBUTE46, s.ATTRIBUTE47, s.ATTRIBUTE48, s.ATTRIBUTE49, s.ATTRIBUTE50,
                    s.ATTRIBUTE1_NUMBER,  s.ATTRIBUTE2_NUMBER,  s.ATTRIBUTE3_NUMBER,  s.ATTRIBUTE4_NUMBER,  s.ATTRIBUTE5_NUMBER,
                    s.ATTRIBUTE6_NUMBER,  s.ATTRIBUTE7_NUMBER,  s.ATTRIBUTE8_NUMBER,  s.ATTRIBUTE9_NUMBER,  s.ATTRIBUTE10_NUMBER,
                    s.ATTRIBUTE11_NUMBER, s.ATTRIBUTE12_NUMBER, s.ATTRIBUTE13_NUMBER, s.ATTRIBUTE14_NUMBER, s.ATTRIBUTE15_NUMBER,
                    s.ATTRIBUTE1_DATE,  s.ATTRIBUTE2_DATE,  s.ATTRIBUTE3_DATE,  s.ATTRIBUTE4_DATE,  s.ATTRIBUTE5_DATE,
                    s.ATTRIBUTE6_DATE,  s.ATTRIBUTE7_DATE,  s.ATTRIBUTE8_DATE,  s.ATTRIBUTE9_DATE,  s.ATTRIBUTE10_DATE,
                    s.ATTRIBUTE11_DATE, s.ATTRIBUTE12_DATE, s.ATTRIBUTE13_DATE, s.ATTRIBUTE14_DATE, s.ATTRIBUTE15_DATE,

                    s.SCHEDULE_NAME,
                    s.EPS_NAME,
                    s.PROJECT_PLAN_VIEW_ACCESS,
                    s.SCHEDULE_TYPE,

                    s.OPPORTUNITY_ID,
                    s.OPPORTUNITY_NUMBER,
                    s.OPPORTUNITY_CUSTOMER_NUMBER,
                    s.OPPORTUNITY_CUSTOMER_ID,
                    s.OPPORTUNITY_AMT,
                    s.OPPORTUNITY_CURRCODE,
                    s.OPPORTUNITY_WIN_CONF_PERCENT,
                    s.OPPORTUNITY_NAME,
                    s.OPPORTUNITY_DESC,
                    s.OPPORTUNITY_CUSTOMER_NAME,
                    s.OPPORTUNITY_STATUS,

                    s.PRJ_PLAN_BASELINE_NAME,
                    s.PRJ_PLAN_BASELINE_DESC,
                    s.PRJ_PLAN_BASELINE_DATE,

                    s.BUDGETARY_CONTROL_FLAG,
                    s.SOURCE_TEMPLATE_NAME,
                    s.CASCADE_OPTION,

                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_PJF_PROJECTS_STG_TBL s
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
            SELECT 1 FROM DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_OWNER.DMT_PJF_PROJECTS_STG_TBL s
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
            SELECT 1 FROM DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_PROJECTS complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_PROJECTS');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_PROJECTS failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_PROJECTS',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_PROJECTS;


    -- ============================================================
    -- TRANSFORM_TASKS
    -- ============================================================
    PROCEDURE TRANSFORM_TASKS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_prefix     VARCHAR2(30);
        l_ok_count   NUMBER := 0;
        l_fail_count NUMBER := 0;

    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_TASKS start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_TASKS');

        l_prefix := get_prefix(p_run_id);


        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_OWNER.DMT_PJF_TASKS_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_OWNER.DMT_PJF_TASKS_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    FBDI_CSV_ID,
                    -- Business columns
                    PROJECT_NAME,
                    PROJECT_NUMBER,
                    TASK_NAME,
                    TASK_NUMBER,
                    TASK_DESCRIPTION,
                    PARENT_TASK_NUMBER,
                    PLANNING_START_DATE,
                    PLANNING_END_DATE,
                    MILESTONE_FLAG,
                    CRITICAL_FLAG,
                    CHARGEABLE_FLAG,
                    BILLABLE_FLAG,
                    CAPITALIZABLE_FLAG,
                    LIMIT_TO_TXN_CONTROLS_FLAG,
                    SOURCE_TASK_REFERENCE,
                    SOURCE_APPLICATION_CODE,
                    SERVICE_TYPE_CODE,
                    WORK_TYPE_ID,
                    MANAGER_PERSON_ID,
                    ALLOW_CROSS_CHARGE_FLAG,
                    CC_PROCESS_LABOR_FLAG,
                    CC_PROCESS_NL_FLAG,
                    RECEIVE_PROJECT_INVOICE_FLAG,
                    -- DFF attributes
                    ATTRIBUTE_CATEGORY,
                    ATTRIBUTE1,  ATTRIBUTE2,  ATTRIBUTE3,  ATTRIBUTE4,  ATTRIBUTE5,
                    ATTRIBUTE6,  ATTRIBUTE7,  ATTRIBUTE8,  ATTRIBUTE9,  ATTRIBUTE10,
                    ATTRIBUTE11, ATTRIBUTE12, ATTRIBUTE13, ATTRIBUTE14, ATTRIBUTE15,
                    ATTRIBUTE16, ATTRIBUTE17, ATTRIBUTE18, ATTRIBUTE19, ATTRIBUTE20,
                    ATTRIBUTE21, ATTRIBUTE22, ATTRIBUTE23, ATTRIBUTE24, ATTRIBUTE25,
                    ATTRIBUTE26, ATTRIBUTE27, ATTRIBUTE28, ATTRIBUTE29, ATTRIBUTE30,
                    ATTRIBUTE31, ATTRIBUTE32, ATTRIBUTE33, ATTRIBUTE34, ATTRIBUTE35,
                    ATTRIBUTE36, ATTRIBUTE37, ATTRIBUTE38, ATTRIBUTE39, ATTRIBUTE40,
                    ATTRIBUTE41, ATTRIBUTE42, ATTRIBUTE43, ATTRIBUTE44, ATTRIBUTE45,
                    ATTRIBUTE46, ATTRIBUTE47, ATTRIBUTE48, ATTRIBUTE49, ATTRIBUTE50,
                    ATTRIBUTE1_NUMBER,  ATTRIBUTE2_NUMBER,  ATTRIBUTE3_NUMBER,  ATTRIBUTE4_NUMBER,  ATTRIBUTE5_NUMBER,
                    ATTRIBUTE6_NUMBER,  ATTRIBUTE7_NUMBER,  ATTRIBUTE8_NUMBER,  ATTRIBUTE9_NUMBER,  ATTRIBUTE10_NUMBER,
                    ATTRIBUTE11_NUMBER, ATTRIBUTE12_NUMBER, ATTRIBUTE13_NUMBER, ATTRIBUTE14_NUMBER, ATTRIBUTE15_NUMBER,
                    ATTRIBUTE1_DATE,  ATTRIBUTE2_DATE,  ATTRIBUTE3_DATE,  ATTRIBUTE4_DATE,  ATTRIBUTE5_DATE,
                    ATTRIBUTE6_DATE,  ATTRIBUTE7_DATE,  ATTRIBUTE8_DATE,  ATTRIBUTE9_DATE,  ATTRIBUTE10_DATE,
                    ATTRIBUTE11_DATE, ATTRIBUTE12_DATE, ATTRIBUTE13_DATE, ATTRIBUTE14_DATE, ATTRIBUTE15_DATE,
                    -- Additional task columns
                    ORGANIZATION_NAME,
                    FINANCIAL_TASK,
                    PLANNED_EFFORT,
                    PLANNED_DURATION,
                    REQMNT_CODE,
                    SPRINT,
                    PRIORITY,
                    SCHEDULE_MODE,
                    BASELINE_START_DATE,
                    BASELINE_FINISH_DATE,
                    BASELINE_EFFORT,
                    BASELINE_DURATION,
                    BASELINE_ALLOCATION,
                    CONSTRAINT_TYPE,
                    CONSTRAINT_DATE,
                    BASELINE_LABOR_COST_AMOUNT,
                    BASELINE_LABOR_BILLED_AMOUNT,
                    BASELINE_EXPENSE_COST_AMOUNT,
                    PROCESSING_MODE,
                    -- Pipeline columns
                    STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    NULL,

                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.PROJECT_NAME, 240),
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.PROJECT_NUMBER, 25),
                    s.TASK_NAME,
                    s.TASK_NUMBER,
                    s.TASK_DESCRIPTION,
                    s.PARENT_TASK_NUMBER,
                    s.PLANNING_START_DATE,
                    s.PLANNING_END_DATE,
                    s.MILESTONE_FLAG,
                    s.CRITICAL_FLAG,
                    s.CHARGEABLE_FLAG,
                    s.BILLABLE_FLAG,
                    s.CAPITALIZABLE_FLAG,
                    s.LIMIT_TO_TXN_CONTROLS_FLAG,
                    s.SOURCE_TASK_REFERENCE,
                    s.SOURCE_APPLICATION_CODE,
                    s.SERVICE_TYPE_CODE,
                    s.WORK_TYPE_ID,
                    s.MANAGER_PERSON_ID,
                    s.ALLOW_CROSS_CHARGE_FLAG,
                    s.CC_PROCESS_LABOR_FLAG,
                    s.CC_PROCESS_NL_FLAG,
                    s.RECEIVE_PROJECT_INVOICE_FLAG,

                    s.ATTRIBUTE_CATEGORY,
                    s.ATTRIBUTE1,  s.ATTRIBUTE2,  s.ATTRIBUTE3,  s.ATTRIBUTE4,  s.ATTRIBUTE5,
                    s.ATTRIBUTE6,  s.ATTRIBUTE7,  s.ATTRIBUTE8,  s.ATTRIBUTE9,  s.ATTRIBUTE10,
                    s.ATTRIBUTE11, s.ATTRIBUTE12, s.ATTRIBUTE13, s.ATTRIBUTE14, s.ATTRIBUTE15,
                    s.ATTRIBUTE16, s.ATTRIBUTE17, s.ATTRIBUTE18, s.ATTRIBUTE19, s.ATTRIBUTE20,
                    s.ATTRIBUTE21, s.ATTRIBUTE22, s.ATTRIBUTE23, s.ATTRIBUTE24, s.ATTRIBUTE25,
                    s.ATTRIBUTE26, s.ATTRIBUTE27, s.ATTRIBUTE28, s.ATTRIBUTE29, s.ATTRIBUTE30,
                    s.ATTRIBUTE31, s.ATTRIBUTE32, s.ATTRIBUTE33, s.ATTRIBUTE34, s.ATTRIBUTE35,
                    s.ATTRIBUTE36, s.ATTRIBUTE37, s.ATTRIBUTE38, s.ATTRIBUTE39, s.ATTRIBUTE40,
                    s.ATTRIBUTE41, s.ATTRIBUTE42, s.ATTRIBUTE43, s.ATTRIBUTE44, s.ATTRIBUTE45,
                    s.ATTRIBUTE46, s.ATTRIBUTE47, s.ATTRIBUTE48, s.ATTRIBUTE49, s.ATTRIBUTE50,
                    s.ATTRIBUTE1_NUMBER,  s.ATTRIBUTE2_NUMBER,  s.ATTRIBUTE3_NUMBER,  s.ATTRIBUTE4_NUMBER,  s.ATTRIBUTE5_NUMBER,
                    s.ATTRIBUTE6_NUMBER,  s.ATTRIBUTE7_NUMBER,  s.ATTRIBUTE8_NUMBER,  s.ATTRIBUTE9_NUMBER,  s.ATTRIBUTE10_NUMBER,
                    s.ATTRIBUTE11_NUMBER, s.ATTRIBUTE12_NUMBER, s.ATTRIBUTE13_NUMBER, s.ATTRIBUTE14_NUMBER, s.ATTRIBUTE15_NUMBER,
                    s.ATTRIBUTE1_DATE,  s.ATTRIBUTE2_DATE,  s.ATTRIBUTE3_DATE,  s.ATTRIBUTE4_DATE,  s.ATTRIBUTE5_DATE,
                    s.ATTRIBUTE6_DATE,  s.ATTRIBUTE7_DATE,  s.ATTRIBUTE8_DATE,  s.ATTRIBUTE9_DATE,  s.ATTRIBUTE10_DATE,
                    s.ATTRIBUTE11_DATE, s.ATTRIBUTE12_DATE, s.ATTRIBUTE13_DATE, s.ATTRIBUTE14_DATE, s.ATTRIBUTE15_DATE,

                    s.ORGANIZATION_NAME,
                    s.FINANCIAL_TASK,
                    s.PLANNED_EFFORT,
                    s.PLANNED_DURATION,
                    s.REQMNT_CODE,
                    s.SPRINT,
                    s.PRIORITY,
                    s.SCHEDULE_MODE,
                    s.BASELINE_START_DATE,
                    s.BASELINE_FINISH_DATE,
                    s.BASELINE_EFFORT,
                    s.BASELINE_DURATION,
                    s.BASELINE_ALLOCATION,
                    s.CONSTRAINT_TYPE,
                    s.CONSTRAINT_DATE,
                    s.BASELINE_LABOR_COST_AMOUNT,
                    s.BASELINE_LABOR_BILLED_AMOUNT,
                    s.BASELINE_EXPENSE_COST_AMOUNT,
                    s.PROCESSING_MODE,

                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_PJF_TASKS_STG_TBL s
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
            SELECT 1 FROM DMT_OWNER.DMT_PJF_TASKS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_OWNER.DMT_PJF_TASKS_STG_TBL s
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
            SELECT 1 FROM DMT_OWNER.DMT_PJF_TASKS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_TASKS complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_TASKS');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_TASKS failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_TASKS',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_TASKS;


    -- ============================================================
    -- TRANSFORM_TEAM_MEMBERS
    -- ============================================================
    PROCEDURE TRANSFORM_TEAM_MEMBERS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_prefix     VARCHAR2(30);
        l_ok_count   NUMBER := 0;
        l_fail_count NUMBER := 0;

    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_TEAM_MEMBERS start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_TEAM_MEMBERS');

        l_prefix := get_prefix(p_run_id);


        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_OWNER.DMT_PJF_TEAM_MEMBERS_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_OWNER.DMT_PJF_TEAM_MEMBERS_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    FBDI_CSV_ID,
                    -- Business columns (team members link via PROJECT_NAME, not PROJECT_NUMBER)
                    PROJECT_NAME,
                    TEAM_MEMBER_NUMBER,
                    TEAM_MEMBER_NAME,
                    TEAM_MEMBER_EMAIL,
                    PROJECT_ROLE_NAME,
                    START_DATE_ACTIVE,
                    END_DATE_ACTIVE,
                    TRACK_TIME_FLAG,
                    ALLOCATION,
                    EFFORT,
                    COST_RATE,
                    BILL_RATE,
                    ASSIGNMENT_TYPE,
                    BILLABLE_PERCENT,
                    BILLABLE_PERCENT_REASON_CODE,
                    -- Pipeline columns
                    STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    NULL,

                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.PROJECT_NAME, 240),
                    s.TEAM_MEMBER_NUMBER,
                    s.TEAM_MEMBER_NAME,
                    s.TEAM_MEMBER_EMAIL,
                    s.PROJECT_ROLE_NAME,
                    s.START_DATE_ACTIVE,
                    s.END_DATE_ACTIVE,
                    s.TRACK_TIME_FLAG,
                    s.ALLOCATION,
                    s.EFFORT,
                    s.COST_RATE,
                    s.BILL_RATE,
                    s.ASSIGNMENT_TYPE,
                    s.BILLABLE_PERCENT,
                    s.BILLABLE_PERCENT_REASON_CODE,

                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_PJF_TEAM_MEMBERS_STG_TBL s
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
            SELECT 1 FROM DMT_OWNER.DMT_PJF_TEAM_MEMBERS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_OWNER.DMT_PJF_TEAM_MEMBERS_STG_TBL s
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
            SELECT 1 FROM DMT_OWNER.DMT_PJF_TEAM_MEMBERS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_TEAM_MEMBERS complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_TEAM_MEMBERS');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_TEAM_MEMBERS failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_TEAM_MEMBERS',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_TEAM_MEMBERS;


    -- ============================================================
    -- TRANSFORM_TXN_CONTROLS
    -- ============================================================
    PROCEDURE TRANSFORM_TXN_CONTROLS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_prefix     VARCHAR2(30);
        l_ok_count   NUMBER := 0;
        l_fail_count NUMBER := 0;

    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_TXN_CONTROLS start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_TXN_CONTROLS');

        l_prefix := get_prefix(p_run_id);


        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_OWNER.DMT_PJC_TXN_CONTROLS_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_OWNER.DMT_PJC_TXN_CONTROLS_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    FBDI_CSV_ID,
                    -- Business columns
                    TXN_CTRL_REFERENCE,
                    PROJECT_NAME,
                    PROJECT_NUMBER,
                    TASK_NUMBER,
                    TASK_NAME,
                    EXPENDITURE_CATEGORY_NAME,
                    EXPENDITURE_TYPE,
                    NON_LABOR_RESOURCE,
                    PERSON_NUMBER,
                    PERSON_NAME,
                    PERSON_EMAILID,
                    PERSON_TYPE,
                    JOB_NAME,
                    ORGANIZATION_NAME,
                    CHARGEABLE_FLAG,
                    BILLABLE_FLAG,
                    CAPITALIZABLE_FLAG,
                    START_DATE_ACTIVE,
                    END_DATE_ACTIVE,
                    -- Pipeline columns
                    STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    NULL,

                    s.TXN_CTRL_REFERENCE,
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.PROJECT_NAME, 240),
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.PROJECT_NUMBER, 25),
                    s.TASK_NUMBER,
                    s.TASK_NAME,
                    s.EXPENDITURE_CATEGORY_NAME,
                    s.EXPENDITURE_TYPE,
                    s.NON_LABOR_RESOURCE,
                    s.PERSON_NUMBER,
                    s.PERSON_NAME,
                    s.PERSON_EMAILID,
                    s.PERSON_TYPE,
                    s.JOB_NAME,
                    s.ORGANIZATION_NAME,
                    s.CHARGEABLE_FLAG,
                    s.BILLABLE_FLAG,
                    s.CAPITALIZABLE_FLAG,
                    s.START_DATE_ACTIVE,
                    s.END_DATE_ACTIVE,

                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_PJC_TXN_CONTROLS_STG_TBL s
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
            SELECT 1 FROM DMT_OWNER.DMT_PJC_TXN_CONTROLS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_OWNER.DMT_PJC_TXN_CONTROLS_STG_TBL s
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
            SELECT 1 FROM DMT_OWNER.DMT_PJC_TXN_CONTROLS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_TXN_CONTROLS complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_TXN_CONTROLS');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_TXN_CONTROLS failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_TXN_CONTROLS',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_TXN_CONTROLS;

END DMT_PROJECT_TRANSFORM_PKG;
/
