-- PACKAGE BODY DMT_LOADER_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_LOADER_PKG" AS
-- ============================================================
-- DMT_LOADER_PKG Body
-- ============================================================

    -- Package-level constants
    C_PKG  CONSTANT VARCHAR2(30) := 'DMT_LOADER_PKG';

    -- Fusion ESS terminal statuses
    C_STATUS_SUCCEEDED CONSTANT VARCHAR2(20) := 'SUCCEEDED';
    C_STATUS_WARNING   CONSTANT VARCHAR2(20) := 'WARNING';
    C_STATUS_FAILED    CONSTANT VARCHAR2(20) := 'FAILED';
    C_STATUS_ERROR     CONSTANT VARCHAR2(20) := 'ERROR';
    C_STATUS_EXPIRED   CONSTANT VARCHAR2(20) := 'EXPIRED';

    -- Poll interval (seconds between ESS status checks)
    -- 60s reduces repeated Basic Auth requests that trigger Fusion rate-limiting (HTTP 401)
    C_POLL_INTERVAL CONSTANT NUMBER := 60;

    -- --------------------------------------------------------
    -- Private: derive the ERP Integrations SOAP endpoint
    -- --------------------------------------------------------
    FUNCTION erp_soap_url RETURN VARCHAR2 IS
    BEGIN
        RETURN RTRIM(DMT_UTIL_PKG.GET_CONFIG('FUSION_URL'), '/') ||
               '/fscmService/ErpIntegrationService';
    END erp_soap_url;

    -- --------------------------------------------------------
    -- Private: resolve a scenario name to its SCENARIO_ID via the
    -- shared DMT_UTIL_PKG.GET_OR_CREATE_SCENARIO procedure (section 7
    -- procedures-only contract) and check its x_error_code. This
    -- package's procedures signal failure by raising, so a scenario-
    -- resolution failure is routed the same way — one check, defined
    -- once, for every RUN_* entry point.
    -- --------------------------------------------------------
    PROCEDURE resolve_scenario (
        p_scenario_name IN  VARCHAR2,
        x_scenario_id   OUT NUMBER
    ) IS
        l_err NUMBER;
    BEGIN
        DMT_UTIL_PKG.GET_OR_CREATE_SCENARIO(
            p_scenario_name => p_scenario_name,
            x_scenario_id   => x_scenario_id,
            x_error_code    => l_err);
        IF l_err != DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20115,
                'resolve_scenario: GET_OR_CREATE_SCENARIO failed for scenario "' ||
                p_scenario_name || '" (detail in DMT_LOG_TBL).');
        END IF;
    END resolve_scenario;

    -- --------------------------------------------------------
    -- Private: parse a scalar value from a simple flat JSON response.
    -- --------------------------------------------------------
    FUNCTION json_get (
        p_json IN CLOB,
        p_key  IN VARCHAR2
    ) RETURN VARCHAR2 IS
        l_value  VARCHAR2(500);
        l_start  INTEGER;
        l_end    INTEGER;
        l_search VARCHAR2(100);
    BEGIN
        l_value := JSON_VALUE(p_json, '$.' || p_key);
        IF l_value IS NULL THEN
            l_value := JSON_VALUE(p_json, '$.' || INITCAP(p_key));
        END IF;
        IF l_value IS NOT NULL THEN
            RETURN l_value;
        END IF;

        l_search := '"' || p_key || '":"';
        l_start  := DBMS_LOB.INSTR(p_json, l_search);
        IF l_start = 0 THEN
            l_search := '"' || INITCAP(p_key) || '":"';
            l_start  := DBMS_LOB.INSTR(p_json, l_search);
        END IF;
        IF l_start = 0 THEN RETURN NULL; END IF;

        l_start := l_start + LENGTH(l_search);
        l_end   := DBMS_LOB.INSTR(p_json, '"', l_start);
        IF l_end = 0 THEN RETURN NULL; END IF;

        RETURN DBMS_LOB.SUBSTR(p_json, l_end - l_start, l_start);
    END json_get;

    -- --------------------------------------------------------
    -- Private: execute a SOAP HTTP POST, return response CLOB.
    -- Raises on non-2xx status.
    -- --------------------------------------------------------
    FUNCTION soap_http (
        p_url         IN VARCHAR2,
        p_soap_action IN VARCHAR2,
        p_body        IN CLOB,
        p_run_id IN NUMBER DEFAULT NULL,
        p_username    IN VARCHAR2 DEFAULT NULL,
        p_password    IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB IS
        l_req      UTL_HTTP.REQ;
        l_resp     UTL_HTTP.RESP;
        l_response CLOB;
        l_chunk    VARCHAR2(32767);
        l_offset   INTEGER := 1;
        l_amount   INTEGER;
        l_body_len INTEGER;
        l_raw      RAW(600);
        l_auth     VARCHAR2(500);
    BEGIN
        l_raw  := UTL_ENCODE.BASE64_ENCODE(
                       UTL_RAW.CAST_TO_RAW(
                           NVL(p_username, DMT_UTIL_PKG.GET_CONFIG('FUSION_USERNAME')) || ':' ||
                           NVL(p_password, DMT_UTIL_PKG.GET_CONFIG('FUSION_PASSWORD'))));
        l_auth := 'Basic ' || UTL_RAW.CAST_TO_VARCHAR2(l_raw);

        UTL_HTTP.SET_RESPONSE_ERROR_CHECK(FALSE);
        UTL_HTTP.SET_TRANSFER_TIMEOUT(600);

        l_req := UTL_HTTP.BEGIN_REQUEST(p_url, 'POST', 'HTTP/1.1');
        UTL_HTTP.SET_HEADER(l_req, 'Authorization',  l_auth);
        UTL_HTTP.SET_HEADER(l_req, 'Content-Type',   'text/xml; charset=utf-8');
        UTL_HTTP.SET_HEADER(l_req, 'Content-Length', DBMS_LOB.GETLENGTH(p_body));
        UTL_HTTP.SET_HEADER(l_req, 'SOAPAction',     '"' || p_soap_action || '"');
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
            RAISE_APPLICATION_ERROR(-20003,
                'SOAP call failed. Status: ' || l_resp.status_code ||
                ' | Action: ' || p_soap_action ||
                ' | Response: ' || DBMS_LOB.SUBSTR(l_response, 500, 1));
        END IF;

        RETURN l_response;
    EXCEPTION
        WHEN OTHERS THEN
            BEGIN UTL_HTTP.END_RESPONSE(l_resp); EXCEPTION WHEN OTHERS THEN NULL; END;
            RAISE;
    END soap_http;

    -- --------------------------------------------------------
    -- Private: look up interfaceDetails ID (ERP_INTERFACE_OPTIONS_ID) for a CEMLI
    -- --------------------------------------------------------
    -- --------------------------------------------------------
    -- Private: look up UCM account, ESS import job name, and
    -- ERP_INTERFACE_OPTIONS_ID for a CEMLI code.
    -- Reads from DMT_ERP_INTERFACE_OPTIONS_TBL (local mirror of
    -- Fusion FUN_ERP_INTERFACE_OPTIONS, seeded at deploy time).
    -- Raises -20040 if CEMLI_CODE not found in the table.
    -- --------------------------------------------------------
    PROCEDURE get_erp_options (
        p_cemli_code            IN  VARCHAR2,
        x_ucm_account           OUT VARCHAR2,
        x_import_job_name       OUT VARCHAR2,  -- semicolon converted to comma (loadAndImportData format)
        x_interface_details_id  OUT NUMBER
    ) IS
        l_raw_job_name VARCHAR2(500);
    BEGIN
        SELECT UCM_ACCOUNT,
               IMPORT_JOB_NAME,
               TO_NUMBER(NVL(SOURCE_ERP_OPTIONS_ID, ERP_INTERFACE_OPTIONS_ID))
        INTO   x_ucm_account,
               l_raw_job_name,
               x_interface_details_id
        FROM   DMT_OWNER.DMT_ERP_INTERFACE_OPTIONS_TBL
        WHERE  CEMLI_CODE = p_cemli_code;

        -- FUN_ERP_INTERFACE_OPTIONS stores IMPORT_JOB_NAME with semicolon as delimiter
        -- (e.g. '/oracle/apps/ess/prc/poz/supplierImport;ImportSuppliers').
        -- loadAndImportData <erp:JobName> requires comma delimiter.
        -- Replace the last semicolon with a comma.
        x_import_job_name := SUBSTR(l_raw_job_name, 1, INSTR(l_raw_job_name, ';', -1) - 1)
                             || ','
                             || SUBSTR(l_raw_job_name, INSTR(l_raw_job_name, ';', -1) + 1);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20040,
                'GET_ERP_OPTIONS: No row found in DMT_ERP_INTERFACE_OPTIONS_TBL ' ||
                'for CEMLI_CODE = ''' || p_cemli_code || '''. ' ||
                'Seed this CEMLI_CODE before running the pipeline.');
    END get_erp_options;

    -- --------------------------------------------------------
    -- (A8/C2b, 2026-07-08) reset_scenario_status DELETED. The Overview
    -- run-mode table (ALL row, decided 2026-07-07): rows are "selected
    -- directly by the run-mode parameter in the selection predicates ...
    -- no status reset, no extra procedure", and the STG RETRY status is
    -- RETIRED ("the staging status is forward-only (NEW -> TRANSFORMED
    -- or FAILED) and is never reset"). Per-object ALL-mode selection
    -- predicates land with each object's Stage D/E port.
    -- --------------------------------------------------------

    -- --------------------------------------------------------
    -- SUBMIT_LOAD
    -- Calls loadAndImportData SOAP — single call that embeds the FBDI zip,
    -- uploads it to UCM, and triggers the "Load File to Interface Tables" ESS
    -- job to unpack the zip into the Fusion interface table (e.g. POZ_SUPPLIERS_INT).
    --
    -- This is step 1 of 2. After this job completes (polled by caller),
    -- the interface table is populated. The caller then submits the Import
    -- ESS job (ImportSuppliers etc.) separately via SUBMIT_IMPORT_JOB.
    --
    -- This matches the MCCS call_loadandimport_ws pattern exactly.
    -- Returns the Load ESS job ID for polling.
    -- --------------------------------------------------------
    FUNCTION SUBMIT_LOAD (
        p_run_id    IN NUMBER,
        p_fbdi_zip          IN BLOB,
        p_filename          IN VARCHAR2,
        p_job_name          IN VARCHAR2,  -- MCCS format: /oracle/.../package,JobDefinition
        p_interface_details IN NUMBER,    -- ERP_INTERFACE_OPTIONS_ID from DMT_ERP_INTERFACE_OPTIONS_TBL
        p_doc_account       IN VARCHAR2,  -- UCM document account e.g. prc/supplier/import
        p_parameter_list    IN VARCHAR2 DEFAULT 'NEW,N',  -- ESS import job parameters
        p_log_context       IN VARCHAR2 DEFAULT NULL,  -- e.g. 'Suppliers' — prefixed onto PROCEDURE_NAME in logs
        p_username          IN VARCHAR2 DEFAULT NULL,  -- per-CEMLI Fusion user override
        p_password          IN VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2 IS
        C_PROC        CONSTANT VARCHAR2(30) := 'SUBMIT_LOAD';
        C_NS_ACTION   CONSTANT VARCHAR2(200) :=
            'http://xmlns.oracle.com/apps/financials/commonModules/' ||
            'shared/model/erpIntegrationService/';
        C_SOAP_NS     CONSTANT VARCHAR2(500) :=
            'xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' ||
            'xmlns:typ="http://xmlns.oracle.com/apps/financials/commonModules/' ||
                'shared/model/erpIntegrationService/types/" ' ||
            'xmlns:erp="http://xmlns.oracle.com/apps/financials/commonModules/' ||
                'shared/model/erpIntegrationService/"';

        l_proc        VARCHAR2(80);
        l_b64_content CLOB;
        l_soap_body   CLOB;
        l_response    CLOB;
        l_soap_log    VARCHAR2(32767);
        l_load_ess_id VARCHAR2(100);
        l_tag_start   INTEGER;
        l_val_start   INTEGER;
        l_val_end     INTEGER;
    BEGIN
        l_proc := NVL2(p_log_context, p_log_context || ' > ', '') || C_PROC;
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'SUBMIT_LOAD start. File: ' || p_filename ||
                                ' | Size (bytes): ' || DBMS_LOB.GETLENGTH(p_fbdi_zip) ||
                                ' | Account: ' || p_doc_account,
            p_package        => C_PKG,
            p_procedure      => l_proc);

        -- Base64-encode the zip; strip newlines inserted by UTL_ENCODE
        DMT_UTIL_PKG.LOG(p_run_id, 'Base64-encoding FBDI zip.', 'INFO', C_PKG, l_proc);
        l_b64_content := DMT_UTIL_PKG.BASE64_ENCODE(p_fbdi_zip);
        l_b64_content := REPLACE(REPLACE(l_b64_content, CHR(13), ''), CHR(10), '');

        -- loadAndImportData: MCCS pattern — embed zip + jobList in single call.
        -- Fusion handles load → import sequencing internally.
        -- p_job_name is the short ESS definition name (e.g. ImportSuppliers).
        DMT_UTIL_PKG.LOG(p_run_id,
            'Calling loadAndImportData. Account: ' || p_doc_account ||
            ' | Job: ' || p_job_name ||
            ' | InterfaceDetails: ' || TO_CHAR(p_interface_details),
            'INFO', C_PKG, l_proc);

        DBMS_LOB.CREATETEMPORARY(l_soap_body, TRUE);
        DBMS_LOB.APPEND(l_soap_body, TO_CLOB(
            '<soapenv:Envelope ' || C_SOAP_NS || '>' ||
            '<soapenv:Header/><soapenv:Body>' ||
            '<typ:loadAndImportData>' ||
            '<typ:document>' ||
            '<erp:Content>'));
        DBMS_LOB.APPEND(l_soap_body, l_b64_content);
        DBMS_LOB.APPEND(l_soap_body, TO_CLOB(
            '</erp:Content>' ||
            '<erp:FileName>'              || p_filename       || '</erp:FileName>' ||
            '<erp:ContentType>ZIP</erp:ContentType>' ||
            '<erp:DocumentTitle>'         || p_filename       || '</erp:DocumentTitle>' ||
            '<erp:DocumentAuthor>InterfaceUser</erp:DocumentAuthor>' ||
            '<erp:DocumentSecurityGroup></erp:DocumentSecurityGroup>' ||
            '<erp:DocumentAccount>'       || p_doc_account    || '</erp:DocumentAccount>' ||
            '<erp:DocumentName></erp:DocumentName>' ||
            '<erp:DocumentId></erp:DocumentId>' ||
            '</typ:document>' ||
            '<typ:jobList>' ||
            '<erp:JobName>'      || p_job_name                      || '</erp:JobName>' ||
            '<erp:ParameterList>' || p_parameter_list || '</erp:ParameterList>' ||
            '</typ:jobList>' ||
            '<typ:interfaceDetails>' || TO_CHAR(p_interface_details) || '</typ:interfaceDetails>' ||
            '<typ:notificationCode>10</typ:notificationCode>' ||
            '<typ:callbackURL></typ:callbackURL>' ||
            '</typ:loadAndImportData>' ||
            '</soapenv:Body></soapenv:Envelope>'));

        -- Log full SOAP envelope BEFORE sending — base64 content replaced with size
        -- (autonomous txn — always committed even if the HTTP call hangs or errors)
        l_soap_log :=
            '<soapenv:Envelope ' || C_SOAP_NS || '>' ||
            '<soapenv:Header/><soapenv:Body>' ||
            '<typ:loadAndImportData>' ||
            '<typ:document>' ||
            '<erp:Content>[base64 content: ' || DBMS_LOB.GETLENGTH(l_b64_content) || ' chars — see DMT_FBDI_CSV_TBL]</erp:Content>' ||
            '<erp:FileName>'             || p_filename                         || '</erp:FileName>' ||
            '<erp:ContentType>ZIP</erp:ContentType>' ||
            '<erp:DocumentTitle>'        || p_filename                         || '</erp:DocumentTitle>' ||
            '<erp:DocumentAuthor>InterfaceUser</erp:DocumentAuthor>' ||
            '<erp:DocumentSecurityGroup></erp:DocumentSecurityGroup>' ||
            '<erp:DocumentAccount>'      || p_doc_account                     || '</erp:DocumentAccount>' ||
            '<erp:DocumentName></erp:DocumentName>' ||
            '<erp:DocumentId></erp:DocumentId>' ||
            '</typ:document>' ||
            '<typ:jobList>' ||
            '<erp:JobName>'              || p_job_name                         || '</erp:JobName>' ||
            '<erp:ParameterList>' || p_parameter_list || '</erp:ParameterList>' ||
            '</typ:jobList>' ||
            '<typ:interfaceDetails>'     || TO_CHAR(p_interface_details)       || '</typ:interfaceDetails>' ||
            '<typ:notificationCode>10</typ:notificationCode>' ||
            '<typ:callbackURL></typ:callbackURL>' ||
            '</typ:loadAndImportData>' ||
            '</soapenv:Body></soapenv:Envelope>';
        -- Envelope logs always route through MASK_CREDENTIALS (this envelope
        -- authenticates via HTTP header, not body — masked anyway by rule).
        DMT_UTIL_PKG.LOG(p_run_id,
            'loadAndImportData pre-send envelope: ' ||
                DBMS_LOB.SUBSTR(
                    DMT_UTIL_PKG.MASK_CREDENTIALS(TO_CLOB(l_soap_log)), 32000, 1),
            'INFO', C_PKG, l_proc);

        -- Log the EXACT payload (tail after base64 content) for debugging
        DECLARE
            l_content_end NUMBER;
            l_tail        VARCHAR2(4000);
        BEGIN
            l_content_end := DBMS_LOB.INSTR(l_soap_body, '</erp:Content>');
            IF l_content_end > 0 THEN
                l_tail := DBMS_LOB.SUBSTR(l_soap_body, 4000, l_content_end);
            ELSE
                l_tail := DBMS_LOB.SUBSTR(l_soap_body, 4000, 1);
            END IF;
            DMT_UTIL_PKG.LOG(p_run_id,
                'EXACT PAYLOAD TAIL: ' || l_tail,
                'INFO', C_PKG, l_proc);
        END;

        l_response := soap_http(
            p_url            => erp_soap_url,
            p_soap_action    => C_NS_ACTION || 'loadAndImportData',
            p_body           => l_soap_body,
            p_run_id => p_run_id,
            p_username       => p_username,
            p_password       => p_password);

        DBMS_LOB.FREETEMPORARY(l_soap_body);
        DMT_UTIL_PKG.LOG(p_run_id,
            'loadAndImportData full response: ' || DBMS_LOB.SUBSTR(l_response, 32767, 1),
            'INFO', C_PKG, l_proc);

        -- Extract Load ESS job ID from <result> element
        l_tag_start := DBMS_LOB.INSTR(l_response, '<result');
        IF l_tag_start > 0 THEN
            l_val_start := DBMS_LOB.INSTR(l_response, '>', l_tag_start) + 1;
            l_val_end   := DBMS_LOB.INSTR(l_response, '</result>', l_val_start);
            IF l_val_end > l_val_start THEN
                l_load_ess_id := DBMS_LOB.SUBSTR(
                                     l_response,
                                     l_val_end - l_val_start,
                                     l_val_start);
            END IF;
        END IF;

        IF l_load_ess_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20021,
                'SUBMIT_LOAD: Could not parse Load ESS job ID from loadAndImportData response. ' ||
                'Response (first 1000): ' || DBMS_LOB.SUBSTR(l_response, 1000, 1));
        END IF;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'loadAndImportData submitted. Load ESS job ID: ' || l_load_ess_id ||
                                ' | File: ' || p_filename,
            p_package        => C_PKG,
            p_procedure      => l_proc);

        RETURN l_load_ess_id;

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'SUBMIT_LOAD failed. File: ' || p_filename,
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => l_proc);
            RAISE;
    END SUBMIT_LOAD;

    -- --------------------------------------------------------
    -- SUBMIT_IMPORT_JOB
    -- Submits the Import ESS job (e.g. ImportSuppliers) after the Load job
    -- has completed and populated the Fusion interface table.
    -- This is step 2 of 2 — called only after SUBMIT_LOAD + polling confirm
    -- the "Load File to Interface Tables" job SUCCEEDED.
    --
    -- p_job_name: full ESS path, last comma separates package from definition.
    --   e.g. /oracle/apps/ess/prc/poz/supplierImport,ImportSuppliers
    -- paramList NEW,N,<run_id> stamps IMPORT_REQUEST_ID on each row
    -- loaded into the interface table, enabling BIP reconciliation to filter by it.
    -- Returns the Import ESS job ID for polling and reconciliation.
    -- --------------------------------------------------------
    FUNCTION SUBMIT_IMPORT_JOB (
        p_run_id         IN NUMBER,
        p_job_name       IN VARCHAR2,
        p_param_list     IN VARCHAR2 DEFAULT NULL  -- ESS ParameterList; NULL => 'NEW,N,<run_id>'
    ) RETURN VARCHAR2 IS
        C_PROC      CONSTANT VARCHAR2(30) := 'SUBMIT_IMPORT_JOB';
        C_NS_ACTION CONSTANT VARCHAR2(200) :=
            'http://xmlns.oracle.com/apps/financials/commonModules/' ||
            'shared/model/erpIntegrationService/';
        C_SOAP_NS   CONSTANT VARCHAR2(500) :=
            'xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' ||
            'xmlns:typ="http://xmlns.oracle.com/apps/financials/commonModules/' ||
                'shared/model/erpIntegrationService/types/" ' ||
            'xmlns:erp="http://xmlns.oracle.com/apps/financials/commonModules/' ||
                'shared/model/erpIntegrationService/"';

        l_sep_pos      INTEGER;
        l_job_pkg      VARCHAR2(300);
        l_job_def      VARCHAR2(200);
        l_param_list   VARCHAR2(4000);
        l_response     CLOB;
        l_import_ess_id VARCHAR2(100);
        l_tag_start    INTEGER;
        l_val_start    INTEGER;
        l_val_end      INTEGER;
    BEGIN
        -- Split job name into package + definition on the LAST separator.
        -- Accept either ',' or ';' (ERP options store either):
        --   /oracle/apps/ess/prc/poz/supplierImport,ImportSuppliers
        --   /oracle/apps/ess/financials/assets/additions;PostMassAdditions
        l_sep_pos := GREATEST(INSTR(p_job_name, ',', -1), INSTR(p_job_name, ';', -1));
        IF l_sep_pos = 0 THEN
            RAISE_APPLICATION_ERROR(-20042,
                'SUBMIT_IMPORT_JOB: Job name ''' || p_job_name ||
                ''' has no '','' or '';'' separator. Expected: /oracle/apps/ess/.../package<sep>JobDefinition');
        END IF;
        l_job_pkg := SUBSTR(p_job_name, 1, l_sep_pos - 1);
        l_job_def := SUBSTR(p_job_name, l_sep_pos + 1);

        -- ParameterList: caller-supplied (e.g. book code 'US CORP') or default.
        l_param_list := NVL(p_param_list, 'NEW,N,' || TO_CHAR(p_run_id));

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'SUBMIT_IMPORT_JOB start. Package: ' || l_job_pkg ||
                                ' | Definition: ' || l_job_def ||
                                ' | ParamList: ' || l_param_list,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        l_response := soap_http(
            p_url            => erp_soap_url,
            p_soap_action    => C_NS_ACTION || 'submitESSJobRequest',
            p_body           => TO_CLOB(
                '<soapenv:Envelope ' || C_SOAP_NS || '>' ||
                '<soapenv:Header/><soapenv:Body>' ||
                '<typ:submitESSJobRequest>' ||
                '<typ:jobPackageName>'    || l_job_pkg || '</typ:jobPackageName>' ||
                '<typ:jobDefinitionName>' || l_job_def || '</typ:jobDefinitionName>' ||
                '<typ:paramList>' || l_param_list || '</typ:paramList>' ||
                '</typ:submitESSJobRequest>' ||
                '</soapenv:Body></soapenv:Envelope>'),
            p_run_id => p_run_id);

        -- Extract Import ESS job ID from <result> element
        l_tag_start := DBMS_LOB.INSTR(l_response, '<result');
        IF l_tag_start > 0 THEN
            l_val_start := DBMS_LOB.INSTR(l_response, '>', l_tag_start) + 1;
            l_val_end   := DBMS_LOB.INSTR(l_response, '</result>', l_val_start);
            IF l_val_end > l_val_start THEN
                l_import_ess_id := DBMS_LOB.SUBSTR(
                                       l_response,
                                       l_val_end - l_val_start,
                                       l_val_start);
            END IF;
        END IF;

        IF l_import_ess_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20021,
                'SUBMIT_IMPORT_JOB: Could not parse Import ESS job ID from submitESSJobRequest response. ' ||
                'Response (first 1000): ' || DBMS_LOB.SUBSTR(l_response, 1000, 1));
        END IF;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Import job submitted. ESS job ID: ' || l_import_ess_id ||
                                ' | IMPORT_REQUEST_ID stamped on interface rows: ' ||
                                TO_CHAR(p_run_id),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        RETURN l_import_ess_id;

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'SUBMIT_IMPORT_JOB failed. Job: ' || p_job_name,
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END SUBMIT_IMPORT_JOB;

    -- --------------------------------------------------------
    -- POLL_ESS_JOB
    -- Polls Fusion ESS job status via SOAP getESSJobStatus every
    -- C_POLL_INTERVAL seconds until terminal status or timeout.
    -- Raises -20022 on hard failure (FAILED/ERROR/EXPIRED).
    -- --------------------------------------------------------
    PROCEDURE POLL_ESS_JOB (
        p_run_id  IN NUMBER,
        p_ess_job_id      IN VARCHAR2,
        p_timeout_sec     IN NUMBER   DEFAULT 1800,
        p_raise_on_error  IN BOOLEAN  DEFAULT TRUE,
        p_log_context     IN VARCHAR2 DEFAULT NULL,  -- e.g. 'Suppliers' — prefixed onto PROCEDURE_NAME in logs
        p_cemli_code      IN VARCHAR2 DEFAULT NULL,  -- passed to CAPTURE_ESS_HIERARCHY for tagging
        x_fusion_status   OUT VARCHAR2,              -- terminal Fusion status returned to caller
        p_username        IN VARCHAR2 DEFAULT NULL,  -- per-CEMLI Fusion user override
        p_password        IN VARCHAR2 DEFAULT NULL
    ) IS
        C_PROC          CONSTANT VARCHAR2(30)  := 'POLL_ESS_JOB';
        C_NS_ACTION     CONSTANT VARCHAR2(200) :=
            'http://xmlns.oracle.com/apps/financials/commonModules/' ||
            'shared/model/erpIntegrationService/';
        C_SOAP_NS       CONSTANT VARCHAR2(300) :=
            'xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' ||
            'xmlns:typ="http://xmlns.oracle.com/apps/financials/commonModules/' ||
                'shared/model/erpIntegrationService/types/"';

        l_proc          VARCHAR2(80);
        l_soap_url      VARCHAR2(500);
        l_soap_body     VARCHAR2(4000);
        l_response      CLOB;
        l_fusion_status VARCHAR2(50);
        l_dmt_status    VARCHAR2(30);
        l_elapsed       NUMBER := 0;
        l_tag_start     INTEGER;
        l_val_start     INTEGER;
        l_val_end       INTEGER;
    BEGIN
        l_proc := NVL2(p_log_context, p_log_context || ' > ', '') || C_PROC;
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'POLL_ESS_JOB start. ESS job: ' || p_ess_job_id ||
                                ' | Timeout: ' || p_timeout_sec || 's',
            p_package        => C_PKG,
            p_procedure      => l_proc);

        l_soap_url  := erp_soap_url;
        l_soap_body :=
            '<soapenv:Envelope ' || C_SOAP_NS || '>' ||
            '<soapenv:Header/><soapenv:Body>' ||
            '<typ:getESSJobStatus>' ||
            '<typ:requestId>' || p_ess_job_id || '</typ:requestId>' ||
            '</typ:getESSJobStatus>' ||
            '</soapenv:Body></soapenv:Envelope>';

        LOOP
            BEGIN
                l_response := soap_http(
                    p_url            => l_soap_url,
                    p_soap_action    => C_NS_ACTION || 'getESSJobStatus',
                    p_body           => TO_CLOB(l_soap_body),
                    p_run_id => p_run_id,
                    p_username       => p_username,
                    p_password       => p_password);
            EXCEPTION
                WHEN OTHERS THEN
                    -- A failure on the *status-check* call must never be conflated with the
                    -- job's terminal status. Transient transport faults — auth rate-limiting
                    -- (401), server errors (5xx) and connection/timeout errors — are logged
                    -- and retried on the next poll interval. The loop is bounded by
                    -- p_timeout_sec, so a genuine outage still terminates as EXPIRED rather
                    -- than mislabelling a running/succeeded job as a failure. Only
                    -- non-transient client errors (other 4xx) surface immediately.
                    IF INSTR(SQLERRM, 'Status: 401') > 0      -- auth rate-limit
                       OR INSTR(SQLERRM, 'Status: 500') > 0   -- internal server error
                       OR INSTR(SQLERRM, 'Status: 502') > 0   -- bad gateway
                       OR INSTR(SQLERRM, 'Status: 503') > 0   -- service unavailable
                       OR INSTR(SQLERRM, 'Status: 504') > 0   -- gateway timeout
                       OR INSTR(SQLERRM, 'ORA-29273') > 0     -- HTTP request failed
                       OR INSTR(SQLERRM, 'ORA-12541') > 0     -- no listener
                       OR INSTR(SQLERRM, 'ORA-12170') > 0     -- connect timeout
                       OR INSTR(SQLERRM, 'ORA-29276') > 0     -- transfer timeout
                    THEN
                        DMT_UTIL_PKG.LOG(
                            p_run_id => p_run_id,
                            p_message        => 'ESS poll transient fault on job ' || p_ess_job_id ||
                                                ' — retrying next interval. Elapsed: ' || l_elapsed ||
                                                's. Detail: ' || SUBSTR(SQLERRM, 1, 200),
                            p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                            p_package        => C_PKG,
                            p_procedure      => l_proc);
                        l_response := NULL;
                    ELSE
                        RAISE;
                    END IF;
            END;

            l_fusion_status := NULL;
            l_tag_start := DBMS_LOB.INSTR(l_response, '<result');
            IF l_tag_start > 0 THEN
                l_val_start := DBMS_LOB.INSTR(l_response, '>', l_tag_start) + 1;
                l_val_end   := DBMS_LOB.INSTR(l_response, '</result>', l_val_start);
                IF l_val_end > l_val_start THEN
                    l_fusion_status := DBMS_LOB.SUBSTR(l_response,
                                           l_val_end - l_val_start, l_val_start);
                END IF;
            END IF;

            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'ESS poll: ' || p_ess_job_id ||
                                    ' | Status: ' || NVL(l_fusion_status, '(no status)') ||
                                    ' | Elapsed: ' || l_elapsed || 's',
                p_package        => C_PKG,
                p_procedure      => l_proc);

            IF l_fusion_status IN (C_STATUS_SUCCEEDED, C_STATUS_WARNING,
                                    C_STATUS_FAILED, C_STATUS_ERROR,
                                    C_STATUS_EXPIRED) THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    'ESS poll final response: ' || DBMS_LOB.SUBSTR(l_response, 32767, 1),
                    'INFO', C_PKG, l_proc);
                EXIT;
            END IF;

            IF l_elapsed >= p_timeout_sec THEN
                l_fusion_status := C_STATUS_EXPIRED;
                DMT_UTIL_PKG.LOG(
                    p_run_id => p_run_id,
                    p_message        => 'POLL_ESS_JOB timed out after ' ||
                                        l_elapsed || 's. Marking as EXPIRED.',
                    p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                    p_package        => C_PKG,
                    p_procedure      => l_proc);
                EXIT;
            END IF;

            DBMS_SESSION.SLEEP(C_POLL_INTERVAL);
            l_elapsed := l_elapsed + C_POLL_INTERVAL;
        END LOOP;

        l_dmt_status := CASE
            WHEN l_fusion_status IN (C_STATUS_SUCCEEDED, C_STATUS_WARNING) THEN 'LOADED'
            ELSE 'FAILED'
        END;

        IF l_fusion_status = C_STATUS_WARNING THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'ESS job completed with WARNING. ' ||
                                    'Treating as LOADED — check BIP reconciliation for record-level errors.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => l_proc);
        END IF;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'POLL_ESS_JOB complete. ESS: ' || p_ess_job_id ||
                                ' | Fusion status: ' || l_fusion_status ||
                                ' | DMT status: ' || l_dmt_status,
            p_package        => C_PKG,
            p_procedure      => l_proc);

        -- Capture ESS job hierarchy for diagnostics.
        -- Runs after every terminal status so child job details are always available.
        -- Any DB or report error here is a hard stop — do not swallow.
        DMT_ESS_UTIL_PKG.CAPTURE_ESS_HIERARCHY(
            p_run_id    => p_run_id,
            p_parent_request_id => TO_NUMBER(p_ess_job_id),
            p_cemli_code        => p_cemli_code);
        -- Enumerate output files for each child job (metadata only, no content stored).
        -- Must run immediately after hierarchy capture while Fusion still has the files.
        DMT_ESS_UTIL_PKG.ENUMERATE_ALL_ESS_FILES(
            p_run_id    => p_run_id,
            p_username          => p_username,
            p_password          => p_password);

        -- Return terminal Fusion status to caller so it can branch
        -- (e.g. skip import lookup / BIP when Load ESS returned ERROR).
        x_fusion_status := l_fusion_status;

        IF l_dmt_status = 'FAILED' AND p_raise_on_error THEN
            RAISE_APPLICATION_ERROR(-20022,
                'Fusion ESS job ' || p_ess_job_id ||
                ' ended with status: ' || l_fusion_status);
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'POLL_ESS_JOB failed. ESS job: ' || p_ess_job_id,
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => l_proc);
            RAISE;
    END POLL_ESS_JOB;

    -- --------------------------------------------------------
    -- Private: HTTP POST for BIP v2 SOAP (no HTTP auth — credentials in body).
    -- --------------------------------------------------------
    FUNCTION bip_http (
        p_url    IN VARCHAR2,
        p_action IN VARCHAR2,
        p_body   IN CLOB
    ) RETURN CLOB IS
        l_req    UTL_HTTP.REQ;
        l_resp   UTL_HTTP.RESP;
        l_result CLOB;
        l_chunk  VARCHAR2(32767);
        l_offset INTEGER := 1;
        l_amount INTEGER;
        l_len    INTEGER;
    BEGIN
        UTL_HTTP.SET_RESPONSE_ERROR_CHECK(FALSE);
        UTL_HTTP.SET_TRANSFER_TIMEOUT(120);
        l_req := UTL_HTTP.BEGIN_REQUEST(p_url, 'POST', 'HTTP/1.1');
        UTL_HTTP.SET_HEADER(l_req, 'Content-Type',   'text/xml; charset=utf-8');
        UTL_HTTP.SET_HEADER(l_req, 'Content-Length', DBMS_LOB.GETLENGTH(p_body));
        UTL_HTTP.SET_HEADER(l_req, 'SOAPAction',     '"' || p_action || '"');
        l_len := DBMS_LOB.GETLENGTH(p_body);
        WHILE l_offset <= l_len LOOP
            l_amount := LEAST(8000, l_len - l_offset + 1);
            UTL_HTTP.WRITE_TEXT(l_req, DBMS_LOB.SUBSTR(p_body, l_amount, l_offset));
            l_offset := l_offset + l_amount;
        END LOOP;
        l_resp := UTL_HTTP.GET_RESPONSE(l_req);
        DBMS_LOB.CREATETEMPORARY(l_result, TRUE);
        BEGIN
            LOOP
                UTL_HTTP.READ_TEXT(l_resp, l_chunk, 32767);
                DBMS_LOB.APPEND(l_result, l_chunk);
            END LOOP;
        EXCEPTION WHEN UTL_HTTP.END_OF_BODY THEN NULL;
        END;
        UTL_HTTP.END_RESPONSE(l_resp);

        -- Check for HTTP errors
        IF l_resp.status_code NOT BETWEEN 200 AND 299 THEN
            RAISE_APPLICATION_ERROR(-20052,
                'BIP SOAP call failed. HTTP ' || l_resp.status_code ||
                ' | Action: ' || p_action ||
                ' | Response: ' || DBMS_LOB.SUBSTR(l_result, 500, 1));
        END IF;

        -- Check for SOAP Fault in response body (can occur even with HTTP 200)
        IF DBMS_LOB.INSTR(l_result, '<faultstring>') > 0 THEN
            RAISE_APPLICATION_ERROR(-20052,
                'BIP SOAP Fault: ' ||
                REGEXP_SUBSTR(DBMS_LOB.SUBSTR(l_result, 2000, 1),
                    '<faultstring>(.*?)</faultstring>', 1, 1, NULL, 1) ||
                ' | Action: ' || p_action);
        END IF;

        RETURN l_result;
    EXCEPTION
        WHEN OTHERS THEN
            BEGIN UTL_HTTP.END_RESPONSE(l_resp); EXCEPTION WHEN OTHERS THEN NULL; END;
            RAISE;
    END bip_http;

    -- --------------------------------------------------------
    -- Private: extract text value between XML tags in a CLOB.
    -- --------------------------------------------------------
    FUNCTION clob_tag_val (p_clob IN CLOB, p_tag IN VARCHAR2) RETURN VARCHAR2 IS
        l_open  VARCHAR2(200) := '<' || p_tag || '>';
        l_close VARCHAR2(200) := '</' || p_tag || '>';
        l_s     INTEGER;
        l_e     INTEGER;
    BEGIN
        l_s := DBMS_LOB.INSTR(p_clob, l_open);
        IF l_s = 0 THEN RETURN NULL; END IF;
        l_s := l_s + LENGTH(l_open);
        l_e := DBMS_LOB.INSTR(p_clob, l_close, l_s);
        IF l_e = 0 THEN RETURN NULL; END IF;
        RETURN DBMS_LOB.SUBSTR(p_clob, l_e - l_s, l_s);
    END clob_tag_val;

    -- --------------------------------------------------------
    -- GET_IMPORT_ESS_ID
    -- After loadAndImportData completes, finds the chained Import ESS
    -- job by querying ess_request_history for a job whose definition
    -- matches the Import job name (e.g. RequisitionImportJob).
    --
    -- The Import job may be a child (absparentid = load ESS ID) or
    -- an independent top-level job (absparentid = itself) depending
    -- on the Fusion ESS scheduler behavior. The BIP query handles
    -- both: prefers absparentid match, falls back to proximity
    -- (requestid > load ESS ID).
    --
    -- Uses the pre-deployed static BIP report (AD#16 — no ephemeral BIP):
    --   /Custom/DMT/common/DMT_ESS_CHILD_JOB_RPT.xdo
    -- Called via runReport with P_LOAD_ESS_ID and P_JOB_DEF bound parameters.
    --
    -- Retries every 15 seconds for up to 15 minutes.
    -- Raises -20050 if no job found after timeout.
    -- --------------------------------------------------------
    FUNCTION get_import_ess_id (
        p_run_id IN NUMBER,
        p_cemli_code     IN VARCHAR2,
        p_load_ess_id    IN VARCHAR2
    ) RETURN VARCHAR2 IS
        C_PROC        CONSTANT VARCHAR2(50)  := 'GET_IMPORT_ESS_ID';
        C_RPT_PATH    CONSTANT VARCHAR2(200) := '/Custom/DMT/common/DMT_ESS_CHILD_JOB_RPT.xdo';
        C_MAX_TRIES   CONSTANT INTEGER       := 60;
        C_SLEEP_SEC   CONSTANT NUMBER        := 15;

        l_base_url    VARCHAR2(500);
        l_bip_user    VARCHAR2(100);
        l_bip_pass    VARCHAR2(100);
        l_url         VARCHAR2(500);
        l_env         CLOB;
        l_resp        CLOB;
        l_b64         VARCHAR2(32767);
        l_xml         VARCHAR2(4000);
        l_import_id   VARCHAR2(100);
        l_attempt     INTEGER := 0;
        l_log_proc    VARCHAR2(100);
        l_job_name    VARCHAR2(500);
        l_job_def     VARCHAR2(200);
    BEGIN
        l_base_url := RTRIM(DMT_UTIL_PKG.GET_CONFIG('FUSION_URL'), '/');
        l_bip_user := DMT_UTIL_PKG.GET_CONFIG('BIP_USERNAME');
        l_bip_pass := DMT_UTIL_PKG.GET_CONFIG('BIP_PASSWORD');
        l_url      := l_base_url || '/xmlpserver/services/v2/ReportService';
        l_log_proc := p_cemli_code || ' > ' || C_PROC;

        -- Derive the definition fragment from the ESS job name.
        -- Job name format after get_erp_options conversion:
        --   '/oracle/apps/ess/.../supplierImport,ImportSuppliers'
        -- The part after the comma is the job definition name stored in ess_request_history.
        DECLARE
            l_ucm_dummy   VARCHAR2(200);
            l_iface_dummy NUMBER;
        BEGIN
            get_erp_options(
                p_cemli_code           => p_cemli_code,
                x_ucm_account          => l_ucm_dummy,
                x_import_job_name      => l_job_name,
                x_interface_details_id => l_iface_dummy);
        END;
        -- ERP options may use comma or semicolon as separator between package path and job definition.
        -- e.g. '.../supplierImport,ImportSuppliers' or '.../reqImport;RequisitionImportJob'
        l_job_def  := SUBSTR(l_job_name, GREATEST(INSTR(l_job_name, ','), INSTR(l_job_name, ';')) + 1);

        IF l_bip_user IS NULL OR l_bip_pass IS NULL THEN
            RAISE_APPLICATION_ERROR(-20051,
                'GET_IMPORT_ESS_ID: BIP_USERNAME or BIP_PASSWORD not found in DMT_CONFIG_TBL.');
        END IF;

        DMT_UTIL_PKG.LOG(p_run_id,
            'GET_IMPORT_ESS_ID start. Load ESS ID: ' || p_load_ess_id ||
            '. Job def filter: ' || l_job_def ||
            '. Will poll up to ' || C_MAX_TRIES ||
            ' times (every ' || C_SLEEP_SEC || 's). CEMLI: ' || p_cemli_code,
            'INFO', C_PKG, l_log_proc);

        LOOP
            l_attempt   := l_attempt + 1;
            l_import_id := NULL;

            DBMS_LOB.CREATETEMPORARY(l_env, TRUE);
            DBMS_LOB.APPEND(l_env, TO_CLOB(
                '<soapenv:Envelope' ||
                ' xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"' ||
                ' xmlns:v2="http://xmlns.oracle.com/oxp/service/v2">' ||
                '  <soapenv:Header/>' ||
                '  <soapenv:Body>' ||
                '    <v2:runReport>' ||
                '      <v2:reportRequest>' ||
                '        <v2:reportAbsolutePath>' || C_RPT_PATH || '</v2:reportAbsolutePath>' ||
                '        <v2:attributeFormat>xml</v2:attributeFormat>' ||
                '        <v2:parameterNameValues>' ||
                '          <v2:listOfParamNameValues>' ||
                '            <v2:item>' ||
                '              <v2:name>P_LOAD_ESS_ID</v2:name>' ||
                '              <v2:values><v2:item>' || p_load_ess_id || '</v2:item></v2:values>' ||
                '            </v2:item>' ||
                '            <v2:item>' ||
                '              <v2:name>P_JOB_DEF</v2:name>' ||
                '              <v2:values><v2:item>' || l_job_def || '</v2:item></v2:values>' ||
                '            </v2:item>' ||
                '          </v2:listOfParamNameValues>' ||
                '        </v2:parameterNameValues>' ||
                '        <v2:sizeOfDataChunkDownload>-1</v2:sizeOfDataChunkDownload>' ||
                '      </v2:reportRequest>' ||
                '      <v2:userID>' || l_bip_user || '</v2:userID>' ||
                '      <v2:password>' || l_bip_pass || '</v2:password>' ||
                '    </v2:runReport>' ||
                '  </soapenv:Body>' ||
                '</soapenv:Envelope>'));

            l_resp := bip_http(
                l_url,
                'http://xmlns.oracle.com/oxp/service/v2/ReportService/runReportRequest',
                l_env);

            DBMS_LOB.FREETEMPORARY(l_env);

            -- Decode reportBytes -> XML -> extract REQUESTID
            l_b64 := clob_tag_val(l_resp, 'reportBytes');
            IF l_b64 IS NOT NULL THEN
                l_xml       := UTL_RAW.CAST_TO_VARCHAR2(
                                   UTL_ENCODE.BASE64_DECODE(UTL_RAW.CAST_TO_RAW(l_b64)));
                l_import_id := REGEXP_SUBSTR(l_xml, '<REQUESTID>(\d+)</REQUESTID>', 1, 1, NULL, 1);
            END IF;

            IF l_import_id IS NOT NULL THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    'GET_IMPORT_ESS_ID: Found Import ESS job ' || l_import_id ||
                    ' on attempt ' || l_attempt || '. CEMLI: ' || p_cemli_code,
                    'INFO', C_PKG, l_log_proc);
                RETURN l_import_id;
            END IF;

            IF l_attempt >= C_MAX_TRIES THEN
                RAISE_APPLICATION_ERROR(-20050,
                    'GET_IMPORT_ESS_ID: Import ESS job (requestid > ' || p_load_ess_id ||
                    ', definition LIKE ''%' || l_job_def || '%'') not found after ' ||
                    (C_MAX_TRIES * C_SLEEP_SEC / 60) ||
                    ' minutes. Integration: ' || p_run_id ||
                    ' | CEMLI: ' || p_cemli_code);
            END IF;

            DMT_UTIL_PKG.LOG(p_run_id,
                'GET_IMPORT_ESS_ID: Import job not yet visible. Attempt ' ||
                l_attempt || '/' || C_MAX_TRIES ||
                '. Sleeping ' || C_SLEEP_SEC || 's. CEMLI: ' || p_cemli_code,
                'INFO', C_PKG, l_log_proc);

            DBMS_SESSION.SLEEP(C_SLEEP_SEC);
        END LOOP;

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'GET_IMPORT_ESS_ID failed. CEMLI: ' || p_cemli_code,
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => l_log_proc);
            RAISE;
    END get_import_ess_id;

    -- --------------------------------------------------------
    -- Private: run one object type through the full cycle:
    --   generate → upload → poll load → find import job →
    --   poll import → reconcile
    -- --------------------------------------------------------
    -- (C2b/A12, 2026-07-08) update_master_totals DELETED. It was a
    -- second run-status rollup (dynamic SQL over every TFM table) that
    -- disagreed with the queue rollup. One writer per status altitude:
    -- RUN_STATUS is written only by the heartbeat rollup
    -- (DMT_QUEUE_PKG.rollup_run_statuses), whose row counts come from
    -- the catalog-driven DMT_QUEUE_WORKER_PKG.ACCOUNT_ROWS.
    -- --------------------------------------------------------

    -- Returns TRUE if rows were generated and processed,
    -- FALSE if no VALIDATED rows existed (object type skipped).
    -- Raises on ESS failure or BIP reconciliation failure — caller must not proceed.
    -- --------------------------------------------------------
    FUNCTION run_one_object_type (
        p_run_id   IN NUMBER,
        p_cemli_code       IN VARCHAR2,
        p_scenario_id      IN NUMBER   DEFAULT NULL,
        p_run_mode         IN VARCHAR2  DEFAULT 'NEW',
        p_skip_bu_refresh  IN BOOLEAN   DEFAULT FALSE
    ) RETURN BOOLEAN IS
        C_PROC               CONSTANT VARCHAR2(40) := 'RUN_ONE_OBJECT_TYPE';
        l_zip                BLOB;
        l_filename           VARCHAR2(200);
        l_job_name           VARCHAR2(500);
        l_ucm_account        VARCHAR2(200);
        l_interface_details  NUMBER;
        l_load_ess_id        VARCHAR2(100);
        l_import_ess_id      VARCHAR2(100);
        l_ess_user           VARCHAR2(100) := NULL;  -- per-CEMLI Fusion user override
        l_ess_pass           VARCHAR2(100) := NULL;
        l_param_list         VARCHAR2(500) := 'NEW,N';  -- default for suppliers
        l_load_status        VARCHAR2(50);  -- Fusion status from Load ESS poll
        -- CEMLI-specific ParameterLists set below after ERP options lookup
        -- Object type label extracted from CEMLI code (e.g. 'Suppliers').
        -- Prefixed onto PROCEDURE_NAME in all LOG calls so multi-object runs are readable.
        l_obj                VARCHAR2(60);

        -- --------------------------------------------------------
        -- Nested helper: submit FBDI zip, poll load+import ESS,
        -- reconcile via BIP.  Captures l_job_name, l_interface_details,
        -- l_ucm_account, p_run_id, p_cemli_code, l_obj from
        -- the enclosing run_one_object_type scope.
        --
        -- Callers pass: FBDI zip (freed inside), filename, CSV ID,
        -- ParameterList, group label (for logging), and optional
        -- per-CEMLI credentials.
        --
        -- Returns x_success = FALSE when Load ESS fails so the
        -- caller can mark GENERATED rows FAILED in its own way.
        -- --------------------------------------------------------
        PROCEDURE submit_and_reconcile_one (
            p_fbdi_zip        IN OUT NOCOPY BLOB,
            p_filename        IN VARCHAR2,
            p_fbdi_csv_id     IN NUMBER,
            p_param_list      IN VARCHAR2,
            p_group_label     IN VARCHAR2,
            p_username        IN VARCHAR2 DEFAULT NULL,
            p_password        IN VARCHAR2 DEFAULT NULL,
            x_load_ess_id     OUT VARCHAR2,
            x_import_ess_id   OUT VARCHAR2,
            x_success         OUT BOOLEAN
        ) IS
            l_sar_load_status VARCHAR2(50);
        BEGIN
            x_success := FALSE;

            -- Submit loadAndImportData
            x_load_ess_id := SUBMIT_LOAD(
                p_run_id    => p_run_id,
                p_fbdi_zip          => p_fbdi_zip,
                p_filename          => p_filename,
                p_job_name          => l_job_name,
                p_interface_details => l_interface_details,
                p_doc_account       => l_ucm_account,
                p_parameter_list    => p_param_list,
                p_log_context       => l_obj,
                p_username          => p_username,
                p_password          => p_password);
            DBMS_LOB.FREETEMPORARY(p_fbdi_zip);

            -- Stamp the parameter list on the zip row. Keyed on FBDI_ZIP_ID, looked
            -- up from the primary csv id the generator returned (the ZIP table no
            -- longer carries FBDI_CSV_ID).
            UPDATE DMT_OWNER.DMT_FBDI_ZIP_TBL
            SET    PARAMETER_LIST  = p_param_list
            WHERE  FBDI_ZIP_ID = (SELECT FBDI_ZIP_ID FROM DMT_OWNER.DMT_FBDI_CSV_TBL
                                  WHERE FBDI_CSV_ID = p_fbdi_csv_id);
            COMMIT;

            -- Poll Load job
            DMT_UTIL_PKG.LOG(p_run_id,
                'Polling Load ESS job: ' || x_load_ess_id || ' (' || p_group_label || ')',
                'INFO', C_PKG, l_obj || ' > ' || C_PROC);
            POLL_ESS_JOB(p_run_id, x_load_ess_id, 1800, FALSE, l_obj, p_cemli_code,
                         l_sar_load_status, p_username => p_username, p_password => p_password);

            -- If Load ESS failed, caller handles error marking
            IF l_sar_load_status NOT IN (C_STATUS_SUCCEEDED, C_STATUS_WARNING) THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    'Load ESS ' || x_load_ess_id || ' returned ' || l_sar_load_status ||
                    ' for ' || p_group_label ||
                    '. No rows committed to interface table. Marking all GENERATED rows FAILED.',
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_obj || ' > ' || C_PROC);
                x_import_ess_id := NULL;
                RETURN;  -- x_success stays FALSE
            END IF;

            -- Find Import ESS job ID
            BEGIN
                x_import_ess_id := get_import_ess_id(p_run_id, p_cemli_code, x_load_ess_id);
            EXCEPTION
                WHEN OTHERS THEN
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Could not find chained Import ESS for Load ' || x_load_ess_id,
                        DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_obj || ' > ' || C_PROC);
                    x_import_ess_id := NULL;
            END;

            -- Stamp Import ESS job ID
            IF x_import_ess_id IS NOT NULL THEN
                COMMIT;

                -- Poll Import job
                DMT_UTIL_PKG.LOG(p_run_id,
                    'Polling Import ESS job: ' || x_import_ess_id || ' (' || p_group_label || ')',
                    'INFO', C_PKG, l_obj || ' > ' || C_PROC);
                POLL_ESS_JOB(p_run_id, x_import_ess_id, 1800, FALSE, l_obj, p_cemli_code,
                             l_sar_load_status, p_username => p_username, p_password => p_password);
            END IF;

            -- Capture the Report child ESS job (e.g. APXIIMPT_BIP, ImportProjectReportJob).
            -- Generic: returns NULL for CEMLIs without a REPORT_JOB_DEF in DMT_ERP_INTERFACE_OPTIONS_TBL.
            IF x_import_ess_id IS NOT NULL THEN
                DECLARE
                    l_report_ess_id NUMBER;
                BEGIN
                    l_report_ess_id := DMT_ESS_UTIL_PKG.CAPTURE_REPORT_ESS_JOB(
                        p_run_id => p_run_id,
                        p_import_ess_id  => TO_NUMBER(x_import_ess_id),
                        p_cemli_code     => p_cemli_code);
                END;

                -- Parse Import Report errors and log them.
                -- Runs for any CEMLI whose import job produced report output.
                BEGIN
                    DECLARE
                        l_ir_count NUMBER;
                    BEGIN
                        l_ir_count := DMT_IMPORT_REPORT_PKG.PARSE_AND_LOG_ERRORS(
                            p_run_id => p_run_id,
                            p_request_id     => TO_NUMBER(x_import_ess_id),
                            p_cemli_code     => p_cemli_code);
                        IF l_ir_count > 0 THEN
                            DMT_UTIL_PKG.LOG(p_run_id,
                                'Import Report captured ' || l_ir_count || ' error(s) for ' ||
                                p_cemli_code || ' (' || p_group_label || ', ESS ' || x_import_ess_id || ').',
                                'INFO', C_PKG, l_obj || ' > ' || C_PROC);
                        END IF;
                    END;
                EXCEPTION
                    WHEN OTHERS THEN
                        DMT_UTIL_PKG.LOG_ERROR(
                            p_run_id => p_run_id,
                            p_message        => 'Import Report capture failed for ' || p_cemli_code ||
                                ' (' || p_group_label || ', ESS ' || x_import_ess_id || '). Continuing to BIP.',
                            p_sqlerrm        => SQLERRM,
                            p_package        => C_PKG,
                            p_procedure      => l_obj || ' > ' || C_PROC);
                END;
            END IF;

            -- Reconcile via BIP — dispatch by CEMLI code
            IF p_cemli_code = 'PurchaseOrders' THEN
                DMT_PO_RESULTS_PKG.RECONCILE_BATCH(p_run_id, TO_NUMBER(x_load_ess_id), TO_NUMBER(x_import_ess_id));
            ELSIF p_cemli_code = 'ARInvoices' THEN
                DMT_AR_RESULTS_PKG.RECONCILE_BATCH(p_run_id, TO_NUMBER(x_load_ess_id), TO_NUMBER(x_import_ess_id));
            ELSIF p_cemli_code = 'BlanketPOs' THEN
                DMT_BLANKET_PO_RESULTS_PKG.RECONCILE_BATCH(p_run_id, TO_NUMBER(x_load_ess_id), TO_NUMBER(x_import_ess_id));
            ELSIF p_cemli_code = 'Contracts' THEN
                DMT_CONTRACT_RESULTS_PKG.RECONCILE_BATCH(p_run_id, TO_NUMBER(x_load_ess_id), TO_NUMBER(x_import_ess_id));
            ELSIF p_cemli_code = 'APInvoices' THEN
                DMT_AP_RESULTS_PKG.RECONCILE_BATCH(p_run_id, TO_NUMBER(x_load_ess_id), TO_NUMBER(x_import_ess_id));
            ELSIF p_cemli_code = '1099Invoices' THEN
                DMT_1099_RESULTS_PKG.RECONCILE_BATCH(p_run_id, TO_NUMBER(x_load_ess_id), TO_NUMBER(x_import_ess_id));
            ELSIF p_cemli_code = 'GLBalances' THEN
                DMT_GL_RESULTS_PKG.RECONCILE_BATCH(p_run_id, TO_NUMBER(x_load_ess_id), TO_NUMBER(x_import_ess_id));
            ELSIF p_cemli_code LIKE 'Supplier%' THEN
                DMT_POZ_SUP_RESULTS_PKG.RECONCILE_BATCH(p_run_id, p_cemli_code, TO_NUMBER(x_load_ess_id), TO_NUMBER(x_import_ess_id));
            ELSIF p_cemli_code = 'Customers' THEN
                DMT_CUST_RESULTS_PKG.RECONCILE_BATCH(p_run_id, TO_NUMBER(x_load_ess_id), TO_NUMBER(x_import_ess_id));
            ELSIF p_cemli_code = 'Projects' THEN
                DMT_PROJECT_RESULTS_PKG.RECONCILE_BATCH(p_run_id, TO_NUMBER(x_load_ess_id), TO_NUMBER(x_import_ess_id));
            ELSIF p_cemli_code = 'BillingEvents' THEN
                DMT_BILLING_EVENT_RESULTS_PKG.RECONCILE_BATCH(p_run_id, TO_NUMBER(x_load_ess_id), TO_NUMBER(x_import_ess_id));
            ELSIF p_cemli_code = 'Expenditures' THEN
                DMT_EXPENDITURE_RESULTS_PKG.RECONCILE_BATCH(p_run_id, TO_NUMBER(x_load_ess_id), TO_NUMBER(x_import_ess_id));
            ELSIF p_cemli_code = 'Grants' THEN
                DMT_GRANTS_RESULTS_PKG.RECONCILE_BATCH(p_run_id, TO_NUMBER(x_load_ess_id), TO_NUMBER(x_import_ess_id));
            ELSIF p_cemli_code = 'Items' THEN
                -- Reconcile items + bundled categories (if any)
                DMT_EGP_ITEM_RESULTS_PKG.RECONCILE_BATCH(p_run_id, TO_NUMBER(x_load_ess_id), TO_NUMBER(x_import_ess_id));
                DECLARE l_cat_gen2 NUMBER;
                BEGIN
                    SELECT COUNT(*) INTO l_cat_gen2 FROM DMT_OWNER.DMT_EGP_ITEM_CAT_TFM_TBL
                    WHERE RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
                    IF l_cat_gen2 > 0 THEN
                        DMT_EGP_ITEM_CAT_RESULTS_PKG.RECONCILE_BATCH(p_run_id, TO_NUMBER(x_load_ess_id), TO_NUMBER(x_import_ess_id));
                    END IF;
                END;
            ELSIF p_cemli_code = 'MiscReceipts' THEN
                DMT_MISC_RECEIPT_RESULTS_PKG.RECONCILE_BATCH(p_run_id, TO_NUMBER(x_load_ess_id), TO_NUMBER(x_import_ess_id));
            ELSIF p_cemli_code = 'Requisitions' THEN
                DMT_REQ_RESULTS_PKG.RECONCILE_BATCH(p_run_id, TO_NUMBER(x_load_ess_id), TO_NUMBER(x_import_ess_id));
            ELSIF p_cemli_code = 'GLBudgetBalances' THEN
                DMT_GL_BUDGET_RESULTS_PKG.RECONCILE_BATCH(p_run_id, TO_NUMBER(x_load_ess_id), TO_NUMBER(x_import_ess_id));
            ELSIF p_cemli_code = 'PlanningBudgets' THEN
                DMT_PLAN_BUDGET_RESULTS_PKG.RECONCILE_BATCH(p_run_id, TO_NUMBER(x_load_ess_id), TO_NUMBER(x_import_ess_id));
            ELSIF p_cemli_code = 'ProjectBudgets' THEN
                DMT_PRJ_BUDGET_RESULTS_PKG.RECONCILE_BATCH(p_run_id, TO_NUMBER(x_load_ess_id), TO_NUMBER(x_import_ess_id));
            ELSIF p_cemli_code = 'Assets' THEN
                DMT_FA_ASSET_RESULTS_PKG.RECONCILE_BATCH(p_run_id, TO_NUMBER(x_load_ess_id), TO_NUMBER(x_import_ess_id));
            END IF;

            x_success := TRUE;
        END submit_and_reconcile_one;

    BEGIN
        l_obj := SUBSTR(p_cemli_code, INSTR(p_cemli_code, '-') + 1);

        -- Refresh BU lookup data (BU IDs, Ledger IDs) from Fusion via BIP.
        -- Pipeline orchestrators call this once up front and pass p_skip_bu_refresh => TRUE.
        -- Standalone one-off runs get the default FALSE and refresh automatically.
        IF NOT p_skip_bu_refresh THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'Refreshing BU lookups (standalone run).',
                'INFO', C_PKG, l_obj || ' > ' || C_PROC);
            DMT_UTIL_PKG.REFRESH_BU_LOOKUPS;
        END IF;
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Object type start: ' || p_cemli_code,
            p_package        => C_PKG,
            p_procedure      => l_obj || ' > ' || C_PROC);

        -- Look up UCM account, ESS job name, and interface details ID once.
        -- All three values come from DMT_ERP_INTERFACE_OPTIONS_TBL (local Fusion mirror).
        get_erp_options(
            p_cemli_code           => p_cemli_code,
            x_ucm_account          => l_ucm_account,
            x_import_job_name      => l_job_name,
            x_interface_details_id => l_interface_details);

        -- Override ParameterList per CEMLI (MCCS patterns).
        -- Default is 'NEW,N' (suppliers). CEMLIs with different import jobs need different params.
        -- Customers is a grouped object: it partitions by BATCH_ID and builds a
        -- per-batch 4-value BulkImportJob ParameterList inside its grouped block
        -- (below), so it sets no ParameterList here -- exactly like ARInvoices.
        IF p_cemli_code = 'Projects' THEN
            -- MCCS RICE_006: ImportProjectJobDef takes 3 args (,,Y)
            l_param_list := ',,Y';
        ELSIF p_cemli_code = 'Expenditures' THEN
            -- MCCS RICE_007: ImportProcessParallelEssJob takes 14 args
            -- Pos: 1=BU_NAME, 2=BU_ID, 3=Process, 4=Selection,
            --      5=Batch(empty), 6=TxnSource(empty=all), 7-11=(empty), 12=Date,
            --      13=(empty), 14=ExpenditureTypeClass
            -- Using #NULL for empty params per Oracle ESS convention.
            -- No-hardcoded-IDs standard (design section 7): the business unit is
            -- named in config (EXPENDITURE_BU_NAME) and its instance-specific id
            -- is resolved from the prepopulated BU lookup, never baked into code.
            DECLARE
                l_exp_bu_name VARCHAR2(240);
                l_exp_bu_id   VARCHAR2(30);
            BEGIN
                l_exp_bu_name := DMT_UTIL_PKG.GET_CONFIG('EXPENDITURE_BU_NAME');
                l_exp_bu_id   := DMT_UTIL_PKG.GET_LOOKUP('BU_NAME_TO_BU_ID', l_exp_bu_name);
                l_param_list := l_exp_bu_name || ',' || l_exp_bu_id
                    || ',IMPORT_AND_PROCESS,PREV_NOT_IMPORTED,#NULL,#NULL,#NULL,#NULL,#NULL,#NULL,#NULL,'
                    || TO_CHAR(SYSDATE, 'YYYY-MM-DD') || ',#NULL,ORA_PJC_DETAIL';
            END;
        -- Requisitions: the ParameterList is built per batch inside the
        -- grouped-by-BATCH_ID block below (position 2 = the batch id,
        -- position 4 = that batch's requisitioning BU id), not here.
        -- Items: the ParameterList is built per batch inside the grouped-by-BATCH_ID
        -- block below (arg 1 = the batch id, matching that batch's interface rows),
        -- not here.
        ELSIF p_cemli_code = 'MiscReceipts' THEN
            -- MCCS RICE_011/012: PollTMEssJob, no parameters
            l_param_list := '#NULL';
        ELSIF p_cemli_code = 'BillingEvents' THEN
            -- Not in MCCS — use empty param list; will need discovery
            l_param_list := '#NULL';
        ELSIF p_cemli_code = 'Grants' THEN
            -- AwardMassImportJob: 3 optional args (award number LOV IDs + boolean)
            -- Discovered via Fusion MCCS UI-4 session 2026-04-01: #NULL,#NULL,#NULL
            -- Prior 'NEW,N' caused ESS WAIT timeout (wrong param count)
            l_param_list := '#NULL,#NULL,#NULL';
        -- GLBalances: param_list built per-ledger inside grouped loop below.
        ELSIF p_cemli_code = 'GLBudgetBalances' THEN
            l_param_list := '#NULL';
        ELSIF p_cemli_code = 'PlanningBudgets' THEN
            l_param_list := '#NULL';
        ELSIF p_cemli_code = 'ProjectBudgets' THEN
            l_param_list := '#NULL';
        ELSIF p_cemli_code = 'Assets' THEN
            -- PostMassAdditions: 3 args (from MCCS RICE_003):
            -- <BookTypeCode>,,NORMAL
            -- No-hardcoded-IDs standard (design section 7): the asset book is
            -- named config (ASSET_BOOK_TYPE), not a literal, so other book types
            -- load without a code change.
            l_param_list := DMT_UTIL_PKG.GET_CONFIG('ASSET_BOOK_TYPE') || ',,NORMAL';
        END IF;
        -- POs/BlanketPOs/Contracts override l_param_list inside their grouped blocks.
        -- AP/AR/1099 override inside their grouped blocks.

        -- Early exit: if param_list lookup found no eligible rows (e.g. Requisitions
        -- with no NEW rows in the scenario), skip the entire CEMLI gracefully.
        IF l_param_list IS NULL THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'No eligible rows for ' || p_cemli_code || ' in this scenario/run_mode. Skipping.',
                'WARN', C_PKG, l_obj || ' > ' || C_PROC);
            RETURN FALSE;
        END IF;

        -- Step 1: Pre-transform validation has been MOVED to Step 1.4b below — it must run
        -- AFTER the ALL-mode reset, otherwise the reset (Step 1.4) wipes any FAILED status
        -- the validator sets, letting bad rows flow into the FBDI/HDL and on to Fusion.

        -- (A8/C2b, 2026-07-08) The "Step 1.4 ALL-mode reset" block is DELETED
        -- (~70 reset_scenario_status calls). ALL mode selects every row in the
        -- scenario directly via the p_run_mode predicates (Overview run-mode
        -- table, ALL row) -- no status reset, and the retired RETRY status is
        -- never written.

        -- Step 1.4b: Pre-transform upstream dependency validation on staging rows.
        -- Marks staging rows FAILED if their upstream parent is not LOADED.
        -- MUST run after the Step 1.4 ALL-mode reset above so that FAILED status persists
        -- (the reset only flips prior-run statuses to RETRY; validation then re-fails the
        -- genuinely bad rows, and transform's NEW/RETRY filter excludes them from the FBDI).
        IF    p_cemli_code = 'Suppliers' THEN
            DMT_POZ_SUP_VALIDATOR_PKG.VALIDATE_SUPPLIERS(p_run_id);
        ELSIF p_cemli_code = 'SupplierAddresses' THEN
            DMT_POZ_SUP_VALIDATOR_PKG.VALIDATE_ADDRESSES(p_run_id);
        ELSIF p_cemli_code = 'SupplierSites' THEN
            DMT_POZ_SUP_VALIDATOR_PKG.VALIDATE_SITES(p_run_id);
        ELSIF p_cemli_code = 'SupplierSiteAssignments' THEN
            DMT_POZ_SUP_VALIDATOR_PKG.VALIDATE_SITE_ASSIGNMENTS(p_run_id);
        ELSIF p_cemli_code = 'SupplierContacts' THEN
            DMT_POZ_SUP_VALIDATOR_PKG.VALIDATE_CONTACTS(p_run_id);
        ELSIF p_cemli_code = 'PurchaseOrders' THEN
            DMT_PO_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id, p_doc_type_filter => 'Purchase Order');
        ELSIF p_cemli_code = 'BlanketPOs' THEN
            DMT_PO_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id, p_doc_type_filter => 'Blanket Purchase Agreement');
        ELSIF p_cemli_code = 'Contracts' THEN
            DMT_PO_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id, p_doc_type_filter => 'Contract Purchase Agreement');
        ELSIF p_cemli_code = 'Customers' THEN
            DMT_CUST_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
        ELSIF p_cemli_code = 'ARInvoices' THEN
            DMT_AR_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
        ELSIF p_cemli_code = 'APInvoices' THEN
            DMT_AP_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
        ELSIF p_cemli_code = 'Projects' THEN
            DMT_PROJECT_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
        ELSIF p_cemli_code = 'BillingEvents' THEN
            DMT_BILLING_EVENT_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
        ELSIF p_cemli_code = 'Expenditures' THEN
            DMT_EXPENDITURE_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
        ELSIF p_cemli_code = 'Grants' THEN
            DMT_GRANTS_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
        ELSIF p_cemli_code = '1099Invoices' THEN
            DMT_AP_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id, p_inv_type_filter => '%1099%');
        ELSIF p_cemli_code = 'Items' THEN
            DMT_EGP_ITEM_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
            -- ItemCategories bundle into the Items FBDI ZIP, so they are validated under the
            -- Items token (no separate 'ItemCategories' CEMLI in the pipeline sequence).
            DMT_EGP_ITEM_CAT_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
        ELSIF p_cemli_code = 'ItemCategories' THEN
            -- Dead in the standard pipeline (no 'ItemCategories' token); retained for the
            -- RUN_ITEM_CATEGORIES standalone validate/transform helper.
            DMT_EGP_ITEM_CAT_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
        ELSIF p_cemli_code = 'MiscReceipts' THEN
            DMT_MISC_RECEIPT_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
        ELSIF p_cemli_code = 'Requisitions' THEN
            DMT_REQ_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
        ELSIF p_cemli_code = 'GLBalances' THEN
            DMT_GL_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
        ELSIF p_cemli_code = 'GLBudgetBalances' THEN
            DMT_GL_BUDGET_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
        ELSIF p_cemli_code = 'PlanningBudgets' THEN
            DMT_PLAN_BUDGET_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
        ELSIF p_cemli_code = 'ProjectBudgets' THEN
            DMT_PRJ_BUDGET_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
        ELSIF p_cemli_code = 'Assets' THEN
            -- Multi-book child rows (g_partition_key set) were already validated by the
            -- parent's transform-only pass; skip to avoid re-processing STAGED rows.
            IF g_partition_key IS NULL THEN
                DMT_FA_ASSET_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
            END IF;
        END IF;
        COMMIT;

        -- Step 1.5: Transform staging rows → transformed table (applies prefix, derives fields).
        -- Only rows with STG_STATUS IN ('NEW','RETRY') that passed pre-validation are picked up.
        -- Scenario filter: when p_scenario_id is non-NULL, only rows matching
        -- the scenario are transformed (scenarios are mandatory at ingestion).
        IF    p_cemli_code = 'Suppliers' THEN
            DMT_POZ_SUP_TRANSFORM_PKG.TRANSFORM_SUPPLIERS(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
        ELSIF p_cemli_code = 'SupplierAddresses' THEN
            DMT_POZ_SUP_TRANSFORM_PKG.TRANSFORM_ADDRESSES(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
        ELSIF p_cemli_code = 'SupplierSites' THEN
            DMT_POZ_SUP_TRANSFORM_PKG.TRANSFORM_SITES(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
        ELSIF p_cemli_code = 'SupplierSiteAssignments' THEN
            DMT_POZ_SUP_TRANSFORM_PKG.TRANSFORM_SITE_ASSIGNMENTS(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
        ELSIF p_cemli_code = 'SupplierContacts' THEN
            DMT_POZ_SUP_TRANSFORM_PKG.TRANSFORM_CONTACTS(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
        ELSIF p_cemli_code = 'PurchaseOrders' THEN
            DMT_PO_TRANSFORM_PKG.TRANSFORM_HEADERS(p_run_id, p_doc_type_filter => 'Purchase Order', p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            DMT_PO_TRANSFORM_PKG.TRANSFORM_LINES(p_run_id, p_doc_type_filter => 'Purchase Order', p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            DMT_PO_TRANSFORM_PKG.TRANSFORM_LINE_LOCS(p_run_id, p_doc_type_filter => 'Purchase Order', p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            DMT_PO_TRANSFORM_PKG.TRANSFORM_DISTS(p_run_id, p_doc_type_filter => 'Purchase Order', p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
        ELSIF p_cemli_code = 'BlanketPOs' THEN
            DMT_PO_TRANSFORM_PKG.TRANSFORM_HEADERS(p_run_id, p_doc_type_filter => 'Blanket Purchase Agreement', p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            DMT_PO_TRANSFORM_PKG.TRANSFORM_LINES(p_run_id, p_doc_type_filter => 'Blanket Purchase Agreement', p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
        ELSIF p_cemli_code = 'Contracts' THEN
            DMT_PO_TRANSFORM_PKG.TRANSFORM_HEADERS(p_run_id, p_doc_type_filter => 'Contract Purchase Agreement', p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
        ELSIF p_cemli_code = 'Customers' THEN
            DMT_CUST_TRANSFORM_PKG.TRANSFORM_PARTIES(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            DMT_CUST_TRANSFORM_PKG.TRANSFORM_LOCATIONS(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            DMT_CUST_TRANSFORM_PKG.TRANSFORM_PARTY_SITES(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            DMT_CUST_TRANSFORM_PKG.TRANSFORM_PARTY_SITE_USES(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            DMT_CUST_TRANSFORM_PKG.TRANSFORM_ACCOUNTS(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            DMT_CUST_TRANSFORM_PKG.TRANSFORM_ACCT_SITES(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            DMT_CUST_TRANSFORM_PKG.TRANSFORM_ACCT_SITE_USES(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
        ELSIF p_cemli_code = 'ARInvoices' THEN
            DMT_AR_TRANSFORM_PKG.TRANSFORM_LINES(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            DMT_AR_TRANSFORM_PKG.TRANSFORM_DISTS(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
        ELSIF p_cemli_code = 'APInvoices' THEN
            DMT_AP_TRANSFORM_PKG.TRANSFORM_HEADERS(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            DMT_AP_TRANSFORM_PKG.TRANSFORM_LINES(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
        ELSIF p_cemli_code = 'Projects' THEN
            DMT_PROJECT_TRANSFORM_PKG.TRANSFORM_PROJECTS(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            DMT_PROJECT_TRANSFORM_PKG.TRANSFORM_TASKS(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            DMT_PROJECT_TRANSFORM_PKG.TRANSFORM_TEAM_MEMBERS(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            DMT_PROJECT_TRANSFORM_PKG.TRANSFORM_TXN_CONTROLS(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
        ELSIF p_cemli_code = 'BillingEvents' THEN
            DMT_BILLING_EVENT_TRANSFORM_PKG.TRANSFORM_EVENTS(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
        ELSIF p_cemli_code = 'Expenditures' THEN
            DMT_EXPENDITURE_TRANSFORM_PKG.TRANSFORM_EXPENDITURES(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
        ELSIF p_cemli_code = 'Grants' THEN
            DMT_GRANTS_TRANSFORM_PKG.TRANSFORM_HEADERS(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            DMT_GRANTS_TRANSFORM_PKG.TRANSFORM_FUNDING(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            DMT_GRANTS_TRANSFORM_PKG.TRANSFORM_PROJECTS(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            DMT_GRANTS_TRANSFORM_PKG.TRANSFORM_PERSONNEL(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            DMT_GRANTS_TRANSFORM_PKG.TRANSFORM_FUND_SOURCES(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            DMT_GRANTS_TRANSFORM_PKG.TRANSFORM_PRJ_FUND_SRCS(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            DMT_GRANTS_TRANSFORM_PKG.TRANSFORM_KEYWORDS(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            DMT_GRANTS_TRANSFORM_PKG.TRANSFORM_BUDGET_PERIODS(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            DMT_GRANTS_TRANSFORM_PKG.TRANSFORM_CERTS(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            DMT_GRANTS_TRANSFORM_PKG.TRANSFORM_CFDAS(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            DMT_GRANTS_TRANSFORM_PKG.TRANSFORM_FUND_ALLOCS(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            DMT_GRANTS_TRANSFORM_PKG.TRANSFORM_ORG_CREDITS(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            DMT_GRANTS_TRANSFORM_PKG.TRANSFORM_PRJ_TASK_BURDEN(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            DMT_GRANTS_TRANSFORM_PKG.TRANSFORM_REFERENCES(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            DMT_GRANTS_TRANSFORM_PKG.TRANSFORM_TERMS(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
        ELSIF p_cemli_code = '1099Invoices' THEN
            DMT_AP_TRANSFORM_PKG.TRANSFORM_HEADERS(p_run_id, p_inv_type_filter => '%1099%', p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            DMT_AP_TRANSFORM_PKG.TRANSFORM_LINES(p_run_id, p_inv_type_filter => '%1099%', p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
        ELSIF p_cemli_code = 'Items' THEN
            DMT_EGP_ITEM_TRANSFORM_PKG.TRANSFORM(p_run_id, p_reprocess_errors => (p_run_mode = 'FAILED'), p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            -- Transform bundled categories before the Items FBDI generator picks them up
            -- (DMT_EGP_ITEM_FBDI_GEN_PKG reads DMT_EGP_ITEM_CAT_TFM_TBL for the bundled CSV).
            DMT_EGP_ITEM_CAT_TRANSFORM_PKG.TRANSFORM(p_run_id, p_reprocess_errors => (p_run_mode = 'FAILED'), p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
        ELSIF p_cemli_code = 'ItemCategories' THEN
            -- Dead in the standard pipeline (categories run under the Items token); retained
            -- for the RUN_ITEM_CATEGORIES standalone helper.
            DMT_EGP_ITEM_CAT_TRANSFORM_PKG.TRANSFORM(p_run_id, p_reprocess_errors => (p_run_mode = 'FAILED'), p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
        ELSIF p_cemli_code = 'MiscReceipts' THEN
            DMT_MISC_RECEIPT_TRANSFORM_PKG.TRANSFORM(p_run_id, p_reprocess_errors => (p_run_mode = 'FAILED'), p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
        ELSIF p_cemli_code = 'Requisitions' THEN
            DMT_REQ_TRANSFORM_PKG.TRANSFORM_HEADERS(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            DMT_REQ_TRANSFORM_PKG.TRANSFORM_LINES(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            DMT_REQ_TRANSFORM_PKG.TRANSFORM_DISTS(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
        ELSIF p_cemli_code = 'GLBalances' THEN
            DMT_GL_TRANSFORM_PKG.TRANSFORM(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
        ELSIF p_cemli_code = 'GLBudgetBalances' THEN
            DMT_GL_BUDGET_TRANSFORM_PKG.TRANSFORM(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
        ELSIF p_cemli_code = 'PlanningBudgets' THEN
            DMT_PLAN_BUDGET_TRANSFORM_PKG.TRANSFORM(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
        ELSIF p_cemli_code = 'ProjectBudgets' THEN
            DMT_PRJ_BUDGET_TRANSFORM_PKG.TRANSFORM(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
        ELSIF p_cemli_code = 'Assets' THEN
            -- Multi-book: a child row (g_partition_key set) is already transformed by the
            -- parent's transform-only pass. Re-transforming would reset STAGED rows.
            IF g_partition_key IS NULL THEN
                DMT_FA_ASSET_TRANSFORM_PKG.TRANSFORM_HEADERS(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
                DMT_FA_ASSET_TRANSFORM_PKG.TRANSFORM_ASSIGNMENTS(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
                DMT_FA_ASSET_TRANSFORM_PKG.TRANSFORM_BOOKS(p_run_id, p_scenario_id => p_scenario_id, p_run_mode => p_run_mode);
            END IF;
        END IF;
        COMMIT;

        -- ============================================================
        -- PurchaseOrders: multi-BU load cycle
        -- Each distinct PRC_BU_NAME gets its own FBDI zip,
        -- loadAndImportData call, and BIP reconciliation.
        -- ============================================================
        IF p_cemli_code = 'PurchaseOrders' THEN
            DECLARE
                l_bu_zip       BLOB;
                l_bu_filename  VARCHAR2(200);
                l_bu_csv_id    NUMBER;
                l_bu_load_id   VARCHAR2(100);
                l_bu_import_id VARCHAR2(100);
                l_bu_param     VARCHAR2(500);
                l_bu_id        VARCHAR2(30);
                l_buyer_id     VARCHAR2(30);
                l_req_bu_id    VARCHAR2(30);
                l_bu_count     NUMBER := 0;
                l_bu_ok        BOOLEAN;
                l_po_user      VARCHAR2(100);
                l_po_pass      VARCHAR2(100);
            BEGIN
                DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS('PurchaseOrders', l_po_user, l_po_pass);
                FOR bu_rec IN (
                    SELECT DISTINCT PRC_BU_NAME
                    FROM   DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL
                    WHERE  RUN_ID = p_run_id
                    AND    TFM_STATUS = 'STAGED'
                    ORDER BY PRC_BU_NAME
                ) LOOP
                    l_bu_count := l_bu_count + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'PO BU cycle start: ' || bu_rec.PRC_BU_NAME,
                        'INFO', C_PKG, l_obj || ' > ' || C_PROC);

                    DMT_PO_FBDI_GEN_PKG.GENERATE_FBDI(
                        p_run_id => p_run_id,
                        p_prc_bu_name    => bu_rec.PRC_BU_NAME,
                        x_fbdi_zip       => l_bu_zip,
                        x_filename       => l_bu_filename,
                        x_fbdi_csv_id    => l_bu_csv_id);

                    IF l_bu_zip IS NULL OR DBMS_LOB.GETLENGTH(l_bu_zip) = 0 THEN
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'No rows for BU ' || bu_rec.PRC_BU_NAME || '. Skipping.',
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_obj || ' > ' || C_PROC);
                        CONTINUE;
                    END IF;

                    -- BU id via the one common lookup accessor (raises -20040
                    -- with a clear halt message if the BU is not resolvable).
                    l_bu_id := DMT_UTIL_PKG.GET_LOOKUP('BU_NAME_TO_BU_ID', bu_rec.PRC_BU_NAME);
                    l_buyer_id := DMT_UTIL_PKG.GET_CONFIG('PO_DEFAULT_BUYER_ID');
                    l_req_bu_id := DMT_UTIL_PKG.GET_CONFIG('PO_DEFAULT_REQ_BU_ID');

                    -- Arg 5 (Batch ID) is left blank on purpose: Import Orders then
                    -- processes all pending interface rows for this BU, so PO partitions
                    -- by Procurement BU only. The user's batch id still rides through on
                    -- the interface BATCH_ID column (transform: NVL(user BATCH_ID, run_id))
                    -- for traceability -- it is a tracking value here, not a load filter.
                    l_bu_param := l_bu_id || ',' || l_buyer_id || ',' || 'SUBMIT' || ',' ||
                                  l_req_bu_id || ',,' || 'N' || ',,' || 'N' || ',' ||
                                  l_bu_id || '_' || TO_CHAR(p_run_id);
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'PO ParameterList for ' || bu_rec.PRC_BU_NAME || ': ' || l_bu_param,
                        'INFO', C_PKG, l_obj || ' > ' || C_PROC);

                    submit_and_reconcile_one(
                        p_fbdi_zip    => l_bu_zip,
                        p_filename    => l_bu_filename,
                        p_fbdi_csv_id => l_bu_csv_id,
                        p_param_list  => l_bu_param,
                        p_group_label => 'BU: ' || bu_rec.PRC_BU_NAME,
                        p_username    => l_po_user,
                        p_password    => l_po_pass,
                        x_load_ess_id   => l_bu_load_id,
                        x_import_ess_id => l_bu_import_id,
                        x_success       => l_bu_ok);

                    IF NOT l_bu_ok THEN
                        DECLARE
                            l_err VARCHAR2(500) := '[LOAD_ERROR] Loading data to the Fusion interface failed. Check ESS job ' || l_bu_load_id || ' logs for details.';
                        BEGIN
                            UPDATE DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL
                            SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err)
                            WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED' AND PRC_BU_NAME=bu_rec.PRC_BU_NAME;
                            UPDATE DMT_OWNER.DMT_PO_LINES_INT_TFM_TBL
                            SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err)
                            WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED'
                            AND INTERFACE_HEADER_KEY IN (SELECT INTERFACE_HEADER_KEY FROM DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL WHERE RUN_ID=p_run_id AND PRC_BU_NAME=bu_rec.PRC_BU_NAME);
                            UPDATE DMT_OWNER.DMT_PO_LINE_LOCS_INT_TFM_TBL
                            SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err)
                            WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED'
                            AND INTERFACE_LINE_KEY IN (SELECT INTERFACE_LINE_KEY FROM DMT_OWNER.DMT_PO_LINES_INT_TFM_TBL WHERE RUN_ID=p_run_id
                                AND INTERFACE_HEADER_KEY IN (SELECT INTERFACE_HEADER_KEY FROM DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL WHERE RUN_ID=p_run_id AND PRC_BU_NAME=bu_rec.PRC_BU_NAME));
                            UPDATE DMT_OWNER.DMT_PO_DISTS_INT_TFM_TBL
                            SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err)
                            WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED'
                            AND INTERFACE_LINE_LOCATION_KEY IN (SELECT INTERFACE_LINE_LOCATION_KEY FROM DMT_OWNER.DMT_PO_LINE_LOCS_INT_TFM_TBL WHERE RUN_ID=p_run_id
                                AND INTERFACE_LINE_KEY IN (SELECT INTERFACE_LINE_KEY FROM DMT_OWNER.DMT_PO_LINES_INT_TFM_TBL WHERE RUN_ID=p_run_id
                                AND INTERFACE_HEADER_KEY IN (SELECT INTERFACE_HEADER_KEY FROM DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL WHERE RUN_ID=p_run_id AND PRC_BU_NAME=bu_rec.PRC_BU_NAME)));
                            COMMIT;
                        END;
                        CONTINUE;
                    END IF;

                    DMT_UTIL_PKG.LOG(p_run_id,
                        'PO BU cycle complete: ' || bu_rec.PRC_BU_NAME,
                        'INFO', C_PKG, l_obj || ' > ' || C_PROC);
                END LOOP;

                IF l_bu_count = 0 THEN
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'No STAGED PO headers found. Skipping PurchaseOrders.',
                        DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_obj || ' > ' || C_PROC);
                    RETURN FALSE;
                END IF;
            END;

            -- After all BUs: check failed rows + update master totals
            GOTO grouped_finish;
        END IF;

        -- ============================================================
        -- ARInvoices: grouped load by (BU_NAME, BATCH_SOURCE_NAME)
        -- Each distinct combination gets its own FBDI zip,
        -- loadAndImportData call, and BIP reconciliation.
        -- ParameterList: BU_NAME, BATCH_SOURCE_NAME, SYSDATE
        -- ============================================================
        IF p_cemli_code = 'ARInvoices' THEN
            DECLARE
                l_ar_zip        BLOB;
                l_ar_filename   VARCHAR2(200);
                l_ar_csv_id     NUMBER;
                l_ar_load_id    VARCHAR2(100);
                l_ar_import_id  VARCHAR2(100);
                l_ar_param      VARCHAR2(500);
                l_ar_count      NUMBER := 0;
                l_ar_ok         BOOLEAN;
            BEGIN
                FOR grp_rec IN (
                    SELECT DISTINCT BU_NAME, BATCH_SOURCE_NAME
                    FROM   DMT_OWNER.DMT_RA_LINES_TFM_TBL
                    WHERE  RUN_ID = p_run_id
                    AND    TFM_STATUS = 'STAGED'
                    ORDER BY BU_NAME, BATCH_SOURCE_NAME
                ) LOOP
                    l_ar_count := l_ar_count + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'AR group cycle start: BU=' || grp_rec.BU_NAME ||
                        ', Source=' || grp_rec.BATCH_SOURCE_NAME,
                        'INFO', C_PKG, l_obj || ' > ' || C_PROC);

                    DMT_AR_FBDI_GEN_PKG.GENERATE_FBDI(
                        p_run_id    => p_run_id,
                        p_bu_name           => grp_rec.BU_NAME,
                        p_batch_source_name => grp_rec.BATCH_SOURCE_NAME,
                        x_fbdi_zip          => l_ar_zip,
                        x_filename          => l_ar_filename,
                        x_fbdi_csv_id       => l_ar_csv_id);

                    IF l_ar_zip IS NULL OR DBMS_LOB.GETLENGTH(l_ar_zip) = 0 THEN
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'No rows for BU=' || grp_rec.BU_NAME ||
                            ', Source=' || grp_rec.BATCH_SOURCE_NAME || '. Skipping.',
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_obj || ' > ' || C_PROC);
                        CONTINUE;
                    END IF;

                    -- 24-arg ParameterList for AutoInvoiceImportEss
                    l_ar_param := grp_rec.BU_NAME || ',' || grp_rec.BATCH_SOURCE_NAME
                        || ',' || TO_CHAR(SYSDATE, 'YYYY-MM-DD')
                        || ',#NULL,#NULL,#NULL,#NULL,#NULL,#NULL,#NULL,#NULL,#NULL'
                        || ',#NULL,#NULL,#NULL,#NULL,#NULL,#NULL,#NULL,#NULL,#NULL'
                        || ',#NULL,N,#NULL';
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'AR ParameterList: ' || l_ar_param,
                        'INFO', C_PKG, l_obj || ' > ' || C_PROC);

                    submit_and_reconcile_one(
                        p_fbdi_zip    => l_ar_zip,
                        p_filename    => l_ar_filename,
                        p_fbdi_csv_id => l_ar_csv_id,
                        p_param_list  => l_ar_param,
                        p_group_label => 'BU: ' || grp_rec.BU_NAME || ', Source: ' || grp_rec.BATCH_SOURCE_NAME,
                        x_load_ess_id   => l_ar_load_id,
                        x_import_ess_id => l_ar_import_id,
                        x_success       => l_ar_ok);

                    IF NOT l_ar_ok THEN
                        DECLARE
                            l_err VARCHAR2(500) := '[LOAD_ERROR] Loading data to the Fusion interface failed. Check ESS job ' || l_ar_load_id || ' logs for details.';
                        BEGIN
                            UPDATE DMT_OWNER.DMT_RA_LINES_TFM_TBL
                            SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err)
                            WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED'
                            AND BU_NAME=grp_rec.BU_NAME AND BATCH_SOURCE_NAME=grp_rec.BATCH_SOURCE_NAME;
                            UPDATE DMT_OWNER.DMT_RA_DISTS_TFM_TBL
                            SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err)
                            WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED'
                            AND BU_NAME=grp_rec.BU_NAME;
                            COMMIT;
                        END;
                        CONTINUE;
                    END IF;

                    -- Check for rows still at GENERATED after BIP reconciliation
                    DECLARE
                        l_gen_count  NUMBER;
                    BEGIN
                        SELECT COUNT(*) INTO l_gen_count
                        FROM   DMT_OWNER.DMT_RA_LINES_TFM_TBL
                        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED'
                        AND    BU_NAME = grp_rec.BU_NAME AND BATCH_SOURCE_NAME = grp_rec.BATCH_SOURCE_NAME;
                        IF l_gen_count > 0 THEN
                            DMT_UTIL_PKG.LOG(p_run_id,
                                'WARNING: ' || l_gen_count || ' AR rows still at GENERATED after BIP reconciliation ' ||
                                '(BU: ' || grp_rec.BU_NAME || ', Source: ' || grp_rec.BATCH_SOURCE_NAME || '). ' ||
                                'These rows were not matched by BIP and require manual investigation.',
                                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_obj || ' > ' || C_PROC);
                        END IF;
                    END;

                    DMT_UTIL_PKG.LOG(p_run_id,
                        'AR group cycle complete: BU=' || grp_rec.BU_NAME ||
                        ', Source=' || grp_rec.BATCH_SOURCE_NAME,
                        'INFO', C_PKG, l_obj || ' > ' || C_PROC);
                END LOOP;

                IF l_ar_count = 0 THEN
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'No STAGED AR invoice lines found. Skipping ARInvoices.',
                        DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_obj || ' > ' || C_PROC);
                    RETURN FALSE;
                END IF;
            END;

            -- After all groups: check failed rows + update master totals
            GOTO grouped_finish;
        END IF;

        -- ============================================================
        -- Customers: grouped load, partitioned by (BATCH_ID, Source System).
        -- The load job MUST be "Import Bulk Customer Data" (job def
        -- CDMAutoBulkImportJob at /oracle/apps/ess/cdm/foundation/bulkImport),
        -- NOT BulkImportJob ("Import Trading Community Data in Bulk", which needs
        -- a pre-existing batch and NPEs on a null batchId). CDMAutoBulkImportJob
        -- CREATES the import batch from a 4-value positional ParameterList
        -- (Batch ID, Batch Name, Object CODE 'CUSTOMER', Source System) and then
        -- processes it -- proven by manual ESS run 9731634. The object arg MUST
        -- be the code 'CUSTOMER' (not 'Customer and Consumer'). We emit one FBDI
        -- + one load per (BATCH_ID, Source System); the batch id comes from the
        -- CSV and one batch uses exactly one source system.
        -- ============================================================
        IF p_cemli_code = 'Customers' THEN
            DECLARE
                l_cu_zip        BLOB;
                l_cu_filename   VARCHAR2(200);
                l_cu_csv_id     NUMBER;
                l_cu_load_id    VARCHAR2(100);
                l_cu_import_id  VARCHAR2(100);
                l_cu_param      VARCHAR2(500);
                l_cu_count      NUMBER := 0;
                l_cu_ok         BOOLEAN;

                -- Fail every one of the 7 customer sub-object TFM tables'
                -- GENERATED rows for this batch, with a reportable error.
                PROCEDURE mark_batch_failed(p_bid IN NUMBER, p_msg IN VARCHAR2) IS
                BEGIN
                    UPDATE DMT_OWNER.DMT_HZ_PARTIES_TFM_TBL         SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,p_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED' AND BATCH_ID=p_bid;
                    UPDATE DMT_OWNER.DMT_HZ_LOCATIONS_TFM_TBL       SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,p_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED' AND BATCH_ID=p_bid;
                    UPDATE DMT_OWNER.DMT_HZ_PARTY_SITES_TFM_TBL     SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,p_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED' AND BATCH_ID=p_bid;
                    UPDATE DMT_OWNER.DMT_HZ_PARTY_SITE_USES_TFM_TBL SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,p_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED' AND BATCH_ID=p_bid;
                    UPDATE DMT_OWNER.DMT_HZ_ACCOUNTS_TFM_TBL        SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,p_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED' AND BATCH_ID=p_bid;
                    UPDATE DMT_OWNER.DMT_HZ_ACCT_SITES_TFM_TBL      SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,p_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED' AND BATCH_ID=p_bid;
                    UPDATE DMT_OWNER.DMT_HZ_ACCT_SITE_USES_TFM_TBL  SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,p_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED' AND BATCH_ID=p_bid;
                    COMMIT;
                END mark_batch_failed;
            BEGIN
                FOR grp_rec IN (
                    SELECT BATCH_ID,
                           MIN(PARTY_ORIG_SYSTEM)            AS SOURCE_SYSTEM,
                           COUNT(DISTINCT PARTY_ORIG_SYSTEM) AS SRC_COUNT
                    FROM   DMT_OWNER.DMT_HZ_PARTIES_TFM_TBL
                    WHERE  RUN_ID = p_run_id
                    AND    TFM_STATUS = 'STAGED'
                    AND    BATCH_ID IS NOT NULL
                    GROUP BY BATCH_ID
                    ORDER BY BATCH_ID
                ) LOOP
                    l_cu_count := l_cu_count + 1;

                    -- One batch = one source system (Source System is a single
                    -- positional ESS parameter for the whole batch).
                    IF grp_rec.SRC_COUNT > 1 THEN
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'Customer batch ' || grp_rec.BATCH_ID || ' mixes ' || grp_rec.SRC_COUNT ||
                            ' source systems -- a batch must use exactly one. Marking FAILED.',
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_obj || ' > ' || C_PROC);
                        mark_batch_failed(grp_rec.BATCH_ID,
                            '[PRE_VALIDATION] Batch ' || grp_rec.BATCH_ID ||
                            ' mixes multiple source systems; one batch must use exactly one source system.');
                        CONTINUE;
                    END IF;

                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Customer batch cycle start: BATCH_ID=' || grp_rec.BATCH_ID ||
                        ', Source=' || grp_rec.SOURCE_SYSTEM,
                        'INFO', C_PKG, l_obj || ' > ' || C_PROC);

                    DMT_CUST_FBDI_GEN_PKG.GENERATE_FBDI(
                        p_run_id      => p_run_id,
                        x_fbdi_zip    => l_cu_zip,
                        x_filename    => l_cu_filename,
                        x_fbdi_csv_id => l_cu_csv_id,
                        p_batch_id    => grp_rec.BATCH_ID);

                    IF l_cu_zip IS NULL OR DBMS_LOB.GETLENGTH(l_cu_zip) = 0 THEN
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'No rows for customer batch ' || grp_rec.BATCH_ID || '. Skipping.',
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_obj || ' > ' || C_PROC);
                        CONTINUE;
                    END IF;

                    -- ParameterList for "Import Bulk Customer Data"
                    -- (job def CDMAutoBulkImportJob), which CREATES the import batch
                    -- from these 4 positional args -- modelled on the proven manual run
                    -- (ESS 9731634): 1=Batch ID (from the CSV), 2=Batch Name,
                    -- 3=Object CODE ('CUSTOMER' -- NOT 'Customer and Consumer',
                    -- which silently fails to create the batch), 4=Source System.
                    l_cu_param := TO_CHAR(grp_rec.BATCH_ID)
                        || ',Batch ID ' || TO_CHAR(grp_rec.BATCH_ID) || ' ' || grp_rec.SOURCE_SYSTEM
                        || ',CUSTOMER'
                        || ',' || grp_rec.SOURCE_SYSTEM;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Customer ParameterList: ' || l_cu_param,
                        'INFO', C_PKG, l_obj || ' > ' || C_PROC);

                    submit_and_reconcile_one(
                        p_fbdi_zip    => l_cu_zip,
                        p_filename    => l_cu_filename,
                        p_fbdi_csv_id => l_cu_csv_id,
                        p_param_list  => l_cu_param,
                        p_group_label => 'Batch: ' || grp_rec.BATCH_ID,
                        x_load_ess_id   => l_cu_load_id,
                        x_import_ess_id => l_cu_import_id,
                        x_success       => l_cu_ok);

                    IF NOT l_cu_ok THEN
                        mark_batch_failed(grp_rec.BATCH_ID,
                            '[LOAD_ERROR] Loading customer batch ' || grp_rec.BATCH_ID ||
                            ' to the Fusion interface failed. Check ESS job ' || l_cu_load_id || ' logs.');
                        CONTINUE;
                    END IF;

                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Customer batch cycle complete: BATCH_ID=' || grp_rec.BATCH_ID,
                        'INFO', C_PKG, l_obj || ' > ' || C_PROC);
                END LOOP;

                IF l_cu_count = 0 THEN
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'No STAGED Customer rows with a batch id found. Skipping Customers.',
                        DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_obj || ' > ' || C_PROC);
                    RETURN FALSE;
                END IF;
            END;

            GOTO grouped_finish;
        END IF;

        -- ============================================================
        -- Requisitions: grouped load by BATCH_ID.
        -- One batch = one FBDI zip = one Import Requisitions ESS run.
        -- The batch key lives on the HEADER only; lines and distributions
        -- belong to a batch through their header link (INTERFACE_HEADER_KEY),
        -- so the generator filters them by joining back to the header.
        -- One batch must use exactly one requisitioning business unit
        -- (RequisitioningBuId is a single positional ESS argument).
        -- ============================================================
        IF p_cemli_code = 'Requisitions' THEN
            DECLARE
                l_rq_zip        BLOB;
                l_rq_filename   VARCHAR2(200);
                l_rq_csv_id     NUMBER;
                l_rq_load_id    VARCHAR2(100);
                l_rq_import_id  VARCHAR2(100);
                l_rq_param      VARCHAR2(500);
                l_rq_count      NUMBER := 0;
                l_rq_bu_id      VARCHAR2(30);
                l_rq_ok         BOOLEAN;
                l_rq_user       VARCHAR2(100);
                l_rq_pass       VARCHAR2(100);

                -- Fail this batch's GENERATED rows across all 3 REQ TFM tables.
                -- Headers filter by BATCH_ID directly; lines/dists filter by
                -- their header's BATCH_ID (they have no batch column).
                PROCEDURE mark_batch_failed(p_bid IN VARCHAR2, p_msg IN VARCHAR2) IS
                BEGIN
                    UPDATE DMT_OWNER.DMT_POR_REQ_HEADERS_TFM_TBL
                    SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,p_msg)
                    WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED' AND BATCH_ID=p_bid;

                    UPDATE DMT_OWNER.DMT_POR_REQ_LINES_TFM_TBL l
                    SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,p_msg)
                    WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED'
                      AND EXISTS (SELECT 1 FROM DMT_OWNER.DMT_POR_REQ_HEADERS_TFM_TBL h
                                  WHERE h.RUN_ID=l.RUN_ID
                                    AND h.INTERFACE_HEADER_KEY=l.INTERFACE_HEADER_KEY
                                    AND h.BATCH_ID=p_bid);

                    UPDATE DMT_OWNER.DMT_POR_REQ_DISTS_TFM_TBL d
                    SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,p_msg)
                    WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED'
                      AND EXISTS (SELECT 1
                                  FROM DMT_OWNER.DMT_POR_REQ_LINES_TFM_TBL l
                                  JOIN DMT_OWNER.DMT_POR_REQ_HEADERS_TFM_TBL h
                                    ON h.RUN_ID=l.RUN_ID AND h.INTERFACE_HEADER_KEY=l.INTERFACE_HEADER_KEY
                                  WHERE l.RUN_ID=d.RUN_ID
                                    AND l.INTERFACE_LINE_KEY=d.INTERFACE_LINE_KEY
                                    AND h.BATCH_ID=p_bid);
                    COMMIT;
                END mark_batch_failed;
            BEGIN
                -- Requisitions submits under its own configured ESS user
                -- (same credential the single-submit path used to load online).
                DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS('Requisitions', l_rq_user, l_rq_pass);

                FOR grp_rec IN (
                    SELECT BATCH_ID,
                           MIN(REQ_BU_NAME)            AS REQ_BU_NAME,
                           COUNT(DISTINCT REQ_BU_NAME) AS BU_COUNT
                    FROM   DMT_OWNER.DMT_POR_REQ_HEADERS_TFM_TBL
                    WHERE  RUN_ID = p_run_id
                    AND    TFM_STATUS = 'STAGED'
                    AND    BATCH_ID IS NOT NULL
                    GROUP BY BATCH_ID
                    ORDER BY BATCH_ID
                ) LOOP
                    l_rq_count := l_rq_count + 1;

                    -- One batch = one requisitioning business unit.
                    IF grp_rec.BU_COUNT > 1 THEN
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'Requisition batch ' || grp_rec.BATCH_ID || ' mixes ' || grp_rec.BU_COUNT ||
                            ' business units -- a batch must use exactly one. Marking FAILED.',
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_obj || ' > ' || C_PROC);
                        mark_batch_failed(grp_rec.BATCH_ID,
                            '[PRE_VALIDATION] Batch ' || grp_rec.BATCH_ID ||
                            ' mixes multiple requisitioning business units; one batch must use exactly one BU.');
                        CONTINUE;
                    END IF;

                    -- Resolve the BU id from its name (no hardcoded ids).
                    BEGIN
                        l_rq_bu_id := DMT_UTIL_PKG.GET_LOOKUP('BU_NAME_TO_BU_ID', grp_rec.REQ_BU_NAME);
                    EXCEPTION WHEN OTHERS THEN
                        l_rq_bu_id := NULL;
                    END;
                    IF l_rq_bu_id IS NULL THEN
                        mark_batch_failed(grp_rec.BATCH_ID,
                            '[PRE_VALIDATION] Requisitioning BU "' || grp_rec.REQ_BU_NAME ||
                            '" for batch ' || grp_rec.BATCH_ID || ' did not resolve to a Fusion BU id.');
                        CONTINUE;
                    END IF;

                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Requisition batch cycle start: BATCH_ID=' || grp_rec.BATCH_ID ||
                        ', BU=' || grp_rec.REQ_BU_NAME,
                        'INFO', C_PKG, l_obj || ' > ' || C_PROC);

                    DMT_REQ_FBDI_GEN_PKG.GENERATE_FBDI(
                        p_run_id      => p_run_id,
                        x_fbdi_zip    => l_rq_zip,
                        x_filename    => l_rq_filename,
                        x_fbdi_csv_id => l_rq_csv_id,
                        p_batch_id    => grp_rec.BATCH_ID);

                    IF l_rq_zip IS NULL OR DBMS_LOB.GETLENGTH(l_rq_zip) = 0 THEN
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'No rows for requisition batch ' || grp_rec.BATCH_ID || '. Skipping.',
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_obj || ' > ' || C_PROC);
                        CONTINUE;
                    END IF;

                    -- RequisitionImportJob, 8 positional args.
                    -- 1=ImportSource, 2=BatchId (this batch), 3=MaxBatchSize,
                    -- 4=RequisitioningBuId (resolved), 5=GroupBy, 6=NextReqNumber,
                    -- 7=InitiateApproval, 8=ErrorLevel.
                    l_rq_param := '#NULL,'
                        || grp_rec.BATCH_ID || ','
                        || '#NULL,'
                        || l_rq_bu_id || ','
                        || 'NONE,'
                        || '#NULL,'
                        || 'NO,'
                        || 'ALL';
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Requisition ParameterList: ' || l_rq_param,
                        'INFO', C_PKG, l_obj || ' > ' || C_PROC);

                    submit_and_reconcile_one(
                        p_fbdi_zip    => l_rq_zip,
                        p_filename    => l_rq_filename,
                        p_fbdi_csv_id => l_rq_csv_id,
                        p_param_list  => l_rq_param,
                        p_group_label => 'Batch: ' || grp_rec.BATCH_ID,
                        p_username    => l_rq_user,
                        p_password    => l_rq_pass,
                        x_load_ess_id   => l_rq_load_id,
                        x_import_ess_id => l_rq_import_id,
                        x_success       => l_rq_ok);

                    IF NOT l_rq_ok THEN
                        mark_batch_failed(grp_rec.BATCH_ID,
                            '[LOAD_ERROR] Loading requisition batch ' || grp_rec.BATCH_ID ||
                            ' to the Fusion interface failed. Check ESS job ' || l_rq_load_id || ' logs.');
                        CONTINUE;
                    END IF;

                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Requisition batch cycle complete: BATCH_ID=' || grp_rec.BATCH_ID,
                        'INFO', C_PKG, l_obj || ' > ' || C_PROC);
                END LOOP;

                IF l_rq_count = 0 THEN
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'No STAGED Requisition rows with a batch id found. Skipping Requisitions.',
                        DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_obj || ' > ' || C_PROC);
                    RETURN FALSE;
                END IF;
            END;

            GOTO grouped_finish;
        END IF;

        -- ============================================================
        -- Items: grouped load by BATCH_ID.
        -- One batch = one FBDI zip (items + bundled categories) =
        -- one Item Import (ItemImportJobDef) ESS run. Both the item TFM
        -- table and the bundled category TFM table carry their own
        -- BATCH_ID column, so each is filtered directly (no join).
        -- ============================================================
        IF p_cemli_code = 'Items' THEN
            DECLARE
                l_it_zip        BLOB;
                l_it_filename   VARCHAR2(200);
                l_it_csv_id     NUMBER;
                l_it_load_id    VARCHAR2(100);
                l_it_import_id  VARCHAR2(100);
                l_it_param      VARCHAR2(500);
                l_it_count      NUMBER := 0;
                l_it_ok         BOOLEAN;
                l_it_user       VARCHAR2(100);
                l_it_pass       VARCHAR2(100);

                -- Fail this batch's GENERATED rows in BOTH bundled TFM tables.
                -- Each has its own BATCH_ID column, so filter directly (no join).
                PROCEDURE mark_batch_failed(p_bid IN VARCHAR2, p_msg IN VARCHAR2) IS
                BEGIN
                    UPDATE DMT_OWNER.DMT_EGP_ITEM_TFM_TBL
                    SET TFM_STATUS='FAILED',
                        ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,p_msg),
                        LAST_UPDATED_DATE=SYSDATE
                    WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED' AND BATCH_ID=TO_NUMBER(p_bid);

                    UPDATE DMT_OWNER.DMT_EGP_ITEM_CAT_TFM_TBL
                    SET TFM_STATUS='FAILED',
                        ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,p_msg),
                        LAST_UPDATED_DATE=SYSDATE
                    WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED' AND BATCH_ID=TO_NUMBER(p_bid);
                    COMMIT;
                END mark_batch_failed;
            BEGIN
                -- Items submits under its own configured ESS user (SCM_IMPL per the
                -- ItemImportJobDef interface-options row) -- same credential the
                -- single-submit path used to load online.
                DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS('Items', l_it_user, l_it_pass);

                -- A batch may have item rows, category rows, or both -- union both
                -- TFM tables for the complete set of distinct batch ids.
                FOR grp_rec IN (
                    SELECT TO_CHAR(BATCH_ID) AS BATCH_ID
                    FROM   DMT_OWNER.DMT_EGP_ITEM_TFM_TBL
                    WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED' AND BATCH_ID IS NOT NULL
                    UNION
                    SELECT TO_CHAR(BATCH_ID)
                    FROM   DMT_OWNER.DMT_EGP_ITEM_CAT_TFM_TBL
                    WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED' AND BATCH_ID IS NOT NULL
                    ORDER BY 1
                ) LOOP
                    l_it_count := l_it_count + 1;

                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Item batch cycle start: BATCH_ID=' || grp_rec.BATCH_ID,
                        'INFO', C_PKG, l_obj || ' > ' || C_PROC);

                    DMT_EGP_ITEM_FBDI_GEN_PKG.GENERATE_FBDI(
                        p_run_id      => p_run_id,
                        x_fbdi_zip    => l_it_zip,
                        x_filename    => l_it_filename,
                        x_fbdi_csv_id => l_it_csv_id,
                        p_batch_id    => grp_rec.BATCH_ID);

                    IF l_it_zip IS NULL OR DBMS_LOB.GETLENGTH(l_it_zip) = 0 THEN
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'No rows for item batch ' || grp_rec.BATCH_ID || '. Skipping.',
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_obj || ' > ' || C_PROC);
                        CONTINUE;
                    END IF;

                    -- ItemImportJobDef, 7 positional args (MCCS RICE_009 pattern).
                    -- 1=BatchID (this batch), 2=Organization(null), 3=ProcessOnly=CREATE,
                    -- 4=ProcessAllOrgs(null), 5=DeleteProcessedRows(null),
                    -- 6=ReprocessError=N, 7=ProcessSequentially=Y.
                    l_it_param := grp_rec.BATCH_ID || ',null,CREATE,null,null,N,Y';
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Item ParameterList: ' || l_it_param,
                        'INFO', C_PKG, l_obj || ' > ' || C_PROC);

                    submit_and_reconcile_one(
                        p_fbdi_zip    => l_it_zip,
                        p_filename    => l_it_filename,
                        p_fbdi_csv_id => l_it_csv_id,
                        p_param_list  => l_it_param,
                        p_group_label => 'Batch: ' || grp_rec.BATCH_ID,
                        p_username    => l_it_user,
                        p_password    => l_it_pass,
                        x_load_ess_id   => l_it_load_id,
                        x_import_ess_id => l_it_import_id,
                        x_success       => l_it_ok);

                    IF NOT l_it_ok THEN
                        mark_batch_failed(grp_rec.BATCH_ID,
                            '[LOAD_ERROR] Loading item batch ' || grp_rec.BATCH_ID ||
                            ' to the Fusion interface failed. Check ESS job ' || l_it_load_id || ' logs.');
                        CONTINUE;
                    END IF;

                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Item batch cycle complete: BATCH_ID=' || grp_rec.BATCH_ID,
                        'INFO', C_PKG, l_obj || ' > ' || C_PROC);
                END LOOP;

                IF l_it_count = 0 THEN
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'No STAGED Item rows with a batch id found. Skipping Items.',
                        DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_obj || ' > ' || C_PROC);
                    RETURN FALSE;
                END IF;
            END;

            GOTO grouped_finish;
        END IF;

        -- ============================================================
        -- BlanketPOs: grouped load by PRC_BU_NAME (same as standard POs)
        -- ============================================================
        IF p_cemli_code = 'BlanketPOs' THEN
            DECLARE
                l_bu_zip       BLOB;
                l_bu_filename  VARCHAR2(200);
                l_bu_csv_id    NUMBER;
                l_bu_load_id   VARCHAR2(100);
                l_bu_import_id VARCHAR2(100);
                l_bu_param     VARCHAR2(500);
                l_bu_id        VARCHAR2(30);
                l_buyer_id     VARCHAR2(30);
                l_bu_count     NUMBER := 0;
                l_any_staged   NUMBER := 0;
                l_bu_ok        BOOLEAN;
                l_po_user      VARCHAR2(100);
                l_po_pass      VARCHAR2(100);
            BEGIN
                DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS('BlanketPOs', l_po_user, l_po_pass);
                FOR bu_rec IN (
                    SELECT DISTINCT PRC_BU_NAME
                    FROM   DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL
                    WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED'
                    AND    STYLE_DISPLAY_NAME = 'Blanket Purchase Agreement'
                    ORDER BY PRC_BU_NAME
                ) LOOP
                    l_bu_count := l_bu_count + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'BlanketPO BU cycle start: ' || bu_rec.PRC_BU_NAME,
                        'INFO', C_PKG, l_obj || ' > ' || C_PROC);

                    DMT_BLANKET_PO_FBDI_GEN_PKG.GENERATE_FBDI(
                        p_run_id => p_run_id, p_prc_bu_name => bu_rec.PRC_BU_NAME,
                        x_fbdi_zip => l_bu_zip, x_filename => l_bu_filename, x_fbdi_csv_id => l_bu_csv_id);

                    IF l_bu_zip IS NULL OR DBMS_LOB.GETLENGTH(l_bu_zip) = 0 THEN
                        DMT_UTIL_PKG.LOG(p_run_id, 'No blanket rows for BU ' || bu_rec.PRC_BU_NAME || '. Skipping.',
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_obj || ' > ' || C_PROC);
                        CONTINUE;
                    END IF;

                    l_bu_id := DMT_UTIL_PKG.GET_LOOKUP('BU_NAME_TO_BU_ID', bu_rec.PRC_BU_NAME);
                    l_buyer_id := DMT_UTIL_PKG.GET_CONFIG('PO_DEFAULT_BUYER_ID');

                    -- ImportBPAJob: 8 args
                    l_bu_param := l_bu_id || ',' || l_buyer_id || ',N,SUBMIT,,,N,' || l_bu_id || '_' || TO_CHAR(p_run_id);

                    submit_and_reconcile_one(
                        p_fbdi_zip => l_bu_zip, p_filename => l_bu_filename, p_fbdi_csv_id => l_bu_csv_id,
                        p_param_list => l_bu_param, p_group_label => 'BU: ' || bu_rec.PRC_BU_NAME,
                        p_username => l_po_user, p_password => l_po_pass,
                        x_load_ess_id => l_bu_load_id, x_import_ess_id => l_bu_import_id, x_success => l_bu_ok);

                    IF NOT l_bu_ok THEN
                        UPDATE DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL
                        SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                            '[LOAD_ERROR] Loading data to the Fusion interface failed. Check ESS job ' || l_bu_load_id || ' logs for details.'),
                            LAST_UPDATED_DATE=SYSDATE
                        WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED' AND PRC_BU_NAME=bu_rec.PRC_BU_NAME
                        AND STYLE_DISPLAY_NAME='Blanket Purchase Agreement';
                        COMMIT;
                        CONTINUE;
                    END IF;
                END LOOP;

                IF l_bu_count = 0 THEN
                    SELECT COUNT(*) INTO l_any_staged FROM DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL
                    WHERE RUN_ID=p_run_id AND TFM_STATUS='STAGED'
                    AND STYLE_DISPLAY_NAME='Blanket Purchase Agreement' AND ROWNUM=1;
                    IF l_any_staged = 0 THEN
                        DMT_UTIL_PKG.LOG(p_run_id, 'No STAGED blanket PO headers. Skipping.',
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_obj || ' > ' || C_PROC);
                        RETURN FALSE;
                    END IF;
                END IF;
            END;
            GOTO grouped_finish;
        END IF;

        -- ============================================================
        -- Contracts: grouped load by PRC_BU_NAME (headers only)
        -- ============================================================
        IF p_cemli_code = 'Contracts' THEN
            DECLARE
                l_bu_zip       BLOB;
                l_bu_filename  VARCHAR2(200);
                l_bu_csv_id    NUMBER;
                l_bu_load_id   VARCHAR2(100);
                l_bu_import_id VARCHAR2(100);
                l_bu_param     VARCHAR2(500);
                l_bu_id        VARCHAR2(30);
                l_buyer_id     VARCHAR2(30);
                l_bu_count     NUMBER := 0;
                l_any_staged   NUMBER := 0;
                l_bu_ok        BOOLEAN;
                l_po_user      VARCHAR2(100);
                l_po_pass      VARCHAR2(100);
            BEGIN
                DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS('Contracts', l_po_user, l_po_pass);
                FOR bu_rec IN (
                    SELECT DISTINCT PRC_BU_NAME
                    FROM   DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL
                    WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED'
                    AND    STYLE_DISPLAY_NAME = 'Contract Purchase Agreement'
                    ORDER BY PRC_BU_NAME
                ) LOOP
                    l_bu_count := l_bu_count + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Contract BU cycle start: ' || bu_rec.PRC_BU_NAME,
                        'INFO', C_PKG, l_obj || ' > ' || C_PROC);

                    DMT_CONTRACT_FBDI_GEN_PKG.GENERATE_FBDI(
                        p_run_id => p_run_id, p_prc_bu_name => bu_rec.PRC_BU_NAME,
                        x_fbdi_zip => l_bu_zip, x_filename => l_bu_filename, x_fbdi_csv_id => l_bu_csv_id);

                    IF l_bu_zip IS NULL OR DBMS_LOB.GETLENGTH(l_bu_zip) = 0 THEN
                        DMT_UTIL_PKG.LOG(p_run_id, 'No contract rows for BU ' || bu_rec.PRC_BU_NAME || '. Skipping.',
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_obj || ' > ' || C_PROC);
                        CONTINUE;
                    END IF;

                    l_bu_id := DMT_UTIL_PKG.GET_LOOKUP('BU_NAME_TO_BU_ID', bu_rec.PRC_BU_NAME);
                    l_buyer_id := DMT_UTIL_PKG.GET_CONFIG('PO_DEFAULT_BUYER_ID');

                    -- ImportCPAJob: 7 args
                    l_bu_param := l_bu_id || ',' || l_buyer_id || ',SUBMIT,,,N,' || l_bu_id || '_' || TO_CHAR(p_run_id);

                    submit_and_reconcile_one(
                        p_fbdi_zip => l_bu_zip, p_filename => l_bu_filename, p_fbdi_csv_id => l_bu_csv_id,
                        p_param_list => l_bu_param, p_group_label => 'BU: ' || bu_rec.PRC_BU_NAME,
                        p_username => l_po_user, p_password => l_po_pass,
                        x_load_ess_id => l_bu_load_id, x_import_ess_id => l_bu_import_id, x_success => l_bu_ok);

                    IF NOT l_bu_ok THEN
                        UPDATE DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL
                        SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                            '[LOAD_ERROR] Loading data to the Fusion interface failed. Check ESS job ' || l_bu_load_id || ' logs for details.'),
                            LAST_UPDATED_DATE=SYSDATE
                        WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED' AND PRC_BU_NAME=bu_rec.PRC_BU_NAME
                        AND STYLE_DISPLAY_NAME='Contract Purchase Agreement';
                        COMMIT;
                        CONTINUE;
                    END IF;
                END LOOP;

                IF l_bu_count = 0 THEN
                    SELECT COUNT(*) INTO l_any_staged FROM DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL
                    WHERE RUN_ID=p_run_id AND TFM_STATUS='STAGED'
                    AND STYLE_DISPLAY_NAME='Contract Purchase Agreement' AND ROWNUM=1;
                    IF l_any_staged = 0 THEN
                        DMT_UTIL_PKG.LOG(p_run_id, 'No STAGED contract headers. Skipping.',
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_obj || ' > ' || C_PROC);
                        RETURN FALSE;
                    END IF;
                END IF;
            END;
            GOTO grouped_finish;
        END IF;

        -- ============================================================
        -- APInvoices: grouped load by OPERATING_UNIT
        -- Each OU gets its own FBDI zip, loadAndImportData, and BIP reconciliation.
        -- ============================================================
        IF p_cemli_code = 'APInvoices' THEN
            DECLARE
                l_ou_zip       BLOB;
                l_ou_filename  VARCHAR2(200);
                l_ou_csv_id    NUMBER;
                l_ou_load_id   VARCHAR2(100);
                l_ou_import_id VARCHAR2(100);
                l_ou_param     VARCHAR2(500);
                l_ou_count     NUMBER := 0;
                l_any_staged   NUMBER := 0;
                l_ou_ok        BOOLEAN;
            BEGIN
                FOR ou_rec IN (
                    SELECT DISTINCT OPERATING_UNIT
                    FROM   DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL
                    WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED'
                    ORDER BY OPERATING_UNIT
                ) LOOP
                    l_ou_count := l_ou_count + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'AP OU cycle start: ' || ou_rec.OPERATING_UNIT,
                        'INFO', C_PKG, l_obj || ' > ' || C_PROC);

                    DMT_AP_FBDI_GEN_PKG.GENERATE_FBDI(
                        p_run_id => p_run_id, p_operating_unit => ou_rec.OPERATING_UNIT,
                        x_fbdi_zip => l_ou_zip, x_filename => l_ou_filename, x_fbdi_csv_id => l_ou_csv_id);

                    IF l_ou_zip IS NULL OR DBMS_LOB.GETLENGTH(l_ou_zip) = 0 THEN
                        DMT_UTIL_PKG.LOG(p_run_id, 'No rows for OU ' || ou_rec.OPERATING_UNIT || '. Skipping.',
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_obj || ' > ' || C_PROC);
                        CONTINUE;
                    END IF;

                    -- AP APXIIMPT 14-arg ParameterList
                    DECLARE
                        l_ap_bu_id  VARCHAR2(50);
                        l_ap_ledger VARCHAR2(50);
                        l_ap_source VARCHAR2(100);
                    BEGIN
                        -- BU id + its primary ledger via the common lookup. Every active BU
                        -- has a BU_NAME_TO_PRIMARY_LEDGER_ID row; it resolves to NULL when the
                        -- BU has no primary ledger, so the NVL(...,'#NULL') below still applies
                        -- (GET_LOOKUP raises only when the BU itself is unknown).
                        l_ap_bu_id  := DMT_UTIL_PKG.GET_LOOKUP('BU_NAME_TO_BU_ID', ou_rec.OPERATING_UNIT);
                        l_ap_ledger := DMT_UTIL_PKG.GET_LOOKUP('BU_NAME_TO_PRIMARY_LEDGER_ID', ou_rec.OPERATING_UNIT);
                        SELECT SOURCE INTO l_ap_source FROM DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL
                        WHERE RUN_ID=p_run_id AND OPERATING_UNIT=ou_rec.OPERATING_UNIT AND TFM_STATUS='GENERATED' AND ROWNUM=1;
                        l_ou_param := ',' || l_ap_bu_id || ',N,' || TO_CHAR(SYSDATE,'YYYY-MM-DD') ||
                            ',#NULL,#NULL,1000,' || l_ap_source || ',' || TO_CHAR(p_run_id) ||
                            ',N,Y,' || NVL(l_ap_ledger,'#NULL') || ',#NULL,1';
                    END;

                    submit_and_reconcile_one(
                        p_fbdi_zip => l_ou_zip, p_filename => l_ou_filename, p_fbdi_csv_id => l_ou_csv_id,
                        p_param_list => l_ou_param, p_group_label => 'OU: ' || ou_rec.OPERATING_UNIT,
                        x_load_ess_id => l_ou_load_id, x_import_ess_id => l_ou_import_id, x_success => l_ou_ok);

                    IF NOT l_ou_ok THEN
                        DECLARE
                            l_err VARCHAR2(500) := '[LOAD_ERROR] Loading data to the Fusion interface failed. Check ESS job ' || l_ou_load_id || ' logs for details.';
                        BEGIN
                            UPDATE DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL
                            SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err)
                            WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED' AND OPERATING_UNIT=ou_rec.OPERATING_UNIT;
                            UPDATE DMT_OWNER.DMT_AP_INVOICE_LINES_INT_TFM_TBL
                            SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err)
                            WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED'
                            AND INVOICE_ID IN (SELECT INVOICE_ID FROM DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL WHERE RUN_ID=p_run_id AND OPERATING_UNIT=ou_rec.OPERATING_UNIT);
                            COMMIT;
                        END;
                        CONTINUE;
                    END IF;

                    -- Check for rows still at GENERATED after BIP
                    DECLARE l_gen_count NUMBER;
                    BEGIN
                        SELECT COUNT(*) INTO l_gen_count FROM DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL
                        WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED' AND OPERATING_UNIT=ou_rec.OPERATING_UNIT;
                        IF l_gen_count > 0 THEN
                            DMT_UTIL_PKG.LOG(p_run_id,
                                'WARNING: ' || l_gen_count || ' AP invoice rows still at GENERATED after BIP reconciliation (OU: ' || ou_rec.OPERATING_UNIT || '). Require manual investigation.',
                                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_obj || ' > ' || C_PROC);
                        END IF;
                    END;
                END LOOP;

                IF l_ou_count = 0 THEN
                    SELECT COUNT(*) INTO l_any_staged FROM DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL
                    WHERE RUN_ID=p_run_id AND TFM_STATUS='STAGED' AND ROWNUM=1;
                    IF l_any_staged = 0 THEN
                        DMT_UTIL_PKG.LOG(p_run_id, 'No STAGED AP invoice headers found. Skipping APInvoices.',
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_obj || ' > ' || C_PROC);
                        RETURN FALSE;
                    END IF;
                END IF;
            END;

            -- After all groups: check failed rows + update master totals
            GOTO grouped_finish;
        END IF;

        -- ============================================================
        -- 1099Invoices: grouped load by OPERATING_UNIT (shares AP tables)
        -- ============================================================
        IF p_cemli_code = '1099Invoices' THEN
            DECLARE
                l_ou_zip       BLOB;
                l_ou_filename  VARCHAR2(200);
                l_ou_csv_id    NUMBER;
                l_ou_load_id   VARCHAR2(100);
                l_ou_import_id VARCHAR2(100);
                l_ou_param     VARCHAR2(500);
                l_ou_count     NUMBER := 0;
                l_any_staged   NUMBER := 0;
                l_ou_ok        BOOLEAN;
            BEGIN
                FOR ou_rec IN (
                    SELECT DISTINCT OPERATING_UNIT
                    FROM   DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL
                    WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED'
                    AND    INVOICE_TYPE_LOOKUP_CODE LIKE '%1099%'
                    ORDER BY OPERATING_UNIT
                ) LOOP
                    l_ou_count := l_ou_count + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        '1099 OU cycle start: ' || ou_rec.OPERATING_UNIT,
                        'INFO', C_PKG, l_obj || ' > ' || C_PROC);

                    DMT_1099_FBDI_GEN_PKG.GENERATE_FBDI(
                        p_run_id => p_run_id, p_operating_unit => ou_rec.OPERATING_UNIT,
                        x_fbdi_zip => l_ou_zip, x_filename => l_ou_filename, x_fbdi_csv_id => l_ou_csv_id);

                    IF l_ou_zip IS NULL OR DBMS_LOB.GETLENGTH(l_ou_zip) = 0 THEN
                        DMT_UTIL_PKG.LOG(p_run_id, 'No 1099 rows for OU ' || ou_rec.OPERATING_UNIT || '. Skipping.',
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_obj || ' > ' || C_PROC);
                        CONTINUE;
                    END IF;

                    -- 1099 shares AP APXIIMPT — same 14-arg ParameterList
                    DECLARE
                        l_1099_bu_id  VARCHAR2(50);
                        l_1099_ledger VARCHAR2(50);
                        l_1099_source VARCHAR2(100);
                    BEGIN
                        -- See the APInvoices note above: the primary-ledger lookup resolves
                        -- to NULL for a BU with no primary ledger, so NVL(...,'#NULL') applies.
                        l_1099_bu_id  := DMT_UTIL_PKG.GET_LOOKUP('BU_NAME_TO_BU_ID', ou_rec.OPERATING_UNIT);
                        l_1099_ledger := DMT_UTIL_PKG.GET_LOOKUP('BU_NAME_TO_PRIMARY_LEDGER_ID', ou_rec.OPERATING_UNIT);
                        SELECT SOURCE INTO l_1099_source FROM DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL
                        WHERE RUN_ID=p_run_id AND OPERATING_UNIT=ou_rec.OPERATING_UNIT
                        AND TFM_STATUS='GENERATED' AND INVOICE_TYPE_LOOKUP_CODE LIKE '%1099%' AND ROWNUM=1;
                        l_ou_param := ',' || l_1099_bu_id || ',N,' || TO_CHAR(SYSDATE,'YYYY-MM-DD') ||
                            ',#NULL,#NULL,1000,' || l_1099_source || ',' || TO_CHAR(p_run_id) ||
                            ',N,Y,' || NVL(l_1099_ledger,'#NULL') || ',#NULL,1';
                    END;

                    submit_and_reconcile_one(
                        p_fbdi_zip => l_ou_zip, p_filename => l_ou_filename, p_fbdi_csv_id => l_ou_csv_id,
                        p_param_list => l_ou_param, p_group_label => 'OU: ' || ou_rec.OPERATING_UNIT,
                        x_load_ess_id => l_ou_load_id, x_import_ess_id => l_ou_import_id, x_success => l_ou_ok);

                    IF NOT l_ou_ok THEN
                        DECLARE
                            l_err VARCHAR2(500) := '[LOAD_ERROR] Loading data to the Fusion interface failed. Check ESS job ' || l_ou_load_id || ' logs for details.';
                        BEGIN
                            UPDATE DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL
                            SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err)
                            WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED' AND OPERATING_UNIT=ou_rec.OPERATING_UNIT
                            AND INVOICE_TYPE_LOOKUP_CODE LIKE '%1099%';
                            UPDATE DMT_OWNER.DMT_AP_INVOICE_LINES_INT_TFM_TBL
                            SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err)
                            WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED'
                            AND INVOICE_ID IN (SELECT INVOICE_ID FROM DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL WHERE RUN_ID=p_run_id AND OPERATING_UNIT=ou_rec.OPERATING_UNIT AND INVOICE_TYPE_LOOKUP_CODE LIKE '%1099%');
                            COMMIT;
                        END;
                        CONTINUE;
                    END IF;
                END LOOP;

                IF l_ou_count = 0 THEN
                    SELECT COUNT(*) INTO l_any_staged FROM DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL
                    WHERE RUN_ID=p_run_id AND TFM_STATUS='STAGED'
                    AND INVOICE_TYPE_LOOKUP_CODE LIKE '%1099%' AND ROWNUM=1;
                    IF l_any_staged = 0 THEN
                        DMT_UTIL_PKG.LOG(p_run_id, 'No STAGED 1099 invoice headers. Skipping.',
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_obj || ' > ' || C_PROC);
                        RETURN FALSE;
                    END IF;
                END IF;
            END;
            GOTO grouped_finish;
        END IF;

        -- ============================================================
        -- GLBudgetBalances: load once, then run "Validate and Load Budgets"
        -- STANDALONE once per distinct Run Name (Column A). The chained import
        -- that loadAndImportData triggers gets no run name and is a throwaway;
        -- the real cube load happens in the per-run-name ValidateAndLoadBudgets
        -- submissions below. Reconciliation is cell-grain against
        -- GL_BUDGET_BALANCES scoped to a run-start window (budgets carry no
        -- source-line identity). See DMT_GL_BUDGET_RESULTS_PKG.
        -- ============================================================
        IF p_cemli_code = 'GLBudgetBalances' THEN
            DECLARE
                l_gb_zip        BLOB;
                l_gb_filename   VARCHAR2(200);
                l_gb_csv_id     NUMBER;
                l_gb_load_id    VARCHAR2(100);
                l_gb_import_id  VARCHAR2(100);
                l_gb_status     VARCHAR2(50);
                l_gb_run_start  TIMESTAMP := SYSTIMESTAMP;
                l_gb_ledger     NUMBER;
                l_gb_ledgers    NUMBER := 0;
                l_gb_rows       NUMBER := 0;
                l_gb_runs       NUMBER := 0;
            BEGIN
                -- Generate one FBDI zip for all STAGED budget rows this run.
                DMT_GL_BUDGET_FBDI_GEN_PKG.GENERATE_FBDI(
                    p_run_id       => p_run_id,
                    x_fbdi_zip     => l_gb_zip,
                    x_filename     => l_gb_filename,
                    x_fbdi_csv_id  => l_gb_csv_id);

                SELECT COUNT(*) INTO l_gb_rows
                FROM   DMT_OWNER.DMT_GL_BUDGET_INT_TFM_TBL
                WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';

                IF l_gb_zip IS NULL OR DBMS_LOB.GETLENGTH(l_gb_zip) = 0 OR l_gb_rows = 0 THEN
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'No STAGED GL budget rows found. Skipping GLBudgetBalances.',
                        DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_obj || ' > ' || C_PROC);
                    RETURN FALSE;
                END IF;

                -- Step 1: Load Interface File for Import (loadAndImportData).
                -- Loads the CSV into GL_BUDGET_INTERFACE. Its chained
                -- ValidateAndLoadBudgets (no run name) is ignored.
                l_gb_load_id := SUBMIT_LOAD(
                    p_run_id            => p_run_id,
                    p_fbdi_zip          => l_gb_zip,
                    p_filename          => l_gb_filename,
                    p_job_name          => l_job_name,
                    p_interface_details => l_interface_details,
                    p_doc_account       => l_ucm_account,
                    p_parameter_list    => l_param_list,
                    p_log_context       => l_obj);
                DBMS_LOB.FREETEMPORARY(l_gb_zip);

                UPDATE DMT_OWNER.DMT_FBDI_ZIP_TBL SET PARAMETER_LIST = l_param_list
                WHERE  FBDI_ZIP_ID = (SELECT FBDI_ZIP_ID FROM DMT_OWNER.DMT_FBDI_CSV_TBL
                                      WHERE FBDI_CSV_ID = l_gb_csv_id);
                COMMIT;

                POLL_ESS_JOB(p_run_id, l_gb_load_id, 1800, FALSE, l_obj, p_cemli_code, l_gb_status);
                IF l_gb_status NOT IN (C_STATUS_SUCCEEDED, C_STATUS_WARNING) THEN
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'GL Budget Load ESS ' || l_gb_load_id || ' returned ' || l_gb_status ||
                        '. Marking GENERATED rows FAILED.',
                        DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_obj || ' > ' || C_PROC);
                    UPDATE DMT_OWNER.DMT_GL_BUDGET_INT_TFM_TBL
                    SET    TFM_STATUS = 'FAILED',
                           ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                               '[LOAD_ERROR] Load to GL_BUDGET_INTERFACE failed. Check ESS job ' || l_gb_load_id || '.'),
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
                    COMMIT;
                    RETURN FALSE;
                END IF;

                -- Step 2: submit Validate and Load Budgets standalone per Run Name.
                FOR rn IN (
                    SELECT DISTINCT RUN_NAME
                    FROM   DMT_OWNER.DMT_GL_BUDGET_INT_TFM_TBL
                    WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED'
                    AND    RUN_NAME IS NOT NULL
                    ORDER BY RUN_NAME
                ) LOOP
                    l_gb_runs := l_gb_runs + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Submitting ValidateAndLoadBudgets for Run Name: ' || rn.RUN_NAME,
                        'INFO', C_PKG, l_obj || ' > ' || C_PROC);
                    l_gb_import_id := SUBMIT_IMPORT_JOB(
                        p_run_id     => p_run_id,
                        p_job_name   => l_job_name,
                        p_param_list => rn.RUN_NAME);   -- single arg: the Run Name
                    POLL_ESS_JOB(p_run_id, l_gb_import_id, 1800, FALSE, l_obj, p_cemli_code, l_gb_status);
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'ValidateAndLoadBudgets ' || l_gb_import_id || ' for ' || rn.RUN_NAME ||
                        ' -> ' || l_gb_status, 'INFO', C_PKG, l_obj || ' > ' || C_PROC);
                END LOOP;

                -- Scope reconciliation to a single ledger when the run uses one.
                SELECT COUNT(DISTINCT LEDGER_ID), MAX(LEDGER_ID)
                INTO   l_gb_ledgers, l_gb_ledger
                FROM   DMT_OWNER.DMT_GL_BUDGET_INT_TFM_TBL
                WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED' AND LEDGER_ID IS NOT NULL;
                IF l_gb_ledgers <> 1 THEN l_gb_ledger := NULL; END IF;

                -- Step 3: reconcile cell-grain against GL_BUDGET_BALANCES + interface errors.
                DMT_GL_BUDGET_RESULTS_PKG.RECONCILE_BATCH(
                    p_run_id        => p_run_id,
                    p_load_ess_id   => TO_NUMBER(l_gb_load_id),
                    p_import_ess_id => TO_NUMBER(l_gb_import_id),
                    p_run_start     => l_gb_run_start,
                    p_ledger_id     => l_gb_ledger);
            END;
            GOTO grouped_finish;
        END IF;

        -- ============================================================
        -- GLBalances: grouped load by LEDGER_NAME
        -- Each distinct ledger gets its own FBDI zip,
        -- JournalImportLauncher call, and BIP reconciliation.
        -- ParameterList: DAS_ID,Source,LedgerID,GroupID,N,N,N
        -- ============================================================
        IF p_cemli_code = 'GLBalances' THEN
            DECLARE
                l_gl_zip       BLOB;
                l_gl_filename  VARCHAR2(200);
                l_gl_csv_id    NUMBER;
                l_gl_load_id   VARCHAR2(100);
                l_gl_import_id VARCHAR2(100);
                l_gl_param     VARCHAR2(500);
                l_gl_ledger_id VARCHAR2(50);
                l_gl_das_id    VARCHAR2(50);
                l_gl_source    VARCHAR2(240);
                l_gl_count     NUMBER := 0;
                l_gl_ok        BOOLEAN;
            BEGIN
                FOR led_rec IN (
                    SELECT DISTINCT LEDGER_NAME
                    FROM   DMT_OWNER.DMT_GL_INTERFACE_TFM_TBL
                    WHERE  RUN_ID = p_run_id
                    AND    TFM_STATUS = 'STAGED'
                    AND    LEDGER_NAME IS NOT NULL
                    ORDER BY LEDGER_NAME
                ) LOOP
                    l_gl_count := l_gl_count + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'GL ledger cycle start: ' || led_rec.LEDGER_NAME,
                        'INFO', C_PKG, l_obj || ' > ' || C_PROC);

                    -- Generate FBDI for this ledger only
                    DMT_GL_FBDI_GEN_PKG.GENERATE_FBDI(
                        p_run_id => p_run_id,
                        x_fbdi_zip       => l_gl_zip,
                        x_filename       => l_gl_filename,
                        x_fbdi_csv_id    => l_gl_csv_id,
                        p_ledger_name    => led_rec.LEDGER_NAME);

                    IF l_gl_zip IS NULL OR DBMS_LOB.GETLENGTH(l_gl_zip) = 0 THEN
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'No GL rows for ledger ' || led_rec.LEDGER_NAME || '. Skipping.',
                            DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_obj || ' > ' || C_PROC);
                        CONTINUE;
                    END IF;

                    -- Ledger id + data-access-set id via the one common lookup
                    -- accessor. The canonical LEDGER_NAME_TO_LEDGER_ID return is
                    -- ledger_id~access_set_id (the reserved ~ separator);
                    -- GET_LOOKUP raises -20040 with a clear halt if unresolvable.
                    DECLARE
                        l_ledger_lkp VARCHAR2(500);
                    BEGIN
                        l_ledger_lkp   := DMT_UTIL_PKG.GET_LOOKUP('LEDGER_NAME_TO_LEDGER_ID', led_rec.LEDGER_NAME);
                        l_gl_ledger_id := SUBSTR(l_ledger_lkp, 1, INSTR(l_ledger_lkp, '~') - 1);
                        l_gl_das_id    := SUBSTR(l_ledger_lkp, INSTR(l_ledger_lkp, '~') + 1);
                    END;

                    -- Get source from TFM data — not hardcoded 'Spreadsheet'
                    BEGIN
                        SELECT USER_JE_SOURCE_NAME INTO l_gl_source
                        FROM   DMT_OWNER.DMT_GL_INTERFACE_TFM_TBL
                        WHERE  RUN_ID = p_run_id
                        AND    LEDGER_NAME = led_rec.LEDGER_NAME
                        AND    TFM_STATUS = 'GENERATED'
                        AND    ROWNUM = 1;
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            l_gl_source := 'Spreadsheet';  -- fallback
                    END;

                    -- JournalImportLauncher: 7 args
                    -- DAS_ID, Source, LedgerID, GroupID, N, N, N
                    l_gl_param := NVL(l_gl_das_id, '#NULL') || ',' ||
                                  l_gl_source || ',' ||
                                  l_gl_ledger_id || ',' ||
                                  TO_CHAR(p_run_id) || ',N,N,N';

                    DMT_UTIL_PKG.LOG(p_run_id,
                        'GL ParameterList for ' || led_rec.LEDGER_NAME || ': ' || l_gl_param,
                        'INFO', C_PKG, l_obj || ' > ' || C_PROC);

                    submit_and_reconcile_one(
                        p_fbdi_zip    => l_gl_zip,
                        p_filename    => l_gl_filename,
                        p_fbdi_csv_id => l_gl_csv_id,
                        p_param_list  => l_gl_param,
                        p_group_label => 'Ledger: ' || led_rec.LEDGER_NAME,
                        x_load_ess_id   => l_gl_load_id,
                        x_import_ess_id => l_gl_import_id,
                        x_success       => l_gl_ok);

                    IF NOT l_gl_ok THEN
                        UPDATE DMT_OWNER.DMT_GL_INTERFACE_TFM_TBL
                        SET    TFM_STATUS = 'FAILED',
                               ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                   '[LOAD_ERROR] Loading data to the Fusion interface failed. Check ESS job ' || l_gl_load_id || ' logs for details.'),
                               LAST_UPDATED_DATE = SYSDATE
                        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED'
                        AND    LEDGER_NAME = led_rec.LEDGER_NAME;
                        COMMIT;
                        CONTINUE;
                    END IF;

                    DMT_UTIL_PKG.LOG(p_run_id,
                        'GL ledger cycle complete: ' || led_rec.LEDGER_NAME,
                        'INFO', C_PKG, l_obj || ' > ' || C_PROC);
                END LOOP;

                IF l_gl_count = 0 THEN
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'No STAGED GL balance rows found. Skipping GLBalances.',
                        DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_obj || ' > ' || C_PROC);
                    RETURN FALSE;
                END IF;
            END;
            GOTO grouped_finish;
        END IF;

        -- ============================================================
        -- Non-grouped CEMLIs: single-load flow
        -- ============================================================

        -- Step 2: Generate FBDI zip
        IF    p_cemli_code = 'Suppliers' THEN
            DMT_POZ_SUP_FBDI_GEN_PKG.GENERATE_FBDI(p_run_id, l_zip, l_filename);
        ELSIF p_cemli_code = 'SupplierAddresses' THEN
            DMT_POZ_SUP_ADDR_FBDI_GEN_PKG.GENERATE_FBDI(p_run_id, l_zip, l_filename);
        ELSIF p_cemli_code = 'SupplierSites' THEN
            DMT_POZ_SUP_SITE_FBDI_GEN_PKG.GENERATE_FBDI(p_run_id, l_zip, l_filename);
        ELSIF p_cemli_code = 'SupplierSiteAssignments' THEN
            DMT_POZ_SUP_SITE_ASSN_FBDI_GEN_PKG.GENERATE_FBDI(p_run_id, l_zip, l_filename);
        ELSIF p_cemli_code = 'SupplierContacts' THEN
            DMT_POZ_SUP_CONT_FBDI_GEN_PKG.GENERATE_FBDI(p_run_id, l_zip, l_filename);
        ELSIF p_cemli_code = 'Projects' THEN
            DECLARE l_csv_id NUMBER;
            BEGIN
                DMT_PROJECT_FBDI_GEN_PKG.GENERATE_FBDI(p_run_id, l_zip, l_filename, l_csv_id);
            END;
        ELSIF p_cemli_code = 'BillingEvents' THEN
            DECLARE l_csv_id NUMBER;
            BEGIN
                DMT_BILLING_EVENT_FBDI_GEN_PKG.GENERATE_FBDI(p_run_id, l_zip, l_filename, l_csv_id);
            END;
        ELSIF p_cemli_code = 'Expenditures' THEN
            DECLARE l_csv_id NUMBER;
            BEGIN
                DMT_EXPENDITURE_FBDI_GEN_PKG.GENERATE_FBDI(p_run_id, l_zip, l_filename, l_csv_id);
            END;
        ELSIF p_cemli_code = 'Grants' THEN
            DECLARE l_csv_id NUMBER;
            BEGIN
                DMT_GRANTS_FBDI_GEN_PKG.GENERATE_FBDI(p_run_id, l_zip, l_filename, l_csv_id);
            END;
        -- Items: handled in grouped loop above.
        ELSIF p_cemli_code = 'ItemCategories' THEN
            DECLARE l_csv_id NUMBER;
            BEGIN
                DMT_EGP_ITEM_CAT_FBDI_GEN_PKG.GENERATE_FBDI(p_run_id, l_zip, l_filename, l_csv_id);
            END;
        ELSIF p_cemli_code = 'MiscReceipts' THEN
            DECLARE l_csv_id NUMBER;
            BEGIN
                DMT_MISC_RECEIPT_FBDI_GEN_PKG.GENERATE_FBDI(p_run_id, l_zip, l_filename, l_csv_id);
            END;
        -- Requisitions: handled in grouped loop above.
        -- GLBalances: handled in grouped loop above.
        ELSIF p_cemli_code = 'GLBudgetBalances' THEN
            DECLARE l_csv_id NUMBER;
            BEGIN
                DMT_GL_BUDGET_FBDI_GEN_PKG.GENERATE_FBDI(p_run_id, l_zip, l_filename, l_csv_id);
            END;
        ELSIF p_cemli_code = 'PlanningBudgets' THEN
            DECLARE l_csv_id NUMBER;
            BEGIN
                DMT_PLAN_BUDGET_FBDI_GEN_PKG.GENERATE_FBDI(p_run_id, l_zip, l_filename, l_csv_id);
            END;
        ELSIF p_cemli_code = 'ProjectBudgets' THEN
            DECLARE l_csv_id NUMBER;
            BEGIN
                DMT_PRJ_BUDGET_FBDI_GEN_PKG.GENERATE_FBDI(p_run_id, l_zip, l_filename, l_csv_id);
            END;
        ELSIF p_cemli_code = 'Assets' THEN
            DECLARE l_csv_id NUMBER;
            BEGIN
                -- Multi-book: generate FBDI for ONLY this book when partitioned.
                DMT_FA_ASSET_FBDI_GEN_PKG.GENERATE_FBDI(p_run_id, l_zip, l_filename, l_csv_id, g_partition_key);
            END;
        ELSE
            RAISE_APPLICATION_ERROR(-20043,
                'RUN_ONE_OBJECT_TYPE: Unknown CEMLI_CODE = ''' || p_cemli_code || '''.');
        END IF;

        -- If no rows, skip this object type
        IF l_zip IS NULL OR DBMS_LOB.GETLENGTH(l_zip) = 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'No rows for ' || p_cemli_code || '. Skipping.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => l_obj || ' > ' || C_PROC);
            RETURN FALSE;
        END IF;

        -- loadAndImportData — MCCS pattern: combined load+import in single call.
        -- Per-CEMLI credentials: resolved from DMT_ERP_INTERFACE_OPTIONS_TBL.
        -- Falls back to FUSION_USERNAME/PASSWORD if no override seeded.
        BEGIN
            DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS(p_cemli_code, l_ess_user, l_ess_pass);
            l_load_ess_id := SUBMIT_LOAD(
                p_run_id    => p_run_id,
                p_fbdi_zip          => l_zip,
                p_filename          => l_filename,
                p_job_name          => l_job_name,
                p_interface_details => l_interface_details,
                p_doc_account       => l_ucm_account,
                p_parameter_list    => l_param_list,
                p_log_context       => l_obj,
                p_username          => l_ess_user,
                p_password          => l_ess_pass);
        END;
        DBMS_LOB.FREETEMPORARY(l_zip);

        -- Stamp Load ESS job ID + parameter list on the ZIP row.
        UPDATE DMT_OWNER.DMT_FBDI_ZIP_TBL
        SET    PARAMETER_LIST  = l_param_list
        WHERE  RUN_ID  = p_run_id
        AND    OBJECT_TYPE     = SUBSTR(p_cemli_code, INSTR(p_cemli_code, '-') + 1);
        COMMIT;

        -- Async mode: stop here, let queue poller handle ESS polling + reconciliation
        IF g_async_mode THEN
            g_load_ess_id := l_load_ess_id;
            RETURN TRUE;
        END IF;

        -- Poll Load job
        DMT_UTIL_PKG.LOG(p_run_id,
            'Polling Load ESS job: ' || l_load_ess_id, 'INFO', C_PKG, l_obj || ' > ' || C_PROC);
        POLL_ESS_JOB(p_run_id, l_load_ess_id, 1800, FALSE, l_obj, p_cemli_code, l_load_status,
                     p_username => l_ess_user, p_password => l_ess_pass);

        -- If Load ESS failed, no rows reached the interface table.
        -- Mark all GENERATED rows FAILED and return — no import job, no BIP.
        IF l_load_status NOT IN (C_STATUS_SUCCEEDED, C_STATUS_WARNING) THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'Load ESS ' || l_load_ess_id || ' returned ' || l_load_status ||
                '. No rows committed to interface table. Marking all GENERATED rows FAILED.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_obj || ' > ' || C_PROC);
            -- Mark GENERATED → FAILED in the appropriate TFM table(s)
            DECLARE
                l_err_msg VARCHAR2(500) := '[LOAD_ERROR] Loading data to the Fusion interface failed. Check ESS job ' || l_load_ess_id || ' logs for details.';
            BEGIN
                IF    p_cemli_code = 'Suppliers' THEN
                    UPDATE DMT_OWNER.DMT_POZ_SUPPLIERS_TFM_TBL SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED';
                ELSIF p_cemli_code = 'SupplierAddresses' THEN
                    UPDATE DMT_OWNER.DMT_POZ_SUP_ADDR_TFM_TBL SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED';
                ELSIF p_cemli_code = 'SupplierSites' THEN
                    UPDATE DMT_OWNER.DMT_POZ_SUP_SITE_TFM_TBL SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED';
                ELSIF p_cemli_code = 'SupplierSiteAssignments' THEN
                    UPDATE DMT_OWNER.DMT_POZ_SUP_SITE_ASSN_TFM_TBL SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED';
                ELSIF p_cemli_code = 'SupplierContacts' THEN
                    UPDATE DMT_OWNER.DMT_POZ_SUP_CONTACTS_TFM_TBL SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED';
                ELSIF p_cemli_code = 'Projects' THEN
                    UPDATE DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED';
                ELSIF p_cemli_code = 'BillingEvents' THEN
                    UPDATE DMT_OWNER.DMT_PJB_BILL_EVENTS_TFM_TBL SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED';
                ELSIF p_cemli_code = 'Expenditures' THEN
                    UPDATE DMT_OWNER.DMT_PJC_EXPENDITURES_TFM_TBL SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED';
                ELSIF p_cemli_code = 'Grants' THEN
                    UPDATE DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED';
                -- Items: handled in grouped loop above.
                ELSIF p_cemli_code = 'MiscReceipts' THEN
                    UPDATE DMT_OWNER.DMT_INV_TRX_TFM_TBL SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED';
                -- Requisitions: handled in grouped loop above.
                -- GLBalances: handled in grouped loop above.
                ELSIF p_cemli_code = 'GLBudgetBalances' THEN
                    UPDATE DMT_OWNER.DMT_GL_BUDGET_INT_TFM_TBL SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED';
                ELSIF p_cemli_code = 'PlanningBudgets' THEN
                    UPDATE DMT_OWNER.DMT_PLAN_BUDGET_TFM_TBL SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED';
                ELSIF p_cemli_code = 'ProjectBudgets' THEN
                    UPDATE DMT_OWNER.DMT_PRJ_BUDGET_TFM_TBL SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED';
                ELSIF p_cemli_code = 'Assets' THEN
                    UPDATE DMT_OWNER.DMT_FA_ASSET_HDR_TFM_TBL SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED';
                END IF;
                COMMIT;
            END;
            RETURN FALSE;
        END IF;

        -- Find the Import ESS job ID.
        -- MiscReceipts: INV Transaction Manager doesn't chain from loadAndImportData
        -- (interfaceDetails=33 is DMT-local, not a real Fusion FUN_ERP_INTERFACE_OPTIONS row).
        -- Submit PollTMEssJob explicitly — it picks up all process_flag=1 rows and
        -- spawns SingleTMEssJob internally to process them.
        IF p_cemli_code = 'MiscReceipts' THEN
            DECLARE
                l_resp     CLOB;
                l_tag_s    INTEGER;
                l_val_s    INTEGER;
                l_val_e    INTEGER;
            BEGIN
                DMT_UTIL_PKG.LOG(p_run_id,
                    'Submitting PollTMEssJob explicitly (INV transactions).', 'INFO', C_PKG, l_obj || ' > ' || C_PROC);
                l_resp := soap_http(
                    p_url            => erp_soap_url,
                    p_soap_action    => 'http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/submitESSJobRequest',
                    p_body           => TO_CLOB(
                        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' ||
                        'xmlns:typ="http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/types/">' ||
                        '<soapenv:Header/><soapenv:Body>' ||
                        '<typ:submitESSJobRequest>' ||
                        '<typ:jobPackageName>/oracle/apps/ess/scm/inventory/materialTransactions/txnManager</typ:jobPackageName>' ||
                        '<typ:jobDefinitionName>PollTMEssJob</typ:jobDefinitionName>' ||
                        '<typ:paramList></typ:paramList>' ||
                        '</typ:submitESSJobRequest>' ||
                        '</soapenv:Body></soapenv:Envelope>'),
                    p_run_id => p_run_id,
                    p_username       => l_ess_user,
                    p_password       => l_ess_pass);
                l_tag_s := DBMS_LOB.INSTR(l_resp, '<result');
                IF l_tag_s > 0 THEN
                    l_val_s := DBMS_LOB.INSTR(l_resp, '>', l_tag_s) + 1;
                    l_val_e := DBMS_LOB.INSTR(l_resp, '</result>', l_val_s);
                    IF l_val_e > l_val_s THEN
                        l_import_ess_id := DBMS_LOB.SUBSTR(l_resp, l_val_e - l_val_s, l_val_s);
                    END IF;
                END IF;
                IF l_import_ess_id IS NULL THEN
                    RAISE_APPLICATION_ERROR(-20050,
                        'Failed to submit PollTMEssJob. Response: ' || DBMS_LOB.SUBSTR(l_resp, 500, 1));
                END IF;
                DMT_UTIL_PKG.LOG(p_run_id,
                    'PollTMEssJob submitted. ESS ID: ' || l_import_ess_id, 'INFO', C_PKG, l_obj || ' > ' || C_PROC);
            END;
        ELSE
            l_import_ess_id := get_import_ess_id(p_run_id, p_cemli_code, l_load_ess_id);
        END IF;

        -- Stamp Import ESS job ID on the ZIP row.
        UPDATE DMT_OWNER.DMT_FBDI_ZIP_TBL
        SET    PARAMETER_LIST = PARAMETER_LIST  -- ESS IDs now on WORK_QUEUE
        WHERE  RUN_ID    = p_run_id
        AND    OBJECT_TYPE       = SUBSTR(p_cemli_code, INSTR(p_cemli_code, '-') + 1);
        COMMIT;

        -- Poll Import job — do NOT raise on error.
        DMT_UTIL_PKG.LOG(p_run_id,
            'Polling Import ESS job: ' || l_import_ess_id, 'INFO', C_PKG, l_obj || ' > ' || C_PROC);
        POLL_ESS_JOB(p_run_id, l_import_ess_id, 1800, FALSE, l_obj, p_cemli_code, l_load_status,
                     p_username => l_ess_user, p_password => l_ess_pass);

        -- Capture the Report child ESS job (e.g. ImportBillingEventReportJob)
        -- into the hierarchy so it's visible in the APEX UI alongside the import job.
        -- Generic — runs for all CEMLIs. Any DB/report error is a hard stop.
        DECLARE
            l_report_ess_id NUMBER;
        BEGIN
            l_report_ess_id := DMT_ESS_UTIL_PKG.CAPTURE_REPORT_ESS_JOB(
                p_run_id => p_run_id,
                p_import_ess_id  => TO_NUMBER(l_import_ess_id),
                p_cemli_code     => p_cemli_code);
        END;

        -- For Projects/Expenditures: capture Import Report errors from ESS output
        -- regardless of BIP outcome. This logs errors even when BIP reconciliation succeeds.
        IF p_cemli_code IN ('Projects', 'Expenditures', 'BillingEvents')
           AND l_load_status IN (C_STATUS_ERROR, C_STATUS_WARNING, C_STATUS_FAILED) THEN
            DECLARE
                l_ir_count NUMBER;
            BEGIN
                l_ir_count := DMT_IMPORT_REPORT_PKG.PARSE_AND_LOG_ERRORS(
                    p_run_id => p_run_id,
                    p_request_id     => TO_NUMBER(l_import_ess_id),
                    p_cemli_code     => p_cemli_code);
                DMT_UTIL_PKG.LOG(p_run_id,
                    'Import Report captured ' || l_ir_count || ' error(s) for ' || p_cemli_code ||
                    ' (ESS ' || l_import_ess_id || ', status ' || l_load_status || ').',
                    'INFO', C_PKG, l_obj || ' > ' || C_PROC);
            EXCEPTION
                WHEN OTHERS THEN
                    DMT_UTIL_PKG.LOG_ERROR(
                        p_run_id => p_run_id,
                        p_message        => 'Import Report capture failed for ' || p_cemli_code ||
                            ' (ESS ' || l_import_ess_id || '). Continuing to BIP reconciliation.',
                        p_sqlerrm        => SQLERRM,
                        p_package        => C_PKG,
                        p_procedure      => l_obj || ' > ' || C_PROC);
            END;
        END IF;

        -- BIP reconciliation — dispatch to correct results package
        IF p_cemli_code LIKE 'Supplier%' THEN
            DMT_POZ_SUP_RESULTS_PKG.RECONCILE_BATCH(
                p_run_id => p_run_id,
                p_cemli_code     => p_cemli_code,
                p_load_ess_id    => TO_NUMBER(l_load_ess_id),
                p_import_ess_id  => TO_NUMBER(l_import_ess_id));
        ELSIF p_cemli_code = 'Projects' THEN
            DMT_PROJECT_RESULTS_PKG.RECONCILE_BATCH(
                p_run_id => p_run_id,
                p_load_ess_id    => TO_NUMBER(l_load_ess_id),
                p_import_ess_id  => TO_NUMBER(l_import_ess_id));
        ELSIF p_cemli_code = 'BillingEvents' THEN
            DMT_BILLING_EVENT_RESULTS_PKG.RECONCILE_BATCH(
                p_run_id => p_run_id,
                p_load_ess_id    => TO_NUMBER(l_load_ess_id),
                p_import_ess_id  => TO_NUMBER(l_import_ess_id));
        ELSIF p_cemli_code = 'Expenditures' THEN
            DMT_EXPENDITURE_RESULTS_PKG.RECONCILE_BATCH(
                p_run_id => p_run_id,
                p_load_ess_id    => TO_NUMBER(l_load_ess_id),
                p_import_ess_id  => TO_NUMBER(l_import_ess_id));
        ELSIF p_cemli_code = 'Grants' THEN
            DMT_GRANTS_RESULTS_PKG.RECONCILE_BATCH(
                p_run_id => p_run_id,
                p_load_ess_id    => TO_NUMBER(l_load_ess_id),
                p_import_ess_id  => TO_NUMBER(l_import_ess_id));
        -- Items: handled in grouped loop above.
        ELSIF p_cemli_code = 'MiscReceipts' THEN
            DMT_MISC_RECEIPT_RESULTS_PKG.RECONCILE_BATCH(
                p_run_id => p_run_id,
                p_load_ess_id    => TO_NUMBER(l_load_ess_id),
                p_import_ess_id  => TO_NUMBER(l_import_ess_id));
        -- Requisitions: handled in grouped loop above.
        -- GLBalances: handled in grouped loop above.
        ELSIF p_cemli_code = 'GLBudgetBalances' THEN
            DMT_GL_BUDGET_RESULTS_PKG.RECONCILE_BATCH(
                p_run_id => p_run_id,
                p_load_ess_id    => TO_NUMBER(l_load_ess_id),
                p_import_ess_id  => TO_NUMBER(l_import_ess_id));
        ELSIF p_cemli_code = 'PlanningBudgets' THEN
            DMT_PLAN_BUDGET_RESULTS_PKG.RECONCILE_BATCH(
                p_run_id => p_run_id,
                p_load_ess_id    => TO_NUMBER(l_load_ess_id),
                p_import_ess_id  => TO_NUMBER(l_import_ess_id));
        ELSIF p_cemli_code = 'ProjectBudgets' THEN
            DMT_PRJ_BUDGET_RESULTS_PKG.RECONCILE_BATCH(
                p_run_id => p_run_id,
                p_load_ess_id    => TO_NUMBER(l_load_ess_id),
                p_import_ess_id  => TO_NUMBER(l_import_ess_id));
        ELSIF p_cemli_code = 'Assets' THEN
            DMT_FA_ASSET_RESULTS_PKG.RECONCILE_BATCH(
                p_run_id => p_run_id,
                p_load_ess_id    => TO_NUMBER(l_load_ess_id),
                p_import_ess_id  => TO_NUMBER(l_import_ess_id));
        END IF;

        -- Check for rows still at GENERATED after BIP reconciliation.
        -- Do NOT assume success — leave at GENERATED for manual investigation.
        DECLARE
            l_still_generated NUMBER := 0;
        BEGIN
            -- Use the CEMLI-specific TFM table to count GENERATED rows
            IF    p_cemli_code = 'Suppliers' THEN
                SELECT COUNT(*) INTO l_still_generated FROM DMT_OWNER.DMT_POZ_SUPPLIERS_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
            ELSIF p_cemli_code = 'SupplierAddresses' THEN
                SELECT COUNT(*) INTO l_still_generated FROM DMT_OWNER.DMT_POZ_SUP_ADDR_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
            ELSIF p_cemli_code = 'SupplierSites' THEN
                SELECT COUNT(*) INTO l_still_generated FROM DMT_OWNER.DMT_POZ_SUP_SITE_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
            ELSIF p_cemli_code = 'SupplierSiteAssignments' THEN
                SELECT COUNT(*) INTO l_still_generated FROM DMT_OWNER.DMT_POZ_SUP_SITE_ASSN_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
            ELSIF p_cemli_code = 'SupplierContacts' THEN
                SELECT COUNT(*) INTO l_still_generated FROM DMT_OWNER.DMT_POZ_SUP_CONTACTS_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
            ELSIF p_cemli_code = 'Projects' THEN
                SELECT COUNT(*) INTO l_still_generated FROM DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
            ELSIF p_cemli_code = 'BillingEvents' THEN
                SELECT COUNT(*) INTO l_still_generated FROM DMT_OWNER.DMT_PJB_BILL_EVENTS_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
            ELSIF p_cemli_code = 'Expenditures' THEN
                SELECT COUNT(*) INTO l_still_generated FROM DMT_OWNER.DMT_PJC_EXPENDITURES_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
            ELSIF p_cemli_code = 'Grants' THEN
                SELECT COUNT(*) INTO l_still_generated FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
            -- Items: handled in grouped loop above.
            ELSIF p_cemli_code = 'MiscReceipts' THEN
                SELECT COUNT(*) INTO l_still_generated FROM DMT_OWNER.DMT_INV_TRX_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
            -- Requisitions: handled in grouped loop above.
            -- GLBalances: handled in grouped loop above.
            ELSIF p_cemli_code = 'GLBudgetBalances' THEN
                SELECT COUNT(*) INTO l_still_generated FROM DMT_OWNER.DMT_GL_BUDGET_INT_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
            ELSIF p_cemli_code = 'PlanningBudgets' THEN
                SELECT COUNT(*) INTO l_still_generated FROM DMT_OWNER.DMT_PLAN_BUDGET_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
            ELSIF p_cemli_code = 'ProjectBudgets' THEN
                SELECT COUNT(*) INTO l_still_generated FROM DMT_OWNER.DMT_PRJ_BUDGET_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
            ELSIF p_cemli_code = 'Assets' THEN
                SELECT COUNT(*) INTO l_still_generated FROM DMT_OWNER.DMT_FA_ASSET_HDR_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
            END IF;

            IF l_still_generated > 0 THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    'WARNING: ' || l_still_generated || ' rows still at GENERATED after BIP reconciliation for ' ||
                    p_cemli_code || '. BIP query returned no matching rows for these records. ' ||
                    'Rows left at GENERATED for manual investigation — do NOT assume success.',
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, l_obj || ' > ' || C_PROC);

                -- Auto-download ESS output to diagnose silent rejections.
                -- Try the Import ESS job first (most likely to contain rejection details).
                -- Any DB/report error is a hard stop.
                IF l_import_ess_id IS NOT NULL THEN
                    DMT_ESS_UTIL_PKG.CAPTURE_ESS_OUTPUT(
                        p_run_id => p_run_id,
                        p_request_id     => TO_NUMBER(l_import_ess_id),
                        p_cemli_code     => p_cemli_code);
                END IF;
            END IF;
        END;

        <<grouped_finish>>

        -- Check for FAILED rows — log warning but do not abort
        DECLARE
            l_failed_count NUMBER;
        BEGIN
            IF    p_cemli_code = 'Suppliers' THEN
                SELECT COUNT(*) INTO l_failed_count
                FROM DMT_OWNER.DMT_POZ_SUPPLIERS_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';
            ELSIF p_cemli_code = 'SupplierAddresses' THEN
                SELECT COUNT(*) INTO l_failed_count
                FROM DMT_OWNER.DMT_POZ_SUP_ADDR_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';
            ELSIF p_cemli_code = 'SupplierSites' THEN
                SELECT COUNT(*) INTO l_failed_count
                FROM DMT_OWNER.DMT_POZ_SUP_SITE_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';
            ELSIF p_cemli_code = 'SupplierSiteAssignments' THEN
                SELECT COUNT(*) INTO l_failed_count
                FROM DMT_OWNER.DMT_POZ_SUP_SITE_ASSN_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';
            ELSIF p_cemli_code = 'SupplierContacts' THEN
                SELECT COUNT(*) INTO l_failed_count
                FROM DMT_OWNER.DMT_POZ_SUP_CONTACTS_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';
            ELSIF p_cemli_code IN ('PurchaseOrders', 'BlanketPOs', 'Contracts') THEN
                SELECT COUNT(*) INTO l_failed_count
                FROM DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';
            ELSIF p_cemli_code = 'Customers' THEN
                SELECT COUNT(*) INTO l_failed_count
                FROM DMT_OWNER.DMT_HZ_PARTIES_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';
            ELSIF p_cemli_code = 'ARInvoices' THEN
                SELECT COUNT(*) INTO l_failed_count
                FROM DMT_OWNER.DMT_RA_LINES_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';
            ELSIF p_cemli_code = 'APInvoices' THEN
                SELECT COUNT(*) INTO l_failed_count
                FROM DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';
            ELSIF p_cemli_code = 'Projects' THEN
                SELECT COUNT(*) INTO l_failed_count
                FROM DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';
            ELSIF p_cemli_code = 'BillingEvents' THEN
                SELECT COUNT(*) INTO l_failed_count
                FROM DMT_OWNER.DMT_PJB_BILL_EVENTS_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';
            ELSIF p_cemli_code = 'Expenditures' THEN
                SELECT COUNT(*) INTO l_failed_count
                FROM DMT_OWNER.DMT_PJC_EXPENDITURES_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';
            ELSIF p_cemli_code = 'Grants' THEN
                SELECT COUNT(*) INTO l_failed_count
                FROM DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';
            ELSIF p_cemli_code = '1099Invoices' THEN
                SELECT COUNT(*) INTO l_failed_count
                FROM DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED'
                AND INVOICE_TYPE_LOOKUP_CODE LIKE '%1099%';
            ELSIF p_cemli_code = 'Items' THEN
                SELECT COUNT(*) INTO l_failed_count
                FROM DMT_OWNER.DMT_EGP_ITEM_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';
                -- Also count bundled categories failures
                SELECT l_failed_count + COUNT(*) INTO l_failed_count
                FROM DMT_OWNER.DMT_EGP_ITEM_CAT_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';
            ELSIF p_cemli_code = 'MiscReceipts' THEN
                SELECT COUNT(*) INTO l_failed_count
                FROM DMT_OWNER.DMT_INV_TRX_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';
            ELSIF p_cemli_code = 'Requisitions' THEN
                SELECT COUNT(*) INTO l_failed_count
                FROM DMT_OWNER.DMT_POR_REQ_HEADERS_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';
            ELSIF p_cemli_code = 'GLBalances' THEN
                SELECT COUNT(*) INTO l_failed_count
                FROM DMT_OWNER.DMT_GL_INTERFACE_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';
            ELSIF p_cemli_code = 'GLBudgetBalances' THEN
                SELECT COUNT(*) INTO l_failed_count
                FROM DMT_OWNER.DMT_GL_BUDGET_INT_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';
            ELSIF p_cemli_code = 'PlanningBudgets' THEN
                SELECT COUNT(*) INTO l_failed_count
                FROM DMT_OWNER.DMT_PLAN_BUDGET_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';
            ELSIF p_cemli_code = 'ProjectBudgets' THEN
                SELECT COUNT(*) INTO l_failed_count
                FROM DMT_OWNER.DMT_PRJ_BUDGET_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';
            ELSIF p_cemli_code = 'Assets' THEN
                SELECT COUNT(*) INTO l_failed_count
                FROM DMT_OWNER.DMT_FA_ASSET_HDR_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';
            ELSE
                l_failed_count := 0;
            END IF;

            IF l_failed_count > 0 THEN
                DMT_UTIL_PKG.LOG(
                    p_run_id => p_run_id,
                    p_message        => p_cemli_code || ': ' || l_failed_count ||
                                        ' record(s) FAILED in Fusion. ' ||
                                        'Downstream object types will continue — check staging table for details.',
                    p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                    p_package        => C_PKG,
                    p_procedure      => l_obj || ' > ' || C_PROC);
            END IF;
        END;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Object type complete: ' || p_cemli_code,
            p_package        => C_PKG,
            p_procedure      => l_obj || ' > ' || C_PROC);

        RETURN TRUE;

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'RUN_ONE_OBJECT_TYPE failed. CEMLI: ' || p_cemli_code,
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => l_obj || ' > ' || C_PROC);
            RAISE;
    END run_one_object_type;

    -- --------------------------------------------------------
    -- RUN_SUPPLIER_PIPELINE
    -- Orchestrates all 5 object types in strict dependency order.
    -- --------------------------------------------------------
    PROCEDURE RUN_SUPPLIER_PIPELINE (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC  CONSTANT VARCHAR2(30) := 'RUN_SUPPLIER_PIPELINE';
        l_dummy BOOLEAN;
        v_scenario_id NUMBER;

    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'RUN_SUPPLIER_PIPELINE start. Integration ID: ' || p_run_id,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        -- (A12, 2026-07-08) direct RUN_STATUS write removed: one writer per
        -- status altitude -- RUN_STATUS is written only by the heartbeat
        -- rollup (DMT_QUEUE_PKG.rollup_run_statuses).

        -- Process in strict dependency order
        l_dummy := run_one_object_type(p_run_id, 'Suppliers', v_scenario_id, p_run_mode, p_skip_bu_refresh);
        COMMIT;

        l_dummy := run_one_object_type(p_run_id, 'SupplierAddresses', v_scenario_id, p_run_mode, p_skip_bu_refresh);
        COMMIT;

        l_dummy := run_one_object_type(p_run_id, 'SupplierSites', v_scenario_id, p_run_mode, p_skip_bu_refresh);
        COMMIT;

        l_dummy := run_one_object_type(p_run_id, 'SupplierSiteAssignments', v_scenario_id, p_run_mode, p_skip_bu_refresh);
        COMMIT;

        l_dummy := run_one_object_type(p_run_id, 'SupplierContacts', v_scenario_id, p_run_mode, p_skip_bu_refresh);
        COMMIT;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'RUN_SUPPLIER_PIPELINE complete.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'RUN_SUPPLIER_PIPELINE failed. Integration ID: ' ||
                                    p_run_id,
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            -- (A12, 2026-07-08) direct RUN_STATUS write removed (single-writer
            -- rule); the raised exception fails the work item and the heartbeat
            -- rollup settles the run.
            RAISE;
    END RUN_SUPPLIER_PIPELINE;

    -- --------------------------------------------------------
    -- Individual object-type runners (public)
    -- Thin wrappers over run_one_object_type; callable from APEX
    -- and Python test scripts for unit testing or one-off loads.
    -- --------------------------------------------------------
    PROCEDURE RUN_SUPPLIERS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RUN_SUPPLIERS';
        l_dummy BOOLEAN;
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_SUPPLIERS start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);
        l_dummy := run_one_object_type(p_run_id, 'Suppliers', v_scenario_id, p_run_mode, p_skip_bu_refresh);
        COMMIT;
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_SUPPLIERS complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'RUN_SUPPLIERS failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_SUPPLIERS;

    PROCEDURE RUN_SUPPLIER_ADDRESSES (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RUN_SUPPLIER_ADDRESSES';
        l_dummy BOOLEAN;
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_SUPPLIER_ADDRESSES start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);
        l_dummy := run_one_object_type(p_run_id, 'SupplierAddresses', v_scenario_id, p_run_mode, p_skip_bu_refresh);
        COMMIT;
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_SUPPLIER_ADDRESSES complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'RUN_SUPPLIER_ADDRESSES failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_SUPPLIER_ADDRESSES;

    PROCEDURE RUN_SUPPLIER_SITES (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RUN_SUPPLIER_SITES';
        l_dummy BOOLEAN;
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_SUPPLIER_SITES start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);
        l_dummy := run_one_object_type(p_run_id, 'SupplierSites', v_scenario_id, p_run_mode, p_skip_bu_refresh);
        COMMIT;
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_SUPPLIER_SITES complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'RUN_SUPPLIER_SITES failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_SUPPLIER_SITES;

    PROCEDURE RUN_SUPPLIER_SITE_ASSIGNMENTS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RUN_SUPPLIER_SITE_ASSIGNMENTS';
        l_dummy BOOLEAN;
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_SUPPLIER_SITE_ASSIGNMENTS start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);
        l_dummy := run_one_object_type(p_run_id, 'SupplierSiteAssignments', v_scenario_id, p_run_mode, p_skip_bu_refresh);
        COMMIT;
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_SUPPLIER_SITE_ASSIGNMENTS complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'RUN_SUPPLIER_SITE_ASSIGNMENTS failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_SUPPLIER_SITE_ASSIGNMENTS;

    PROCEDURE RUN_SUPPLIER_CONTACTS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RUN_SUPPLIER_CONTACTS';
        l_dummy BOOLEAN;
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_SUPPLIER_CONTACTS start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);
        l_dummy := run_one_object_type(p_run_id, 'SupplierContacts', v_scenario_id, p_run_mode, p_skip_bu_refresh);
        COMMIT;
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_SUPPLIER_CONTACTS complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'RUN_SUPPLIER_CONTACTS failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_SUPPLIER_CONTACTS;

    PROCEDURE RUN_PURCHASE_ORDERS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RUN_PURCHASE_ORDERS';
        l_dummy BOOLEAN;
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_PURCHASE_ORDERS start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);
        l_dummy := run_one_object_type(p_run_id, 'PurchaseOrders', v_scenario_id, p_run_mode, p_skip_bu_refresh);
        COMMIT;
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_PURCHASE_ORDERS complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'RUN_PURCHASE_ORDERS failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_PURCHASE_ORDERS;

    -- --------------------------------------------------------
    -- RUN_STANDALONE
    -- Single entry point for running any CEMLI individually with
    -- automatic prefix assignment. Creates CONVERSION_MASTER row,
    -- then dispatches to run_one_object_type.
    -- --------------------------------------------------------
    PROCEDURE RUN_STANDALONE (
        x_run_id   OUT NUMBER,
        p_cemli_code       IN  VARCHAR2,
        p_scenario_name    IN  VARCHAR2 DEFAULT NULL,
        p_run_mode         IN  VARCHAR2 DEFAULT 'NEW'
    ) IS
        C_PROC           CONSTANT VARCHAR2(30) := 'RUN_STANDALONE';
        l_run_id NUMBER;
        l_prefix         VARCHAR2(20);
        v_scenario_id    NUMBER;
        l_dummy          BOOLEAN;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);

        SELECT DMT_OWNER.DMT_PIPELINE_RUN_SEQ.NEXTVAL INTO l_run_id FROM DUAL;
        SELECT TO_CHAR(DMT_OWNER.DMT_RUN_PREFIX_SEQ.NEXTVAL) INTO l_prefix FROM DUAL;

        INSERT INTO DMT_OWNER.DMT_PIPELINE_RUN_TBL (
            RUN_ID, INTEGRATION_ID, PIPELINE_CODES, RUN_TYPE,
            SUBMITTED_BY, RUN_STATUS, PREFIX, CEMLI_SEQUENCE,
            SCENARIO_NAME, RUN_MODE
        ) VALUES (
            l_run_id, l_run_id, p_cemli_code, 'STANDALONE',
            'MANUAL', 'IN_PROGRESS', l_prefix, p_cemli_code,
            p_scenario_name, p_run_mode
        );
        COMMIT;

        x_run_id := l_run_id;

        DMT_UTIL_PKG.LOG(l_run_id,
            C_PROC || ' start. CEMLI: ' || p_cemli_code ||
            ' | Integration ID: ' || l_run_id ||
            ' | Prefix: ' || l_prefix ||
            ' | Mode: ' || p_run_mode,
            'INFO', C_PKG, C_PROC);

        l_dummy := run_one_object_type(
            l_run_id, p_cemli_code, v_scenario_id,
            p_run_mode);

        COMMIT;

        DMT_UTIL_PKG.LOG(l_run_id,
            C_PROC || ' complete. CEMLI: ' || p_cemli_code,
            'INFO', C_PKG, C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(l_run_id,
                C_PROC || ' failed. CEMLI: ' || p_cemli_code,
                SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_STANDALONE;

    -- --------------------------------------------------------
    -- RUN_PROCURE_TO_PAY
    -- Full P2P pipeline. Currently: all 5 supplier object types.
    -- Creates a CONVERSION_MASTER row; integration ID and prefix both from sequences.
    -- Returns the generated integration ID via x_run_id OUT.
    -- Future: add PO, AP Invoice, etc. runners here in order.
    -- --------------------------------------------------------
    PROCEDURE RUN_PROCURE_TO_PAY (x_run_id OUT NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW') IS
        C_PROC           CONSTANT VARCHAR2(30) := 'RUN_PROCURE_TO_PAY';
        l_run_id NUMBER;
        l_prefix         VARCHAR2(20);
        v_scenario_id    NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);

        -- Derive integration ID and prefix from sequences
        SELECT DMT_OWNER.DMT_PIPELINE_RUN_SEQ.NEXTVAL INTO l_run_id FROM DUAL;
        SELECT TO_CHAR(DMT_OWNER.DMT_RUN_PREFIX_SEQ.NEXTVAL) INTO l_prefix FROM DUAL;

        INSERT INTO DMT_OWNER.DMT_PIPELINE_RUN_TBL (
            RUN_ID, INTEGRATION_ID, PIPELINE_CODES, RUN_TYPE,
            SUBMITTED_BY, RUN_STATUS, PREFIX, CEMLI_SEQUENCE,
            SCENARIO_NAME, RUN_MODE
        ) VALUES (
            l_run_id, l_run_id, 'ProcureToPay', 'PIPELINE',
            'MANUAL', 'IN_PROGRESS', l_prefix,
            'Suppliers,SupplierAddresses,SupplierSites,SupplierSiteAssignments,SupplierContacts,PurchaseOrders,BlanketPOs,ContractPOs,APInvoices,1099Invoices,Requisitions',
            p_scenario_name, p_run_mode
        );
        COMMIT;

        x_run_id := l_run_id;

        DMT_UTIL_PKG.LOG(l_run_id,
            'RUN_PROCURE_TO_PAY start. Integration ID: ' || l_run_id ||
            ' | Prefix: ' || l_prefix, 'INFO', C_PKG, C_PROC);

        -- Refresh BU lookups once for the entire pipeline run
        DMT_UTIL_PKG.REFRESH_BU_LOOKUPS;

        -- Suppliers (all 5 object types in dependency order)
        RUN_SUPPLIER_PIPELINE(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);

        -- Purchase Orders (one ESS job for all 4 object types)
        RUN_PURCHASE_ORDERS(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);

        -- Blanket Purchase Agreements
        RUN_BLANKET_POS(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);

        -- Contract Purchase Agreements
        RUN_CONTRACTS(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);

        -- AP Invoices (headers + lines, grouped by operating unit)
        RUN_AP_INVOICES(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);

        -- 1099 Invoices (shares AP tables, filtered by invoice type)
        RUN_1099_INVOICES(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);

        -- Requisitions (headers + lines + distributions)
        RUN_REQUISITIONS(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);

        COMMIT;

        DMT_UTIL_PKG.LOG(l_run_id,
            'RUN_PROCURE_TO_PAY complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            IF l_run_id IS NOT NULL THEN
                DMT_UTIL_PKG.LOG_ERROR(l_run_id,
                    'RUN_PROCURE_TO_PAY failed.', SQLERRM, C_PKG, C_PROC);
                COMMIT;
            END IF;
            RAISE;
    END RUN_PROCURE_TO_PAY;

    -- --------------------------------------------------------
    -- RUN_CUSTOMERS (public)
    -- Customers: single FBDI with 7 CSVs, single BulkImportJob ESS.
    -- --------------------------------------------------------
    PROCEDURE RUN_CUSTOMERS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RUN_CUSTOMERS';
        l_dummy BOOLEAN;
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_CUSTOMERS start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);
        l_dummy := run_one_object_type(p_run_id, 'Customers', v_scenario_id, p_run_mode, p_skip_bu_refresh);
        COMMIT;
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_CUSTOMERS complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'RUN_CUSTOMERS failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_CUSTOMERS;

    -- --------------------------------------------------------
    -- RUN_AR_INVOICES (public)
    -- ARInvoices: grouped by (BU_NAME, BATCH_SOURCE_NAME).
    -- Each group gets its own FBDI zip + loadAndImportData + BIP reconciliation.
    -- Upstream dependency: customers must be LOADED.
    -- --------------------------------------------------------
    PROCEDURE RUN_AR_INVOICES (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RUN_AR_INVOICES';
        l_dummy BOOLEAN;
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_AR_INVOICES start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);
        l_dummy := run_one_object_type(p_run_id, 'ARInvoices', v_scenario_id, p_run_mode, p_skip_bu_refresh);
        COMMIT;
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_AR_INVOICES complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'RUN_AR_INVOICES failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_AR_INVOICES;

    -- --------------------------------------------------------
    -- RUN_BILLING_EVENTS (public)
    -- --------------------------------------------------------
    PROCEDURE RUN_BILLING_EVENTS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RUN_BILLING_EVENTS';
        l_dummy BOOLEAN;
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_BILLING_EVENTS start.', 'INFO', C_PKG, C_PROC);
        l_dummy := run_one_object_type(p_run_id, 'BillingEvents', v_scenario_id, p_run_mode, p_skip_bu_refresh);
        COMMIT;
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_BILLING_EVENTS complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'RUN_BILLING_EVENTS failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_BILLING_EVENTS;

    -- --------------------------------------------------------
    -- RUN_EXPENDITURES (public)
    -- --------------------------------------------------------
    PROCEDURE RUN_EXPENDITURES (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RUN_EXPENDITURES';
        l_dummy BOOLEAN;
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_EXPENDITURES start.', 'INFO', C_PKG, C_PROC);
        l_dummy := run_one_object_type(p_run_id, 'Expenditures', v_scenario_id, p_run_mode, p_skip_bu_refresh);
        COMMIT;
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_EXPENDITURES complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'RUN_EXPENDITURES failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_EXPENDITURES;

    -- --------------------------------------------------------
    -- RUN_GRANTS (public)
    -- --------------------------------------------------------
    PROCEDURE RUN_GRANTS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RUN_GRANTS';
        l_dummy BOOLEAN;
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_GRANTS start.', 'INFO', C_PKG, C_PROC);
        l_dummy := run_one_object_type(p_run_id, 'Grants', v_scenario_id, p_run_mode, p_skip_bu_refresh);
        COMMIT;
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_GRANTS complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'RUN_GRANTS failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_GRANTS;

    -- --------------------------------------------------------
    -- RUN_1099_INVOICES (public)
    -- --------------------------------------------------------
    PROCEDURE RUN_1099_INVOICES (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RUN_1099_INVOICES';
        l_dummy BOOLEAN;
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_1099_INVOICES start.', 'INFO', C_PKG, C_PROC);
        l_dummy := run_one_object_type(p_run_id, '1099Invoices', v_scenario_id, p_run_mode, p_skip_bu_refresh);
        COMMIT;
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_1099_INVOICES complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'RUN_1099_INVOICES failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_1099_INVOICES;

    -- --------------------------------------------------------
    -- RUN_REQUISITIONS (public)
    -- --------------------------------------------------------
    PROCEDURE RUN_REQUISITIONS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RUN_REQUISITIONS';
        l_dummy BOOLEAN;
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_REQUISITIONS start.', 'INFO', C_PKG, C_PROC);
        l_dummy := run_one_object_type(p_run_id, 'Requisitions', v_scenario_id, p_run_mode, p_skip_bu_refresh);
        COMMIT;
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_REQUISITIONS complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'RUN_REQUISITIONS failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_REQUISITIONS;

    -- --------------------------------------------------------
    -- RUN_ITEMS (public)
    -- --------------------------------------------------------
    PROCEDURE RUN_ITEMS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RUN_ITEMS';
        l_dummy BOOLEAN;
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_ITEMS start (includes ItemCategories bundled in same ZIP).', 'INFO', C_PKG, C_PROC);

        -- Categories are validated, transformed, bundled into the FBDI ZIP, and reconciled
        -- inside the 'Items' branch of run_one_object_type, so a single call covers both.
        l_dummy := run_one_object_type(p_run_id, 'Items', v_scenario_id, p_run_mode, p_skip_bu_refresh);
        COMMIT;
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_ITEMS complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'RUN_ITEMS failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_ITEMS;

    -- --------------------------------------------------------
    -- RUN_ITEM_CATEGORIES (public)
    -- --------------------------------------------------------
    PROCEDURE RUN_ITEM_CATEGORIES (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RUN_ITEM_CATEGORIES';
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        -- ItemCategories are bundled with Items in one FBDI ZIP under ItemImportJobDef.
        -- This proc only validates+transforms; FBDI gen + ESS submission happens in RUN_ITEMS.
        -- Kept for standalone validate/transform use (e.g. data quality check without submission).
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_ITEM_CATEGORIES start (validate+transform only — ESS submission via RUN_ITEMS).', 'INFO', C_PKG, C_PROC);

        DMT_EGP_ITEM_CAT_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
        DMT_EGP_ITEM_CAT_TRANSFORM_PKG.TRANSFORM(
            p_run_id   => p_run_id,
            p_reprocess_errors => (p_run_mode = 'FAILED'),
            p_scenario_id      => v_scenario_id,
            p_run_mode         => p_run_mode
        );
        COMMIT;

        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_ITEM_CATEGORIES complete (validate+transform only).', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'RUN_ITEM_CATEGORIES failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_ITEM_CATEGORIES;

    -- --------------------------------------------------------
    -- RUN_MISC_RECEIPTS (public)
    -- --------------------------------------------------------
    PROCEDURE RUN_MISC_RECEIPTS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RUN_MISC_RECEIPTS';
        l_dummy BOOLEAN;
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_MISC_RECEIPTS start.', 'INFO', C_PKG, C_PROC);
        l_dummy := run_one_object_type(p_run_id, 'MiscReceipts', v_scenario_id, p_run_mode, p_skip_bu_refresh);
        COMMIT;
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_MISC_RECEIPTS complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'RUN_MISC_RECEIPTS failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_MISC_RECEIPTS;

    -- --------------------------------------------------------
    -- RUN_PROJECTS (public)
    -- --------------------------------------------------------
    PROCEDURE RUN_PROJECTS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RUN_PROJECTS';
        l_dummy BOOLEAN;
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_PROJECTS start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);
        l_dummy := run_one_object_type(p_run_id, 'Projects', v_scenario_id, p_run_mode, p_skip_bu_refresh);
        COMMIT;
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_PROJECTS complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'RUN_PROJECTS failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_PROJECTS;

    -- --------------------------------------------------------
    -- RUN_BLANKET_POS (public)
    -- --------------------------------------------------------
    PROCEDURE RUN_BLANKET_POS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RUN_BLANKET_POS';
        l_dummy BOOLEAN;
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_BLANKET_POS start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);
        l_dummy := run_one_object_type(p_run_id, 'BlanketPOs', v_scenario_id, p_run_mode, p_skip_bu_refresh);
        COMMIT;
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_BLANKET_POS complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'RUN_BLANKET_POS failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_BLANKET_POS;

    -- --------------------------------------------------------
    -- RUN_CONTRACTS (public)
    -- --------------------------------------------------------
    PROCEDURE RUN_CONTRACTS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RUN_CONTRACTS';
        l_dummy BOOLEAN;
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_CONTRACTS start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);
        l_dummy := run_one_object_type(p_run_id, 'Contracts', v_scenario_id, p_run_mode, p_skip_bu_refresh);
        COMMIT;
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_CONTRACTS complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'RUN_CONTRACTS failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_CONTRACTS;

    -- --------------------------------------------------------
    -- RUN_AP_INVOICES (public)
    -- APInvoices: grouped by OPERATING_UNIT.
    -- Each group gets its own FBDI zip + loadAndImportData + BIP reconciliation.
    -- Upstream dependency: suppliers must be LOADED.
    -- --------------------------------------------------------
    PROCEDURE RUN_AP_INVOICES (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RUN_AP_INVOICES';
        l_dummy BOOLEAN;
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_AP_INVOICES start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);
        l_dummy := run_one_object_type(p_run_id, 'APInvoices', v_scenario_id, p_run_mode, p_skip_bu_refresh);
        COMMIT;
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_AP_INVOICES complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'RUN_AP_INVOICES failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_AP_INVOICES;

    -- --------------------------------------------------------
    -- RUN_ORDER_TO_CASH
    -- Full O2C pipeline: customers → AR invoices.
    -- Creates a CONVERSION_MASTER row; integration ID and prefix both from sequences.
    -- --------------------------------------------------------
    PROCEDURE RUN_ORDER_TO_CASH (x_run_id OUT NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW') IS
        C_PROC           CONSTANT VARCHAR2(30) := 'RUN_ORDER_TO_CASH';
        l_run_id NUMBER;
        l_prefix         VARCHAR2(20);
        v_scenario_id    NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);

        SELECT DMT_OWNER.DMT_PIPELINE_RUN_SEQ.NEXTVAL INTO l_run_id FROM DUAL;
        SELECT TO_CHAR(DMT_OWNER.DMT_RUN_PREFIX_SEQ.NEXTVAL) INTO l_prefix FROM DUAL;

        INSERT INTO DMT_OWNER.DMT_PIPELINE_RUN_TBL (
            RUN_ID, INTEGRATION_ID, PIPELINE_CODES, RUN_TYPE,
            SUBMITTED_BY, RUN_STATUS, PREFIX, CEMLI_SEQUENCE,
            SCENARIO_NAME, RUN_MODE
        ) VALUES (
            l_run_id, l_run_id, 'OrderToCash', 'PIPELINE',
            'MANUAL', 'IN_PROGRESS', l_prefix,
            'Customers,ARInvoices',
            p_scenario_name, p_run_mode
        );
        COMMIT;

        x_run_id := l_run_id;

        DMT_UTIL_PKG.LOG(l_run_id,
            'RUN_ORDER_TO_CASH start. Integration ID: ' || l_run_id ||
            ' | Prefix: ' || l_prefix, 'INFO', C_PKG, C_PROC);

        DMT_UTIL_PKG.REFRESH_BU_LOOKUPS;

        -- Customers (all 7 object types in one FBDI)
        RUN_CUSTOMERS(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);

        -- AR Invoices (lines + distributions)
        RUN_AR_INVOICES(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);

        COMMIT;

        DMT_UTIL_PKG.LOG(l_run_id,
            'RUN_ORDER_TO_CASH complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            IF l_run_id IS NOT NULL THEN
                DMT_UTIL_PKG.LOG_ERROR(l_run_id,
                    'RUN_ORDER_TO_CASH failed.', SQLERRM, C_PKG, C_PROC);
                COMMIT;
            END IF;
            RAISE;
    END RUN_ORDER_TO_CASH;

    -- --------------------------------------------------------
    -- RUN_WORKERS (public) — HDL pattern
    -- Generates Worker.dat, uploads via HCM REST, polls, reconciles.
    -- --------------------------------------------------------
    PROCEDURE RUN_WORKERS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC      CONSTANT VARCHAR2(30) := 'RUN_WORKERS';
        l_hdl_zip   BLOB;
        l_filename  VARCHAR2(200);
        l_csv_id    NUMBER;
        l_content_id    VARCHAR2(100);
        l_request_id    VARCHAR2(100);
        l_dataset_status VARCHAR2(50);
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_WORKERS start. Integration ID: ' || p_run_id,
            'INFO', C_PKG, C_PROC);

        -- Step 1: Pre-validation (stub — no rules yet)
        DMT_WORKER_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);

        -- Step 2: Transform all 7 business objects (STG → TFM)
        DMT_WORKER_TRANSFORM_PKG.TRANSFORM_WORKERS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_WORKER_TRANSFORM_PKG.TRANSFORM_PERSON_NAMES(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_WORKER_TRANSFORM_PKG.TRANSFORM_PERSON_EMAILS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_WORKER_TRANSFORM_PKG.TRANSFORM_PERSON_PHONES(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_WORKER_TRANSFORM_PKG.TRANSFORM_PERSON_ADDRESSES(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_WORKER_TRANSFORM_PKG.TRANSFORM_PERSON_NIDS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_WORKER_TRANSFORM_PKG.TRANSFORM_PERSON_LEGISL(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;

        -- Step 3: Post-validation (stub)
        DMT_WORKER_VALIDATOR_PKG.VALIDATE_POST_TRANSFORM(p_run_id);

        -- Step 4: Generate Worker.dat HDL file → ZIP
        DMT_WORKER_HDL_GEN_PKG.GENERATE_HDL(p_run_id, l_hdl_zip, l_filename, l_csv_id);
        COMMIT;

        -- If no rows generated, skip
        IF l_hdl_zip IS NULL OR DBMS_LOB.GETLENGTH(l_hdl_zip) = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'No Worker rows to load. Skipping.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
            RETURN;
        END IF;

        -- Step 5: Upload ZIP to Fusion UCM via HCM REST
        l_content_id := DMT_HDL_UTIL_PKG.UPLOAD_HDL(
            p_run_id => p_run_id,
            p_hdl_zip        => l_hdl_zip,
            p_filename       => l_filename,
            p_log_context    => 'Workers');
        DBMS_LOB.FREETEMPORARY(l_hdl_zip);

        -- Step 6: Submit HCM Data Loader import
        l_request_id := DMT_HDL_UTIL_PKG.SUBMIT_HDL(
            p_run_id => p_run_id,
            p_content_id     => l_content_id,
            p_dataset_name   => 'DMT Workers ' || TO_CHAR(p_run_id),
            p_log_context    => 'Workers');

        -- Stamp request IDs on ZIP row
        COMMIT;

        -- Step 7: Poll HCM Data Loader until terminal
        DMT_HDL_UTIL_PKG.POLL_HDL(
            p_run_id => p_run_id,
            p_request_id     => l_request_id,
            p_timeout_sec    => 1800,
            p_raise_on_error => FALSE,
            p_log_context    => 'Workers',
            x_dataset_status => l_dataset_status);

        -- Step 8: Reconcile — parse HDL errors, update TFM/STG
        DMT_WORKER_RESULTS_PKG.RECONCILE_BATCH(
            p_run_id => p_run_id,
            p_request_id     => l_request_id,
            p_dataset_status => l_dataset_status);

        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_WORKERS complete.', 'INFO', C_PKG, C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'RUN_WORKERS failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_WORKERS;

    -- --------------------------------------------------------
    -- RUN_ASSIGNMENTS (public) — HDL pattern
    -- WorkRelationship + Assignment in Worker.dat HDL.
    -- --------------------------------------------------------
    PROCEDURE RUN_ASSIGNMENTS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC      CONSTANT VARCHAR2(30) := 'RUN_ASSIGNMENTS';
        l_hdl_zip   BLOB;
        l_filename  VARCHAR2(200);
        l_csv_id    NUMBER;
        l_content_id    VARCHAR2(100);
        l_request_id    VARCHAR2(100);
        l_dataset_status VARCHAR2(50);
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_ASSIGNMENTS start. Integration ID: ' || p_run_id,
            'INFO', C_PKG, C_PROC);

        DMT_ASSIGNMENT_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);

        DMT_ASSIGNMENT_TRANSFORM_PKG.TRANSFORM_WORK_RELS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_ASSIGNMENT_TRANSFORM_PKG.TRANSFORM_ASSIGNMENTS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;

        DMT_ASSIGNMENT_VALIDATOR_PKG.VALIDATE_POST_TRANSFORM(p_run_id);

        DMT_ASSIGNMENT_HDL_GEN_PKG.GENERATE_HDL(p_run_id, l_hdl_zip, l_filename, l_csv_id);
        COMMIT;

        IF l_hdl_zip IS NULL OR DBMS_LOB.GETLENGTH(l_hdl_zip) = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id, 'No Assignment rows to load. Skipping.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
            RETURN;
        END IF;

        l_content_id := DMT_HDL_UTIL_PKG.UPLOAD_HDL(p_run_id, l_hdl_zip, l_filename, 'Assignments');
        DBMS_LOB.FREETEMPORARY(l_hdl_zip);

        l_request_id := DMT_HDL_UTIL_PKG.SUBMIT_HDL(p_run_id, l_content_id,
            'DMT Assignments ' || TO_CHAR(p_run_id), 'Assignments');

        COMMIT;

        DMT_HDL_UTIL_PKG.POLL_HDL(p_run_id, l_request_id, 1800, FALSE, 'Assignments', l_dataset_status);

        DMT_ASSIGNMENT_RESULTS_PKG.RECONCILE_BATCH(p_run_id, l_request_id, l_dataset_status);

        DMT_UTIL_PKG.LOG(p_run_id, 'RUN_ASSIGNMENTS complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'RUN_ASSIGNMENTS failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_ASSIGNMENTS;

    -- --------------------------------------------------------
    -- RUN_SALARIES (public) — HDL pattern
    -- --------------------------------------------------------
    PROCEDURE RUN_SALARIES (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC      CONSTANT VARCHAR2(30) := 'RUN_SALARIES';
        l_hdl_zip   BLOB;
        l_filename  VARCHAR2(200);
        l_csv_id    NUMBER;
        l_content_id    VARCHAR2(100);
        l_request_id    VARCHAR2(100);
        l_dataset_status VARCHAR2(50);
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_SALARIES start. Integration ID: ' || p_run_id,
            'INFO', C_PKG, C_PROC);

        DMT_SALARY_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);

        DMT_SALARY_TRANSFORM_PKG.TRANSFORM_SALARIES(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;
        DMT_SALARY_VALIDATOR_PKG.VALIDATE_POST_TRANSFORM(p_run_id);

        DMT_SALARY_HDL_GEN_PKG.GENERATE_HDL(p_run_id, l_hdl_zip, l_filename, l_csv_id);
        COMMIT;

        IF l_hdl_zip IS NULL OR DBMS_LOB.GETLENGTH(l_hdl_zip) = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id, 'No Salary rows to load. Skipping.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
            RETURN;
        END IF;

        l_content_id := DMT_HDL_UTIL_PKG.UPLOAD_HDL(p_run_id, l_hdl_zip, l_filename, 'Salaries');
        DBMS_LOB.FREETEMPORARY(l_hdl_zip);
        l_request_id := DMT_HDL_UTIL_PKG.SUBMIT_HDL(p_run_id, l_content_id,
            'DMT Salaries ' || TO_CHAR(p_run_id), 'Salaries');
        COMMIT;

        DMT_HDL_UTIL_PKG.POLL_HDL(p_run_id, l_request_id, 1800, FALSE, 'Salaries', l_dataset_status);
        DMT_SALARY_RESULTS_PKG.RECONCILE_BATCH(p_run_id, l_request_id, l_dataset_status);

        DMT_UTIL_PKG.LOG(p_run_id, 'RUN_SALARIES complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'RUN_SALARIES failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_SALARIES;

    -- --------------------------------------------------------
    -- RUN_SALARY_BASES (public) — HDL pattern
    -- --------------------------------------------------------
    PROCEDURE RUN_SALARY_BASES (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC      CONSTANT VARCHAR2(30) := 'RUN_SALARY_BASES';
        l_hdl_zip   BLOB;
        l_filename  VARCHAR2(200);
        l_csv_id    NUMBER;
        l_content_id    VARCHAR2(100);
        l_request_id    VARCHAR2(100);
        l_dataset_status VARCHAR2(50);
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_SALARY_BASES start. Integration ID: ' || p_run_id,
            'INFO', C_PKG, C_PROC);

        DMT_SAL_BASIS_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);

        DMT_SAL_BASIS_TRANSFORM_PKG.TRANSFORM_SALARYBASES(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;
        DMT_SAL_BASIS_VALIDATOR_PKG.VALIDATE_POST_TRANSFORM(p_run_id);

        DMT_SAL_BASIS_HDL_GEN_PKG.GENERATE_HDL(p_run_id, l_hdl_zip, l_filename, l_csv_id);
        COMMIT;

        IF l_hdl_zip IS NULL OR DBMS_LOB.GETLENGTH(l_hdl_zip) = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id, 'No SalaryBasis rows to load. Skipping.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
            RETURN;
        END IF;

        l_content_id := DMT_HDL_UTIL_PKG.UPLOAD_HDL(p_run_id, l_hdl_zip, l_filename, 'SalaryBases');
        DBMS_LOB.FREETEMPORARY(l_hdl_zip);
        l_request_id := DMT_HDL_UTIL_PKG.SUBMIT_HDL(p_run_id, l_content_id,
            'DMT SalaryBases ' || TO_CHAR(p_run_id), 'SalaryBases');
        COMMIT;

        DMT_HDL_UTIL_PKG.POLL_HDL(p_run_id, l_request_id, 1800, FALSE, 'SalaryBases', l_dataset_status);
        DMT_SAL_BASIS_RESULTS_PKG.RECONCILE_BATCH(p_run_id, l_request_id, l_dataset_status);

        DMT_UTIL_PKG.LOG(p_run_id, 'RUN_SALARY_BASES complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'RUN_SALARY_BASES failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_SALARY_BASES;

    -- --------------------------------------------------------
    -- RUN_ABSENCES (public) — HDL pattern
    -- --------------------------------------------------------
    PROCEDURE RUN_ABSENCES (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC      CONSTANT VARCHAR2(30) := 'RUN_ABSENCES';
        l_hdl_zip   BLOB;
        l_filename  VARCHAR2(200);
        l_csv_id    NUMBER;
        l_content_id    VARCHAR2(100);
        l_request_id    VARCHAR2(100);
        l_dataset_status VARCHAR2(50);
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_ABSENCES start. Integration ID: ' || p_run_id,
            'INFO', C_PKG, C_PROC);

        DMT_ABSENCE_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);

        DMT_ABSENCE_TRANSFORM_PKG.TRANSFORM_ABSENCEENTRIES(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;
        DMT_ABSENCE_VALIDATOR_PKG.VALIDATE_POST_TRANSFORM(p_run_id);

        DMT_ABSENCE_HDL_GEN_PKG.GENERATE_HDL(p_run_id, l_hdl_zip, l_filename, l_csv_id);
        COMMIT;

        IF l_hdl_zip IS NULL OR DBMS_LOB.GETLENGTH(l_hdl_zip) = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id, 'No Absence rows to load. Skipping.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
            RETURN;
        END IF;

        l_content_id := DMT_HDL_UTIL_PKG.UPLOAD_HDL(p_run_id, l_hdl_zip, l_filename, 'Absences');
        DBMS_LOB.FREETEMPORARY(l_hdl_zip);
        l_request_id := DMT_HDL_UTIL_PKG.SUBMIT_HDL(p_run_id, l_content_id,
            'DMT Absences ' || TO_CHAR(p_run_id), 'Absences');
        COMMIT;

        DMT_HDL_UTIL_PKG.POLL_HDL(p_run_id, l_request_id, 1800, FALSE, 'Absences', l_dataset_status);
        DMT_ABSENCE_RESULTS_PKG.RECONCILE_BATCH(p_run_id, l_request_id, l_dataset_status);

        DMT_UTIL_PKG.LOG(p_run_id, 'RUN_ABSENCES complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'RUN_ABSENCES failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_ABSENCES;

    -- --------------------------------------------------------
    -- RUN_W2_BALANCES (public) — HDL pattern
    -- --------------------------------------------------------
    PROCEDURE RUN_W2_BALANCES (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC      CONSTANT VARCHAR2(30) := 'RUN_W2_BALANCES';
        l_hdl_zip   BLOB;
        l_filename  VARCHAR2(200);
        l_csv_id    NUMBER;
        l_content_id    VARCHAR2(100);
        l_request_id    VARCHAR2(100);
        l_dataset_status VARCHAR2(50);
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_W2_BALANCES start. Integration ID: ' || p_run_id,
            'INFO', C_PKG, C_PROC);

        DMT_W2_BAL_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);

        DMT_W2_BAL_TRANSFORM_PKG.TRANSFORM_W2BALANCES(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;
        DMT_W2_BAL_VALIDATOR_PKG.VALIDATE_POST_TRANSFORM(p_run_id);

        DMT_W2_BAL_HDL_GEN_PKG.GENERATE_HDL(p_run_id, l_hdl_zip, l_filename, l_csv_id);
        COMMIT;

        IF l_hdl_zip IS NULL OR DBMS_LOB.GETLENGTH(l_hdl_zip) = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id, 'No W2Balance rows to load. Skipping.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
            RETURN;
        END IF;

        l_content_id := DMT_HDL_UTIL_PKG.UPLOAD_HDL(p_run_id, l_hdl_zip, l_filename, 'W2Balances');
        DBMS_LOB.FREETEMPORARY(l_hdl_zip);
        l_request_id := DMT_HDL_UTIL_PKG.SUBMIT_HDL(p_run_id, l_content_id,
            'DMT W2Balances ' || TO_CHAR(p_run_id), 'W2Balances');
        COMMIT;

        DMT_HDL_UTIL_PKG.POLL_HDL(p_run_id, l_request_id, 1800, FALSE, 'W2Balances', l_dataset_status);
        DMT_W2_BAL_RESULTS_PKG.RECONCILE_BATCH(p_run_id, l_request_id, l_dataset_status);

        DMT_UTIL_PKG.LOG(p_run_id, 'RUN_W2_BALANCES complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'RUN_W2_BALANCES failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_W2_BALANCES;

    -- --------------------------------------------------------
    -- RUN_BEN_PARTICIPANT (public) — HDL pattern
    -- --------------------------------------------------------
    PROCEDURE RUN_BEN_PARTICIPANT (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC      CONSTANT VARCHAR2(30) := 'RUN_BEN_PARTICIPANT';
        l_hdl_zip   BLOB;
        l_filename  VARCHAR2(200);
        l_csv_id    NUMBER;
        l_content_id    VARCHAR2(100);
        l_request_id    VARCHAR2(100);
        l_dataset_status VARCHAR2(50);
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_BEN_PARTICIPANT start. Integration ID: ' || p_run_id,
            'INFO', C_PKG, C_PROC);

        DMT_BEN_PARTIC_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);

        DMT_BEN_PARTIC_TRANSFORM_PKG.TRANSFORM_PARTICIPANTENROLLMENTS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;
        DMT_BEN_PARTIC_VALIDATOR_PKG.VALIDATE_POST_TRANSFORM(p_run_id);

        DMT_BEN_PARTIC_HDL_GEN_PKG.GENERATE_HDL(p_run_id, l_hdl_zip, l_filename, l_csv_id);
        COMMIT;

        IF l_hdl_zip IS NULL OR DBMS_LOB.GETLENGTH(l_hdl_zip) = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id, 'No ParticipantEnrollment rows to load. Skipping.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
            RETURN;
        END IF;

        l_content_id := DMT_HDL_UTIL_PKG.UPLOAD_HDL(p_run_id, l_hdl_zip, l_filename, 'BenParticipant');
        DBMS_LOB.FREETEMPORARY(l_hdl_zip);
        l_request_id := DMT_HDL_UTIL_PKG.SUBMIT_HDL(p_run_id, l_content_id,
            'DMT BenParticipant ' || TO_CHAR(p_run_id), 'BenParticipant');
        COMMIT;

        DMT_HDL_UTIL_PKG.POLL_HDL(p_run_id, l_request_id, 1800, FALSE, 'BenParticipant', l_dataset_status);
        DMT_BEN_PARTIC_RESULTS_PKG.RECONCILE_BATCH(p_run_id, l_request_id, l_dataset_status);

        DMT_UTIL_PKG.LOG(p_run_id, 'RUN_BEN_PARTICIPANT complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'RUN_BEN_PARTICIPANT failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_BEN_PARTICIPANT;

    -- --------------------------------------------------------
    -- RUN_BEN_DEPENDENT (public) — HDL pattern
    -- --------------------------------------------------------
    PROCEDURE RUN_BEN_DEPENDENT (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC      CONSTANT VARCHAR2(30) := 'RUN_BEN_DEPENDENT';
        l_hdl_zip   BLOB;
        l_filename  VARCHAR2(200);
        l_csv_id    NUMBER;
        l_content_id    VARCHAR2(100);
        l_request_id    VARCHAR2(100);
        l_dataset_status VARCHAR2(50);
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_BEN_DEPENDENT start. Integration ID: ' || p_run_id,
            'INFO', C_PKG, C_PROC);

        DMT_BEN_DEPEND_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);

        DMT_BEN_DEPEND_TRANSFORM_PKG.TRANSFORM_DEPENDENTENROLLMENTS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;
        DMT_BEN_DEPEND_VALIDATOR_PKG.VALIDATE_POST_TRANSFORM(p_run_id);

        DMT_BEN_DEPEND_HDL_GEN_PKG.GENERATE_HDL(p_run_id, l_hdl_zip, l_filename, l_csv_id);
        COMMIT;

        IF l_hdl_zip IS NULL OR DBMS_LOB.GETLENGTH(l_hdl_zip) = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id, 'No DependentEnrollment rows to load. Skipping.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
            RETURN;
        END IF;

        l_content_id := DMT_HDL_UTIL_PKG.UPLOAD_HDL(p_run_id, l_hdl_zip, l_filename, 'BenDependent');
        DBMS_LOB.FREETEMPORARY(l_hdl_zip);
        l_request_id := DMT_HDL_UTIL_PKG.SUBMIT_HDL(p_run_id, l_content_id,
            'DMT BenDependent ' || TO_CHAR(p_run_id), 'BenDependent');
        COMMIT;

        DMT_HDL_UTIL_PKG.POLL_HDL(p_run_id, l_request_id, 1800, FALSE, 'BenDependent', l_dataset_status);
        DMT_BEN_DEPEND_RESULTS_PKG.RECONCILE_BATCH(p_run_id, l_request_id, l_dataset_status);

        DMT_UTIL_PKG.LOG(p_run_id, 'RUN_BEN_DEPENDENT complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'RUN_BEN_DEPENDENT failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_BEN_DEPENDENT;

    -- --------------------------------------------------------
    -- RUN_BEN_BENEFICIARY (public) — HDL pattern
    -- --------------------------------------------------------
    PROCEDURE RUN_BEN_BENEFICIARY (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC      CONSTANT VARCHAR2(30) := 'RUN_BEN_BENEFICIARY';
        l_hdl_zip   BLOB;
        l_filename  VARCHAR2(200);
        l_csv_id    NUMBER;
        l_content_id    VARCHAR2(100);
        l_request_id    VARCHAR2(100);
        l_dataset_status VARCHAR2(50);
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_BEN_BENEFICIARY start. Integration ID: ' || p_run_id,
            'INFO', C_PKG, C_PROC);

        DMT_BEN_BENFY_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);

        DMT_BEN_BENFY_TRANSFORM_PKG.TRANSFORM_BENEFICIARYDESIGNATIONS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;
        DMT_BEN_BENFY_VALIDATOR_PKG.VALIDATE_POST_TRANSFORM(p_run_id);

        DMT_BEN_BENFY_HDL_GEN_PKG.GENERATE_HDL(p_run_id, l_hdl_zip, l_filename, l_csv_id);
        COMMIT;

        IF l_hdl_zip IS NULL OR DBMS_LOB.GETLENGTH(l_hdl_zip) = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id, 'No BeneficiaryDesignation rows to load. Skipping.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
            RETURN;
        END IF;

        l_content_id := DMT_HDL_UTIL_PKG.UPLOAD_HDL(p_run_id, l_hdl_zip, l_filename, 'BenBeneficiary');
        DBMS_LOB.FREETEMPORARY(l_hdl_zip);
        l_request_id := DMT_HDL_UTIL_PKG.SUBMIT_HDL(p_run_id, l_content_id,
            'DMT BenBeneficiary ' || TO_CHAR(p_run_id), 'BenBeneficiary');
        COMMIT;

        DMT_HDL_UTIL_PKG.POLL_HDL(p_run_id, l_request_id, 1800, FALSE, 'BenBeneficiary', l_dataset_status);
        DMT_BEN_BENFY_RESULTS_PKG.RECONCILE_BATCH(p_run_id, l_request_id, l_dataset_status);

        DMT_UTIL_PKG.LOG(p_run_id, 'RUN_BEN_BENEFICIARY complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'RUN_BEN_BENEFICIARY failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_BEN_BENEFICIARY;

    -- --------------------------------------------------------
    -- RUN_PAYROLL_RELS (public) — HDL pattern
    -- --------------------------------------------------------
    PROCEDURE RUN_PAYROLL_RELS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC      CONSTANT VARCHAR2(30) := 'RUN_PAYROLL_RELS';
        l_hdl_zip   BLOB;
        l_filename  VARCHAR2(200);
        l_csv_id    NUMBER;
        l_content_id    VARCHAR2(100);
        l_request_id    VARCHAR2(100);
        l_dataset_status VARCHAR2(50);
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_PAYROLL_RELS start. Integration ID: ' || p_run_id,
            'INFO', C_PKG, C_PROC);

        DMT_PAY_REL_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);

        DMT_PAY_REL_TRANSFORM_PKG.TRANSFORM_PAYROLLRELATIONSHIPS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;
        DMT_PAY_REL_VALIDATOR_PKG.VALIDATE_POST_TRANSFORM(p_run_id);

        DMT_PAY_REL_HDL_GEN_PKG.GENERATE_HDL(p_run_id, l_hdl_zip, l_filename, l_csv_id);
        COMMIT;

        IF l_hdl_zip IS NULL OR DBMS_LOB.GETLENGTH(l_hdl_zip) = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id, 'No PayrollRelationship rows to load. Skipping.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
            RETURN;
        END IF;

        l_content_id := DMT_HDL_UTIL_PKG.UPLOAD_HDL(p_run_id, l_hdl_zip, l_filename, 'PayrollRels');
        DBMS_LOB.FREETEMPORARY(l_hdl_zip);
        l_request_id := DMT_HDL_UTIL_PKG.SUBMIT_HDL(p_run_id, l_content_id,
            'DMT PayrollRels ' || TO_CHAR(p_run_id), 'PayrollRels');
        COMMIT;

        DMT_HDL_UTIL_PKG.POLL_HDL(p_run_id, l_request_id, 1800, FALSE, 'PayrollRels', l_dataset_status);
        DMT_PAY_REL_RESULTS_PKG.RECONCILE_BATCH(p_run_id, l_request_id, l_dataset_status);

        DMT_UTIL_PKG.LOG(p_run_id, 'RUN_PAYROLL_RELS complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'RUN_PAYROLL_RELS failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_PAYROLL_RELS;

    -- --------------------------------------------------------
    -- RUN_TAX_CARDS (public) — HDL pattern
    -- --------------------------------------------------------
    PROCEDURE RUN_TAX_CARDS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC      CONSTANT VARCHAR2(30) := 'RUN_TAX_CARDS';
        l_hdl_zip   BLOB;
        l_filename  VARCHAR2(200);
        l_csv_id    NUMBER;
        l_content_id    VARCHAR2(100);
        l_request_id    VARCHAR2(100);
        l_dataset_status VARCHAR2(50);
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_TAX_CARDS start. Integration ID: ' || p_run_id,
            'INFO', C_PKG, C_PROC);

        DMT_TAX_CARD_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);

        DMT_TAX_CARD_TRANSFORM_PKG.TRANSFORM_TAXCARDS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;
        DMT_TAX_CARD_VALIDATOR_PKG.VALIDATE_POST_TRANSFORM(p_run_id);

        DMT_TAX_CARD_HDL_GEN_PKG.GENERATE_HDL(p_run_id, l_hdl_zip, l_filename, l_csv_id);
        COMMIT;

        IF l_hdl_zip IS NULL OR DBMS_LOB.GETLENGTH(l_hdl_zip) = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id, 'No TaxCard rows to load. Skipping.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
            RETURN;
        END IF;

        l_content_id := DMT_HDL_UTIL_PKG.UPLOAD_HDL(p_run_id, l_hdl_zip, l_filename, 'TaxCards');
        DBMS_LOB.FREETEMPORARY(l_hdl_zip);
        l_request_id := DMT_HDL_UTIL_PKG.SUBMIT_HDL(p_run_id, l_content_id,
            'DMT TaxCards ' || TO_CHAR(p_run_id), 'TaxCards');
        COMMIT;

        DMT_HDL_UTIL_PKG.POLL_HDL(p_run_id, l_request_id, 1800, FALSE, 'TaxCards', l_dataset_status);
        DMT_TAX_CARD_RESULTS_PKG.RECONCILE_BATCH(p_run_id, l_request_id, l_dataset_status);

        DMT_UTIL_PKG.LOG(p_run_id, 'RUN_TAX_CARDS complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'RUN_TAX_CARDS failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_TAX_CARDS;

    -- --------------------------------------------------------
    -- RUN_TALENT_PROFILES (public) — HDL pattern
    -- --------------------------------------------------------
    PROCEDURE RUN_TALENT_PROFILES (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC      CONSTANT VARCHAR2(30) := 'RUN_TALENT_PROFILES';
        l_hdl_zip   BLOB;
        l_filename  VARCHAR2(200);
        l_csv_id    NUMBER;
        l_content_id    VARCHAR2(100);
        l_request_id    VARCHAR2(100);
        l_dataset_status VARCHAR2(50);
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_TALENT_PROFILES start. Integration ID: ' || p_run_id,
            'INFO', C_PKG, C_PROC);

        DMT_TALENT_PROF_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);

        DMT_TALENT_PROF_TRANSFORM_PKG.TRANSFORM_TALENTPROFILES(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;
        DMT_TALENT_PROF_VALIDATOR_PKG.VALIDATE_POST_TRANSFORM(p_run_id);

        DMT_TALENT_PROF_HDL_GEN_PKG.GENERATE_HDL(p_run_id, l_hdl_zip, l_filename, l_csv_id);
        COMMIT;

        IF l_hdl_zip IS NULL OR DBMS_LOB.GETLENGTH(l_hdl_zip) = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id, 'No TalentProfile rows to load. Skipping.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
            RETURN;
        END IF;

        l_content_id := DMT_HDL_UTIL_PKG.UPLOAD_HDL(p_run_id, l_hdl_zip, l_filename, 'TalentProfiles');
        DBMS_LOB.FREETEMPORARY(l_hdl_zip);
        l_request_id := DMT_HDL_UTIL_PKG.SUBMIT_HDL(p_run_id, l_content_id,
            'DMT TalentProfiles ' || TO_CHAR(p_run_id), 'TalentProfiles');
        COMMIT;

        DMT_HDL_UTIL_PKG.POLL_HDL(p_run_id, l_request_id, 1800, FALSE, 'TalentProfiles', l_dataset_status);
        DMT_TALENT_PROF_RESULTS_PKG.RECONCILE_BATCH(p_run_id, l_request_id, l_dataset_status);

        DMT_UTIL_PKG.LOG(p_run_id, 'RUN_TALENT_PROFILES complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'RUN_TALENT_PROFILES failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_TALENT_PROFILES;

    -- --------------------------------------------------------
    -- RUN_PERF_EVALUATIONS (public) — HDL pattern
    -- --------------------------------------------------------
    PROCEDURE RUN_PERF_EVALUATIONS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC      CONSTANT VARCHAR2(30) := 'RUN_PERF_EVALUATIONS';
        l_hdl_zip   BLOB;
        l_filename  VARCHAR2(200);
        l_csv_id    NUMBER;
        l_content_id    VARCHAR2(100);
        l_request_id    VARCHAR2(100);
        l_dataset_status VARCHAR2(50);
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_PERF_EVALUATIONS start. Integration ID: ' || p_run_id,
            'INFO', C_PKG, C_PROC);

        DMT_PERF_EVAL_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);

        DMT_PERF_EVAL_TRANSFORM_PKG.TRANSFORM_PERFORMANCEDOCUMENTS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;
        DMT_PERF_EVAL_VALIDATOR_PKG.VALIDATE_POST_TRANSFORM(p_run_id);

        DMT_PERF_EVAL_HDL_GEN_PKG.GENERATE_HDL(p_run_id, l_hdl_zip, l_filename, l_csv_id);
        COMMIT;

        IF l_hdl_zip IS NULL OR DBMS_LOB.GETLENGTH(l_hdl_zip) = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id, 'No PerformanceEval rows to load. Skipping.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
            RETURN;
        END IF;

        l_content_id := DMT_HDL_UTIL_PKG.UPLOAD_HDL(p_run_id, l_hdl_zip, l_filename, 'PerfEvaluations');
        DBMS_LOB.FREETEMPORARY(l_hdl_zip);
        l_request_id := DMT_HDL_UTIL_PKG.SUBMIT_HDL(p_run_id, l_content_id,
            'DMT PerfEvaluations ' || TO_CHAR(p_run_id), 'PerfEvaluations');
        COMMIT;

        DMT_HDL_UTIL_PKG.POLL_HDL(p_run_id, l_request_id, 1800, FALSE, 'PerfEvaluations', l_dataset_status);
        DMT_PERF_EVAL_RESULTS_PKG.RECONCILE_BATCH(p_run_id, l_request_id, l_dataset_status);

        DMT_UTIL_PKG.LOG(p_run_id, 'RUN_PERF_EVALUATIONS complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'RUN_PERF_EVALUATIONS failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_PERF_EVALUATIONS;

    -- --------------------------------------------------------
    -- RUN_WORK_SCHEDULES (public) — HDL pattern
    -- --------------------------------------------------------
    PROCEDURE RUN_WORK_SCHEDULES (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC      CONSTANT VARCHAR2(30) := 'RUN_WORK_SCHEDULES';
        l_hdl_zip   BLOB;
        l_filename  VARCHAR2(200);
        l_csv_id    NUMBER;
        l_content_id    VARCHAR2(100);
        l_request_id    VARCHAR2(100);
        l_dataset_status VARCHAR2(50);
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_WORK_SCHEDULES start. Integration ID: ' || p_run_id,
            'INFO', C_PKG, C_PROC);

        DMT_WORK_SCHED_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);

        DMT_WORK_SCHED_TRANSFORM_PKG.TRANSFORM_WORKSCHEDULES(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;
        DMT_WORK_SCHED_VALIDATOR_PKG.VALIDATE_POST_TRANSFORM(p_run_id);

        DMT_WORK_SCHED_HDL_GEN_PKG.GENERATE_HDL(p_run_id, l_hdl_zip, l_filename, l_csv_id);
        COMMIT;

        IF l_hdl_zip IS NULL OR DBMS_LOB.GETLENGTH(l_hdl_zip) = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id, 'No WorkSchedule rows to load. Skipping.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
            RETURN;
        END IF;

        l_content_id := DMT_HDL_UTIL_PKG.UPLOAD_HDL(p_run_id, l_hdl_zip, l_filename, 'WorkSchedules');
        DBMS_LOB.FREETEMPORARY(l_hdl_zip);
        l_request_id := DMT_HDL_UTIL_PKG.SUBMIT_HDL(p_run_id, l_content_id,
            'DMT WorkSchedules ' || TO_CHAR(p_run_id), 'WorkSchedules');
        COMMIT;

        DMT_HDL_UTIL_PKG.POLL_HDL(p_run_id, l_request_id, 1800, FALSE, 'WorkSchedules', l_dataset_status);
        DMT_WORK_SCHED_RESULTS_PKG.RECONCILE_BATCH(p_run_id, l_request_id, l_dataset_status);

        DMT_UTIL_PKG.LOG(p_run_id, 'RUN_WORK_SCHEDULES complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'RUN_WORK_SCHEDULES failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_WORK_SCHEDULES;

    -- --------------------------------------------------------
    -- RUN_GL_BALANCES (public) — FBDI pattern
    -- --------------------------------------------------------
    PROCEDURE RUN_GL_BALANCES (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RUN_GL_BALANCES';
        l_dummy BOOLEAN;
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_GL_BALANCES start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);
        l_dummy := run_one_object_type(p_run_id, 'GLBalances', v_scenario_id, p_run_mode, p_skip_bu_refresh);
        COMMIT;
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_GL_BALANCES complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'RUN_GL_BALANCES failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_GL_BALANCES;

    -- --------------------------------------------------------
    -- RUN_GL_BUDGETS (public) — FBDI pattern
    -- --------------------------------------------------------
    PROCEDURE RUN_GL_BUDGETS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RUN_GL_BUDGETS';
        l_dummy BOOLEAN;
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_GL_BUDGETS start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);
        l_dummy := run_one_object_type(p_run_id, 'GLBudgetBalances', v_scenario_id, p_run_mode, p_skip_bu_refresh);
        COMMIT;
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_GL_BUDGETS complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'RUN_GL_BUDGETS failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_GL_BUDGETS;

    -- --------------------------------------------------------
    -- RUN_PLAN_BUDGETS (public) — FBDI pattern
    -- --------------------------------------------------------
    PROCEDURE RUN_PLAN_BUDGETS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RUN_PLAN_BUDGETS';
        l_dummy BOOLEAN;
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_PLAN_BUDGETS start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);
        l_dummy := run_one_object_type(p_run_id, 'PlanningBudgets', v_scenario_id, p_run_mode, p_skip_bu_refresh);
        COMMIT;
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_PLAN_BUDGETS complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'RUN_PLAN_BUDGETS failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_PLAN_BUDGETS;

    -- --------------------------------------------------------
    -- RUN_PROJECT_BUDGETS (public) — FBDI pattern
    -- --------------------------------------------------------
    PROCEDURE RUN_PROJECT_BUDGETS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RUN_PROJECT_BUDGETS';
        l_dummy BOOLEAN;
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_PROJECT_BUDGETS start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);
        l_dummy := run_one_object_type(p_run_id, 'ProjectBudgets', v_scenario_id, p_run_mode, p_skip_bu_refresh);
        COMMIT;
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_PROJECT_BUDGETS complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'RUN_PROJECT_BUDGETS failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_PROJECT_BUDGETS;

    -- --------------------------------------------------------
    -- RUN_ASSETS (public) — FBDI pattern
    -- --------------------------------------------------------
    PROCEDURE RUN_ASSETS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RUN_ASSETS';
        l_dummy BOOLEAN;
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_ASSETS start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);
        l_dummy := run_one_object_type(p_run_id, 'Assets', v_scenario_id, p_run_mode, p_skip_bu_refresh);
        COMMIT;
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_ASSETS complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'RUN_ASSETS failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_ASSETS;

    -- --------------------------------------------------------
    -- RUN_ASSETS_TRANSFORM_ONLY — multi-book split support.
    -- Validate + transform STG -> TFM (STAGED). No generate/submit.
    -- The queue worker then splits into one child row per BOOK_TYPE_CODE.
    -- --------------------------------------------------------
    PROCEDURE RUN_ASSETS_TRANSFORM_ONLY (
        p_run_id           IN NUMBER,
        p_scenario_name    IN VARCHAR2 DEFAULT NULL,
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        C_PROC CONSTANT VARCHAR2(40) := 'RUN_ASSETS_TRANSFORM_ONLY';
        v_scenario_id NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id, 'RUN_ASSETS_TRANSFORM_ONLY start.', 'INFO', C_PKG, C_PROC);
        DMT_FA_ASSET_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
        COMMIT;
        DMT_FA_ASSET_TRANSFORM_PKG.TRANSFORM_HEADERS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_FA_ASSET_TRANSFORM_PKG.TRANSFORM_ASSIGNMENTS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_FA_ASSET_TRANSFORM_PKG.TRANSFORM_BOOKS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;
        DMT_UTIL_PKG.LOG(p_run_id, 'RUN_ASSETS_TRANSFORM_ONLY complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'RUN_ASSETS_TRANSFORM_ONLY failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_ASSETS_TRANSFORM_ONLY;

    -- --------------------------------------------------------
    -- RUN_PROJECT_PIPELINE
    -- Full Project pipeline: projects → billing events → expenditures → grants → project budgets.
    -- Creates a new CONVERSION_MASTER row.
    -- --------------------------------------------------------
    PROCEDURE RUN_PROJECT_PIPELINE (x_run_id OUT NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW') IS
        C_PROC           CONSTANT VARCHAR2(30) := 'RUN_PROJECT_PIPELINE';
        l_run_id NUMBER;
        l_prefix         VARCHAR2(20);
        v_scenario_id    NUMBER;
        l_projects_loaded NUMBER := 0;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);

        SELECT DMT_OWNER.DMT_PIPELINE_RUN_SEQ.NEXTVAL INTO l_run_id FROM DUAL;
        SELECT TO_CHAR(DMT_OWNER.DMT_RUN_PREFIX_SEQ.NEXTVAL) INTO l_prefix FROM DUAL;

        INSERT INTO DMT_OWNER.DMT_PIPELINE_RUN_TBL (
            RUN_ID, INTEGRATION_ID, PIPELINE_CODES, RUN_TYPE,
            SUBMITTED_BY, RUN_STATUS, PREFIX, CEMLI_SEQUENCE,
            SCENARIO_NAME, RUN_MODE
        ) VALUES (
            l_run_id, l_run_id, 'Projects', 'PIPELINE',
            'MANUAL', 'IN_PROGRESS', l_prefix,
            'Projects,ProjectTasks,ProjectTeamMembers,TransactionControls,BillingEvents,Expenditures',
            p_scenario_name, p_run_mode
        );
        COMMIT;

        x_run_id := l_run_id;

        DMT_UTIL_PKG.LOG(l_run_id,
            'RUN_PROJECT_PIPELINE start. Integration ID: ' || l_run_id ||
            ' | Prefix: ' || l_prefix, 'INFO', C_PKG, C_PROC);

        DMT_UTIL_PKG.REFRESH_BU_LOOKUPS;

        -- Projects must run first — all downstream objects depend on projects being LOADED.
        RUN_PROJECTS(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);

        -- Check if any projects reached LOADED. If zero, skip all downstream objects.
        SELECT COUNT(*) INTO l_projects_loaded
        FROM   DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL
        WHERE  RUN_ID = l_run_id
        AND    TFM_STATUS = 'LOADED';

        IF l_projects_loaded = 0 THEN
            DMT_UTIL_PKG.LOG(l_run_id,
                'No projects reached LOADED status. Skipping downstream objects ' ||
                '(BillingEvents, Expenditures, Grants, ProjectBudgets).',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
        ELSE
            DMT_UTIL_PKG.LOG(l_run_id,
                l_projects_loaded || ' project(s) LOADED. Proceeding with downstream objects.',
                'INFO', C_PKG, C_PROC);
            RUN_BILLING_EVENTS(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);
            RUN_EXPENDITURES(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);
            RUN_GRANTS(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);
            RUN_PROJECT_BUDGETS(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);
        END IF;

        COMMIT;

        DMT_UTIL_PKG.LOG(l_run_id,
            'RUN_PROJECT_PIPELINE complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            IF l_run_id IS NOT NULL THEN
                DMT_UTIL_PKG.LOG_ERROR(l_run_id,
                    'RUN_PROJECT_PIPELINE failed.', SQLERRM, C_PKG, C_PROC);
                COMMIT;
            END IF;
            RAISE;
    END RUN_PROJECT_PIPELINE;

    -- --------------------------------------------------------
    -- RUN_HCM_PIPELINE
    -- Full HCM pipeline: all 14 HDL object types in dependency order.
    -- Creates a new CONVERSION_MASTER row.
    -- --------------------------------------------------------
    PROCEDURE RUN_HCM_PIPELINE (x_run_id OUT NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW') IS
        C_PROC           CONSTANT VARCHAR2(30) := 'RUN_HCM_PIPELINE';
        l_run_id NUMBER;
        l_prefix         VARCHAR2(20);
        v_scenario_id    NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);

        SELECT DMT_OWNER.DMT_PIPELINE_RUN_SEQ.NEXTVAL INTO l_run_id FROM DUAL;
        SELECT TO_CHAR(DMT_OWNER.DMT_RUN_PREFIX_SEQ.NEXTVAL) INTO l_prefix FROM DUAL;

        INSERT INTO DMT_OWNER.DMT_PIPELINE_RUN_TBL (
            RUN_ID, INTEGRATION_ID, PIPELINE_CODES, RUN_TYPE,
            SUBMITTED_BY, RUN_STATUS, PREFIX, CEMLI_SEQUENCE,
            SCENARIO_NAME, RUN_MODE
        ) VALUES (
            l_run_id, l_run_id, 'HCM', 'PIPELINE',
            'MANUAL', 'IN_PROGRESS', l_prefix,
            'Workers,Assignments,Salaries,SalaryBases,PayrollRels,TaxCards,W2Balances,BenParticipant,BenDependent,BenBeneficiary,Absences',
            p_scenario_name, p_run_mode
        );
        COMMIT;

        x_run_id := l_run_id;

        DMT_UTIL_PKG.LOG(l_run_id,
            'RUN_HCM_PIPELINE start. Integration ID: ' || l_run_id ||
            ' | Prefix: ' || l_prefix, 'INFO', C_PKG, C_PROC);

        DMT_UTIL_PKG.REFRESH_BU_LOOKUPS;

        -- Workers first (master data — all other HCM objects depend on workers)
        RUN_WORKERS(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);

        -- Assignments depend on workers
        RUN_ASSIGNMENTS(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);

        -- Salary and salary basis depend on assignments
        RUN_SALARIES(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);
        RUN_SALARY_BASES(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);

        -- Payroll relationships depend on workers
        RUN_PAYROLL_RELS(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);

        -- Tax cards depend on payroll relationships
        RUN_TAX_CARDS(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);

        -- W-2 balances depend on payroll relationships
        RUN_W2_BALANCES(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);

        -- Benefits depend on workers
        RUN_BEN_PARTICIPANT(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);
        RUN_BEN_DEPENDENT(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);
        RUN_BEN_BENEFICIARY(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);

        -- Absences depend on workers
        RUN_ABSENCES(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);

        -- Talent and performance depend on workers
        RUN_TALENT_PROFILES(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);
        RUN_PERF_EVALUATIONS(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);

        -- Work schedules are independent
        RUN_WORK_SCHEDULES(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);

        COMMIT;

        DMT_UTIL_PKG.LOG(l_run_id,
            'RUN_HCM_PIPELINE complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            IF l_run_id IS NOT NULL THEN
                DMT_UTIL_PKG.LOG_ERROR(l_run_id,
                    'RUN_HCM_PIPELINE failed.', SQLERRM, C_PKG, C_PROC);
                COMMIT;
            END IF;
            RAISE;
    END RUN_HCM_PIPELINE;

    -- --------------------------------------------------------
    -- RUN_FINANCIALS_PIPELINE
    -- Full Financials pipeline: GL → GL Budget → Assets.
    -- PlanningBudgets (EPBCS) is DORMANT — no ERP-options seed exists for it on this
    -- instance, so it is intentionally excluded here and from the scheduler queue list.
    -- Re-add it once EPBCS UCM/ESS-job metadata is discovered and seeded.
    -- Creates a new CONVERSION_MASTER row.
    -- --------------------------------------------------------
    PROCEDURE RUN_FINANCIALS_PIPELINE (x_run_id OUT NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW') IS
        C_PROC           CONSTANT VARCHAR2(30) := 'RUN_FINANCIALS_PIPELINE';
        l_run_id NUMBER;
        l_prefix         VARCHAR2(20);
        v_scenario_id    NUMBER;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);

        SELECT DMT_OWNER.DMT_PIPELINE_RUN_SEQ.NEXTVAL INTO l_run_id FROM DUAL;
        SELECT TO_CHAR(DMT_OWNER.DMT_RUN_PREFIX_SEQ.NEXTVAL) INTO l_prefix FROM DUAL;

        INSERT INTO DMT_OWNER.DMT_PIPELINE_RUN_TBL (
            RUN_ID, INTEGRATION_ID, PIPELINE_CODES, RUN_TYPE,
            SUBMITTED_BY, RUN_STATUS, PREFIX, CEMLI_SEQUENCE,
            SCENARIO_NAME, RUN_MODE
        ) VALUES (
            l_run_id, l_run_id, 'Financials', 'PIPELINE',
            'MANUAL', 'IN_PROGRESS', l_prefix,
            'GLBalances,GLBudgets,Assets',
            p_scenario_name, p_run_mode
        );
        COMMIT;

        x_run_id := l_run_id;

        DMT_UTIL_PKG.LOG(l_run_id,
            'RUN_FINANCIALS_PIPELINE start. Integration ID: ' || l_run_id ||
            ' | Prefix: ' || l_prefix, 'INFO', C_PKG, C_PROC);

        DMT_UTIL_PKG.REFRESH_BU_LOOKUPS;

        RUN_GL_BALANCES(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);
        RUN_GL_BUDGETS(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);
        -- RUN_PLAN_BUDGETS intentionally not called — PlanningBudgets is DORMANT (no ERP-options
        -- seed on this instance). Procedure retained for future activation once EPBCS is seeded.
        RUN_ASSETS(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);

        COMMIT;

        DMT_UTIL_PKG.LOG(l_run_id,
            'RUN_FINANCIALS_PIPELINE complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            IF l_run_id IS NOT NULL THEN
                DMT_UTIL_PKG.LOG_ERROR(l_run_id,
                    'RUN_FINANCIALS_PIPELINE failed.', SQLERRM, C_PKG, C_PROC);
                COMMIT;
            END IF;
            RAISE;
    END RUN_FINANCIALS_PIPELINE;

END DMT_LOADER_PKG;
/
