-- PACKAGE BODY DMT_FND_LOOKUP_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_FND_LOOKUP_RESULTS_PKG" AS

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_FND_LOOKUP_RESULTS_PKG';

    -- Fusion REST base path for standard lookups
    C_LOOKUPS_PATH CONSTANT VARCHAR2(200) := '/fscmRestApi/resources/11.13.18.05/standardLookups';

    -- ModuleId for user-level lookup types (required by Fusion REST API)
    -- Discovered from instance: this is the common FND module GUID
    C_MODULE_ID CONSTANT VARCHAR2(50) := '40B3FA7250D19380E040449823C67A1A';

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
    -- Main entry point. Creates lookup types + codes in Fusion
    -- via REST, then verifies and updates TFM/STG status.
    -- ============================================================
    PROCEDURE LOAD_AND_RECONCILE (
        p_run_id IN NUMBER
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'LOAD_AND_RECONCILE';

        l_response      CLOB;
        l_http_status   NUMBER;
        l_body          VARCHAR2(32767);
        l_payload       CLOB;

        l_types_loaded  NUMBER := 0;
        l_types_failed  NUMBER := 0;
        l_values_loaded NUMBER := 0;
        l_values_failed NUMBER := 0;
        l_errmsg        VARCHAR2(4000);
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id,
            'LOAD_AND_RECONCILE start.', C_PKG, C_PROC);

        -- ========================================
        -- Phase 1: Create Lookup Types in Fusion
        -- ========================================
        FOR r IN (
            SELECT TFM_SEQUENCE_ID, STG_SEQUENCE_ID, LOOKUP_TYPE, MEANING, DESCRIPTION
            FROM   DMT_FND_LOOKUP_TYPE_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS = 'GENERATED'
            ORDER BY TFM_SEQUENCE_ID
        ) LOOP
            BEGIN
                l_payload := '{"LookupType":"' || REPLACE(r.LOOKUP_TYPE, '"', '\"') || '"'
                    || ',"Meaning":"' || REPLACE(NVL(r.MEANING, r.LOOKUP_TYPE), '"', '\"') || '"'
                    || CASE WHEN r.DESCRIPTION IS NOT NULL
                       THEN ',"Description":"' || REPLACE(r.DESCRIPTION, '"', '\"') || '"'
                       END
                    || ',"ModuleId":"' || C_MODULE_ID || '"'
                    || '}';

                l_response := rest_call('POST', C_LOOKUPS_PATH, l_payload, p_run_id);
                l_http_status := get_status(l_response);

                IF l_http_status IN (200, 201) THEN
                    UPDATE DMT_FND_LOOKUP_TYPE_TFM_TBL
                    SET    TFM_STATUS = 'LOADED', RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    UPDATE DMT_FND_LOOKUP_TYPE_STG_TBL
                    SET    STG_STATUS = 'LOADED', LAST_UPDATED_DATE = SYSDATE
                    WHERE  STG_SEQUENCE_ID = r.STG_SEQUENCE_ID;

                    l_types_loaded := l_types_loaded + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Type LOADED: ' || r.LOOKUP_TYPE, C_PKG, C_PROC);
                ELSE
                    l_body := DBMS_LOB.SUBSTR(l_response, 1000, INSTR(l_response, '|') + 1);
                    UPDATE DMT_FND_LOOKUP_TYPE_TFM_TBL
                    SET    TFM_STATUS = 'FAILED',
                           ERROR_TEXT = '[FUSION_ERROR] HTTP ' || l_http_status || ': ' || SUBSTR(l_body, 1, 2000),
                           RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    UPDATE DMT_FND_LOOKUP_TYPE_STG_TBL
                    SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                    WHERE  STG_SEQUENCE_ID = r.STG_SEQUENCE_ID;

                    l_types_failed := l_types_failed + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Type FAILED: ' || r.LOOKUP_TYPE || ' HTTP ' || l_http_status,
                        C_PKG, C_PROC, 'WARN');
                END IF;

                IF DBMS_LOB.ISTEMPORARY(l_response) = 1 THEN
                    DBMS_LOB.FREETEMPORARY(l_response);
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    l_errmsg := SQLERRM;
                    UPDATE DMT_FND_LOOKUP_TYPE_TFM_TBL
                    SET    TFM_STATUS = 'FAILED',
                           ERROR_TEXT = '[FUSION_ERROR] ' || l_errmsg,
                           RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    UPDATE DMT_FND_LOOKUP_TYPE_STG_TBL
                    SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                    WHERE  STG_SEQUENCE_ID = r.STG_SEQUENCE_ID;

                    l_types_failed := l_types_failed + 1;
                    DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                        'Type FAILED (exception): ' || r.LOOKUP_TYPE,
                        l_errmsg, C_PKG, C_PROC);
            END;
        END LOOP;

        COMMIT;

        -- ========================================
        -- Phase 2: Create Lookup Codes in Fusion
        -- Only for types that LOADED successfully.
        -- ========================================
        FOR r IN (
            SELECT v.TFM_SEQUENCE_ID, v.STG_SEQUENCE_ID,
                   v.LOOKUP_TYPE, v.LOOKUP_CODE, v.DISPLAY_SEQUENCE,
                   v.ENABLED_FLAG, v.START_DATE_ACTIVE, v.END_DATE_ACTIVE,
                   v.MEANING, v.DESCRIPTION, v.TAG
            FROM   DMT_FND_LOOKUP_VALUE_TFM_TBL v
            WHERE  v.RUN_ID = p_run_id
            AND    v.TFM_STATUS = 'GENERATED'
            -- Only load values whose parent type was LOADED
            AND    EXISTS (
                SELECT 1 FROM DMT_FND_LOOKUP_TYPE_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id
                AND    t.LOOKUP_TYPE = v.LOOKUP_TYPE
                AND    t.TFM_STATUS = 'LOADED'
            )
            ORDER BY v.LOOKUP_TYPE, v.DISPLAY_SEQUENCE
        ) LOOP
            BEGIN
                l_payload := '{"LookupCode":"' || REPLACE(r.LOOKUP_CODE, '"', '\"') || '"'
                    || ',"DisplaySequence":' || NVL(TO_CHAR(r.DISPLAY_SEQUENCE), '1')
                    || ',"EnabledFlag":"' || NVL(r.ENABLED_FLAG, 'Y') || '"'
                    || ',"Meaning":"' || REPLACE(NVL(r.MEANING, r.LOOKUP_CODE), '"', '\"') || '"'
                    || CASE WHEN r.DESCRIPTION IS NOT NULL
                       THEN ',"Description":"' || REPLACE(r.DESCRIPTION, '"', '\"') || '"'
                       END
                    || CASE WHEN r.TAG IS NOT NULL
                       THEN ',"Tag":"' || REPLACE(r.TAG, '"', '\"') || '"'
                       END
                    || CASE WHEN r.START_DATE_ACTIVE IS NOT NULL
                       THEN ',"StartDateActive":"' || TO_CHAR(r.START_DATE_ACTIVE, 'YYYY-MM-DD') || '"'
                       END
                    || CASE WHEN r.END_DATE_ACTIVE IS NOT NULL
                       THEN ',"EndDateActive":"' || TO_CHAR(r.END_DATE_ACTIVE, 'YYYY-MM-DD') || '"'
                       END
                    || '}';

                l_response := rest_call('POST',
                    C_LOOKUPS_PATH || '/' || r.LOOKUP_TYPE || '/child/lookupCodes',
                    l_payload, p_run_id);
                l_http_status := get_status(l_response);

                IF l_http_status IN (200, 201) THEN
                    UPDATE DMT_FND_LOOKUP_VALUE_TFM_TBL
                    SET    TFM_STATUS = 'LOADED', RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    UPDATE DMT_FND_LOOKUP_VALUE_STG_TBL
                    SET    STG_STATUS = 'LOADED', LAST_UPDATED_DATE = SYSDATE
                    WHERE  STG_SEQUENCE_ID = r.STG_SEQUENCE_ID;

                    l_values_loaded := l_values_loaded + 1;
                ELSE
                    l_body := DBMS_LOB.SUBSTR(l_response, 1000, INSTR(l_response, '|') + 1);
                    UPDATE DMT_FND_LOOKUP_VALUE_TFM_TBL
                    SET    TFM_STATUS = 'FAILED',
                           ERROR_TEXT = '[FUSION_ERROR] HTTP ' || l_http_status || ': ' || SUBSTR(l_body, 1, 2000),
                           RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    UPDATE DMT_FND_LOOKUP_VALUE_STG_TBL
                    SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                    WHERE  STG_SEQUENCE_ID = r.STG_SEQUENCE_ID;

                    l_values_failed := l_values_failed + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Value FAILED: ' || r.LOOKUP_TYPE || '.' || r.LOOKUP_CODE || ' HTTP ' || l_http_status,
                        C_PKG, C_PROC, 'WARN');
                END IF;

                IF DBMS_LOB.ISTEMPORARY(l_response) = 1 THEN
                    DBMS_LOB.FREETEMPORARY(l_response);
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    l_errmsg := SQLERRM;
                    UPDATE DMT_FND_LOOKUP_VALUE_TFM_TBL
                    SET    TFM_STATUS = 'FAILED',
                           ERROR_TEXT = '[FUSION_ERROR] ' || l_errmsg,
                           RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    UPDATE DMT_FND_LOOKUP_VALUE_STG_TBL
                    SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                    WHERE  STG_SEQUENCE_ID = r.STG_SEQUENCE_ID;

                    l_values_failed := l_values_failed + 1;
                    DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                        'Value FAILED (exception): ' || r.LOOKUP_TYPE || '.' || r.LOOKUP_CODE,
                        l_errmsg, C_PKG, C_PROC);
            END;
        END LOOP;

        -- Mark orphan values (parent type FAILED) as FAILED too
        UPDATE DMT_FND_LOOKUP_VALUE_TFM_TBL
        SET    TFM_STATUS = 'FAILED',
               ERROR_TEXT = NVL(ERROR_TEXT, '') || '[FUSION_ERROR] Parent lookup type was not loaded.',
               RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'GENERATED'
        AND    NOT EXISTS (
            SELECT 1 FROM DMT_FND_LOOKUP_TYPE_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id
            AND    t.LOOKUP_TYPE = DMT_FND_LOOKUP_VALUE_TFM_TBL.LOOKUP_TYPE
            AND    t.TFM_STATUS = 'LOADED'
        );

        -- Echo those to STG
        UPDATE DMT_FND_LOOKUP_VALUE_STG_TBL
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (
            SELECT STG_SEQUENCE_ID FROM DMT_FND_LOOKUP_VALUE_TFM_TBL
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'FAILED'
            AND    STG_STATUS != 'FAILED'
        );

        COMMIT;

        DMT_UTIL_PKG.LOG(p_run_id,
            'LOAD_AND_RECONCILE complete. Types: ' || l_types_loaded || ' LOADED, ' || l_types_failed || ' FAILED'
            || ' | Values: ' || l_values_loaded || ' LOADED, ' || l_values_failed || ' FAILED',
            C_PKG, C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'LOAD_AND_RECONCILE failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END LOAD_AND_RECONCILE;

END DMT_FND_LOOKUP_RESULTS_PKG;
/
