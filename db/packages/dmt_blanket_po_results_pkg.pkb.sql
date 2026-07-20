-- PACKAGE BODY DMT_BLANKET_PO_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_BLANKET_PO_RESULTS_PKG" 
AS
-- ============================================================
-- DMT_BLANKET_PO_RESULTS_PKG body
-- BlanketPOs BIP reconciliation.
-- Pattern: identical to DMT_PO_RESULTS_PKG but scoped to
-- Blanket Purchase Agreement headers + lines only (no locs/dists).
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_BLANKET_PO_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'BlanketPOs';

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
    -- blanket PO header TFM rows, cascades to lines only
    -- (no locs/dists for blanket POs), then echoes back to STG.
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
        --   BASE  rows (from PO_HEADERS_ALL, TYPE_LOOKUP_CODE = 'BLANKET') positively
        --         confirm a load; match the TFM record on its prefixed DOCUMENT_NUM
        --         (= base SEGMENT1).
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

        -- (The absence != LOADED catch-all now lives in the standard
        -- SWEEP_UNACCOUNTED procedure, called at the end of RECONCILE_BATCH,
        -- scoped to blanket-style rows in the shared PO tables — see design §7.)

        -- Cascade LOADED to lines (no locs/dists for blanket POs)
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
            AND    h.TFM_STATUS              = 'LOADED'
            AND    h.STYLE_DISPLAY_NAME  = 'Blanket Purchase Agreement');

        -- Cascade FAILED to lines
        UPDATE DMT_OWNER.DMT_PO_LINES_INT_TFM_TBL ln
        SET    ln.TFM_STATUS            = 'FAILED',
               ln.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(ln.ERROR_TEXT,
                   '[FUSION_ERROR] Parent blanket PO header ''' || ln.INTERFACE_HEADER_KEY || ''' was rejected by Fusion.'),
               ln.RESULTS_UPDATED_DATE = SYSDATE,
               ln.LAST_UPDATED_DATE = SYSDATE
        WHERE  ln.RUN_ID    = p_run_id
        AND    ln.TFM_STATUS           != 'FAILED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL h
            WHERE  h.RUN_ID      = p_run_id
            AND    h.INTERFACE_HEADER_KEY = ln.INTERFACE_HEADER_KEY
            AND    h.TFM_STATUS              = 'FAILED'
            AND    h.STYLE_DISPLAY_NAME  = 'Blanket Purchase Agreement');

        -- (Removed 2026-07-13, design section 5.) No STG echo-back: STG carries a
        -- forward-only status written only by stage->transform; LOADED is TFM-only
        -- and the TFM row is the sole outcome record. BlanketPOs share the physical
        -- DMT_PO_HEADERS_INT_STG_TBL / DMT_PO_LINES_INT_STG_TBL with PurchaseOrders
        -- and Contracts, so echoing LOADED here would reintroduce the same illegal
        -- STG write PO just dropped.

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
        UPDATE DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL
        -- <<END EDIT-TABLE — everything below is FIXED until EDIT-MSG>>
        SET    TFM_STATUS           = 'FAILED',
               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
        -- <<EDIT-MSG — CHANGE BELOW: the message text. It MUST begin with the
        --   literal '[RECONCILE_ERROR] ' tag.>>
                   '[RECONCILE_ERROR] Blanket purchase agreement header not confirmed in '
                   || 'Fusion (neither the PO_HEADERS_ALL base table nor the PO import '
                   || 'interface) after reconciliation; import outcome could not be verified.'
        -- <<END EDIT-MSG — everything below is FIXED until EDIT-SCOPE>>
               ),
               RESULTS_UPDATED_DATE = SYSDATE,
               LAST_UPDATED_DATE    = SYSDATE
        WHERE  RUN_ID     = p_run_id
        AND    TFM_STATUS NOT IN ('LOADED','FAILED')
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id)  -- work-queue-ID core: sweep only this item's rows
        -- <<EDIT-SCOPE — OPTIONAL. CHANGE BELOW: one "AND <filter>" that is EXACTLY
        --   this object's ROW_FILTER for THIS table from DMT_CEMLI_CATALOG_TBL. Use
        --   ONLY when the object shares this TFM table with another object. If the
        --   table is NOT shared, delete everything from EDIT-SCOPE to END EDIT-SCOPE.>>
        AND    STYLE_DISPLAY_NAME = 'Blanket Purchase Agreement'
        -- <<END EDIT-SCOPE — nothing below this changes>>
        ;

        -- <<EDIT-TABLE — CHANGE BELOW: the object's TFM table name. Repeat this
        --   whole UPDATE block (EDIT-TABLE through the ';') once per TFM table
        --   the object owns.>>
        UPDATE DMT_OWNER.DMT_PO_LINES_INT_TFM_TBL
        -- <<END EDIT-TABLE — everything below is FIXED until EDIT-MSG>>
        SET    TFM_STATUS           = 'FAILED',
               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
        -- <<EDIT-MSG — CHANGE BELOW: the message text. It MUST begin with the
        --   literal '[RECONCILE_ERROR] ' tag.>>
                   '[RECONCILE_ERROR] Blanket purchase agreement line not confirmed loaded '
                   || 'in Fusion after reconciliation (its header was not confirmed, or the '
                   || 'line itself was not accounted); import outcome could not be verified.'
        -- <<END EDIT-MSG — everything below is FIXED until EDIT-SCOPE>>
               ),
               RESULTS_UPDATED_DATE = SYSDATE,
               LAST_UPDATED_DATE    = SYSDATE
        WHERE  RUN_ID     = p_run_id
        AND    TFM_STATUS NOT IN ('LOADED','FAILED')
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id)  -- work-queue-ID core: sweep only this item's rows
        -- <<EDIT-SCOPE — OPTIONAL. CHANGE BELOW: one "AND <filter>" that is EXACTLY
        --   this object's ROW_FILTER for THIS table from DMT_CEMLI_CATALOG_TBL. Use
        --   ONLY when the object shares this TFM table with another object. If the
        --   table is NOT shared, delete everything from EDIT-SCOPE to END EDIT-SCOPE.>>
        AND    INTERFACE_HEADER_KEY IN (SELECT INTERFACE_HEADER_KEY FROM DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL WHERE STYLE_DISPLAY_NAME = 'Blanket Purchase Agreement')
        -- <<END EDIT-SCOPE — nothing below this changes>>
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

        -- Forward p_import_ess_id so the BIP report's P_IMPORT_ESS_ID is populated
        -- and the BASE tier (PO_HEADERS_ALL WHERE request_id = :P_IMPORT_ESS_ID AND
        -- type_lookup_code = 'BLANKET') can confirm loaded blanket POs. Without it
        -- the BASE tier never fires and every good blanket PO whose interface row was
        -- purged falls through to the RECONCILE_ERROR catch-all.
        l_xml := FETCH_BIP_RESULTS(p_run_id, p_load_ess_id, p_import_ess_id);
        PARSE_AND_UPDATE(p_run_id, l_xml);

        -- Standard final step: fail any row still unaccounted (absence != LOADED).
        SWEEP_UNACCOUNTED(p_run_id, p_work_queue_id);

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

END DMT_BLANKET_PO_RESULTS_PKG;
/
