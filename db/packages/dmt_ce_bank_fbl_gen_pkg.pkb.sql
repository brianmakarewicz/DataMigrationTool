-- PACKAGE BODY DMT_CE_BANK_FBL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_CE_BANK_FBL_GEN_PKG" AS
-- ============================================================
-- CE Bank FBL generator
-- Three pipe-delimited CSV files with headers.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_CE_BANK_FBL_GEN_PKG';

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
    -- gen_banks_csv
    -- --------------------------------------------------------
    FUNCTION gen_banks_csv (p_run_id IN NUMBER) RETURN CLOB IS
        l_csv  CLOB;
        l_line VARCHAR2(32767);
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        l_line := 'SourceGroupId|CountryCode|BankName|BankNumber|ShortBankName'
               || '|Description|TaxPayerId|TaxRegistrationNumber|EndDate'
               || '|AttributeCategory|Attribute1|Attribute2|Attribute3|Attribute4|Attribute5'
               || CHR(10);
        DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(l_line), l_line);

        FOR r IN (
            SELECT SOURCE_GROUP_ID, COUNTRY_CODE, BANK_NAME, BANK_NUMBER,
                   SHORT_BANK_NAME, DESCRIPTION, TAX_PAYER_ID,
                   TAX_REGISTRATION_NUMBER, END_DATE,
                   ATTRIBUTE_CATEGORY, ATTRIBUTE1, ATTRIBUTE2, ATTRIBUTE3,
                   ATTRIBUTE4, ATTRIBUTE5
            FROM   DMT_OWNER.DMT_CE_BANK_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS     = 'STAGED'
            ORDER BY TFM_SEQUENCE_ID
        ) LOOP
            l_line := NVL(r.SOURCE_GROUP_ID, '')                                 || '|'
                   || NVL(r.COUNTRY_CODE, '')                                    || '|'
                   || NVL(r.BANK_NAME, '')                                       || '|'
                   || NVL(r.BANK_NUMBER, '')                                     || '|'
                   || NVL(r.SHORT_BANK_NAME, '')                                 || '|'
                   || NVL(r.DESCRIPTION, '')                                     || '|'
                   || NVL(r.TAX_PAYER_ID, '')                                    || '|'
                   || NVL(r.TAX_REGISTRATION_NUMBER, '')                         || '|'
                   || NVL(TO_CHAR(r.END_DATE, 'YYYY/MM/DD'), '')                 || '|'
                   || NVL(r.ATTRIBUTE_CATEGORY, '')                              || '|'
                   || NVL(r.ATTRIBUTE1, '')                                      || '|'
                   || NVL(r.ATTRIBUTE2, '')                                      || '|'
                   || NVL(r.ATTRIBUTE3, '')                                      || '|'
                   || NVL(r.ATTRIBUTE4, '')                                      || '|'
                   || NVL(r.ATTRIBUTE5, '')
                   || CHR(10);
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(l_line), l_line);
        END LOOP;

        RETURN l_csv;
    END gen_banks_csv;

    -- --------------------------------------------------------
    -- gen_branches_csv
    -- --------------------------------------------------------
    FUNCTION gen_branches_csv (p_run_id IN NUMBER) RETURN CLOB IS
        l_csv  CLOB;
        l_line VARCHAR2(32767);
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        l_line := 'SourceGroupId|SourceLineId|BankName|BranchName|BranchNumber'
               || '|BicCode|AlternateName|Description|EftSwiftCode|CountryCode'
               || '|AddressLine1|City|State|PostalCode|EndDate'
               || CHR(10);
        DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(l_line), l_line);

        FOR r IN (
            SELECT SOURCE_GROUP_ID, SOURCE_LINE_ID, BANK_NAME, BRANCH_NAME,
                   BRANCH_NUMBER, BIC_CODE, ALTERNATE_NAME, DESCRIPTION,
                   EFT_SWIFT_CODE, COUNTRY_CODE, ADDRESS_LINE1, CITY,
                   STATE, POSTAL_CODE, END_DATE
            FROM   DMT_OWNER.DMT_CE_BRANCH_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS     = 'STAGED'
            ORDER BY TFM_SEQUENCE_ID
        ) LOOP
            l_line := NVL(r.SOURCE_GROUP_ID, '')       || '|'
                   || NVL(r.SOURCE_LINE_ID, '')        || '|'
                   || NVL(r.BANK_NAME, '')             || '|'
                   || NVL(r.BRANCH_NAME, '')           || '|'
                   || NVL(r.BRANCH_NUMBER, '')         || '|'
                   || NVL(r.BIC_CODE, '')              || '|'
                   || NVL(r.ALTERNATE_NAME, '')        || '|'
                   || NVL(r.DESCRIPTION, '')           || '|'
                   || NVL(r.EFT_SWIFT_CODE, '')        || '|'
                   || NVL(r.COUNTRY_CODE, '')          || '|'
                   || NVL(r.ADDRESS_LINE1, '')         || '|'
                   || NVL(r.CITY, '')                  || '|'
                   || NVL(r.STATE, '')                 || '|'
                   || NVL(r.POSTAL_CODE, '')           || '|'
                   || NVL(TO_CHAR(r.END_DATE, 'YYYY/MM/DD'), '')
                   || CHR(10);
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(l_line), l_line);
        END LOOP;

        RETURN l_csv;
    END gen_branches_csv;

    -- --------------------------------------------------------
    -- gen_accounts_csv
    -- --------------------------------------------------------
    FUNCTION gen_accounts_csv (p_run_id IN NUMBER) RETURN CLOB IS
        l_csv  CLOB;
        l_line VARCHAR2(32767);
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        l_line := 'SourceGroupId|SourceLineId|BankName|BranchName|AccountName'
               || '|AccountNumber|CurrencyCode|AccountType|LegalEntityName'
               || '|Description|Iban|CheckDigits|MultiCurrencyAllowedFlag'
               || '|AccountSuffix|SecondaryAccountReference|EndDate'
               || '|AttributeCategory|Attribute1|Attribute2|Attribute3|Attribute4|Attribute5'
               || CHR(10);
        DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(l_line), l_line);

        FOR r IN (
            SELECT SOURCE_GROUP_ID, SOURCE_LINE_ID, BANK_NAME, BRANCH_NAME,
                   ACCOUNT_NAME, ACCOUNT_NUMBER, CURRENCY_CODE, ACCOUNT_TYPE,
                   LEGAL_ENTITY_NAME, DESCRIPTION, IBAN, CHECK_DIGITS,
                   MULTI_CURRENCY_ALLOWED_FLAG, ACCOUNT_SUFFIX,
                   SECONDARY_ACCOUNT_REFERENCE, END_DATE,
                   ATTRIBUTE_CATEGORY, ATTRIBUTE1, ATTRIBUTE2, ATTRIBUTE3,
                   ATTRIBUTE4, ATTRIBUTE5
            FROM   DMT_OWNER.DMT_CE_BANK_ACCT_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS     = 'STAGED'
            ORDER BY TFM_SEQUENCE_ID
        ) LOOP
            l_line := NVL(r.SOURCE_GROUP_ID, '')                    || '|'
                   || NVL(r.SOURCE_LINE_ID, '')                     || '|'
                   || NVL(r.BANK_NAME, '')                          || '|'
                   || NVL(r.BRANCH_NAME, '')                        || '|'
                   || NVL(r.ACCOUNT_NAME, '')                       || '|'
                   || NVL(r.ACCOUNT_NUMBER, '')                     || '|'
                   || NVL(r.CURRENCY_CODE, '')                      || '|'
                   || NVL(r.ACCOUNT_TYPE, '')                       || '|'
                   || NVL(r.LEGAL_ENTITY_NAME, '')                  || '|'
                   || NVL(r.DESCRIPTION, '')                        || '|'
                   || NVL(r.IBAN, '')                               || '|'
                   || NVL(r.CHECK_DIGITS, '')                       || '|'
                   || NVL(r.MULTI_CURRENCY_ALLOWED_FLAG, '')        || '|'
                   || NVL(r.ACCOUNT_SUFFIX, '')                     || '|'
                   || NVL(r.SECONDARY_ACCOUNT_REFERENCE, '')        || '|'
                   || NVL(TO_CHAR(r.END_DATE, 'YYYY/MM/DD'), '')    || '|'
                   || NVL(r.ATTRIBUTE_CATEGORY, '')                 || '|'
                   || NVL(r.ATTRIBUTE1, '')                         || '|'
                   || NVL(r.ATTRIBUTE2, '')                         || '|'
                   || NVL(r.ATTRIBUTE3, '')                         || '|'
                   || NVL(r.ATTRIBUTE4, '')                         || '|'
                   || NVL(r.ATTRIBUTE5, '')
                   || CHR(10);
            DBMS_LOB.WRITEAPPEND(l_csv, LENGTH(l_line), l_line);
        END LOOP;

        RETURN l_csv;
    END gen_accounts_csv;

    -- ============================================================
    -- GENERATE_FBL
    -- ============================================================
    PROCEDURE GENERATE_FBL (
        p_run_id  IN  NUMBER,
        x_fbl_zip         OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_fbdi_csv_id     OUT NUMBER
    ) IS
        C_PROC           CONSTANT VARCHAR2(30) := 'GENERATE_FBL';
        l_zip            BLOB;
        l_bank_csv       CLOB;
        l_branch_csv     CLOB;
        l_acct_csv       CLOB;
        l_bank_csv_id    NUMBER;
        l_branch_csv_id  NUMBER;
        l_acct_csv_id    NUMBER;
        l_now            DATE := SYSDATE;
        l_bank_count     NUMBER;
        l_branch_count   NUMBER;
        l_acct_count     NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'CE Bank FBL generation start.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        x_filename := 'CeBanks_' || TO_CHAR(p_run_id) || '.zip';

        SELECT COUNT(*) INTO l_bank_count
        FROM   DMT_OWNER.DMT_CE_BANK_TFM_TBL
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        SELECT COUNT(*) INTO l_branch_count
        FROM   DMT_OWNER.DMT_CE_BRANCH_TFM_TBL
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        SELECT COUNT(*) INTO l_acct_count
        FROM   DMT_OWNER.DMT_CE_BANK_ACCT_TFM_TBL
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        IF l_bank_count = 0 AND l_branch_count = 0 AND l_acct_count = 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'No STAGED bank/branch/account rows found. Skipping zip generation.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            x_fbl_zip     := NULL;
            x_fbdi_csv_id := NULL;
            RETURN;
        END IF;

        l_bank_csv   := gen_banks_csv(p_run_id);
        l_branch_csv := gen_branches_csv(p_run_id);
        l_acct_csv   := gen_accounts_csv(p_run_id);

        -- Store bank CSV artefact
        SELECT DMT_OWNER.DMT_FBDI_CSV_ID_SEQ.NEXTVAL INTO l_bank_csv_id FROM DUAL;
        INSERT INTO DMT_OWNER.DMT_FBDI_CSV_TBL (
            FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME, ROW_COUNT,
            CSV_CONTENT, CREATED_DATE
        ) VALUES (
            l_bank_csv_id, p_run_id, 'CE_BANK',
            'CeBank.csv', l_bank_count, l_bank_csv, l_now
        );

        -- Store branch CSV artefact
        SELECT DMT_OWNER.DMT_FBDI_CSV_ID_SEQ.NEXTVAL INTO l_branch_csv_id FROM DUAL;
        INSERT INTO DMT_OWNER.DMT_FBDI_CSV_TBL (
            FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME, ROW_COUNT,
            CSV_CONTENT, CREATED_DATE
        ) VALUES (
            l_branch_csv_id, p_run_id, 'CE_BRANCH',
            'CeBranch.csv', l_branch_count, l_branch_csv, l_now
        );

        -- Store account CSV artefact
        SELECT DMT_OWNER.DMT_FBDI_CSV_ID_SEQ.NEXTVAL INTO l_acct_csv_id FROM DUAL;
        INSERT INTO DMT_OWNER.DMT_FBDI_CSV_TBL (
            FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME, ROW_COUNT,
            CSV_CONTENT, CREATED_DATE
        ) VALUES (
            l_acct_csv_id, p_run_id, 'CE_BANK_ACCT',
            'CeAccount.csv', l_acct_count, l_acct_csv, l_now
        );

        -- Build zip with all three files
        DBMS_LOB.CREATETEMPORARY(l_zip, TRUE);

        IF l_bank_count > 0 AND DBMS_LOB.GETLENGTH(l_bank_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'CeBank.csv',
                clob_to_blob(l_bank_csv));
        END IF;

        IF l_branch_count > 0 AND DBMS_LOB.GETLENGTH(l_branch_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'CeBranch.csv',
                clob_to_blob(l_branch_csv));
        END IF;

        IF l_acct_count > 0 AND DBMS_LOB.GETLENGTH(l_acct_csv) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'CeAccount.csv',
                clob_to_blob(l_acct_csv));
        END IF;

        DMT_OWNER.UTL_ZIP.finish_zip(l_zip);

        -- Store zip artefact
        INSERT INTO DMT_OWNER.DMT_FBDI_ZIP_TBL (
            FBDI_ZIP_ID, FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME,
            ZIP_SIZE_BYTES, ZIP_CONTENT, CREATED_DATE
        ) VALUES (
            DMT_OWNER.DMT_FBDI_ZIP_ID_SEQ.NEXTVAL, l_bank_csv_id, p_run_id,
            'CE_BANK', x_filename, DBMS_LOB.GETLENGTH(l_zip), l_zip, l_now
        );

        -- Update bank TFM: STAGED -> GENERATED
        IF l_bank_count > 0 THEN
            UPDATE DMT_OWNER.DMT_CE_BANK_TFM_TBL
            SET    TFM_STATUS        = 'GENERATED',
                   FBDI_CSV_ID       = l_bank_csv_id,
                   LAST_UPDATED_DATE = l_now
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';
        END IF;

        -- Update branch TFM: STAGED -> GENERATED
        IF l_branch_count > 0 THEN
            UPDATE DMT_OWNER.DMT_CE_BRANCH_TFM_TBL
            SET    TFM_STATUS        = 'GENERATED',
                   FBDI_CSV_ID       = l_branch_csv_id,
                   LAST_UPDATED_DATE = l_now
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';
        END IF;

        -- Update account TFM: STAGED -> GENERATED
        IF l_acct_count > 0 THEN
            UPDATE DMT_OWNER.DMT_CE_BANK_ACCT_TFM_TBL
            SET    TFM_STATUS        = 'GENERATED',
                   FBDI_CSV_ID       = l_acct_csv_id,
                   LAST_UPDATED_DATE = l_now
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';
        END IF;

        DBMS_LOB.FREETEMPORARY(l_bank_csv);
        DBMS_LOB.FREETEMPORARY(l_branch_csv);
        DBMS_LOB.FREETEMPORARY(l_acct_csv);

        x_fbl_zip     := l_zip;
        x_fbdi_csv_id := l_bank_csv_id;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'CE Bank FBL generation complete. Banks: ' || l_bank_count
                                || ' | Branches: ' || l_branch_count
                                || ' | Accounts: ' || l_acct_count
                                || ' | File: ' || x_filename
                                || ' | Zip bytes: ' || DBMS_LOB.GETLENGTH(l_zip),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'CE Bank FBL generation failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END GENERATE_FBL;

END DMT_CE_BANK_FBL_GEN_PKG;
/
