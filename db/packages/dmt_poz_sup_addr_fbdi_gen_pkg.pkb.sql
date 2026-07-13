-- PACKAGE BODY DMT_POZ_SUP_ADDR_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_POZ_SUP_ADDR_FBDI_GEN_PKG" AS
-- ============================================================
-- DMT_POZ_SUP_ADDR_FBDI_GEN_PKG Body
-- Generates PozSupAddressesInt.csv zipped for Fusion FBDI import.
-- Interface table: POZ_SUP_ADDRESSES_INT
-- ============================================================

    C_PKG      CONSTANT VARCHAR2(50) := 'DMT_POZ_SUP_ADDR_FBDI_GEN_PKG';
    C_CSV_FILE CONSTANT VARCHAR2(50) := 'PozSupAddressesInt.csv';

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
        C_PROC     CONSTANT VARCHAR2(30) := 'GENERATE_FBDI';
        l_csv      CLOB;
        l_csv_blob BLOB;
        l_row_count NUMBER := 0;
        l_crlf     CONSTANT VARCHAR2(2) := CHR(13) || CHR(10);
        l_zip_id   NUMBER;
        l_csv_id   NUMBER;
        l_bytes    NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Supplier Address FBDI generation start.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);
        FOR r IN (
            SELECT *
            FROM   DMT_OWNER.DMT_POZ_SUP_ADDR_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS         = 'STAGED'
            ORDER BY TFM_SEQUENCE_ID
        ) LOOP
            l_row_count := l_row_count + 1;
            DBMS_LOB.APPEND(l_csv,
                q(r.IMPORT_ACTION)              || ',' ||
                q(r.VENDOR_NAME)                || ',' ||
                q(r.PARTY_SITE_NAME)            || ',' ||
                q(r.PARTY_SITE_NAME_NEW)        || ',' ||
                q(r.COUNTRY)                    || ',' ||
                q(r.ADDRESS_LINE1)              || ',' ||
                q(r.ADDRESS_LINE2)              || ',' ||
                q(r.ADDRESS_LINE3)              || ',' ||
                q(r.ADDRESS_LINE4)              || ',' ||
                q(r.ADDRESS_LINES_PHONETIC)     || ',' ||
                q(r.ADDR_ELEMENT_ATTRIBUTE1)    || ',' ||
                q(r.ADDR_ELEMENT_ATTRIBUTE2)    || ',' ||
                q(r.ADDR_ELEMENT_ATTRIBUTE3)    || ',' ||
                q(r.ADDR_ELEMENT_ATTRIBUTE4)    || ',' ||
                q(r.ADDR_ELEMENT_ATTRIBUTE5)    || ',' ||
                q(r.BUILDING)                   || ',' ||
                q(r.FLOOR_NUMBER)               || ',' ||
                q(r.CITY)                       || ',' ||
                q(r.STATE)                      || ',' ||
                q(r.PROVINCE)                   || ',' ||
                q(r.COUNTY)                     || ',' ||
                q(r.POSTAL_CODE)                || ',' ||
                q(r.POSTAL_PLUS4_CODE)          || ',' ||
                q(r.ADDRESSEE)                  || ',' ||
                q(r.GLOBAL_LOCATION_NUMBER)     || ',' ||
                q(r.PARTY_SITE_LANGUAGE)        || ',' ||
                qd(r.INACTIVE_DATE)             || ',' ||
                q(r.PHONE_COUNTRY_CODE)         || ',' ||
                q(r.PHONE_AREA_CODE)            || ',' ||
                q(r.PHONE)                      || ',' ||
                q(r.PHONE_EXTENSION)            || ',' ||
                q(r.FAX_COUNTRY_CODE)           || ',' ||
                q(r.FAX_AREA_CODE)              || ',' ||
                q(r.FAX)                        || ',' ||
                q(r.RFQ_OR_BIDDING_PURPOSE_FLAG)|| ',' ||
                q(r.ORDERING_PURPOSE_FLAG)      || ',' ||
                q(r.REMIT_TO_PURPOSE_FLAG)      || ',' ||
                q(r.ATTRIBUTE_CATEGORY)         || ',' ||
                q(r.ATTRIBUTE1)  || ',' || q(r.ATTRIBUTE2)  || ',' ||
                q(r.ATTRIBUTE3)  || ',' || q(r.ATTRIBUTE4)  || ',' ||
                q(r.ATTRIBUTE5)  || ',' || q(r.ATTRIBUTE6)  || ',' ||
                q(r.ATTRIBUTE7)  || ',' || q(r.ATTRIBUTE8)  || ',' ||
                q(r.ATTRIBUTE9)  || ',' || q(r.ATTRIBUTE10) || ',' ||
                q(r.ATTRIBUTE11) || ',' || q(r.ATTRIBUTE12) || ',' ||
                q(r.ATTRIBUTE13) || ',' || q(r.ATTRIBUTE14) || ',' ||
                q(r.ATTRIBUTE15) || ',' || q(r.ATTRIBUTE16) || ',' ||
                q(r.ATTRIBUTE17) || ',' || q(r.ATTRIBUTE18) || ',' ||
                q(r.ATTRIBUTE19) || ',' || q(r.ATTRIBUTE20) || ',' ||
                q(r.ATTRIBUTE21) || ',' || q(r.ATTRIBUTE22) || ',' ||
                q(r.ATTRIBUTE23) || ',' || q(r.ATTRIBUTE24) || ',' ||
                q(r.ATTRIBUTE25) || ',' || q(r.ATTRIBUTE26) || ',' ||
                q(r.ATTRIBUTE27) || ',' || q(r.ATTRIBUTE28) || ',' ||
                q(r.ATTRIBUTE29) || ',' || q(r.ATTRIBUTE30) || ',' ||
                qn(r.ATTRIBUTE_NUMBER1)  || ',' || qn(r.ATTRIBUTE_NUMBER2)  || ',' ||
                qn(r.ATTRIBUTE_NUMBER3)  || ',' || qn(r.ATTRIBUTE_NUMBER4)  || ',' ||
                qn(r.ATTRIBUTE_NUMBER5)  || ',' || qn(r.ATTRIBUTE_NUMBER6)  || ',' ||
                qn(r.ATTRIBUTE_NUMBER7)  || ',' || qn(r.ATTRIBUTE_NUMBER8)  || ',' ||
                qn(r.ATTRIBUTE_NUMBER9)  || ',' || qn(r.ATTRIBUTE_NUMBER10) || ',' ||
                qn(r.ATTRIBUTE_NUMBER11) || ',' || qn(r.ATTRIBUTE_NUMBER12) || ',' ||
                qd(r.ATTRIBUTE_DATE1)  || ',' || qd(r.ATTRIBUTE_DATE2)  || ',' ||
                qd(r.ATTRIBUTE_DATE3)  || ',' || qd(r.ATTRIBUTE_DATE4)  || ',' ||
                qd(r.ATTRIBUTE_DATE5)  || ',' || qd(r.ATTRIBUTE_DATE6)  || ',' ||
                qd(r.ATTRIBUTE_DATE7)  || ',' || qd(r.ATTRIBUTE_DATE8)  || ',' ||
                qd(r.ATTRIBUTE_DATE9)  || ',' || qd(r.ATTRIBUTE_DATE10) || ',' ||
                qd(r.ATTRIBUTE_DATE11) || ',' || qd(r.ATTRIBUTE_DATE12) || ',' ||
                q(r.EMAIL_ADDRESS)              || ',' ||
                q(r.DELIVERY_CHANNEL_CODE)      || ',' ||
                q(r.BANK_INSTRUCTION1_CODE)     || ',' ||
                q(r.BANK_INSTRUCTION2_CODE)     || ',' ||
                q(r.BANK_INSTRUCTION_DETAILS)   || ',' ||
                qn(r.SETTLEMENT_PRIORITY)       || ',' ||
                q(r.PAYMENT_TEXT_MESSAGE1)      || ',' ||
                q(r.PAYMENT_TEXT_MESSAGE2)      || ',' ||
                q(r.PAYMENT_TEXT_MESSAGE3)      || ',' ||
                q(r.SERVICE_LEVEL_CODE)         || ',' ||
                q(r.EXCLUSIVE_PAYMENT_FLAG)     || ',' ||
                q(r.IBY_BANK_CHARGE_BEARER)     || ',' ||
                q(r.PAYMENT_REASON_CODE)        || ',' ||
                q(r.PAYMENT_REASON_COMMENTS)    || ',' ||
                q(r.REMIT_ADVICE_DELIVERY_METHOD) || ',' ||
                q(r.REMIT_ADVICE_EMAIL)         || ',' ||
                q(r.REMIT_ADVICE_FAX)
                || l_crlf
            );
        END LOOP;

        IF l_row_count = 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'No VALIDATED supplier address rows found. Skipping zip generation.',
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

        x_filename := 'SupplierAddresses_' || p_run_id || '.zip';

        -- FBDI CSV<->ZIP remodel: register the physical CSV as its own row, then
        -- build the zip from that persisted row via the shared helper pair.
        SELECT DMT_OWNER.DMT_FBDI_ZIP_ID_SEQ.NEXTVAL INTO l_zip_id FROM DUAL;
        DMT_UTIL_PKG.REGISTER_CSV(p_run_id, l_zip_id, 1, 'SupplierAddresses', C_CSV_FILE, l_row_count, l_csv, l_csv_id);
        DMT_UTIL_PKG.BUILD_ZIP_FROM_CSVS(p_run_id, l_zip_id, 'SupplierAddresses', x_filename, x_fbdi_zip, l_bytes);
        DBMS_LOB.FREETEMPORARY(l_csv);

        UPDATE DMT_OWNER.DMT_POZ_SUP_ADDR_TFM_TBL
        SET    TFM_STATUS             = 'GENERATED',
               FBDI_CSV_ID       = l_csv_id,
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID    = p_run_id
        AND    TFM_STATUS             = 'STAGED';

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Supplier Address FBDI generation complete. Rows: ' || l_row_count ||
                                ' | File: ' || x_filename ||
                                ' | Zip bytes: ' || DBMS_LOB.GETLENGTH(x_fbdi_zip),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'Supplier Address FBDI generation failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END GENERATE_FBDI;

END DMT_POZ_SUP_ADDR_FBDI_GEN_PKG;
/
