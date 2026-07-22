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
    -- REST_HTTP
    -- --------------------------------------------------------
    FUNCTION REST_HTTP (
        p_url              IN VARCHAR2,
        p_method           IN VARCHAR2 DEFAULT 'GET',
        p_body             IN CLOB     DEFAULT NULL,
        p_run_id   IN NUMBER   DEFAULT NULL
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
            IF p_run_id IS NOT NULL THEN
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

        -- Initial delay — data set may not be queryable immediately after createFileDataSet
        DBMS_SESSION.SLEEP(10);

        LOOP
            -- GET status — handle 404 gracefully (data set may not be ready yet)
            BEGIN
                l_response := REST_HTTP(
                    p_url            => l_url,
                    p_method         => 'GET',
                    p_run_id => p_run_id);
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
    -- GET_HDL_ERRORS
    -- Retrieves error messages from HCM Data Loader via REST.
    -- Returns JSON CLOB of messages.
    -- --------------------------------------------------------
    FUNCTION GET_HDL_ERRORS (
        p_run_id IN NUMBER,
        p_request_id     IN VARCHAR2,
        p_log_context    IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB IS
        l_url      VARCHAR2(500);
        l_response CLOB;
        l_proc     VARCHAR2(100) := NVL(p_log_context, '') || ' > GET_HDL_ERRORS';
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id,
            'GET_HDL_ERRORS start. RequestId: ' || p_request_id,
            'INFO', C_PKG, l_proc);

        l_url := get_url() || C_HCM_REST_PATH || '/' || p_request_id ||
                 '/child/messages?onlyData=true&orderBy=DatFileName,FileLine&limit=500';

        l_response := REST_HTTP(
            p_url            => l_url,
            p_method         => 'GET',
            p_run_id => p_run_id);

        DMT_UTIL_PKG.LOG(p_run_id,
            'GET_HDL_ERRORS complete. Response length: ' || DBMS_LOB.GETLENGTH(l_response),
            'INFO', C_PKG, l_proc);

        RETURN l_response;

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'GET_HDL_ERRORS failed. RequestId: ' || p_request_id,
                SQLERRM, C_PKG, l_proc);
            RAISE;
    END GET_HDL_ERRORS;

    -- --------------------------------------------------------
    -- RECONCILE_HDL
    -- Parses HDL error messages (JSON) and updates TFM/STG tables.
    -- Marks rows as LOADED (no errors) or FAILED (with error text).
    -- --------------------------------------------------------
    PROCEDURE RECONCILE_HDL (
        p_run_id  IN NUMBER,
        p_request_id      IN VARCHAR2,
        p_tfm_table       IN VARCHAR2,
        p_stg_table       IN VARCHAR2,
        p_key_column      IN VARCHAR2 DEFAULT 'SOURCE_REF',
        p_dataset_status  IN VARCHAR2 DEFAULT NULL,
        p_log_context     IN VARCHAR2 DEFAULT NULL,
        p_key_suffixes    IN VARCHAR2 DEFAULT NULL
    ) IS
        l_json      CLOB;
        l_proc      VARCHAR2(100) := NVL(p_log_context, '') || ' > RECONCILE_HDL';
        l_err_count NUMBER := 0;
        l_ok_count  NUMBER := 0;
        l_gen_count NUMBER := 0;
        l_match     VARCHAR2(4000);
        l_sfx       VARCHAR2(200);
        l_rest      VARCHAR2(4000);
        l_pos       PLS_INTEGER;
        l_ds_resp   CLOB;
        l_load_succ NUMBER;         -- data set ObjectSuccessCount; NULL if unreadable
        l_zero_load BOOLEAN;        -- TRUE only when Fusion loaded ZERO objects
    BEGIN
        -- Build the row<->message match predicate against jt.src_ref (the HDL
        -- SourceSystemId) and t.<p_key_column>.
        --   * No suffixes (person-keyed loads): legacy prefix match. A worker's
        --     name/position/etc. SourceSystemIds all begin with PERSON_NUMBER.
        --   * With suffixes (e.g. '_TRM,_ASG'): EXACT equality against
        --     p_key_column||<suffix>. This is what the Assignment generator emits
        --     ('<ASSIGNMENT_NUMBER>_TRM' / '<ASSIGNMENT_NUMBER>_ASG'), so each
        --     real error lands on its own row and 'G1' never absorbs 'G1B'.
        IF p_key_suffixes IS NULL THEN
            l_match := 'jt.src_ref LIKE t.' || p_key_column || ' || ''%''';
        ELSE
            l_match := '(';
            l_rest  := p_key_suffixes;
            l_pos   := 0;
            LOOP
                l_pos := INSTR(l_rest, ',');
                IF l_pos > 0 THEN
                    l_sfx  := TRIM(SUBSTR(l_rest, 1, l_pos - 1));
                    l_rest := SUBSTR(l_rest, l_pos + 1);
                ELSE
                    l_sfx  := TRIM(l_rest);
                    l_rest := NULL;
                END IF;
                l_match := l_match || 'jt.src_ref = t.' || p_key_column ||
                           ' || ''' || l_sfx || '''';
                EXIT WHEN l_rest IS NULL;
                l_match := l_match || ' OR ';
            END LOOP;
            l_match := l_match || ')';
        END IF;

        DMT_UTIL_PKG.LOG(p_run_id,
            'RECONCILE_HDL start. RequestId: ' || p_request_id ||
            ' | TFM: ' || p_tfm_table || ' | Key: ' || p_key_column ||
            CASE WHEN p_key_suffixes IS NULL THEN ''
                 ELSE ' | Suffixes: ' || p_key_suffixes END ||
            ' | DataSetStatus: ' || NVL(p_dataset_status, '(unknown)'),
            'INFO', C_PKG, l_proc);

        -- Count GENERATED rows before reconciliation
        EXECUTE IMMEDIATE
            'SELECT COUNT(*) FROM DMT_OWNER.' || p_tfm_table ||
            ' WHERE RUN_ID = :iid AND TFM_STATUS = ''GENERATED'''
            INTO l_gen_count USING p_run_id;

        IF l_gen_count = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'No GENERATED rows to reconcile in ' || p_tfm_table,
                'INFO', C_PKG, l_proc);
            RETURN;
        END IF;

        -- Step 1: Get error messages and mark failed rows
        l_json := GET_HDL_ERRORS(p_run_id, p_request_id, p_log_context);

        BEGIN
            EXECUTE IMMEDIATE
                'UPDATE DMT_OWNER.' || p_tfm_table || ' t ' ||
                'SET t.TFM_STATUS = ''FAILED'', ' ||
                '    t.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, ' ||
                '        ''[FUSION_ERROR] '' || (' ||
                '        SELECT LISTAGG(jt.msg, ''; '') WITHIN GROUP (ORDER BY jt.msg) ' ||
                '        FROM JSON_TABLE(:json, ''$.items[*]'' ' ||
                '            COLUMNS (src_ref VARCHAR2(200) PATH ''$.SourceSystemId'', ' ||
                '                     msg VARCHAR2(4000) PATH ''$.MessageText'')) jt ' ||
                '        WHERE ' || l_match || ')), ' ||
                '    t.LAST_UPDATED_DATE = SYSDATE ' ||
                'WHERE t.RUN_ID = :iid ' ||
                'AND   t.TFM_STATUS = ''GENERATED'' ' ||
                'AND   EXISTS ( ' ||
                '    SELECT 1 FROM JSON_TABLE(:json2, ''$.items[*]'' ' ||
                '        COLUMNS (src_ref VARCHAR2(200) PATH ''$.SourceSystemId'')) jt ' ||
                '    WHERE ' || l_match || ')'
                USING l_json, p_run_id, l_json;
            l_err_count := SQL%ROWCOUNT;
        EXCEPTION
            WHEN OTHERS THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    'JSON_TABLE error parse failed: ' || SQLERRM,
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
        END;

        -- Read the data set's actual object-load success count. A remaining row may
        -- be promoted to LOADED only when Fusion loaded at least one object. If the
        -- data set loaded ZERO objects, nothing succeeded this run, so NO row may be
        -- marked LOADED — even the un-errored remainder. (This is the fabrication that
        -- stamped a Worker/Assignment LOADED when the whole file was rejected and only
        -- some errors matched a row.) If the count can't be read, we leave it unknown
        -- and preserve the status-based behaviour rather than mass-fail good loads.
        BEGIN
            l_ds_resp := REST_HTTP(
                p_url    => get_url() || C_HCM_REST_PATH || '/' || p_request_id,
                p_method => 'GET',
                p_run_id => p_run_id);
            l_load_succ := TO_NUMBER(
                REGEXP_SUBSTR(l_ds_resp, '"ObjectSuccessCount"\s*:\s*([0-9]+)', 1, 1, NULL, 1));
        EXCEPTION
            WHEN OTHERS THEN
                l_load_succ := NULL;
        END;
        l_zero_load := (l_load_succ IS NOT NULL AND l_load_succ = 0);

        -- Step 2: Handle remaining GENERATED rows based on data set status
        -- Only mark LOADED if we have positive evidence of success.
        -- If the data set loaded ZERO objects, mark nothing LOADED.
        -- If data set was ORA_COMPLETED, remaining rows are successes.
        -- If data set was ORA_IN_ERROR and we found specific error rows,
        --   remaining rows MAY be successes (partial success) — mark LOADED.
        -- If data set was ORA_IN_ERROR and we found NO error rows, we have no
        --   per-record evidence either way — LEAVE the rows GENERATED (unaccounted).
        --   We never fabricate a FAILED for an outcome we did not observe.
        IF l_zero_load THEN
            -- Fusion loaded 0 objects. No remaining row may be promoted to LOADED;
            -- rows without a matched per-row error stay GENERATED for the honest
            -- UNACCOUNTED sweep. Never assert a success the data set did not report.
            DMT_UTIL_PKG.LOG(p_run_id,
                'Data set ' || p_request_id || ' reports ObjectSuccessCount=0; ' ||
                'not marking any remaining GENERATED row LOADED.',
                'INFO', C_PKG, l_proc);
        ELSIF p_dataset_status IN ('ORA_COMPLETED', 'ORA_SUCCESS', 'SUCCESS') THEN
            -- All remaining are confirmed successes
            EXECUTE IMMEDIATE
                'UPDATE DMT_OWNER.' || p_tfm_table ||
                ' SET TFM_STATUS = ''LOADED'', LAST_UPDATED_DATE = SYSDATE ' ||
                ' WHERE RUN_ID = :iid AND TFM_STATUS = ''GENERATED'''
                USING p_run_id;
            l_ok_count := SQL%ROWCOUNT;
        ELSIF p_dataset_status IN ('ORA_IN_ERROR', 'ERROR', 'WARNING') AND l_err_count > 0 THEN
            -- Partial success: specific rows failed, rest are OK (and the data set
            -- reported at least one successful object load, so l_zero_load is FALSE)
            EXECUTE IMMEDIATE
                'UPDATE DMT_OWNER.' || p_tfm_table ||
                ' SET TFM_STATUS = ''LOADED'', LAST_UPDATED_DATE = SYSDATE ' ||
                ' WHERE RUN_ID = :iid AND TFM_STATUS = ''GENERATED'''
                USING p_run_id;
            l_ok_count := SQL%ROWCOUNT;
        ELSIF p_dataset_status IN ('ORA_IN_ERROR', 'ERROR') AND l_err_count = 0 THEN
            -- Error status but NO row-level error matched this run's rows. We have
            -- no per-record evidence either way, so we must NOT fabricate a FAILED:
            -- the remaining GENERATED rows are LEFT GENERATED (unaccounted). The
            -- accounting gate then reports the object not-DONE and the funnel
            -- surfaces these as UNRECONCILED. (Previously these were stamped
            -- '[FUSION_ERROR] ... no row-level error matched' — a fabricated
            -- fallback that asserted a failure we never observed.)
            NULL;
        ELSE
            -- Unknown / non-terminal status (EXPIRED, etc.). No positive success
            -- and no per-record error observed — LEAVE remaining GENERATED rows
            -- GENERATED (unaccounted) rather than fabricate a FAILED from a bare
            -- status code. The accounting gate + funnel surface them honestly.
            NULL;
        END IF;

        -- Step 3: Echo to STG tables
        BEGIN
            EXECUTE IMMEDIATE
                'UPDATE DMT_OWNER.' || p_stg_table ||
                ' SET STG_STATUS = ''LOADED'', LAST_UPDATED_DATE = SYSDATE ' ||
                ' WHERE STG_STATUS = ''TRANSFORMED'' AND STG_SEQUENCE_ID IN ' ||
                '(SELECT STG_SEQUENCE_ID FROM DMT_OWNER.' || p_tfm_table ||
                ' WHERE RUN_ID = :iid AND TFM_STATUS = ''LOADED'')'
                USING p_run_id;

            EXECUTE IMMEDIATE
                'UPDATE DMT_OWNER.' || p_stg_table ||
                ' SET STG_STATUS = ''FAILED'', LAST_UPDATED_DATE = SYSDATE ' ||
                ' WHERE STG_STATUS = ''TRANSFORMED'' AND STG_SEQUENCE_ID IN ' ||
                '(SELECT STG_SEQUENCE_ID FROM DMT_OWNER.' || p_tfm_table ||
                ' WHERE RUN_ID = :iid AND TFM_STATUS = ''FAILED'')'
                USING p_run_id;
        EXCEPTION
            WHEN OTHERS THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    'STG echo failed: ' || SQLERRM,
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_proc);
        END;

        COMMIT;

        DMT_UTIL_PKG.LOG(p_run_id,
            'RECONCILE_HDL complete. LOADED: ' || l_ok_count || ' | FAILED: ' || l_err_count,
            'INFO', C_PKG, l_proc);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'RECONCILE_HDL failed.',
                SQLERRM, C_PKG, l_proc);
            RAISE;
    END RECONCILE_HDL;

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
            FROM DMT_OWNER.DMT_WORKER_TFM_TBL
            WHERE RUN_ID = p_run_id
              AND TFM_STATUS = 'LOADED'
              AND FUSION_PERSON_ID IS NULL;

        -- Assignment cursor: LOADED rows with NULL FUSION_ASSIGNMENT_ID.
        -- ASSIGNMENT_NUMBER is carried so each row can be matched to its OWN
        -- assignment in the worker's assignments child (a person may have
        -- more than one assignment), instead of blindly taking assignments[0].
        CURSOR c_assignments IS
            SELECT TFM_SEQUENCE_ID, PERSON_NUMBER, ASSIGNMENT_NUMBER
            FROM DMT_OWNER.DMT_ASSIGNMENT_TFM_TBL
            WHERE RUN_ID = p_run_id
              AND TFM_STATUS = 'LOADED'
              AND FUSION_ASSIGNMENT_ID IS NULL;

        -- Salary cursor: LOADED rows with NULL FUSION_SALARY_ID
        -- Requires FUSION_PERSON_ID from the worker TFM to be populated first
        CURSOR c_salaries IS
            SELECT s.TFM_SEQUENCE_ID, s.PERSON_NUMBER, w.FUSION_PERSON_ID
            FROM DMT_OWNER.DMT_SALARY_TFM_TBL s
            LEFT JOIN DMT_OWNER.DMT_WORKER_TFM_TBL w
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
            FROM DMT_OWNER.DMT_PAY_REL_TFM_TBL p
            LEFT JOIN DMT_OWNER.DMT_WORKER_TFM_TBL w
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
            FROM DMT_OWNER.DMT_TALENT_PROF_TFM_TBL tp
            LEFT JOIN DMT_OWNER.DMT_WORKER_TFM_TBL w
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
            FROM DMT_OWNER.DMT_ABSENCE_TFM_TBL a
            LEFT JOIN DMT_OWNER.DMT_WORKER_TFM_TBL w
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
            FROM DMT_OWNER.DMT_TAX_CARD_TFM_TBL tc
            LEFT JOIN DMT_OWNER.DMT_WORKER_TFM_TBL w
              ON  w.PERSON_NUMBER = tc.PERSON_NUMBER
              AND w.RUN_ID = tc.RUN_ID
              AND w.TFM_STATUS = 'LOADED'
              AND w.FUSION_PERSON_ID IS NOT NULL
            WHERE tc.RUN_ID = p_run_id
              AND tc.TFM_STATUS = 'LOADED'
              AND tc.FUSION_DIR_CARD_ID IS NULL;

        -- W2Balances -> the person balance id
        CURSOR c_w2_balances IS
            SELECT b.TFM_SEQUENCE_ID, b.PERSON_NUMBER, w.FUSION_PERSON_ID
            FROM DMT_OWNER.DMT_W2_BAL_TFM_TBL b
            LEFT JOIN DMT_OWNER.DMT_WORKER_TFM_TBL w
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
            FROM DMT_OWNER.DMT_WORK_SCHED_TFM_TBL ws
            LEFT JOIN DMT_OWNER.DMT_WORKER_TFM_TBL w
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
            FROM DMT_OWNER.DMT_PERF_EVAL_TFM_TBL pe
            LEFT JOIN DMT_OWNER.DMT_WORKER_TFM_TBL w
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
            FROM DMT_OWNER.DMT_BEN_PARTIC_TFM_TBL bp
            LEFT JOIN DMT_OWNER.DMT_WORKER_TFM_TBL w
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
            FROM DMT_OWNER.DMT_BEN_BENFY_TFM_TBL bb
            LEFT JOIN DMT_OWNER.DMT_WORKER_TFM_TBL w
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
            FROM DMT_OWNER.DMT_BEN_DEPEND_TFM_TBL bd
            LEFT JOIN DMT_OWNER.DMT_WORKER_TFM_TBL w
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
                        UPDATE DMT_OWNER.DMT_WORKER_TFM_TBL
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
                        UPDATE DMT_OWNER.DMT_ASSIGNMENT_TFM_TBL
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
                        UPDATE DMT_OWNER.DMT_SALARY_TFM_TBL
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
                        UPDATE DMT_OWNER.DMT_PAY_REL_TFM_TBL
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
                        UPDATE DMT_OWNER.DMT_TALENT_PROF_TFM_TBL
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
                        UPDATE DMT_OWNER.DMT_ABSENCE_TFM_TBL
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
                        UPDATE DMT_OWNER.DMT_TAX_CARD_TFM_TBL
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
                        UPDATE DMT_OWNER.DMT_W2_BAL_TFM_TBL
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
                        UPDATE DMT_OWNER.DMT_WORK_SCHED_TFM_TBL
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
                        UPDATE DMT_OWNER.DMT_PERF_EVAL_TFM_TBL
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
                        UPDATE DMT_OWNER.DMT_BEN_PARTIC_TFM_TBL
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
                        UPDATE DMT_OWNER.DMT_BEN_BENFY_TFM_TBL
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
                        UPDATE DMT_OWNER.DMT_BEN_DEPEND_TFM_TBL
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
