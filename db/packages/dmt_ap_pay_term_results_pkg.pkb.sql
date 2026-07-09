-- PACKAGE BODY DMT_AP_PAY_TERM_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_AP_PAY_TERM_RESULTS_PKG" AS

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_AP_PAY_TERM_RESULTS_PKG';

    -- Fusion REST base path for standard payment terms
    C_TERMS_PATH CONSTANT VARCHAR2(200) := '/fscmRestApi/resources/11.13.18.05/standardTerms';

    -- --------------------------------------------------------
    -- Private: make a REST call and return status|body
    -- --------------------------------------------------------
    FUNCTION rest_call (
        p_method         IN VARCHAR2,
        p_path           IN VARCHAR2,
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

        UTL_HTTP.SET_WALLET('file:' || DMT_UTIL_PKG.GET_CONFIG('WALLET_DIR'),
                            DMT_UTIL_PKG.GET_CONFIG('WALLET_PASSWORD'));

        l_http_req := UTL_HTTP.BEGIN_REQUEST(l_url, p_method, 'HTTP/1.1');
        UTL_HTTP.SET_HEADER(l_http_req, 'Authorization',
            'Basic ' || UTL_RAW.CAST_TO_VARCHAR2(UTL_ENCODE.BASE64_ENCODE(
                UTL_RAW.CAST_TO_RAW(l_username || ':' || l_password))));
        UTL_HTTP.SET_HEADER(l_http_req, 'Accept', 'application/json');

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

    FUNCTION get_status(p_response IN CLOB) RETURN NUMBER IS
    BEGIN
        RETURN TO_NUMBER(SUBSTR(p_response, 1, INSTR(p_response, '|') - 1));
    END;

    FUNCTION get_body(p_response IN CLOB) RETURN CLOB IS
    BEGIN
        RETURN DBMS_LOB.SUBSTR(p_response,
            DBMS_LOB.GETLENGTH(p_response) - INSTR(p_response, '|'),
            INSTR(p_response, '|') + 1);
    END;

    -- ============================================================
    -- LOAD_AND_RECONCILE
    -- Phase 1: POST headers, extract TermId from response.
    -- Phase 2: POST lines as children of the TermId.
    -- ============================================================
    PROCEDURE LOAD_AND_RECONCILE (
        p_run_id IN NUMBER
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'LOAD_AND_RECONCILE';

        l_response      CLOB;
        l_http_status   NUMBER;
        l_body          VARCHAR2(32767);
        l_payload       CLOB;
        l_term_id       NUMBER;

        l_hdr_loaded    NUMBER := 0;
        l_hdr_failed    NUMBER := 0;
        l_line_loaded   NUMBER := 0;
        l_line_failed   NUMBER := 0;
        l_errmsg        VARCHAR2(4000);

        -- Map SOURCE_GROUP_ID -> Fusion TermId for child URL construction
        TYPE t_term_map IS TABLE OF NUMBER INDEX BY VARCHAR2(100);
        l_term_map t_term_map;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id,
            'LOAD_AND_RECONCILE start.', C_PKG, C_PROC);

        -- ========================================
        -- Phase 1: Create Payment Terms in Fusion
        -- ========================================
        FOR r IN (
            SELECT TFM_SEQUENCE_ID, STG_SEQUENCE_ID, SOURCE_GROUP_ID,
                   NAME, DESCRIPTION, PAY_TERM_TYPE
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
                    -- Extract TermId from response body
                    l_body := DBMS_LOB.SUBSTR(l_response, 4000, INSTR(l_response, '|') + 1);
                    l_term_id := JSON_VALUE(l_body, '$.TermId' RETURNING NUMBER);

                    -- Store mapping for child line creation
                    IF r.SOURCE_GROUP_ID IS NOT NULL AND l_term_id IS NOT NULL THEN
                        l_term_map(r.SOURCE_GROUP_ID) := l_term_id;
                    END IF;

                    UPDATE DMT_AP_PAY_TERM_HDR_TFM_TBL
                    SET    TFM_STATUS = 'LOADED', RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    UPDATE DMT_AP_PAY_TERM_HDR_STG_TBL
                    SET    STG_STATUS = 'LOADED', LAST_UPDATED_DATE = SYSDATE
                    WHERE  STG_SEQUENCE_ID = r.STG_SEQUENCE_ID;

                    l_hdr_loaded := l_hdr_loaded + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Term LOADED: ' || r.NAME || ' (TermId=' || l_term_id || ')',
                        C_PKG, C_PROC);
                ELSE
                    l_body := DBMS_LOB.SUBSTR(l_response, 1000, INSTR(l_response, '|') + 1);
                    UPDATE DMT_AP_PAY_TERM_HDR_TFM_TBL
                    SET    TFM_STATUS = 'FAILED',
                           ERROR_TEXT = '[FUSION_ERROR] HTTP ' || l_http_status || ': '
                                        || SUBSTR(l_body, 1, 2000),
                           RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    UPDATE DMT_AP_PAY_TERM_HDR_STG_TBL
                    SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                    WHERE  STG_SEQUENCE_ID = r.STG_SEQUENCE_ID;

                    l_hdr_failed := l_hdr_failed + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Term FAILED: ' || r.NAME || ' HTTP ' || l_http_status,
                        C_PKG, C_PROC, 'WARN');
                END IF;

                IF DBMS_LOB.ISTEMPORARY(l_response) = 1 THEN
                    DBMS_LOB.FREETEMPORARY(l_response);
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    l_errmsg := SQLERRM;
                    UPDATE DMT_AP_PAY_TERM_HDR_TFM_TBL
                    SET    TFM_STATUS = 'FAILED',
                           ERROR_TEXT = '[FUSION_ERROR] ' || l_errmsg,
                           RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    UPDATE DMT_AP_PAY_TERM_HDR_STG_TBL
                    SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                    WHERE  STG_SEQUENCE_ID = r.STG_SEQUENCE_ID;

                    l_hdr_failed := l_hdr_failed + 1;
                    DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                        'Term FAILED (exception): ' || r.NAME,
                        l_errmsg, C_PKG, C_PROC);
            END;
        END LOOP;

        COMMIT;

        -- ========================================
        -- Phase 2: Create Installment Lines
        -- Only for headers that LOADED successfully.
        -- ========================================
        FOR r IN (
            SELECT ln.TFM_SEQUENCE_ID, ln.STG_SEQUENCE_ID,
                   ln.SOURCE_GROUP_ID, ln.SEQUENCE_NUM,
                   ln.DUE_PERCENT, ln.DUE_AMOUNT, ln.DUE_DAYS, ln.DUE_DATE,
                   ln.DISCOUNT_PERCENT, ln.DISCOUNT_DAYS,
                   ln.DISCOUNT_PERCENT_2, ln.DISCOUNT_DAYS_2
            FROM   DMT_AP_PAY_TERM_LINE_TFM_TBL ln
            WHERE  ln.RUN_ID = p_run_id
            AND    ln.TFM_STATUS = 'GENERATED'
            AND    EXISTS (
                SELECT 1 FROM DMT_AP_PAY_TERM_HDR_TFM_TBL h
                WHERE  h.RUN_ID  = p_run_id
                AND    h.SOURCE_GROUP_ID  = ln.SOURCE_GROUP_ID
                AND    h.TFM_STATUS       = 'LOADED'
            )
            ORDER BY ln.SOURCE_GROUP_ID, ln.SEQUENCE_NUM
        ) LOOP
            BEGIN
                -- Look up TermId from map
                IF NOT l_term_map.EXISTS(r.SOURCE_GROUP_ID) THEN
                    l_errmsg := 'No TermId mapping found for SOURCE_GROUP_ID=' || r.SOURCE_GROUP_ID;
                    UPDATE DMT_AP_PAY_TERM_LINE_TFM_TBL
                    SET    TFM_STATUS = 'FAILED',
                           ERROR_TEXT = '[FUSION_ERROR] ' || l_errmsg,
                           RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    UPDATE DMT_AP_PAY_TERM_LINE_STG_TBL
                    SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                    WHERE  STG_SEQUENCE_ID = r.STG_SEQUENCE_ID;

                    l_line_failed := l_line_failed + 1;
                    CONTINUE;
                END IF;

                l_term_id := l_term_map(r.SOURCE_GROUP_ID);

                l_payload := '{"SequenceNumber":' || NVL(TO_CHAR(r.SEQUENCE_NUM), '1')
                    || CASE WHEN r.DUE_PERCENT IS NOT NULL
                       THEN ',"DuePercent":' || TO_CHAR(r.DUE_PERCENT)
                       END
                    || CASE WHEN r.DUE_AMOUNT IS NOT NULL
                       THEN ',"DueAmount":' || TO_CHAR(r.DUE_AMOUNT)
                       END
                    || CASE WHEN r.DUE_DAYS IS NOT NULL
                       THEN ',"DueDays":' || TO_CHAR(r.DUE_DAYS)
                       END
                    || CASE WHEN r.DUE_DATE IS NOT NULL
                       THEN ',"DueDate":"' || TO_CHAR(r.DUE_DATE, 'YYYY-MM-DD') || '"'
                       END
                    || CASE WHEN r.DISCOUNT_PERCENT IS NOT NULL
                       THEN ',"DiscountPercent":' || TO_CHAR(r.DISCOUNT_PERCENT)
                       END
                    || CASE WHEN r.DISCOUNT_DAYS IS NOT NULL
                       THEN ',"DiscountDays":' || TO_CHAR(r.DISCOUNT_DAYS)
                       END
                    || CASE WHEN r.DISCOUNT_PERCENT_2 IS NOT NULL
                       THEN ',"DiscountPercent2":' || TO_CHAR(r.DISCOUNT_PERCENT_2)
                       END
                    || CASE WHEN r.DISCOUNT_DAYS_2 IS NOT NULL
                       THEN ',"DiscountDays2":' || TO_CHAR(r.DISCOUNT_DAYS_2)
                       END
                    || '}';

                l_response := rest_call('POST',
                    C_TERMS_PATH || '/' || TO_CHAR(l_term_id) || '/child/installments',
                    l_payload, p_run_id);
                l_http_status := get_status(l_response);

                IF l_http_status IN (200, 201) THEN
                    UPDATE DMT_AP_PAY_TERM_LINE_TFM_TBL
                    SET    TFM_STATUS = 'LOADED', RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    UPDATE DMT_AP_PAY_TERM_LINE_STG_TBL
                    SET    STG_STATUS = 'LOADED', LAST_UPDATED_DATE = SYSDATE
                    WHERE  STG_SEQUENCE_ID = r.STG_SEQUENCE_ID;

                    l_line_loaded := l_line_loaded + 1;
                ELSE
                    l_body := DBMS_LOB.SUBSTR(l_response, 1000, INSTR(l_response, '|') + 1);
                    UPDATE DMT_AP_PAY_TERM_LINE_TFM_TBL
                    SET    TFM_STATUS = 'FAILED',
                           ERROR_TEXT = '[FUSION_ERROR] HTTP ' || l_http_status || ': '
                                        || SUBSTR(l_body, 1, 2000),
                           RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    UPDATE DMT_AP_PAY_TERM_LINE_STG_TBL
                    SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                    WHERE  STG_SEQUENCE_ID = r.STG_SEQUENCE_ID;

                    l_line_failed := l_line_failed + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Line FAILED: GRP=' || r.SOURCE_GROUP_ID || ' SEQ=' || r.SEQUENCE_NUM
                        || ' HTTP ' || l_http_status,
                        C_PKG, C_PROC, 'WARN');
                END IF;

                IF DBMS_LOB.ISTEMPORARY(l_response) = 1 THEN
                    DBMS_LOB.FREETEMPORARY(l_response);
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    l_errmsg := SQLERRM;
                    UPDATE DMT_AP_PAY_TERM_LINE_TFM_TBL
                    SET    TFM_STATUS = 'FAILED',
                           ERROR_TEXT = '[FUSION_ERROR] ' || l_errmsg,
                           RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = r.TFM_SEQUENCE_ID;

                    UPDATE DMT_AP_PAY_TERM_LINE_STG_TBL
                    SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                    WHERE  STG_SEQUENCE_ID = r.STG_SEQUENCE_ID;

                    l_line_failed := l_line_failed + 1;
                    DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                        'Line FAILED (exception): GRP=' || r.SOURCE_GROUP_ID
                        || ' SEQ=' || r.SEQUENCE_NUM,
                        l_errmsg, C_PKG, C_PROC);
            END;
        END LOOP;

        -- Mark orphan lines (parent header FAILED) as FAILED too
        UPDATE DMT_AP_PAY_TERM_LINE_TFM_TBL
        SET    TFM_STATUS = 'FAILED',
               ERROR_TEXT = NVL(ERROR_TEXT, '') || '[FUSION_ERROR] Parent payment term header was not loaded.',
               RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'GENERATED'
        AND    NOT EXISTS (
            SELECT 1 FROM DMT_AP_PAY_TERM_HDR_TFM_TBL h
            WHERE  h.RUN_ID  = p_run_id
            AND    h.SOURCE_GROUP_ID  = DMT_AP_PAY_TERM_LINE_TFM_TBL.SOURCE_GROUP_ID
            AND    h.TFM_STATUS       = 'LOADED'
        );

        -- Echo orphan failures to STG
        UPDATE DMT_AP_PAY_TERM_LINE_STG_TBL
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (
            SELECT STG_SEQUENCE_ID FROM DMT_AP_PAY_TERM_LINE_TFM_TBL
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'FAILED'
        )
        AND    STG_STATUS != 'FAILED';

        COMMIT;

        DMT_UTIL_PKG.LOG(p_run_id,
            'LOAD_AND_RECONCILE complete. Headers: ' || l_hdr_loaded || ' LOADED, '
            || l_hdr_failed || ' FAILED | Lines: ' || l_line_loaded || ' LOADED, '
            || l_line_failed || ' FAILED',
            C_PKG, C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'LOAD_AND_RECONCILE failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END LOAD_AND_RECONCILE;

END DMT_AP_PAY_TERM_RESULTS_PKG;
/
