-- PACKAGE BODY DMT_INV_UOM_FBL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_INV_UOM_FBL_GEN_PKG" AS
-- ============================================================
-- Units of Measure FBL generator
-- Produces pipe-delimited file with headers.
-- InvUnitOfMeasure.csv columns:
--   UomCode|UomClass|UnitOfMeasure|Description|BaseUomFlag|
--   DisableDate|AttributeCategory|Attribute1..Attribute5
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_INV_UOM_FBL_GEN_PKG';

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

    FUNCTION gen_uom_csv (p_run_id IN NUMBER) RETURN CLOB IS
        l_csv  CLOB;
        l_line VARCHAR2(32767);
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        -- Header row
        l_line := 'UomCode|UomClass|UnitOfMeasure|Description|BaseUomFlag'
               || '|DisableDate|AttributeCategory'
               || '|Attribute1|Attribute2|Attribute3|Attribute4|Attribute5'
               || CHR(10);
        DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(l_line), l_line);

        FOR r IN (
            SELECT UOM_CODE, UOM_CLASS, UNIT_OF_MEASURE, DESCRIPTION,
                   BASE_UOM_FLAG, DISABLE_DATE,
                   ATTRIBUTE_CATEGORY,
                   ATTRIBUTE1, ATTRIBUTE2, ATTRIBUTE3, ATTRIBUTE4, ATTRIBUTE5
            FROM   DMT_OWNER.DMT_INV_UOM_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS     = 'STAGED'
            ORDER BY TFM_SEQUENCE_ID
        ) LOOP
            l_line := NVL(r.UOM_CODE, '')                                        || '|'
                   || NVL(r.UOM_CLASS, '')                                        || '|'
                   || NVL(r.UNIT_OF_MEASURE, '')                                  || '|'
                   || NVL(r.DESCRIPTION, '')                                      || '|'
                   || NVL(r.BASE_UOM_FLAG, '')                                    || '|'
                   || NVL(TO_CHAR(r.DISABLE_DATE, 'YYYY/MM/DD'), '')              || '|'
                   || NVL(r.ATTRIBUTE_CATEGORY, '')                               || '|'
                   || NVL(r.ATTRIBUTE1, '')                                       || '|'
                   || NVL(r.ATTRIBUTE2, '')                                       || '|'
                   || NVL(r.ATTRIBUTE3, '')                                       || '|'
                   || NVL(r.ATTRIBUTE4, '')                                       || '|'
                   || NVL(r.ATTRIBUTE5, '')
                   || CHR(10);
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(l_line), l_line);
        END LOOP;

        RETURN l_csv;
    END gen_uom_csv;

    PROCEDURE GENERATE_FBL (
        p_run_id  IN  NUMBER,
        x_fbl_zip         OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_fbdi_csv_id     OUT NUMBER
    ) IS
        C_PROC       CONSTANT VARCHAR2(30) := 'GENERATE_FBL';
        l_zip        BLOB;
        l_csv        CLOB;
        l_csv_id     NUMBER;
        l_now        DATE := SYSDATE;
        l_row_count  NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'UOM FBL generation start.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        x_filename := 'InvUnitOfMeasure_' || TO_CHAR(p_run_id) || '.zip';

        SELECT COUNT(*) INTO l_row_count
        FROM   DMT_OWNER.DMT_INV_UOM_TFM_TBL
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        IF l_row_count = 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'No STAGED UOM rows found. Skipping zip generation.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            x_fbl_zip     := NULL;
            x_fbdi_csv_id := NULL;
            RETURN;
        END IF;

        l_csv := gen_uom_csv(p_run_id);

        SELECT DMT_OWNER.DMT_FBDI_CSV_ID_SEQ.NEXTVAL INTO l_csv_id FROM DUAL;
        INSERT INTO DMT_OWNER.DMT_FBDI_CSV_TBL (
            FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME, ROW_COUNT,
            CSV_CONTENT, CREATED_DATE
        ) VALUES (
            l_csv_id, p_run_id, 'INV_UOM',
            'InvUnitOfMeasure.csv', l_row_count, l_csv, l_now
        );

        DBMS_LOB.CREATETEMPORARY(l_zip, TRUE);
        DMT_OWNER.UTL_ZIP.add1file(l_zip, 'InvUnitOfMeasure.csv', clob_to_blob(l_csv));
        DMT_OWNER.UTL_ZIP.finish_zip(l_zip);

        INSERT INTO DMT_OWNER.DMT_FBDI_ZIP_TBL (
            FBDI_ZIP_ID, FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME,
            ZIP_SIZE_BYTES, ZIP_CONTENT, CREATED_DATE
        ) VALUES (
            DMT_OWNER.DMT_FBDI_ZIP_ID_SEQ.NEXTVAL, l_csv_id, p_run_id,
            'INV_UOM', x_filename, DBMS_LOB.GETLENGTH(l_zip), l_zip, l_now
        );

        UPDATE DMT_OWNER.DMT_INV_UOM_TFM_TBL
        SET    TFM_STATUS        = 'GENERATED',
               FBDI_CSV_ID       = l_csv_id,
               LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        DBMS_LOB.FREETEMPORARY(l_csv);

        x_fbl_zip     := l_zip;
        x_fbdi_csv_id := l_csv_id;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'UOM FBL generation complete. Rows: ' || l_row_count
                                || ' | File: ' || x_filename
                                || ' | Zip bytes: ' || DBMS_LOB.GETLENGTH(l_zip),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'UOM FBL generation failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END GENERATE_FBL;

END DMT_INV_UOM_FBL_GEN_PKG;
/
