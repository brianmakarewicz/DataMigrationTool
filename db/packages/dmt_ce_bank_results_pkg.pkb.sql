-- PACKAGE BODY DMT_CE_BANK_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_CE_BANK_RESULTS_PKG" AS
-- ============================================================
-- DMT_CE_BANK_RESULTS_PKG body
-- Cash Management Banks / Bank Branches / Bank Accounts:
-- REST load + BIP base-table reconciliation.
--
-- New reconciliation standard (DMT_DESIGN.html, PROPOSED 2026-09):
-- reconciliation MUST be a BIP report over the Fusion BASE tables that returns
-- the base-table surrogate id. A REST load-call HTTP 200 is NOT reconciliation.
-- So the two responsibilities are separated, and this three-tier object handles
-- each tier the same way (banks, then branches, then accounts):
--
--   LOAD  (LOAD_BANKS / LOAD_BRANCHES / LOAD_ACCOUNTS): POST each GENERATED row
--         to its Fusion REST resource. A non-2xx response or an exception is a
--         genuine load-time rejection -> its real message is STASHED into
--         ERROR_TEXT (accumulate, never overwrite). The POST response is NOT
--         treated as LOADED; the row is left GENERATED, pending positive
--         base-table confirmation.
--
--   RECONCILE (FETCH_BIP_RESULTS + PARSE_*): run the base-table report
--         DMT_CEBANK_RECON_RPT over this run's natural keys. A key found in the
--         base view/table is positive proof -> the row is LOADED with its
--         FUSION_*_ID set to the real surrogate id (BANK_PARTY_ID /
--         BRANCH_PARTY_ID / BANK_ACCOUNT_ID). A key not returned by the report
--         was not created: it stays FAILED if the REST load stashed a real error,
--         otherwise it is left GENERATED (unaccounted) -- never a fabricated
--         LOADED or id.
--
--   HIERARCHY: branches are children of a confirmed bank; accounts are children
--         of a confirmed branch. A tier's LOAD step only POSTs rows whose parent
--         was base-table-confirmed in the prior tier; rows under an unconfirmed
--         parent are left GENERATED (no fabricated error) for the accounting gate
--         to surface. Because GOOD demo fixtures reuse EXISTING bank/branch/
--         account records (the demo pod does not always allow REST create of
--         cash-management master data), the POST may return a 4xx duplicate --
--         but the base-table report still confirms the row LOADED and captures
--         the real surrogate id. That is the whole point of the new standard.
--
-- Transport is a local rest_call helper (the "STATUS|body" convention). The
-- base-table report goes through the shared DMT_UTIL_PKG.RUN_BIP_REPORT. The
-- base views are CE_BANKS_V (BANK_PARTY_ID), CE_BANK_BRANCHES_V
-- (BRANCH_PARTY_ID) and the base table CE_BANK_ACCOUNTS (BANK_ACCOUNT_ID).
-- Backlog #11 / new recon standard.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_CE_BANK_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'CashBanks';

    -- Fusion REST base paths
    C_BANKS_PATH    CONSTANT VARCHAR2(200) := '/fscmRestApi/resources/11.13.18.05/cashBanks';
    C_BRANCHES_PATH CONSTANT VARCHAR2(200) := '/fscmRestApi/resources/11.13.18.05/cashBankBranches';
    C_ACCOUNTS_PATH CONSTANT VARCHAR2(200) := '/fscmRestApi/resources/11.13.18.05/cashBankAccounts';

    -- Cash Management requires the fin_impl role -- override default user.
    C_CE_USERNAME CONSTANT VARCHAR2(30) := 'fin_impl';

    -- --------------------------------------------------------
    -- Private: make a REST call and return status|body
    -- (unchanged transport; the "STATUS|body" convention is kept).
    -- --------------------------------------------------------
    FUNCTION rest_call (
        p_method IN VARCHAR2,
        p_path   IN VARCHAR2,
        p_body   IN CLOB DEFAULT NULL,
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

        -- Attach a wallet only when a real one is configured; otherwise use the DB
        -- default certificate store (as DMT_UTIL_PKG.HTTP_REQUEST and every other
        -- HTTP caller do). An unset/placeholder WALLET_DIR must not be forced into
        -- an invalid 'file:...' path -- that throws ORA-29273 before any auth.
        IF INSTR(NVL(DMT_UTIL_PKG.GET_CONFIG('WALLET_DIR'),' '),'/') > 0 THEN
            UTL_HTTP.SET_WALLET('file:' || DMT_UTIL_PKG.GET_CONFIG('WALLET_DIR'),
                                DMT_UTIL_PKG.GET_CONFIG('WALLET_PASSWORD'));
        END IF;

        l_http_req := UTL_HTTP.BEGIN_REQUEST(l_url, p_method, 'HTTP/1.1');
        UTL_HTTP.SET_HEADER(l_http_req, 'Authorization',
            'Basic ' || UTL_RAW.CAST_TO_VARCHAR2(UTL_ENCODE.BASE64_ENCODE(
                UTL_RAW.CAST_TO_RAW(l_username || ':' || l_password))));
        UTL_HTTP.SET_HEADER(l_http_req, 'Accept', 'application/json');
        -- Ask Fusion NOT to gzip the response. Without this, error bodies come
        -- back gzip-compressed and land in ERROR_TEXT as unreadable binary; the
        -- real Fusion rejection message must be human-readable per the mission.
        UTL_HTTP.SET_HEADER(l_http_req, 'Accept-Encoding', 'identity');

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

    -- --------------------------------------------------------
    -- Private: extract HTTP status from rest_call response
    -- --------------------------------------------------------
    FUNCTION get_status(p_response IN CLOB) RETURN NUMBER IS
    BEGIN
        RETURN TO_NUMBER(SUBSTR(p_response, 1, INSTR(p_response, '|') - 1));
    END get_status;

    -- --------------------------------------------------------
    -- Private: map 2-char ISO country code to the full Fusion country name.
    -- --------------------------------------------------------
    FUNCTION country_name(p_code IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        IF p_code IS NULL OR LENGTH(p_code) <= 3 THEN
            RETURN CASE p_code
                WHEN 'US' THEN 'United States'
                WHEN 'CA' THEN 'Canada'
                WHEN 'GB' THEN 'United Kingdom'
                WHEN 'AU' THEN 'Australia'
                WHEN 'IN' THEN 'India'
                WHEN 'DE' THEN 'Germany'
                WHEN 'FR' THEN 'France'
                WHEN 'AE' THEN 'United Arab Emirates'
                ELSE NVL(p_code, 'United States')
            END;
        END IF;
        RETURN p_code;
    END country_name;

    -- ============================================================
    -- LOAD_BANKS
    -- The LOAD step for banks: POST each GENERATED bank to Fusion. The base-table
    -- report -- not the POST response -- is the authority for LOADED, so this
    -- step NEVER marks a bank terminal. It leaves every attempted bank GENERATED.
    -- A non-2xx / exception is a real Fusion rejection: its message is STASHED
    -- into ERROR_TEXT (accumulate, never overwrite) so that if the reconcile step
    -- later finds the bank absent from CE_BANKS_V, the sweep can mark it FAILED
    -- with that real error. If the reconcile step DOES find the bank (e.g. a
    -- duplicate POST 400 for a bank name that already exists), the stash is
    -- harmless context and the bank is correctly marked LOADED.
    -- Writes the TFM table only; no COMMIT (the runner owns the txn).
    -- ============================================================
    PROCEDURE LOAD_BANKS (
        p_run_id IN NUMBER
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'LOAD_BANKS';
        l_response     CLOB;
        l_http_status  NUMBER;
        l_body         VARCHAR2(32767);
        l_payload      CLOB;
        l_posted       NUMBER := 0;
        l_reject       NUMBER := 0;
        l_errmsg       VARCHAR2(4000);
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, C_PROC || ' start.', p_package => C_PKG, p_procedure => C_PROC);

        FOR r IN (
            SELECT TFM_SEQUENCE_ID, BANK_NAME, BANK_NUMBER, SHORT_BANK_NAME,
                   DESCRIPTION, TAX_PAYER_ID, TAX_REGISTRATION_NUMBER, COUNTRY_CODE
            FROM   DMT_CE_BANK_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS = 'GENERATED'
            ORDER BY TFM_SEQUENCE_ID
        ) LOOP
            BEGIN
                l_payload := '{"CountryName":"' || REPLACE(country_name(r.COUNTRY_CODE), '"', '\"') || '"'
                    || ',"BankName":"' || REPLACE(r.BANK_NAME, '"', '\"') || '"'
                    || CASE WHEN r.BANK_NUMBER IS NOT NULL
                       THEN ',"BankNumber":"' || REPLACE(r.BANK_NUMBER, '"', '\"') || '"' END
                    || CASE WHEN r.SHORT_BANK_NAME IS NOT NULL
                       THEN ',"ShortBankName":"' || REPLACE(r.SHORT_BANK_NAME, '"', '\"') || '"' END
                    || CASE WHEN r.DESCRIPTION IS NOT NULL
                       THEN ',"Description":"' || REPLACE(r.DESCRIPTION, '"', '\"') || '"' END
                    || CASE WHEN r.TAX_PAYER_ID IS NOT NULL
                       THEN ',"TaxPayerId":"' || REPLACE(r.TAX_PAYER_ID, '"', '\"') || '"' END
                    || CASE WHEN r.TAX_REGISTRATION_NUMBER IS NOT NULL
                       THEN ',"TaxRegistrationNumber":"' || REPLACE(r.TAX_REGISTRATION_NUMBER, '"', '\"') || '"' END
                    || '}';

                l_response := rest_call('POST', C_BANKS_PATH, l_payload, p_run_id);
                l_http_status := get_status(l_response);

                IF l_http_status IN (200, 201) THEN
                    l_posted := l_posted + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Bank POSTed (awaiting base-table confirmation): ' || r.BANK_NAME
                        || ' HTTP ' || l_http_status, p_package => C_PKG, p_procedure => C_PROC);
                ELSE
                    l_body := DBMS_LOB.SUBSTR(l_response, 2000, INSTR(l_response, '|') + 1);
                    UPDATE DMT_CE_BANK_TFM_TBL
                    SET    ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                          '[FUSION_ERROR] HTTP ' || l_http_status || ': '
                                          || SUBSTR(l_body, 1, 2000)),
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;
                    l_reject := l_reject + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Bank POST rejected (stashed, awaiting base-table verdict): '
                        || r.BANK_NAME || ' HTTP ' || l_http_status, 'WARN', p_package => C_PKG, p_procedure => C_PROC);
                END IF;

                IF DBMS_LOB.ISTEMPORARY(l_response) = 1 THEN
                    DBMS_LOB.FREETEMPORARY(l_response);
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    l_errmsg := SQLERRM;
                    UPDATE DMT_CE_BANK_TFM_TBL
                    SET    ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                          '[FUSION_ERROR] ' || l_errmsg),
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;
                    l_reject := l_reject + 1;
                    DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                        'Bank POST failed (exception, stashed): ' || r.BANK_NAME,
                        l_errmsg, C_PKG, C_PROC);
            END;
        END LOOP;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. POSTed 2xx: ' || l_posted
            || ', POST-rejected(stashed): ' || l_reject
            || ' (all banks left GENERATED for base-table reconciliation).',
            p_package => C_PKG, p_procedure => C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, C_PROC || ' failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END LOAD_BANKS;

    -- ============================================================
    -- LOAD_BRANCHES
    -- The LOAD step for branches: POST each GENERATED branch whose parent bank
    -- was base-table-confirmed LOADED. Same policy as LOAD_BANKS: never terminal,
    -- non-2xx / exception stashed, row left GENERATED for the branch report to
    -- confirm. A branch whose parent bank is not LOADED is skipped (left
    -- GENERATED, no fabricated error) for the accounting gate to surface.
    -- Writes the TFM table only; no COMMIT (the runner owns the txn).
    -- ============================================================
    PROCEDURE LOAD_BRANCHES (
        p_run_id IN NUMBER
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'LOAD_BRANCHES';
        l_response     CLOB;
        l_http_status  NUMBER;
        l_body         VARCHAR2(32767);
        l_payload      CLOB;
        l_posted       NUMBER := 0;
        l_reject       NUMBER := 0;
        l_skipped      NUMBER := 0;
        l_errmsg       VARCHAR2(4000);
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, C_PROC || ' start.', p_package => C_PKG, p_procedure => C_PROC);

        FOR r IN (
            SELECT br.TFM_SEQUENCE_ID, br.BANK_NAME, br.BRANCH_NAME, br.BRANCH_NUMBER,
                   br.BIC_CODE, br.DESCRIPTION, br.EFT_SWIFT_CODE, br.COUNTRY_CODE,
                   (SELECT MAX(bk.TFM_STATUS) FROM DMT_CE_BANK_TFM_TBL bk
                    WHERE  bk.RUN_ID = p_run_id
                    AND    bk.SOURCE_GROUP_ID = br.SOURCE_GROUP_ID) AS parent_status
            FROM   DMT_CE_BRANCH_TFM_TBL br
            WHERE  br.RUN_ID = p_run_id
            AND    br.TFM_STATUS = 'GENERATED'
            ORDER BY br.SOURCE_GROUP_ID, br.TFM_SEQUENCE_ID
        ) LOOP
            BEGIN
                -- Only POST children under a base-table-confirmed parent bank.
                IF r.parent_status IS NULL OR r.parent_status != 'LOADED' THEN
                    l_skipped := l_skipped + 1;
                    CONTINUE;
                END IF;

                l_payload := '{"BankName":"' || REPLACE(r.BANK_NAME, '"', '\"') || '"'
                    || ',"BankBranchName":"' || REPLACE(r.BRANCH_NAME, '"', '\"') || '"'
                    || CASE WHEN r.BRANCH_NUMBER IS NOT NULL
                       THEN ',"BranchNumber":"' || REPLACE(r.BRANCH_NUMBER, '"', '\"') || '"' END
                    || ',"CountryName":"' || REPLACE(country_name(r.COUNTRY_CODE), '"', '\"') || '"'
                    || CASE WHEN r.BIC_CODE IS NOT NULL
                       THEN ',"EFTSWIFTCode":"' || REPLACE(r.BIC_CODE, '"', '\"') || '"' END
                    || CASE WHEN r.DESCRIPTION IS NOT NULL
                       THEN ',"Description":"' || REPLACE(r.DESCRIPTION, '"', '\"') || '"' END
                    || '}';

                l_response := rest_call('POST', C_BRANCHES_PATH, l_payload, p_run_id);
                l_http_status := get_status(l_response);

                IF l_http_status IN (200, 201) THEN
                    l_posted := l_posted + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Branch POSTed (awaiting base-table confirmation): ' || r.BRANCH_NAME
                        || ' HTTP ' || l_http_status, p_package => C_PKG, p_procedure => C_PROC);
                ELSE
                    l_body := DBMS_LOB.SUBSTR(l_response, 2000, INSTR(l_response, '|') + 1);
                    UPDATE DMT_CE_BRANCH_TFM_TBL
                    SET    ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                          '[FUSION_ERROR] HTTP ' || l_http_status || ': '
                                          || SUBSTR(l_body, 1, 2000)),
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;
                    l_reject := l_reject + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Branch POST rejected (stashed, awaiting base-table verdict): '
                        || r.BRANCH_NAME || ' HTTP ' || l_http_status, 'WARN', p_package => C_PKG, p_procedure => C_PROC);
                END IF;

                IF DBMS_LOB.ISTEMPORARY(l_response) = 1 THEN
                    DBMS_LOB.FREETEMPORARY(l_response);
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    l_errmsg := SQLERRM;
                    UPDATE DMT_CE_BRANCH_TFM_TBL
                    SET    ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                          '[FUSION_ERROR] ' || l_errmsg),
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;
                    l_reject := l_reject + 1;
                    DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                        'Branch POST failed (exception, stashed): ' || r.BRANCH_NAME,
                        l_errmsg, C_PKG, C_PROC);
            END;
        END LOOP;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. POSTed 2xx: ' || l_posted
            || ', POST-rejected(stashed): ' || l_reject
            || ', skipped (parent bank not confirmed): ' || l_skipped
            || ' (all attempted branches left GENERATED for base-table reconciliation).',
            p_package => C_PKG, p_procedure => C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, C_PROC || ' failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END LOAD_BRANCHES;

    -- ============================================================
    -- LOAD_ACCOUNTS
    -- The LOAD step for bank accounts: POST each GENERATED account whose parent
    -- branch was base-table-confirmed LOADED. Same policy: never terminal,
    -- non-2xx / exception stashed, row left GENERATED for the account report to
    -- confirm. An account whose parent branch is not LOADED is skipped (left
    -- GENERATED, no fabricated error).
    -- Writes the TFM table only; no COMMIT (the runner owns the txn).
    -- ============================================================
    PROCEDURE LOAD_ACCOUNTS (
        p_run_id IN NUMBER
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'LOAD_ACCOUNTS';
        l_response     CLOB;
        l_http_status  NUMBER;
        l_body         VARCHAR2(32767);
        l_payload      CLOB;
        l_posted       NUMBER := 0;
        l_reject       NUMBER := 0;
        l_skipped      NUMBER := 0;
        l_errmsg       VARCHAR2(4000);
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, C_PROC || ' start.', p_package => C_PKG, p_procedure => C_PROC);

        FOR r IN (
            SELECT acct.TFM_SEQUENCE_ID, acct.BANK_NAME, acct.BRANCH_NAME,
                   acct.ACCOUNT_NAME, acct.ACCOUNT_NUMBER, acct.CURRENCY_CODE,
                   acct.DESCRIPTION, acct.IBAN, acct.CHECK_DIGITS, acct.ACCOUNT_SUFFIX,
                   (SELECT MAX(br.TFM_STATUS) FROM DMT_CE_BRANCH_TFM_TBL br
                    WHERE  br.RUN_ID = p_run_id
                    AND    br.SOURCE_LINE_ID = acct.SOURCE_LINE_ID) AS parent_status
            FROM   DMT_CE_BANK_ACCT_TFM_TBL acct
            WHERE  acct.RUN_ID = p_run_id
            AND    acct.TFM_STATUS = 'GENERATED'
            ORDER BY acct.SOURCE_LINE_ID, acct.TFM_SEQUENCE_ID
        ) LOOP
            BEGIN
                -- Only POST children under a base-table-confirmed parent branch.
                IF r.parent_status IS NULL OR r.parent_status != 'LOADED' THEN
                    l_skipped := l_skipped + 1;
                    CONTINUE;
                END IF;

                l_payload := '{"BankAccountName":"' || REPLACE(r.ACCOUNT_NAME, '"', '\"') || '"'
                    || CASE WHEN r.ACCOUNT_NUMBER IS NOT NULL
                       THEN ',"BankAccountNumber":"' || REPLACE(r.ACCOUNT_NUMBER, '"', '\"') || '"' END
                    || CASE WHEN r.CURRENCY_CODE IS NOT NULL
                       THEN ',"CurrencyCode":"' || REPLACE(r.CURRENCY_CODE, '"', '\"') || '"' END
                    || CASE WHEN r.DESCRIPTION IS NOT NULL
                       THEN ',"Description":"' || REPLACE(r.DESCRIPTION, '"', '\"') || '"' END
                    || CASE WHEN r.IBAN IS NOT NULL
                       THEN ',"IBANNumber":"' || REPLACE(r.IBAN, '"', '\"') || '"' END
                    || CASE WHEN r.CHECK_DIGITS IS NOT NULL
                       THEN ',"CheckDigits":"' || REPLACE(r.CHECK_DIGITS, '"', '\"') || '"' END
                    || CASE WHEN r.ACCOUNT_SUFFIX IS NOT NULL
                       THEN ',"AccountSuffix":"' || REPLACE(r.ACCOUNT_SUFFIX, '"', '\"') || '"' END
                    || '}';

                l_response := rest_call('POST', C_ACCOUNTS_PATH, l_payload, p_run_id);
                l_http_status := get_status(l_response);

                IF l_http_status IN (200, 201) THEN
                    l_posted := l_posted + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Account POSTed (awaiting base-table confirmation): ' || r.ACCOUNT_NAME
                        || ' HTTP ' || l_http_status, p_package => C_PKG, p_procedure => C_PROC);
                ELSE
                    l_body := DBMS_LOB.SUBSTR(l_response, 2000, INSTR(l_response, '|') + 1);
                    UPDATE DMT_CE_BANK_ACCT_TFM_TBL
                    SET    ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                          '[FUSION_ERROR] HTTP ' || l_http_status || ': '
                                          || SUBSTR(l_body, 1, 2000)),
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;
                    l_reject := l_reject + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Account POST rejected (stashed, awaiting base-table verdict): '
                        || r.ACCOUNT_NAME || ' HTTP ' || l_http_status, 'WARN', p_package => C_PKG, p_procedure => C_PROC);
                END IF;

                IF DBMS_LOB.ISTEMPORARY(l_response) = 1 THEN
                    DBMS_LOB.FREETEMPORARY(l_response);
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    l_errmsg := SQLERRM;
                    UPDATE DMT_CE_BANK_ACCT_TFM_TBL
                    SET    ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                          '[FUSION_ERROR] ' || l_errmsg),
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;
                    l_reject := l_reject + 1;
                    DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                        'Account POST failed (exception, stashed): ' || r.ACCOUNT_NAME,
                        l_errmsg, C_PKG, C_PROC);
            END;
        END LOOP;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. POSTed 2xx: ' || l_posted
            || ', POST-rejected(stashed): ' || l_reject
            || ', skipped (parent branch not confirmed): ' || l_skipped
            || ' (all attempted accounts left GENERATED for base-table reconciliation).',
            p_package => C_PKG, p_procedure => C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, C_PROC || ' failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END LOAD_ACCOUNTS;

    -- --------------------------------------------------------
    -- FETCH_BIP_RESULTS
    -- Runs the base-table reconciliation report for this run. Delegates to the
    -- shared DMT_UTIL_PKG.RUN_BIP_REPORT (no private SOAP copy). Three parameters,
    -- one per tier: P_BANK_NAMES confirms banks over CE_BANKS_V (G_1),
    -- P_BRANCH_NAMES confirms branches over CE_BANK_BRANCHES_V (G_2), and
    -- P_ACCT_NAMES confirms accounts over CE_BANK_ACCOUNTS (G_3). Any may be blank
    -- on a pass that does not need it. Natural keys are not run-prefixed.
    -- PROCEDURE per the procedures-only contract: x_report_xml NULL with
    -- x_error_code = C_SUCCESS means zero rows; failures are logged and surfaced
    -- through x_error_code -- exceptions never escape.
    -- --------------------------------------------------------
    PROCEDURE FETCH_BIP_RESULTS (
        p_run_id       IN  NUMBER,
        p_bank_names   IN  VARCHAR2,
        p_branch_names IN  VARCHAR2,
        p_acct_names   IN  VARCHAR2,
        x_report_xml   OUT XMLTYPE,
        x_error_code   OUT NUMBER
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'FETCH_BIP_RESULTS';
        l_step VARCHAR2(500);
    BEGIN
        x_report_xml := NULL;
        x_error_code := DMT_UTIL_PKG.C_ERROR;   -- pessimistic until proven

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' start. CEMLI: ' || C_CEMLI
            || ' | P_BANK_NAMES: ' || NVL(p_bank_names, '(none)')
            || ' | P_BRANCH_NAMES: ' || NVL(p_branch_names, '(none)')
            || ' | P_ACCT_NAMES: ' || NVL(p_acct_names, '(none)'),
            p_package => C_PKG, p_procedure => C_PROC);

        IF p_bank_names IS NULL AND p_branch_names IS NULL AND p_acct_names IS NULL THEN
            x_error_code := DMT_UTIL_PKG.C_SUCCESS;   -- nothing to confirm
            RETURN;
        END IF;

        l_step := 'running base-table reconciliation report for ' || C_CEMLI;
        DMT_UTIL_PKG.RUN_BIP_REPORT(
            p_run_id     => p_run_id,
            p_cemli_code => C_CEMLI,
            p_params     => 'P_BANK_NAMES|'   || p_bank_names
                            || '~P_BRANCH_NAMES|' || p_branch_names
                            || '~P_ACCT_NAMES|'   || p_acct_names,
            x_report_xml => x_report_xml,
            x_error_code => x_error_code);

        IF x_error_code != DMT_UTIL_PKG.C_SUCCESS THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ' failed while ' || l_step
                || ' (detail logged by RUN_BIP_REPORT).', 'ERROR', p_package => C_PKG, p_procedure => C_PROC);
            RETURN;
        END IF;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. CEMLI: ' || C_CEMLI ||
            CASE WHEN x_report_xml IS NULL
                 THEN ' | Report returned zero rows.'
                 ELSE ' | Report data received.'
            END, p_package => C_PKG, p_procedure => C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            x_report_xml := NULL;
            x_error_code := DMT_UTIL_PKG.C_ERROR;
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed while ' || l_step || ' | CEMLI: ' || C_CEMLI,
                SQLERRM, C_PKG, C_PROC);
    END FETCH_BIP_RESULTS;

    -- --------------------------------------------------------
    -- PARSE_BANKS
    -- Positive base-table confirmation for banks only (G_1). Each report row is a
    -- bank found in CE_BANKS_V -> mark the matching bank LOADED with
    -- FUSION_BANK_PARTY_ID = the returned BANK_PARTY_ID. Match on the run's
    -- BANK_NAME (report RECORD_KEY). Banks not returned are left as the load step
    -- set them (stashed error, else GENERATED/unaccounted) -- never fabricated.
    -- Writes the TFM table only; no COMMIT (the runner owns the txn).
    -- --------------------------------------------------------
    PROCEDURE PARSE_BANKS (
        p_run_id     IN NUMBER,
        p_report_xml IN XMLTYPE
    ) IS
        C_PROC   CONSTANT VARCHAR2(30) := 'PARSE_BANKS';
        l_loaded NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, C_PROC || ' start.', p_package => C_PKG, p_procedure => C_PROC);

        IF p_report_xml IS NULL THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': report returned zero base-table rows. '
                || 'No fabricated LOADED; banks left as the load step set them.',
                C_PKG, C_PROC, 'WARN');
            RETURN;
        END IF;

        FOR r IN (
            SELECT x.record_key,
                   UPPER(x.source_type) AS source_type,
                   x.fusion_id
            FROM   XMLTABLE('/DATA_DS/G_1' PASSING p_report_xml
                COLUMNS
                    record_key  VARCHAR2(360) PATH 'RECORD_KEY',
                    source_type VARCHAR2(20)  PATH 'SOURCE_TYPE',
                    fusion_id   NUMBER        PATH 'FUSION_ID'
            ) x
        ) LOOP
            IF r.source_type = 'BASE_BANK' AND r.fusion_id IS NOT NULL THEN
                UPDATE DMT_CE_BANK_TFM_TBL
                SET    TFM_STATUS           = 'LOADED',
                       FUSION_BANK_PARTY_ID = r.fusion_id,
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID     = p_run_id
                AND    BANK_NAME  = r.record_key
                AND    TFM_STATUS NOT IN ('LOADED','FAILED');
                l_loaded := l_loaded + SQL%ROWCOUNT;
            END IF;
        END LOOP;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. Banks base-table confirmed LOADED: ' || l_loaded || '.',
            p_package => C_PKG, p_procedure => C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, C_PROC || ' failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END PARSE_BANKS;

    -- --------------------------------------------------------
    -- PARSE_BRANCHES
    -- Positive base-table confirmation for branches only (G_2). Each report row is
    -- a branch found in CE_BANK_BRANCHES_V -> mark the matching branch LOADED with
    -- FUSION_BRANCH_PARTY_ID = the returned BRANCH_PARTY_ID. Match on the run's
    -- (BRANCH_NAME, parent BANK_NAME) -- the report carries PARENT_BANK_NAME so a
    -- branch name reused across banks is never mis-attributed. Branches not
    -- returned are left as the load step set them -- never fabricated.
    -- Writes the TFM table only; no COMMIT (the runner owns the txn).
    -- --------------------------------------------------------
    PROCEDURE PARSE_BRANCHES (
        p_run_id     IN NUMBER,
        p_report_xml IN XMLTYPE
    ) IS
        C_PROC   CONSTANT VARCHAR2(30) := 'PARSE_BRANCHES';
        l_loaded NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, C_PROC || ' start.', p_package => C_PKG, p_procedure => C_PROC);

        IF p_report_xml IS NULL THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': report returned zero base-table rows. '
                || 'No fabricated LOADED; branches left as the load step set them.',
                C_PKG, C_PROC, 'WARN');
            RETURN;
        END IF;

        FOR r IN (
            SELECT x.record_key,
                   UPPER(x.source_type) AS source_type,
                   x.fusion_id,
                   x.parent_bank_name
            FROM   XMLTABLE('/DATA_DS/G_2' PASSING p_report_xml
                COLUMNS
                    record_key       VARCHAR2(360) PATH 'RECORD_KEY',
                    source_type      VARCHAR2(20)  PATH 'SOURCE_TYPE',
                    fusion_id        NUMBER        PATH 'FUSION_ID',
                    parent_bank_name VARCHAR2(360) PATH 'PARENT_BANK_NAME'
            ) x
        ) LOOP
            IF r.source_type = 'BASE_BRANCH' AND r.fusion_id IS NOT NULL THEN
                UPDATE DMT_CE_BRANCH_TFM_TBL
                SET    TFM_STATUS             = 'LOADED',
                       FUSION_BRANCH_PARTY_ID = r.fusion_id,
                       RESULTS_UPDATED_DATE   = SYSDATE,
                       LAST_UPDATED_DATE      = SYSDATE
                WHERE  RUN_ID      = p_run_id
                AND    BRANCH_NAME = r.record_key
                AND    BANK_NAME   = r.parent_bank_name
                AND    TFM_STATUS NOT IN ('LOADED','FAILED');
                l_loaded := l_loaded + SQL%ROWCOUNT;
            END IF;
        END LOOP;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. Branches base-table confirmed LOADED: ' || l_loaded || '.',
            p_package => C_PKG, p_procedure => C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, C_PROC || ' failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END PARSE_BRANCHES;

    -- --------------------------------------------------------
    -- PARSE_ACCOUNTS
    -- Positive base-table confirmation for accounts only (G_3). Each report row is
    -- an account found in CE_BANK_ACCOUNTS -> mark the matching account LOADED with
    -- FUSION_BANK_ACCOUNT_ID = the returned BANK_ACCOUNT_ID. Match on the run's
    -- ACCOUNT_NAME (report RECORD_KEY). Accounts not returned are left as the load
    -- step set them -- never fabricated.
    -- Writes the TFM table only; no COMMIT (the runner owns the txn).
    -- --------------------------------------------------------
    PROCEDURE PARSE_ACCOUNTS (
        p_run_id     IN NUMBER,
        p_report_xml IN XMLTYPE
    ) IS
        C_PROC   CONSTANT VARCHAR2(30) := 'PARSE_ACCOUNTS';
        l_loaded NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, C_PROC || ' start.', p_package => C_PKG, p_procedure => C_PROC);

        IF p_report_xml IS NULL THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': report returned zero base-table rows. '
                || 'No fabricated LOADED; accounts left as the load step set them.',
                C_PKG, C_PROC, 'WARN');
            RETURN;
        END IF;

        FOR r IN (
            SELECT x.record_key,
                   UPPER(x.source_type) AS source_type,
                   x.fusion_id
            FROM   XMLTABLE('/DATA_DS/G_3' PASSING p_report_xml
                COLUMNS
                    record_key  VARCHAR2(360) PATH 'RECORD_KEY',
                    source_type VARCHAR2(20)  PATH 'SOURCE_TYPE',
                    fusion_id   NUMBER        PATH 'FUSION_ID'
            ) x
        ) LOOP
            IF r.source_type = 'BASE_ACCOUNT' AND r.fusion_id IS NOT NULL THEN
                UPDATE DMT_CE_BANK_ACCT_TFM_TBL
                SET    TFM_STATUS             = 'LOADED',
                       FUSION_BANK_ACCOUNT_ID = r.fusion_id,
                       RESULTS_UPDATED_DATE   = SYSDATE,
                       LAST_UPDATED_DATE      = SYSDATE
                WHERE  RUN_ID       = p_run_id
                AND    ACCOUNT_NAME = r.record_key
                AND    TFM_STATUS NOT IN ('LOADED','FAILED');
                l_loaded := l_loaded + SQL%ROWCOUNT;
            END IF;
        END LOOP;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. Accounts base-table confirmed LOADED: ' || l_loaded || '.',
            p_package => C_PKG, p_procedure => C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, C_PROC || ' failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END PARSE_ACCOUNTS;

    -- --------------------------------------------------------
    -- Private: build a comma-delimited list of the still-GENERATED natural keys
    -- for one tier, so the base-table report is asked only about rows we still
    -- need to confirm. Static SQL per tier (no dynamic SQL).
    -- --------------------------------------------------------
    FUNCTION bank_names(p_run_id IN NUMBER) RETURN VARCHAR2 IS
        l_list VARCHAR2(4000);
    BEGIN
        SELECT LISTAGG(BANK_NAME, ',') WITHIN GROUP (ORDER BY BANK_NAME)
        INTO   l_list
        FROM   DMT_CE_BANK_TFM_TBL
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
        RETURN l_list;
    END bank_names;

    FUNCTION branch_names(p_run_id IN NUMBER) RETURN VARCHAR2 IS
        l_list VARCHAR2(4000);
    BEGIN
        SELECT LISTAGG(BRANCH_NAME, ',') WITHIN GROUP (ORDER BY BRANCH_NAME)
        INTO   l_list
        FROM   DMT_CE_BRANCH_TFM_TBL
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
        RETURN l_list;
    END branch_names;

    FUNCTION acct_names(p_run_id IN NUMBER) RETURN VARCHAR2 IS
        l_list VARCHAR2(4000);
    BEGIN
        SELECT LISTAGG(ACCOUNT_NAME, ',') WITHIN GROUP (ORDER BY ACCOUNT_NAME)
        INTO   l_list
        FROM   DMT_CE_BANK_ACCT_TFM_TBL
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
        RETURN l_list;
    END acct_names;

    -- --------------------------------------------------------
    -- Private: mirror a tier's terminal TFM outcome onto its STG row.
    -- --------------------------------------------------------
    PROCEDURE mirror_bank_stg(p_run_id IN NUMBER) IS
    BEGIN
        UPDATE DMT_CE_BANK_STG_TBL s
        SET    s.STG_STATUS = (SELECT t.TFM_STATUS FROM DMT_CE_BANK_TFM_TBL t
                               WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id),
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  EXISTS (SELECT 1 FROM DMT_CE_BANK_TFM_TBL t
                       WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id
                       AND   t.TFM_STATUS IN ('LOADED','FAILED'));
    END mirror_bank_stg;

    PROCEDURE mirror_branch_stg(p_run_id IN NUMBER) IS
    BEGIN
        UPDATE DMT_CE_BRANCH_STG_TBL s
        SET    s.STG_STATUS = (SELECT t.TFM_STATUS FROM DMT_CE_BRANCH_TFM_TBL t
                               WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id),
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  EXISTS (SELECT 1 FROM DMT_CE_BRANCH_TFM_TBL t
                       WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id
                       AND   t.TFM_STATUS IN ('LOADED','FAILED'));
    END mirror_branch_stg;

    PROCEDURE mirror_acct_stg(p_run_id IN NUMBER) IS
    BEGIN
        UPDATE DMT_CE_BANK_ACCT_STG_TBL s
        SET    s.STG_STATUS = (SELECT t.TFM_STATUS FROM DMT_CE_BANK_ACCT_TFM_TBL t
                               WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id),
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  EXISTS (SELECT 1 FROM DMT_CE_BANK_ACCT_TFM_TBL t
                       WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id
                       AND   t.TFM_STATUS IN ('LOADED','FAILED'));
    END mirror_acct_stg;

    -- ============================================================
    -- LOAD_AND_RECONCILE
    -- Main entry point. For each of the three tiers in hierarchy order:
    --   1. LOAD  -- POST the tier's GENERATED rows (children only under a
    --              base-table-confirmed parent). Never terminal; non-2xx stashed.
    --   2. RECONCILE -- run the base-table report over that tier's natural keys
    --              and mark confirmed rows LOADED with the real surrogate id.
    -- After all three tiers, a single post-reconcile sweep marks any row still
    -- GENERATED that carries a stashed real error FAILED; rows with no stashed
    -- error and no base-table hit are left GENERATED (the accounting gate surfaces
    -- them as UNACCOUNTED) -- never a fabricated verdict. STG mirrors the terminal
    -- TFM outcome. The reconcile transport failing raises loudly so the queue work
    -- item fails, never a silent zero-row "success".
    -- ============================================================
    PROCEDURE LOAD_AND_RECONCILE (
        p_run_id IN NUMBER
    ) IS
        C_PROC     CONSTANT VARCHAR2(30) := 'LOAD_AND_RECONCILE';
        l_xml      XMLTYPE;
        l_err      NUMBER;
        l_loaded   NUMBER;
        l_failed   NUMBER;
        l_unaccnt  NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, C_PROC || ' start.', p_package => C_PKG, p_procedure => C_PROC);

        -- ===== Tier 1: BANKS =====
        LOAD_BANKS(p_run_id);
        FETCH_BIP_RESULTS(p_run_id, bank_names(p_run_id), NULL, NULL, l_xml, l_err);
        IF l_err != DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20039,
                'LOAD_AND_RECONCILE: bank base-table reconciliation report failed for CEMLI '
                || C_CEMLI || ' (detail in DMT_LOG_TBL).');
        END IF;
        PARSE_BANKS(p_run_id, l_xml);

        -- ===== Tier 2: BRANCHES (under confirmed banks) =====
        LOAD_BRANCHES(p_run_id);
        FETCH_BIP_RESULTS(p_run_id, NULL, branch_names(p_run_id), NULL, l_xml, l_err);
        IF l_err != DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20039,
                'LOAD_AND_RECONCILE: branch base-table reconciliation report failed for CEMLI '
                || C_CEMLI || ' (detail in DMT_LOG_TBL).');
        END IF;
        PARSE_BRANCHES(p_run_id, l_xml);

        -- ===== Tier 3: ACCOUNTS (under confirmed branches) =====
        LOAD_ACCOUNTS(p_run_id);
        FETCH_BIP_RESULTS(p_run_id, NULL, NULL, acct_names(p_run_id), l_xml, l_err);
        IF l_err != DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20039,
                'LOAD_AND_RECONCILE: account base-table reconciliation report failed for CEMLI '
                || C_CEMLI || ' (detail in DMT_LOG_TBL).');
        END IF;
        PARSE_ACCOUNTS(p_run_id, l_xml);

        -- ===== Post-reconcile sweep: stashed real error -> FAILED =====
        -- Any row NOT confirmed in its base table is still GENERATED. If its POST
        -- returned a real Fusion error (stashed in ERROR_TEXT) mark it FAILED on
        -- that real error. A row with no stashed error AND no base-table hit is
        -- left GENERATED (unaccounted); the accounting gate surfaces it.
        UPDATE DMT_CE_BANK_TFM_TBL
        SET    TFM_STATUS = 'FAILED', RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED' AND ERROR_TEXT IS NOT NULL;

        UPDATE DMT_CE_BRANCH_TFM_TBL
        SET    TFM_STATUS = 'FAILED', RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED' AND ERROR_TEXT IS NOT NULL;

        UPDATE DMT_CE_BANK_ACCT_TFM_TBL
        SET    TFM_STATUS = 'FAILED', RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED' AND ERROR_TEXT IS NOT NULL;

        -- Mirror terminal outcomes onto STG for all three tiers.
        mirror_bank_stg(p_run_id);
        mirror_branch_stg(p_run_id);
        mirror_acct_stg(p_run_id);

        COMMIT;

        SELECT COUNT(CASE WHEN TFM_STATUS = 'LOADED' THEN 1 END),
               COUNT(CASE WHEN TFM_STATUS = 'FAILED' THEN 1 END),
               COUNT(CASE WHEN TFM_STATUS NOT IN ('LOADED','FAILED') THEN 1 END)
        INTO   l_loaded, l_failed, l_unaccnt
        FROM   (SELECT TFM_STATUS FROM DMT_CE_BANK_TFM_TBL      WHERE RUN_ID = p_run_id
                UNION ALL
                SELECT TFM_STATUS FROM DMT_CE_BRANCH_TFM_TBL    WHERE RUN_ID = p_run_id
                UNION ALL
                SELECT TFM_STATUS FROM DMT_CE_BANK_ACCT_TFM_TBL WHERE RUN_ID = p_run_id);

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. LOADED: ' || l_loaded
            || ', FAILED: ' || l_failed
            || ', UNACCOUNTED: ' || l_unaccnt || '.', p_package => C_PKG, p_procedure => C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, C_PROC || ' failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END LOAD_AND_RECONCILE;

END DMT_CE_BANK_RESULTS_PKG;
/
