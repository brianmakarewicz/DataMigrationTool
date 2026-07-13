-- PACKAGE BODY DMT_BILLING_EVENT_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_BILLING_EVENT_FBDI_GEN_PKG" 
AS
    C_PKG CONSTANT VARCHAR2(50) := 'DMT_BILLING_EVENT_FBDI_GEN_PKG';

-- ============================================================
-- DMT_BILLING_EVENT_FBDI_GEN_PKG body
-- Billing Events FBDI zip generation.
-- ONE zip with 1 CSV, ONE ESS job (ImportBillingEvents).
-- No multi-BU grouping needed.
-- ============================================================

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
    -- Private: append a delimited CSV field to a CLOB
    -- --------------------------------------------------------
    PROCEDURE append_csv_field (
        p_clob   IN OUT NOCOPY CLOB,
        p_value  IN VARCHAR2,
        p_last   IN BOOLEAN DEFAULT FALSE
    )
    IS
        l_val VARCHAR2(32767);
    BEGIN
        l_val := '"' || REPLACE(p_value, '"', '""') || '"';
        DBMS_LOB.WRITEAPPEND(p_clob, LENGTH(l_val), l_val);
        IF NOT p_last THEN
            DBMS_LOB.WRITEAPPEND(p_clob, 1, ',');
        ELSE
            DBMS_LOB.WRITEAPPEND(p_clob, 1, CHR(10));
        END IF;
    END append_csv_field;

    -- --------------------------------------------------------
    -- Private: format DATE as YYYY/MM/DD (Fusion FBDI date format)
    -- --------------------------------------------------------
    FUNCTION fmt_date(p_date IN DATE) RETURN VARCHAR2
    IS
    BEGIN
        RETURN TO_CHAR(p_date, 'MM/DD/YYYY');
    END fmt_date;

    -- --------------------------------------------------------
    -- Private: generate PjbBillingEventsXface.csv CLOB
    -- --------------------------------------------------------
    FUNCTION gen_billing_events_csv (
        p_run_id IN NUMBER
    ) RETURN CLOB
    IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        FOR r IN (
            SELECT
                '"' || REPLACE(NVL(SOURCENAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SOURCEREF,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ORGANIZATION_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CONTRACT_TYPE_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CONTRACT_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CONTRACT_LINE_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(EVENT_TYPE_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(EVENT_DESC,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(COMPLETION_DATE, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || REPLACE(NVL(BILL_TRNS_CURRENCY_CODE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(BILL_TRNS_AMOUNT), '') || '"' || ','
                || '"' || REPLACE(NVL(PROJECT_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TASK_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(BILL_HOLD_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(REVENUE_HOLD_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_CATEGORY,''), '"', '""') || '"' || ','
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
                || '"' || REPLACE(NVL(ATTRIBUTE_CHAR11,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_CHAR12,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_CHAR13,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_CHAR14,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_CHAR15,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_CHAR16,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_CHAR17,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_CHAR18,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_CHAR19,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_CHAR20,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_CHAR21,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_CHAR22,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_CHAR23,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_CHAR24,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_CHAR25,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_CHAR26,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_CHAR27,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_CHAR28,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_CHAR29,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE_CHAR30,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER1), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER2), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER3), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER4), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER5), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER6), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER7), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER8), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER9), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_NUMBER10), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE1, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE2, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE3, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE4, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE5, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE6, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE7, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE8, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE9, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_DATE10, 'MM/DD/YYYY'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP1, 'MM/DD/YYYY HH24:MI:SS'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP2, 'MM/DD/YYYY HH24:MI:SS'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP3, 'MM/DD/YYYY HH24:MI:SS'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP4, 'MM/DD/YYYY HH24:MI:SS'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ATTRIBUTE_TIMESTAMP5, 'MM/DD/YYYY HH24:MI:SS'), '') || '"' || ','
                || '"' || REPLACE(NVL(REVERSE_ACCRUAL_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ITEM_EVENT_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(QUANTITY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ITEM_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(UNIT_OF_MEASURE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(UNIT_PRICE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PREPAYMENT_REQ_EVENT_NUM,''), '"', '""') || '"' || CHR(10) AS csv_line
            FROM   DMT_OWNER.DMT_PJB_BILL_EVENTS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id
            AND    t.TFM_STATUS = 'STAGED'
            ORDER BY t.TFM_SEQUENCE_ID
                    ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;

        RETURN l_csv;
    END gen_billing_events_csv;

    -- ============================================================
    -- GENERATE_FBDI
    -- Builds 1 CSV, zips it, registers in FBDI tables,
    -- updates TFM rows to GENERATED.
    -- ============================================================
    PROCEDURE GENERATE_FBDI (
        p_run_id IN  NUMBER,
        x_fbdi_zip       OUT BLOB,
        x_filename       OUT VARCHAR2,
        x_fbdi_csv_id    OUT NUMBER
    )
    IS
        l_zip              BLOB;
        l_events_csv       CLOB;
        l_fbdi_csv_id      NUMBER;
        l_zip_id           NUMBER;
        l_bytes            NUMBER;
        l_now              DATE := SYSDATE;
        C_PROC CONSTANT VARCHAR2(30) := 'GENERATE_FBDI';
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Billing Event FBDI generation start.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        x_filename := 'BillingEvents_' || TO_CHAR(p_run_id) || '.zip';

        -- Generate CSV
        l_events_csv := gen_billing_events_csv(p_run_id);

        -- AD#20: Skip gracefully if no rows generated
        IF DBMS_LOB.GETLENGTH(l_events_csv) IS NULL
           OR DBMS_LOB.GETLENGTH(l_events_csv) = 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'No STAGED Billing Event rows found. Skipping FBDI generation.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            DBMS_LOB.FREETEMPORARY(l_events_csv);
            x_fbdi_zip := NULL;
            x_filename := NULL;
            x_fbdi_csv_id := NULL;
            RETURN;
        END IF;

        -- FBDI CSV<->ZIP remodel: register the physical CSV as its own row, then
        -- build the zip from that persisted row.
        SELECT DMT_OWNER.DMT_FBDI_ZIP_ID_SEQ.NEXTVAL INTO l_zip_id FROM DUAL;
        DMT_UTIL_PKG.REGISTER_CSV(p_run_id, l_zip_id, 1, 'BillingEvents', 'PjbBillingEventsXface.csv', 0, l_events_csv, l_fbdi_csv_id);
        DMT_UTIL_PKG.BUILD_ZIP_FROM_CSVS(p_run_id, l_zip_id, 'BillingEvents', x_filename, l_zip, l_bytes);

        -- Update TFM rows to GENERATED and stamp FBDI_CSV_ID
        UPDATE DMT_OWNER.DMT_PJB_BILL_EVENTS_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_fbdi_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        -- Free temporary CLOBs
        DBMS_LOB.FREETEMPORARY(l_events_csv);

        x_fbdi_zip    := l_zip;
        x_fbdi_csv_id := l_fbdi_csv_id;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Billing Event FBDI generation complete.' ||
                                ' | File: ' || x_filename ||
                                ' | Zip bytes: ' || DBMS_LOB.GETLENGTH(x_fbdi_zip),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'Billing Event FBDI generation failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END GENERATE_FBDI;

END DMT_BILLING_EVENT_FBDI_GEN_PKG;
/
