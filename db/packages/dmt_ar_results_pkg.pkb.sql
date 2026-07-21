-- PACKAGE BODY DMT_AR_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_AR_RESULTS_PKG" 
AS
-- ============================================================
-- DMT_AR_RESULTS_PKG body
-- ARInvoices BIP reconciliation.
-- Pattern: identical to DMT_PO_RESULTS_PKG.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_AR_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'ARInvoices';

    -- --------------------------------------------------------
    -- Private: POST a SOAP envelope; return full response CLOB.
    -- (Same helper as PO results -- duplicated to keep packages independent.)
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
    -- AR lines TFM rows, cascades to distributions,
    -- then echoes back to STG tables.
    --
    -- BIP XML has rows from RA_INTERFACE_LINES_ALL.
    -- Key columns: INTERFACE_LINE_ATTRIBUTE1, TRX_NUMBER,
    --   CUSTOMER_TRX_ID, INTERFACE_STATUS (null=pending,
    --   P=processed=LOADED, others=FAILED), REQUEST_ID,
    --   INTERFACE_LINE_ID.
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

        -- Process line rows from BIP XML
        -- RA_INTERFACE_LINES_ALL: INTERFACE_STATUS = 'P' means processed (LOADED),
        -- NULL = pending, any other value = FAILED.
        FOR r IN (
            SELECT x.interface_line_attribute1,
                   x.trx_number,
                   x.customer_trx_id,
                   x.interface_status,
                   x.interface_line_id,
                   x.request_id,
                   x.error_msg
            FROM   XMLTABLE('/DATA_DS/G_1' PASSING l_xml
                COLUMNS
                    interface_line_attribute1 VARCHAR2(150)  PATH 'INTERFACE_LINE_ATTRIBUTE1',
                    trx_number               VARCHAR2(30)   PATH 'TRX_NUMBER',
                    customer_trx_id          VARCHAR2(20)   PATH 'CUSTOMER_TRX_ID',
                    interface_status         VARCHAR2(1)    PATH 'INTERFACE_STATUS',
                    interface_line_id        VARCHAR2(20)   PATH 'INTERFACE_LINE_ID',
                    request_id               VARCHAR2(20)   PATH 'REQUEST_ID',
                    error_msg                VARCHAR2(4000) PATH 'ERROR_MESSAGE'
            ) x
        ) LOOP
            IF UPPER(r.interface_status) = 'P' OR r.customer_trx_id IS NOT NULL THEN
                -- Processed (tfm_status=P) or transaction created (customer_trx_id populated) = LOADED
                UPDATE DMT_OWNER.DMT_RA_LINES_TFM_TBL
                SET    TFM_STATUS                = 'LOADED',
                       FUSION_CUSTOMER_TRX_ID = TO_NUMBER(r.customer_trx_id),
                       FUSION_TRX_NUMBER     = r.trx_number,
                       RESULTS_UPDATED_DATE  = SYSDATE,
                       LAST_UPDATED_DATE     = SYSDATE
                WHERE  RUN_ID        = p_run_id
                AND    INTERFACE_LINE_ATTRIBUTE1 = r.interface_line_attribute1
                AND    TFM_STATUS               != 'LOADED';
                l_loaded := l_loaded + SQL%ROWCOUNT;
            ELSE
                -- NULL or any non-P interface status. Only mark FAILED when the BIP
                -- report carried a real Fusion error message (r.error_msg). A NULL
                -- interface status is pending, not a rejection, and gives us no real
                -- Fusion error: leave the row GENERATED for the honest sweep to mark
                -- UNACCOUNTED.
                IF r.error_msg IS NOT NULL THEN
                    UPDATE DMT_OWNER.DMT_RA_LINES_TFM_TBL
                    SET    TFM_STATUS               = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                                     '[FUSION_ERROR] ' || r.error_msg),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    INTERFACE_LINE_ATTRIBUTE1 = r.interface_line_attribute1
                    AND    TFM_STATUS              != 'FAILED';
                    l_failed := l_failed + SQL%ROWCOUNT;
                END IF;
            END IF;
        END LOOP;

        -- Cascade LOADED to distribution TFM rows
        -- Distributions link to lines via INTERFACE_LINE_CONTEXT + INTERFACE_LINE_ATTRIBUTE1.
        UPDATE DMT_OWNER.DMT_RA_DISTS_TFM_TBL d
        SET    d.TFM_STATUS              = 'LOADED',
               d.RESULTS_UPDATED_DATE = SYSDATE,
               d.LAST_UPDATED_DATE  = SYSDATE
        WHERE  d.RUN_ID     = p_run_id
        AND    d.TFM_STATUS            != 'LOADED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_RA_LINES_TFM_TBL ln
            WHERE  ln.RUN_ID           = p_run_id
            AND    ln.INTERFACE_LINE_CONTEXT    = d.INTERFACE_LINE_CONTEXT
            AND    ln.INTERFACE_LINE_ATTRIBUTE1 = d.INTERFACE_LINE_ATTRIBUTE1
            AND    ln.TFM_STATUS                    = 'LOADED');

        -- Cascade FAILED to distribution TFM rows. The parent line only reaches
        -- FAILED with a real Fusion error (r.error_msg from the BIP report), so the
        -- distribution carries that same real parent error in the prescribed
        -- linked-record form.
        UPDATE DMT_OWNER.DMT_RA_DISTS_TFM_TBL d
        SET    d.TFM_STATUS              = 'FAILED',
               d.ERROR_TEXT          = DMT_UTIL_PKG.APPEND_ERROR(d.ERROR_TEXT,
                   '[FUSION_ERROR]The parent record has the following Fusion error: ' ||
                   (SELECT ln.ERROR_TEXT FROM DMT_OWNER.DMT_RA_LINES_TFM_TBL ln
                    WHERE  ln.RUN_ID           = p_run_id
                    AND    ln.INTERFACE_LINE_CONTEXT    = d.INTERFACE_LINE_CONTEXT
                    AND    ln.INTERFACE_LINE_ATTRIBUTE1 = d.INTERFACE_LINE_ATTRIBUTE1
                    AND    ln.TFM_STATUS                    = 'FAILED'
                    AND    ROWNUM = 1)),
               d.RESULTS_UPDATED_DATE = SYSDATE,
               d.LAST_UPDATED_DATE  = SYSDATE
        WHERE  d.RUN_ID     = p_run_id
        AND    d.TFM_STATUS            != 'FAILED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_RA_LINES_TFM_TBL ln
            WHERE  ln.RUN_ID           = p_run_id
            AND    ln.INTERFACE_LINE_CONTEXT    = d.INTERFACE_LINE_CONTEXT
            AND    ln.INTERFACE_LINE_ATTRIBUTE1 = d.INTERFACE_LINE_ATTRIBUTE1
            AND    ln.TFM_STATUS                    = 'FAILED');

        -- Echo outcomes back to STG tables (both lines and distributions)
        -- Lines: LOADED
        UPDATE DMT_OWNER.DMT_RA_LINES_STG_TBL stg
        SET    stg.STG_STATUS            = 'LOADED',
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_RA_LINES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');
        -- Lines: FAILED
        UPDATE DMT_OWNER.DMT_RA_LINES_STG_TBL stg
        SET    stg.STG_STATUS            = 'FAILED',
               stg.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_RA_LINES_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                    AND    t.RUN_ID  = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_RA_LINES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');

        -- Distributions: LOADED
        UPDATE DMT_OWNER.DMT_RA_DISTS_STG_TBL stg
        SET    stg.STG_STATUS            = 'LOADED',
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_RA_DISTS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');
        -- Distributions: FAILED
        UPDATE DMT_OWNER.DMT_RA_DISTS_STG_TBL stg
        SET    stg.STG_STATUS            = 'FAILED',
               stg.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_RA_DISTS_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                    AND    t.RUN_ID  = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_RA_DISTS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');

        -- NO COMMIT — orchestrator controls transaction boundaries

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' complete. Lines LOADED: ' || l_loaded ||
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

END DMT_AR_RESULTS_PKG;
/
