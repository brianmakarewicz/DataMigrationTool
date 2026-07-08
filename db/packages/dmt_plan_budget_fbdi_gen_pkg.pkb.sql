-- PACKAGE BODY DMT_PLAN_BUDGET_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_PLAN_BUDGET_FBDI_GEN_PKG" AS
    C_PKG CONSTANT VARCHAR2(50) := 'DMT_PLAN_BUDGET_FBDI_GEN_PKG';

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
        p_clob IN OUT NOCOPY CLOB, p_value IN VARCHAR2, p_last IN BOOLEAN DEFAULT FALSE
    ) IS l_val VARCHAR2(32767);
    BEGIN
        l_val := '"' || REPLACE(p_value, '"', '""') || '"';
        DBMS_LOB.WRITEAPPEND(p_clob, LENGTH(l_val), l_val);
        IF NOT p_last THEN DBMS_LOB.WRITEAPPEND(p_clob, 1, ',');
        ELSE DBMS_LOB.WRITEAPPEND(p_clob, 1, CHR(10)); END IF;
    END append_csv_field;

    FUNCTION gen_plan_csv (p_run_id IN NUMBER) RETURN CLOB IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);
        FOR r IN (
            SELECT
                '"' || REPLACE(NVL(SCENARIO,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(VERSION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ENTITY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ACCOUNT,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PERIOD,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(AMOUNT), '') || '"' || ','
                || '"' || REPLACE(NVL(CURRENCY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DATA_LOAD_DEFINITION_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE1,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE2,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE3,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE4,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE5,''), '"', '""') || '"' || CHR(10) AS csv_line
            FROM DMT_OWNER.DMT_PLAN_BUDGET_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.STATUS = 'STAGED'
            ORDER BY t.TFM_SEQUENCE_ID
        ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;
        RETURN l_csv;
    END gen_plan_csv;

    PROCEDURE GENERATE_FBDI (
        p_run_id IN NUMBER, x_fbdi_zip OUT BLOB, x_filename OUT VARCHAR2, x_fbdi_csv_id OUT NUMBER
    ) IS
        l_zip BLOB; l_csv CLOB; l_fbdi_csv_id NUMBER; l_now DATE := SYSDATE;
        C_PROC CONSTANT VARCHAR2(30) := 'GENERATE_FBDI';
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Planning Budget FBDI generation start.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        x_filename := 'PlanningBudgets_' || TO_CHAR(p_run_id) || '.zip';
        l_csv := gen_plan_csv(p_run_id);

        -- AD#20: Skip gracefully if no rows generated
        IF (l_csv IS NULL OR DBMS_LOB.GETLENGTH(l_csv) = 0) THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'No STAGED Planning Budget rows found. Skipping FBDI generation.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            DBMS_LOB.FREETEMPORARY(l_csv);
            x_fbdi_zip := NULL;
            x_filename := NULL;
            x_fbdi_csv_id := NULL;
            RETURN;
        END IF;

        DBMS_LOB.CREATETEMPORARY(l_zip, TRUE);
        DMT_OWNER.UTL_ZIP.add1file(l_zip, 'EpbcsDataImport.csv',
            clob_to_blob(l_csv));
        DMT_OWNER.UTL_ZIP.finish_zip(l_zip);

        SELECT DMT_OWNER.DMT_FBDI_CSV_ID_SEQ.NEXTVAL INTO l_fbdi_csv_id FROM DUAL;
        INSERT INTO DMT_OWNER.DMT_FBDI_CSV_TBL (FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME, ROW_COUNT, CSV_CONTENT, CREATED_DATE)
        VALUES (l_fbdi_csv_id, p_run_id, 'PlanningBudgets', x_filename, 0, l_csv, l_now);
        INSERT INTO DMT_OWNER.DMT_FBDI_ZIP_TBL (FBDI_ZIP_ID, FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME, ZIP_SIZE_BYTES, ZIP_CONTENT, CREATED_DATE)
        VALUES (DMT_OWNER.DMT_FBDI_ZIP_ID_SEQ.NEXTVAL, l_fbdi_csv_id, p_run_id, 'PlanningBudgets', x_filename, DBMS_LOB.GETLENGTH(l_zip), l_zip, l_now);

        UPDATE DMT_OWNER.DMT_PLAN_BUDGET_TFM_TBL
        SET    STATUS = 'GENERATED', FBDI_CSV_ID = l_fbdi_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND STATUS = 'STAGED';

        DBMS_LOB.FREETEMPORARY(l_csv);
        x_fbdi_zip := l_zip; x_fbdi_csv_id := l_fbdi_csv_id;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Planning Budget FBDI generation complete.' ||
                                ' | File: ' || x_filename ||
                                ' | Zip bytes: ' || DBMS_LOB.GETLENGTH(x_fbdi_zip),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'Planning Budget FBDI generation failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END GENERATE_FBDI;

END DMT_PLAN_BUDGET_FBDI_GEN_PKG;
/
