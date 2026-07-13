-- PACKAGE BODY DMT_GL_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_GL_FBDI_GEN_PKG" AS
-- ============================================================
-- GL Balances FBDI generator
-- Column order matches GlInterface.ctl (25B) exactly.
-- CONSTANT/EXPRESSION columns in CTL are NOT included in CSV:
--   LOAD_REQUEST_ID, CREATED_BY, CREATION_DATE, LAST_UPDATE_DATE,
--   LAST_UPDATE_LOGIN, LAST_UPDATED_BY, OBJECT_VERSION_NUMBER
-- Result: 149 CSV fields per row.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_GL_FBDI_GEN_PKG';

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

    PROCEDURE af (p_clob IN OUT NOCOPY CLOB, p_value IN VARCHAR2, p_last IN BOOLEAN DEFAULT FALSE) IS
        l_val VARCHAR2(32767);
    BEGIN
        l_val := '"' || REPLACE(NVL(p_value,''), '"', '""') || '"';
        DBMS_LOB.WRITEAPPEND(p_clob, LENGTH(l_val), l_val);
        IF NOT p_last THEN DBMS_LOB.WRITEAPPEND(p_clob, 1, ',');
        ELSE DBMS_LOB.WRITEAPPEND(p_clob, 1, CHR(10)); END IF;
    END af;

    -- Append N empty comma-separated fields
    PROCEDURE af_empty (p_clob IN OUT NOCOPY CLOB, p_count IN NUMBER) IS
    BEGIN
        FOR i IN 1..p_count LOOP
            DBMS_LOB.WRITEAPPEND(p_clob, 3, '"",');
        END LOOP;
    END af_empty;

    FUNCTION fmt_dt(p_date IN DATE) RETURN VARCHAR2 IS
    BEGIN
        IF p_date IS NULL THEN RETURN NULL; END IF;
        RETURN TO_CHAR(p_date, 'YYYY/MM/DD');
    END fmt_dt;

    FUNCTION gen_gl_csv (p_run_id IN NUMBER, p_ledger_name IN VARCHAR2 DEFAULT NULL) RETURN CLOB IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);
        FOR r IN (
            SELECT
                '"' || REPLACE(NVL(JOURNAL_STATUS,''), '"', '""') || '"' || ','
                || '""' || ','
                || '"' || NVL(TO_CHAR(ACCOUNTING_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(USER_JE_SOURCE_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(USER_JE_CATEGORY_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CURRENCY_CODE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(DATE_CREATED, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(ACTUAL_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT1,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT2,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT3,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT4,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT5,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT6,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT7,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT8,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT9,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT10,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT11,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT12,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT13,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT14,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT15,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT16,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT17,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT18,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT19,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT20,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT21,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT22,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT23,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT24,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT25,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT26,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT27,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT28,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT29,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SEGMENT30,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(ENTERED_DR), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ENTERED_CR), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ACCOUNTED_DR), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ACCOUNTED_CR), '') || '"' || ','
                || '"' || REPLACE(NVL(REFERENCE1,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(REFERENCE2,''), '"', '""') || '"' || ','
                || '""' || ','
                || '"' || REPLACE(NVL(REFERENCE4,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(REFERENCE5,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(REFERENCE6,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(REFERENCE7,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(REFERENCE8,''), '"', '""') || '"' || ','
                || '""' || ','
                || '"' || REPLACE(NVL(REFERENCE10,''), '"', '""') || '"' || ','
                -- Slot 53 = GL_INTERFACE.REFERENCE21 -> GL_JE_LINES.REFERENCE_1
                -- (proven empirically 2026-07-11): the per-line reconciliation key.
                || '"' || REPLACE(NVL(RECON_KEY,''), '"', '""') || '"' || ','
                || '""' || ','   -- REFERENCE22
                || '""' || ','   -- REFERENCE23
                || '""' || ','   -- REFERENCE24
                || '""' || ','   -- REFERENCE25
                || '""' || ','   -- REFERENCE26
                || '""' || ','   -- REFERENCE27
                || '""' || ','   -- REFERENCE28
                || '""' || ','   -- REFERENCE29
                || '""' || ','   -- REFERENCE30
                || '"' || NVL(TO_CHAR(STAT_AMOUNT), '') || '"' || ','
                || '"' || REPLACE(NVL(USER_CURRENCY_CONVERSION_TYPE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(CURRENCY_CONVERSION_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(CURRENCY_CONVERSION_RATE), '') || '"' || ','
                || '"' || NVL(TO_CHAR(GROUP_ID), '') || '"' || ','
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
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '"' || REPLACE(NVL(LEDGER_NAME,''), '"', '""') || '"' || ','
                || '""' || ','
                || '""' || ','
                || '"' || REPLACE(NVL(PERIOD_NAME,''), '"', '""') || '"' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || CHR(10) AS csv_line
            FROM DMT_OWNER.DMT_GL_INTERFACE_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'STAGED'
            AND    (p_ledger_name IS NULL OR t.LEDGER_NAME = p_ledger_name)
            ORDER BY t.TFM_SEQUENCE_ID
        ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;
        RETURN l_csv;
    END gen_gl_csv;

    PROCEDURE GENERATE_FBDI (
        p_run_id  IN  NUMBER,
        x_fbdi_zip        OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_fbdi_csv_id     OUT NUMBER,
        p_ledger_name     IN  VARCHAR2 DEFAULT NULL
    ) IS
        C_PROC        CONSTANT VARCHAR2(30) := 'GENERATE_FBDI';
        l_zip         BLOB;
        l_csv         CLOB;
        l_fbdi_csv_id NUMBER;
        l_zip_id      NUMBER;
        l_bytes       NUMBER;
        l_now         DATE := SYSDATE;
        l_row_count   NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'GL Balances FBDI generation start.' ||
                                CASE WHEN p_ledger_name IS NOT NULL THEN ' Ledger: ' || p_ledger_name END,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        IF p_ledger_name IS NOT NULL THEN
            x_filename := 'GLBalances_' || TO_CHAR(p_run_id) || '_' ||
                          REPLACE(p_ledger_name, ' ', '_') || '.zip';
        ELSE
            x_filename := 'GLBalances_' || TO_CHAR(p_run_id) || '.zip';
        END IF;

        l_csv := gen_gl_csv(p_run_id, p_ledger_name);

        SELECT COUNT(*) INTO l_row_count
        FROM DMT_OWNER.DMT_GL_INTERFACE_TFM_TBL
        WHERE RUN_ID = p_run_id AND TFM_STATUS = 'STAGED'
        AND   (p_ledger_name IS NULL OR LEDGER_NAME = p_ledger_name);

        IF l_row_count = 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'No STAGED GL balance rows found. Skipping zip generation.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            x_fbdi_zip    := NULL;
            x_fbdi_csv_id := NULL;
            DBMS_LOB.FREETEMPORARY(l_csv);
            RETURN;
        END IF;

        -- Log CSV content BEFORE zipping (autonomous txn — always committed)
        DMT_UTIL_PKG.LOG(p_run_id,
            'CSV payload pre-zip (' || l_row_count || ' rows): ' || DBMS_LOB.SUBSTR(l_csv, 32767, 1),
            'INFO', C_PKG, C_PROC);

        -- FBDI CSV<->ZIP remodel: register the physical CSV as its own row, then
        -- build the zip from that persisted row.
        SELECT DMT_OWNER.DMT_FBDI_ZIP_ID_SEQ.NEXTVAL INTO l_zip_id FROM DUAL;
        l_fbdi_csv_id := DMT_UTIL_PKG.REGISTER_CSV(p_run_id, l_zip_id, 1, 'GLBalances', 'GlInterface.csv', 0, l_csv);
        DMT_UTIL_PKG.BUILD_ZIP_FROM_CSVS(p_run_id, l_zip_id, 'GLBalances', x_filename, l_zip, l_bytes);

        UPDATE DMT_OWNER.DMT_GL_INTERFACE_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_fbdi_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED'
        AND    (p_ledger_name IS NULL OR LEDGER_NAME = p_ledger_name);

        DBMS_LOB.FREETEMPORARY(l_csv);
        x_fbdi_zip    := l_zip;
        x_fbdi_csv_id := l_fbdi_csv_id;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'GL Balances FBDI generation complete. Rows: ' || l_row_count ||
                                ' | File: ' || x_filename ||
                                ' | Zip bytes: ' || DBMS_LOB.GETLENGTH(l_zip),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'GL Balances FBDI generation failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END GENERATE_FBDI;

END DMT_GL_FBDI_GEN_PKG;
/
