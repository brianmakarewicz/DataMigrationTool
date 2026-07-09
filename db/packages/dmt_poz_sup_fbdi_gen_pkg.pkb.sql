-- PACKAGE BODY DMT_POZ_SUP_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_POZ_SUP_FBDI_GEN_PKG" AS
-- ============================================================
-- DMT_POZ_SUP_FBDI_GEN_PKG Body
-- Generates PoSupplierImport.csv zipped for Fusion FBDI import.
-- Interface table: POZ_SUPPLIERS_INT
-- ============================================================

    C_PKG      CONSTANT VARCHAR2(50) := 'DMT_POZ_SUP_FBDI_GEN_PKG';
    C_CSV_FILE CONSTANT VARCHAR2(50) := 'PoSupplierImport.csv';

    FUNCTION q(p_val IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        IF p_val IS NULL THEN RETURN '""'; END IF;
        RETURN '"' || REPLACE(p_val, '"', '""') || '"';
    END q;

    FUNCTION qd(p_val IN DATE) RETURN VARCHAR2 IS
    BEGIN
        IF p_val IS NULL THEN RETURN '""'; END IF;
        RETURN '"' || TO_CHAR(p_val, 'YYYY/MM/DD') || '"';
    END qd;

    FUNCTION qt(p_val IN TIMESTAMP) RETURN VARCHAR2 IS
    BEGIN
        IF p_val IS NULL THEN RETURN '""'; END IF;
        RETURN '"' || TO_CHAR(p_val, 'YYYY/MM/DD HH24:MI:SS') || '"';
    END qt;

    FUNCTION qn(p_val IN NUMBER) RETURN VARCHAR2 IS
    BEGIN
        IF p_val IS NULL THEN RETURN '""'; END IF;
        RETURN '"' || TO_CHAR(p_val) || '"';
    END qn;

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

    PROCEDURE GENERATE_FBDI (
        p_run_id IN  NUMBER,
        x_fbdi_zip       OUT BLOB,
        x_filename       OUT VARCHAR2
    ) IS
        C_PROC    CONSTANT VARCHAR2(30) := 'GENERATE_FBDI';
        l_csv     CLOB;
        l_csv_blob BLOB;
        l_row_count NUMBER := 0;
        l_crlf    CONSTANT VARCHAR2(2) := CHR(13) || CHR(10);
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Supplier FBDI generation start.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);
        FOR r IN (
            SELECT
                -- All quoting/concatenation done in SQL — no PL/SQL function calls per field
                '"' || REPLACE(NVL(IMPORT_ACTION,''), '"', '""') || '","'
                || REPLACE(NVL(VENDOR_NAME,''), '"', '""') || '","'
                || REPLACE(NVL(VENDOR_NAME_NEW,''), '"', '""') || '","'
                || REPLACE(NVL(SEGMENT1,''), '"', '""') || '","'
                || REPLACE(NVL(VENDOR_NAME_ALT,''), '"', '""') || '","'
                || REPLACE(NVL(ORGANIZATION_TYPE_LOOKUP_CODE,''), '"', '""') || '","'
                || REPLACE(NVL(VENDOR_TYPE_LOOKUP_CODE,''), '"', '""') || '","'
                || NVL(TO_CHAR(END_DATE_ACTIVE, 'YYYY/MM/DD'), '') || '","'
                || REPLACE(NVL(BUSINESS_RELATIONSHIP,''), '"', '""') || '","'
                || REPLACE(NVL(PARENT_SUPPLIER_NAME,''), '"', '""') || '","'
                || REPLACE(NVL(ALIAS,''), '"', '""') || '","'
                || REPLACE(NVL(DUNS_NUMBER,''), '"', '""') || '","'
                || REPLACE(NVL(ONE_TIME_FLAG,''), '"', '""') || '","'
                || REPLACE(NVL(CUSTOMER_NUM,''), '"', '""') || '","'
                || REPLACE(NVL(STANDARD_INDUSTRY_CLASS,''), '"', '""') || '","'
                || REPLACE(NVL(NI_NUMBER,''), '"', '""') || '","'
                || REPLACE(NVL(CORPORATE_WEBSITE,''), '"', '""') || '","'
                || REPLACE(NVL(CHIEF_EXECUTIVE_TITLE,''), '"', '""') || '","'
                || REPLACE(NVL(CHIEF_EXECUTIVE_NAME,''), '"', '""') || '","'
                || REPLACE(NVL(BC_NOT_APPLICABLE_FLAG,''), '"', '""') || '","'
                || REPLACE(NVL(TAX_COUNTRY_CODE,''), '"', '""') || '","'
                || REPLACE(NVL(NUM_1099,''), '"', '""') || '","'
                || REPLACE(NVL(FEDERAL_REPORTABLE_FLAG,''), '"', '""') || '","'
                || REPLACE(NVL(TYPE_1099,''), '"', '""') || '","'
                || REPLACE(NVL(STATE_REPORTABLE_FLAG,''), '"', '""') || '","'
                || REPLACE(NVL(TAX_REPORTING_NAME,''), '"', '""') || '","'
                || REPLACE(NVL(NAME_CONTROL,''), '"', '""') || '","'
                || NVL(TO_CHAR(TAX_VERIFICATION_DATE, 'YYYY/MM/DD'), '') || '","'
                || REPLACE(NVL(ALLOW_AWT_FLAG,''), '"', '""') || '","'
                || REPLACE(NVL(AWT_GROUP_NAME,''), '"', '""') || '","'
                || REPLACE(NVL(VAT_CODE,''), '"', '""') || '","'
                || REPLACE(NVL(VAT_REGISTRATION_NUM,''), '"', '""') || '","'
                || REPLACE(NVL(AUTO_TAX_CALC_OVERRIDE,''), '"', '""') || '","'
                || REPLACE(NVL(PAYMENT_METHOD_LOOKUP_CODE,''), '"', '""') || '","'
                || REPLACE(NVL(DELIVERY_CHANNEL_CODE,''), '"', '""') || '","'
                || REPLACE(NVL(BANK_INSTRUCTION1_CODE,''), '"', '""') || '","'
                || REPLACE(NVL(BANK_INSTRUCTION2_CODE,''), '"', '""') || '","'
                || REPLACE(NVL(BANK_INSTRUCTION_DETAILS,''), '"', '""') || '","'
                || NVL(TO_CHAR(SETTLEMENT_PRIORITY), '') || '","'
                || REPLACE(NVL(PAYMENT_TEXT_MESSAGE1,''), '"', '""') || '","'
                || REPLACE(NVL(PAYMENT_TEXT_MESSAGE2,''), '"', '""') || '","'
                || REPLACE(NVL(PAYMENT_TEXT_MESSAGE3,''), '"', '""') || '","'
                || REPLACE(NVL(IBY_BANK_CHARGE_BEARER,''), '"', '""') || '","'
                || REPLACE(NVL(PAYMENT_REASON_CODE,''), '"', '""') || '","'
                || REPLACE(NVL(PAYMENT_REASON_COMMENTS,''), '"', '""') || '","'
                || REPLACE(NVL(PAYMENT_FORMAT_CODE,''), '"', '""') || '","'
                || REPLACE(NVL(ATTRIBUTE_CATEGORY,''), '"', '""') || '","'
                || REPLACE(NVL(ATTRIBUTE1,''), '"', '""') || '","'
                || REPLACE(NVL(ATTRIBUTE2,''), '"', '""') || '","'
                || REPLACE(NVL(ATTRIBUTE3,''), '"', '""') || '","'
                || REPLACE(NVL(ATTRIBUTE4,''), '"', '""') || '","'
                || REPLACE(NVL(ATTRIBUTE5,''), '"', '""') || '","'
                || REPLACE(NVL(ATTRIBUTE6,''), '"', '""') || '","'
                || REPLACE(NVL(ATTRIBUTE7,''), '"', '""') || '","'
                || REPLACE(NVL(ATTRIBUTE8,''), '"', '""') || '","'
                || REPLACE(NVL(ATTRIBUTE9,''), '"', '""') || '","'
                || REPLACE(NVL(ATTRIBUTE10,''), '"', '""') || '","'
                || REPLACE(NVL(ATTRIBUTE11,''), '"', '""') || '","'
                || REPLACE(NVL(ATTRIBUTE12,''), '"', '""') || '","'
                || REPLACE(NVL(ATTRIBUTE13,''), '"', '""') || '","'
                || REPLACE(NVL(ATTRIBUTE14,''), '"', '""') || '","'
                || REPLACE(NVL(ATTRIBUTE15,''), '"', '""') || '","'
                || REPLACE(NVL(ATTRIBUTE16,''), '"', '""') || '","'
                || REPLACE(NVL(ATTRIBUTE17,''), '"', '""') || '","'
                || REPLACE(NVL(ATTRIBUTE18,''), '"', '""') || '","'
                || REPLACE(NVL(ATTRIBUTE19,''), '"', '""') || '","'
                || REPLACE(NVL(ATTRIBUTE20,''), '"', '""') || '","'
                || NVL(TO_CHAR(ATTRIBUTE_DATE1, 'YYYY/MM/DD'), '') || '","'
                || NVL(TO_CHAR(ATTRIBUTE_DATE2, 'YYYY/MM/DD'), '') || '","'
                || NVL(TO_CHAR(ATTRIBUTE_DATE3, 'YYYY/MM/DD'), '') || '","'
                || NVL(TO_CHAR(ATTRIBUTE_DATE4, 'YYYY/MM/DD'), '') || '","'
                || NVL(TO_CHAR(ATTRIBUTE_DATE5, 'YYYY/MM/DD'), '') || '","'
                || NVL(TO_CHAR(ATTRIBUTE_DATE6, 'YYYY/MM/DD'), '') || '","'
                || NVL(TO_CHAR(ATTRIBUTE_DATE7, 'YYYY/MM/DD'), '') || '","'
                || NVL(TO_CHAR(ATTRIBUTE_DATE8, 'YYYY/MM/DD'), '') || '","'
                || NVL(TO_CHAR(ATTRIBUTE_DATE9, 'YYYY/MM/DD'), '') || '","'
                || NVL(TO_CHAR(ATTRIBUTE_DATE10, 'YYYY/MM/DD'), '') || '","'
                || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP1, 'YYYY/MM/DD HH24:MI:SS'), '') || '","'
                || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP2, 'YYYY/MM/DD HH24:MI:SS'), '') || '","'
                || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP3, 'YYYY/MM/DD HH24:MI:SS'), '') || '","'
                || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP4, 'YYYY/MM/DD HH24:MI:SS'), '') || '","'
                || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP5, 'YYYY/MM/DD HH24:MI:SS'), '') || '","'
                || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP6, 'YYYY/MM/DD HH24:MI:SS'), '') || '","'
                || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP7, 'YYYY/MM/DD HH24:MI:SS'), '') || '","'
                || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP8, 'YYYY/MM/DD HH24:MI:SS'), '') || '","'
                || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP9, 'YYYY/MM/DD HH24:MI:SS'), '') || '","'
                || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP10, 'YYYY/MM/DD HH24:MI:SS'), '') || '","'
                || NVL(TO_CHAR(ATTRIBUTE_NUMBER1), '') || '","'
                || NVL(TO_CHAR(ATTRIBUTE_NUMBER2), '') || '","'
                || NVL(TO_CHAR(ATTRIBUTE_NUMBER3), '') || '","'
                || NVL(TO_CHAR(ATTRIBUTE_NUMBER4), '') || '","'
                || NVL(TO_CHAR(ATTRIBUTE_NUMBER5), '') || '","'
                || NVL(TO_CHAR(ATTRIBUTE_NUMBER6), '') || '","'
                || NVL(TO_CHAR(ATTRIBUTE_NUMBER7), '') || '","'
                || NVL(TO_CHAR(ATTRIBUTE_NUMBER8), '') || '","'
                || NVL(TO_CHAR(ATTRIBUTE_NUMBER9), '') || '","'
                || NVL(TO_CHAR(ATTRIBUTE_NUMBER10), '') || '","'
                || REPLACE(NVL(GLOBAL_ATTRIBUTE_CATEGORY,''), '"', '""') || '","'
                || REPLACE(NVL(GLOBAL_ATTRIBUTE1,''), '"', '""') || '","'
                || REPLACE(NVL(GLOBAL_ATTRIBUTE2,''), '"', '""') || '","'
                || REPLACE(NVL(GLOBAL_ATTRIBUTE3,''), '"', '""') || '","'
                || REPLACE(NVL(GLOBAL_ATTRIBUTE4,''), '"', '""') || '","'
                || REPLACE(NVL(GLOBAL_ATTRIBUTE5,''), '"', '""') || '","'
                || REPLACE(NVL(GLOBAL_ATTRIBUTE6,''), '"', '""') || '","'
                || REPLACE(NVL(GLOBAL_ATTRIBUTE7,''), '"', '""') || '","'
                || REPLACE(NVL(GLOBAL_ATTRIBUTE8,''), '"', '""') || '","'
                || REPLACE(NVL(GLOBAL_ATTRIBUTE9,''), '"', '""') || '","'
                || REPLACE(NVL(GLOBAL_ATTRIBUTE10,''), '"', '""') || '","'
                || REPLACE(NVL(GLOBAL_ATTRIBUTE11,''), '"', '""') || '","'
                || REPLACE(NVL(GLOBAL_ATTRIBUTE12,''), '"', '""') || '","'
                || REPLACE(NVL(GLOBAL_ATTRIBUTE13,''), '"', '""') || '","'
                || REPLACE(NVL(GLOBAL_ATTRIBUTE14,''), '"', '""') || '","'
                || REPLACE(NVL(GLOBAL_ATTRIBUTE15,''), '"', '""') || '","'
                || REPLACE(NVL(GLOBAL_ATTRIBUTE16,''), '"', '""') || '","'
                || REPLACE(NVL(GLOBAL_ATTRIBUTE17,''), '"', '""') || '","'
                || REPLACE(NVL(GLOBAL_ATTRIBUTE18,''), '"', '""') || '","'
                || REPLACE(NVL(GLOBAL_ATTRIBUTE19,''), '"', '""') || '","'
                || REPLACE(NVL(GLOBAL_ATTRIBUTE20,''), '"', '""') || '","'
                || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_DATE1, 'YYYY/MM/DD'), '') || '","'
                || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_DATE2, 'YYYY/MM/DD'), '') || '","'
                || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_DATE3, 'YYYY/MM/DD'), '') || '","'
                || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_DATE4, 'YYYY/MM/DD'), '') || '","'
                || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_DATE5, 'YYYY/MM/DD'), '') || '","'
                || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_DATE6, 'YYYY/MM/DD'), '') || '","'
                || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_DATE7, 'YYYY/MM/DD'), '') || '","'
                || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_DATE8, 'YYYY/MM/DD'), '') || '","'
                || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_DATE9, 'YYYY/MM/DD'), '') || '","'
                || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_DATE10, 'YYYY/MM/DD'), '') || '","'
                || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_TIMESTAMP1, 'YYYY/MM/DD HH24:MI:SS'), '') || '","'
                || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_TIMESTAMP2, 'YYYY/MM/DD HH24:MI:SS'), '') || '","'
                || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_TIMESTAMP3, 'YYYY/MM/DD HH24:MI:SS'), '') || '","'
                || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_TIMESTAMP4, 'YYYY/MM/DD HH24:MI:SS'), '') || '","'
                || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_TIMESTAMP5, 'YYYY/MM/DD HH24:MI:SS'), '') || '","'
                || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_TIMESTAMP6, 'YYYY/MM/DD HH24:MI:SS'), '') || '","'
                || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_TIMESTAMP7, 'YYYY/MM/DD HH24:MI:SS'), '') || '","'
                || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_TIMESTAMP8, 'YYYY/MM/DD HH24:MI:SS'), '') || '","'
                || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_TIMESTAMP9, 'YYYY/MM/DD HH24:MI:SS'), '') || '","'
                || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_TIMESTAMP10, 'YYYY/MM/DD HH24:MI:SS'), '') || '","'
                || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_NUMBER1), '') || '","'
                || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_NUMBER2), '') || '","'
                || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_NUMBER3), '') || '","'
                || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_NUMBER4), '') || '","'
                || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_NUMBER5), '') || '","'
                || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_NUMBER6), '') || '","'
                || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_NUMBER7), '') || '","'
                || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_NUMBER8), '') || '","'
                || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_NUMBER9), '') || '","'
                || NVL(TO_CHAR(GLOBAL_ATTRIBUTE_NUMBER10), '') || '","'
                || REPLACE(NVL(PARTY_NUMBER,''), '"', '""') || '","'
                || REPLACE(NVL(SERVICE_LEVEL_CODE,''), '"', '""') || '","'
                || REPLACE(NVL(EXCLUSIVE_PAYMENT_FLAG,''), '"', '""') || '","'
                || REPLACE(NVL(REMIT_ADVICE_DELIVERY_METHOD,''), '"', '""') || '","'
                || REPLACE(NVL(REMIT_ADVICE_EMAIL,''), '"', '""') || '","'
                || REPLACE(NVL(REMIT_ADVICE_FAX,''), '"', '""') || '","'
                || REPLACE(NVL(DATAFOX_COMPANY_ID,''), '"', '""') || '"'
                || CHR(13) || CHR(10) AS csv_line
            FROM   DMT_OWNER.DMT_POZ_SUPPLIERS_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS         = 'STAGED'
            ORDER BY TFM_SEQUENCE_ID
        ) LOOP
            l_row_count := l_row_count + 1;
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;

        IF l_row_count = 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'No VALIDATED supplier rows found. Skipping zip generation.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            x_fbdi_zip := NULL;
            x_filename := NULL;
            DBMS_LOB.FREETEMPORARY(l_csv);
            RETURN;
        END IF;

        -- Log CSV content BEFORE zipping (autonomous txn — always committed even if hang/error)
        DMT_UTIL_PKG.LOG(p_run_id,
            'CSV payload pre-zip (' || l_row_count || ' rows): ' || DBMS_LOB.SUBSTR(l_csv, 32767, 1),
            'INFO', C_PKG, C_PROC);

        l_csv_blob := clob_to_blob(l_csv);

        -- Persist CSV for traceability
        INSERT INTO DMT_OWNER.DMT_FBDI_CSV_TBL (
            FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME, ROW_COUNT, CSV_CONTENT, CREATED_DATE
        ) VALUES (
            DMT_OWNER.DMT_FBDI_CSV_ID_SEQ.NEXTVAL, p_run_id,
            'Suppliers', C_CSV_FILE, l_row_count, l_csv, SYSDATE
        );
        DBMS_LOB.FREETEMPORARY(l_csv);

        DBMS_LOB.CREATETEMPORARY(x_fbdi_zip, TRUE);
        UTL_ZIP.add1file(x_fbdi_zip, C_CSV_FILE, l_csv_blob);
        UTL_ZIP.finish_zip(x_fbdi_zip);
        DBMS_LOB.FREETEMPORARY(l_csv_blob);

        x_filename := 'Suppliers_' || p_run_id || '.zip';

        -- Persist ZIP for traceability
        INSERT INTO DMT_OWNER.DMT_FBDI_ZIP_TBL (
            FBDI_ZIP_ID, FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME, ZIP_SIZE_BYTES, ZIP_CONTENT, CREATED_DATE
        ) VALUES (
            DMT_OWNER.DMT_FBDI_ZIP_ID_SEQ.NEXTVAL,
            (SELECT MAX(FBDI_CSV_ID) FROM DMT_OWNER.DMT_FBDI_CSV_TBL
             WHERE RUN_ID = p_run_id AND OBJECT_TYPE = 'Suppliers'),
            p_run_id, 'Suppliers', x_filename,
            DBMS_LOB.GETLENGTH(x_fbdi_zip), x_fbdi_zip, SYSDATE
        );

        UPDATE DMT_OWNER.DMT_POZ_SUPPLIERS_TFM_TBL
        SET    TFM_STATUS             = 'GENERATED',
               FBDI_CSV_ID       = (SELECT MAX(FBDI_CSV_ID) FROM DMT_OWNER.DMT_FBDI_CSV_TBL
                                    WHERE RUN_ID = p_run_id AND OBJECT_TYPE = 'Suppliers'),
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID    = p_run_id
        AND    TFM_STATUS             = 'STAGED';

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Supplier FBDI generation complete. Rows: ' || l_row_count ||
                                ' | File: ' || x_filename ||
                                ' | Zip bytes: ' || DBMS_LOB.GETLENGTH(x_fbdi_zip),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'Supplier FBDI generation failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END GENERATE_FBDI;

END DMT_POZ_SUP_FBDI_GEN_PKG;
/
