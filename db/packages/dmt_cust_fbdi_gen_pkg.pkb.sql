-- PACKAGE BODY DMT_CUST_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_CUST_FBDI_GEN_PKG" 
AS
    C_PKG CONSTANT VARCHAR2(50) := 'DMT_CUST_FBDI_GEN_PKG';

-- ============================================================
-- DMT_CUST_FBDI_GEN_PKG body
-- Customers FBDI zip generation.
-- ONE zip with 7 CSVs, ONE ESS job (BulkImportJob).
-- No multi-BU grouping needed.
-- Records are LF-terminated (CHR(10)), matching the golden Customers_116.zip
-- (Wave-1 offline port 2026-07-09; the HZ bulk-import CSVs use LF, unlike the
-- CRLF supplier-family CSVs).
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
    -- Private: generate HzImpPartiesT.csv CLOB
    -- --------------------------------------------------------
    FUNCTION gen_parties_csv (
        p_run_id IN NUMBER,
        p_batch_id IN NUMBER DEFAULT NULL
    ) RETURN CLOB
    IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        FOR r IN (
            SELECT
                '"' || NVL(TO_CHAR(BATCH_ID), '') || '"' || ','
                || '"' || REPLACE(NVL(PARTY_ORIG_SYSTEM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PARTY_ORIG_SYSTEM_REFERENCE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INSERT_UPDATE_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PARTY_TYPE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PARTY_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SALUTATION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PARTY_USAGE_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(JGZZ_FISCAL_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ORGANIZATION_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DUNS_NUMBER_C,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PERSON_FIRST_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PERSON_LAST_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PERSON_LAST_NAME_PREFIX,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PERSON_SECOND_LAST_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PERSON_MIDDLE_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PERSON_NAME_SUFFIX,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PERSON_TITLE,''), '"', '""') || '"' || ','
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
                || '"' || REPLACE(NVL(ATTRIBUTE11,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE12,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE13,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE14,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE15,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE16,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE17,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE18,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE19,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE20,''), '"', '""') || '"' || CHR(10) AS csv_line
            FROM   DMT_OWNER.DMT_HZ_PARTIES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id
            AND    t.TFM_STATUS = 'STAGED'
            AND    (p_batch_id IS NULL OR t.BATCH_ID = p_batch_id)
            ORDER BY t.TFM_SEQUENCE_ID
                    ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;

        RETURN l_csv;
    END gen_parties_csv;

    -- --------------------------------------------------------
    -- Private: generate HzImpLocationsT.csv CLOB
    -- --------------------------------------------------------
    FUNCTION gen_locations_csv (
        p_run_id IN NUMBER,
        p_batch_id IN NUMBER DEFAULT NULL
    ) RETURN CLOB
    IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        FOR r IN (
            SELECT
                '"' || NVL(TO_CHAR(BATCH_ID), '') || '"' || ','
                || '"' || REPLACE(NVL(LOCATION_ORIG_SYSTEM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LOCATION_ORIG_SYSTEM_REFERENCE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INSERT_UPDATE_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(COUNTRY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ADDRESS1,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ADDRESS2,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ADDRESS3,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ADDRESS4,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CITY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(STATE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PROVINCE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(COUNTY,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(POSTAL_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(POSTAL_PLUS4_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LOCATION_LANGUAGE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DESCRIPTION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SHORT_DESCRIPTION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SALES_TAX_GEOCODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SALES_TAX_INSIDE_CITY_LIMITS,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TIMEZONE_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ADDRESS1_STD,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ADAPTER_CONTENT_SOURCE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ADDR_VALID_STATUS_CODE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(DATE_VALIDATED, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ADDRESS_EFFECTIVE_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(ADDRESS_EXPIRATION_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(VALIDATED_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(DO_NOT_VALIDATE_FLAG,''), '"', '""') || '"' || ','
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
                || '"' || REPLACE(NVL(ATTRIBUTE11,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE12,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE13,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE14,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE15,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE16,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE17,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE18,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE19,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE20,''), '"', '""') || '"' || CHR(10) AS csv_line
            FROM   DMT_OWNER.DMT_HZ_LOCATIONS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id
            AND    t.TFM_STATUS = 'STAGED'
            AND    (p_batch_id IS NULL OR t.BATCH_ID = p_batch_id)
            ORDER BY t.TFM_SEQUENCE_ID
                    ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;

        RETURN l_csv;
    END gen_locations_csv;

    -- --------------------------------------------------------
    -- Private: generate HzImpPartySitesT.csv CLOB
    -- --------------------------------------------------------
    FUNCTION gen_party_sites_csv (
        p_run_id IN NUMBER,
        p_batch_id IN NUMBER DEFAULT NULL
    ) RETURN CLOB
    IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        FOR r IN (
            SELECT
                '"' || NVL(TO_CHAR(BATCH_ID), '') || '"' || ','
                || '"' || REPLACE(NVL(PARTY_ORIG_SYSTEM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PARTY_ORIG_SYSTEM_REFERENCE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SITE_ORIG_SYSTEM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SITE_ORIG_SYSTEM_REFERENCE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LOCATION_ORIG_SYSTEM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LOCATION_ORIG_SYSTEM_REFERENCE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INSERT_UPDATE_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PARTY_SITE_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PARTY_SITE_NUMBER,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(START_DATE_ACTIVE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(END_DATE_ACTIVE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(MAILSTOP,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(IDENTIFYING_ADDRESS_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PARTY_SITE_LANGUAGE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(REL_ORIG_SYSTEM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(REL_ORIG_SYSTEM_REFERENCE,''), '"', '""') || '"' || ','
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
                || '"' || REPLACE(NVL(ATTRIBUTE11,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE12,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE13,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE14,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE15,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE16,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE17,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE18,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE19,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE20,''), '"', '""') || '"' || CHR(10) AS csv_line
            FROM   DMT_OWNER.DMT_HZ_PARTY_SITES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id
            AND    t.TFM_STATUS = 'STAGED'
            AND    (p_batch_id IS NULL OR t.BATCH_ID = p_batch_id)
            ORDER BY t.TFM_SEQUENCE_ID
                    ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;

        RETURN l_csv;
    END gen_party_sites_csv;

    -- --------------------------------------------------------
    -- Private: generate HzImpPartySiteUsesT.csv CLOB
    -- --------------------------------------------------------
    FUNCTION gen_party_site_uses_csv (
        p_run_id IN NUMBER,
        p_batch_id IN NUMBER DEFAULT NULL
    ) RETURN CLOB
    IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        FOR r IN (
            SELECT
                '"' || NVL(TO_CHAR(BATCH_ID), '') || '"' || ','
                || '"' || REPLACE(NVL(PARTY_ORIG_SYSTEM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PARTY_ORIG_SYSTEM_REFERENCE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SITE_ORIG_SYSTEM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SITE_ORIG_SYSTEM_REFERENCE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SITE_USE_TYPE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PRIMARY_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INSERT_UPDATE_FLAG,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(START_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(END_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(SITEUSE_ORIG_SYSTEM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SITEUSE_ORIG_SYSTEM_REF,''), '"', '""') || '"' || ','
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
                || '"' || REPLACE(NVL(ATTRIBUTE11,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE12,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE13,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE14,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE15,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE16,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE17,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE18,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE19,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE20,''), '"', '""') || '"' || CHR(10) AS csv_line
            FROM   DMT_OWNER.DMT_HZ_PARTY_SITE_USES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id
            AND    t.TFM_STATUS = 'STAGED'
            AND    (p_batch_id IS NULL OR t.BATCH_ID = p_batch_id)
            ORDER BY t.TFM_SEQUENCE_ID
                    ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;

        RETURN l_csv;
    END gen_party_site_uses_csv;

    -- --------------------------------------------------------
    -- Private: generate HzImpAccountsT.csv CLOB
    -- --------------------------------------------------------
    FUNCTION gen_accounts_csv (
        p_run_id IN NUMBER,
        p_batch_id IN NUMBER DEFAULT NULL
    ) RETURN CLOB
    IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        FOR r IN (
            SELECT
                '"' || NVL(TO_CHAR(BATCH_ID), '') || '"' || ','
                || '"' || REPLACE(NVL(CUST_ORIG_SYSTEM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CUST_ORIG_SYSTEM_REFERENCE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PARTY_ORIG_SYSTEM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PARTY_ORIG_SYSTEM_REFERENCE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ACCOUNT_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INSERT_UPDATE_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CUSTOMER_TYPE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CUSTOMER_CLASS_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ACCOUNT_NAME,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(ACCOUNT_ESTABLISHED_DATE, 'YYYY/MM/DD'), '') || '"' || ','
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
                || '"' || REPLACE(NVL(ATTRIBUTE11,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE12,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE13,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE14,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE15,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE16,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE17,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE18,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE19,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE20,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(ACCOUNT_TERMINATION_DATE, 'YYYY/MM/DD'), '') || '"' || CHR(10) AS csv_line
            FROM   DMT_OWNER.DMT_HZ_ACCOUNTS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id
            AND    t.TFM_STATUS = 'STAGED'
            AND    (p_batch_id IS NULL OR t.BATCH_ID = p_batch_id)
            ORDER BY t.TFM_SEQUENCE_ID
                    ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;

        RETURN l_csv;
    END gen_accounts_csv;

    -- --------------------------------------------------------
    -- Private: generate HzImpAcctSitesT.csv CLOB
    -- --------------------------------------------------------
    FUNCTION gen_acct_sites_csv (
        p_run_id IN NUMBER,
        p_batch_id IN NUMBER DEFAULT NULL
    ) RETURN CLOB
    IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        FOR r IN (
            SELECT
                '"' || NVL(TO_CHAR(BATCH_ID), '') || '"' || ','
                || '"' || REPLACE(NVL(CUST_ORIG_SYSTEM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CUST_ORIG_SYSTEM_REFERENCE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CUST_SITE_ORIG_SYSTEM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CUST_SITE_ORIG_SYS_REF,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SITE_ORIG_SYSTEM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SITE_ORIG_SYSTEM_REFERENCE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ACCT_SITE_LANGUAGE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INSERT_UPDATE_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CUSTOMER_CATEGORY_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(TRANSLATED_CUSTOMER_NAME,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SET_CODE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(START_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(END_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(KEY_ACCOUNT_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ACCOUNT_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PARTY_SITE_NUMBER,''), '"', '""') || '"' || ','
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
                || '"' || REPLACE(NVL(ATTRIBUTE11,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE12,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE13,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE14,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE15,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE16,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE17,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE18,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE19,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE20,''), '"', '""') || '"' || CHR(10) AS csv_line
            FROM   DMT_OWNER.DMT_HZ_ACCT_SITES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id
            AND    t.TFM_STATUS = 'STAGED'
            AND    (p_batch_id IS NULL OR t.BATCH_ID = p_batch_id)
            ORDER BY t.TFM_SEQUENCE_ID
                    ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;

        RETURN l_csv;
    END gen_acct_sites_csv;

    -- --------------------------------------------------------
    -- Private: generate HzImpAcctSiteUsesT.csv CLOB
    -- --------------------------------------------------------
    FUNCTION gen_acct_site_uses_csv (
        p_run_id IN NUMBER,
        p_batch_id IN NUMBER DEFAULT NULL
    ) RETURN CLOB
    IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        FOR r IN (
            SELECT
                '"' || NVL(TO_CHAR(BATCH_ID), '') || '"' || ','
                || '"' || REPLACE(NVL(CUST_SITE_ORIG_SYSTEM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CUST_SITE_ORIG_SYS_REF,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CUST_SITEUSE_ORIG_SYSTEM,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(CUST_SITEUSE_ORIG_SYS_REF,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SITE_USE_CODE,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PRIMARY_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(INSERT_UPDATE_FLAG,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(LOCATION,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(SET_CODE,''), '"', '""') || '"' || ','
                || '"' || NVL(TO_CHAR(START_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || NVL(TO_CHAR(END_DATE, 'YYYY/MM/DD'), '') || '"' || ','
                || '"' || REPLACE(NVL(ACCOUNT_NUMBER,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(PARTY_SITE_NUMBER,''), '"', '""') || '"' || ','
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
                || '"' || REPLACE(NVL(ATTRIBUTE11,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE12,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE13,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE14,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE15,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE16,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE17,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE18,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE19,''), '"', '""') || '"' || ','
                || '"' || REPLACE(NVL(ATTRIBUTE20,''), '"', '""') || '"' || CHR(10) AS csv_line
            FROM   DMT_OWNER.DMT_HZ_ACCT_SITE_USES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id
            AND    t.TFM_STATUS = 'STAGED'
            AND    (p_batch_id IS NULL OR t.BATCH_ID = p_batch_id)
            ORDER BY t.TFM_SEQUENCE_ID
                    ) LOOP
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(r.csv_line), r.csv_line);
        END LOOP;

        RETURN l_csv;
    END gen_acct_site_uses_csv;

    -- --------------------------------------------------------
    -- Public: GENERATE_FBDI
    -- Builds 7 CSVs, zips them, persists to traceability tables,
    -- marks all 7 TFM tables as GENERATED.
    -- --------------------------------------------------------
    PROCEDURE GENERATE_FBDI (
        p_run_id IN  NUMBER,
        x_fbdi_zip       OUT BLOB,
        x_filename       OUT VARCHAR2,
        x_fbdi_csv_id    OUT NUMBER,
        p_batch_id       IN  NUMBER DEFAULT NULL
    )
    IS
        l_zip             BLOB;
        l_parties_csv     CLOB;
        l_locations_csv   CLOB;
        l_psites_csv      CLOB;
        l_psite_uses_csv  CLOB;
        l_accounts_csv    CLOB;
        l_acct_sites_csv  CLOB;
        l_acct_suses_csv  CLOB;
        l_fbdi_csv_id     NUMBER;   -- primary (parties) csv id, returned to the loader
        l_locations_csv_id  NUMBER;
        l_psites_csv_id     NUMBER;
        l_psite_uses_csv_id NUMBER;
        l_accounts_csv_id   NUMBER;
        l_acct_sites_csv_id NUMBER;
        l_acct_suses_csv_id NUMBER;
        l_zip_id          NUMBER;
        l_bytes           NUMBER;
        l_now             DATE := SYSDATE;
        C_PROC CONSTANT VARCHAR2(30) := 'GENERATE_FBDI';
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Customer FBDI generation start.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        x_filename := 'Customers_' || TO_CHAR(p_run_id) || '.zip';

        -- Generate all 7 CSVs
        l_parties_csv    := gen_parties_csv(p_run_id, p_batch_id);
        l_locations_csv  := gen_locations_csv(p_run_id, p_batch_id);
        l_psites_csv     := gen_party_sites_csv(p_run_id, p_batch_id);
        l_psite_uses_csv := gen_party_site_uses_csv(p_run_id, p_batch_id);
        l_accounts_csv   := gen_accounts_csv(p_run_id, p_batch_id);
        l_acct_sites_csv := gen_acct_sites_csv(p_run_id, p_batch_id);
        l_acct_suses_csv := gen_acct_site_uses_csv(p_run_id, p_batch_id);

        -- AD#20: Skip gracefully if no rows generated (parties is the primary CSV)
        IF (l_parties_csv IS NULL OR DBMS_LOB.GETLENGTH(l_parties_csv) = 0) THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'No STAGED Customer rows found. Skipping FBDI generation.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            DBMS_LOB.FREETEMPORARY(l_parties_csv);
            DBMS_LOB.FREETEMPORARY(l_locations_csv);
            DBMS_LOB.FREETEMPORARY(l_psites_csv);
            DBMS_LOB.FREETEMPORARY(l_psite_uses_csv);
            DBMS_LOB.FREETEMPORARY(l_accounts_csv);
            DBMS_LOB.FREETEMPORARY(l_acct_sites_csv);
            DBMS_LOB.FREETEMPORARY(l_acct_suses_csv);
            x_fbdi_zip := NULL;
            x_filename := NULL;
            x_fbdi_csv_id := NULL;
            RETURN;
        END IF;

        -- FBDI CSV<->ZIP remodel: register each physical CSV as its own row, then
        -- build the zip from those persisted rows. One zip owns seven CSVs.
        SELECT DMT_OWNER.DMT_FBDI_ZIP_ID_SEQ.NEXTVAL INTO l_zip_id FROM DUAL;
        -- Parties (primary) is always present (early-return guards it); each of the other
        -- six child files is registered/zipped only when it has rows, matching the
        -- pre-remodel per-file guards (a batch may legitimately have no account sites yet, etc.).
        l_fbdi_csv_id       := DMT_UTIL_PKG.REGISTER_CSV(p_run_id, l_zip_id, 1, 'Customers', 'HzImpPartiesT.csv',       0, l_parties_csv);
        IF l_locations_csv  IS NOT NULL AND DBMS_LOB.GETLENGTH(l_locations_csv)  > 0 THEN
            l_locations_csv_id  := DMT_UTIL_PKG.REGISTER_CSV(p_run_id, l_zip_id, 2, 'Customers', 'HzImpLocationsT.csv',      0, l_locations_csv);
        END IF;
        IF l_psites_csv     IS NOT NULL AND DBMS_LOB.GETLENGTH(l_psites_csv)     > 0 THEN
            l_psites_csv_id     := DMT_UTIL_PKG.REGISTER_CSV(p_run_id, l_zip_id, 3, 'Customers', 'HzImpPartySitesT.csv',     0, l_psites_csv);
        END IF;
        IF l_psite_uses_csv IS NOT NULL AND DBMS_LOB.GETLENGTH(l_psite_uses_csv) > 0 THEN
            l_psite_uses_csv_id := DMT_UTIL_PKG.REGISTER_CSV(p_run_id, l_zip_id, 4, 'Customers', 'HzImpPartySiteUsesT.csv',  0, l_psite_uses_csv);
        END IF;
        IF l_accounts_csv   IS NOT NULL AND DBMS_LOB.GETLENGTH(l_accounts_csv)   > 0 THEN
            l_accounts_csv_id   := DMT_UTIL_PKG.REGISTER_CSV(p_run_id, l_zip_id, 5, 'Customers', 'HzImpAccountsT.csv',       0, l_accounts_csv);
        END IF;
        IF l_acct_sites_csv IS NOT NULL AND DBMS_LOB.GETLENGTH(l_acct_sites_csv) > 0 THEN
            l_acct_sites_csv_id := DMT_UTIL_PKG.REGISTER_CSV(p_run_id, l_zip_id, 6, 'Customers', 'HzImpAcctSitesT.csv',      0, l_acct_sites_csv);
        END IF;
        IF l_acct_suses_csv IS NOT NULL AND DBMS_LOB.GETLENGTH(l_acct_suses_csv) > 0 THEN
            l_acct_suses_csv_id := DMT_UTIL_PKG.REGISTER_CSV(p_run_id, l_zip_id, 7, 'Customers', 'HzImpAcctSiteUsesT.csv',   0, l_acct_suses_csv);
        END IF;
        DMT_UTIL_PKG.BUILD_ZIP_FROM_CSVS(p_run_id, l_zip_id, 'Customers', x_filename, l_zip, l_bytes);

        -- Update all 7 TFM tables to GENERATED and stamp EACH file's own FBDI_CSV_ID
        UPDATE DMT_OWNER.DMT_HZ_PARTIES_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_fbdi_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED'
        AND    (p_batch_id IS NULL OR BATCH_ID = p_batch_id);

        UPDATE DMT_OWNER.DMT_HZ_LOCATIONS_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_locations_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED'
        AND    (p_batch_id IS NULL OR BATCH_ID = p_batch_id);

        UPDATE DMT_OWNER.DMT_HZ_PARTY_SITES_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_psites_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED'
        AND    (p_batch_id IS NULL OR BATCH_ID = p_batch_id);

        UPDATE DMT_OWNER.DMT_HZ_PARTY_SITE_USES_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_psite_uses_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED'
        AND    (p_batch_id IS NULL OR BATCH_ID = p_batch_id);

        UPDATE DMT_OWNER.DMT_HZ_ACCOUNTS_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_accounts_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED'
        AND    (p_batch_id IS NULL OR BATCH_ID = p_batch_id);

        UPDATE DMT_OWNER.DMT_HZ_ACCT_SITES_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_acct_sites_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED'
        AND    (p_batch_id IS NULL OR BATCH_ID = p_batch_id);

        UPDATE DMT_OWNER.DMT_HZ_ACCT_SITE_USES_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_acct_suses_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED'
        AND    (p_batch_id IS NULL OR BATCH_ID = p_batch_id);

        -- Free temporary CLOBs
        DBMS_LOB.FREETEMPORARY(l_parties_csv);
        DBMS_LOB.FREETEMPORARY(l_locations_csv);
        DBMS_LOB.FREETEMPORARY(l_psites_csv);
        DBMS_LOB.FREETEMPORARY(l_psite_uses_csv);
        DBMS_LOB.FREETEMPORARY(l_accounts_csv);
        DBMS_LOB.FREETEMPORARY(l_acct_sites_csv);
        DBMS_LOB.FREETEMPORARY(l_acct_suses_csv);

        x_fbdi_zip    := l_zip;
        x_fbdi_csv_id := l_fbdi_csv_id;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Customer FBDI generation complete.' ||
                                ' | File: ' || x_filename ||
                                ' | Zip bytes: ' || DBMS_LOB.GETLENGTH(x_fbdi_zip),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'Customer FBDI generation failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END GENERATE_FBDI;

END DMT_CUST_FBDI_GEN_PKG;
/
