-- PACKAGE BODY DMT_EGP_ITEM_CAT_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_EGP_ITEM_CAT_FBDI_GEN_PKG" AS
-- ============================================================
-- Item Categories FBDI generator
-- FBDI pattern: comma-delimited, no header row, quoted fields.
-- Column order:
--   TransactionType, BatchId, BatchNumber, OrganizationCode,
--   ItemNumber, CategorySetName, CategoryCode, CategoryName,
--   OldCategoryCode, OldCategoryName, SourceSystemCode,
--   SourceSystemReference
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_EGP_ITEM_CAT_FBDI_GEN_PKG';

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

    FUNCTION gen_item_cat_csv (p_run_id IN NUMBER, p_batch_id IN VARCHAR2 DEFAULT NULL) RETURN CLOB IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        -- No header row for FBDI
        FOR r IN (
            SELECT TRANSACTION_TYPE, BATCH_ID, BATCH_NUMBER,
                   ORGANIZATION_CODE, ITEM_NUMBER, CATEGORY_SET_NAME,
                   CATEGORY_CODE, CATEGORY_NAME, OLD_CATEGORY_CODE,
                   OLD_CATEGORY_NAME, SOURCE_SYSTEM_CODE, SOURCE_SYSTEM_REFERENCE
            FROM   DMT_OWNER.DMT_EGP_ITEM_CAT_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS     = 'STAGED'
            AND    (p_batch_id IS NULL OR BATCH_ID = TO_NUMBER(p_batch_id))
            ORDER BY TFM_SEQUENCE_ID
        ) LOOP
            -- Column order per EgpItemCategoriesInterface.ctl (14 data columns)
            af(l_csv, r.TRANSACTION_TYPE);          -- 1
            af(l_csv, NVL(TO_CHAR(r.BATCH_ID), '')); -- 2
            af(l_csv, r.BATCH_NUMBER);              -- 3
            af(l_csv, r.ITEM_NUMBER);               -- 4
            af(l_csv, r.ORGANIZATION_CODE);         -- 5
            af(l_csv, r.CATEGORY_SET_NAME);         -- 6
            af(l_csv, r.CATEGORY_NAME);             -- 7
            af(l_csv, r.CATEGORY_CODE);             -- 8
            af(l_csv, r.OLD_CATEGORY_NAME);         -- 9
            af(l_csv, r.OLD_CATEGORY_CODE);         -- 10
            af(l_csv, r.SOURCE_SYSTEM_CODE);        -- 11
            af(l_csv, r.SOURCE_SYSTEM_REFERENCE);   -- 12
            af(l_csv, NULL);                        -- 13: START_DATE
            af(l_csv, NULL, p_last => TRUE);        -- 14: END_DATE
        END LOOP;

        RETURN l_csv;
    END gen_item_cat_csv;

    -- Public wrapper around the private CSV generator
    FUNCTION GENERATE_CSV (
        p_run_id  IN  NUMBER,
        p_batch_id IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB IS
    BEGIN
        RETURN gen_item_cat_csv(p_run_id, p_batch_id);
    END GENERATE_CSV;

    PROCEDURE GENERATE_FBDI (
        p_run_id  IN  NUMBER,
        x_fbdi_zip        OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_fbdi_csv_id     OUT NUMBER
    ) IS
        C_PROC       CONSTANT VARCHAR2(30) := 'GENERATE_FBDI';
        l_zip        BLOB;
        l_csv        CLOB;
        l_csv_id     NUMBER;
        l_now        DATE := SYSDATE;
        l_row_count  NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Item Categories FBDI generation start.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        x_filename := 'EgpItemCategories_' || TO_CHAR(p_run_id) || '.zip';

        SELECT COUNT(*) INTO l_row_count
        FROM   DMT_OWNER.DMT_EGP_ITEM_CAT_TFM_TBL
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        IF l_row_count = 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'No STAGED item category rows found. Skipping zip generation.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            x_fbdi_zip    := NULL;
            x_fbdi_csv_id := NULL;
            RETURN;
        END IF;

        l_csv := gen_item_cat_csv(p_run_id);

        SELECT DMT_OWNER.DMT_FBDI_CSV_ID_SEQ.NEXTVAL INTO l_csv_id FROM DUAL;
        INSERT INTO DMT_OWNER.DMT_FBDI_CSV_TBL (
            FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME, ROW_COUNT,
            CSV_CONTENT, CREATED_DATE
        ) VALUES (
            l_csv_id, p_run_id, 'EGP_ITEM_CATEGORY',
            'EgpItemCategoriesInterface.csv', l_row_count, l_csv, l_now
        );

        DBMS_LOB.CREATETEMPORARY(l_zip, TRUE);
        DMT_OWNER.UTL_ZIP.add1file(l_zip, 'EgpItemCategoriesInterface.csv', clob_to_blob(l_csv));
        DMT_OWNER.UTL_ZIP.finish_zip(l_zip);

        INSERT INTO DMT_OWNER.DMT_FBDI_ZIP_TBL (
            FBDI_ZIP_ID, FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME,
            ZIP_SIZE_BYTES, ZIP_CONTENT, CREATED_DATE
        ) VALUES (
            DMT_OWNER.DMT_FBDI_ZIP_ID_SEQ.NEXTVAL, l_csv_id, p_run_id,
            'EGP_ITEM_CATEGORY', x_filename, DBMS_LOB.GETLENGTH(l_zip), l_zip, l_now
        );

        UPDATE DMT_OWNER.DMT_EGP_ITEM_CAT_TFM_TBL
        SET    TFM_STATUS        = 'GENERATED',
               FBDI_CSV_ID       = l_csv_id,
               LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        DBMS_LOB.FREETEMPORARY(l_csv);

        x_fbdi_zip    := l_zip;
        x_fbdi_csv_id := l_csv_id;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Item Categories FBDI generation complete. Rows: ' || l_row_count
                                || ' | File: ' || x_filename
                                || ' | Zip bytes: ' || DBMS_LOB.GETLENGTH(l_zip),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'Item Categories FBDI generation failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END GENERATE_FBDI;

END DMT_EGP_ITEM_CAT_FBDI_GEN_PKG;
/
