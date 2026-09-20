-- PACKAGE BODY DMT_ZX_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_ZX_RESULTS_PKG" AS
-- ============================================================
-- DMT_ZX_RESULTS_PKG body
-- Taxes (two tiers: tax regimes + tax rates): REST load + BIP base-table
-- reconciliation.
--
-- New reconciliation standard (DMT_DESIGN.html, PROPOSED 2026-09):
-- reconciliation MUST be a BIP report over the Fusion BASE tables that returns
-- the base-table surrogate id. A REST load-call HTTP 200 is NOT reconciliation.
-- So the two responsibilities are separated, exactly as PaymentTerms does:
--
--   LOAD  (LOAD_REGIMES / LOAD_RATES): POST each GENERATED regime to the
--         taxRegimes REST resource and each GENERATED rate to taxRates. A
--         non-2xx response or an exception is a genuine load-time rejection ->
--         its real message is STASHED into ERROR_TEXT (accumulate, never
--         overwrite). The POST response is NOT treated as LOADED; the row is
--         left GENERATED, pending positive base-table confirmation.
--
--   RECONCILE (FETCH_BIP_RESULTS + PARSE_REGIMES / PARSE_RATES): run the
--         base-table report DMT_ZX_RECON_RPT over this run's codes. A regime
--         code found in ZX_REGIMES_B is positive proof -> regime LOADED with
--         FUSION_TAX_REGIME_ID = TAX_REGIME_ID (the real surrogate id). A rate
--         code found in ZX_RATES_B is positive proof -> rate LOADED with
--         FUSION_TAX_RATE_ID = TAX_RATE_ID. A code not returned by the report
--         was not created: it becomes FAILED if the REST load already rejected
--         it (stashed error), otherwise it is left GENERATED (unaccounted) --
--         never a fabricated LOADED or id.
--
-- Transport is a local rest_call helper (the "STATUS|body" convention). The
-- base-table report goes through the shared DMT_UTIL_PKG.RUN_BIP_REPORT (no
-- private SOAP copy). Base tables + surrogate ids:
--   regimes -> ZX_REGIMES_B (TAX_REGIME_ID), natural key TAX_REGIME_CODE.
--   rates   -> ZX_RATES_B   (TAX_RATE_ID),   natural key TAX_RATE_CODE.
-- Backlog #11 / new recon standard.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_ZX_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'TaxConfig';

    -- Fusion REST base paths
    C_REGIMES_PATH CONSTANT VARCHAR2(200) := '/fscmRestApi/resources/11.13.18.05/taxRegimes';
    C_RATES_PATH   CONSTANT VARCHAR2(200) := '/fscmRestApi/resources/11.13.18.05/taxRates';

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
        l_raw_body     BLOB;
        l_raw_chunk    RAW(32767);
        l_base_url     VARCHAR2(500);
        l_username     VARCHAR2(100);
        l_password     VARCHAR2(100);
        l_status       NUMBER;
    BEGIN
        l_base_url := RTRIM(DMT_UTIL_PKG.GET_CONFIG('FUSION_URL'), '/');
        l_username := DMT_UTIL_PKG.GET_CONFIG('FUSION_USERNAME');
        l_password := DMT_UTIL_PKG.GET_CONFIG('FUSION_PASSWORD');
        l_url      := l_base_url || p_path;

        -- Attach a wallet only when a real one is configured; otherwise use the DB
        -- default certificate store. An unset/placeholder WALLET_DIR must not be
        -- forced into an invalid 'file:...' path -- that throws ORA-29273 before
        -- any auth.
        IF INSTR(NVL(DMT_UTIL_PKG.GET_CONFIG('WALLET_DIR'),' '),'/') > 0 THEN
            UTL_HTTP.SET_WALLET('file:' || DMT_UTIL_PKG.GET_CONFIG('WALLET_DIR'),
                                DMT_UTIL_PKG.GET_CONFIG('WALLET_PASSWORD'));
        END IF;

        l_http_req := UTL_HTTP.BEGIN_REQUEST(l_url, p_method, 'HTTP/1.1');
        UTL_HTTP.SET_HEADER(l_http_req, 'Authorization',
            'Basic ' || UTL_RAW.CAST_TO_VARCHAR2(UTL_ENCODE.BASE64_ENCODE(
                UTL_RAW.CAST_TO_RAW(l_username || ':' || l_password))));
        UTL_HTTP.SET_HEADER(l_http_req, 'Accept', 'application/json');
        -- Ask Fusion NOT to gzip the response so error bodies land in ERROR_TEXT
        -- as human-readable text, not unreadable binary.
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

        -- Read the body as RAW bytes (not text) so a gzip-compressed error body
        -- survives intact. Fusion sometimes gzips error bodies even though we
        -- ask for identity encoding; DMT_UTIL_PKG.GUNZIP_RESPONSE detects the
        -- gzip magic number and inflates, otherwise returns the bytes as text.
        DBMS_LOB.CREATETEMPORARY(l_raw_body, TRUE);
        BEGIN
            LOOP
                UTL_HTTP.READ_RAW(l_http_resp, l_raw_chunk, 32767);
                DBMS_LOB.WRITEAPPEND(l_raw_body, UTL_RAW.LENGTH(l_raw_chunk), l_raw_chunk);
            END LOOP;
        EXCEPTION
            WHEN UTL_HTTP.END_OF_BODY THEN NULL;
        END;
        UTL_HTTP.END_RESPONSE(l_http_resp);

        l_response := DMT_UTIL_PKG.GUNZIP_RESPONSE(l_raw_body);
        IF DBMS_LOB.ISTEMPORARY(l_raw_body) = 1 THEN
            DBMS_LOB.FREETEMPORARY(l_raw_body);
        END IF;

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

    -- ============================================================
    -- LOAD_REGIMES
    -- The LOAD step for tier 1. POST each GENERATED regime to Fusion. The BIP
    -- base-table report -- not the POST response -- is the authority for LOADED,
    -- so this step NEVER marks a regime terminal. It leaves every attempted
    -- regime GENERATED. A non-2xx / exception is a real Fusion rejection: its
    -- message is STASHED into ERROR_TEXT (accumulate, never overwrite) so a later
    -- absent-from-base-table regime can be marked FAILED on that real error.
    -- Writes the TFM table only; no COMMIT (the runner owns the txn).
    -- ============================================================
    PROCEDURE LOAD_REGIMES (
        p_run_id IN NUMBER
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'LOAD_REGIMES';
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
            SELECT TFM_SEQUENCE_ID, TAX_REGIME_CODE, TAX_REGIME_NAME, DESCRIPTION,
                   EFFECTIVE_FROM, EFFECTIVE_TO, COUNTRY_CODE, REGIME_TYPE_FLAG,
                   HAS_SUB_REGIME_FLAG, PARENT_REGIME_CODE
            FROM   DMT_ZX_REGIME_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS = 'GENERATED'
            ORDER BY TFM_SEQUENCE_ID
        ) LOOP
            BEGIN
                l_payload := '{"TaxRegimeCode":"' || REPLACE(r.TAX_REGIME_CODE, '"', '\"') || '"'
                    || ',"TaxRegimeName":"' || REPLACE(NVL(r.TAX_REGIME_NAME, r.TAX_REGIME_CODE), '"', '\"') || '"'
                    || CASE WHEN r.DESCRIPTION IS NOT NULL
                       THEN ',"Description":"' || REPLACE(r.DESCRIPTION, '"', '\"') || '"' END
                    || ',"CountryCode":"' || NVL(r.COUNTRY_CODE, 'US') || '"'
                    || ',"EffectiveFrom":"' || TO_CHAR(NVL(r.EFFECTIVE_FROM, DATE '2020-01-01'), 'YYYY-MM-DD') || '"'
                    || CASE WHEN r.EFFECTIVE_TO IS NOT NULL
                       THEN ',"EffectiveTo":"' || TO_CHAR(r.EFFECTIVE_TO, 'YYYY-MM-DD') || '"' END
                    || CASE WHEN r.REGIME_TYPE_FLAG IS NOT NULL
                       THEN ',"RegimeTypeFlag":"' || r.REGIME_TYPE_FLAG || '"' END
                    || CASE WHEN r.HAS_SUB_REGIME_FLAG IS NOT NULL
                       THEN ',"HasSubRegimeFlag":"' || r.HAS_SUB_REGIME_FLAG || '"' END
                    || CASE WHEN r.PARENT_REGIME_CODE IS NOT NULL
                       THEN ',"ParentRegimeCode":"' || REPLACE(r.PARENT_REGIME_CODE, '"', '\"') || '"' END
                    || '}';

                l_response := rest_call('POST', C_REGIMES_PATH, l_payload, p_run_id);
                l_http_status := get_status(l_response);

                IF l_http_status IN (200, 201) THEN
                    l_posted := l_posted + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Regime POSTed (awaiting base-table confirmation): ' || r.TAX_REGIME_CODE
                        || ' HTTP ' || l_http_status,
                        p_package => C_PKG, p_procedure => C_PROC);
                ELSE
                    l_body := DBMS_LOB.SUBSTR(l_response, 2000, INSTR(l_response, '|') + 1);
                    UPDATE DMT_ZX_REGIME_TFM_TBL
                    SET    ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                          '[FUSION_ERROR] HTTP ' || l_http_status || ': '
                                          || SUBSTR(l_body, 1, 2000)),
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;
                    l_reject := l_reject + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Regime POST rejected (stashed, awaiting base-table verdict): '
                        || r.TAX_REGIME_CODE || ' HTTP ' || l_http_status,
                        p_package => C_PKG, p_procedure => C_PROC, p_log_type => 'WARN');
                END IF;

                IF DBMS_LOB.ISTEMPORARY(l_response) = 1 THEN
                    DBMS_LOB.FREETEMPORARY(l_response);
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    l_errmsg := SQLERRM;
                    UPDATE DMT_ZX_REGIME_TFM_TBL
                    SET    ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                          '[FUSION_ERROR] ' || l_errmsg),
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;
                    l_reject := l_reject + 1;
                    DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                        'Regime POST failed (exception, stashed): ' || r.TAX_REGIME_CODE,
                        l_errmsg, p_package => C_PKG, p_procedure => C_PROC);
            END;
        END LOOP;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. POSTed 2xx: ' || l_posted
            || ', POST-rejected(stashed): ' || l_reject
            || ' (all regimes left GENERATED for base-table reconciliation).',
            p_package => C_PKG, p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed.', SQLERRM, p_package => C_PKG, p_procedure => C_PROC);
            RAISE;
    END LOAD_REGIMES;

    -- ============================================================
    -- LOAD_RATES
    -- The LOAD step for tier 2. POST each GENERATED rate to Fusion. taxRates is a
    -- top-level REST resource that carries TaxRegimeCode in the body, so a rate is
    -- attempted only when its parent regime is present in Fusion -- proven by the
    -- parent regime TFM row being LOADED (base-table-confirmed) in THIS run. Like
    -- LOAD_REGIMES this NEVER marks a rate terminal: the base-table report over
    -- ZX_RATES_B is the authority for LOADED. A non-2xx / exception is stashed
    -- into ERROR_TEXT (accumulate, never overwrite); the rate stays GENERATED.
    -- A rate whose parent regime was NOT confirmed is skipped (left GENERATED,
    -- no fabricated error) for the honest accounting gate to surface.
    -- Writes the TFM table only; no COMMIT (the runner owns the txn).
    -- ============================================================
    PROCEDURE LOAD_RATES (
        p_run_id IN NUMBER
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'LOAD_RATES';
        l_response     CLOB;
        l_http_status  NUMBER;
        l_body         VARCHAR2(32767);
        l_payload      CLOB;
        l_posted       NUMBER := 0;
        l_reject       NUMBER := 0;
        l_skipped      NUMBER := 0;
        l_errmsg       VARCHAR2(4000);
        l_parent_ok    NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, C_PROC || ' start.', p_package => C_PKG, p_procedure => C_PROC);

        FOR r IN (
            SELECT v.TFM_SEQUENCE_ID, v.TAX_REGIME_CODE, v.TAX, v.TAX_STATUS_CODE,
                   v.TAX_RATE_CODE, v.TAX_RATE_NAME, v.RATE_TYPE_CODE,
                   v.PERCENTAGE_RATE, v.EFFECTIVE_FROM, v.EFFECTIVE_TO,
                   v.ACTIVE_FLAG, v.DESCRIPTION, v.DEFAULT_RATE_FLAG
            FROM   DMT_ZX_RATE_TFM_TBL v
            WHERE  v.RUN_ID = p_run_id
            AND    v.TFM_STATUS = 'GENERATED'
            ORDER BY v.TAX_REGIME_CODE, v.TFM_SEQUENCE_ID
        ) LOOP
            BEGIN
                -- Only attempt a rate whose parent regime is base-table-confirmed
                -- (LOADED) in this run. Otherwise skip -- leave GENERATED, no
                -- fabricated error.
                SELECT COUNT(*) INTO l_parent_ok
                FROM   DMT_ZX_REGIME_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id
                AND    t.TAX_REGIME_CODE = r.TAX_REGIME_CODE
                AND    t.TFM_STATUS = 'LOADED';

                IF l_parent_ok = 0 THEN
                    l_skipped := l_skipped + 1;
                    CONTINUE;
                END IF;

                l_payload := '{"TaxRateCode":"' || REPLACE(r.TAX_RATE_CODE, '"', '\"') || '"'
                    || ',"TaxRateName":"' || REPLACE(NVL(r.TAX_RATE_NAME, r.TAX_RATE_CODE), '"', '\"') || '"'
                    || ',"TaxRegimeCode":"' || REPLACE(r.TAX_REGIME_CODE, '"', '\"') || '"'
                    || CASE WHEN r.TAX IS NOT NULL
                       THEN ',"Tax":"' || REPLACE(r.TAX, '"', '\"') || '"' END
                    || CASE WHEN r.TAX_STATUS_CODE IS NOT NULL
                       THEN ',"TaxStatusCode":"' || REPLACE(r.TAX_STATUS_CODE, '"', '\"') || '"' END
                    || CASE WHEN r.RATE_TYPE_CODE IS NOT NULL
                       THEN ',"RateTypeCode":"' || REPLACE(r.RATE_TYPE_CODE, '"', '\"') || '"' END
                    || CASE WHEN r.PERCENTAGE_RATE IS NOT NULL
                       THEN ',"PercentageRate":' || TO_CHAR(r.PERCENTAGE_RATE) END
                    || ',"EffectiveFrom":"' || TO_CHAR(NVL(r.EFFECTIVE_FROM, DATE '2020-01-01'), 'YYYY-MM-DD') || '"'
                    || CASE WHEN r.EFFECTIVE_TO IS NOT NULL
                       THEN ',"EffectiveTo":"' || TO_CHAR(r.EFFECTIVE_TO, 'YYYY-MM-DD') || '"' END
                    || ',"ActiveFlag":"' || NVL(r.ACTIVE_FLAG, 'Y') || '"'
                    || CASE WHEN r.DESCRIPTION IS NOT NULL
                       THEN ',"Description":"' || REPLACE(r.DESCRIPTION, '"', '\"') || '"' END
                    || CASE WHEN r.DEFAULT_RATE_FLAG IS NOT NULL
                       THEN ',"DefaultRateFlag":"' || r.DEFAULT_RATE_FLAG || '"' END
                    || '}';

                l_response := rest_call('POST', C_RATES_PATH, l_payload, p_run_id);
                l_http_status := get_status(l_response);

                IF l_http_status IN (200, 201) THEN
                    l_posted := l_posted + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Rate POSTed (awaiting base-table confirmation): '
                        || r.TAX_REGIME_CODE || '.' || r.TAX_RATE_CODE || ' HTTP ' || l_http_status,
                        p_package => C_PKG, p_procedure => C_PROC);
                ELSE
                    l_body := DBMS_LOB.SUBSTR(l_response, 2000, INSTR(l_response, '|') + 1);
                    UPDATE DMT_ZX_RATE_TFM_TBL
                    SET    ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                          '[FUSION_ERROR] HTTP ' || l_http_status || ': '
                                          || SUBSTR(l_body, 1, 2000)),
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;
                    l_reject := l_reject + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Rate POST rejected (stashed, awaiting base-table verdict): '
                        || r.TAX_REGIME_CODE || '.' || r.TAX_RATE_CODE || ' HTTP ' || l_http_status,
                        p_package => C_PKG, p_procedure => C_PROC, p_log_type => 'WARN');
                END IF;

                IF DBMS_LOB.ISTEMPORARY(l_response) = 1 THEN
                    DBMS_LOB.FREETEMPORARY(l_response);
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    l_errmsg := SQLERRM;
                    UPDATE DMT_ZX_RATE_TFM_TBL
                    SET    ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                          '[FUSION_ERROR] ' || l_errmsg),
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;
                    l_reject := l_reject + 1;
                    DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                        'Rate POST failed (exception, stashed): '
                        || r.TAX_REGIME_CODE || '.' || r.TAX_RATE_CODE,
                        l_errmsg, p_package => C_PKG, p_procedure => C_PROC);
            END;
        END LOOP;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. POSTed 2xx: ' || l_posted
            || ', POST-rejected(stashed): ' || l_reject
            || ', skipped(parent regime not confirmed): ' || l_skipped
            || ' (all rates left GENERATED for base-table reconciliation).',
            p_package => C_PKG, p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed.', SQLERRM, p_package => C_PKG, p_procedure => C_PROC);
            RAISE;
    END LOAD_RATES;

    -- --------------------------------------------------------
    -- FETCH_BIP_RESULTS
    -- Runs the base-table reconciliation report for this run. Delegates to the
    -- shared DMT_UTIL_PKG.RUN_BIP_REPORT (no private SOAP copy). Two parameters:
    -- P_REGIME_CODES confirms regimes over ZX_REGIMES_B (G_1); P_RATE_CODES
    -- confirms rates over ZX_RATES_B (G_2). Either may be blank. Codes are not
    -- run-prefixed. PROCEDURE per the procedures-only contract: x_report_xml NULL
    -- with x_error_code = C_SUCCESS means zero rows; failures are logged and
    -- surfaced through x_error_code -- exceptions never escape.
    -- --------------------------------------------------------
    PROCEDURE FETCH_BIP_RESULTS (
        p_run_id       IN  NUMBER,
        p_regime_codes IN  VARCHAR2,
        p_rate_codes   IN  VARCHAR2,
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
            || ' | P_REGIME_CODES: ' || NVL(p_regime_codes, '(none)')
            || ' | P_RATE_CODES: ' || NVL(p_rate_codes, '(none)'),
            p_package => C_PKG, p_procedure => C_PROC);

        IF p_regime_codes IS NULL AND p_rate_codes IS NULL THEN
            x_error_code := DMT_UTIL_PKG.C_SUCCESS;   -- nothing to confirm
            RETURN;
        END IF;

        l_step := 'running base-table reconciliation report for ' || C_CEMLI;
        DMT_UTIL_PKG.RUN_BIP_REPORT(
            p_run_id     => p_run_id,
            p_cemli_code => C_CEMLI,
            p_params     => 'P_REGIME_CODES|' || p_regime_codes
                            || '~P_RATE_CODES|' || p_rate_codes,
            x_report_xml => x_report_xml,
            x_error_code => x_error_code);

        IF x_error_code != DMT_UTIL_PKG.C_SUCCESS THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ' failed while ' || l_step
                || ' (detail logged by RUN_BIP_REPORT).',
                p_package => C_PKG, p_procedure => C_PROC, p_log_type => 'ERROR');
            RETURN;
        END IF;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. CEMLI: ' || C_CEMLI ||
            CASE WHEN x_report_xml IS NULL
                 THEN ' | Report returned zero rows.'
                 ELSE ' | Report data received.'
            END,
            p_package => C_PKG, p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            x_report_xml := NULL;
            x_error_code := DMT_UTIL_PKG.C_ERROR;
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed while ' || l_step || ' | CEMLI: ' || C_CEMLI,
                SQLERRM, p_package => C_PKG, p_procedure => C_PROC);
    END FETCH_BIP_RESULTS;

    -- --------------------------------------------------------
    -- PARSE_REGIMES
    -- Positive base-table confirmation for tier 1. Each G_1 report row is a
    -- regime found in ZX_REGIMES_B -> mark the matching regime TFM row LOADED
    -- with FUSION_TAX_REGIME_ID = the returned TAX_REGIME_ID. Regimes not
    -- returned are left as the load step set them (stashed error, else
    -- GENERATED/unaccounted) -- never a fabricated verdict or id.
    -- Writes the TFM table only; no COMMIT (the runner owns the txn).
    -- --------------------------------------------------------
    PROCEDURE PARSE_REGIMES (
        p_run_id     IN  NUMBER,
        p_report_xml IN  XMLTYPE
    ) IS
        C_PROC   CONSTANT VARCHAR2(30) := 'PARSE_REGIMES';
        l_loaded NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, C_PROC || ' start.', p_package => C_PKG, p_procedure => C_PROC);

        IF p_report_xml IS NULL THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': report returned zero base-table rows. '
                || 'No fabricated LOADED; regimes left as the load step set them.',
                p_package => C_PKG, p_procedure => C_PROC, p_log_type => 'WARN');
            RETURN;
        END IF;

        FOR r IN (
            SELECT x.record_key,
                   UPPER(x.source_type) AS source_type,
                   x.fusion_id
            FROM   XMLTABLE('/DATA_DS/G_1' PASSING p_report_xml
                COLUMNS
                    record_key  VARCHAR2(100) PATH 'RECORD_KEY',
                    source_type VARCHAR2(20)  PATH 'SOURCE_TYPE',
                    fusion_id   NUMBER        PATH 'FUSION_ID'
            ) x
        ) LOOP
            IF r.source_type = 'BASE_REGIME' AND r.fusion_id IS NOT NULL THEN
                UPDATE DMT_ZX_REGIME_TFM_TBL
                SET    TFM_STATUS           = 'LOADED',
                       FUSION_TAX_REGIME_ID = r.fusion_id,
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID          = p_run_id
                AND    TAX_REGIME_CODE = r.record_key
                AND    TFM_STATUS NOT IN ('LOADED','FAILED');
                l_loaded := l_loaded + SQL%ROWCOUNT;
            END IF;
        END LOOP;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. Regimes base-table confirmed LOADED: ' || l_loaded || '.',
            p_package => C_PKG, p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed.', SQLERRM, p_package => C_PKG, p_procedure => C_PROC);
            RAISE;
    END PARSE_REGIMES;

    -- --------------------------------------------------------
    -- PARSE_RATES
    -- Positive base-table confirmation for tier 2. Each G_2 report row is a rate
    -- found in ZX_RATES_B -> mark the matching rate TFM row LOADED with
    -- FUSION_TAX_RATE_ID = the returned TAX_RATE_ID. Rates not returned are left
    -- as the load step set them (stashed error, else GENERATED/unaccounted) --
    -- never a fabricated verdict or id.
    -- Writes the TFM table only; no COMMIT (the runner owns the txn).
    -- --------------------------------------------------------
    PROCEDURE PARSE_RATES (
        p_run_id     IN  NUMBER,
        p_report_xml IN  XMLTYPE
    ) IS
        C_PROC   CONSTANT VARCHAR2(30) := 'PARSE_RATES';
        l_loaded NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, C_PROC || ' start.', p_package => C_PKG, p_procedure => C_PROC);

        IF p_report_xml IS NULL THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': rate report returned zero base-table rows. '
                || 'No fabricated LOADED; rates left as the load step set them.',
                p_package => C_PKG, p_procedure => C_PROC, p_log_type => 'WARN');
            RETURN;
        END IF;

        FOR r IN (
            SELECT x.record_key,
                   UPPER(x.source_type) AS source_type,
                   x.fusion_id
            FROM   XMLTABLE('/DATA_DS/G_2' PASSING p_report_xml
                COLUMNS
                    record_key  VARCHAR2(100) PATH 'RECORD_KEY',
                    source_type VARCHAR2(20)  PATH 'SOURCE_TYPE',
                    fusion_id   NUMBER        PATH 'FUSION_ID'
            ) x
        ) LOOP
            IF r.source_type = 'BASE_RATE' AND r.fusion_id IS NOT NULL THEN
                UPDATE DMT_ZX_RATE_TFM_TBL
                SET    TFM_STATUS          = 'LOADED',
                       FUSION_TAX_RATE_ID  = r.fusion_id,
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID        = p_run_id
                AND    TAX_RATE_CODE = r.record_key
                AND    TFM_STATUS NOT IN ('LOADED','FAILED');
                l_loaded := l_loaded + SQL%ROWCOUNT;
            END IF;
        END LOOP;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. Rates base-table confirmed LOADED: ' || l_loaded || '.',
            p_package => C_PKG, p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed.', SQLERRM, p_package => C_PKG, p_procedure => C_PROC);
            RAISE;
    END PARSE_RATES;

    -- ============================================================
    -- LOAD_AND_RECONCILE
    -- Main entry point. LOAD regimes via REST POST, RECONCILE regimes via the BIP
    -- base-table report (the new standard), then LOAD rates under confirmed
    -- regimes and RECONCILE rates via the same report. Post-reconcile sweep marks
    -- any GENERATED row that carries a stashed real error FAILED; rows with no
    -- error and no base-table hit are left GENERATED (unaccounted) for the honest
    -- accounting gate. Mirrors terminal outcomes onto STG.
    -- ============================================================
    PROCEDURE LOAD_AND_RECONCILE (
        p_run_id IN NUMBER
    ) IS
        C_PROC        CONSTANT VARCHAR2(30) := 'LOAD_AND_RECONCILE';
        l_regime_codes VARCHAR2(4000);
        l_rate_codes   VARCHAR2(4000);
        l_xml          XMLTYPE;
        l_err          NUMBER;
        l_loaded       NUMBER;
        l_failed       NUMBER;
        l_unaccnt      NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, C_PROC || ' start.', p_package => C_PKG, p_procedure => C_PROC);

        -- Phase 1: LOAD tier 1 -- POST every GENERATED regime.
        LOAD_REGIMES(p_run_id);

        -- Regime codes still needing confirmation (not FAILED by the load step).
        SELECT LISTAGG(TAX_REGIME_CODE, ',') WITHIN GROUP (ORDER BY TAX_REGIME_CODE)
        INTO   l_regime_codes
        FROM   DMT_ZX_REGIME_TFM_TBL
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'GENERATED';

        -- Phase 2: RECONCILE regimes (G_1 over ZX_REGIMES_B by code).
        FETCH_BIP_RESULTS(
            p_run_id       => p_run_id,
            p_regime_codes => l_regime_codes,
            p_rate_codes   => NULL,
            x_report_xml   => l_xml,
            x_error_code   => l_err);

        IF l_err != DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20039,
                'LOAD_AND_RECONCILE: regime base-table reconciliation report failed for CEMLI '
                || C_CEMLI || ' (detail in DMT_LOG_TBL).');
        END IF;

        PARSE_REGIMES(p_run_id, l_xml);

        -- Phase 3: LOAD tier 2 -- POST rates under base-table-confirmed regimes.
        LOAD_RATES(p_run_id);

        -- Rate codes still needing confirmation (not FAILED by the load step).
        SELECT LISTAGG(TAX_RATE_CODE, ',') WITHIN GROUP (ORDER BY TAX_RATE_CODE)
        INTO   l_rate_codes
        FROM   DMT_ZX_RATE_TFM_TBL
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'GENERATED';

        -- Phase 4: RECONCILE rates (G_2 over ZX_RATES_B by code).
        IF l_rate_codes IS NOT NULL THEN
            FETCH_BIP_RESULTS(
                p_run_id       => p_run_id,
                p_regime_codes => NULL,
                p_rate_codes   => l_rate_codes,
                x_report_xml   => l_xml,
                x_error_code   => l_err);

            IF l_err != DMT_UTIL_PKG.C_SUCCESS THEN
                RAISE_APPLICATION_ERROR(-20039,
                    'LOAD_AND_RECONCILE: rate base-table reconciliation report failed for CEMLI '
                    || C_CEMLI || ' (detail in DMT_LOG_TBL).');
            END IF;

            PARSE_RATES(p_run_id, l_xml);
        END IF;

        -- Post-reconcile sweep: any regime/rate NOT confirmed in the base table
        -- is still GENERATED. If its POST returned a real Fusion error (stashed in
        -- ERROR_TEXT) mark it FAILED on that real error. A row with no stashed
        -- error AND no base-table hit is left GENERATED (unaccounted); the
        -- accounting gate surfaces it -- never a fabricated verdict.
        UPDATE DMT_ZX_REGIME_TFM_TBL
        SET    TFM_STATUS           = 'FAILED',
               RESULTS_UPDATED_DATE = SYSDATE,
               LAST_UPDATED_DATE    = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'GENERATED'
        AND    ERROR_TEXT IS NOT NULL;

        UPDATE DMT_ZX_RATE_TFM_TBL
        SET    TFM_STATUS           = 'FAILED',
               RESULTS_UPDATED_DATE = SYSDATE,
               LAST_UPDATED_DATE    = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'GENERATED'
        AND    ERROR_TEXT IS NOT NULL;

        -- Mirror the terminal TFM outcome onto STG for regimes.
        UPDATE DMT_ZX_REGIME_STG_TBL s
        SET    s.STG_STATUS = (SELECT t.TFM_STATUS
                               FROM   DMT_ZX_REGIME_TFM_TBL t
                               WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                               AND    t.RUN_ID = p_run_id),
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  EXISTS (SELECT 1 FROM DMT_ZX_REGIME_TFM_TBL t
                       WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                       AND    t.RUN_ID = p_run_id
                       AND    t.TFM_STATUS IN ('LOADED','FAILED'));

        -- Mirror the terminal TFM outcome onto STG for rates.
        UPDATE DMT_ZX_RATE_STG_TBL s
        SET    s.STG_STATUS = (SELECT t.TFM_STATUS
                               FROM   DMT_ZX_RATE_TFM_TBL t
                               WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                               AND    t.RUN_ID = p_run_id),
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  EXISTS (SELECT 1 FROM DMT_ZX_RATE_TFM_TBL t
                       WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                       AND    t.RUN_ID = p_run_id
                       AND    t.TFM_STATUS IN ('LOADED','FAILED'));

        COMMIT;

        SELECT COUNT(CASE WHEN TFM_STATUS = 'LOADED' THEN 1 END),
               COUNT(CASE WHEN TFM_STATUS = 'FAILED' THEN 1 END),
               COUNT(CASE WHEN TFM_STATUS NOT IN ('LOADED','FAILED') THEN 1 END)
        INTO   l_loaded, l_failed, l_unaccnt
        FROM   (SELECT TFM_STATUS FROM DMT_ZX_REGIME_TFM_TBL WHERE RUN_ID = p_run_id
                UNION ALL
                SELECT TFM_STATUS FROM DMT_ZX_RATE_TFM_TBL WHERE RUN_ID = p_run_id);

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. LOADED: ' || l_loaded
            || ', FAILED: ' || l_failed
            || ', UNACCOUNTED: ' || l_unaccnt || '.',
            p_package => C_PKG, p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed.', SQLERRM, p_package => C_PKG, p_procedure => C_PROC);
            RAISE;
    END LOAD_AND_RECONCILE;

END DMT_ZX_RESULTS_PKG;
/
