-- PACKAGE BODY DMT_CONTRACT_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_CONTRACT_FBDI_GEN_PKG" 
AS
    C_PKG CONSTANT VARCHAR2(50) := 'DMT_CONTRACT_FBDI_GEN_PKG';

-- ============================================================
-- DMT_CONTRACT_FBDI_GEN_PKG body
-- Contracts FBDI zip generation.
-- 1 CSV only: PoHeadersInterfaceContract.csv (no lines).
-- Column order follows POContractPurchaseAgreementImportTemplate.xlsm
-- (105 header columns).
-- Grouped by PRC_BU_NAME — same pattern as standard POs.
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

    -- Helper: quote-wrap a value for CSV
    FUNCTION q(p_val IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN RETURN '"' || REPLACE(NVL(p_val, ''), '"', '""') || '"'; END q;

    FUNCTION qn(p_val IN NUMBER) RETURN VARCHAR2 IS
    BEGIN RETURN '"' || NVL(TO_CHAR(p_val), '') || '"'; END qn;

    FUNCTION qd(p_val IN DATE) RETURN VARCHAR2 IS
    BEGIN RETURN '"' || NVL(TO_CHAR(p_val, 'YYYY/MM/DD'), '') || '"'; END qd;

    FUNCTION qt(p_val IN TIMESTAMP) RETURN VARCHAR2 IS
    BEGIN RETURN '"' || NVL(TO_CHAR(p_val, 'YYYY/MM/DD'), '') || '"'; END qt;

    -- --------------------------------------------------------
    -- Private: generate PoHeadersInterfaceContract.csv CLOB
    -- CPA template order: 105 columns
    -- Filters: STYLE_DISPLAY_NAME = 'Contract Purchase Agreement'
    -- When p_prc_bu_name is non-NULL, only includes headers for that BU.
    -- --------------------------------------------------------
    FUNCTION gen_headers_csv (
        p_run_id IN NUMBER,
        p_prc_bu_name    IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB
    IS
        l_csv  CLOB;
        l_line VARCHAR2(32767);
        E      CONSTANT VARCHAR2(4) := '""';  -- empty quoted field
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        FOR r IN (
            SELECT t.*
            FROM   DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id
            AND    t.TFM_STATUS = 'STAGED'
            AND    t.STYLE_DISPLAY_NAME = 'Contract Purchase Agreement'
            AND    (p_prc_bu_name IS NULL OR t.PRC_BU_NAME = p_prc_bu_name)
            ORDER BY t.TFM_SEQUENCE_ID
        ) LOOP
            -- CPA PO_HEADERS_INTERFACE: 105 columns
            l_line :=
                -- 1. Interface Header Key
                q(r.INTERFACE_HEADER_KEY) || ','
                -- 2. Action
                || q(r.ACTION) || ','
                -- 3. Batch ID
                || qn(r.BATCH_ID) || ','
                -- 4. Import Source
                || q(r.INTERFACE_SOURCE_CODE) || ','
                -- 5. Approval Action
                || q(r.APPROVAL_ACTION) || ','
                -- 6. Agreement (Document Num)
                || q(r.DOCUMENT_NUM) || ','
                -- 7. Document Type Code
                || q(r.DOCUMENT_TYPE_CODE) || ','
                -- 8. Style
                || q(r.STYLE_DISPLAY_NAME) || ','
                -- 9. Procurement BU
                || q(r.PRC_BU_NAME) || ','
                -- 10. Buyer
                || q(r.AGENT_NAME) || ','
                -- 11. Currency Code
                || q(r.CURRENCY_CODE) || ','
                -- 12. Description
                || q(r.COMMENTS) || ','
                -- 13. Supplier
                || q(r.VENDOR_NAME) || ','
                -- 14. Supplier Number
                || q(r.VENDOR_NUM) || ','
                -- 15. Supplier Site
                || q(r.VENDOR_SITE_CODE) || ','
                -- 16. Supplier Contact
                || q(r.VENDOR_CONTACT) || ','
                -- 17. Supplier Order
                || q(r.VENDOR_DOC_NUM) || ','
                -- 18. Fob
                || q(r.FOB) || ','
                -- 19. Carrier
                || q(r.FREIGHT_CARRIER) || ','
                -- 20. Freight Terms
                || q(r.FREIGHT_TERMS) || ','
                -- 21. Pay On Code
                || q(r.PAY_ON_CODE) || ','
                -- 22. Payment Terms
                || q(r.PAYMENT_TERMS) || ','
                -- 23. Initiating Party
                || q(r.ORIGINATOR_ROLE) || ','
                -- 24. Change Order Description
                || q(r.CHANGE_ORDER_DESC) || ','
                -- 25. Required Acknowledgment
                || q(r.ACCEPTANCE_REQUIRED_FLAG) || ','
                -- 26. Acknowledge Within (Days)
                || qn(r.ACCEPTANCE_WITHIN_DAYS) || ','
                -- 27. Communication Method
                || q(r.SUPPLIER_NOTIF_METHOD) || ','
                -- 28. Fax
                || q(r.FAX) || ','
                -- 29. E-mail
                || q(r.EMAIL_ADDRESS) || ','
                -- 30. Confirming order
                || q(r.CONFIRMING_ORDER_FLAG) || ','
                -- 31. Agreement Amount (empty)
                || E || ','
                -- 32. Amount Limit (empty)
                || E || ','
                -- 33. Minimum Release Amount (empty)
                || E || ','
                -- 34. Start Date (empty)
                || E || ','
                -- 35. End Date (empty)
                || E || ','
                -- 36. Note to Supplier
                || q(r.NOTE_TO_VENDOR) || ','
                -- 37. Note to Receiver
                || q(r.NOTE_TO_RECEIVER) || ','
                -- 38. Automatically generate orders (empty)
                || E || ','
                -- 39. Automatically submit for approval (empty)
                || E || ','
                -- 40. Group requisitions (empty)
                || E || ','
                -- 41. Group requisition lines (empty)
                || E || ','
                -- 42. Use ship-to organization and location (empty)
                || E || ','
                -- 43. Use need-by date (empty)
                || E || ','
                -- 44. ATTRIBUTE_CATEGORY
                || q(r.ATTRIBUTE_CATEGORY) || ','
                -- 45-64. ATTRIBUTE1-20
                || q(r.ATTRIBUTE1) || ',' || q(r.ATTRIBUTE2) || ',' || q(r.ATTRIBUTE3) || ','
                || q(r.ATTRIBUTE4) || ',' || q(r.ATTRIBUTE5) || ',' || q(r.ATTRIBUTE6) || ','
                || q(r.ATTRIBUTE7) || ',' || q(r.ATTRIBUTE8) || ',' || q(r.ATTRIBUTE9) || ','
                || q(r.ATTRIBUTE10) || ',' || q(r.ATTRIBUTE11) || ',' || q(r.ATTRIBUTE12) || ','
                || q(r.ATTRIBUTE13) || ',' || q(r.ATTRIBUTE14) || ',' || q(r.ATTRIBUTE15) || ','
                || q(r.ATTRIBUTE16) || ',' || q(r.ATTRIBUTE17) || ',' || q(r.ATTRIBUTE18) || ','
                || q(r.ATTRIBUTE19) || ',' || q(r.ATTRIBUTE20) || ','
                -- 65-74. ATTRIBUTE_DATE1-10
                || qd(r.ATTRIBUTE_DATE1) || ',' || qd(r.ATTRIBUTE_DATE2) || ','
                || qd(r.ATTRIBUTE_DATE3) || ',' || qd(r.ATTRIBUTE_DATE4) || ','
                || qd(r.ATTRIBUTE_DATE5) || ',' || qd(r.ATTRIBUTE_DATE6) || ','
                || qd(r.ATTRIBUTE_DATE7) || ',' || qd(r.ATTRIBUTE_DATE8) || ','
                || qd(r.ATTRIBUTE_DATE9) || ',' || qd(r.ATTRIBUTE_DATE10) || ','
                -- 75-84. ATTRIBUTE_NUMBER1-10
                || qn(r.ATTRIBUTE_NUMBER1) || ',' || qn(r.ATTRIBUTE_NUMBER2) || ','
                || qn(r.ATTRIBUTE_NUMBER3) || ',' || qn(r.ATTRIBUTE_NUMBER4) || ','
                || qn(r.ATTRIBUTE_NUMBER5) || ',' || qn(r.ATTRIBUTE_NUMBER6) || ','
                || qn(r.ATTRIBUTE_NUMBER7) || ',' || qn(r.ATTRIBUTE_NUMBER8) || ','
                || qn(r.ATTRIBUTE_NUMBER9) || ',' || qn(r.ATTRIBUTE_NUMBER10) || ','
                -- 85-94. ATTRIBUTE_TIMESTAMP1-10
                || qt(r.ATTRIBUTE_TIMESTAMP1) || ',' || qt(r.ATTRIBUTE_TIMESTAMP2) || ','
                || qt(r.ATTRIBUTE_TIMESTAMP3) || ',' || qt(r.ATTRIBUTE_TIMESTAMP4) || ','
                || qt(r.ATTRIBUTE_TIMESTAMP5) || ',' || qt(r.ATTRIBUTE_TIMESTAMP6) || ','
                || qt(r.ATTRIBUTE_TIMESTAMP7) || ',' || qt(r.ATTRIBUTE_TIMESTAMP8) || ','
                || qt(r.ATTRIBUTE_TIMESTAMP9) || ',' || qt(r.ATTRIBUTE_TIMESTAMP10) || ','
                -- 95. Buyer E-mail
                || q(r.AGENT_EMAIL_ADDRESS) || ','
                -- 96. Mode of Transport
                || q(r.MODE_OF_TRANSPORT) || ','
                -- 97. Service level
                || q(r.SERVICE_LEVEL) || ','
                -- 98. Use Customer Sales Order (empty)
                || E || ','
                -- 99. Buyer Managed Transportation
                || q(r.BUYER_MANAGED_TRANSPORT_FLAG) || ','
                -- 100. Configuration Ordering Enabled (empty)
                || E || ','
                -- 101. Allow ordering from unassigned sites (empty)
                || E || ','
                -- 102. Outside Processing Enabled (empty)
                || E || ','
                -- 103. Enable automatic sourcing (empty)
                || E || ','
                -- 104. Master Contract Number (empty)
                || E || ','
                -- 105. Master Contract Type (empty)
                || E || ','
                -- END marker (required by Oracle FBDI CTL)
                || 'END'
                || CHR(10);

            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(l_line), l_line);
        END LOOP;

        RETURN l_csv;
    END gen_headers_csv;

    -- --------------------------------------------------------
    -- Public: GENERATE_FBDI
    -- Builds 1 CSV (headers only), zips it, persists to
    -- traceability tables, marks TFM rows as GENERATED.
    -- When p_prc_bu_name is non-NULL, only includes rows for that BU.
    -- --------------------------------------------------------
    PROCEDURE GENERATE_FBDI (
        p_run_id IN  NUMBER,
        p_prc_bu_name    IN  VARCHAR2 DEFAULT NULL,
        x_fbdi_zip       OUT BLOB,
        x_filename       OUT VARCHAR2,
        x_fbdi_csv_id    OUT NUMBER
    )
    IS
        l_zip         BLOB;
        l_hdr_csv     CLOB;
        l_fbdi_csv_id NUMBER;
        l_zip_id      NUMBER;
        l_bytes       NUMBER;
        l_bu_suffix   VARCHAR2(50);
        l_now         DATE := SYSDATE;
        C_PROC CONSTANT VARCHAR2(30) := 'GENERATE_FBDI';
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Contract PO FBDI generation start.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        -- Filename: Contract_{GroupValue}_{IntegrationID}.zip
        IF p_prc_bu_name IS NOT NULL THEN
            l_bu_suffix := '_' || REPLACE(SUBSTR(p_prc_bu_name, 1, 30), ' ', '');
        END IF;
        x_filename := 'Contract' || NVL(l_bu_suffix, '_All') || '_' || TO_CHAR(p_run_id) || '.zip';

        -- Generate 1 CSV (headers only, filtered by BU when provided)
        l_hdr_csv := gen_headers_csv(p_run_id, p_prc_bu_name);

        -- AD#20: Skip gracefully if no rows generated
        IF (l_hdr_csv IS NULL OR DBMS_LOB.GETLENGTH(l_hdr_csv) = 0) THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'No STAGED Contract PO rows found. Skipping FBDI generation.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            DBMS_LOB.FREETEMPORARY(l_hdr_csv);
            x_fbdi_zip := NULL;
            x_filename := NULL;
            x_fbdi_csv_id := NULL;
            RETURN;
        END IF;

        -- FBDI CSV<->ZIP remodel: register the physical CSV as its own row, then
        -- build the zip from that persisted row.
        SELECT DMT_OWNER.DMT_FBDI_ZIP_ID_SEQ.NEXTVAL INTO l_zip_id FROM DUAL;
        l_fbdi_csv_id := DMT_UTIL_PKG.REGISTER_CSV(p_run_id, l_zip_id, 1, 'Contracts', 'PoHeadersInterfaceContract.csv', 0, l_hdr_csv);
        DMT_UTIL_PKG.BUILD_ZIP_FROM_CSVS(p_run_id, l_zip_id, 'Contracts', x_filename, l_zip, l_bytes);

        -- Update TFM rows to GENERATED and stamp FBDI_CSV_ID.
        -- Headers only: filter by STYLE_DISPLAY_NAME and PRC_BU_NAME.
        UPDATE DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_fbdi_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED'
        AND    STYLE_DISPLAY_NAME = 'Contract Purchase Agreement'
        AND    (p_prc_bu_name IS NULL OR PRC_BU_NAME = p_prc_bu_name);

        -- Free temporary CLOB
        DBMS_LOB.FREETEMPORARY(l_hdr_csv);

        x_fbdi_zip   := l_zip;
        x_fbdi_csv_id := l_fbdi_csv_id;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Contract PO FBDI generation complete.' ||
                                ' | File: ' || x_filename ||
                                ' | Zip bytes: ' || DBMS_LOB.GETLENGTH(x_fbdi_zip),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'Contract PO FBDI generation failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END GENERATE_FBDI;

END DMT_CONTRACT_FBDI_GEN_PKG;
/
