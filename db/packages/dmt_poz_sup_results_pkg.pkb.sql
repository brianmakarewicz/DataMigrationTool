-- PACKAGE BODY DMT_POZ_SUP_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_POZ_SUP_RESULTS_PKG" AS
-- ============================================================
-- DMT_POZ_SUP_RESULTS_PKG Body
-- BIP v2 SOAP runReport reconciliation for all 5 supplier object types.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_POZ_SUP_RESULTS_PKG';

    -- --------------------------------------------------------
    -- Private: POST a SOAP envelope; return full response CLOB.
    -- BIP v2 uses username/password in SOAP body — no HTTP auth header.
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
    -- Private: extract a text value between simple XML tags using INSTR.
    -- Works on VARCHAR2 segments of the response.
    -- --------------------------------------------------------
    FUNCTION tag_value(p_text IN VARCHAR2, p_tag IN VARCHAR2) RETURN VARCHAR2 IS
        l_open  VARCHAR2(200) := '<' || p_tag || '>';
        l_close VARCHAR2(200) := '</' || p_tag || '>';
        l_start INTEGER;
        l_end   INTEGER;
    BEGIN
        l_start := INSTR(p_text, l_open);
        IF l_start = 0 THEN RETURN NULL; END IF;
        l_start := l_start + LENGTH(l_open);
        l_end   := INSTR(p_text, l_close, l_start);
        IF l_end = 0 THEN RETURN NULL; END IF;
        RETURN SUBSTR(p_text, l_start, l_end - l_start);
    END tag_value;

    -- --------------------------------------------------------
    -- FETCH_BIP_RESULTS
    -- Calls BIP v2 SOAP runReport with the CEMLI report path
    -- and P_BATCH_ID = p_run_id.
    -- Returns the raw SOAP XML response CLOB.
    -- --------------------------------------------------------
    FUNCTION FETCH_BIP_RESULTS (
        p_run_id  IN NUMBER,
        p_cemli_code      IN VARCHAR2,
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
            p_message        => 'FETCH_BIP_RESULTS start. CEMLI: ' || p_cemli_code,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        l_base_url := RTRIM(DMT_UTIL_PKG.GET_CONFIG('FUSION_URL'), '/');
        l_username := DMT_UTIL_PKG.GET_CONFIG('FUSION_USERNAME');
        l_password := DMT_UTIL_PKG.GET_CONFIG('FUSION_PASSWORD');

        IF l_base_url IS NULL OR l_username IS NULL OR l_password IS NULL THEN
            RAISE_APPLICATION_ERROR(-20031,
                'FETCH_BIP_RESULTS: Fusion connection config is incomplete. ' ||
                'Check FUSION_URL, FUSION_USERNAME, FUSION_PASSWORD in DMT_CONFIG_TBL.');
        END IF;

        BEGIN
            SELECT REPORT_CATALOG_PATH
            INTO   l_rpt_path
            FROM   DMT_OWNER.DMT_BIP_REPORT_TBL
            WHERE  CEMLI_CODE = p_cemli_code;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20032,
                    'FETCH_BIP_RESULTS: No row found in DMT_BIP_REPORT_TBL for CEMLI_CODE = ''' ||
                    p_cemli_code || '''.');
        END;

        IF l_rpt_path IS NULL THEN
            RAISE_APPLICATION_ERROR(-20033,
                'FETCH_BIP_RESULTS: REPORT_CATALOG_PATH is NULL for CEMLI_CODE = ''' ||
                p_cemli_code || '''.');
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
            p_message        => 'BIP runReport request: ' || DBMS_LOB.SUBSTR(l_env, 32767, 1),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        l_resp := bip_soap_post(l_url, l_action, l_env);
        DBMS_LOB.FREETEMPORARY(l_env);

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'BIP runReport full response: ' || DBMS_LOB.SUBSTR(l_resp, 32767, 1),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        IF DBMS_LOB.INSTR(l_resp, 'soapenv:Fault') > 0 OR
           DBMS_LOB.INSTR(l_resp, 'soap:Fault')    > 0 THEN
            RAISE_APPLICATION_ERROR(-20034,
                'FETCH_BIP_RESULTS: SOAP Fault from BIP runReport. CEMLI: ' || p_cemli_code ||
                ' | Report: ' || l_rpt_path ||
                ' | Response (first 1000): ' || DBMS_LOB.SUBSTR(l_resp, 1000, 1));
        END IF;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'FETCH_BIP_RESULTS complete. CEMLI: ' || p_cemli_code ||
                                ' | Response bytes: ' || DBMS_LOB.GETLENGTH(l_resp),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        RETURN l_resp;

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'FETCH_BIP_RESULTS failed. CEMLI: ' || p_cemli_code,
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END FETCH_BIP_RESULTS;

    -- --------------------------------------------------------
    -- PARSE_AND_UPDATE
    -- Parses the BIP XML SOAP response (base64-encoded reportBytes)
    -- and updates the appropriate staging table.
    --
    -- The decoded XML contains ROW elements under /DATA_DS/G_1/ROW.
    -- Parsed using XMLTYPE + XMLTable (supported on ATP 19c+).
    -- --------------------------------------------------------
    PROCEDURE PARSE_AND_UPDATE (
        p_run_id IN NUMBER,
        p_cemli_code     IN VARCHAR2,
        p_xml_data       IN CLOB
    ) IS
        C_PROC       CONSTANT VARCHAR2(30) := 'PARSE_AND_UPDATE';
        l_xml        XMLTYPE;
        l_loaded     NUMBER := 0;
        l_failed     NUMBER := 0;

        -- (b64_to_clob removed — base64 decode is now centralised in
        --  DMT_UTIL_PKG.BASE64_DECODE_CLOB / BIP_REPORT_XML, which decode CLOBs of
        --  any size. The old local copy truncated at VARCHAR2(32767).)

    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'PARSE_AND_UPDATE start. CEMLI: ' || p_cemli_code,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        -- Decode the BIP report via the shared helper (handles any size, no
        -- VARCHAR2(32767) truncation). Returns NULL when there are no rows.
        l_xml := DMT_UTIL_PKG.BIP_REPORT_XML(p_xml_data);
        IF l_xml IS NULL THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'PARSE_AND_UPDATE: No <reportBytes> in BIP response for CEMLI: ' ||
                                    p_cemli_code || '. No staging rows updated.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RETURN;
        END IF;

        -- Process rows using XMLTable — requires no legacy XMLSEQUENCE
        IF p_cemli_code = 'Suppliers' THEN
            FOR r IN (
                SELECT x.vendor_name, x.segment1,
                       x.vendor_id,
                       UPPER(x.fusion_status) AS fusion_status,
                       x.error_msg
                FROM   XMLTABLE('/DATA_DS/G_1' PASSING l_xml
                    COLUMNS
                        vendor_name    VARCHAR2(360)  PATH 'VENDOR_NAME',
                        segment1       VARCHAR2(30)   PATH 'SEGMENT1',
                        vendor_id      NUMBER         PATH 'VENDOR_ID',
                        fusion_status  VARCHAR2(50)   PATH 'STATUS',
                        error_msg      VARCHAR2(4000) PATH 'ERROR_MESSAGE'
                ) x
            ) LOOP
                IF r.fusion_status IN ('PROCESSED','SUCCESS','COMPLETED') THEN
                    UPDATE DMT_OWNER.DMT_POZ_SUPPLIERS_TFM_TBL
                    SET    STATUS               = 'LOADED',
                           FUSION_VENDOR_ID     = r.vendor_id,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    VENDOR_NAME          = r.vendor_name
                    AND    (SEGMENT1 = r.segment1 OR (SEGMENT1 IS NULL AND r.segment1 IS NULL))
                    AND    STATUS              != 'LOADED';
                    l_loaded := l_loaded + SQL%ROWCOUNT;
                ELSIF r.fusion_status IN ('ERROR','REJECTED','FAILED','FAILURE') THEN
                    UPDATE DMT_OWNER.DMT_POZ_SUPPLIERS_TFM_TBL
                    SET    STATUS               = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT, '[FUSION_ERROR] ' || r.error_msg),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    VENDOR_NAME          = r.vendor_name
                    AND    (SEGMENT1 = r.segment1 OR (SEGMENT1 IS NULL AND r.segment1 IS NULL))
                    AND    STATUS              != 'FAILED';
                    l_failed := l_failed + SQL%ROWCOUNT;
                END IF;
            END LOOP;
            -- Echo TFM outcomes back to staging
            UPDATE DMT_OWNER.DMT_POZ_SUPPLIERS_STG_TBL stg
            SET    stg.STATUS            = 'LOADED',
                   stg.LAST_UPDATED_DATE = SYSDATE
            WHERE  stg.STG_SEQUENCE_ID IN (
                SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_POZ_SUPPLIERS_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id AND t.STATUS = 'LOADED');
            UPDATE DMT_OWNER.DMT_POZ_SUPPLIERS_STG_TBL stg
            SET    stg.STATUS            = 'FAILED',
                   stg.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                       (SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_POZ_SUPPLIERS_TFM_TBL t
                        WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                        AND    t.RUN_ID  = p_run_id)),
                   stg.LAST_UPDATED_DATE = SYSDATE
            WHERE  stg.STG_SEQUENCE_ID IN (
                SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_POZ_SUPPLIERS_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id AND t.STATUS = 'FAILED');

        ELSIF p_cemli_code = 'SupplierAddresses' THEN
            FOR r IN (
                SELECT x.vendor_name, x.party_site_name,
                       x.party_site_id,
                       UPPER(x.fusion_status) AS fusion_status,
                       x.error_msg
                FROM   XMLTABLE('/DATA_DS/G_1' PASSING l_xml
                    COLUMNS
                        vendor_name      VARCHAR2(360)  PATH 'VENDOR_NAME',
                        party_site_name  VARCHAR2(240)  PATH 'PARTY_SITE_NAME',
                        party_site_id    NUMBER         PATH 'PARTY_SITE_ID',
                        fusion_status    VARCHAR2(50)   PATH 'STATUS',
                        error_msg        VARCHAR2(4000) PATH 'ERROR_MESSAGE'
                ) x
            ) LOOP
                IF r.fusion_status IN ('PROCESSED','SUCCESS','COMPLETED') THEN
                    UPDATE DMT_OWNER.DMT_POZ_SUP_ADDR_TFM_TBL
                    SET    STATUS               = 'LOADED',
                           FUSION_PARTY_SITE_ID = r.party_site_id,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    VENDOR_NAME          = r.vendor_name
                    AND    PARTY_SITE_NAME      = r.party_site_name
                    AND    STATUS              != 'LOADED';
                    l_loaded := l_loaded + SQL%ROWCOUNT;
                ELSIF r.fusion_status IN ('ERROR','REJECTED','FAILED','FAILURE') THEN
                    UPDATE DMT_OWNER.DMT_POZ_SUP_ADDR_TFM_TBL
                    SET    STATUS               = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT, '[FUSION_ERROR] ' || r.error_msg),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    VENDOR_NAME          = r.vendor_name
                    AND    PARTY_SITE_NAME      = r.party_site_name
                    AND    STATUS              != 'FAILED';
                    l_failed := l_failed + SQL%ROWCOUNT;
                END IF;
            END LOOP;
            -- Echo TFM outcomes back to staging
            UPDATE DMT_OWNER.DMT_POZ_SUP_ADDR_STG_TBL stg
            SET    stg.STATUS            = 'LOADED',
                   stg.LAST_UPDATED_DATE = SYSDATE
            WHERE  stg.STG_SEQUENCE_ID IN (
                SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_POZ_SUP_ADDR_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id AND t.STATUS = 'LOADED');
            UPDATE DMT_OWNER.DMT_POZ_SUP_ADDR_STG_TBL stg
            SET    stg.STATUS            = 'FAILED',
                   stg.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                       (SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_POZ_SUP_ADDR_TFM_TBL t
                        WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                        AND    t.RUN_ID  = p_run_id)),
                   stg.LAST_UPDATED_DATE = SYSDATE
            WHERE  stg.STG_SEQUENCE_ID IN (
                SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_POZ_SUP_ADDR_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id AND t.STATUS = 'FAILED');

        ELSIF p_cemli_code = 'SupplierSites' THEN
            FOR r IN (
                SELECT x.vendor_name, x.vendor_site_code,
                       x.vendor_site_id,
                       UPPER(x.fusion_status) AS fusion_status,
                       x.error_msg
                FROM   XMLTABLE('/DATA_DS/G_1' PASSING l_xml
                    COLUMNS
                        vendor_name      VARCHAR2(360)  PATH 'VENDOR_NAME',
                        vendor_site_code VARCHAR2(15)   PATH 'VENDOR_SITE_CODE',
                        vendor_site_id   NUMBER         PATH 'VENDOR_SITE_ID',
                        fusion_status    VARCHAR2(50)   PATH 'STATUS',
                        error_msg        VARCHAR2(4000) PATH 'ERROR_MESSAGE'
                ) x
            ) LOOP
                IF r.fusion_status IN ('PROCESSED','SUCCESS','COMPLETED') THEN
                    UPDATE DMT_OWNER.DMT_POZ_SUP_SITE_TFM_TBL
                    SET    STATUS               = 'LOADED',
                           FUSION_VENDOR_SITE_ID = r.vendor_site_id,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    VENDOR_NAME          = r.vendor_name
                    AND    VENDOR_SITE_CODE     = r.vendor_site_code
                    AND    STATUS              != 'LOADED';
                    l_loaded := l_loaded + SQL%ROWCOUNT;
                ELSIF r.fusion_status IN ('ERROR','REJECTED','FAILED','FAILURE') THEN
                    UPDATE DMT_OWNER.DMT_POZ_SUP_SITE_TFM_TBL
                    SET    STATUS               = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT, '[FUSION_ERROR] ' || r.error_msg),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    VENDOR_NAME          = r.vendor_name
                    AND    VENDOR_SITE_CODE     = r.vendor_site_code
                    AND    STATUS              != 'FAILED';
                    l_failed := l_failed + SQL%ROWCOUNT;
                END IF;
            END LOOP;
            -- Echo TFM outcomes back to staging
            UPDATE DMT_OWNER.DMT_POZ_SUP_SITE_STG_TBL stg
            SET    stg.STATUS            = 'LOADED',
                   stg.LAST_UPDATED_DATE = SYSDATE
            WHERE  stg.STG_SEQUENCE_ID IN (
                SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_POZ_SUP_SITE_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id AND t.STATUS = 'LOADED');
            UPDATE DMT_OWNER.DMT_POZ_SUP_SITE_STG_TBL stg
            SET    stg.STATUS            = 'FAILED',
                   stg.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                       (SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_POZ_SUP_SITE_TFM_TBL t
                        WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                        AND    t.RUN_ID  = p_run_id)),
                   stg.LAST_UPDATED_DATE = SYSDATE
            WHERE  stg.STG_SEQUENCE_ID IN (
                SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_POZ_SUP_SITE_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id AND t.STATUS = 'FAILED');

        ELSIF p_cemli_code = 'SupplierSiteAssignments' THEN
            FOR r IN (
                SELECT x.vendor_name, x.vendor_site_code, x.bu_name,
                       x.assignment_id,
                       UPPER(x.fusion_status) AS fusion_status,
                       x.error_msg
                FROM   XMLTABLE('/DATA_DS/G_1' PASSING l_xml
                    COLUMNS
                        vendor_name      VARCHAR2(360)  PATH 'VENDOR_NAME',
                        vendor_site_code VARCHAR2(15)   PATH 'VENDOR_SITE_CODE',
                        bu_name          VARCHAR2(240)  PATH 'BUSINESS_UNIT_NAME',
                        assignment_id    NUMBER         PATH 'ASSIGNMENT_ID',
                        fusion_status    VARCHAR2(50)   PATH 'STATUS',
                        error_msg        VARCHAR2(4000) PATH 'ERROR_MESSAGE'
                ) x
            ) LOOP
                IF r.fusion_status IN ('PROCESSED','SUCCESS','COMPLETED') THEN
                    UPDATE DMT_OWNER.DMT_POZ_SUP_SITE_ASSN_TFM_TBL
                    SET    STATUS               = 'LOADED',
                           FUSION_ASSIGNMENT_ID = r.assignment_id,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    VENDOR_NAME          = r.vendor_name
                    AND    VENDOR_SITE_CODE     = r.vendor_site_code
                    AND    BUSINESS_UNIT_NAME   = r.bu_name
                    AND    STATUS              != 'LOADED';
                    l_loaded := l_loaded + SQL%ROWCOUNT;
                ELSIF r.fusion_status IN ('ERROR','REJECTED','FAILED','FAILURE') THEN
                    UPDATE DMT_OWNER.DMT_POZ_SUP_SITE_ASSN_TFM_TBL
                    SET    STATUS               = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT, '[FUSION_ERROR] ' || r.error_msg),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    VENDOR_NAME          = r.vendor_name
                    AND    VENDOR_SITE_CODE     = r.vendor_site_code
                    AND    BUSINESS_UNIT_NAME   = r.bu_name
                    AND    STATUS              != 'FAILED';
                    l_failed := l_failed + SQL%ROWCOUNT;
                END IF;
            END LOOP;
            -- Echo TFM outcomes back to staging
            UPDATE DMT_OWNER.DMT_POZ_SUP_SITE_ASSN_STG_TBL stg
            SET    stg.STATUS            = 'LOADED',
                   stg.LAST_UPDATED_DATE = SYSDATE
            WHERE  stg.STG_SEQUENCE_ID IN (
                SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_POZ_SUP_SITE_ASSN_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id AND t.STATUS = 'LOADED');
            UPDATE DMT_OWNER.DMT_POZ_SUP_SITE_ASSN_STG_TBL stg
            SET    stg.STATUS            = 'FAILED',
                   stg.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                       (SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_POZ_SUP_SITE_ASSN_TFM_TBL t
                        WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                        AND    t.RUN_ID  = p_run_id)),
                   stg.LAST_UPDATED_DATE = SYSDATE
            WHERE  stg.STG_SEQUENCE_ID IN (
                SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_POZ_SUP_SITE_ASSN_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id AND t.STATUS = 'FAILED');

        ELSIF p_cemli_code = 'SupplierContacts' THEN
            FOR r IN (
                SELECT x.vendor_name, x.first_name, x.last_name,
                       x.contact_id,
                       UPPER(x.fusion_status) AS fusion_status,
                       x.error_msg
                FROM   XMLTABLE('/DATA_DS/G_1' PASSING l_xml
                    COLUMNS
                        vendor_name   VARCHAR2(360)  PATH 'VENDOR_NAME',
                        first_name    VARCHAR2(150)  PATH 'FIRST_NAME',
                        last_name     VARCHAR2(150)  PATH 'LAST_NAME',
                        contact_id    NUMBER         PATH 'CONTACT_ID',
                        fusion_status VARCHAR2(50)   PATH 'STATUS',
                        error_msg     VARCHAR2(4000) PATH 'ERROR_MESSAGE'
                ) x
            ) LOOP
                IF r.fusion_status IN ('PROCESSED','SUCCESS','COMPLETED') THEN
                    UPDATE DMT_OWNER.DMT_POZ_SUP_CONTACTS_TFM_TBL
                    SET    STATUS               = 'LOADED',
                           FUSION_CONTACT_ID    = r.contact_id,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    VENDOR_NAME          = r.vendor_name
                    AND    FIRST_NAME           = r.first_name
                    AND    LAST_NAME            = r.last_name
                    AND    STATUS              != 'LOADED';
                    l_loaded := l_loaded + SQL%ROWCOUNT;
                ELSIF r.fusion_status IN ('ERROR','REJECTED','FAILED','FAILURE') THEN
                    UPDATE DMT_OWNER.DMT_POZ_SUP_CONTACTS_TFM_TBL
                    SET    STATUS               = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT, '[FUSION_ERROR] ' || r.error_msg),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    VENDOR_NAME          = r.vendor_name
                    AND    FIRST_NAME           = r.first_name
                    AND    LAST_NAME            = r.last_name
                    AND    STATUS              != 'FAILED';
                    l_failed := l_failed + SQL%ROWCOUNT;
                END IF;
            END LOOP;
            -- Echo TFM outcomes back to staging
            UPDATE DMT_OWNER.DMT_POZ_SUP_CONTACTS_STG_TBL stg
            SET    stg.STATUS            = 'LOADED',
                   stg.LAST_UPDATED_DATE = SYSDATE
            WHERE  stg.STG_SEQUENCE_ID IN (
                SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_POZ_SUP_CONTACTS_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id AND t.STATUS = 'LOADED');
            UPDATE DMT_OWNER.DMT_POZ_SUP_CONTACTS_STG_TBL stg
            SET    stg.STATUS            = 'FAILED',
                   stg.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                       (SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_POZ_SUP_CONTACTS_TFM_TBL t
                        WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                        AND    t.RUN_ID  = p_run_id)),
                   stg.LAST_UPDATED_DATE = SYSDATE
            WHERE  stg.STG_SEQUENCE_ID IN (
                SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_POZ_SUP_CONTACTS_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id AND t.STATUS = 'FAILED');

        ELSE
            RAISE_APPLICATION_ERROR(-20037,
                'PARSE_AND_UPDATE: Unknown CEMLI_CODE = ''' || p_cemli_code ||
                '''. Valid values: Suppliers, SupplierAddresses, ' ||
                'SupplierSites, SupplierSiteAssignments, SupplierContacts');
        END IF;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'PARSE_AND_UPDATE complete. CEMLI: ' || p_cemli_code ||
                                ' | LOADED: ' || l_loaded || ' | FAILED: ' || l_failed,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'PARSE_AND_UPDATE failed. CEMLI: ' || p_cemli_code,
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END PARSE_AND_UPDATE;

    -- --------------------------------------------------------
    -- RECONCILE_BATCH
    -- Orchestrates FETCH then PARSE for one CEMLI.
    -- --------------------------------------------------------
    PROCEDURE RECONCILE_BATCH (
        p_run_id  IN NUMBER,
        p_cemli_code      IN VARCHAR2,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL
    ) IS
        C_PROC  CONSTANT VARCHAR2(30) := 'RECONCILE_BATCH';
        l_xml   CLOB;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'RECONCILE_BATCH start. CEMLI: ' || p_cemli_code ||
                                ' | Load ESS ID: ' || p_load_ess_id,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        l_xml := FETCH_BIP_RESULTS(p_run_id, p_cemli_code, p_load_ess_id);
        PARSE_AND_UPDATE(p_run_id, p_cemli_code, l_xml);

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'RECONCILE_BATCH complete. CEMLI: ' || p_cemli_code,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'RECONCILE_BATCH failed. CEMLI: ' || p_cemli_code,
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END RECONCILE_BATCH;

END DMT_POZ_SUP_RESULTS_PKG;
/
