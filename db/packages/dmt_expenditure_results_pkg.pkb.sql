-- PACKAGE BODY DMT_EXPENDITURE_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_EXPENDITURE_RESULTS_PKG" 
AS
-- ============================================================
-- DMT_EXPENDITURE_RESULTS_PKG body
-- Expenditures BIP reconciliation — Two-Tier pattern.
-- Tier 1: PJC_TXN_XFACE_STAGE_ALL (interface table, errors/status)
-- Tier 2: PJC_EXP_ITEMS_ALL (base table, positive confirmation)
-- No absence=LOADED fallback. Every row gets positive verification
-- or is marked FAILED with a reconciliation error.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_EXPENDITURE_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'Expenditures';

    -- --------------------------------------------------------
    -- GET_PARTITION_KEYS — distinct (USER_TRANSACTION_SOURCE, DOCUMENT_NAME)
    -- tokens for one run, STATIC SQL over the expenditures transform table (this
    -- object's own table). Spawn-per-partition (work-queue-ID core): one child work
    -- item per source/document group, because Import and Process Cost Transactions
    -- takes exactly one transaction-source id (ParameterList position 6) and one
    -- document per submission, so one submission == one (source, document). Unlike
    -- the single-column BATCH_ID objects (Requisitions/Items), this key is a
    -- TWO-column composite; both columns ride in one JSON object and are decoded at
    -- generate + load time via DECODE_PARTITION_KEY. Called through invoke_registered
    -- (style KEYS).
    -- --------------------------------------------------------
    FUNCTION GET_PARTITION_KEYS (
        p_run_id IN NUMBER
    ) RETURN DMT_PARTITION_KEY_TBL IS
        l_keys DMT_PARTITION_KEY_TBL;
    BEGIN
        -- One JSON object per distinct (source, document), keyed by the two
        -- partition column names. Only STAGED rows with both columns non-null are
        -- eligible (a null source/document cannot build the import filter).
        SELECT DISTINCT JSON_OBJECT('USER_TRANSACTION_SOURCE' VALUE USER_TRANSACTION_SOURCE,
                                    'DOCUMENT_NAME'            VALUE DOCUMENT_NAME)
        BULK COLLECT INTO l_keys
        FROM   DMT_PJC_EXPENDITURES_TFM_TBL
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'STAGED'
        AND    USER_TRANSACTION_SOURCE IS NOT NULL
        AND    DOCUMENT_NAME IS NOT NULL;
        RETURN l_keys;
    END GET_PARTITION_KEYS;

    -- ============================================================
    -- HARVEST_PROCESSING_ERRORS — pull the PROCESSING/COSTING rejections out of
    -- the "Import and Process Cost Transactions" report XML and mark each
    -- matching TFM row FAILED with Fusion's real message. Returns rows matched.
    --
    -- WHY THIS EXISTS: G_STAG_ERR (parsed separately) only carries STAGING
    -- validation errors keyed by the transaction reference. Cost-time rejections
    -- (e.g. PJC_EX_PROJECT_DATE, PJC_NEW_TXNS_NOT_ALLOWED) live in a different
    -- pair of groups and are keyed by the Fusion TXN_INTERFACE_ID, which our TFM
    -- row does not carry (and the interface table is purged after costing). So:
    --   * G_ERROR_MSG_DETAILS -> the message (MESSAGE_TEXT_2 / MESSAGE_NAME_2 /
    --       MESSAGE_TYPE_CODE_2), keyed by TXN_INTERFACE_ID_2.
    --   * G_ERROR_WO_NLR      -> the business key (SEGMENT1=project,
    --       ELEMENT_NUMBER=task, QUANTITY, EXPENDITURE_ITEM_DATE) + MESSAGE_NAME_3_1,
    --       keyed by TXN_INTERFACE_ID_3_1.
    -- We join the two on (interface id + message name) to attach each message to a
    -- business key, then match the TFM row on that business key.
    --
    -- !!! MAINTENANCE — READ WHEN A NEW EXPENDITURE STAYS UNACCOUNTED:
    --   UNACCOUNTED means Fusion rejected the row but the reason sits in a report
    --   subsection/suffix this query does NOT read. Dump the report with
    --     DMT_ESS_UTIL_PKG.GET_ESS_OUTPUT_XML(<import BIP request id>)
    --   and diff its group names + field SUFFIXES (_2, _3_1, _10, _11, ...)
    --   against the PATHs below — Oracle shifts suffixes/renames groups between
    --   report versions, and THAT is where the query and the XML drift apart.
    --   Add the missing group/suffix here.
    -- !!! SCOPE: this layout is SPECIFIC to the PJC cost-transaction report. Every
    --   other object's import report (AP, AR, PO, Items, HDL, ...) has a COMPLETELY
    --   DIFFERENT XML structure — do NOT reuse this for them; each object needs its
    --   own harvest matched to its own report. Generalising is per-report, not one XPath.
    -- ============================================================
    FUNCTION harvest_processing_errors (p_run_id IN NUMBER, p_xml IN CLOB) RETURN NUMBER IS
        l_matched NUMBER := 0;
        l_hits    NUMBER := 0;
    BEGIN
        IF p_xml IS NULL OR DBMS_LOB.GETLENGTH(p_xml) = 0 THEN
            RETURN 0;
        END IF;
        -- The report's processing-error groups carry NO ORIG_TRANSACTION_REFERENCE
        -- (only the Fusion TXN_INTERFACE_ID, which our TFM row lacks and the
        -- interface table is purged of after costing). We therefore match on the
        -- fullest business identity the report gives us — project, task, quantity,
        -- date, expenditure type AND person. Type+person are essential: without
        -- them a GOOD row and the seed's BAD row (same project/task/qty/date,
        -- differing only in EXPENDITURE_TYPE) collide and one row would be stamped
        -- with the other's error — a fabricated verdict (violates Rule 1). To stay
        -- honest we ALSO refuse to stamp when the key is ambiguous: only update
        -- when the business key resolves to EXACTLY ONE still-GENERATED TFM row;
        -- otherwise leave it UNACCOUNTED (logged) rather than guess.
        FOR e IN (
            SELECT wo.seg1, wo.elem, wo.qty, wo.eidate, wo.etype, wo.person,
                   LISTAGG(md.mname || ' - ' || md.mtext, ' | ')
                       WITHIN GROUP (ORDER BY md.mname) AS msgs
            FROM   XMLTABLE('//G_ERROR_MSG_DETAILS' PASSING XMLTYPE(p_xml)
                    COLUMNS ifid  VARCHAR2(50)   PATH 'TXN_INTERFACE_ID_2',
                            mtype VARCHAR2(20)   PATH 'MESSAGE_TYPE_CODE_2',
                            mname VARCHAR2(100)  PATH 'MESSAGE_NAME_2',
                            mtext VARCHAR2(1000) PATH 'MESSAGE_TEXT_2') md
            JOIN   XMLTABLE('//G_ERROR_WO_NLR' PASSING XMLTYPE(p_xml)
                    COLUMNS ifid   VARCHAR2(50)  PATH 'TXN_INTERFACE_ID_3_1',
                            mname  VARCHAR2(100) PATH 'MESSAGE_NAME_3_1',
                            seg1   VARCHAR2(100) PATH 'SEGMENT1_3_1',
                            elem   VARCHAR2(100) PATH 'ELEMENT_NUMBER_3_1',
                            qty    VARCHAR2(50)  PATH 'QUANTITY_3_1',
                            eidate VARCHAR2(30)  PATH 'EXPENDITURE_ITEM_DATE_3_1',
                            etype  VARCHAR2(240) PATH 'EXPENDITURE_TYPE_NAME_3_1',
                            person VARCHAR2(50)  PATH 'PERSON_NUMBER_3_1') wo
              ON   wo.ifid = md.ifid AND wo.mname = md.mname
            WHERE  md.mtype = 'ERROR'
            GROUP BY wo.seg1, wo.elem, wo.qty, wo.eidate, wo.etype, wo.person
        ) LOOP
            -- ambiguity guard: how many still-open TFM rows match this key?
            SELECT COUNT(*) INTO l_hits
            FROM   DMT_PJC_EXPENDITURES_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS NOT IN ('LOADED','FAILED')
            AND    PROJECT_NUMBER = e.seg1
            AND    TASK_NUMBER    = e.elem
            AND    QUANTITY = TO_NUMBER(e.qty)   -- numeric compare (no NLS-dependent TO_CHAR)
            AND    TO_CHAR(EXPENDITURE_ITEM_DATE,'YYYY-MM-DD') = e.eidate
            AND    EXPENDITURE_TYPE = e.etype
            AND    (PERSON_NUMBER = e.person OR (PERSON_NUMBER IS NULL AND e.person IS NULL));
            IF l_hits <> 1 THEN
                DMT_UTIL_PKG.LOG(p_run_id => p_run_id,
                    p_message => 'HARVEST_PROCESSING_ERRORS: business key ('||e.seg1||'/'||e.elem||'/'||
                        e.qty||'/'||e.eidate||'/'||e.etype||'/'||e.person||') matched '||l_hits||
                        ' open rows — left UNACCOUNTED to avoid a fabricated verdict.',
                    p_log_type => DMT_UTIL_PKG.C_LOG_WARN, p_package => C_PKG,
                    p_procedure => 'HARVEST_PROCESSING_ERRORS');
                CONTINUE;
            END IF;
            UPDATE DMT_PJC_EXPENDITURES_TFM_TBL
            SET    TFM_STATUS           = 'FAILED',
                   ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                       '[FUSION_ERROR] ' || e.msgs),
                   RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS NOT IN ('LOADED','FAILED')
            AND    PROJECT_NUMBER = e.seg1
            AND    TASK_NUMBER    = e.elem
            AND    QUANTITY = TO_NUMBER(e.qty)   -- numeric compare (no NLS-dependent TO_CHAR)
            AND    TO_CHAR(EXPENDITURE_ITEM_DATE,'YYYY-MM-DD') = e.eidate
            AND    EXPENDITURE_TYPE = e.etype
            AND    (PERSON_NUMBER = e.person OR (PERSON_NUMBER IS NULL AND e.person IS NULL));
            l_matched := l_matched + SQL%ROWCOUNT;
        END LOOP;
        RETURN l_matched;
    EXCEPTION WHEN OTHERS THEN
        DMT_UTIL_PKG.LOG(p_run_id => p_run_id,
            p_message => 'HARVEST_PROCESSING_ERRORS failed (check report XML vs the PATHs '
                || '— see maintenance note): ' || SQLERRM,
            p_log_type => DMT_UTIL_PKG.C_LOG_WARN, p_package => C_PKG,
            p_procedure => 'HARVEST_PROCESSING_ERRORS');
        RETURN l_matched;
    END harvest_processing_errors;

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
            FROM   DMT_BIP_REPORT_TBL
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
    -- PARSE_AND_UPDATE — Two-tier reconciliation, no absence=LOADED
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
            IF p_import_ess_id IS NOT NULL THEN
                DECLARE
                    l_ir_errors DMT_IMPORT_REPORT_PKG.t_error_list;
                    l_ir_xml    CLOB;
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

                        -- Static single-key match on ORIG_TRANSACTION_REFERENCE.
                        -- The composed [IMPORT_REPORT] message is built by the
                        -- shared DMT_IMPORT_REPORT_PKG.ERROR_TEXT_FOR helper
                        -- (backlog item 28); the UPDATE itself stays static.
                        FOR i IN 1..l_ir_errors.COUNT LOOP
                            IF l_ir_errors(i).row_identifier IS NOT NULL THEN
                                UPDATE DMT_PJC_EXPENDITURES_TFM_TBL
                                SET    TFM_STATUS           = 'FAILED',
                                       ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                           DMT_IMPORT_REPORT_PKG.ERROR_TEXT_FOR(l_ir_errors(i).error_message)),
                                       RESULTS_UPDATED_DATE = SYSDATE,
                                       LAST_UPDATED_DATE    = SYSDATE
                                WHERE  RUN_ID              = p_run_id
                                AND    TFM_STATUS                   = 'GENERATED'
                                AND    ORIG_TRANSACTION_REFERENCE   = l_ir_errors(i).row_identifier;
                                l_ir_matched := l_ir_matched + SQL%ROWCOUNT;
                            END IF;
                        END LOOP;

                        -- Targeted parse: the Import and Process Cost Transactions
                        -- report lists per-transaction validation rejections in
                        -- LIST_G_STAG_ERR/G_STAG_ERR with fields suffixed _10
                        -- (TXN_INTERFACE_ID_10 = the transaction reference,
                        -- MESSAGE_NAME_10 = the real Fusion error code). The generic
                        -- parser above does not recognise that layout, so match these
                        -- directly to their TFM row with the real Fusion message.
                        BEGIN
                            FOR e IN (
                                SELECT x.ref, x.msg
                                FROM   XMLTABLE('//G_STAG_ERR' PASSING XMLTYPE(l_ir_xml)
                                        COLUMNS ref VARCHAR2(240) PATH 'TXN_INTERFACE_ID_10',
                                                msg VARCHAR2(400)  PATH 'MESSAGE_NAME_10') x
                                WHERE  x.ref IS NOT NULL
                            ) LOOP
                                UPDATE DMT_PJC_EXPENDITURES_TFM_TBL
                                SET    TFM_STATUS           = 'FAILED',
                                       ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                           '[FUSION_ERROR] ' || NVL(e.msg, 'Cost transaction rejected')),
                                       RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                                WHERE  RUN_ID = p_run_id
                                AND    ORIG_TRANSACTION_REFERENCE = e.ref
                                AND    TFM_STATUS NOT IN ('LOADED','FAILED');
                                l_ir_matched := l_ir_matched + SQL%ROWCOUNT;
                            END LOOP;
                        EXCEPTION WHEN OTHERS THEN
                            DMT_UTIL_PKG.LOG(p_run_id => p_run_id,
                                p_message => C_PROC || ': G_STAG_ERR targeted parse failed: ' || SQLERRM,
                                p_log_type => DMT_UTIL_PKG.C_LOG_WARN, p_package => C_PKG, p_procedure => C_PROC);
                        END;

                        -- Cost-time rejections live in OTHER report groups than
                        -- G_STAG_ERR (see HARVEST_PROCESSING_ERRORS for the full
                        -- layout + the "check XML vs harvester on new UNACCOUNTED"
                        -- maintenance note). Without this they stay UNACCOUNTED.
                        l_ir_matched := l_ir_matched + harvest_processing_errors(p_run_id, l_ir_xml);

                        DMT_UTIL_PKG.LOG(
                            p_run_id => p_run_id,
                            p_message        => 'Import Report parsed (BIP 0-row fallback): ' || l_ir_errors.COUNT ||
                                ' errors matched to ' || l_ir_matched || ' unreconciled rows.',
                            p_package        => C_PKG,
                            p_procedure      => C_PROC);

                        IF l_ir_xml IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_ir_xml) = 1 THEN
                            DBMS_LOB.FREETEMPORARY(l_ir_xml);
                        END IF;
                    END IF;
                END;
            END IF;

            -- Rows the Import Report fallback matched are now FAILED with a REAL
            -- import error. The rows it did NOT match remain GENERATED: we could
            -- determine neither a base-table LOADED nor a real Fusion per-record
            -- error for them, so we do NOT fabricate a FAILED. They are left
            -- unaccounted; the accounting gate reports the object not-DONE and
            -- the funnel surfaces them as unreconciled.
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => C_PROC || ': After Import Report fallback, ' ||
                                    l_ir_matched || ' rows matched a real import error; remaining ' ||
                                    'GENERATED rows left unaccounted (not marked FAILED).',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            GOTO echo_to_stg;
        END IF;

        -- Process rows from BIP XML — two-tier reconciliation
        FOR r IN (
            SELECT x.orig_transaction_reference,
                   x.project_number,
                   x.task_number,
                   x.expenditure_type,
                   UPPER(x.source_type)   AS source_type,
                   UPPER(x.fusion_status) AS fusion_status,
                   x.fusion_id,
                   x.error_msg
            FROM   XMLTABLE('/DATA_DS/G_1' PASSING l_xml
                COLUMNS
                    orig_transaction_reference VARCHAR2(240)  PATH 'ORIG_TRANSACTION_REFERENCE',
                    project_number             VARCHAR2(25)   PATH 'PROJECT_NUMBER',
                    task_number                VARCHAR2(100)  PATH 'TASK_NUMBER',
                    expenditure_type           VARCHAR2(240)  PATH 'EXPENDITURE_TYPE',
                    source_type                VARCHAR2(20)   PATH 'SOURCE_TYPE',
                    fusion_status              VARCHAR2(50)   PATH 'FUSION_STATUS',
                    fusion_id                  NUMBER         PATH 'FUSION_ID',
                    error_msg                  VARCHAR2(4000) PATH 'ERROR_MESSAGE'
            ) x
            -- Process BASE rows first so a genuinely-posted row is marked LOADED
            -- before its (possibly still-present) INTERFACE row is seen.
            ORDER BY CASE WHEN UPPER(x.source_type) = 'BASE' THEN 0 ELSE 1 END
        ) LOOP
            IF r.source_type = 'BASE' THEN
                -- Tier 2: Found in base table = positively LOADED
                UPDATE DMT_PJC_EXPENDITURES_TFM_TBL
                SET    TFM_STATUS                       = 'LOADED',
                       FUSION_EXPENDITURE_ITEM_ID   = r.fusion_id,
                       RESULTS_UPDATED_DATE         = SYSDATE,
                       LAST_UPDATED_DATE            = SYSDATE
                WHERE  RUN_ID               = p_run_id
                AND    ORIG_TRANSACTION_REFERENCE    = r.orig_transaction_reference
                AND    TFM_STATUS                      NOT IN ('LOADED','FAILED');
                l_loaded := l_loaded + SQL%ROWCOUNT;

            ELSIF r.source_type = 'INTERFACE' THEN
                -- Tier 1: interface row. The BASE tier is the ONLY source of LOADED.
                -- A row reaching here is not in the base table. We may only mark it
                -- FAILED when the interface carries a REAL Fusion rejection message:
                -- a reject-class status AND a non-null error_msg. In that case we
                -- write the actual returned error_msg. If the interface returned only
                -- a status label and no message (including a "success" status like 'P'
                -- with no base row), we have NO real Fusion error -- do NOT fabricate a
                -- FAILED. Leave the row GENERATED so the Import Report fallback below
                -- or the shared honest sweep accounts for it (sweep -> UNACCOUNTED).
                IF r.fusion_status IN ('ERROR','REJECTED','FAILED','FAILURE','N','R')
                   AND r.error_msg IS NOT NULL THEN
                    UPDATE DMT_PJC_EXPENDITURES_TFM_TBL
                    SET    TFM_STATUS               = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                                     '[FUSION_ERROR] ' || r.error_msg),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID            = p_run_id
                    AND    ORIG_TRANSACTION_REFERENCE = r.orig_transaction_reference
                    AND    TFM_STATUS                    NOT IN ('LOADED','FAILED');
                    l_failed := l_failed + SQL%ROWCOUNT;
                END IF;
            END IF;
        END LOOP;

        -- Import Report fallback: if we have an import ESS ID and there are
        -- still GENERATED rows, try to match errors from the ESS Import Report XML.
        IF p_import_ess_id IS NOT NULL THEN
            DECLARE
                l_still_gen  NUMBER := 0;
                l_ir_errors  DMT_IMPORT_REPORT_PKG.t_error_list;
                l_ir_xml     CLOB;
            BEGIN
                SELECT COUNT(*) INTO l_still_gen
                FROM   DMT_PJC_EXPENDITURES_TFM_TBL
                WHERE  RUN_ID = p_run_id
                AND    TFM_STATUS         = 'GENERATED';

                IF l_still_gen > 0 THEN
                    DMT_UTIL_PKG.LOG(
                        p_run_id => p_run_id,
                        p_message        => C_PROC || ': ' || l_still_gen ||
                            ' rows still GENERATED after BIP. Attempting Import Report error matching (ESS ' ||
                            p_import_ess_id || ').',
                        p_package        => C_PKG,
                        p_procedure      => C_PROC);

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

                        -- Static single-key match on ORIG_TRANSACTION_REFERENCE.
                        -- Message built by the shared ERROR_TEXT_FOR helper
                        -- (backlog item 28); UPDATE stays static.
                        FOR i IN 1..l_ir_errors.COUNT LOOP
                            IF l_ir_errors(i).row_identifier IS NOT NULL THEN
                                UPDATE DMT_PJC_EXPENDITURES_TFM_TBL
                                SET    TFM_STATUS           = 'FAILED',
                                       ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                           DMT_IMPORT_REPORT_PKG.ERROR_TEXT_FOR(l_ir_errors(i).error_message)),
                                       RESULTS_UPDATED_DATE = SYSDATE,
                                       LAST_UPDATED_DATE    = SYSDATE
                                WHERE  RUN_ID              = p_run_id
                                AND    TFM_STATUS                   = 'GENERATED'
                                AND    ORIG_TRANSACTION_REFERENCE   = l_ir_errors(i).row_identifier;
                                l_ir_matched := l_ir_matched + SQL%ROWCOUNT;
                            END IF;
                        END LOOP;

                        DMT_UTIL_PKG.LOG(
                            p_run_id => p_run_id,
                            p_message        => 'Import Report parsed: ' || l_ir_errors.COUNT ||
                                ' errors matched to ' || l_ir_matched || ' unreconciled rows.',
                            p_package        => C_PKG,
                            p_procedure      => C_PROC);

                        IF l_ir_xml IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_ir_xml) = 1 THEN
                            DBMS_LOB.FREETEMPORARY(l_ir_xml);
                        END IF;
                    END IF;
                END IF;
            END;
        END IF;

        -- (No absence-!=-LOADED sweep: a record neither confirmed LOADED nor
        -- given a real Fusion error is left GENERATED (unaccounted). The
        -- accounting gate then reports the object not-DONE and the funnel
        -- surfaces it as UNRECONCILED — no fabricated FAILED.)
        l_not_recon := 0;

        -- Reached when the base BIP report was present but matched nothing (the
        -- cost transactions did not post). Capture per-transaction rejections from
        -- the Import and Process Cost Transactions report (LIST_G_STAG_ERR/G_STAG_ERR,
        -- fields suffixed _10) so rejected rows get their real Fusion error instead
        -- of being left UNACCOUNTED. Only touches rows not already resolved.
        IF p_import_ess_id IS NOT NULL THEN
            DECLARE l_ir2 CLOB; l_h NUMBER;
            BEGIN
                l_ir2 := DMT_ESS_UTIL_PKG.GET_ESS_OUTPUT_XML(p_import_ess_id);
                IF l_ir2 IS NOT NULL AND DBMS_LOB.GETLENGTH(l_ir2) > 0 THEN
                    FOR e IN (
                        SELECT x.ref, x.msg
                        FROM   XMLTABLE('//G_STAG_ERR' PASSING XMLTYPE(l_ir2)
                                COLUMNS ref VARCHAR2(240) PATH 'TXN_INTERFACE_ID_10',
                                        msg VARCHAR2(400)  PATH 'MESSAGE_NAME_10') x
                        WHERE  x.ref IS NOT NULL
                    ) LOOP
                        UPDATE DMT_PJC_EXPENDITURES_TFM_TBL
                        SET    TFM_STATUS           = 'FAILED',
                               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                   '[FUSION_ERROR] ' || NVL(e.msg, 'Cost transaction rejected')),
                               RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                        WHERE  RUN_ID = p_run_id
                        AND    ORIG_TRANSACTION_REFERENCE = e.ref
                        AND    TFM_STATUS NOT IN ('LOADED','FAILED');
                    END LOOP;
                    -- Cost-time rejections (project-date, project-status, etc.) are in
                    -- other report groups than G_STAG_ERR — harvest them too, else they
                    -- stay UNACCOUNTED (see HARVEST_PROCESSING_ERRORS + maintenance note).
                    l_h := harvest_processing_errors(p_run_id, l_ir2);
                END IF;
            EXCEPTION WHEN OTHERS THEN NULL;
            END;
        END IF;

        <<echo_to_stg>>
        -- Echo outcomes back to STG
        UPDATE DMT_PJC_EXPENDITURES_STG_TBL stg
        SET    stg.STG_STATUS            = 'LOADED',
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_PJC_EXPENDITURES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');
        UPDATE DMT_PJC_EXPENDITURES_STG_TBL stg
        SET    stg.STG_STATUS            = 'FAILED',
               stg.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_PJC_EXPENDITURES_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                    AND    t.RUN_ID  = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_PJC_EXPENDITURES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');

        -- NO COMMIT — orchestrator controls transaction boundaries

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' complete. Expenditures LOADED: ' || l_loaded ||
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

        -- Unresolved records intentionally left GENERATED (unaccounted).
        -- No fabricated FAILED: the accounting gate reports the object
        -- not-DONE and the funnel surfaces these as UNRECONCILED.

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

END DMT_EXPENDITURE_RESULTS_PKG;
/
