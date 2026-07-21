-- PACKAGE BODY DMT_PLAN_BUDGET_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_PLAN_BUDGET_RESULTS_PKG" AS
    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_PLAN_BUDGET_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'PlanningBudgets';

    FUNCTION bip_soap_post (p_url IN VARCHAR2, p_action IN VARCHAR2, p_body IN CLOB) RETURN CLOB IS
        l_req UTL_HTTP.REQ; l_resp UTL_HTTP.RESP; l_response CLOB; l_chunk VARCHAR2(32767);
        l_offset INTEGER := 1; l_amount INTEGER; l_body_len INTEGER;
    BEGIN
        UTL_HTTP.SET_RESPONSE_ERROR_CHECK(FALSE); UTL_HTTP.SET_TRANSFER_TIMEOUT(600);
        l_req := UTL_HTTP.BEGIN_REQUEST(p_url, 'POST', 'HTTP/1.1');
        UTL_HTTP.SET_HEADER(l_req, 'Content-Type', 'text/xml; charset=utf-8');
        UTL_HTTP.SET_HEADER(l_req, 'Content-Length', DBMS_LOB.GETLENGTH(p_body));
        UTL_HTTP.SET_HEADER(l_req, 'SOAPAction', '"' || p_action || '"');
        UTL_HTTP.SET_HEADER(l_req, 'Accept', 'text/xml');
        l_body_len := DBMS_LOB.GETLENGTH(p_body);
        WHILE l_offset <= l_body_len LOOP
            l_amount := LEAST(8000, l_body_len - l_offset + 1);
            l_chunk := DBMS_LOB.SUBSTR(p_body, l_amount, l_offset);
            UTL_HTTP.WRITE_TEXT(l_req, l_chunk); l_offset := l_offset + l_amount;
        END LOOP;
        l_resp := UTL_HTTP.GET_RESPONSE(l_req);
        DBMS_LOB.CREATETEMPORARY(l_response, TRUE);
        BEGIN LOOP UTL_HTTP.READ_TEXT(l_resp, l_chunk, 32767); DBMS_LOB.APPEND(l_response, l_chunk); END LOOP;
        EXCEPTION WHEN UTL_HTTP.END_OF_BODY THEN NULL; END;
        UTL_HTTP.END_RESPONSE(l_resp);
        IF l_resp.status_code NOT BETWEEN 200 AND 299 THEN
            RAISE_APPLICATION_ERROR(-20030, 'BIP SOAP failed. Status: ' || l_resp.status_code);
        END IF;
        RETURN l_response;
    EXCEPTION WHEN OTHERS THEN BEGIN UTL_HTTP.END_RESPONSE(l_resp); EXCEPTION WHEN OTHERS THEN NULL; END; RAISE;
    END bip_soap_post;

    FUNCTION b64_to_clob(p_b64 IN VARCHAR2) RETURN CLOB IS
        l_raw RAW(32767); l_blob BLOB; l_clob CLOB;
        l_dest_off INTEGER := 1; l_src_off INTEGER := 1; l_lang_ctx INTEGER := DBMS_LOB.DEFAULT_LANG_CTX; l_warning INTEGER;
    BEGIN
        l_raw := UTL_ENCODE.BASE64_DECODE(UTL_RAW.CAST_TO_RAW(p_b64));
        DBMS_LOB.CREATETEMPORARY(l_blob, TRUE); DBMS_LOB.WRITEAPPEND(l_blob, UTL_RAW.LENGTH(l_raw), l_raw);
        DBMS_LOB.CREATETEMPORARY(l_clob, TRUE);
        DBMS_LOB.CONVERTTOCLOB(l_clob, l_blob, DBMS_LOB.LOBMAXSIZE, l_dest_off, l_src_off, DBMS_LOB.DEFAULT_CSID, l_lang_ctx, l_warning);
        DBMS_LOB.FREETEMPORARY(l_blob); RETURN l_clob;
    END b64_to_clob;

    FUNCTION FETCH_BIP_RESULTS (p_run_id IN NUMBER, p_load_ess_id IN NUMBER, p_import_ess_id IN NUMBER DEFAULT NULL) RETURN CLOB IS
        l_base_url VARCHAR2(500); l_username VARCHAR2(100); l_password VARCHAR2(100);
        l_rpt_path VARCHAR2(500); l_env CLOB; l_resp CLOB;
        l_action CONSTANT VARCHAR2(200) := 'http://xmlns.oracle.com/oxp/service/v2/ReportService/runReportRequest';
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, 'FETCH_BIP_RESULTS start. load_ess_id: ' || p_load_ess_id, C_PKG, 'FETCH_BIP_RESULTS');
        l_base_url := RTRIM(DMT_UTIL_PKG.GET_CONFIG('FUSION_URL'), '/');
        l_username := DMT_UTIL_PKG.GET_CONFIG('FUSION_USERNAME');
        l_password := DMT_UTIL_PKG.GET_CONFIG('FUSION_PASSWORD');
        SELECT REPORT_CATALOG_PATH INTO l_rpt_path FROM DMT_OWNER.DMT_BIP_REPORT_TBL WHERE CEMLI_CODE = C_CEMLI;
        DBMS_LOB.CREATETEMPORARY(l_env, TRUE);
        DBMS_LOB.APPEND(l_env, TO_CLOB(
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:v2="http://xmlns.oracle.com/oxp/service/v2">' ||
            '<soapenv:Header/><soapenv:Body><v2:runReport><v2:reportRequest>' ||
            '<v2:reportAbsolutePath>' || l_rpt_path || '</v2:reportAbsolutePath>' ||
            '<v2:attributeFormat>xml</v2:attributeFormat>' ||
            '<v2:parameterNameValues><v2:listOfParamNameValues><v2:item>' ||
            '<v2:name>P_BATCH_ID</v2:name><v2:values><v2:item>' || TO_CHAR(p_load_ess_id) || '</v2:item></v2:values>' ||
            '</v2:item></v2:listOfParamNameValues></v2:parameterNameValues>' ||
            '<v2:sizeOfDataChunkDownload>-1</v2:sizeOfDataChunkDownload>' ||
            '</v2:reportRequest><v2:userID>' || l_username || '</v2:userID><v2:password>' || l_password || '</v2:password>' ||
            '</v2:runReport></soapenv:Body></soapenv:Envelope>'));
        l_resp := bip_soap_post(l_base_url || '/xmlpserver/services/v2/ReportService', l_action, l_env);
        DBMS_LOB.FREETEMPORARY(l_env);
        RETURN l_resp;
    EXCEPTION WHEN OTHERS THEN DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'FETCH_BIP_RESULTS failed.', SQLERRM, C_PKG, 'FETCH_BIP_RESULTS'); RAISE;
    END FETCH_BIP_RESULTS;

    PROCEDURE PARSE_AND_UPDATE (p_run_id IN NUMBER, p_xml_data IN CLOB) IS
        l_report_b64 VARCHAR2(32767); l_b64_start INTEGER; l_b64_end INTEGER;
        l_report_xml CLOB; l_xml XMLTYPE; l_loaded NUMBER := 0; l_failed NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, 'PARSE_AND_UPDATE start.', C_PKG, 'PARSE_AND_UPDATE');
        l_b64_start := DBMS_LOB.INSTR(p_xml_data, '<reportBytes>');
        IF l_b64_start = 0 THEN RETURN; END IF;
        l_b64_start := l_b64_start + LENGTH('<reportBytes>');
        l_b64_end := DBMS_LOB.INSTR(p_xml_data, '</reportBytes>', l_b64_start);
        l_report_b64 := DBMS_LOB.SUBSTR(p_xml_data, LEAST(32767, l_b64_end - l_b64_start), l_b64_start);
        l_report_xml := b64_to_clob(l_report_b64);
        l_xml := XMLTYPE(l_report_xml);
        DBMS_LOB.FREETEMPORARY(l_report_xml);

        FOR r IN (
            SELECT x.scenario, UPPER(x.import_status) AS import_status, x.error_msg
            FROM XMLTABLE('/DATA_DS/G_1' PASSING l_xml COLUMNS
                scenario    VARCHAR2(100)  PATH 'SCENARIO',
                import_status VARCHAR2(50)   PATH 'IMPORT_STATUS',
                error_msg     VARCHAR2(4000) PATH 'ERROR_MESSAGE') x
        ) LOOP
            IF r.import_status IN ('Y','PROCESSED','SUCCESS','COMPLETED') THEN
                UPDATE DMT_OWNER.DMT_PLAN_BUDGET_TFM_TBL SET TFM_STATUS='LOADED', RESULTS_UPDATED_DATE=SYSDATE, LAST_UPDATED_DATE=SYSDATE
                WHERE RUN_ID=p_run_id AND SCENARIO=r.scenario AND TFM_STATUS!='LOADED';
                l_loaded := l_loaded + SQL%ROWCOUNT;
            ELSIF r.error_msg IS NOT NULL THEN
                -- Real Fusion error returned — mark FAILED carrying it.
                UPDATE DMT_OWNER.DMT_PLAN_BUDGET_TFM_TBL SET TFM_STATUS='FAILED',
                    ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,'[FUSION_ERROR] '||r.error_msg),
                    RESULTS_UPDATED_DATE=SYSDATE, LAST_UPDATED_DATE=SYSDATE
                WHERE RUN_ID=p_run_id AND SCENARIO=r.scenario AND TFM_STATUS!='FAILED';
                l_failed := l_failed + SQL%ROWCOUNT;
            -- Non-success status but no real Fusion error message: do NOT write a
            -- bare '[FUSION_ERROR]' with no detail. Leave the row GENERATED for the
            -- honest sweep to mark UNACCOUNTED.
            END IF;
        END LOOP;

        -- Absence = LOADED: rows not returned by BIP (not in error) are considered LOADED
        IF l_loaded = 0 AND l_failed = 0 THEN
            UPDATE DMT_OWNER.DMT_PLAN_BUDGET_TFM_TBL SET TFM_STATUS='LOADED', RESULTS_UPDATED_DATE=SYSDATE, LAST_UPDATED_DATE=SYSDATE
            WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED';
            l_loaded := SQL%ROWCOUNT;
        END IF;

        UPDATE DMT_OWNER.DMT_PLAN_BUDGET_STG_TBL SET STG_STATUS='LOADED', LAST_UPDATED_DATE=SYSDATE
        WHERE STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_OWNER.DMT_PLAN_BUDGET_TFM_TBL WHERE RUN_ID=p_run_id AND TFM_STATUS='LOADED');
        UPDATE DMT_OWNER.DMT_PLAN_BUDGET_STG_TBL SET STG_STATUS='FAILED', LAST_UPDATED_DATE=SYSDATE
        WHERE STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_OWNER.DMT_PLAN_BUDGET_TFM_TBL WHERE RUN_ID=p_run_id AND TFM_STATUS='FAILED');
        -- NO COMMIT — orchestrator controls transaction boundaries
        DMT_UTIL_PKG.LOG(p_run_id, 'PARSE_AND_UPDATE complete. LOADED: '||l_loaded||', FAILED: '||l_failed, C_PKG, 'PARSE_AND_UPDATE');
    EXCEPTION WHEN OTHERS THEN DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'PARSE_AND_UPDATE failed.', SQLERRM, C_PKG, 'PARSE_AND_UPDATE'); RAISE;
    END PARSE_AND_UPDATE;

    PROCEDURE RECONCILE_BATCH (p_run_id IN NUMBER, p_load_ess_id IN NUMBER, p_import_ess_id IN NUMBER DEFAULT NULL) IS
        l_xml CLOB;
    BEGIN
        l_xml := FETCH_BIP_RESULTS(p_run_id, p_load_ess_id);
        PARSE_AND_UPDATE(p_run_id, l_xml);
        IF l_xml IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_xml) = 1 THEN DBMS_LOB.FREETEMPORARY(l_xml); END IF;
    EXCEPTION WHEN OTHERS THEN DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'RECONCILE_BATCH failed.', SQLERRM, C_PKG, 'RECONCILE_BATCH'); RAISE;
    END RECONCILE_BATCH;

END DMT_PLAN_BUDGET_RESULTS_PKG;
/
