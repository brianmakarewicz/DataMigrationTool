-- PACKAGE BODY DMT_GL_BUDGET_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_GL_BUDGET_FBDI_GEN_PKG" AS
-- ============================================================
-- GL Budget Balances FBDI generator
-- Column order matches GlBudgetInterface.ctl exactly.
-- CONSTANT/EXPRESSION columns in CTL are NOT included in CSV:
--   CREATION_DATE, LAST_UPDATE_DATE, OBJECT_VERSION_NUMBER,
--   CREATED_BY, LAST_UPDATED_BY, LAST_UPDATE_LOGIN, LOAD_REQUEST_ID
-- Result: 38 CSV fields per row.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_GL_BUDGET_FBDI_GEN_PKG';

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
        l_val := '"' || REPLACE(NVL(p_value,''), '"', '""') || '"';
        DBMS_LOB.WRITEAPPEND(p_clob, LENGTH(l_val), l_val);
        IF NOT p_last THEN DBMS_LOB.WRITEAPPEND(p_clob, 1, ',');
        ELSE DBMS_LOB.WRITEAPPEND(p_clob, 1, CHR(10)); END IF;
    END append_csv_field;

    FUNCTION gen_budget_csv (p_run_id IN NUMBER) RETURN CLOB IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);
        FOR r IN (
            SELECT
                -- 38 columns matching GlBudgetInterface.ctl order
                '"' || REPLACE(NVL(RUN_NAME,''), '"', '""') || '"' || ','           -- 1  RUN_NAME
                || '"' || REPLACE(NVL(STATUS_FBDI,''), '"', '""') || '"' || ','     -- 2  TFM_STATUS
                || '"' || NVL(TO_CHAR(LEDGER_ID), '') || '"' || ','                 -- 3  LEDGER_ID
                || '"' || REPLACE(NVL(BUDGET_NAME,''), '"', '""') || '"' || ','     -- 4  BUDGET_NAME
                || '"' || REPLACE(NVL(PERIOD_NAME,''), '"', '""') || '"' || ','     -- 5  PERIOD_NAME
                || '"' || REPLACE(NVL(CURRENCY_CODE,''), '"', '""') || '"' || ','   -- 6  CURRENCY_CODE
                || '"' || REPLACE(NVL(SEGMENT1,''), '"', '""') || '"' || ','        -- 7  SEGMENT1
                || '"' || REPLACE(NVL(SEGMENT2,''), '"', '""') || '"' || ','        -- 8  SEGMENT2
                || '"' || REPLACE(NVL(SEGMENT3,''), '"', '""') || '"' || ','        -- 9  SEGMENT3
                || '"' || REPLACE(NVL(SEGMENT4,''), '"', '""') || '"' || ','        -- 10 SEGMENT4
                || '"' || REPLACE(NVL(SEGMENT5,''), '"', '""') || '"' || ','        -- 11 SEGMENT5
                || '"' || REPLACE(NVL(SEGMENT6,''), '"', '""') || '"' || ','        -- 12 SEGMENT6
                || '"' || REPLACE(NVL(SEGMENT7,''), '"', '""') || '"' || ','        -- 13 SEGMENT7
                || '"' || REPLACE(NVL(SEGMENT8,''), '"', '""') || '"' || ','        -- 14 SEGMENT8
                || '"' || REPLACE(NVL(SEGMENT9,''), '"', '""') || '"' || ','        -- 15 SEGMENT9
                || '"' || REPLACE(NVL(SEGMENT10,''), '"', '""') || '"' || ','       -- 16 SEGMENT10
                || '"' || REPLACE(NVL(SEGMENT11,''), '"', '""') || '"' || ','       -- 17 SEGMENT11
                || '"' || REPLACE(NVL(SEGMENT12,''), '"', '""') || '"' || ','       -- 18 SEGMENT12
                || '"' || REPLACE(NVL(SEGMENT13,''), '"', '""') || '"' || ','       -- 19 SEGMENT13
                || '"' || REPLACE(NVL(SEGMENT14,''), '"', '""') || '"' || ','       -- 20 SEGMENT14
                || '"' || REPLACE(NVL(SEGMENT15,''), '"', '""') || '"' || ','       -- 21 SEGMENT15
                || '"' || REPLACE(NVL(SEGMENT16,''), '"', '""') || '"' || ','       -- 22 SEGMENT16
                || '"' || REPLACE(NVL(SEGMENT17,''), '"', '""') || '"' || ','       -- 23 SEGMENT17
                || '"' || REPLACE(NVL(SEGMENT18,''), '"', '""') || '"' || ','       -- 24 SEGMENT18
                || '"' || REPLACE(NVL(SEGMENT19,''), '"', '""') || '"' || ','       -- 25 SEGMENT19
                || '"' || REPLACE(NVL(SEGMENT20,''), '"', '""') || '"' || ','       -- 26 SEGMENT20
                || '"' || REPLACE(NVL(SEGMENT21,''), '"', '""') || '"' || ','       -- 27 SEGMENT21
                || '"' || REPLACE(NVL(SEGMENT22,''), '"', '""') || '"' || ','       -- 28 SEGMENT22
                || '"' || REPLACE(NVL(SEGMENT23,''), '"', '""') || '"' || ','       -- 29 SEGMENT23
                || '"' || REPLACE(NVL(SEGMENT24,''), '"', '""') || '"' || ','       -- 30 SEGMENT24
                || '"' || REPLACE(NVL(SEGMENT25,''), '"', '""') || '"' || ','       -- 31 SEGMENT25
                || '"' || REPLACE(NVL(SEGMENT26,''), '"', '""') || '"' || ','       -- 32 SEGMENT26
                || '"' || REPLACE(NVL(SEGMENT27,''), '"', '""') || '"' || ','       -- 33 SEGMENT27
                || '"' || REPLACE(NVL(SEGMENT28,''), '"', '""') || '"' || ','       -- 34 SEGMENT28
                || '"' || REPLACE(NVL(SEGMENT29,''), '"', '""') || '"' || ','       -- 35 SEGMENT29
                || '"' || REPLACE(NVL(SEGMENT30,''), '"', '""') || '"' || ','       -- 36 SEGMENT30
                || '"' || NVL(TO_CHAR(BUDGET_AMOUNT), '') || '"' || ','             -- 37 BUDGET_AMOUNT
                || '"' || REPLACE(NVL(LEDGER_NAME,''), '"', '""') || '"'            -- 38 LEDGER_NAME
                || CHR(10) AS csv_line
            FROM DMT_OWNER.DMT_GL_BUDGET_INT_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'STAGED'
            ORDER BY t.TFM_SEQUENCE_ID
        ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;
        RETURN l_csv;
    END gen_budget_csv;

    PROCEDURE GENERATE_FBDI (
        p_run_id IN NUMBER, x_fbdi_zip OUT BLOB, x_filename OUT VARCHAR2, x_fbdi_csv_id OUT NUMBER
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'GENERATE_FBDI';
        l_zip BLOB; l_csv CLOB; l_fbdi_csv_id NUMBER; l_now DATE := SYSDATE;
        l_zip_id NUMBER; l_bytes NUMBER;
        l_row_count NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, 'GL Budget Balances FBDI generation start.',
            'INFO', C_PKG, C_PROC);

        x_filename := 'GLBudgetBalances_' || TO_CHAR(p_run_id) || '.zip';
        l_csv := gen_budget_csv(p_run_id);

        SELECT COUNT(*) INTO l_row_count
        FROM DMT_OWNER.DMT_GL_BUDGET_INT_TFM_TBL
        WHERE RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        IF l_row_count = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'No STAGED GL budget balance rows found. Skipping zip generation.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
            x_fbdi_zip := NULL; x_fbdi_csv_id := NULL;
            DBMS_LOB.FREETEMPORARY(l_csv);
            RETURN;
        END IF;

        DMT_UTIL_PKG.LOG(p_run_id,
            'CSV payload pre-zip (' || l_row_count || ' rows): ' || DBMS_LOB.SUBSTR(l_csv, 32767, 1),
            'INFO', C_PKG, C_PROC);

        -- FBDI CSV<->ZIP remodel: register the physical CSV as its own row, then
        -- build the zip from that persisted row.
        SELECT DMT_OWNER.DMT_FBDI_ZIP_ID_SEQ.NEXTVAL INTO l_zip_id FROM DUAL;
        DMT_UTIL_PKG.REGISTER_CSV(p_run_id, l_zip_id, 1, 'GLBudgetBalances', 'GlBudgetInterface.csv', 0, l_csv, l_fbdi_csv_id);
        DMT_UTIL_PKG.BUILD_ZIP_FROM_CSVS(p_run_id, l_zip_id, 'GLBudgetBalances', x_filename, l_zip, l_bytes);

        UPDATE DMT_OWNER.DMT_GL_BUDGET_INT_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_fbdi_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        DBMS_LOB.FREETEMPORARY(l_csv);
        x_fbdi_zip := l_zip; x_fbdi_csv_id := l_fbdi_csv_id;

        DMT_UTIL_PKG.LOG(p_run_id,
            'GL Budget Balances FBDI generation complete. Rows: ' || l_row_count ||
            ' | File: ' || x_filename || ' | Zip bytes: ' || DBMS_LOB.GETLENGTH(l_zip),
            'INFO', C_PKG, C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'GL Budget Balances FBDI generation failed.',
                SQLERRM, C_PKG, C_PROC);
            RAISE;
    END GENERATE_FBDI;

END DMT_GL_BUDGET_FBDI_GEN_PKG;
/
