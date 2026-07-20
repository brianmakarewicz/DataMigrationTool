-- PACKAGE BODY DMT_PO_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_PO_RESULTS_PKG" 
AS
-- ============================================================
-- DMT_PO_RESULTS_PKG body
-- PurchaseOrders BIP reconciliation.
-- Pattern: identical to DMT_POZ_SUP_RESULTS_PKG.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_PO_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'PurchaseOrders';

    -- --------------------------------------------------------
    -- Private: POST a SOAP envelope; return full response CLOB.
    -- (Same helper as supplier results — duplicated to keep packages independent.)
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
            '            <v2:item>' ||
            '              <v2:name>P_IMPORT_ESS_ID</v2:name>' ||
            '              <v2:values><v2:item>' || NVL(TO_CHAR(p_import_ess_id), '') || '</v2:item></v2:values>' ||
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
    -- PO header TFM rows, cascades to lines/locs/dists,
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

        -- Process header rows from BIP XML — two-tier reconciliation.
        --   BASE  rows (from PO_HEADERS_ALL) positively confirm a load; match
        --         the TFM record on its prefixed DOCUMENT_NUM (= base SEGMENT1).
        --   INTERFACE rows are left in PO_HEADERS_INTERFACE: PROCESS_CODE
        --         ACCEPTED = success (match on INTERFACE_HEADER_KEY),
        --         REJECTED/ERROR = failed (write the error text).
        FOR r IN (
            SELECT x.interface_header_key,
                   x.document_num,
                   x.po_header_id,
                   UPPER(x.source_type)  AS source_type,
                   UPPER(x.process_code) AS process_code,
                   x.error_msg
            FROM   XMLTABLE('/DATA_DS/G_1' PASSING l_xml
                COLUMNS
                    interface_header_key VARCHAR2(50)   PATH 'INTERFACE_HEADER_KEY',
                    document_num         VARCHAR2(20)   PATH 'DOCUMENT_NUM',
                    po_header_id         VARCHAR2(20)   PATH 'PO_HEADER_ID',
                    source_type          VARCHAR2(20)   PATH 'SOURCE_TYPE',
                    process_code         VARCHAR2(50)   PATH 'PROCESS_CODE',
                    error_msg            VARCHAR2(4000) PATH 'ERROR_MESSAGE'
            ) x
        ) LOOP
            IF r.source_type = 'BASE' THEN
                -- Positive base-table confirmation. Key on the prefixed document
                -- number the loader wrote, which equals the base SEGMENT1.
                UPDATE DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL
                SET    TFM_STATUS               = 'LOADED',
                       FUSION_PO_HEADER_ID  = TO_NUMBER(r.po_header_id),
                       FUSION_DOCUMENT_NUM  = r.document_num,
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID       = p_run_id
                AND    DOCUMENT_NUM          = r.document_num
                AND    TFM_STATUS              NOT IN ('LOADED','FAILED');
                l_loaded := l_loaded + SQL%ROWCOUNT;

            ELSIF r.source_type = 'INTERFACE' THEN
                IF r.process_code IN ('ACCEPTED','PROCESSED','SUCCESS','COMPLETED') THEN
                    UPDATE DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL
                    SET    TFM_STATUS               = 'LOADED',
                           FUSION_PO_HEADER_ID  = TO_NUMBER(r.po_header_id),
                           FUSION_DOCUMENT_NUM  = r.document_num,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    INTERFACE_HEADER_KEY  = r.interface_header_key
                    AND    TFM_STATUS              NOT IN ('LOADED','FAILED');
                    l_loaded := l_loaded + SQL%ROWCOUNT;
                ELSIF r.process_code IN ('ERROR','REJECTED','FAILED','FAILURE') THEN
                    UPDATE DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL
                    SET    TFM_STATUS               = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                                     '[FUSION_ERROR] ' || r.error_msg),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    INTERFACE_HEADER_KEY  = r.interface_header_key
                    AND    TFM_STATUS              NOT IN ('LOADED','FAILED');
                    l_failed := l_failed + SQL%ROWCOUNT;
                END IF;
            END IF;
        END LOOP;

        -- (No absence-!=-LOADED sweep: a record neither confirmed LOADED nor
        -- given a real Fusion error is left GENERATED (unaccounted). The
        -- accounting gate then reports the object not-DONE and the funnel
        -- surfaces it as UNRECONCILED — no fabricated FAILED.)

        -- Cascade LOADED to child TFM tables (lines/locs/dists)
        -- Lines: match on INTERFACE_HEADER_KEY
        UPDATE DMT_OWNER.DMT_PO_LINES_INT_TFM_TBL ln
        SET    ln.TFM_STATUS            = 'LOADED',
               ln.RESULTS_UPDATED_DATE = SYSDATE,
               ln.LAST_UPDATED_DATE = SYSDATE
        WHERE  ln.RUN_ID    = p_run_id
        AND    ln.TFM_STATUS           != 'LOADED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL h
            WHERE  h.RUN_ID      = p_run_id
            AND    h.INTERFACE_HEADER_KEY = ln.INTERFACE_HEADER_KEY
            AND    h.TFM_STATUS              = 'LOADED');

        -- Line locations: match via line's INTERFACE_LINE_KEY
        UPDATE DMT_OWNER.DMT_PO_LINE_LOCS_INT_TFM_TBL loc
        SET    loc.TFM_STATUS            = 'LOADED',
               loc.RESULTS_UPDATED_DATE = SYSDATE,
               loc.LAST_UPDATED_DATE = SYSDATE
        WHERE  loc.RUN_ID    = p_run_id
        AND    loc.TFM_STATUS           != 'LOADED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_PO_LINES_INT_TFM_TBL ln
            WHERE  ln.RUN_ID    = p_run_id
            AND    ln.INTERFACE_LINE_KEY = loc.INTERFACE_LINE_KEY
            AND    ln.TFM_STATUS            = 'LOADED');

        -- Distributions: match via loc's INTERFACE_LINE_LOCATION_KEY
        UPDATE DMT_OWNER.DMT_PO_DISTS_INT_TFM_TBL d
        SET    d.TFM_STATUS            = 'LOADED',
               d.RESULTS_UPDATED_DATE = SYSDATE,
               d.LAST_UPDATED_DATE = SYSDATE
        WHERE  d.RUN_ID    = p_run_id
        AND    d.TFM_STATUS           != 'LOADED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_PO_LINE_LOCS_INT_TFM_TBL loc
            WHERE  loc.RUN_ID              = p_run_id
            AND    loc.INTERFACE_LINE_LOCATION_KEY = d.INTERFACE_LINE_LOCATION_KEY
            AND    loc.TFM_STATUS                      = 'LOADED');

        -- Cascade FAILED to child TFM tables
        UPDATE DMT_OWNER.DMT_PO_LINES_INT_TFM_TBL ln
        SET    ln.TFM_STATUS            = 'FAILED',
               ln.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(ln.ERROR_TEXT,
                   '[FUSION_ERROR] Parent PO header ''' || ln.INTERFACE_HEADER_KEY || ''' was rejected by Fusion.'),
               ln.RESULTS_UPDATED_DATE = SYSDATE,
               ln.LAST_UPDATED_DATE = SYSDATE
        WHERE  ln.RUN_ID    = p_run_id
        AND    ln.TFM_STATUS           != 'FAILED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL h
            WHERE  h.RUN_ID      = p_run_id
            AND    h.INTERFACE_HEADER_KEY = ln.INTERFACE_HEADER_KEY
            AND    h.TFM_STATUS              = 'FAILED');

        UPDATE DMT_OWNER.DMT_PO_LINE_LOCS_INT_TFM_TBL loc
        SET    loc.TFM_STATUS            = 'FAILED',
               loc.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(loc.ERROR_TEXT,
                   '[FUSION_ERROR] Parent PO header was rejected by Fusion.'),
               loc.RESULTS_UPDATED_DATE = SYSDATE,
               loc.LAST_UPDATED_DATE = SYSDATE
        WHERE  loc.RUN_ID    = p_run_id
        AND    loc.TFM_STATUS           != 'FAILED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_PO_LINES_INT_TFM_TBL ln
            WHERE  ln.RUN_ID    = p_run_id
            AND    ln.INTERFACE_LINE_KEY = loc.INTERFACE_LINE_KEY
            AND    ln.TFM_STATUS            = 'FAILED');

        UPDATE DMT_OWNER.DMT_PO_DISTS_INT_TFM_TBL d
        SET    d.TFM_STATUS            = 'FAILED',
               d.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(d.ERROR_TEXT,
                   '[FUSION_ERROR] Parent PO header was rejected by Fusion.'),
               d.RESULTS_UPDATED_DATE = SYSDATE,
               d.LAST_UPDATED_DATE = SYSDATE
        WHERE  d.RUN_ID    = p_run_id
        AND    d.TFM_STATUS           != 'FAILED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_PO_LINE_LOCS_INT_TFM_TBL loc
            WHERE  loc.RUN_ID              = p_run_id
            AND    loc.INTERFACE_LINE_LOCATION_KEY = d.INTERFACE_LINE_LOCATION_KEY
            AND    loc.TFM_STATUS                      = 'FAILED');

        -- (Removed 2026-07-13, design section 5.) The reconciler no longer echoes
        -- outcomes back to the STG tables. Per the decided rule, STG carries a
        -- forward-only status (NEW -> TRANSFORMED/FAILED) written ONLY by the
        -- stage->transform step; LOADED is a TFM-only status and the TFM row is
        -- the sole record of the Fusion outcome. This mirrors the supplier
        -- reconciler (kept TFM-only) and the tranche-review H1 finding. Verified
        -- nothing downstream reads the PO STG LOADED status (the dependent
        -- validators read the upstream TFM row, per H2).

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
            p_message        => C_PROC || ' start. load_ess_id: ' || p_load_ess_id,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        -- Forward p_import_ess_id so the BIP report's P_IMPORT_ESS_ID is populated
        -- and the BASE tier (PO_HEADERS_ALL WHERE request_id = :P_IMPORT_ESS_ID) can
        -- confirm loaded POs. Without it the BASE tier never fires and every good PO
        -- whose interface row was purged falls through to the RECONCILE_ERROR catch-all.
        l_xml := FETCH_BIP_RESULTS(p_run_id, p_load_ess_id, p_import_ess_id);
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

END DMT_PO_RESULTS_PKG;
/
