CREATE OR REPLACE PACKAGE BODY DMT_LOOKUP.DMT_LKP_REFRESH_PKG AS
-- ============================================================
-- DMT_LKP_REFRESH_PKG Body
-- BIP v2 SOAP: login -> runDataModel -> parse XML -> MERGE
-- ============================================================

    C_PKG CONSTANT VARCHAR2(30) := 'DMT_LKP_REFRESH_PKG';

    -- --------------------------------------------------------
    -- Private: Fusion base URL from DMT_OWNER config
    -- --------------------------------------------------------
    FUNCTION fusion_base RETURN VARCHAR2 IS
        v_url VARCHAR2(500);
    BEGIN
        SELECT config_value INTO v_url
        FROM DMT_OWNER.DMT_CONFIG_TBL
        WHERE config_key = 'FUSION_URL';
        RETURN RTRIM(v_url, '/');
    END fusion_base;

    -- --------------------------------------------------------
    -- Private: SOAP POST helper
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
    -- Private: BIP v2 login -> session token
    -- --------------------------------------------------------
    FUNCTION get_session_token RETURN VARCHAR2 IS
        l_url    VARCHAR2(500);
        l_action VARCHAR2(200) :=
            'http://xmlns.oracle.com/oxp/service/v2/SecurityService/loginRequest';
        l_env    CLOB;
        l_resp   CLOB;
        l_token  VARCHAR2(4000);
        l_user   VARCHAR2(200);
        l_pass   VARCHAR2(200);
    BEGIN
        l_url := fusion_base || '/xmlpserver/services/v2/SecurityService';

        SELECT config_value INTO l_user FROM DMT_OWNER.DMT_CONFIG_TBL WHERE config_key = 'FUSION_USERNAME';
        SELECT config_value INTO l_pass FROM DMT_OWNER.DMT_CONFIG_TBL WHERE config_key = 'FUSION_PASSWORD';

        l_env :=
            '<soapenv:Envelope'||
            ' xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"'||
            ' xmlns:v2="http://xmlns.oracle.com/oxp/service/v2">'||
            '<soapenv:Header/>'||
            '<soapenv:Body>'||
            '<v2:login>'||
            '<v2:userID>'|| l_user ||'</v2:userID>'||
            '<v2:password>'|| l_pass ||'</v2:password>'||
            '</v2:login>'||
            '</soapenv:Body>'||
            '</soapenv:Envelope>';

        l_resp := soap_post(l_url, l_action, l_env);

        SELECT REGEXP_SUBSTR(l_resp, '<loginReturn>(.*?)</loginReturn>', 1, 1, NULL, 1)
          INTO l_token FROM DUAL;

        IF l_token IS NULL THEN
            RAISE_APPLICATION_ERROR(-20050,
                'BIP login returned no token. Response: ' || SUBSTR(l_resp, 1, 500));
        END IF;

        RETURN l_token;
    END get_session_token;

    -- --------------------------------------------------------
    -- Private: run a pre-deployed data model by catalog path
    -- Uses userID/password auth (not session token).
    -- Returns raw SOAP response containing base64 XML data.
    -- --------------------------------------------------------
    FUNCTION run_data_model (
        p_dm_path IN VARCHAR2
    ) RETURN CLOB IS
        l_url    VARCHAR2(500);
        l_action VARCHAR2(200) :=
            'http://xmlns.oracle.com/oxp/service/v2/ReportService/runDataModelRequest';
        l_env    CLOB;
        l_resp   CLOB;
        l_user   VARCHAR2(200);
        l_pass   VARCHAR2(200);
    BEGIN
        l_url := fusion_base || '/xmlpserver/services/v2/ReportService';

        SELECT config_value INTO l_user FROM DMT_OWNER.DMT_CONFIG_TBL WHERE config_key = 'FUSION_USERNAME';
        SELECT config_value INTO l_pass FROM DMT_OWNER.DMT_CONFIG_TBL WHERE config_key = 'FUSION_PASSWORD';

        l_env :=
            '<soapenv:Envelope'||
            ' xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"'||
            ' xmlns:v2="http://xmlns.oracle.com/oxp/service/v2">'||
            '<soapenv:Header/>'||
            '<soapenv:Body>'||
            '<v2:runDataModel>'||
            '<v2:reportRequest>'||
            '<v2:reportAbsolutePath>'|| p_dm_path ||'</v2:reportAbsolutePath>'||
            '<v2:sizeOfDataChunkDownload>-1</v2:sizeOfDataChunkDownload>'||
            '</v2:reportRequest>'||
            '<v2:userID>'|| l_user ||'</v2:userID>'||
            '<v2:password>'|| l_pass ||'</v2:password>'||
            '</v2:runDataModel>'||
            '</soapenv:Body>'||
            '</soapenv:Envelope>';

        l_resp := soap_post(l_url, l_action, l_env);

        IF INSTR(l_resp, 'soapenv:Fault') > 0 OR INSTR(l_resp, 'soap:Fault') > 0 THEN
            RAISE_APPLICATION_ERROR(-20052,
                'runDataModel Fault for ' || p_dm_path ||
                '. Response: ' || SUBSTR(l_resp, 1, 500));
        END IF;

        RETURN l_resp;
    END run_data_model;

    -- --------------------------------------------------------
    -- Private: extract base64 data from SOAP response, decode
    -- to XML CLOB. BIP returns data in <reportBytes> element.
    -- --------------------------------------------------------
    FUNCTION decode_bip_response (p_resp IN CLOB) RETURN CLOB IS
        l_b64      CLOB;
        l_raw      RAW(32767);
        l_blob     BLOB;
        l_clob     CLOB;
        l_offset   PLS_INTEGER := 1;
        l_chunk    PLS_INTEGER := 32000;
        l_b64_len  PLS_INTEGER;
        l_dest_off INTEGER := 1;
        l_src_off  INTEGER := 1;
        l_lang_ctx INTEGER := DBMS_LOB.DEFAULT_LANG_CTX;
        l_warning  INTEGER;
    BEGIN
        -- Extract base64 content from <reportBytes>...</reportBytes>
        l_b64 := REGEXP_SUBSTR(p_resp, '<reportBytes>(.*?)</reportBytes>', 1, 1, 'n', 1);

        IF l_b64 IS NULL THEN
            -- Try alternate tag name
            l_b64 := REGEXP_SUBSTR(p_resp, '<ns2:reportBytes>(.*?)</ns2:reportBytes>', 1, 1, 'n', 1);
        END IF;

        IF l_b64 IS NULL OR DBMS_LOB.GETLENGTH(l_b64) = 0 THEN
            RETURN NULL;
        END IF;

        -- Strip any whitespace/newlines from base64
        l_b64 := REPLACE(REPLACE(l_b64, CHR(10), ''), CHR(13), '');

        -- Decode base64 to BLOB in chunks
        DBMS_LOB.CREATETEMPORARY(l_blob, TRUE);
        l_b64_len := DBMS_LOB.GETLENGTH(l_b64);

        WHILE l_offset <= l_b64_len LOOP
            l_raw := UTL_ENCODE.BASE64_DECODE(
                UTL_RAW.CAST_TO_RAW(DBMS_LOB.SUBSTR(l_b64, LEAST(l_chunk, l_b64_len - l_offset + 1), l_offset))
            );
            DBMS_LOB.WRITEAPPEND(l_blob, UTL_RAW.LENGTH(l_raw), l_raw);
            l_offset := l_offset + l_chunk;
        END LOOP;

        -- Convert BLOB to CLOB
        DBMS_LOB.CREATETEMPORARY(l_clob, TRUE);
        DBMS_LOB.CONVERTTOCLOB(
            dest_lob     => l_clob,
            src_blob     => l_blob,
            amount       => DBMS_LOB.LOBMAXSIZE,
            dest_offset  => l_dest_off,
            src_offset   => l_src_off,
            blob_csid    => NLS_CHARSET_ID('AL32UTF8'),
            lang_context => l_lang_ctx,
            warning      => l_warning
        );

        DBMS_LOB.FREETEMPORARY(l_blob);
        RETURN l_clob;
    END decode_bip_response;

    -- --------------------------------------------------------
    -- Private: parse XML rows and MERGE into FUSION_VALUES
    -- Expected XML: <DATA_DS><G_ROW><FUSION_VALUE>x</FUSION_VALUE>
    --              <FUSION_ID>n</FUSION_ID><FUSION_DESCRIPTION>d</FUSION_DESCRIPTION></G_ROW>...</DATA_DS>
    -- --------------------------------------------------------
    PROCEDURE parse_and_merge (
        p_lookup_type IN VARCHAR2,
        p_xml         IN CLOB
    ) IS
        l_xml     XMLTYPE;
        l_count   PLS_INTEGER := 0;
    BEGIN
        IF p_xml IS NULL OR DBMS_LOB.GETLENGTH(p_xml) < 10 THEN
            RETURN;
        END IF;

        l_xml := XMLTYPE(p_xml);

        -- MERGE: insert new values, update descriptions on existing
        MERGE INTO DMT_LKP_FUSION_VALUES tgt
        USING (
            SELECT p_lookup_type AS lookup_type,
                   x.fusion_value,
                   x.fusion_id,
                   x.fusion_description
            FROM XMLTABLE('/DATA_DS/G_ROW'
                    PASSING l_xml
                    COLUMNS
                        fusion_value       VARCHAR2(500) PATH 'FUSION_VALUE',
                        fusion_id          NUMBER        PATH 'FUSION_ID',
                        fusion_description VARCHAR2(500) PATH 'FUSION_DESCRIPTION'
                 ) x
            WHERE x.fusion_value IS NOT NULL
        ) src
        ON (tgt.lookup_type = src.lookup_type AND tgt.fusion_value = src.fusion_value)
        WHEN MATCHED THEN UPDATE SET
            tgt.fusion_id          = src.fusion_id,
            tgt.fusion_description = src.fusion_description,
            tgt.active_flag        = 'Y',
            tgt.last_refresh_date  = SYSDATE
        WHEN NOT MATCHED THEN INSERT (
            lookup_type, fusion_value, fusion_id, fusion_description, active_flag, last_refresh_date
        ) VALUES (
            src.lookup_type, src.fusion_value, src.fusion_id, src.fusion_description, 'Y', SYSDATE
        );

        l_count := SQL%ROWCOUNT;

        -- Mark values not in the current refresh as inactive
        UPDATE DMT_LKP_FUSION_VALUES
        SET    active_flag = 'N', last_refresh_date = SYSDATE
        WHERE  lookup_type = p_lookup_type
        AND    active_flag = 'Y'
        AND    last_refresh_date < SYSDATE - (1/86400);  -- not touched this second

        COMMIT;

        INSERT INTO DMT_OWNER.DMT_LOG_TBL (LOG_ID, PACKAGE_NAME, PROCEDURE_NAME, MESSAGE, LOG_TYPE, LOG_DATE)
        VALUES (DMT_OWNER.DMT_LOG_ID_SEQ.NEXTVAL, C_PKG, 'parse_and_merge',
                'REFRESH ' || p_lookup_type || ': merged ' || l_count || ' rows',
                'INFO', SYSDATE);
        COMMIT;

    END parse_and_merge;

    -- ========================================================
    -- Public: REFRESH_FUSION_VALUES
    -- ========================================================
    PROCEDURE REFRESH_FUSION_VALUES (
        p_lookup_type IN VARCHAR2 DEFAULT NULL
    ) IS
        l_resp      CLOB;
        l_xml       CLOB;
        l_dm_path   VARCHAR2(500);

        CURSOR c_types IS
            SELECT lookup_type, bip_catalog_path
            FROM DMT_LKP_TYPE_CONFIG
            WHERE active_flag = 'Y'
            AND (p_lookup_type IS NULL OR lookup_type = p_lookup_type)
            ORDER BY lookup_type;
    BEGIN
        INSERT INTO DMT_OWNER.DMT_LOG_TBL (LOG_ID, PACKAGE_NAME, PROCEDURE_NAME, MESSAGE, LOG_TYPE, LOG_DATE)
        VALUES (DMT_OWNER.DMT_LOG_ID_SEQ.NEXTVAL, C_PKG, 'REFRESH_FUSION_VALUES',
                'Starting refresh. Type filter: ' || NVL(p_lookup_type, 'ALL'),
                'INFO', SYSDATE);
        COMMIT;

        FOR r IN c_types LOOP
            BEGIN
                l_dm_path := r.bip_catalog_path;

                l_resp := run_data_model(l_dm_path);
                l_xml  := decode_bip_response(l_resp);

                parse_and_merge(r.lookup_type, l_xml);

            EXCEPTION
                WHEN OTHERS THEN
                    -- Log error but continue to next type
                    DECLARE
                        l_errmsg VARCHAR2(4000) := SQLERRM;
                    BEGIN
                        INSERT INTO DMT_OWNER.DMT_LOG_TBL (LOG_ID, PACKAGE_NAME, PROCEDURE_NAME, MESSAGE, LOG_TYPE, LOG_DATE)
                        VALUES (DMT_OWNER.DMT_LOG_ID_SEQ.NEXTVAL, C_PKG, 'REFRESH_FUSION_VALUES',
                                'ERROR refreshing ' || r.lookup_type || ': ' || l_errmsg,
                                'ERROR', SYSDATE);
                        COMMIT;
                    END;
            END;
        END LOOP;

        INSERT INTO DMT_OWNER.DMT_LOG_TBL (LOG_ID, PACKAGE_NAME, PROCEDURE_NAME, MESSAGE, LOG_TYPE, LOG_DATE)
        VALUES (DMT_OWNER.DMT_LOG_ID_SEQ.NEXTVAL, C_PKG, 'REFRESH_FUSION_VALUES', 'Refresh complete.', 'INFO', SYSDATE);
        COMMIT;

    END REFRESH_FUSION_VALUES;

    -- ========================================================
    -- Public: REFRESH_ALL_FUSION_VALUES
    -- ========================================================
    PROCEDURE REFRESH_ALL_FUSION_VALUES IS
    BEGIN
        REFRESH_FUSION_VALUES(NULL);
    END REFRESH_ALL_FUSION_VALUES;

END DMT_LKP_REFRESH_PKG;
/
