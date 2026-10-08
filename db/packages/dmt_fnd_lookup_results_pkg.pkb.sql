-- PACKAGE BODY DMT_FND_LOOKUP_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_FND_LOOKUP_RESULTS_PKG" AS
-- ============================================================
-- DMT_FND_LOOKUP_RESULTS_PKG body
-- FND Lookups: REST load + BIP base-table reconciliation.
--
-- New reconciliation standard (DMT_DESIGN.html, PROPOSED 2026-09): the BIP
-- report over the Fusion BASE tables -- not the POST response -- is the sole
-- authority for LOADED. Lookups is a two-tier load (a lookup type, then its
-- child lookup codes), so LOAD and RECONCILE are two phases, each covering
-- both tiers.
--
-- SPECIAL CASE -- no numeric surrogate id. FND lookups expose only string
-- keys: FND_LOOKUP_TYPES (key LOOKUP_TYPE) and FND_LOOKUP_VALUES_B (key
-- LOOKUP_TYPE + LOOKUP_CODE). There is NO LOOKUP_TYPE_ID / LOOKUP_ID numeric
-- column, so reconciliation confirms EXISTENCE by the string key and marks the
-- row LOADED while stamping the Fusion-returned natural key as its proof
-- (#160; design section 7, Standard LOADED-promotion shape, clause (5)):
-- FUSION_LOOKUP_TYPE_ID = LOOKUP_TYPE, FUSION_LOOKUP_ID = LOOKUP_TYPE~LOOKUP_CODE
-- (both VARCHAR2, read back from the base tables -- never fabricated). The
-- report returns RECORD_KEY + SOURCE_TYPE only.
--
--   LOAD  (LOAD_TYPES / LOAD_VALUES): POST each GENERATED type, then each
--         GENERATED value to its type's child collection. A non-2xx with a
--         Fusion message body is a real Fusion rejection -> '[FUSION_ERROR] ' ||
--         that message is STASHED into ERROR_TEXT (accumulate, never overwrite);
--         the row is left GENERATED, pending base-table proof. A blank body or a
--         transport exception writes no error (UNACCOUNTED, never a made-up
--         Fusion error). A 2xx is NOT treated as LOADED.
--
--   RECONCILE (FETCH_BIP_RESULTS + PARSE_AND_UPDATE): run DMT_LOOKUP_RECON_RPT
--         over this run's type codes and value keys. A type found in
--         FND_LOOKUP_TYPES -> LOADED. A value found in FND_LOOKUP_VALUES_B ->
--         LOADED. Rows not returned stay as the load step set them: FAILED if
--         the REST load stashed a real error, else left GENERATED (unaccounted)
--         -- never a fabricated verdict or id.
--
-- Transport is the shared DMT_UTIL_PKG.RUN_BIP_REPORT (no private SOAP copy).
-- Backlog #11 / new recon standard.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_FND_LOOKUP_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'Lookups';

    -- Fusion REST base path for standard lookups
    C_LOOKUPS_PATH CONSTANT VARCHAR2(200) := '/fscmRestApi/resources/11.13.18.05/standardLookups';

    -- Default ModuleId for user-level lookup types, required by the
    -- standardLookups REST API on create. CONFIGURABLE per instance via
    -- DMT_CONFIG_TBL key LOOKUP_DEFAULT_MODULE_ID (seeded by
    -- db/migrations/2026-10-06_rest_load_call_status_and_module_key_widen.sql).
    -- The literal below is the hard fallback when the key is absent, and is the
    -- proven-valid instance module id (direct POST -> HTTP 201, type confirmed in
    -- FND_LOOKUP_TYPES). The former hard-code '40B3FA7250D19380E040449823C67A1A'
    -- was observed returning HTTP 400 "Invalid Module ID" during the #130 live
    -- investigation, so the id must never again be a bare un-overridable literal.
    C_MODULE_ID_FALLBACK CONSTANT VARCHAR2(50) := '817AA25E27D8124DE0401490D3C54C17';

    -- Resolve the active default module id: config override, else the proven
    -- fallback. A blank/absent config value falls back, never sends an empty id.
    FUNCTION default_module_id RETURN VARCHAR2 IS
        l_cfg VARCHAR2(500);
    BEGIN
        l_cfg := DMT_UTIL_PKG.GET_CONFIG('LOOKUP_DEFAULT_MODULE_ID');
        RETURN NVL(TRIM(l_cfg), C_MODULE_ID_FALLBACK);
    END default_module_id;

    -- --------------------------------------------------------
    -- Private: make a REST call and return status + response
    -- (shared "STATUS|body" convention, same as the ValueSets reconciler).
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
        -- Central Fusion user for this object (backlog #309).
        DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS(p_cemli_code => C_CEMLI,
                                           x_username   => l_username,
                                           x_password   => l_password);
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
        -- real Fusion rejection message must be human-readable.
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
    -- LOAD_TYPES
    -- The LOAD step for lookup types: POST each GENERATED type. The BIP
    -- base-table report -- not the POST response -- is the authority for LOADED,
    -- so this step NEVER marks a row terminal; it leaves every attempted row
    -- GENERATED. A non-2xx / exception is a real Fusion rejection: its message
    -- is STASHED into ERROR_TEXT (accumulate, never overwrite) so that if
    -- reconcile later finds the type absent from FND_LOOKUP_TYPES, the sweep
    -- marks it FAILED on that real error. Writes the TFM table only; no COMMIT
    -- (the runner owns the txn).
    -- ============================================================
    PROCEDURE LOAD_TYPES (
        p_run_id IN NUMBER
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'LOAD_TYPES';

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
            SELECT TFM_SEQUENCE_ID, LOOKUP_TYPE, MEANING, DESCRIPTION, MODULE_KEY
            FROM   DMT_FND_LOOKUP_TYPE_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS = 'GENERATED'
            ORDER BY TFM_SEQUENCE_ID
        ) LOOP
            BEGIN
                -- ModuleId: use the mapped MODULE_KEY when the source carries one,
                -- else the common user-level FND module GUID. A bad mapped module
                -- is a genuine Fusion rejection (HTTP 400), not a fabricated one.
                l_payload := '{"LookupType":"' || REPLACE(r.LOOKUP_TYPE, '"', '\"') || '"'
                    || ',"Meaning":"' || REPLACE(NVL(r.MEANING, r.LOOKUP_TYPE), '"', '\"') || '"'
                    || CASE WHEN r.DESCRIPTION IS NOT NULL
                       THEN ',"Description":"' || REPLACE(r.DESCRIPTION, '"', '\"') || '"'
                       END
                    || ',"ModuleId":"' || NVL(r.MODULE_KEY, default_module_id) || '"'
                    || '}';

                l_response := rest_call('POST', C_LOOKUPS_PATH, l_payload, p_run_id);
                l_http_status := get_status(l_response);

                IF l_http_status IN (200, 201) THEN
                    -- POST accepted. Row stays GENERATED for the base-table report to
                    -- confirm (no id to capture on lookups). Stamp LOAD_CALL_STATUS =
                    -- CREATED: honest proof OUR OWN create for THIS record returned 2xx,
                    -- so PARSE_AND_UPDATE may promote it (base-table key match alone is
                    -- not enough -- #130 hollow-LOADED guard).
                    UPDATE DMT_FND_LOOKUP_TYPE_TFM_TBL
                    SET    LOAD_CALL_STATUS = 'CREATED',
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;
                    l_posted_count := l_posted_count + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Type POSTed (awaiting base-table confirmation): ' || r.LOOKUP_TYPE
                        || ' HTTP ' || l_http_status,
                        p_package => C_PKG, p_procedure => C_PROC);
                ELSE
                    -- Non-2xx. Stash a [FUSION_ERROR] ONLY when Fusion returned a real
                    -- per-record message body (#161). A blank-bodied transport code is
                    -- NOT a per-record verdict: stash nothing, leave the row GENERATED
                    -- so the honest accounting gate surfaces it as UNACCOUNTED.
                    l_body := TRIM(DBMS_LOB.SUBSTR(l_response, 2000, INSTR(l_response, '|') + 1));
                    -- Record that OUR create for THIS record did NOT return 2xx
                    -- (#130): LOAD_CALL_STATUS = REJECTED keeps the row out of the
                    -- LOADED promotion even when the error body is blank and a
                    -- pre-existing base-table row shares its key.
                    UPDATE DMT_FND_LOOKUP_TYPE_TFM_TBL
                    SET    LOAD_CALL_STATUS = 'REJECTED',
                           ERROR_TEXT = CASE WHEN l_body IS NOT NULL
                                             THEN DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                                    '[FUSION_ERROR] ' || SUBSTR(l_body, 1, 2000))
                                             ELSE ERROR_TEXT END,
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    l_reject_count := l_reject_count + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Type POST rejected (' ||
                        CASE WHEN l_body IS NOT NULL
                             THEN 'real error stashed, awaiting base-table verdict'
                             ELSE 'blank body, left UNACCOUNTED (no bare HTTP code stashed)'
                        END || '): ' || r.LOOKUP_TYPE || ' HTTP ' || l_http_status,
                        p_log_type => 'WARN', p_package => C_PKG, p_procedure => C_PROC);
                END IF;

                IF DBMS_LOB.ISTEMPORARY(l_response) = 1 THEN
                    DBMS_LOB.FREETEMPORARY(l_response);
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    l_errmsg := SQLERRM;
                    UPDATE DMT_FND_LOOKUP_TYPE_TFM_TBL
                    -- #160: an exception here is OUR transport/PL-SQL failure (SQLERRM),
                    -- not a Fusion response, so it is never written as [FUSION_ERROR].
                    -- REJECTED keeps the row out of LOADED; with no Fusion error it stays
                    -- GENERATED and the shared sweep marks it UNACCOUNTED (logged below).
                    SET    LOAD_CALL_STATUS = 'REJECTED',
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    l_reject_count := l_reject_count + 1;
                    DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                        'Type POST failed (exception, no Fusion response -- left for the UNACCOUNTED sweep): ' || r.LOOKUP_TYPE,
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
    END LOAD_TYPES;

    -- ============================================================
    -- LOAD_VALUES
    -- The LOAD step for lookup codes: POST each GENERATED value to its parent
    -- type's child collection. Same policy as LOAD_TYPES: never terminal, stash
    -- real errors, leave GENERATED for base-table proof. A value whose parent
    -- type does not exist in Fusion draws a real HTTP error from the child
    -- collection endpoint -- a genuine Fusion rejection, stashed like any other.
    -- Writes the TFM table only; no COMMIT (the runner owns the txn).
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
                   v.LOOKUP_TYPE, v.LOOKUP_CODE, v.DISPLAY_SEQUENCE,
                   v.ENABLED_FLAG, v.START_DATE_ACTIVE, v.END_DATE_ACTIVE,
                   v.MEANING, v.DESCRIPTION, v.TAG,
                   (SELECT COUNT(*) FROM DMT_FND_LOOKUP_TYPE_TFM_TBL t
                    WHERE  t.RUN_ID = p_run_id
                    AND    t.LOOKUP_TYPE = v.LOOKUP_TYPE) AS parent_rows,
                   (SELECT MAX(t.LOAD_CALL_STATUS) FROM DMT_FND_LOOKUP_TYPE_TFM_TBL t
                    WHERE  t.RUN_ID = p_run_id
                    AND    t.LOOKUP_TYPE = v.LOOKUP_TYPE
                    AND    t.LOAD_CALL_STATUS = 'CREATED') AS parent_created
            FROM   DMT_FND_LOOKUP_VALUE_TFM_TBL v
            WHERE  v.RUN_ID = p_run_id
            AND    v.TFM_STATUS = 'GENERATED'
            ORDER BY v.LOOKUP_TYPE, v.DISPLAY_SEQUENCE, v.TFM_SEQUENCE_ID
        ) LOOP
            BEGIN
                -- Parent not created (run 236 BADVAL): when this run also sent the
                -- value's parent lookup TYPE and Fusion did NOT create it, the value
                -- is not sent -- posting it only draws a blank-bodied HTTP 404 from
                -- the missing child collection, which (#161) carries no per-record
                -- message. Fusion returned no error for the value itself, so no
                -- error text is written: it stays GENERATED and the shared sweep
                -- marks it UNACCOUNTED (a generic "parent failed" sentence is never
                -- a Fusion error). Quoting the parent's real error in the shared
                -- cross-grain format waits for DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR.
                -- LOAD_CALL_STATUS stays NULL (never attempted).
                IF r.parent_rows > 0 AND r.parent_created IS NULL THEN
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Value not sent (parent lookup type not created): '
                        || r.LOOKUP_TYPE || '.' || r.LOOKUP_CODE,
                        p_package => C_PKG, p_procedure => C_PROC);
                    CONTINUE;
                END IF;

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
                    -- #130: stamp CREATED -- our own POST for THIS value returned 2xx.
                    UPDATE DMT_FND_LOOKUP_VALUE_TFM_TBL
                    SET    LOAD_CALL_STATUS = 'CREATED',
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;
                    l_posted_count := l_posted_count + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Value POSTed (awaiting base-table confirmation): '
                        || r.LOOKUP_TYPE || '.' || r.LOOKUP_CODE || ' HTTP ' || l_http_status,
                        p_package => C_PKG, p_procedure => C_PROC);
                ELSE
                    -- Non-2xx. Stash a [FUSION_ERROR] ONLY when Fusion returned a real
                    -- per-record message body (#161). A blank-bodied transport code is
                    -- NOT a per-record verdict: stash nothing, leave the row GENERATED
                    -- so the honest accounting gate surfaces it as UNACCOUNTED.
                    l_body := TRIM(DBMS_LOB.SUBSTR(l_response, 2000, INSTR(l_response, '|') + 1));
                    -- #130: our create did NOT return 2xx -> REJECTED (keeps the row
                    -- out of the LOADED promotion even on a blank body + key collision).
                    UPDATE DMT_FND_LOOKUP_VALUE_TFM_TBL
                    SET    LOAD_CALL_STATUS = 'REJECTED',
                           ERROR_TEXT = CASE WHEN l_body IS NOT NULL
                                             THEN DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                                    '[FUSION_ERROR] ' || SUBSTR(l_body, 1, 2000))
                                             ELSE ERROR_TEXT END,
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    l_reject_count := l_reject_count + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Value POST rejected (' ||
                        CASE WHEN l_body IS NOT NULL
                             THEN 'real error stashed, awaiting base-table verdict'
                             ELSE 'blank body, left UNACCOUNTED (no bare HTTP code stashed)'
                        END || '): '
                        || r.LOOKUP_TYPE || '.' || r.LOOKUP_CODE || ' HTTP ' || l_http_status,
                        p_log_type => 'WARN', p_package => C_PKG, p_procedure => C_PROC);
                END IF;

                IF DBMS_LOB.ISTEMPORARY(l_response) = 1 THEN
                    DBMS_LOB.FREETEMPORARY(l_response);
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    l_errmsg := SQLERRM;
                    UPDATE DMT_FND_LOOKUP_VALUE_TFM_TBL
                    -- #160: an exception here is OUR transport/PL-SQL failure (SQLERRM),
                    -- not a Fusion response, so it is never written as [FUSION_ERROR].
                    -- REJECTED keeps the row out of LOADED; with no Fusion error it stays
                    -- GENERATED and the shared sweep marks it UNACCOUNTED (logged below).
                    SET    LOAD_CALL_STATUS = 'REJECTED',
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    l_reject_count := l_reject_count + 1;
                    DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                        'Value POST failed (exception, no Fusion response -- left for the UNACCOUNTED sweep): ' || r.LOOKUP_TYPE || '.' || r.LOOKUP_CODE,
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
    -- Runs the base-table reconciliation report for this run's type codes and
    -- value keys. Delegates to the shared DMT_UTIL_PKG.RUN_BIP_REPORT. Two
    -- parameters: P_TYPE_CODES (comma-delimited LOOKUP_TYPE list) and
    -- P_VALUE_KEYS (comma-delimited LOOKUP_TYPE^LOOKUP_CODE composite-key list);
    -- lookup types carry the run prefix. PROCEDURE per the procedures-only
    -- contract: x_report_xml NULL with x_error_code = C_SUCCESS means zero rows;
    -- failures are logged and surfaced through x_error_code -- exceptions never
    -- escape.
    -- --------------------------------------------------------
    PROCEDURE FETCH_BIP_RESULTS (
        p_run_id      IN  NUMBER,
        p_type_codes  IN  VARCHAR2,
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
            || ' | P_TYPE_CODES: ' || NVL(p_type_codes, '(none)')
            || ' | P_VALUE_KEYS: ' || NVL(p_value_keys, '(none)'),
            p_package => C_PKG, p_procedure => C_PROC);

        IF p_type_codes IS NULL AND p_value_keys IS NULL THEN
            -- Nothing to confirm: zero rows, not an error.
            x_error_code := DMT_UTIL_PKG.C_SUCCESS;
            RETURN;
        END IF;

        l_step := 'running base-table reconciliation report for ' || C_CEMLI;
        DMT_UTIL_PKG.RUN_BIP_REPORT(
            p_run_id     => p_run_id,
            p_cemli_code => C_CEMLI,
            p_params     => 'P_TYPE_CODES|' || p_type_codes
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
    -- PARSE_AND_UPDATE  (this object's LOADED-promotion procedure)
    -- Standard LOADED-promotion shape, natural-key variant (design: "Standard
    -- LOADED-promotion shape", clause (1)/(5) -- an object with no single Fusion
    -- surrogate id promotes on its sanctioned natural key). FND lookups have NO
    -- numeric surrogate in Fusion, so the natural key IS the proof: LOOKUP_TYPE for
    -- types, LOOKUP_TYPE^LOOKUP_CODE for values (the report's RECORD_KEY). The
    -- same update stamps that Fusion-returned natural key into the registered
    -- FUSION_*_ID column (#160), guarded non-null, so no LOADED row lacks proof.
    -- Positive base-table confirmation only. Each report row is either a type
    -- found in FND_LOOKUP_TYPES (SOURCE_TYPE='TYPE') or a value found in
    -- FND_LOOKUP_VALUES_B (SOURCE_TYPE='VALUE'):
    --   TYPE  -> LOADED. RECORD_KEY = LOOKUP_TYPE.
    --            FUSION_LOOKUP_TYPE_ID = LOOKUP_TYPE.
    --   VALUE -> LOADED. RECORD_KEY = LOOKUP_TYPE || '^' || LOOKUP_CODE.
    --            FUSION_LOOKUP_ID = LOOKUP_TYPE || '~' || LOOKUP_CODE.
    -- Rows not returned are left as the load step set them (FAILED with a real
    -- REST error, else GENERATED/unaccounted) -- never a fabricated verdict.
    -- Writes the TFM tables only; no COMMIT (the runner owns the txn).
    -- --------------------------------------------------------
    PROCEDURE PARSE_AND_UPDATE (
        p_run_id     IN NUMBER,
        p_report_xml IN XMLTYPE
    ) IS
        C_PROC         CONSTANT VARCHAR2(30) := 'PARSE_AND_UPDATE';
        l_types_loaded  NUMBER := 0;
        l_values_loaded NUMBER := 0;
        l_type          VARCHAR2(30);
        l_code          VARCHAR2(30);
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
                   UPPER(x.source_type) AS source_type
            FROM   XMLTABLE('/DATA_DS/G_1' PASSING p_report_xml
                COLUMNS
                    record_key  VARCHAR2(300) PATH 'RECORD_KEY',
                    source_type VARCHAR2(20)  PATH 'SOURCE_TYPE'
            ) x
        ) LOOP
            IF r.record_key IS NULL THEN
                CONTINUE;
            END IF;

            IF r.source_type = 'TYPE' THEN
                -- Positive proof: the type exists in FND_LOOKUP_TYPES. LOADED by
                -- string-key match.
                -- #160 guard: a row whose OWN POST failed (ERROR_TEXT stashed) is NOT
                -- promoted on a natural-key base-table hit -- the key may be a
                -- pre-existing/duplicate type, not proof THIS record loaded.
                -- #130 hollow-LOADED guard: promote ONLY when OUR OWN create for
                -- THIS type returned 2xx (LOAD_CALL_STATUS = 'CREATED'). A
                -- base-table key match alone can be a PRE-EXISTING type DMT never
                -- created; ERROR_TEXT IS NULL is not enough because a blank-bodied
                -- 404 stashes no error. Only a record we actually created is LOADED.
                -- #160 (design section 7, Standard LOADED-promotion shape, clauses
                -- (2) and (5)): the SAME update stamps the Fusion-returned natural key
                -- (FND_LOOKUP_TYPES.LOOKUP_TYPE, read back by the report as
                -- RECORD_KEY) into FUSION_LOOKUP_TYPE_ID, guarded non-null, so a
                -- LOADED type always carries its base-table proof.
                UPDATE DMT_FND_LOOKUP_TYPE_TFM_TBL
                SET    TFM_STATUS            = 'LOADED',
                       FUSION_LOOKUP_TYPE_ID = r.record_key,
                       RESULTS_UPDATED_DATE  = SYSDATE,
                       LAST_UPDATED_DATE     = SYSDATE
                WHERE  RUN_ID     = p_run_id
                AND    LOOKUP_TYPE = r.record_key
                AND    r.record_key IS NOT NULL
                AND    TFM_STATUS NOT IN ('LOADED','FAILED')
                AND    ERROR_TEXT IS NULL
                AND    LOAD_CALL_STATUS = 'CREATED';
                l_types_loaded := l_types_loaded + SQL%ROWCOUNT;

            ELSIF r.source_type = 'VALUE' THEN
                -- Composite RECORD_KEY = LOOKUP_TYPE || '^' || LOOKUP_CODE.
                l_sep := INSTR(r.record_key, '^');
                IF l_sep > 0 THEN
                    l_type := SUBSTR(r.record_key, 1, l_sep - 1);
                    l_code := SUBSTR(r.record_key, l_sep + 1);

                    -- #160 guard: a value whose OWN POST failed (ERROR_TEXT stashed) is
                    -- NOT promoted on a natural-key base-table hit. ERROR_TEXT IS NULL
                    -- is the honest surrogate for the FBDI id non-null guard.
                    -- #130 hollow-LOADED guard: promote ONLY when OUR OWN create for
                    -- THIS value returned 2xx (LOAD_CALL_STATUS = 'CREATED').
                    -- #160: stamp the Fusion-returned natural key at the value's own
                    -- grain, LOOKUP_TYPE~LOOKUP_CODE (the '~' composite convention),
                    -- guarded non-null, in the same update that sets LOADED.
                    UPDATE DMT_FND_LOOKUP_VALUE_TFM_TBL
                    SET    TFM_STATUS           = 'LOADED',
                           FUSION_LOOKUP_ID     = l_type || '~' || l_code,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID     = p_run_id
                    AND    LOOKUP_TYPE = l_type
                    AND    LOOKUP_CODE = l_code
                    AND    l_type IS NOT NULL
                    AND    l_code IS NOT NULL
                    AND    TFM_STATUS NOT IN ('LOADED','FAILED')
                    AND    ERROR_TEXT IS NULL
                    AND    LOAD_CALL_STATUS = 'CREATED';
                    l_values_loaded := l_values_loaded + SQL%ROWCOUNT;
                END IF;
            END IF;
        END LOOP;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. Base-table confirmed LOADED (FUSION_*_ID = the '
            || 'Fusion natural key) -- types: ' || l_types_loaded
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
    -- Main entry point. LOAD types then values via REST POST, then RECONCILE
    -- both against the Fusion base tables via the BIP report (the new standard).
    -- COMMIT at the end (the runner also commits, but this keeps the two phases
    -- in one txn).
    -- ============================================================
    PROCEDURE LOAD_AND_RECONCILE (
        p_run_id IN NUMBER
    ) IS
        C_PROC       CONSTANT VARCHAR2(30) := 'LOAD_AND_RECONCILE';
        l_type_codes  VARCHAR2(4000);
        l_value_keys  VARCHAR2(4000);
        l_xml         XMLTYPE;
        l_err         NUMBER;
        l_types_loaded   NUMBER;
        l_types_failed   NUMBER;
        l_types_unaccnt  NUMBER;
        l_vals_loaded    NUMBER;
        l_vals_failed    NUMBER;
        l_vals_unaccnt   NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, C_PROC || ' start.', p_package => C_PKG, p_procedure => C_PROC);

        -- Phase 1: LOAD -- POST every GENERATED type, then every GENERATED value.
        LOAD_TYPES(p_run_id);
        LOAD_VALUES(p_run_id);

        -- Build the comma-delimited lists of type codes / value keys we POSTed and
        -- still need confirmed (rows the load step did NOT mark FAILED; config
        -- types carry the run prefix, so match the base tables on the exact TFM keys).
        SELECT LISTAGG(LOOKUP_TYPE, ',') WITHIN GROUP (ORDER BY LOOKUP_TYPE)
        INTO   l_type_codes
        FROM   DMT_FND_LOOKUP_TYPE_TFM_TBL
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'GENERATED';

        SELECT LISTAGG(LOOKUP_TYPE || '^' || LOOKUP_CODE, ',')
                   WITHIN GROUP (ORDER BY LOOKUP_TYPE, LOOKUP_CODE)
        INTO   l_value_keys
        FROM   DMT_FND_LOOKUP_VALUE_TFM_TBL
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'GENERATED';

        -- Phase 2: RECONCILE -- run the base-table report and confirm.
        FETCH_BIP_RESULTS(
            p_run_id     => p_run_id,
            p_type_codes => l_type_codes,
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
        UPDATE DMT_FND_LOOKUP_TYPE_TFM_TBL
        SET    TFM_STATUS           = 'FAILED',
               RESULTS_UPDATED_DATE = SYSDATE,
               LAST_UPDATED_DATE    = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'GENERATED'
        AND    ERROR_TEXT IS NOT NULL;

        UPDATE DMT_FND_LOOKUP_VALUE_TFM_TBL
        SET    TFM_STATUS           = 'FAILED',
               RESULTS_UPDATED_DATE = SYSDATE,
               LAST_UPDATED_DATE    = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'GENERATED'
        AND    ERROR_TEXT IS NOT NULL;

        -- Outcomes live on the TFM rows only; nothing is written back to the
        -- staging tables (design section 5).

        COMMIT;

        SELECT COUNT(CASE WHEN TFM_STATUS = 'LOADED' THEN 1 END),
               COUNT(CASE WHEN TFM_STATUS = 'FAILED' THEN 1 END),
               COUNT(CASE WHEN TFM_STATUS NOT IN ('LOADED','FAILED') THEN 1 END)
        INTO   l_types_loaded, l_types_failed, l_types_unaccnt
        FROM   DMT_FND_LOOKUP_TYPE_TFM_TBL
        WHERE  RUN_ID = p_run_id;

        SELECT COUNT(CASE WHEN TFM_STATUS = 'LOADED' THEN 1 END),
               COUNT(CASE WHEN TFM_STATUS = 'FAILED' THEN 1 END),
               COUNT(CASE WHEN TFM_STATUS NOT IN ('LOADED','FAILED') THEN 1 END)
        INTO   l_vals_loaded, l_vals_failed, l_vals_unaccnt
        FROM   DMT_FND_LOOKUP_VALUE_TFM_TBL
        WHERE  RUN_ID = p_run_id;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. Types -- LOADED: ' || l_types_loaded
            || ', FAILED: ' || l_types_failed || ', UNACCOUNTED: ' || l_types_unaccnt
            || ' | Values -- LOADED: ' || l_vals_loaded
            || ', FAILED: ' || l_vals_failed || ', UNACCOUNTED: ' || l_vals_unaccnt || '.',
            p_package => C_PKG, p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed.', SQLERRM, p_package => C_PKG, p_procedure => C_PROC);
            RAISE;
    END LOAD_AND_RECONCILE;

END DMT_FND_LOOKUP_RESULTS_PKG;
/
