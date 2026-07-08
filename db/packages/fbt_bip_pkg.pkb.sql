-- PACKAGE BODY FBT_BIP_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "FBT_BIP_PKG" AS
-- ============================================================
-- FBT_BIP_PKG Body
-- BIP v2 SOAP session approach from ATP via UTL_HTTP.
-- Modeled on APEX_QUERY_BIP_PKG (oracle-queryapp) and
-- DMT_BIP_SETUP_PKG / DMT_BIP_DEPLOY_PKG (ConversionTool).
-- All private helpers are proven-working verbatim copies.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(30) := 'FBT_BIP_PKG';

    -- --------------------------------------------------------
    -- Private: resolve folder path.
    -- Returns p_folder if provided, else '/~' || p_username.
    -- Raises -20009 if both are NULL.
    -- --------------------------------------------------------
    FUNCTION get_folder (
        p_folder   IN VARCHAR2,
        p_username IN VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2 IS
    BEGIN
        IF p_folder IS NOT NULL THEN
            RETURN p_folder;
        ELSIF p_username IS NOT NULL THEN
            RETURN '/~' || p_username;
        ELSE
            RAISE_APPLICATION_ERROR(-20009,
                'FBT_BIP_PKG: p_folder is required when username is not available. ' ||
                'Pass the BIP folder path explicitly (e.g. ''/~calvin.roth'').');
        END IF;
    END get_folder;

    -- --------------------------------------------------------
    -- Private: POST a SOAP envelope; return full response CLOB.
    -- No Authorization header â€” BIP v2 authenticates via
    -- session token in the SOAP body, not HTTP auth.
    -- Content-Length is always set (required by Fusion/nginx).
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

        -- Write envelope in chunks (WRITE_TEXT has a 32767-char limit)
        DECLARE
            l_chunk_size PLS_INTEGER := 16000;
            l_pos        PLS_INTEGER := 1;
            l_piece      VARCHAR2(16000);
        BEGIN
            WHILE l_pos <= l_len LOOP
                l_piece := DBMS_LOB.SUBSTR(p_envelope, LEAST(l_chunk_size, l_len - l_pos + 1), l_pos);
                UTL_HTTP.WRITE_TEXT(l_req, l_piece);
                l_pos := l_pos + l_chunk_size;
            END LOOP;
        END;

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
    -- chunks (divisible by 3 â€” required for correct base64).
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
    -- Private: BLOB -> base64 CLOB.
    -- Like clob_to_b64 but input is already a BLOB â€” skips the
    -- CLOB->BLOB charset conversion step.
    -- --------------------------------------------------------
    FUNCTION blob_to_b64 (p_blob IN BLOB) RETURN CLOB IS
        l_b64blob  BLOB;
        l_amt      PLS_INTEGER := 18000;  -- divisible by 3; base64 output = 24000 (well under 32767)
        l_offset   PLS_INTEGER := 1;
        l_blob_len PLS_INTEGER;
        l_chunk    RAW(18000);
        l_enc_raw  RAW(32767);
    BEGIN
        l_blob_len := DBMS_LOB.GETLENGTH(p_blob);
        DBMS_LOB.CREATETEMPORARY(l_b64blob, TRUE);

        WHILE l_offset <= l_blob_len LOOP
            l_chunk   := DBMS_LOB.SUBSTR(p_blob,
                             LEAST(l_amt, l_blob_len - l_offset + 1),
                             l_offset);
            l_enc_raw := UTL_ENCODE.BASE64_ENCODE(l_chunk);
            DBMS_LOB.WRITEAPPEND(l_b64blob, UTL_RAW.LENGTH(l_enc_raw), l_enc_raw);
            l_offset  := l_offset + l_amt;
        END LOOP;

        RETURN REPLACE(blob_to_clob_utf8(l_b64blob), CHR(10), '');
    END blob_to_b64;

    -- --------------------------------------------------------
    -- Private: base64 CLOB -> BLOB.
    -- Strips newlines, converts base64 text to raw bytes in
    -- 24576-byte chunks (divisible by 4 for correct decoding).
    -- --------------------------------------------------------
    FUNCTION b64_to_blob (p_b64 IN CLOB) RETURN BLOB IS
        l_b64_clean CLOB;
        l_b64_blob  BLOB;
        l_out_blob  BLOB;
        l_amt       PLS_INTEGER := 24576;
        l_offset    PLS_INTEGER := 1;
        l_len       PLS_INTEGER;
        l_chunk     RAW(24576);
        l_dec_raw   RAW(18432);
    BEGIN
        l_b64_clean := REPLACE(REPLACE(p_b64, CHR(13), ''), CHR(10), '');
        l_b64_blob  := clob_to_blob_utf8(l_b64_clean);
        l_len       := DBMS_LOB.GETLENGTH(l_b64_blob);

        DBMS_LOB.CREATETEMPORARY(l_out_blob, TRUE);

        WHILE l_offset <= l_len LOOP
            l_chunk   := DBMS_LOB.SUBSTR(l_b64_blob,
                             LEAST(l_amt, l_len - l_offset + 1),
                             l_offset);
            l_dec_raw := UTL_ENCODE.BASE64_DECODE(l_chunk);
            DBMS_LOB.WRITEAPPEND(l_out_blob, UTL_RAW.LENGTH(l_dec_raw), l_dec_raw);
            l_offset  := l_offset + l_amt;
        END LOOP;

        RETURN l_out_blob;
    END b64_to_blob;

    -- --------------------------------------------------------
    -- GET_SESSION_TOKEN
    -- --------------------------------------------------------
    FUNCTION GET_SESSION_TOKEN (
        p_base_url IN VARCHAR2,
        p_username IN VARCHAR2,
        p_password IN VARCHAR2
    ) RETURN VARCHAR2 IS
        l_url    VARCHAR2(500);
        l_action CONSTANT VARCHAR2(200) :=
            'http://xmlns.oracle.com/oxp/service/v2/SecurityService/loginRequest';
        l_env    CLOB;
        l_resp   CLOB;
        l_token  VARCHAR2(4000);
    BEGIN
        l_url := RTRIM(p_base_url, '/') || '/xmlpserver/services/v2/SecurityService';

        l_env :=
            '<soapenv:Envelope'||
            ' xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"'||
            ' xmlns:v2="http://xmlns.oracle.com/oxp/service/v2">'||
            '  <soapenv:Header/>'||
            '  <soapenv:Body>'||
            '    <v2:login>'||
            '      <v2:userID>'||p_username||'</v2:userID>'||
            '      <v2:password>'||p_password||'</v2:password>'||
            '    </v2:login>'||
            '  </soapenv:Body>'||
            '</soapenv:Envelope>';

        l_resp := soap_post(l_url, l_action, l_env);

        SELECT REGEXP_SUBSTR(l_resp, '<loginReturn>(.*?)</loginReturn>', 1, 1, NULL, 1)
          INTO l_token
          FROM DUAL;

        IF l_token IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001,
                'FBT_BIP_PKG.GET_SESSION_TOKEN: login returned no token. ' ||
                'Response: ' || SUBSTR(l_resp, 1, 500));
        END IF;

        RETURN l_token;
    END GET_SESSION_TOKEN;

    -- --------------------------------------------------------
    -- DEPLOY_DATA_MODEL
    -- --------------------------------------------------------
    PROCEDURE DEPLOY_DATA_MODEL (
        p_session_token IN VARCHAR2,
        p_base_url      IN VARCHAR2,
        p_name          IN VARCHAR2,
        p_xdm_xml       IN CLOB,
        p_folder        IN VARCHAR2 DEFAULT NULL
    ) IS
        l_url    VARCHAR2(500);
        l_action CONSTANT VARCHAR2(200) :=
            'http://xmlns.oracle.com/oxp/service/v2/CatalogService/createObjectInSessionRequest';
        l_folder VARCHAR2(500);
        l_b64    CLOB;
        l_env    CLOB;
        l_resp   CLOB;
    BEGIN
        l_folder := get_folder(p_folder);
        l_url    := RTRIM(p_base_url, '/') || '/xmlpserver/services/v2/CatalogService';
        l_b64    := clob_to_b64(p_xdm_xml);

        DBMS_LOB.CREATETEMPORARY(l_env, TRUE);
        DBMS_LOB.APPEND(l_env,
            '<soapenv:Envelope'||
            ' xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"'||
            ' xmlns:v2="http://xmlns.oracle.com/oxp/service/v2">'||
            '  <soapenv:Header/>'||
            '  <soapenv:Body>'||
            '    <v2:createObjectInSession>'||
            '      <v2:folderAbsolutePathURL>'||l_folder||'</v2:folderAbsolutePathURL>'||
            '      <v2:objectName>'||p_name||'</v2:objectName>'||
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
            RAISE_APPLICATION_ERROR(-20002,
                'FBT_BIP_PKG.DEPLOY_DATA_MODEL: SOAP Fault. DM: ' || p_name ||
                ' | Folder: ' || l_folder ||
                ' | Response: ' || SUBSTR(l_resp, 1, 500));
        END IF;
    END DEPLOY_DATA_MODEL;

    -- --------------------------------------------------------
    -- TEST_DATA_MODEL
    -- --------------------------------------------------------
    FUNCTION TEST_DATA_MODEL (
        p_session_token IN VARCHAR2,
        p_base_url      IN VARCHAR2,
        p_name          IN VARCHAR2,
        p_folder        IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB IS
        l_url    VARCHAR2(500);
        l_action CONSTANT VARCHAR2(200) :=
            'http://xmlns.oracle.com/oxp/service/v2/ReportService/runDataModelRequest';
        l_folder VARCHAR2(500);
        l_env    CLOB;
        l_resp   CLOB;
    BEGIN
        l_folder := get_folder(p_folder);
        l_url    := RTRIM(p_base_url, '/') || '/xmlpserver/services/v2/ReportService';

        l_env :=
            '<soapenv:Envelope'||
            ' xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"'||
            ' xmlns:v2="http://xmlns.oracle.com/oxp/service/v2">'||
            '  <soapenv:Header/>'||
            '  <soapenv:Body>'||
            '    <v2:runDataModelInSession>'||
            '      <v2:reportRequest>'||
            '        <v2:reportAbsolutePath>'||l_folder||'/'||p_name||'.xdm</v2:reportAbsolutePath>'||
            '        <v2:sizeOfDataChunkDownload>-1</v2:sizeOfDataChunkDownload>'||
            '      </v2:reportRequest>'||
            '      <v2:bipSessionToken>'||p_session_token||'</v2:bipSessionToken>'||
            '    </v2:runDataModelInSession>'||
            '  </soapenv:Body>'||
            '</soapenv:Envelope>';

        l_resp := soap_post(l_url, l_action, l_env);

        IF INSTR(l_resp, 'soapenv:Fault') > 0 OR
           INSTR(l_resp, 'soap:Fault')    > 0 THEN
            RAISE_APPLICATION_ERROR(-20003,
                'FBT_BIP_PKG.TEST_DATA_MODEL: SOAP Fault. DM: ' || p_name ||
                ' | Response: ' || SUBSTR(l_resp, 1, 1800));
        END IF;

        RETURN l_resp;
    END TEST_DATA_MODEL;

    -- --------------------------------------------------------
    -- DELETE_DATA_MODEL
    -- --------------------------------------------------------
    PROCEDURE DELETE_DATA_MODEL (
        p_session_token IN VARCHAR2,
        p_base_url      IN VARCHAR2,
        p_name          IN VARCHAR2,
        p_folder        IN VARCHAR2 DEFAULT NULL
    ) IS
        l_url    VARCHAR2(500);
        l_action CONSTANT VARCHAR2(200) :=
            'http://xmlns.oracle.com/oxp/service/v2/CatalogService/deleteObjectInSessionRequest';
        l_folder VARCHAR2(500);
        l_env    CLOB;
        l_tmp    CLOB;
    BEGIN
        l_folder := get_folder(p_folder);
        l_url    := RTRIM(p_base_url, '/') || '/xmlpserver/services/v2/CatalogService';

        l_env :=
            '<soapenv:Envelope'||
            ' xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"'||
            ' xmlns:v2="http://xmlns.oracle.com/oxp/service/v2">'||
            '  <soapenv:Header/>'||
            '  <soapenv:Body>'||
            '    <v2:deleteObjectInSession>'||
            '      <v2:objectAbsolutePath>'||l_folder||'/'||p_name||'.xdm</v2:objectAbsolutePath>'||
            '      <v2:bipSessionToken>'||p_session_token||'</v2:bipSessionToken>'||
            '    </v2:deleteObjectInSession>'||
            '  </soapenv:Body>'||
            '</soapenv:Envelope>';

        BEGIN
            l_tmp := soap_post(l_url, l_action, l_env);
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
    END DELETE_DATA_MODEL;

    -- --------------------------------------------------------
    -- RUN_DATA_MODEL_EPHEMERAL
    -- --------------------------------------------------------
    FUNCTION RUN_DATA_MODEL_EPHEMERAL (
        p_base_url IN VARCHAR2,
        p_username IN VARCHAR2,
        p_password IN VARCHAR2,
        p_xdm_xml  IN CLOB,
        p_name     IN VARCHAR2 DEFAULT 'FBT_EPHEMERAL'
    ) RETURN CLOB IS
        l_token  VARCHAR2(4000);
        l_folder VARCHAR2(500);
        l_resp   CLOB;
    BEGIN
        l_token  := GET_SESSION_TOKEN(p_base_url, p_username, p_password);
        l_folder := '/~' || p_username;

        BEGIN
            DEPLOY_DATA_MODEL(l_token, p_base_url, p_name, p_xdm_xml, l_folder);
            l_resp := TEST_DATA_MODEL(l_token, p_base_url, p_name, l_folder);
        EXCEPTION
            WHEN OTHERS THEN
                DELETE_DATA_MODEL(l_token, p_base_url, p_name, l_folder);
                RAISE;
        END;

        DELETE_DATA_MODEL(l_token, p_base_url, p_name, l_folder);
        RETURN l_resp;
    END RUN_DATA_MODEL_EPHEMERAL;

    -- --------------------------------------------------------
    -- DEPLOY_REPORT
    -- --------------------------------------------------------
    PROCEDURE DEPLOY_REPORT (
        p_session_token IN VARCHAR2,
        p_base_url      IN VARCHAR2,
        p_name          IN VARCHAR2,
        p_dm_path       IN VARCHAR2,
        p_folder        IN VARCHAR2 DEFAULT NULL
    ) IS
        l_url    VARCHAR2(500);
        l_action CONSTANT VARCHAR2(200) :=
            'http://xmlns.oracle.com/oxp/service/v2/CatalogService/createObjectInSessionRequest';
        l_folder  VARCHAR2(500);
        l_xdo_xml CLOB;
        l_b64     CLOB;
        l_env     CLOB;
        l_resp    CLOB;
    BEGIN
        l_folder := get_folder(p_folder);
        l_url    := RTRIM(p_base_url, '/') || '/xmlpserver/services/v2/CatalogService';

        -- BIP report definition referencing the data model.
        -- Structure derived from a UI-built report downloaded via getObjectInSession.
        -- Key attributes on root: xmlns, dataModel="true", useBipParameters="true".
        -- <parameters> element with style attr required for params to surface in UI.
        -- <templates> block required for BIP to treat this as a runnable report.
        l_xdo_xml :=
            '<?xml version="1.0" encoding="UTF-8"?>'||CHR(10)||
            '<report xmlns="http://xmlns.oracle.com/oxp/xmlp" version="2.0"'||CHR(10)||
            '        dataModel="true" useBipParameters="true">'||CHR(10)||
            '  <dataModel url="'||p_dm_path||'" cache="true"/>'||CHR(10)||
            '  <description/>'||CHR(10)||
            '  <property name="showControls" value="true"/>'||CHR(10)||
            '  <property name="online" value="true"/>'||CHR(10)||
            '  <property name="openLinkInNewWindow" value="true"/>'||CHR(10)||
            '  <property name="autoRun" value="true"/>'||CHR(10)||
            '  <property name="cacheDocument" value="false"/>'||CHR(10)||
            '  <property name="showReportLinks" value="false"/>'||CHR(10)||
            '  <property name="asynchronousRun" value="false"/>'||CHR(10)||
            '  <property name="saveXMLForRepublishing" value="true"/>'||CHR(10)||
            '  <property name="disableMakeOutputPublic" value="false"/>'||CHR(10)||
            '  <parameters paramPerLine="3" style="parameterLocation:in-horizontal;promptLocation:side;"/>'||CHR(10)||
            '  <templates default="default">'||CHR(10)||
            '    <template label="default" url="default.rtf" type="rtf"'||CHR(10)||
            '              outputFormat="html,pdf,rtf,xlsx,pptx,xml,csv" defaultFormat="xml"'||CHR(10)||
            '              locale="en" disableMasterTemplate="true" active="true" viewOnline="true"/>'||CHR(10)||
            '  </templates>'||CHR(10)||
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
            '      <v2:folderAbsolutePathURL>'||l_folder||'</v2:folderAbsolutePathURL>'||
            '      <v2:objectName>'||p_name||'</v2:objectName>'||
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
            RAISE_APPLICATION_ERROR(-20004,
                'FBT_BIP_PKG.DEPLOY_REPORT: SOAP Fault. Report: ' || p_name ||
                ' | Response: ' || SUBSTR(l_resp, 1, 500));
        END IF;
    END DEPLOY_REPORT;

    -- --------------------------------------------------------
    -- DEPLOY_TEMPLATE
    -- Templates are stored as sub-objects of the report.
    -- Derives template folder from p_report_path by stripping
    -- the file extension (e.g. '/~user/MyReport.xdo' ->
    -- '/~user/MyReport' is the folder; objectName = template_name,
    -- objectType = template_type).
    -- --------------------------------------------------------
    PROCEDURE DEPLOY_TEMPLATE (
        p_session_token IN VARCHAR2,
        p_base_url      IN VARCHAR2,
        p_report_path   IN VARCHAR2,
        p_template_name IN VARCHAR2,
        p_template_data IN CLOB,
        p_template_type IN VARCHAR2 DEFAULT 'rtf'
    ) IS
        l_url            VARCHAR2(500);
        l_action CONSTANT VARCHAR2(200) :=
            'http://xmlns.oracle.com/oxp/service/v2/CatalogService/createObjectInSessionRequest';
        l_template_folder VARCHAR2(500);
        l_b64             CLOB;
        l_env             CLOB;
        l_resp            CLOB;
    BEGIN
        -- Strip file extension to derive the template sub-folder
        l_template_folder := REGEXP_REPLACE(p_report_path, '\.[^./]+$', '');
        l_url             := RTRIM(p_base_url, '/') || '/xmlpserver/services/v2/CatalogService';
        l_b64             := clob_to_b64(p_template_data);

        DBMS_LOB.CREATETEMPORARY(l_env, TRUE);
        DBMS_LOB.APPEND(l_env,
            '<soapenv:Envelope'||
            ' xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"'||
            ' xmlns:v2="http://xmlns.oracle.com/oxp/service/v2">'||
            '  <soapenv:Header/>'||
            '  <soapenv:Body>'||
            '    <v2:createObjectInSession>'||
            '      <v2:folderAbsolutePathURL>'||l_template_folder||'</v2:folderAbsolutePathURL>'||
            '      <v2:objectName>'||p_template_name||'</v2:objectName>'||
            '      <v2:objectType>'||p_template_type||'</v2:objectType>'||
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
            RAISE_APPLICATION_ERROR(-20005,
                'FBT_BIP_PKG.DEPLOY_TEMPLATE: SOAP Fault. Template: ' || p_template_name ||
                ' | Report: ' || p_report_path ||
                ' | Response: ' || SUBSTR(l_resp, 1, 500));
        END IF;
    END DEPLOY_TEMPLATE;

    -- --------------------------------------------------------
    -- RUN_REPORT
    -- runReport authenticates with userID/password directly;
    -- it does NOT accept bipSessionToken.
    -- --------------------------------------------------------
    FUNCTION RUN_REPORT (
        p_base_url    IN VARCHAR2,
        p_username    IN VARCHAR2,
        p_password    IN VARCHAR2,
        p_report_path IN VARCHAR2
    ) RETURN CLOB IS
        l_url    VARCHAR2(500);
        l_action CONSTANT VARCHAR2(200) :=
            'http://xmlns.oracle.com/oxp/service/v2/ReportService/runReportRequest';
        l_env    CLOB;
        l_resp   CLOB;
    BEGIN
        l_url := RTRIM(p_base_url, '/') || '/xmlpserver/services/v2/ReportService';

        l_env :=
            '<soapenv:Envelope'||
            ' xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"'||
            ' xmlns:v2="http://xmlns.oracle.com/oxp/service/v2">'||
            '  <soapenv:Header/>'||
            '  <soapenv:Body>'||
            '    <v2:runReport>'||
            '      <v2:reportRequest>'||
            '        <v2:reportAbsolutePath>'||p_report_path||'</v2:reportAbsolutePath>'||
            '        <v2:attributeFormat>xml</v2:attributeFormat>'||
            '        <v2:sizeOfDataChunkDownload>-1</v2:sizeOfDataChunkDownload>'||
            '      </v2:reportRequest>'||
            '      <v2:userID>'||p_username||'</v2:userID>'||
            '      <v2:password>'||p_password||'</v2:password>'||
            '    </v2:runReport>'||
            '  </soapenv:Body>'||
            '</soapenv:Envelope>';

        l_resp := soap_post(l_url, l_action, l_env);

        IF INSTR(l_resp, 'soapenv:Fault') > 0 OR
           INSTR(l_resp, 'soap:Fault')    > 0 THEN
            RAISE_APPLICATION_ERROR(-20006,
                'FBT_BIP_PKG.RUN_REPORT: SOAP Fault. Report: ' || p_report_path ||
                ' | Response: ' || SUBSTR(l_resp, 1, 1800));
        END IF;

        RETURN l_resp;
    END RUN_REPORT;

    -- --------------------------------------------------------
    -- DELETE_REPORT
    -- --------------------------------------------------------
    PROCEDURE DELETE_REPORT (
        p_session_token IN VARCHAR2,
        p_base_url      IN VARCHAR2,
        p_name          IN VARCHAR2,
        p_folder        IN VARCHAR2 DEFAULT NULL
    ) IS
        l_url    VARCHAR2(500);
        l_action CONSTANT VARCHAR2(200) :=
            'http://xmlns.oracle.com/oxp/service/v2/CatalogService/deleteObjectInSessionRequest';
        l_folder VARCHAR2(500);
        l_env    CLOB;
        l_tmp    CLOB;
    BEGIN
        l_folder := get_folder(p_folder);
        l_url    := RTRIM(p_base_url, '/') || '/xmlpserver/services/v2/CatalogService';

        l_env :=
            '<soapenv:Envelope'||
            ' xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"'||
            ' xmlns:v2="http://xmlns.oracle.com/oxp/service/v2">'||
            '  <soapenv:Header/>'||
            '  <soapenv:Body>'||
            '    <v2:deleteObjectInSession>'||
            '      <v2:objectAbsolutePath>'||l_folder||'/'||p_name||'.xdo</v2:objectAbsolutePath>'||
            '      <v2:bipSessionToken>'||p_session_token||'</v2:bipSessionToken>'||
            '    </v2:deleteObjectInSession>'||
            '  </soapenv:Body>'||
            '</soapenv:Envelope>';

        BEGIN
            l_tmp := soap_post(l_url, l_action, l_env);
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
    END DELETE_REPORT;

    -- --------------------------------------------------------
    -- GET_TEMPLATE
    -- --------------------------------------------------------
    FUNCTION GET_TEMPLATE (
        p_session_token IN VARCHAR2,
        p_base_url      IN VARCHAR2,
        p_report_path   IN VARCHAR2,
        p_template_id   IN VARCHAR2,
        p_locale        IN VARCHAR2 DEFAULT 'en-US'
    ) RETURN BLOB IS
        l_url    VARCHAR2(500);
        l_action CONSTANT VARCHAR2(200) :=
            'http://xmlns.oracle.com/oxp/service/v2/ReportService/getTemplateInSessionRequest';
        l_env  CLOB;
        l_resp CLOB;
        l_b64  CLOB;
    BEGIN
        l_url := RTRIM(p_base_url, '/') || '/xmlpserver/services/v2/ReportService';

        l_env :=
            '<soapenv:Envelope'||
            ' xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"'||
            ' xmlns:v2="http://xmlns.oracle.com/oxp/service/v2">'||
            '  <soapenv:Header/>'||
            '  <soapenv:Body>'||
            '    <v2:getTemplateInSession>'||
            '      <v2:reportAbsolutePath>'||p_report_path||'</v2:reportAbsolutePath>'||
            '      <v2:templateID>'||p_template_id||'</v2:templateID>'||
            '      <v2:locale>'||p_locale||'</v2:locale>'||
            '      <v2:bipSessionToken>'||p_session_token||'</v2:bipSessionToken>'||
            '    </v2:getTemplateInSession>'||
            '  </soapenv:Body>'||
            '</soapenv:Envelope>';

        l_resp := soap_post(l_url, l_action, l_env);

        IF INSTR(l_resp, 'soapenv:Fault') > 0 OR
           INSTR(l_resp, 'soap:Fault')    > 0 THEN
            RAISE_APPLICATION_ERROR(-20007,
                'FBT_BIP_PKG.GET_TEMPLATE: SOAP Fault. Report: ' || p_report_path ||
                ' | Template: ' || p_template_id ||
                ' | Response: ' || SUBSTR(l_resp, 1, 500));
        END IF;

        SELECT REGEXP_SUBSTR(l_resp,
                   '<getTemplateInSessionReturn>(.*?)</getTemplateInSessionReturn>',
                   1, 1, NULL, 1)
          INTO l_b64
          FROM DUAL;

        RETURN b64_to_blob(l_b64);
    END GET_TEMPLATE;

    -- --------------------------------------------------------
    -- CREATE_REPORT_WITH_TEMPLATE
    -- --------------------------------------------------------
    FUNCTION CREATE_REPORT_WITH_TEMPLATE (
        p_session_token   IN VARCHAR2,
        p_base_url        IN VARCHAR2,
        p_name            IN VARCHAR2,
        p_folder          IN VARCHAR2,
        p_dm_path         IN VARCHAR2,
        p_template_name   IN VARCHAR2,
        p_template_data   IN BLOB,
        p_update_existing IN VARCHAR2 DEFAULT 'false'
    ) RETURN VARCHAR2 IS
        l_url    VARCHAR2(500);
        l_action CONSTANT VARCHAR2(200) :=
            'http://xmlns.oracle.com/oxp/service/v2/ReportService/createReportInSessionRequest';
        l_b64  CLOB;
        l_env  CLOB;
        l_resp CLOB;
        l_path VARCHAR2(2000);
    BEGIN
        l_url := RTRIM(p_base_url, '/') || '/xmlpserver/services/v2/ReportService';
        l_b64 := blob_to_b64(p_template_data);

        DBMS_LOB.CREATETEMPORARY(l_env, TRUE);
        DBMS_LOB.APPEND(l_env,
            '<soapenv:Envelope'||
            ' xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"'||
            ' xmlns:v2="http://xmlns.oracle.com/oxp/service/v2">'||
            '  <soapenv:Header/>'||
            '  <soapenv:Body>'||
            '    <v2:createReportInSession>'||
            '      <v2:reportName>'||p_name||'</v2:reportName>'||
            '      <v2:folderAbsolutePathURL>'||p_folder||'</v2:folderAbsolutePathURL>'||
            '      <v2:dataModelURL>'||p_dm_path||'</v2:dataModelURL>'||
            '      <v2:templateFileName>'||p_template_name||'</v2:templateFileName>'||
            '      <v2:templateData>');
        DBMS_LOB.APPEND(l_env, l_b64);
        DBMS_LOB.APPEND(l_env,
            '</v2:templateData>'||
            '      <v2:XLIFFFileName/>'||
            '      <v2:XLIFFData/>'||
            '      <v2:updateFlag>'||p_update_existing||'</v2:updateFlag>'||
            '      <v2:bipSessionToken>'||p_session_token||'</v2:bipSessionToken>'||
            '    </v2:createReportInSession>'||
            '  </soapenv:Body>'||
            '</soapenv:Envelope>');

        l_resp := soap_post(l_url, l_action, l_env);

        IF INSTR(l_resp, 'soapenv:Fault') > 0 OR
           INSTR(l_resp, 'soap:Fault')    > 0 THEN
            RAISE_APPLICATION_ERROR(-20008,
                'FBT_BIP_PKG.CREATE_REPORT_WITH_TEMPLATE: SOAP Fault. Report: ' || p_name ||
                ' | Folder: ' || p_folder ||
                ' | Response: ' || SUBSTR(l_resp, 1, 500));
        END IF;

        SELECT REGEXP_SUBSTR(l_resp,
                   '<createReportInSessionReturn>(.*?)</createReportInSessionReturn>',
                   1, 1, NULL, 1)
          INTO l_path
          FROM DUAL;

        RETURN l_path;
    END CREATE_REPORT_WITH_TEMPLATE;

    -- --------------------------------------------------------
    -- UPLOAD_TEMPLATE_FOR_REPORT
    -- --------------------------------------------------------
    PROCEDURE UPLOAD_TEMPLATE_FOR_REPORT (
        p_session_token IN VARCHAR2,
        p_base_url      IN VARCHAR2,
        p_report_path   IN VARCHAR2,
        p_template_name IN VARCHAR2,
        p_template_type IN VARCHAR2,
        p_locale        IN VARCHAR2 DEFAULT 'en-US',
        p_template_data IN BLOB
    ) IS
        l_url    VARCHAR2(500);
        l_action CONSTANT VARCHAR2(200) :=
            'http://xmlns.oracle.com/oxp/service/v2/ReportService/uploadTemplateForReportInSessionRequest';
        l_b64  CLOB;
        l_env  CLOB;
        l_resp CLOB;
    BEGIN
        l_url := RTRIM(p_base_url, '/') || '/xmlpserver/services/v2/ReportService';
        l_b64 := blob_to_b64(p_template_data);

        DBMS_LOB.CREATETEMPORARY(l_env, TRUE);
        DBMS_LOB.APPEND(l_env,
            '<soapenv:Envelope'||
            ' xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"'||
            ' xmlns:v2="http://xmlns.oracle.com/oxp/service/v2">'||
            '  <soapenv:Header/>'||
            '  <soapenv:Body>'||
            '    <v2:uploadTemplateForReportInSession>'||
            '      <v2:reportAbsolutePath>'||p_report_path||'</v2:reportAbsolutePath>'||
            '      <v2:templateName>'||p_template_name||'</v2:templateName>'||
            '      <v2:templateType>'||p_template_type||'</v2:templateType>'||
            '      <v2:locale>'||p_locale||'</v2:locale>'||
            '      <v2:templateData>');
        DBMS_LOB.APPEND(l_env, l_b64);
        DBMS_LOB.APPEND(l_env,
            '</v2:templateData>'||
            '      <v2:bipSessionToken>'||p_session_token||'</v2:bipSessionToken>'||
            '    </v2:uploadTemplateForReportInSession>'||
            '  </soapenv:Body>'||
            '</soapenv:Envelope>');

        l_resp := soap_post(l_url, l_action, l_env);

        IF INSTR(l_resp, 'soapenv:Fault') > 0 OR
           INSTR(l_resp, 'soap:Fault')    > 0 THEN
            RAISE_APPLICATION_ERROR(-20010,
                'FBT_BIP_PKG.UPLOAD_TEMPLATE_FOR_REPORT: SOAP Fault. Report: ' || p_report_path ||
                ' | Template: ' || p_template_name ||
                ' | Response: ' || SUBSTR(l_resp, 1, 500));
        END IF;
    END UPLOAD_TEMPLATE_FOR_REPORT;

    -- --------------------------------------------------------
    -- DOWNLOAD_CATALOG
    -- --------------------------------------------------------
    FUNCTION DOWNLOAD_CATALOG (
        p_session_token IN VARCHAR2,
        p_base_url      IN VARCHAR2,
        p_object_path   IN VARCHAR2
    ) RETURN BLOB IS
        l_url    VARCHAR2(500);
        l_action CONSTANT VARCHAR2(200) :=
            'http://xmlns.oracle.com/oxp/service/v2/CatalogService/downloadObjectInSessionRequest';
        l_env    CLOB;
        l_resp   CLOB;
        l_b64    CLOB;
        l_start  PLS_INTEGER;
        l_end    PLS_INTEGER;
        l_amt    PLS_INTEGER;
        l_tag_open  CONSTANT VARCHAR2(60) := '<downloadObjectInSessionReturn>';
        l_tag_close CONSTANT VARCHAR2(60) := '</downloadObjectInSessionReturn>';
    BEGIN
        l_url := RTRIM(p_base_url, '/') || '/xmlpserver/services/v2/CatalogService';

        l_env :=
            '<soapenv:Envelope'||
            ' xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"'||
            ' xmlns:v2="http://xmlns.oracle.com/oxp/service/v2">'||
            '  <soapenv:Header/>'||
            '  <soapenv:Body>'||
            '    <v2:downloadObjectInSession>'||
            '      <v2:reportAbsolutePath>'||p_object_path||'</v2:reportAbsolutePath>'||
            '      <v2:bipSessionToken>'||p_session_token||'</v2:bipSessionToken>'||
            '    </v2:downloadObjectInSession>'||
            '  </soapenv:Body>'||
            '</soapenv:Envelope>';

        l_resp := soap_post(l_url, l_action, l_env);

        IF INSTR(l_resp, 'soapenv:Fault') > 0 OR
           INSTR(l_resp, 'soap:Fault')    > 0 THEN
            RAISE_APPLICATION_ERROR(-20013,
                'FBT_BIP_PKG.DOWNLOAD_CATALOG: SOAP Fault. Path: ' || p_object_path ||
                ' | Response: ' || SUBSTR(l_resp, 1, 500));
        END IF;

        -- Extract base64 payload from response
        l_start := DBMS_LOB.INSTR(l_resp, l_tag_open) + LENGTH(l_tag_open);
        l_end   := DBMS_LOB.INSTR(l_resp, l_tag_close);
        IF l_start > LENGTH(l_tag_open) AND l_end > l_start THEN
            l_amt := l_end - l_start;
            DBMS_LOB.CREATETEMPORARY(l_b64, TRUE);
            DBMS_LOB.COPY(l_b64, l_resp, l_amt, 1, l_start);
        ELSE
            RAISE_APPLICATION_ERROR(-20013,
                'FBT_BIP_PKG.DOWNLOAD_CATALOG: No payload in response for ' || p_object_path);
        END IF;

        RETURN b64_to_blob(l_b64);
    END DOWNLOAD_CATALOG;

    -- --------------------------------------------------------
    -- DOWNLOAD_CATALOG_FOLDER
    -- Uses the same downloadObjectInSession SOAP call but the
    -- path points to a folder rather than a single object.
    -- BIP returns a ZIP containing all objects in the folder.
    -- --------------------------------------------------------
    FUNCTION DOWNLOAD_CATALOG_FOLDER (
        p_session_token IN VARCHAR2,
        p_base_url      IN VARCHAR2,
        p_folder_path   IN VARCHAR2
    ) RETURN BLOB IS
    BEGIN
        -- Folder download uses the same SOAP operation as object download.
        -- BIP detects that the path is a folder and returns a folder archive.
        RETURN DOWNLOAD_CATALOG(p_session_token, p_base_url, p_folder_path);
    END DOWNLOAD_CATALOG_FOLDER;

    -- --------------------------------------------------------
    -- UPLOAD_CATALOG
    -- --------------------------------------------------------
    PROCEDURE UPLOAD_CATALOG (
        p_session_token IN VARCHAR2,
        p_base_url      IN VARCHAR2,
        p_object_path   IN VARCHAR2,
        p_object_type   IN VARCHAR2,
        p_catalog_data  IN BLOB
    ) IS
        l_url    VARCHAR2(500);
        l_action CONSTANT VARCHAR2(200) :=
            'http://xmlns.oracle.com/oxp/service/v2/CatalogService/uploadObjectInSessionRequest';
        l_b64    CLOB;
        l_env    CLOB;
        l_resp   CLOB;
    BEGIN
        l_url := RTRIM(p_base_url, '/') || '/xmlpserver/services/v2/CatalogService';
        l_b64 := blob_to_b64(p_catalog_data);

        DBMS_LOB.CREATETEMPORARY(l_env, TRUE);
        DBMS_LOB.APPEND(l_env,
            '<soapenv:Envelope'||
            ' xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"'||
            ' xmlns:v2="http://xmlns.oracle.com/oxp/service/v2">'||
            '  <soapenv:Header/>'||
            '  <soapenv:Body>'||
            '    <v2:uploadObjectInSession>'||
            '      <v2:reportObjectAbsolutePathURL>'||p_object_path||'</v2:reportObjectAbsolutePathURL>'||
            '      <v2:objectType>'||p_object_type||'</v2:objectType>'||
            '      <v2:objectZippedData>');
        DBMS_LOB.APPEND(l_env, l_b64);
        DBMS_LOB.APPEND(l_env,
            '</v2:objectZippedData>'||
            '      <v2:bipSessionToken>'||p_session_token||'</v2:bipSessionToken>'||
            '    </v2:uploadObjectInSession>'||
            '  </soapenv:Body>'||
            '</soapenv:Envelope>');

        l_resp := soap_post(l_url, l_action, l_env);

        IF INSTR(l_resp, 'soapenv:Fault') > 0 OR
           INSTR(l_resp, 'soap:Fault')    > 0 THEN
            RAISE_APPLICATION_ERROR(-20014,
                'FBT_BIP_PKG.UPLOAD_CATALOG: SOAP Fault. Path: ' || p_object_path ||
                ' | Type: ' || p_object_type ||
                ' | Response: ' || SUBSTR(l_resp, 1, 500));
        END IF;
    END UPLOAD_CATALOG;

    -- --------------------------------------------------------
    -- BUILD_PARAMS_XML
    -- --------------------------------------------------------
    FUNCTION BUILD_PARAMS_XML (
        p_params IN fbt_param_tab_t
    ) RETURN CLOB IS
        l_xml CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_xml, TRUE);
        DBMS_LOB.APPEND(l_xml, '<parameters>'||CHR(10));

        FOR i IN 1 .. p_params.COUNT LOOP
            DBMS_LOB.APPEND(l_xml,
                '  <parameter name="'  || p_params(i).name ||'"'||
                ' dataType="'          || NVL(p_params(i).data_type, 'xsd:string') || '"'||
                ' rowPlacement="'      || i || '">'||CHR(10));
            -- Date params need <date> child element; all others use <input>
            IF NVL(p_params(i).data_type, 'xsd:string') = 'xsd:date' THEN
                DBMS_LOB.APPEND(l_xml,
                    '    <date label="' || NVL(p_params(i).label, p_params(i).name) || '" format="MM-dd-yyyy"/>'||CHR(10));
            ELSE
                DBMS_LOB.APPEND(l_xml,
                    '    <input label="' || NVL(p_params(i).label, p_params(i).name) || '"/>'||CHR(10));
            END IF;
            DBMS_LOB.APPEND(l_xml,
                '  </parameter>'||CHR(10));
        END LOOP;

        DBMS_LOB.APPEND(l_xml, '</parameters>');
        RETURN l_xml;
    END BUILD_PARAMS_XML;

    -- --------------------------------------------------------
    -- DEPLOY_DATA_MODEL (params overload)
    -- --------------------------------------------------------
    PROCEDURE DEPLOY_DATA_MODEL (
        p_session_token IN VARCHAR2,
        p_base_url      IN VARCHAR2,
        p_name          IN VARCHAR2,
        p_xdm_xml       IN CLOB,
        p_folder        IN VARCHAR2      DEFAULT NULL,
        p_params        IN fbt_param_tab_t
    ) IS
        l_xdm CLOB;
    BEGIN
        IF p_params.COUNT > 0 THEN
            l_xdm := REPLACE(p_xdm_xml, '<parameters/>', BUILD_PARAMS_XML(p_params));
        ELSE
            l_xdm := p_xdm_xml;
        END IF;

        DEPLOY_DATA_MODEL(p_session_token, p_base_url, p_name, l_xdm, p_folder);
    END DEPLOY_DATA_MODEL;

    -- --------------------------------------------------------
    -- GET_CATALOG_OBJECT
    -- --------------------------------------------------------
    FUNCTION GET_CATALOG_OBJECT (
        p_session_token IN VARCHAR2,
        p_base_url      IN VARCHAR2,
        p_object_path   IN VARCHAR2
    ) RETURN CLOB IS
        l_url    VARCHAR2(500);
        l_action CONSTANT VARCHAR2(200) :=
            'http://xmlns.oracle.com/oxp/service/v2/CatalogService/getObjectInSessionRequest';
        l_env    CLOB;
        l_resp   CLOB;
        l_b64    VARCHAR2(32767);
    BEGIN
        l_url := RTRIM(p_base_url, '/') || '/xmlpserver/services/v2/CatalogService';

        l_env :=
            '<soapenv:Envelope'||
            ' xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"'||
            ' xmlns:v2="http://xmlns.oracle.com/oxp/service/v2">'||
            '  <soapenv:Header/>'||
            '  <soapenv:Body>'||
            '    <v2:getObjectInSession>'||
            '      <v2:objectAbsolutePath>'||p_object_path||'</v2:objectAbsolutePath>'||
            '      <v2:bipSessionToken>'||p_session_token||'</v2:bipSessionToken>'||
            '    </v2:getObjectInSession>'||
            '  </soapenv:Body>'||
            '</soapenv:Envelope>';

        l_resp := soap_post(l_url, l_action, l_env);

        IF INSTR(l_resp, 'soapenv:Fault') > 0 OR
           INSTR(l_resp, 'soap:Fault')    > 0 THEN
            RAISE_APPLICATION_ERROR(-20011,
                'FBT_BIP_PKG.GET_CATALOG_OBJECT: SOAP Fault. Path: ' || p_object_path ||
                ' | Response: ' || SUBSTR(l_resp, 1, 500));
        END IF;

        -- Extract base64 between tags using DBMS_LOB.COPY (handles large content)
        DECLARE
            l_tag_open  CONSTANT VARCHAR2(50) := '<getObjectInSessionReturn>';
            l_tag_close CONSTANT VARCHAR2(50) := '</getObjectInSessionReturn>';
            l_start PLS_INTEGER;
            l_end   PLS_INTEGER;
            l_amt   PLS_INTEGER;
        BEGIN
            l_start := DBMS_LOB.INSTR(l_resp, l_tag_open) + LENGTH(l_tag_open);
            l_end   := DBMS_LOB.INSTR(l_resp, l_tag_close);
            IF l_start > LENGTH(l_tag_open) AND l_end > l_start THEN
                l_amt := l_end - l_start;
                DBMS_LOB.CREATETEMPORARY(l_b64, TRUE);
                DBMS_LOB.COPY(l_b64, l_resp, l_amt, 1, l_start);
            ELSE
                RAISE_APPLICATION_ERROR(-20011,
                    'FBT_BIP_PKG.GET_CATALOG_OBJECT: Could not extract content from response for ' || p_object_path);
            END IF;
        END;

        RETURN blob_to_clob_utf8(b64_to_blob(l_b64));
    END GET_CATALOG_OBJECT;

    -- --------------------------------------------------------
    -- PRINT_CATALOG_OBJECT
    -- --------------------------------------------------------
    PROCEDURE PRINT_CATALOG_OBJECT (
        p_base_url    IN VARCHAR2,
        p_username    IN VARCHAR2,
        p_password    IN VARCHAR2,
        p_object_path IN VARCHAR2
    ) IS
        l_token   VARCHAR2(4000);
        l_content CLOB;
        l_len     PLS_INTEGER;
        l_offset  PLS_INTEGER := 1;
        l_chunk   PLS_INTEGER := 4000;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('Authenticating as ' || p_username || '...');
        l_token := GET_SESSION_TOKEN(p_base_url, p_username, p_password);

        DBMS_OUTPUT.PUT_LINE('Downloading ' || p_object_path || ' ...');
        l_content := GET_CATALOG_OBJECT(l_token, p_base_url, p_object_path);

        l_len := DBMS_LOB.GETLENGTH(l_content);
        DBMS_OUTPUT.PUT_LINE('Content length: ' || l_len || ' chars');
        DBMS_OUTPUT.PUT_LINE('--- BEGIN ---');

        WHILE l_offset <= l_len LOOP
            DBMS_OUTPUT.PUT_LINE(DBMS_LOB.SUBSTR(l_content, l_chunk, l_offset));
            l_offset := l_offset + l_chunk;
        END LOOP;

        DBMS_OUTPUT.PUT_LINE('--- END ---');
    END PRINT_CATALOG_OBJECT;

    -- --------------------------------------------------------
    -- BUILD_NESTED_XDM
    -- --------------------------------------------------------
    FUNCTION BUILD_NESTED_XDM (
        p_datasets IN fbt_dataset_tab_t,
        p_params   IN fbt_param_tab_t DEFAULT fbt_param_tab_t()
    ) RETURN CLOB IS
        l_xdm CLOB;

        -- Column record parsed from SQL alias
        TYPE col_rec_t IS RECORD (
            col_name  VARCHAR2(200),
            xsd_type  VARCHAR2(30)
        );
        TYPE col_tab_t IS TABLE OF col_rec_t INDEX BY PLS_INTEGER;

        -- Parsed columns keyed by dataset_id
        TYPE ds_cols_t IS TABLE OF col_tab_t INDEX BY PLS_INTEGER;
        l_ds_cols ds_cols_t;

        -- Children lookup: parent_dataset_id -> list of dataset indices
        TYPE idx_tab_t IS TABLE OF PLS_INTEGER INDEX BY PLS_INTEGER;
        TYPE children_t IS TABLE OF idx_tab_t INDEX BY PLS_INTEGER;
        l_children children_t;

        l_root_idx PLS_INTEGER := NULL;

        -- ---------------------------------------------------
        -- Parse column aliases from a SELECT statement.
        -- Looks for "AS ALIAS" patterns (case insensitive).
        -- Returns collection of (col_name, xsd_type).
        -- ---------------------------------------------------
        FUNCTION parse_columns(p_sql IN VARCHAR2) RETURN col_tab_t IS
            l_cols   col_tab_t;
            l_idx    PLS_INTEGER := 0;
            l_upper  VARCHAR2(32767) := UPPER(p_sql);
            l_pos    PLS_INTEGER := 1;
            l_alias  VARCHAR2(200);
            l_type   VARCHAR2(30);
        BEGIN
            -- Find each " AS <ALIAS>" pattern
            LOOP
                l_pos := INSTR(l_upper, ' AS ', l_pos);
                EXIT WHEN l_pos = 0;
                l_pos := l_pos + 4; -- skip past ' AS '

                -- Skip whitespace
                WHILE l_pos <= LENGTH(l_upper) AND SUBSTR(l_upper, l_pos, 1) = ' ' LOOP
                    l_pos := l_pos + 1;
                END LOOP;

                -- Read the alias (word chars: A-Z, 0-9, _)
                l_alias := REGEXP_SUBSTR(l_upper, '[A-Z0-9_]+', l_pos);
                IF l_alias IS NOT NULL THEN
                    -- Determine XSD type from alias suffix
                    IF l_alias LIKE '%\_ID' ESCAPE '\' OR
                       l_alias LIKE '%\_NUM' ESCAPE '\' OR
                       l_alias LIKE '%\_AMOUNT' ESCAPE '\' OR
                       l_alias LIKE '%\_TOTAL' ESCAPE '\' OR
                       l_alias LIKE '%\_PRICE' ESCAPE '\' OR
                       l_alias LIKE '%\_QTY' ESCAPE '\' OR
                       l_alias LIKE '%\_QUANTITY' ESCAPE '\' OR
                       l_alias LIKE '%\_COUNT' ESCAPE '\' THEN
                        l_type := 'xsd:double';
                    ELSIF l_alias LIKE '%\_DATE' ESCAPE '\' THEN
                        l_type := 'xsd:date';
                    ELSE
                        l_type := 'xsd:string';
                    END IF;

                    l_idx := l_idx + 1;
                    l_cols(l_idx).col_name := l_alias;
                    l_cols(l_idx).xsd_type := l_type;
                END IF;

                l_pos := l_pos + NVL(LENGTH(l_alias), 1);
            END LOOP;

            RETURN l_cols;
        END parse_columns;

        -- ---------------------------------------------------
        -- Recursively build nested <group> elements.
        -- ---------------------------------------------------
        PROCEDURE build_group(p_ds_idx IN PLS_INTEGER, p_xdm IN OUT NOCOPY CLOB) IS
            l_ds   fbt_dataset_t := p_datasets(p_ds_idx);
            l_cols col_tab_t;
            l_child_key PLS_INTEGER;
            l_child_tab idx_tab_t;
        BEGIN
            DBMS_LOB.APPEND(p_xdm,
                '        <group name="' || l_ds.group_name || '" label="' || l_ds.group_name ||
                '" source="' || l_ds.dataset_name || '">' || CHR(10));

            -- Elements from parsed columns
            l_cols := l_ds_cols(l_ds.dataset_id);
            FOR i IN 1..l_cols.COUNT LOOP
                DBMS_LOB.APPEND(p_xdm,
                    '          <element name="' || l_cols(i).col_name ||
                    '" value="' || l_cols(i).col_name ||
                    '" dataType="' || l_cols(i).xsd_type ||
                    '" tagName="' || l_cols(i).col_name || '"/>' || CHR(10));
            END LOOP;

            -- Recurse into children
            IF l_children.EXISTS(l_ds.dataset_id) THEN
                l_child_tab := l_children(l_ds.dataset_id);
                FOR c IN 1..l_child_tab.COUNT LOOP
                    build_group(l_child_tab(c), p_xdm);
                END LOOP;
            END IF;

            DBMS_LOB.APPEND(p_xdm, '        </group>' || CHR(10));
        END build_group;

    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_xdm, TRUE);

        -- Phase 1: Parse columns and build children index
        FOR i IN p_datasets.FIRST..p_datasets.LAST LOOP
            l_ds_cols(p_datasets(i).dataset_id) := parse_columns(p_datasets(i).sql_text);

            IF p_datasets(i).parent_dataset_id IS NULL THEN
                l_root_idx := i;
            ELSE
                DECLARE
                    l_pid PLS_INTEGER := p_datasets(i).parent_dataset_id;
                    l_n   PLS_INTEGER;
                BEGIN
                    IF NOT l_children.EXISTS(l_pid) THEN
                        l_children(l_pid)(1) := i;
                    ELSE
                        l_n := l_children(l_pid).COUNT + 1;
                        l_children(l_pid)(l_n) := i;
                    END IF;
                END;
            END IF;
        END LOOP;

        IF l_root_idx IS NULL THEN
            RAISE_APPLICATION_ERROR(-20012, 'BUILD_NESTED_XDM: No root dataset (parent_dataset_id IS NULL) found.');
        END IF;

        -- Phase 2: Build XDM
        DBMS_LOB.APPEND(l_xdm,
            '<?xml version="1.0" encoding="utf-8"?>' || CHR(10) ||
            '<dataModel xmlns="http://xmlns.oracle.com/oxp/xmlp" version="2.1"' || CHR(10) ||
            '           xmlns:xdm="http://xmlns.oracle.com/oxp/xmlp"' || CHR(10) ||
            '           xmlns:xsd="http://www.w3.org/2001/XMLSchema"' || CHR(10) ||
            '           defaultDataSourceRef="ApplicationDB_FSCM">' || CHR(10) ||
            '  <dataProperties>' || CHR(10) ||
            '    <property name="include_parameters" value="true"/>' || CHR(10) ||
            '    <property name="include_null_Element" value="false"/>' || CHR(10) ||
            '    <property name="include_rowsettag" value="false"/>' || CHR(10) ||
            '    <property name="xml_tag_case" value="upper"/>' || CHR(10) ||
            '  </dataProperties>' || CHR(10));

        -- dataSets: one <dataSet> per entry + <link> for non-root
        DBMS_LOB.APPEND(l_xdm, '  <dataSets>' || CHR(10));

        FOR i IN p_datasets.FIRST..p_datasets.LAST LOOP
            DBMS_LOB.APPEND(l_xdm,
                '    <dataSet name="' || p_datasets(i).dataset_name || '" type="complex">' || CHR(10) ||
                '      <sql dataSourceRef="ApplicationDB_FSCM"><![CDATA[' ||
                p_datasets(i).sql_text || ']]></sql>' || CHR(10) ||
                '    </dataSet>' || CHR(10));
        END LOOP;

        -- Links for non-root datasets
        FOR i IN p_datasets.FIRST..p_datasets.LAST LOOP
            IF p_datasets(i).parent_dataset_id IS NOT NULL THEN
                -- Find parent's group_name
                DECLARE
                    l_parent_group VARCHAR2(30);
                BEGIN
                    FOR j IN p_datasets.FIRST..p_datasets.LAST LOOP
                        IF p_datasets(j).dataset_id = p_datasets(i).parent_dataset_id THEN
                            l_parent_group := p_datasets(j).group_name;
                            EXIT;
                        END IF;
                    END LOOP;
                    DBMS_LOB.APPEND(l_xdm,
                        '    <link name="dl-' || p_datasets(i).dataset_id ||
                        '" parentGroup="' || l_parent_group ||
                        '" parentColumn="' || p_datasets(i).parent_join_column ||
                        '" childQuery="' || p_datasets(i).dataset_name ||
                        '" childColumn="' || p_datasets(i).child_join_column || '"/>' || CHR(10));
                END;
            END IF;
        END LOOP;

        DBMS_LOB.APPEND(l_xdm, '  </dataSets>' || CHR(10));

        -- Output: recursive nested groups
        DBMS_LOB.APPEND(l_xdm,
            '  <output rootName="DATA_DS" uniqueRowName="false">' || CHR(10) ||
            '    <nodeList name="data-structure">' || CHR(10) ||
            '      <dataStructure tagName="DATA_DS">' || CHR(10));

        build_group(l_root_idx, l_xdm);

        DBMS_LOB.APPEND(l_xdm,
            '      </dataStructure>' || CHR(10) ||
            '    </nodeList>' || CHR(10) ||
            '  </output>' || CHR(10));

        -- Remaining sections
        DBMS_LOB.APPEND(l_xdm,
            '  <eventTriggers/>' || CHR(10) ||
            '  <lexicals/>' || CHR(10));

        -- Parameters
        IF p_params.COUNT > 0 THEN
            DBMS_LOB.APPEND(l_xdm, BUILD_PARAMS_XML(p_params));
        ELSE
            DBMS_LOB.APPEND(l_xdm, '  <parameters/>' || CHR(10));
        END IF;

        DBMS_LOB.APPEND(l_xdm,
            '  <valueSets/>' || CHR(10) ||
            '  <bursting/>' || CHR(10));

        -- Display: groupLinks for non-root datasets
        DBMS_LOB.APPEND(l_xdm,
            '  <display>' || CHR(10) ||
            '    <layouts>' || CHR(10));

        FOR i IN p_datasets.FIRST..p_datasets.LAST LOOP
            DBMS_LOB.APPEND(l_xdm,
                '      <layout name="' || p_datasets(i).dataset_name || '" left="0px" top="34px"/>' || CHR(10));
        END LOOP;

        DBMS_LOB.APPEND(l_xdm,
            '      <layout name="DATA_DS" left="0px" top="34px"/>' || CHR(10) ||
            '    </layouts>' || CHR(10) ||
            '    <groupLinks>' || CHR(10));

        FOR i IN p_datasets.FIRST..p_datasets.LAST LOOP
            IF p_datasets(i).parent_dataset_id IS NOT NULL THEN
                DECLARE
                    l_parent_group VARCHAR2(30);
                BEGIN
                    FOR j IN p_datasets.FIRST..p_datasets.LAST LOOP
                        IF p_datasets(j).dataset_id = p_datasets(i).parent_dataset_id THEN
                            l_parent_group := p_datasets(j).group_name;
                            EXIT;
                        END IF;
                    END LOOP;
                    DBMS_LOB.APPEND(l_xdm,
                        '      <groupLink name="gl-' || p_datasets(i).dataset_id ||
                        '" parentGroup="' || l_parent_group ||
                        '" childGroup="' || p_datasets(i).group_name || '"/>' || CHR(10));
                END;
            END IF;
        END LOOP;

        DBMS_LOB.APPEND(l_xdm,
            '    </groupLinks>' || CHR(10) ||
            '  </display>' || CHR(10) ||
            '</dataModel>' || CHR(10));

        RETURN l_xdm;
    END BUILD_NESTED_XDM;

    -- --------------------------------------------------------
    -- RUN_POC_TEST
    -- --------------------------------------------------------
    PROCEDURE RUN_POC_TEST (
        p_base_url IN VARCHAR2,
        p_username IN VARCHAR2,
        p_password IN VARCHAR2
    ) IS
        C_DM_NAME CONSTANT VARCHAR2(50) := 'FBT_POC_DM';
        l_folder  VARCHAR2(500);
        l_token   VARCHAR2(4000);
        l_xdm_xml CLOB;
        l_resp    CLOB;
    BEGIN
        l_folder := '/~' || p_username;

        DBMS_OUTPUT.PUT_LINE('FBT_BIP_PKG.RUN_POC_TEST start. Folder: ' || l_folder);

        -- Data model: 2 columns (ROW_NUM, LABEL), 2 rows from DUAL.
        -- Uses ApplicationDB_FSCM + REF CURSOR pattern.
        -- SELECT FROM DUAL is confirmed to work on Fusion demo instances.
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
        l_token := GET_SESSION_TOKEN(p_base_url, p_username, p_password);
        DBMS_OUTPUT.PUT_LINE('  Session token obtained.');

        -- Step 2: Cleanup any object left from a previous run (errors swallowed)
        DELETE_DATA_MODEL(l_token, p_base_url, C_DM_NAME, l_folder);
        DBMS_OUTPUT.PUT_LINE('  Cleanup complete (previous ' || C_DM_NAME || ' removed if present).');

        -- Step 3: Deploy data model (persistent â€” kept for inspection)
        DEPLOY_DATA_MODEL(l_token, p_base_url, C_DM_NAME, l_xdm_xml, l_folder);
        DBMS_OUTPUT.PUT_LINE('  Data model deployed: ' || l_folder || '/' || C_DM_NAME || '.xdm');

        -- Step 4: Test â€” run the data model; does NOT delete it
        l_resp := TEST_DATA_MODEL(l_token, p_base_url, C_DM_NAME, l_folder);
        DBMS_OUTPUT.PUT_LINE('  Data model ran. Response length: ' ||
                             DBMS_LOB.GETLENGTH(l_resp));
        DBMS_OUTPUT.PUT_LINE('  Response preview: ' || SUBSTR(l_resp, 1, 400));

        DBMS_OUTPUT.PUT_LINE('RUN_POC_TEST SUCCESS. Object kept: ' ||
                             l_folder || '/' || C_DM_NAME || '.xdm');
    END RUN_POC_TEST;

END FBT_BIP_PKG;
/
