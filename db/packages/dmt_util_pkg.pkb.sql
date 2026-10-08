-- PACKAGE BODY DMT_UTIL_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_UTIL_PKG" AS
-- ============================================================
-- DMT_UTIL_PKG Body
-- ============================================================

    -- Session log context (see SET_LOG_CONTEXT). Session-scoped package
    -- globals: each child-job session sets its own, so there is no leakage
    -- across work items. LOG / LOG_ERROR read these to stamp every row.
    g_ctx_run_id   NUMBER;
    g_ctx_queue_id NUMBER;

    PROCEDURE SET_LOG_CONTEXT (
        p_run_id   IN NUMBER,
        p_queue_id IN NUMBER DEFAULT NULL
    ) IS
    BEGIN
        g_ctx_run_id   := p_run_id;
        g_ctx_queue_id := p_queue_id;
    END SET_LOG_CONTEXT;

    PROCEDURE CLEAR_LOG_CONTEXT IS
    BEGIN
        g_ctx_run_id   := NULL;
        g_ctx_queue_id := NULL;
    END CLEAR_LOG_CONTEXT;

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
    -- Build Basic Auth header value. The caller passes a user+password PAIR
    -- (from GET_CEMLI_CREDENTIALS); passing neither means the run-scoped
    -- default user, resolved by GET_CEMLI_CREDENTIALS(NULL). Passing only
    -- one half raises -20002: halves are never mixed (backlog #309).
    -- UTL_ENCODE.BASE64_ENCODE inserts a CR/LF every 64 output chars
    -- (i.e. beyond a 48-byte user:password), which corrupted the header
    -- into multiple lines — strip all CR/LF from the encoded value.
    -- --------------------------------------------------------
    FUNCTION BASIC_AUTH_HEADER (
        p_username IN VARCHAR2 DEFAULT NULL,
        p_password IN VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2 IS
        l_username  VARCHAR2(200);
        l_password  VARCHAR2(500);
        l_raw       RAW(2000);
    BEGIN
        IF p_username IS NULL AND p_password IS NULL THEN
            GET_CEMLI_CREDENTIALS(p_cemli_code => NULL,
                                  x_username   => l_username,
                                  x_password   => l_password);
        ELSIF p_username IS NULL OR p_password IS NULL THEN
            RAISE_APPLICATION_ERROR(-20002,
                'BASIC_AUTH_HEADER: a Fusion username and password must be passed together.');
        ELSE
            l_username := p_username;
            l_password := p_password;
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
        l_old_url   DMT_CONFIG_TBL.CONFIG_VALUE%TYPE;
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
            FROM   DMT_CONFIG_TBL
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
                                principal_name => USER,  -- connected schema (schema-relative)
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
                            principal_name => USER,  -- connected schema (schema-relative)
                            principal_type => xs_acl.ptype_db
                        )
            );
        EXCEPTION
            WHEN OTHERS THEN
                -- ORA-24244: ACL/ACE already exists for this host â€” safe to ignore
                IF SQLCODE != -24244 THEN RAISE; END IF;
        END;

        -- Upsert config row
        MERGE INTO DMT_CONFIG_TBL t
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
        l_value DMT_CONFIG_TBL.CONFIG_VALUE%TYPE;
    BEGIN
        SELECT CONFIG_VALUE INTO l_value
        FROM   DMT_CONFIG_TBL
        WHERE  CONFIG_KEY = p_key;
        RETURN l_value;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN NULL;
    END GET_CONFIG;

    -- --------------------------------------------------------
    -- SHOULD_VALIDATE_UPSTREAM (Backlog #142)
    -- Per-run Validate-Upstream flag. Reads the run row first; only
    -- when the run row carries no explicit value does it fall back to
    -- the (retired) global DMT_CONFIG_TBL switch, so an older run row
    -- written before this column existed still behaves predictably.
    -- Any value other than 'Y' (including NULL) resolves to 'N'.
    -- --------------------------------------------------------
    FUNCTION SHOULD_VALIDATE_UPSTREAM (p_run_id IN NUMBER) RETURN VARCHAR2 IS
        l_flag DMT_PIPELINE_RUN_TBL.VALIDATE_UPSTREAM%TYPE;
    BEGIN
        IF p_run_id IS NULL THEN
            RETURN CASE WHEN GET_CONFIG('VALIDATE_UPSTREAM_DEPS') = 'Y' THEN 'Y' ELSE 'N' END;
        END IF;

        SELECT VALIDATE_UPSTREAM INTO l_flag
        FROM   DMT_PIPELINE_RUN_TBL
        WHERE  RUN_ID = p_run_id;

        IF l_flag IS NULL THEN
            RETURN CASE WHEN GET_CONFIG('VALIDATE_UPSTREAM_DEPS') = 'Y' THEN 'Y' ELSE 'N' END;
        END IF;

        RETURN CASE WHEN l_flag = 'Y' THEN 'Y' ELSE 'N' END;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN CASE WHEN GET_CONFIG('VALIDATE_UPSTREAM_DEPS') = 'Y' THEN 'Y' ELSE 'N' END;
    END SHOULD_VALIDATE_UPSTREAM;

    -- --------------------------------------------------------
    -- GET_DEPENDENT_PREFIX (Backlog #142)
    -- The run's explicit Dependent-Run override when set, else the
    -- run's own PREFIX (the prior automatic behavior).
    -- --------------------------------------------------------
    FUNCTION GET_DEPENDENT_PREFIX (p_run_id IN NUMBER) RETURN VARCHAR2 IS
        l_dep_prefix DMT_PIPELINE_RUN_TBL.DEPENDENT_PREFIX%TYPE;
        l_own_prefix DMT_PIPELINE_RUN_TBL.PREFIX%TYPE;
    BEGIN
        SELECT DEPENDENT_PREFIX, PREFIX
        INTO   l_dep_prefix, l_own_prefix
        FROM   DMT_PIPELINE_RUN_TBL
        WHERE  RUN_ID = p_run_id;

        RETURN NVL(l_dep_prefix, l_own_prefix);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN NULL;
    END GET_DEPENDENT_PREFIX;

    -- --------------------------------------------------------
    -- SET_CONFIG
    -- --------------------------------------------------------
    PROCEDURE SET_CONFIG (
        p_key         IN VARCHAR2,
        p_value       IN VARCHAR2,
        p_description IN VARCHAR2 DEFAULT NULL
    ) IS
    BEGIN
        MERGE INTO DMT_CONFIG_TBL t
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
        INSERT INTO DMT_LOG_TBL (
            LOG_ID,
            RUN_ID,
            QUEUE_ID,
            LOG_DATE,
            LOG_TYPE,
            PACKAGE_NAME,
            PROCEDURE_NAME,
            MESSAGE
        ) VALUES (
            DMT_LOG_ID_SEQ.NEXTVAL,
            NVL(p_run_id, g_ctx_run_id),
            g_ctx_queue_id,
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
        INSERT INTO DMT_LOG_TBL (
            LOG_ID,
            RUN_ID,
            QUEUE_ID,
            LOG_DATE,
            LOG_TYPE,
            PACKAGE_NAME,
            PROCEDURE_NAME,
            MESSAGE,
            SQLERRM_TEXT
        ) VALUES (
            DMT_LOG_ID_SEQ.NEXTVAL,
            NVL(p_run_id, g_ctx_run_id),
            g_ctx_queue_id,
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
        p_raise_on_error IN  BOOLEAN     DEFAULT TRUE,
        p_auth_header    IN  VARCHAR2    DEFAULT NULL
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
            -- p_auth_header lets a caller probe a SPECIFIC credential
            -- (VERIFY_CREDENTIAL); NULL = the default user from GET_CEMLI_CREDENTIALS(NULL).
            UTL_HTTP.SET_HEADER(l_req, 'Authorization', NVL(p_auth_header, basic_auth_header));
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
    -- STG_ROW_SELECTED  (backlog item #44)
    -- One shared mode-driven selection predicate for all phases. See spec in
    -- the package header. Deterministic so it is safe and cheap to call inside
    -- a WHERE clause. RETRY is retired; a row can only be NEW, TRANSFORMED or
    -- FAILED, so NEW mode maps to STG_STATUS = 'NEW' only.
    -- --------------------------------------------------------
    FUNCTION STG_ROW_SELECTED (
        p_run_mode   IN VARCHAR2,
        p_stg_status IN VARCHAR2
    ) RETURN VARCHAR2 DETERMINISTIC IS
    BEGIN
        RETURN CASE
                   WHEN p_run_mode = 'NEW'    AND p_stg_status = 'NEW'    THEN 'Y'
                   WHEN p_run_mode = 'FAILED' AND p_stg_status = 'FAILED' THEN 'Y'
                   WHEN p_run_mode = 'ALL'                                THEN 'Y'
                   ELSE 'N'
               END;
    END STG_ROW_SELECTED;

    -- --------------------------------------------------------
    -- GET_CEMLI_CREDENTIALS -- THE central Fusion user resolver (backlog #309).
    -- Every Fusion call DMT makes for an object (upload, ESS submit/poll/
    -- download, BIP, REST, HDL) gets its user here. The username and password
    -- are taken TOGETHER from ONE place (backlog #303):
    --   * the object's DMT_ERP_INTERFACE_OPTIONS_TBL row when that row names a
    --     FUSION_USERNAME -- both halves from that row;
    --   * otherwise (no row, or a row with no username) both halves from the
    --     default user, DMT_CONFIG_TBL FUSION_USERNAME / FUSION_PASSWORD.
    -- A password on a row without a username is ignored, never paired with
    -- the default username. p_cemli_code NULL = the run-scoped default user.
    -- An incomplete pair (missing or still-masked password) raises -20002
    -- instead of sending one user with another user's password.
    -- --------------------------------------------------------
    PROCEDURE GET_CEMLI_CREDENTIALS (
        p_cemli_code IN  VARCHAR2,
        x_username   OUT VARCHAR2,
        x_password   OUT VARCHAR2
    ) IS
        C_MASKED   CONSTANT VARCHAR2(30) := '***MASKED-SET-ME***';
        l_row_user DMT_ERP_INTERFACE_OPTIONS_TBL.FUSION_USERNAME%TYPE;
        l_row_pass DMT_ERP_INTERFACE_OPTIONS_TBL.FUSION_PASSWORD%TYPE;
    BEGIN
        -- CEMLI_CODE is unique (DMT_ERP_INT_OPT_TBL_UQ), so MAX() reads the
        -- zero-or-one row without a NO_DATA_FOUND handler; both columns come
        -- from that same row.
        SELECT MAX(o.FUSION_USERNAME), MAX(o.FUSION_PASSWORD)
        INTO   l_row_user, l_row_pass
        FROM   DMT_ERP_INTERFACE_OPTIONS_TBL o
        WHERE  o.CEMLI_CODE = p_cemli_code;

        IF l_row_user IS NOT NULL THEN
            x_username := l_row_user;
            x_password := l_row_pass;
        ELSE
            x_username := GET_CONFIG('FUSION_USERNAME');
            x_password := GET_CONFIG('FUSION_PASSWORD');
        END IF;

        IF x_username IS NULL OR x_password IS NULL OR x_password = C_MASKED THEN
            RAISE_APPLICATION_ERROR(-20002,
                'GET_CEMLI_CREDENTIALS: incomplete Fusion credential for '
                || NVL(p_cemli_code, 'the default user') || ' (user '
                || NVL(x_username, '<none>') || ' has no password set). '
                || 'Run db/tools/setup_runtime_config.py.');
        END IF;
    END GET_CEMLI_CREDENTIALS;

    -- --------------------------------------------------------
    -- GET_CREDENTIALS_FOR_REQUEST
    -- Resolve credentials from an ESS request_id: find the CEMLI that owns
    -- the request (DMT_ESS_JOB_TBL, else the work item that submitted it as
    -- its load, import or post-run job) and hand it to GET_CEMLI_CREDENTIALS.
    -- A request DMT never recorded resolves to the default user.
    -- --------------------------------------------------------
    PROCEDURE GET_CREDENTIALS_FOR_REQUEST (
        p_request_id IN  NUMBER,
        x_username   OUT VARCHAR2,
        x_password   OUT VARCHAR2
    ) IS
        l_cemli DMT_ESS_JOB_TBL.CEMLI_CODE%TYPE;
    BEGIN
        SELECT MAX(src.CEMLI_CODE) KEEP (DENSE_RANK FIRST ORDER BY src.SRC_ORDER)
        INTO   l_cemli
        FROM  (SELECT j.CEMLI_CODE, 1 AS SRC_ORDER
               FROM   DMT_ESS_JOB_TBL j
               WHERE  j.REQUEST_ID = p_request_id
               AND    j.CEMLI_CODE IS NOT NULL
               UNION ALL
               SELECT q.CEMLI_CODE, 2 AS SRC_ORDER
               FROM   DMT_WORK_QUEUE_TBL q
               WHERE  TO_CHAR(p_request_id) IN (q.LOAD_ESS_JOB_ID,
                                                q.IMPORT_ESS_JOB_ID,
                                                q.POSTRUN_ESS_JOB_ID)) src;

        GET_CEMLI_CREDENTIALS(p_cemli_code => l_cemli,
                              x_username   => x_username,
                              x_password   => x_password);
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
    -- FORMAT_DOCUMENT_ERROR -- see spec. Pure value converter.
    -- --------------------------------------------------------
    FUNCTION FORMAT_DOCUMENT_ERROR (
        p_source_grain IN VARCHAR2,
        p_source_key   IN VARCHAR2,
        p_source_msg   IN VARCHAR2
    ) RETURN VARCHAR2 DETERMINISTIC IS
        C_TAG CONSTANT VARCHAR2(20) := '[FUSION_ERROR] ';
    BEGIN
        IF p_source_msg IS NULL THEN
            RETURN NULL;
        END IF;
        RETURN SUBSTR(C_TAG || C_DOC_ERROR_MARKER || p_source_grain || ' ' || p_source_key
                      || ': '
                      || CASE WHEN SUBSTR(p_source_msg, 1, LENGTH(C_TAG)) = C_TAG
                              THEN SUBSTR(p_source_msg, LENGTH(C_TAG) + 1)
                              ELSE p_source_msg
                         END,
                      1, 4000);
    END FORMAT_DOCUMENT_ERROR;

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
    -- GUNZIP_RESPONSE
    -- Turn a (possibly gzip-compressed) HTTP response BLOB into readable text.
    --
    -- Why this exists: Fusion sometimes gzip-compresses error bodies even when
    -- the request asked for identity encoding. The REST reconcilers used to
    -- read the response with UTL_HTTP.READ_TEXT and stash it straight into
    -- ERROR_TEXT, so a compressed body became unreadable binary and the real
    -- 400/404 rejection message was lost. The reconcilers now read the raw
    -- bytes into a BLOB and hand them here.
    --
    -- gzip framing (RFC 1952): a 10-byte header, then a raw DEFLATE stream,
    -- then an 8-byte trailer (CRC32 + ISIZE). On this database's Oracle version
    -- UTL_COMPRESS.LZ_UNCOMPRESS reads a whole gzip stream directly, so we feed
    -- it the untouched bytes and render the result as AL32UTF8 text.
    --
    -- We only attempt inflation when the bytes carry the gzip magic number
    -- (0x1F 0x8B); anything else is already text and is returned unchanged.
    --
    -- Never raises: any failure (not gzip, unexpected framing, inflate error)
    -- falls back to returning the raw bytes as text, so a reconcile is never
    -- crashed by an undecodable body.
    -- --------------------------------------------------------
    FUNCTION GUNZIP_RESPONSE (p_raw IN BLOB) RETURN CLOB IS
        l_len       INTEGER;
        l_magic     RAW(2);
        l_out       BLOB;
        l_clob      CLOB;

        -- Return a BLOB rendered as text (AL32UTF8) via a temporary CLOB.
        FUNCTION blob_to_text (p_b IN BLOB) RETURN CLOB IS
            l_c   CLOB;
            l_do  INTEGER := 1;
            l_so  INTEGER := 1;
            l_lc  INTEGER := DBMS_LOB.DEFAULT_LANG_CTX;
            l_w   INTEGER;
        BEGIN
            DBMS_LOB.CREATETEMPORARY(l_c, TRUE);
            IF p_b IS NULL OR DBMS_LOB.GETLENGTH(p_b) = 0 THEN
                RETURN l_c;
            END IF;
            DBMS_LOB.CONVERTTOCLOB(
                dest_lob     => l_c,
                src_blob     => p_b,
                amount       => DBMS_LOB.LOBMAXSIZE,
                dest_offset  => l_do,
                src_offset   => l_so,
                blob_csid    => NLS_CHARSET_ID('AL32UTF8'),
                lang_context => l_lc,
                warning      => l_w);
            RETURN l_c;
        END blob_to_text;
    BEGIN
        IF p_raw IS NULL OR DBMS_LOB.GETLENGTH(p_raw) = 0 THEN
            DBMS_LOB.CREATETEMPORARY(l_clob, TRUE);
            RETURN l_clob;
        END IF;

        l_len   := DBMS_LOB.GETLENGTH(p_raw);
        l_magic := DBMS_LOB.SUBSTR(p_raw, 2, 1);

        -- Not gzip (no 1F 8B magic) -> return the bytes as text unchanged.
        IF l_magic <> HEXTORAW('1F8B') OR l_len <= 18 THEN
            RETURN blob_to_text(p_raw);
        END IF;

        BEGIN
            -- LZ_UNCOMPRESS inflates the whole gzip stream on this version.
            l_out  := UTL_COMPRESS.LZ_UNCOMPRESS(p_raw);
            l_clob := blob_to_text(l_out);
            IF DBMS_LOB.ISTEMPORARY(l_out) = 1 THEN DBMS_LOB.FREETEMPORARY(l_out); END IF;
            RETURN l_clob;
        EXCEPTION
            WHEN OTHERS THEN
                -- Inflation failed for any reason: fall back to raw text so the
                -- reconcile still gets *something* and never crashes.
                BEGIN IF DBMS_LOB.ISTEMPORARY(l_out) = 1 THEN DBMS_LOB.FREETEMPORARY(l_out); END IF; EXCEPTION WHEN OTHERS THEN NULL; END;
                RETURN blob_to_text(p_raw);
        END;
    END GUNZIP_RESPONSE;

    -- --------------------------------------------------------
    -- REGISTER_CSV: persist one physical CSV as a child of a zip.
    -- --------------------------------------------------------
    PROCEDURE REGISTER_CSV (
        p_run_id      IN NUMBER,
        p_fbdi_zip_id IN NUMBER,
        p_file_seq    IN NUMBER,
        p_object_type IN VARCHAR2,
        p_filename    IN VARCHAR2,
        p_row_count   IN NUMBER,
        p_csv         IN CLOB,
        x_fbdi_csv_id OUT NUMBER
    ) IS
    BEGIN
        SELECT DMT_FBDI_CSV_ID_SEQ.NEXTVAL INTO x_fbdi_csv_id FROM DUAL;
        INSERT INTO DMT_FBDI_CSV_TBL (
            FBDI_CSV_ID, FBDI_ZIP_ID, FILE_SEQ, RUN_ID, OBJECT_TYPE,
            FILENAME, ROW_COUNT, CSV_CONTENT, CREATED_DATE
        ) VALUES (
            x_fbdi_csv_id, p_fbdi_zip_id, p_file_seq, p_run_id, p_object_type,
            p_filename, p_row_count, p_csv, SYSDATE
        );
    END REGISTER_CSV;

    -- --------------------------------------------------------
    -- BUILD_ZIP_FROM_CSVS: zip the persisted CSV rows for a zip id
    -- (in FILE_SEQ order), insert the DMT_FBDI_ZIP_TBL row, return the BLOB.
    -- The zip bytes come from DMT_FBDI_CSV_TBL.CSV_CONTENT -- so the archive
    -- is provably what is persisted, not a separate in-memory copy.
    -- --------------------------------------------------------
    PROCEDURE BUILD_ZIP_FROM_CSVS (
        p_run_id       IN  NUMBER,
        p_fbdi_zip_id  IN  NUMBER,
        p_object_type  IN  VARCHAR2,
        p_zip_filename IN  VARCHAR2,
        x_fbdi_zip     OUT BLOB,
        x_zip_bytes    OUT NUMBER
    ) IS
        l_zip         BLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_zip, TRUE);
        FOR r IN (
            SELECT FILENAME, CSV_CONTENT
            FROM   DMT_FBDI_CSV_TBL
            WHERE  FBDI_ZIP_ID = p_fbdi_zip_id
            ORDER BY FILE_SEQ
        ) LOOP
            UTL_ZIP.add1file(l_zip, r.FILENAME, CLOB_TO_BLOB(r.CSV_CONTENT));
        END LOOP;
        UTL_ZIP.finish_zip(l_zip);

        -- The zip's CSV members live in DMT_FBDI_CSV_TBL keyed by FBDI_ZIP_ID; the
        -- loader stamps PARAMETER_LIST by FBDI_ZIP_ID (looked up from the primary
        -- csv id), so the zip row no longer carries a FBDI_CSV_ID pointer.
        x_zip_bytes := DBMS_LOB.GETLENGTH(l_zip);
        INSERT INTO DMT_FBDI_ZIP_TBL (
            FBDI_ZIP_ID, RUN_ID, OBJECT_TYPE, FILENAME,
            ZIP_SIZE_BYTES, ZIP_CONTENT, CREATED_DATE
        ) VALUES (
            p_fbdi_zip_id, p_run_id, p_object_type, p_zip_filename,
            x_zip_bytes, l_zip, SYSDATE
        );
        x_fbdi_zip := l_zip;
    END BUILD_ZIP_FROM_CSVS;

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
    --
    -- TRANSIENT TRANSPORT RESILIENCE (Backlog #148). The runReport POST is
    -- wrapped in a BOUNDED retry that fires ONLY on transient TRANSPORT
    -- faults, so a single network/connection blip no longer fails a whole
    -- object's reconcile (regression run 225: one ORA-29273 'HTTP request
    -- failed' stranded Item Category rows that the identical call loaded in
    -- run 205). The failure is classified:
    --   * TRANSPORT fault (transient -> retried): HTTP_REQUEST raised
    --     (UTL_HTTP/ORA-29273, connection reset, ORA-12xxx), OR a
    --     transport-level HTTP 5xx carrying no valid SOAP body. runReport is
    --     read-only, so re-POSTing is side-effect free.
    --   * SOAP FAULT (NOT transient -> raised immediately, NEVER retried):
    --     a well-formed SOAP response containing soapenv:Fault / soap:Fault
    --     (e.g. wrong report name, report error). Honors the standing rule
    --     bip_soap_fault_handling -- a SOAP fault means a real problem.
    --   * Other non-2xx with no SOAP body (e.g. 4xx client error): NOT
    --     transient -> raised on the first occurrence, no retry.
    -- Attempts are bounded by 1 + BIP_TRANSPORT_MAX_RETRIES (default 2),
    -- each retry preceded by a BIP_TRANSPORT_BACKOFF_SECONDS wait
    -- (default 3); both read from DMT_CONFIG_TBL via GET_CONFIG. The loop
    -- cannot spin forever (fixed FOR bound). When retries are exhausted on a
    -- transport fault, it raises -20030 and the WHEN OTHERS below reports
    -- C_ERROR as before.
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
        l_user      VARCHAR2(500);
        l_pass      VARCHAR2(500);
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
        -- Backlog #148: bounded retry on TRANSIENT TRANSPORT faults only.
        -- A transport fault is a network/connection blip on the runReport
        -- POST (UTL_HTTP/ORA-29273 'HTTP request failed', connection reset,
        -- ORA-12xxx connect errors, or a transport-level HTTP 5xx that
        -- carries no valid SOAP body). These are transient and safe to
        -- re-POST: runReport is READ-ONLY (it just renders a report), so a
        -- re-POST has no side effects. A BIP SOAP FAULT (a well-formed SOAP
        -- response carrying soapenv:Fault / soap:Fault -- e.g. wrong report
        -- name, report error) is NOT transient: it still raises immediately
        -- and is NEVER retried (standing rule bip_soap_fault_handling). A
        -- non-5xx non-2xx HTTP status with no SOAP body (e.g. a 4xx client
        -- error) is also NOT transient and raises on the first occurrence.
        -- Attempt budget and backoff come from DMT_CONFIG_TBL via GET_CONFIG;
        -- see the BIP_TRANSPORT_* keys in db/seed/dmt_config_tbl.sql.
        l_max_retries    PLS_INTEGER;
        l_backoff_secs   PLS_INTEGER;
        l_posted_ok      BOOLEAN := FALSE;
        l_transient_err  VARCHAR2(4000);
    BEGIN
        x_report_xml := NULL;
        x_error_code := C_ERROR;   -- pessimistic until proven successful

        l_step := 'reading Fusion BIP connection config';
        l_base_url := RTRIM(GET_CONFIG('FUSION_URL'), '/');
        -- The report runs as the object's central Fusion user (backlog #309),
        -- the same user that loaded the object; never a separate BIP user.
        GET_CEMLI_CREDENTIALS(p_cemli_code => p_cemli_code,
                              x_username   => l_user,
                              x_password   => l_pass);
        IF l_base_url IS NULL OR l_user IS NULL OR l_pass IS NULL THEN
            RAISE_APPLICATION_ERROR(-20031, C_PROC || ': Fusion BIP connection config incomplete.');
        END IF;

        l_step := 'resolving report catalog path for CEMLI ' || p_cemli_code;
        l_path := p_report_path;
        IF l_path IS NULL THEN
            BEGIN
                SELECT REPORT_CATALOG_PATH INTO l_path
                FROM   DMT_BIP_REPORT_TBL
                WHERE  CEMLI_CODE = p_cemli_code;
            EXCEPTION WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20032,
                    C_PROC || ': No DMT_BIP_REPORT_TBL row for CEMLI_CODE=' || p_cemli_code);
            END;
        END IF;
        IF l_path IS NULL THEN
            RAISE_APPLICATION_ERROR(-20033, C_PROC || ': REPORT_CATALOG_PATH NULL for ' || p_cemli_code);
        END IF;

        -- Deploy-drift guard: DMT2 reports live under /Custom/DMT2/. A resolved
        -- /Custom/DMT/... path means the local BIP registry still points at the
        -- frozen stack's folder (a seed change was pulled but the DB seed was not
        -- re-run), so the reconciler would silently run the old interface-only
        -- report. Warn loudly rather than fail — the run can still proceed.
        IF l_path LIKE '/Custom/DMT/%' THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message => C_PROC || ': WARNING — BIP report path for ' || p_cemli_code ||
                    ' resolved to the frozen-stack folder ''' || l_path ||
                    '''. DMT2 reports belong under /Custom/DMT2/. Re-run the BIP registry seed ' ||
                    '(db/seed/dmt_bip_report_tbl.sql) to converge this DB.',
                p_log_type => DMT_UTIL_PKG.C_LOG_WARN,
                p_package => 'DMT_UTIL_PKG',
                p_procedure => C_PROC);
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

        -- Attempt budget + backoff (Backlog #148). GET_CONFIG returns NULL
        -- when a key is absent, so NVL supplies the documented defaults
        -- (2 retries, 3-second backoff). A non-numeric value is treated as
        -- the default rather than blowing up the reconcile. A negative or
        -- absent retry count means "no retries" (one attempt).
        l_step := 'reading BIP transport retry config';
        -- A non-numeric config value raises VALUE_ERROR (ORA-06502) from
        -- TO_NUMBER in PL/SQL; fall back to the default rather than failing.
        BEGIN
            l_max_retries := GREATEST(0, TO_NUMBER(NVL(GET_CONFIG('BIP_TRANSPORT_MAX_RETRIES'), '2')));
        EXCEPTION WHEN VALUE_ERROR THEN l_max_retries := 2;
        END;
        BEGIN
            l_backoff_secs := GREATEST(0, TO_NUMBER(NVL(GET_CONFIG('BIP_TRANSPORT_BACKOFF_SECONDS'), '3')));
        EXCEPTION WHEN VALUE_ERROR THEN l_backoff_secs := 3;
        END;

        -- Shared transport: credentials travel in the envelope (no Basic
        -- header); non-2xx comes back as x_status_code so this procedure
        -- maps it to its documented -20030 code below. The POST sits inside
        -- a bounded retry loop that fires ONLY on transient transport faults
        -- (see the variable-section note). A SOAP fault or a non-5xx HTTP
        -- error breaks out and raises on the first occurrence -- never
        -- retried. runReport is read-only so re-POST is side-effect free.
        -- Total attempts = 1 + l_max_retries.
        FOR l_attempt IN 0 .. l_max_retries LOOP
            l_transient_err := NULL;
            l_step := 'posting runReport to BIP for ' || l_path ||
                      ' (attempt ' || (l_attempt + 1) || ' of ' || (l_max_retries + 1) || ')';
            BEGIN
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
            EXCEPTION
                WHEN OTHERS THEN
                    -- HTTP_REQUEST raised (UTL_HTTP/ORA-29273, connection
                    -- reset, ORA-12xxx). This is a TRANSPORT fault: there is
                    -- no SOAP body to inspect, so it is transient by
                    -- definition and eligible for retry.
                    l_transient_err := SQLERRM;
            END;

            IF l_transient_err IS NULL THEN
                l_step := 'checking BIP response status/fault for ' || l_path;
                -- A SOAP Fault only exists inside a well-formed SOAP body
                -- (which BIP returns with HTTP 200). Classify it FIRST and
                -- raise immediately -- it is a real problem, NOT transient,
                -- and is NEVER retried (bip_soap_fault_handling).
                IF DBMS_LOB.INSTR(l_resp, 'soapenv:Fault') > 0
                   OR DBMS_LOB.INSTR(l_resp, 'soap:Fault') > 0 THEN
                    RAISE_APPLICATION_ERROR(-20034,
                        C_PROC || ': SOAP Fault from BIP for ' || l_path || ' | ' ||
                        DBMS_LOB.SUBSTR(l_resp, 1000, 1));
                END IF;

                IF l_status BETWEEN 200 AND 299 THEN
                    l_posted_ok := TRUE;
                    EXIT;                       -- success
                ELSIF l_status BETWEEN 500 AND 599 THEN
                    -- Transport-level HTTP 5xx with no SOAP body: a
                    -- server/gateway blip, treated as transient and retried.
                    l_transient_err := 'BIP SOAP HTTP ' || l_status || ' (no SOAP body) for ' ||
                                       l_path || ' | ' || DBMS_LOB.SUBSTR(l_resp, 400, 1);
                ELSE
                    -- Any other non-2xx (e.g. 4xx client error) is NOT
                    -- transient: raise on the first occurrence, no retry.
                    RAISE_APPLICATION_ERROR(-20030,
                        C_PROC || ': BIP SOAP HTTP ' || l_status || ' for ' || l_path ||
                        ' | ' || DBMS_LOB.SUBSTR(l_resp, 400, 1));
                END IF;
            END IF;

            -- Reached here only on a classified TRANSPORT fault. Retry if
            -- the budget allows, else fall through and raise below.
            IF l_attempt < l_max_retries THEN
                LOG(p_run_id => p_run_id,
                    p_message => C_PROC || ': transient BIP transport fault for ' || l_path ||
                        ' on attempt ' || (l_attempt + 1) || ' of ' || (l_max_retries + 1) ||
                        '; retrying after ' || l_backoff_secs || 's backoff. Detail: ' ||
                        SUBSTR(l_transient_err, 1, 500),
                    p_log_type => C_LOG_WARN,
                    p_package => 'DMT_UTIL_PKG',
                    p_procedure => C_PROC);
                IF l_backoff_secs > 0 THEN
                    DBMS_SESSION.SLEEP(l_backoff_secs);
                END IF;
            END IF;
        END LOOP;

        DBMS_LOB.FREETEMPORARY(l_env);

        -- Exhausted the attempt budget on a transport fault: raise now.
        IF NOT l_posted_ok THEN
            l_step := 'BIP runReport transport fault exhausted retries for ' || l_path;
            RAISE_APPLICATION_ERROR(-20030,
                C_PROC || ': BIP runReport failed after ' || (l_max_retries + 1) ||
                ' attempt(s) on transient transport fault for ' || l_path ||
                ' | ' || SUBSTR(l_transient_err, 1, 1000));
        END IF;

        -- Extract <reportBytes> + decode + parse via the shared helper.
        l_step := 'decoding reportBytes for ' || l_path;
        x_report_xml := BIP_REPORT_XML(l_resp);
        x_error_code := C_SUCCESS;
    EXCEPTION
        WHEN OTHERS THEN
            x_report_xml := NULL;
            x_error_code := C_ERROR;
            -- Defensive temp-LOB cleanup: a raise inside the retry loop (SOAP
            -- fault / 4xx) jumps here before the post-loop FREETEMPORARY, so
            -- release l_items / l_env if either is still a live temp LOB.
            BEGIN
                IF l_items IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_items) = 1 THEN
                    DBMS_LOB.FREETEMPORARY(l_items);
                END IF;
            EXCEPTION WHEN OTHERS THEN NULL; END;
            BEGIN
                IF l_env IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_env) = 1 THEN
                    DBMS_LOB.FREETEMPORARY(l_env);
                END IF;
            EXCEPTION WHEN OTHERS THEN NULL; END;
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
                -- Not found: create it. Guard the INSERT against a
                -- concurrent (or prior) creator of the same name --
                -- DMT_SCENARIO_UK makes the name unique, so a race
                -- between this SELECT-miss and the INSERT, or a reused
                -- scenario name across runs, would otherwise raise
                -- ORA-00001 and fail the whole run. On the dup, the row
                -- now exists, so re-select and return its id. Idempotent:
                -- return the existing id if present, create only when
                -- truly absent, never propagate ORA-00001.
                l_step := 'creating scenario "' || p_scenario_name || '"';
                BEGIN
                    INSERT INTO DMT_SCENARIO_TBL (SCENARIO_NAME)
                    VALUES (TRIM(p_scenario_name))
                    RETURNING SCENARIO_ID INTO x_scenario_id;
                EXCEPTION
                    WHEN DUP_VAL_ON_INDEX THEN
                        l_step := 're-selecting scenario "' ||
                                  p_scenario_name || '" after concurrent create';
                        SELECT SCENARIO_ID INTO x_scenario_id
                        FROM DMT_SCENARIO_TBL
                        WHERE UPPER(SCENARIO_NAME) = UPPER(TRIM(p_scenario_name));
                END;
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
            FROM   DMT_BIP_REPORT_TBL
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
    -- REFRESH_LOOKUPS -- full refresh of the canonical lookup types in
    -- DMT_LOOKUP_TBL from Fusion (design section 7 canonical lookup registry).
    -- Each DM returns LOOKUP_TYPE / LOOKUP_VALUE / RETURN_VALUE in a G_LKP
    -- group; the managed types are deleted then re-inserted so a value dropped
    -- in Fusion never lingers. Types produced: BU_NAME_TO_BU_ID,
    -- BU_NAME_TO_PRIMARY_LEDGER_ID, LEDGER_NAME_TO_LEDGER_ID
    -- (RETURN_VALUE = ledger_id~access_set_id),
    -- BATCH_SOURCE_NAME_TO_TRX_SOURCE_ID (AutoInvoice transaction-source id),
    -- PJC_TXN_SOURCE_NAME_TO_ID and PJC_DOC_NAME_TO_ID (PPM Import and Process
    -- Cost Transactions transaction-source id / document entry id),
    -- BUYER_NAME_TO_BUYER_ID (procurement buyer name -> agent_id, backlog #78).
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

        l_resp   CLOB;
        l_xml    XMLTYPE;
        l_loaded NUMBER;
        l_total  NUMBER := 0;

        -- BU DM: emits BOTH canonical BU types -- one source business unit
        -- becomes two typed rows so its id and its primary-ledger id are each
        -- resolvable by name.
        C_BU_XDM CONSTANT CLOB :=
'<?xml version="1.0" encoding="utf-8"?>'||CHR(10)||
'<dataModel xmlns="http://xmlns.oracle.com/oxp/xmlp" version="2.1" defaultDataSourceRef="ApplicationDB_FSCM">'||CHR(10)||
'<dataProperties><property name="include_parameters" value="true"/><property name="include_null_Element" value="true"/><property name="include_rowsettag" value="false"/><property name="xml_tag_case" value="upper"/></dataProperties>'||CHR(10)||
'<dataSets><dataSet name="bu_lookups" type="complex"><sql dataSourceRef="ApplicationDB_FSCM"><![CDATA['||
'SELECT ''BU_NAME_TO_BU_ID'' AS LOOKUP_TYPE, bu.bu_name AS LOOKUP_VALUE, TO_CHAR(bu.bu_id) AS RETURN_VALUE FROM fun_all_business_units_v bu WHERE bu.status = ''A'' '||
'UNION ALL '||
'SELECT ''BU_NAME_TO_PRIMARY_LEDGER_ID'', bu.bu_name, TO_CHAR(bu.primary_ledger_id) FROM fun_all_business_units_v bu WHERE bu.status = ''A'''||
']]></sql></dataSet></dataSets>'||CHR(10)||
'<output rootName="DATA_DS" uniqueRowName="false"><nodeList name="data-structure"><dataStructure tagName="DATA_DS"><group name="G_LKP" label="G_LKP" source="bu_lookups">'||
'<element name="LOOKUP_TYPE" value="LOOKUP_TYPE" dataType="xsd:string" tagName="LOOKUP_TYPE"/>'||
'<element name="LOOKUP_VALUE" value="LOOKUP_VALUE" dataType="xsd:string" tagName="LOOKUP_VALUE"/>'||
'<element name="RETURN_VALUE" value="RETURN_VALUE" dataType="xsd:string" tagName="RETURN_VALUE"/>'||
'</group></dataStructure></nodeList></output><eventTriggers/><lexicals/><valueSets/><bursting/></dataModel>';

        -- Ledger DM: the ledger id and its auto-created data-access-set id
        -- always travel together, so they share one row joined with ~.
        C_LEDGER_XDM CONSTANT CLOB :=
'<?xml version="1.0" encoding="utf-8"?>'||CHR(10)||
'<dataModel xmlns="http://xmlns.oracle.com/oxp/xmlp" version="2.1" defaultDataSourceRef="ApplicationDB_FSCM">'||CHR(10)||
'<dataProperties><property name="include_parameters" value="true"/><property name="include_null_Element" value="true"/><property name="include_rowsettag" value="false"/><property name="xml_tag_case" value="upper"/></dataProperties>'||CHR(10)||
'<dataSets><dataSet name="ledger_lookups" type="complex"><sql dataSourceRef="ApplicationDB_FSCM"><![CDATA['||
'SELECT ''LEDGER_NAME_TO_LEDGER_ID'' AS LOOKUP_TYPE, gl.name AS LOOKUP_VALUE, '||
'TO_CHAR(gl.ledger_id) || ''~'' || TO_CHAR((SELECT MIN(gas.access_set_id) FROM gl_access_sets gas WHERE gas.default_ledger_id = gl.ledger_id AND gas.automatically_created_flag = ''Y'')) AS RETURN_VALUE '||
'FROM gl_ledgers gl WHERE gl.object_type_code = ''L'' ORDER BY gl.name'||
']]></sql></dataSet></dataSets>'||CHR(10)||
'<output rootName="DATA_DS" uniqueRowName="false"><nodeList name="data-structure"><dataStructure tagName="DATA_DS"><group name="G_LKP" label="G_LKP" source="ledger_lookups">'||
'<element name="LOOKUP_TYPE" value="LOOKUP_TYPE" dataType="xsd:string" tagName="LOOKUP_TYPE"/>'||
'<element name="LOOKUP_VALUE" value="LOOKUP_VALUE" dataType="xsd:string" tagName="LOOKUP_VALUE"/>'||
'<element name="RETURN_VALUE" value="RETURN_VALUE" dataType="xsd:string" tagName="RETURN_VALUE"/>'||
'</group></dataStructure></nodeList></output><eventTriggers/><lexicals/><valueSets/><bursting/></dataModel>';

        -- AR batch-source DM: resolves an AutoInvoice batch source NAME to its
        -- numeric transaction-source id. Needed for the AutoInvoiceMasterEss
        -- ("Import Receivables Transactions Using AutoInvoice") parameter list,
        -- which takes the numeric trx_source_id, not the name. No hardcoded id --
        -- the id is read from ra_batch_sources_all by name at pipeline preflight,
        -- exactly like the BU and ledger lookups.
        C_AR_SOURCE_XDM CONSTANT CLOB :=
'<?xml version="1.0" encoding="utf-8"?>'||CHR(10)||
'<dataModel xmlns="http://xmlns.oracle.com/oxp/xmlp" version="2.1" defaultDataSourceRef="ApplicationDB_FSCM">'||CHR(10)||
'<dataProperties><property name="include_parameters" value="true"/><property name="include_null_Element" value="true"/><property name="include_rowsettag" value="false"/><property name="xml_tag_case" value="upper"/></dataProperties>'||CHR(10)||
'<dataSets><dataSet name="ar_source_lookups" type="complex"><sql dataSourceRef="ApplicationDB_FSCM"><![CDATA['||
'SELECT ''BATCH_SOURCE_NAME_TO_TRX_SOURCE_ID'' AS LOOKUP_TYPE, bs.name AS LOOKUP_VALUE, TO_CHAR(bs.batch_source_id) AS RETURN_VALUE '||
'FROM ra_batch_sources_all bs WHERE bs.batch_source_type = ''FOREIGN'' ORDER BY bs.name'||
']]></sql></dataSet></dataSets>'||CHR(10)||
'<output rootName="DATA_DS" uniqueRowName="false"><nodeList name="data-structure"><dataStructure tagName="DATA_DS"><group name="G_LKP" label="G_LKP" source="ar_source_lookups">'||
'<element name="LOOKUP_TYPE" value="LOOKUP_TYPE" dataType="xsd:string" tagName="LOOKUP_TYPE"/>'||
'<element name="LOOKUP_VALUE" value="LOOKUP_VALUE" dataType="xsd:string" tagName="LOOKUP_VALUE"/>'||
'<element name="RETURN_VALUE" value="RETURN_VALUE" dataType="xsd:string" tagName="RETURN_VALUE"/>'||
'</group></dataStructure></nodeList></output><eventTriggers/><lexicals/><valueSets/><bursting/></dataModel>';

        -- Project-costing txn-source / document DM: resolves the numeric ids the
        -- "Import and Process Cost Transactions" job needs in positions 6 and 7 of
        -- its ParameterList. Import Costs filters the pending rows by transaction
        -- source id AND document id, so those two ids must match the source and
        -- document NAME each interface row carries (e.g. Time Card / Time Card, or
        -- External Miscellaneous / Miscellaneous). We emit one typed row per
        -- transaction-source name and one per document name -- keyed by name -- so
        -- the loader resolves whichever source/document the run's rows actually use.
        -- No hardcoded Fusion ids: both ids are read by name at pipeline preflight,
        -- exactly like the BU, ledger and AR batch-source lookups above.
        C_PJC_SOURCE_XDM CONSTANT CLOB :=
'<?xml version="1.0" encoding="utf-8"?>'||CHR(10)||
'<dataModel xmlns="http://xmlns.oracle.com/oxp/xmlp" version="2.1" defaultDataSourceRef="ApplicationDB_FSCM">'||CHR(10)||
'<dataProperties><property name="include_parameters" value="true"/><property name="include_null_Element" value="true"/><property name="include_rowsettag" value="false"/><property name="xml_tag_case" value="upper"/></dataProperties>'||CHR(10)||
'<dataSets><dataSet name="pjc_source_lookups" type="complex"><sql dataSourceRef="ApplicationDB_FSCM"><![CDATA['||
'SELECT ''PJC_TXN_SOURCE_NAME_TO_ID'' AS LOOKUP_TYPE, ts.user_transaction_source AS LOOKUP_VALUE, TO_CHAR(ts.transaction_source_id) AS RETURN_VALUE FROM pjf_txn_sources_vl ts '||
'UNION ALL '||
'SELECT ''PJC_DOC_NAME_TO_ID'', dv.document_name, TO_CHAR(db.document_id) FROM pjf_txn_document_b db, pjf_txn_document_vl dv WHERE db.document_id = dv.document_id'||
']]></sql></dataSet></dataSets>'||CHR(10)||
'<output rootName="DATA_DS" uniqueRowName="false"><nodeList name="data-structure"><dataStructure tagName="DATA_DS"><group name="G_LKP" label="G_LKP" source="pjc_source_lookups">'||
'<element name="LOOKUP_TYPE" value="LOOKUP_TYPE" dataType="xsd:string" tagName="LOOKUP_TYPE"/>'||
'<element name="LOOKUP_VALUE" value="LOOKUP_VALUE" dataType="xsd:string" tagName="LOOKUP_VALUE"/>'||
'<element name="RETURN_VALUE" value="RETURN_VALUE" dataType="xsd:string" tagName="RETURN_VALUE"/>'||
'</group></dataStructure></nodeList></output><eventTriggers/><lexicals/><valueSets/><bursting/></dataModel>';

        -- Buyer DM: resolves a procurement buyer NAME to its numeric agent_id
        -- (= buyer id). This is the source that backlog #78 wires so the PO
        -- default buyer, stored by NAME in config (PO_DEFAULT_BUYER_NAME =
        -- ''Roth, Calvin''), resolves to its instance id through GET_LOOKUP at
        -- run time instead of falling back to the raw PO_DEFAULT_BUYER_ID --
        -- exactly as backlog #36 already wired the requisitioning BU through
        -- BU_NAME_TO_BU_ID. No hardcoded instance id: the id is read by name at
        -- pipeline preflight, like the BU, ledger, AR batch-source and PJC
        -- lookups above. Buyers are persons who are procurement agents, so the
        -- name comes from the person-name view (FULL_NAME is the "Last, First"
        -- form the buyer is configured by) and the id is the agent_id on
        -- po_agents_v (the valid-buyer view). GLOBAL, currently-effective name
        -- row only, so one name row per buyer. ''MASKED'' is excluded: Fusion
        -- substitutes that literal for privacy-masked persons, so it is not a
        -- real, resolvable buyer name -- loading it would map a meaningless
        -- ''MASKED'' key to an arbitrary one of the masked agents.
        C_BUYER_XDM CONSTANT CLOB :=
'<?xml version="1.0" encoding="utf-8"?>'||CHR(10)||
'<dataModel xmlns="http://xmlns.oracle.com/oxp/xmlp" version="2.1" defaultDataSourceRef="ApplicationDB_FSCM">'||CHR(10)||
'<dataProperties><property name="include_parameters" value="true"/><property name="include_null_Element" value="true"/><property name="include_rowsettag" value="false"/><property name="xml_tag_case" value="upper"/></dataProperties>'||CHR(10)||
'<dataSets><dataSet name="buyer_lookups" type="complex"><sql dataSourceRef="ApplicationDB_FSCM"><![CDATA['||
'SELECT ''BUYER_NAME_TO_BUYER_ID'' AS LOOKUP_TYPE, n.full_name AS LOOKUP_VALUE, TO_CHAR(a.agent_id) AS RETURN_VALUE '||
'FROM po_agents_v a, per_person_names_f n '||
'WHERE n.person_id = a.agent_id AND n.name_type = ''GLOBAL'' '||
'AND n.full_name != ''MASKED'' '||
'AND TRUNC(SYSDATE) BETWEEN n.effective_start_date AND n.effective_end_date ORDER BY n.full_name'||
']]></sql></dataSet></dataSets>'||CHR(10)||
'<output rootName="DATA_DS" uniqueRowName="false"><nodeList name="data-structure"><dataStructure tagName="DATA_DS"><group name="G_LKP" label="G_LKP" source="buyer_lookups">'||
'<element name="LOOKUP_TYPE" value="LOOKUP_TYPE" dataType="xsd:string" tagName="LOOKUP_TYPE"/>'||
'<element name="LOOKUP_VALUE" value="LOOKUP_VALUE" dataType="xsd:string" tagName="LOOKUP_VALUE"/>'||
'<element name="RETURN_VALUE" value="RETURN_VALUE" dataType="xsd:string" tagName="RETURN_VALUE"/>'||
'</group></dataStructure></nodeList></output><eventTriggers/><lexicals/><valueSets/><bursting/></dataModel>';

    BEGIN
        LOG(p_message => C_PROC || ' start.', p_package => C_PKG, p_procedure => C_PROC);

        -- One-time cleanup: remove the retired pre-canonical types. Safe --
        -- they are never reinserted and nothing reads them, so clearing them
        -- cannot leave a needed type empty. The canonical types are replaced
        -- per-DM, atomically, only after that DM returns rows (below) -- an
        -- upfront delete of the canonical types would leave a type empty and
        -- committed if its DM later returned nothing.
        DELETE FROM DMT_LOOKUP_TBL WHERE LOOKUP_TYPE IN ('BU','LEDGER');
        COMMIT;

        l_dms.EXTEND(5);
        l_dms(1).dm_name := 'DMT_BU_LKP_DM';         l_dms(1).xdm_xml := C_BU_XDM;
        l_dms(2).dm_name := 'DMT_LEDGER_LKP_DM';     l_dms(2).xdm_xml := C_LEDGER_XDM;
        l_dms(3).dm_name := 'DMT_AR_SOURCE_LKP_DM';  l_dms(3).xdm_xml := C_AR_SOURCE_XDM;
        l_dms(4).dm_name := 'DMT_PJC_SOURCE_LKP_DM'; l_dms(4).xdm_xml := C_PJC_SOURCE_XDM;
        l_dms(5).dm_name := 'DMT_BUYER_LKP_DM';      l_dms(5).xdm_xml := C_BUYER_XDM;

        FOR i IN 1..l_dms.COUNT LOOP
            LOG(p_message => C_PROC || ': running ' || l_dms(i).dm_name,
                p_package => C_PKG, p_procedure => C_PROC);

            l_resp := DMT_BIP_DEPLOY_PKG.RUN_DATA_MODEL(
                p_xdm_name => l_dms(i).dm_name,
                p_xdm_xml  => l_dms(i).xdm_xml
            );

            -- Extract + decode reportBytes via the shared any-size extractor.
            l_xml := BIP_REPORT_XML(l_resp);

            -- Fail closed: an empty/absent response for a lookup DM is NOT a
            -- valid outcome -- a real Fusion instance always has active business
            -- units and ledgers. Raise so REFRESH_LOOKUPS (and the preflight that
            -- calls it) halt, rather than silently leaving a lookup type empty
            -- and failing later at the first GET_LOOKUP.
            IF l_xml IS NULL THEN
                RAISE_APPLICATION_ERROR(-20041,
                    'REFRESH_LOOKUPS: lookup data model ' || l_dms(i).dm_name ||
                    ' returned no rows. Refusing to leave lookups incomplete.');
            END IF;

            -- Atomic per-DM replace: delete ONLY the types this DM produces, then
            -- insert this refresh's rows. A failure on one DM can never wipe
            -- another DM's good rows (which an upfront delete-all could).
            DELETE FROM DMT_LOOKUP_TBL
            WHERE LOOKUP_TYPE IN (
                SELECT DISTINCT x.lookup_type
                FROM XMLTABLE('/DATA_DS/G_LKP' PASSING l_xml
                    COLUMNS lookup_type VARCHAR2(100) PATH 'LOOKUP_TYPE') x
                WHERE x.lookup_type IS NOT NULL);

            -- Insert the canonical rows. One row per (LOOKUP_TYPE, LOOKUP_VALUE)
            -- -- ROW_NUMBER de-dups defensively so a repeated source name can
            -- never violate the unique key.
            INSERT INTO DMT_LOOKUP_TBL (LOOKUP_TYPE, LOOKUP_VALUE, RETURN_VALUE)
            SELECT lookup_type, lookup_value, return_value
            FROM (
                SELECT x.lookup_type, x.lookup_value, x.return_value,
                       ROW_NUMBER() OVER (PARTITION BY x.lookup_type, x.lookup_value
                                          ORDER BY x.return_value) AS rn
                FROM XMLTABLE('/DATA_DS/G_LKP' PASSING l_xml
                    COLUMNS
                        lookup_type  VARCHAR2(100) PATH 'LOOKUP_TYPE',
                        lookup_value VARCHAR2(500) PATH 'LOOKUP_VALUE',
                        return_value VARCHAR2(500) PATH 'RETURN_VALUE'
                ) x
                WHERE x.lookup_value IS NOT NULL
            ) WHERE rn = 1;

            l_loaded := SQL%ROWCOUNT;
            l_total := l_total + l_loaded;
            COMMIT;

            LOG(p_message => C_PROC || ': ' || l_dms(i).dm_name || ' complete. ' || l_loaded || ' rows loaded.',
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

    -- --------------------------------------------------------
    -- GET_LOOKUP -- resolve one canonical lookup (the ONE accessor).
    -- Raises -20040 (a single clear halt-the-run error) when the row is
    -- missing or not unique; signals failure ONLY by raising (section-7
    -- procedures-only contract, read-function carve-out).
    -- --------------------------------------------------------
    FUNCTION GET_LOOKUP (
        p_type  IN VARCHAR2,
        p_value IN VARCHAR2
    ) RETURN VARCHAR2 IS
        l_return VARCHAR2(500);
    BEGIN
        SELECT RETURN_VALUE
        INTO   l_return
        FROM   DMT_LOOKUP_TBL
        WHERE  LOOKUP_TYPE = p_type
          AND  LOOKUP_VALUE = p_value;
        RETURN l_return;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20040,
                'No row in DMT_LOOKUP_TBL for LOOKUP_TYPE=''' || p_type ||
                ''', LOOKUP_VALUE=''' || p_value || '''. Run halted; refresh lookups '
                || '(REFRESH_LOOKUPS runs at pipeline preflight) or check the source value.');
        WHEN TOO_MANY_ROWS THEN
            RAISE_APPLICATION_ERROR(-20040,
                'Multiple rows in DMT_LOOKUP_TBL for LOOKUP_TYPE=''' || p_type ||
                ''', LOOKUP_VALUE=''' || p_value || '''. A lookup must resolve to exactly one value.');
    END GET_LOOKUP;

    -- --------------------------------------------------------
    -- VERIFY_CREDENTIAL -- one authenticated probe, 401 => bad.
    -- Outcome via the section-7 error-code contract; the reason is
    -- logged at the point of failure, never returned as text.
    -- --------------------------------------------------------
    PROCEDURE VERIFY_CREDENTIAL (
        p_username   IN  VARCHAR2,
        p_password   IN  VARCHAR2,
        x_error_code OUT NUMBER
    ) IS
        C_PKG    CONSTANT VARCHAR2(30) := 'DMT_UTIL_PKG';
        C_PROC   CONSTANT VARCHAR2(30) := 'VERIFY_CREDENTIAL';
        l_step   VARCHAR2(200);
        l_url    VARCHAR2(600);
        l_resp   CLOB;
        l_status NUMBER;
    BEGIN
        x_error_code := C_ERROR;

        l_step := 'checking the credential is present';
        IF p_username IS NULL OR p_password IS NULL THEN
            LOG(p_message   => C_PROC || ': credential resolves to NULL (username or password missing).',
                p_log_type  => C_LOG_WARN, p_package => C_PKG, p_procedure => C_PROC);
            RETURN;
        END IF;

        -- One authenticated GET to a stable, always-present endpoint. We read
        -- only the HTTP status: 401 = password rejected; anything else = it
        -- signs in. No retry on 401 (project rule: on 401 stop, never retry
        -- into a lockout). p_raise_on_error => FALSE so a non-2xx status comes
        -- back as a value instead of an exception.
        l_step := 'authenticating user ' || p_username || ' against Fusion';
        l_url  := RTRIM(GET_CONFIG(p_key => 'FUSION_URL'), '/')
                  || '/fscmRestApi/resources/11.13.18.05/';

        HTTP_REQUEST(
            p_url            => l_url,
            p_method         => 'GET',
            x_response       => l_resp,
            x_status_code    => l_status,
            p_raise_on_error => FALSE,
            p_auth_header    => BASIC_AUTH_HEADER(p_username => p_username, p_password => p_password));

        IF l_status = 401 THEN
            LOG(p_message   => C_PROC || ': HTTP 401 (Fusion rejected the password) for user ' || p_username || '.',
                p_log_type  => C_LOG_ERROR, p_package => C_PKG, p_procedure => C_PROC);
            RETURN;
        END IF;

        x_error_code := C_SUCCESS;
        LOG(p_message   => C_PROC || ': authenticated (HTTP ' || l_status || ') for user ' || p_username || '.',
            p_package => C_PKG, p_procedure => C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            -- Cannot verify (network/URL/wallet) is treated as a failure --
            -- the preflight must not pass a credential it could not check.
            x_error_code := C_ERROR;
            LOG_ERROR(p_message   => l_step || ' -- probe failed for user ' || p_username,
                      p_sqlerrm   => SQLERRM, p_package => C_PKG, p_procedure => C_PROC);
            RETURN;
    END VERIFY_CREDENTIAL;

    -- --------------------------------------------------------
    -- RUN_PREFLIGHT -- refresh lookups + verify every run credential.
    -- Outcome via the section-7 error-code contract; each failure is
    -- logged where it happens. Does NOT pre-check that needed lookup
    -- VALUES exist -- a missing value halts later at GET_LOOKUP
    -- (2026-07-10 scope decision; DMT_DESIGN.html section-7 write-up pending).
    -- --------------------------------------------------------
    PROCEDURE RUN_PREFLIGHT (
        p_run_id     IN  NUMBER,
        x_error_code OUT NUMBER
    ) IS
        C_PKG      CONSTANT VARCHAR2(30) := 'DMT_UTIL_PKG';
        C_PROC     CONSTANT VARCHAR2(30) := 'RUN_PREFLIGHT';
        l_step     VARCHAR2(200);
        l_user     VARCHAR2(100);
        l_pass     VARCHAR2(500);
        l_cred     NUMBER;
        l_failures NUMBER := 0;
    BEGIN
        x_error_code := C_SUCCESS;
        LOG(p_run_id => p_run_id, p_message => C_PROC || ' start.',
            p_package => C_PKG, p_procedure => C_PROC);

        -- (1) Refresh the name->id lookups. This authenticates as the global
        -- Fusion user, so a bad global password fails here. REFRESH_LOOKUPS
        -- logs and re-raises on failure; the single handler below reports
        -- l_step, so no nested block is needed.
        l_step := 'refreshing Fusion lookups';
        REFRESH_LOOKUPS;

        -- (2) Verify every DISTINCT credential the run's objects will use --
        -- the per-object override or the global default. VERIFY_CREDENTIAL
        -- handles its own errors and returns a code, so the loop body needs
        -- no exception scope of its own. Accumulate failures and halt if any.
        FOR c IN (
            SELECT DISTINCT q.CEMLI_CODE
            FROM   DMT_WORK_QUEUE_TBL q
            WHERE  q.RUN_ID = p_run_id
        ) LOOP
            l_step := 'resolving credentials for ' || c.CEMLI_CODE;
            GET_CEMLI_CREDENTIALS(p_cemli_code => c.CEMLI_CODE,
                                  x_username   => l_user,
                                  x_password   => l_pass);

            l_step := 'verifying credential for ' || c.CEMLI_CODE;
            VERIFY_CREDENTIAL(p_username   => l_user,
                              p_password   => l_pass,
                              x_error_code => l_cred);

            IF l_cred != C_SUCCESS THEN
                l_failures := l_failures + 1;
                LOG(p_run_id    => p_run_id,
                    p_message   => C_PROC || ': credential check FAILED for ' || c.CEMLI_CODE || '.',
                    p_log_type  => C_LOG_ERROR, p_package => C_PKG, p_procedure => C_PROC);
            END IF;
        END LOOP;

        IF l_failures > 0 THEN
            x_error_code := C_ERROR;
            LOG(p_run_id    => p_run_id,
                p_message   => C_PROC || ': ' || l_failures || ' credential(s) will not authenticate. Run must halt.',
                p_log_type  => C_LOG_ERROR, p_package => C_PKG, p_procedure => C_PROC);
            RETURN;
        END IF;

        LOG(p_run_id => p_run_id,
            p_message => C_PROC || ' complete: lookups refreshed, all credentials verified.',
            p_package => C_PKG, p_procedure => C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            x_error_code := C_ERROR;
            LOG_ERROR(p_run_id    => p_run_id, p_message => l_step,
                      p_sqlerrm   => SQLERRM, p_package => C_PKG, p_procedure => C_PROC);
            RETURN;
    END RUN_PREFLIGHT;

END DMT_UTIL_PKG;
/
