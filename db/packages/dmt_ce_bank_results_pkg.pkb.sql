-- PACKAGE BODY DMT_CE_BANK_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_CE_BANK_RESULTS_PKG" AS

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_CE_BANK_RESULTS_PKG';

    -- Fusion REST paths
    C_BANKS_PATH    CONSTANT VARCHAR2(200) := '/fscmRestApi/resources/11.13.18.05/cashBanks';
    C_BRANCHES_PATH CONSTANT VARCHAR2(200) := '/fscmRestApi/resources/11.13.18.05/cashBankBranches';
    C_ACCOUNTS_PATH CONSTANT VARCHAR2(200) := '/fscmRestApi/resources/11.13.18.05/cashBankAccounts';

    -- Cash Management requires fin_impl role — override default user
    C_CE_USERNAME CONSTANT VARCHAR2(30) := 'fin_impl';

    -- --------------------------------------------------------
    -- Private: make a REST call and return status|body
    -- --------------------------------------------------------
    FUNCTION rest_call (
        p_method         IN VARCHAR2,
        p_path           IN VARCHAR2,
        p_body           IN CLOB DEFAULT NULL,
        p_run_id IN NUMBER DEFAULT NULL
    ) RETURN CLOB
    IS
        l_url          VARCHAR2(4000);
        l_http_req     UTL_HTTP.REQ;
        l_http_resp    UTL_HTTP.RESP;
        l_response     CLOB;
        l_chunk        VARCHAR2(32767);
        l_base_url     VARCHAR2(500);
        l_username     VARCHAR2(100);
        l_password     VARCHAR2(100);
        l_status       NUMBER;
    BEGIN
        l_base_url := RTRIM(DMT_UTIL_PKG.GET_CONFIG('FUSION_URL'), '/');
        l_username := C_CE_USERNAME;
        l_password := DMT_UTIL_PKG.GET_CONFIG('FUSION_PASSWORD');
        l_url      := l_base_url || p_path;

        UTL_HTTP.SET_WALLET('file:' || DMT_UTIL_PKG.GET_CONFIG('WALLET_DIR'),
                            DMT_UTIL_PKG.GET_CONFIG('WALLET_PASSWORD'));

        l_http_req := UTL_HTTP.BEGIN_REQUEST(l_url, p_method, 'HTTP/1.1');
        UTL_HTTP.SET_HEADER(l_http_req, 'Authorization',
            'Basic ' || UTL_RAW.CAST_TO_VARCHAR2(UTL_ENCODE.BASE64_ENCODE(
                UTL_RAW.CAST_TO_RAW(l_username || ':' || l_password))));
        UTL_HTTP.SET_HEADER(l_http_req, 'Accept', 'application/json');

        IF p_body IS NOT NULL THEN
            UTL_HTTP.SET_HEADER(l_http_req, 'Content-Type', 'application/json');
            UTL_HTTP.SET_HEADER(l_http_req, 'Content-Length', DBMS_LOB.GETLENGTH(p_body));
            DECLARE
                l_offset PLS_INTEGER := 1;
                l_amount PLS_INTEGER := 8000;
                l_buf    VARCHAR2(8000);
            BEGIN
                WHILE l_offset <= DBMS_LOB.GETLENGTH(p_body) LOOP
                    l_amount := LEAST(8000, DBMS_LOB.GETLENGTH(p_body) - l_offset + 1);
                    DBMS_LOB.READ(p_body, l_amount, l_offset, l_buf);
                    UTL_HTTP.WRITE_TEXT(l_http_req, l_buf);
                    l_offset := l_offset + l_amount;
                END LOOP;
            END;
        END IF;

        l_http_resp := UTL_HTTP.GET_RESPONSE(l_http_req);
        l_status := l_http_resp.status_code;

        DBMS_LOB.CREATETEMPORARY(l_response, TRUE);
        BEGIN
            LOOP
                UTL_HTTP.READ_TEXT(l_http_resp, l_chunk, 32767);
                DBMS_LOB.WRITEAPPEND(l_response, LENGTH(l_chunk), l_chunk);
            END LOOP;
        EXCEPTION
            WHEN UTL_HTTP.END_OF_BODY THEN NULL;
        END;
        UTL_HTTP.END_RESPONSE(l_http_resp);

        DECLARE
            l_result CLOB;
        BEGIN
            DBMS_LOB.CREATETEMPORARY(l_result, TRUE);
            DBMS_LOB.WRITEAPPEND(l_result, LENGTH(TO_CHAR(l_status)), TO_CHAR(l_status));
            DBMS_LOB.WRITEAPPEND(l_result, 1, '|');
            DBMS_LOB.APPEND(l_result, l_response);
            DBMS_LOB.FREETEMPORARY(l_response);
            RETURN l_result;
        END;

    EXCEPTION
        WHEN OTHERS THEN
            BEGIN UTL_HTTP.END_RESPONSE(l_http_resp); EXCEPTION WHEN OTHERS THEN NULL; END;
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'REST call failed: ' || p_method || ' ' || p_path,
                SQLERRM, C_PKG, 'rest_call');
            RAISE;
    END rest_call;

    FUNCTION get_status(p_response IN CLOB) RETURN NUMBER IS
    BEGIN
        RETURN TO_NUMBER(SUBSTR(p_response, 1, INSTR(p_response, '|') - 1));
    END;

    FUNCTION get_body(p_response IN CLOB) RETURN CLOB IS
    BEGIN
        RETURN DBMS_LOB.SUBSTR(p_response,
            DBMS_LOB.GETLENGTH(p_response) - INSTR(p_response, '|'),
            INSTR(p_response, '|') + 1);
    END;

    -- ============================================================
    -- LOAD_AND_RECONCILE
    -- Phase 1: POST banks, extract BankPartyId
    -- Phase 2: POST branches as children, extract BranchPartyId
    -- Phase 3: POST accounts
    -- ============================================================
    PROCEDURE LOAD_AND_RECONCILE (
        p_run_id IN NUMBER
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'LOAD_AND_RECONCILE';

        l_response       CLOB;
        l_http_status    NUMBER;
        l_body           VARCHAR2(32767);
        l_payload        CLOB;
        l_bank_party_id  NUMBER;
        l_branch_party_id NUMBER;
        l_country_name   VARCHAR2(100);

        l_banks_loaded   NUMBER := 0;
        l_banks_failed   NUMBER := 0;
        l_branches_loaded NUMBER := 0;
        l_branches_failed NUMBER := 0;
        l_accts_loaded   NUMBER := 0;
        l_accts_failed   NUMBER := 0;
        l_errmsg         VARCHAR2(4000);

        -- Map SOURCE_GROUP_ID -> BankPartyId
        TYPE t_id_map IS TABLE OF NUMBER INDEX BY VARCHAR2(100);
        l_bank_map   t_id_map;
        -- Map SOURCE_LINE_ID -> BranchPartyId
        l_branch_map t_id_map;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id,
            'LOAD_AND_RECONCILE start.', C_PKG, C_PROC);

        -- ========================================
        -- Phase 1: Create Banks in Fusion
        -- ========================================
        FOR r IN (
            SELECT TFM_SEQUENCE_ID, STG_SEQUENCE_ID, SOURCE_GROUP_ID,
                   COUNTRY_CODE, BANK_NAME, BANK_NUMBER, SHORT_BANK_NAME,
                   DESCRIPTION, TAX_PAYER_ID, TAX_REGISTRATION_NUMBER
            FROM   DMT_CE_BANK_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS = 'GENERATED'
            ORDER BY TFM_SEQUENCE_ID
        ) LOOP
            BEGIN
                -- Map 2-char ISO code to full country name for Fusion REST
                IF r.COUNTRY_CODE IS NULL OR LENGTH(r.COUNTRY_CODE) <= 3 THEN
                    l_country_name := CASE r.COUNTRY_CODE
                        WHEN 'US' THEN 'United States'
                        WHEN 'CA' THEN 'Canada'
                        WHEN 'GB' THEN 'United Kingdom'
                        WHEN 'AU' THEN 'Australia'
                        WHEN 'IN' THEN 'India'
                        WHEN 'DE' THEN 'Germany'
                        WHEN 'FR' THEN 'France'
                        WHEN 'AE' THEN 'United Arab Emirates'
                        ELSE NVL(r.COUNTRY_CODE, 'United States')
                    END;
                ELSE
                    l_country_name := r.COUNTRY_CODE;
                END IF;
                l_payload := '{"CountryName":"' || REPLACE(l_country_name, '"', '\"') || '"'
                    || ',"BankName":"' || REPLACE(r.BANK_NAME, '"', '\"') || '"'
                    || CASE WHEN r.BANK_NUMBER IS NOT NULL
                       THEN ',"BankNumber":"' || REPLACE(r.BANK_NUMBER, '"', '\"') || '"'
                       END
                    || CASE WHEN r.SHORT_BANK_NAME IS NOT NULL
                       THEN ',"ShortBankName":"' || REPLACE(r.SHORT_BANK_NAME, '"', '\"') || '"'
                       END
                    || CASE WHEN r.DESCRIPTION IS NOT NULL
                       THEN ',"Description":"' || REPLACE(r.DESCRIPTION, '"', '\"') || '"'
                       END
                    || CASE WHEN r.TAX_PAYER_ID IS NOT NULL
                       THEN ',"TaxPayerId":"' || REPLACE(r.TAX_PAYER_ID, '"', '\"') || '"'
                       END
                    || CASE WHEN r.TAX_REGISTRATION_NUMBER IS NOT NULL
                       THEN ',"TaxRegistrationNumber":"' || REPLACE(r.TAX_REGISTRATION_NUMBER, '"', '\"') || '"'
                       END
                    || '}';

                l_response := rest_call('POST', C_BANKS_PATH, l_payload, p_run_id);
                l_http_status := get_status(l_response);

                IF l_http_status IN (200, 201) THEN
                    l_body := DBMS_LOB.SUBSTR(l_response, 4000, INSTR(l_response, '|') + 1);
                    l_bank_party_id := JSON_VALUE(l_body, '$.BankPartyId' RETURNING NUMBER);

                    IF r.SOURCE_GROUP_ID IS NOT NULL AND l_bank_party_id IS NOT NULL THEN
                        l_bank_map(r.SOURCE_GROUP_ID) := l_bank_party_id;
                    END IF;

                    UPDATE DMT_CE_BANK_TFM_TBL
                    SET    TFM_STATUS = 'LOADED', RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    UPDATE DMT_CE_BANK_STG_TBL
                    SET    STG_STATUS = 'LOADED', LAST_UPDATED_DATE = SYSDATE
                    WHERE  STG_SEQUENCE_ID = r.STG_SEQUENCE_ID;

                    l_banks_loaded := l_banks_loaded + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Bank LOADED: ' || r.BANK_NAME || ' (BankPartyId=' || l_bank_party_id || ')',
                        C_PKG, C_PROC);
                ELSE
                    l_body := DBMS_LOB.SUBSTR(l_response, 1000, INSTR(l_response, '|') + 1);
                    UPDATE DMT_CE_BANK_TFM_TBL
                    SET    TFM_STATUS = 'FAILED',
                           ERROR_TEXT = '[FUSION_ERROR] HTTP ' || l_http_status || ': '
                                        || SUBSTR(l_body, 1, 2000),
                           RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    UPDATE DMT_CE_BANK_STG_TBL
                    SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                    WHERE  STG_SEQUENCE_ID = r.STG_SEQUENCE_ID;

                    l_banks_failed := l_banks_failed + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Bank FAILED: ' || r.BANK_NAME || ' HTTP ' || l_http_status,
                        C_PKG, C_PROC, 'WARN');
                END IF;

                IF DBMS_LOB.ISTEMPORARY(l_response) = 1 THEN
                    DBMS_LOB.FREETEMPORARY(l_response);
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    l_errmsg := SQLERRM;
                    UPDATE DMT_CE_BANK_TFM_TBL
                    SET    TFM_STATUS = 'FAILED',
                           ERROR_TEXT = '[FUSION_ERROR] ' || l_errmsg,
                           RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    UPDATE DMT_CE_BANK_STG_TBL
                    SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                    WHERE  STG_SEQUENCE_ID = r.STG_SEQUENCE_ID;

                    l_banks_failed := l_banks_failed + 1;
                    DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                        'Bank FAILED (exception): ' || r.BANK_NAME,
                        l_errmsg, C_PKG, C_PROC);
            END;
        END LOOP;

        COMMIT;

        -- ========================================
        -- Phase 2: Create Branches in Fusion
        -- Only for banks that LOADED successfully.
        -- ========================================
        FOR r IN (
            SELECT br.TFM_SEQUENCE_ID, br.STG_SEQUENCE_ID,
                   br.SOURCE_GROUP_ID, br.SOURCE_LINE_ID,
                   br.BANK_NAME, br.BRANCH_NAME, br.BRANCH_NUMBER,
                   br.BIC_CODE, br.ALTERNATE_NAME, br.DESCRIPTION,
                   br.EFT_SWIFT_CODE, br.COUNTRY_CODE,
                   br.ADDRESS_LINE1, br.CITY, br.STATE, br.POSTAL_CODE
            FROM   DMT_CE_BRANCH_TFM_TBL br
            WHERE  br.RUN_ID = p_run_id
            AND    br.TFM_STATUS = 'GENERATED'
            AND    EXISTS (
                SELECT 1 FROM DMT_CE_BANK_TFM_TBL bk
                WHERE  bk.RUN_ID  = p_run_id
                AND    bk.SOURCE_GROUP_ID  = br.SOURCE_GROUP_ID
                AND    bk.TFM_STATUS       = 'LOADED'
            )
            ORDER BY br.SOURCE_GROUP_ID, br.TFM_SEQUENCE_ID
        ) LOOP
            BEGIN
                IF NOT l_bank_map.EXISTS(r.SOURCE_GROUP_ID) THEN
                    l_errmsg := 'No BankPartyId mapping found for SOURCE_GROUP_ID=' || r.SOURCE_GROUP_ID;
                    UPDATE DMT_CE_BRANCH_TFM_TBL
                    SET    TFM_STATUS = 'FAILED',
                           ERROR_TEXT = '[FUSION_ERROR] ' || l_errmsg,
                           RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    UPDATE DMT_CE_BRANCH_STG_TBL
                    SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                    WHERE  STG_SEQUENCE_ID = r.STG_SEQUENCE_ID;

                    l_branches_failed := l_branches_failed + 1;
                    CONTINUE;
                END IF;

                l_bank_party_id := l_bank_map(r.SOURCE_GROUP_ID);

                -- Country mapping for branch
                IF r.COUNTRY_CODE IS NULL OR LENGTH(r.COUNTRY_CODE) <= 3 THEN
                    l_country_name := CASE r.COUNTRY_CODE
                        WHEN 'US' THEN 'United States' WHEN 'CA' THEN 'Canada'
                        WHEN 'GB' THEN 'United Kingdom' WHEN 'AU' THEN 'Australia'
                        ELSE NVL(r.COUNTRY_CODE, 'United States')
                    END;
                ELSE
                    l_country_name := r.COUNTRY_CODE;
                END IF;
                l_payload := '{"BankName":"' || REPLACE(r.BANK_NAME, '"', '\"') || '"'
                    || ',"BankBranchName":"' || REPLACE(r.BRANCH_NAME, '"', '\"') || '"'
                    || CASE WHEN r.BRANCH_NUMBER IS NOT NULL
                       THEN ',"BranchNumber":"' || REPLACE(r.BRANCH_NUMBER, '"', '\"') || '"'
                       END
                    || ',"CountryName":"' || REPLACE(l_country_name, '"', '\"') || '"'
                    || CASE WHEN r.BIC_CODE IS NOT NULL
                       THEN ',"EFTSWIFTCode":"' || REPLACE(r.BIC_CODE, '"', '\"') || '"'
                       END
                    || CASE WHEN r.DESCRIPTION IS NOT NULL
                       THEN ',"Description":"' || REPLACE(r.DESCRIPTION, '"', '\"') || '"'
                       END
                    || '}';

                l_response := rest_call('POST', C_BRANCHES_PATH, l_payload, p_run_id);
                l_http_status := get_status(l_response);

                IF l_http_status IN (200, 201) THEN
                    l_body := DBMS_LOB.SUBSTR(l_response, 4000, INSTR(l_response, '|') + 1);
                    l_branch_party_id := JSON_VALUE(l_body, '$.BranchPartyId' RETURNING NUMBER);

                    IF r.SOURCE_LINE_ID IS NOT NULL AND l_branch_party_id IS NOT NULL THEN
                        l_branch_map(r.SOURCE_LINE_ID) := l_branch_party_id;
                    END IF;

                    UPDATE DMT_CE_BRANCH_TFM_TBL
                    SET    TFM_STATUS = 'LOADED', RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    UPDATE DMT_CE_BRANCH_STG_TBL
                    SET    STG_STATUS = 'LOADED', LAST_UPDATED_DATE = SYSDATE
                    WHERE  STG_SEQUENCE_ID = r.STG_SEQUENCE_ID;

                    l_branches_loaded := l_branches_loaded + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Branch LOADED: ' || r.BRANCH_NAME || ' (BranchPartyId=' || l_branch_party_id || ')',
                        C_PKG, C_PROC);
                ELSE
                    l_body := DBMS_LOB.SUBSTR(l_response, 1000, INSTR(l_response, '|') + 1);
                    UPDATE DMT_CE_BRANCH_TFM_TBL
                    SET    TFM_STATUS = 'FAILED',
                           ERROR_TEXT = '[FUSION_ERROR] HTTP ' || l_http_status || ': '
                                        || SUBSTR(l_body, 1, 2000),
                           RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    UPDATE DMT_CE_BRANCH_STG_TBL
                    SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                    WHERE  STG_SEQUENCE_ID = r.STG_SEQUENCE_ID;

                    l_branches_failed := l_branches_failed + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Branch FAILED: ' || r.BRANCH_NAME || ' HTTP ' || l_http_status,
                        C_PKG, C_PROC, 'WARN');
                END IF;

                IF DBMS_LOB.ISTEMPORARY(l_response) = 1 THEN
                    DBMS_LOB.FREETEMPORARY(l_response);
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    l_errmsg := SQLERRM;
                    UPDATE DMT_CE_BRANCH_TFM_TBL
                    SET    TFM_STATUS = 'FAILED',
                           ERROR_TEXT = '[FUSION_ERROR] ' || l_errmsg,
                           RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    UPDATE DMT_CE_BRANCH_STG_TBL
                    SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                    WHERE  STG_SEQUENCE_ID = r.STG_SEQUENCE_ID;

                    l_branches_failed := l_branches_failed + 1;
                    DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                        'Branch FAILED (exception): ' || r.BRANCH_NAME,
                        l_errmsg, C_PKG, C_PROC);
            END;
        END LOOP;

        -- Mark orphan branches (parent bank FAILED)
        UPDATE DMT_CE_BRANCH_TFM_TBL
        SET    TFM_STATUS = 'FAILED',
               ERROR_TEXT = NVL(ERROR_TEXT, '') || '[FUSION_ERROR] Parent bank was not loaded.',
               RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'GENERATED'
        AND    NOT EXISTS (
            SELECT 1 FROM DMT_CE_BANK_TFM_TBL bk
            WHERE  bk.RUN_ID  = p_run_id
            AND    bk.SOURCE_GROUP_ID  = DMT_CE_BRANCH_TFM_TBL.SOURCE_GROUP_ID
            AND    bk.TFM_STATUS       = 'LOADED'
        );

        UPDATE DMT_CE_BRANCH_STG_TBL
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (
            SELECT STG_SEQUENCE_ID FROM DMT_CE_BRANCH_TFM_TBL
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'FAILED'
        )
        AND    STG_STATUS != 'FAILED';

        COMMIT;

        -- ========================================
        -- Phase 3: Create Bank Accounts in Fusion
        -- Only for branches that LOADED successfully.
        -- ========================================
        FOR r IN (
            SELECT acct.TFM_SEQUENCE_ID, acct.STG_SEQUENCE_ID,
                   acct.SOURCE_GROUP_ID, acct.SOURCE_LINE_ID,
                   acct.BANK_NAME, acct.BRANCH_NAME,
                   acct.ACCOUNT_NAME, acct.ACCOUNT_NUMBER,
                   acct.CURRENCY_CODE, acct.ACCOUNT_TYPE,
                   acct.LEGAL_ENTITY_NAME, acct.DESCRIPTION,
                   acct.IBAN, acct.CHECK_DIGITS,
                   acct.MULTI_CURRENCY_ALLOWED_FLAG,
                   acct.ACCOUNT_SUFFIX, acct.SECONDARY_ACCOUNT_REFERENCE
            FROM   DMT_CE_BANK_ACCT_TFM_TBL acct
            WHERE  acct.RUN_ID = p_run_id
            AND    acct.TFM_STATUS = 'GENERATED'
            AND    EXISTS (
                SELECT 1 FROM DMT_CE_BRANCH_TFM_TBL br
                WHERE  br.RUN_ID = p_run_id
                AND    br.SOURCE_LINE_ID  = acct.SOURCE_LINE_ID
                AND    br.TFM_STATUS      = 'LOADED'
            )
            ORDER BY acct.SOURCE_LINE_ID, acct.TFM_SEQUENCE_ID
        ) LOOP
            BEGIN
                -- Build payload — field names from cashBankAccounts/describe
                l_payload := '{"BankAccountName":"' || REPLACE(r.ACCOUNT_NAME, '"', '\"') || '"'
                    || CASE WHEN r.ACCOUNT_NUMBER IS NOT NULL
                       THEN ',"BankAccountNumber":"' || REPLACE(r.ACCOUNT_NUMBER, '"', '\"') || '"'
                       END
                    || CASE WHEN r.CURRENCY_CODE IS NOT NULL
                       THEN ',"CurrencyCode":"' || REPLACE(r.CURRENCY_CODE, '"', '\"') || '"'
                       END
                    || CASE WHEN r.DESCRIPTION IS NOT NULL
                       THEN ',"Description":"' || REPLACE(r.DESCRIPTION, '"', '\"') || '"'
                       END
                    || CASE WHEN r.IBAN IS NOT NULL
                       THEN ',"IBANNumber":"' || REPLACE(r.IBAN, '"', '\"') || '"'
                       END
                    || CASE WHEN r.CHECK_DIGITS IS NOT NULL
                       THEN ',"CheckDigits":"' || REPLACE(r.CHECK_DIGITS, '"', '\"') || '"'
                       END
                    || CASE WHEN r.ACCOUNT_SUFFIX IS NOT NULL
                       THEN ',"AccountSuffix":"' || REPLACE(r.ACCOUNT_SUFFIX, '"', '\"') || '"'
                       END
                    || '}';

                l_response := rest_call('POST', C_ACCOUNTS_PATH, l_payload, p_run_id);
                l_http_status := get_status(l_response);

                IF l_http_status IN (200, 201) THEN
                    UPDATE DMT_CE_BANK_ACCT_TFM_TBL
                    SET    TFM_STATUS = 'LOADED', RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    UPDATE DMT_CE_BANK_ACCT_STG_TBL
                    SET    STG_STATUS = 'LOADED', LAST_UPDATED_DATE = SYSDATE
                    WHERE  STG_SEQUENCE_ID = r.STG_SEQUENCE_ID;

                    l_accts_loaded := l_accts_loaded + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Account LOADED: ' || r.ACCOUNT_NAME,
                        C_PKG, C_PROC);
                ELSE
                    l_body := DBMS_LOB.SUBSTR(l_response, 1000, INSTR(l_response, '|') + 1);
                    UPDATE DMT_CE_BANK_ACCT_TFM_TBL
                    SET    TFM_STATUS = 'FAILED',
                           ERROR_TEXT = '[FUSION_ERROR] HTTP ' || l_http_status || ': '
                                        || SUBSTR(l_body, 1, 2000),
                           RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    UPDATE DMT_CE_BANK_ACCT_STG_TBL
                    SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                    WHERE  STG_SEQUENCE_ID = r.STG_SEQUENCE_ID;

                    l_accts_failed := l_accts_failed + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Account FAILED: ' || r.ACCOUNT_NAME || ' HTTP ' || l_http_status,
                        C_PKG, C_PROC, 'WARN');
                END IF;

                IF DBMS_LOB.ISTEMPORARY(l_response) = 1 THEN
                    DBMS_LOB.FREETEMPORARY(l_response);
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    l_errmsg := SQLERRM;
                    UPDATE DMT_CE_BANK_ACCT_TFM_TBL
                    SET    TFM_STATUS = 'FAILED',
                           ERROR_TEXT = '[FUSION_ERROR] ' || l_errmsg,
                           RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    UPDATE DMT_CE_BANK_ACCT_STG_TBL
                    SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                    WHERE  STG_SEQUENCE_ID = r.STG_SEQUENCE_ID;

                    l_accts_failed := l_accts_failed + 1;
                    DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                        'Account FAILED (exception): ' || r.ACCOUNT_NAME,
                        l_errmsg, C_PKG, C_PROC);
            END;
        END LOOP;

        -- Mark orphan accounts (parent branch FAILED)
        UPDATE DMT_CE_BANK_ACCT_TFM_TBL
        SET    TFM_STATUS = 'FAILED',
               ERROR_TEXT = NVL(ERROR_TEXT, '') || '[FUSION_ERROR] Parent branch was not loaded.',
               RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'GENERATED'
        AND    NOT EXISTS (
            SELECT 1 FROM DMT_CE_BRANCH_TFM_TBL br
            WHERE  br.RUN_ID = p_run_id
            AND    br.SOURCE_LINE_ID  = DMT_CE_BANK_ACCT_TFM_TBL.SOURCE_LINE_ID
            AND    br.TFM_STATUS      = 'LOADED'
        );

        UPDATE DMT_CE_BANK_ACCT_STG_TBL
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (
            SELECT STG_SEQUENCE_ID FROM DMT_CE_BANK_ACCT_TFM_TBL
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'FAILED'
        )
        AND    STG_STATUS != 'FAILED';

        COMMIT;

        DMT_UTIL_PKG.LOG(p_run_id,
            'LOAD_AND_RECONCILE complete. Banks: ' || l_banks_loaded || ' LOADED, '
            || l_banks_failed || ' FAILED | Branches: ' || l_branches_loaded || ' LOADED, '
            || l_branches_failed || ' FAILED | Accounts: ' || l_accts_loaded || ' LOADED, '
            || l_accts_failed || ' FAILED',
            C_PKG, C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'LOAD_AND_RECONCILE failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END LOAD_AND_RECONCILE;

END DMT_CE_BANK_RESULTS_PKG;
/
