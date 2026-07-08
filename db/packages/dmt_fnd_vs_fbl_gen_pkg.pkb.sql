-- PACKAGE BODY DMT_FND_VS_FBL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_FND_VS_FBL_GEN_PKG" AS
-- ============================================================
-- FND Value Set FBL generator
-- Produces pipe-delimited files with headers for Fusion
-- Value Set import.
-- ValueSetCode.csv: ValueSetCode|Description|ModuleId|ValidationType|
--                   ValueDataType|MaximumSize|FormatType|ProtectedFlag|
--                   SecurityEnabledFlag
-- ValueSetValue.csv: ValueSetCode|Value|Description|EnabledFlag|
--                    EffectiveStartDate|EffectiveEndDate|IndependentValue|Tag
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_FND_VS_FBL_GEN_PKG';

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
    -- gen_sets_csv
    -- Generates the ValueSetCode.csv content (pipe-delimited, header row)
    -- --------------------------------------------------------
    FUNCTION gen_sets_csv (p_run_id IN NUMBER) RETURN CLOB IS
        l_csv  CLOB;
        l_line VARCHAR2(32767);
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        -- Header row
        l_line := 'ValueSetCode|Description|ModuleId|ValidationType'
               || '|ValueDataType|MaximumSize|FormatType|ProtectedFlag'
               || '|SecurityEnabledFlag' || CHR(10);
        DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(l_line), l_line);

        FOR r IN (
            SELECT VALUE_SET_CODE, DESCRIPTION, MODULE_ID, VALIDATION_TYPE,
                   VALUE_DATA_TYPE, MAXIMUM_SIZE, FORMAT_TYPE, PROTECTED_FLAG,
                   SECURITY_ENABLED_FLAG
            FROM   DMT_OWNER.DMT_FND_VS_SET_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS     = 'STAGED'
            ORDER BY TFM_SEQUENCE_ID
        ) LOOP
            l_line := NVL(r.VALUE_SET_CODE, '')        || '|'
                   || NVL(r.DESCRIPTION, '')            || '|'
                   || NVL(r.MODULE_ID, '')              || '|'
                   || NVL(r.VALIDATION_TYPE, '')         || '|'
                   || NVL(r.VALUE_DATA_TYPE, '')         || '|'
                   || NVL(TO_CHAR(r.MAXIMUM_SIZE), '')   || '|'
                   || NVL(r.FORMAT_TYPE, '')              || '|'
                   || NVL(r.PROTECTED_FLAG, '')           || '|'
                   || NVL(r.SECURITY_ENABLED_FLAG, '')
                   || CHR(10);
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(l_line), l_line);
        END LOOP;

        RETURN l_csv;
    END gen_sets_csv;

    -- --------------------------------------------------------
    -- gen_values_csv
    -- Generates the ValueSetValue.csv content (pipe-delimited, header row)
    -- --------------------------------------------------------
    FUNCTION gen_values_csv (p_run_id IN NUMBER) RETURN CLOB IS
        l_csv  CLOB;
        l_line VARCHAR2(32767);
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        -- Header row
        l_line := 'ValueSetCode|Value|Description|EnabledFlag'
               || '|EffectiveStartDate|EffectiveEndDate|IndependentValue|Tag'
               || CHR(10);
        DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(l_line), l_line);

        FOR r IN (
            SELECT VALUE_SET_CODE, VALUE, DESCRIPTION, ENABLED_FLAG,
                   EFFECTIVE_START_DATE, EFFECTIVE_END_DATE, INDEPENDENT_VALUE, TAG
            FROM   DMT_OWNER.DMT_FND_VS_VALUE_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS     = 'STAGED'
            ORDER BY TFM_SEQUENCE_ID
        ) LOOP
            l_line := NVL(r.VALUE_SET_CODE, '')                                      || '|'
                   || NVL(r.VALUE, '')                                                || '|'
                   || NVL(r.DESCRIPTION, '')                                          || '|'
                   || NVL(r.ENABLED_FLAG, '')                                         || '|'
                   || NVL(TO_CHAR(r.EFFECTIVE_START_DATE, 'YYYY/MM/DD'), '')           || '|'
                   || NVL(TO_CHAR(r.EFFECTIVE_END_DATE, 'YYYY/MM/DD'), '')             || '|'
                   || NVL(r.INDEPENDENT_VALUE, '')                                    || '|'
                   || NVL(r.TAG, '')
                   || CHR(10);
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(l_line), l_line);
        END LOOP;

        RETURN l_csv;
    END gen_values_csv;

    -- ============================================================
    -- GENERATE_FBL
    -- Main entry point: builds both CSVs, packages into zip,
    -- stores artefacts, updates TFM status.
    -- ============================================================
    PROCEDURE GENERATE_FBL (
        p_run_id  IN  NUMBER,
        x_fbl_zip         OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_fbdi_csv_id     OUT NUMBER
    ) IS
        C_PROC           CONSTANT VARCHAR2(30) := 'GENERATE_FBL';
        l_zip            BLOB;
        l_sets_csv       CLOB;
        l_values_csv     CLOB;
        l_set_csv_id     NUMBER;
        l_value_csv_id   NUMBER;
        l_now            DATE := SYSDATE;
        l_set_count      NUMBER;
        l_value_count    NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'FND Value Set FBL generation start.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        x_filename := 'FndValueSet_' || TO_CHAR(p_run_id) || '.zip';

        -- Count STAGED rows for each object type
        SELECT COUNT(*) INTO l_set_count
        FROM   DMT_OWNER.DMT_FND_VS_SET_TFM_TBL
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        SELECT COUNT(*) INTO l_value_count
        FROM   DMT_OWNER.DMT_FND_VS_VALUE_TFM_TBL
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        -- If both are empty, nothing to generate
        IF l_set_count = 0 AND l_value_count = 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'No STAGED value set or value rows found. Skipping zip generation.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            x_fbl_zip     := NULL;
            x_fbdi_csv_id := NULL;
            RETURN;
        END IF;

        -- Generate CSV content
        l_sets_csv   := gen_sets_csv(p_run_id);
        l_values_csv := gen_values_csv(p_run_id);

        -- Store set CSV artefact
        SELECT DMT_OWNER.DMT_FBDI_CSV_ID_SEQ.NEXTVAL INTO l_set_csv_id FROM DUAL;
        INSERT INTO DMT_OWNER.DMT_FBDI_CSV_TBL (
            FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME, ROW_COUNT,
            CSV_CONTENT, CREATED_DATE
        ) VALUES (
            l_set_csv_id, p_run_id, 'FND_VS_SET',
            'ValueSetCode.csv', l_set_count, l_sets_csv, l_now
        );

        -- Store value CSV artefact
        SELECT DMT_OWNER.DMT_FBDI_CSV_ID_SEQ.NEXTVAL INTO l_value_csv_id FROM DUAL;
        INSERT INTO DMT_OWNER.DMT_FBDI_CSV_TBL (
            FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME, ROW_COUNT,
            CSV_CONTENT, CREATED_DATE
        ) VALUES (
            l_value_csv_id, p_run_id, 'FND_VS_VALUE',
            'ValueSetValue.csv', l_value_count, l_values_csv, l_now
        );

        -- Build zip with both files
        DBMS_LOB.CREATETEMPORARY(l_zip, TRUE);

        IF l_set_count > 0 AND DBMS_LOB.GETLENGTH(l_sets_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'ValueSetCode.csv',
                clob_to_blob(l_sets_csv));
        END IF;

        IF l_value_count > 0 AND DBMS_LOB.GETLENGTH(l_values_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'ValueSetValue.csv',
                clob_to_blob(l_values_csv));
        END IF;

        DMT_OWNER.UTL_ZIP.finish_zip(l_zip);

        -- Store zip artefact (reference the set CSV ID as the primary)
        INSERT INTO DMT_OWNER.DMT_FBDI_ZIP_TBL (
            FBDI_ZIP_ID, FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME,
            ZIP_SIZE_BYTES, ZIP_CONTENT, CREATED_DATE
        ) VALUES (
            DMT_OWNER.DMT_FBDI_ZIP_ID_SEQ.NEXTVAL, l_set_csv_id, p_run_id,
            'FND_VS', x_filename, DBMS_LOB.GETLENGTH(l_zip), l_zip, l_now
        );

        -- Update set TFM rows: STAGED -> GENERATED
        IF l_set_count > 0 THEN
            UPDATE DMT_OWNER.DMT_FND_VS_SET_TFM_TBL
            SET    TFM_STATUS       = 'GENERATED',
                   FBDI_CSV_ID      = l_set_csv_id,
                   LAST_UPDATED_DATE = l_now
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';
        END IF;

        -- Update value TFM rows: STAGED -> GENERATED
        IF l_value_count > 0 THEN
            UPDATE DMT_OWNER.DMT_FND_VS_VALUE_TFM_TBL
            SET    TFM_STATUS       = 'GENERATED',
                   FBDI_CSV_ID      = l_value_csv_id,
                   LAST_UPDATED_DATE = l_now
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';
        END IF;

        -- Free temporary LOBs
        DBMS_LOB.FREETEMPORARY(l_sets_csv);
        DBMS_LOB.FREETEMPORARY(l_values_csv);

        x_fbl_zip     := l_zip;
        x_fbdi_csv_id := l_set_csv_id;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'FND Value Set FBL generation complete. Sets: ' || l_set_count
                                || ' | Values: ' || l_value_count
                                || ' | File: ' || x_filename
                                || ' | Zip bytes: ' || DBMS_LOB.GETLENGTH(l_zip),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'FND Value Set FBL generation failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END GENERATE_FBL;

END DMT_FND_VS_FBL_GEN_PKG;
/
