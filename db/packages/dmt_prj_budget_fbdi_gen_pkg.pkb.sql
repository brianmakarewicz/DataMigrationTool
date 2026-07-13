-- PACKAGE BODY DMT_PRJ_BUDGET_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_PRJ_BUDGET_FBDI_GEN_PKG" AS
    C_PKG CONSTANT VARCHAR2(50) := 'DMT_PRJ_BUDGET_FBDI_GEN_PKG';

-- ============================================================
-- ProjectBudgets FBDI generator.
-- CSV: PjoPlanVersionsXface.csv (62 columns, position-based, no header)
-- Column order verified against PjoPlanVersionsXface.ctl from Fusion 25C.
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

    FUNCTION fmt_date(p_date IN DATE) RETURN VARCHAR2
    IS
    BEGIN
        RETURN TO_CHAR(p_date, 'YYYY/MM/DD');
    END fmt_date;

    FUNCTION q(p_val IN VARCHAR2) RETURN VARCHAR2
    IS
    BEGIN
        RETURN '"' || REPLACE(NVL(p_val, ''), '"', '""') || '"';
    END q;

    FUNCTION qn(p_val IN NUMBER) RETURN VARCHAR2
    IS
    BEGIN
        RETURN '"' || NVL(TO_CHAR(p_val), '') || '"';
    END qn;

    FUNCTION qd(p_val IN DATE) RETURN VARCHAR2
    IS
    BEGIN
        RETURN '"' || NVL(fmt_date(p_val), '') || '"';
    END qd;

    FUNCTION gen_budget_csv (p_run_id IN NUMBER) RETURN CLOB IS
        l_csv CLOB;
        l_line VARCHAR2(32767);
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);
        FOR r IN (
            SELECT t.* FROM DMT_OWNER.DMT_PRJ_BUDGET_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'STAGED'
            ORDER BY t.TFM_SEQUENCE_ID
        ) LOOP
            -- 62 columns per PjoPlanVersionsXface.ctl
            l_line :=
                q(r.AWARD_NUMBER)                    || ',' ||  -- 1
                q(r.FINANCIAL_PLAN_TYPE)             || ',' ||  -- 2
                q(r.PROJECT_NUMBER)                  || ',' ||  -- 3
                q(r.PROJECT_NAME)                    || ',' ||  -- 4
                q(r.TASK_NAME)                       || ',' ||  -- 5
                q(r.TASK_NUMBER)                     || ',' ||  -- 6
                q(r.PLAN_VERSION_NAME)               || ',' ||  -- 7
                q(r.PLAN_VERSION_DESCRIPTION)        || ',' ||  -- 8
                q(r.PLAN_VERSION_STATUS)             || ',' ||  -- 9
                q(r.RESOURCE_NAME)                   || ',' ||  -- 10
                q(r.PERIOD_NAME)                     || ',' ||  -- 11
                q(r.PLANNING_CURRENCY)               || ',' ||  -- 12
                qn(r.TOTAL_QUANTITY)                 || ',' ||  -- 13
                qn(r.TOTAL_TC_RAW_COST)              || ',' ||  -- 14
                qn(r.TOTAL_TC_REVENUE)               || ',' ||  -- 15
                q(r.SRC_BUDGET_LINE_REFERENCE)       || ',' ||  -- 16
                q(r.FUNDING_SOURCE_NUMBER)           || ',' ||  -- 17
                q(r.FUNDING_SOURCE_NAME)             || ',' ||  -- 18
                qn(r.PC_RAW_COST)                    || ',' ||  -- 19
                qn(r.PC_REVENUE)                     || ',' ||  -- 20
                qn(r.PFC_RAW_COST)                   || ',' ||  -- 21
                qn(r.PFC_REVENUE)                    || ',' ||  -- 22
                qn(r.TOTAL_TC_BRDND_COST)            || ',' ||  -- 23
                qn(r.PC_BRDND_COST)                  || ',' ||  -- 24
                qn(r.PFC_BRDND_COST)                 || ',' ||  -- 25
                q(r.LINE_TYPE)                       || ',' ||  -- 26
                qd(r.PLANNING_START_DATE)            || ',' ||  -- 27
                qd(r.PLANNING_END_DATE)              || ',' ||  -- 28
                '""'                                 || ',' ||  -- 29 REQUEST_ID (auto-populated)
                q(r.ATTRIBUTE_CATEGORY)              || ',' ||  -- 30
                q(r.ATTRIBUTE1)  || ',' || q(r.ATTRIBUTE2)  || ',' ||  -- 31-32
                q(r.ATTRIBUTE3)  || ',' || q(r.ATTRIBUTE4)  || ',' ||  -- 33-34
                q(r.ATTRIBUTE5)  || ',' || q(r.ATTRIBUTE6)  || ',' ||  -- 35-36
                q(r.ATTRIBUTE7)  || ',' || q(r.ATTRIBUTE8)  || ',' ||  -- 37-38
                q(r.ATTRIBUTE9)  || ',' || q(r.ATTRIBUTE10) || ',' ||  -- 39-40
                q(r.ATTRIBUTE11) || ',' || q(r.ATTRIBUTE12) || ',' ||  -- 41-42
                q(r.ATTRIBUTE13) || ',' || q(r.ATTRIBUTE14) || ',' ||  -- 43-44
                q(r.ATTRIBUTE15) || ',' || q(r.ATTRIBUTE16) || ',' ||  -- 45-46
                q(r.ATTRIBUTE17) || ',' || q(r.ATTRIBUTE18) || ',' ||  -- 47-48
                q(r.ATTRIBUTE19) || ',' || q(r.ATTRIBUTE20) || ',' ||  -- 49-50
                q(r.ATTRIBUTE21) || ',' || q(r.ATTRIBUTE22) || ',' ||  -- 51-52
                q(r.ATTRIBUTE23) || ',' || q(r.ATTRIBUTE24) || ',' ||  -- 53-54
                q(r.ATTRIBUTE25) || ',' || q(r.ATTRIBUTE26) || ',' ||  -- 55-56
                q(r.ATTRIBUTE27) || ',' || q(r.ATTRIBUTE28) || ',' ||  -- 57-58
                q(r.ATTRIBUTE29) || ',' || q(r.ATTRIBUTE30) || ',' ||  -- 59-60
                qn(r.PLAN_VERSION_NUMBER)            || ',' ||  -- 61
                q(r.PROCESSING_MODE)                 ||         -- 62
                CHR(10);
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(l_line), l_line);
        END LOOP;
        RETURN l_csv;
    END gen_budget_csv;

    PROCEDURE GENERATE_FBDI (
        p_run_id IN NUMBER, x_fbdi_zip OUT BLOB, x_filename OUT VARCHAR2, x_fbdi_csv_id OUT NUMBER
    ) IS
        l_zip BLOB; l_csv CLOB; l_fbdi_csv_id NUMBER; l_now DATE := SYSDATE;
        l_zip_id NUMBER; l_bytes NUMBER;
        C_PROC CONSTANT VARCHAR2(30) := 'GENERATE_FBDI';
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Project Budget FBDI generation start.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        x_filename := 'ProjectBudgets_' || TO_CHAR(p_run_id) || '.zip';
        l_csv := gen_budget_csv(p_run_id);

        -- AD#20: Skip gracefully if no rows generated
        IF (l_csv IS NULL OR DBMS_LOB.GETLENGTH(l_csv) = 0) THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'No STAGED Project Budget rows found. Skipping FBDI generation.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            DBMS_LOB.FREETEMPORARY(l_csv);
            x_fbdi_zip := NULL;
            x_filename := NULL;
            x_fbdi_csv_id := NULL;
            RETURN;
        END IF;

        -- FBDI CSV<->ZIP remodel: register the physical CSV as its own row, then
        -- build the zip from that persisted row.
        SELECT DMT_OWNER.DMT_FBDI_ZIP_ID_SEQ.NEXTVAL INTO l_zip_id FROM DUAL;
        DMT_UTIL_PKG.REGISTER_CSV(p_run_id, l_zip_id, 1, 'ProjectBudgets', 'PjoPlanVersionsXface.csv', 0, l_csv, l_fbdi_csv_id);
        DMT_UTIL_PKG.BUILD_ZIP_FROM_CSVS(p_run_id, l_zip_id, 'ProjectBudgets', x_filename, l_zip, l_bytes);

        UPDATE DMT_OWNER.DMT_PRJ_BUDGET_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_fbdi_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        DBMS_LOB.FREETEMPORARY(l_csv);
        x_fbdi_zip := l_zip; x_fbdi_csv_id := l_fbdi_csv_id;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Project Budget FBDI generation complete.' ||
                                ' | File: ' || x_filename ||
                                ' | Zip bytes: ' || DBMS_LOB.GETLENGTH(x_fbdi_zip),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'Project Budget FBDI generation failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END GENERATE_FBDI;

END DMT_PRJ_BUDGET_FBDI_GEN_PKG;
/
