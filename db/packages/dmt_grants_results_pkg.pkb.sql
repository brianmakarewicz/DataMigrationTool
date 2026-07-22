-- PACKAGE BODY DMT_GRANTS_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_GRANTS_RESULTS_PKG" 
AS
-- ============================================================
-- DMT_GRANTS_RESULTS_PKG body
-- Grants BIP reconciliation.
-- Pattern: identical to DMT_PROJECT_RESULTS_PKG.
-- Cascade: headers TFM -> all 14 child TFM tables via AWARD_NUMBER.
-- Echo back to all 15 STG tables.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_GRANTS_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'Grants';

    -- --------------------------------------------------------
    -- Private: POST a SOAP envelope; return full response CLOB.
    -- --------------------------------------------------------
    FUNCTION bip_soap_post (
        p_url      IN VARCHAR2,
        p_action   IN VARCHAR2,
        p_body     IN CLOB
    ) RETURN CLOB IS
        l_req      UTL_HTTP.REQ;
        l_resp     UTL_HTTP.RESP;
        l_response CLOB;
        l_chunk    VARCHAR2(32767);
        l_offset   INTEGER := 1;
        l_amount   INTEGER;
        l_body_len INTEGER;
    BEGIN
        UTL_HTTP.SET_RESPONSE_ERROR_CHECK(FALSE);
        UTL_HTTP.SET_TRANSFER_TIMEOUT(600);

        l_req := UTL_HTTP.BEGIN_REQUEST(p_url, 'POST', 'HTTP/1.1');
        UTL_HTTP.SET_HEADER(l_req, 'Content-Type',   'text/xml; charset=utf-8');
        UTL_HTTP.SET_HEADER(l_req, 'Content-Length', DBMS_LOB.GETLENGTH(p_body));
        UTL_HTTP.SET_HEADER(l_req, 'SOAPAction',     '"' || p_action || '"');
        UTL_HTTP.SET_HEADER(l_req, 'Accept',         'text/xml');

        l_body_len := DBMS_LOB.GETLENGTH(p_body);
        WHILE l_offset <= l_body_len LOOP
            l_amount := LEAST(8000, l_body_len - l_offset + 1);
            l_chunk  := DBMS_LOB.SUBSTR(p_body, l_amount, l_offset);
            UTL_HTTP.WRITE_TEXT(l_req, l_chunk);
            l_offset := l_offset + l_amount;
        END LOOP;

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
            RAISE_APPLICATION_ERROR(-20030,
                'BIP SOAP call failed. Status: ' || l_resp.status_code ||
                ' | Action: ' || p_action ||
                ' | Response (first 500): ' || DBMS_LOB.SUBSTR(l_response, 500, 1));
        END IF;

        RETURN l_response;
    EXCEPTION
        WHEN OTHERS THEN
            BEGIN UTL_HTTP.END_RESPONSE(l_resp); EXCEPTION WHEN OTHERS THEN NULL; END;
            RAISE;
    END bip_soap_post;

    -- (b64_to_clob removed — base64 decode is now centralised in
    --  DMT_UTIL_PKG.BASE64_DECODE_CLOB / BIP_REPORT_XML, which decode CLOBs of
    --  any size. The old local copy truncated at VARCHAR2(32767).)

    -- --------------------------------------------------------
    -- FETCH_BIP_RESULTS
    -- --------------------------------------------------------
    FUNCTION FETCH_BIP_RESULTS (
        p_run_id  IN NUMBER,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL
    ) RETURN CLOB IS
        C_PROC       CONSTANT VARCHAR2(30) := 'FETCH_BIP_RESULTS';
        l_base_url   VARCHAR2(500);
        l_username   VARCHAR2(100);
        l_password   VARCHAR2(100);
        l_rpt_path   VARCHAR2(500);
        l_url        VARCHAR2(500);
        l_action     CONSTANT VARCHAR2(200) :=
            'http://xmlns.oracle.com/oxp/service/v2/ReportService/runReportRequest';
        l_env        CLOB;
        l_resp       CLOB;
        l_import_str VARCHAR2(30) := NVL(TO_CHAR(p_import_ess_id), '');
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' start. CEMLI: ' || C_CEMLI || ' | load_ess_id: ' || p_load_ess_id ||
            ' | import_ess_id: ' || NVL(TO_CHAR(p_import_ess_id), 'NULL'),
            C_PKG, C_PROC);

        l_base_url := RTRIM(DMT_UTIL_PKG.GET_CONFIG('FUSION_URL'), '/');
        l_username := DMT_UTIL_PKG.GET_CONFIG('FUSION_USERNAME');
        l_password := DMT_UTIL_PKG.GET_CONFIG('FUSION_PASSWORD');

        IF l_base_url IS NULL OR l_username IS NULL OR l_password IS NULL THEN
            RAISE_APPLICATION_ERROR(-20031,
                C_PROC || ': Fusion connection config is incomplete.');
        END IF;

        BEGIN
            SELECT REPORT_CATALOG_PATH INTO l_rpt_path
            FROM   DMT_OWNER.DMT_BIP_REPORT_TBL
            WHERE  CEMLI_CODE = C_CEMLI;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20032,
                    C_PROC || ': No row in DMT_BIP_REPORT_TBL for CEMLI_CODE = ''' || C_CEMLI || '''.');
        END;

        l_url := l_base_url || '/xmlpserver/services/v2/ReportService';

        DBMS_LOB.CREATETEMPORARY(l_env, TRUE);
        DBMS_LOB.APPEND(l_env, TO_CLOB(
            '<soapenv:Envelope' ||
            ' xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"' ||
            ' xmlns:v2="http://xmlns.oracle.com/oxp/service/v2">' ||
            '  <soapenv:Header/>' ||
            '  <soapenv:Body>' ||
            '    <v2:runReport>' ||
            '      <v2:reportRequest>' ||
            '        <v2:reportAbsolutePath>' || l_rpt_path || '</v2:reportAbsolutePath>' ||
            '        <v2:attributeFormat>xml</v2:attributeFormat>' ||
            '        <v2:parameterNameValues>' ||
            '          <v2:listOfParamNameValues>' ||
            '            <v2:item>' ||
            '              <v2:name>P_BATCH_ID</v2:name>' ||
            '              <v2:values><v2:item>' || TO_CHAR(p_load_ess_id) || '</v2:item></v2:values>' ||
            '            </v2:item>' ||
            '            <v2:item>' ||
            '              <v2:name>P_IMPORT_ESS_ID</v2:name>' ||
            '              <v2:values><v2:item>' || l_import_str || '</v2:item></v2:values>' ||
            '            </v2:item>' ||
            '          </v2:listOfParamNameValues>' ||
            '        </v2:parameterNameValues>' ||
            '        <v2:sizeOfDataChunkDownload>-1</v2:sizeOfDataChunkDownload>' ||
            '      </v2:reportRequest>' ||
            '      <v2:userID>' || l_username || '</v2:userID>' ||
            '      <v2:password>' || l_password || '</v2:password>' ||
            '    </v2:runReport>' ||
            '  </soapenv:Body>' ||
            '</soapenv:Envelope>'));

        l_resp := bip_soap_post(l_url, l_action, l_env);
        DBMS_LOB.FREETEMPORARY(l_env);

        IF DBMS_LOB.INSTR(l_resp, 'soapenv:Fault') > 0 OR
           DBMS_LOB.INSTR(l_resp, 'soap:Fault')    > 0 THEN
            RAISE_APPLICATION_ERROR(-20034,
                C_PROC || ': SOAP Fault from BIP runReport. Response (first 1000): ' || DBMS_LOB.SUBSTR(l_resp, 1000, 1));
        END IF;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. Response bytes: ' || DBMS_LOB.GETLENGTH(l_resp),
            C_PKG, C_PROC);

        RETURN l_resp;
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, C_PROC || ' failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END FETCH_BIP_RESULTS;

    -- --------------------------------------------------------
    -- find_report_ess_id
    -- Resolve the child Award Batch Import Report ESS request
    -- (ImportAwardReportJob) that Fusion spawns alongside the
    -- AwardMassImportJob. The report holds the per-award rejection
    -- messages that survive the interface-table purge.
    --
    -- Mirrors DMT_BILLING_EVENT_RESULTS_PKG.find_report_ess_id:
    -- first look for a child already captured in DMT_ESS_JOB_TBL
    -- (PARENT_REQUEST_ID = the import ESS id, a REPORT job), then
    -- fall back to capturing it now via CAPTURE_REPORT_ESS_JOB (which
    -- needs REPORT_JOB_DEF seeded for 'Grants'). Non-blocking: any
    -- failure logs a WARN and returns NULL.
    -- --------------------------------------------------------
    FUNCTION find_report_ess_id (
        p_run_id        IN NUMBER,
        p_import_ess_id IN NUMBER
    ) RETURN NUMBER IS
        C_PROC   CONSTANT VARCHAR2(30) := 'find_report_ess_id';
        l_result NUMBER;
    BEGIN
        -- Already captured in the ESS hierarchy?
        BEGIN
            SELECT REQUEST_ID INTO l_result
            FROM   DMT_OWNER.DMT_ESS_JOB_TBL
            WHERE  PARENT_REQUEST_ID = p_import_ess_id
            AND    UPPER(JOB_DEFINITION) LIKE '%REPORT%'
            FETCH FIRST 1 ROW ONLY;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_result := NULL;
        END;

        IF l_result IS NOT NULL THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': Found report ESS ' || l_result ||
                ' in hierarchy (child of import ' || p_import_ess_id || ').',
                C_PKG, C_PROC);
            RETURN l_result;
        END IF;

        -- Not captured yet — capture it now (needs REPORT_JOB_DEF seeded).
        l_result := DMT_ESS_UTIL_PKG.CAPTURE_REPORT_ESS_JOB(
            p_run_id        => p_run_id,
            p_import_ess_id => p_import_ess_id,
            p_cemli_code    => C_CEMLI);

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ': Report ESS id = ' || NVL(TO_CHAR(l_result), 'NULL') ||
            ' (captured from import ESS ' || p_import_ess_id || ').',
            C_PKG, C_PROC);

        RETURN l_result;
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': Failed to find Report child ESS: ' || SQLERRM,
                C_PKG, C_PROC);
            RETURN NULL;
    END find_report_ess_id;

    -- --------------------------------------------------------
    -- apply_award_import_report
    -- Read the Award Batch Import Report XML and mark each rejected
    -- award FAILED with its REAL Fusion message.
    --
    -- The report's per-award failure rows live in LIST_G_4/G_4:
    --   PARENT_AWARD_NUMBER -> the award number (TFM key)
    --   PROCESSED_MESSAGE   -> the real Fusion rejection message
    -- This is a FAILURE-ONLY list (the report runs with
    -- REPORT_SUCCESS_RECORDS=N), so every G_4 row is a real rejection.
    -- We only ever transition GENERATED -> FAILED here, and only when
    -- PROCESSED_MESSAGE is non-empty (never fabricate an error). Awards
    -- absent from the list are left untouched (base tier may have set
    -- them LOADED; otherwise they stay GENERATED for the honest sweep).
    --
    -- Returns the count of TFM rows marked FAILED.
    -- --------------------------------------------------------
    FUNCTION apply_award_import_report (
        p_run_id        IN NUMBER,
        p_import_ess_id IN NUMBER
    ) RETURN NUMBER IS
        C_PROC          CONSTANT VARCHAR2(30) := 'apply_award_import_report';
        l_report_ess_id NUMBER;
        l_xml_clob      CLOB;
        l_xml           XMLTYPE;
        l_matched       NUMBER := 0;
    BEGIN
        IF p_import_ess_id IS NULL THEN
            RETURN 0;
        END IF;

        l_report_ess_id := find_report_ess_id(p_run_id, p_import_ess_id);
        IF l_report_ess_id IS NULL THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': No Award Batch Import Report child found for import ESS ' ||
                p_import_ess_id || '. Nothing to attribute from the report.',
                C_PKG, C_PROC);
            RETURN 0;
        END IF;

        BEGIN
            l_xml_clob := DMT_ESS_UTIL_PKG.GET_ESS_OUTPUT_XML(l_report_ess_id);
        EXCEPTION
            WHEN OTHERS THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    C_PROC || ': Failed to download report XML from ESS ' ||
                    l_report_ess_id || ': ' || SQLERRM,
                    C_PKG, C_PROC);
                RETURN 0;
        END;

        IF l_xml_clob IS NULL OR DBMS_LOB.GETLENGTH(l_xml_clob) = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': Report ESS ' || l_report_ess_id || ' returned empty output.',
                C_PKG, C_PROC);
            RETURN 0;
        END IF;

        BEGIN
            l_xml := XMLTYPE(l_xml_clob);
        EXCEPTION
            WHEN OTHERS THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    C_PROC || ': Report output for ESS ' || l_report_ess_id ||
                    ' is not valid XML: ' || SQLERRM,
                    C_PKG, C_PROC);
                IF DBMS_LOB.ISTEMPORARY(l_xml_clob) = 1 THEN
                    DBMS_LOB.FREETEMPORARY(l_xml_clob);
                END IF;
                RETURN 0;
        END;

        -- Attribute each rejected award to its TFM row with the real message.
        FOR r IN (
            SELECT x.award_number,
                   x.processed_message
            FROM   XMLTABLE('/DATA_DS/LIST_G_4/G_4' PASSING l_xml
                COLUMNS
                    award_number      VARCHAR2(300)  PATH 'PARENT_AWARD_NUMBER',
                    processed_message VARCHAR2(4000) PATH 'PROCESSED_MESSAGE'
            ) x
            WHERE  x.award_number IS NOT NULL
            AND    x.processed_message IS NOT NULL
        ) LOOP
            UPDATE DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL
            SET    TFM_STATUS = 'FAILED',
                   ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                       '[FUSION_ERROR] ' || r.processed_message),
                   RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
            WHERE  RUN_ID = p_run_id AND AWARD_NUMBER = r.award_number
            AND    TFM_STATUS NOT IN ('LOADED','FAILED');
            l_matched := l_matched + SQL%ROWCOUNT;
        END LOOP;

        IF DBMS_LOB.ISTEMPORARY(l_xml_clob) = 1 THEN
            DBMS_LOB.FREETEMPORARY(l_xml_clob);
        END IF;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ': Award Batch Import Report (ESS ' || l_report_ess_id ||
            ') parsed; ' || l_matched || ' award(s) marked FAILED with a real Fusion message.',
            C_PKG, C_PROC);

        RETURN l_matched;
    EXCEPTION
        WHEN OTHERS THEN
            -- Never abort reconciliation on a report-read problem: log and
            -- return what we matched. Unmatched rows stay GENERATED (honest).
            BEGIN
                IF l_xml_clob IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_xml_clob) = 1 THEN
                    DBMS_LOB.FREETEMPORARY(l_xml_clob);
                END IF;
            EXCEPTION WHEN OTHERS THEN NULL;
            END;
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': report parse/apply failed (' || SQLERRM ||
                '); ' || l_matched || ' rows matched before the error.',
                C_PKG, C_PROC);
            RETURN l_matched;
    END apply_award_import_report;

    -- --------------------------------------------------------
    -- PARSE_AND_UPDATE
    -- --------------------------------------------------------
    PROCEDURE PARSE_AND_UPDATE (
        p_run_id IN NUMBER,
        p_xml_data       IN CLOB,
        p_import_ess_id  IN NUMBER DEFAULT NULL
    ) IS
        C_PROC       CONSTANT VARCHAR2(30) := 'PARSE_AND_UPDATE';
        l_xml        XMLTYPE;
        l_loaded     NUMBER := 0;
        l_failed     NUMBER := 0;

        -- Child TFM table names for cascade
        TYPE t_child_tbl IS RECORD (
            tbl_name VARCHAR2(60)
        );
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, C_PROC || ' start.', C_PKG, C_PROC);

        -- Decode the BIP report via the shared helper (handles any size, no
        -- VARCHAR2(32767) truncation). Returns NULL when there are no rows.
        l_xml := DMT_UTIL_PKG.BIP_REPORT_XML(p_xml_data);
        IF l_xml IS NULL THEN
            -- No reportBytes = 0 rows from both interface and base tables. This
            -- is the expected shape after a successful AwardMassImportJob:
            -- Fusion PURGES the award interface/error tables right after import,
            -- so the base+interface BIP report is empty. An empty interface read
            -- is NOT "absent" — the per-award rejection messages survive only in
            -- Fusion's own Award Batch Import Report. Read THAT before giving up.
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': No <reportBytes> in BIP response (interface purged). '
                || 'Reading the Award Batch Import Report for per-award errors.',
                C_PKG, C_PROC);

            l_failed := apply_award_import_report(p_run_id, p_import_ess_id);

            -- Cascade any FAILED award to its 14 child TFM tables + echo to STG,
            -- then finish. Awards with neither a base-table LOADED nor a real
            -- report error stay GENERATED (honest unaccounted) — never fabricated.
            GOTO cascade_and_echo;
        END IF;

        -- Process header rows from BIP XML — two-tier reconciliation
        FOR r IN (
            SELECT x.award_id,
                   x.award_name,
                   x.award_number,
                   UPPER(x.source_type)   AS source_type,
                   UPPER(x.fusion_status) AS fusion_status,
                   x.fusion_id,
                   x.error_msg
            FROM   XMLTABLE('/DATA_DS/G_1' PASSING l_xml
                COLUMNS
                    award_id        NUMBER         PATH 'AWARD_ID',
                    award_name      VARCHAR2(300)  PATH 'AWARD_NAME',
                    award_number    VARCHAR2(300)  PATH 'AWARD_NUMBER',
                    source_type     VARCHAR2(20)   PATH 'SOURCE_TYPE',
                    fusion_status   VARCHAR2(50)   PATH 'FUSION_STATUS',
                    fusion_id       NUMBER         PATH 'FUSION_ID',
                    error_msg       VARCHAR2(4000) PATH 'ERROR_MESSAGE'
            ) x
        ) LOOP
            IF r.source_type = 'BASE' THEN
                -- Tier 2: Found in base table = positively LOADED
                UPDATE DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL
                SET    TFM_STATUS = 'LOADED', FUSION_AWARD_ID = r.fusion_id,
                       RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                WHERE  RUN_ID = p_run_id AND AWARD_NUMBER = r.award_number
                AND    TFM_STATUS NOT IN ('LOADED','FAILED');
                l_loaded := l_loaded + SQL%ROWCOUNT;
            ELSIF r.source_type = 'INTERFACE' THEN
                IF r.fusion_status IN ('COMPLETED','IMPORTED','Y','PROCESSED','SUCCESS','P') THEN
                    UPDATE DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL
                    SET    TFM_STATUS = 'LOADED', FUSION_AWARD_ID = r.fusion_id,
                           RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                    WHERE  RUN_ID = p_run_id AND AWARD_NUMBER = r.award_number
                    AND    TFM_STATUS NOT IN ('LOADED','FAILED');
                    l_loaded := l_loaded + SQL%ROWCOUNT;
                ELSIF r.fusion_status IN ('ERROR','REJECTED','FAILED','FAILURE','N') THEN
                    -- Only mark FAILED when Fusion actually returned an error
                    -- message. When error_msg is NULL we have only a status label
                    -- (which we compose), not a real Fusion error, so we leave the
                    -- row GENERATED for the honest sweep to mark UNACCOUNTED.
                    IF r.error_msg IS NOT NULL THEN
                        UPDATE DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL
                        SET    TFM_STATUS = 'FAILED',
                               ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT, '[FUSION_ERROR] ' || r.error_msg),
                               RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                        WHERE  RUN_ID = p_run_id AND AWARD_NUMBER = r.award_number
                        AND    TFM_STATUS NOT IN ('LOADED','FAILED');
                        l_failed := l_failed + SQL%ROWCOUNT;
                    END IF;
                ELSE
                    -- Unrecognized interface status and no real Fusion error to
                    -- report. Do NOT compose a FAILED; leave the row GENERATED for
                    -- the honest sweep to mark UNACCOUNTED.
                    NULL;
                END IF;
            END IF;
        END LOOP;

        -- Award Batch Import Report pass: any award the base/interface BIP did
        -- not confirm LOADED and did not already fail gets its REAL Fusion
        -- rejection message from Fusion's own Award Batch Import Report (the
        -- errors that survive the interface-table purge). Only GENERATED rows
        -- with a non-empty PROCESSED_MESSAGE become FAILED — never fabricated.
        l_failed := l_failed + apply_award_import_report(p_run_id, p_import_ess_id);

        -- (No absence-!=-LOADED sweep: a record neither confirmed LOADED nor
        -- given a real Fusion error is left GENERATED (unaccounted). The
        -- accounting gate then reports the object not-DONE and the funnel
        -- surfaces it as UNRECONCILED — no fabricated FAILED.)

        <<cascade_and_echo>>
        -- Cascade LOADED to all 14 child TFM tables via AWARD_NUMBER
        UPDATE DMT_OWNER.DMT_GMS_AWD_FUNDING_TFM_TBL c
        SET c.TFM_STATUS='LOADED', c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE
        WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='LOADED'
        AND EXISTS (SELECT 1 FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='LOADED');

        UPDATE DMT_OWNER.DMT_GMS_AWD_PROJECTS_TFM_TBL c
        SET c.TFM_STATUS='LOADED', c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE
        WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='LOADED'
        AND EXISTS (SELECT 1 FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='LOADED');

        UPDATE DMT_OWNER.DMT_GMS_AWD_PERSONNEL_TFM_TBL c
        SET c.TFM_STATUS='LOADED', c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE
        WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='LOADED'
        AND EXISTS (SELECT 1 FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='LOADED');

        UPDATE DMT_OWNER.DMT_GMS_AWD_FUND_SRC_TFM_TBL c
        SET c.TFM_STATUS='LOADED', c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE
        WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='LOADED'
        AND EXISTS (SELECT 1 FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='LOADED');

        UPDATE DMT_OWNER.DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL c
        SET c.TFM_STATUS='LOADED', c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE
        WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='LOADED'
        AND EXISTS (SELECT 1 FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='LOADED');

        UPDATE DMT_OWNER.DMT_GMS_AWD_KEYWORDS_TFM_TBL c
        SET c.TFM_STATUS='LOADED', c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE
        WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='LOADED'
        AND EXISTS (SELECT 1 FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='LOADED');

        UPDATE DMT_OWNER.DMT_GMS_AWD_BDGT_PRDS_TFM_TBL c
        SET c.TFM_STATUS='LOADED', c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE
        WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='LOADED'
        AND EXISTS (SELECT 1 FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='LOADED');

        UPDATE DMT_OWNER.DMT_GMS_AWD_CERTS_TFM_TBL c
        SET c.TFM_STATUS='LOADED', c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE
        WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='LOADED'
        AND EXISTS (SELECT 1 FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='LOADED');

        UPDATE DMT_OWNER.DMT_GMS_AWD_CFDAS_TFM_TBL c
        SET c.TFM_STATUS='LOADED', c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE
        WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='LOADED'
        AND EXISTS (SELECT 1 FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='LOADED');

        UPDATE DMT_OWNER.DMT_GMS_AWD_FUND_ALLOC_TFM_TBL c
        SET c.TFM_STATUS='LOADED', c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE
        WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='LOADED'
        AND EXISTS (SELECT 1 FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='LOADED');

        UPDATE DMT_OWNER.DMT_GMS_AWD_ORG_CREDITS_TFM_TBL c
        SET c.TFM_STATUS='LOADED', c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE
        WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='LOADED'
        AND EXISTS (SELECT 1 FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='LOADED');

        UPDATE DMT_OWNER.DMT_GMS_AWD_PRJ_TSK_BRD_TFM_TBL c
        SET c.TFM_STATUS='LOADED', c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE
        WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='LOADED'
        AND EXISTS (SELECT 1 FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='LOADED');

        UPDATE DMT_OWNER.DMT_GMS_AWD_REFERENCES_TFM_TBL c
        SET c.TFM_STATUS='LOADED', c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE
        WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='LOADED'
        AND EXISTS (SELECT 1 FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='LOADED');

        UPDATE DMT_OWNER.DMT_GMS_AWD_TERMS_TFM_TBL c
        SET c.TFM_STATUS='LOADED', c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE
        WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='LOADED'
        AND EXISTS (SELECT 1 FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='LOADED');

        -- Cascade FAILED to all 14 child TFM tables. The parent award header
        -- only reaches FAILED with a real Fusion error, so each child carries
        -- that same real parent error in the prescribed linked-record form.
        UPDATE DMT_OWNER.DMT_GMS_AWD_FUNDING_TFM_TBL c SET c.TFM_STATUS='FAILED', c.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,'[FUSION_ERROR]The parent record has the following Fusion error: '||(SELECT h2.ERROR_TEXT FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h2 WHERE h2.RUN_ID=p_run_id AND h2.AWARD_NUMBER=c.AWARD_NUMBER AND h2.TFM_STATUS='FAILED' AND ROWNUM=1)), c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='FAILED' AND EXISTS (SELECT 1 FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='FAILED');
        UPDATE DMT_OWNER.DMT_GMS_AWD_PROJECTS_TFM_TBL c SET c.TFM_STATUS='FAILED', c.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,'[FUSION_ERROR]The parent record has the following Fusion error: '||(SELECT h2.ERROR_TEXT FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h2 WHERE h2.RUN_ID=p_run_id AND h2.AWARD_NUMBER=c.AWARD_NUMBER AND h2.TFM_STATUS='FAILED' AND ROWNUM=1)), c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='FAILED' AND EXISTS (SELECT 1 FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='FAILED');
        UPDATE DMT_OWNER.DMT_GMS_AWD_PERSONNEL_TFM_TBL c SET c.TFM_STATUS='FAILED', c.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,'[FUSION_ERROR]The parent record has the following Fusion error: '||(SELECT h2.ERROR_TEXT FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h2 WHERE h2.RUN_ID=p_run_id AND h2.AWARD_NUMBER=c.AWARD_NUMBER AND h2.TFM_STATUS='FAILED' AND ROWNUM=1)), c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='FAILED' AND EXISTS (SELECT 1 FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='FAILED');
        UPDATE DMT_OWNER.DMT_GMS_AWD_FUND_SRC_TFM_TBL c SET c.TFM_STATUS='FAILED', c.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,'[FUSION_ERROR]The parent record has the following Fusion error: '||(SELECT h2.ERROR_TEXT FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h2 WHERE h2.RUN_ID=p_run_id AND h2.AWARD_NUMBER=c.AWARD_NUMBER AND h2.TFM_STATUS='FAILED' AND ROWNUM=1)), c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='FAILED' AND EXISTS (SELECT 1 FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='FAILED');
        UPDATE DMT_OWNER.DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL c SET c.TFM_STATUS='FAILED', c.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,'[FUSION_ERROR]The parent record has the following Fusion error: '||(SELECT h2.ERROR_TEXT FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h2 WHERE h2.RUN_ID=p_run_id AND h2.AWARD_NUMBER=c.AWARD_NUMBER AND h2.TFM_STATUS='FAILED' AND ROWNUM=1)), c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='FAILED' AND EXISTS (SELECT 1 FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='FAILED');
        UPDATE DMT_OWNER.DMT_GMS_AWD_KEYWORDS_TFM_TBL c SET c.TFM_STATUS='FAILED', c.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,'[FUSION_ERROR]The parent record has the following Fusion error: '||(SELECT h2.ERROR_TEXT FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h2 WHERE h2.RUN_ID=p_run_id AND h2.AWARD_NUMBER=c.AWARD_NUMBER AND h2.TFM_STATUS='FAILED' AND ROWNUM=1)), c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='FAILED' AND EXISTS (SELECT 1 FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='FAILED');
        UPDATE DMT_OWNER.DMT_GMS_AWD_BDGT_PRDS_TFM_TBL c SET c.TFM_STATUS='FAILED', c.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,'[FUSION_ERROR]The parent record has the following Fusion error: '||(SELECT h2.ERROR_TEXT FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h2 WHERE h2.RUN_ID=p_run_id AND h2.AWARD_NUMBER=c.AWARD_NUMBER AND h2.TFM_STATUS='FAILED' AND ROWNUM=1)), c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='FAILED' AND EXISTS (SELECT 1 FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='FAILED');
        UPDATE DMT_OWNER.DMT_GMS_AWD_CERTS_TFM_TBL c SET c.TFM_STATUS='FAILED', c.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,'[FUSION_ERROR]The parent record has the following Fusion error: '||(SELECT h2.ERROR_TEXT FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h2 WHERE h2.RUN_ID=p_run_id AND h2.AWARD_NUMBER=c.AWARD_NUMBER AND h2.TFM_STATUS='FAILED' AND ROWNUM=1)), c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='FAILED' AND EXISTS (SELECT 1 FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='FAILED');
        UPDATE DMT_OWNER.DMT_GMS_AWD_CFDAS_TFM_TBL c SET c.TFM_STATUS='FAILED', c.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,'[FUSION_ERROR]The parent record has the following Fusion error: '||(SELECT h2.ERROR_TEXT FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h2 WHERE h2.RUN_ID=p_run_id AND h2.AWARD_NUMBER=c.AWARD_NUMBER AND h2.TFM_STATUS='FAILED' AND ROWNUM=1)), c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='FAILED' AND EXISTS (SELECT 1 FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='FAILED');
        UPDATE DMT_OWNER.DMT_GMS_AWD_FUND_ALLOC_TFM_TBL c SET c.TFM_STATUS='FAILED', c.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,'[FUSION_ERROR]The parent record has the following Fusion error: '||(SELECT h2.ERROR_TEXT FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h2 WHERE h2.RUN_ID=p_run_id AND h2.AWARD_NUMBER=c.AWARD_NUMBER AND h2.TFM_STATUS='FAILED' AND ROWNUM=1)), c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='FAILED' AND EXISTS (SELECT 1 FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='FAILED');
        UPDATE DMT_OWNER.DMT_GMS_AWD_ORG_CREDITS_TFM_TBL c SET c.TFM_STATUS='FAILED', c.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,'[FUSION_ERROR]The parent record has the following Fusion error: '||(SELECT h2.ERROR_TEXT FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h2 WHERE h2.RUN_ID=p_run_id AND h2.AWARD_NUMBER=c.AWARD_NUMBER AND h2.TFM_STATUS='FAILED' AND ROWNUM=1)), c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='FAILED' AND EXISTS (SELECT 1 FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='FAILED');
        UPDATE DMT_OWNER.DMT_GMS_AWD_PRJ_TSK_BRD_TFM_TBL c SET c.TFM_STATUS='FAILED', c.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,'[FUSION_ERROR]The parent record has the following Fusion error: '||(SELECT h2.ERROR_TEXT FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h2 WHERE h2.RUN_ID=p_run_id AND h2.AWARD_NUMBER=c.AWARD_NUMBER AND h2.TFM_STATUS='FAILED' AND ROWNUM=1)), c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='FAILED' AND EXISTS (SELECT 1 FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='FAILED');
        UPDATE DMT_OWNER.DMT_GMS_AWD_REFERENCES_TFM_TBL c SET c.TFM_STATUS='FAILED', c.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,'[FUSION_ERROR]The parent record has the following Fusion error: '||(SELECT h2.ERROR_TEXT FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h2 WHERE h2.RUN_ID=p_run_id AND h2.AWARD_NUMBER=c.AWARD_NUMBER AND h2.TFM_STATUS='FAILED' AND ROWNUM=1)), c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='FAILED' AND EXISTS (SELECT 1 FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='FAILED');
        UPDATE DMT_OWNER.DMT_GMS_AWD_TERMS_TFM_TBL c SET c.TFM_STATUS='FAILED', c.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,'[FUSION_ERROR]The parent record has the following Fusion error: '||(SELECT h2.ERROR_TEXT FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h2 WHERE h2.RUN_ID=p_run_id AND h2.AWARD_NUMBER=c.AWARD_NUMBER AND h2.TFM_STATUS='FAILED' AND ROWNUM=1)), c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='FAILED' AND EXISTS (SELECT 1 FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='FAILED');

        -- Echo outcomes back to all 15 STG tables
        -- Headers
        UPDATE DMT_OWNER.DMT_GMS_AWD_HEADERS_STG_TBL stg SET stg.STG_STATUS='LOADED', stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='LOADED');
        UPDATE DMT_OWNER.DMT_GMS_AWD_HEADERS_STG_TBL stg SET stg.STG_STATUS='FAILED', stg.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,(SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL t WHERE t.STG_SEQUENCE_ID=stg.STG_SEQUENCE_ID AND t.RUN_ID=p_run_id)), stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='FAILED');

        -- Funding
        UPDATE DMT_OWNER.DMT_GMS_AWD_FUNDING_STG_TBL stg SET stg.STG_STATUS='LOADED', stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_GMS_AWD_FUNDING_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='LOADED');
        UPDATE DMT_OWNER.DMT_GMS_AWD_FUNDING_STG_TBL stg SET stg.STG_STATUS='FAILED', stg.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,(SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_GMS_AWD_FUNDING_TFM_TBL t WHERE t.STG_SEQUENCE_ID=stg.STG_SEQUENCE_ID AND t.RUN_ID=p_run_id)), stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_GMS_AWD_FUNDING_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='FAILED');

        -- Projects
        UPDATE DMT_OWNER.DMT_GMS_AWD_PROJECTS_STG_TBL stg SET stg.STG_STATUS='LOADED', stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_GMS_AWD_PROJECTS_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='LOADED');
        UPDATE DMT_OWNER.DMT_GMS_AWD_PROJECTS_STG_TBL stg SET stg.STG_STATUS='FAILED', stg.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,(SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_GMS_AWD_PROJECTS_TFM_TBL t WHERE t.STG_SEQUENCE_ID=stg.STG_SEQUENCE_ID AND t.RUN_ID=p_run_id)), stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_GMS_AWD_PROJECTS_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='FAILED');

        -- Personnel
        UPDATE DMT_OWNER.DMT_GMS_AWD_PERSONNEL_STG_TBL stg SET stg.STG_STATUS='LOADED', stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_GMS_AWD_PERSONNEL_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='LOADED');
        UPDATE DMT_OWNER.DMT_GMS_AWD_PERSONNEL_STG_TBL stg SET stg.STG_STATUS='FAILED', stg.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,(SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_GMS_AWD_PERSONNEL_TFM_TBL t WHERE t.STG_SEQUENCE_ID=stg.STG_SEQUENCE_ID AND t.RUN_ID=p_run_id)), stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_GMS_AWD_PERSONNEL_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='FAILED');

        -- Fund Sources
        UPDATE DMT_OWNER.DMT_GMS_AWD_FUND_SRC_STG_TBL stg SET stg.STG_STATUS='LOADED', stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_GMS_AWD_FUND_SRC_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='LOADED');
        UPDATE DMT_OWNER.DMT_GMS_AWD_FUND_SRC_STG_TBL stg SET stg.STG_STATUS='FAILED', stg.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,(SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_GMS_AWD_FUND_SRC_TFM_TBL t WHERE t.STG_SEQUENCE_ID=stg.STG_SEQUENCE_ID AND t.RUN_ID=p_run_id)), stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_GMS_AWD_FUND_SRC_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='FAILED');

        -- Prj Fund Sources
        UPDATE DMT_OWNER.DMT_GMS_AWD_PRJ_FUND_SRC_STG_TBL stg SET stg.STG_STATUS='LOADED', stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='LOADED');
        UPDATE DMT_OWNER.DMT_GMS_AWD_PRJ_FUND_SRC_STG_TBL stg SET stg.STG_STATUS='FAILED', stg.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,(SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL t WHERE t.STG_SEQUENCE_ID=stg.STG_SEQUENCE_ID AND t.RUN_ID=p_run_id)), stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='FAILED');

        -- Keywords
        UPDATE DMT_OWNER.DMT_GMS_AWD_KEYWORDS_STG_TBL stg SET stg.STG_STATUS='LOADED', stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_GMS_AWD_KEYWORDS_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='LOADED');
        UPDATE DMT_OWNER.DMT_GMS_AWD_KEYWORDS_STG_TBL stg SET stg.STG_STATUS='FAILED', stg.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,(SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_GMS_AWD_KEYWORDS_TFM_TBL t WHERE t.STG_SEQUENCE_ID=stg.STG_SEQUENCE_ID AND t.RUN_ID=p_run_id)), stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_GMS_AWD_KEYWORDS_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='FAILED');

        -- Budget Periods
        UPDATE DMT_OWNER.DMT_GMS_AWD_BDGT_PRDS_STG_TBL stg SET stg.STG_STATUS='LOADED', stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_GMS_AWD_BDGT_PRDS_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='LOADED');
        UPDATE DMT_OWNER.DMT_GMS_AWD_BDGT_PRDS_STG_TBL stg SET stg.STG_STATUS='FAILED', stg.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,(SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_GMS_AWD_BDGT_PRDS_TFM_TBL t WHERE t.STG_SEQUENCE_ID=stg.STG_SEQUENCE_ID AND t.RUN_ID=p_run_id)), stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_GMS_AWD_BDGT_PRDS_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='FAILED');

        -- Certs
        UPDATE DMT_OWNER.DMT_GMS_AWD_CERTS_STG_TBL stg SET stg.STG_STATUS='LOADED', stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_GMS_AWD_CERTS_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='LOADED');
        UPDATE DMT_OWNER.DMT_GMS_AWD_CERTS_STG_TBL stg SET stg.STG_STATUS='FAILED', stg.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,(SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_GMS_AWD_CERTS_TFM_TBL t WHERE t.STG_SEQUENCE_ID=stg.STG_SEQUENCE_ID AND t.RUN_ID=p_run_id)), stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_GMS_AWD_CERTS_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='FAILED');

        -- CFDAs
        UPDATE DMT_OWNER.DMT_GMS_AWD_CFDAS_STG_TBL stg SET stg.STG_STATUS='LOADED', stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_GMS_AWD_CFDAS_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='LOADED');
        UPDATE DMT_OWNER.DMT_GMS_AWD_CFDAS_STG_TBL stg SET stg.STG_STATUS='FAILED', stg.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,(SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_GMS_AWD_CFDAS_TFM_TBL t WHERE t.STG_SEQUENCE_ID=stg.STG_SEQUENCE_ID AND t.RUN_ID=p_run_id)), stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_GMS_AWD_CFDAS_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='FAILED');

        -- Fund Allocations
        UPDATE DMT_OWNER.DMT_GMS_AWD_FUND_ALLOC_STG_TBL stg SET stg.STG_STATUS='LOADED', stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_GMS_AWD_FUND_ALLOC_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='LOADED');
        UPDATE DMT_OWNER.DMT_GMS_AWD_FUND_ALLOC_STG_TBL stg SET stg.STG_STATUS='FAILED', stg.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,(SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_GMS_AWD_FUND_ALLOC_TFM_TBL t WHERE t.STG_SEQUENCE_ID=stg.STG_SEQUENCE_ID AND t.RUN_ID=p_run_id)), stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_GMS_AWD_FUND_ALLOC_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='FAILED');

        -- Org Credits
        UPDATE DMT_OWNER.DMT_GMS_AWD_ORG_CREDITS_STG_TBL stg SET stg.STG_STATUS='LOADED', stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_GMS_AWD_ORG_CREDITS_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='LOADED');
        UPDATE DMT_OWNER.DMT_GMS_AWD_ORG_CREDITS_STG_TBL stg SET stg.STG_STATUS='FAILED', stg.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,(SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_GMS_AWD_ORG_CREDITS_TFM_TBL t WHERE t.STG_SEQUENCE_ID=stg.STG_SEQUENCE_ID AND t.RUN_ID=p_run_id)), stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_GMS_AWD_ORG_CREDITS_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='FAILED');

        -- Prj Task Burden
        UPDATE DMT_OWNER.DMT_GMS_AWD_PRJ_TSK_BRD_STG_TBL stg SET stg.STG_STATUS='LOADED', stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_GMS_AWD_PRJ_TSK_BRD_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='LOADED');
        UPDATE DMT_OWNER.DMT_GMS_AWD_PRJ_TSK_BRD_STG_TBL stg SET stg.STG_STATUS='FAILED', stg.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,(SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_GMS_AWD_PRJ_TSK_BRD_TFM_TBL t WHERE t.STG_SEQUENCE_ID=stg.STG_SEQUENCE_ID AND t.RUN_ID=p_run_id)), stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_GMS_AWD_PRJ_TSK_BRD_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='FAILED');

        -- References
        UPDATE DMT_OWNER.DMT_GMS_AWD_REFERENCES_STG_TBL stg SET stg.STG_STATUS='LOADED', stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_GMS_AWD_REFERENCES_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='LOADED');
        UPDATE DMT_OWNER.DMT_GMS_AWD_REFERENCES_STG_TBL stg SET stg.STG_STATUS='FAILED', stg.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,(SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_GMS_AWD_REFERENCES_TFM_TBL t WHERE t.STG_SEQUENCE_ID=stg.STG_SEQUENCE_ID AND t.RUN_ID=p_run_id)), stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_GMS_AWD_REFERENCES_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='FAILED');

        -- Terms
        UPDATE DMT_OWNER.DMT_GMS_AWD_TERMS_STG_TBL stg SET stg.STG_STATUS='LOADED', stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_GMS_AWD_TERMS_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='LOADED');
        UPDATE DMT_OWNER.DMT_GMS_AWD_TERMS_STG_TBL stg SET stg.STG_STATUS='FAILED', stg.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,(SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_GMS_AWD_TERMS_TFM_TBL t WHERE t.STG_SEQUENCE_ID=stg.STG_SEQUENCE_ID AND t.RUN_ID=p_run_id)), stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_GMS_AWD_TERMS_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='FAILED');

        -- NO COMMIT — orchestrator controls transaction boundaries

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. Awards LOADED: ' || l_loaded || ', FAILED: ' || l_failed || '.',
            C_PKG, C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, C_PROC || ' failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END PARSE_AND_UPDATE;

    -- --------------------------------------------------------
    -- RECONCILE_BATCH
    -- --------------------------------------------------------
    PROCEDURE RECONCILE_BATCH (
        p_run_id  IN NUMBER,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RECONCILE_BATCH';
        l_xml CLOB;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' start. load_ess_id: ' || p_load_ess_id ||
            ' | import_ess_id: ' || NVL(TO_CHAR(p_import_ess_id), 'NULL'),
            C_PKG, C_PROC);

        l_xml := FETCH_BIP_RESULTS(p_run_id, p_load_ess_id, p_import_ess_id);
        PARSE_AND_UPDATE(p_run_id, l_xml, p_import_ess_id);

        IF l_xml IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_xml) = 1 THEN
            DBMS_LOB.FREETEMPORARY(l_xml);
        END IF;

        -- Unresolved records intentionally left GENERATED (unaccounted).
        -- No fabricated FAILED: the accounting gate reports the object
        -- not-DONE and the funnel surfaces these as UNRECONCILED.

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete.', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, C_PROC || ' failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RECONCILE_BATCH;

END DMT_GRANTS_RESULTS_PKG;
/
