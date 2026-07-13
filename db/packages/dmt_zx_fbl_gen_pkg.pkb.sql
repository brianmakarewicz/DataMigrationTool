-- PACKAGE BODY DMT_ZX_FBL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_ZX_FBL_GEN_PKG" AS
-- ============================================================
-- ZX Tax FBL generator
-- Produces pipe-delimited files with headers for Fusion
-- Tax configuration import.
-- TaxRegime.csv: TaxRegimeCode|TaxRegimeName|Description|EffectiveFrom|
--                EffectiveTo|CountryCode|RegimeTypeFlag|HasSubRegimeFlag|
--                ParentRegimeCode|AttributeCategory|Attribute1-5
-- TaxRate.csv:   TaxRegimeCode|Tax|TaxStatusCode|TaxRateCode|TaxRateName|
--                RateTypeCode|PercentageRate|EffectiveFrom|EffectiveTo|
--                ActiveFlag|Description|DefaultRateFlag|AttributeCategory|
--                Attribute1-5
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_ZX_FBL_GEN_PKG';

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
    -- gen_regimes_csv
    -- Generates the TaxRegime.csv content (pipe-delimited, header row)
    -- --------------------------------------------------------
    FUNCTION gen_regimes_csv (p_run_id IN NUMBER) RETURN CLOB IS
        l_csv  CLOB;
        l_line VARCHAR2(32767);
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        -- Header row
        l_line := 'TaxRegimeCode|TaxRegimeName|Description|EffectiveFrom'
               || '|EffectiveTo|CountryCode|RegimeTypeFlag|HasSubRegimeFlag'
               || '|ParentRegimeCode|AttributeCategory'
               || '|Attribute1|Attribute2|Attribute3|Attribute4|Attribute5'
               || CHR(10);
        DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(l_line), l_line);

        FOR r IN (
            SELECT TAX_REGIME_CODE, TAX_REGIME_NAME, DESCRIPTION,
                   EFFECTIVE_FROM, EFFECTIVE_TO, COUNTRY_CODE,
                   REGIME_TYPE_FLAG, HAS_SUB_REGIME_FLAG, PARENT_REGIME_CODE,
                   ATTRIBUTE_CATEGORY, ATTRIBUTE1, ATTRIBUTE2, ATTRIBUTE3,
                   ATTRIBUTE4, ATTRIBUTE5
            FROM   DMT_OWNER.DMT_ZX_REGIME_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS     = 'STAGED'
            ORDER BY TFM_SEQUENCE_ID
        ) LOOP
            l_line := NVL(r.TAX_REGIME_CODE, '')                                    || '|'
                   || NVL(r.TAX_REGIME_NAME, '')                                    || '|'
                   || NVL(r.DESCRIPTION, '')                                        || '|'
                   || NVL(TO_CHAR(r.EFFECTIVE_FROM, 'YYYY/MM/DD'), '')               || '|'
                   || NVL(TO_CHAR(r.EFFECTIVE_TO, 'YYYY/MM/DD'), '')                 || '|'
                   || NVL(r.COUNTRY_CODE, '')                                        || '|'
                   || NVL(r.REGIME_TYPE_FLAG, '')                                    || '|'
                   || NVL(r.HAS_SUB_REGIME_FLAG, '')                                || '|'
                   || NVL(r.PARENT_REGIME_CODE, '')                                  || '|'
                   || NVL(r.ATTRIBUTE_CATEGORY, '')                                  || '|'
                   || NVL(r.ATTRIBUTE1, '')                                          || '|'
                   || NVL(r.ATTRIBUTE2, '')                                          || '|'
                   || NVL(r.ATTRIBUTE3, '')                                          || '|'
                   || NVL(r.ATTRIBUTE4, '')                                          || '|'
                   || NVL(r.ATTRIBUTE5, '')
                   || CHR(10);
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(l_line), l_line);
        END LOOP;

        RETURN l_csv;
    END gen_regimes_csv;

    -- --------------------------------------------------------
    -- gen_rates_csv
    -- Generates the TaxRate.csv content (pipe-delimited, header row)
    -- --------------------------------------------------------
    FUNCTION gen_rates_csv (p_run_id IN NUMBER) RETURN CLOB IS
        l_csv  CLOB;
        l_line VARCHAR2(32767);
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        -- Header row
        l_line := 'TaxRegimeCode|Tax|TaxStatusCode|TaxRateCode|TaxRateName'
               || '|RateTypeCode|PercentageRate|EffectiveFrom|EffectiveTo'
               || '|ActiveFlag|Description|DefaultRateFlag|AttributeCategory'
               || '|Attribute1|Attribute2|Attribute3|Attribute4|Attribute5'
               || CHR(10);
        DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(l_line), l_line);

        FOR r IN (
            SELECT TAX_REGIME_CODE, TAX, TAX_STATUS_CODE, TAX_RATE_CODE,
                   TAX_RATE_NAME, RATE_TYPE_CODE, PERCENTAGE_RATE,
                   EFFECTIVE_FROM, EFFECTIVE_TO, ACTIVE_FLAG, DESCRIPTION,
                   DEFAULT_RATE_FLAG, ATTRIBUTE_CATEGORY,
                   ATTRIBUTE1, ATTRIBUTE2, ATTRIBUTE3, ATTRIBUTE4, ATTRIBUTE5
            FROM   DMT_OWNER.DMT_ZX_RATE_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS     = 'STAGED'
            ORDER BY TFM_SEQUENCE_ID
        ) LOOP
            l_line := NVL(r.TAX_REGIME_CODE, '')                                    || '|'
                   || NVL(r.TAX, '')                                                || '|'
                   || NVL(r.TAX_STATUS_CODE, '')                                    || '|'
                   || NVL(r.TAX_RATE_CODE, '')                                      || '|'
                   || NVL(r.TAX_RATE_NAME, '')                                      || '|'
                   || NVL(r.RATE_TYPE_CODE, '')                                     || '|'
                   || NVL(TO_CHAR(r.PERCENTAGE_RATE), '')                            || '|'
                   || NVL(TO_CHAR(r.EFFECTIVE_FROM, 'YYYY/MM/DD'), '')               || '|'
                   || NVL(TO_CHAR(r.EFFECTIVE_TO, 'YYYY/MM/DD'), '')                 || '|'
                   || NVL(r.ACTIVE_FLAG, '')                                         || '|'
                   || NVL(r.DESCRIPTION, '')                                         || '|'
                   || NVL(r.DEFAULT_RATE_FLAG, '')                                   || '|'
                   || NVL(r.ATTRIBUTE_CATEGORY, '')                                  || '|'
                   || NVL(r.ATTRIBUTE1, '')                                          || '|'
                   || NVL(r.ATTRIBUTE2, '')                                          || '|'
                   || NVL(r.ATTRIBUTE3, '')                                          || '|'
                   || NVL(r.ATTRIBUTE4, '')                                          || '|'
                   || NVL(r.ATTRIBUTE5, '')
                   || CHR(10);
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(l_line), l_line);
        END LOOP;

        RETURN l_csv;
    END gen_rates_csv;

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
        C_PROC            CONSTANT VARCHAR2(30) := 'GENERATE_FBL';
        l_zip             BLOB;
        l_regimes_csv     CLOB;
        l_rates_csv       CLOB;
        l_regime_csv_id   NUMBER;
        l_rate_csv_id     NUMBER;
        l_now             DATE := SYSDATE;
        l_regime_count    NUMBER;
        l_rate_count      NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'ZX Tax FBL generation start.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        x_filename := 'ZxTax_' || TO_CHAR(p_run_id) || '.zip';

        -- Count STAGED rows for each object type
        SELECT COUNT(*) INTO l_regime_count
        FROM   DMT_OWNER.DMT_ZX_REGIME_TFM_TBL
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        SELECT COUNT(*) INTO l_rate_count
        FROM   DMT_OWNER.DMT_ZX_RATE_TFM_TBL
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        -- If both are empty, nothing to generate
        IF l_regime_count = 0 AND l_rate_count = 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'No STAGED tax regime or rate rows found. Skipping zip generation.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            x_fbl_zip     := NULL;
            x_fbdi_csv_id := NULL;
            RETURN;
        END IF;

        -- Generate CSV content
        l_regimes_csv := gen_regimes_csv(p_run_id);
        l_rates_csv   := gen_rates_csv(p_run_id);

        -- Store regime CSV artefact
        SELECT DMT_OWNER.DMT_FBDI_CSV_ID_SEQ.NEXTVAL INTO l_regime_csv_id FROM DUAL;
        INSERT INTO DMT_OWNER.DMT_FBDI_CSV_TBL (
            FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME, ROW_COUNT,
            CSV_CONTENT, CREATED_DATE
        ) VALUES (
            l_regime_csv_id, p_run_id, 'ZX_REGIME',
            'TaxRegime.csv', l_regime_count, l_regimes_csv, l_now
        );

        -- Store rate CSV artefact
        SELECT DMT_OWNER.DMT_FBDI_CSV_ID_SEQ.NEXTVAL INTO l_rate_csv_id FROM DUAL;
        INSERT INTO DMT_OWNER.DMT_FBDI_CSV_TBL (
            FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME, ROW_COUNT,
            CSV_CONTENT, CREATED_DATE
        ) VALUES (
            l_rate_csv_id, p_run_id, 'ZX_RATE',
            'TaxRate.csv', l_rate_count, l_rates_csv, l_now
        );

        -- Build zip with both files
        DBMS_LOB.CREATETEMPORARY(l_zip, TRUE);

        IF l_regime_count > 0 AND DBMS_LOB.GETLENGTH(l_regimes_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'TaxRegime.csv',
                clob_to_blob(l_regimes_csv));
        END IF;

        IF l_rate_count > 0 AND DBMS_LOB.GETLENGTH(l_rates_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'TaxRate.csv',
                clob_to_blob(l_rates_csv));
        END IF;

        DMT_OWNER.UTL_ZIP.finish_zip(l_zip);

        -- Store zip artefact (reference the regime CSV ID as the primary)
        INSERT INTO DMT_OWNER.DMT_FBDI_ZIP_TBL (
            FBDI_ZIP_ID, RUN_ID, OBJECT_TYPE, FILENAME,
            ZIP_SIZE_BYTES, ZIP_CONTENT, CREATED_DATE
        ) VALUES (
            DMT_OWNER.DMT_FBDI_ZIP_ID_SEQ.NEXTVAL, p_run_id,
            'ZX_TAX', x_filename, DBMS_LOB.GETLENGTH(l_zip), l_zip, l_now
        );

        -- Update regime TFM rows: STAGED -> GENERATED
        IF l_regime_count > 0 THEN
            UPDATE DMT_OWNER.DMT_ZX_REGIME_TFM_TBL
            SET    TFM_STATUS       = 'GENERATED',
                   FBDI_CSV_ID      = l_regime_csv_id,
                   LAST_UPDATED_DATE = l_now
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';
        END IF;

        -- Update rate TFM rows: STAGED -> GENERATED
        IF l_rate_count > 0 THEN
            UPDATE DMT_OWNER.DMT_ZX_RATE_TFM_TBL
            SET    TFM_STATUS       = 'GENERATED',
                   FBDI_CSV_ID      = l_rate_csv_id,
                   LAST_UPDATED_DATE = l_now
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';
        END IF;

        -- Free temporary LOBs
        DBMS_LOB.FREETEMPORARY(l_regimes_csv);
        DBMS_LOB.FREETEMPORARY(l_rates_csv);

        x_fbl_zip     := l_zip;
        x_fbdi_csv_id := l_regime_csv_id;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'ZX Tax FBL generation complete. Regimes: ' || l_regime_count
                                || ' | Rates: ' || l_rate_count
                                || ' | File: ' || x_filename
                                || ' | Zip bytes: ' || DBMS_LOB.GETLENGTH(l_zip),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'ZX Tax FBL generation failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END GENERATE_FBL;

END DMT_ZX_FBL_GEN_PKG;
/
