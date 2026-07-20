-- PACKAGE BODY DMT_AP_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_AP_RESULTS_PKG" 
AS
-- ============================================================
-- DMT_AP_RESULTS_PKG body
-- APInvoices BIP reconciliation.
-- Pattern: identical to DMT_PO_RESULTS_PKG.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_AP_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'APInvoices';

    -- --------------------------------------------------------
    -- Private: POST a SOAP envelope; return full response CLOB.
    -- (Same helper as PO/supplier results — duplicated to keep packages independent.)
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
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' start. CEMLI: ' || C_CEMLI ||
                                ' | load_ess_id: ' || p_load_ess_id,
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
    -- PARSE_AND_UPDATE
    -- Parses BIP XML response (base64 reportBytes), updates
    -- AP invoice header TFM rows, cascades to lines,
    -- then echoes back to STG tables.
    -- --------------------------------------------------------
    PROCEDURE PARSE_AND_UPDATE (
        p_run_id IN NUMBER,
        p_xml_data       IN CLOB
    ) IS
        C_PROC       CONSTANT VARCHAR2(30) := 'PARSE_AND_UPDATE';
        l_xml        XMLTYPE;
        l_loaded     NUMBER := 0;
        l_failed     NUMBER := 0;
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
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => C_PROC || ': No <reportBytes> in BIP response. No rows updated.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RETURN;
        END IF;

        -- Process header rows from BIP XML
        -- AP_INVOICES_INTERFACE IMPORT_STATUS: 'Y' = success, anything else = failed
        FOR r IN (
            SELECT x.invoice_num,
                   x.invoice_id,
                   UPPER(x.import_status) AS import_status,
                   x.vendor_name,
                   x.vendor_num,
                   x.error_msg
            FROM   XMLTABLE('/DATA_DS/G_1' PASSING l_xml
                COLUMNS
                    invoice_num   VARCHAR2(50)   PATH 'INVOICE_NUM',
                    invoice_id    VARCHAR2(20)   PATH 'INVOICE_ID',
                    import_status VARCHAR2(50)   PATH 'IMPORT_STATUS',
                    vendor_name   VARCHAR2(360)  PATH 'VENDOR_NAME',
                    vendor_num    VARCHAR2(30)   PATH 'VENDOR_NUM',
                    error_msg     VARCHAR2(4000) PATH 'ERROR_MESSAGE'
            ) x
        ) LOOP
            IF r.import_status IN ('Y','PROCESSED','SUCCESS','COMPLETED') THEN
                UPDATE DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL
                SET    TFM_STATUS               = 'LOADED',
                       FUSION_INVOICE_ID    = TO_NUMBER(r.invoice_id),
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID       = p_run_id
                AND    INVOICE_NUM          = r.invoice_num
                AND    TFM_STATUS              != 'LOADED';
                l_loaded := l_loaded + SQL%ROWCOUNT;
            ELSIF r.import_status IN ('N','ERROR','REJECTED','FAILED','FAILURE') THEN
                UPDATE DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL
                SET    TFM_STATUS               = 'FAILED',
                       ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                                 '[FUSION_ERROR] ' || r.error_msg),
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID       = p_run_id
                AND    INVOICE_NUM          = r.invoice_num
                AND    TFM_STATUS              != 'FAILED';
                l_failed := l_failed + SQL%ROWCOUNT;
            ELSIF r.import_status IN ('NEW', 'STAGING') THEN
                -- Row is in interface table but APXIIMPT did not process it.
                -- This means the Import job's ParameterList did not match
                -- (wrong source, wrong OU, or invoice was skipped).
                UPDATE DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL
                SET    TFM_STATUS           = 'FAILED',
                       ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                           '[FUSION_ERROR] Invoice still in interface table (tfm_status=' ||
                           r.import_status || '). Import Payables Invoices (APXIIMPT) did not ' ||
                           'process this invoice. Check the ParameterList, invoice SOURCE, ' ||
                           'and Operating Unit.'),
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID       = p_run_id
                AND    INVOICE_NUM          = r.invoice_num
                AND    TFM_STATUS          != 'FAILED';
                l_failed := l_failed + SQL%ROWCOUNT;
            ELSE
                -- Unknown tfm_status — don't silently ignore it
                UPDATE DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL
                SET    TFM_STATUS           = 'FAILED',
                       ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                           '[FUSION_ERROR] Unexpected interface tfm_status: ' ||
                           r.import_status || '. Investigate AP_INVOICES_INTERFACE.'),
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID       = p_run_id
                AND    INVOICE_NUM          = r.invoice_num
                AND    TFM_STATUS          != 'FAILED';
                l_failed := l_failed + SQL%ROWCOUNT;
            END IF;
        END LOOP;

        -- Cascade LOADED to child TFM table (lines via INVOICE_ID)
        UPDATE DMT_OWNER.DMT_AP_INVOICE_LINES_INT_TFM_TBL ln
        SET    ln.TFM_STATUS            = 'LOADED',
               ln.RESULTS_UPDATED_DATE = SYSDATE,
               ln.LAST_UPDATED_DATE = SYSDATE
        WHERE  ln.RUN_ID    = p_run_id
        AND    ln.TFM_STATUS           != 'LOADED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL h
            WHERE  h.RUN_ID = p_run_id
            AND    h.INVOICE_ID     = ln.INVOICE_ID
            AND    h.TFM_STATUS         = 'LOADED');

        -- Cascade FAILED to child TFM table (lines via INVOICE_ID)
        UPDATE DMT_OWNER.DMT_AP_INVOICE_LINES_INT_TFM_TBL ln
        SET    ln.TFM_STATUS            = 'FAILED',
               ln.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(ln.ERROR_TEXT,
                   '[FUSION_ERROR] Parent invoice was rejected by Fusion.'),
               ln.RESULTS_UPDATED_DATE = SYSDATE,
               ln.LAST_UPDATED_DATE = SYSDATE
        WHERE  ln.RUN_ID    = p_run_id
        AND    ln.TFM_STATUS           != 'FAILED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL h
            WHERE  h.RUN_ID = p_run_id
            AND    h.INVOICE_ID     = ln.INVOICE_ID
            AND    h.TFM_STATUS         = 'FAILED');

        -- Echo outcomes back to STG tables (2 types: headers + lines)
        -- Headers — LOADED
        UPDATE DMT_OWNER.DMT_AP_INVOICES_INT_STG_TBL stg
        SET    stg.STG_STATUS            = 'LOADED',
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');
        -- Headers — FAILED
        UPDATE DMT_OWNER.DMT_AP_INVOICES_INT_STG_TBL stg
        SET    stg.STG_STATUS            = 'FAILED',
               stg.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                    AND    t.RUN_ID  = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');

        -- Lines — LOADED
        UPDATE DMT_OWNER.DMT_AP_INVOICE_LINES_INT_STG_TBL stg
        SET    stg.STG_STATUS            = 'LOADED',
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_AP_INVOICE_LINES_INT_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');
        -- Lines — FAILED
        UPDATE DMT_OWNER.DMT_AP_INVOICE_LINES_INT_STG_TBL stg
        SET    stg.STG_STATUS            = 'FAILED',
               stg.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_AP_INVOICE_LINES_INT_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                    AND    t.RUN_ID  = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_AP_INVOICE_LINES_INT_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');

        -- NO COMMIT — orchestrator controls transaction boundaries

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' complete. Headers LOADED: ' || l_loaded ||
                                ', FAILED: ' || l_failed || '.',
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
    PROCEDURE SWEEP_UNACCOUNTED (p_run_id IN NUMBER, p_work_queue_id IN NUMBER DEFAULT NULL) IS
    BEGIN
        -- <<EDIT-TABLE — CHANGE BELOW: the object's TFM table name. Repeat this
        --   whole UPDATE block (EDIT-TABLE through the ';') once per TFM table
        --   the object owns.>>
        UPDATE DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL
        -- <<END EDIT-TABLE — everything below is FIXED until EDIT-MSG>>
        SET    TFM_STATUS           = 'FAILED',
               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
        -- <<EDIT-MSG — CHANGE BELOW: the message text. It MUST begin with the
        --   literal '[RECONCILE_ERROR] ' tag.>>
                   '[RECONCILE_ERROR] AP invoice header not confirmed in Fusion '
                   || '(neither the AP_INVOICES_ALL base table nor the AP import '
                   || 'interface) after reconciliation; import outcome could not be verified.'
        -- <<END EDIT-MSG — everything below is FIXED until EDIT-SCOPE>>
               ),
               RESULTS_UPDATED_DATE = SYSDATE,
               LAST_UPDATED_DATE    = SYSDATE
        WHERE  RUN_ID     = p_run_id
        AND    TFM_STATUS NOT IN ('LOADED','FAILED')
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id)  -- work-queue-ID core: sweep only this item's rows
        -- (EDIT-SCOPE deleted — DMT_AP_INVOICES_INT_TFM_TBL is not shared.)
        ;

        -- <<EDIT-TABLE — CHANGE BELOW: the object's TFM table name. Repeat this
        --   whole UPDATE block (EDIT-TABLE through the ';') once per TFM table
        --   the object owns.>>
        UPDATE DMT_OWNER.DMT_AP_INVOICE_LINES_INT_TFM_TBL
        -- <<END EDIT-TABLE — everything below is FIXED until EDIT-MSG>>
        SET    TFM_STATUS           = 'FAILED',
               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
        -- <<EDIT-MSG — CHANGE BELOW: the message text. It MUST begin with the
        --   literal '[RECONCILE_ERROR] ' tag.>>
                   '[RECONCILE_ERROR] AP invoice line not confirmed loaded in Fusion '
                   || 'after reconciliation (its header was not confirmed, or the line '
                   || 'itself was not accounted); import outcome could not be verified.'
        -- <<END EDIT-MSG — everything below is FIXED until EDIT-SCOPE>>
               ),
               RESULTS_UPDATED_DATE = SYSDATE,
               LAST_UPDATED_DATE    = SYSDATE
        WHERE  RUN_ID     = p_run_id
        AND    TFM_STATUS NOT IN ('LOADED','FAILED')
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id)  -- work-queue-ID core: sweep only this item's rows
        -- (EDIT-SCOPE deleted — DMT_AP_INVOICE_LINES_INT_TFM_TBL is not shared.)
        ;
    END SWEEP_UNACCOUNTED;

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
            p_message        => C_PROC || ' start. load_ess_id: ' || p_load_ess_id,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        l_xml := FETCH_BIP_RESULTS(p_run_id, p_load_ess_id);
        PARSE_AND_UPDATE(p_run_id, l_xml);

        IF l_xml IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_xml) = 1 THEN
            DBMS_LOB.FREETEMPORARY(l_xml);
        END IF;

        -- Tier 2: Base table verification for rows still GENERATED after BIP.
        -- ap_invoices_interface purges successfully imported rows, so BIP Tier 1
        -- returns 0 for successes. Check ap_invoices_all via REST to confirm
        -- each invoice actually made it to the base table.
        DECLARE
            l_remaining NUMBER;
            l_loaded    NUMBER := 0;
            l_failed    NUMBER := 0;
            l_rest_json CLOB;
            l_error_msg VARCHAR2(4000);
        BEGIN
            SELECT COUNT(*) INTO l_remaining
            FROM   DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS = 'GENERATED';

            IF l_remaining > 0 THEN
                DMT_UTIL_PKG.LOG(
                    p_run_id => p_run_id,
                    p_message        => 'Tier 2: ' || l_remaining ||
                                        ' AP invoices still GENERATED after BIP (interface table purged).' ||
                                        ' Verifying each against ap_invoices_all via REST.',
                    p_package        => C_PKG,
                    p_procedure      => C_PROC);

                FOR r IN (
                    SELECT TFM_SEQUENCE_ID, INVOICE_NUM
                    FROM   DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL
                    WHERE  RUN_ID = p_run_id
                    AND    TFM_STATUS = 'GENERATED'
                ) LOOP
                    BEGIN
                        l_rest_json := DMT_REST_LOOKUP_PKG.LOOKUP_RECORD('APInvoices', r.INVOICE_NUM);

                        -- Check if REST found the record
                        l_error_msg := JSON_VALUE(l_rest_json, '$.error');

                        IF l_error_msg IS NULL THEN
                            -- Found in base table — extract InvoiceId
                            DECLARE
                                l_fusion_id VARCHAR2(100);
                            BEGIN
                                -- Parse first field value (InvoiceId)
                                l_fusion_id := JSON_VALUE(l_rest_json, '$.fields[0].value');
                                UPDATE DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL
                                SET    TFM_STATUS               = 'LOADED',
                                       FUSION_INVOICE_ID    = TO_NUMBER(l_fusion_id),
                                       RESULTS_UPDATED_DATE = SYSDATE,
                                       LAST_UPDATED_DATE    = SYSDATE
                                WHERE  TFM_SEQUENCE_ID      = r.TFM_SEQUENCE_ID;
                                l_loaded := l_loaded + 1;
                            END;
                        ELSE
                            -- Not found in base table after import — genuine failure
                            UPDATE DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL
                            SET    TFM_STATUS               = 'FAILED',
                                   ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                       '[FUSION_ERROR] Invoice not found in AP base table after import. ' ||
                                       'Import ESS succeeded but invoice was likely rejected during processing.'),
                                   RESULTS_UPDATED_DATE = SYSDATE,
                                   LAST_UPDATED_DATE    = SYSDATE
                            WHERE  TFM_SEQUENCE_ID      = r.TFM_SEQUENCE_ID;
                            l_failed := l_failed + 1;
                        END IF;
                    EXCEPTION
                        WHEN OTHERS THEN
                            -- REST call itself failed — mark FAILED with error
                            DECLARE
                                l_sqlerrm VARCHAR2(4000) := SQLERRM;
                            BEGIN
                                UPDATE DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL
                                SET    TFM_STATUS               = 'FAILED',
                                       ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                           '[FUSION_ERROR] Base table verification failed: ' || l_sqlerrm),
                                       RESULTS_UPDATED_DATE = SYSDATE,
                                       LAST_UPDATED_DATE    = SYSDATE
                                WHERE  TFM_SEQUENCE_ID      = r.TFM_SEQUENCE_ID;
                                l_failed := l_failed + 1;
                            END;
                    END;
                END LOOP;

                -- Cascade to lines based on header outcomes
                UPDATE DMT_OWNER.DMT_AP_INVOICE_LINES_INT_TFM_TBL ln
                SET    ln.TFM_STATUS = 'LOADED', ln.RESULTS_UPDATED_DATE = SYSDATE,
                       ln.LAST_UPDATED_DATE = SYSDATE
                WHERE  ln.RUN_ID = p_run_id
                AND    ln.TFM_STATUS != 'LOADED'
                AND    EXISTS (
                    SELECT 1 FROM DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL h
                    WHERE  h.RUN_ID = p_run_id
                    AND    h.INVOICE_ID = ln.INVOICE_ID AND h.TFM_STATUS = 'LOADED');

                UPDATE DMT_OWNER.DMT_AP_INVOICE_LINES_INT_TFM_TBL ln
                SET    ln.TFM_STATUS = 'FAILED',
                       ln.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ln.ERROR_TEXT,
                           '[FUSION_ERROR] Parent invoice not found in AP base table.'),
                       ln.RESULTS_UPDATED_DATE = SYSDATE, ln.LAST_UPDATED_DATE = SYSDATE
                WHERE  ln.RUN_ID = p_run_id
                AND    ln.TFM_STATUS NOT IN ('LOADED', 'FAILED')
                AND    EXISTS (
                    SELECT 1 FROM DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL h
                    WHERE  h.RUN_ID = p_run_id
                    AND    h.INVOICE_ID = ln.INVOICE_ID AND h.TFM_STATUS = 'FAILED');

                -- Echo to STG
                UPDATE DMT_OWNER.DMT_AP_INVOICES_INT_STG_TBL stg
                SET    stg.STG_STATUS = 'LOADED', stg.LAST_UPDATED_DATE = SYSDATE
                WHERE  stg.STG_SEQUENCE_ID IN (
                    SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL t
                    WHERE t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');
                UPDATE DMT_OWNER.DMT_AP_INVOICES_INT_STG_TBL stg
                SET    stg.STG_STATUS = 'FAILED',
                       stg.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                           (SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL t
                            WHERE t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                            AND t.RUN_ID = p_run_id)),
                       stg.LAST_UPDATED_DATE = SYSDATE
                WHERE  stg.STG_SEQUENCE_ID IN (
                    SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL t
                    WHERE t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');
                UPDATE DMT_OWNER.DMT_AP_INVOICE_LINES_INT_STG_TBL stg
                SET    stg.STG_STATUS = 'LOADED', stg.LAST_UPDATED_DATE = SYSDATE
                WHERE  stg.STG_SEQUENCE_ID IN (
                    SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_AP_INVOICE_LINES_INT_TFM_TBL t
                    WHERE t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');
                UPDATE DMT_OWNER.DMT_AP_INVOICE_LINES_INT_STG_TBL stg
                SET    stg.STG_STATUS = 'FAILED',
                       stg.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                           (SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_AP_INVOICE_LINES_INT_TFM_TBL t
                            WHERE t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                            AND t.RUN_ID = p_run_id)),
                       stg.LAST_UPDATED_DATE = SYSDATE
                WHERE  stg.STG_SEQUENCE_ID IN (
                    SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_AP_INVOICE_LINES_INT_TFM_TBL t
                    WHERE t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');

                DMT_UTIL_PKG.LOG(
                    p_run_id => p_run_id,
                    p_message        => 'Tier 2 complete. Base table verified: ' ||
                                        l_loaded || ' LOADED, ' || l_failed || ' FAILED.',
                    p_package        => C_PKG,
                    p_procedure      => C_PROC);
            END IF;
        END;

        -- Standard final step: fail any row still unaccounted (absence != LOADED).
        SWEEP_UNACCOUNTED(p_run_id, p_work_queue_id);

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

END DMT_AP_RESULTS_PKG;
/
