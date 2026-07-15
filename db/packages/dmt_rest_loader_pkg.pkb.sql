-- PACKAGE BODY DMT_REST_LOADER_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_REST_LOADER_PKG" 
AS
-- ============================================================
-- DMT_REST_LOADER_PKG body
-- REST-based loading infrastructure for Fusion Cloud.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_REST_LOADER_PKG';


    -- --------------------------------------------------------
    -- Private: build Basic Auth header value from config.
    -- Mirrors the pattern in DMT_UTIL_PKG but kept private so
    -- this package can make raw UTL_HTTP calls without the
    -- auto-raise behaviour of DMT_UTIL_PKG.HTTP_REQUEST.
    -- --------------------------------------------------------
    FUNCTION basic_auth_header RETURN VARCHAR2 IS
        l_username  VARCHAR2(200);
        l_password  VARCHAR2(200);
        l_raw       RAW(600);
    BEGIN
        l_username := DMT_UTIL_PKG.GET_CONFIG('FUSION_USERNAME');
        l_password := DMT_UTIL_PKG.GET_CONFIG('FUSION_PASSWORD');

        IF l_username IS NULL OR l_password IS NULL THEN
            RAISE_APPLICATION_ERROR(-20002,
                'FUSION_USERNAME or FUSION_PASSWORD not set in DMT_CONFIG_TBL.');
        END IF;

        l_raw := UTL_ENCODE.BASE64_ENCODE(
                     UTL_RAW.CAST_TO_RAW(l_username || ':' || l_password));
        RETURN 'Basic ' || UTL_RAW.CAST_TO_VARCHAR2(l_raw);
    END basic_auth_header;


    -- --------------------------------------------------------
    -- Private: resolve the Fusion base URL from config, strip
    -- trailing slash to avoid double slashes when concatenating
    -- with the endpoint path.
    -- --------------------------------------------------------
    FUNCTION get_base_url RETURN VARCHAR2 IS
        l_url VARCHAR2(500);
    BEGIN
        l_url := DMT_UTIL_PKG.GET_CONFIG('FUSION_URL');
        IF l_url IS NULL THEN
            RAISE_APPLICATION_ERROR(-20010,
                'FUSION_URL not configured in DMT_CONFIG_TBL.');
        END IF;
        RETURN RTRIM(l_url, '/');
    END get_base_url;


    -- --------------------------------------------------------
    -- Private: execute a raw UTL_HTTP call (POST or PATCH).
    -- Does NOT raise on non-2xx — returns status + response so
    -- the caller can decide what to do.  This is intentionally
    -- different from DMT_UTIL_PKG.HTTP_REQUEST which auto-raises
    -- on non-2xx, because REST loaders need to inspect 4xx/5xx
    -- responses for per-row error messages without aborting.
    -- --------------------------------------------------------
    PROCEDURE rest_http (
        p_url            IN  VARCHAR2,
        p_method         IN  VARCHAR2,   -- 'POST' or 'PATCH'
        p_payload        IN  CLOB,
        p_run_id IN  NUMBER,
        p_object_type    IN  VARCHAR2,
        x_http_status    OUT NUMBER,
        x_response       OUT CLOB
    ) IS
        l_req       UTL_HTTP.REQ;
        l_resp      UTL_HTTP.RESP;
        l_buffer    VARCHAR2(32767);
        l_offset    INTEGER := 1;
        l_amount    INTEGER;
        l_body_len  INTEGER;
        l_proc      VARCHAR2(100);
    BEGIN
        l_proc := NVL(p_object_type, 'REST') || ' > REST_HTTP';

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'HTTP ' || p_method || ' ' || p_url,
            p_log_type       => DMT_UTIL_PKG.C_LOG_INFO,
            p_package        => C_PKG,
            p_procedure      => l_proc);

        UTL_HTTP.SET_RESPONSE_ERROR_CHECK(FALSE);
        UTL_HTTP.SET_TRANSFER_TIMEOUT(600);

        l_req := UTL_HTTP.BEGIN_REQUEST(p_url, p_method, 'HTTP/1.1');
        UTL_HTTP.SET_HEADER(l_req, 'Authorization',  basic_auth_header);
        UTL_HTTP.SET_HEADER(l_req, 'Content-Type',   'application/json');
        UTL_HTTP.SET_HEADER(l_req, 'Accept',          'application/json');

        -- Write request body in 8000-byte chunks
        IF p_payload IS NOT NULL THEN
            l_body_len := DBMS_LOB.GETLENGTH(p_payload);
            UTL_HTTP.SET_HEADER(l_req, 'Content-Length', TO_CHAR(l_body_len));
            l_offset := 1;
            WHILE l_offset <= l_body_len LOOP
                l_amount := LEAST(8000, l_body_len - l_offset + 1);
                UTL_HTTP.WRITE_TEXT(l_req,
                    DBMS_LOB.SUBSTR(p_payload, l_amount, l_offset));
                l_offset := l_offset + l_amount;
            END LOOP;
        ELSE
            UTL_HTTP.SET_HEADER(l_req, 'Content-Length', '0');
        END IF;

        -- Capture response
        l_resp := UTL_HTTP.GET_RESPONSE(l_req);
        x_http_status := l_resp.status_code;
        x_response := EMPTY_CLOB();

        BEGIN
            LOOP
                UTL_HTTP.READ_TEXT(l_resp, l_buffer, 32767);
                x_response := x_response || l_buffer;
            END LOOP;
        EXCEPTION
            WHEN UTL_HTTP.END_OF_BODY THEN NULL;
        END;

        UTL_HTTP.END_RESPONSE(l_resp);

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'HTTP response: ' || x_http_status ||
                                ' | ' || p_method || ' ' || p_url,
            p_log_type       => CASE WHEN x_http_status BETWEEN 200 AND 299
                                     THEN DMT_UTIL_PKG.C_LOG_INFO
                                     ELSE DMT_UTIL_PKG.C_LOG_WARN END,
            p_package        => C_PKG,
            p_procedure      => l_proc);

        -- Debug logging: log the first 2000 chars of the response body
        -- so a DBA can reconstruct what Fusion returned.
        IF DMT_UTIL_PKG.GET_CONFIG('DEBUG_LOGGING') = 'Y' THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'Response body (truncated): ' ||
                                    SUBSTR(x_response, 1, 2000),
                p_log_type       => DMT_UTIL_PKG.C_LOG_INFO,
                p_package        => C_PKG,
                p_procedure      => l_proc);
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            BEGIN UTL_HTTP.END_RESPONSE(l_resp);
            EXCEPTION WHEN OTHERS THEN NULL; END;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'REST_HTTP failed: ' || p_method || ' ' || p_url,
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => l_proc);
            RAISE;
    END rest_http;


    -- ============================================================
    -- POST_TO_FUSION
    -- ============================================================
    PROCEDURE POST_TO_FUSION (
        p_endpoint       IN  VARCHAR2,
        p_payload        IN  CLOB,
        p_run_id IN  NUMBER   DEFAULT NULL,
        p_object_type    IN  VARCHAR2 DEFAULT NULL,
        x_http_status    OUT NUMBER,
        x_response       OUT CLOB
    ) IS
        l_url  VARCHAR2(4000);
    BEGIN
        l_url := get_base_url || p_endpoint;

        rest_http(
            p_url            => l_url,
            p_method         => 'POST',
            p_payload        => p_payload,
            p_run_id => p_run_id,
            p_object_type    => p_object_type,
            x_http_status    => x_http_status,
            x_response       => x_response
        );

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'POST_TO_FUSION failed for endpoint: ' || p_endpoint,
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => NVL(p_object_type, 'REST') || ' > POST_TO_FUSION');
            RAISE;
    END POST_TO_FUSION;


    -- ============================================================
    -- PATCH_FUSION
    -- ============================================================
    PROCEDURE PATCH_FUSION (
        p_endpoint       IN  VARCHAR2,
        p_payload        IN  CLOB,
        p_resource_id    IN  VARCHAR2,
        p_run_id IN  NUMBER   DEFAULT NULL,
        p_object_type    IN  VARCHAR2 DEFAULT NULL,
        x_http_status    OUT NUMBER,
        x_response       OUT CLOB
    ) IS
        l_url  VARCHAR2(4000);
    BEGIN
        l_url := get_base_url || p_endpoint || '/' || p_resource_id;

        rest_http(
            p_url            => l_url,
            p_method         => 'PATCH',
            p_payload        => p_payload,
            p_run_id => p_run_id,
            p_object_type    => p_object_type,
            x_http_status    => x_http_status,
            x_response       => x_response
        );

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'PATCH_FUSION failed for endpoint: ' || p_endpoint ||
                                    '/' || p_resource_id,
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => NVL(p_object_type, 'REST') || ' > PATCH_FUSION');
            RAISE;
    END PATCH_FUSION;


    -- ============================================================
    -- PARSE_REST_RESPONSE
    -- ============================================================
    PROCEDURE PARSE_REST_RESPONSE (
        p_http_status    IN  NUMBER,
        p_response       IN  CLOB,
        p_id_field       IN  VARCHAR2 DEFAULT 'BankId',
        x_success        OUT BOOLEAN,
        x_fusion_id      OUT NUMBER,
        x_error_message  OUT VARCHAR2
    ) IS
        l_json JSON_OBJECT_T;
    BEGIN
        x_success       := FALSE;
        x_fusion_id     := NULL;
        x_error_message := NULL;

        IF p_http_status IN (200, 201) THEN
            -- Success: extract the Fusion-assigned ID from the response JSON.
            -- Fusion REST responses return the created/updated resource as a
            -- JSON object at the top level (not nested under "items").
            x_success := TRUE;

            IF p_response IS NOT NULL AND DBMS_LOB.GETLENGTH(p_response) > 0 THEN
                BEGIN
                    -- p_id_field is a runtime value, so the JSON path cannot be a
                    -- literal for JSON_VALUE (26ai rejects a concatenated path at
                    -- compile time). Use the PL/SQL JSON API, which takes a dynamic
                    -- key, instead.
                    l_json := JSON_OBJECT_T.parse(p_response);
                    IF l_json.has(p_id_field) THEN
                        x_fusion_id := l_json.get_Number(p_id_field);
                    END IF;
                EXCEPTION
                    WHEN OTHERS THEN
                        -- The ID field might not exist or might not be numeric.
                        -- This is not fatal for the success determination; the
                        -- caller can handle a NULL fusion_id if needed.
                        x_fusion_id := NULL;
                END;
            END IF;

        ELSE
            -- Failure: extract error detail from the Fusion error envelope.
            -- Fusion REST errors typically return:
            --   {"type":"...","title":"...","detail":"...","o:errorCode":"..."}
            -- or for validation errors:
            --   {"title":"...","detail":"...","o:errorDetails":[{"detail":"..."},...]}
            x_success := FALSE;

            IF p_response IS NOT NULL AND DBMS_LOB.GETLENGTH(p_response) > 0 THEN
                BEGIN
                    -- Try the top-level "detail" field first (most common)
                    SELECT JSON_VALUE(p_response, '$.detail'
                                      RETURNING VARCHAR2(4000))
                    INTO   x_error_message
                    FROM   DUAL;

                    -- If detail is empty, fall back to title
                    IF x_error_message IS NULL THEN
                        SELECT JSON_VALUE(p_response, '$.title'
                                          RETURNING VARCHAR2(4000))
                        INTO   x_error_message
                        FROM   DUAL;
                    END IF;

                    -- If still empty, try the first nested error detail
                    IF x_error_message IS NULL THEN
                        SELECT JSON_VALUE(p_response,
                                   '$."o:errorDetails"[0].detail'
                                   RETURNING VARCHAR2(4000))
                        INTO   x_error_message
                        FROM   DUAL;
                    END IF;
                EXCEPTION
                    WHEN OTHERS THEN
                        -- JSON parse failed; use the raw response (truncated)
                        x_error_message := 'HTTP ' || p_http_status ||
                                           ': ' || SUBSTR(p_response, 1, 2000);
                END;
            ELSE
                x_error_message := 'HTTP ' || p_http_status ||
                                   ' with empty response body.';
            END IF;

            -- Ensure we always have some error text
            IF x_error_message IS NULL THEN
                x_error_message := 'HTTP ' || p_http_status ||
                                   ' — no detail in response.';
            END IF;
        END IF;

    END PARSE_REST_RESPONSE;


    -- ============================================================
    -- LOAD_OBJECT_REST (STUB)
    -- ============================================================
    PROCEDURE LOAD_OBJECT_REST (
        p_object_code    IN VARCHAR2,
        p_run_id IN NUMBER
    ) IS
        l_proc VARCHAR2(100);
    BEGIN
        l_proc := NVL(p_object_code, 'REST') || ' > LOAD_OBJECT_REST';

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'REST pipeline not yet implemented for ' ||
                                NVL(p_object_code, '(null)') ||
                                '. Requires DMT_REST_OBJECT_CONFIG_TBL with ' ||
                                'endpoint and column-to-JSON mappings.',
            p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
            p_package        => C_PKG,
            p_procedure      => l_proc);

    END LOAD_OBJECT_REST;


END DMT_REST_LOADER_PKG;
/
