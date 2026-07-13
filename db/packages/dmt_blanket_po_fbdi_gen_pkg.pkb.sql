-- PACKAGE BODY DMT_BLANKET_PO_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_BLANKET_PO_FBDI_GEN_PKG" 
AS
    C_PKG CONSTANT VARCHAR2(50) := 'DMT_BLANKET_PO_FBDI_GEN_PKG';

-- ============================================================
-- DMT_BLANKET_PO_FBDI_GEN_PKG body
-- BlanketPOs FBDI zip generation.
-- 2 CSVs: PO_HEADERS_INTERFACE.csv + PO_LINES_INTERFACE.csv
-- Column order follows POBlanketPurchaseAgreementImportTemplate.xlsm
-- (121 header columns, 107 line columns).
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

    -- --------------------------------------------------------
    -- Private: append a delimited CSV row to a CLOB
    -- --------------------------------------------------------
    PROCEDURE append_csv_field (
        p_clob   IN OUT NOCOPY CLOB,
        p_value  IN VARCHAR2,
        p_last   IN BOOLEAN DEFAULT FALSE
    )
    IS
        l_val VARCHAR2(32767);
    BEGIN
        -- Wrap in double-quotes; escape internal double-quotes by doubling them
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
        RETURN TO_CHAR(p_date, 'YYYY/MM/DD');
    END fmt_date;

    -- --------------------------------------------------------
    -- Private helper: quote-wrap a value for inline CSV building
    -- --------------------------------------------------------
    FUNCTION q(p_val IN VARCHAR2) RETURN VARCHAR2
    IS
    BEGIN
        RETURN '"' || REPLACE(NVL(p_val, ''), '"', '""') || '"';
    END q;

    FUNCTION qn(p_val IN NUMBER) RETURN VARCHAR2
    IS
    BEGIN
        RETURN '"' || NVL(TO_CHAR(p_val), '') || '"';
    END qn;

    FUNCTION qd(p_val IN DATE) RETURN VARCHAR2
    IS
    BEGIN
        RETURN '"' || NVL(TO_CHAR(p_val, 'YYYY/MM/DD'), '') || '"';
    END qd;

    FUNCTION qt(p_val IN TIMESTAMP) RETURN VARCHAR2
    IS
    BEGIN
        RETURN '"' || NVL(TO_CHAR(p_val, 'YYYY/MM/DD'), '') || '"';
    END qt;

    -- --------------------------------------------------------
    -- Private: generate PO_HEADERS_INTERFACE.csv CLOB
    -- BPA template order: 121 columns
    -- Filters: STYLE_DISPLAY_NAME = 'Blanket Purchase Agreement'
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
            AND    t.STYLE_DISPLAY_NAME = 'Blanket Purchase Agreement'
            AND    (p_prc_bu_name IS NULL OR t.PRC_BU_NAME = p_prc_bu_name)
            ORDER BY t.TFM_SEQUENCE_ID
        ) LOOP
            -- BPA PO_HEADERS_INTERFACE: 121 columns
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
                -- 44. Catalog Administrator Authoring (empty)
                || E || ','
                -- 45. Apply price updates to existing orders (empty)
                || E || ','
                -- 46. Communicate price updates (empty)
                || E || ','
                -- 47. ATTRIBUTE_CATEGORY
                || q(r.ATTRIBUTE_CATEGORY) || ','
                -- 48-67. ATTRIBUTE1-20
                || q(r.ATTRIBUTE1) || ','
                || q(r.ATTRIBUTE2) || ','
                || q(r.ATTRIBUTE3) || ','
                || q(r.ATTRIBUTE4) || ','
                || q(r.ATTRIBUTE5) || ','
                || q(r.ATTRIBUTE6) || ','
                || q(r.ATTRIBUTE7) || ','
                || q(r.ATTRIBUTE8) || ','
                || q(r.ATTRIBUTE9) || ','
                || q(r.ATTRIBUTE10) || ','
                || q(r.ATTRIBUTE11) || ','
                || q(r.ATTRIBUTE12) || ','
                || q(r.ATTRIBUTE13) || ','
                || q(r.ATTRIBUTE14) || ','
                || q(r.ATTRIBUTE15) || ','
                || q(r.ATTRIBUTE16) || ','
                || q(r.ATTRIBUTE17) || ','
                || q(r.ATTRIBUTE18) || ','
                || q(r.ATTRIBUTE19) || ','
                || q(r.ATTRIBUTE20) || ','
                -- 68-77. ATTRIBUTE_DATE1-10
                || qd(r.ATTRIBUTE_DATE1) || ','
                || qd(r.ATTRIBUTE_DATE2) || ','
                || qd(r.ATTRIBUTE_DATE3) || ','
                || qd(r.ATTRIBUTE_DATE4) || ','
                || qd(r.ATTRIBUTE_DATE5) || ','
                || qd(r.ATTRIBUTE_DATE6) || ','
                || qd(r.ATTRIBUTE_DATE7) || ','
                || qd(r.ATTRIBUTE_DATE8) || ','
                || qd(r.ATTRIBUTE_DATE9) || ','
                || qd(r.ATTRIBUTE_DATE10) || ','
                -- 78-87. ATTRIBUTE_NUMBER1-10
                || qn(r.ATTRIBUTE_NUMBER1) || ','
                || qn(r.ATTRIBUTE_NUMBER2) || ','
                || qn(r.ATTRIBUTE_NUMBER3) || ','
                || qn(r.ATTRIBUTE_NUMBER4) || ','
                || qn(r.ATTRIBUTE_NUMBER5) || ','
                || qn(r.ATTRIBUTE_NUMBER6) || ','
                || qn(r.ATTRIBUTE_NUMBER7) || ','
                || qn(r.ATTRIBUTE_NUMBER8) || ','
                || qn(r.ATTRIBUTE_NUMBER9) || ','
                || qn(r.ATTRIBUTE_NUMBER10) || ','
                -- 88-97. ATTRIBUTE_TIMESTAMP1-10
                || qd(r.ATTRIBUTE_TIMESTAMP1) || ','
                || qd(r.ATTRIBUTE_TIMESTAMP2) || ','
                || qd(r.ATTRIBUTE_TIMESTAMP3) || ','
                || qd(r.ATTRIBUTE_TIMESTAMP4) || ','
                || qd(r.ATTRIBUTE_TIMESTAMP5) || ','
                || qd(r.ATTRIBUTE_TIMESTAMP6) || ','
                || qd(r.ATTRIBUTE_TIMESTAMP7) || ','
                || qd(r.ATTRIBUTE_TIMESTAMP8) || ','
                || qd(r.ATTRIBUTE_TIMESTAMP9) || ','
                || qd(r.ATTRIBUTE_TIMESTAMP10) || ','
                -- 98. Buyer E-mail
                || q(r.AGENT_EMAIL_ADDRESS) || ','
                -- 99. Mode of Transport
                || q(r.MODE_OF_TRANSPORT) || ','
                -- 100. Service Level
                || q(r.SERVICE_LEVEL) || ','
                -- 101-121. BPA-specific columns (all empty, 21 columns)
                -- 101. Aging Period Days
                || E || ','
                -- 102. Aging Onset Point
                || E || ','
                -- 103. Consumption Advice Frequency
                || E || ','
                -- 104. Consumption Advice Summary
                || E || ','
                -- 105. Default line as consignment line
                || E || ','
                -- 106. Pay on use
                || E || ','
                -- 107. Billing Cycle Closing Date
                || E || ','
                -- 108. Configuration Ordering Enabled
                || E || ','
                -- 109. Use Customer Sales Order
                || E || ','
                -- 110. Buyer Managed Transportation
                || E || ','
                -- 111. Allow ordering from unassigned sites
                || E || ','
                -- 112. Outside Processing Enabled
                || E || ','
                -- 113. Master Contract Number
                || E || ','
                -- 114. Master Contract Type
                || E || ','
                -- 115. Use order date for order pricing
                || E || ','
                -- 116. Priority
                || E || ','
                -- 117. Checklist Title
                || E || ','
                -- 118. Checklist Number
                || E || ','
                -- 119. Use ship-to location
                || E || ','
                -- 120. Initiate retroactive pricing upon agreement approval
                || E || ','
                -- 121. Reprice open orders only
                || E || ','
                -- END marker (required by Oracle FBDI CTL)
                || 'END'
                || CHR(10);

            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(l_line), l_line);
        END LOOP;

        RETURN l_csv;
    END gen_headers_csv;

    -- --------------------------------------------------------
    -- Private: generate PO_LINES_INTERFACE.csv CLOB
    -- BPA template order: 107 columns
    -- Filters via header join on STYLE_DISPLAY_NAME = 'Blanket Purchase Agreement'
    -- When p_prc_bu_name is non-NULL, only includes lines whose
    -- parent header belongs to that BU.
    -- --------------------------------------------------------
    FUNCTION gen_lines_csv (
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
            SELECT l.*
            FROM   DMT_OWNER.DMT_PO_LINES_INT_TFM_TBL l
            WHERE  l.RUN_ID = p_run_id
            AND    l.TFM_STATUS = 'STAGED'
            AND    l.INTERFACE_HEADER_KEY IN (
            SELECT h.INTERFACE_HEADER_KEY
            FROM   DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL h
            WHERE  h.RUN_ID = p_run_id
            AND    h.STYLE_DISPLAY_NAME = 'Blanket Purchase Agreement'
            AND    h.TFM_STATUS IN ('STAGED','GENERATED')
            AND    (p_prc_bu_name IS NULL OR h.PRC_BU_NAME = p_prc_bu_name))
            ORDER BY l.TFM_SEQUENCE_ID
        ) LOOP
            -- BPA PO_LINES_INTERFACE: 107 columns
            l_line :=
                -- 1. Interface Line Key
                q(r.INTERFACE_LINE_KEY) || ','
                -- 2. Interface Header Key
                || q(r.INTERFACE_HEADER_KEY) || ','
                -- 3. Action
                || q(r.ACTION) || ','
                -- 4. Line
                || qn(r.LINE_NUM) || ','
                -- 5. Line Type
                || q(r.LINE_TYPE) || ','
                -- 6. Item
                || q(r.ITEM) || ','
                -- 7. Item Description
                || q(r.ITEM_DESCRIPTION) || ','
                -- 8. Item Revision
                || q(r.ITEM_REVISION) || ','
                -- 9. Category Name
                || q(r.CATEGORY) || ','
                -- 10. Agreement Amount (empty)
                || E || ','
                -- 11. UOM (mapped from UNIT_OF_MEASURE)
                || q(r.UNIT_OF_MEASURE) || ','
                -- 12. Price
                || qn(r.UNIT_PRICE) || ','
                -- 13. Allow Price Override (empty)
                || E || ','
                -- 14. Not to exceed price (empty)
                || E || ','
                -- 15. Supplier Item (empty)
                || E || ','
                -- 16. Negotiated
                || q(r.NEGOTIATED_BY_PREPARER_FLAG) || ','
                -- 17. Note to Supplier
                || q(r.NOTE_TO_VENDOR) || ','
                -- 18. Note to Receiver
                || q(r.NOTE_TO_RECEIVER) || ','
                -- 19. Minimum Release Amount (empty)
                || E || ','
                -- 20. Expiration Date (empty)
                || E || ','
                -- 21. Supplier Part Auxiliary ID (empty)
                || E || ','
                -- 22. Supplier Ref Number (empty)
                || E || ','
                -- 23. ATTRIBUTE_CATEGORY (LINE_ATTRIBUTE_CATEGORY_LINES)
                || q(r.LINE_ATTRIBUTE_CATEGORY_LINES) || ','
                -- 24-43. ATTRIBUTE1-20
                || q(r.LINE_ATTRIBUTE1) || ','
                || q(r.LINE_ATTRIBUTE2) || ','
                || q(r.LINE_ATTRIBUTE3) || ','
                || q(r.LINE_ATTRIBUTE4) || ','
                || q(r.LINE_ATTRIBUTE5) || ','
                || q(r.LINE_ATTRIBUTE6) || ','
                || q(r.LINE_ATTRIBUTE7) || ','
                || q(r.LINE_ATTRIBUTE8) || ','
                || q(r.LINE_ATTRIBUTE9) || ','
                || q(r.LINE_ATTRIBUTE10) || ','
                || q(r.LINE_ATTRIBUTE11) || ','
                || q(r.LINE_ATTRIBUTE12) || ','
                || q(r.LINE_ATTRIBUTE13) || ','
                || q(r.LINE_ATTRIBUTE14) || ','
                || q(r.LINE_ATTRIBUTE15) || ','
                || q(r.ATTRIBUTE16) || ','
                || q(r.ATTRIBUTE17) || ','
                || q(r.ATTRIBUTE18) || ','
                || q(r.ATTRIBUTE19) || ','
                || q(r.ATTRIBUTE20) || ','
                -- 44-53. ATTRIBUTE_DATE1-10
                || qd(r.ATTRIBUTE_DATE1) || ','
                || qd(r.ATTRIBUTE_DATE2) || ','
                || qd(r.ATTRIBUTE_DATE3) || ','
                || qd(r.ATTRIBUTE_DATE4) || ','
                || qd(r.ATTRIBUTE_DATE5) || ','
                || qd(r.ATTRIBUTE_DATE6) || ','
                || qd(r.ATTRIBUTE_DATE7) || ','
                || qd(r.ATTRIBUTE_DATE8) || ','
                || qd(r.ATTRIBUTE_DATE9) || ','
                || qd(r.ATTRIBUTE_DATE10) || ','
                -- 54-63. ATTRIBUTE_NUMBER1-10
                || qn(r.ATTRIBUTE_NUMBER1) || ','
                || qn(r.ATTRIBUTE_NUMBER2) || ','
                || qn(r.ATTRIBUTE_NUMBER3) || ','
                || qn(r.ATTRIBUTE_NUMBER4) || ','
                || qn(r.ATTRIBUTE_NUMBER5) || ','
                || qn(r.ATTRIBUTE_NUMBER6) || ','
                || qn(r.ATTRIBUTE_NUMBER7) || ','
                || qn(r.ATTRIBUTE_NUMBER8) || ','
                || qn(r.ATTRIBUTE_NUMBER9) || ','
                || qn(r.ATTRIBUTE_NUMBER10) || ','
                -- 64-73. ATTRIBUTE_TIMESTAMP1-10
                || qd(r.ATTRIBUTE_TIMESTAMP1) || ','
                || qd(r.ATTRIBUTE_TIMESTAMP2) || ','
                || qd(r.ATTRIBUTE_TIMESTAMP3) || ','
                || qd(r.ATTRIBUTE_TIMESTAMP4) || ','
                || qd(r.ATTRIBUTE_TIMESTAMP5) || ','
                || qd(r.ATTRIBUTE_TIMESTAMP6) || ','
                || qd(r.ATTRIBUTE_TIMESTAMP7) || ','
                || qd(r.ATTRIBUTE_TIMESTAMP8) || ','
                || qd(r.ATTRIBUTE_TIMESTAMP9) || ','
                || qd(r.ATTRIBUTE_TIMESTAMP10) || ','
                -- 74-107. Remaining BPA-specific columns (34 columns, all empty)
                -- 74. Price Break Type
                || E || ','
                -- 75. Quantity Committed
                || E || ','
                -- 76. Minimum Order Quantity
                || E || ','
                -- 77. Maximum Order Quantity
                || E || ','
                -- 78. Line Amount Committed
                || E || ','
                -- 79. Line Minimum Release Amount
                || E || ','
                -- 80. Create or update item flag
                || E || ','
                -- 81. Secondary UOM
                || E || ','
                -- 82. Advance Amount
                || E || ','
                -- 83. Advance Percentage
                || E || ','
                -- 84. Recoupment Rate
                || E || ','
                -- 85. Maximum Retainage Amount
                || E || ','
                -- 86. Retainage Rate
                || E || ','
                -- 87. Progress Payment Rate
                || E || ','
                -- 88. Source Agreement Procurement BU
                || E || ','
                -- 89. Source Agreement
                || E || ','
                -- 90. Source Agreement Line
                || E || ','
                -- 91. Supplier Configuration ID
                || E || ','
                -- 92. Allow Item Description Update
                || E || ','
                -- 93. Allow Category Update
                || E || ','
                -- 94. Configured Item Flag
                || E || ','
                -- 95. Assigned to Buyer
                || E || ','
                -- 96. Enable Price Notifications
                || E || ','
                -- 97. Max Price Increase Percentage
                || E || ','
                -- 98. Max Price Decrease Percentage
                || E || ','
                -- 99. Max Price Increase Value
                || E || ','
                -- 100. Max Price Decrease Value
                || E || ','
                -- 101. Price Update Tolerance
                || E || ','
                -- 102. Line Catalog Administrator Authoring
                || E || ','
                -- 103. IP Category
                || E || ','
                -- 104. IP Category Display Name
                || E || ','
                -- 105. Response Type
                || E || ','
                -- 106. Supplier Rebate Program
                || E || ','
                -- 107. Response Reason
                || E || ','
                -- END marker (required by Oracle FBDI CTL)
                || 'END'
                || CHR(10);

            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(l_line), l_line);
        END LOOP;

        RETURN l_csv;
    END gen_lines_csv;

    -- --------------------------------------------------------
    -- Public: GENERATE_FBDI
    -- Builds 2 CSVs (headers + lines), zips them, persists to
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
        l_lines_csv   CLOB;
        l_fbdi_csv_id NUMBER;   -- primary (headers) csv id, returned to the loader
        l_lines_csv_id NUMBER;
        l_zip_id      NUMBER;
        l_bytes       NUMBER;
        l_bu_suffix   VARCHAR2(50);
        l_now         DATE := SYSDATE;
        C_PROC CONSTANT VARCHAR2(30) := 'GENERATE_FBDI';
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Blanket PO FBDI generation start.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        -- Filename: BlanketPO_{GroupValue}_{IntegrationID}.zip
        IF p_prc_bu_name IS NOT NULL THEN
            l_bu_suffix := '_' || REPLACE(SUBSTR(p_prc_bu_name, 1, 30), ' ', '');
        END IF;
        x_filename := 'BlanketPO' || NVL(l_bu_suffix, '_All') || '_' || TO_CHAR(p_run_id) || '.zip';

        -- Generate 2 CSVs (filtered by BU when provided)
        l_hdr_csv   := gen_headers_csv(p_run_id, p_prc_bu_name);
        l_lines_csv := gen_lines_csv(p_run_id, p_prc_bu_name);

        -- AD#20: Skip gracefully if no rows generated
        IF (l_hdr_csv IS NULL OR DBMS_LOB.GETLENGTH(l_hdr_csv) = 0) THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'No STAGED Blanket PO rows found. Skipping FBDI generation.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            IF l_hdr_csv IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_hdr_csv) = 1 THEN DBMS_LOB.FREETEMPORARY(l_hdr_csv); END IF;
            IF l_lines_csv IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_lines_csv) = 1 THEN DBMS_LOB.FREETEMPORARY(l_lines_csv); END IF;
            x_fbdi_zip := NULL;
            x_filename := NULL;
            x_fbdi_csv_id := NULL;
            RETURN;
        END IF;

        -- FBDI CSV<->ZIP remodel: register each physical CSV as its own row, then
        -- build the zip from those persisted rows. One zip owns two CSVs.
        SELECT DMT_OWNER.DMT_FBDI_ZIP_ID_SEQ.NEXTVAL INTO l_zip_id FROM DUAL;
        DMT_UTIL_PKG.REGISTER_CSV(p_run_id, l_zip_id, 1, 'BlanketPOs', 'PoHeadersInterfaceBlanket.csv', 0, l_hdr_csv, l_fbdi_csv_id);
        -- Lines are optional: only register (and thus zip) the file when it has rows.
        IF l_lines_csv IS NOT NULL AND DBMS_LOB.GETLENGTH(l_lines_csv) > 0 THEN
            DMT_UTIL_PKG.REGISTER_CSV(p_run_id, l_zip_id, 2, 'BlanketPOs', 'PoLinesInterfaceBlanket.csv',   0, l_lines_csv, l_lines_csv_id);
        END IF;
        DMT_UTIL_PKG.BUILD_ZIP_FROM_CSVS(p_run_id, l_zip_id, 'BlanketPOs', x_filename, l_zip, l_bytes);

        -- Update TFM rows to GENERATED and stamp EACH file's own FBDI_CSV_ID.
        -- Headers: filter by STYLE_DISPLAY_NAME and PRC_BU_NAME.
        UPDATE DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_fbdi_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED'
        AND    STYLE_DISPLAY_NAME = 'Blanket Purchase Agreement'
        AND    (p_prc_bu_name IS NULL OR PRC_BU_NAME = p_prc_bu_name);

        -- Lines -> lines csv id; join predicate scopes on the PARENT (headers) csv id
        -- (only lines belonging to blanket headers just stamped above).
        UPDATE DMT_OWNER.DMT_PO_LINES_INT_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_lines_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED'
        AND    INTERFACE_HEADER_KEY IN (
            SELECT h.INTERFACE_HEADER_KEY
            FROM   DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL h
            WHERE  h.RUN_ID = p_run_id
            AND    h.FBDI_CSV_ID = l_fbdi_csv_id);

        -- Free temporary CLOBs
        DBMS_LOB.FREETEMPORARY(l_hdr_csv);
        DBMS_LOB.FREETEMPORARY(l_lines_csv);

        x_fbdi_zip   := l_zip;
        x_fbdi_csv_id := l_fbdi_csv_id;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Blanket PO FBDI generation complete.' ||
                                ' | File: ' || x_filename ||
                                ' | Zip bytes: ' || DBMS_LOB.GETLENGTH(x_fbdi_zip),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'Blanket PO FBDI generation failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END GENERATE_FBDI;

END DMT_BLANKET_PO_FBDI_GEN_PKG;
/
