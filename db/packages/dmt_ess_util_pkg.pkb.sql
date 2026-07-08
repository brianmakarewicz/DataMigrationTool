-- PACKAGE BODY DMT_ESS_UTIL_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_ESS_UTIL_PKG" AS

    C_PKG CONSTANT VARCHAR2(30) := 'DMT_ESS_UTIL_PKG';

    -- ZIP entry record for unzip_all
    TYPE t_zip_entry IS RECORD (
        filename     VARCHAR2(4000),
        content      BLOB
    );
    TYPE t_zip_entries IS TABLE OF t_zip_entry INDEX BY PLS_INTEGER;

    -- Namespace constants for ErpIntegrationService
    C_ERP_NS CONSTANT VARCHAR2(200) := 'http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/';
    C_ERP_NS_TYPES CONSTANT VARCHAR2(200) := 'http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/types/';

    -- --------------------------------------------------------
    -- Private: SOAP HTTP POST with Basic Auth (same pattern as DMT_LOADER_PKG)
    -- --------------------------------------------------------
    FUNCTION soap_http (
        p_url         IN VARCHAR2,
        p_soap_action IN VARCHAR2,
        p_body        IN CLOB
    ) RETURN CLOB IS
        l_req      UTL_HTTP.REQ;
        l_resp     UTL_HTTP.RESP;
        l_response CLOB;
        l_chunk    VARCHAR2(32767);
        l_offset   INTEGER := 1;
        l_amount   INTEGER;
        l_body_len INTEGER;
        l_auth     VARCHAR2(500);
    BEGIN
        -- Central encode+CRLF-strip (was a private copy of the same logic)
        l_auth := DMT_UTIL_PKG.BASIC_AUTH_HEADER;

        UTL_HTTP.SET_RESPONSE_ERROR_CHECK(FALSE);
        UTL_HTTP.SET_TRANSFER_TIMEOUT(300);

        l_req := UTL_HTTP.BEGIN_REQUEST(p_url, 'POST', 'HTTP/1.1');
        UTL_HTTP.SET_HEADER(l_req, 'Authorization',  l_auth);
        UTL_HTTP.SET_HEADER(l_req, 'Content-Type',   'text/xml; charset=utf-8');
        UTL_HTTP.SET_HEADER(l_req, 'Content-Length',  DBMS_LOB.GETLENGTH(p_body));
        UTL_HTTP.SET_HEADER(l_req, 'SOAPAction',      '"' || p_soap_action || '"');

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

        -- Check for HTTP errors
        IF l_resp.status_code NOT BETWEEN 200 AND 299 THEN
            RAISE_APPLICATION_ERROR(-20052,
                'SOAP call failed. HTTP ' || l_resp.status_code ||
                ' | Action: ' || p_soap_action ||
                ' | Response: ' || DBMS_LOB.SUBSTR(l_response, 500, 1));
        END IF;

        -- Check for SOAP Fault in response body (can occur even with HTTP 200)
        IF DBMS_LOB.INSTR(l_response, '<faultstring>') > 0 THEN
            RAISE_APPLICATION_ERROR(-20052,
                'SOAP Fault: ' ||
                REGEXP_SUBSTR(DBMS_LOB.SUBSTR(l_response, 2000, 1),
                    '<faultstring>(.*?)</faultstring>', 1, 1, NULL, 1) ||
                ' | Action: ' || p_soap_action);
        END IF;

        RETURN l_response;
    EXCEPTION
        WHEN OTHERS THEN
            BEGIN UTL_HTTP.END_RESPONSE(l_resp); EXCEPTION WHEN OTHERS THEN NULL; END;
            RAISE;
    END soap_http;

    -- --------------------------------------------------------
    -- Private: SOAP HTTP POST returning BLOB (for MTOM/binary responses).
    -- Same auth and write pattern as soap_http, but reads response
    -- as RAW chunks into a BLOB to preserve binary content.
    -- --------------------------------------------------------
    FUNCTION soap_http_blob (
        p_url         IN VARCHAR2,
        p_soap_action IN VARCHAR2,
        p_body        IN CLOB,
        p_username    IN VARCHAR2 DEFAULT NULL,
        p_password    IN VARCHAR2 DEFAULT NULL
    ) RETURN BLOB IS
        l_req      UTL_HTTP.REQ;
        l_resp     UTL_HTTP.RESP;
        l_response BLOB;
        l_chunk    RAW(32767);
        l_offset   INTEGER := 1;
        l_amount   INTEGER;
        l_body_len INTEGER;
        l_auth     VARCHAR2(500);
        l_txt_chunk VARCHAR2(32767);
    BEGIN
        -- Central encode+CRLF-strip (was a private copy of the same logic)
        l_auth := DMT_UTIL_PKG.BASIC_AUTH_HEADER(p_username, p_password);

        UTL_HTTP.SET_RESPONSE_ERROR_CHECK(FALSE);
        UTL_HTTP.SET_TRANSFER_TIMEOUT(300);

        l_req := UTL_HTTP.BEGIN_REQUEST(p_url, 'POST', 'HTTP/1.1');
        UTL_HTTP.SET_HEADER(l_req, 'Authorization',  l_auth);
        UTL_HTTP.SET_HEADER(l_req, 'Content-Type',   'text/xml; charset=utf-8');
        UTL_HTTP.SET_HEADER(l_req, 'Content-Length',  DBMS_LOB.GETLENGTH(p_body));
        UTL_HTTP.SET_HEADER(l_req, 'SOAPAction',      '"' || p_soap_action || '"');

        l_body_len := DBMS_LOB.GETLENGTH(p_body);
        WHILE l_offset <= l_body_len LOOP
            l_amount := LEAST(8000, l_body_len - l_offset + 1);
            l_txt_chunk := DBMS_LOB.SUBSTR(p_body, l_amount, l_offset);
            UTL_HTTP.WRITE_TEXT(l_req, l_txt_chunk);
            l_offset := l_offset + l_amount;
        END LOOP;

        l_resp := UTL_HTTP.GET_RESPONSE(l_req);
        DBMS_LOB.CREATETEMPORARY(l_response, TRUE);
        BEGIN
            LOOP
                UTL_HTTP.READ_RAW(l_resp, l_chunk, 32767);
                DBMS_LOB.WRITEAPPEND(l_response, UTL_RAW.LENGTH(l_chunk), l_chunk);
            END LOOP;
        EXCEPTION WHEN UTL_HTTP.END_OF_BODY THEN NULL;
        END;
        UTL_HTTP.END_RESPONSE(l_resp);

        RETURN l_response;
    EXCEPTION
        WHEN OTHERS THEN
            BEGIN UTL_HTTP.END_RESPONSE(l_resp); EXCEPTION WHEN OTHERS THEN NULL; END;
            RAISE;
    END soap_http_blob;

    -- --------------------------------------------------------
    -- Private: Extract all files from a ZIP BLOB.
    -- Reads the central directory (PK\001\002) for accurate sizes
    -- (handles data descriptors / streaming ZIPs where local header
    -- has comp_size=0).
    -- --------------------------------------------------------
    FUNCTION unzip_all (p_zip IN BLOB) RETURN t_zip_entries IS
        l_entries         t_zip_entries;
        l_idx             PLS_INTEGER := 0;
        l_pos             INTEGER;
        l_zip_len         INTEGER := DBMS_LOB.GETLENGTH(p_zip);
        l_method          PLS_INTEGER;
        l_comp_size       INTEGER;
        l_name_len        PLS_INTEGER;
        l_extra_len       PLS_INTEGER;
        l_comment_len     PLS_INTEGER;
        l_local_off       INTEGER;
        l_local_name_len  PLS_INTEGER;
        l_local_extra_len PLS_INTEGER;
        l_filename        VARCHAR2(4000);
        l_data            BLOB;
        l_crc32           RAW(4);
        l_uncomp_raw      RAW(4);
        l_cdir_sig        RAW(4) := HEXTORAW('504B0102');
    BEGIN
        -- Find the first central directory entry
        l_pos := DBMS_LOB.INSTR(p_zip, l_cdir_sig, 1);
        IF l_pos = 0 OR l_pos IS NULL THEN
            RETURN l_entries;
        END IF;

        WHILE l_pos + 46 <= l_zip_len LOOP
            IF DBMS_LOB.SUBSTR(p_zip, 4, l_pos) != l_cdir_sig THEN
                EXIT;
            END IF;

            l_method := UTL_RAW.CAST_TO_BINARY_INTEGER(
                DBMS_LOB.SUBSTR(p_zip, 2, l_pos + 10), UTL_RAW.LITTLE_ENDIAN);
            l_comp_size := UTL_RAW.CAST_TO_BINARY_INTEGER(
                DBMS_LOB.SUBSTR(p_zip, 4, l_pos + 20), UTL_RAW.LITTLE_ENDIAN);
            l_crc32 := DBMS_LOB.SUBSTR(p_zip, 4, l_pos + 16);  -- CRC-32 (raw, already little-endian)
            l_uncomp_raw := DBMS_LOB.SUBSTR(p_zip, 4, l_pos + 24);  -- uncompressed size (raw LE)
            l_name_len := UTL_RAW.CAST_TO_BINARY_INTEGER(
                DBMS_LOB.SUBSTR(p_zip, 2, l_pos + 28), UTL_RAW.LITTLE_ENDIAN);
            l_extra_len := UTL_RAW.CAST_TO_BINARY_INTEGER(
                DBMS_LOB.SUBSTR(p_zip, 2, l_pos + 30), UTL_RAW.LITTLE_ENDIAN);
            l_comment_len := UTL_RAW.CAST_TO_BINARY_INTEGER(
                DBMS_LOB.SUBSTR(p_zip, 2, l_pos + 32), UTL_RAW.LITTLE_ENDIAN);
            l_local_off := UTL_RAW.CAST_TO_BINARY_INTEGER(
                DBMS_LOB.SUBSTR(p_zip, 4, l_pos + 42), UTL_RAW.LITTLE_ENDIAN);

            l_filename := UTL_RAW.CAST_TO_VARCHAR2(
                DBMS_LOB.SUBSTR(p_zip, l_name_len, l_pos + 46));

            -- Read local header's name_len and extra_len (may differ)
            l_local_name_len := UTL_RAW.CAST_TO_BINARY_INTEGER(
                DBMS_LOB.SUBSTR(p_zip, 2, l_local_off + 1 + 26), UTL_RAW.LITTLE_ENDIAN);
            l_local_extra_len := UTL_RAW.CAST_TO_BINARY_INTEGER(
                DBMS_LOB.SUBSTR(p_zip, 2, l_local_off + 1 + 28), UTL_RAW.LITTLE_ENDIAN);

            IF l_comp_size > 0 THEN
                DBMS_LOB.CREATETEMPORARY(l_data, TRUE);
                DBMS_LOB.COPY(l_data, p_zip, l_comp_size, 1,
                    l_local_off + 1 + 30 + l_local_name_len + l_local_extra_len);

                l_idx := l_idx + 1;
                l_entries(l_idx).filename := l_filename;

                IF l_method = 0 THEN
                    l_entries(l_idx).content := l_data;
                ELSIF l_method = 8 THEN
                    -- DEFLATED: wrap in gzip envelope for UTL_COMPRESS.LZ_UNCOMPRESS
                    -- gzip = 10-byte header + raw deflate + CRC32(4) + ISIZE(4)
                    DECLARE
                        l_gzip    BLOB;
                        l_gz_hdr  RAW(10) := HEXTORAW('1F8B08000000000000FF');
                        l_gz_trl  RAW(8);
                    BEGIN
                        -- Build trailer: CRC32 + uncompressed size (both little-endian from ZIP)
                        l_gz_trl := UTL_RAW.CONCAT(l_crc32, l_uncomp_raw);
                        DBMS_LOB.CREATETEMPORARY(l_gzip, TRUE);
                        DBMS_LOB.WRITEAPPEND(l_gzip, 10, l_gz_hdr);
                        DBMS_LOB.APPEND(l_gzip, l_data);
                        DBMS_LOB.WRITEAPPEND(l_gzip, 8, l_gz_trl);
                        l_entries(l_idx).content := UTL_COMPRESS.LZ_UNCOMPRESS(l_gzip);
                        IF DBMS_LOB.ISTEMPORARY(l_gzip) = 1 THEN
                            DBMS_LOB.FREETEMPORARY(l_gzip);
                        END IF;
                    EXCEPTION
                        WHEN OTHERS THEN
                            l_entries(l_idx).content := l_data;
                    END;
                    IF DBMS_LOB.ISTEMPORARY(l_data) = 1 THEN
                        DBMS_LOB.FREETEMPORARY(l_data);
                    END IF;
                ELSE
                    l_entries(l_idx).content := l_data;
                END IF;
            END IF;

            l_pos := l_pos + 46 + l_name_len + l_extra_len + l_comment_len;
        END LOOP;

        RETURN l_entries;
    END unzip_all;

    -- --------------------------------------------------------
    -- Private: Extract ZIP BLOB from an MTOM/XOP multipart response.
    -- Finds the PK (ZIP magic bytes 504B0304) in the BLOB and
    -- extracts from there to the next MIME boundary.
    -- Returns NULL if no ZIP found.
    -- --------------------------------------------------------
    FUNCTION extract_mtom_zip (p_mtom IN BLOB) RETURN BLOB IS
        l_pk_sig     RAW(4) := HEXTORAW('504B0304');
        l_pk_pos     INTEGER;
        l_boundary   RAW(100);
        l_bound_pos  INTEGER;
        l_zip_len    INTEGER;
        l_zip        BLOB;
        l_crlf_dash  RAW(4) := HEXTORAW('0D0A2D2D');  -- CRLF followed by --
    BEGIN
        -- Find PK signature (ZIP file start)
        l_pk_pos := DBMS_LOB.INSTR(p_mtom, l_pk_sig, 1);
        IF l_pk_pos = 0 OR l_pk_pos IS NULL THEN
            RETURN NULL;
        END IF;

        -- Find the next CRLF-- after the PK position (start of boundary)
        l_bound_pos := DBMS_LOB.INSTR(p_mtom, l_crlf_dash, l_pk_pos);
        IF l_bound_pos = 0 OR l_bound_pos IS NULL THEN
            -- No boundary found â€” take everything from PK to end
            l_zip_len := DBMS_LOB.GETLENGTH(p_mtom) - l_pk_pos + 1;
        ELSE
            l_zip_len := l_bound_pos - l_pk_pos;
        END IF;

        DBMS_LOB.CREATETEMPORARY(l_zip, TRUE);
        DBMS_LOB.COPY(l_zip, p_mtom, l_zip_len, 1, l_pk_pos);
        RETURN l_zip;
    END extract_mtom_zip;

    -- --------------------------------------------------------
    -- Private: BIP v2 SOAP HTTP POST (no HTTP auth â€” creds in body).
    -- Used by CAPTURE_ESS_HIERARCHY for runReport calls.
    -- --------------------------------------------------------
    FUNCTION bip_soap (
        p_url    IN VARCHAR2,
        p_action IN VARCHAR2,
        p_body   IN CLOB
    ) RETURN CLOB IS
        l_req UTL_HTTP.REQ; l_resp UTL_HTTP.RESP; l_response CLOB; l_chunk VARCHAR2(32767);
        l_offset INTEGER := 1; l_amount INTEGER; l_body_len INTEGER;
    BEGIN
        UTL_HTTP.SET_RESPONSE_ERROR_CHECK(FALSE);
        UTL_HTTP.SET_TRANSFER_TIMEOUT(120);
        l_req := UTL_HTTP.BEGIN_REQUEST(p_url, 'POST', 'HTTP/1.1');
        UTL_HTTP.SET_HEADER(l_req, 'Content-Type', 'text/xml; charset=utf-8');
        UTL_HTTP.SET_HEADER(l_req, 'Content-Length', DBMS_LOB.GETLENGTH(p_body));
        UTL_HTTP.SET_HEADER(l_req, 'SOAPAction', '"' || p_action || '"');
        l_body_len := DBMS_LOB.GETLENGTH(p_body);
        WHILE l_offset <= l_body_len LOOP
            l_amount := LEAST(8000, l_body_len - l_offset + 1);
            l_chunk := DBMS_LOB.SUBSTR(p_body, l_amount, l_offset);
            UTL_HTTP.WRITE_TEXT(l_req, l_chunk); l_offset := l_offset + l_amount;
        END LOOP;
        l_resp := UTL_HTTP.GET_RESPONSE(l_req);
        DBMS_LOB.CREATETEMPORARY(l_response, TRUE);
        BEGIN LOOP UTL_HTTP.READ_TEXT(l_resp, l_chunk, 32767); DBMS_LOB.APPEND(l_response, l_chunk); END LOOP;
        EXCEPTION WHEN UTL_HTTP.END_OF_BODY THEN NULL; END;
        UTL_HTTP.END_RESPONSE(l_resp);
        RETURN l_response;
    EXCEPTION WHEN OTHERS THEN BEGIN UTL_HTTP.END_RESPONSE(l_resp); EXCEPTION WHEN OTHERS THEN NULL; END; RAISE;
    END bip_soap;

    -- --------------------------------------------------------
    -- Private: map ESS state code to text
    -- --------------------------------------------------------
    FUNCTION state_text (p_state IN NUMBER) RETURN VARCHAR2 IS
    BEGIN
        RETURN CASE p_state
            WHEN 1  THEN 'WAIT'
            WHEN 2  THEN 'READY'
            WHEN 3  THEN 'RUNNING'
            WHEN 4  THEN 'COMPLETED'
            WHEN 5  THEN 'BLOCKED'
            WHEN 6  THEN 'HOLD'
            WHEN 7  THEN 'CANCELLING'
            WHEN 8  THEN 'CANCELLED'
            WHEN 9  THEN 'PAUSED'
            WHEN 10 THEN 'ERROR'
            WHEN 11 THEN 'WARNING'
            WHEN 12 THEN 'SUCCEEDED'
            WHEN 13 THEN 'EXPIRED'
            ELSE 'UNKNOWN(' || p_state || ')'
        END;
    END state_text;

    -- ============================================================
    -- CAPTURE_ESS_HIERARCHY
    -- Queries ESS_REQUEST_HISTORY via pre-deployed BIP DM (AD#16)
    -- for the parent + all descendants. Inserts into DMT_ESS_JOB_TBL.
    --
    -- Uses: /Custom/DMT/common/DMT_ESS_HIERARCHY_RPT.xdo
    -- Parameter: P_PARENT_REQUEST_ID
    -- ============================================================
    PROCEDURE CAPTURE_ESS_HIERARCHY (
        p_run_id    IN NUMBER,
        p_parent_request_id IN NUMBER,
        p_cemli_code        IN VARCHAR2 DEFAULT NULL
    ) IS
        C_PROC     CONSTANT VARCHAR2(30)  := 'CAPTURE_ESS_HIERARCHY';
        C_RPT_PATH CONSTANT VARCHAR2(200) := '/Custom/DMT/common/DMT_ESS_HIERARCHY_RPT.xdo';

        l_base_url  VARCHAR2(500);
        l_bip_user  VARCHAR2(100);
        l_bip_pass  VARCHAR2(100);
        l_url       VARCHAR2(500);
        l_env       CLOB;
        l_resp      CLOB;
        l_xml       XMLTYPE;
        l_row_count NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id,
            'CAPTURE_ESS_HIERARCHY start. Parent: ' || p_parent_request_id,
            'INFO', C_PKG, C_PROC);

        l_base_url := RTRIM(DMT_UTIL_PKG.GET_CONFIG('FUSION_URL'), '/');
        l_bip_user := NVL(DMT_UTIL_PKG.GET_CONFIG('BIP_USERNAME'), DMT_UTIL_PKG.GET_CONFIG('FUSION_USERNAME'));
        l_bip_pass := NVL(DMT_UTIL_PKG.GET_CONFIG('BIP_PASSWORD'), DMT_UTIL_PKG.GET_CONFIG('FUSION_PASSWORD'));
        l_url      := l_base_url || '/xmlpserver/services/v2/ReportService';

        -- Call runReport on the pre-deployed static DM with P_PARENT_REQUEST_ID
        DBMS_LOB.CREATETEMPORARY(l_env, TRUE);
        DBMS_LOB.APPEND(l_env, TO_CLOB(
            '<soapenv:Envelope' ||
            ' xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"' ||
            ' xmlns:v2="http://xmlns.oracle.com/oxp/service/v2">' ||
            '<soapenv:Header/><soapenv:Body>' ||
            '<v2:runReport><v2:reportRequest>' ||
            '<v2:reportAbsolutePath>' || C_RPT_PATH || '</v2:reportAbsolutePath>' ||
            '<v2:attributeFormat>xml</v2:attributeFormat>' ||
            '<v2:parameterNameValues><v2:listOfParamNameValues>' ||
            '<v2:item><v2:name>P_PARENT_REQUEST_ID</v2:name>' ||
            '<v2:values><v2:item>' || TO_CHAR(p_parent_request_id) || '</v2:item></v2:values>' ||
            '</v2:item>' ||
            '</v2:listOfParamNameValues></v2:parameterNameValues>' ||
            '<v2:sizeOfDataChunkDownload>-1</v2:sizeOfDataChunkDownload>' ||
            '</v2:reportRequest>' ||
            '<v2:userID>' || l_bip_user || '</v2:userID>' ||
            '<v2:password>' || l_bip_pass || '</v2:password>' ||
            '</v2:runReport></soapenv:Body></soapenv:Envelope>'));

        l_resp := bip_soap(l_url,
            'http://xmlns.oracle.com/oxp/service/v2/ReportService/runReportRequest', l_env);

        DBMS_LOB.FREETEMPORARY(l_env);

        -- Decode base64 reportBytes -> XML via the shared any-size extractor.
        -- (Was: a regexp read into a VARCHAR2(32767) + single-shot UTL_ENCODE
        -- decode - the exact >32K truncation bug family BIP_REPORT_XML exists
        -- to remove; a large hierarchy was silently dropped as
        -- "No ESS hierarchy data returned".)
        l_xml := DMT_UTIL_PKG.BIP_REPORT_XML(l_resp);

        IF l_xml IS NULL THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'No ESS hierarchy data returned for parent ' || p_parent_request_id,
                'WARN', C_PKG, C_PROC);
            RETURN;
        END IF;

        FOR r IN (
            SELECT x.req_id, x.parent_id, x.job_def, x.state_code, x.submitter,
                   x.start_ts, x.end_ts, x.depth_lvl
            FROM XMLTABLE('/DATA_DS/G_1' PASSING l_xml COLUMNS
                req_id     VARCHAR2(30)  PATH 'REQ_ID',
                parent_id  VARCHAR2(30)  PATH 'PARENT_ID',
                job_def    VARCHAR2(500) PATH 'JOB_DEF',
                state_code VARCHAR2(10)  PATH 'STATE_CODE',
                submitter  VARCHAR2(100) PATH 'SUBMITTER',
                start_ts   VARCHAR2(30)  PATH 'START_TS',
                end_ts     VARCHAR2(30)  PATH 'END_TS',
                depth_lvl  VARCHAR2(10)  PATH 'DEPTH_LVL') x
        ) LOOP
            DECLARE
                l_state      NUMBER := TO_NUMBER(r.state_code);
                l_state_txt  VARCHAR2(30);
                l_short      VARCHAR2(200);
            BEGIN
                -- Extract short name from job definition
                l_short     := SUBSTR(r.job_def, INSTR(r.job_def, '/', -1) + 1);
                l_state_txt := state_text(l_state);

                INSERT INTO DMT_OWNER.DMT_ESS_JOB_TBL (
                    RUN_ID, REQUEST_ID, PARENT_REQUEST_ID,
                    JOB_DEFINITION, JOB_SHORT_NAME, STATE, STATE_TEXT,
                    SUBMITTER, START_TIME, END_TIME,
                    CEMLI_CODE, DEPTH_LEVEL
                ) VALUES (
                    p_run_id,
                    TO_NUMBER(r.req_id),
                    CASE WHEN r.parent_id = r.req_id THEN NULL ELSE TO_NUMBER(r.parent_id) END,
                    r.job_def, l_short, l_state, l_state_txt,
                    r.submitter,
                    TO_DATE(r.start_ts, 'YYYY-MM-DD HH24:MI:SS'),
                    TO_DATE(r.end_ts, 'YYYY-MM-DD HH24:MI:SS'),
                    p_cemli_code,
                    NVL(TO_NUMBER(r.depth_lvl), 0)
                );
                l_row_count := l_row_count + 1;
            EXCEPTION
                WHEN DUP_VAL_ON_INDEX THEN NULL; -- already captured
            END;
        END LOOP;

        COMMIT;
        DMT_UTIL_PKG.LOG(p_run_id,
            'CAPTURE_ESS_HIERARCHY complete. Jobs captured: ' || l_row_count,
            'INFO', C_PKG, C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'CAPTURE_ESS_HIERARCHY failed.', SQLERRM, C_PKG, C_PROC);
            -- Don't re-raise â€” hierarchy capture is diagnostic, not critical path
    END CAPTURE_ESS_HIERARCHY;

    -- ============================================================
    -- DOWNLOAD_ESS_FILE
    -- Calls downloadESSJobExecutionDetails on ErpIntegrationService.
    -- Returns the raw SOAP response as CLOB (legacy â€” use DOWNLOAD_ESS_FILE_BLOB for MTOM).
    -- ============================================================
    FUNCTION DOWNLOAD_ESS_FILE (
        p_request_id IN NUMBER,
        p_file_type  IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB IS
        l_base_url VARCHAR2(500);
        l_env      CLOB;
        l_resp     CLOB;
        l_action   CONSTANT VARCHAR2(200) :=
            C_ERP_NS_TYPES || 'downloadESSJobExecutionDetails';
        l_file_type_xml VARCHAR2(100) := '';
    BEGIN
        l_base_url := RTRIM(DMT_UTIL_PKG.GET_CONFIG('FUSION_URL'), '/');

        IF p_file_type IS NOT NULL THEN
            l_file_type_xml := '<typ:fileType>' || p_file_type || '</typ:fileType>';
        END IF;

        l_env := TO_CLOB(
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"' ||
            ' xmlns:typ="' || C_ERP_NS_TYPES || '">' ||
            '<soapenv:Header/><soapenv:Body>' ||
            '<typ:downloadESSJobExecutionDetails>' ||
            '<typ:requestId>' || TO_CHAR(p_request_id) || '</typ:requestId>' ||
            l_file_type_xml ||
            '</typ:downloadESSJobExecutionDetails>' ||
            '</soapenv:Body></soapenv:Envelope>');

        l_resp := soap_http(
            p_url         => l_base_url || '/fscmService/ErpIntegrationService',
            p_soap_action => l_action,
            p_body        => l_env);

        RETURN l_resp;
    END DOWNLOAD_ESS_FILE;

    -- ============================================================
    -- DOWNLOAD_ESS_FILE_BLOB
    -- Calls downloadESSJobExecutionDetails, returns MTOM response as BLOB.
    -- Use this for all ESS output downloads â€” binary-safe.
    -- ============================================================
    FUNCTION DOWNLOAD_ESS_FILE_BLOB (
        p_request_id IN NUMBER,
        p_file_type  IN VARCHAR2 DEFAULT NULL,
        p_username   IN VARCHAR2 DEFAULT NULL,
        p_password   IN VARCHAR2 DEFAULT NULL
    ) RETURN BLOB IS
        l_base_url VARCHAR2(500);
        l_env      CLOB;
        l_action   CONSTANT VARCHAR2(200) :=
            C_ERP_NS_TYPES || 'downloadESSJobExecutionDetails';
        l_file_type_xml VARCHAR2(100) := '';
    BEGIN
        l_base_url := RTRIM(DMT_UTIL_PKG.GET_CONFIG('FUSION_URL'), '/');

        IF p_file_type IS NOT NULL THEN
            l_file_type_xml := '<typ:fileType>' || p_file_type || '</typ:fileType>';
        END IF;

        l_env := TO_CLOB(
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"' ||
            ' xmlns:typ="' || C_ERP_NS_TYPES || '">' ||
            '<soapenv:Header/><soapenv:Body>' ||
            '<typ:downloadESSJobExecutionDetails>' ||
            '<typ:requestId>' || TO_CHAR(p_request_id) || '</typ:requestId>' ||
            l_file_type_xml ||
            '</typ:downloadESSJobExecutionDetails>' ||
            '</soapenv:Body></soapenv:Envelope>');

        RETURN soap_http_blob(
            p_url         => l_base_url || '/fscmService/ErpIntegrationService',
            p_soap_action => l_action,
            p_body        => l_env,
            p_username    => p_username,
            p_password    => p_password);
    END DOWNLOAD_ESS_FILE_BLOB;

    -- ============================================================
    -- GET_ESS_ZIP
    -- Downloads ESS output as BLOB, extracts the ZIP from the MTOM
    -- multipart response. Returns the ZIP BLOB (caller uses UTL_ZIP
    -- to extract individual files).
    -- Returns NULL if download fails or no ZIP in response.
    -- ============================================================
    FUNCTION GET_ESS_ZIP (
        p_request_id IN NUMBER,
        p_username   IN VARCHAR2 DEFAULT NULL,
        p_password   IN VARCHAR2 DEFAULT NULL
    ) RETURN BLOB IS
        l_mtom BLOB;
        l_zip  BLOB;
    BEGIN
        l_mtom := DOWNLOAD_ESS_FILE_BLOB(p_request_id, NULL, p_username, p_password);
        IF l_mtom IS NULL OR DBMS_LOB.GETLENGTH(l_mtom) = 0 THEN
            RETURN NULL;
        END IF;
        l_zip := extract_mtom_zip(l_mtom);
        IF DBMS_LOB.ISTEMPORARY(l_mtom) = 1 THEN
            DBMS_LOB.FREETEMPORARY(l_mtom);
        END IF;
        RETURN l_zip;
    END GET_ESS_ZIP;

    -- ============================================================
    -- GET_ESS_OUTPUT_TEXT
    -- Downloads ESS output ZIP, extracts the .log file, returns as CLOB.
    -- Falls back to extracting .xml if no .log found.
    -- ============================================================
    FUNCTION GET_ESS_OUTPUT_TEXT (
        p_request_id IN NUMBER,
        p_file_type  IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB IS
        l_zip      BLOB;
        l_entries  t_zip_entries;
        l_content  BLOB;
        l_clob     CLOB;
        l_dest_off INTEGER := 1;
        l_src_off  INTEGER := 1;
        l_lang_ctx INTEGER := DBMS_LOB.DEFAULT_LANG_CTX;
        l_warning  INTEGER;
    BEGIN
        l_zip := GET_ESS_ZIP(p_request_id);
        IF l_zip IS NULL THEN
            RETURN NULL;
        END IF;

        l_entries := unzip_all(l_zip);
        IF DBMS_LOB.ISTEMPORARY(l_zip) = 1 THEN
            DBMS_LOB.FREETEMPORARY(l_zip);
        END IF;

        -- Find .log file first, then .xml
        FOR i IN 1 .. l_entries.COUNT LOOP
            IF l_entries(i).filename LIKE '%.log' THEN
                l_content := l_entries(i).content;
                EXIT;
            END IF;
        END LOOP;
        IF l_content IS NULL THEN
            FOR i IN 1 .. l_entries.COUNT LOOP
                IF l_entries(i).filename LIKE '%.xml' THEN
                    l_content := l_entries(i).content;
                    EXIT;
                END IF;
            END LOOP;
        END IF;

        IF l_content IS NULL THEN
            RETURN NULL;
        END IF;

        -- Convert BLOB to CLOB (UTF-8)
        DBMS_LOB.CREATETEMPORARY(l_clob, TRUE);
        DBMS_LOB.CONVERTTOCLOB(
            dest_lob     => l_clob,
            src_blob     => l_content,
            amount       => DBMS_LOB.LOBMAXSIZE,
            dest_offset  => l_dest_off,
            src_offset   => l_src_off,
            blob_csid    => DBMS_LOB.DEFAULT_CSID,
            lang_context => l_lang_ctx,
            warning      => l_warning);

        RETURN l_clob;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'Error downloading ESS output: ' || SQLERRM;
    END GET_ESS_OUTPUT_TEXT;

    -- ============================================================
    -- GET_ESS_OUTPUT_XML
    -- Downloads ESS output ZIP, extracts the BIP XML report file.
    -- Returns as CLOB. Used for Import Report error parsing.
    -- ============================================================
    FUNCTION GET_ESS_OUTPUT_XML (
        p_request_id IN NUMBER
    ) RETURN CLOB IS
        l_zip      BLOB;
        l_entries  t_zip_entries;
        l_content  BLOB;
        l_clob     CLOB;
        l_dest_off INTEGER := 1;
        l_src_off  INTEGER := 1;
        l_lang_ctx INTEGER := DBMS_LOB.DEFAULT_LANG_CTX;
        l_warning  INTEGER;
    BEGIN
        l_zip := GET_ESS_ZIP(p_request_id);
        IF l_zip IS NULL THEN
            RETURN NULL;
        END IF;

        l_entries := unzip_all(l_zip);
        IF DBMS_LOB.ISTEMPORARY(l_zip) = 1 THEN
            DBMS_LOB.FREETEMPORARY(l_zip);
        END IF;

        FOR i IN 1 .. l_entries.COUNT LOOP
            IF l_entries(i).filename LIKE '%.xml' THEN
                l_content := l_entries(i).content;
                EXIT;
            END IF;
        END LOOP;

        IF l_content IS NULL THEN
            RETURN NULL;
        END IF;

        DBMS_LOB.CREATETEMPORARY(l_clob, TRUE);
        DBMS_LOB.CONVERTTOCLOB(
            dest_lob     => l_clob,
            src_blob     => l_content,
            amount       => DBMS_LOB.LOBMAXSIZE,
            dest_offset  => l_dest_off,
            src_offset   => l_src_off,
            blob_csid    => DBMS_LOB.DEFAULT_CSID,
            lang_context => l_lang_ctx,
            warning      => l_warning);

        RETURN l_clob;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'Error downloading ESS output XML: ' || SQLERRM;
    END GET_ESS_OUTPUT_XML;

    -- ============================================================
    -- CAPTURE_ESS_OUTPUT
    -- Downloads ESS output for a given request ID and writes it
    -- to DMT_LOG_TBL for diagnostic purposes.
    -- ============================================================
    PROCEDURE CAPTURE_ESS_OUTPUT (
        p_run_id IN NUMBER,
        p_request_id     IN NUMBER,
        p_cemli_code     IN VARCHAR2 DEFAULT NULL
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'CAPTURE_ESS_OUTPUT';
        l_output     CLOB;
        l_log_ctx    VARCHAR2(80);
        l_chunk      VARCHAR2(4000);
        l_offset     INTEGER := 1;
        l_out_len    INTEGER;
        l_chunk_num  INTEGER := 0;
    BEGIN
        l_log_ctx := NVL2(p_cemli_code, p_cemli_code || ' > ', '') || C_PROC;

        DMT_UTIL_PKG.LOG(p_run_id,
            'Downloading ESS output for request ' || p_request_id || ' ...',
            'INFO', C_PKG, l_log_ctx);

        l_output := GET_ESS_OUTPUT_TEXT(p_request_id);

        IF l_output IS NULL THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'No ESS output available for request ' || p_request_id || '.',
                'WARN', C_PKG, l_log_ctx);
            RETURN;
        END IF;

        l_out_len := DBMS_LOB.GETLENGTH(l_output);
        DMT_UTIL_PKG.LOG(p_run_id,
            'ESS output downloaded. Length: ' || l_out_len || ' chars.',
            'INFO', C_PKG, l_log_ctx);

        -- Write output to log in 3950-char chunks (LOG column is VARCHAR2(4000);
        -- leave room for the ESS_OUTPUT prefix)
        WHILE l_offset <= l_out_len LOOP
            l_chunk_num := l_chunk_num + 1;
            l_chunk := DBMS_LOB.SUBSTR(l_output, 3950, l_offset);
            DMT_UTIL_PKG.LOG(p_run_id,
                'ESS_OUTPUT[' || p_request_id || '] chunk ' || l_chunk_num || ': ' || l_chunk,
                'INFO', C_PKG, l_log_ctx);
            l_offset := l_offset + 3950;
        END LOOP;

        DBMS_LOB.FREETEMPORARY(l_output);

    EXCEPTION
        WHEN OTHERS THEN
            BEGIN
                IF l_output IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_output) = 1 THEN
                    DBMS_LOB.FREETEMPORARY(l_output);
                END IF;
            EXCEPTION WHEN OTHERS THEN NULL;
            END;
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'CAPTURE_ESS_OUTPUT failed for request ' || p_request_id || '.',
                SQLERRM, C_PKG, l_log_ctx);
            -- Non-critical â€” don't re-raise
    END CAPTURE_ESS_OUTPUT;

    -- ============================================================
    -- ENUMERATE_ESS_FILES
    -- Downloads MTOM response for a single ESS job, parses the ZIP
    -- central directory to discover filenames, inserts metadata rows
    -- into DMT_ESS_JOB_FILE_TBL. File content is NOT stored.
    -- ============================================================
    PROCEDURE ENUMERATE_ESS_FILES (
        p_ess_job_id   IN NUMBER,
        p_request_id   IN NUMBER,
        p_username     IN VARCHAR2 DEFAULT NULL,
        p_password     IN VARCHAR2 DEFAULT NULL
    ) IS
        C_PROC    CONSTANT VARCHAR2(30) := 'ENUMERATE_ESS_FILES';
        l_zip     BLOB;
        l_entries t_zip_entries;
        l_ext     VARCHAR2(30);
        l_ftype   VARCHAR2(30);
        l_ctype   VARCHAR2(100);
    BEGIN
        -- Download and extract ZIP from MTOM response
        l_zip := GET_ESS_ZIP(p_request_id, p_username, p_password);
        IF l_zip IS NULL OR DBMS_LOB.GETLENGTH(l_zip) = 0 THEN
            RETURN; -- no output files for this job
        END IF;

        -- Parse ZIP to get filenames (content is extracted but we discard it)
        DMT_UTIL_PKG.LOG(NULL,
            'ENUMERATE_ESS_FILES: ZIP size=' || DBMS_LOB.GETLENGTH(l_zip) ||
            ' for request_id=' || p_request_id, 'INFO', C_PKG, C_PROC);
        l_entries := unzip_all(l_zip);
        DMT_UTIL_PKG.LOG(NULL,
            'ENUMERATE_ESS_FILES: unzip_all returned ' || l_entries.COUNT ||
            ' entries for request_id=' || p_request_id, 'INFO', C_PKG, C_PROC);
        IF DBMS_LOB.ISTEMPORARY(l_zip) = 1 THEN
            DBMS_LOB.FREETEMPORARY(l_zip);
        END IF;

        FOR i IN 1 .. l_entries.COUNT LOOP
            -- Derive FILE_TYPE and CONTENT_TYPE from extension
            l_ext := LOWER(SUBSTR(l_entries(i).filename,
                INSTR(l_entries(i).filename, '.', -1) + 1));
            CASE l_ext
                WHEN 'log' THEN l_ftype := 'LOG'; l_ctype := 'text/plain';
                WHEN 'xml' THEN l_ftype := 'XML'; l_ctype := 'application/xml';
                WHEN 'zip' THEN l_ftype := 'OUT'; l_ctype := 'application/zip';
                WHEN 'csv' THEN l_ftype := 'OUT'; l_ctype := 'text/csv';
                WHEN 'txt' THEN l_ftype := 'LOG'; l_ctype := 'text/plain';
                ELSE             l_ftype := 'OUT'; l_ctype := 'application/octet-stream';
            END CASE;

            BEGIN
                INSERT INTO DMT_OWNER.DMT_ESS_JOB_FILE_TBL (
                    ESS_JOB_ID, REQUEST_ID, FILE_TYPE, FILE_NAME, CONTENT_TYPE
                ) VALUES (
                    p_ess_job_id, p_request_id, l_ftype,
                    l_entries(i).filename, l_ctype
                );
            EXCEPTION
                WHEN DUP_VAL_ON_INDEX THEN NULL; -- already enumerated
            END;

            -- Free the BLOB content we don't need
            IF DBMS_LOB.ISTEMPORARY(l_entries(i).content) = 1 THEN
                DBMS_LOB.FREETEMPORARY(l_entries(i).content);
            END IF;
        END LOOP;

        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG(NULL,
                'ENUMERATE_ESS_FILES failed for ess_job_id=' || p_ess_job_id ||
                ' request_id=' || p_request_id || ': ' || SQLERRM ||
                ' | ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE,
                'ERROR', C_PKG, C_PROC);
    END ENUMERATE_ESS_FILES;

    -- ============================================================
    -- ENUMERATE_ALL_ESS_FILES
    -- Loops through all jobs (depth >= 0) for an integration run and
    -- enumerates their output files into DMT_ESS_JOB_FILE_TBL.
    -- Called after CAPTURE_ESS_HIERARCHY.
    -- ============================================================
    PROCEDURE ENUMERATE_ALL_ESS_FILES (
        p_run_id IN NUMBER,
        p_username       IN VARCHAR2 DEFAULT NULL,
        p_password       IN VARCHAR2 DEFAULT NULL
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'ENUMERATE_ALL_ESS_FILES';
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id,
            'Enumerating ESS output files for integration ' || p_run_id,
            'INFO', C_PKG, C_PROC);

        FOR r IN (
            SELECT ESS_JOB_ID, REQUEST_ID
            FROM DMT_OWNER.DMT_ESS_JOB_TBL
            WHERE RUN_ID = p_run_id
              AND DEPTH_LEVEL >= 0  -- all jobs including top-level (Import jobs at depth 0 have output)
        ) LOOP
            ENUMERATE_ESS_FILES(r.ESS_JOB_ID, r.REQUEST_ID, p_username, p_password);
        END LOOP;

        DMT_UTIL_PKG.LOG(p_run_id,
            'ESS file enumeration complete for integration ' || p_run_id,
            'INFO', C_PKG, C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'ENUMERATE_ALL_ESS_FILES failed.', SQLERRM, C_PKG, C_PROC);
            -- Non-critical â€” don't re-raise
    END ENUMERATE_ALL_ESS_FILES;

    -- ============================================================
    -- DOWNLOAD_ESS_FILE_TO_BROWSER
    -- Downloads a specific file from an ESS job's output ZIP and
    -- streams it to the browser with proper HTTP headers.
    -- Called from APEX AJAX callback on Page 57.
    -- ============================================================
    PROCEDURE DOWNLOAD_ESS_FILE_TO_BROWSER (
        p_request_id IN NUMBER,
        p_file_name  IN VARCHAR2,
        p_username   IN VARCHAR2 DEFAULT NULL,
        p_password   IN VARCHAR2 DEFAULT NULL
    ) IS
        C_PROC    CONSTANT VARCHAR2(30) := 'DOWNLOAD_ESS_FILE_TO_BROWSER';
        l_zip     BLOB;
        l_entries t_zip_entries;
        l_found   BOOLEAN := FALSE;
        l_content BLOB;
        l_ctype   VARCHAR2(100);
        l_ext     VARCHAR2(30);
        l_user    VARCHAR2(100) := p_username;
        l_pass    VARCHAR2(100) := p_password;
    BEGIN
        -- Auto-resolve credentials from request_id if not explicitly passed.
        -- Uses per-CEMLI override from DMT_ERP_INTERFACE_OPTIONS_TBL.FUSION_USERNAME/PASSWORD,
        -- falling back to DMT_CONFIG_TBL defaults. The SOAP downloadESSJobExecutionDetails
        -- call requires the same user that submitted the ESS job or it returns FND-2.
        IF l_user IS NULL THEN
            DMT_UTIL_PKG.GET_CREDENTIALS_FOR_REQUEST(p_request_id, l_user, l_pass);
        END IF;

        -- Download and extract ZIP
        l_zip := GET_ESS_ZIP(p_request_id, l_user, l_pass);
        IF l_zip IS NULL OR DBMS_LOB.GETLENGTH(l_zip) = 0 THEN
            HTP.P('No output files available for ESS job ' || p_request_id);
            RETURN;
        END IF;

        l_entries := unzip_all(l_zip);
        IF DBMS_LOB.ISTEMPORARY(l_zip) = 1 THEN
            DBMS_LOB.FREETEMPORARY(l_zip);
        END IF;

        -- Find the matching file
        FOR i IN 1 .. l_entries.COUNT LOOP
            IF l_entries(i).filename = p_file_name THEN
                l_content := l_entries(i).content;
                l_found := TRUE;
                EXIT;
            END IF;
            -- Free non-matching entries
            IF DBMS_LOB.ISTEMPORARY(l_entries(i).content) = 1 THEN
                DBMS_LOB.FREETEMPORARY(l_entries(i).content);
            END IF;
        END LOOP;

        IF NOT l_found OR l_content IS NULL THEN
            HTP.P('File not found: ' || p_file_name);
            RETURN;
        END IF;

        -- Derive content type from extension
        l_ext := LOWER(SUBSTR(p_file_name, INSTR(p_file_name, '.', -1) + 1));
        l_ctype := CASE l_ext
            WHEN 'log' THEN 'text/plain'
            WHEN 'xml' THEN 'application/xml'
            WHEN 'zip' THEN 'application/zip'
            WHEN 'csv' THEN 'text/csv'
            WHEN 'txt' THEN 'text/plain'
            WHEN 'pdf' THEN 'application/pdf'
            ELSE 'application/octet-stream'
        END;

        -- Stream the file as a RAW BINARY download.
        --   HTP.INIT clears any buffered APEX output so the body is only the
        --     file bytes.
        --   STOP_APEX_ENGINE (below) halts the APEX engine so it cannot append
        --     its own output OR re-serialise the binary response as character
        --     data. Without it, every byte > 0x7F is silently mangled by the
        --     charset conversion -- pure-ASCII logs/CSVs survive, but binary
        --     files (PDF, xlsx) come back structurally valid yet BLANK.
        SYS.HTP.INIT;
        SYS.OWA_UTIL.MIME_HEADER(l_ctype, FALSE);
        SYS.HTP.P('Content-Length: ' || DBMS_LOB.GETLENGTH(l_content));
        SYS.HTP.P('Content-Disposition: attachment; filename="' || p_file_name || '"');
        SYS.OWA_UTIL.HTTP_HEADER_CLOSE;
        SYS.WPG_DOCLOAD.DOWNLOAD_FILE(l_content);

        IF DBMS_LOB.ISTEMPORARY(l_content) = 1 THEN
            DBMS_LOB.FREETEMPORARY(l_content);
        END IF;

        -- Halt the APEX engine. This raises ORA-20876, which MUST propagate to
        -- the APEX top level -- both this handler and the calling app process
        -- must re-raise it (a plain WHEN OTHERS would silently cancel the stop).
        -- Conditional compilation: databases without APEX (e.g. the local Docker
        -- dev DB) have no APEX_APPLICATION package, which left this whole package
        -- body INVALID. Compile with PLSQL_CCFLAGS='apex_installed:TRUE' on any
        -- instance that has APEX; without the flag the same ORA-20876 stop signal
        -- is raised directly (this procedure is only ever called from APEX anyway).
        $IF $$apex_installed $THEN
        APEX_APPLICATION.STOP_APEX_ENGINE;
        $ELSE
        RAISE_APPLICATION_ERROR(-20876, 'Stop APEX Engine');
        $END

    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20876 THEN
                RAISE;   -- APEX "Stop APEX Engine" signal -- must propagate
            END IF;
            HTP.P('Error downloading file: ' || SQLERRM);
    END DOWNLOAD_ESS_FILE_TO_BROWSER;

    -- ============================================================
    -- CAPTURE_REPORT_ESS_JOB
    -- Finds the Report child ESS job spawned by the Import ESS job
    -- and inserts it into DMT_ESS_JOB_TBL as a logical child.
    --
    -- Looks up the exact report job definition from REPORT_JOB_DEF
    -- in DMT_ERP_INTERFACE_OPTIONS_TBL. Only CEMLIs with a seeded
    -- REPORT_JOB_DEF have report children (currently: BillingEvents,
    -- Projects). CEMLIs without one return NULL immediately.
    --
    -- Uses DMT_ESS_CHILD_JOB_RPT.xdo with P_JOB_DEF bound to the
    -- exact definition to query ESS_REQUEST_HISTORY.
    --
    -- Fusion doesn't model the report job as a child (parentrequestid=0),
    -- but we store it with PARENT_REQUEST_ID = p_import_ess_id so the
    -- APEX UI renders it in the correct hierarchy position.
    --
    -- Returns the report request_id, or NULL if not found/not applicable.
    -- Non-blocking: logs and returns NULL on any failure.
    -- ============================================================
    FUNCTION CAPTURE_REPORT_ESS_JOB (
        p_run_id IN NUMBER,
        p_import_ess_id  IN NUMBER,
        p_cemli_code     IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER IS
        C_PROC     CONSTANT VARCHAR2(30)  := 'CAPTURE_REPORT_ESS_JOB';
        C_RPT_PATH CONSTANT VARCHAR2(200) := '/Custom/DMT/common/DMT_ESS_CHILD_JOB_RPT.xdo';

        l_report_job_def VARCHAR2(200);
        l_base_url  VARCHAR2(500);
        l_bip_user  VARCHAR2(100);
        l_bip_pass  VARCHAR2(100);
        l_url       VARCHAR2(500);
        l_env       CLOB;
        l_resp      CLOB;
        l_xml       XMLTYPE;
        l_report_id NUMBER;
        l_import_depth NUMBER;
    BEGIN
        -- Look up the report job definition for this CEMLI.
        -- If not seeded, this CEMLI has no report child â€” return immediately.
        BEGIN
            SELECT REPORT_JOB_DEF INTO l_report_job_def
            FROM   DMT_OWNER.DMT_ERP_INTERFACE_OPTIONS_TBL
            WHERE  CEMLI_CODE = p_cemli_code
            AND    REPORT_JOB_DEF IS NOT NULL;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RETURN NULL;  -- No report child for this CEMLI
        END;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' start. Import ESS: ' || p_import_ess_id ||
            ', report job def: ' || l_report_job_def,
            'INFO', C_PKG, C_PROC);

        l_base_url := RTRIM(DMT_UTIL_PKG.GET_CONFIG('FUSION_URL'), '/');
        l_bip_user := NVL(DMT_UTIL_PKG.GET_CONFIG('BIP_USERNAME'), DMT_UTIL_PKG.GET_CONFIG('FUSION_USERNAME'));
        l_bip_pass := NVL(DMT_UTIL_PKG.GET_CONFIG('BIP_PASSWORD'), DMT_UTIL_PKG.GET_CONFIG('FUSION_PASSWORD'));
        l_url      := l_base_url || '/xmlpserver/services/v2/ReportService';

        -- Query for the Report child job using the exact job definition
        DBMS_LOB.CREATETEMPORARY(l_env, TRUE);
        DBMS_LOB.APPEND(l_env, TO_CLOB(
            '<soapenv:Envelope' ||
            ' xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"' ||
            ' xmlns:v2="http://xmlns.oracle.com/oxp/service/v2">' ||
            '<soapenv:Header/><soapenv:Body>' ||
            '<v2:runReport><v2:reportRequest>' ||
            '<v2:reportAbsolutePath>' || C_RPT_PATH || '</v2:reportAbsolutePath>' ||
            '<v2:attributeFormat>xml</v2:attributeFormat>' ||
            '<v2:parameterNameValues><v2:listOfParamNameValues>' ||
            '<v2:item><v2:name>P_LOAD_ESS_ID</v2:name>' ||
            '<v2:values><v2:item>' || TO_CHAR(p_import_ess_id) || '</v2:item></v2:values>' ||
            '</v2:item>' ||
            '<v2:item><v2:name>P_JOB_DEF</v2:name>' ||
            '<v2:values><v2:item>' || l_report_job_def || '</v2:item></v2:values>' ||
            '</v2:item>' ||
            '</v2:listOfParamNameValues></v2:parameterNameValues>' ||
            '<v2:sizeOfDataChunkDownload>-1</v2:sizeOfDataChunkDownload>' ||
            '</v2:reportRequest>' ||
            '<v2:userID>' || l_bip_user || '</v2:userID>' ||
            '<v2:password>' || l_bip_pass || '</v2:password>' ||
            '</v2:runReport></soapenv:Body></soapenv:Envelope>'));

        l_resp := bip_soap(l_url,
            'http://xmlns.oracle.com/oxp/service/v2/ReportService/runReportRequest', l_env);
        DBMS_LOB.FREETEMPORARY(l_env);

        -- Extract + decode reportBytes via the shared any-size extractor
        -- (was the same VARCHAR2(32767) single-shot decode as CAPTURE_ESS_HIERARCHY)
        l_xml := DMT_UTIL_PKG.BIP_REPORT_XML(l_resp);
        IF l_xml IS NULL THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': No ' || l_report_job_def || ' found for import ESS ' || p_import_ess_id,
                'WARN', C_PKG, C_PROC);
            RETURN NULL;
        END IF;

        BEGIN
            l_report_id := l_xml.extract('/DATA_DS/G_1/REQUESTID/text()').getNumberVal();
        EXCEPTION
            WHEN OTHERS THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    C_PROC || ': Could not extract REQUESTID from BIP response.',
                    'WARN', C_PKG, C_PROC);
                RETURN NULL;
        END;

        -- Look up the import job's depth level so we can nest the report one level deeper
        BEGIN
            SELECT NVL(DEPTH_LEVEL, 0) INTO l_import_depth
            FROM   DMT_OWNER.DMT_ESS_JOB_TBL
            WHERE  REQUEST_ID = p_import_ess_id
            FETCH FIRST 1 ROW ONLY;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_import_depth := 0;
        END;

        -- Insert the report job as a logical child of the import job
        DECLARE
            l_state_txt VARCHAR2(30) := state_text(12); -- 12 = SUCCEEDED
        BEGIN
            INSERT INTO DMT_OWNER.DMT_ESS_JOB_TBL (
                RUN_ID, REQUEST_ID, PARENT_REQUEST_ID,
                JOB_DEFINITION, JOB_SHORT_NAME, STATE, STATE_TEXT,
                CEMLI_CODE, DEPTH_LEVEL
            ) VALUES (
                p_run_id,
                l_report_id,
                p_import_ess_id,
                l_report_job_def,
                l_report_job_def,
                12, l_state_txt,
                p_cemli_code,
                l_import_depth + 1
            );
        EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN NULL; -- already captured
        END;

        COMMIT;

        -- Enumerate output files for the report job
        BEGIN
            ENUMERATE_ESS_FILES(
                p_ess_job_id => l_report_id,
                p_request_id => l_report_id);
        EXCEPTION
            WHEN OTHERS THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    C_PROC || ': File enumeration failed for report ESS ' || l_report_id || ': ' || SQLERRM,
                    'WARN', C_PKG, C_PROC);
        END;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. Report ESS: ' || l_report_id ||
            ' captured as child of import ESS ' || p_import_ess_id,
            'INFO', C_PKG, C_PROC);

        RETURN l_report_id;

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed.', SQLERRM, C_PKG, C_PROC);
            RETURN NULL;
    END CAPTURE_REPORT_ESS_JOB;

END DMT_ESS_UTIL_PKG;
/
