-- PACKAGE BODY DMT_BILLING_EVENT_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_BILLING_EVENT_RESULTS_PKG" 
AS
-- ============================================================
-- DMT_BILLING_EVENT_RESULTS_PKG body
-- Billing Events reconciliation — Three-Tier pattern.
--
-- Tier 1: BIP query on PJB_BILLING_EVENTS_INT (interface table)
--         Always purged after import — will rarely return rows.
-- Tier 2: BIP query on PJB_BILLING_EVENTS (base table)
--         Catches successfully LOADED rows via prefix-based SOURCEREF match.
-- Tier 3: Import Report XML from ImportBillingEventReportJob ESS output.
--         Contains G_6 (full interface snapshot per row) + G_7 (per-row errors).
--         Primary error source since interface table is always purged.
--
-- Flow:
--   1. Run BIP two-tier (Tier 1+2). Tier 2 catches successes.
--   2. For remaining GENERATED rows, find the Report child ESS job.
--   3. Download Import Report XML via GET_ESS_OUTPUT_XML.
--   4. Parse G_6 + G_7: match SOURCEREF → TFM, mark LOADED or FAILED.
--   5. Sweep: remaining GENERATED → FAILED with RECONCILE_ERROR.
--   6. Echo outcomes to STG.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_BILLING_EVENT_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'BillingEvents';

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

    -- --------------------------------------------------------
    -- (b64_to_clob removed — base64 decode is now centralised in
    --  DMT_UTIL_PKG.BASE64_DECODE_CLOB / BIP_REPORT_XML, which decode CLOBs of
    --  any size. The old local copy truncated at VARCHAR2(32767).)

    -- --------------------------------------------------------
    -- Private: Find the ImportBillingEventReportJob child ESS ID.
    -- Delegates to DMT_ESS_UTIL_PKG.CAPTURE_REPORT_ESS_JOB which
    -- looks up the exact job definition from DMT_ERP_INTERFACE_OPTIONS_TBL.
    -- Used as fallback when the loader didn't capture it (manual/one-off calls).
    -- Returns NULL if not found.
    -- --------------------------------------------------------
    FUNCTION find_report_ess_id (
        p_run_id IN NUMBER,
        p_import_ess_id  IN NUMBER
    ) RETURN NUMBER IS
        C_PROC CONSTANT VARCHAR2(30) := 'find_report_ess_id';
        l_result NUMBER;
    BEGIN
        -- First check if already captured in the hierarchy
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
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => C_PROC || ': Found report ESS ' || l_result ||
                                    ' in hierarchy (child of import ' || p_import_ess_id || ')',
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RETURN l_result;
        END IF;

        -- Not in hierarchy yet — capture it now
        l_result := DMT_ESS_UTIL_PKG.CAPTURE_REPORT_ESS_JOB(
            p_run_id => p_run_id,
            p_import_ess_id  => p_import_ess_id,
            p_cemli_code     => C_CEMLI);

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ': Report ESS ID = ' || NVL(TO_CHAR(l_result), 'NULL') ||
                                ' (captured from import ESS ' || p_import_ess_id || ')',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        RETURN l_result;

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => C_PROC || ': Failed to find Report child ESS: ' || SQLERRM,
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RETURN NULL;
    END find_report_ess_id;

    -- --------------------------------------------------------
    -- Private: Parse Import Report XML (G_6 + G_7) and update TFM rows.
    -- Returns the number of TFM rows matched.
    --
    -- XML structure (from ImportBillingEventReportJob output):
    --   G_6: one per interface row — SOURCEREF, IMPORT_STATUS, all FBDI columns
    --   G_7: nested under G_6 — per-row error codes and messages
    -- --------------------------------------------------------
    FUNCTION parse_import_report (
        p_run_id IN NUMBER,
        p_report_xml     IN CLOB
    ) RETURN NUMBER IS
        C_PROC     CONSTANT VARCHAR2(30) := 'parse_import_report';
        l_xml      XMLTYPE;
        l_loaded   NUMBER := 0;
        l_failed   NUMBER := 0;
        l_err_msgs VARCHAR2(4000);
    BEGIN
        IF p_report_xml IS NULL OR DBMS_LOB.GETLENGTH(p_report_xml) = 0 THEN
            RETURN 0;
        END IF;

        BEGIN
            l_xml := XMLTYPE(p_report_xml);
        EXCEPTION
            WHEN OTHERS THEN
                DMT_UTIL_PKG.LOG(
                    p_run_id => p_run_id,
                    p_message        => C_PROC || ': Failed to parse Import Report XML: ' || SQLERRM,
                    p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                    p_package        => C_PKG,
                    p_procedure      => C_PROC);
                RETURN 0;
        END;

        -- Process G_6 rows (one per interface record)
        FOR r IN (
            SELECT x.sourceref,
                   UPPER(x.import_status) AS import_status,
                   x.int_rec_id,
                   x.project_number,
                   x.contract_number,
                   x.g6_xml
            FROM   XMLTABLE('/DATA_DS/G_6' PASSING l_xml
                COLUMNS
                    sourceref       VARCHAR2(240)  PATH 'SOURCEREF',
                    import_status   VARCHAR2(50)   PATH 'IMPORT_STATUS',
                    int_rec_id      NUMBER         PATH 'INT_REC_ID',
                    project_number  VARCHAR2(25)   PATH 'PROJECT_NUMBER',
                    contract_number VARCHAR2(120)  PATH 'CONTRACT_NUMBER',
                    g6_xml          XMLTYPE        PATH '.'
            ) x
        ) LOOP
            -- Aggregate G_7 error messages for this row
            l_err_msgs := NULL;
            BEGIN
                FOR e IN (
                    SELECT y.error_code,
                           y.message_text
                    FROM   XMLTABLE('/G_6/G_7' PASSING r.g6_xml
                        COLUMNS
                            error_code   VARCHAR2(100)  PATH 'ERROR_CODE_S3',
                            message_text VARCHAR2(2000) PATH 'MESSAGE_TEXT_S3'
                    ) y
                ) LOOP
                    IF l_err_msgs IS NOT NULL THEN
                        l_err_msgs := l_err_msgs || ' | ';
                    END IF;
                    l_err_msgs := SUBSTR(l_err_msgs || NVL(e.error_code, '') || ': ' || NVL(e.message_text, ''), 1, 4000);
                END LOOP;
            EXCEPTION
                WHEN OTHERS THEN NULL; -- no G_7 children — not an error
            END;

            IF r.sourceref IS NULL THEN
                CONTINUE;
            END IF;

            IF r.import_status IN ('ERROR', 'REJECTED', 'FAILED', 'FAILURE', 'N') THEN
                UPDATE DMT_OWNER.DMT_PJB_BILL_EVENTS_TFM_TBL
                SET    TFM_STATUS               = 'FAILED',
                       ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                           '[FUSION_ERROR] ' || NVL(l_err_msgs, 'Import status: ' || r.import_status)),
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID       = p_run_id
                AND    SOURCEREF            = r.sourceref
                AND    TFM_STATUS              NOT IN ('LOADED', 'FAILED');
                l_failed := l_failed + SQL%ROWCOUNT;

            ELSIF r.import_status IN ('COMPLETE', 'COMPLETED', 'IMPORTED', 'Y', 'PROCESSED', 'SUCCESS', 'P') THEN
                UPDATE DMT_OWNER.DMT_PJB_BILL_EVENTS_TFM_TBL
                SET    TFM_STATUS               = 'LOADED',
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID       = p_run_id
                AND    SOURCEREF            = r.sourceref
                AND    TFM_STATUS              NOT IN ('LOADED', 'FAILED');
                l_loaded := l_loaded + SQL%ROWCOUNT;

            ELSE
                -- Unknown tfm_status — mark FAILED with whatever info we have
                UPDATE DMT_OWNER.DMT_PJB_BILL_EVENTS_TFM_TBL
                SET    TFM_STATUS               = 'FAILED',
                       ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                           '[FUSION_ERROR] Import Report status: ' || NVL(r.import_status, 'NULL') ||
                           CASE WHEN l_err_msgs IS NOT NULL THEN ' — ' || l_err_msgs END),
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID       = p_run_id
                AND    SOURCEREF            = r.sourceref
                AND    TFM_STATUS              NOT IN ('LOADED', 'FAILED');
                l_failed := l_failed + SQL%ROWCOUNT;
            END IF;
        END LOOP;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' complete. From Import Report: LOADED=' || l_loaded ||
                                ', FAILED=' || l_failed,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        RETURN l_loaded + l_failed;

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => C_PROC || ' failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RETURN 0;
    END parse_import_report;

    -- --------------------------------------------------------
    -- FETCH_BIP_RESULTS — passes P_BATCH_ID, P_IMPORT_ESS_ID, P_PREFIX
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
        l_prefix     VARCHAR2(30);
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' start. CEMLI: ' || C_CEMLI ||
                                ' | load_ess_id: ' || p_load_ess_id ||
                                ' | import_ess_id: ' || NVL(TO_CHAR(p_import_ess_id), 'NULL'),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        l_base_url := RTRIM(DMT_UTIL_PKG.GET_CONFIG('FUSION_URL'), '/');
        l_username := DMT_UTIL_PKG.GET_CONFIG('FUSION_USERNAME');
        l_password := DMT_UTIL_PKG.GET_CONFIG('FUSION_PASSWORD');

        IF l_base_url IS NULL OR l_username IS NULL OR l_password IS NULL THEN
            RAISE_APPLICATION_ERROR(-20031,
                C_PROC || ': Fusion connection config is incomplete.');
        END IF;

        BEGIN
            SELECT REPORT_CATALOG_PATH
            INTO   l_rpt_path
            FROM   DMT_OWNER.DMT_BIP_REPORT_TBL
            WHERE  CEMLI_CODE = C_CEMLI;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20032,
                    C_PROC || ': No row in DMT_BIP_REPORT_TBL for CEMLI_CODE = ''' || C_CEMLI || '''.');
        END;

        IF l_rpt_path IS NULL THEN
            RAISE_APPLICATION_ERROR(-20033,
                C_PROC || ': REPORT_CATALOG_PATH is NULL for CEMLI_CODE = ''' || C_CEMLI || '''.');
        END IF;

        l_url := l_base_url || '/xmlpserver/services/v2/ReportService';

        -- Look up prefix for Tier 2 base table matching
        BEGIN
            SELECT PREFIX INTO l_prefix
            FROM   DMT_OWNER.DMT_PIPELINE_RUN_TBL
            WHERE  RUN_ID = p_run_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_prefix := NULL;
        END;

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
            '            <v2:item>' ||
            '              <v2:name>P_PREFIX</v2:name>' ||
            '              <v2:values><v2:item>' || NVL(l_prefix, '') || '</v2:item></v2:values>' ||
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

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'BIP runReport request built. Report: ' || l_rpt_path,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        l_resp := bip_soap_post(l_url, l_action, l_env);
        DBMS_LOB.FREETEMPORARY(l_env);

        IF DBMS_LOB.INSTR(l_resp, 'soapenv:Fault') > 0 OR
           DBMS_LOB.INSTR(l_resp, 'soap:Fault')    > 0 THEN
            RAISE_APPLICATION_ERROR(-20034,
                C_PROC || ': SOAP Fault from BIP runReport. Report: ' || l_rpt_path ||
                ' | Response (first 1000): ' || DBMS_LOB.SUBSTR(l_resp, 1000, 1));
        END IF;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' complete. Response bytes: ' || DBMS_LOB.GETLENGTH(l_resp),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        RETURN l_resp;

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => C_PROC || ' failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END FETCH_BIP_RESULTS;

    -- --------------------------------------------------------
    -- PARSE_AND_UPDATE — Three-tier reconciliation
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
        l_not_recon  NUMBER := 0;
        l_ir_matched NUMBER := 0;
        l_still_gen  NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' start.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        -- ====================================================
        -- PHASE 1: BIP Two-Tier (Tier 1 = interface, Tier 2 = base table)
        -- ====================================================
        -- Decode the BIP report via the shared helper (handles any size, no
        -- VARCHAR2(32767) truncation). Returns NULL when there are no rows.
        l_xml := DMT_UTIL_PKG.BIP_REPORT_XML(p_xml_data);
        IF l_xml IS NULL THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => C_PROC || ': No <reportBytes> in BIP response. BIP returned 0 rows from both tiers.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            GOTO import_report_fallback;
        END IF;

        -- Process rows from BIP XML — two-tier reconciliation
        FOR r IN (
            SELECT x.sourceref,
                   x.project_number,
                   x.task_number,
                   UPPER(x.source_type)   AS source_type,
                   UPPER(x.fusion_status) AS fusion_status,
                   x.fusion_id,
                   x.error_msg
            FROM   XMLTABLE('/DATA_DS/G_1' PASSING l_xml
                COLUMNS
                    sourceref       VARCHAR2(240)  PATH 'SOURCEREF',
                    project_number  VARCHAR2(25)   PATH 'PROJECT_NUMBER',
                    task_number     VARCHAR2(100)  PATH 'TASK_NUMBER',
                    source_type     VARCHAR2(20)   PATH 'SOURCE_TYPE',
                    fusion_status   VARCHAR2(50)   PATH 'FUSION_STATUS',
                    fusion_id       NUMBER         PATH 'FUSION_ID',
                    error_msg       VARCHAR2(4000) PATH 'ERROR_MESSAGE'
            ) x
        ) LOOP
            IF r.source_type = 'BASE' THEN
                -- Tier 2: Found in base table = positively LOADED
                UPDATE DMT_OWNER.DMT_PJB_BILL_EVENTS_TFM_TBL
                SET    TFM_STATUS               = 'LOADED',
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID       = p_run_id
                AND    SOURCEREF            = r.sourceref
                AND    TFM_STATUS              NOT IN ('LOADED','FAILED');
                l_loaded := l_loaded + SQL%ROWCOUNT;

            ELSIF r.source_type = 'INTERFACE' THEN
                -- Tier 1: Interface table row — check tfm_status
                IF r.fusion_status IN ('COMPLETE','COMPLETED','IMPORTED','Y','PROCESSED','SUCCESS','P') THEN
                    UPDATE DMT_OWNER.DMT_PJB_BILL_EVENTS_TFM_TBL
                    SET    TFM_STATUS               = 'LOADED',
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    SOURCEREF            = r.sourceref
                    AND    TFM_STATUS              NOT IN ('LOADED','FAILED');
                    l_loaded := l_loaded + SQL%ROWCOUNT;
                ELSIF r.fusion_status IN ('ERROR','REJECTED','FAILED','FAILURE','N') THEN
                    UPDATE DMT_OWNER.DMT_PJB_BILL_EVENTS_TFM_TBL
                    SET    TFM_STATUS               = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                                     '[FUSION_ERROR] ' || NVL(r.error_msg, 'Interface status: ' || r.fusion_status)),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    SOURCEREF            = r.sourceref
                    AND    TFM_STATUS              NOT IN ('LOADED','FAILED');
                    l_failed := l_failed + SQL%ROWCOUNT;
                ELSE
                    UPDATE DMT_OWNER.DMT_PJB_BILL_EVENTS_TFM_TBL
                    SET    TFM_STATUS               = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                                     '[FUSION_ERROR] Unrecognized interface status: ' || NVL(r.fusion_status, 'NULL')),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    SOURCEREF            = r.sourceref
                    AND    TFM_STATUS              NOT IN ('LOADED','FAILED');
                    l_failed := l_failed + SQL%ROWCOUNT;
                END IF;
            END IF;
        END LOOP;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ': BIP two-tier complete. LOADED=' || l_loaded || ', FAILED=' || l_failed,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        -- ====================================================
        -- PHASE 2: Import Report XML fallback (Tier 3)
        -- For any GENERATED rows not resolved by BIP, download
        -- the Import Report from the Report child ESS job.
        -- ====================================================
        <<import_report_fallback>>

        SELECT COUNT(*) INTO l_still_gen
        FROM   DMT_OWNER.DMT_PJB_BILL_EVENTS_TFM_TBL
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS         = 'GENERATED';

        IF l_still_gen > 0 AND p_import_ess_id IS NOT NULL THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => C_PROC || ': ' || l_still_gen ||
                    ' rows still GENERATED after BIP. Attempting Import Report fallback (import ESS ' ||
                    p_import_ess_id || ').',
                p_package        => C_PKG,
                p_procedure      => C_PROC);

            DECLARE
                l_report_ess_id NUMBER;
                l_ir_xml        CLOB;
            BEGIN
                -- Find the Report child ESS job
                l_report_ess_id := find_report_ess_id(p_run_id, p_import_ess_id);

                IF l_report_ess_id IS NOT NULL THEN
                    -- Download Import Report XML from the Report child job
                    BEGIN
                        l_ir_xml := DMT_ESS_UTIL_PKG.GET_ESS_OUTPUT_XML(l_report_ess_id);
                    EXCEPTION
                        WHEN OTHERS THEN
                            DMT_UTIL_PKG.LOG(
                                p_run_id => p_run_id,
                                p_message        => C_PROC || ': Failed to download Import Report XML from ESS ' ||
                                    l_report_ess_id || ': ' || SQLERRM,
                                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                                p_package        => C_PKG,
                                p_procedure      => C_PROC);
                            l_ir_xml := NULL;
                    END;

                    IF l_ir_xml IS NOT NULL AND DBMS_LOB.GETLENGTH(l_ir_xml) > 0 THEN
                        l_ir_matched := parse_import_report(p_run_id, l_ir_xml);

                        DMT_UTIL_PKG.LOG(
                            p_run_id => p_run_id,
                            p_message        => C_PROC || ': Import Report parsed. ' || l_ir_matched ||
                                ' TFM rows matched from Report ESS ' || l_report_ess_id || '.',
                            p_package        => C_PKG,
                            p_procedure      => C_PROC);

                        IF DBMS_LOB.ISTEMPORARY(l_ir_xml) = 1 THEN
                            DBMS_LOB.FREETEMPORARY(l_ir_xml);
                        END IF;
                    ELSE
                        DMT_UTIL_PKG.LOG(
                            p_run_id => p_run_id,
                            p_message        => C_PROC || ': Import Report XML is empty from ESS ' || l_report_ess_id,
                            p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                            p_package        => C_PKG,
                            p_procedure      => C_PROC);
                    END IF;
                ELSE
                    DMT_UTIL_PKG.LOG(
                        p_run_id => p_run_id,
                        p_message        => C_PROC || ': Report child ESS job not found. Cannot retrieve Import Report.',
                        p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                        p_package        => C_PKG,
                        p_procedure      => C_PROC);
                END IF;
            END;
        END IF;

        -- PHASE 3: (The absence != LOADED sweep now lives in the standard
        -- SWEEP_UNACCOUNTED procedure, called at the end of RECONCILE_BATCH — §7.)
        l_not_recon := 0;

        -- ====================================================
        -- Echo outcomes back to STG
        -- ====================================================
        UPDATE DMT_OWNER.DMT_PJB_BILL_EVENTS_STG_TBL stg
        SET    stg.STG_STATUS            = 'LOADED',
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_PJB_BILL_EVENTS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');
        UPDATE DMT_OWNER.DMT_PJB_BILL_EVENTS_STG_TBL stg
        SET    stg.STG_STATUS            = 'FAILED',
               stg.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_PJB_BILL_EVENTS_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                    AND    t.RUN_ID  = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_PJB_BILL_EVENTS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');

        -- NO COMMIT — orchestrator controls transaction boundaries

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' complete. BillingEvents LOADED: ' || l_loaded ||
                                ', FAILED: ' || l_failed ||
                                ', IMPORT_REPORT_MATCHED: ' || l_ir_matched ||
                                ', NOT_RECONCILED: ' || l_not_recon || '.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => C_PROC || ' failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END PARSE_AND_UPDATE;

    -- ============================================================
    -- SWEEP_UNACCOUNTED — STANDARD RECONCILE-ERROR SWEEP (design §7).
    -- Marks every TFM row still NOT IN ('LOADED','FAILED') as FAILED with a
    -- reportable [RECONCILE_ERROR] (absence != LOADED, Rule #1). Byte-identical
    -- across packages except the tagged EDIT regions. Does NOT commit.
    -- ============================================================
    PROCEDURE SWEEP_UNACCOUNTED (p_run_id IN NUMBER) IS
    BEGIN
        -- <<EDIT-TABLE — CHANGE BELOW: the object's TFM table name. Repeat this
        --   whole UPDATE block (EDIT-TABLE through the ';') once per TFM table
        --   the object owns.>>
        UPDATE DMT_OWNER.DMT_PJB_BILL_EVENTS_TFM_TBL
        -- <<END EDIT-TABLE — everything below is FIXED until EDIT-MSG>>
        SET    TFM_STATUS           = 'FAILED',
               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
        -- <<EDIT-MSG — CHANGE BELOW: the message text. It MUST begin with the
        --   literal '[RECONCILE_ERROR] ' tag.>>
                   '[RECONCILE_ERROR] Billing event not confirmed in Fusion '
                   || '(not found in the billing-event base tables for this run) after '
                   || 'reconciliation; import outcome could not be verified.'
        -- <<END EDIT-MSG — everything below is FIXED until EDIT-SCOPE>>
               ),
               RESULTS_UPDATED_DATE = SYSDATE,
               LAST_UPDATED_DATE    = SYSDATE
        WHERE  RUN_ID     = p_run_id
        AND    TFM_STATUS NOT IN ('LOADED','FAILED')
        -- (EDIT-SCOPE deleted — DMT_PJB_BILL_EVENTS_TFM_TBL is not shared.)
        ;
    END SWEEP_UNACCOUNTED;

    -- --------------------------------------------------------
    -- RECONCILE_BATCH
    -- --------------------------------------------------------
    PROCEDURE RECONCILE_BATCH (
        p_run_id  IN NUMBER,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RECONCILE_BATCH';
        l_xml CLOB;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' start. load_ess_id: ' || p_load_ess_id ||
                                ' | import_ess_id: ' || NVL(TO_CHAR(p_import_ess_id), 'NULL'),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        l_xml := FETCH_BIP_RESULTS(p_run_id, p_load_ess_id, p_import_ess_id);
        PARSE_AND_UPDATE(p_run_id, l_xml, p_import_ess_id);

        IF l_xml IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_xml) = 1 THEN
            DBMS_LOB.FREETEMPORARY(l_xml);
        END IF;

        -- Standard final step: fail any row still unaccounted (absence != LOADED).
        SWEEP_UNACCOUNTED(p_run_id);

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' complete.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => C_PROC || ' failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END RECONCILE_BATCH;

END DMT_BILLING_EVENT_RESULTS_PKG;
/
