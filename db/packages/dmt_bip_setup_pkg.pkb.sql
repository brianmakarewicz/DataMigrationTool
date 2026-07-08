-- PACKAGE BODY DMT_BIP_SETUP_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_BIP_SETUP_PKG" AS
-- ============================================================
-- DMT_BIP_SETUP_PKG Body
-- BIP v2 SOAP session approach.
-- Modeled on APEX_QUERY_BIP_PKG from oracle-queryapp.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(30) := 'DMT_BIP_SETUP_PKG';

    -- --------------------------------------------------------
    -- Private: Fusion base URL (no trailing slash).
    -- --------------------------------------------------------
    FUNCTION fusion_base RETURN VARCHAR2 IS
    BEGIN
        RETURN RTRIM(DMT_UTIL_PKG.GET_CONFIG('FUSION_URL'), '/');
    END fusion_base;

    -- --------------------------------------------------------
    -- Private: BIP username from config.
    -- --------------------------------------------------------
    FUNCTION bip_username RETURN VARCHAR2 IS
    BEGIN
        RETURN DMT_UTIL_PKG.GET_CONFIG('FUSION_USERNAME');
    END bip_username;

    -- --------------------------------------------------------
    -- Private: POST a SOAP envelope; return full response as CLOB.
    -- No Authorization header — BIP v2 authenticates via session
    -- token in the SOAP body, not HTTP auth.
    -- Content-Length is always set (required by Fusion / nginx).
    -- --------------------------------------------------------
    FUNCTION soap_post (
        p_url      IN VARCHAR2,
        p_action   IN VARCHAR2,
        p_envelope IN CLOB
    ) RETURN CLOB IS
        l_req  UTL_HTTP.REQ;
        l_resp UTL_HTTP.RESP;
        l_buf  VARCHAR2(32767);
        l_out  CLOB;
        l_len  PLS_INTEGER;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_out, TRUE);

        UTL_HTTP.SET_RESPONSE_ERROR_CHECK(FALSE);
        UTL_HTTP.SET_TRANSFER_TIMEOUT(120);

        l_req := UTL_HTTP.BEGIN_REQUEST(p_url, 'POST', 'HTTP/1.1');
        UTL_HTTP.SET_HEADER(l_req, 'Content-Type', 'text/xml;charset=UTF-8');
        UTL_HTTP.SET_HEADER(l_req, 'SOAPAction',   p_action);

        l_len := DBMS_LOB.GETLENGTH(p_envelope);
        UTL_HTTP.SET_HEADER(l_req, 'Content-Length', TO_CHAR(l_len));
        UTL_HTTP.WRITE_TEXT(l_req, p_envelope);

        l_resp := UTL_HTTP.GET_RESPONSE(l_req);

        LOOP
            UTL_HTTP.READ_TEXT(l_resp, l_buf, 32767);
            DBMS_LOB.WRITEAPPEND(l_out, LENGTH(l_buf), l_buf);
        END LOOP;

    EXCEPTION
        WHEN UTL_HTTP.END_OF_BODY THEN
            UTL_HTTP.END_RESPONSE(l_resp);
            RETURN l_out;
        WHEN OTHERS THEN
            BEGIN UTL_HTTP.END_RESPONSE(l_resp); EXCEPTION WHEN OTHERS THEN NULL; END;
            RAISE;
    END soap_post;

    -- --------------------------------------------------------
    -- Private: CLOB -> BLOB (AL32UTF8).
    -- --------------------------------------------------------
    FUNCTION clob_to_blob_utf8 (p_clob IN CLOB) RETURN BLOB IS
        l_blob     BLOB;
        l_dest_off INTEGER := 1;
        l_src_off  INTEGER := 1;
        l_lang_ctx INTEGER := DBMS_LOB.DEFAULT_LANG_CTX;
        l_warning  INTEGER;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_blob, TRUE);
        DBMS_LOB.CONVERTTOBLOB(
            dest_lob     => l_blob,
            src_clob     => p_clob,
            amount       => DBMS_LOB.LOBMAXSIZE,
            dest_offset  => l_dest_off,
            src_offset   => l_src_off,
            blob_csid    => NLS_CHARSET_ID('AL32UTF8'),
            lang_context => l_lang_ctx,
            warning      => l_warning
        );
        RETURN l_blob;
    END clob_to_blob_utf8;

    -- --------------------------------------------------------
    -- Private: BLOB -> CLOB (AL32UTF8).
    -- --------------------------------------------------------
    FUNCTION blob_to_clob_utf8 (p_blob IN BLOB) RETURN CLOB IS
        l_clob     CLOB;
        l_dest_off INTEGER := 1;
        l_src_off  INTEGER := 1;
        l_lang_ctx INTEGER := DBMS_LOB.DEFAULT_LANG_CTX;
        l_warning  INTEGER;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_clob, TRUE);
        DBMS_LOB.CONVERTTOCLOB(
            dest_lob     => l_clob,
            src_blob     => p_blob,
            amount       => DBMS_LOB.LOBMAXSIZE,
            dest_offset  => l_dest_off,
            src_offset   => l_src_off,
            blob_csid    => NLS_CHARSET_ID('AL32UTF8'),
            lang_context => l_lang_ctx,
            warning      => l_warning
        );
        RETURN l_clob;
    END blob_to_clob_utf8;

    -- --------------------------------------------------------
    -- Private: base64-encode a CLOB.
    -- Converts to BLOB (AL32UTF8) then encodes in 24576-byte
    -- chunks (divisible by 3 — required for correct base64).
    -- Strips embedded newlines that UTL_ENCODE inserts every 64 chars.
    -- --------------------------------------------------------
    FUNCTION clob_to_b64 (p_clob IN CLOB) RETURN CLOB IS
        l_blob      BLOB := clob_to_blob_utf8(p_clob);
        l_b64blob   BLOB;
        l_amt       PLS_INTEGER := 24576;
        l_offset    PLS_INTEGER := 1;
        l_blob_len  PLS_INTEGER;
        l_chunk_raw RAW(24576);
        l_enc_raw   RAW(32767);
    BEGIN
        l_blob_len := DBMS_LOB.GETLENGTH(l_blob);
        DBMS_LOB.CREATETEMPORARY(l_b64blob, TRUE);

        WHILE l_offset <= l_blob_len LOOP
            l_chunk_raw := DBMS_LOB.SUBSTR(l_blob,
                               LEAST(l_amt, l_blob_len - l_offset + 1),
                               l_offset);
            l_enc_raw := UTL_ENCODE.BASE64_ENCODE(l_chunk_raw);
            DBMS_LOB.WRITEAPPEND(l_b64blob, UTL_RAW.LENGTH(l_enc_raw), l_enc_raw);
            l_offset := l_offset + l_amt;
        END LOOP;

        RETURN REPLACE(blob_to_clob_utf8(l_b64blob), CHR(10), '');
    END clob_to_b64;

    -- --------------------------------------------------------
    -- GET_SESSION_TOKEN
    -- --------------------------------------------------------
    FUNCTION GET_SESSION_TOKEN RETURN VARCHAR2 IS
        C_PROC   CONSTANT VARCHAR2(30) := 'GET_SESSION_TOKEN';
        l_url    VARCHAR2(500);
        l_action CONSTANT VARCHAR2(200) :=
            'http://xmlns.oracle.com/oxp/service/v2/SecurityService/loginRequest';
        l_env    CLOB;
        l_resp   CLOB;
        l_token  VARCHAR2(4000);
    BEGIN
        l_url := fusion_base || '/xmlpserver/services/v2/SecurityService';

        l_env :=
            '<soapenv:Envelope'||
            ' xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"'||
            ' xmlns:v2="http://xmlns.oracle.com/oxp/service/v2">'||
            '  <soapenv:Header/>'||
            '  <soapenv:Body>'||
            '    <v2:login>'||
            '      <v2:userID>'||DMT_UTIL_PKG.GET_CONFIG('FUSION_USERNAME')||'</v2:userID>'||
            '      <v2:password>'||DMT_UTIL_PKG.GET_CONFIG('FUSION_PASSWORD')||'</v2:password>'||
            '    </v2:login>'||
            '  </soapenv:Body>'||
            '</soapenv:Envelope>';

        l_resp := soap_post(l_url, l_action, l_env);

        SELECT REGEXP_SUBSTR(l_resp, '<loginReturn>(.*?)</loginReturn>', 1, 1, NULL, 1)
          INTO l_token
          FROM DUAL;

        IF l_token IS NULL THEN
            RAISE_APPLICATION_ERROR(-20050,
                'GET_SESSION_TOKEN: login returned no token. ' ||
                'Response: ' || SUBSTR(l_resp, 1, 500));
        END IF;

        RETURN l_token;

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_message   => 'GET_SESSION_TOKEN failed',
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE;
    END GET_SESSION_TOKEN;

    -- --------------------------------------------------------
    -- CREATE_DM
    -- --------------------------------------------------------
    PROCEDURE CREATE_DM (
        p_session_token IN VARCHAR2,
        p_xdm_name      IN VARCHAR2,
        p_xdm_xml       IN CLOB
    ) IS
        C_PROC   CONSTANT VARCHAR2(30) := 'CREATE_DM';
        l_url    VARCHAR2(500);
        l_action CONSTANT VARCHAR2(200) :=
            'http://xmlns.oracle.com/oxp/service/v2/CatalogService/createObjectInSessionRequest';
        l_b64    CLOB;
        l_env    CLOB;
        l_resp   CLOB;
    BEGIN
        l_url := fusion_base || '/xmlpserver/services/v2/CatalogService';
        l_b64 := clob_to_b64(p_xdm_xml);

        -- Build envelope as CLOB because objectData (base64) may be large
        DBMS_LOB.CREATETEMPORARY(l_env, TRUE);
        DBMS_LOB.APPEND(l_env,
            '<soapenv:Envelope'||
            ' xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"'||
            ' xmlns:v2="http://xmlns.oracle.com/oxp/service/v2">'||
            '  <soapenv:Header/>'||
            '  <soapenv:Body>'||
            '    <v2:createObjectInSession>'||
            '      <v2:folderAbsolutePathURL>/~'||bip_username||'</v2:folderAbsolutePathURL>'||
            '      <v2:objectName>'||p_xdm_name||'</v2:objectName>'||
            '      <v2:objectType>xdm</v2:objectType>'||
            '      <v2:bipSessionToken>'||p_session_token||'</v2:bipSessionToken>'||
            '      <v2:objectData>');
        DBMS_LOB.APPEND(l_env, l_b64);
        DBMS_LOB.APPEND(l_env,
            '</v2:objectData>'||
            '    </v2:createObjectInSession>'||
            '  </soapenv:Body>'||
            '</soapenv:Envelope>');

        l_resp := soap_post(l_url, l_action, l_env);

        IF INSTR(l_resp, 'soapenv:Fault') > 0 OR
           INSTR(l_resp, 'soap:Fault')    > 0 THEN
            RAISE_APPLICATION_ERROR(-20051,
                'CREATE_DM: SOAP Fault returned. DM: ' || p_xdm_name ||
                ' | Response: ' || SUBSTR(l_resp, 1, 500));
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_message   => 'CREATE_DM failed. DM: ' || p_xdm_name,
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE;
    END CREATE_DM;

    -- --------------------------------------------------------
    -- RUN_DM
    -- --------------------------------------------------------
    FUNCTION RUN_DM (
        p_session_token IN VARCHAR2,
        p_xdm_name      IN VARCHAR2
    ) RETURN CLOB IS
        C_PROC   CONSTANT VARCHAR2(30) := 'RUN_DM';
        l_url    VARCHAR2(500);
        l_action CONSTANT VARCHAR2(200) :=
            'http://xmlns.oracle.com/oxp/service/v2/ReportService/runDataModelRequest';
        l_env    CLOB;
        l_resp   CLOB;
    BEGIN
        l_url := fusion_base || '/xmlpserver/services/v2/ReportService';

        l_env :=
            '<soapenv:Envelope'||
            ' xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"'||
            ' xmlns:v2="http://xmlns.oracle.com/oxp/service/v2">'||
            '  <soapenv:Header/>'||
            '  <soapenv:Body>'||
            '    <v2:runDataModelInSession>'||
            '      <v2:reportRequest>'||
            '        <v2:reportAbsolutePath>/~'||bip_username||'/'||
                         p_xdm_name||'.xdm</v2:reportAbsolutePath>'||
            '        <v2:sizeOfDataChunkDownload>-1</v2:sizeOfDataChunkDownload>'||
            '      </v2:reportRequest>'||
            '      <v2:bipSessionToken>'||p_session_token||'</v2:bipSessionToken>'||
            '    </v2:runDataModelInSession>'||
            '  </soapenv:Body>'||
            '</soapenv:Envelope>';

        l_resp := soap_post(l_url, l_action, l_env);

        IF INSTR(l_resp, 'soapenv:Fault') > 0 OR
           INSTR(l_resp, 'soap:Fault')    > 0 THEN
            DMT_UTIL_PKG.LOG(
                p_message   => 'RUN_DM fault. Full response: ' || SUBSTR(l_resp, 1, 3900),
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE_APPLICATION_ERROR(-20052,
                'RUN_DM: SOAP Fault returned. DM: ' || p_xdm_name ||
                ' | Response: ' || SUBSTR(l_resp, 1, 1800));
        END IF;

        RETURN l_resp;

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_message   => 'RUN_DM failed. DM: ' || p_xdm_name,
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE;
    END RUN_DM;

    -- --------------------------------------------------------
    -- DELETE_DM
    -- --------------------------------------------------------
    PROCEDURE DELETE_DM (
        p_session_token IN VARCHAR2,
        p_xdm_name      IN VARCHAR2
    ) IS
        l_url    VARCHAR2(500);
        l_action CONSTANT VARCHAR2(200) :=
            'http://xmlns.oracle.com/oxp/service/v2/CatalogService/deleteObjectInSessionRequest';
        l_env    CLOB;
        l_tmp    CLOB;
    BEGIN
        l_url := fusion_base || '/xmlpserver/services/v2/CatalogService';

        l_env :=
            '<soapenv:Envelope'||
            ' xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"'||
            ' xmlns:v2="http://xmlns.oracle.com/oxp/service/v2">'||
            '  <soapenv:Header/>'||
            '  <soapenv:Body>'||
            '    <v2:deleteObjectInSession>'||
            '      <v2:objectAbsolutePath>/~'||bip_username||'/'||
                       p_xdm_name||'.xdm</v2:objectAbsolutePath>'||
            '      <v2:bipSessionToken>'||p_session_token||'</v2:bipSessionToken>'||
            '    </v2:deleteObjectInSession>'||
            '  </soapenv:Body>'||
            '</soapenv:Envelope>';

        BEGIN
            l_tmp := soap_post(l_url, l_action, l_env);
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
    END DELETE_DM;

    -- --------------------------------------------------------
    -- CREATE_RPT
    -- --------------------------------------------------------
    PROCEDURE CREATE_RPT (
        p_session_token IN VARCHAR2,
        p_rpt_name      IN VARCHAR2,
        p_dm_path       IN VARCHAR2
    ) IS
        C_PROC   CONSTANT VARCHAR2(30) := 'CREATE_RPT';
        l_url    VARCHAR2(500);
        l_action CONSTANT VARCHAR2(200) :=
            'http://xmlns.oracle.com/oxp/service/v2/CatalogService/createObjectInSessionRequest';
        l_xdo_xml CLOB;
        l_b64     CLOB;
        l_env     CLOB;
        l_resp    CLOB;
    BEGIN
        l_url := fusion_base || '/xmlpserver/services/v2/CatalogService';

        -- Minimal BIP report definition referencing the data model.
        -- No namespace on root element — BIP v2 parses version attribute
        -- as null when xmlns is present, causing "version not supported" fault.
        -- No layout templates — output format is raw XML.
        l_xdo_xml :=
            '<?xml version="1.0" encoding="UTF-8"?>'||CHR(10)||
            '<report version="2.0">'||CHR(10)||
            '  <dataModel path="'||p_dm_path||'"/>'||CHR(10)||
            '  <defaultOutputFormat>xml</defaultOutputFormat>'||CHR(10)||
            '</report>';

        l_b64 := clob_to_b64(l_xdo_xml);

        DBMS_LOB.CREATETEMPORARY(l_env, TRUE);
        DBMS_LOB.APPEND(l_env,
            '<soapenv:Envelope'||
            ' xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"'||
            ' xmlns:v2="http://xmlns.oracle.com/oxp/service/v2">'||
            '  <soapenv:Header/>'||
            '  <soapenv:Body>'||
            '    <v2:createObjectInSession>'||
            '      <v2:folderAbsolutePathURL>/~'||bip_username||'</v2:folderAbsolutePathURL>'||
            '      <v2:objectName>'||p_rpt_name||'</v2:objectName>'||
            '      <v2:objectType>xdo</v2:objectType>'||
            '      <v2:bipSessionToken>'||p_session_token||'</v2:bipSessionToken>'||
            '      <v2:objectData>');
        DBMS_LOB.APPEND(l_env, l_b64);
        DBMS_LOB.APPEND(l_env,
            '</v2:objectData>'||
            '    </v2:createObjectInSession>'||
            '  </soapenv:Body>'||
            '</soapenv:Envelope>');

        l_resp := soap_post(l_url, l_action, l_env);

        IF INSTR(l_resp, 'soapenv:Fault') > 0 OR
           INSTR(l_resp, 'soap:Fault')    > 0 THEN
            DMT_UTIL_PKG.LOG(
                p_message   => 'CREATE_RPT fault response: ' || SUBSTR(l_resp, 1, 3900),
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE_APPLICATION_ERROR(-20053,
                'CREATE_RPT: SOAP Fault returned. RPT: ' || p_rpt_name ||
                ' | Response: ' || SUBSTR(l_resp, 1, 1800));
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_message   => 'CREATE_RPT failed. RPT: ' || p_rpt_name,
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE;
    END CREATE_RPT;

    -- --------------------------------------------------------
    -- RUN_RPT
    -- --------------------------------------------------------
    FUNCTION RUN_RPT (
        p_rpt_name IN VARCHAR2
    ) RETURN CLOB IS
        C_PROC   CONSTANT VARCHAR2(30) := 'RUN_RPT';
        l_url    VARCHAR2(500);
        l_action CONSTANT VARCHAR2(200) :=
            'http://xmlns.oracle.com/oxp/service/v2/ReportService/runReportRequest';
        l_env    CLOB;
        l_resp   CLOB;
    BEGIN
        l_url := fusion_base || '/xmlpserver/services/v2/ReportService';

        -- runReport uses userID/password directly; it does NOT accept bipSessionToken.
        l_env :=
            '<soapenv:Envelope'||
            ' xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"'||
            ' xmlns:v2="http://xmlns.oracle.com/oxp/service/v2">'||
            '  <soapenv:Header/>'||
            '  <soapenv:Body>'||
            '    <v2:runReport>'||
            '      <v2:reportRequest>'||
            '        <v2:reportAbsolutePath>/~'||bip_username||'/'||
                         p_rpt_name||'.xdo</v2:reportAbsolutePath>'||
            '        <v2:attributeFormat>xml</v2:attributeFormat>'||
            '        <v2:sizeOfDataChunkDownload>-1</v2:sizeOfDataChunkDownload>'||
            '      </v2:reportRequest>'||
            '      <v2:userID>'||DMT_UTIL_PKG.GET_CONFIG('FUSION_USERNAME')||'</v2:userID>'||
            '      <v2:password>'||DMT_UTIL_PKG.GET_CONFIG('FUSION_PASSWORD')||'</v2:password>'||
            '    </v2:runReport>'||
            '  </soapenv:Body>'||
            '</soapenv:Envelope>';

        l_resp := soap_post(l_url, l_action, l_env);

        IF INSTR(l_resp, 'soapenv:Fault') > 0 OR
           INSTR(l_resp, 'soap:Fault')    > 0 THEN
            DMT_UTIL_PKG.LOG(
                p_message   => 'RUN_RPT fault response: ' || SUBSTR(l_resp, 1, 3900),
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE_APPLICATION_ERROR(-20054,
                'RUN_RPT: SOAP Fault returned. RPT: ' || p_rpt_name ||
                ' | Response: ' || SUBSTR(l_resp, 1, 1800));
        END IF;

        RETURN l_resp;

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_message   => 'RUN_RPT failed. RPT: ' || p_rpt_name,
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE;
    END RUN_RPT;

    -- --------------------------------------------------------
    -- DELETE_RPT
    -- --------------------------------------------------------
    PROCEDURE DELETE_RPT (
        p_session_token IN VARCHAR2,
        p_rpt_name      IN VARCHAR2
    ) IS
        l_url    VARCHAR2(500);
        l_action CONSTANT VARCHAR2(200) :=
            'http://xmlns.oracle.com/oxp/service/v2/CatalogService/deleteObjectInSessionRequest';
        l_env    CLOB;
        l_tmp    CLOB;
    BEGIN
        l_url := fusion_base || '/xmlpserver/services/v2/CatalogService';

        l_env :=
            '<soapenv:Envelope'||
            ' xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"'||
            ' xmlns:v2="http://xmlns.oracle.com/oxp/service/v2">'||
            '  <soapenv:Header/>'||
            '  <soapenv:Body>'||
            '    <v2:deleteObjectInSession>'||
            '      <v2:objectAbsolutePath>/~'||bip_username||'/'||
                       p_rpt_name||'.xdo</v2:objectAbsolutePath>'||
            '      <v2:bipSessionToken>'||p_session_token||'</v2:bipSessionToken>'||
            '    </v2:deleteObjectInSession>'||
            '  </soapenv:Body>'||
            '</soapenv:Envelope>';

        BEGIN
            l_tmp := soap_post(l_url, l_action, l_env);
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
    END DELETE_RPT;

    -- --------------------------------------------------------
    -- RUN_POC_TEST
    -- --------------------------------------------------------
    PROCEDURE RUN_POC_TEST (
        p_run_id IN NUMBER DEFAULT NULL
    ) IS
        C_PROC     CONSTANT VARCHAR2(30) := 'RUN_POC_TEST';
        C_DM_NAME  CONSTANT VARCHAR2(50) := 'DMT_POC_DM';
        C_RPT_NAME CONSTANT VARCHAR2(50) := 'DMT_POC_RPT';

        l_xdm_xml CLOB;
        l_token   VARCHAR2(4000);
        l_resp    CLOB;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'RUN_POC_TEST start',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        -- Data model: 2 columns (ROW_NUM, LABEL), 2 rows from DUAL.
        -- Uses ApplicationDB_FSCM + REF CURSOR pattern.
        -- SELECT FROM DUAL is confirmed to work on this instance.
        l_xdm_xml :=
            '<?xml version="1.0" encoding="utf-8"?>'||CHR(10)||
            '<dataModel xmlns="http://xmlns.oracle.com/oxp/xmlp" version="2.0"'||
            ' xmlns:xdm="http://xmlns.oracle.com/oxp/xmlp"'||
            ' xmlns:xsd="http://www.w3.org/2001/XMLSchema"'||
            ' defaultDataSourceRef="ApplicationDB_FSCM">'||CHR(10)||
            '  <dataProperties>'||CHR(10)||
            '    <property name="include_parameters" value="true"/>'||CHR(10)||
            '    <property name="include_null_Element" value="false"/>'||CHR(10)||
            '    <property name="include_rowsettag" value="false"/>'||CHR(10)||
            '    <property name="xml_tag_case" value="upper"/>'||CHR(10)||
            '  </dataProperties>'||CHR(10)||
            '  <dataSets>'||CHR(10)||
            '    <dataSet name="poc_data" type="simple">'||CHR(10)||
            '      <sql dataSourceRef="ApplicationDB_FSCM" nsQuery="true" sp="true"'||
            '           xmlRowTagName="record"'||
            '           bindMultiValueAsCommaSepStr="false"><![CDATA[DECLARE'||CHR(10)||
            'type refcursor is REF CURSOR;'||CHR(10)||
            'xdo_cursor  refcursor;'||CHR(10)||
            'BEGIN'||CHR(10)||
            'OPEN :xdo_cursor FOR'||CHR(10)||
            'SELECT 1 AS ROW_NUM, ''Alpha'' AS LABEL FROM DUAL'||CHR(10)||
            'UNION ALL'||CHR(10)||
            'SELECT 2, ''Beta'' FROM DUAL;'||CHR(10)||
            'END;]]></sql>'||CHR(10)||
            '    </dataSet>'||CHR(10)||
            '  </dataSets>'||CHR(10)||
            '  <output rootName="DATA_DS" uniqueRowName="false">'||CHR(10)||
            '    <nodeList name="poc_data"/>'||CHR(10)||
            '  </output>'||CHR(10)||
            '  <eventTriggers/>'||CHR(10)||
            '  <lexicals/>'||CHR(10)||
            '  <parameters/>'||CHR(10)||
            '  <valueSets/>'||CHR(10)||
            '  <bursting/>'||CHR(10)||
            '  <validations><validation>N</validation></validations>'||CHR(10)||
            '  <display><layouts>'||CHR(10)||
            '    <layout name="poc_data" left="280px" top="0px"/>'||CHR(10)||
            '    <layout name="DATA_DS" left="0px" top="35px"/>'||CHR(10)||
            '  </layouts><groupLinks/></display>'||CHR(10)||
            '</dataModel>';

        -- Step 1: Login
        l_token := GET_SESSION_TOKEN;
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Session token obtained.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        -- Step 2: Cleanup objects from any previous run (errors swallowed)
        DELETE_DM (l_token, C_DM_NAME);
        DELETE_RPT(l_token, C_RPT_NAME);
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Cleanup complete (previous objects removed if present).',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        -- Step 3: Create data model (persistent — kept after test)
        CREATE_DM(l_token, C_DM_NAME, l_xdm_xml);
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Data model created: /~'||bip_username||'/'||C_DM_NAME||'.xdm',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        -- Step 4: Create report referencing the data model (persistent — kept after test)
        CREATE_RPT(l_token, C_RPT_NAME,
                   '/~'||bip_username||'/'||C_DM_NAME||'.xdm');
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Report created: /~'||bip_username||'/'||C_RPT_NAME||'.xdo',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        -- Step 5: Run the report (runReport uses credentials, not session token)
        l_resp := RUN_RPT(C_RPT_NAME);
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Report run complete. Response length: '||
                                DBMS_LOB.GETLENGTH(l_resp)||
                                ' | Preview: '||SUBSTR(l_resp, 1, 500),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'RUN_POC_TEST complete. Objects kept in /~'||
                                bip_username||': '||C_DM_NAME||'.xdm, '||C_RPT_NAME||'.xdo',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'RUN_POC_TEST failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END RUN_POC_TEST;

END DMT_BIP_SETUP_PKG;
/
