-- PACKAGE BODY DMT_GRANTS_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_GRANTS_FBDI_GEN_PKG" 
AS
    C_PKG CONSTANT VARCHAR2(50) := 'DMT_GRANTS_FBDI_GEN_PKG';

-- ============================================================
-- DMT_GRANTS_FBDI_GEN_PKG body
-- Grants FBDI zip generation.
-- ONE zip with 15 CSVs, ONE ESS job (ImportAward).
-- UCM account: prj/grantsManagement/import
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

    PROCEDURE append_csv_field (
        p_clob   IN OUT NOCOPY CLOB,
        p_value  IN VARCHAR2,
        p_last   IN BOOLEAN DEFAULT FALSE
    ) IS
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

    FUNCTION fmt_date(p_date IN DATE) RETURN VARCHAR2 IS
    BEGIN
        -- Grants CTL uses MM/DD/YYYY format (NOT YYYY/MM/DD like RCV CTLs)
        RETURN TO_CHAR(p_date, 'MM/DD/YYYY');
    END fmt_date;

    -- ============================================================
    -- 1. GmsAwardHeadersInterface.csv
    -- ============================================================
    FUNCTION gen_headers_csv (p_run_id IN NUMBER) RETURN CLOB IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);
        FOR r IN (
            SELECT
                '"' || REPLACE(NVL(AWARD_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(AWARD_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SOURCE_TEMPLATE_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(BUSINESS_UNIT,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LEGAL_ENTITY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CONTRACT_TYPE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PRIMARY_SPONSOR,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PRINCIPAL_INVESTIGATOR_EMAIL,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PI_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PI_NUMBER,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(AWARD_START_DATE, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(AWARD_END_DATE, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || REPLACE(NVL(AWARD_DESCRIPTION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ORGANIZATION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INSTITUTION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SPONSOR_AWARD_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(AWARD_PURPOSE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(AWARD_TYPE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(EXPANDED_AUTHORITY_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(COST_SHARE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DEFAULT_BURDEN_SCHEDULE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(FIXED_DATE, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(PRE_AWARD_DATE, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || REPLACE(NVL(PRE_AWARD_SPENDING_ALLOWED,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PRE_AWARD_GSF,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(CLOSE_DATE, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || REPLACE(NVL(COI_INST_POLICY_COMPLIANT,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(COI_REVIEW_COMPLETED,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(COI_APPROVAL_DATE, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || REPLACE(NVL(FT_PRIMARY_SPONSOR,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(FT_REF_AWARD_NAME,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(FT_FROM_DATE, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(FT_TO_DATE, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || REPLACE(NVL(FT_AMOUNT,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(FT_IS_FEDERAL,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(IS_INTELL_PROP_REPORTED,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTELL_PROP_DESC,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PREV_AWARD_BU,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PREV_AWARD_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PREV_AWARD_RENEWAL_INPRG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PREV_AWARD_ABR,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(COST_SHARE_REQ_BY_SPONSOR,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(COST_SHARE_APPROVED_BY,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(COST_SHARE_APPROVAL_DATE, 'MM/DD/YYYY'), '') || '"' || ','
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
                || '"' || REPLACE(NVL(ATTRIBUTE_NUMBER1,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_NUMBER2,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_NUMBER3,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_NUMBER4,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_NUMBER5,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_NUMBER6,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_NUMBER7,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_NUMBER8,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_NUMBER9,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_NUMBER10,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE1, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE2, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE3, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE4, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE5, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE6, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE7, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE8, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE9, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE10, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP1, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP2, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP3, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP4, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP5, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP6, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP7, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP8, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP9, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP10, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || REPLACE(NVL(CONTRACT_STATUS,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CONTRACT_LINE_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LOC_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DOC_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(FED_INVOICE_FORMAT,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(BILL_PLAN_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(REVENUE_PLAN_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INVOICE_METHOD,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(REVENUE_METHOD,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(BILLING_CYCLE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PAYMENT_TERM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LABOR_FORMAT,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(NON_LABOR_FORMAT,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(EVENT_FORMAT,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CURRENCY_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PRIMARY_SPONSOR_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(FT_PRIMARY_SPONSOR_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(NET_INVOICE_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INV_HDR_GROUPING_OPTIONS,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(BILL_TO_SITE_LOCATION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(BILL_TO_CONTACT_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(BILL_TO_CONTACT_EMAIL,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SHIP_TO_SITE_LOCATION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(BILL_SET_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(GENERATED_INVOICE_STATUS,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INV_TRX_TYPE_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(BILL_TO_ACCT_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SHIP_TO_ACCT_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PREPAY_TRX_TYPE_NAME,''), '"', '""') || '"' || CHR(10) AS csv_line
            FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL t
            WHERE t.RUN_ID = p_run_id AND t.TFM_STATUS = 'STAGED'
            ORDER BY t.TFM_SEQUENCE_ID
        ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;
        RETURN l_csv;
    END gen_headers_csv;

    -- ============================================================
    -- 2. GmsAwardFundingInterface.csv
    -- ============================================================
    FUNCTION gen_funding_csv (p_run_id IN NUMBER) RETURN CLOB IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);
        FOR r IN (
            SELECT
                '"' || REPLACE(NVL(AWARD_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(BUDGET_PERIOD_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(FUNDING_SOURCE_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ISSUE_TYPE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ISSUE_NUMBER,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(ISSUE_DATE, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || REPLACE(NVL(ISSUE_DESCRIPTION,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(DIRECT_FUNDING_AMOUNT), '') || '"' || ','
                || '"' || NVL(TO_CHAR(INDIRECT_FUNDING_AMOUNT), '') || '"' || ','
                || '"' || REPLACE(NVL(FUNDING_SOURCE_NUMBER,''), '"', '""') || '"' || CHR(10) AS csv_line
            FROM DMT_OWNER.DMT_GMS_AWD_FUNDING_TFM_TBL t
            WHERE t.RUN_ID = p_run_id AND t.TFM_STATUS = 'STAGED' ORDER BY t.TFM_SEQUENCE_ID
        ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;
        RETURN l_csv;
    END gen_funding_csv;

    -- ============================================================
    -- 3. GmsAwardProjectsInterface.csv
    -- ============================================================
    FUNCTION gen_projects_csv (p_run_id IN NUMBER) RETURN CLOB IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);
        FOR r IN (
            SELECT
                '"' || REPLACE(NVL(AWARD_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(FUNDING_SOURCE_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PROJECT_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(AWARD_PRJ_BRD_SCHEDULE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(FIXED_DATE, 'MM/DD/YYYY'), '') || '"' || ','
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
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE1, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE2, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE3, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE4, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE5, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE6, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE7, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE8, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE9, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE10, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP1, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP2, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP3, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP4, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP5, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP6, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP7, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP8, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP9, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP10, 'MM/DD/YYYY'), '') || '"' || CHR(10) AS csv_line
            FROM DMT_OWNER.DMT_GMS_AWD_PROJECTS_TFM_TBL t
            WHERE t.RUN_ID = p_run_id AND t.TFM_STATUS = 'STAGED' ORDER BY t.TFM_SEQUENCE_ID
        ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;
        RETURN l_csv;
    END gen_projects_csv;

    -- ============================================================
    -- 4. GmsAwardPersonnelInterface.csv
    -- ============================================================
    FUNCTION gen_personnel_csv (p_run_id IN NUMBER) RETURN CLOB IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);
        FOR r IN (
            SELECT
                '"' || REPLACE(NVL(AWARD_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PROJECT_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INTERNAL,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PERSON_EMAIL,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PERSON_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PERSON_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ROLE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(START_DATE, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(END_DATE, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(CREDIT_PERCENTAGE), '') || '"' || ','
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
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE1, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE2, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE3, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE4, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE5, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE6, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE7, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE8, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE9, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE10, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP1, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP2, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP3, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP4, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP5, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP6, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP7, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP8, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP9, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP10, 'MM/DD/YYYY'), '') || '"' || CHR(10) AS csv_line
            FROM DMT_OWNER.DMT_GMS_AWD_PERSONNEL_TFM_TBL t
            WHERE t.RUN_ID = p_run_id AND t.TFM_STATUS = 'STAGED' ORDER BY t.TFM_SEQUENCE_ID
        ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;
        RETURN l_csv;
    END gen_personnel_csv;

    -- ============================================================
    -- 5. GmsAwardFundSrcInterface.csv
    -- ============================================================
    FUNCTION gen_fund_src_csv (p_run_id IN NUMBER) RETURN CLOB IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);
        FOR r IN (
            SELECT
                '"' || REPLACE(NVL(AWARD_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(FUNDING_SOURCE_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(FUNDING_SOURCE_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(COST_SHARE_REQ_BY_SPONSOR,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(COST_SHARE_APPROVED_BY_EMAIL,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(COST_SHARE_APPROVED_BY_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(COST_SHARE_APPROVED_BY_NUMBER,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(COST_SHARE_APPROVAL_DATE, 'MM/DD/YYYY'), '') || '"' || CHR(10) AS csv_line
            FROM DMT_OWNER.DMT_GMS_AWD_FUND_SRC_TFM_TBL t
            WHERE t.RUN_ID = p_run_id AND t.TFM_STATUS = 'STAGED' ORDER BY t.TFM_SEQUENCE_ID
        ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;
        RETURN l_csv;
    END gen_fund_src_csv;

    -- ============================================================
    -- 6. GmsAwardPrjFundSrcInterface.csv
    -- ============================================================
    FUNCTION gen_prj_fund_src_csv (p_run_id IN NUMBER) RETURN CLOB IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);
        FOR r IN (
            SELECT
                '"' || REPLACE(NVL(AWARD_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PROJECT_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(FUNDING_SOURCE_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(FUNDING_SOURCE_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ENABLE_BURDENING_FLAG,''), '"', '""') || '"' || CHR(10) AS csv_line
            FROM DMT_OWNER.DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL t
            WHERE t.RUN_ID = p_run_id AND t.TFM_STATUS = 'STAGED' ORDER BY t.TFM_SEQUENCE_ID
        ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;
        RETURN l_csv;
    END gen_prj_fund_src_csv;

    -- ============================================================
    -- 7. GmsAwardKeywordsInterface.csv
    -- ============================================================
    FUNCTION gen_keywords_csv (p_run_id IN NUMBER) RETURN CLOB IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);
        FOR r IN (
            SELECT
                '"' || REPLACE(NVL(AWARD_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PROJECT_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(KEYWORD_NAME,''), '"', '""') || '"' || CHR(10) AS csv_line
            FROM DMT_OWNER.DMT_GMS_AWD_KEYWORDS_TFM_TBL t
            WHERE t.RUN_ID = p_run_id AND t.TFM_STATUS = 'STAGED' ORDER BY t.TFM_SEQUENCE_ID
        ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;
        RETURN l_csv;
    END gen_keywords_csv;

    -- ============================================================
    -- 8. GmsAwardBudgetPeriodsInterface.csv
    -- ============================================================
    FUNCTION gen_budget_periods_csv (p_run_id IN NUMBER) RETURN CLOB IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);
        FOR r IN (
            SELECT
                '"' || REPLACE(NVL(AWARD_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(BUDGET_PERIOD,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(START_DATE, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(END_DATE, 'MM/DD/YYYY'), '') || '"' || CHR(10) AS csv_line
            FROM DMT_OWNER.DMT_GMS_AWD_BDGT_PRDS_TFM_TBL t
            WHERE t.RUN_ID = p_run_id AND t.TFM_STATUS = 'STAGED' ORDER BY t.TFM_SEQUENCE_ID
        ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;
        RETURN l_csv;
    END gen_budget_periods_csv;

    -- ============================================================
    -- 9. GmsAwardCertsInterface.csv
    -- ============================================================
    FUNCTION gen_certs_csv (p_run_id IN NUMBER) RETURN CLOB IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);
        FOR r IN (
            SELECT
                '"' || REPLACE(NVL(AWARD_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PROJECT_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CERTIFICATION_NAME,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(CERTIFICATION_DATE, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || REPLACE(NVL(CERTIFIED_BY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CERT_STATUS,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(APPROVAL_DATE, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(EXPIRATION_DATE, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || REPLACE(NVL(EXPEDITED_REVIEW,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(FULL_REVIEW,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ASSURANCE_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(EXEMPTION_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(COMMENTS,''), '"', '""') || '"' || CHR(10) AS csv_line
            FROM DMT_OWNER.DMT_GMS_AWD_CERTS_TFM_TBL t
            WHERE t.RUN_ID = p_run_id AND t.TFM_STATUS = 'STAGED' ORDER BY t.TFM_SEQUENCE_ID
        ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;
        RETURN l_csv;
    END gen_certs_csv;

    -- ============================================================
    -- 10. GmsAwardCfdasInterface.csv
    -- ============================================================
    FUNCTION gen_cfdas_csv (p_run_id IN NUMBER) RETURN CLOB IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);
        FOR r IN (
            SELECT
                '"' || REPLACE(NVL(AWARD_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CFDA,''), '"', '""') || '"' || CHR(10) AS csv_line
            FROM DMT_OWNER.DMT_GMS_AWD_CFDAS_TFM_TBL t
            WHERE t.RUN_ID = p_run_id AND t.TFM_STATUS = 'STAGED' ORDER BY t.TFM_SEQUENCE_ID
        ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;
        RETURN l_csv;
    END gen_cfdas_csv;

    -- ============================================================
    -- 11. GmsAwardFundAllocInterface.csv
    -- ============================================================
    FUNCTION gen_fund_alloc_csv (p_run_id IN NUMBER) RETURN CLOB IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);
        FOR r IN (
            SELECT
                '"' || REPLACE(NVL(AWARD_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PROJECT_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ISSUE_NUMBER,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(FUNDING_AMOUNT), '') || '"' || CHR(10) AS csv_line
            FROM DMT_OWNER.DMT_GMS_AWD_FUND_ALLOC_TFM_TBL t
            WHERE t.RUN_ID = p_run_id AND t.TFM_STATUS = 'STAGED' ORDER BY t.TFM_SEQUENCE_ID
        ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;
        RETURN l_csv;
    END gen_fund_alloc_csv;

    -- ============================================================
    -- 12. GmsAwardOrgCreditsInterface.csv
    -- ============================================================
    FUNCTION gen_org_credits_csv (p_run_id IN NUMBER) RETURN CLOB IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);
        FOR r IN (
            SELECT
                '"' || REPLACE(NVL(AWARD_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PROJECT_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ORGANIZATION,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(CREDIT_PERCENTAGE), '') || '"' || CHR(10) AS csv_line
            FROM DMT_OWNER.DMT_GMS_AWD_ORG_CREDITS_TFM_TBL t
            WHERE t.RUN_ID = p_run_id AND t.TFM_STATUS = 'STAGED' ORDER BY t.TFM_SEQUENCE_ID
        ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;
        RETURN l_csv;
    END gen_org_credits_csv;

    -- ============================================================
    -- 13. GmsAwardPrjTaskBurdenInterface.csv
    -- ============================================================
    FUNCTION gen_prj_task_burden_csv (p_run_id IN NUMBER) RETURN CLOB IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);
        FOR r IN (
            SELECT
                '"' || REPLACE(NVL(AWARD_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PROJECT_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TASK_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(BURDEN_SCHEDULE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(FIXED_DATE, 'MM/DD/YYYY'), '') || '"' || CHR(10) AS csv_line
            FROM DMT_OWNER.DMT_GMS_AWD_PRJ_TSK_BRD_TFM_TBL t
            WHERE t.RUN_ID = p_run_id AND t.TFM_STATUS = 'STAGED' ORDER BY t.TFM_SEQUENCE_ID
        ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;
        RETURN l_csv;
    END gen_prj_task_burden_csv;

    -- ============================================================
    -- 14. GmsAwardReferencesInterface.csv
    -- ============================================================
    FUNCTION gen_references_csv (p_run_id IN NUMBER) RETURN CLOB IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);
        FOR r IN (
            SELECT
                '"' || REPLACE(NVL(AWARD_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PROJECT_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(REFERENCE_TYPE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(VALUE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(COMMENTS,''), '"', '""') || '"' || CHR(10) AS csv_line
            FROM DMT_OWNER.DMT_GMS_AWD_REFERENCES_TFM_TBL t
            WHERE t.RUN_ID = p_run_id AND t.TFM_STATUS = 'STAGED' ORDER BY t.TFM_SEQUENCE_ID
        ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;
        RETURN l_csv;
    END gen_references_csv;

    -- ============================================================
    -- 15. GmsAwardTermsInterface.csv
    -- ============================================================
    FUNCTION gen_terms_csv (p_run_id IN NUMBER) RETURN CLOB IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);
        FOR r IN (
            SELECT
                '"' || REPLACE(NVL(AWARD_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TERM_CATEGORY_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TERM_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TERM_DESCRIPTION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TERM_OPERAND,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TERM_VALUE,''), '"', '""') || '"' || CHR(10) AS csv_line
            FROM DMT_OWNER.DMT_GMS_AWD_TERMS_TFM_TBL t
            WHERE t.RUN_ID = p_run_id AND t.TFM_STATUS = 'STAGED' ORDER BY t.TFM_SEQUENCE_ID
        ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;
        RETURN l_csv;
    END gen_terms_csv;


    -- ============================================================
    -- GENERATE_FBDI
    -- Builds 15 CSVs, zips them, registers in FBDI tables,
    -- updates all 15 TFM tables to GENERATED.
    -- ============================================================
    PROCEDURE GENERATE_FBDI (
        p_run_id IN  NUMBER,
        x_fbdi_zip       OUT BLOB,
        x_filename       OUT VARCHAR2,
        x_fbdi_csv_id    OUT NUMBER
    )
    IS
        l_zip           BLOB;
        l_fbdi_csv_id   NUMBER;
        l_now           DATE := SYSDATE;

        l_hdr_csv       CLOB;
        l_fund_csv      CLOB;
        l_proj_csv      CLOB;
        l_pers_csv      CLOB;
        l_fsrc_csv      CLOB;
        l_pfsrc_csv     CLOB;
        l_kw_csv        CLOB;
        l_bdgt_csv      CLOB;
        l_cert_csv      CLOB;
        l_cfda_csv      CLOB;
        l_falloc_csv    CLOB;
        l_orgcr_csv     CLOB;
        l_ptbrd_csv     CLOB;
        l_ref_csv       CLOB;
        l_term_csv      CLOB;
        C_PROC CONSTANT VARCHAR2(30) := 'GENERATE_FBDI';
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Grant FBDI generation start.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        x_filename := 'Grants_' || TO_CHAR(p_run_id) || '.zip';

        -- Generate all 15 CSVs
        l_hdr_csv   := gen_headers_csv(p_run_id);
        l_fund_csv  := gen_funding_csv(p_run_id);
        l_proj_csv  := gen_projects_csv(p_run_id);
        l_pers_csv  := gen_personnel_csv(p_run_id);
        l_fsrc_csv  := gen_fund_src_csv(p_run_id);
        l_pfsrc_csv := gen_prj_fund_src_csv(p_run_id);
        l_kw_csv    := gen_keywords_csv(p_run_id);
        l_bdgt_csv  := gen_budget_periods_csv(p_run_id);
        l_cert_csv  := gen_certs_csv(p_run_id);
        l_cfda_csv  := gen_cfdas_csv(p_run_id);
        l_falloc_csv:= gen_fund_alloc_csv(p_run_id);
        l_orgcr_csv := gen_org_credits_csv(p_run_id);
        l_ptbrd_csv := gen_prj_task_burden_csv(p_run_id);
        l_ref_csv   := gen_references_csv(p_run_id);
        l_term_csv  := gen_terms_csv(p_run_id);

        -- AD#20: Skip gracefully if no rows generated (headers is the primary CSV)
        IF (l_hdr_csv IS NULL OR DBMS_LOB.GETLENGTH(l_hdr_csv) = 0) THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'No STAGED Grant rows found. Skipping FBDI generation.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            IF l_hdr_csv IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_hdr_csv) = 1 THEN DBMS_LOB.FREETEMPORARY(l_hdr_csv); END IF;
            IF l_fund_csv IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_fund_csv) = 1 THEN DBMS_LOB.FREETEMPORARY(l_fund_csv); END IF;
            IF l_proj_csv IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_proj_csv) = 1 THEN DBMS_LOB.FREETEMPORARY(l_proj_csv); END IF;
            IF l_pers_csv IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_pers_csv) = 1 THEN DBMS_LOB.FREETEMPORARY(l_pers_csv); END IF;
            IF l_fsrc_csv IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_fsrc_csv) = 1 THEN DBMS_LOB.FREETEMPORARY(l_fsrc_csv); END IF;
            IF l_pfsrc_csv IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_pfsrc_csv) = 1 THEN DBMS_LOB.FREETEMPORARY(l_pfsrc_csv); END IF;
            IF l_kw_csv IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_kw_csv) = 1 THEN DBMS_LOB.FREETEMPORARY(l_kw_csv); END IF;
            IF l_bdgt_csv IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_bdgt_csv) = 1 THEN DBMS_LOB.FREETEMPORARY(l_bdgt_csv); END IF;
            IF l_cert_csv IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_cert_csv) = 1 THEN DBMS_LOB.FREETEMPORARY(l_cert_csv); END IF;
            IF l_cfda_csv IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_cfda_csv) = 1 THEN DBMS_LOB.FREETEMPORARY(l_cfda_csv); END IF;
            IF l_falloc_csv IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_falloc_csv) = 1 THEN DBMS_LOB.FREETEMPORARY(l_falloc_csv); END IF;
            IF l_orgcr_csv IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_orgcr_csv) = 1 THEN DBMS_LOB.FREETEMPORARY(l_orgcr_csv); END IF;
            IF l_ptbrd_csv IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_ptbrd_csv) = 1 THEN DBMS_LOB.FREETEMPORARY(l_ptbrd_csv); END IF;
            IF l_ref_csv IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_ref_csv) = 1 THEN DBMS_LOB.FREETEMPORARY(l_ref_csv); END IF;
            IF l_term_csv IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_term_csv) = 1 THEN DBMS_LOB.FREETEMPORARY(l_term_csv); END IF;
            x_fbdi_zip := NULL;
            x_filename := NULL;
            x_fbdi_csv_id := NULL;
            RETURN;
        END IF;

        -- Build zip
        DBMS_LOB.CREATETEMPORARY(l_zip, TRUE);
        IF DBMS_LOB.GETLENGTH(l_hdr_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'GmsAwardHeadersInterface.csv',
                clob_to_blob(l_hdr_csv));
        END IF;
        IF DBMS_LOB.GETLENGTH(l_fund_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'GmsAwardFundingInterface.csv',
                clob_to_blob(l_fund_csv));
        END IF;
        IF DBMS_LOB.GETLENGTH(l_proj_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'GmsAwardProjectsInterface.csv',
                clob_to_blob(l_proj_csv));
        END IF;
        IF DBMS_LOB.GETLENGTH(l_pers_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'GmsAwardPersonnelInterface.csv',
                clob_to_blob(l_pers_csv));
        END IF;
        IF DBMS_LOB.GETLENGTH(l_fsrc_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'GmsAwardFundSrcInterface.csv',
                clob_to_blob(l_fsrc_csv));
        END IF;
        IF DBMS_LOB.GETLENGTH(l_pfsrc_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'GmsAwardPrjFundSrcInterface.csv',
                clob_to_blob(l_pfsrc_csv));
        END IF;
        IF DBMS_LOB.GETLENGTH(l_kw_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'GmsAwardKeywordsInterface.csv',
                clob_to_blob(l_kw_csv));
        END IF;
        IF DBMS_LOB.GETLENGTH(l_bdgt_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'GmsAwardBudgetPeriodsInterface.csv',
                clob_to_blob(l_bdgt_csv));
        END IF;
        IF DBMS_LOB.GETLENGTH(l_cert_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'GmsAwardCertsInterface.csv',
                clob_to_blob(l_cert_csv));
        END IF;
        IF DBMS_LOB.GETLENGTH(l_cfda_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'GmsAwardCfdasInterface.csv',
                clob_to_blob(l_cfda_csv));
        END IF;
        IF DBMS_LOB.GETLENGTH(l_falloc_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'GmsAwardFundAllocInterface.csv',
                clob_to_blob(l_falloc_csv));
        END IF;
        IF DBMS_LOB.GETLENGTH(l_orgcr_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'GmsAwardOrgCreditsInterface.csv',
                clob_to_blob(l_orgcr_csv));
        END IF;
        IF DBMS_LOB.GETLENGTH(l_ptbrd_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'GmsAwardPrjTaskBurdenInterface.csv',
                clob_to_blob(l_ptbrd_csv));
        END IF;
        IF DBMS_LOB.GETLENGTH(l_ref_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'GmsAwardReferencesInterface.csv',
                clob_to_blob(l_ref_csv));
        END IF;
        IF DBMS_LOB.GETLENGTH(l_term_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'GmsAwardTermsInterface.csv',
                clob_to_blob(l_term_csv));
        END IF;
        DMT_OWNER.UTL_ZIP.finish_zip(l_zip);

        -- Register in DMT_FBDI_CSV_TBL
        SELECT DMT_OWNER.DMT_FBDI_CSV_ID_SEQ.NEXTVAL INTO l_fbdi_csv_id FROM DUAL;
        INSERT INTO DMT_OWNER.DMT_FBDI_CSV_TBL (
            FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME, ROW_COUNT, CSV_CONTENT, CREATED_DATE
        ) VALUES (
            l_fbdi_csv_id, p_run_id, 'Grants', x_filename, 0, l_hdr_csv, l_now
        );

        -- Register in DMT_FBDI_ZIP_TBL
        INSERT INTO DMT_OWNER.DMT_FBDI_ZIP_TBL (
            FBDI_ZIP_ID, FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME,
            ZIP_SIZE_BYTES, ZIP_CONTENT, CREATED_DATE
        ) VALUES (
            DMT_OWNER.DMT_FBDI_ZIP_ID_SEQ.NEXTVAL, l_fbdi_csv_id, p_run_id,
            'Grants', x_filename, DBMS_LOB.GETLENGTH(l_zip), l_zip, l_now
        );

        -- Update all 15 TFM tables to GENERATED and stamp FBDI_CSV_ID
        UPDATE DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL      SET TFM_STATUS='GENERATED', FBDI_CSV_ID=l_fbdi_csv_id, LAST_UPDATED_DATE=l_now WHERE RUN_ID=p_run_id AND TFM_STATUS='STAGED';
        UPDATE DMT_OWNER.DMT_GMS_AWD_FUNDING_TFM_TBL       SET TFM_STATUS='GENERATED', FBDI_CSV_ID=l_fbdi_csv_id, LAST_UPDATED_DATE=l_now WHERE RUN_ID=p_run_id AND TFM_STATUS='STAGED';
        UPDATE DMT_OWNER.DMT_GMS_AWD_PROJECTS_TFM_TBL      SET TFM_STATUS='GENERATED', FBDI_CSV_ID=l_fbdi_csv_id, LAST_UPDATED_DATE=l_now WHERE RUN_ID=p_run_id AND TFM_STATUS='STAGED';
        UPDATE DMT_OWNER.DMT_GMS_AWD_PERSONNEL_TFM_TBL     SET TFM_STATUS='GENERATED', FBDI_CSV_ID=l_fbdi_csv_id, LAST_UPDATED_DATE=l_now WHERE RUN_ID=p_run_id AND TFM_STATUS='STAGED';
        UPDATE DMT_OWNER.DMT_GMS_AWD_FUND_SRC_TFM_TBL      SET TFM_STATUS='GENERATED', FBDI_CSV_ID=l_fbdi_csv_id, LAST_UPDATED_DATE=l_now WHERE RUN_ID=p_run_id AND TFM_STATUS='STAGED';
        UPDATE DMT_OWNER.DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL  SET TFM_STATUS='GENERATED', FBDI_CSV_ID=l_fbdi_csv_id, LAST_UPDATED_DATE=l_now WHERE RUN_ID=p_run_id AND TFM_STATUS='STAGED';
        UPDATE DMT_OWNER.DMT_GMS_AWD_KEYWORDS_TFM_TBL      SET TFM_STATUS='GENERATED', FBDI_CSV_ID=l_fbdi_csv_id, LAST_UPDATED_DATE=l_now WHERE RUN_ID=p_run_id AND TFM_STATUS='STAGED';
        UPDATE DMT_OWNER.DMT_GMS_AWD_BDGT_PRDS_TFM_TBL     SET TFM_STATUS='GENERATED', FBDI_CSV_ID=l_fbdi_csv_id, LAST_UPDATED_DATE=l_now WHERE RUN_ID=p_run_id AND TFM_STATUS='STAGED';
        UPDATE DMT_OWNER.DMT_GMS_AWD_CERTS_TFM_TBL         SET TFM_STATUS='GENERATED', FBDI_CSV_ID=l_fbdi_csv_id, LAST_UPDATED_DATE=l_now WHERE RUN_ID=p_run_id AND TFM_STATUS='STAGED';
        UPDATE DMT_OWNER.DMT_GMS_AWD_CFDAS_TFM_TBL         SET TFM_STATUS='GENERATED', FBDI_CSV_ID=l_fbdi_csv_id, LAST_UPDATED_DATE=l_now WHERE RUN_ID=p_run_id AND TFM_STATUS='STAGED';
        UPDATE DMT_OWNER.DMT_GMS_AWD_FUND_ALLOC_TFM_TBL    SET TFM_STATUS='GENERATED', FBDI_CSV_ID=l_fbdi_csv_id, LAST_UPDATED_DATE=l_now WHERE RUN_ID=p_run_id AND TFM_STATUS='STAGED';
        UPDATE DMT_OWNER.DMT_GMS_AWD_ORG_CREDITS_TFM_TBL   SET TFM_STATUS='GENERATED', FBDI_CSV_ID=l_fbdi_csv_id, LAST_UPDATED_DATE=l_now WHERE RUN_ID=p_run_id AND TFM_STATUS='STAGED';
        UPDATE DMT_OWNER.DMT_GMS_AWD_PRJ_TSK_BRD_TFM_TBL   SET TFM_STATUS='GENERATED', FBDI_CSV_ID=l_fbdi_csv_id, LAST_UPDATED_DATE=l_now WHERE RUN_ID=p_run_id AND TFM_STATUS='STAGED';
        UPDATE DMT_OWNER.DMT_GMS_AWD_REFERENCES_TFM_TBL    SET TFM_STATUS='GENERATED', FBDI_CSV_ID=l_fbdi_csv_id, LAST_UPDATED_DATE=l_now WHERE RUN_ID=p_run_id AND TFM_STATUS='STAGED';
        UPDATE DMT_OWNER.DMT_GMS_AWD_TERMS_TFM_TBL         SET TFM_STATUS='GENERATED', FBDI_CSV_ID=l_fbdi_csv_id, LAST_UPDATED_DATE=l_now WHERE RUN_ID=p_run_id AND TFM_STATUS='STAGED';

        -- Free temporary CLOBs
        DBMS_LOB.FREETEMPORARY(l_hdr_csv);   DBMS_LOB.FREETEMPORARY(l_fund_csv);
        DBMS_LOB.FREETEMPORARY(l_proj_csv);  DBMS_LOB.FREETEMPORARY(l_pers_csv);
        DBMS_LOB.FREETEMPORARY(l_fsrc_csv);  DBMS_LOB.FREETEMPORARY(l_pfsrc_csv);
        DBMS_LOB.FREETEMPORARY(l_kw_csv);    DBMS_LOB.FREETEMPORARY(l_bdgt_csv);
        DBMS_LOB.FREETEMPORARY(l_cert_csv);  DBMS_LOB.FREETEMPORARY(l_cfda_csv);
        DBMS_LOB.FREETEMPORARY(l_falloc_csv);DBMS_LOB.FREETEMPORARY(l_orgcr_csv);
        DBMS_LOB.FREETEMPORARY(l_ptbrd_csv); DBMS_LOB.FREETEMPORARY(l_ref_csv);
        DBMS_LOB.FREETEMPORARY(l_term_csv);

        x_fbdi_zip    := l_zip;
        x_fbdi_csv_id := l_fbdi_csv_id;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Grant FBDI generation complete.' ||
                                ' | File: ' || x_filename ||
                                ' | Zip bytes: ' || DBMS_LOB.GETLENGTH(x_fbdi_zip),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'Grant FBDI generation failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END GENERATE_FBDI;

END DMT_GRANTS_FBDI_GEN_PKG;
/
