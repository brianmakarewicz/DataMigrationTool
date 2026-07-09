-- PACKAGE BODY DMT_ZX_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_ZX_RESULTS_PKG" AS

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_ZX_RESULTS_PKG';

    -- Fusion REST base path for tax regimes
    C_REGIMES_PATH CONSTANT VARCHAR2(200) := '/fscmRestApi/resources/11.13.18.05/taxRegimes';

    -- Fusion REST base path for tax rates (direct endpoint — may need
    -- adjustment to the hierarchical regime>tax>status>rate path)
    C_RATES_PATH CONSTANT VARCHAR2(200) := '/fscmRestApi/resources/11.13.18.05/taxRates';

    -- --------------------------------------------------------
    -- Private: make a REST call and return status + response
    -- --------------------------------------------------------
    FUNCTION rest_call (
        p_method         IN VARCHAR2,  -- GET, POST, DELETE
        p_path           IN VARCHAR2,  -- relative path after base URL
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
        l_username := DMT_UTIL_PKG.GET_CONFIG('FUSION_USERNAME');
        l_password := DMT_UTIL_PKG.GET_CONFIG('FUSION_PASSWORD');
        l_url      := l_base_url || p_path;

        UTL_HTTP.SET_WALLET('file:' || DMT_UTIL_PKG.GET_CONFIG('WALLET_DIR'), DMT_UTIL_PKG.GET_CONFIG('WALLET_PASSWORD'));

        l_http_req := UTL_HTTP.BEGIN_REQUEST(l_url, p_method, 'HTTP/1.1');
        UTL_HTTP.SET_HEADER(l_http_req, 'Authorization',
            'Basic ' || UTL_RAW.CAST_TO_VARCHAR2(UTL_ENCODE.BASE64_ENCODE(
                UTL_RAW.CAST_TO_RAW(l_username || ':' || l_password))));
        UTL_HTTP.SET_HEADER(l_http_req, 'Accept', 'application/json');

        IF p_body IS NOT NULL THEN
            UTL_HTTP.SET_HEADER(l_http_req, 'Content-Type', 'application/json');
            UTL_HTTP.SET_HEADER(l_http_req, 'Content-Length', DBMS_LOB.GETLENGTH(p_body));
            -- Chunked write for large payloads
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

        -- Prepend status code so caller can check
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
    END;

    -- --------------------------------------------------------
    -- Private: extract body from rest_call response
    -- --------------------------------------------------------
    FUNCTION get_body(p_response IN CLOB) RETURN CLOB IS
    BEGIN
        RETURN DBMS_LOB.SUBSTR(p_response, DBMS_LOB.GETLENGTH(p_response) - INSTR(p_response, '|'), INSTR(p_response, '|') + 1);
    END;

    -- ============================================================
    -- LOAD_AND_RECONCILE
    -- Main entry point. Creates tax regimes + rates in Fusion
    -- via REST, then updates TFM/STG status.
    -- ============================================================
    PROCEDURE LOAD_AND_RECONCILE (
        p_run_id IN NUMBER
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'LOAD_AND_RECONCILE';

        l_response        CLOB;
        l_http_status     NUMBER;
        l_body            VARCHAR2(32767);
        l_payload         CLOB;

        l_regimes_loaded  NUMBER := 0;
        l_regimes_failed  NUMBER := 0;
        l_rates_loaded    NUMBER := 0;
        l_rates_failed    NUMBER := 0;
        l_errmsg          VARCHAR2(4000);
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id,
            'LOAD_AND_RECONCILE start.', C_PKG, C_PROC);

        -- ========================================
        -- Phase 1: Create Tax Regimes in Fusion
        -- ========================================
        FOR r IN (
            SELECT TFM_SEQUENCE_ID, STG_SEQUENCE_ID, TAX_REGIME_CODE,
                   TAX_REGIME_NAME, DESCRIPTION, EFFECTIVE_FROM, EFFECTIVE_TO,
                   COUNTRY_CODE, REGIME_TYPE_FLAG, HAS_SUB_REGIME_FLAG,
                   PARENT_REGIME_CODE
            FROM   DMT_ZX_REGIME_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS = 'GENERATED'
            ORDER BY TFM_SEQUENCE_ID
        ) LOOP
            BEGIN
                l_payload := '{"TaxRegimeCode":"' || REPLACE(r.TAX_REGIME_CODE, '"', '\"') || '"'
                    || ',"TaxRegimeName":"' || REPLACE(NVL(r.TAX_REGIME_NAME, r.TAX_REGIME_CODE), '"', '\"') || '"'
                    || CASE WHEN r.DESCRIPTION IS NOT NULL
                       THEN ',"Description":"' || REPLACE(r.DESCRIPTION, '"', '\"') || '"'
                       END
                    || ',"CountryCode":"' || NVL(r.COUNTRY_CODE, 'US') || '"'
                    || ',"EffectiveFrom":"' || TO_CHAR(NVL(r.EFFECTIVE_FROM, DATE '2020-01-01'), 'YYYY-MM-DD') || '"'
                    || CASE WHEN r.EFFECTIVE_TO IS NOT NULL
                       THEN ',"EffectiveTo":"' || TO_CHAR(r.EFFECTIVE_TO, 'YYYY-MM-DD') || '"'
                       END
                    || CASE WHEN r.REGIME_TYPE_FLAG IS NOT NULL
                       THEN ',"RegimeTypeFlag":"' || r.REGIME_TYPE_FLAG || '"'
                       END
                    || CASE WHEN r.HAS_SUB_REGIME_FLAG IS NOT NULL
                       THEN ',"HasSubRegimeFlag":"' || r.HAS_SUB_REGIME_FLAG || '"'
                       END
                    || CASE WHEN r.PARENT_REGIME_CODE IS NOT NULL
                       THEN ',"ParentRegimeCode":"' || REPLACE(r.PARENT_REGIME_CODE, '"', '\"') || '"'
                       END
                    || '}';

                l_response := rest_call('POST', C_REGIMES_PATH, l_payload, p_run_id);
                l_http_status := get_status(l_response);

                IF l_http_status IN (200, 201) THEN
                    UPDATE DMT_ZX_REGIME_TFM_TBL
                    SET    TFM_STATUS = 'LOADED', RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    UPDATE DMT_ZX_REGIME_STG_TBL
                    SET    STG_STATUS = 'LOADED', LAST_UPDATED_DATE = SYSDATE
                    WHERE  STG_SEQUENCE_ID = r.STG_SEQUENCE_ID;

                    l_regimes_loaded := l_regimes_loaded + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Regime LOADED: ' || r.TAX_REGIME_CODE, C_PKG, C_PROC);
                ELSE
                    l_body := DBMS_LOB.SUBSTR(l_response, 1000, INSTR(l_response, '|') + 1);
                    UPDATE DMT_ZX_REGIME_TFM_TBL
                    SET    TFM_STATUS = 'FAILED',
                           ERROR_TEXT = '[FUSION_ERROR] HTTP ' || l_http_status || ': ' || SUBSTR(l_body, 1, 2000),
                           RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    UPDATE DMT_ZX_REGIME_STG_TBL
                    SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                    WHERE  STG_SEQUENCE_ID = r.STG_SEQUENCE_ID;

                    l_regimes_failed := l_regimes_failed + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Regime FAILED: ' || r.TAX_REGIME_CODE || ' HTTP ' || l_http_status,
                        C_PKG, C_PROC, 'WARN');
                END IF;

                IF DBMS_LOB.ISTEMPORARY(l_response) = 1 THEN
                    DBMS_LOB.FREETEMPORARY(l_response);
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    l_errmsg := SQLERRM;
                    UPDATE DMT_ZX_REGIME_TFM_TBL
                    SET    TFM_STATUS = 'FAILED',
                           ERROR_TEXT = '[FUSION_ERROR] ' || l_errmsg,
                           RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    UPDATE DMT_ZX_REGIME_STG_TBL
                    SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                    WHERE  STG_SEQUENCE_ID = r.STG_SEQUENCE_ID;

                    l_regimes_failed := l_regimes_failed + 1;
                    DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                        'Regime FAILED (exception): ' || r.TAX_REGIME_CODE,
                        l_errmsg, C_PKG, C_PROC);
            END;
        END LOOP;

        COMMIT;

        -- ========================================
        -- Phase 2: Create Tax Rates in Fusion
        -- Only for regimes that LOADED successfully.
        -- Uses the direct taxRates endpoint first; if 404,
        -- the error is captured per-row rather than crashing.
        -- ========================================
        FOR r IN (
            SELECT v.TFM_SEQUENCE_ID, v.STG_SEQUENCE_ID,
                   v.TAX_REGIME_CODE, v.TAX, v.TAX_STATUS_CODE,
                   v.TAX_RATE_CODE, v.TAX_RATE_NAME, v.RATE_TYPE_CODE,
                   v.PERCENTAGE_RATE, v.EFFECTIVE_FROM, v.EFFECTIVE_TO,
                   v.ACTIVE_FLAG, v.DESCRIPTION, v.DEFAULT_RATE_FLAG
            FROM   DMT_ZX_RATE_TFM_TBL v
            WHERE  v.RUN_ID = p_run_id
            AND    v.TFM_STATUS = 'GENERATED'
            -- Only load rates whose parent regime was LOADED
            AND    EXISTS (
                SELECT 1 FROM DMT_ZX_REGIME_TFM_TBL t
                WHERE  t.RUN_ID  = p_run_id
                AND    t.TAX_REGIME_CODE = v.TAX_REGIME_CODE
                AND    t.TFM_STATUS = 'LOADED'
            )
            ORDER BY v.TAX_REGIME_CODE, v.TFM_SEQUENCE_ID
        ) LOOP
            BEGIN
                l_payload := '{"TaxRateCode":"' || REPLACE(r.TAX_RATE_CODE, '"', '\"') || '"'
                    || ',"TaxRateName":"' || REPLACE(NVL(r.TAX_RATE_NAME, r.TAX_RATE_CODE), '"', '\"') || '"'
                    || ',"TaxRegimeCode":"' || REPLACE(r.TAX_REGIME_CODE, '"', '\"') || '"'
                    || CASE WHEN r.TAX IS NOT NULL
                       THEN ',"Tax":"' || REPLACE(r.TAX, '"', '\"') || '"'
                       END
                    || CASE WHEN r.TAX_STATUS_CODE IS NOT NULL
                       THEN ',"TaxStatusCode":"' || REPLACE(r.TAX_STATUS_CODE, '"', '\"') || '"'
                       END
                    || CASE WHEN r.RATE_TYPE_CODE IS NOT NULL
                       THEN ',"RateTypeCode":"' || REPLACE(r.RATE_TYPE_CODE, '"', '\"') || '"'
                       END
                    || CASE WHEN r.PERCENTAGE_RATE IS NOT NULL
                       THEN ',"PercentageRate":' || TO_CHAR(r.PERCENTAGE_RATE)
                       END
                    || ',"EffectiveFrom":"' || TO_CHAR(NVL(r.EFFECTIVE_FROM, DATE '2020-01-01'), 'YYYY-MM-DD') || '"'
                    || CASE WHEN r.EFFECTIVE_TO IS NOT NULL
                       THEN ',"EffectiveTo":"' || TO_CHAR(r.EFFECTIVE_TO, 'YYYY-MM-DD') || '"'
                       END
                    || ',"ActiveFlag":"' || NVL(r.ACTIVE_FLAG, 'Y') || '"'
                    || CASE WHEN r.DESCRIPTION IS NOT NULL
                       THEN ',"Description":"' || REPLACE(r.DESCRIPTION, '"', '\"') || '"'
                       END
                    || CASE WHEN r.DEFAULT_RATE_FLAG IS NOT NULL
                       THEN ',"DefaultRateFlag":"' || r.DEFAULT_RATE_FLAG || '"'
                       END
                    || '}';

                l_response := rest_call('POST', C_RATES_PATH, l_payload, p_run_id);
                l_http_status := get_status(l_response);

                IF l_http_status IN (200, 201) THEN
                    UPDATE DMT_ZX_RATE_TFM_TBL
                    SET    TFM_STATUS = 'LOADED', RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    UPDATE DMT_ZX_RATE_STG_TBL
                    SET    STG_STATUS = 'LOADED', LAST_UPDATED_DATE = SYSDATE
                    WHERE  STG_SEQUENCE_ID = r.STG_SEQUENCE_ID;

                    l_rates_loaded := l_rates_loaded + 1;
                ELSE
                    l_body := DBMS_LOB.SUBSTR(l_response, 1000, INSTR(l_response, '|') + 1);

                    -- Log 404 as a warning — endpoint structure may need refinement
                    IF l_http_status = 404 THEN
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'Rate endpoint returned 404 for ' || r.TAX_RATE_CODE
                            || '. The taxRates endpoint may require a hierarchical path '
                            || '(regime>tax>status>rate). Marking FAILED for now.',
                            C_PKG, C_PROC, 'WARN');
                    END IF;

                    UPDATE DMT_ZX_RATE_TFM_TBL
                    SET    TFM_STATUS = 'FAILED',
                           ERROR_TEXT = '[FUSION_ERROR] HTTP ' || l_http_status || ': ' || SUBSTR(l_body, 1, 2000),
                           RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    UPDATE DMT_ZX_RATE_STG_TBL
                    SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                    WHERE  STG_SEQUENCE_ID = r.STG_SEQUENCE_ID;

                    l_rates_failed := l_rates_failed + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Rate FAILED: ' || r.TAX_REGIME_CODE || '.' || r.TAX_RATE_CODE || ' HTTP ' || l_http_status,
                        C_PKG, C_PROC, 'WARN');
                END IF;

                IF DBMS_LOB.ISTEMPORARY(l_response) = 1 THEN
                    DBMS_LOB.FREETEMPORARY(l_response);
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    l_errmsg := SQLERRM;
                    UPDATE DMT_ZX_RATE_TFM_TBL
                    SET    TFM_STATUS = 'FAILED',
                           ERROR_TEXT = '[FUSION_ERROR] ' || l_errmsg,
                           RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    UPDATE DMT_ZX_RATE_STG_TBL
                    SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                    WHERE  STG_SEQUENCE_ID = r.STG_SEQUENCE_ID;

                    l_rates_failed := l_rates_failed + 1;
                    DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                        'Rate FAILED (exception): ' || r.TAX_REGIME_CODE || '.' || r.TAX_RATE_CODE,
                        l_errmsg, C_PKG, C_PROC);
            END;
        END LOOP;

        -- Mark orphan rates (parent regime FAILED) as FAILED too
        UPDATE DMT_ZX_RATE_TFM_TBL
        SET    TFM_STATUS = 'FAILED',
               ERROR_TEXT = NVL(ERROR_TEXT, '') || '[FUSION_ERROR] Parent tax regime was not loaded.',
               RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'GENERATED'
        AND    NOT EXISTS (
            SELECT 1 FROM DMT_ZX_REGIME_TFM_TBL t
            WHERE  t.RUN_ID  = p_run_id
            AND    t.TAX_REGIME_CODE = DMT_ZX_RATE_TFM_TBL.TAX_REGIME_CODE
            AND    t.TFM_STATUS = 'LOADED'
        );

        -- Echo those to STG
        UPDATE DMT_ZX_RATE_STG_TBL
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (
            SELECT STG_SEQUENCE_ID FROM DMT_ZX_RATE_TFM_TBL
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'FAILED'
            AND    STG_STATUS != 'FAILED'
        );

        COMMIT;

        DMT_UTIL_PKG.LOG(p_run_id,
            'LOAD_AND_RECONCILE complete. Regimes: ' || l_regimes_loaded || ' LOADED, ' || l_regimes_failed || ' FAILED'
            || ' | Rates: ' || l_rates_loaded || ' LOADED, ' || l_rates_failed || ' FAILED',
            C_PKG, C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'LOAD_AND_RECONCILE failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END LOAD_AND_RECONCILE;

END DMT_ZX_RESULTS_PKG;
/
