-- PACKAGE BODY DMT_PROJECT_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_PROJECT_RESULTS_PKG" 
AS
-- ============================================================
-- DMT_PROJECT_RESULTS_PKG body
-- Projects BIP reconciliation — per-object-type from Fusion.
--
-- BIP query returns rows from ALL 4 interface tables:
--   Projects:    PJF_PROJECTS_ALL_XFACE (Tier 1) + PJF_PROJECTS_ALL_B (Tier 2)
--   Tasks:       PJF_PROJ_ELEMENTS_XFACE (Tier 1 only)
--   TeamMembers: PJF_PROJECT_PARTIES_INT (Tier 1 only)
--   TxnControls: PJC_TXN_CONTROLS_STAGE (Tier 1 only)
--
-- Each child object gets its status directly from Fusion, not
-- inferred from the parent project. Cascade is still used as a
-- fallback for children purged from interface tables after import.
--
-- Import Report XML (ESS output) provides error details — routed
-- to the correct TFM table by error_source.
--
-- Echo back to all 4 STG tables.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_PROJECT_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'Projects';

    -- --------------------------------------------------------
    -- Private: POST a SOAP envelope; return full response CLOB.
    -- (Same helper as other results packages — duplicated to keep packages independent.)
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
    -- FETCH_BIP_RESULTS — now passes P_IMPORT_ESS_ID as second parameter
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

        -- Look up prefix for Tier 2 base table matching (REQUEST_ID is NULL for projects)
        BEGIN
            SELECT PREFIX INTO l_prefix
            FROM   DMT_OWNER.DMT_PIPELINE_RUN_TBL
            WHERE  RUN_ID = p_run_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_prefix := NULL;
                DMT_UTIL_PKG.LOG(
                    p_run_id => p_run_id,
                    p_message        => C_PROC || ': No CONVERSION_MASTER row for run_id ' ||
                                        p_run_id || '. Tier 2 (base table) reconciliation will be skipped.',
                    p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                    p_package        => C_PKG,
                    p_procedure      => C_PROC);
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
    -- PARSE_AND_UPDATE — Two-tier reconciliation + child objects
    -- Parses BIP XML response (base64 reportBytes), updates
    -- all 4 TFM tables (Projects, Tasks, TeamMembers, TxnControls)
    -- directly from their respective Fusion interface tables,
    -- then echoes back to STG tables.
    --
    -- BIP query returns OBJECT_TYPE discriminator:
    --   Projects    → PJF_PROJECTS_ALL_XFACE (Tier 1) + PJF_PROJECTS_ALL_B (Tier 2)
    --   Tasks       → PJF_PROJ_ELEMENTS_XFACE (Tier 1 only)
    --   TeamMembers → PJF_PROJECT_PARTIES_INT (Tier 1 only)
    --   TxnControls → PJC_TXN_CONTROLS_STAGE (Tier 1 only)
    --
    -- Import Report XML also matches errors against all 4 TFM tables
    -- using error_source (PROJECT/TASK/TEAM_MEMBER/TXN_CONTROL).
    -- --------------------------------------------------------
    PROCEDURE PARSE_AND_UPDATE (
        p_run_id IN NUMBER,
        p_xml_data       IN CLOB,
        p_import_ess_id  IN NUMBER DEFAULT NULL
    ) IS
        C_PROC       CONSTANT VARCHAR2(30) := 'PARSE_AND_UPDATE';
        l_xml        XMLTYPE;
        -- Per-object counters
        l_prj_loaded     NUMBER := 0;
        l_prj_failed     NUMBER := 0;
        l_tsk_loaded     NUMBER := 0;
        l_tsk_failed     NUMBER := 0;
        l_tm_loaded      NUMBER := 0;
        l_tm_failed      NUMBER := 0;
        l_tc_loaded      NUMBER := 0;
        l_tc_failed      NUMBER := 0;
        l_not_recon      NUMBER := 0;
        l_ir_matched     NUMBER := 0;
        -- Aliases for summary
        l_loaded         NUMBER := 0;
        l_failed         NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' start.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        -- Decode the BIP report via the shared helper (handles any size, no
        -- VARCHAR2(32767) truncation). Returns NULL when there are no rows.
        l_xml := DMT_UTIL_PKG.BIP_REPORT_XML(p_xml_data);
        IF l_xml IS NULL THEN
            -- No reportBytes at all — BIP returned 0 rows from BOTH tiers.
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => C_PROC || ': No <reportBytes> in BIP response. Attempting Import Report fallback.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);

            -- Try Import Report fallback before marking everything FAILED
            -- (same logic as the post-BIP fallback, but on the 0-row path)
            IF p_import_ess_id IS NOT NULL THEN
                DECLARE
                    l_ir_errors DMT_IMPORT_REPORT_PKG.t_error_list;
                    l_ir_xml    CLOB;
                    l_src       VARCHAR2(100);
                BEGIN
                    BEGIN
                        l_ir_xml := DMT_ESS_UTIL_PKG.GET_ESS_OUTPUT_XML(p_import_ess_id);
                    EXCEPTION
                        WHEN OTHERS THEN
                            DMT_UTIL_PKG.LOG(
                                p_run_id => p_run_id,
                                p_message        => C_PROC || ': Failed to download ESS output XML for request ' ||
                                    p_import_ess_id || ': ' || SQLERRM,
                                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                                p_package        => C_PKG,
                                p_procedure      => C_PROC);
                            l_ir_xml := NULL;
                    END;

                    IF l_ir_xml IS NOT NULL AND DBMS_LOB.GETLENGTH(l_ir_xml) > 0 THEN
                        l_ir_errors := DMT_IMPORT_REPORT_PKG.PARSE_ERRORS(l_ir_xml);

                        FOR i IN 1..l_ir_errors.COUNT LOOP
                            IF l_ir_errors(i).row_identifier IS NULL THEN
                                CONTINUE;
                            END IF;

                            l_src := UPPER(NVL(l_ir_errors(i).error_source, ''));

                            IF l_src LIKE '%TASK%' THEN
                                UPDATE DMT_OWNER.DMT_PJF_TASKS_TFM_TBL
                                SET    STATUS = 'FAILED',
                                       ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                           '[IMPORT_REPORT] ' || NVL(l_ir_errors(i).error_message, 'Import error')),
                                       RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                                WHERE  RUN_ID = p_run_id AND STATUS = 'GENERATED'
                                AND    (TASK_NAME = l_ir_errors(i).row_identifier
                                        OR PROJECT_NUMBER || '/' || TASK_NAME = l_ir_errors(i).row_identifier);
                                l_ir_matched := l_ir_matched + SQL%ROWCOUNT;
                            ELSIF l_src LIKE '%TEAM%' OR l_src LIKE '%PART%' OR l_src LIKE '%MEMBER%' THEN
                                UPDATE DMT_OWNER.DMT_PJF_TEAM_MEMBERS_TFM_TBL
                                SET    STATUS = 'FAILED',
                                       ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                           '[IMPORT_REPORT] ' || NVL(l_ir_errors(i).error_message, 'Import error')),
                                       RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                                WHERE  RUN_ID = p_run_id AND STATUS = 'GENERATED'
                                AND    (TEAM_MEMBER_NAME = l_ir_errors(i).row_identifier
                                        OR PROJECT_NAME || '/' || TEAM_MEMBER_NAME = l_ir_errors(i).row_identifier);
                                l_ir_matched := l_ir_matched + SQL%ROWCOUNT;
                            ELSIF l_src LIKE '%TXN%' OR l_src LIKE '%CONTROL%' THEN
                                UPDATE DMT_OWNER.DMT_PJC_TXN_CONTROLS_TFM_TBL
                                SET    STATUS = 'FAILED',
                                       ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                           '[IMPORT_REPORT] ' || NVL(l_ir_errors(i).error_message, 'Import error')),
                                       RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                                WHERE  RUN_ID = p_run_id AND STATUS = 'GENERATED'
                                AND    (TXN_CTRL_REFERENCE = l_ir_errors(i).row_identifier
                                        OR PROJECT_NUMBER || '/' || TXN_CTRL_REFERENCE = l_ir_errors(i).row_identifier);
                                l_ir_matched := l_ir_matched + SQL%ROWCOUNT;
                            ELSE
                                UPDATE DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL
                                SET    STATUS = 'FAILED',
                                       ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                           '[IMPORT_REPORT] ' || NVL(l_ir_errors(i).error_message, 'Import error')),
                                       RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                                WHERE  RUN_ID = p_run_id AND STATUS = 'GENERATED'
                                AND    PROJECT_NUMBER = l_ir_errors(i).row_identifier;
                                l_ir_matched := l_ir_matched + SQL%ROWCOUNT;
                            END IF;
                        END LOOP;

                        DMT_UTIL_PKG.LOG(
                            p_run_id => p_run_id,
                            p_message        => 'Import Report parsed (BIP 0-row fallback): ' || l_ir_errors.COUNT ||
                                ' errors, ' || l_ir_matched || ' matched to TFM rows.',
                            p_package        => C_PKG,
                            p_procedure      => C_PROC);

                        IF l_ir_xml IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_ir_xml) = 1 THEN
                            DBMS_LOB.FREETEMPORARY(l_ir_xml);
                        END IF;
                    END IF;
                END;
            END IF;

            -- Mark remaining GENERATED rows as FAILED across ALL 4 TFM tables
            UPDATE DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL
            SET    STATUS = 'FAILED',
                   ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                       '[RECONCILE_ERROR] BIP returned 0 rows. Cannot verify Fusion outcome.'),
                   RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
            WHERE  RUN_ID = p_run_id AND STATUS = 'GENERATED';
            l_not_recon := SQL%ROWCOUNT;
            UPDATE DMT_OWNER.DMT_PJF_TASKS_TFM_TBL
            SET    STATUS = 'FAILED',
                   ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                       '[RECONCILE_ERROR] BIP returned 0 rows. Cannot verify Fusion outcome.'),
                   RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
            WHERE  RUN_ID = p_run_id AND STATUS = 'GENERATED';
            l_not_recon := l_not_recon + SQL%ROWCOUNT;
            UPDATE DMT_OWNER.DMT_PJF_TEAM_MEMBERS_TFM_TBL
            SET    STATUS = 'FAILED',
                   ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                       '[RECONCILE_ERROR] BIP returned 0 rows. Cannot verify Fusion outcome.'),
                   RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
            WHERE  RUN_ID = p_run_id AND STATUS = 'GENERATED';
            l_not_recon := l_not_recon + SQL%ROWCOUNT;
            UPDATE DMT_OWNER.DMT_PJC_TXN_CONTROLS_TFM_TBL
            SET    STATUS = 'FAILED',
                   ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                       '[RECONCILE_ERROR] BIP returned 0 rows. Cannot verify Fusion outcome.'),
                   RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
            WHERE  RUN_ID = p_run_id AND STATUS = 'GENERATED';
            l_not_recon := l_not_recon + SQL%ROWCOUNT;

            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => C_PROC || ': After Import Report fallback, ' ||
                                    l_not_recon || ' GENERATED rows still not reconciled — marked FAILED.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            GOTO echo_to_stg;
        END IF;

        -- ================================================================
        -- Process rows from BIP XML — per-object-type reconciliation
        -- BIP query now returns OBJECT_TYPE to route rows to the correct
        -- TFM table: Projects, Tasks, TeamMembers, TxnControls.
        --
        -- Projects: Tier 1 (INTERFACE) + Tier 2 (BASE)
        -- Tasks/TeamMembers/TxnControls: Tier 1 (INTERFACE) only
        --   — successful child rows are purged from interface tables;
        --     only rejected/unprocessed rows remain.
        -- ================================================================
        FOR r IN (
            SELECT UPPER(x.object_type)    AS object_type,
                   x.project_name,
                   x.project_number,
                   x.task_name,
                   x.team_member_name,
                   x.txn_ctrl_reference,
                   UPPER(x.source_type)    AS source_type,
                   UPPER(x.import_status)  AS import_status,
                   UPPER(x.load_status)    AS load_status,
                   x.fusion_id,
                   x.error_msg
            FROM   XMLTABLE('/DATA_DS/G_1' PASSING l_xml
                COLUMNS
                    object_type       VARCHAR2(30)   PATH 'OBJECT_TYPE',
                    project_name      VARCHAR2(240)  PATH 'PROJECT_NAME',
                    project_number    VARCHAR2(25)   PATH 'PROJECT_NUMBER',
                    task_name         VARCHAR2(240)  PATH 'TASK_NAME',
                    team_member_name  VARCHAR2(240)  PATH 'TEAM_MEMBER_NAME',
                    txn_ctrl_reference VARCHAR2(240) PATH 'TXN_CTRL_REFERENCE',
                    source_type       VARCHAR2(20)   PATH 'SOURCE_TYPE',
                    import_status     VARCHAR2(50)   PATH 'IMPORT_STATUS',
                    load_status       VARCHAR2(50)   PATH 'LOAD_STATUS',
                    fusion_id         NUMBER         PATH 'FUSION_ID',
                    error_msg         VARCHAR2(4000) PATH 'ERROR_MESSAGE'
            ) x
        ) LOOP

            -- ---- PROJECTS ----
            IF r.object_type = 'PROJECTS' THEN
                IF r.source_type = 'BASE' THEN
                    -- Tier 2: Found in base table = positively LOADED
                    UPDATE DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL
                    SET    STATUS               = 'LOADED',
                           FUSION_PROJECT_ID    = r.fusion_id,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    PROJECT_NUMBER       = r.project_number
                    AND    STATUS              NOT IN ('LOADED','FAILED');
                    l_prj_loaded := l_prj_loaded + SQL%ROWCOUNT;

                ELSIF r.source_type = 'INTERFACE' THEN
                    IF r.import_status IN ('COMPLETED','IMPORTED','Y','PROCESSED','SUCCESS','P') THEN
                        UPDATE DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL
                        SET    STATUS               = 'LOADED',
                               FUSION_PROJECT_ID    = r.fusion_id,
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID       = p_run_id
                        AND    PROJECT_NUMBER       = r.project_number
                        AND    STATUS              NOT IN ('LOADED','FAILED');
                        l_prj_loaded := l_prj_loaded + SQL%ROWCOUNT;
                    ELSIF r.import_status IN ('ERROR','REJECTED','FAILED','FAILURE','N','SUBMITTED') THEN
                        -- SUBMITTED = loaded but not processed (e.g. parent missing)
                        UPDATE DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL
                        SET    STATUS               = 'FAILED',
                               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                   '[FUSION_ERROR] ' || NVL(r.error_msg, 'Interface status: ' || r.import_status)),
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID       = p_run_id
                        AND    PROJECT_NUMBER       = r.project_number
                        AND    STATUS              NOT IN ('LOADED','FAILED');
                        l_prj_failed := l_prj_failed + SQL%ROWCOUNT;
                    ELSE
                        UPDATE DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL
                        SET    STATUS               = 'FAILED',
                               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                   '[FUSION_ERROR] Unrecognized interface status: ' || NVL(r.import_status, 'NULL')),
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID       = p_run_id
                        AND    PROJECT_NUMBER       = r.project_number
                        AND    STATUS              NOT IN ('LOADED','FAILED');
                        l_prj_failed := l_prj_failed + SQL%ROWCOUNT;
                    END IF;
                END IF;

            -- ---- TASKS ----
            ELSIF r.object_type = 'TASKS' THEN
                -- Tier 1 only: rows remaining in PJF_PROJ_ELEMENTS_XFACE = rejected
                -- SUBMITTED = loaded but not imported (parent project missing or rejected)
                IF r.import_status IN ('ERROR','REJECTED','FAILED','FAILURE','N','SUBMITTED') THEN
                    UPDATE DMT_OWNER.DMT_PJF_TASKS_TFM_TBL
                    SET    STATUS               = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                               '[FUSION_ERROR] Task rejected by Fusion. Project: ' || r.project_number ||
                               '. Interface status: ' || r.import_status),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    TASK_NAME            = r.task_name
                    AND    PROJECT_NUMBER       = r.project_number
                    AND    STATUS              NOT IN ('LOADED','FAILED');
                    l_tsk_failed := l_tsk_failed + SQL%ROWCOUNT;
                ELSIF r.import_status IN ('COMPLETED','IMPORTED','Y','PROCESSED','SUCCESS','P') THEN
                    UPDATE DMT_OWNER.DMT_PJF_TASKS_TFM_TBL
                    SET    STATUS               = 'LOADED',
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    TASK_NAME            = r.task_name
                    AND    PROJECT_NUMBER       = r.project_number
                    AND    STATUS              NOT IN ('LOADED','FAILED');
                    l_tsk_loaded := l_tsk_loaded + SQL%ROWCOUNT;
                ELSE
                    UPDATE DMT_OWNER.DMT_PJF_TASKS_TFM_TBL
                    SET    STATUS               = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                               '[FUSION_ERROR] Task unrecognized status: ' || NVL(r.import_status, 'NULL')),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    TASK_NAME            = r.task_name
                    AND    PROJECT_NUMBER       = r.project_number
                    AND    STATUS              NOT IN ('LOADED','FAILED');
                    l_tsk_failed := l_tsk_failed + SQL%ROWCOUNT;
                END IF;

            -- ---- TEAM MEMBERS ----
            ELSIF r.object_type = 'TEAMMEMBERS' THEN
                IF r.import_status IN ('ERROR','REJECTED','FAILED','FAILURE','N','SUBMITTED') THEN
                    UPDATE DMT_OWNER.DMT_PJF_TEAM_MEMBERS_TFM_TBL
                    SET    STATUS               = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                               '[FUSION_ERROR] Team member rejected by Fusion. Project: ' || r.project_name ||
                               '. Interface status: ' || r.import_status),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    TEAM_MEMBER_NAME     = r.team_member_name
                    AND    PROJECT_NAME         = r.project_name
                    AND    STATUS              NOT IN ('LOADED','FAILED');
                    l_tm_failed := l_tm_failed + SQL%ROWCOUNT;
                ELSIF r.import_status IN ('COMPLETED','IMPORTED','Y','PROCESSED','SUCCESS','P') THEN
                    UPDATE DMT_OWNER.DMT_PJF_TEAM_MEMBERS_TFM_TBL
                    SET    STATUS               = 'LOADED',
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    TEAM_MEMBER_NAME     = r.team_member_name
                    AND    PROJECT_NAME         = r.project_name
                    AND    STATUS              NOT IN ('LOADED','FAILED');
                    l_tm_loaded := l_tm_loaded + SQL%ROWCOUNT;
                ELSE
                    UPDATE DMT_OWNER.DMT_PJF_TEAM_MEMBERS_TFM_TBL
                    SET    STATUS               = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                               '[FUSION_ERROR] Team member unrecognized status: ' || NVL(r.import_status, 'NULL')),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    TEAM_MEMBER_NAME     = r.team_member_name
                    AND    PROJECT_NAME         = r.project_name
                    AND    STATUS              NOT IN ('LOADED','FAILED');
                    l_tm_failed := l_tm_failed + SQL%ROWCOUNT;
                END IF;

            -- ---- TXN CONTROLS ----
            ELSIF r.object_type = 'TXNCONTROLS' THEN
                -- PJC_TXN_CONTROLS_STAGE has LOAD_STATUS but no IMPORT_STATUS
                IF NVL(r.import_status, r.load_status) IN ('ERROR','REJECTED','FAILED','FAILURE','N','SUBMITTED') THEN
                    UPDATE DMT_OWNER.DMT_PJC_TXN_CONTROLS_TFM_TBL
                    SET    STATUS               = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                               '[FUSION_ERROR] Txn control rejected by Fusion. Project: ' || r.project_number ||
                               '. Status: ' || NVL(r.import_status, r.load_status)),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    TXN_CTRL_REFERENCE   = r.txn_ctrl_reference
                    AND    PROJECT_NUMBER       = r.project_number
                    AND    STATUS              NOT IN ('LOADED','FAILED');
                    l_tc_failed := l_tc_failed + SQL%ROWCOUNT;
                ELSIF NVL(r.import_status, r.load_status) IN ('COMPLETED','IMPORTED','Y','PROCESSED','SUCCESS','P','COMPLETE') THEN
                    UPDATE DMT_OWNER.DMT_PJC_TXN_CONTROLS_TFM_TBL
                    SET    STATUS               = 'LOADED',
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    TXN_CTRL_REFERENCE   = r.txn_ctrl_reference
                    AND    PROJECT_NUMBER       = r.project_number
                    AND    STATUS              NOT IN ('LOADED','FAILED');
                    l_tc_loaded := l_tc_loaded + SQL%ROWCOUNT;
                ELSE
                    UPDATE DMT_OWNER.DMT_PJC_TXN_CONTROLS_TFM_TBL
                    SET    STATUS               = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                               '[FUSION_ERROR] Txn control unrecognized status: ' ||
                               NVL(r.import_status, NVL(r.load_status, 'NULL'))),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    TXN_CTRL_REFERENCE   = r.txn_ctrl_reference
                    AND    PROJECT_NUMBER       = r.project_number
                    AND    STATUS              NOT IN ('LOADED','FAILED');
                    l_tc_failed := l_tc_failed + SQL%ROWCOUNT;
                END IF;

            END IF;
        END LOOP;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ': BIP complete. Projects ' || l_prj_loaded || 'L/' || l_prj_failed || 'F' ||
                                ', Tasks ' || l_tsk_loaded || 'L/' || l_tsk_failed || 'F' ||
                                ', TeamMembers ' || l_tm_loaded || 'L/' || l_tm_failed || 'F' ||
                                ', TxnControls ' || l_tc_loaded || 'L/' || l_tc_failed || 'F',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        -- ================================================================
        -- Import Report fallback: if any TFM rows across all 4 tables are
        -- still GENERATED, try to match errors from the ESS Import Report XML.
        -- Import Report returns error_source (PROJECT, TASK, etc.) so we can
        -- route errors to the correct TFM table.
        -- ================================================================
        IF p_import_ess_id IS NOT NULL THEN
            DECLARE
                l_still_gen  NUMBER := 0;
                l_ir_errors  DMT_IMPORT_REPORT_PKG.t_error_list;
                l_ir_xml     CLOB;
                l_src        VARCHAR2(100);
            BEGIN
                SELECT (SELECT COUNT(*) FROM DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL
                        WHERE RUN_ID = p_run_id AND STATUS = 'GENERATED')
                     + (SELECT COUNT(*) FROM DMT_OWNER.DMT_PJF_TASKS_TFM_TBL
                        WHERE RUN_ID = p_run_id AND STATUS = 'GENERATED')
                     + (SELECT COUNT(*) FROM DMT_OWNER.DMT_PJF_TEAM_MEMBERS_TFM_TBL
                        WHERE RUN_ID = p_run_id AND STATUS = 'GENERATED')
                     + (SELECT COUNT(*) FROM DMT_OWNER.DMT_PJC_TXN_CONTROLS_TFM_TBL
                        WHERE RUN_ID = p_run_id AND STATUS = 'GENERATED')
                INTO l_still_gen FROM DUAL;

                IF l_still_gen > 0 THEN
                    DMT_UTIL_PKG.LOG(
                        p_run_id => p_run_id,
                        p_message        => C_PROC || ': ' || l_still_gen ||
                            ' rows still GENERATED after BIP (all tables). Attempting Import Report (ESS ' ||
                            p_import_ess_id || ').',
                        p_package        => C_PKG,
                        p_procedure      => C_PROC);

                    BEGIN
                        l_ir_xml := DMT_ESS_UTIL_PKG.GET_ESS_OUTPUT_XML(p_import_ess_id);
                    EXCEPTION
                        WHEN OTHERS THEN
                            DMT_UTIL_PKG.LOG(
                                p_run_id => p_run_id,
                                p_message        => C_PROC || ': Failed to download ESS output XML: ' || SQLERRM,
                                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                                p_package        => C_PKG,
                                p_procedure      => C_PROC);
                            l_ir_xml := NULL;
                    END;

                    IF l_ir_xml IS NOT NULL AND DBMS_LOB.GETLENGTH(l_ir_xml) > 0 THEN
                        l_ir_errors := DMT_IMPORT_REPORT_PKG.PARSE_ERRORS(l_ir_xml);

                        FOR i IN 1..l_ir_errors.COUNT LOOP
                            IF l_ir_errors(i).row_identifier IS NULL THEN
                                CONTINUE;
                            END IF;

                            l_src := UPPER(NVL(l_ir_errors(i).error_source, ''));

                            -- Route by error_source to the correct TFM table
                            IF l_src LIKE '%TASK%' THEN
                                -- Task errors: row_identifier may be PROJECT_NUMBER/TASK_NAME
                                UPDATE DMT_OWNER.DMT_PJF_TASKS_TFM_TBL
                                SET    STATUS               = 'FAILED',
                                       ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                           '[IMPORT_REPORT] ' || NVL(l_ir_errors(i).error_message, 'Import error')),
                                       RESULTS_UPDATED_DATE = SYSDATE,
                                       LAST_UPDATED_DATE    = SYSDATE
                                WHERE  RUN_ID       = p_run_id
                                AND    STATUS               = 'GENERATED'
                                AND    (TASK_NAME = l_ir_errors(i).row_identifier
                                        OR PROJECT_NUMBER || '/' || TASK_NAME = l_ir_errors(i).row_identifier);
                                l_ir_matched := l_ir_matched + SQL%ROWCOUNT;

                            ELSIF l_src LIKE '%TEAM%' OR l_src LIKE '%PART%' OR l_src LIKE '%MEMBER%' THEN
                                UPDATE DMT_OWNER.DMT_PJF_TEAM_MEMBERS_TFM_TBL
                                SET    STATUS               = 'FAILED',
                                       ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                           '[IMPORT_REPORT] ' || NVL(l_ir_errors(i).error_message, 'Import error')),
                                       RESULTS_UPDATED_DATE = SYSDATE,
                                       LAST_UPDATED_DATE    = SYSDATE
                                WHERE  RUN_ID       = p_run_id
                                AND    STATUS               = 'GENERATED'
                                AND    (TEAM_MEMBER_NAME = l_ir_errors(i).row_identifier
                                        OR PROJECT_NAME || '/' || TEAM_MEMBER_NAME = l_ir_errors(i).row_identifier);
                                l_ir_matched := l_ir_matched + SQL%ROWCOUNT;

                            ELSIF l_src LIKE '%TXN%' OR l_src LIKE '%CONTROL%' THEN
                                UPDATE DMT_OWNER.DMT_PJC_TXN_CONTROLS_TFM_TBL
                                SET    STATUS               = 'FAILED',
                                       ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                           '[IMPORT_REPORT] ' || NVL(l_ir_errors(i).error_message, 'Import error')),
                                       RESULTS_UPDATED_DATE = SYSDATE,
                                       LAST_UPDATED_DATE    = SYSDATE
                                WHERE  RUN_ID       = p_run_id
                                AND    STATUS               = 'GENERATED'
                                AND    (TXN_CTRL_REFERENCE = l_ir_errors(i).row_identifier
                                        OR PROJECT_NUMBER || '/' || TXN_CTRL_REFERENCE = l_ir_errors(i).row_identifier);
                                l_ir_matched := l_ir_matched + SQL%ROWCOUNT;

                            ELSE
                                -- Default: PROJECT errors or unrecognized source
                                UPDATE DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL
                                SET    STATUS               = 'FAILED',
                                       ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                           '[IMPORT_REPORT] ' || NVL(l_ir_errors(i).error_message, 'Import error')),
                                       RESULTS_UPDATED_DATE = SYSDATE,
                                       LAST_UPDATED_DATE    = SYSDATE
                                WHERE  RUN_ID       = p_run_id
                                AND    STATUS               = 'GENERATED'
                                AND    PROJECT_NUMBER       = l_ir_errors(i).row_identifier;
                                l_ir_matched := l_ir_matched + SQL%ROWCOUNT;
                            END IF;
                        END LOOP;

                        DMT_UTIL_PKG.LOG(
                            p_run_id => p_run_id,
                            p_message        => 'Import Report parsed: ' || l_ir_errors.COUNT ||
                                ' errors, ' || l_ir_matched || ' matched to TFM rows.',
                            p_package        => C_PKG,
                            p_procedure      => C_PROC);

                        IF l_ir_xml IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_ir_xml) = 1 THEN
                            DBMS_LOB.FREETEMPORARY(l_ir_xml);
                        END IF;
                    END IF;
                END IF;
            END;
        END IF;

        -- ================================================================
        -- Cascade: if a child TFM row is still GENERATED but its parent
        -- project is LOADED, mark it LOADED. If parent is FAILED, mark
        -- it FAILED. This catches children that were purged from the
        -- interface table after successful import (no BIP row returned).
        -- ================================================================
        -- Tasks: cascade LOADED from parent project
        UPDATE DMT_OWNER.DMT_PJF_TASKS_TFM_TBL tsk
        SET    tsk.STATUS            = 'LOADED',
               tsk.RESULTS_UPDATED_DATE = SYSDATE,
               tsk.LAST_UPDATED_DATE = SYSDATE
        WHERE  tsk.RUN_ID    = p_run_id
        AND    tsk.STATUS            = 'GENERATED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL p
            WHERE  p.RUN_ID = p_run_id
            AND    p.PROJECT_NUMBER  = tsk.PROJECT_NUMBER
            AND    p.STATUS          = 'LOADED');

        -- Team Members: cascade LOADED from parent project
        UPDATE DMT_OWNER.DMT_PJF_TEAM_MEMBERS_TFM_TBL tm
        SET    tm.STATUS            = 'LOADED',
               tm.RESULTS_UPDATED_DATE = SYSDATE,
               tm.LAST_UPDATED_DATE = SYSDATE
        WHERE  tm.RUN_ID    = p_run_id
        AND    tm.STATUS            = 'GENERATED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL p
            WHERE  p.RUN_ID = p_run_id
            AND    p.PROJECT_NAME    = tm.PROJECT_NAME
            AND    p.STATUS          = 'LOADED');

        -- Txn Controls: cascade LOADED from parent project
        UPDATE DMT_OWNER.DMT_PJC_TXN_CONTROLS_TFM_TBL tc
        SET    tc.STATUS            = 'LOADED',
               tc.RESULTS_UPDATED_DATE = SYSDATE,
               tc.LAST_UPDATED_DATE = SYSDATE
        WHERE  tc.RUN_ID    = p_run_id
        AND    tc.STATUS            = 'GENERATED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL p
            WHERE  p.RUN_ID = p_run_id
            AND    p.PROJECT_NUMBER  = tc.PROJECT_NUMBER
            AND    p.STATUS          = 'LOADED');

        -- Tasks: cascade FAILED from parent project
        UPDATE DMT_OWNER.DMT_PJF_TASKS_TFM_TBL tsk
        SET    tsk.STATUS            = 'FAILED',
               tsk.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(tsk.ERROR_TEXT,
                   '[FUSION_ERROR] Parent project ' || tsk.PROJECT_NUMBER || ' was rejected by Fusion.'),
               tsk.RESULTS_UPDATED_DATE = SYSDATE,
               tsk.LAST_UPDATED_DATE = SYSDATE
        WHERE  tsk.RUN_ID    = p_run_id
        AND    tsk.STATUS            = 'GENERATED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL p
            WHERE  p.RUN_ID = p_run_id
            AND    p.PROJECT_NUMBER  = tsk.PROJECT_NUMBER
            AND    p.STATUS          = 'FAILED');

        -- Team Members: cascade FAILED from parent project
        UPDATE DMT_OWNER.DMT_PJF_TEAM_MEMBERS_TFM_TBL tm
        SET    tm.STATUS            = 'FAILED',
               tm.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(tm.ERROR_TEXT,
                   '[FUSION_ERROR] Parent project ' || tm.PROJECT_NAME || ' was rejected by Fusion.'),
               tm.RESULTS_UPDATED_DATE = SYSDATE,
               tm.LAST_UPDATED_DATE = SYSDATE
        WHERE  tm.RUN_ID    = p_run_id
        AND    tm.STATUS            = 'GENERATED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL p
            WHERE  p.RUN_ID = p_run_id
            AND    p.PROJECT_NAME    = tm.PROJECT_NAME
            AND    p.STATUS          = 'FAILED');

        -- Txn Controls: cascade FAILED from parent project
        UPDATE DMT_OWNER.DMT_PJC_TXN_CONTROLS_TFM_TBL tc
        SET    tc.STATUS            = 'FAILED',
               tc.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(tc.ERROR_TEXT,
                   '[FUSION_ERROR] Parent project ' || tc.PROJECT_NUMBER || ' was rejected by Fusion.'),
               tc.RESULTS_UPDATED_DATE = SYSDATE,
               tc.LAST_UPDATED_DATE = SYSDATE
        WHERE  tc.RUN_ID    = p_run_id
        AND    tc.STATUS            = 'GENERATED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL p
            WHERE  p.RUN_ID = p_run_id
            AND    p.PROJECT_NUMBER  = tc.PROJECT_NUMBER
            AND    p.STATUS          = 'FAILED');

        -- ================================================================
        -- Final sweep: mark any remaining GENERATED rows as FAILED
        -- across ALL 4 TFM tables. These are rows not matched by BIP,
        -- Import Report, or cascade.
        -- ================================================================
        UPDATE DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL
        SET    STATUS               = 'FAILED',
               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                   '[RECONCILE_ERROR] Row not found in Fusion interface table or base application table.'),
               RESULTS_UPDATED_DATE = SYSDATE,
               LAST_UPDATED_DATE    = SYSDATE
        WHERE  RUN_ID       = p_run_id
        AND    STATUS               = 'GENERATED';
        l_not_recon := SQL%ROWCOUNT;

        UPDATE DMT_OWNER.DMT_PJF_TASKS_TFM_TBL
        SET    STATUS               = 'FAILED',
               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                   '[RECONCILE_ERROR] Task not reconciled. Not found in Fusion interface table and parent project status unknown.'),
               RESULTS_UPDATED_DATE = SYSDATE,
               LAST_UPDATED_DATE    = SYSDATE
        WHERE  RUN_ID       = p_run_id
        AND    STATUS               = 'GENERATED';
        l_not_recon := l_not_recon + SQL%ROWCOUNT;

        UPDATE DMT_OWNER.DMT_PJF_TEAM_MEMBERS_TFM_TBL
        SET    STATUS               = 'FAILED',
               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                   '[RECONCILE_ERROR] Team member not reconciled. Not found in Fusion interface table and parent project status unknown.'),
               RESULTS_UPDATED_DATE = SYSDATE,
               LAST_UPDATED_DATE    = SYSDATE
        WHERE  RUN_ID       = p_run_id
        AND    STATUS               = 'GENERATED';
        l_not_recon := l_not_recon + SQL%ROWCOUNT;

        UPDATE DMT_OWNER.DMT_PJC_TXN_CONTROLS_TFM_TBL
        SET    STATUS               = 'FAILED',
               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                   '[RECONCILE_ERROR] Txn control not reconciled. Not found in Fusion interface table and parent project status unknown.'),
               RESULTS_UPDATED_DATE = SYSDATE,
               LAST_UPDATED_DATE    = SYSDATE
        WHERE  RUN_ID       = p_run_id
        AND    STATUS               = 'GENERATED';
        l_not_recon := l_not_recon + SQL%ROWCOUNT;

        <<echo_to_stg>>
        -- Echo outcomes back to STG tables (all 4 types)
        -- Projects
        UPDATE DMT_OWNER.DMT_PJF_PROJECTS_STG_TBL stg
        SET    stg.STATUS            = 'LOADED',
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.STATUS = 'LOADED');
        UPDATE DMT_OWNER.DMT_PJF_PROJECTS_STG_TBL stg
        SET    stg.STATUS            = 'FAILED',
               stg.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                    AND    t.RUN_ID  = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.STATUS = 'FAILED');

        -- Tasks
        UPDATE DMT_OWNER.DMT_PJF_TASKS_STG_TBL stg
        SET    stg.STATUS            = 'LOADED',
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_PJF_TASKS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.STATUS = 'LOADED');
        UPDATE DMT_OWNER.DMT_PJF_TASKS_STG_TBL stg
        SET    stg.STATUS            = 'FAILED',
               stg.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_PJF_TASKS_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                    AND    t.RUN_ID  = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_PJF_TASKS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.STATUS = 'FAILED');

        -- Team Members
        UPDATE DMT_OWNER.DMT_PJF_TEAM_MEMBERS_STG_TBL stg
        SET    stg.STATUS            = 'LOADED',
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_PJF_TEAM_MEMBERS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.STATUS = 'LOADED');
        UPDATE DMT_OWNER.DMT_PJF_TEAM_MEMBERS_STG_TBL stg
        SET    stg.STATUS            = 'FAILED',
               stg.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_PJF_TEAM_MEMBERS_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                    AND    t.RUN_ID  = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_PJF_TEAM_MEMBERS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.STATUS = 'FAILED');

        -- Txn Controls
        UPDATE DMT_OWNER.DMT_PJC_TXN_CONTROLS_STG_TBL stg
        SET    stg.STATUS            = 'LOADED',
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_PJC_TXN_CONTROLS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.STATUS = 'LOADED');
        UPDATE DMT_OWNER.DMT_PJC_TXN_CONTROLS_STG_TBL stg
        SET    stg.STATUS            = 'FAILED',
               stg.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_PJC_TXN_CONTROLS_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                    AND    t.RUN_ID  = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_PJC_TXN_CONTROLS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.STATUS = 'FAILED');

        -- NO COMMIT — orchestrator controls transaction boundaries

        l_loaded := l_prj_loaded + l_tsk_loaded + l_tm_loaded + l_tc_loaded;
        l_failed := l_prj_failed + l_tsk_failed + l_tm_failed + l_tc_failed;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' complete.' ||
                                ' Projects ' || l_prj_loaded || 'L/' || l_prj_failed || 'F' ||
                                ', Tasks ' || l_tsk_loaded || 'L/' || l_tsk_failed || 'F' ||
                                ', TeamMembers ' || l_tm_loaded || 'L/' || l_tm_failed || 'F' ||
                                ', TxnControls ' || l_tc_loaded || 'L/' || l_tc_failed || 'F' ||
                                ', IR_MATCHED: ' || l_ir_matched ||
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

END DMT_PROJECT_RESULTS_PKG;
/
