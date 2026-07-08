-- PACKAGE BODY DMT_MISC_RECEIPT_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_MISC_RECEIPT_RESULTS_PKG" 
AS
-- ============================================================
-- DMT_MISC_RECEIPT_RESULTS_PKG body
-- Two-table reconciliation via BIP:
--   LOADED: rows in INV_MATERIAL_TXNS (base table) with positive TRANSACTION_ID.
--   FAILED: rows in INV_TRANSACTIONS_INTERFACE with PROCESS_FLAG=3 and error details.
-- Batch key: TRANSACTION_REFERENCE = 'DMT-{run_id}', SOURCE_CODE = 'DMT'.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_MISC_RECEIPT_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'MiscReceipts';

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
    -- P_BATCH_ID = 'DMT-{run_id}' (matches TRANSACTION_REFERENCE).
    -- Returns UNION ALL of LOADED rows from INV_MATERIAL_TXNS + FAILED rows from interface.
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
        l_batch_id   VARCHAR2(100);
        l_env        CLOB;
        l_resp       CLOB;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' start. CEMLI: ' || C_CEMLI || ' | run_id: ' || p_run_id,
            C_PKG, C_PROC);

        l_base_url := RTRIM(DMT_UTIL_PKG.GET_CONFIG('FUSION_URL'), '/');
        l_username := DMT_UTIL_PKG.GET_CONFIG('FUSION_USERNAME');
        l_password := DMT_UTIL_PKG.GET_CONFIG('FUSION_PASSWORD');

        IF l_base_url IS NULL OR l_username IS NULL OR l_password IS NULL THEN
            RAISE_APPLICATION_ERROR(-20031, C_PROC || ': Fusion connection config incomplete.');
        END IF;

        BEGIN
            SELECT REPORT_CATALOG_PATH INTO l_rpt_path
            FROM   DMT_OWNER.DMT_BIP_REPORT_TBL
            WHERE  CEMLI_CODE = C_CEMLI;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20032,
                    C_PROC || ': No row in DMT_BIP_REPORT_TBL for CEMLI_CODE=''' || C_CEMLI || '''.');
        END;

        l_url      := l_base_url || '/xmlpserver/services/v2/ReportService';
        l_batch_id := 'DMT-' || TO_CHAR(p_run_id);

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
            '              <v2:values><v2:item>' || l_batch_id || '</v2:item></v2:values>' ||
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

        DMT_UTIL_PKG.LOG(p_run_id,
            'BIP runReport request built. Report: ' || l_rpt_path || ' | P_BATCH_ID: ' || l_batch_id,
            C_PKG, C_PROC);

        l_resp := bip_soap_post(l_url, l_action, l_env);
        DBMS_LOB.FREETEMPORARY(l_env);

        IF DBMS_LOB.INSTR(l_resp, 'soapenv:Fault') > 0 OR
           DBMS_LOB.INSTR(l_resp, 'soap:Fault')    > 0 THEN
            RAISE_APPLICATION_ERROR(-20034,
                C_PROC || ': SOAP Fault. Report: ' || l_rpt_path ||
                ' | Response: ' || DBMS_LOB.SUBSTR(l_resp, 1000, 1));
        END IF;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. Response bytes: ' || DBMS_LOB.GETLENGTH(l_resp),
            C_PKG, C_PROC);

        RETURN l_resp;
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END FETCH_BIP_RESULTS;

    -- --------------------------------------------------------
    -- PARSE_AND_UPDATE
    -- BIP returns RESULT_STATUS = 'LOADED' or 'FAILED' per row.
    -- LOADED rows carry FUSION_ID (transaction_id from INV_MATERIAL_TXNS).
    -- FAILED rows carry ERROR_CODE + ERROR_EXPLANATION from interface.
    -- SOURCE_LINE_ID maps back to STG_SEQUENCE_ID in our TFM table.
    -- --------------------------------------------------------
    PROCEDURE PARSE_AND_UPDATE (
        p_run_id IN NUMBER,
        p_xml_data       IN CLOB
    ) IS
        C_PROC       CONSTANT VARCHAR2(30) := 'PARSE_AND_UPDATE';
        l_xml        XMLTYPE;
        l_failed     NUMBER := 0;
        l_loaded     NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, C_PROC || ' start.', C_PKG, C_PROC);

        -- Decode the BIP report via the shared helper (handles any size, no
        -- VARCHAR2(32767) truncation). Returns NULL when there are no rows.
        l_xml := DMT_UTIL_PKG.BIP_REPORT_XML(p_xml_data);
        IF l_xml IS NULL THEN
            -- No reportBytes at all — BIP returned nothing. Mark all GENERATED as FAILED (unknown).
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': No <reportBytes> in BIP response. Cannot reconcile.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);

            UPDATE DMT_OWNER.DMT_INV_TRX_TFM_TBL
            SET    TFM_STATUS = 'FAILED',
                   ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT, '[BIP] No reconciliation data returned'),
                   RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
            l_failed := SQL%ROWCOUNT;

            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ' complete. LOADED: 0, FAILED: ' || l_failed || '.',
                C_PKG, C_PROC);
            RETURN;
        END IF;

        -- Process each row from BIP: LOADED or FAILED based on RESULT_STATUS
        FOR r IN (
            SELECT x.result_status,
                   x.fusion_id,
                   x.source_line_id,
                   x.error_code,
                   x.error_explanation
            FROM   XMLTABLE('/DATA_DS/G_1' PASSING l_xml
                COLUMNS
                    result_status     VARCHAR2(10)   PATH 'RESULT_STATUS',
                    fusion_id         VARCHAR2(30)   PATH 'FUSION_ID',
                    source_line_id    VARCHAR2(30)   PATH 'SOURCE_LINE_ID',
                    error_code        VARCHAR2(240)  PATH 'ERROR_CODE',
                    error_explanation VARCHAR2(4000) PATH 'ERROR_EXPLANATION'
            ) x
        ) LOOP
            IF r.result_status = 'LOADED' THEN
                UPDATE DMT_OWNER.DMT_INV_TRX_TFM_TBL
                SET    TFM_STATUS           = 'LOADED',
                       FUSION_ID            = r.fusion_id,
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID  = p_run_id
                AND    STG_SEQUENCE_ID = TO_NUMBER(r.source_line_id)
                AND    TFM_STATUS     != 'LOADED';
                l_loaded := l_loaded + SQL%ROWCOUNT;

            ELSIF r.result_status = 'FAILED' THEN
                UPDATE DMT_OWNER.DMT_INV_TRX_TFM_TBL
                SET    TFM_STATUS           = 'FAILED',
                       ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                           '[FUSION_ERROR] ' || r.error_code || ': ' || r.error_explanation),
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID  = p_run_id
                AND    STG_SEQUENCE_ID = TO_NUMBER(r.source_line_id)
                AND    TFM_STATUS     != 'FAILED';
                l_failed := l_failed + SQL%ROWCOUNT;
            END IF;
        END LOOP;

        -- Echo to STG
        UPDATE DMT_OWNER.DMT_INV_TRX_STG_TBL stg
        SET    stg.STATUS = 'LOADED', stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_INV_TRX_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');

        UPDATE DMT_OWNER.DMT_INV_TRX_STG_TBL stg
        SET    stg.STATUS     = 'FAILED',
               stg.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_INV_TRX_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                    AND    t.RUN_ID  = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_INV_TRX_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. LOADED: ' || l_loaded || ', FAILED: ' || l_failed || '.',
            C_PKG, C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed.', SQLERRM, C_PKG, C_PROC);
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
        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' start. run_id: ' || p_run_id,
            C_PKG, C_PROC);

        l_xml := FETCH_BIP_RESULTS(p_run_id, p_load_ess_id);
        PARSE_AND_UPDATE(p_run_id, l_xml);

        IF l_xml IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_xml) = 1 THEN
            DBMS_LOB.FREETEMPORARY(l_xml);
        END IF;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete.', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RECONCILE_BATCH;

END DMT_MISC_RECEIPT_RESULTS_PKG;
/
