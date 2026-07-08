-- PACKAGE BODY DMT_AP_PAY_TERM_FBL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_AP_PAY_TERM_FBL_GEN_PKG" AS
-- ============================================================
-- AP Payment Terms FBL generator
-- Produces pipe-delimited files with headers.
-- PayTermHeader.csv: Name|Description|EnabledFlag|StartDateActive|
--     EndDateActive|PayTermType|CutoffDay|Rank|AttributeCategory|
--     Attribute1|Attribute2|Attribute3|Attribute4|Attribute5
-- PayTermLine.csv: SourceGroupId|SequenceNum|DuePercent|DueAmount|
--     DueDays|DueDate|DiscountPercent|DiscountDays|
--     DiscountPercent2|DiscountDays2
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_AP_PAY_TERM_FBL_GEN_PKG';

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
    -- gen_headers_csv
    -- --------------------------------------------------------
    FUNCTION gen_headers_csv (p_run_id IN NUMBER) RETURN CLOB IS
        l_csv  CLOB;
        l_line VARCHAR2(32767);
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        l_line := 'SourceGroupId|Name|Description|EnabledFlag|StartDateActive'
               || '|EndDateActive|PayTermType|CutoffDay|Rank'
               || '|AttributeCategory|Attribute1|Attribute2|Attribute3|Attribute4|Attribute5'
               || CHR(10);
        DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(l_line), l_line);

        FOR r IN (
            SELECT SOURCE_GROUP_ID, NAME, DESCRIPTION, ENABLED_FLAG,
                   START_DATE_ACTIVE, END_DATE_ACTIVE, PAY_TERM_TYPE,
                   CUTOFF_DAY, RANK, ATTRIBUTE_CATEGORY,
                   ATTRIBUTE1, ATTRIBUTE2, ATTRIBUTE3, ATTRIBUTE4, ATTRIBUTE5
            FROM   DMT_OWNER.DMT_AP_PAY_TERM_HDR_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS     = 'STAGED'
            ORDER BY TFM_SEQUENCE_ID
        ) LOOP
            l_line := NVL(r.SOURCE_GROUP_ID, '')                                 || '|'
                   || NVL(r.NAME, '')                                            || '|'
                   || NVL(r.DESCRIPTION, '')                                     || '|'
                   || NVL(r.ENABLED_FLAG, '')                                    || '|'
                   || NVL(TO_CHAR(r.START_DATE_ACTIVE, 'YYYY/MM/DD'), '')        || '|'
                   || NVL(TO_CHAR(r.END_DATE_ACTIVE, 'YYYY/MM/DD'), '')          || '|'
                   || NVL(r.PAY_TERM_TYPE, '')                                   || '|'
                   || NVL(TO_CHAR(r.CUTOFF_DAY), '')                             || '|'
                   || NVL(TO_CHAR(r.RANK), '')                                   || '|'
                   || NVL(r.ATTRIBUTE_CATEGORY, '')                              || '|'
                   || NVL(r.ATTRIBUTE1, '')                                      || '|'
                   || NVL(r.ATTRIBUTE2, '')                                      || '|'
                   || NVL(r.ATTRIBUTE3, '')                                      || '|'
                   || NVL(r.ATTRIBUTE4, '')                                      || '|'
                   || NVL(r.ATTRIBUTE5, '')
                   || CHR(10);
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(l_line), l_line);
        END LOOP;

        RETURN l_csv;
    END gen_headers_csv;

    -- --------------------------------------------------------
    -- gen_lines_csv
    -- --------------------------------------------------------
    FUNCTION gen_lines_csv (p_run_id IN NUMBER) RETURN CLOB IS
        l_csv  CLOB;
        l_line VARCHAR2(32767);
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        l_line := 'SourceGroupId|SequenceNum|DuePercent|DueAmount|DueDays'
               || '|DueDate|DiscountPercent|DiscountDays|DiscountPercent2|DiscountDays2'
               || CHR(10);
        DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(l_line), l_line);

        FOR r IN (
            SELECT SOURCE_GROUP_ID, SEQUENCE_NUM, DUE_PERCENT, DUE_AMOUNT,
                   DUE_DAYS, DUE_DATE, DISCOUNT_PERCENT, DISCOUNT_DAYS,
                   DISCOUNT_PERCENT_2, DISCOUNT_DAYS_2
            FROM   DMT_OWNER.DMT_AP_PAY_TERM_LINE_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS     = 'STAGED'
            ORDER BY TFM_SEQUENCE_ID
        ) LOOP
            l_line := NVL(r.SOURCE_GROUP_ID, '')                             || '|'
                   || NVL(TO_CHAR(r.SEQUENCE_NUM), '')                       || '|'
                   || NVL(TO_CHAR(r.DUE_PERCENT), '')                        || '|'
                   || NVL(TO_CHAR(r.DUE_AMOUNT), '')                         || '|'
                   || NVL(TO_CHAR(r.DUE_DAYS), '')                           || '|'
                   || NVL(TO_CHAR(r.DUE_DATE, 'YYYY/MM/DD'), '')             || '|'
                   || NVL(TO_CHAR(r.DISCOUNT_PERCENT), '')                   || '|'
                   || NVL(TO_CHAR(r.DISCOUNT_DAYS), '')                      || '|'
                   || NVL(TO_CHAR(r.DISCOUNT_PERCENT_2), '')                 || '|'
                   || NVL(TO_CHAR(r.DISCOUNT_DAYS_2), '')
                   || CHR(10);
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(l_line), l_line);
        END LOOP;

        RETURN l_csv;
    END gen_lines_csv;

    -- ============================================================
    -- GENERATE_FBL
    -- ============================================================
    PROCEDURE GENERATE_FBL (
        p_run_id  IN  NUMBER,
        x_fbl_zip         OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_fbdi_csv_id     OUT NUMBER
    ) IS
        C_PROC           CONSTANT VARCHAR2(30) := 'GENERATE_FBL';
        l_zip            BLOB;
        l_hdr_csv        CLOB;
        l_line_csv       CLOB;
        l_hdr_csv_id     NUMBER;
        l_line_csv_id    NUMBER;
        l_now            DATE := SYSDATE;
        l_hdr_count      NUMBER;
        l_line_count     NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'AP Payment Terms FBL generation start.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        x_filename := 'PayTerms_' || TO_CHAR(p_run_id) || '.zip';

        SELECT COUNT(*) INTO l_hdr_count
        FROM   DMT_OWNER.DMT_AP_PAY_TERM_HDR_TFM_TBL
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        SELECT COUNT(*) INTO l_line_count
        FROM   DMT_OWNER.DMT_AP_PAY_TERM_LINE_TFM_TBL
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        IF l_hdr_count = 0 AND l_line_count = 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'No STAGED payment term rows found. Skipping zip generation.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            x_fbl_zip     := NULL;
            x_fbdi_csv_id := NULL;
            RETURN;
        END IF;

        l_hdr_csv  := gen_headers_csv(p_run_id);
        l_line_csv := gen_lines_csv(p_run_id);

        -- Store header CSV artefact
        SELECT DMT_OWNER.DMT_FBDI_CSV_ID_SEQ.NEXTVAL INTO l_hdr_csv_id FROM DUAL;
        INSERT INTO DMT_OWNER.DMT_FBDI_CSV_TBL (
            FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME, ROW_COUNT,
            CSV_CONTENT, CREATED_DATE
        ) VALUES (
            l_hdr_csv_id, p_run_id, 'AP_PAY_TERM_HDR',
            'PayTermHeader.csv', l_hdr_count, l_hdr_csv, l_now
        );

        -- Store line CSV artefact
        SELECT DMT_OWNER.DMT_FBDI_CSV_ID_SEQ.NEXTVAL INTO l_line_csv_id FROM DUAL;
        INSERT INTO DMT_OWNER.DMT_FBDI_CSV_TBL (
            FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME, ROW_COUNT,
            CSV_CONTENT, CREATED_DATE
        ) VALUES (
            l_line_csv_id, p_run_id, 'AP_PAY_TERM_LINE',
            'PayTermLine.csv', l_line_count, l_line_csv, l_now
        );

        -- Build zip
        DBMS_LOB.CREATETEMPORARY(l_zip, TRUE);

        IF l_hdr_count > 0 AND DBMS_LOB.GETLENGTH(l_hdr_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'PayTermHeader.csv',
                clob_to_blob(l_hdr_csv));
        END IF;

        IF l_line_count > 0 AND DBMS_LOB.GETLENGTH(l_line_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'PayTermLine.csv',
                clob_to_blob(l_line_csv));
        END IF;

        DMT_OWNER.UTL_ZIP.finish_zip(l_zip);

        -- Store zip artefact
        INSERT INTO DMT_OWNER.DMT_FBDI_ZIP_TBL (
            FBDI_ZIP_ID, FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME,
            ZIP_SIZE_BYTES, ZIP_CONTENT, CREATED_DATE
        ) VALUES (
            DMT_OWNER.DMT_FBDI_ZIP_ID_SEQ.NEXTVAL, l_hdr_csv_id, p_run_id,
            'AP_PAY_TERM', x_filename, DBMS_LOB.GETLENGTH(l_zip), l_zip, l_now
        );

        -- Update header TFM: STAGED -> GENERATED
        IF l_hdr_count > 0 THEN
            UPDATE DMT_OWNER.DMT_AP_PAY_TERM_HDR_TFM_TBL
            SET    TFM_STATUS        = 'GENERATED',
                   FBDI_CSV_ID       = l_hdr_csv_id,
                   LAST_UPDATED_DATE = l_now
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';
        END IF;

        -- Update line TFM: STAGED -> GENERATED
        IF l_line_count > 0 THEN
            UPDATE DMT_OWNER.DMT_AP_PAY_TERM_LINE_TFM_TBL
            SET    TFM_STATUS        = 'GENERATED',
                   FBDI_CSV_ID       = l_line_csv_id,
                   LAST_UPDATED_DATE = l_now
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';
        END IF;

        DBMS_LOB.FREETEMPORARY(l_hdr_csv);
        DBMS_LOB.FREETEMPORARY(l_line_csv);

        x_fbl_zip     := l_zip;
        x_fbdi_csv_id := l_hdr_csv_id;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'AP Payment Terms FBL generation complete. Headers: ' || l_hdr_count
                                || ' | Lines: ' || l_line_count
                                || ' | File: ' || x_filename
                                || ' | Zip bytes: ' || DBMS_LOB.GETLENGTH(l_zip),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'AP Payment Terms FBL generation failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END GENERATE_FBL;

END DMT_AP_PAY_TERM_FBL_GEN_PKG;
/
