-- PACKAGE BODY DMT_POZ_SUP_SITE_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_POZ_SUP_SITE_FBDI_GEN_PKG" AS
-- ============================================================
-- DMT_POZ_SUP_SITE_FBDI_GEN_PKG Body
-- Generates PozSupplierSitesInt.csv zipped for Fusion FBDI import.
-- Interface table: POZ_SUPPLIER_SITES_INT
-- ============================================================

    C_PKG      CONSTANT VARCHAR2(50) := 'DMT_POZ_SUP_SITE_FBDI_GEN_PKG';
    C_CSV_FILE CONSTANT VARCHAR2(50) := 'PozSupplierSitesInt.csv';

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
            p_message        => 'Supplier Site FBDI generation start.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);
        FOR r IN (
            SELECT *
            FROM   DMT_OWNER.DMT_POZ_SUP_SITE_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS         = 'STAGED'
            ORDER BY TFM_SEQUENCE_ID
        ) LOOP
            l_row_count := l_row_count + 1;
            DBMS_LOB.APPEND(l_csv,
                q(r.IMPORT_ACTION)                  || ',' ||
                q(r.VENDOR_NAME)                    || ',' ||
                q(r.PROCUREMENT_BUSINESS_UNIT_NAME) || ',' ||
                q(r.PARTY_SITE_NAME)                || ',' ||
                q(r.VENDOR_SITE_CODE)               || ',' ||
                q(r.VENDOR_SITE_CODE_NEW)           || ',' ||
                qd(r.INACTIVE_DATE)                 || ',' ||
                q(r.RFQ_ONLY_SITE_FLAG)             || ',' ||
                q(r.PURCHASING_SITE_FLAG)           || ',' ||
                q(r.PCARD_SITE_FLAG)                || ',' ||
                q(r.PAY_SITE_FLAG)                  || ',' ||
                q(r.PRIMARY_PAY_SITE_FLAG)          || ',' ||
                q(r.TAX_REPORTING_SITE_FLAG)        || ',' ||
                q(r.VENDOR_SITE_CODE_ALT)           || ',' ||
                q(r.CUSTOMER_NUM)                   || ',' ||
                q(r.B2B_COMM_METHOD_CODE)           || ',' ||
                q(r.B2B_SITE_CODE)                  || ',' ||
                q(r.SUPPLIER_NOTIF_METHOD)          || ',' ||
                q(r.EMAIL_ADDRESS)                  || ',' ||
                q(r.FAX_COUNTRY_CODE)               || ',' ||
                q(r.FAX_AREA_CODE)                  || ',' ||
                q(r.FAX)                            || ',' ||
                q(r.HOLD_FLAG)                      || ',' ||
                q(r.PURCHASING_HOLD_REASON)         || ',' ||
                q(r.CARRIER)                        || ',' ||
                q(r.MODE_OF_TRANSPORT_CODE)         || ',' ||
                q(r.SERVICE_LEVEL_CODE)             || ',' ||
                q(r.FREIGHT_TERMS_LOOKUP_CODE)      || ',' ||
                q(r.PAY_ON_CODE)                    || ',' ||
                q(r.FOB_LOOKUP_CODE)                || ',' ||
                q(r.COUNTRY_OF_ORIGIN_CODE)         || ',' ||
                q(r.BUYER_MANAGED_TRANSPORT_FLAG)   || ',' ||
                q(r.PAY_ON_USE_FLAG)                || ',' ||
                qn(r.AGING_ONSET_POINT)             || ',' ||
                qn(r.AGING_PERIOD_DAYS)             || ',' ||
                q(r.CONSUMPTION_ADVICE_FREQUENCY)   || ',' ||
                q(r.CONSUMPTION_ADVICE_SUMMARY)     || ',' ||
                q(r.DEFAULT_PAY_SITE_CODE)          || ',' ||
                q(r.PAY_ON_RECEIPT_SUMMARY_CODE)    || ',' ||
                q(r.GAPLESS_INV_NUM_FLAG)           || ',' ||
                q(r.SELLING_COMPANY_IDENTIFIER)     || ',' ||
                q(r.CREATE_DEBIT_MEMO_FLAG)         || ',' ||
                q(r.ENFORCE_SHIP_TO_LOCATION_CODE)  || ',' ||
                qn(r.RECEIVING_ROUTING_ID)          || ',' ||
                qn(r.QTY_RCV_TOLERANCE)             || ',' ||
                q(r.QTY_RCV_EXCEPTION_CODE)         || ',' ||
                qn(r.DAYS_EARLY_RECEIPT_ALLOWED)    || ',' ||
                qn(r.DAYS_LATE_RECEIPT_ALLOWED)     || ',' ||
                q(r.ALLOW_SUBSTITUTE_RECEIPTS_FLAG) || ',' ||
                q(r.ALLOW_UNORDERED_RECEIPTS_FLAG)  || ',' ||
                q(r.RECEIPT_DAYS_EXCEPTION_CODE)    || ',' ||
                q(r.INVOICE_CURRENCY_CODE)          || ',' ||
                qn(r.INVOICE_AMOUNT_LIMIT)          || ',' ||
                q(r.MATCH_OPTION)                   || ',' ||
                q(r.MATCH_APPROVAL_LEVEL)           || ',' ||
                q(r.PAYMENT_CURRENCY_CODE)          || ',' ||
                qn(r.PAYMENT_PRIORITY)              || ',' ||
                q(r.PAY_GROUP_LOOKUP_CODE)          || ',' ||
                q(r.TOLERANCE_NAME)                 || ',' ||
                qn(r.SERVICES_TOLERANCE)            || ',' ||
                q(r.HOLD_ALL_PAYMENTS_FLAG)         || ',' ||
                q(r.HOLD_UNMATCHED_INVOICES_FLAG)   || ',' ||
                q(r.HOLD_FUTURE_PAYMENTS_FLAG)      || ',' ||
                q(r.HOLD_BY)                        || ',' ||
                qd(r.PAYMENT_HOLD_DATE)             || ',' ||
                q(r.HOLD_REASON)                    || ',' ||
                q(r.TERMS_NAME)                     || ',' ||
                q(r.TERMS_DATE_BASIS)               || ',' ||
                q(r.PAY_DATE_BASIS_LOOKUP_CODE)     || ',' ||
                q(r.BANK_CHARGE_DEDUCTION_TYPE)     || ',' ||
                q(r.ALWAYS_TAKE_DISC_FLAG)          || ',' ||
                q(r.EXCLUDE_FREIGHT_FROM_DISCOUNT)  || ',' ||
                q(r.EXCLUDE_TAX_FROM_DISCOUNT)      || ',' ||
                q(r.AUTO_CALCULATE_INTEREST_FLAG)   || ',' ||
                q(r.VAT_CODE)                       || ',' ||
                q(r.VAT_REGISTRATION_NUM)           || ',' ||
                q(r.PAYMENT_METHOD_LOOKUP_CODE)     || ',' ||
                q(r.DELIVERY_CHANNEL_CODE)          || ',' ||
                q(r.BANK_INSTRUCTION1_CODE)         || ',' ||
                q(r.BANK_INSTRUCTION2_CODE)         || ',' ||
                q(r.BANK_INSTRUCTION_DETAILS)       || ',' ||
                qn(r.SETTLEMENT_PRIORITY)           || ',' ||
                q(r.PAYMENT_TEXT_MESSAGE1)          || ',' ||
                q(r.PAYMENT_TEXT_MESSAGE2)          || ',' ||
                q(r.PAYMENT_TEXT_MESSAGE3)          || ',' ||
                q(r.IBY_BANK_CHARGE_BEARER)         || ',' ||
                q(r.PAYMENT_REASON_CODE)            || ',' ||
                q(r.PAYMENT_REASON_COMMENTS)        || ',' ||
                q(r.REMIT_ADVICE_DELIVERY_METHOD)   || ',' ||
                q(r.REMITTANCE_EMAIL)               || ',' ||
                q(r.REMITTANCE_FAX)                 || ',' ||
                q(r.ATTRIBUTE_CATEGORY)             || ',' ||
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
                qd(r.ATTRIBUTE_DATE1)  || ',' || qd(r.ATTRIBUTE_DATE2)  || ',' ||
                qd(r.ATTRIBUTE_DATE3)  || ',' || qd(r.ATTRIBUTE_DATE4)  || ',' ||
                qd(r.ATTRIBUTE_DATE5)  || ',' || qd(r.ATTRIBUTE_DATE6)  || ',' ||
                qd(r.ATTRIBUTE_DATE7)  || ',' || qd(r.ATTRIBUTE_DATE8)  || ',' ||
                qd(r.ATTRIBUTE_DATE9)  || ',' || qd(r.ATTRIBUTE_DATE10) || ',' ||
                qt(r.ATTRIBUTE_TIMESTAMP1)  || ',' || qt(r.ATTRIBUTE_TIMESTAMP2)  || ',' ||
                qt(r.ATTRIBUTE_TIMESTAMP3)  || ',' || qt(r.ATTRIBUTE_TIMESTAMP4)  || ',' ||
                qt(r.ATTRIBUTE_TIMESTAMP5)  || ',' || qt(r.ATTRIBUTE_TIMESTAMP6)  || ',' ||
                qt(r.ATTRIBUTE_TIMESTAMP7)  || ',' || qt(r.ATTRIBUTE_TIMESTAMP8)  || ',' ||
                qt(r.ATTRIBUTE_TIMESTAMP9)  || ',' || qt(r.ATTRIBUTE_TIMESTAMP10) || ',' ||
                qn(r.ATTRIBUTE_NUMBER1)  || ',' || qn(r.ATTRIBUTE_NUMBER2)  || ',' ||
                qn(r.ATTRIBUTE_NUMBER3)  || ',' || qn(r.ATTRIBUTE_NUMBER4)  || ',' ||
                qn(r.ATTRIBUTE_NUMBER5)  || ',' || qn(r.ATTRIBUTE_NUMBER6)  || ',' ||
                qn(r.ATTRIBUTE_NUMBER7)  || ',' || qn(r.ATTRIBUTE_NUMBER8)  || ',' ||
                qn(r.ATTRIBUTE_NUMBER9)  || ',' || qn(r.ATTRIBUTE_NUMBER10) || ',' ||
                q(r.GLOBAL_ATTRIBUTE_CATEGORY)  || ',' ||
                q(r.GLOBAL_ATTRIBUTE1)  || ',' || q(r.GLOBAL_ATTRIBUTE2)  || ',' ||
                q(r.GLOBAL_ATTRIBUTE3)  || ',' || q(r.GLOBAL_ATTRIBUTE4)  || ',' ||
                q(r.GLOBAL_ATTRIBUTE5)  || ',' || q(r.GLOBAL_ATTRIBUTE6)  || ',' ||
                q(r.GLOBAL_ATTRIBUTE7)  || ',' || q(r.GLOBAL_ATTRIBUTE8)  || ',' ||
                q(r.GLOBAL_ATTRIBUTE9)  || ',' || q(r.GLOBAL_ATTRIBUTE10) || ',' ||
                q(r.GLOBAL_ATTRIBUTE11) || ',' || q(r.GLOBAL_ATTRIBUTE12) || ',' ||
                q(r.GLOBAL_ATTRIBUTE13) || ',' || q(r.GLOBAL_ATTRIBUTE14) || ',' ||
                q(r.GLOBAL_ATTRIBUTE15) || ',' || q(r.GLOBAL_ATTRIBUTE16) || ',' ||
                q(r.GLOBAL_ATTRIBUTE17) || ',' || q(r.GLOBAL_ATTRIBUTE18) || ',' ||
                q(r.GLOBAL_ATTRIBUTE19) || ',' || q(r.GLOBAL_ATTRIBUTE20) || ',' ||
                qd(r.GLOBAL_ATTRIBUTE_DATE1)  || ',' || qd(r.GLOBAL_ATTRIBUTE_DATE2)  || ',' ||
                qd(r.GLOBAL_ATTRIBUTE_DATE3)  || ',' || qd(r.GLOBAL_ATTRIBUTE_DATE4)  || ',' ||
                qd(r.GLOBAL_ATTRIBUTE_DATE5)  || ',' || qd(r.GLOBAL_ATTRIBUTE_DATE6)  || ',' ||
                qd(r.GLOBAL_ATTRIBUTE_DATE7)  || ',' || qd(r.GLOBAL_ATTRIBUTE_DATE8)  || ',' ||
                qd(r.GLOBAL_ATTRIBUTE_DATE9)  || ',' || qd(r.GLOBAL_ATTRIBUTE_DATE10) || ',' ||
                qt(r.GLOBAL_ATTRIBUTE_TIMESTAMP1)  || ',' || qt(r.GLOBAL_ATTRIBUTE_TIMESTAMP2)  || ',' ||
                qt(r.GLOBAL_ATTRIBUTE_TIMESTAMP3)  || ',' || qt(r.GLOBAL_ATTRIBUTE_TIMESTAMP4)  || ',' ||
                qt(r.GLOBAL_ATTRIBUTE_TIMESTAMP5)  || ',' || qt(r.GLOBAL_ATTRIBUTE_TIMESTAMP6)  || ',' ||
                qt(r.GLOBAL_ATTRIBUTE_TIMESTAMP7)  || ',' || qt(r.GLOBAL_ATTRIBUTE_TIMESTAMP8)  || ',' ||
                qt(r.GLOBAL_ATTRIBUTE_TIMESTAMP9)  || ',' || qt(r.GLOBAL_ATTRIBUTE_TIMESTAMP10) || ',' ||
                qn(r.GLOBAL_ATTRIBUTE_NUMBER1)  || ',' || qn(r.GLOBAL_ATTRIBUTE_NUMBER2)  || ',' ||
                qn(r.GLOBAL_ATTRIBUTE_NUMBER3)  || ',' || qn(r.GLOBAL_ATTRIBUTE_NUMBER4)  || ',' ||
                qn(r.GLOBAL_ATTRIBUTE_NUMBER5)  || ',' || qn(r.GLOBAL_ATTRIBUTE_NUMBER6)  || ',' ||
                qn(r.GLOBAL_ATTRIBUTE_NUMBER7)  || ',' || qn(r.GLOBAL_ATTRIBUTE_NUMBER8)  || ',' ||
                qn(r.GLOBAL_ATTRIBUTE_NUMBER9)  || ',' || qn(r.GLOBAL_ATTRIBUTE_NUMBER10) || ',' ||
                q(r.PO_ACK_REQD_CODE)               || ',' ||
                qn(r.PO_ACK_REQD_DAYS)              || ',' ||
                q(r.INVOICE_CHANNEL)                || ',' ||
                q(r.PAYEE_SERVICE_LEVEL_CODE)       || ',' ||
                q(r.EXCLUSIVE_PAYMENT_FLAG)         || ',' ||
                q(r.OVERRIDE_B2B_COMM_CODE)
                || l_crlf
            );
        END LOOP;

        IF l_row_count = 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'No VALIDATED supplier site rows found. Skipping zip generation.',
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

        x_filename := 'SupplierSites_' || p_run_id || '.zip';

        -- FBDI CSV<->ZIP remodel: register the physical CSV as its own row, then
        -- build the zip from that persisted row via the shared helper pair.
        SELECT DMT_OWNER.DMT_FBDI_ZIP_ID_SEQ.NEXTVAL INTO l_zip_id FROM DUAL;
        l_csv_id := DMT_UTIL_PKG.REGISTER_CSV(p_run_id, l_zip_id, 1, 'SupplierSites', C_CSV_FILE, l_row_count, l_csv);
        DMT_UTIL_PKG.BUILD_ZIP_FROM_CSVS(p_run_id, l_zip_id, 'SupplierSites', x_filename, x_fbdi_zip, l_bytes);
        DBMS_LOB.FREETEMPORARY(l_csv);

        UPDATE DMT_OWNER.DMT_POZ_SUP_SITE_TFM_TBL
        SET    TFM_STATUS             = 'GENERATED',
               FBDI_CSV_ID       = l_csv_id,
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID    = p_run_id
        AND    TFM_STATUS             = 'STAGED';

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Supplier Site FBDI generation complete. Rows: ' || l_row_count ||
                                ' | File: ' || x_filename ||
                                ' | Zip bytes: ' || DBMS_LOB.GETLENGTH(x_fbdi_zip),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'Supplier Site FBDI generation failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END GENERATE_FBDI;

END DMT_POZ_SUP_SITE_FBDI_GEN_PKG;
/
