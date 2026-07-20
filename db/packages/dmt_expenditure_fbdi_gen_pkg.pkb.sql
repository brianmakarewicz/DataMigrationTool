-- PACKAGE BODY DMT_EXPENDITURE_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_EXPENDITURE_FBDI_GEN_PKG" 
AS
    C_PKG CONSTANT VARCHAR2(50) := 'DMT_EXPENDITURE_FBDI_GEN_PKG';

-- ============================================================
-- DMT_EXPENDITURE_FBDI_GEN_PKG body
-- Expenditures FBDI zip generation.
-- ONE zip with 1 CSV, ONE ESS job (ImportCosts).
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
    -- Private: generate PjcTxnXfaceStageAll.csv CLOB
    -- --------------------------------------------------------
    FUNCTION gen_expenditures_csv (
        p_run_id IN NUMBER
    ) RETURN CLOB
    IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        FOR r IN (
            SELECT
                -- First field is the TRANSACTION discriminator (LABOR/NONLABOR filler),
                -- NOT the TRANSACTION_TYPE column value.
                -- CTL uses this to route rows via WHEN clause.
                '"' || CASE WHEN UPPER(TRANSACTION_TYPE) IN ('LABOR','NONLABOR') THEN UPPER(TRANSACTION_TYPE)
                            ELSE 'LABOR' END || '"' || ','
                || '"' || REPLACE(NVL(BUSINESS_UNIT,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(ORG_ID), '') || '"' || ','
                || '"' || REPLACE(NVL(USER_TRANSACTION_SOURCE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(TRANSACTION_SOURCE_ID), '') || '"' || ','
                || '"' || REPLACE(NVL(DOCUMENT_NAME,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(DOCUMENT_ID), '') || '"' || ','
                || '"' || REPLACE(NVL(DOC_ENTRY_NAME,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(DOC_ENTRY_ID), '') || '"' || ','
                || '"' || REPLACE(NVL(BATCH_NAME,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(BATCH_ENDING_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(BATCH_DESCRIPTION,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(EXPENDITURE_ITEM_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(PERSON_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PERSON_NAME,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(PERSON_ID), '') || '"' || ','
                || '"' || REPLACE(NVL(HCM_ASSIGNMENT_NAME,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(HCM_ASSIGNMENT_ID), '') || '"' || ','
                || '"' || REPLACE(NVL(PROJECT_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PROJECT_NAME,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(PROJECT_ID), '') || '"' || ','
                || '"' || REPLACE(NVL(TASK_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TASK_NAME,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(TASK_ID), '') || '"' || ','
                || '"' || REPLACE(NVL(EXPENDITURE_TYPE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(EXPENDITURE_TYPE_ID), '') || '"' || ','
                || '"' || REPLACE(NVL(ORGANIZATION_NAME,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(ORGANIZATION_ID), '') || '"' || ','
                -- The SQL*Loader control file PjcTxnXfaceStageAll.ctl is a
                -- discriminator file: the FIRST field (LABOR/NONLABOR) selects one
                -- of several INTO TABLE branches, each with its OWN column layout.
                -- The NONLABOR branch inserts these four NON_LABOR_RESOURCE columns
                -- right after ORGANIZATION_ID; the LABOR branch does NOT have them.
                -- Both layouts are proven live:
                --   LABOR    = 105 positional fields, NO NLR columns
                --              (proven CSV: run-116 Expenditures_116.zip, costed to
                --               PJC_EXP_ITEMS_ALL).
                --   NONLABOR = 107 positional fields, WITH these 4 NLR columns
                --              (proven CSV: gold_regression/objects/Expenditures,
                --               costed to PJC_EXP_ITEMS_ALL, prefix 32159).
                -- So the 4 NLR columns are emitted ONLY for NONLABOR. Emitting them
                -- for LABOR would push QUANTITY (a numeric CTL column) right by 4 and
                -- the import dies with ORA-06502 character-to-number; omitting them
                -- for NONLABOR would shift QUANTITY left by 4 (ORA-01400).
                || CASE WHEN UPPER(TRANSACTION_TYPE) = 'NONLABOR' THEN
                       '"' || REPLACE(NVL(NON_LABOR_RESOURCE,''), '"', '""') || '"' || ','
                    || '"' || NVL(TO_CHAR(NON_LABOR_RESOURCE_ID), '') || '"' || ','
                    || '"' || REPLACE(NVL(NON_LABOR_RESOURCE_ORG,''), '"', '""') || '"' || ','
                    || '"' || NVL(TO_CHAR(NON_LABOR_RESOURCE_ORG_ID), '') || '"' || ','
                   ELSE '' END
                || '"' || NVL(TO_CHAR(QUANTITY), '') || '"' || ','
                || '"' || REPLACE(NVL(UNIT_OF_MEASURE_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(UNIT_OF_MEASURE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(WORK_TYPE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(WORK_TYPE_ID), '') || '"' || ','
                || '"' || REPLACE(NVL(BILLABLE_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CAPITALIZABLE_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ORIG_TRANSACTION_REFERENCE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(UNMATCHED_NEGATIVE_TXN_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(REVERSED_ORIG_TXN_REFERENCE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(EXPENDITURE_COMMENT,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(GL_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(DENOM_CURRENCY_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DENOM_CURRENCY,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(DENOM_RAW_COST), '') || '"' || ','
                || '"' || NVL(TO_CHAR(DENOM_BURDENED_COST), '') || '"' || ','
                || '"' || NVL(TO_CHAR(RAW_COST_CR_CCID), '') || '"' || ','
                || '"' || REPLACE(NVL(RAW_COST_CR_ACCOUNT,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(RAW_COST_DR_CCID), '') || '"' || ','
                || '"' || REPLACE(NVL(RAW_COST_DR_ACCOUNT,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(BURDENED_COST_CR_CCID), '') || '"' || ','
                || '"' || REPLACE(NVL(BURDENED_COST_CR_ACCOUNT,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(BURDENED_COST_DR_CCID), '') || '"' || ','
                || '"' || REPLACE(NVL(BURDENED_COST_DR_ACCOUNT,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(BURDEN_COST_CR_CCID), '') || '"' || ','
                || '"' || REPLACE(NVL(BURDEN_COST_CR_ACCOUNT,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(BURDEN_COST_DR_CCID), '') || '"' || ','
                || '"' || REPLACE(NVL(BURDEN_COST_DR_ACCOUNT,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ACCT_CURRENCY_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ACCT_CURRENCY,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(ACCT_RAW_COST), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ACCT_BURDENED_COST), '') || '"' || ','
                || '"' || REPLACE(NVL(ACCT_RATE_TYPE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(ACCT_RATE_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(ACCT_RATE_DATE_TYPE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(ACCT_EXCHANGE_RATE), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ACCT_EXCHANGE_ROUNDING_LIMIT), '') || '"' || ','
                || '"' || REPLACE(NVL(CONVERTED_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CONTEXT_CATEGORY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(USER_DEF_ATTRIBUTE1,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(USER_DEF_ATTRIBUTE2,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(USER_DEF_ATTRIBUTE3,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(USER_DEF_ATTRIBUTE4,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(USER_DEF_ATTRIBUTE5,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(USER_DEF_ATTRIBUTE6,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(USER_DEF_ATTRIBUTE7,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(USER_DEF_ATTRIBUTE8,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(USER_DEF_ATTRIBUTE9,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(USER_DEF_ATTRIBUTE10,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(RESERVED_ATTRIBUTE1,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(RESERVED_ATTRIBUTE2,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(RESERVED_ATTRIBUTE3,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(RESERVED_ATTRIBUTE4,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(RESERVED_ATTRIBUTE5,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(RESERVED_ATTRIBUTE6,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(RESERVED_ATTRIBUTE7,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(RESERVED_ATTRIBUTE8,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(RESERVED_ATTRIBUTE9,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(RESERVED_ATTRIBUTE10,''), '"', '""') || '"' || ','
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
                || '"' || REPLACE(NVL(CONTRACT_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CONTRACT_NAME,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(CONTRACT_ID), '') || '"' || ','
                || '"' || REPLACE(NVL(FUNDING_SOURCE_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(FUNDING_SOURCE_NAME,''), '"', '""') || '"'
                -- Tail differs by branch (both proven live):
                --   LABOR    : two more empty positional fields
                --              (PROJECT_ROLE_NAME, PROJECT_ROLE_ID) => 105 fields.
                --   NONLABOR : FUNDING_SOURCE_NAME is the last field => 107 fields.
                || CASE WHEN UPPER(TRANSACTION_TYPE) = 'NONLABOR' THEN CHR(10)
                        ELSE ',' || '""' || ',' || '""' || CHR(10) END AS csv_line
            FROM   DMT_OWNER.DMT_PJC_EXPENDITURES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id
            AND    t.TFM_STATUS = 'STAGED'
            ORDER BY t.TFM_SEQUENCE_ID
                    ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;

        RETURN l_csv;
    END gen_expenditures_csv;

    -- ============================================================
    -- GENERATE_FBDI
    -- Builds 1 CSV, zips it, registers in FBDI tables,
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
        l_exp_csv          CLOB;
        l_fbdi_csv_id      NUMBER;
        l_zip_id           NUMBER;
        l_bytes            NUMBER;
        l_now              DATE := SYSDATE;
        C_PROC CONSTANT VARCHAR2(30) := 'GENERATE_FBDI';
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Expenditure FBDI generation start.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        x_filename := 'Expenditures_' || TO_CHAR(p_run_id) || '.zip';

        -- Generate CSV
        l_exp_csv := gen_expenditures_csv(p_run_id);

        -- AD#20: Skip gracefully if no rows generated
        IF (l_exp_csv IS NULL OR DBMS_LOB.GETLENGTH(l_exp_csv) = 0) THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'No STAGED Expenditure rows found. Skipping FBDI generation.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            DBMS_LOB.FREETEMPORARY(l_exp_csv);
            x_fbdi_zip := NULL;
            x_filename := NULL;
            x_fbdi_csv_id := NULL;
            RETURN;
        END IF;

        -- FBDI CSV<->ZIP remodel: register the physical CSV as its own row, then
        -- build the zip from that persisted row.
        SELECT DMT_OWNER.DMT_FBDI_ZIP_ID_SEQ.NEXTVAL INTO l_zip_id FROM DUAL;
        DMT_UTIL_PKG.REGISTER_CSV(p_run_id, l_zip_id, 1, 'Expenditures', 'PjcTxnXfaceStageAll.csv', 0, l_exp_csv, l_fbdi_csv_id);
        DMT_UTIL_PKG.BUILD_ZIP_FROM_CSVS(p_run_id, l_zip_id, 'Expenditures', x_filename, l_zip, l_bytes);

        -- Update TFM rows to GENERATED and stamp FBDI_CSV_ID
        UPDATE DMT_OWNER.DMT_PJC_EXPENDITURES_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_fbdi_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        -- Free temporary CLOBs
        DBMS_LOB.FREETEMPORARY(l_exp_csv);

        x_fbdi_zip    := l_zip;
        x_fbdi_csv_id := l_fbdi_csv_id;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Expenditure FBDI generation complete.' ||
                                ' | File: ' || x_filename ||
                                ' | Zip bytes: ' || DBMS_LOB.GETLENGTH(x_fbdi_zip),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'Expenditure FBDI generation failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END GENERATE_FBDI;

END DMT_EXPENDITURE_FBDI_GEN_PKG;
/
