-- PACKAGE BODY DMT_FND_VS_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_FND_VS_RESULTS_PKG" AS
-- ============================================================
-- DMT_FND_VS_RESULTS_PKG body
-- Value Sets: REST load + BIP base-table reconciliation.
--
-- New reconciliation standard (DMT_DESIGN.html, PROPOSED 2026-09):
-- reconciliation MUST be a BIP report over the Fusion BASE tables that
-- returns the base-table surrogate id. A REST load-call HTTP 200 is NOT
-- reconciliation. ValueSets is a two-object load (a value set, then its
-- child values), so LOAD and RECONCILE are two separate phases, each
-- covering both objects:
--
--   LOAD  (LOAD_SETS / LOAD_VALUES): POST each GENERATED set to the
--         valueSets REST resource, then POST each GENERATED value to the
--         set's child collection. A non-2xx response or an exception is a
--         genuine load-time rejection -> its real error is STASHED into
--         ERROR_TEXT (accumulate, never overwrite). The row is NOT marked
--         terminal here; it is left GENERATED, pending base-table proof.
--         A 2xx is NOT treated as LOADED. Values are POSTed only for sets
--         whose own POST did not error (a set that failed to create cannot
--         hold values); a value whose parent set errored is left GENERATED
--         with no fabricated error (the honest sweep surfaces it).
--
--   RECONCILE (FETCH_BIP_RESULTS + PARSE_AND_UPDATE): run the base-table
--         report DMT_VS_RECON_RPT over this run's set codes and value keys.
--         A set found in FND_VS_VALUE_SETS -> LOADED with
--         FUSION_VALUE_SET_ID = VALUE_SET_ID. A value found in
--         FND_VS_VALUES_B  -> LOADED with FUSION_VALUE_ID = VALUE_ID (the
--         real surrogate ids). Rows not returned stay as the load step set
--         them: FAILED if the REST load stashed a real error, else left
--         GENERATED (unaccounted) -- never a fabricated LOADED or id.
--
-- Transport is the shared DMT_UTIL_PKG.RUN_BIP_REPORT (no private SOAP
-- copy). Base tables: FND_VS_VALUE_SETS (id VALUE_SET_ID) and
-- FND_VS_VALUES_B (id VALUE_ID). Backlog #11 / new recon standard.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50)  := 'DMT_FND_VS_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30)  := 'ValueSets';

    -- Fusion REST base path for value sets
    C_VS_PATH CONSTANT VARCHAR2(200) := '/fscmRestApi/resources/11.13.18.05/valueSets';

    -- ModuleId for user-level value sets (same FND module GUID as lookups)
    C_MODULE_ID CONSTANT VARCHAR2(50) := '40B3FA7250D19380E040449823C67A1A';

    -- --------------------------------------------------------
    -- Private: make a REST call and return status + response
    -- (shared "STATUS|body" convention, same as the UOM reconciler).
    -- --------------------------------------------------------
    FUNCTION rest_call (
        p_method IN VARCHAR2,  -- GET, POST, DELETE
        p_path   IN VARCHAR2,  -- relative path after base URL
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
        -- default certificate store (as DMT_UTIL_PKG.HTTP_REQUEST and every other
        -- HTTP caller do). An unset/placeholder WALLET_DIR must not be forced into
        -- an invalid 'file:...' path -- that throws ORA-29273 before any auth.
        IF INSTR(NVL(DMT_UTIL_PKG.GET_CONFIG('WALLET_DIR'),' '),'/') > 0 THEN
            UTL_HTTP.SET_WALLET('file:' || DMT_UTIL_PKG.GET_CONFIG('WALLET_DIR'), DMT_UTIL_PKG.GET_CONFIG('WALLET_PASSWORD'));
        END IF;

        l_http_req := UTL_HTTP.BEGIN_REQUEST(l_url, p_method, 'HTTP/1.1');
        UTL_HTTP.SET_HEADER(l_http_req, 'Authorization',
            'Basic ' || UTL_RAW.CAST_TO_VARCHAR2(UTL_ENCODE.BASE64_ENCODE(
                UTL_RAW.CAST_TO_RAW(l_username || ':' || l_password))));
        UTL_HTTP.SET_HEADER(l_http_req, 'Accept', 'application/json');
        -- Ask Fusion NOT to gzip the response. Without this, error bodies come
        -- back gzip-compressed and land in ERROR_TEXT as unreadable binary; the
        -- real Fusion rejection message must be human-readable per the mission
        -- ("FAILED only with a real Fusion error string").
        UTL_HTTP.SET_HEADER(l_http_req, 'Accept-Encoding', 'identity');

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
    END get_status;

    -- ============================================================
    -- LOAD_SETS
    -- The LOAD step for value sets: POST each GENERATED set. The BIP base-table
    -- report -- not the POST response -- is the authority for LOADED, so this
    -- step NEVER marks a row terminal. It leaves every attempted row GENERATED.
    -- A non-2xx / exception is a real Fusion rejection: its message is STASHED
    -- into ERROR_TEXT (accumulate, never overwrite) so that if reconcile later
    -- finds the set absent from FND_VS_VALUE_SETS, the sweep marks it FAILED on
    -- that real error. Writes the TFM table only; no COMMIT (the runner owns
    -- the txn).
    -- ============================================================
    PROCEDURE LOAD_SETS (
        p_run_id IN NUMBER
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'LOAD_SETS';

        l_response      CLOB;
        l_http_status   NUMBER;
        l_body          VARCHAR2(32767);
        l_payload       CLOB;

        l_posted_count  NUMBER := 0;
        l_reject_count  NUMBER := 0;
        l_errmsg        VARCHAR2(4000);
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, C_PROC || ' start.', p_package => C_PKG, p_procedure => C_PROC);

        FOR r IN (
            SELECT TFM_SEQUENCE_ID, VALUE_SET_CODE, DESCRIPTION,
                   MODULE_ID, VALIDATION_TYPE, VALUE_DATA_TYPE, MAXIMUM_SIZE,
                   FORMAT_TYPE, PROTECTED_FLAG, SECURITY_ENABLED_FLAG
            FROM   DMT_FND_VS_SET_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS = 'GENERATED'
            ORDER BY TFM_SEQUENCE_ID
        ) LOOP
            BEGIN
                l_payload := '{"ValueSetCode":"' || REPLACE(r.VALUE_SET_CODE, '"', '\"') || '"'
                    || CASE WHEN r.DESCRIPTION IS NOT NULL
                       THEN ',"Description":"' || REPLACE(r.DESCRIPTION, '"', '\"') || '"'
                       END
                    || ',"ModuleId":"' || NVL(r.MODULE_ID, C_MODULE_ID) || '"'
                    || CASE WHEN r.VALIDATION_TYPE IS NOT NULL
                       THEN ',"ValidationType":"' || REPLACE(r.VALIDATION_TYPE, '"', '\"') || '"'
                       END
                    || CASE WHEN r.VALUE_DATA_TYPE IS NOT NULL
                       THEN ',"ValueDataType":"' || REPLACE(r.VALUE_DATA_TYPE, '"', '\"') || '"'
                       END
                    || CASE WHEN r.MAXIMUM_SIZE IS NOT NULL
                       THEN ',"MaximumSize":' || TO_CHAR(r.MAXIMUM_SIZE)
                       END
                    || CASE WHEN r.FORMAT_TYPE IS NOT NULL
                       THEN ',"FormatType":"' || REPLACE(r.FORMAT_TYPE, '"', '\"') || '"'
                       END
                    || CASE WHEN r.PROTECTED_FLAG IS NOT NULL
                       THEN ',"ProtectedFlag":"' || r.PROTECTED_FLAG || '"'
                       END
                    || CASE WHEN r.SECURITY_ENABLED_FLAG IS NOT NULL
                       THEN ',"SecurityEnabledFlag":"' || r.SECURITY_ENABLED_FLAG || '"'
                       END
                    || '}';

                l_response := rest_call('POST', C_VS_PATH, l_payload, p_run_id);
                l_http_status := get_status(l_response);

                IF l_http_status IN (200, 201) THEN
                    -- POST accepted. Row stays GENERATED for the base-table report to
                    -- confirm (and capture FUSION_VALUE_SET_ID).
                    l_posted_count := l_posted_count + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Set POSTed (awaiting base-table confirmation): ' || r.VALUE_SET_CODE
                        || ' HTTP ' || l_http_status,
                        p_package => C_PKG, p_procedure => C_PROC);
                ELSE
                    -- Non-2xx: stash the real REST error but leave the row GENERATED.
                    l_body := DBMS_LOB.SUBSTR(l_response, 2000, INSTR(l_response, '|') + 1);
                    UPDATE DMT_FND_VS_SET_TFM_TBL
                    SET    ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                          '[FUSION_ERROR] HTTP ' || l_http_status || ': '
                                          || SUBSTR(l_body, 1, 2000)),
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    l_reject_count := l_reject_count + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Set POST rejected (stashed, awaiting base-table verdict): '
                        || r.VALUE_SET_CODE || ' HTTP ' || l_http_status,
                        p_log_type => 'WARN', p_package => C_PKG, p_procedure => C_PROC);
                END IF;

                IF DBMS_LOB.ISTEMPORARY(l_response) = 1 THEN
                    DBMS_LOB.FREETEMPORARY(l_response);
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    l_errmsg := SQLERRM;
                    UPDATE DMT_FND_VS_SET_TFM_TBL
                    SET    ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                          '[FUSION_ERROR] ' || l_errmsg),
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    l_reject_count := l_reject_count + 1;
                    DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                        'Set POST failed (exception, stashed): ' || r.VALUE_SET_CODE,
                        l_errmsg, p_package => C_PKG, p_procedure => C_PROC);
            END;
        END LOOP;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. POSTed 2xx: ' || l_posted_count
            || ', POST-rejected(stashed): ' || l_reject_count
            || ' (all rows left GENERATED for base-table reconciliation).',
            p_package => C_PKG, p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed.', SQLERRM, p_package => C_PKG, p_procedure => C_PROC);
            RAISE;
    END LOAD_SETS;

    -- ============================================================
    -- LOAD_VALUES
    -- The LOAD step for values: POST each GENERATED value to its parent set's
    -- child collection. Same policy as LOAD_SETS: never terminal, stash real
    -- errors, leave GENERATED for base-table proof. A value whose parent set
    -- does not exist in Fusion draws a real HTTP 404 from the child collection
    -- endpoint -- a genuine Fusion rejection, so it is stashed like any other
    -- and the sweep marks the row FAILED on it (never fabricated). Writes the
    -- TFM table only; no COMMIT (the runner owns the txn).
    -- ============================================================
    PROCEDURE LOAD_VALUES (
        p_run_id IN NUMBER
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'LOAD_VALUES';

        l_response      CLOB;
        l_http_status   NUMBER;
        l_body          VARCHAR2(32767);
        l_payload       CLOB;

        l_posted_count  NUMBER := 0;
        l_reject_count  NUMBER := 0;
        l_errmsg        VARCHAR2(4000);
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, C_PROC || ' start.', p_package => C_PKG, p_procedure => C_PROC);

        FOR r IN (
            SELECT v.TFM_SEQUENCE_ID,
                   v.VALUE_SET_CODE, v.VALUE, v.DESCRIPTION,
                   v.ENABLED_FLAG, v.EFFECTIVE_START_DATE, v.EFFECTIVE_END_DATE,
                   v.INDEPENDENT_VALUE, v.TAG
            FROM   DMT_FND_VS_VALUE_TFM_TBL v
            WHERE  v.RUN_ID = p_run_id
            AND    v.TFM_STATUS = 'GENERATED'
            ORDER BY v.VALUE_SET_CODE, v.TFM_SEQUENCE_ID
        ) LOOP
            BEGIN
                l_payload := '{"Value":"' || REPLACE(r.VALUE, '"', '\"') || '"'
                    || CASE WHEN r.DESCRIPTION IS NOT NULL
                       THEN ',"Description":"' || REPLACE(r.DESCRIPTION, '"', '\"') || '"'
                       END
                    || ',"EnabledFlag":"' || NVL(r.ENABLED_FLAG, 'Y') || '"'
                    || CASE WHEN r.INDEPENDENT_VALUE IS NOT NULL
                       THEN ',"IndependentValue":"' || REPLACE(r.INDEPENDENT_VALUE, '"', '\"') || '"'
                       END
                    || CASE WHEN r.TAG IS NOT NULL
                       THEN ',"Tag":"' || REPLACE(r.TAG, '"', '\"') || '"'
                       END
                    || CASE WHEN r.EFFECTIVE_START_DATE IS NOT NULL
                       THEN ',"EffectiveStartDate":"' || TO_CHAR(r.EFFECTIVE_START_DATE, 'YYYY-MM-DD') || '"'
                       END
                    || CASE WHEN r.EFFECTIVE_END_DATE IS NOT NULL
                       THEN ',"EffectiveEndDate":"' || TO_CHAR(r.EFFECTIVE_END_DATE, 'YYYY-MM-DD') || '"'
                       END
                    || '}';

                l_response := rest_call('POST',
                    C_VS_PATH || '/' || r.VALUE_SET_CODE || '/child/values',
                    l_payload, p_run_id);
                l_http_status := get_status(l_response);

                IF l_http_status IN (200, 201) THEN
                    l_posted_count := l_posted_count + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Value POSTed (awaiting base-table confirmation): '
                        || r.VALUE_SET_CODE || '.' || r.VALUE || ' HTTP ' || l_http_status,
                        p_package => C_PKG, p_procedure => C_PROC);
                ELSE
                    l_body := DBMS_LOB.SUBSTR(l_response, 2000, INSTR(l_response, '|') + 1);
                    UPDATE DMT_FND_VS_VALUE_TFM_TBL
                    SET    ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                          '[FUSION_ERROR] HTTP ' || l_http_status || ': '
                                          || SUBSTR(l_body, 1, 2000)),
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    l_reject_count := l_reject_count + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Value POST rejected (stashed, awaiting base-table verdict): '
                        || r.VALUE_SET_CODE || '.' || r.VALUE || ' HTTP ' || l_http_status,
                        p_log_type => 'WARN', p_package => C_PKG, p_procedure => C_PROC);
                END IF;

                IF DBMS_LOB.ISTEMPORARY(l_response) = 1 THEN
                    DBMS_LOB.FREETEMPORARY(l_response);
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    l_errmsg := SQLERRM;
                    UPDATE DMT_FND_VS_VALUE_TFM_TBL
                    SET    ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                          '[FUSION_ERROR] ' || l_errmsg),
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    l_reject_count := l_reject_count + 1;
                    DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                        'Value POST failed (exception, stashed): ' || r.VALUE_SET_CODE || '.' || r.VALUE,
                        l_errmsg, p_package => C_PKG, p_procedure => C_PROC);
            END;
        END LOOP;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. POSTed 2xx: ' || l_posted_count
            || ', POST-rejected(stashed): ' || l_reject_count
            || ' (all rows left GENERATED for base-table reconciliation).',
            p_package => C_PKG, p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed.', SQLERRM, p_package => C_PKG, p_procedure => C_PROC);
            RAISE;
    END LOAD_VALUES;

    -- --------------------------------------------------------
    -- FETCH_BIP_RESULTS
    -- Runs the base-table reconciliation report for this run's set codes and
    -- value keys. Delegates to the shared DMT_UTIL_PKG.RUN_BIP_REPORT (no
    -- private SOAP copy). Two parameters: P_SET_CODES (comma-delimited
    -- VALUE_SET_CODE list) and P_VALUE_KEYS (comma-delimited
    -- VALUE_SET_CODE^VALUE composite-key list); config codes are not
    -- run-prefixed. PROCEDURE per the procedures-only contract: x_report_xml
    -- NULL with x_error_code = C_SUCCESS means zero rows; failures are logged
    -- and surfaced through x_error_code -- exceptions never escape.
    -- --------------------------------------------------------
    PROCEDURE FETCH_BIP_RESULTS (
        p_run_id      IN  NUMBER,
        p_set_codes   IN  VARCHAR2,
        p_value_keys  IN  VARCHAR2,
        x_report_xml  OUT XMLTYPE,
        x_error_code  OUT NUMBER
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'FETCH_BIP_RESULTS';
        l_step VARCHAR2(500);
    BEGIN
        x_report_xml := NULL;
        x_error_code := DMT_UTIL_PKG.C_ERROR;   -- pessimistic until proven

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' start. CEMLI: ' || C_CEMLI
            || ' | P_SET_CODES: ' || NVL(p_set_codes, '(none)')
            || ' | P_VALUE_KEYS: ' || NVL(p_value_keys, '(none)'),
            p_package => C_PKG, p_procedure => C_PROC);

        IF p_set_codes IS NULL AND p_value_keys IS NULL THEN
            -- Nothing to confirm: zero rows, not an error.
            x_error_code := DMT_UTIL_PKG.C_SUCCESS;
            RETURN;
        END IF;

        l_step := 'running base-table reconciliation report for ' || C_CEMLI;
        DMT_UTIL_PKG.RUN_BIP_REPORT(
            p_run_id     => p_run_id,
            p_cemli_code => C_CEMLI,
            p_params     => 'P_SET_CODES|' || p_set_codes
                            || '~P_VALUE_KEYS|' || p_value_keys,
            x_report_xml => x_report_xml,
            x_error_code => x_error_code);

        IF x_error_code != DMT_UTIL_PKG.C_SUCCESS THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ' failed while ' || l_step
                || ' (detail logged by RUN_BIP_REPORT).',
                p_log_type => 'ERROR', p_package => C_PKG, p_procedure => C_PROC);
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
    -- PARSE_AND_UPDATE
    -- Positive base-table confirmation only. Each report row is either a set
    -- found in FND_VS_VALUE_SETS (SOURCE_TYPE='SET') or a value found in
    -- FND_VS_VALUES_B (SOURCE_TYPE='VALUE'):
    --   SET   -> LOADED with FUSION_VALUE_SET_ID = the returned VALUE_SET_ID.
    --            RECORD_KEY = VALUE_SET_CODE.
    --   VALUE -> LOADED with FUSION_VALUE_ID = the returned VALUE_ID.
    --            RECORD_KEY = VALUE_SET_CODE || '^' || VALUE.
    -- Rows not returned are left as the load step set them (FAILED with a real
    -- REST error, else GENERATED/unaccounted) -- never a fabricated verdict or
    -- id. Writes the TFM tables only; no COMMIT (the runner owns the txn).
    -- --------------------------------------------------------
    PROCEDURE PARSE_AND_UPDATE (
        p_run_id     IN NUMBER,
        p_report_xml IN XMLTYPE
    ) IS
        C_PROC        CONSTANT VARCHAR2(30) := 'PARSE_AND_UPDATE';
        l_sets_loaded   NUMBER := 0;
        l_values_loaded NUMBER := 0;
        l_set_code      VARCHAR2(60);
        l_value         VARCHAR2(150);
        l_sep           PLS_INTEGER;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, C_PROC || ' start.', p_package => C_PKG, p_procedure => C_PROC);

        IF p_report_xml IS NULL THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': report returned zero base-table rows. '
                || 'No fabricated LOADED; rows left as the load step set them.',
                p_log_type => 'WARN', p_package => C_PKG, p_procedure => C_PROC);
            RETURN;
        END IF;

        FOR r IN (
            SELECT x.record_key,
                   UPPER(x.source_type) AS source_type,
                   x.fusion_id
            FROM   XMLTABLE('/DATA_DS/G_1' PASSING p_report_xml
                COLUMNS
                    record_key  VARCHAR2(300) PATH 'RECORD_KEY',
                    source_type VARCHAR2(20)  PATH 'SOURCE_TYPE',
                    fusion_id   NUMBER        PATH 'FUSION_ID'
            ) x
        ) LOOP
            IF r.fusion_id IS NULL THEN
                CONTINUE;
            END IF;

            IF r.source_type = 'SET' THEN
                -- Positive proof: the set exists in FND_VS_VALUE_SETS.
                UPDATE DMT_FND_VS_SET_TFM_TBL
                SET    TFM_STATUS           = 'LOADED',
                       FUSION_VALUE_SET_ID  = r.fusion_id,
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID     = p_run_id
                AND    VALUE_SET_CODE = r.record_key
                AND    TFM_STATUS NOT IN ('LOADED','FAILED');
                l_sets_loaded := l_sets_loaded + SQL%ROWCOUNT;

            ELSIF r.source_type = 'VALUE' THEN
                -- Composite RECORD_KEY = VALUE_SET_CODE || '^' || VALUE.
                l_sep := INSTR(r.record_key, '^');
                IF l_sep > 0 THEN
                    l_set_code := SUBSTR(r.record_key, 1, l_sep - 1);
                    l_value    := SUBSTR(r.record_key, l_sep + 1);

                    UPDATE DMT_FND_VS_VALUE_TFM_TBL
                    SET    TFM_STATUS           = 'LOADED',
                           FUSION_VALUE_ID      = r.fusion_id,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID     = p_run_id
                    AND    VALUE_SET_CODE = l_set_code
                    AND    VALUE          = l_value
                    AND    TFM_STATUS NOT IN ('LOADED','FAILED');
                    l_values_loaded := l_values_loaded + SQL%ROWCOUNT;
                END IF;
            END IF;
        END LOOP;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. Base-table confirmed LOADED -- sets: ' || l_sets_loaded
            || ', values: ' || l_values_loaded || '.',
            p_package => C_PKG, p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed.', SQLERRM, p_package => C_PKG, p_procedure => C_PROC);
            RAISE;
    END PARSE_AND_UPDATE;

    -- ============================================================
    -- LOAD_AND_RECONCILE
    -- Main entry point. LOAD sets then values via REST POST, then RECONCILE
    -- both against the Fusion base tables via the BIP report (the new standard).
    -- No COMMIT until the end (the runner also commits, but this keeps the two
    -- phases in one txn).
    -- ============================================================
    PROCEDURE LOAD_AND_RECONCILE (
        p_run_id IN NUMBER
    ) IS
        C_PROC     CONSTANT VARCHAR2(30) := 'LOAD_AND_RECONCILE';
        l_set_codes  VARCHAR2(4000);
        l_value_keys VARCHAR2(4000);
        l_xml        XMLTYPE;
        l_err        NUMBER;
        l_sets_loaded    NUMBER;
        l_sets_failed    NUMBER;
        l_sets_unaccnt   NUMBER;
        l_vals_loaded    NUMBER;
        l_vals_failed    NUMBER;
        l_vals_unaccnt   NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, C_PROC || ' start.', p_package => C_PKG, p_procedure => C_PROC);

        -- Phase 1: LOAD -- POST every GENERATED set, then every GENERATED value.
        LOAD_SETS(p_run_id);
        LOAD_VALUES(p_run_id);

        -- Build the comma-delimited lists of set codes / value keys we POSTed and
        -- still need confirmed (rows the load step did NOT mark FAILED; config
        -- codes are not run-prefixed, so match the base tables on the exact codes).
        SELECT LISTAGG(VALUE_SET_CODE, ',') WITHIN GROUP (ORDER BY VALUE_SET_CODE)
        INTO   l_set_codes
        FROM   DMT_FND_VS_SET_TFM_TBL
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'GENERATED';

        SELECT LISTAGG(VALUE_SET_CODE || '^' || VALUE, ',')
                   WITHIN GROUP (ORDER BY VALUE_SET_CODE, VALUE)
        INTO   l_value_keys
        FROM   DMT_FND_VS_VALUE_TFM_TBL
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'GENERATED';

        -- Phase 2: RECONCILE -- run the base-table report and confirm.
        FETCH_BIP_RESULTS(
            p_run_id     => p_run_id,
            p_set_codes  => l_set_codes,
            p_value_keys => l_value_keys,
            x_report_xml => l_xml,
            x_error_code => l_err);

        IF l_err != DMT_UTIL_PKG.C_SUCCESS THEN
            -- Reconciliation transport failed: raise loudly so the queue work item
            -- fails, never a silent zero-row "success".
            RAISE_APPLICATION_ERROR(-20039,
                'LOAD_AND_RECONCILE: base-table reconciliation report failed for CEMLI '
                || C_CEMLI || ' (detail in DMT_LOG_TBL).');
        END IF;

        PARSE_AND_UPDATE(p_run_id, l_xml);

        -- Post-reconcile sweep: any row NOT confirmed in the base table is still
        -- GENERATED. If its POST returned a real Fusion error (stashed in
        -- ERROR_TEXT by the load step) mark it FAILED on that real error. A row
        -- with no stashed error AND no base-table hit is left GENERATED
        -- (unaccounted); the accounting gate surfaces it -- we never fabricate a
        -- verdict.
        UPDATE DMT_FND_VS_SET_TFM_TBL
        SET    TFM_STATUS           = 'FAILED',
               RESULTS_UPDATED_DATE = SYSDATE,
               LAST_UPDATED_DATE    = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'GENERATED'
        AND    ERROR_TEXT IS NOT NULL;

        UPDATE DMT_FND_VS_VALUE_TFM_TBL
        SET    TFM_STATUS           = 'FAILED',
               RESULTS_UPDATED_DATE = SYSDATE,
               LAST_UPDATED_DATE    = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'GENERATED'
        AND    ERROR_TEXT IS NOT NULL;

        -- Mirror the terminal TFM outcome onto STG for both objects (STG_STATUS is
        -- terminal from staging's point of view; the TFM row is the record of the
        -- Fusion outcome).
        UPDATE DMT_FND_VS_SET_STG_TBL s
        SET    s.STG_STATUS = (SELECT t.TFM_STATUS
                               FROM   DMT_FND_VS_SET_TFM_TBL t
                               WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                               AND    t.RUN_ID = p_run_id),
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  EXISTS (SELECT 1 FROM DMT_FND_VS_SET_TFM_TBL t
                       WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                       AND    t.RUN_ID = p_run_id
                       AND    t.TFM_STATUS IN ('LOADED','FAILED'));

        UPDATE DMT_FND_VS_VALUE_STG_TBL s
        SET    s.STG_STATUS = (SELECT t.TFM_STATUS
                               FROM   DMT_FND_VS_VALUE_TFM_TBL t
                               WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                               AND    t.RUN_ID = p_run_id),
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  EXISTS (SELECT 1 FROM DMT_FND_VS_VALUE_TFM_TBL t
                       WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                       AND    t.RUN_ID = p_run_id
                       AND    t.TFM_STATUS IN ('LOADED','FAILED'));

        COMMIT;

        SELECT COUNT(CASE WHEN TFM_STATUS = 'LOADED' THEN 1 END),
               COUNT(CASE WHEN TFM_STATUS = 'FAILED' THEN 1 END),
               COUNT(CASE WHEN TFM_STATUS NOT IN ('LOADED','FAILED') THEN 1 END)
        INTO   l_sets_loaded, l_sets_failed, l_sets_unaccnt
        FROM   DMT_FND_VS_SET_TFM_TBL
        WHERE  RUN_ID = p_run_id;

        SELECT COUNT(CASE WHEN TFM_STATUS = 'LOADED' THEN 1 END),
               COUNT(CASE WHEN TFM_STATUS = 'FAILED' THEN 1 END),
               COUNT(CASE WHEN TFM_STATUS NOT IN ('LOADED','FAILED') THEN 1 END)
        INTO   l_vals_loaded, l_vals_failed, l_vals_unaccnt
        FROM   DMT_FND_VS_VALUE_TFM_TBL
        WHERE  RUN_ID = p_run_id;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. Sets -- LOADED: ' || l_sets_loaded
            || ', FAILED: ' || l_sets_failed || ', UNACCOUNTED: ' || l_sets_unaccnt
            || ' | Values -- LOADED: ' || l_vals_loaded
            || ', FAILED: ' || l_vals_failed || ', UNACCOUNTED: ' || l_vals_unaccnt || '.',
            p_package => C_PKG, p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed.', SQLERRM, p_package => C_PKG, p_procedure => C_PROC);
            RAISE;
    END LOAD_AND_RECONCILE;

END DMT_FND_VS_RESULTS_PKG;
/
