-- PACKAGE BODY DMT_POZ_SUP_SITE_ASSN_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_POZ_SUP_SITE_ASSN_FBDI_GEN_PKG" AS
-- ============================================================
-- DMT_POZ_SUP_SITE_ASSN_FBDI_GEN_PKG Body
-- Generates PozSiteAssignmentsInt.csv zipped for Fusion FBDI import.
-- Interface table: POZ_SITE_ASSIGNMENTS_INT
-- ============================================================

    C_PKG      CONSTANT VARCHAR2(50) := 'DMT_POZ_SUP_SITE_ASSN_FBDI_GEN_PKG';
    C_CSV_FILE CONSTANT VARCHAR2(50) := 'PozSiteAssignmentsInt.csv';

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
            p_message        => 'Supplier Site Assignment FBDI generation start.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);
        FOR r IN (
            SELECT *
            FROM   DMT_OWNER.DMT_POZ_SUP_SITE_ASSN_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS         = 'STAGED'
            ORDER BY TFM_SEQUENCE_ID
        ) LOOP
            l_row_count := l_row_count + 1;
            DBMS_LOB.APPEND(l_csv,
                q(r.IMPORT_ACTION)                  || ',' ||
                q(r.VENDOR_NAME)                    || ',' ||
                q(r.VENDOR_SITE_CODE)               || ',' ||
                q(r.PROCUREMENT_BUSINESS_UNIT_NAME) || ',' ||
                q(r.BUSINESS_UNIT_NAME)             || ',' ||
                q(r.BILL_TO_BU_NAME)                || ',' ||
                q(r.SHIP_TO_LOCATION_CODE)          || ',' ||
                q(r.BILL_TO_LOCATION_CODE)          || ',' ||
                q(r.ALLOW_AWT_FLAG)                 || ',' ||
                q(r.AWT_GROUP_NAME)                 || ',' ||
                q(r.ACCTS_PAY_CONCAT_SEGMENTS)      || ',' ||
                q(r.PREPAY_CONCAT_SEGMENTS)         || ',' ||
                q(r.FUTURE_DATED_CONCAT_SEGMENTS)   || ',' ||
                q(r.DISTRIBUTION_SET_NAME)          || ',' ||
                qd(r.INACTIVE_DATE)
                || l_crlf
            );
        END LOOP;

        IF l_row_count = 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'No VALIDATED supplier site assignment rows found. Skipping zip generation.',
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

        x_filename := 'SupplierSiteAssignments_' || p_run_id || '.zip';

        -- FBDI CSV<->ZIP remodel: register the physical CSV as its own row, then
        -- build the zip from that persisted row via the shared helper pair.
        SELECT DMT_OWNER.DMT_FBDI_ZIP_ID_SEQ.NEXTVAL INTO l_zip_id FROM DUAL;
        l_csv_id := DMT_UTIL_PKG.REGISTER_CSV(p_run_id, l_zip_id, 1, 'SupplierSiteAssignments', C_CSV_FILE, l_row_count, l_csv);
        DMT_UTIL_PKG.BUILD_ZIP_FROM_CSVS(p_run_id, l_zip_id, 'SupplierSiteAssignments', x_filename, x_fbdi_zip, l_bytes);
        DBMS_LOB.FREETEMPORARY(l_csv);

        UPDATE DMT_OWNER.DMT_POZ_SUP_SITE_ASSN_TFM_TBL
        SET    TFM_STATUS             = 'GENERATED',
               FBDI_CSV_ID       = l_csv_id,
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID    = p_run_id
        AND    TFM_STATUS             = 'STAGED';

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Supplier Site Assignment FBDI generation complete. Rows: ' || l_row_count ||
                                ' | File: ' || x_filename ||
                                ' | Zip bytes: ' || DBMS_LOB.GETLENGTH(x_fbdi_zip),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'Supplier Site Assignment FBDI generation failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END GENERATE_FBDI;

END DMT_POZ_SUP_SITE_ASSN_FBDI_GEN_PKG;
/
