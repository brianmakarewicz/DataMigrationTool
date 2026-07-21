-- PACKAGE BODY DMT_REQ_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_REQ_RESULTS_PKG" 
AS
-- ============================================================
-- DMT_REQ_RESULTS_PKG body
-- Requisitions BIP reconciliation — Two-Tier pattern.
-- Tier 1: POR_REQ_HEADERS_INTERFACE_ALL (interface table, errors/status)
-- Tier 2: POR_REQUISITION_HEADERS_ALL (base table, positive confirmation)
-- No absence=LOADED fallback. Every row gets positive verification
-- or is marked FAILED with a reconciliation error.
--
-- Cascades header outcomes to lines and distributions TFM,
-- then echoes all outcomes back to all 3 STG tables.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_REQ_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'Requisitions';

    -- --------------------------------------------------------
    -- GET_PARTITION_KEYS — distinct BATCH_ID tokens for one run, STATIC SQL
    -- over the requisition-headers transform table (this object's own table).
    -- Spawn-per-partition (work-queue-ID core, 2026-07-20): one child work item
    -- per batch. Called through invoke_registered (style KEYS).
    -- --------------------------------------------------------
    FUNCTION GET_PARTITION_KEYS (
        p_run_id IN NUMBER
    ) RETURN DMT_OWNER.DMT_PARTITION_KEY_TBL IS
        l_keys DMT_OWNER.DMT_PARTITION_KEY_TBL;
    BEGIN
        -- One JSON object per distinct batch, keyed by the partition column name.
        SELECT DISTINCT JSON_OBJECT('BATCH_ID' VALUE TO_CHAR(BATCH_ID))
        BULK COLLECT INTO l_keys
        FROM   DMT_OWNER.DMT_POR_REQ_HEADERS_TFM_TBL
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'STAGED'
        AND    BATCH_ID IS NOT NULL;
        RETURN l_keys;
    END GET_PARTITION_KEYS;

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
    -- FETCH_BIP_RESULTS — passes P_IMPORT_ESS_ID as second parameter
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
    -- Parses BIP XML response (base64 reportBytes), updates
    -- Requisition header TFM rows, cascades to lines/dists,
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
        l_not_recon  NUMBER := 0;
        l_err_hdr    NUMBER := 0;
        l_err_line   NUMBER := 0;
        l_err_dist   NUMBER := 0;
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
            -- No reportBytes at all — BIP returned 0 rows from BOTH datasets.
            -- We could determine neither a base-table LOADED nor a real Fusion
            -- per-record error, so we do NOT fabricate a FAILED. The GENERATED
            -- header, line and distribution rows are left as-is (unaccounted);
            -- the accounting gate reports the object not-DONE and the funnel
            -- surfaces them as unreconciled.
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => C_PROC || ': No <reportBytes> in BIP response. ' ||
                                    'GENERATED rows left unaccounted (not marked FAILED).',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RETURN;
        END IF;

        -- ============================================================
        -- STEP 1: Process G_STATUS — determine header LOADED/FAILED
        --         (no error text written here — just tfm_status)
        -- ============================================================
        FOR r IN (
            SELECT x.interface_header_key,
                   x.requisition_number,
                   UPPER(x.source_type)   AS source_type,
                   UPPER(x.process_code)  AS process_code,
                   x.fusion_id
            FROM   XMLTABLE('/DATA_DS/G_STATUS' PASSING l_xml
                COLUMNS
                    interface_header_key VARCHAR2(50)   PATH 'INTERFACE_HEADER_KEY',
                    requisition_number   VARCHAR2(64)   PATH 'REQUISITION_NUMBER',
                    source_type          VARCHAR2(20)   PATH 'SOURCE_TYPE',
                    process_code         VARCHAR2(50)   PATH 'PROCESS_CODE',
                    fusion_id            NUMBER         PATH 'FUSION_ID'
            ) x
        ) LOOP
            IF r.source_type = 'BASE' THEN
                UPDATE DMT_OWNER.DMT_POR_REQ_HEADERS_TFM_TBL
                SET    TFM_STATUS               = 'LOADED',
                       FUSION_REQUISITION_HEADER_ID = r.fusion_id,
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID       = p_run_id
                AND    REQUISITION_NUMBER   = r.requisition_number
                AND    TFM_STATUS              NOT IN ('LOADED','FAILED');
                l_loaded := l_loaded + SQL%ROWCOUNT;

            ELSIF r.source_type = 'INTERFACE' THEN
                IF r.process_code IN ('ACCEPTED','PROCESSED','SUCCESS','COMPLETED') THEN
                    UPDATE DMT_OWNER.DMT_POR_REQ_HEADERS_TFM_TBL
                    SET    TFM_STATUS               = 'LOADED',
                           FUSION_REQUISITION_HEADER_ID = r.fusion_id,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    INTERFACE_HEADER_KEY  = r.interface_header_key
                    AND    TFM_STATUS              NOT IN ('LOADED','FAILED');
                    l_loaded := l_loaded + SQL%ROWCOUNT;
                ELSIF r.process_code IN ('ERROR','REJECTED','FAILED','FAILURE') THEN
                    -- Mark FAILED but do NOT write error text here.
                    -- Specific errors come from G_ERRORS in Step 2.
                    UPDATE DMT_OWNER.DMT_POR_REQ_HEADERS_TFM_TBL
                    SET    TFM_STATUS               = 'FAILED',
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    INTERFACE_HEADER_KEY  = r.interface_header_key
                    AND    TFM_STATUS              NOT IN ('LOADED','FAILED');
                    l_failed := l_failed + SQL%ROWCOUNT;
                ELSE
                    -- Unknown tfm_status — mark FAILED with tfm_status info
                    UPDATE DMT_OWNER.DMT_POR_REQ_HEADERS_TFM_TBL
                    SET    TFM_STATUS               = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                                     '[FUSION_ERROR] Unrecognized interface status: ' || NVL(r.process_code, 'NULL')),
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
        l_not_recon := 0;

        -- ============================================================
        -- STEP 2: Process G_ERRORS — write specific error messages
        --         to the exact TFM record that caused them.
        --         INTERFACE_TYPE: HEADER / LINE / DISTRIBUTION
        --         INTERFACE_KEY:  matches interface_header_key /
        --                         interface_line_key / interface_distribution_key
        -- ============================================================
        FOR e IN (
            SELECT x.interface_type,
                   x.interface_key,
                   x.error_msg
            FROM   XMLTABLE('/DATA_DS/G_ERRORS' PASSING l_xml
                COLUMNS
                    interface_type VARCHAR2(20)   PATH 'INTERFACE_TYPE',
                    interface_key  VARCHAR2(50)   PATH 'INTERFACE_KEY',
                    error_msg      VARCHAR2(4000) PATH 'ERROR_MESSAGE'
            ) x
        ) LOOP
            IF UPPER(e.interface_type) = 'HEADER' THEN
                UPDATE DMT_OWNER.DMT_POR_REQ_HEADERS_TFM_TBL
                SET    ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                                 '[FUSION_ERROR] [HDR] ' || e.error_msg),
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID       = p_run_id
                AND    INTERFACE_HEADER_KEY  = e.interface_key;
                l_err_hdr := l_err_hdr + SQL%ROWCOUNT;

            ELSIF UPPER(e.interface_type) = 'LINE' THEN
                UPDATE DMT_OWNER.DMT_POR_REQ_LINES_TFM_TBL
                SET    ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                                 '[FUSION_ERROR] [LINE] ' || e.error_msg),
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID       = p_run_id
                AND    INTERFACE_LINE_KEY    = e.interface_key;
                l_err_line := l_err_line + SQL%ROWCOUNT;

            ELSIF UPPER(e.interface_type) = 'DISTRIBUTION' THEN
                UPDATE DMT_OWNER.DMT_POR_REQ_DISTS_TFM_TBL
                SET    ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                                 '[FUSION_ERROR] [DIST] ' || e.error_msg),
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID       = p_run_id
                AND    INTERFACE_DISTRIBUTION_KEY = e.interface_key;
                l_err_dist := l_err_dist + SQL%ROWCOUNT;
            END IF;
        END LOOP;

        -- ============================================================
        -- STEP 3: Bottom-up cascade — propagate child errors upward.
        --         Errors always APPEND (concatenate), never overwrite.
        -- ============================================================

        -- 3a. Dists with errors → mark parent LINE as FAILED + append message
        UPDATE DMT_OWNER.DMT_POR_REQ_LINES_TFM_TBL ln
        SET    ln.TFM_STATUS            = 'FAILED',
               ln.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(ln.ERROR_TEXT,
                   '[FUSION_ERROR] Child distribution rejected by Fusion. See distribution details.'),
               ln.RESULTS_UPDATED_DATE = SYSDATE,
               ln.LAST_UPDATED_DATE = SYSDATE
        WHERE  ln.RUN_ID    = p_run_id
        AND    ln.TFM_STATUS           NOT IN ('LOADED','FAILED')
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_POR_REQ_DISTS_TFM_TBL d
            WHERE  d.RUN_ID    = p_run_id
            AND    d.INTERFACE_LINE_KEY = ln.INTERFACE_LINE_KEY
            AND    d.ERROR_TEXT        IS NOT NULL);

        -- 3b. Lines with errors (own or from 3a) → append message to parent HEADER.
        --     Header may already be FAILED from Step 1 — just append error context.
        UPDATE DMT_OWNER.DMT_POR_REQ_HEADERS_TFM_TBL h
        SET    h.ERROR_TEXT         = DMT_UTIL_PKG.APPEND_ERROR(h.ERROR_TEXT,
                   '[FUSION_ERROR] Child line rejected by Fusion. See line details.'),
               h.RESULTS_UPDATED_DATE = SYSDATE,
               h.LAST_UPDATED_DATE = SYSDATE
        WHERE  h.RUN_ID    = p_run_id
        AND    h.TFM_STATUS            = 'FAILED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_POR_REQ_LINES_TFM_TBL ln
            WHERE  ln.RUN_ID      = p_run_id
            AND    ln.INTERFACE_HEADER_KEY = h.INTERFACE_HEADER_KEY
            AND    ln.ERROR_TEXT          IS NOT NULL);

        -- ============================================================
        -- STEP 4: Top-down cascade LOADED to children of LOADED headers
        -- ============================================================
        UPDATE DMT_OWNER.DMT_POR_REQ_LINES_TFM_TBL ln
        SET    ln.TFM_STATUS            = 'LOADED',
               ln.RESULTS_UPDATED_DATE = SYSDATE,
               ln.LAST_UPDATED_DATE = SYSDATE
        WHERE  ln.RUN_ID    = p_run_id
        AND    ln.TFM_STATUS           NOT IN ('LOADED','FAILED')
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_POR_REQ_HEADERS_TFM_TBL h
            WHERE  h.RUN_ID      = p_run_id
            AND    h.INTERFACE_HEADER_KEY = ln.INTERFACE_HEADER_KEY
            AND    h.TFM_STATUS              = 'LOADED');

        UPDATE DMT_OWNER.DMT_POR_REQ_DISTS_TFM_TBL d
        SET    d.TFM_STATUS            = 'LOADED',
               d.RESULTS_UPDATED_DATE = SYSDATE,
               d.LAST_UPDATED_DATE = SYSDATE
        WHERE  d.RUN_ID    = p_run_id
        AND    d.TFM_STATUS           NOT IN ('LOADED','FAILED')
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_POR_REQ_LINES_TFM_TBL ln
            WHERE  ln.RUN_ID    = p_run_id
            AND    ln.INTERFACE_LINE_KEY = d.INTERFACE_LINE_KEY
            AND    ln.TFM_STATUS            = 'LOADED');

        -- ============================================================
        -- STEP 5: Top-down cascade FAILED for remaining GENERATED children.
        --         These have no errors of their own and weren't resolved
        --         by bottom-up. Point to the correct parent level.
        -- ============================================================

        -- 5a. Lines still GENERATED under FAILED headers — only if they
        --     don't already have their own error text (from Step 2 or 3a)
        UPDATE DMT_OWNER.DMT_POR_REQ_LINES_TFM_TBL ln
        SET    ln.TFM_STATUS            = 'FAILED',
               ln.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(ln.ERROR_TEXT,
                   '[FUSION_ERROR] Parent requisition header was rejected by Fusion. See header details.'),
               ln.RESULTS_UPDATED_DATE = SYSDATE,
               ln.LAST_UPDATED_DATE = SYSDATE
        WHERE  ln.RUN_ID    = p_run_id
        AND    ln.TFM_STATUS           NOT IN ('LOADED','FAILED')
        AND    ln.ERROR_TEXT       IS NULL
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_POR_REQ_HEADERS_TFM_TBL h
            WHERE  h.RUN_ID      = p_run_id
            AND    h.INTERFACE_HEADER_KEY = ln.INTERFACE_HEADER_KEY
            AND    h.TFM_STATUS              = 'FAILED');

        -- 5a2. Lines with their own error that are still GENERATED: just set FAILED
        UPDATE DMT_OWNER.DMT_POR_REQ_LINES_TFM_TBL ln
        SET    ln.TFM_STATUS            = 'FAILED',
               ln.RESULTS_UPDATED_DATE = SYSDATE,
               ln.LAST_UPDATED_DATE = SYSDATE
        WHERE  ln.RUN_ID    = p_run_id
        AND    ln.TFM_STATUS           NOT IN ('LOADED','FAILED')
        AND    ln.ERROR_TEXT       IS NOT NULL;

        -- 5b. Dists still GENERATED under FAILED lines — only if no own error
        UPDATE DMT_OWNER.DMT_POR_REQ_DISTS_TFM_TBL d
        SET    d.TFM_STATUS            = 'FAILED',
               d.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(d.ERROR_TEXT,
                   '[FUSION_ERROR] Parent requisition line was rejected by Fusion. See line details.'),
               d.RESULTS_UPDATED_DATE = SYSDATE,
               d.LAST_UPDATED_DATE = SYSDATE
        WHERE  d.RUN_ID    = p_run_id
        AND    d.TFM_STATUS           NOT IN ('LOADED','FAILED')
        AND    d.ERROR_TEXT       IS NULL
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_POR_REQ_LINES_TFM_TBL ln
            WHERE  ln.RUN_ID    = p_run_id
            AND    ln.INTERFACE_LINE_KEY = d.INTERFACE_LINE_KEY
            AND    ln.TFM_STATUS            = 'FAILED');

        -- 5b2. Dists with their own error that are still GENERATED: just set FAILED
        UPDATE DMT_OWNER.DMT_POR_REQ_DISTS_TFM_TBL d
        SET    d.TFM_STATUS            = 'FAILED',
               d.RESULTS_UPDATED_DATE = SYSDATE,
               d.LAST_UPDATED_DATE = SYSDATE
        WHERE  d.RUN_ID    = p_run_id
        AND    d.TFM_STATUS           NOT IN ('LOADED','FAILED')
        AND    d.ERROR_TEXT       IS NOT NULL;

        <<echo_to_stg>>
        -- ============================================================
        -- STEP 5: Echo outcomes back to STG tables (all 3 types)
        -- ============================================================
        -- Headers
        UPDATE DMT_OWNER.DMT_POR_REQ_HEADERS_STG_TBL stg
        SET    stg.STG_STATUS            = 'LOADED',
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_POR_REQ_HEADERS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');
        UPDATE DMT_OWNER.DMT_POR_REQ_HEADERS_STG_TBL stg
        SET    stg.STG_STATUS            = 'FAILED',
               stg.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_POR_REQ_HEADERS_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                    AND    t.RUN_ID  = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_POR_REQ_HEADERS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');

        -- Lines
        UPDATE DMT_OWNER.DMT_POR_REQ_LINES_STG_TBL stg
        SET    stg.STG_STATUS            = 'LOADED',
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_POR_REQ_LINES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');
        UPDATE DMT_OWNER.DMT_POR_REQ_LINES_STG_TBL stg
        SET    stg.STG_STATUS            = 'FAILED',
               stg.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_POR_REQ_LINES_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                    AND    t.RUN_ID  = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_POR_REQ_LINES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');

        -- Distributions
        UPDATE DMT_OWNER.DMT_POR_REQ_DISTS_STG_TBL stg
        SET    stg.STG_STATUS            = 'LOADED',
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_POR_REQ_DISTS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');
        UPDATE DMT_OWNER.DMT_POR_REQ_DISTS_STG_TBL stg
        SET    stg.STG_STATUS            = 'FAILED',
               stg.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_POR_REQ_DISTS_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                    AND    t.RUN_ID  = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_POR_REQ_DISTS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');

        -- NO COMMIT — orchestrator controls transaction boundaries

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' complete. Headers LOADED: ' || l_loaded ||
                                ', FAILED: ' || l_failed ||
                                ', NOT_RECONCILED: ' || l_not_recon ||
                                '. Errors attributed: HDR=' || l_err_hdr ||
                                ', LINE=' || l_err_line ||
                                ', DIST=' || l_err_dist || '.',
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

END DMT_REQ_RESULTS_PKG;
/
