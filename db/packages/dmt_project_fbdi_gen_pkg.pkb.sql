-- PACKAGE BODY DMT_PROJECT_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_PROJECT_FBDI_GEN_PKG" 
AS
    C_PKG CONSTANT VARCHAR2(50) := 'DMT_PROJECT_FBDI_GEN_PKG';

-- ============================================================
-- DMT_PROJECT_FBDI_GEN_PKG body
-- Projects FBDI zip generation.
-- ONE zip with 4 CSVs, ONE ESS job (ImportProjects).
-- No multi-BU grouping needed.
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
    -- Private: generate PjfProjectsAllXface.csv CLOB
    -- --------------------------------------------------------
    FUNCTION gen_projects_csv (
        p_run_id IN NUMBER
    ) RETURN CLOB
    IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        FOR r IN (
            SELECT
                '"' || REPLACE(NVL(PROJECT_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PROJECT_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SOURCE_TEMPLATE_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SOURCE_APPLICATION_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SOURCE_PROJECT_REFERENCE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ORGANIZATION_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LEGAL_ENTITY_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DESCRIPTION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PROJECT_MANAGER_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PROJECT_MANAGER_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PROJECT_MANAGER_EMAIL,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(PROJECT_START_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(PROJECT_FINISH_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(CLOSED_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(PROJECT_STATUS_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PROJECT_PRIORITY_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(OUTLINE_DISPLAY_LEVEL,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PLANNING_PROJECT_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SERVICE_TYPE_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(WORK_TYPE_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LIMIT_TO_TXN_CONTROLS_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PROJECT_CURRENCY_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CURRENCY_CONV_RATE_TYPE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CURRENCY_CONV_DATE_TYPE_CODE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(CURRENCY_CONV_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(CINT_ELIGIBLE_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CINT_RATE_SCH_NAME,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(CINT_STOP_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(ASSET_ALLOCATION_METHOD_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CAPITAL_EVENT_PROCESSING_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ALLOW_CROSS_CHARGE_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CC_PROCESS_LABOR_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LABOR_TP_SCHEDULE_NAME,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(LABOR_TP_FIXED_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(CC_PROCESS_NL_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(NL_TP_SCHEDULE_NAME,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(NL_TP_FIXED_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(BURDEN_SCHEDULE_NAME,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(BURDEN_SCH_FIXED_DATED, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(KPI_NOTIFICATION_ENABLED,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(KPI_NOTIFICATION_RECIPIENTS,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(KPI_NOTIFICATION_INCLUDE_NOTES,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(COPY_TEAM_MEMBERS_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(COPY_PROJECT_CLASSES_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(COPY_ATTACHMENTS_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(COPY_DFF_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(COPY_GROUP_SPACE_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(COPY_TASKS_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(COPY_TASK_ATTACHMENTS_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(COPY_TASK_DFF_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(COPY_TASK_ASSIGNMENTS_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(COPY_TRANSACTION_CONTROLS_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(COPY_ASSETS_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(COPY_ASSET_ASSIGNMENTS_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(COPY_COST_OVERRIDES_FLAG,''), '"', '""') || '"' || ','
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
                || '"' || REPLACE(NVL(ATTRIBUTE21,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE22,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE23,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE24,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE25,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE26,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE27,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE28,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE29,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE30,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE31,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE32,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE33,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE34,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE35,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE36,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE37,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE38,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE39,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE40,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE41,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE42,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE43,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE44,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE45,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE46,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE47,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE48,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE49,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE50,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE1_NUMBER), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE2_NUMBER), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE3_NUMBER), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE4_NUMBER), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE5_NUMBER), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE6_NUMBER), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE7_NUMBER), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE8_NUMBER), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE9_NUMBER), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE10_NUMBER), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE11_NUMBER), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE12_NUMBER), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE13_NUMBER), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE14_NUMBER), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE15_NUMBER), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE1_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE2_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE3_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE4_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE5_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE6_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE7_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE8_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE9_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE10_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE11_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE12_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE13_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE14_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE15_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(SCHEDULE_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(EPS_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PROJECT_PLAN_VIEW_ACCESS,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SCHEDULE_TYPE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(OPPORTUNITY_ID,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(OPPORTUNITY_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(OPPORTUNITY_CUSTOMER_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(OPPORTUNITY_CUSTOMER_ID,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(OPPORTUNITY_AMT), '') || '"' || ','
                || '"' || REPLACE(NVL(OPPORTUNITY_CURRCODE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(OPPORTUNITY_WIN_CONF_PERCENT), '') || '"' || ','
                || '"' || REPLACE(NVL(OPPORTUNITY_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(OPPORTUNITY_DESC,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(OPPORTUNITY_CUSTOMER_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(OPPORTUNITY_STATUS,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PRJ_PLAN_BASELINE_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PRJ_PLAN_BASELINE_DESC,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(PRJ_PLAN_BASELINE_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(BUDGETARY_CONTROL_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SOURCE_TEMPLATE_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CASCADE_OPTION,''), '"', '""') || '"' || CHR(10) AS csv_line
            FROM   DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id
            AND    t.STATUS = 'STAGED'
            ORDER BY t.TFM_SEQUENCE_ID
                    ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;

        RETURN l_csv;
    END gen_projects_csv;

    -- --------------------------------------------------------
    -- Private: generate PjfProjElementsXface.csv CLOB (Tasks)
    -- --------------------------------------------------------
    FUNCTION gen_tasks_csv (
        p_run_id IN NUMBER
    ) RETURN CLOB
    IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        FOR r IN (
            SELECT
                '"' || REPLACE(NVL(PROJECT_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PROJECT_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TASK_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TASK_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TASK_DESCRIPTION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PARENT_TASK_NUMBER,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(PLANNING_START_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(PLANNING_END_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(MILESTONE_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CRITICAL_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CHARGEABLE_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(BILLABLE_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CAPITALIZABLE_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LIMIT_TO_TXN_CONTROLS_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SOURCE_TASK_REFERENCE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SOURCE_APPLICATION_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SERVICE_TYPE_CODE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(WORK_TYPE_ID), '') || '"' || ','
                || '"' || NVL(TO_CHAR(MANAGER_PERSON_ID), '') || '"' || ','
                || '"' || REPLACE(NVL(ALLOW_CROSS_CHARGE_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CC_PROCESS_LABOR_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CC_PROCESS_NL_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(RECEIVE_PROJECT_INVOICE_FLAG,''), '"', '""') || '"' || ','
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
                || '"' || REPLACE(NVL(ATTRIBUTE21,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE22,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE23,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE24,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE25,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE26,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE27,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE28,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE29,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE30,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE31,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE32,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE33,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE34,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE35,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE36,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE37,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE38,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE39,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE40,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE41,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE42,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE43,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE44,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE45,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE46,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE47,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE48,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE49,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE50,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE1_NUMBER), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE2_NUMBER), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE3_NUMBER), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE4_NUMBER), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE5_NUMBER), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE6_NUMBER), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE7_NUMBER), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE8_NUMBER), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE9_NUMBER), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE10_NUMBER), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE11_NUMBER), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE12_NUMBER), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE13_NUMBER), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE14_NUMBER), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE15_NUMBER), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE1_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE2_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE3_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE4_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE5_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE6_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE7_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE8_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE9_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE10_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE11_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE12_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE13_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE14_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE15_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(ORGANIZATION_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(FINANCIAL_TASK,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(PLANNED_EFFORT), '') || '"' || ','
                || '"' || NVL(TO_CHAR(PLANNED_DURATION), '') || '"' || ','
                || '"' || REPLACE(NVL(REQMNT_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SPRINT,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PRIORITY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SCHEDULE_MODE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(BASELINE_START_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(BASELINE_FINISH_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(BASELINE_EFFORT), '') || '"' || ','
                || '"' || NVL(TO_CHAR(BASELINE_DURATION), '') || '"' || ','
                || '"' || NVL(TO_CHAR(BASELINE_ALLOCATION), '') || '"' || ','
                || '"' || REPLACE(NVL(CONSTRAINT_TYPE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(CONSTRAINT_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(BASELINE_LABOR_COST_AMOUNT), '') || '"' || ','
                || '"' || NVL(TO_CHAR(BASELINE_LABOR_BILLED_AMOUNT), '') || '"' || ','
                || '"' || NVL(TO_CHAR(BASELINE_EXPENSE_COST_AMOUNT), '') || '"' || CHR(10) AS csv_line
            FROM   DMT_OWNER.DMT_PJF_TASKS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id
            AND    t.STATUS = 'STAGED'
            ORDER BY t.TFM_SEQUENCE_ID
                    ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;

        RETURN l_csv;
    END gen_tasks_csv;

    -- --------------------------------------------------------
    -- Private: generate PjfProjectPartiesInt.csv CLOB (Team Members)
    -- --------------------------------------------------------
    FUNCTION gen_team_members_csv (
        p_run_id IN NUMBER
    ) RETURN CLOB
    IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        FOR r IN (
            SELECT
                '"' || REPLACE(NVL(PROJECT_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TEAM_MEMBER_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TEAM_MEMBER_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TEAM_MEMBER_EMAIL,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PROJECT_ROLE_NAME,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(START_DATE_ACTIVE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(END_DATE_ACTIVE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(TRACK_TIME_FLAG,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(ALLOCATION), '') || '"' || ','
                || '"' || NVL(TO_CHAR(EFFORT), '') || '"' || ','
                || '"' || NVL(TO_CHAR(COST_RATE), '') || '"' || ','
                || '"' || NVL(TO_CHAR(BILL_RATE), '') || '"' || ','
                || '"' || REPLACE(NVL(ASSIGNMENT_TYPE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(BILLABLE_PERCENT), '') || '"' || ','
                || '"' || REPLACE(NVL(BILLABLE_PERCENT_REASON_CODE,''), '"', '""') || '"' || CHR(10) AS csv_line
            FROM   DMT_OWNER.DMT_PJF_TEAM_MEMBERS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id
            AND    t.STATUS = 'STAGED'
            ORDER BY t.TFM_SEQUENCE_ID
                    ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;

        RETURN l_csv;
    END gen_team_members_csv;

    -- --------------------------------------------------------
    -- Private: generate PjcTxnControlsStage.csv CLOB (Txn Controls)
    -- --------------------------------------------------------
    FUNCTION gen_txn_controls_csv (
        p_run_id IN NUMBER
    ) RETURN CLOB
    IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        FOR r IN (
            SELECT
                '"' || REPLACE(NVL(TXN_CTRL_REFERENCE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PROJECT_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PROJECT_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TASK_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TASK_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(EXPENDITURE_CATEGORY_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(EXPENDITURE_TYPE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(NON_LABOR_RESOURCE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PERSON_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PERSON_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PERSON_EMAILID,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PERSON_TYPE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(JOB_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ORGANIZATION_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CHARGEABLE_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(BILLABLE_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CAPITALIZABLE_FLAG,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(START_DATE_ACTIVE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(END_DATE_ACTIVE, 'YYYY/MM/DD'), '') || '"' || CHR(10) AS csv_line
            FROM   DMT_OWNER.DMT_PJC_TXN_CONTROLS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id
            AND    t.STATUS = 'STAGED'
            ORDER BY t.TFM_SEQUENCE_ID
                    ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;

        RETURN l_csv;
    END gen_txn_controls_csv;

    -- ============================================================
    -- GENERATE_FBDI
    -- Builds 4 CSVs, zips them, registers in FBDI tables,
    -- updates TFM rows to GENERATED.
    -- ============================================================
    PROCEDURE GENERATE_FBDI (
        p_run_id IN  NUMBER,
        x_fbdi_zip       OUT BLOB,
        x_filename       OUT VARCHAR2,
        x_fbdi_csv_id    OUT NUMBER
    )
    IS
        l_zip              BLOB;
        l_projects_csv     CLOB;
        l_tasks_csv        CLOB;
        l_team_csv         CLOB;
        l_txn_csv          CLOB;
        l_fbdi_csv_id      NUMBER;
        l_now              DATE := SYSDATE;
        C_PROC CONSTANT VARCHAR2(30) := 'GENERATE_FBDI';
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Project FBDI generation start.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        x_filename := 'Projects_' || TO_CHAR(p_run_id) || '.zip';

        -- Generate all 4 CSVs
        l_projects_csv := gen_projects_csv(p_run_id);
        l_tasks_csv    := gen_tasks_csv(p_run_id);
        l_team_csv     := gen_team_members_csv(p_run_id);
        l_txn_csv      := gen_txn_controls_csv(p_run_id);

        DMT_UTIL_PKG.LOG(p_run_id,
            'GENERATE_FBDI CSV lengths: projects=' || NVL(DBMS_LOB.GETLENGTH(l_projects_csv), 0) ||
            ' tasks=' || NVL(DBMS_LOB.GETLENGTH(l_tasks_csv), 0) ||
            ' team=' || NVL(DBMS_LOB.GETLENGTH(l_team_csv), 0) ||
            ' txn=' || NVL(DBMS_LOB.GETLENGTH(l_txn_csv), 0),
            'INFO', 'DMT_PROJECT_FBDI_GEN_PKG', 'GENERATE_FBDI');

        -- AD#20: Skip gracefully if no rows generated (projects is the primary CSV)
        IF (l_projects_csv IS NULL OR DBMS_LOB.GETLENGTH(l_projects_csv) = 0) THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'No STAGED Project rows found. Skipping FBDI generation.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            DBMS_LOB.FREETEMPORARY(l_projects_csv);
            DBMS_LOB.FREETEMPORARY(l_tasks_csv);
            DBMS_LOB.FREETEMPORARY(l_team_csv);
            DBMS_LOB.FREETEMPORARY(l_txn_csv);
            x_fbdi_zip := NULL;
            x_filename := NULL;
            x_fbdi_csv_id := NULL;
            RETURN;
        END IF;

        -- Build zip using Anton Scheffer UTL_ZIP (skip empty CSVs)
        DBMS_LOB.CREATETEMPORARY(l_zip, TRUE);
        IF DBMS_LOB.GETLENGTH(l_projects_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'PjfProjectsAllXface.csv',
                clob_to_blob(l_projects_csv));
        END IF;
        IF DBMS_LOB.GETLENGTH(l_tasks_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'PjfProjElementsXface.csv',
                clob_to_blob(l_tasks_csv));
        END IF;
        IF DBMS_LOB.GETLENGTH(l_team_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'PjfProjectPartiesInt.csv',
                clob_to_blob(l_team_csv));
        END IF;
        IF DBMS_LOB.GETLENGTH(l_txn_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'PjcTxnControlsStage.csv',
                clob_to_blob(l_txn_csv));
        END IF;
        DMT_OWNER.UTL_ZIP.finish_zip(l_zip);

        -- Register in DMT_FBDI_CSV_TBL
        SELECT DMT_OWNER.DMT_FBDI_CSV_ID_SEQ.NEXTVAL INTO l_fbdi_csv_id FROM DUAL;
        INSERT INTO DMT_OWNER.DMT_FBDI_CSV_TBL (
            FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME, ROW_COUNT,
            CSV_CONTENT, CREATED_DATE
        ) VALUES (
            l_fbdi_csv_id, p_run_id,
            'Projects',
            x_filename, 0, l_projects_csv, l_now
        );

        -- Register in DMT_FBDI_ZIP_TBL
        INSERT INTO DMT_OWNER.DMT_FBDI_ZIP_TBL (
            FBDI_ZIP_ID, FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME,
            ZIP_SIZE_BYTES, ZIP_CONTENT, CREATED_DATE
        ) VALUES (
            DMT_OWNER.DMT_FBDI_ZIP_ID_SEQ.NEXTVAL, l_fbdi_csv_id, p_run_id,
            'Projects',
            x_filename,
            DBMS_LOB.GETLENGTH(l_zip), l_zip, l_now
        );

        -- Update all 4 TFM tables to GENERATED and stamp FBDI_CSV_ID
        UPDATE DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL
        SET    STATUS = 'GENERATED', FBDI_CSV_ID = l_fbdi_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND STATUS = 'STAGED';

        UPDATE DMT_OWNER.DMT_PJF_TASKS_TFM_TBL
        SET    STATUS = 'GENERATED', FBDI_CSV_ID = l_fbdi_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND STATUS = 'STAGED';

        UPDATE DMT_OWNER.DMT_PJF_TEAM_MEMBERS_TFM_TBL
        SET    STATUS = 'GENERATED', FBDI_CSV_ID = l_fbdi_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND STATUS = 'STAGED';

        UPDATE DMT_OWNER.DMT_PJC_TXN_CONTROLS_TFM_TBL
        SET    STATUS = 'GENERATED', FBDI_CSV_ID = l_fbdi_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND STATUS = 'STAGED';

        -- Free temporary CLOBs
        DBMS_LOB.FREETEMPORARY(l_projects_csv);
        DBMS_LOB.FREETEMPORARY(l_tasks_csv);
        DBMS_LOB.FREETEMPORARY(l_team_csv);
        DBMS_LOB.FREETEMPORARY(l_txn_csv);

        x_fbdi_zip    := l_zip;
        x_fbdi_csv_id := l_fbdi_csv_id;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Project FBDI generation complete.' ||
                                ' | File: ' || x_filename ||
                                ' | Zip bytes: ' || DBMS_LOB.GETLENGTH(x_fbdi_zip),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'Project FBDI generation failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END GENERATE_FBDI;

END DMT_PROJECT_FBDI_GEN_PKG;
/
