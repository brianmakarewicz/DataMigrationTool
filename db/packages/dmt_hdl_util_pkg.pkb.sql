-- PACKAGE BODY DMT_HDL_UTIL_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_HDL_UTIL_PKG" AS
-- ============================================================
-- DMT_HDL_UTIL_PKG Body
-- HCM Data Loader utilities — REST-based pipeline.
-- ============================================================

    -- --------------------------------------------------------
    -- Private: get Basic auth header value
    -- --------------------------------------------------------
    FUNCTION get_auth RETURN VARCHAR2 IS
        l_user VARCHAR2(200);
        l_pass VARCHAR2(200);
    BEGIN
        -- HCM REST uses a separate user (hcm_impl) that has HCM Data Loader role.
        -- Falls back to FUSION_USERNAME/FUSION_PASSWORD if HCM keys not set.
        l_user := NVL(DMT_UTIL_PKG.GET_CONFIG('HCM_USERNAME'),
                      DMT_UTIL_PKG.GET_CONFIG('FUSION_USERNAME'));
        l_pass := NVL(DMT_UTIL_PKG.GET_CONFIG('HCM_PASSWORD'),
                      DMT_UTIL_PKG.GET_CONFIG('FUSION_PASSWORD'));

        RETURN 'Basic ' || UTL_RAW.CAST_TO_VARCHAR2(
            UTL_ENCODE.BASE64_ENCODE(
                UTL_RAW.CAST_TO_RAW(l_user || ':' || l_pass)));
    END get_auth;

    -- --------------------------------------------------------
    -- Private: get Fusion base URL
    -- --------------------------------------------------------
    FUNCTION get_url RETURN VARCHAR2 IS
    BEGIN
        -- Normalized: always ends with exactly one '/' so path joins work whether
        -- the stored FUSION_URL carries a trailing slash or not (2026-07-08 fix:
        -- a slash-less config value produced hostname garbage and ACL denials).
        RETURN RTRIM(DMT_UTIL_PKG.GET_CONFIG('FUSION_URL'), '/') || '/';
    END get_url;

    -- --------------------------------------------------------
    -- GET_SOURCE_SYSTEM_OWNER (backlog #287) -- see spec.
    -- --------------------------------------------------------
    FUNCTION GET_SOURCE_SYSTEM_OWNER RETURN VARCHAR2 IS
        l_owner DMT_CONFIG_TBL.CONFIG_VALUE%TYPE;
    BEGIN
        l_owner := TRIM(DMT_UTIL_PKG.GET_CONFIG(C_SSO_CONFIG_KEY));
        IF l_owner IS NULL THEN
            RAISE_APPLICATION_ERROR(-20130,
                'DMT_CONFIG_TBL key ' || C_SSO_CONFIG_KEY || ' is not set. It must hold this '
                || 'DMT instance''s HDL SourceSystemOwner (an enabled HRC_SOURCE_SYSTEM_OWNER '
                || 'lookup code, e.g. DMT_LOCAL or DMT_ATP).');
        END IF;
        RETURN l_owner;
    END GET_SOURCE_SYSTEM_OWNER;

    -- --------------------------------------------------------
    -- REST_HTTP
    -- --------------------------------------------------------
    FUNCTION REST_HTTP (
        p_url              IN VARCHAR2,
        p_method           IN VARCHAR2 DEFAULT 'GET',
        p_body             IN CLOB     DEFAULT NULL,
        p_run_id   IN NUMBER   DEFAULT NULL,
        p_log_errors       IN BOOLEAN  DEFAULT TRUE
    ) RETURN CLOB IS
        l_req       UTL_HTTP.REQ;
        l_resp      UTL_HTTP.RESP;
        l_response  CLOB;
        l_chunk     VARCHAR2(32767);
        l_offset    INTEGER := 1;
        l_amount    INTEGER;
        l_body_len  INTEGER;
    BEGIN
        UTL_HTTP.SET_RESPONSE_ERROR_CHECK(FALSE);
        UTL_HTTP.SET_TRANSFER_TIMEOUT(600);

        l_req := UTL_HTTP.BEGIN_REQUEST(p_url, p_method, 'HTTP/1.1');
        UTL_HTTP.SET_HEADER(l_req, 'Authorization', get_auth());

        IF p_method = 'POST' AND p_body IS NOT NULL THEN
            UTL_HTTP.SET_HEADER(l_req, 'Content-Type', 'application/vnd.oracle.adf.action+json');
            UTL_HTTP.SET_HEADER(l_req, 'Content-Length', DBMS_LOB.GETLENGTH(p_body));

            l_body_len := DBMS_LOB.GETLENGTH(p_body);
            WHILE l_offset <= l_body_len LOOP
                l_amount := LEAST(8000, l_body_len - l_offset + 1);
                l_chunk  := DBMS_LOB.SUBSTR(p_body, l_amount, l_offset);
                UTL_HTTP.WRITE_TEXT(l_req, l_chunk);
                l_offset := l_offset + l_amount;
            END LOOP;
        ELSIF p_method = 'GET' THEN
            UTL_HTTP.SET_HEADER(l_req, 'Accept', 'application/json');
        END IF;

        l_resp := UTL_HTTP.GET_RESPONSE(l_req);

        DBMS_LOB.CREATETEMPORARY(l_response, TRUE);
        BEGIN
            LOOP
                UTL_HTTP.READ_TEXT(l_resp, l_chunk, 32767);
                DBMS_LOB.APPEND(l_response, l_chunk);
            END LOOP;
        EXCEPTION WHEN UTL_HTTP.END_OF_BODY THEN NULL;
        END;
        UTL_HTTP.END_RESPONSE(l_resp);

        IF l_resp.status_code NOT BETWEEN 200 AND 299 THEN
            RAISE_APPLICATION_ERROR(-20050,
                'HDL REST call failed. Status: ' || l_resp.status_code ||
                ' | URL: ' || SUBSTR(p_url, 1, 200) ||
                ' | Response: ' || DBMS_LOB.SUBSTR(l_response, 500, 1));
        END IF;

        RETURN l_response;

    EXCEPTION
        WHEN OTHERS THEN
            -- p_log_errors=FALSE suppresses the ERROR row for callers that already
            -- handle a failed call and log their own outcome (POLL_HDL's status GET,
            -- whose expected first-poll 404 is not a real error — backlog #156). The
            -- exception is still re-raised so the caller's own handling runs.
            IF p_run_id IS NOT NULL AND p_log_errors THEN
                DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                    'REST_HTTP failed. URL: ' || SUBSTR(p_url, 1, 200),
                    SQLERRM, C_PKG, 'REST_HTTP');
            END IF;
            RAISE;
    END REST_HTTP;

    -- --------------------------------------------------------
    -- UPLOAD_HDL
    -- Uploads HDL zip to Fusion UCM via HCM REST uploadFile action.
    -- Returns UCM ContentId.
    -- --------------------------------------------------------
    FUNCTION UPLOAD_HDL (
        p_run_id IN NUMBER,
        p_hdl_zip        IN BLOB,
        p_filename       IN VARCHAR2,
        p_log_context    IN VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2 IS
        l_url       VARCHAR2(500);
        l_b64       CLOB;
        l_body      CLOB;
        l_response  CLOB;
        l_content_id VARCHAR2(100);
        l_proc      VARCHAR2(100) := NVL(p_log_context, '') || ' > UPLOAD_HDL';
        l_raw       RAW(32767);
        l_offset    INTEGER := 1;
        l_amount    INTEGER;
        l_blob_len  INTEGER;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id,
            'UPLOAD_HDL start. File: ' || p_filename || ' | Size: ' || DBMS_LOB.GETLENGTH(p_hdl_zip),
            'INFO', C_PKG, l_proc);

        l_url := get_url() || C_HCM_REST_PATH || '/action/uploadFile';

        -- Base64-encode the ZIP
        DBMS_LOB.CREATETEMPORARY(l_b64, TRUE);
        l_blob_len := DBMS_LOB.GETLENGTH(p_hdl_zip);
        WHILE l_offset <= l_blob_len LOOP
            l_amount := LEAST(12000, l_blob_len - l_offset + 1);
            l_raw := UTL_ENCODE.BASE64_ENCODE(DBMS_LOB.SUBSTR(p_hdl_zip, l_amount, l_offset));
            DBMS_LOB.WRITEAPPEND(l_b64, UTL_RAW.LENGTH(l_raw),
                UTL_RAW.CAST_TO_VARCHAR2(l_raw));
            l_offset := l_offset + l_amount;
        END LOOP;

        -- Remove newlines from base64
        l_b64 := REPLACE(REPLACE(l_b64, CHR(13), ''), CHR(10), '');

        -- Build JSON body
        l_body := '{"content":"' || l_b64 || '","fileName":"' || p_filename || '"}';
        DBMS_LOB.FREETEMPORARY(l_b64);

        DMT_UTIL_PKG.LOG(p_run_id,
            'Calling HCM uploadFile. File: ' || p_filename,
            'INFO', C_PKG, l_proc);

        l_response := REST_HTTP(
            p_url            => l_url,
            p_method         => 'POST',
            p_body           => l_body,
            p_run_id => p_run_id);

        DBMS_LOB.FREETEMPORARY(l_body);

        -- Parse ContentId from JSON response: {"result":{"Status":"SUCCESS","ContentId":"UCMFA00078879"}}
        l_content_id := REGEXP_SUBSTR(l_response, '"ContentId"\s*:\s*"([^"]+)"', 1, 1, NULL, 1);

        IF l_content_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20051,
                'UPLOAD_HDL: ContentId not found in response. Response: ' ||
                DBMS_LOB.SUBSTR(l_response, 500, 1));
        END IF;

        DMT_UTIL_PKG.LOG(p_run_id,
            'UPLOAD_HDL complete. ContentId: ' || l_content_id || ' | File: ' || p_filename,
            'INFO', C_PKG, l_proc);

        RETURN l_content_id;

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'UPLOAD_HDL failed. File: ' || p_filename,
                SQLERRM, C_PKG, l_proc);
            RAISE;
    END UPLOAD_HDL;

    -- --------------------------------------------------------
    -- SUBMIT_HDL
    -- Triggers HCM Data Loader import via REST createFileDataSet.
    -- Returns HDL RequestId (data set ID).
    -- --------------------------------------------------------
    FUNCTION SUBMIT_HDL (
        p_run_id IN NUMBER,
        p_content_id     IN VARCHAR2,
        p_dataset_name   IN VARCHAR2 DEFAULT NULL,
        p_log_context    IN VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2 IS
        l_url        VARCHAR2(500);
        l_body       CLOB;
        l_response   CLOB;
        l_request_id VARCHAR2(100);
        l_ds_name    VARCHAR2(200) := NVL(p_dataset_name,
                         'DMT_' || TO_CHAR(p_run_id) || '_' || TO_CHAR(SYSDATE, 'YYYYMMDDHH24MISS'));
        l_proc       VARCHAR2(100) := NVL(p_log_context, '') || ' > SUBMIT_HDL';
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id,
            'SUBMIT_HDL start. ContentId: ' || p_content_id || ' | DataSet: ' || l_ds_name,
            'INFO', C_PKG, l_proc);

        l_url := get_url() || C_HCM_REST_PATH || '/action/createFileDataSet';

        -- JSON body — lowercase field names, minimal params
        l_body := '{"contentId":"' || p_content_id || '","fileAction":"IMPORT_AND_LOAD"}';

        l_response := REST_HTTP(
            p_url            => l_url,
            p_method         => 'POST',
            p_body           => l_body,
            p_run_id => p_run_id);

        -- Parse RequestId from JSON: {"result":{"Status":"SUCCESS","RequestId":"107468"}}
        l_request_id := REGEXP_SUBSTR(l_response, '"RequestId"\s*:\s*"([^"]+)"', 1, 1, NULL, 1);

        IF l_request_id IS NULL THEN
            -- Try numeric format (no quotes)
            l_request_id := REGEXP_SUBSTR(l_response, '"RequestId"\s*:\s*([0-9]+)', 1, 1, NULL, 1);
        END IF;

        IF l_request_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20052,
                'SUBMIT_HDL: RequestId not found in response. Response: ' ||
                DBMS_LOB.SUBSTR(l_response, 500, 1));
        END IF;

        DMT_UTIL_PKG.LOG(p_run_id,
            'SUBMIT_HDL complete. RequestId: ' || l_request_id || ' | ContentId: ' || p_content_id,
            'INFO', C_PKG, l_proc);

        RETURN l_request_id;

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'SUBMIT_HDL failed. ContentId: ' || p_content_id,
                SQLERRM, C_PKG, l_proc);
            RAISE;
    END SUBMIT_HDL;

    -- --------------------------------------------------------
    -- POLL_HDL
    -- Polls HCM Data Loader status via REST GET until terminal.
    -- Terminal: ORA_COMPLETED, ORA_IN_ERROR, ORA_STOPPED
    -- --------------------------------------------------------
    PROCEDURE POLL_HDL (
        p_run_id  IN NUMBER,
        p_request_id      IN VARCHAR2,
        p_timeout_sec     IN NUMBER   DEFAULT 1800,
        p_raise_on_error  IN BOOLEAN  DEFAULT FALSE,
        p_log_context     IN VARCHAR2 DEFAULT NULL,
        x_dataset_status  OUT VARCHAR2
    ) IS
        l_url       VARCHAR2(500);
        l_response  CLOB;
        l_status    VARCHAR2(50);
        l_elapsed   NUMBER := 0;
        l_proc      VARCHAR2(100) := NVL(p_log_context, '') || ' > POLL_HDL';
        C_INTERVAL  CONSTANT NUMBER := 30;  -- 30 seconds between polls
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id,
            'POLL_HDL start. RequestId: ' || p_request_id || ' | Timeout: ' || p_timeout_sec || 's',
            'INFO', C_PKG, l_proc);

        l_url := get_url() || C_HCM_REST_PATH || '/' || p_request_id;

        -- Initial delay — data set is NOT queryable the instant createFileDataSet
        -- returns; a GET before it registers comes back 404. 20s covers the common
        -- registration lag so the first poll usually hits a real status. Even when it
        -- does not, the GET below is marked p_log_errors=>FALSE and the loop retries,
        -- so a transient 404 is handled quietly rather than logged as an ERROR (#156).
        DBMS_SESSION.SLEEP(20);

        LOOP
            -- GET status — handle 404 gracefully (data set may not be ready yet).
            -- p_log_errors=>FALSE: a failed GET here is expected (not-yet-registered
            -- or a dropped poll) and is retried on the next tick, so it must not emit
            -- a scary ERROR row; the INFO status line below records each poll instead.
            BEGIN
                l_response := REST_HTTP(
                    p_url            => l_url,
                    p_method         => 'GET',
                    p_run_id => p_run_id,
                    p_log_errors     => FALSE);
                l_status := REGEXP_SUBSTR(l_response, '"DataSetStatusCode"\s*:\s*"([^"]+)"', 1, 1, NULL, 1);
            EXCEPTION
                WHEN OTHERS THEN
                    -- 404 or other transient error — treat as not-ready
                    l_status := 'NOT_READY';
            END;

            DMT_UTIL_PKG.LOG(p_run_id,
                'HDL poll: ' || p_request_id || ' | Status: ' || NVL(l_status, 'UNKNOWN') ||
                ' | Elapsed: ' || l_elapsed || 's',
                'INFO', C_PKG, l_proc);

            -- Terminal states (ORA_ prefix or plain status codes)
            IF l_status IN ('ORA_COMPLETED', 'ORA_SUCCESS', 'ORA_IN_ERROR', 'ORA_STOPPED',
                            'SUCCESS', 'ERROR', 'WARNING') THEN
                EXIT;
            END IF;

            -- Timeout
            IF l_elapsed >= p_timeout_sec THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    'POLL_HDL timed out after ' || p_timeout_sec || 's. Status: ' || NVL(l_status, 'UNKNOWN'),
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
                l_status := 'EXPIRED';
                EXIT;
            END IF;

            DBMS_SESSION.SLEEP(C_INTERVAL);
            l_elapsed := l_elapsed + C_INTERVAL;
        END LOOP;

        -- Log final status with counts
        DECLARE
            l_imp_err   VARCHAR2(20) := REGEXP_SUBSTR(l_response, '"FileLineImportErrorCount"\s*:\s*([0-9]+)', 1, 1, NULL, 1);
            l_imp_succ  VARCHAR2(20) := REGEXP_SUBSTR(l_response, '"FileLineImportSuccessCount"\s*:\s*([0-9]+)', 1, 1, NULL, 1);
            l_load_err  VARCHAR2(20) := REGEXP_SUBSTR(l_response, '"ObjectLoadErrorCount"\s*:\s*([0-9]+)', 1, 1, NULL, 1);
            l_load_succ VARCHAR2(20) := REGEXP_SUBSTR(l_response, '"ObjectSuccessCount"\s*:\s*([0-9]+)', 1, 1, NULL, 1);
        BEGIN
            DMT_UTIL_PKG.LOG(p_run_id,
                'POLL_HDL complete. RequestId: ' || p_request_id ||
                ' | Status: ' || l_status ||
                ' | Import: ' || NVL(l_imp_succ, '?') || ' ok / ' || NVL(l_imp_err, '?') || ' err' ||
                ' | Load: ' || NVL(l_load_succ, '?') || ' ok / ' || NVL(l_load_err, '?') || ' err',
                'INFO', C_PKG, l_proc);
        END;

        x_dataset_status := l_status;

        IF l_status = 'ORA_IN_ERROR' AND p_raise_on_error THEN
            RAISE_APPLICATION_ERROR(-20053,
                'HDL data set ' || p_request_id || ' ended with status: ORA_IN_ERROR');
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'POLL_HDL failed. RequestId: ' || p_request_id,
                SQLERRM, C_PKG, l_proc);
            RAISE;
    END POLL_HDL;

    -- --------------------------------------------------------
    -- FORMAT_HDL_ERROR (backlog #288) -- see spec. Pure value converter.
    -- --------------------------------------------------------
    FUNCTION FORMAT_HDL_ERROR (
        p_source_system_id IN VARCHAR2,
        p_dat_file_name    IN VARCHAR2,
        p_file_line        IN NUMBER,
        p_message_text     IN VARCHAR2
    ) RETURN VARCHAR2 DETERMINISTIC IS
        C_TAG CONSTANT VARCHAR2(20) := '[FUSION_ERROR] ';
        l_where VARCHAR2(4000);
    BEGIN
        IF p_message_text IS NULL THEN
            RETURN NULL;
        END IF;
        -- "<file> line <n>", "<file>", or nothing.
        l_where := CASE
                       WHEN p_dat_file_name IS NOT NULL AND p_file_line IS NOT NULL
                           THEN p_dat_file_name || ' line ' || TO_CHAR(p_file_line)
                       WHEN p_dat_file_name IS NOT NULL
                           THEN p_dat_file_name
                   END;
        RETURN SUBSTR(
            C_TAG ||
            CASE
                WHEN p_source_system_id IS NOT NULL AND l_where IS NOT NULL
                    THEN p_source_system_id || ' (' || l_where || '): '
                WHEN p_source_system_id IS NOT NULL
                    THEN p_source_system_id || ': '
                WHEN l_where IS NOT NULL
                    THEN l_where || ': '
            END ||
            p_message_text, 1, 4000);
    END FORMAT_HDL_ERROR;

    -- --------------------------------------------------------
    -- STAGE_HDL_MESSAGES (backlog #288) -- see spec.
    -- Replaces GET_HDL_ERRORS (one 500-message page, never followed hasMore) and
    -- the dynamic-SQL RECONCILE_HDL. Every statement here is static.
    -- --------------------------------------------------------
    PROCEDURE STAGE_HDL_MESSAGES (
        p_run_id         IN  NUMBER,
        p_request_id     IN  VARCHAR2,
        p_log_context    IN  VARCHAR2 DEFAULT NULL,
        x_message_count  OUT NUMBER
    ) IS
        C_PAGE_SIZE CONSTANT PLS_INTEGER := 500;
        -- A data set never has this many pages of messages; reaching it means the
        -- paging is not advancing, so stop loudly rather than loop forever.
        C_MAX_PAGES CONSTANT PLS_INTEGER := 2000;
        l_proc      VARCHAR2(200) := NVL(p_log_context, '') || ' > STAGE_HDL_MESSAGES';
        l_request   NUMBER := TO_NUMBER(p_request_id);
        l_resp      CLOB;
        l_offset    PLS_INTEGER := 0;
        l_page      PLS_INTEGER := 0;
        l_items     NUMBER;
        l_has_more  VARCHAR2(10);
        l_step      VARCHAR2(400);
    BEGIN
        x_message_count := 0;

        l_step := 'clearing the staged messages of request ' || p_request_id;
        DELETE FROM DMT_HDL_MESSAGE_GTT WHERE REQUEST_ID = l_request;

        LOOP
            l_page := l_page + 1;
            l_step := 'reading HDL messages page ' || l_page || ' (offset ' || l_offset
                      || ') of request ' || p_request_id;
            l_resp := REST_HTTP(
                p_url    => get_url() || C_HCM_REST_PATH || '/' || p_request_id ||
                            '/child/messages?onlyData=true&orderBy=DatFileName,FileLine' ||
                            '&limit=' || C_PAGE_SIZE || '&offset=' || l_offset,
                p_method => 'GET',
                p_run_id => p_run_id);

            -- Error messages only: a WARNING does not reject the record.
            l_step := 'staging HDL messages page ' || l_page || ' of request ' || p_request_id;
            INSERT INTO DMT_HDL_MESSAGE_GTT (
                REQUEST_ID, MESSAGE_LINE_ID, SOURCE_SYSTEM_ID, DAT_FILE_NAME,
                FILE_LINE, BUSINESS_OBJECT, MESSAGE_TEXT, ERROR_TEXT)
            SELECT l_request,
                   jt.message_line_id,
                   jt.source_system_id,
                   jt.dat_file_name,
                   jt.file_line,
                   jt.business_object,
                   jt.message_text,
                   FORMAT_HDL_ERROR(jt.source_system_id, jt.dat_file_name,
                                    jt.file_line, jt.message_text)
            FROM   JSON_TABLE(l_resp, '$.items[*]'
                       COLUMNS (
                           message_line_id  NUMBER                  PATH '$.MessageLineId',
                           source_system_id VARCHAR2(4000) TRUNCATE PATH '$.SourceSystemId',
                           dat_file_name    VARCHAR2(240)  TRUNCATE PATH '$.DatFileName',
                           file_line        NUMBER                  PATH '$.FileLine',
                           business_object  VARCHAR2(240)  TRUNCATE PATH '$.BusinessObjectDiscriminator',
                           message_type     VARCHAR2(30)   TRUNCATE PATH '$.MessageTypeCode',
                           message_text     VARCHAR2(4000) TRUNCATE PATH '$.MessageText')) jt
            WHERE  jt.message_text IS NOT NULL
            AND    (jt.message_type IS NULL OR jt.message_type = 'ERROR');
            x_message_count := x_message_count + SQL%ROWCOUNT;

            l_items    := JSON_VALUE(l_resp, '$.count' RETURNING NUMBER);
            l_has_more := JSON_VALUE(l_resp, '$.hasMore');
            EXIT WHEN NVL(l_has_more, 'false') <> 'true' OR NVL(l_items, 0) = 0;

            IF l_page >= C_MAX_PAGES THEN
                RAISE_APPLICATION_ERROR(-20131,
                    'STAGE_HDL_MESSAGES: request ' || p_request_id || ' still reports more '
                    || 'messages after ' || C_MAX_PAGES || ' pages; stopping.');
            END IF;
            l_offset := l_offset + l_items;
        END LOOP;

        DMT_UTIL_PKG.LOG(p_run_id,
            'STAGE_HDL_MESSAGES complete. RequestId: ' || p_request_id ||
            ' | pages read: ' || l_page || ' | error messages staged: ' || x_message_count,
            'INFO', C_PKG, l_proc);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'STAGE_HDL_MESSAGES failed while ' || l_step || '.',
                SQLERRM, C_PKG, l_proc);
            RAISE;
    END STAGE_HDL_MESSAGES;

    -- --------------------------------------------------------
    -- ROW_ERRORS (backlog #288) -- see spec. Exact SourceSystemId equality.
    -- --------------------------------------------------------
    FUNCTION ROW_ERRORS (
        p_request_id         IN VARCHAR2,
        p_source_system_id   IN VARCHAR2,
        p_source_system_id_2 IN VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2 IS
        l_text VARCHAR2(4000);
    BEGIN
        SELECT LISTAGG(m.ERROR_TEXT, ' | ' ON OVERFLOW TRUNCATE)
                   WITHIN GROUP (ORDER BY m.DAT_FILE_NAME, m.FILE_LINE, m.MESSAGE_LINE_ID)
        INTO   l_text
        FROM   DMT_HDL_MESSAGE_GTT m
        WHERE  m.REQUEST_ID = TO_NUMBER(p_request_id)
        AND    m.SOURCE_SYSTEM_ID IN (p_source_system_id, p_source_system_id_2);
        RETURN l_text;
    END ROW_ERRORS;

    -- --------------------------------------------------------
    -- FILE_LEVEL_ERRORS (backlog #288) -- see spec.
    -- --------------------------------------------------------
    FUNCTION FILE_LEVEL_ERRORS (
        p_request_id    IN VARCHAR2,
        p_dat_file_name IN VARCHAR2
    ) RETURN VARCHAR2 IS
        l_text VARCHAR2(4000);
    BEGIN
        SELECT LISTAGG(m.ERROR_TEXT, ' | ' ON OVERFLOW TRUNCATE)
                   WITHIN GROUP (ORDER BY m.DAT_FILE_NAME, m.FILE_LINE, m.MESSAGE_LINE_ID)
        INTO   l_text
        FROM   DMT_HDL_MESSAGE_GTT m
        WHERE  m.REQUEST_ID = TO_NUMBER(p_request_id)
        AND    m.SOURCE_SYSTEM_ID IS NULL
        AND    (m.DAT_FILE_NAME = p_dat_file_name OR m.DAT_FILE_NAME IS NULL);
        RETURN l_text;
    END FILE_LEVEL_ERRORS;

    -- --------------------------------------------------------
    -- BUILD_DAT_HEADER
    -- --------------------------------------------------------
    FUNCTION BUILD_DAT_HEADER (
        p_business_object IN VARCHAR2,
        p_columns         IN VARCHAR2
    ) RETURN VARCHAR2 IS
    BEGIN
        RETURN 'METADATA|' || p_business_object || '|' || p_columns || CHR(10);
    END BUILD_DAT_HEADER;

    -- --------------------------------------------------------
    -- APPEND_DAT_LINE
    -- --------------------------------------------------------
    PROCEDURE APPEND_DAT_LINE (
        p_clob           IN OUT NOCOPY CLOB,
        p_values         IN VARCHAR2,
        p_action         IN VARCHAR2 DEFAULT 'MERGE',
        p_discriminator  IN VARCHAR2 DEFAULT NULL
    ) IS
        l_line VARCHAR2(32767);
    BEGIN
        -- HDL format: ACTION|FileDiscriminator|val1|val2|...
        -- The file discriminator (business object component name) is required
        -- as the second field on every data line.
        IF p_discriminator IS NOT NULL THEN
            l_line := p_action || '|' || p_discriminator || '|' || p_values || CHR(10);
        ELSE
            l_line := p_action || '|' || p_values || CHR(10);
        END IF;
        DBMS_LOB.WRITEAPPEND(p_clob, LENGTH(l_line), l_line);
    END APPEND_DAT_LINE;

    -- --------------------------------------------------------
    -- LOOKUP_FUSION_IDS
    -- Post-reconciliation HCM REST lookup to populate
    -- Fusion-assigned IDs on LOADED TFM rows.
    -- --------------------------------------------------------
    PROCEDURE LOOKUP_FUSION_IDS (
        p_run_id IN NUMBER,
        p_object_type    IN VARCHAR2,
        p_log_context    IN VARCHAR2 DEFAULT NULL
    ) IS
        l_proc      VARCHAR2(100) := NVL(p_log_context, '') || ' > LOOKUP_FUSION_IDS';
        l_base_url  VARCHAR2(500);
        l_url       VARCHAR2(2000);
        l_response  CLOB;
        l_person_id NUMBER;
        l_asgn_id   NUMBER;
        l_salary_id NUMBER;
        l_fusion_id NUMBER;   -- generic captured id for the extended HDL objects
        l_ok_count  NUMBER := 0;
        l_err_count NUMBER := 0;
        l_total     NUMBER := 0;

        -- Worker cursor: LOADED rows with NULL FUSION_PERSON_ID
        CURSOR c_workers IS
            SELECT TFM_SEQUENCE_ID, PERSON_NUMBER
            FROM DMT_WORKER_TFM_TBL
            WHERE RUN_ID = p_run_id
              AND TFM_STATUS = 'LOADED'
              AND FUSION_PERSON_ID IS NULL;

        -- Assignment cursor: LOADED rows with NULL FUSION_ASSIGNMENT_ID.
        -- ASSIGNMENT_NUMBER is carried so each row can be matched to its OWN
        -- assignment in the worker's assignments child (a person may have
        -- more than one assignment), instead of blindly taking assignments[0].
        CURSOR c_assignments IS
            SELECT TFM_SEQUENCE_ID, PERSON_NUMBER, ASSIGNMENT_NUMBER
            FROM DMT_ASSIGNMENT_TFM_TBL
            WHERE RUN_ID = p_run_id
              AND TFM_STATUS = 'LOADED'
              AND FUSION_ASSIGNMENT_ID IS NULL;

        -- Salary cursor: LOADED rows with NULL FUSION_SALARY_ID
        -- Requires FUSION_PERSON_ID from the worker TFM to be populated first
        CURSOR c_salaries IS
            SELECT s.TFM_SEQUENCE_ID, s.PERSON_NUMBER, w.FUSION_PERSON_ID
            FROM DMT_SALARY_TFM_TBL s
            LEFT JOIN DMT_WORKER_TFM_TBL w
              ON  w.PERSON_NUMBER = s.PERSON_NUMBER
              AND w.RUN_ID = s.RUN_ID
              AND w.TFM_STATUS = 'LOADED'
              AND w.FUSION_PERSON_ID IS NOT NULL
            WHERE s.RUN_ID = p_run_id
              AND s.TFM_STATUS = 'LOADED'
              AND s.FUSION_SALARY_ID IS NULL;

        -- ==================================================================
        -- Extended HDL objects (design section 5 source map). Each resolves
        -- the worker's PersonId from the LOADED worker TFM (same dependency
        -- as Salary), then reads the object's person-scoped HCM REST child
        -- resource. NOTE: none of these objects loads to its Fusion base
        -- table on the demo instance today (per-object blockers documented
        -- in objects/{Object}/README.md and the HCM live-state notes), so
        -- these cursors will return zero LOADED rows and populate nothing
        -- until the object itself loads. The lookup/UPDATE wiring follows
        -- the exact Worker/Assignment/Salary pattern so no further plumbing
        -- is needed once an object goes live; the REST resource paths below
        -- are the documented HCM REST resources and must be confirmed
        -- against a real loaded record before that object is declared live.
        -- ==================================================================

        -- PayrollRelationships -> PAY_PAY_RELATIONSHIPS_DN.PAYROLL_RELATIONSHIP_ID
        CURSOR c_payroll_rels IS
            SELECT p.TFM_SEQUENCE_ID, p.PERSON_NUMBER, w.FUSION_PERSON_ID
            FROM DMT_PAY_REL_TFM_TBL p
            LEFT JOIN DMT_WORKER_TFM_TBL w
              ON  w.PERSON_NUMBER = p.PERSON_NUMBER
              AND w.RUN_ID = p.RUN_ID
              AND w.TFM_STATUS = 'LOADED'
              AND w.FUSION_PERSON_ID IS NOT NULL
            WHERE p.RUN_ID = p_run_id
              AND p.TFM_STATUS = 'LOADED'
              AND p.FUSION_PAYROLL_RELATIONSHIP_ID IS NULL;

        -- TalentProfiles -> HRT_PROFILES_B.PROFILE_ID
        CURSOR c_talent_profiles IS
            SELECT tp.TFM_SEQUENCE_ID, tp.PERSON_NUMBER, w.FUSION_PERSON_ID
            FROM DMT_TALENT_PROF_TFM_TBL tp
            LEFT JOIN DMT_WORKER_TFM_TBL w
              ON  w.PERSON_NUMBER = tp.PERSON_NUMBER
              AND w.RUN_ID = tp.RUN_ID
              AND w.TFM_STATUS = 'LOADED'
              AND w.FUSION_PERSON_ID IS NOT NULL
            WHERE tp.RUN_ID = p_run_id
              AND tp.TFM_STATUS = 'LOADED'
              AND tp.FUSION_PROFILE_ID IS NULL;

        -- Absences -> ANC_PER_ABS_ENTRIES.PER_ABSENCE_ENTRY_ID
        CURSOR c_absences IS
            SELECT a.TFM_SEQUENCE_ID, a.PERSON_NUMBER, w.FUSION_PERSON_ID
            FROM DMT_ABSENCE_TFM_TBL a
            LEFT JOIN DMT_WORKER_TFM_TBL w
              ON  w.PERSON_NUMBER = a.PERSON_NUMBER
              AND w.RUN_ID = a.RUN_ID
              AND w.TFM_STATUS = 'LOADED'
              AND w.FUSION_PERSON_ID IS NOT NULL
            WHERE a.RUN_ID = p_run_id
              AND a.TFM_STATUS = 'LOADED'
              AND a.FUSION_ABSENCE_ENTRY_ID IS NULL;

        -- TaxCards -> the DIR card id
        CURSOR c_tax_cards IS
            SELECT tc.TFM_SEQUENCE_ID, tc.PERSON_NUMBER, w.FUSION_PERSON_ID
            FROM DMT_TAX_CARD_TFM_TBL tc
            LEFT JOIN DMT_WORKER_TFM_TBL w
              ON  w.PERSON_NUMBER = tc.PERSON_NUMBER
              AND w.RUN_ID = tc.RUN_ID
              AND w.TFM_STATUS = 'LOADED'
              AND w.FUSION_PERSON_ID IS NOT NULL
            WHERE tc.RUN_ID = p_run_id
              AND tc.TFM_STATUS = 'LOADED'
              AND tc.FUSION_DIR_CARD_ID IS NULL;

        -- TaxCard components -> the DIR card component id.
        -- Each component belongs to the person's deduction card, so it is
        -- matched to the card TFM row (same PERSON_NUMBER + RUN_ID) to reuse
        -- the already-captured FUSION_DIR_CARD_ID, then resolved to its own
        -- component id inside the card's cardComponents child by COMPONENT_NAME.
        CURSOR c_tax_card_comps IS
            SELECT cc.TFM_SEQUENCE_ID, cc.PERSON_NUMBER, cc.COMPONENT_NAME,
                   tc.FUSION_DIR_CARD_ID
            FROM DMT_TAX_CARD_COMP_TFM_TBL cc
            LEFT JOIN DMT_TAX_CARD_TFM_TBL tc
              ON  tc.PERSON_NUMBER = cc.PERSON_NUMBER
              AND tc.RUN_ID = cc.RUN_ID
              AND tc.TFM_STATUS = 'LOADED'
              AND tc.FUSION_DIR_CARD_ID IS NOT NULL
            WHERE cc.RUN_ID = p_run_id
              AND cc.TFM_STATUS = 'LOADED'
              AND cc.FUSION_DIR_CARD_COMP_ID IS NULL;

        -- W2Balances -> the person balance id
        CURSOR c_w2_balances IS
            SELECT b.TFM_SEQUENCE_ID, b.PERSON_NUMBER, w.FUSION_PERSON_ID
            FROM DMT_W2_BAL_TFM_TBL b
            LEFT JOIN DMT_WORKER_TFM_TBL w
              ON  w.PERSON_NUMBER = b.PERSON_NUMBER
              AND w.RUN_ID = b.RUN_ID
              AND w.TFM_STATUS = 'LOADED'
              AND w.FUSION_PERSON_ID IS NOT NULL
            WHERE b.RUN_ID = p_run_id
              AND b.TFM_STATUS = 'LOADED'
              AND b.FUSION_BALANCE_ID IS NULL;

        -- WorkSchedules -> the assigned work schedule id
        CURSOR c_work_schedules IS
            SELECT ws.TFM_SEQUENCE_ID, ws.PERSON_NUMBER, w.FUSION_PERSON_ID
            FROM DMT_WORK_SCHED_TFM_TBL ws
            LEFT JOIN DMT_WORKER_TFM_TBL w
              ON  w.PERSON_NUMBER = ws.PERSON_NUMBER
              AND w.RUN_ID = ws.RUN_ID
              AND w.TFM_STATUS = 'LOADED'
              AND w.FUSION_PERSON_ID IS NOT NULL
            WHERE ws.RUN_ID = p_run_id
              AND ws.TFM_STATUS = 'LOADED'
              AND ws.FUSION_SCHEDULE_ID IS NULL;

        -- PerfEvaluations -> the performance evaluation id
        CURSOR c_perf_evals IS
            SELECT pe.TFM_SEQUENCE_ID, pe.PERSON_NUMBER, w.FUSION_PERSON_ID
            FROM DMT_PERF_EVAL_TFM_TBL pe
            LEFT JOIN DMT_WORKER_TFM_TBL w
              ON  w.PERSON_NUMBER = pe.PERSON_NUMBER
              AND w.RUN_ID = pe.RUN_ID
              AND w.TFM_STATUS = 'LOADED'
              AND w.FUSION_PERSON_ID IS NOT NULL
            WHERE pe.RUN_ID = p_run_id
              AND pe.TFM_STATUS = 'LOADED'
              AND pe.FUSION_EVALUATION_ID IS NULL;

        -- Benefits participants -> the enrolled participant id
        CURSOR c_ben_partics IS
            SELECT bp.TFM_SEQUENCE_ID, bp.PERSON_NUMBER, w.FUSION_PERSON_ID
            FROM DMT_BEN_PARTIC_TFM_TBL bp
            LEFT JOIN DMT_WORKER_TFM_TBL w
              ON  w.PERSON_NUMBER = bp.PERSON_NUMBER
              AND w.RUN_ID = bp.RUN_ID
              AND w.TFM_STATUS = 'LOADED'
              AND w.FUSION_PERSON_ID IS NOT NULL
            WHERE bp.RUN_ID = p_run_id
              AND bp.TFM_STATUS = 'LOADED'
              AND bp.FUSION_PARTICIPANT_ID IS NULL;

        -- Benefits beneficiaries -> the beneficiary id
        CURSOR c_ben_benfys IS
            SELECT bb.TFM_SEQUENCE_ID, bb.PERSON_NUMBER, w.FUSION_PERSON_ID
            FROM DMT_BEN_BENFY_TFM_TBL bb
            LEFT JOIN DMT_WORKER_TFM_TBL w
              ON  w.PERSON_NUMBER = bb.PERSON_NUMBER
              AND w.RUN_ID = bb.RUN_ID
              AND w.TFM_STATUS = 'LOADED'
              AND w.FUSION_PERSON_ID IS NOT NULL
            WHERE bb.RUN_ID = p_run_id
              AND bb.TFM_STATUS = 'LOADED'
              AND bb.FUSION_BENEFICIARY_ID IS NULL;

        -- Benefits dependents -> the dependent id
        CURSOR c_ben_depends IS
            SELECT bd.TFM_SEQUENCE_ID, bd.PERSON_NUMBER, w.FUSION_PERSON_ID
            FROM DMT_BEN_DEPEND_TFM_TBL bd
            LEFT JOIN DMT_WORKER_TFM_TBL w
              ON  w.PERSON_NUMBER = bd.PERSON_NUMBER
              AND w.RUN_ID = bd.RUN_ID
              AND w.TFM_STATUS = 'LOADED'
              AND w.FUSION_PERSON_ID IS NOT NULL
            WHERE bd.RUN_ID = p_run_id
              AND bd.TFM_STATUS = 'LOADED'
              AND bd.FUSION_DEPENDENT_ID IS NULL;

    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id,
            'LOOKUP_FUSION_IDS start. ObjectType: ' || p_object_type,
            'INFO', C_PKG, l_proc);

        l_base_url := get_url() || 'hcmRestApi/resources/11.13.18.05/workers';

        -- ======================================================
        -- Worker: query workers?q=PersonNumber=X to get PersonId
        -- ======================================================
        IF p_object_type = 'Worker' THEN
            FOR r IN c_workers LOOP
                l_total := l_total + 1;
                BEGIN
                    l_url := l_base_url ||
                             '?q=PersonNumber=' || UTL_URL.ESCAPE(r.PERSON_NUMBER, TRUE) ||
                             '&fields=PersonId,PersonNumber&onlyData=true';

                    l_response := REST_HTTP(
                        p_url            => l_url,
                        p_method         => 'GET',
                        p_run_id => p_run_id);

                    -- Parse PersonId from JSON: {"items":[{"PersonId":300000012345678,...}]}
                    l_person_id := TO_NUMBER(
                        JSON_VALUE(l_response, '$.items[0].PersonId'));

                    IF l_person_id IS NOT NULL THEN
                        UPDATE DMT_WORKER_TFM_TBL
                        SET FUSION_PERSON_ID = l_person_id,
                            LAST_UPDATED_DATE = SYSDATE
                        WHERE TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;
                        l_ok_count := l_ok_count + 1;
                    ELSE
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'PersonId not found for PersonNumber: ' || r.PERSON_NUMBER ||
                            ' | Response empty or no items.',
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
                    END IF;

                EXCEPTION
                    WHEN OTHERS THEN
                        l_err_count := l_err_count + 1;
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'Worker lookup failed for PersonNumber: ' || r.PERSON_NUMBER ||
                            ' | ' || SQLERRM,
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
                END;
            END LOOP;

        -- ======================================================
        -- Assignment: query workers?q=PersonNumber=X with expand=assignments
        -- ======================================================
        ELSIF p_object_type = 'Assignment' THEN
            FOR r IN c_assignments LOOP
                l_total := l_total + 1;
                BEGIN
                    -- Expand the worker's assignments child and ask for both
                    -- AssignmentNumber and AssignmentId so we can match this
                    -- TFM row to its OWN assignment by number. A person may
                    -- have several assignments; taking assignments[0] would
                    -- give every one of that person's rows the first
                    -- assignment's id (the classic multi-assignment bug).
                    -- expand=assignments returns the full assignments child,
                    -- which includes AssignmentNumber and AssignmentId. We do
                    -- not narrow the child fields (nested field selectors are
                    -- fragile across Fusion releases); the top-level worker is
                    -- trimmed to PersonId only.
                    l_url := l_base_url ||
                             '?q=PersonNumber=' || UTL_URL.ESCAPE(r.PERSON_NUMBER, TRUE) ||
                             '&fields=PersonId&expand=assignments&onlyData=true';

                    l_response := REST_HTTP(
                        p_url            => l_url,
                        p_method         => 'GET',
                        p_run_id => p_run_id);

                    -- The generator emits the assignment's AssignmentNumber as
                    -- the RAW source value (DMT_ASSIGNMENT_HDL_GEN_PKG uses
                    -- pv(ASSIGNMENT_NUMBER), no run prefix), and the transform
                    -- stores it raw in DMT_ASSIGNMENT_TFM_TBL.ASSIGNMENT_NUMBER.
                    -- So Fusion holds the same raw number this TFM row carries
                    -- and we match raw-to-raw. Structured JSON parsing only:
                    -- pull every assignment (number + id) and pick the one whose
                    -- number equals this row's. No offset/string arithmetic.
                    l_asgn_id := NULL;

                    BEGIN
                        SELECT TO_NUMBER(jt.assignment_id)
                        INTO   l_asgn_id
                        FROM   JSON_TABLE(
                                   l_response,
                                   '$.items[0].assignments[*]'
                                   COLUMNS (
                                       assignment_number VARCHAR2(120) PATH '$.AssignmentNumber',
                                       assignment_id     VARCHAR2(40)  PATH '$.AssignmentId'
                                   )
                               ) jt
                        WHERE  jt.assignment_number = r.ASSIGNMENT_NUMBER
                          AND  ROWNUM = 1;
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            l_asgn_id := NULL;
                    END;

                    IF l_asgn_id IS NOT NULL THEN
                        UPDATE DMT_ASSIGNMENT_TFM_TBL
                        SET FUSION_ASSIGNMENT_ID = l_asgn_id,
                            LAST_UPDATED_DATE = SYSDATE
                        WHERE TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;
                        l_ok_count := l_ok_count + 1;
                    ELSE
                        -- No assignment in the response carried this row's
                        -- number. Leave FUSION_ASSIGNMENT_ID null (unconfirmed)
                        -- and log honestly. Never fall back to assignments[0].
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'AssignmentId not confirmed for PersonNumber: ' || r.PERSON_NUMBER ||
                            ' AssignmentNumber: ' || r.ASSIGNMENT_NUMBER ||
                            ' | No assignment with that number in the worker response.',
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
                    END IF;

                EXCEPTION
                    WHEN OTHERS THEN
                        l_err_count := l_err_count + 1;
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'Assignment lookup failed for PersonNumber: ' || r.PERSON_NUMBER ||
                            ' | ' || SQLERRM,
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
                END;
            END LOOP;

        -- ======================================================
        -- Salary: query workers/{PersonId}/child/salaries
        -- ======================================================
        ELSIF p_object_type = 'Salary' THEN
            FOR r IN c_salaries LOOP
                l_total := l_total + 1;
                BEGIN
                    IF r.FUSION_PERSON_ID IS NULL THEN
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'Salary lookup skipped for PersonNumber: ' || r.PERSON_NUMBER ||
                            ' | No FUSION_PERSON_ID available from worker TFM.',
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
                        l_err_count := l_err_count + 1;
                        CONTINUE;
                    END IF;

                    l_url := l_base_url || '/' || r.FUSION_PERSON_ID ||
                             '/child/salaries?onlyData=true';

                    l_response := REST_HTTP(
                        p_url            => l_url,
                        p_method         => 'GET',
                        p_run_id => p_run_id);

                    -- Parse SalaryId from the first salary child
                    l_salary_id := TO_NUMBER(
                        JSON_VALUE(l_response, '$.items[0].SalaryId'));

                    IF l_salary_id IS NOT NULL THEN
                        UPDATE DMT_SALARY_TFM_TBL
                        SET FUSION_SALARY_ID = l_salary_id,
                            LAST_UPDATED_DATE = SYSDATE
                        WHERE TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;
                        l_ok_count := l_ok_count + 1;
                    ELSE
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'SalaryId not found for PersonNumber: ' || r.PERSON_NUMBER ||
                            ' (PersonId: ' || r.FUSION_PERSON_ID || ')' ||
                            ' | Response empty or no salary items.',
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
                    END IF;

                EXCEPTION
                    WHEN OTHERS THEN
                        l_err_count := l_err_count + 1;
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'Salary lookup failed for PersonNumber: ' || r.PERSON_NUMBER ||
                            ' | ' || SQLERRM,
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
                END;
            END LOOP;

        -- ======================================================
        -- PayrollRelationship: workers/{PersonId}/child/workRelationships
        --   /child/... — PayrollRelationshipId on the payroll-relationship
        --   child. Blocked today (the worker HIRE auto-creates the payroll
        --   relationship, so a separate object collides); populates only for
        --   an EXISTING-worker target once that path loads.
        -- ======================================================
        ELSIF p_object_type = 'PayrollRelationship' THEN
            FOR r IN c_payroll_rels LOOP
                l_total := l_total + 1;
                BEGIN
                    IF r.FUSION_PERSON_ID IS NULL THEN
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'PayrollRelationship lookup skipped for PersonNumber: ' || r.PERSON_NUMBER ||
                            ' | No FUSION_PERSON_ID available from worker TFM.',
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
                        l_err_count := l_err_count + 1;
                        CONTINUE;
                    END IF;

                    l_url := l_base_url || '/' || r.FUSION_PERSON_ID ||
                             '/child/workRelationships?fields=PayrollRelationshipId&onlyData=true';
                    l_response := REST_HTTP(p_url => l_url, p_method => 'GET', p_run_id => p_run_id);
                    l_fusion_id := TO_NUMBER(
                        JSON_VALUE(l_response, '$.items[0].PayrollRelationshipId'));

                    IF l_fusion_id IS NOT NULL THEN
                        UPDATE DMT_PAY_REL_TFM_TBL
                        SET FUSION_PAYROLL_RELATIONSHIP_ID = l_fusion_id,
                            LAST_UPDATED_DATE = SYSDATE
                        WHERE TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;
                        l_ok_count := l_ok_count + 1;
                    ELSE
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'PayrollRelationshipId not found for PersonNumber: ' || r.PERSON_NUMBER,
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
                    END IF;
                EXCEPTION
                    WHEN OTHERS THEN
                        l_err_count := l_err_count + 1;
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'PayrollRelationship lookup failed for PersonNumber: ' || r.PERSON_NUMBER ||
                            ' | ' || SQLERRM,
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
                END;
            END LOOP;

        -- ======================================================
        -- TalentProfiles: talentProfiles?q=PersonId=X — ProfileId.
        --   Blocked today (the DAT imports but the load errors, 0 loaded);
        --   populates once the profile reaches HRT_PROFILES_B.
        -- ======================================================
        ELSIF p_object_type = 'TalentProfiles' THEN
            FOR r IN c_talent_profiles LOOP
                l_total := l_total + 1;
                BEGIN
                    IF r.FUSION_PERSON_ID IS NULL THEN
                        l_err_count := l_err_count + 1;
                        CONTINUE;
                    END IF;
                    l_url := get_url() || 'hcmRestApi/resources/11.13.18.05/talentProfiles' ||
                             '?q=PersonId=' || r.FUSION_PERSON_ID ||
                             '&fields=ProfileId&onlyData=true';
                    l_response := REST_HTTP(p_url => l_url, p_method => 'GET', p_run_id => p_run_id);
                    l_fusion_id := TO_NUMBER(JSON_VALUE(l_response, '$.items[0].ProfileId'));
                    IF l_fusion_id IS NOT NULL THEN
                        UPDATE DMT_TALENT_PROF_TFM_TBL
                        SET FUSION_PROFILE_ID = l_fusion_id, LAST_UPDATED_DATE = SYSDATE
                        WHERE TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;
                        l_ok_count := l_ok_count + 1;
                    ELSE
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'ProfileId not found for PersonNumber: ' || r.PERSON_NUMBER,
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
                    END IF;
                EXCEPTION
                    WHEN OTHERS THEN
                        l_err_count := l_err_count + 1;
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'TalentProfiles lookup failed for PersonNumber: ' || r.PERSON_NUMBER ||
                            ' | ' || SQLERRM, DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
                END;
            END LOOP;

        -- ======================================================
        -- Absences: absences?q=PersonId=X — PersonAbsenceEntryId.
        --   Blocked today (instance approval-workflow config rejects the
        --   absence status); populates once ANC_PER_ABS_ENTRIES accepts it.
        -- ======================================================
        ELSIF p_object_type = 'Absences' THEN
            FOR r IN c_absences LOOP
                l_total := l_total + 1;
                BEGIN
                    IF r.FUSION_PERSON_ID IS NULL THEN
                        l_err_count := l_err_count + 1;
                        CONTINUE;
                    END IF;
                    l_url := get_url() || 'hcmRestApi/resources/11.13.18.05/absences' ||
                             '?q=PersonId=' || r.FUSION_PERSON_ID ||
                             '&fields=PersonAbsenceEntryId&onlyData=true';
                    l_response := REST_HTTP(p_url => l_url, p_method => 'GET', p_run_id => p_run_id);
                    l_fusion_id := TO_NUMBER(JSON_VALUE(l_response, '$.items[0].PersonAbsenceEntryId'));
                    IF l_fusion_id IS NOT NULL THEN
                        UPDATE DMT_ABSENCE_TFM_TBL
                        SET FUSION_ABSENCE_ENTRY_ID = l_fusion_id, LAST_UPDATED_DATE = SYSDATE
                        WHERE TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;
                        l_ok_count := l_ok_count + 1;
                    ELSE
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'PersonAbsenceEntryId not found for PersonNumber: ' || r.PERSON_NUMBER,
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
                    END IF;
                EXCEPTION
                    WHEN OTHERS THEN
                        l_err_count := l_err_count + 1;
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'Absences lookup failed for PersonNumber: ' || r.PERSON_NUMBER ||
                            ' | ' || SQLERRM, DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
                END;
            END LOOP;

        -- ======================================================
        -- TaxCards: workers/{PersonId}/child/... deduction card id.
        --   Blocked today (generator can't supply SourceType on the DIR
        --   card child + the worker needs a Tax Reporting Unit association).
        -- ======================================================
        ELSIF p_object_type = 'TaxCards' THEN
            FOR r IN c_tax_cards LOOP
                l_total := l_total + 1;
                BEGIN
                    IF r.FUSION_PERSON_ID IS NULL THEN
                        l_err_count := l_err_count + 1;
                        CONTINUE;
                    END IF;
                    l_url := get_url() || 'hcmRestApi/resources/11.13.18.05/payrollDeductionCards' ||
                             '?q=PersonId=' || r.FUSION_PERSON_ID ||
                             '&fields=DeductionCardId&onlyData=true';
                    l_response := REST_HTTP(p_url => l_url, p_method => 'GET', p_run_id => p_run_id);
                    l_fusion_id := TO_NUMBER(JSON_VALUE(l_response, '$.items[0].DeductionCardId'));
                    IF l_fusion_id IS NOT NULL THEN
                        UPDATE DMT_TAX_CARD_TFM_TBL
                        SET FUSION_DIR_CARD_ID = l_fusion_id, LAST_UPDATED_DATE = SYSDATE
                        WHERE TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;
                        l_ok_count := l_ok_count + 1;
                    ELSE
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'DeductionCardId not found for PersonNumber: ' || r.PERSON_NUMBER,
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
                    END IF;
                EXCEPTION
                    WHEN OTHERS THEN
                        l_err_count := l_err_count + 1;
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'TaxCards lookup failed for PersonNumber: ' || r.PERSON_NUMBER ||
                            ' | ' || SQLERRM, DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
                END;
            END LOOP;

            -- Card components: each LOADED component row is resolved to its own
            -- Fusion component id (DIR_CARD_COMP_ID) inside its card's
            -- cardComponents child, matched by ComponentName. Reuses the card's
            -- captured FUSION_DIR_CARD_ID (populated by the loop above).
            FOR cr IN c_tax_card_comps LOOP
                l_total := l_total + 1;
                BEGIN
                    IF cr.FUSION_DIR_CARD_ID IS NULL THEN
                        l_err_count := l_err_count + 1;
                        CONTINUE;
                    END IF;
                    l_url := get_url() || 'hcmRestApi/resources/11.13.18.05/payrollDeductionCards/' ||
                             cr.FUSION_DIR_CARD_ID || '/child/cardComponents' ||
                             '?q=ComponentName=''' || UTL_URL.ESCAPE(REPLACE(cr.COMPONENT_NAME, '''', ''''''), TRUE) || '''' ||
                             '&fields=CardComponentId&onlyData=true';
                    l_response := REST_HTTP(p_url => l_url, p_method => 'GET', p_run_id => p_run_id);
                    l_fusion_id := TO_NUMBER(JSON_VALUE(l_response, '$.items[0].CardComponentId'));
                    IF l_fusion_id IS NOT NULL THEN
                        UPDATE DMT_TAX_CARD_COMP_TFM_TBL
                        SET FUSION_DIR_CARD_COMP_ID = l_fusion_id, LAST_UPDATED_DATE = SYSDATE
                        WHERE TFM_SEQUENCE_ID = cr.TFM_SEQUENCE_ID;
                        l_ok_count := l_ok_count + 1;
                    ELSE
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'CardComponentId not found for PersonNumber: ' || cr.PERSON_NUMBER ||
                            ', ComponentName: ' || cr.COMPONENT_NAME,
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
                    END IF;
                EXCEPTION
                    WHEN OTHERS THEN
                        l_err_count := l_err_count + 1;
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'TaxCard component lookup failed for PersonNumber: ' || cr.PERSON_NUMBER ||
                            ', ComponentName: ' || cr.COMPONENT_NAME ||
                            ' | ' || SQLERRM, DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
                END;
            END LOOP;

        -- ======================================================
        -- W2Balances: personBalances?q=PersonId=X — the balance id.
        --   Blocked today (not yet seeded); populates once loaded.
        -- ======================================================
        ELSIF p_object_type = 'W2Balances' THEN
            FOR r IN c_w2_balances LOOP
                l_total := l_total + 1;
                BEGIN
                    IF r.FUSION_PERSON_ID IS NULL THEN
                        l_err_count := l_err_count + 1;
                        CONTINUE;
                    END IF;
                    l_url := get_url() || 'hcmRestApi/resources/11.13.18.05/balances' ||
                             '?q=PersonId=' || r.FUSION_PERSON_ID ||
                             '&fields=BalanceId&onlyData=true';
                    l_response := REST_HTTP(p_url => l_url, p_method => 'GET', p_run_id => p_run_id);
                    l_fusion_id := TO_NUMBER(JSON_VALUE(l_response, '$.items[0].BalanceId'));
                    IF l_fusion_id IS NOT NULL THEN
                        UPDATE DMT_W2_BAL_TFM_TBL
                        SET FUSION_BALANCE_ID = l_fusion_id, LAST_UPDATED_DATE = SYSDATE
                        WHERE TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;
                        l_ok_count := l_ok_count + 1;
                    ELSE
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'BalanceId not found for PersonNumber: ' || r.PERSON_NUMBER,
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
                    END IF;
                EXCEPTION
                    WHEN OTHERS THEN
                        l_err_count := l_err_count + 1;
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'W2Balances lookup failed for PersonNumber: ' || r.PERSON_NUMBER ||
                            ' | ' || SQLERRM, DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
                END;
            END LOOP;

        -- ======================================================
        -- WorkSchedules: workScheduleAssignmentsDEO?q=PersonId=X — the
        --   assigned schedule id. Blocked today (not yet seeded).
        -- ======================================================
        ELSIF p_object_type = 'WorkSchedules' THEN
            FOR r IN c_work_schedules LOOP
                l_total := l_total + 1;
                BEGIN
                    IF r.FUSION_PERSON_ID IS NULL THEN
                        l_err_count := l_err_count + 1;
                        CONTINUE;
                    END IF;
                    l_url := get_url() || 'hcmRestApi/resources/11.13.18.05/workScheduleAssignments' ||
                             '?q=PersonId=' || r.FUSION_PERSON_ID ||
                             '&fields=WorkScheduleId&onlyData=true';
                    l_response := REST_HTTP(p_url => l_url, p_method => 'GET', p_run_id => p_run_id);
                    l_fusion_id := TO_NUMBER(JSON_VALUE(l_response, '$.items[0].WorkScheduleId'));
                    IF l_fusion_id IS NOT NULL THEN
                        UPDATE DMT_WORK_SCHED_TFM_TBL
                        SET FUSION_SCHEDULE_ID = l_fusion_id, LAST_UPDATED_DATE = SYSDATE
                        WHERE TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;
                        l_ok_count := l_ok_count + 1;
                    ELSE
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'WorkScheduleId not found for PersonNumber: ' || r.PERSON_NUMBER,
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
                    END IF;
                EXCEPTION
                    WHEN OTHERS THEN
                        l_err_count := l_err_count + 1;
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'WorkSchedules lookup failed for PersonNumber: ' || r.PERSON_NUMBER ||
                            ' | ' || SQLERRM, DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
                END;
            END LOOP;

        -- ======================================================
        -- PerfEvaluations: performanceRatings?q=PersonId=X — the
        --   evaluation id. Blocked today (not yet seeded).
        -- ======================================================
        ELSIF p_object_type = 'PerfEvaluations' THEN
            FOR r IN c_perf_evals LOOP
                l_total := l_total + 1;
                BEGIN
                    IF r.FUSION_PERSON_ID IS NULL THEN
                        l_err_count := l_err_count + 1;
                        CONTINUE;
                    END IF;
                    l_url := get_url() || 'hcmRestApi/resources/11.13.18.05/performanceRatings' ||
                             '?q=PersonId=' || r.FUSION_PERSON_ID ||
                             '&fields=EvaluationId&onlyData=true';
                    l_response := REST_HTTP(p_url => l_url, p_method => 'GET', p_run_id => p_run_id);
                    l_fusion_id := TO_NUMBER(JSON_VALUE(l_response, '$.items[0].EvaluationId'));
                    IF l_fusion_id IS NOT NULL THEN
                        UPDATE DMT_PERF_EVAL_TFM_TBL
                        SET FUSION_EVALUATION_ID = l_fusion_id, LAST_UPDATED_DATE = SYSDATE
                        WHERE TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;
                        l_ok_count := l_ok_count + 1;
                    ELSE
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'EvaluationId not found for PersonNumber: ' || r.PERSON_NUMBER,
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
                    END IF;
                EXCEPTION
                    WHEN OTHERS THEN
                        l_err_count := l_err_count + 1;
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'PerfEvaluations lookup failed for PersonNumber: ' || r.PERSON_NUMBER ||
                            ' | ' || SQLERRM, DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
                END;
            END LOOP;

        -- ======================================================
        -- Benefits participants: participantEnrollments?q=PersonId=X.
        --   Blocked today (not yet seeded).
        -- ======================================================
        ELSIF p_object_type = 'BenefitsParticipant' THEN
            FOR r IN c_ben_partics LOOP
                l_total := l_total + 1;
                BEGIN
                    IF r.FUSION_PERSON_ID IS NULL THEN
                        l_err_count := l_err_count + 1;
                        CONTINUE;
                    END IF;
                    l_url := get_url() || 'hcmRestApi/resources/11.13.18.05/participantEnrollments' ||
                             '?q=PersonId=' || r.FUSION_PERSON_ID ||
                             '&fields=ParticipantId&onlyData=true';
                    l_response := REST_HTTP(p_url => l_url, p_method => 'GET', p_run_id => p_run_id);
                    l_fusion_id := TO_NUMBER(JSON_VALUE(l_response, '$.items[0].ParticipantId'));
                    IF l_fusion_id IS NOT NULL THEN
                        UPDATE DMT_BEN_PARTIC_TFM_TBL
                        SET FUSION_PARTICIPANT_ID = l_fusion_id, LAST_UPDATED_DATE = SYSDATE
                        WHERE TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;
                        l_ok_count := l_ok_count + 1;
                    ELSE
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'ParticipantId not found for PersonNumber: ' || r.PERSON_NUMBER,
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
                    END IF;
                EXCEPTION
                    WHEN OTHERS THEN
                        l_err_count := l_err_count + 1;
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'BenefitsParticipant lookup failed for PersonNumber: ' || r.PERSON_NUMBER ||
                            ' | ' || SQLERRM, DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
                END;
            END LOOP;

        -- ======================================================
        -- Benefits beneficiaries: beneficiaries?q=PersonId=X.
        --   Blocked today (not yet seeded).
        -- ======================================================
        ELSIF p_object_type = 'BenefitsBeneficiary' THEN
            FOR r IN c_ben_benfys LOOP
                l_total := l_total + 1;
                BEGIN
                    IF r.FUSION_PERSON_ID IS NULL THEN
                        l_err_count := l_err_count + 1;
                        CONTINUE;
                    END IF;
                    l_url := get_url() || 'hcmRestApi/resources/11.13.18.05/beneficiaries' ||
                             '?q=PersonId=' || r.FUSION_PERSON_ID ||
                             '&fields=BeneficiaryId&onlyData=true';
                    l_response := REST_HTTP(p_url => l_url, p_method => 'GET', p_run_id => p_run_id);
                    l_fusion_id := TO_NUMBER(JSON_VALUE(l_response, '$.items[0].BeneficiaryId'));
                    IF l_fusion_id IS NOT NULL THEN
                        UPDATE DMT_BEN_BENFY_TFM_TBL
                        SET FUSION_BENEFICIARY_ID = l_fusion_id, LAST_UPDATED_DATE = SYSDATE
                        WHERE TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;
                        l_ok_count := l_ok_count + 1;
                    ELSE
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'BeneficiaryId not found for PersonNumber: ' || r.PERSON_NUMBER,
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
                    END IF;
                EXCEPTION
                    WHEN OTHERS THEN
                        l_err_count := l_err_count + 1;
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'BenefitsBeneficiary lookup failed for PersonNumber: ' || r.PERSON_NUMBER ||
                            ' | ' || SQLERRM, DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
                END;
            END LOOP;

        -- ======================================================
        -- Benefits dependents: dependents?q=PersonId=X.
        --   Blocked today (not yet seeded).
        -- ======================================================
        ELSIF p_object_type = 'BenefitsDependent' THEN
            FOR r IN c_ben_depends LOOP
                l_total := l_total + 1;
                BEGIN
                    IF r.FUSION_PERSON_ID IS NULL THEN
                        l_err_count := l_err_count + 1;
                        CONTINUE;
                    END IF;
                    l_url := get_url() || 'hcmRestApi/resources/11.13.18.05/dependents' ||
                             '?q=PersonId=' || r.FUSION_PERSON_ID ||
                             '&fields=DependentId&onlyData=true';
                    l_response := REST_HTTP(p_url => l_url, p_method => 'GET', p_run_id => p_run_id);
                    l_fusion_id := TO_NUMBER(JSON_VALUE(l_response, '$.items[0].DependentId'));
                    IF l_fusion_id IS NOT NULL THEN
                        UPDATE DMT_BEN_DEPEND_TFM_TBL
                        SET FUSION_DEPENDENT_ID = l_fusion_id, LAST_UPDATED_DATE = SYSDATE
                        WHERE TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;
                        l_ok_count := l_ok_count + 1;
                    ELSE
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'DependentId not found for PersonNumber: ' || r.PERSON_NUMBER,
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
                    END IF;
                EXCEPTION
                    WHEN OTHERS THEN
                        l_err_count := l_err_count + 1;
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'BenefitsDependent lookup failed for PersonNumber: ' || r.PERSON_NUMBER ||
                            ' | ' || SQLERRM, DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
                END;
            END LOOP;

        ELSE
            DMT_UTIL_PKG.LOG(p_run_id,
                'LOOKUP_FUSION_IDS: unsupported object type: ' || p_object_type,
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
        END IF;

        IF l_total > 0 THEN
            COMMIT;
        END IF;

        DMT_UTIL_PKG.LOG(p_run_id,
            'LOOKUP_FUSION_IDS complete. ObjectType: ' || p_object_type ||
            ' | Total: ' || l_total || ' | Updated: ' || l_ok_count ||
            ' | Errors: ' || l_err_count,
            'INFO', C_PKG, l_proc);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'LOOKUP_FUSION_IDS failed. ObjectType: ' || p_object_type,
                SQLERRM, C_PKG, l_proc);
            RAISE;
    END LOOKUP_FUSION_IDS;

END DMT_HDL_UTIL_PKG;
/
