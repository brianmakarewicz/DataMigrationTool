-- PACKAGE BODY DMT_FA_ASSET_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_FA_ASSET_FBDI_GEN_PKG" AS
    -- ================================================================
    -- Assets FBDI Generator — FaMassAdditions.ctl (422 CSV cols + 3 expression cols)
    --                        + FaMassaddDistributions.ctl (66 CSV cols)
    --
    -- FaMassAdditions.csv = header TFM JOIN book TFM on ASSET_NUMBER
    --   (one row per asset-book combination)
    -- FaMassaddDistributions.csv = assignment TFM
    --   (FK: b.TFM_SEQUENCE_ID = book TFM_SEQUENCE_ID)
    -- ================================================================

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

    PROCEDURE a (p_clob IN OUT NOCOPY CLOB, p_value IN VARCHAR2, p_last IN BOOLEAN DEFAULT FALSE) IS
        l_val VARCHAR2(32767);
    BEGIN
        l_val := '"' || REPLACE(p_value, '"', '""') || '"';
        DBMS_LOB.WRITEAPPEND(p_clob, LENGTH(l_val), l_val);
        IF NOT p_last THEN DBMS_LOB.WRITEAPPEND(p_clob, 1, ',');
        ELSE DBMS_LOB.WRITEAPPEND(p_clob, 1, CHR(10)); END IF;
    END a;

    -- Emit N blank fields
    PROCEDURE blanks (p_clob IN OUT NOCOPY CLOB, p_count IN PLS_INTEGER) IS
    BEGIN
        FOR i IN 1..p_count LOOP a(p_clob, NULL); END LOOP;
    END blanks;

    FUNCTION fd(p_date IN DATE) RETURN VARCHAR2 IS
    BEGIN RETURN TO_CHAR(p_date, 'YYYY/MM/DD'); END fd;

    FUNCTION fn(p_num IN NUMBER) RETURN VARCHAR2 IS
    BEGIN RETURN TO_CHAR(p_num); END fn;

    -- ================================================================
    -- FaMassAdditions.csv — 422 CSV columns (+3 extra tail ignored by SqlLdr)
    -- Source: FaMassAdditions.ctl (25B)
    -- Joins header TFM (descriptive) + book TFM (financial/depreciation)
    -- b.TFM_SEQUENCE_ID = b.TFM_SEQUENCE_ID (unique per asset-book row)
    -- ================================================================
    FUNCTION gen_mass_additions_csv (p_run_id IN NUMBER, p_book IN VARCHAR2 DEFAULT NULL) RETURN CLOB IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);
        FOR r IN (
            SELECT
                '"' || NVL(TO_CHAR(b.TFM_SEQUENCE_ID), '') || '"' || ','
                || '"' || REPLACE(NVL(b.BOOK_TYPE_CODE,''), '"', '""') || '"' || ','
                || '""' || ','
                || '"' || REPLACE(NVL(h.ASSET_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(h.DESCRIPTION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(h.TAG_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(h.MANUFACTURER_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(h.SERIAL_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(h.MODEL_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(h.ASSET_TYPE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(b.COST), '') || '"' || ','
                || '"' || NVL(TO_CHAR(h.DATE_PLACED_IN_SERVICE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(b.PRORATE_CONVENTION_CODE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(b.CURRENT_UNITS), '') || '"' || ','
                || '"' || REPLACE(NVL(h.ASSET_CATEGORY_SEGMENT1,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(h.ASSET_CATEGORY_SEGMENT2,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(h.ASSET_CATEGORY_SEGMENT3,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(h.ASSET_CATEGORY_SEGMENT4,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(h.ASSET_CATEGORY_SEGMENT5,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(h.ASSET_CATEGORY_SEGMENT6,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(h.ASSET_CATEGORY_SEGMENT7,''), '"', '""') || '"' || ','
                || '"POST"' || ','
                || '""' || ','
                || '""' || ','
                || '"' || REPLACE(NVL(h.PARENT_ASSET_NUMBER,''), '"', '""') || '"' || ','
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
                || '"' || REPLACE(NVL(h.PROPERTY_TYPE_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(h.PROPERTY_1245_1250_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(h.IN_USE_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(h.OWNED_LEASED,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(h.NEW_USED,''), '"', '""') || '"' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '""' || ','
                || '"YES"' || ','
                || '""' || ','
                || '"' || NVL(TO_CHAR(b.SALVAGE_VALUE), '') || '"' || ','
                || '""' || ','
                || '"' || NVL(TO_CHAR(b.YTD_DEPRN), '') || '"' || ','
                || '"' || NVL(TO_CHAR(b.DEPRN_RESERVE), '') || '"' || ','
                || '"' || NVL(TO_CHAR(b.BONUS_YTD_DEPRN), '') || '"' || ','
                || '"' || NVL(TO_CHAR(b.BONUS_DEPRN_RESERVE), '') || '"' || ','
                || '""' || ','
                || '""' || ','
                || '"' || REPLACE(NVL(b.DEPRECIATION_METHOD,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(b.LIFE_IN_MONTHS), '') || '"' || ','
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
                || '"' || REPLACE(NVL(ATTRIBUTE_CATEGORY,''), '"', '""') || '"' || ','
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
                || '"' || NVL(TO_CHAR(DEPRN_START_DATE, 'YYYY/MM/DD'), '') || '"' || ','
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
            FROM DMT_OWNER.DMT_FA_ASSET_HDR_TFM_TBL h
            JOIN DMT_OWNER.DMT_FA_ASSET_BOOK_TFM_TBL b
            ON b.ASSET_NUMBER = h.ASSET_NUMBER
            AND b.RUN_ID = h.RUN_ID
            AND b.TFM_STATUS = 'STAGED'
            AND (p_book IS NULL OR b.BOOK_TYPE_CODE = p_book)
            WHERE h.RUN_ID = p_run_id
            AND h.TFM_STATUS = 'STAGED'
            ORDER BY b.TFM_SEQUENCE_ID
        ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;
        RETURN l_csv;
    END gen_mass_additions_csv;

    -- ================================================================
    -- FaMassaddDistributions.csv — 66 CSV columns
    -- Source: FaMassaddDistributions.ctl (25B)
    -- b.TFM_SEQUENCE_ID FK = MIN(b.TFM_SEQUENCE_ID) for matching ASSET_NUMBER
    -- ================================================================
    FUNCTION gen_distributions_csv (p_run_id IN NUMBER, p_book IN VARCHAR2 DEFAULT NULL) RETURN CLOB IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);
        FOR r IN (
            SELECT
                '"' || NVL(TO_CHAR(MASS_ADDITION_ID), '') || '"' || ','
                || '"' || NVL(TO_CHAR(UNITS), '') || '"' || ','
                || '""' || ','
                || '"' || REPLACE(NVL(LOCATION_SEGMENT1,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LOCATION_SEGMENT2,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LOCATION_SEGMENT3,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LOCATION_SEGMENT4,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LOCATION_SEGMENT5,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LOCATION_SEGMENT6,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LOCATION_SEGMENT7,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(EXPENSE_ACCOUNT_SEGMENT1,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(EXPENSE_ACCOUNT_SEGMENT2,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(EXPENSE_ACCOUNT_SEGMENT3,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(EXPENSE_ACCOUNT_SEGMENT4,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(EXPENSE_ACCOUNT_SEGMENT5,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(EXPENSE_ACCOUNT_SEGMENT6,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(EXPENSE_ACCOUNT_SEGMENT7,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(EXPENSE_ACCOUNT_SEGMENT8,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(EXPENSE_ACCOUNT_SEGMENT9,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(EXPENSE_ACCOUNT_SEGMENT10,''), '"', '""') || '"' || ','
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
            FROM (
                SELECT
                    (SELECT MIN(b.TFM_SEQUENCE_ID)
                     FROM   DMT_OWNER.DMT_FA_ASSET_BOOK_TFM_TBL b
                     WHERE  b.ASSET_NUMBER = d.ASSET_NUMBER
                     AND    b.RUN_ID = d.RUN_ID
                     AND    b.TFM_STATUS = 'STAGED') AS MASS_ADDITION_ID,
                    d.UNITS_ASSIGNED AS UNITS,
                    d.LOCATION_SEGMENT1, d.LOCATION_SEGMENT2, d.LOCATION_SEGMENT3,
                    d.LOCATION_SEGMENT4, d.LOCATION_SEGMENT5, d.LOCATION_SEGMENT6,
                    d.LOCATION_SEGMENT7,
                    d.EXPENSE_ACCOUNT_SEGMENT1, d.EXPENSE_ACCOUNT_SEGMENT2, d.EXPENSE_ACCOUNT_SEGMENT3,
                    d.EXPENSE_ACCOUNT_SEGMENT4, d.EXPENSE_ACCOUNT_SEGMENT5, d.EXPENSE_ACCOUNT_SEGMENT6,
                    d.EXPENSE_ACCOUNT_SEGMENT7, d.EXPENSE_ACCOUNT_SEGMENT8, d.EXPENSE_ACCOUNT_SEGMENT9,
                    d.EXPENSE_ACCOUNT_SEGMENT10
                FROM DMT_OWNER.DMT_FA_ASSET_ASSIGN_TFM_TBL d
                WHERE d.RUN_ID = p_run_id AND d.TFM_STATUS = 'STAGED'
                AND (p_book IS NULL OR EXISTS (
                        SELECT 1 FROM DMT_OWNER.DMT_FA_ASSET_BOOK_TFM_TBL b2
                        WHERE b2.ASSET_NUMBER = d.ASSET_NUMBER
                        AND   b2.RUN_ID = d.RUN_ID
                        AND   b2.TFM_STATUS = 'STAGED'
                        AND   b2.BOOK_TYPE_CODE = p_book))
                ORDER BY d.TFM_SEQUENCE_ID
            )
        ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;
        RETURN l_csv;
    END gen_distributions_csv;

    -- ================================================================
    -- GENERATE_FBDI — public entry point
    -- ================================================================
    PROCEDURE GENERATE_FBDI (
        p_run_id IN NUMBER, x_fbdi_zip OUT BLOB, x_filename OUT VARCHAR2, x_fbdi_csv_id OUT NUMBER,
        p_book IN VARCHAR2 DEFAULT NULL  -- multi-book: generate FBDI for ONE book only
    ) IS
        l_zip BLOB; l_ma_csv CLOB; l_dist_csv CLOB;
        l_fbdi_csv_id NUMBER; l_now DATE := SYSDATE;
    BEGIN
        x_filename := 'Assets_' || TO_CHAR(p_run_id)
                      || CASE WHEN p_book IS NOT NULL
                              THEN '_' || REGEXP_REPLACE(p_book, '[^A-Za-z0-9]', '_') END
                      || '.zip';
        l_ma_csv   := gen_mass_additions_csv(p_run_id, p_book);
        l_dist_csv := gen_distributions_csv(p_run_id, p_book);

        -- AD#20: Skip gracefully if no rows generated
        IF (l_ma_csv IS NULL OR DBMS_LOB.GETLENGTH(l_ma_csv) = 0) THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'No STAGED Asset rows found. Skipping FBDI generation.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => 'DMT_FA_ASSET_FBDI_GEN_PKG',
                p_procedure      => 'GENERATE_FBDI');
            IF l_ma_csv IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_ma_csv) = 1 THEN DBMS_LOB.FREETEMPORARY(l_ma_csv); END IF;
            IF l_dist_csv IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_dist_csv) = 1 THEN DBMS_LOB.FREETEMPORARY(l_dist_csv); END IF;
            x_fbdi_zip := NULL;
            x_filename := NULL;
            x_fbdi_csv_id := NULL;
            RETURN;
        END IF;

        DBMS_LOB.CREATETEMPORARY(l_zip, TRUE);
        DMT_OWNER.UTL_ZIP.add1file(l_zip, 'FaMassAdditions.csv',
            clob_to_blob(l_ma_csv));
        IF l_dist_csv IS NOT NULL AND DBMS_LOB.GETLENGTH(l_dist_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'FaMassaddDistributions.csv',
                clob_to_blob(l_dist_csv));
        END IF;
        DMT_OWNER.UTL_ZIP.finish_zip(l_zip);

        SELECT DMT_OWNER.DMT_FBDI_CSV_ID_SEQ.NEXTVAL INTO l_fbdi_csv_id FROM DUAL;
        INSERT INTO DMT_OWNER.DMT_FBDI_CSV_TBL (FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME, ROW_COUNT, CSV_CONTENT, CREATED_DATE)
        VALUES (l_fbdi_csv_id, p_run_id, 'Assets', x_filename, 0, EMPTY_CLOB(), l_now);
        INSERT INTO DMT_OWNER.DMT_FBDI_ZIP_TBL (FBDI_ZIP_ID, FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME, ZIP_SIZE_BYTES, ZIP_CONTENT, CREATED_DATE)
        VALUES (DMT_OWNER.DMT_FBDI_ZIP_ID_SEQ.NEXTVAL, l_fbdi_csv_id, p_run_id, 'Assets', x_filename, DBMS_LOB.GETLENGTH(l_zip), l_zip, l_now);

        -- Mark only THIS book's rows GENERATED (one book per asset → HDR/ASSIGN scoped by
        -- the asset's book). p_book NULL = all books (single-FBDI / legacy path).
        UPDATE DMT_OWNER.DMT_FA_ASSET_BOOK_TFM_TBL SET TFM_STATUS='GENERATED', FBDI_CSV_ID=l_fbdi_csv_id, LAST_UPDATED_DATE=l_now
        WHERE RUN_ID=p_run_id AND TFM_STATUS='STAGED' AND (p_book IS NULL OR BOOK_TYPE_CODE=p_book);
        UPDATE DMT_OWNER.DMT_FA_ASSET_HDR_TFM_TBL SET TFM_STATUS='GENERATED', FBDI_CSV_ID=l_fbdi_csv_id, LAST_UPDATED_DATE=l_now
        WHERE RUN_ID=p_run_id AND TFM_STATUS='STAGED'
        AND (p_book IS NULL OR ASSET_NUMBER IN (
              SELECT ASSET_NUMBER FROM DMT_OWNER.DMT_FA_ASSET_BOOK_TFM_TBL
              WHERE RUN_ID=p_run_id AND BOOK_TYPE_CODE=p_book));
        UPDATE DMT_OWNER.DMT_FA_ASSET_ASSIGN_TFM_TBL SET TFM_STATUS='GENERATED', FBDI_CSV_ID=l_fbdi_csv_id, LAST_UPDATED_DATE=l_now
        WHERE RUN_ID=p_run_id AND TFM_STATUS='STAGED'
        AND (p_book IS NULL OR ASSET_NUMBER IN (
              SELECT ASSET_NUMBER FROM DMT_OWNER.DMT_FA_ASSET_BOOK_TFM_TBL
              WHERE RUN_ID=p_run_id AND BOOK_TYPE_CODE=p_book));

        IF l_ma_csv IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_ma_csv) = 1 THEN DBMS_LOB.FREETEMPORARY(l_ma_csv); END IF;
        IF l_dist_csv IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_dist_csv) = 1 THEN DBMS_LOB.FREETEMPORARY(l_dist_csv); END IF;
        x_fbdi_zip := l_zip; x_fbdi_csv_id := l_fbdi_csv_id;
    EXCEPTION
        WHEN OTHERS THEN RAISE_APPLICATION_ERROR(-20100, 'Assets > GENERATE_FBDI: ' || SQLERRM, TRUE);
    END GENERATE_FBDI;

END DMT_FA_ASSET_FBDI_GEN_PKG;
/
