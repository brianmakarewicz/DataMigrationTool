-- PACKAGE BODY DMT_AP_PAY_TERM_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_AP_PAY_TERM_RESULTS_PKG" AS
-- ============================================================
-- DMT_AP_PAY_TERM_RESULTS_PKG body
-- AP Payment Terms: REST load + BIP base-table reconciliation.
--
-- New reconciliation standard (DMT_DESIGN.html, PROPOSED 2026-09):
-- reconciliation MUST be a BIP report over the Fusion BASE table that
-- returns the base-table surrogate id. A REST load-call HTTP 200 is NOT
-- reconciliation. So the two responsibilities are separated:
--
--   LOAD  (LOAD_TERMS): POST each GENERATED payment-term header to the
--         standardTerms REST resource. A non-2xx response or an exception is
--         a genuine load-time rejection -> its real message is STASHED into
--         ERROR_TEXT (accumulate, never overwrite). The POST response is NOT
--         treated as LOADED; the header row is left GENERATED, pending
--         positive base-table confirmation.
--
--   RECONCILE (FETCH_BIP_RESULTS + PARSE_AND_UPDATE): run the base-table
--         report DMT_APTERMS_RECON_RPT over this run's term names. A name found
--         in AP_TERMS is positive proof -> header LOADED with FUSION_TERM_ID =
--         TERM_ID (the real surrogate id, == the REST TermId). A name not
--         returned by the report was not created: it stays FAILED if the REST
--         load already rejected it (stashed error), otherwise it is left
--         GENERATED (unaccounted) -- never a fabricated LOADED or id.
--
--   LINES: installment lines are children of a confirmed term. They are POSTed
--         (per-record LOADED/FAILED with real errors) only under a header that
--         the base-table report confirmed, using the confirmed TERM_ID as the
--         child URL key. Lines under an unconfirmed header are left GENERATED
--         for the honest accounting gate to surface.
--
-- Transport is a local rest_call helper (the "STATUS|body" convention). The
-- base-table report goes through the shared DMT_UTIL_PKG.RUN_BIP_REPORT. The
-- base table is AP_TERMS; the surrogate id is TERM_ID. Backlog #11 / new recon
-- standard.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_AP_PAY_TERM_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'PaymentTerms';

    -- Fusion REST base path for standard payment terms
    C_TERMS_PATH CONSTANT VARCHAR2(200) := '/fscmRestApi/resources/11.13.18.05/standardTerms';

    -- Map term NAME -> confirmed Fusion TERM_ID (from the base-table report),
    -- used to build the child installment URL.
    TYPE t_term_map IS TABLE OF NUMBER INDEX BY VARCHAR2(100);

    -- --------------------------------------------------------
    -- Private: make a REST call and return status|body
    -- (unchanged transport; the "STATUS|body" convention is kept).
    -- --------------------------------------------------------
    FUNCTION rest_call (
        p_method IN VARCHAR2,
        p_path   IN VARCHAR2,
        p_body   IN CLOB DEFAULT NULL,
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

        -- Attach a wallet only when a real one is configured; otherwise use the DB
        -- default certificate store (as DMT_UTIL_PKG.HTTP_REQUEST and every other
        -- HTTP caller do). An unset/placeholder WALLET_DIR must not be forced into
        -- an invalid 'file:...' path -- that throws ORA-29273 before any auth.
        IF INSTR(NVL(DMT_UTIL_PKG.GET_CONFIG('WALLET_DIR'),' '),'/') > 0 THEN
            UTL_HTTP.SET_WALLET('file:' || DMT_UTIL_PKG.GET_CONFIG('WALLET_DIR'),
                                DMT_UTIL_PKG.GET_CONFIG('WALLET_PASSWORD'));
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
    -- LOAD_TERMS
    -- The LOAD step: POST each GENERATED payment-term header to Fusion. The
    -- BIP base-table report -- not the POST response -- is the authority for
    -- LOADED, so this step NEVER marks a header terminal. It leaves every
    -- attempted header GENERATED. A non-2xx / exception is a real Fusion
    -- rejection: its message is STASHED into ERROR_TEXT (accumulate, never
    -- overwrite) so that if the reconcile step later finds the header absent
    -- from the base table, the sweep can mark it FAILED with that real error.
    -- If the reconcile step DOES find the header in AP_TERMS (e.g. a duplicate
    -- POST 400 for a term name that already exists), the stash is harmless
    -- context and the header is correctly marked LOADED. This keeps the base
    -- table the single source of truth for the outcome.
    -- Writes the TFM table only; no COMMIT (the runner owns the txn).
    -- ============================================================
    PROCEDURE LOAD_TERMS (
        p_run_id IN NUMBER
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'LOAD_TERMS';

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
            SELECT TFM_SEQUENCE_ID, NAME, DESCRIPTION, PAY_TERM_TYPE
            FROM   DMT_AP_PAY_TERM_HDR_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS = 'GENERATED'
            ORDER BY TFM_SEQUENCE_ID
        ) LOOP
            BEGIN
                l_payload := '{"Name":"' || REPLACE(r.NAME, '"', '\"') || '"'
                    || CASE WHEN r.DESCRIPTION IS NOT NULL
                       THEN ',"Description":"' || REPLACE(r.DESCRIPTION, '"', '\"') || '"'
                       END
                    || CASE WHEN r.PAY_TERM_TYPE IS NOT NULL
                       THEN ',"PayTermType":"' || REPLACE(r.PAY_TERM_TYPE, '"', '\"') || '"'
                       END
                    || '}';

                l_response := rest_call('POST', C_TERMS_PATH, l_payload, p_run_id);
                l_http_status := get_status(l_response);

                IF l_http_status IN (200, 201) THEN
                    -- POST accepted. Header stays GENERATED for the base-table
                    -- report to confirm (and capture FUSION_TERM_ID).
                    l_posted_count := l_posted_count + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Term POSTed (awaiting base-table confirmation): ' || r.NAME
                        || ' HTTP ' || l_http_status,
                        p_package => C_PKG, p_procedure => C_PROC);
                ELSE
                    -- Non-2xx: stash the real REST error but leave the header
                    -- GENERATED. The base-table report decides LOADED vs FAILED.
                    l_body := DBMS_LOB.SUBSTR(l_response, 2000, INSTR(l_response, '|') + 1);
                    UPDATE DMT_AP_PAY_TERM_HDR_TFM_TBL
                    SET    ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                          '[FUSION_ERROR] HTTP ' || l_http_status || ': '
                                          || SUBSTR(l_body, 1, 2000)),
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    l_reject_count := l_reject_count + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Term POST rejected (stashed, awaiting base-table verdict): '
                        || r.NAME || ' HTTP ' || l_http_status,
                        p_package => C_PKG, p_procedure => C_PROC, p_log_type => 'WARN');
                END IF;

                IF DBMS_LOB.ISTEMPORARY(l_response) = 1 THEN
                    DBMS_LOB.FREETEMPORARY(l_response);
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    -- Transport exception: stash it, leave GENERATED (same policy).
                    l_errmsg := SQLERRM;
                    UPDATE DMT_AP_PAY_TERM_HDR_TFM_TBL
                    SET    ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                          '[FUSION_ERROR] ' || l_errmsg),
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    l_reject_count := l_reject_count + 1;
                    DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                        'Term POST failed (exception, stashed): ' || r.NAME,
                        l_errmsg, p_package => C_PKG, p_procedure => C_PROC);
            END;
        END LOOP;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. POSTed 2xx: ' || l_posted_count
            || ', POST-rejected(stashed): ' || l_reject_count
            || ' (all headers left GENERATED for base-table reconciliation).',
            p_package => C_PKG, p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed.', SQLERRM, p_package => C_PKG, p_procedure => C_PROC);
            RAISE;
    END LOAD_TERMS;

    -- --------------------------------------------------------
    -- FETCH_BIP_RESULTS
    -- Runs the base-table reconciliation report for this run. Delegates to the
    -- shared DMT_UTIL_PKG.RUN_BIP_REPORT (no private SOAP copy). Two parameters:
    -- P_TERM_NAMES confirms headers over AP_TERMS (G_1); P_TERM_IDS confirms
    -- installment lines over AP_TERMS_LINES for the already-confirmed header
    -- TERM_IDs (G_2). Either may be blank on a pass that does not need it.
    -- Term names are not run-prefixed. PROCEDURE per the procedures-only
    -- contract: x_report_xml NULL with x_error_code = C_SUCCESS means zero rows;
    -- failures are logged and surfaced through x_error_code -- exceptions never
    -- escape.
    -- --------------------------------------------------------
    PROCEDURE FETCH_BIP_RESULTS (
        p_run_id     IN  NUMBER,
        p_term_names IN  VARCHAR2,
        p_term_ids   IN  VARCHAR2,
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
            || ' | P_TERM_NAMES: ' || NVL(p_term_names, '(none)')
            || ' | P_TERM_IDS: ' || NVL(p_term_ids, '(none)'),
            p_package => C_PKG, p_procedure => C_PROC);

        IF p_term_names IS NULL AND p_term_ids IS NULL THEN
            -- Nothing to confirm: zero rows, not an error.
            x_error_code := DMT_UTIL_PKG.C_SUCCESS;
            RETURN;
        END IF;

        l_step := 'running base-table reconciliation report for ' || C_CEMLI;
        DMT_UTIL_PKG.RUN_BIP_REPORT(
            p_run_id     => p_run_id,
            p_cemli_code => C_CEMLI,
            p_params     => 'P_TERM_NAMES|' || p_term_names
                            || '~P_TERM_IDS|' || p_term_ids,
            x_report_xml => x_report_xml,
            x_error_code => x_error_code);

        IF x_error_code != DMT_UTIL_PKG.C_SUCCESS THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ' failed while ' || l_step
                || ' (detail logged by RUN_BIP_REPORT).',
                p_package => C_PKG, p_procedure => C_PROC, p_log_type => 'ERROR');
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
    -- Positive base-table confirmation only. Each report row is a term found
    -- in AP_TERMS -> mark the matching header LOADED with FUSION_TERM_ID = the
    -- returned TERM_ID, and record NAME->TERM_ID in x_term_map so the caller
    -- can create installment children under the confirmed term. Headers not
    -- returned are left as the load step set them (stashed error, else
    -- GENERATED/unaccounted) -- never a fabricated verdict or id.
    -- Writes the TFM table only; no COMMIT (the runner owns the txn).
    -- --------------------------------------------------------
    PROCEDURE PARSE_HEADERS (
        p_run_id     IN  NUMBER,
        p_report_xml IN  XMLTYPE,
        x_term_map   OUT NOCOPY t_term_map
    ) IS
        C_PROC   CONSTANT VARCHAR2(30) := 'PARSE_HEADERS';
        l_loaded NUMBER := 0;
        l_grp    NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, C_PROC || ' start.', p_package => C_PKG, p_procedure => C_PROC);

        IF p_report_xml IS NULL THEN
            -- BIP returned no base-table rows. No name was positively confirmed;
            -- we do NOT fabricate a verdict. Headers the load step stashed an
            -- error on keep it; any still-GENERATED header is left unaccounted
            -- for the honest accounting gate to surface.
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': report returned zero base-table rows. '
                || 'No fabricated LOADED; headers left as the load step set them.',
                p_package => C_PKG, p_procedure => C_PROC, p_log_type => 'WARN');
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
                -- Positive proof: the term exists in AP_TERMS. LOADED with the
                -- real surrogate id. Match on the run's NAME (report RECORD_KEY).
                UPDATE DMT_AP_PAY_TERM_HDR_TFM_TBL
                SET    TFM_STATUS           = 'LOADED',
                       FUSION_TERM_ID       = r.fusion_id,
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID     = p_run_id
                AND    NAME       = r.record_key
                AND    TFM_STATUS NOT IN ('LOADED','FAILED');
                l_loaded := l_loaded + SQL%ROWCOUNT;

                -- Record SOURCE_GROUP_ID->TERM_ID so the line pass can confirm
                -- installments under this confirmed term.
                BEGIN
                    SELECT SOURCE_GROUP_ID INTO l_grp
                    FROM   DMT_AP_PAY_TERM_HDR_TFM_TBL
                    WHERE  RUN_ID = p_run_id AND NAME = r.record_key
                    AND    ROWNUM = 1;
                    IF l_grp IS NOT NULL THEN
                        x_term_map(TO_CHAR(l_grp)) := r.fusion_id;
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN NULL;
                END;
            END IF;
        END LOOP;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. Headers base-table confirmed LOADED: ' || l_loaded || '.',
            p_package => C_PKG, p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed.', SQLERRM, p_package => C_PKG, p_procedure => C_PROC);
            RAISE;
    END PARSE_HEADERS;

    -- --------------------------------------------------------
    -- POST_LINES
    -- The LOAD step for installment lines: POST each GENERATED line whose parent
    -- header was base-table-confirmed (present in p_term_map, keyed by
    -- SOURCE_GROUP_ID), using the confirmed TERM_ID as the child URL key. Like
    -- LOAD_TERMS, this NEVER marks a line terminal: the base-table report over
    -- AP_TERMS_LINES is the authority for LOADED. A non-2xx / exception is a real
    -- Fusion rejection whose message is STASHED into ERROR_TEXT (accumulate,
    -- never overwrite); the line stays GENERATED pending line-report confirmation.
    -- A line whose parent was NOT confirmed is skipped (left GENERATED with no
    -- fabricated error) for the honest accounting gate to surface.
    -- Writes the TFM table only; no COMMIT (the runner owns the txn).
    -- --------------------------------------------------------
    PROCEDURE POST_LINES (
        p_run_id   IN NUMBER,
        p_term_map IN t_term_map
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'POST_LINES';

        l_response     CLOB;
        l_http_status  NUMBER;
        l_body         VARCHAR2(32767);
        l_payload      CLOB;
        l_term_id      NUMBER;
        l_posted       NUMBER := 0;
        l_reject       NUMBER := 0;
        l_errmsg       VARCHAR2(4000);
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, C_PROC || ' start.', p_package => C_PKG, p_procedure => C_PROC);

        FOR r IN (
            SELECT ln.TFM_SEQUENCE_ID, ln.SOURCE_GROUP_ID, ln.SEQUENCE_NUM,
                   ln.DUE_PERCENT, ln.DUE_AMOUNT, ln.DUE_DAYS, ln.DUE_DATE,
                   ln.DISCOUNT_PERCENT, ln.DISCOUNT_DAYS,
                   ln.DISCOUNT_PERCENT_2, ln.DISCOUNT_DAYS_2
            FROM   DMT_AP_PAY_TERM_LINE_TFM_TBL ln
            WHERE  ln.RUN_ID = p_run_id
            AND    ln.TFM_STATUS = 'GENERATED'
            ORDER BY ln.SOURCE_GROUP_ID, ln.SEQUENCE_NUM
        ) LOOP
            BEGIN
                -- Only attempt children under a base-table-confirmed parent.
                IF NOT p_term_map.EXISTS(TO_CHAR(r.SOURCE_GROUP_ID)) THEN
                    CONTINUE;
                END IF;

                l_term_id := p_term_map(TO_CHAR(r.SOURCE_GROUP_ID));

                l_payload := '{"SequenceNumber":' || NVL(TO_CHAR(r.SEQUENCE_NUM), '1')
                    || CASE WHEN r.DUE_PERCENT IS NOT NULL
                       THEN ',"DuePercent":' || TO_CHAR(r.DUE_PERCENT) END
                    || CASE WHEN r.DUE_AMOUNT IS NOT NULL
                       THEN ',"DueAmount":' || TO_CHAR(r.DUE_AMOUNT) END
                    || CASE WHEN r.DUE_DAYS IS NOT NULL
                       THEN ',"DueDays":' || TO_CHAR(r.DUE_DAYS) END
                    || CASE WHEN r.DUE_DATE IS NOT NULL
                       THEN ',"DueDate":"' || TO_CHAR(r.DUE_DATE, 'YYYY-MM-DD') || '"' END
                    || CASE WHEN r.DISCOUNT_PERCENT IS NOT NULL
                       THEN ',"DiscountPercent":' || TO_CHAR(r.DISCOUNT_PERCENT) END
                    || CASE WHEN r.DISCOUNT_DAYS IS NOT NULL
                       THEN ',"DiscountDays":' || TO_CHAR(r.DISCOUNT_DAYS) END
                    || CASE WHEN r.DISCOUNT_PERCENT_2 IS NOT NULL
                       THEN ',"DiscountPercent2":' || TO_CHAR(r.DISCOUNT_PERCENT_2) END
                    || CASE WHEN r.DISCOUNT_DAYS_2 IS NOT NULL
                       THEN ',"DiscountDays2":' || TO_CHAR(r.DISCOUNT_DAYS_2) END
                    || '}';

                l_response := rest_call('POST',
                    C_TERMS_PATH || '/' || TO_CHAR(l_term_id) || '/child/installments',
                    l_payload, p_run_id);
                l_http_status := get_status(l_response);

                IF l_http_status IN (200, 201) THEN
                    -- POST accepted; leave GENERATED for the line report to confirm.
                    l_posted := l_posted + 1;
                ELSE
                    -- Non-2xx: stash the real error, leave GENERATED. The
                    -- AP_TERMS_LINES report decides LOADED vs FAILED.
                    l_body := DBMS_LOB.SUBSTR(l_response, 2000, INSTR(l_response, '|') + 1);
                    UPDATE DMT_AP_PAY_TERM_LINE_TFM_TBL
                    SET    ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                          '[FUSION_ERROR] HTTP ' || l_http_status || ': '
                                          || SUBSTR(l_body, 1, 2000)),
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;
                    l_reject := l_reject + 1;
                END IF;

                IF DBMS_LOB.ISTEMPORARY(l_response) = 1 THEN
                    DBMS_LOB.FREETEMPORARY(l_response);
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    l_errmsg := SQLERRM;
                    UPDATE DMT_AP_PAY_TERM_LINE_TFM_TBL
                    SET    ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                          '[FUSION_ERROR] ' || l_errmsg),
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;
                    l_reject := l_reject + 1;
                    DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                        'Line POST failed (exception, stashed): GRP=' || r.SOURCE_GROUP_ID
                        || ' SEQ=' || r.SEQUENCE_NUM,
                        l_errmsg, p_package => C_PKG, p_procedure => C_PROC);
            END;
        END LOOP;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. POSTed 2xx: ' || l_posted
            || ', POST-rejected(stashed): ' || l_reject
            || ' (all lines left GENERATED for base-table reconciliation).',
            p_package => C_PKG, p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed.', SQLERRM, p_package => C_PKG, p_procedure => C_PROC);
            RAISE;
    END POST_LINES;

    -- --------------------------------------------------------
    -- PARSE_LINES
    -- Positive base-table confirmation for installment lines. Each G_2 report
    -- row is a line found in AP_TERMS_LINES for a confirmed TERM_ID; match it to
    -- its TFM line by (confirmed TERM_ID via SOURCE_GROUP_ID map, SEQUENCE_NUM)
    -- and mark it LOADED with FUSION_TERM_ID = the confirmed TERM_ID. Lines not
    -- returned are left as the load step set them (stashed error, else
    -- GENERATED/unaccounted) -- never a fabricated verdict.
    -- Writes the TFM table only; no COMMIT (the runner owns the txn).
    -- --------------------------------------------------------
    PROCEDURE PARSE_LINES (
        p_run_id     IN NUMBER,
        p_report_xml IN XMLTYPE
    ) IS
        C_PROC   CONSTANT VARCHAR2(30) := 'PARSE_LINES';
        l_loaded NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, C_PROC || ' start.', p_package => C_PKG, p_procedure => C_PROC);

        IF p_report_xml IS NULL THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': line report returned zero base-table rows. '
                || 'No fabricated LOADED; lines left as the load step set them.',
                p_package => C_PKG, p_procedure => C_PROC, p_log_type => 'WARN');
            RETURN;
        END IF;

        -- Report RECORD_KEY for a line is TERM_ID-SEQUENCE_NUM. Match the TFM
        -- line by its confirmed parent TERM_ID (joined via the header) and
        -- SEQUENCE_NUM. FUSION_ID carries the TERM_ID; SEQUENCE_NUM its own tag.
        FOR r IN (
            SELECT UPPER(x.source_type) AS source_type,
                   x.fusion_id          AS term_id,
                   x.sequence_num       AS sequence_num
            FROM   XMLTABLE('/DATA_DS/G_2' PASSING p_report_xml
                COLUMNS
                    source_type  VARCHAR2(20) PATH 'SOURCE_TYPE',
                    fusion_id    NUMBER       PATH 'FUSION_ID',
                    sequence_num NUMBER       PATH 'SEQUENCE_NUM'
            ) x
        ) LOOP
            IF r.source_type = 'BASE_LINE' AND r.term_id IS NOT NULL THEN
                UPDATE DMT_AP_PAY_TERM_LINE_TFM_TBL ln
                SET    ln.TFM_STATUS           = 'LOADED',
                       ln.FUSION_TERM_ID       = r.term_id,
                       ln.RESULTS_UPDATED_DATE = SYSDATE,
                       ln.LAST_UPDATED_DATE    = SYSDATE
                WHERE  ln.RUN_ID       = p_run_id
                AND    ln.SEQUENCE_NUM = r.sequence_num
                AND    ln.TFM_STATUS NOT IN ('LOADED','FAILED')
                AND    EXISTS (SELECT 1 FROM DMT_AP_PAY_TERM_HDR_TFM_TBL h
                               WHERE  h.RUN_ID          = p_run_id
                               AND    h.SOURCE_GROUP_ID = ln.SOURCE_GROUP_ID
                               AND    h.FUSION_TERM_ID  = r.term_id);
                l_loaded := l_loaded + SQL%ROWCOUNT;
            END IF;
        END LOOP;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. Lines base-table confirmed LOADED: ' || l_loaded || '.',
            p_package => C_PKG, p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed.', SQLERRM, p_package => C_PKG, p_procedure => C_PROC);
            RAISE;
    END PARSE_LINES;

    -- ============================================================
    -- LOAD_AND_RECONCILE
    -- Main entry point. LOAD headers via REST POST, RECONCILE headers via the
    -- BIP base-table report (the new standard), then LOAD installment lines
    -- under confirmed terms. No COMMIT until the end (the runner also commits,
    -- but this keeps the phases in one txn).
    -- ============================================================
    PROCEDURE LOAD_AND_RECONCILE (
        p_run_id IN NUMBER
    ) IS
        C_PROC     CONSTANT VARCHAR2(30) := 'LOAD_AND_RECONCILE';
        l_names    VARCHAR2(4000);
        l_ids      VARCHAR2(4000);
        l_xml      XMLTYPE;
        l_line_xml XMLTYPE;
        l_err      NUMBER;
        l_term_map t_term_map;
        l_idx      VARCHAR2(100);
        l_loaded   NUMBER;
        l_failed   NUMBER;
        l_unaccnt  NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, C_PROC || ' start.', p_package => C_PKG, p_procedure => C_PROC);

        -- Phase 1: LOAD -- POST every GENERATED header to Fusion.
        LOAD_TERMS(p_run_id);

        -- Build the comma-delimited list of term names we POSTed and still need
        -- confirmed (headers the load step did NOT mark FAILED). Names are not
        -- run-prefixed, so match the base table on the exact names.
        SELECT LISTAGG(NAME, ',') WITHIN GROUP (ORDER BY NAME)
        INTO   l_names
        FROM   DMT_AP_PAY_TERM_HDR_TFM_TBL
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'GENERATED';

        -- Phase 2: RECONCILE headers -- run the base-table report (G_1 by name)
        -- and confirm. P_TERM_IDS is empty on this pass (no lines yet).
        FETCH_BIP_RESULTS(
            p_run_id     => p_run_id,
            p_term_names => l_names,
            p_term_ids   => NULL,
            x_report_xml => l_xml,
            x_error_code => l_err);

        IF l_err != DMT_UTIL_PKG.C_SUCCESS THEN
            -- Reconciliation transport failed: raise loudly so the queue work item
            -- fails, never a silent zero-row "success".
            RAISE_APPLICATION_ERROR(-20039,
                'LOAD_AND_RECONCILE: header base-table reconciliation report failed for CEMLI '
                || C_CEMLI || ' (detail in DMT_LOG_TBL).');
        END IF;

        PARSE_HEADERS(p_run_id, l_xml, l_term_map);

        -- Phase 3: LOAD lines under base-table-confirmed terms (POST only;
        -- never terminal), then RECONCILE lines via the base-table report
        -- (G_2 over AP_TERMS_LINES by the confirmed TERM_IDs).
        POST_LINES(p_run_id, l_term_map);

        -- Build the comma-delimited list of confirmed TERM_IDs from the map.
        l_ids := NULL;
        l_idx := l_term_map.FIRST;
        WHILE l_idx IS NOT NULL LOOP
            l_ids := CASE WHEN l_ids IS NULL THEN '' ELSE l_ids || ',' END
                     || TO_CHAR(l_term_map(l_idx));
            l_idx := l_term_map.NEXT(l_idx);
        END LOOP;

        IF l_ids IS NOT NULL THEN
            FETCH_BIP_RESULTS(
                p_run_id     => p_run_id,
                p_term_names => NULL,
                p_term_ids   => l_ids,
                x_report_xml => l_line_xml,
                x_error_code => l_err);

            IF l_err != DMT_UTIL_PKG.C_SUCCESS THEN
                RAISE_APPLICATION_ERROR(-20039,
                    'LOAD_AND_RECONCILE: line base-table reconciliation report failed for CEMLI '
                    || C_CEMLI || ' (detail in DMT_LOG_TBL).');
            END IF;

            PARSE_LINES(p_run_id, l_line_xml);
        END IF;

        -- Post-reconcile sweep: any header NOT confirmed in the base table is
        -- still GENERATED. If its POST returned a real Fusion error (stashed in
        -- ERROR_TEXT by LOAD_TERMS) mark it FAILED on that real error. A header
        -- with no stashed error AND no base-table hit is left GENERATED
        -- (unaccounted); the accounting gate surfaces it -- never a fabricated
        -- verdict. The same sweep applies to lines (stashed by POST_LINES).
        UPDATE DMT_AP_PAY_TERM_HDR_TFM_TBL
        SET    TFM_STATUS           = 'FAILED',
               RESULTS_UPDATED_DATE = SYSDATE,
               LAST_UPDATED_DATE    = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'GENERATED'
        AND    ERROR_TEXT IS NOT NULL;

        UPDATE DMT_AP_PAY_TERM_LINE_TFM_TBL
        SET    TFM_STATUS           = 'FAILED',
               RESULTS_UPDATED_DATE = SYSDATE,
               LAST_UPDATED_DATE    = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'GENERATED'
        AND    ERROR_TEXT IS NOT NULL;

        -- Mirror the terminal TFM outcome onto STG for headers.
        UPDATE DMT_AP_PAY_TERM_HDR_STG_TBL s
        SET    s.STG_STATUS = (SELECT t.TFM_STATUS
                               FROM   DMT_AP_PAY_TERM_HDR_TFM_TBL t
                               WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                               AND    t.RUN_ID = p_run_id),
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  EXISTS (SELECT 1 FROM DMT_AP_PAY_TERM_HDR_TFM_TBL t
                       WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                       AND    t.RUN_ID = p_run_id
                       AND    t.TFM_STATUS IN ('LOADED','FAILED'));

        -- Mirror the terminal TFM outcome onto STG for lines.
        UPDATE DMT_AP_PAY_TERM_LINE_STG_TBL s
        SET    s.STG_STATUS = (SELECT t.TFM_STATUS
                               FROM   DMT_AP_PAY_TERM_LINE_TFM_TBL t
                               WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                               AND    t.RUN_ID = p_run_id),
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  EXISTS (SELECT 1 FROM DMT_AP_PAY_TERM_LINE_TFM_TBL t
                       WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                       AND    t.RUN_ID = p_run_id
                       AND    t.TFM_STATUS IN ('LOADED','FAILED'));

        COMMIT;

        SELECT COUNT(CASE WHEN TFM_STATUS = 'LOADED' THEN 1 END),
               COUNT(CASE WHEN TFM_STATUS = 'FAILED' THEN 1 END),
               COUNT(CASE WHEN TFM_STATUS NOT IN ('LOADED','FAILED') THEN 1 END)
        INTO   l_loaded, l_failed, l_unaccnt
        FROM   (SELECT TFM_STATUS FROM DMT_AP_PAY_TERM_HDR_TFM_TBL WHERE RUN_ID = p_run_id
                UNION ALL
                SELECT TFM_STATUS FROM DMT_AP_PAY_TERM_LINE_TFM_TBL WHERE RUN_ID = p_run_id);

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

END DMT_AP_PAY_TERM_RESULTS_PKG;
/
