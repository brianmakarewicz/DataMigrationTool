-- PACKAGE BODY DMT_FND_LOOKUP_FBL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_FND_LOOKUP_FBL_GEN_PKG" AS
-- ============================================================
-- FND Lookup FBL generator
-- Produces pipe-delimited files with headers for the Fusion
-- "Import Lookups" ESS job.
-- LookupType.csv: LookupType|Meaning|Description|ModuleType|ModuleKey
-- LookupCode.csv: LookupType|LookupCode|DisplaySequence|EnabledFlag|
--                 StartDateActive|EndDateActive|Meaning|Description|Tag
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_FND_LOOKUP_FBL_GEN_PKG';

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
    -- gen_types_csv
    -- Generates the LookupType.csv content (pipe-delimited, header row)
    -- --------------------------------------------------------
    FUNCTION gen_types_csv (p_run_id IN NUMBER) RETURN CLOB IS
        l_csv  CLOB;
        l_line VARCHAR2(32767);
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        -- Header row
        l_line := 'LookupType|Meaning|Description|ModuleType|ModuleKey' || CHR(10);
        DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(l_line), l_line);

        FOR r IN (
            SELECT LOOKUP_TYPE, MEANING, DESCRIPTION, MODULE_TYPE, MODULE_KEY
            FROM   DMT_OWNER.DMT_FND_LOOKUP_TYPE_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS     = 'STAGED'
            ORDER BY TFM_SEQUENCE_ID
        ) LOOP
            l_line := NVL(r.LOOKUP_TYPE, '') || '|'
                   || NVL(r.MEANING, '')     || '|'
                   || NVL(r.DESCRIPTION, '') || '|'
                   || NVL(r.MODULE_TYPE, '') || '|'
                   || NVL(r.MODULE_KEY, '')
                   || CHR(10);
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(l_line), l_line);
        END LOOP;

        RETURN l_csv;
    END gen_types_csv;

    -- --------------------------------------------------------
    -- gen_values_csv
    -- Generates the LookupCode.csv content (pipe-delimited, header row)
    -- --------------------------------------------------------
    FUNCTION gen_values_csv (p_run_id IN NUMBER) RETURN CLOB IS
        l_csv  CLOB;
        l_line VARCHAR2(32767);
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        -- Header row
        l_line := 'LookupType|LookupCode|DisplaySequence|EnabledFlag'
               || '|StartDateActive|EndDateActive|Meaning|Description|Tag'
               || CHR(10);
        DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(l_line), l_line);

        FOR r IN (
            SELECT LOOKUP_TYPE, LOOKUP_CODE, DISPLAY_SEQUENCE, ENABLED_FLAG,
                   START_DATE_ACTIVE, END_DATE_ACTIVE, MEANING, DESCRIPTION, TAG
            FROM   DMT_OWNER.DMT_FND_LOOKUP_VALUE_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS     = 'STAGED'
            ORDER BY TFM_SEQUENCE_ID
        ) LOOP
            l_line := NVL(r.LOOKUP_TYPE, '')                                          || '|'
                   || NVL(r.LOOKUP_CODE, '')                                          || '|'
                   || NVL(TO_CHAR(r.DISPLAY_SEQUENCE), '')                            || '|'
                   || NVL(r.ENABLED_FLAG, '')                                         || '|'
                   || NVL(TO_CHAR(r.START_DATE_ACTIVE, 'YYYY/MM/DD'), '')             || '|'
                   || NVL(TO_CHAR(r.END_DATE_ACTIVE, 'YYYY/MM/DD'), '')               || '|'
                   || NVL(r.MEANING, '')                                              || '|'
                   || NVL(r.DESCRIPTION, '')                                          || '|'
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
        l_types_csv      CLOB;
        l_values_csv     CLOB;
        l_type_csv_id    NUMBER;
        l_value_csv_id   NUMBER;
        l_now            DATE := SYSDATE;
        l_type_count     NUMBER;
        l_value_count    NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'FND Lookup FBL generation start.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        x_filename := 'FndLookup_' || TO_CHAR(p_run_id) || '.zip';

        -- Count STAGED rows for each object type
        SELECT COUNT(*) INTO l_type_count
        FROM   DMT_OWNER.DMT_FND_LOOKUP_TYPE_TFM_TBL
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        SELECT COUNT(*) INTO l_value_count
        FROM   DMT_OWNER.DMT_FND_LOOKUP_VALUE_TFM_TBL
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        -- If both are empty, nothing to generate
        IF l_type_count = 0 AND l_value_count = 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'No STAGED lookup type or value rows found. Skipping zip generation.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            x_fbl_zip     := NULL;
            x_fbdi_csv_id := NULL;
            RETURN;
        END IF;

        -- Generate CSV content
        l_types_csv  := gen_types_csv(p_run_id);
        l_values_csv := gen_values_csv(p_run_id);

        -- Store type CSV artefact
        SELECT DMT_OWNER.DMT_FBDI_CSV_ID_SEQ.NEXTVAL INTO l_type_csv_id FROM DUAL;
        INSERT INTO DMT_OWNER.DMT_FBDI_CSV_TBL (
            FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME, ROW_COUNT,
            CSV_CONTENT, CREATED_DATE
        ) VALUES (
            l_type_csv_id, p_run_id, 'FND_LOOKUP_TYPE',
            'LookupType.csv', l_type_count, l_types_csv, l_now
        );

        -- Store value CSV artefact
        SELECT DMT_OWNER.DMT_FBDI_CSV_ID_SEQ.NEXTVAL INTO l_value_csv_id FROM DUAL;
        INSERT INTO DMT_OWNER.DMT_FBDI_CSV_TBL (
            FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME, ROW_COUNT,
            CSV_CONTENT, CREATED_DATE
        ) VALUES (
            l_value_csv_id, p_run_id, 'FND_LOOKUP_VALUE',
            'LookupCode.csv', l_value_count, l_values_csv, l_now
        );

        -- Build zip with both files
        DBMS_LOB.CREATETEMPORARY(l_zip, TRUE);

        IF l_type_count > 0 AND DBMS_LOB.GETLENGTH(l_types_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'LookupType.csv',
                clob_to_blob(l_types_csv));
        END IF;

        IF l_value_count > 0 AND DBMS_LOB.GETLENGTH(l_values_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'LookupCode.csv',
                clob_to_blob(l_values_csv));
        END IF;

        DMT_OWNER.UTL_ZIP.finish_zip(l_zip);

        -- Store zip artefact (reference the type CSV ID as the primary)
        INSERT INTO DMT_OWNER.DMT_FBDI_ZIP_TBL (
            FBDI_ZIP_ID, RUN_ID, OBJECT_TYPE, FILENAME,
            ZIP_SIZE_BYTES, ZIP_CONTENT, CREATED_DATE
        ) VALUES (
            DMT_OWNER.DMT_FBDI_ZIP_ID_SEQ.NEXTVAL, p_run_id,
            'FND_LOOKUP', x_filename, DBMS_LOB.GETLENGTH(l_zip), l_zip, l_now
        );

        -- Update type TFM rows: STAGED -> GENERATED
        IF l_type_count > 0 THEN
            UPDATE DMT_OWNER.DMT_FND_LOOKUP_TYPE_TFM_TBL
            SET    TFM_STATUS       = 'GENERATED',
                   FBDI_CSV_ID      = l_type_csv_id,
                   LAST_UPDATED_DATE = l_now
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';
        END IF;

        -- Update value TFM rows: STAGED -> GENERATED
        IF l_value_count > 0 THEN
            UPDATE DMT_OWNER.DMT_FND_LOOKUP_VALUE_TFM_TBL
            SET    TFM_STATUS       = 'GENERATED',
                   FBDI_CSV_ID      = l_value_csv_id,
                   LAST_UPDATED_DATE = l_now
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';
        END IF;

        -- Free temporary LOBs
        DBMS_LOB.FREETEMPORARY(l_types_csv);
        DBMS_LOB.FREETEMPORARY(l_values_csv);

        x_fbl_zip     := l_zip;
        x_fbdi_csv_id := l_type_csv_id;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'FND Lookup FBL generation complete. Types: ' || l_type_count
                                || ' | Values: ' || l_value_count
                                || ' | File: ' || x_filename
                                || ' | Zip bytes: ' || DBMS_LOB.GETLENGTH(l_zip),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'FND Lookup FBL generation failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END GENERATE_FBL;

END DMT_FND_LOOKUP_FBL_GEN_PKG;
/
