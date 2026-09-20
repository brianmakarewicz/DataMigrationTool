-- PACKAGE BODY DMT_INV_UOM_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_INV_UOM_RESULTS_PKG" AS
-- ============================================================
-- DMT_INV_UOM_RESULTS_PKG body
-- Units of Measure: REST load + BIP base-table reconciliation.
--
-- New reconciliation standard (DMT_DESIGN.html, PROPOSED 2026-09):
-- reconciliation MUST be a BIP report over the Fusion BASE table that
-- returns the base-table surrogate id. A REST load-call HTTP 200 is NOT
-- reconciliation. So the two responsibilities are now separated:
--
--   LOAD  (LOAD_UOMS): POST each GENERATED UOM to the unitsOfMeasure REST
--         resource. A non-2xx response or an exception is a genuine
--         load-time rejection -> that row is marked FAILED with the real
--         REST error. A 2xx response is NOT treated as LOADED; the row is
--         left GENERATED, pending positive base-table confirmation.
--
--   RECONCILE (FETCH_BIP_RESULTS + PARSE_AND_UPDATE): run the base-table
--         report DMT_UOM_RECON_RPT over this run's UOM codes. A code found
--         in INV_UNITS_OF_MEASURE_B is positive proof -> LOADED with
--         FUSION_UOM_ID = UNIT_OF_MEASURE_ID (the real surrogate id). A
--         code not returned by the report was not created: it stays FAILED
--         if the REST load already rejected it, otherwise it is left
--         GENERATED (unaccounted) -- never a fabricated LOADED or id.
--
-- Transport is the shared DMT_UTIL_PKG.RUN_BIP_REPORT (no private SOAP
-- copy). The base table is INV_UNITS_OF_MEASURE_B; the surrogate id is
-- UNIT_OF_MEASURE_ID (== the REST UOMId). Backlog #11 / new recon standard.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50)  := 'DMT_INV_UOM_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30)  := 'UnitsOfMeasure';

    -- Fusion REST base path for units of measure
    C_UOM_PATH CONSTANT VARCHAR2(200) := '/fscmRestApi/resources/11.13.18.05/unitsOfMeasure';

    -- --------------------------------------------------------
    -- Private: make a REST call and return status + response
    -- (unchanged transport; the "STATUS|body" convention is kept).
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
    -- LOAD_UOMS
    -- The LOAD step: POST each GENERATED UOM to Fusion. The BIP base-table
    -- report -- not the POST response -- is the authority for LOADED, so this
    -- step NEVER marks a row terminal. It leaves every attempted row GENERATED.
    -- A non-2xx / exception is a real Fusion rejection: its message is STASHED
    -- into ERROR_TEXT (accumulate, never overwrite) so that if the reconcile
    -- step later finds the row absent from the base table, the sweep can mark it
    -- FAILED with that real error. If the reconcile step DOES find the row in the
    -- base table (e.g. a duplicate POST 400 for a UOM that already exists), the
    -- stash is harmless context and the row is correctly marked LOADED. This
    -- keeps the base table the single source of truth for the outcome.
    -- Writes the TFM table only; no COMMIT (the runner owns the txn).
    -- ============================================================
    PROCEDURE LOAD_UOMS (
        p_run_id IN NUMBER
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'LOAD_UOMS';

        l_response      CLOB;
        l_http_status   NUMBER;
        l_body          VARCHAR2(32767);
        l_payload       CLOB;

        l_posted_count  NUMBER := 0;
        l_reject_count  NUMBER := 0;
        l_errmsg        VARCHAR2(4000);
        l_base_uom_val  VARCHAR2(10);
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, C_PROC || ' start.', p_package => C_PKG, p_procedure => C_PROC);

        FOR r IN (
            SELECT TFM_SEQUENCE_ID,
                   UOM_CODE, UOM_CLASS, UNIT_OF_MEASURE,
                   DESCRIPTION, BASE_UOM_FLAG
            FROM   DMT_INV_UOM_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS = 'GENERATED'
            ORDER BY TFM_SEQUENCE_ID
        ) LOOP
            BEGIN
                -- Fusion REST expects BaseUnitFlag as boolean true/false
                IF r.BASE_UOM_FLAG = 'Y' THEN
                    l_base_uom_val := 'true';
                ELSE
                    l_base_uom_val := 'false';
                END IF;

                l_payload := '{"UOMCode":"' || REPLACE(r.UOM_CODE, '"', '\"') || '"'
                    || ',"UOM":"' || REPLACE(NVL(r.UNIT_OF_MEASURE, r.UOM_CODE), '"', '\"') || '"'
                    || ',"UOMClass":' || NVL(r.UOM_CLASS, 'null')
                    || ',"BaseUnitFlag":' || l_base_uom_val
                    || CASE WHEN r.DESCRIPTION IS NOT NULL
                       THEN ',"Description":"' || REPLACE(r.DESCRIPTION, '"', '\"') || '"'
                       END
                    || '}';

                l_response := rest_call('POST', C_UOM_PATH, l_payload, p_run_id);
                l_http_status := get_status(l_response);

                IF l_http_status IN (200, 201) THEN
                    -- POST accepted. Row stays GENERATED for the base-table report to
                    -- confirm (and capture FUSION_UOM_ID).
                    l_posted_count := l_posted_count + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'UOM POSTed (awaiting base-table confirmation): ' || r.UOM_CODE
                        || ' HTTP ' || l_http_status,
                        p_package => C_PKG, p_procedure => C_PROC);
                ELSE
                    -- Non-2xx: stash the real REST error but leave the row GENERATED.
                    -- The base-table report decides LOADED vs FAILED. If the report
                    -- finds this code absent, the sweep marks it FAILED on this error.
                    l_body := DBMS_LOB.SUBSTR(l_response, 2000, INSTR(l_response, '|') + 1);
                    UPDATE DMT_INV_UOM_TFM_TBL
                    SET    ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                          '[FUSION_ERROR] HTTP ' || l_http_status || ': '
                                          || SUBSTR(l_body, 1, 2000)),
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    l_reject_count := l_reject_count + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'UOM POST rejected (stashed, awaiting base-table verdict): '
                        || r.UOM_CODE || ' HTTP ' || l_http_status,
                        p_log_type => 'WARN', p_package => C_PKG, p_procedure => C_PROC);
                END IF;

                IF DBMS_LOB.ISTEMPORARY(l_response) = 1 THEN
                    DBMS_LOB.FREETEMPORARY(l_response);
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    -- Transport exception: stash it, leave GENERATED (same policy).
                    l_errmsg := SQLERRM;
                    UPDATE DMT_INV_UOM_TFM_TBL
                    SET    ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                          '[FUSION_ERROR] ' || l_errmsg),
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    l_reject_count := l_reject_count + 1;
                    DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                        'UOM POST failed (exception, stashed): ' || r.UOM_CODE,
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
    END LOAD_UOMS;

    -- --------------------------------------------------------
    -- FETCH_BIP_RESULTS
    -- Runs the base-table reconciliation report for this run's UOM codes.
    -- Delegates to the shared DMT_UTIL_PKG.RUN_BIP_REPORT (no private SOAP
    -- copy). The one parameter is the comma-delimited list of UOM codes
    -- this run sent (config UOM codes are not run-prefixed). PROCEDURE per
    -- the procedures-only contract: x_report_xml NULL with x_error_code =
    -- C_SUCCESS means zero rows; failures are logged and surfaced through
    -- x_error_code -- exceptions never escape.
    -- --------------------------------------------------------
    PROCEDURE FETCH_BIP_RESULTS (
        p_run_id     IN  NUMBER,
        p_uom_codes  IN  VARCHAR2,
        x_report_xml OUT XMLTYPE,
        x_error_code OUT NUMBER
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'FETCH_BIP_RESULTS';
        l_step VARCHAR2(500);
    BEGIN
        x_report_xml := NULL;
        x_error_code := DMT_UTIL_PKG.C_ERROR;   -- pessimistic until proven

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' start. CEMLI: ' || C_CEMLI
            || ' | P_UOM_CODES: ' || NVL(p_uom_codes, '(none)'),
            p_package => C_PKG, p_procedure => C_PROC);

        IF p_uom_codes IS NULL THEN
            -- No POSTed codes to confirm: zero rows, not an error.
            x_error_code := DMT_UTIL_PKG.C_SUCCESS;
            RETURN;
        END IF;

        l_step := 'running base-table reconciliation report for ' || C_CEMLI;
        DMT_UTIL_PKG.RUN_BIP_REPORT(
            p_run_id     => p_run_id,
            p_cemli_code => C_CEMLI,
            p_params     => 'P_UOM_CODES|' || p_uom_codes,
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
    -- Positive base-table confirmation only. Each report row is a UOM
    -- found in INV_UNITS_OF_MEASURE_B -> mark that TFM row LOADED with
    -- FUSION_UOM_ID = the returned UNIT_OF_MEASURE_ID. Rows not returned
    -- are left as the load step set them (FAILED with a real REST error,
    -- else GENERATED/unaccounted) -- never a fabricated verdict or id.
    -- Writes the TFM table only; no COMMIT (the runner owns the txn).
    -- --------------------------------------------------------
    PROCEDURE PARSE_AND_UPDATE (
        p_run_id     IN NUMBER,
        p_report_xml IN XMLTYPE
    ) IS
        C_PROC   CONSTANT VARCHAR2(30) := 'PARSE_AND_UPDATE';
        l_loaded NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, C_PROC || ' start.', p_package => C_PKG, p_procedure => C_PROC);

        IF p_report_xml IS NULL THEN
            -- BIP returned no base-table rows. No code was positively confirmed;
            -- we do NOT fabricate a verdict. Rows the load step marked FAILED keep
            -- their real REST error; any still-GENERATED row is left unaccounted
            -- for the honest accounting gate to surface.
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
                    record_key  VARCHAR2(100) PATH 'RECORD_KEY',
                    source_type VARCHAR2(20)  PATH 'SOURCE_TYPE',
                    fusion_id   NUMBER        PATH 'FUSION_ID'
            ) x
        ) LOOP
            IF r.source_type = 'BASE' AND r.fusion_id IS NOT NULL THEN
                -- Positive proof: the UOM exists in the base table. LOADED with the
                -- real surrogate id. Match on the run's UOM_CODE (report RECORD_KEY).
                UPDATE DMT_INV_UOM_TFM_TBL
                SET    TFM_STATUS           = 'LOADED',
                       FUSION_UOM_ID        = r.fusion_id,
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID     = p_run_id
                AND    UOM_CODE   = r.record_key
                AND    TFM_STATUS NOT IN ('LOADED','FAILED');
                l_loaded := l_loaded + SQL%ROWCOUNT;
            END IF;
        END LOOP;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. Base-table confirmed LOADED: ' || l_loaded || '.',
            p_package => C_PKG, p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed.', SQLERRM, p_package => C_PKG, p_procedure => C_PROC);
            RAISE;
    END PARSE_AND_UPDATE;

    -- ============================================================
    -- LOAD_AND_RECONCILE
    -- Main entry point. LOAD via REST POST, then RECONCILE via the BIP
    -- base-table report (the new standard). No COMMIT until the end (the
    -- runner also commits, but this keeps the two phases in one txn).
    -- ============================================================
    PROCEDURE LOAD_AND_RECONCILE (
        p_run_id IN NUMBER
    ) IS
        C_PROC     CONSTANT VARCHAR2(30) := 'LOAD_AND_RECONCILE';
        l_codes    VARCHAR2(4000);
        l_xml      XMLTYPE;
        l_err      NUMBER;
        l_loaded   NUMBER;
        l_failed   NUMBER;
        l_unaccnt  NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, C_PROC || ' start.', p_package => C_PKG, p_procedure => C_PROC);

        -- Phase 1: LOAD -- POST every GENERATED UOM to Fusion.
        LOAD_UOMS(p_run_id);

        -- Build the comma-delimited list of codes we POSTed and still need
        -- confirmed (rows the load step did NOT mark FAILED). Config UOM codes
        -- are not run-prefixed, so we match the base table on the exact codes.
        SELECT LISTAGG(UOM_CODE, ',') WITHIN GROUP (ORDER BY UOM_CODE)
        INTO   l_codes
        FROM   DMT_INV_UOM_TFM_TBL
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'GENERATED';

        -- Phase 2: RECONCILE -- run the base-table report and confirm.
        FETCH_BIP_RESULTS(
            p_run_id     => p_run_id,
            p_uom_codes  => l_codes,
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
        -- ERROR_TEXT by LOAD_UOMS) mark it FAILED on that real error. A row with
        -- no stashed error AND no base-table hit is left GENERATED (unaccounted);
        -- the accounting gate surfaces it -- we never fabricate a verdict.
        UPDATE DMT_INV_UOM_TFM_TBL
        SET    TFM_STATUS           = 'FAILED',
               RESULTS_UPDATED_DATE = SYSDATE,
               LAST_UPDATED_DATE    = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'GENERATED'
        AND    ERROR_TEXT IS NOT NULL;

        -- Mirror the terminal TFM outcome onto STG (STG_STATUS is terminal from
        -- staging's point of view; the TFM row is the record of the Fusion outcome).
        UPDATE DMT_INV_UOM_STG_TBL s
        SET    s.STG_STATUS = (SELECT t.TFM_STATUS
                               FROM   DMT_INV_UOM_TFM_TBL t
                               WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                               AND    t.RUN_ID = p_run_id),
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  EXISTS (SELECT 1 FROM DMT_INV_UOM_TFM_TBL t
                       WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                       AND    t.RUN_ID = p_run_id
                       AND    t.TFM_STATUS IN ('LOADED','FAILED'));

        COMMIT;

        SELECT COUNT(CASE WHEN TFM_STATUS = 'LOADED'    THEN 1 END),
               COUNT(CASE WHEN TFM_STATUS = 'FAILED'    THEN 1 END),
               COUNT(CASE WHEN TFM_STATUS NOT IN ('LOADED','FAILED') THEN 1 END)
        INTO   l_loaded, l_failed, l_unaccnt
        FROM   DMT_INV_UOM_TFM_TBL
        WHERE  RUN_ID = p_run_id;

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

END DMT_INV_UOM_RESULTS_PKG;
/
