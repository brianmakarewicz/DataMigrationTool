-- PACKAGE BODY DMT_UTIL_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_UTIL_PKG" AS
-- ============================================================
-- DMT_UTIL_PKG Body
-- ============================================================

    -- --------------------------------------------------------
    -- Private: extract hostname from a full URL
    -- e.g. 'https://fa-esew-dev28.oraclecloud.com/fscmUI' -> 'fa-esew-dev28.oraclecloud.com'
    -- --------------------------------------------------------
    FUNCTION extract_host (p_url IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN REGEXP_SUBSTR(p_url, '://([^/]+)', 1, 1, 'i', 1);
    END extract_host;

    -- --------------------------------------------------------
    -- BASIC_AUTH_HEADER
    -- Build Basic Auth header value; credentials default to config.
    -- UTL_ENCODE.BASE64_ENCODE inserts a CR/LF every 64 output chars
    -- (i.e. beyond a 48-byte user:password), which corrupted the header
    -- into multiple lines — strip all CR/LF from the encoded value.
    -- --------------------------------------------------------
    FUNCTION BASIC_AUTH_HEADER (
        p_username IN VARCHAR2 DEFAULT NULL,
        p_password IN VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2 IS
        l_username  VARCHAR2(200);
        l_password  VARCHAR2(200);
        l_raw       RAW(600);
    BEGIN
        l_username := NVL(p_username, GET_CONFIG('FUSION_USERNAME'));
        l_password := NVL(p_password, GET_CONFIG('FUSION_PASSWORD'));

        IF l_username IS NULL OR l_password IS NULL THEN
            RAISE_APPLICATION_ERROR(-20002,
                'FUSION_USERNAME or FUSION_PASSWORD not set in DMT_CONFIG_TBL.');
        END IF;

        l_raw := UTL_ENCODE.BASE64_ENCODE(
                     UTL_RAW.CAST_TO_RAW(l_username || ':' || l_password));
        RETURN 'Basic ' || REPLACE(REPLACE(
                   UTL_RAW.CAST_TO_VARCHAR2(l_raw), CHR(13)), CHR(10));
    END BASIC_AUTH_HEADER;

    -- --------------------------------------------------------
    -- MASK_CREDENTIALS — redact credential material before logging.
    -- Masks the content of <...password...> / <...userID...> XML elements
    -- (any namespace prefix, any case) and Authorization header values.
    -- Every request-envelope log MUST route through this helper.
    -- --------------------------------------------------------
    FUNCTION MASK_CREDENTIALS (p_text IN CLOB) RETURN CLOB IS
        l_out CLOB;
    BEGIN
        IF p_text IS NULL THEN
            RETURN NULL;
        END IF;
        l_out := p_text;
        -- <v2:password>secret</v2:password>, <password>...</password>, etc.
        l_out := REGEXP_REPLACE(l_out,
            '(<([A-Za-z0-9_]+:)?password[^>]*>).*?(</([A-Za-z0-9_]+:)?password>)',
            '\1***MASKED***\3', 1, 0, 'in');
        -- <v2:userID>user</v2:userID> — masked with the password: the pair
        -- is a credential.
        l_out := REGEXP_REPLACE(l_out,
            '(<([A-Za-z0-9_]+:)?userID[^>]*>).*?(</([A-Za-z0-9_]+:)?userID>)',
            '\1***MASKED***\3', 1, 0, 'in');
        -- Authorization: Basic dXNlcjpwYXNz / Bearer eyJ... / raw token
        l_out := REGEXP_REPLACE(l_out,
            '(Authorization["'']?\s*[:=]\s*["'']?)((Basic|Bearer)\s+)?[A-Za-z0-9+/=._-]+',
            '\1***MASKED***', 1, 0, 'in');
        RETURN l_out;
    END MASK_CREDENTIALS;

    -- --------------------------------------------------------
    -- SET_FUSION_URL
    -- --------------------------------------------------------
    PROCEDURE SET_FUSION_URL (p_url IN VARCHAR2) IS
        l_old_url   DMT_OWNER.DMT_CONFIG_TBL.CONFIG_VALUE%TYPE;
        l_old_host  VARCHAR2(500);
        l_new_host  VARCHAR2(500);
    BEGIN
        l_new_host := extract_host(p_url);

        IF l_new_host IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001,
                'Invalid Fusion URL â€” could not extract hostname: ' || p_url);
        END IF;

        -- Retrieve existing URL (if any)
        BEGIN
            SELECT CONFIG_VALUE INTO l_old_url
            FROM   DMT_OWNER.DMT_CONFIG_TBL
            WHERE  CONFIG_KEY = 'FUSION_URL';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN l_old_url := NULL;
        END;

        -- Remove old ACL entry when URL is changing
        IF l_old_url IS NOT NULL AND l_old_url != p_url THEN
            l_old_host := extract_host(l_old_url);
            BEGIN
                DBMS_NETWORK_ACL_ADMIN.REMOVE_HOST_ACE(
                    host => l_old_host,
                    ace  => xs$ace_type(
                                privilege_list => xs$name_list('connect', 'resolve'),
                                principal_name => 'DMT_OWNER',
                                principal_type => xs_acl.ptype_db
                            )
                );
            EXCEPTION
                WHEN OTHERS THEN NULL; -- entry may not exist; safe to ignore
            END;
        END IF;

        -- Add ACL entry for new host
        BEGIN
            DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
                host => l_new_host,
                ace  => xs$ace_type(
                            privilege_list => xs$name_list('connect', 'resolve'),
                            principal_name => 'DMT_OWNER',
                            principal_type => xs_acl.ptype_db
                        )
            );
        EXCEPTION
            WHEN OTHERS THEN
                -- ORA-24244: ACL/ACE already exists for this host â€” safe to ignore
                IF SQLCODE != -24244 THEN RAISE; END IF;
        END;

        -- Upsert config row
        MERGE INTO DMT_OWNER.DMT_CONFIG_TBL t
        USING DUAL ON (t.CONFIG_KEY = 'FUSION_URL')
        WHEN MATCHED THEN
            UPDATE SET t.CONFIG_VALUE       = p_url,
                       t.LAST_UPDATED_DATE  = SYSDATE,
                       t.LAST_UPDATED_BY    = SYS_CONTEXT('USERENV', 'SESSION_USER')
        WHEN NOT MATCHED THEN
            INSERT (CONFIG_KEY, CONFIG_VALUE, DESCRIPTION, LAST_UPDATED_DATE, LAST_UPDATED_BY)
            VALUES ('FUSION_URL', p_url, 'Active Fusion instance base URL',
                    SYSDATE, SYS_CONTEXT('USERENV', 'SESSION_USER'));

        COMMIT;
    END SET_FUSION_URL;

    -- --------------------------------------------------------
    -- GET_CONFIG
    -- --------------------------------------------------------
    FUNCTION GET_CONFIG (p_key IN VARCHAR2) RETURN VARCHAR2 IS
        l_value DMT_OWNER.DMT_CONFIG_TBL.CONFIG_VALUE%TYPE;
    BEGIN
        SELECT CONFIG_VALUE INTO l_value
        FROM   DMT_OWNER.DMT_CONFIG_TBL
        WHERE  CONFIG_KEY = p_key;
        RETURN l_value;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN NULL;
    END GET_CONFIG;

    -- --------------------------------------------------------
    -- SET_CONFIG
    -- --------------------------------------------------------
    PROCEDURE SET_CONFIG (
        p_key         IN VARCHAR2,
        p_value       IN VARCHAR2,
        p_description IN VARCHAR2 DEFAULT NULL
    ) IS
    BEGIN
        MERGE INTO DMT_OWNER.DMT_CONFIG_TBL t
        USING DUAL ON (t.CONFIG_KEY = p_key)
        WHEN MATCHED THEN
            UPDATE SET t.CONFIG_VALUE       = p_value,
                       t.LAST_UPDATED_DATE  = SYSDATE,
                       t.LAST_UPDATED_BY    = SYS_CONTEXT('USERENV', 'SESSION_USER')
        WHEN NOT MATCHED THEN
            INSERT (CONFIG_KEY, CONFIG_VALUE, DESCRIPTION, LAST_UPDATED_DATE, LAST_UPDATED_BY)
            VALUES (p_key, p_value, p_description,
                    SYSDATE, SYS_CONTEXT('USERENV', 'SESSION_USER'));
        COMMIT;
    END SET_CONFIG;

    -- --------------------------------------------------------
    -- LOG
    -- PRAGMA AUTONOMOUS_TRANSACTION ensures log entries persist
    -- even if the calling transaction rolls back.
    -- Failure to log is swallowed â€” never let logging break the caller.
    -- --------------------------------------------------------
    PROCEDURE LOG (
        p_run_id IN NUMBER    DEFAULT NULL,
        p_message        IN VARCHAR2,
        p_log_type       IN VARCHAR2  DEFAULT 'INFO',
        p_package        IN VARCHAR2  DEFAULT NULL,
        p_procedure      IN VARCHAR2  DEFAULT NULL
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO DMT_OWNER.DMT_LOG_TBL (
            LOG_ID,
            RUN_ID,
            LOG_DATE,
            LOG_TYPE,
            PACKAGE_NAME,
            PROCEDURE_NAME,
            MESSAGE
        ) VALUES (
            DMT_OWNER.DMT_LOG_ID_SEQ.NEXTVAL,
            p_run_id,
            SYSDATE,
            NVL(p_log_type, 'INFO'),
            p_package,
            p_procedure,
            p_message
        );
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            -- Never propagate a logging failure to the caller
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('[DMT_UTIL_PKG.LOG FAILURE] ' || SQLERRM ||
                                 ' | Message was: ' || SUBSTR(p_message, 1, 200));
    END LOG;

    -- --------------------------------------------------------
    -- LOG_ERROR
    -- --------------------------------------------------------
    PROCEDURE LOG_ERROR (
        p_run_id IN NUMBER    DEFAULT NULL,
        p_message        IN VARCHAR2,
        p_sqlerrm        IN VARCHAR2,
        p_package        IN VARCHAR2  DEFAULT NULL,
        p_procedure      IN VARCHAR2  DEFAULT NULL
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO DMT_OWNER.DMT_LOG_TBL (
            LOG_ID,
            RUN_ID,
            LOG_DATE,
            LOG_TYPE,
            PACKAGE_NAME,
            PROCEDURE_NAME,
            MESSAGE,
            SQLERRM_TEXT
        ) VALUES (
            DMT_OWNER.DMT_LOG_ID_SEQ.NEXTVAL,
            p_run_id,
            SYSDATE,
            'ERROR',
            p_package,
            p_procedure,
            p_message,
            p_sqlerrm
        );
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('[DMT_UTIL_PKG.LOG_ERROR FAILURE] ' || SQLERRM);
    END LOG_ERROR;

    -- --------------------------------------------------------
    -- HTTP_REQUEST
    -- --------------------------------------------------------
    PROCEDURE HTTP_REQUEST (
        p_url            IN  VARCHAR2,
        p_method         IN  VARCHAR2,
        p_body           IN  CLOB        DEFAULT NULL,
        p_content_type   IN  VARCHAR2    DEFAULT 'application/json',
        p_run_id IN  NUMBER      DEFAULT NULL,
        x_response       OUT CLOB,
        x_status_code    OUT NUMBER,
        p_soap_action    IN  VARCHAR2    DEFAULT NULL,
        p_accept         IN  VARCHAR2    DEFAULT 'application/json',
        p_send_auth      IN  BOOLEAN     DEFAULT TRUE,
        p_raise_on_error IN  BOOLEAN     DEFAULT TRUE
    ) IS
        l_req       UTL_HTTP.REQ;
        l_resp      UTL_HTTP.RESP;
        l_buffer    VARCHAR2(32767);
        l_offset    INTEGER := 1;
        l_amount    INTEGER;
        l_body_len  INTEGER;
    BEGIN
        LOG(p_run_id => p_run_id,
            p_message        => 'HTTP ' || p_method || ' ' || p_url,
            p_log_type       => C_LOG_INFO,
            p_package        => 'DMT_UTIL_PKG',
            p_procedure      => 'HTTP_REQUEST');

        UTL_HTTP.SET_RESPONSE_ERROR_CHECK(FALSE);
        UTL_HTTP.SET_TRANSFER_TIMEOUT(600); -- 10 min for long Fusion operations

        l_req := UTL_HTTP.BEGIN_REQUEST(p_url, p_method, 'HTTP/1.1');
        -- SOAP callers whose credentials travel inside the envelope
        -- (BIP v2 userID/password elements) suppress the Basic header.
        IF p_send_auth THEN
            UTL_HTTP.SET_HEADER(l_req, 'Authorization', basic_auth_header);
        END IF;
        UTL_HTTP.SET_HEADER(l_req, 'Content-Type',   p_content_type);
        UTL_HTTP.SET_HEADER(l_req, 'Accept',         p_accept);
        IF p_soap_action IS NOT NULL THEN
            UTL_HTTP.SET_HEADER(l_req, 'SOAPAction', p_soap_action);
        END IF;

        -- Write request body in 8000-byte chunks
        IF p_body IS NOT NULL THEN
            l_body_len := DBMS_LOB.GETLENGTH(p_body);
            UTL_HTTP.SET_HEADER(l_req, 'Content-Length', TO_CHAR(l_body_len));
            l_offset := 1;
            WHILE l_offset <= l_body_len LOOP
                l_amount := LEAST(8000, l_body_len - l_offset + 1);
                UTL_HTTP.WRITE_TEXT(l_req, DBMS_LOB.SUBSTR(p_body, l_amount, l_offset));
                l_offset := l_offset + l_amount;
            END LOOP;
        END IF;

        -- Capture response
        l_resp := UTL_HTTP.GET_RESPONSE(l_req);
        x_status_code := l_resp.status_code;
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

        LOG(p_run_id => p_run_id,
            p_message        => 'HTTP response: ' || x_status_code || ' | ' || p_url,
            p_log_type       => CASE WHEN x_status_code BETWEEN 200 AND 299
                                     THEN C_LOG_INFO ELSE C_LOG_WARN END,
            p_package        => 'DMT_UTIL_PKG',
            p_procedure      => 'HTTP_REQUEST');

        -- Raise on non-2xx so callers do not have to check status themselves.
        -- Callers passing p_raise_on_error => FALSE map failures to their own
        -- documented error codes and MUST check x_status_code.
        IF p_raise_on_error AND x_status_code NOT BETWEEN 200 AND 299 THEN
            RAISE_APPLICATION_ERROR(-20003,
                'HTTP ' || p_method || ' failed. Status: ' || x_status_code ||
                ' | URL: ' || p_url ||
                ' | Response: ' || SUBSTR(x_response, 1, 500));
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            BEGIN UTL_HTTP.END_RESPONSE(l_resp); EXCEPTION WHEN OTHERS THEN NULL; END;
            LOG_ERROR(p_run_id => p_run_id,
                      p_message        => 'HTTP_REQUEST failed: ' || p_method || ' ' || p_url,
                      p_sqlerrm        => SQLERRM,
                      p_package        => 'DMT_UTIL_PKG',
                      p_procedure      => 'HTTP_REQUEST');
            RAISE;
    END HTTP_REQUEST;

    -- --------------------------------------------------------
    -- BIP_REQUEST
    -- Fetches a BIP report via the Fusion xmlpserver REST API.
    -- Endpoint: POST {FUSION_URL}/xmlpserver/services/rest/v1/reports
    -- Response contains reportBytes as a base64-encoded CSV (or other format).
    -- --------------------------------------------------------
    PROCEDURE BIP_REQUEST (
        p_report_path    IN  VARCHAR2,
        p_params         IN  VARCHAR2    DEFAULT NULL,
        p_output_format  IN  VARCHAR2    DEFAULT 'csv',
        p_run_id IN  NUMBER      DEFAULT NULL,
        x_report_data    OUT CLOB
    ) IS
        l_fusion_url    VARCHAR2(500);
        l_bip_url       VARCHAR2(1000);
        l_body          CLOB;
        l_response      CLOB;
        l_status_code   NUMBER;
        l_params_json   CLOB;
        l_param_token   VARCHAR2(500);
        l_param_name    VARCHAR2(200);
        l_param_value   VARCHAR2(200);
        l_pos           INTEGER;
        l_b64_start     INTEGER;
        l_b64_end       INTEGER;
        l_b64_data      CLOB;
        l_decoded_blob  BLOB;
        l_dest_off      INTEGER := 1;
        l_src_off       INTEGER := 1;
        l_lang_ctx      INTEGER := DBMS_LOB.DEFAULT_LANG_CTX;
        l_conv_warn     INTEGER;
    BEGIN
        LOG(p_run_id => p_run_id,
            p_message        => 'BIP_REQUEST start: ' || p_report_path,
            p_log_type       => C_LOG_INFO,
            p_package        => 'DMT_UTIL_PKG',
            p_procedure      => 'BIP_REQUEST');

        l_fusion_url := GET_CONFIG('FUSION_URL');
        IF l_fusion_url IS NULL THEN
            RAISE_APPLICATION_ERROR(-20004, 'FUSION_URL not configured in DMT_CONFIG_TBL.');
        END IF;

        l_bip_url := RTRIM(l_fusion_url, '/') || '/xmlpserver/services/rest/v1/reports';

        -- Build the parameters JSON array from pipe~tilde-delimited input
        -- Format: 'PARAM1|VALUE1~PARAM2|VALUE2'
        l_params_json := '';
        IF p_params IS NOT NULL THEN
            l_params_json := '"reportParameters": [';
            DECLARE
                l_remaining VARCHAR2(4000) := p_params;
                l_pair      VARCHAR2(500);
                l_first     BOOLEAN := TRUE;
            BEGIN
                WHILE l_remaining IS NOT NULL LOOP
                    l_pos := INSTR(l_remaining, '~');
                    IF l_pos > 0 THEN
                        l_pair      := SUBSTR(l_remaining, 1, l_pos - 1);
                        l_remaining := SUBSTR(l_remaining, l_pos + 1);
                    ELSE
                        l_pair      := l_remaining;
                        l_remaining := NULL;
                    END IF;

                    l_pos         := INSTR(l_pair, '|');
                    l_param_name  := SUBSTR(l_pair, 1, l_pos - 1);
                    l_param_value := SUBSTR(l_pair, l_pos + 1);

                    IF NOT l_first THEN l_params_json := l_params_json || ','; END IF;
                    l_params_json := l_params_json ||
                        '{"name":"' || l_param_name || '",' ||
                        '"values":["' || l_param_value || '"]}';
                    l_first := FALSE;
                END LOOP;
            END;
            l_params_json := l_params_json || '],';
        END IF;

        -- Build JSON request body
        l_body :=
            '{' ||
                '"reportAbsolutePath":"' || p_report_path || '",' ||
                l_params_json ||
                '"outputFormat":"' || p_output_format || '",' ||
                '"flattenXML":false' ||
            '}';

        HTTP_REQUEST(
            p_url            => l_bip_url,
            p_method         => 'POST',
            p_body           => l_body,
            p_content_type   => 'application/json',
            p_run_id => p_run_id,
            x_response       => l_response,
            x_status_code    => l_status_code
        );

        -- Extract reportBytes value from JSON response using DBMS_LOB
        -- Response format: {"reportBytes":"<base64>","reportContentType":"..."}
        l_b64_start := DBMS_LOB.INSTR(l_response, '"reportBytes":"') +
                       LENGTH('"reportBytes":"');
        l_b64_end   := DBMS_LOB.INSTR(l_response, '"', l_b64_start);

        IF l_b64_start <= LENGTH('"reportBytes":"') OR l_b64_end = 0 THEN
            RAISE_APPLICATION_ERROR(-20005,
                'BIP response did not contain reportBytes. ' ||
                'Report: ' || p_report_path ||
                ' Response (first 500): ' || DBMS_LOB.SUBSTR(l_response, 500, 1));
        END IF;

        DBMS_LOB.CREATETEMPORARY(l_b64_data, TRUE);
        DBMS_LOB.COPY(l_b64_data, l_response, l_b64_end - l_b64_start, 1, l_b64_start);

        -- Decode via the central whitespace-safe decoder (BASE64_DECODE_CLOB),
        -- then convert the bytes to CLOB. The previous inline decoder aligned
        -- its 4-char quanta over RAW chunk positions without stripping the
        -- CR/LF line breaks base64 streams legally carry — the same bug family
        -- BASE64_DECODE_CLOB exists to fix (silent corruption beyond one chunk).
        l_decoded_blob := BASE64_DECODE_CLOB(l_b64_data);
        DBMS_LOB.FREETEMPORARY(l_b64_data);

        DBMS_LOB.CREATETEMPORARY(x_report_data, TRUE);
        IF DBMS_LOB.GETLENGTH(l_decoded_blob) > 0 THEN
            DBMS_LOB.CONVERTTOCLOB(
                dest_lob     => x_report_data,
                src_blob     => l_decoded_blob,
                amount       => DBMS_LOB.LOBMAXSIZE,
                dest_offset  => l_dest_off,
                src_offset   => l_src_off,
                blob_csid    => DBMS_LOB.DEFAULT_CSID,
                lang_context => l_lang_ctx,
                warning      => l_conv_warn);
        END IF;
        IF DBMS_LOB.ISTEMPORARY(l_decoded_blob) = 1 THEN
            DBMS_LOB.FREETEMPORARY(l_decoded_blob);
        END IF;

        LOG(p_run_id => p_run_id,
            p_message        => 'BIP_REQUEST complete: ' || p_report_path ||
                                ' | Data length: ' || DBMS_LOB.GETLENGTH(x_report_data),
            p_log_type       => C_LOG_INFO,
            p_package        => 'DMT_UTIL_PKG',
            p_procedure      => 'BIP_REQUEST');

    EXCEPTION
        WHEN OTHERS THEN
            LOG_ERROR(p_run_id => p_run_id,
                      p_message        => 'BIP_REQUEST failed: ' || p_report_path,
                      p_sqlerrm        => SQLERRM,
                      p_package        => 'DMT_UTIL_PKG',
                      p_procedure      => 'BIP_REQUEST');
            RAISE;
    END BIP_REQUEST;

    -- --------------------------------------------------------
    -- (Retired per-CEMLI prefix functions GET_PREFIX /
    --  INCREMENT_AND_GET_PREFIX removed 2026-07-08, Stage C prefix
    --  consolidation — design section 6: one prefix per run from
    --  DMT_RUN_PREFIX_SEQ, stored on DMT_PIPELINE_RUN_TBL.PREFIX.)
    -- --------------------------------------------------------

    -- --------------------------------------------------------
    -- PREFIXED â€” prefix + value, truncated to fit column width
    -- --------------------------------------------------------
    FUNCTION PREFIXED (
        p_prefix  IN VARCHAR2,
        p_value   IN VARCHAR2,
        p_max_len IN NUMBER DEFAULT 240
    ) RETURN VARCHAR2 DETERMINISTIC IS
        l_pfx VARCHAR2(20) := NVL(p_prefix, '');
    BEGIN
        IF p_value IS NULL THEN
            RETURN NULL;
        END IF;
        RETURN SUBSTR(l_pfx || p_value, 1, p_max_len);
    END PREFIXED;

    -- --------------------------------------------------------
    -- GET_CEMLI_CREDENTIALS
    -- Resolve Fusion credentials for a CEMLI.
    -- Priority: options table override > config table default.
    -- --------------------------------------------------------
    PROCEDURE GET_CEMLI_CREDENTIALS (
        p_cemli_code IN  VARCHAR2,
        x_username   OUT VARCHAR2,
        x_password   OUT VARCHAR2
    ) IS
    BEGIN
        IF p_cemli_code IS NOT NULL THEN
            BEGIN
                SELECT FUSION_USERNAME, FUSION_PASSWORD
                INTO   x_username, x_password
                FROM   DMT_OWNER.DMT_ERP_INTERFACE_OPTIONS_TBL
                WHERE  CEMLI_CODE = p_cemli_code;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    x_username := NULL;
                    x_password := NULL;
            END;
        END IF;

        -- Fall back to config defaults if the options table had NULL
        x_username := NVL(x_username, GET_CONFIG('FUSION_USERNAME'));
        x_password := NVL(x_password, GET_CONFIG('FUSION_PASSWORD'));
    END GET_CEMLI_CREDENTIALS;

    -- --------------------------------------------------------
    -- GET_CREDENTIALS_FOR_REQUEST
    -- Resolve credentials from an ESS request_id by tracing back
    -- to the CEMLI that submitted it.
    -- --------------------------------------------------------
    PROCEDURE GET_CREDENTIALS_FOR_REQUEST (
        p_request_id IN  NUMBER,
        x_username   OUT VARCHAR2,
        x_password   OUT VARCHAR2
    ) IS
        l_cemli VARCHAR2(100);
    BEGIN
        BEGIN
            SELECT j.CEMLI_CODE INTO l_cemli
            FROM   DMT_OWNER.DMT_ESS_JOB_TBL j
            WHERE  j.REQUEST_ID = p_request_id
            AND    ROWNUM = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_cemli := NULL;
        END;

        GET_CEMLI_CREDENTIALS(l_cemli, x_username, x_password);
    END GET_CREDENTIALS_FOR_REQUEST;

    -- --------------------------------------------------------
    -- APPEND_ERROR
    -- --------------------------------------------------------
    FUNCTION APPEND_ERROR (
        p_existing  IN CLOB,
        p_new_error IN VARCHAR2
    ) RETURN CLOB IS
    BEGIN
        IF p_existing IS NULL OR DBMS_LOB.GETLENGTH(p_existing) = 0 THEN
            RETURN TO_CLOB(p_new_error);
        ELSE
            RETURN p_existing || ' | ' || p_new_error;
        END IF;
    END APPEND_ERROR;

    -- --------------------------------------------------------
    -- CLOB_TO_BLOB
    -- Null-safe: returns an empty BLOB for NULL or zero-length input.
    -- --------------------------------------------------------
    FUNCTION CLOB_TO_BLOB (p_clob IN CLOB) RETURN BLOB IS
        l_blob         BLOB;
        l_dest_offset  INTEGER := 1;
        l_src_offset   INTEGER := 1;
        l_lang_context INTEGER := DBMS_LOB.DEFAULT_LANG_CTX;
        l_warning      INTEGER;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_blob, TRUE);
        IF p_clob IS NULL OR DBMS_LOB.GETLENGTH(p_clob) = 0 THEN
            RETURN l_blob;
        END IF;
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
    END CLOB_TO_BLOB;

    -- --------------------------------------------------------
    -- BASE64_ENCODE
    -- --------------------------------------------------------
    FUNCTION BASE64_ENCODE (p_blob IN BLOB) RETURN CLOB IS
        l_clob    CLOB;
        l_raw     RAW(12000);
        l_offset  INTEGER := 1;
        l_amount  INTEGER;
        l_length  INTEGER;
    BEGIN
        l_length := DBMS_LOB.GETLENGTH(p_blob);
        IF l_length IS NULL OR l_length = 0 THEN
            RETURN EMPTY_CLOB();
        END IF;

        DBMS_LOB.CREATETEMPORARY(l_clob, TRUE);

        WHILE l_offset <= l_length LOOP
            -- 12000 bytes â€” multiple of 3 to avoid base64 padding mid-stream
            l_amount := LEAST(12000, l_length - l_offset + 1);
            DBMS_LOB.READ(p_blob, l_amount, l_offset, l_raw);
            -- Trim to actual bytes read (DBMS_LOB.READ updates l_amount)
            DBMS_LOB.APPEND(l_clob,
                TO_CLOB(UTL_RAW.CAST_TO_VARCHAR2(
                    UTL_ENCODE.BASE64_ENCODE(l_raw))));
            l_offset := l_offset + l_amount;
        END LOOP;

        RETURN l_clob;
    END BASE64_ENCODE;

    -- --------------------------------------------------------
    -- BASE64_DECODE_CLOB â€” decode a base64 CLOB of any size to BLOB.
    -- Processes in 4-char-aligned chunks (base64 is 4-char quantized),
    -- so the whole payload decodes correctly regardless of length.
    -- --------------------------------------------------------
    FUNCTION BASE64_DECODE_CLOB (p_b64 IN CLOB) RETURN BLOB IS
        l_blob      BLOB;
        l_offset    INTEGER := 1;
        l_len       INTEGER;
        l_chunk_len INTEGER;
        l_buf       VARCHAR2(32767);   -- carry + whitespace-stripped chunk
        l_carry     VARCHAR2(3) := '';
        l_take      INTEGER;
        -- Raw chars read per pass. Base64 streams legally contain CR/LF
        -- line breaks (UTL_ENCODE emits one every 64 chars; BIP responses
        -- carry them too), so the 4-char quantum alignment must be computed
        -- AFTER stripping whitespace — counting raw chars mis-aligned every
        -- chunk after the first and corrupted any payload > one chunk.
        C_CHUNK     CONSTANT INTEGER := 24000;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_blob, TRUE);
        IF p_b64 IS NULL THEN
            RETURN l_blob;
        END IF;
        l_len := DBMS_LOB.GETLENGTH(p_b64);
        WHILE l_offset <= l_len LOOP
            l_chunk_len := LEAST(C_CHUNK, l_len - l_offset + 1);
            -- strip CR/LF/tab/space so only real base64 chars are counted,
            -- then prepend the 0-3 char remainder carried from the last pass
            l_buf := l_carry || REPLACE(REPLACE(REPLACE(REPLACE(
                         DBMS_LOB.SUBSTR(p_b64, l_chunk_len, l_offset),
                         CHR(13)), CHR(10)), CHR(9)), ' ');
            l_offset := l_offset + l_chunk_len;
            -- decode whole 4-char quanta; on the final pass decode everything
            l_take := TRUNC(NVL(LENGTH(l_buf), 0) / 4) * 4;
            IF l_offset > l_len THEN
                l_take := NVL(LENGTH(l_buf), 0);
            END IF;
            IF l_take > 0 THEN
                DBMS_LOB.APPEND(l_blob,
                    UTL_ENCODE.BASE64_DECODE(
                        UTL_RAW.CAST_TO_RAW(SUBSTR(l_buf, 1, l_take))));
            END IF;
            l_carry := SUBSTR(l_buf, l_take + 1);
        END LOOP;
        RETURN l_blob;
    END BASE64_DECODE_CLOB;

    -- --------------------------------------------------------
    -- BIP_REPORT_XML â€” extract <reportBytes> from a BIP SOAP response CLOB,
    -- decode (any size) and return as XMLTYPE. NULL when no <reportBytes>.
    -- Shared replacement for each reconciler's local b64_to_clob + the
    -- VARCHAR2(32767) reportBytes extraction (the truncation bug).
    -- --------------------------------------------------------
    FUNCTION BIP_REPORT_XML (p_soap_response IN CLOB) RETURN XMLTYPE IS
        C_PROC      CONSTANT VARCHAR2(30) := 'BIP_REPORT_XML';
        l_b64_start INTEGER;
        l_b64_end   INTEGER;
        l_b64       CLOB;
        l_blob      BLOB;
        l_xmlclob   CLOB;
        l_dest      INTEGER := 1;
        l_src       INTEGER := 1;
        l_lang      INTEGER := DBMS_LOB.DEFAULT_LANG_CTX;
        l_warn      INTEGER;
    BEGIN
        IF p_soap_response IS NULL THEN
            RETURN NULL;
        END IF;
        l_b64_start := DBMS_LOB.INSTR(p_soap_response, '<reportBytes>');
        IF l_b64_start = 0 THEN
            RETURN NULL;   -- no rows â€” caller applies its no-rows policy
        END IF;
        l_b64_start := l_b64_start + LENGTH('<reportBytes>');
        l_b64_end   := DBMS_LOB.INSTR(p_soap_response, '</reportBytes>', l_b64_start);
        IF l_b64_end = 0 OR l_b64_end <= l_b64_start THEN
            RAISE_APPLICATION_ERROR(-20035, C_PROC || ': Malformed <reportBytes>.');
        END IF;
        DBMS_LOB.CREATETEMPORARY(l_b64, TRUE);
        DBMS_LOB.COPY(l_b64, p_soap_response, l_b64_end - l_b64_start, 1, l_b64_start);
        BEGIN
            l_blob := BASE64_DECODE_CLOB(l_b64);
            DBMS_LOB.FREETEMPORARY(l_b64);
            DBMS_LOB.CREATETEMPORARY(l_xmlclob, TRUE);
            DBMS_LOB.CONVERTTOCLOB(l_xmlclob, l_blob, DBMS_LOB.LOBMAXSIZE,
                l_dest, l_src, DBMS_LOB.DEFAULT_CSID, l_lang, l_warn);
            DBMS_LOB.FREETEMPORARY(l_blob);
            RETURN XMLTYPE(l_xmlclob);
        EXCEPTION
            WHEN OTHERS THEN
                RAISE_APPLICATION_ERROR(-20036,
                    C_PROC || ': Failed to decode/parse BIP report bytes. Error: ' || SQLERRM);
        END;
    END BIP_REPORT_XML;

    -- --------------------------------------------------------
    -- RUN_BIP_REPORT â€” run a deployed BIP report (SOAP v2 ReportService)
    -- through the shared HTTP_REQUEST transport and return its data as
    -- XMLTYPE via x_report_xml. Centralised replacement for the
    -- per-reconciler bip_soap_post + FETCH_BIP_RESULTS + b64_to_clob +
    -- <reportBytes> extraction. x_report_xml NULL with x_error_code =
    -- C_SUCCESS means no <reportBytes> (zero rows) â€” the caller applies
    -- its own no-rows policy. PROCEDURE per the section 7 procedures-only
    -- contract: every failure is caught here, logged with the step in
    -- flight, and reported through x_error_code; exceptions never escape.
    -- The request envelope carries credentials and is NEVER logged.
    -- --------------------------------------------------------
    PROCEDURE RUN_BIP_REPORT (
        p_run_id      IN  NUMBER,
        p_cemli_code  IN  VARCHAR2,
        p_params      IN  VARCHAR2,
        x_report_xml  OUT XMLTYPE,
        x_error_code  OUT NUMBER,
        p_report_path IN  VARCHAR2 DEFAULT NULL
    ) IS
        C_PROC   CONSTANT VARCHAR2(30) := 'RUN_BIP_REPORT';
        C_ACTION CONSTANT VARCHAR2(200) :=
            'http://xmlns.oracle.com/oxp/service/v2/ReportService/runReportRequest';
        l_step      VARCHAR2(500);
        l_base_url  VARCHAR2(500);
        l_user      VARCHAR2(100);
        l_pass      VARCHAR2(100);
        l_path      VARCHAR2(500);
        l_items     CLOB;
        l_env       CLOB;
        l_resp      CLOB;
        l_status    NUMBER;
        l_rem       VARCHAR2(4000) := p_params;
        l_pair      VARCHAR2(600);
        l_pos       INTEGER;
        l_pname     VARCHAR2(200);
        l_pval      VARCHAR2(2000);
    BEGIN
        x_report_xml := NULL;
        x_error_code := C_ERROR;   -- pessimistic until proven successful

        l_step := 'reading Fusion BIP connection config';
        l_base_url := RTRIM(GET_CONFIG('FUSION_URL'), '/');
        l_user := NVL(GET_CONFIG('BIP_USERNAME'), GET_CONFIG('FUSION_USERNAME'));
        l_pass := NVL(GET_CONFIG('BIP_PASSWORD'), GET_CONFIG('FUSION_PASSWORD'));
        IF l_base_url IS NULL OR l_user IS NULL OR l_pass IS NULL THEN
            RAISE_APPLICATION_ERROR(-20031, C_PROC || ': Fusion BIP connection config incomplete.');
        END IF;

        l_step := 'resolving report catalog path for CEMLI ' || p_cemli_code;
        l_path := p_report_path;
        IF l_path IS NULL THEN
            BEGIN
                SELECT REPORT_CATALOG_PATH INTO l_path
                FROM   DMT_OWNER.DMT_BIP_REPORT_TBL
                WHERE  CEMLI_CODE = p_cemli_code;
            EXCEPTION WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20032,
                    C_PROC || ': No DMT_BIP_REPORT_TBL row for CEMLI_CODE=' || p_cemli_code);
            END;
        END IF;
        IF l_path IS NULL THEN
            RAISE_APPLICATION_ERROR(-20033, C_PROC || ': REPORT_CATALOG_PATH NULL for ' || p_cemli_code);
        END IF;

        -- Build parameterNameValues items from 'NAME|VAL~NAME2|VAL2'
        l_step := 'building runReport parameter list';
        DBMS_LOB.CREATETEMPORARY(l_items, TRUE);
        WHILE l_rem IS NOT NULL LOOP
            l_pos := INSTR(l_rem, '~');
            IF l_pos > 0 THEN
                l_pair := SUBSTR(l_rem, 1, l_pos - 1);
                l_rem  := SUBSTR(l_rem, l_pos + 1);
            ELSE
                l_pair := l_rem;
                l_rem  := NULL;
            END IF;
            IF l_pair IS NOT NULL THEN
                l_pos   := INSTR(l_pair, '|');
                l_pname := SUBSTR(l_pair, 1, l_pos - 1);
                l_pval  := SUBSTR(l_pair, l_pos + 1);
                DBMS_LOB.APPEND(l_items, TO_CLOB(
                    '<v2:item><v2:name>' || l_pname || '</v2:name>' ||
                    '<v2:values><v2:item>' || l_pval || '</v2:item></v2:values></v2:item>'));
            END IF;
        END LOOP;

        l_step := 'building runReport SOAP envelope for ' || l_path;
        DBMS_LOB.CREATETEMPORARY(l_env, TRUE);
        DBMS_LOB.APPEND(l_env, TO_CLOB(
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' ||
            'xmlns:v2="http://xmlns.oracle.com/oxp/service/v2">' ||
            '<soapenv:Header/><soapenv:Body><v2:runReport><v2:reportRequest>' ||
            '<v2:reportAbsolutePath>' || l_path || '</v2:reportAbsolutePath>' ||
            '<v2:attributeFormat>xml</v2:attributeFormat>' ||
            '<v2:parameterNameValues><v2:listOfParamNameValues>'));
        DBMS_LOB.APPEND(l_env, l_items);
        DBMS_LOB.APPEND(l_env, TO_CLOB(
            '</v2:listOfParamNameValues></v2:parameterNameValues>' ||
            '<v2:sizeOfDataChunkDownload>-1</v2:sizeOfDataChunkDownload>' ||
            '</v2:reportRequest>' ||
            '<v2:userID>' || l_user || '</v2:userID>' ||
            '<v2:password>' || l_pass || '</v2:password>' ||
            '</v2:runReport></soapenv:Body></soapenv:Envelope>'));
        DBMS_LOB.FREETEMPORARY(l_items);

        -- Shared transport: credentials travel in the envelope (no Basic
        -- header); non-2xx comes back as x_status_code so this procedure
        -- maps it to its documented -20030 code below.
        l_step := 'posting runReport to BIP for ' || l_path;
        HTTP_REQUEST(
            p_url            => l_base_url || '/xmlpserver/services/v2/ReportService',
            p_method         => 'POST',
            p_body           => l_env,
            p_content_type   => 'text/xml; charset=utf-8',
            p_run_id         => p_run_id,
            x_response       => l_resp,
            x_status_code    => l_status,
            p_soap_action    => '"' || C_ACTION || '"',
            p_accept         => 'text/xml',
            p_send_auth      => FALSE,
            p_raise_on_error => FALSE);
        DBMS_LOB.FREETEMPORARY(l_env);

        l_step := 'checking BIP response status/fault for ' || l_path;
        IF l_status NOT BETWEEN 200 AND 299 THEN
            RAISE_APPLICATION_ERROR(-20030,
                C_PROC || ': BIP SOAP HTTP ' || l_status || ' for ' || l_path ||
                ' | ' || DBMS_LOB.SUBSTR(l_resp, 400, 1));
        END IF;
        IF DBMS_LOB.INSTR(l_resp, 'soapenv:Fault') > 0
           OR DBMS_LOB.INSTR(l_resp, 'soap:Fault') > 0 THEN
            RAISE_APPLICATION_ERROR(-20034,
                C_PROC || ': SOAP Fault from BIP for ' || l_path || ' | ' ||
                DBMS_LOB.SUBSTR(l_resp, 1000, 1));
        END IF;

        -- Extract <reportBytes> + decode + parse via the shared helper.
        l_step := 'decoding reportBytes for ' || l_path;
        x_report_xml := BIP_REPORT_XML(l_resp);
        x_error_code := C_SUCCESS;
    EXCEPTION
        WHEN OTHERS THEN
            x_report_xml := NULL;
            x_error_code := C_ERROR;
            LOG_ERROR(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ' failed while ' || l_step ||
                               ' | CEMLI: ' || NVL(p_cemli_code, '(path only)'),
                p_sqlerrm   => SQLERRM,
                p_package   => 'DMT_UTIL_PKG',
                p_procedure => C_PROC);
    END RUN_BIP_REPORT;

    -- --------------------------------------------------------
    -- GET_OR_CREATE_SCENARIO
    -- PROCEDURE per the section 7 procedures-only contract (writes
    -- rows). NULL name passes through as a NULL id with C_SUCCESS;
    -- failures are logged here and reported via x_error_code —
    -- exceptions never escape. Does not commit.
    -- --------------------------------------------------------
    PROCEDURE GET_OR_CREATE_SCENARIO (
        p_scenario_name IN  VARCHAR2,
        x_scenario_id   OUT NUMBER,
        x_error_code    OUT NUMBER
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'GET_OR_CREATE_SCENARIO';
        l_step VARCHAR2(500);
    BEGIN
        x_scenario_id := NULL;
        x_error_code  := C_SUCCESS;

        IF p_scenario_name IS NULL THEN
            RETURN;
        END IF;

        l_step := 'looking up scenario "' || p_scenario_name || '"';
        BEGIN
            SELECT SCENARIO_ID INTO x_scenario_id
            FROM DMT_SCENARIO_TBL
            WHERE UPPER(SCENARIO_NAME) = UPPER(TRIM(p_scenario_name));
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_step := 'creating scenario "' || p_scenario_name || '"';
                INSERT INTO DMT_SCENARIO_TBL (SCENARIO_NAME)
                VALUES (TRIM(p_scenario_name))
                RETURNING SCENARIO_ID INTO x_scenario_id;
        END;
    EXCEPTION
        WHEN OTHERS THEN
            x_scenario_id := NULL;
            x_error_code  := C_ERROR;
            LOG_ERROR(
                p_message   => C_PROC || ' failed while ' || l_step,
                p_sqlerrm   => SQLERRM,
                p_package   => 'DMT_UTIL_PKG',
                p_procedure => C_PROC);
    END GET_OR_CREATE_SCENARIO;

    -- --------------------------------------------------------
    -- GET_DEEP_LINK
    -- Builds a Fusion deep link URL for a specific record.
    -- Returns NULL if the CEMLI has no deep link configured,
    -- if FUSION_URL is not set, or if p_fusion_id is NULL.
    -- --------------------------------------------------------
    FUNCTION GET_DEEP_LINK (
        p_cemli_code IN VARCHAR2,
        p_fusion_id  IN VARCHAR2
    ) RETURN VARCHAR2
    IS
        v_base_url    VARCHAR2(500);
        v_obj_type    VARCHAR2(100);
        v_key_tmpl    VARCHAR2(500);
        v_ui_path     VARCHAR2(50);
    BEGIN
        IF p_fusion_id IS NULL THEN
            RETURN NULL;
        END IF;

        -- Get Fusion base URL
        v_base_url := GET_CONFIG('FUSION_URL');
        IF v_base_url IS NULL THEN
            RETURN NULL;
        END IF;

        -- Get deep link config for this CEMLI
        BEGIN
            SELECT DEEP_LINK_OBJ_TYPE, DEEP_LINK_KEY_TEMPLATE
            INTO   v_obj_type, v_key_tmpl
            FROM   DMT_OWNER.DMT_BIP_REPORT_TBL
            WHERE  CEMLI_CODE = p_cemli_code;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN RETURN NULL;
        END;

        IF v_obj_type IS NULL THEN
            RETURN NULL;
        END IF;

        -- REST_API type: direct REST URL (for demo instances where deep links don't work)
        IF v_obj_type = 'REST_API' THEN
            RETURN RTRIM(v_base_url, '/') || REPLACE(v_key_tmpl, '{ID}', p_fusion_id);
        END IF;

        -- HCM objects use hcmUI, ERP objects use fscmUI.
        IF p_cemli_code LIKE '%Worker%'
           OR p_cemli_code LIKE '%Salary%'
           OR p_cemli_code LIKE '%Assignment%'
           OR p_cemli_code LIKE '%Absence%'
           OR p_cemli_code LIKE '%Benefit%'
           OR p_cemli_code LIKE '%TaxCard%'
           OR p_cemli_code LIKE '%TalentProfile%'
           OR p_cemli_code LIKE '%PerfEval%'
           OR p_cemli_code LIKE '%WorkSchedule%' THEN
            v_ui_path := '/hcmUI/faces/deeplink';
        ELSE
            v_ui_path := '/fscmUI/faces/deeplink';
        END IF;

        RETURN RTRIM(v_base_url, '/') || v_ui_path ||
               '?objType=' || v_obj_type ||
               '&objKey=' || REPLACE(v_key_tmpl, '{ID}', p_fusion_id);
    END GET_DEEP_LINK;

    -- --------------------------------------------------------
    -- REFRESH_LOOKUPS (generic)
    -- Runs all registered lookup BIP DMs via DMT_BIP_DEPLOY_PKG
    -- and MERGEs results into DMT_LOOKUP_TBL.
    -- Each DM must return: LOOKUP_TYPE, LOOKUP_CODE,
    -- LOOKUP_VALUE, LOOKUP_VALUE2 in a G_LKP group.
    -- --------------------------------------------------------
    PROCEDURE REFRESH_LOOKUPS IS
        C_PKG  CONSTANT VARCHAR2(30) := 'DMT_UTIL_PKG';
        C_PROC CONSTANT VARCHAR2(30) := 'REFRESH_LOOKUPS';

        TYPE t_dm_rec IS RECORD (
            dm_name VARCHAR2(100),
            xdm_xml CLOB
        );
        TYPE t_dm_list IS TABLE OF t_dm_rec;
        l_dms t_dm_list := t_dm_list();

        l_resp     CLOB;
        l_xml       XMLTYPE;
        l_merged    NUMBER;
        l_total     NUMBER := 0;

        -- Standard BU lookup DM
        C_BU_XDM CONSTANT CLOB :=
'<?xml version="1.0" encoding="utf-8"?>'||CHR(10)||
'<dataModel xmlns="http://xmlns.oracle.com/oxp/xmlp" version="2.1" defaultDataSourceRef="ApplicationDB_FSCM">'||CHR(10)||
'<dataProperties><property name="include_parameters" value="true"/><property name="include_null_Element" value="true"/><property name="include_rowsettag" value="false"/><property name="xml_tag_case" value="upper"/></dataProperties>'||CHR(10)||
'<dataSets><dataSet name="bu_lookups" type="complex"><sql dataSourceRef="ApplicationDB_FSCM"><![CDATA['||
'SELECT ''BU'' AS LOOKUP_TYPE, bu.bu_name AS LOOKUP_CODE, TO_CHAR(bu.bu_id) AS LOOKUP_VALUE, TO_CHAR(bu.primary_ledger_id) AS LOOKUP_VALUE2 FROM fun_all_business_units_v bu WHERE bu.status = ''A'' ORDER BY bu.bu_name'||
']]></sql></dataSet></dataSets>'||CHR(10)||
'<output rootName="DATA_DS" uniqueRowName="false"><nodeList name="data-structure"><dataStructure tagName="DATA_DS"><group name="G_LKP" label="G_LKP" source="bu_lookups">'||
'<element name="LOOKUP_TYPE" value="LOOKUP_TYPE" dataType="xsd:string" tagName="LOOKUP_TYPE"/>'||
'<element name="LOOKUP_CODE" value="LOOKUP_CODE" dataType="xsd:string" tagName="LOOKUP_CODE"/>'||
'<element name="LOOKUP_VALUE" value="LOOKUP_VALUE" dataType="xsd:string" tagName="LOOKUP_VALUE"/>'||
'<element name="LOOKUP_VALUE2" value="LOOKUP_VALUE2" dataType="xsd:string" tagName="LOOKUP_VALUE2"/>'||
'</group></dataStructure></nodeList></output><eventTriggers/><lexicals/><valueSets/><bursting/></dataModel>';

        -- Standard Ledger lookup DM
        C_LEDGER_XDM CONSTANT CLOB :=
'<?xml version="1.0" encoding="utf-8"?>'||CHR(10)||
'<dataModel xmlns="http://xmlns.oracle.com/oxp/xmlp" version="2.1" defaultDataSourceRef="ApplicationDB_FSCM">'||CHR(10)||
'<dataProperties><property name="include_parameters" value="true"/><property name="include_null_Element" value="true"/><property name="include_rowsettag" value="false"/><property name="xml_tag_case" value="upper"/></dataProperties>'||CHR(10)||
'<dataSets><dataSet name="ledger_lookups" type="complex"><sql dataSourceRef="ApplicationDB_FSCM"><![CDATA['||
'SELECT ''LEDGER'' AS LOOKUP_TYPE, gl.name AS LOOKUP_CODE, TO_CHAR(gl.ledger_id) AS LOOKUP_VALUE, '||
'TO_CHAR((SELECT MIN(gas.access_set_id) FROM gl_access_sets gas WHERE gas.default_ledger_id = gl.ledger_id AND gas.automatically_created_flag = ''Y'')) AS LOOKUP_VALUE2 '||
'FROM gl_ledgers gl WHERE gl.object_type_code = ''L'' ORDER BY gl.name'||
']]></sql></dataSet></dataSets>'||CHR(10)||
'<output rootName="DATA_DS" uniqueRowName="false"><nodeList name="data-structure"><dataStructure tagName="DATA_DS"><group name="G_LKP" label="G_LKP" source="ledger_lookups">'||
'<element name="LOOKUP_TYPE" value="LOOKUP_TYPE" dataType="xsd:string" tagName="LOOKUP_TYPE"/>'||
'<element name="LOOKUP_CODE" value="LOOKUP_CODE" dataType="xsd:string" tagName="LOOKUP_CODE"/>'||
'<element name="LOOKUP_VALUE" value="LOOKUP_VALUE" dataType="xsd:string" tagName="LOOKUP_VALUE"/>'||
'<element name="LOOKUP_VALUE2" value="LOOKUP_VALUE2" dataType="xsd:string" tagName="LOOKUP_VALUE2"/>'||
'</group></dataStructure></nodeList></output><eventTriggers/><lexicals/><valueSets/><bursting/></dataModel>';

    BEGIN
        LOG(p_message => C_PROC || ' start.', p_package => C_PKG, p_procedure => C_PROC);

        -- Register all lookup DMs
        l_dms.EXTEND(2);
        l_dms(1).dm_name := 'DMT_BU_LKP_DM';     l_dms(1).xdm_xml := C_BU_XDM;
        l_dms(2).dm_name := 'DMT_LEDGER_LKP_DM';  l_dms(2).xdm_xml := C_LEDGER_XDM;

        FOR i IN 1..l_dms.COUNT LOOP
            LOG(p_message => C_PROC || ': running ' || l_dms(i).dm_name,
                p_package => C_PKG, p_procedure => C_PROC);

            l_resp := DMT_BIP_DEPLOY_PKG.RUN_DATA_MODEL(
                p_xdm_name => l_dms(i).dm_name,
                p_xdm_xml  => l_dms(i).xdm_xml
            );

            -- Extract + decode reportBytes via the shared any-size extractor
            -- (was another inline whitespace-unsafe 4-aligned chunk decoder —
            -- the same >32K corruption bug family BASE64_DECODE_CLOB fixes)
            l_xml := BIP_REPORT_XML(l_resp);
            IF l_xml IS NULL THEN
                LOG(p_message => C_PROC || ': No reportBytes for ' || l_dms(i).dm_name || '. Skipping.',
                    p_log_type => C_LOG_WARN, p_package => C_PKG, p_procedure => C_PROC);
                CONTINUE;
            END IF;

            -- MERGE into DMT_LOOKUP_TBL (dedup by type+code+value)
            MERGE INTO DMT_OWNER.DMT_LOOKUP_TBL tgt
            USING (
                SELECT lookup_type, lookup_code, lookup_value, lookup_value2
                FROM (
                    SELECT x.lookup_type, x.lookup_code, x.lookup_value, x.lookup_value2,
                           ROW_NUMBER() OVER (PARTITION BY x.lookup_type, x.lookup_code, x.lookup_value
                                              ORDER BY x.lookup_code) AS rn
                    FROM XMLTABLE('/DATA_DS/G_LKP' PASSING l_xml
                        COLUMNS
                            lookup_type  VARCHAR2(100) PATH 'LOOKUP_TYPE',
                            lookup_code  VARCHAR2(500) PATH 'LOOKUP_CODE',
                            lookup_value VARCHAR2(500) PATH 'LOOKUP_VALUE',
                            lookup_value2 VARCHAR2(500) PATH 'LOOKUP_VALUE2'
                    ) x
                    WHERE x.lookup_code IS NOT NULL
                ) WHERE rn = 1
            ) src ON (tgt.LOOKUP_TYPE = src.lookup_type
                  AND tgt.LOOKUP_CODE = src.lookup_code
                  AND tgt.LOOKUP_VALUE = src.lookup_value)
            WHEN MATCHED THEN
                UPDATE SET tgt.LOOKUP_VALUE2 = src.lookup_value2,
                           tgt.LAST_UPDATED_DATE = SYSDATE
            WHEN NOT MATCHED THEN
                INSERT (LOOKUP_TYPE, LOOKUP_CODE, LOOKUP_VALUE, LOOKUP_VALUE2)
                VALUES (src.lookup_type, src.lookup_code, src.lookup_value, src.lookup_value2);

            l_merged := SQL%ROWCOUNT;
            l_total := l_total + l_merged;
            COMMIT;

            LOG(p_message => C_PROC || ': ' || l_dms(i).dm_name || ' complete. ' || l_merged || ' rows merged.',
                p_package => C_PKG, p_procedure => C_PROC);

            IF l_resp IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_resp) = 1 THEN
                DBMS_LOB.FREETEMPORARY(l_resp);
            END IF;
        END LOOP;

        LOG(p_message => C_PROC || ' complete. ' || l_total || ' total lookup rows refreshed.',
            p_package => C_PKG, p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            LOG_ERROR(p_message => C_PROC || ' failed.', p_sqlerrm => SQLERRM,
                      p_package => C_PKG, p_procedure => C_PROC);
            RAISE;
    END REFRESH_LOOKUPS;

    -- --------------------------------------------------------
    -- REFRESH_BU_LOOKUPS (legacy alias)
    -- --------------------------------------------------------
    PROCEDURE REFRESH_BU_LOOKUPS IS
    BEGIN
        REFRESH_LOOKUPS;
    END REFRESH_BU_LOOKUPS;

END DMT_UTIL_PKG;
/
