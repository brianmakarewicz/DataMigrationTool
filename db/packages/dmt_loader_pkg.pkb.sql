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
    -- DECODE_PARTITION_KEY — the ONE decoder for JSON-encoded spawn partition
    -- keys (work-queue-ID core, 2026-07-20). A real spawn child's PARTITION_KEY
    -- is a JSON object keyed by the partition column name, e.g.
    -- {"BATCH_ID":"8102"}; the consuming generator asks for the scalar it needs
    -- by column name and binds it into its existing static cursor. The two
    -- sentinels are never JSON: NULL (parent / no partition) and 'ALL' (in-zip
    -- non-spawn split) pass through unchanged so parent-detection and the ALL
    -- path behave exactly as before.
    -- --------------------------------------------------------
    FUNCTION DECODE_PARTITION_KEY (
        p_partition_key IN VARCHAR2,
        p_column        IN VARCHAR2
    ) RETURN VARCHAR2 IS
    BEGIN
        IF p_partition_key IS NULL OR p_partition_key = 'ALL' THEN
            RETURN p_partition_key;
        END IF;
        RETURN JSON_VALUE(p_partition_key, '$.' || p_column);
    END DECODE_PARTITION_KEY;

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
        FROM   DMT_ERP_INTERFACE_OPTIONS_TBL
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
        l_param_xml    VARCHAR2(8000);
        l_rest         VARCHAR2(4000);
        l_pos          PLS_INTEGER;
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

        -- submitESSJobRequest takes the ParameterList as a REPEATED element -- one
        -- <typ:paramList> per positional argument. Emitting the whole list as a single
        -- element makes Fusion read it as argument #1 only, so any multi-argument job
        -- (e.g. Expenditures' ImportProcessParallelEssJob, 13 args) fails inside the job
        -- with ORA-01008 "not all variables bound". Split on '~' and emit one element
        -- per token. A value with no '~' -> exactly one element, so single-argument
        -- callers (GL Budgets' Run Name, Assets' book code) are unchanged.
        l_param_xml := NULL;
        l_rest      := l_param_list;
        LOOP
            l_pos := INSTR(l_rest, '~');
            IF l_pos = 0 THEN
                l_param_xml := l_param_xml || '<typ:paramList>' || l_rest || '</typ:paramList>';
                EXIT;
            END IF;
            l_param_xml := l_param_xml
                || '<typ:paramList>' || SUBSTR(l_rest, 1, l_pos - 1) || '</typ:paramList>';
            l_rest := SUBSTR(l_rest, l_pos + 1);
        END LOOP;

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
                l_param_xml ||
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
    --   /Custom/DMT2/common/DMT_ESS_CHILD_JOB_RPT.xdo
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
        C_RPT_PATH    CONSTANT VARCHAR2(200) := '/Custom/DMT2/common/DMT_ESS_CHILD_JOB_RPT.xdo';
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
    -- run_one_object_type — DELETED (backlog #8, 2026-09).
    -- The per-object load monolith is fully retired. Every object now runs through
    -- its own self-contained RUN_<object>() recipe (validate/transform/generate +
    -- the shared phase helpers: sup_*, po_*, ar_*, fin_*). The generic dispatchers
    -- RUN_STANDALONE and RUN_TRANSFORM_ONLY route to those recipes (RUN_STANDALONE
    -- via the registered EXEC_PROC through DMT_QUEUE_WORKER_PKG.INVOKE_REGISTERED;
    -- RUN_TRANSFORM_ONLY via a static CASE over the spawn-per-partition objects).
    -- Nothing calls run_one_object_type any longer, so the function and its private
    -- nested submit_and_reconcile_one were removed.
    -- --------------------------------------------------------

    -- Shared helper (backlog #70, extended for non-partitioned objects): stamp THIS
    -- work item's own Load and Import ESS request ids onto its own work-queue row so
    -- the run-detail tiles show the real ids.
    --
    -- Keyed on g_gen_queue_id — the QUEUE_ID of the work item currently generating /
    -- loading, which EXECUTE_ONE sets UNCONDITIONALLY for EVERY object (a spawn
    -- child's own QUEUE_ID, or a non-partitioned single item's QUEUE_ID), and leaves
    -- NULL for a direct/standalone call outside the queue. This broadens the original
    -- partition-child-only stamping (which keyed on g_work_queue_id, NULL for
    -- non-partitioned objects) so that non-partitioned objects — MiscReceipts,
    -- grouped ARInvoices / Customers / PurchaseOrders, and the single-load Suppliers
    -- family — now also record their real load + import ess ids on the queue row
    -- instead of leaving those columns NULL (which the #70 tiles rendered as a
    -- skipped load). The NULL guard makes it a no-op for direct/standalone calls.
    --
    -- Only stamps when a Load ESS id is present, and only overwrites the import id
    -- when a new one is given, so for a grouped object that submits several loads on
    -- one queue row a failed group's NULL ids never wipe an earlier group's real ids
    -- (the last group with real ids wins — a representative id for the single tile).
    -- Static single-row UPDATE, no dynamic SQL. Defined here (ahead of the family
    -- helper blocks) so every inline load path below can call it.
    PROCEDURE stamp_item_ess_ids (
        p_load_ess_id   IN VARCHAR2,
        p_import_ess_id IN VARCHAR2
    ) IS
    BEGIN
        IF g_gen_queue_id IS NULL OR p_load_ess_id IS NULL THEN
            RETURN;
        END IF;
        UPDATE DMT_WORK_QUEUE_TBL
        SET    LOAD_ESS_JOB_ID   = SUBSTR(p_load_ess_id, 1, 30),
               IMPORT_ESS_JOB_ID = NVL(SUBSTR(p_import_ess_id, 1, 30), IMPORT_ESS_JOB_ID)
        WHERE  QUEUE_ID = g_gen_queue_id;
        COMMIT;
    END stamp_item_ess_ids;

    -- ========================================================================
    -- SUPPLIERS FAMILY — self-contained runners (backlog #8, first family).
    --
    -- The five supplier objects (Suppliers, SupplierAddresses, SupplierSites,
    -- SupplierSiteAssignments, SupplierContacts) NO LONGER route through the
    -- run_one_object_type p_cemli_code ladders. Each RUN_<object>() below is a
    -- self-contained recipe (the same shape as the config runners, e.g.
    -- DMT_CE_BANK_RUNNER_PKG.RUN): it calls its own validate + transform +
    -- generate directly and then hands the object-agnostic phases (submit,
    -- async-return / poll, load-failure marking, import, reconcile, row-count
    -- accounting) to the shared helpers in this block.
    --
    -- Behaviour is preserved byte-for-byte with the pre-refactor Suppliers path
    -- through run_one_object_type for BOTH modes it is invoked in:
    --   * ASYNC  — the queue worker (EXECUTE_ONE) sets g_async_mode = TRUE, so
    --              sup_after_generate submits the load and returns at the async
    --              gate (no poll / no inline reconcile). The queue then polls the
    --              load ESS job and later runs the registered RECON_PROC.
    --   * SYNC   — a direct RUN_SUPPLIERS / RUN_SUPPLIER_PIPELINE call leaves
    --              g_async_mode FALSE, so sup_after_generate polls the load,
    --              marks GENERATED rows FAILED on a load failure, submits+polls
    --              the import job, and reconciles inline via RECONCILE_VIA_REGISTRY.
    --
    -- Non-supplier objects still route through run_one_object_type unchanged.
    -- ========================================================================

    -- Shared helper: fail every GENERATED row in one supplier TFM table with a
    -- reportable [LOAD_ERROR] (mirrors the Suppliers arms of the retired
    -- mark-GENERATED-FAILED ladder). Object-agnostic — the TFM table name is the
    -- only per-object input. p_tfm_table is a validated identifier, never user data.
    -- Static per-object statements (design doc Coding Standards section: all
    -- runtime SQL in this package is static literal SQL, never dynamic). The
    -- helper selects the one literal statement for the caller's supplier CEMLI;
    -- each is identical to the original per-object arm in run_one_object_type.
    -- The p_cemli ELSE raises, so a mis-wired caller fails loudly, not silently.
    PROCEDURE sup_mark_generated_failed (
        p_run_id      IN NUMBER,
        p_cemli_code  IN VARCHAR2,
        p_load_ess_id IN VARCHAR2
    ) IS
        l_err_msg VARCHAR2(500) :=
            '[LOAD_ERROR] Loading data to the Fusion interface failed. Check ESS job '
            || p_load_ess_id || ' logs for details.';
    BEGIN
        IF    p_cemli_code = 'Suppliers' THEN
            UPDATE DMT_POZ_SUPPLIERS_TFM_TBL     SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED';
        ELSIF p_cemli_code = 'SupplierAddresses' THEN
            UPDATE DMT_POZ_SUP_ADDR_TFM_TBL      SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED';
        ELSIF p_cemli_code = 'SupplierSites' THEN
            UPDATE DMT_POZ_SUP_SITE_TFM_TBL      SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED';
        ELSIF p_cemli_code = 'SupplierSiteAssignments' THEN
            UPDATE DMT_POZ_SUP_SITE_ASSN_TFM_TBL SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED';
        ELSIF p_cemli_code = 'SupplierContacts' THEN
            UPDATE DMT_POZ_SUP_CONTACTS_TFM_TBL  SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED';
        ELSE
            RAISE_APPLICATION_ERROR(-20047,
                'sup_mark_generated_failed: unexpected CEMLI ''' || p_cemli_code || '''.');
        END IF;
        COMMIT;
    END sup_mark_generated_failed;

    -- Shared helper: count rows in one supplier TFM table at a given status
    -- (used for the still-GENERATED and FAILED accounting checks). Static per
    -- object — one literal SELECT per supplier TFM table, mirroring the original.
    FUNCTION sup_count_status (
        p_run_id     IN NUMBER,
        p_cemli_code IN VARCHAR2,
        p_status     IN VARCHAR2
    ) RETURN NUMBER IS
        l_cnt NUMBER;
    BEGIN
        IF    p_cemli_code = 'Suppliers' THEN
            SELECT COUNT(*) INTO l_cnt FROM DMT_POZ_SUPPLIERS_TFM_TBL     WHERE RUN_ID=p_run_id AND TFM_STATUS=p_status;
        ELSIF p_cemli_code = 'SupplierAddresses' THEN
            SELECT COUNT(*) INTO l_cnt FROM DMT_POZ_SUP_ADDR_TFM_TBL      WHERE RUN_ID=p_run_id AND TFM_STATUS=p_status;
        ELSIF p_cemli_code = 'SupplierSites' THEN
            SELECT COUNT(*) INTO l_cnt FROM DMT_POZ_SUP_SITE_TFM_TBL      WHERE RUN_ID=p_run_id AND TFM_STATUS=p_status;
        ELSIF p_cemli_code = 'SupplierSiteAssignments' THEN
            SELECT COUNT(*) INTO l_cnt FROM DMT_POZ_SUP_SITE_ASSN_TFM_TBL WHERE RUN_ID=p_run_id AND TFM_STATUS=p_status;
        ELSIF p_cemli_code = 'SupplierContacts' THEN
            SELECT COUNT(*) INTO l_cnt FROM DMT_POZ_SUP_CONTACTS_TFM_TBL  WHERE RUN_ID=p_run_id AND TFM_STATUS=p_status;
        ELSE
            RAISE_APPLICATION_ERROR(-20047,
                'sup_count_status: unexpected CEMLI ''' || p_cemli_code || '''.');
        END IF;
        RETURN l_cnt;
    END sup_count_status;

    -- Shared helper: everything after the FBDI zip is generated. Parameterised by
    -- the object's registered CEMLI code + label. Replicates the Suppliers slice
    -- of run_one_object_type's default single-load path (submit + stamp + async
    -- gate + poll + load-failure marking + import + reconcile + counts). Returns
    -- FALSE only for the empty-zip / load-failure skips, TRUE otherwise — exactly
    -- as the old function did for these objects.
    FUNCTION sup_after_generate (
        p_run_id    IN NUMBER,
        p_cemli_code        IN VARCHAR2,
        p_obj               IN VARCHAR2,          -- object label for logging
        p_zip               IN OUT NOCOPY BLOB,
        p_filename          IN VARCHAR2
    ) RETURN BOOLEAN IS
        C_PROC        CONSTANT VARCHAR2(40) := 'SUP_AFTER_GENERATE';
        l_ucm_account       VARCHAR2(200);
        l_job_name          VARCHAR2(500);
        l_interface_details NUMBER;
        l_ess_user          VARCHAR2(100);
        l_ess_pass          VARCHAR2(100);
        l_load_ess_id       VARCHAR2(100);
        l_import_ess_id     VARCHAR2(100);
        l_load_status       VARCHAR2(50);
        l_param_list        VARCHAR2(500) := 'NEW,N';  -- suppliers default
    BEGIN
        -- If no rows, skip this object type (mirrors the empty-zip guard).
        IF p_zip IS NULL OR DBMS_LOB.GETLENGTH(p_zip) = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'No rows for ' || p_cemli_code || '. Skipping.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, p_obj || ' > ' || C_PROC);
            RETURN FALSE;
        END IF;

        -- ERP options (UCM account, import job name, interface details id) + creds.
        get_erp_options(
            p_cemli_code           => p_cemli_code,
            x_ucm_account          => l_ucm_account,
            x_import_job_name      => l_job_name,
            x_interface_details_id => l_interface_details);
        DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS(p_cemli_code, l_ess_user, l_ess_pass);

        -- loadAndImportData — combined load+import single call.
        l_load_ess_id := SUBMIT_LOAD(
            p_run_id            => p_run_id,
            p_fbdi_zip          => p_zip,
            p_filename          => p_filename,
            p_job_name          => l_job_name,
            p_interface_details => l_interface_details,
            p_doc_account       => l_ucm_account,
            p_parameter_list    => l_param_list,
            p_log_context       => p_obj,
            p_username          => l_ess_user,
            p_password          => l_ess_pass);
        DBMS_LOB.FREETEMPORARY(p_zip);

        -- Stamp Load ESS job ID + parameter list on the ZIP row.
        UPDATE DMT_FBDI_ZIP_TBL
        SET    PARAMETER_LIST = l_param_list
        WHERE  RUN_ID = p_run_id
        AND    OBJECT_TYPE = SUBSTR(p_cemli_code, INSTR(p_cemli_code, '-') + 1);
        COMMIT;

        -- Async mode: stop here, let the queue poller handle ESS polling +
        -- reconciliation (this is the live path for every queue-driven run).
        IF g_async_mode THEN
            g_load_ess_id := l_load_ess_id;
            RETURN TRUE;
        END IF;

        -- ---- SYNC path (direct RUN_* / RUN_SUPPLIER_PIPELINE calls) ----

        -- Poll Load job.
        DMT_UTIL_PKG.LOG(p_run_id,
            'Polling Load ESS job: ' || l_load_ess_id, 'INFO', C_PKG, p_obj || ' > ' || C_PROC);
        POLL_ESS_JOB(p_run_id, l_load_ess_id, 1800, FALSE, p_obj, p_cemli_code, l_load_status,
                     p_username => l_ess_user, p_password => l_ess_pass);

        -- Load failed → no rows reached the interface table. Mark all GENERATED
        -- rows FAILED and return (no import job, no BIP).
        IF l_load_status NOT IN (C_STATUS_SUCCEEDED, C_STATUS_WARNING) THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'Load ESS ' || l_load_ess_id || ' returned ' || l_load_status ||
                '. No rows committed to interface table. Marking all GENERATED rows FAILED.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, p_obj || ' > ' || C_PROC);
            sup_mark_generated_failed(p_run_id, p_cemli_code, l_load_ess_id);
            RETURN FALSE;
        END IF;

        -- Find the Import ESS job ID.
        l_import_ess_id := get_import_ess_id(p_run_id, p_cemli_code, l_load_ess_id);
        COMMIT;

        -- Backlog #70 (non-partitioned): stamp this item's own load + import ess ids
        -- on its own queue row (no-op for a direct/standalone call, g_gen_queue_id NULL).
        stamp_item_ess_ids(l_load_ess_id, l_import_ess_id);

        -- Poll Import job — do NOT raise on error.
        DMT_UTIL_PKG.LOG(p_run_id,
            'Polling Import ESS job: ' || l_import_ess_id, 'INFO', C_PKG, p_obj || ' > ' || C_PROC);
        POLL_ESS_JOB(p_run_id, l_import_ess_id, 1800, FALSE, p_obj, p_cemli_code, l_load_status,
                     p_username => l_ess_user, p_password => l_ess_pass);

        -- Capture the Report child ESS job into the hierarchy (generic).
        DECLARE l_report_ess_id NUMBER;
        BEGIN
            l_report_ess_id := DMT_ESS_UTIL_PKG.CAPTURE_REPORT_ESS_JOB(
                p_run_id        => p_run_id,
                p_import_ess_id => TO_NUMBER(l_import_ess_id),
                p_cemli_code    => p_cemli_code);
        END;

        -- BIP reconciliation — single registry-driven dispatch.
        DMT_QUEUE_WORKER_PKG.RECONCILE_VIA_REGISTRY(
            p_run_id        => p_run_id,
            p_cemli_code    => p_cemli_code,
            p_load_ess_id   => TO_NUMBER(l_load_ess_id),
            p_import_ess_id => TO_NUMBER(l_import_ess_id),
            p_work_queue_id => g_work_queue_id);
        g_reconciled_inline := TRUE;

        -- Rows still GENERATED after reconciliation → warn + capture ESS output.
        DECLARE
            l_still_generated NUMBER;
        BEGIN
            l_still_generated := sup_count_status(p_run_id, p_cemli_code, 'GENERATED');
            IF l_still_generated > 0 THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    'WARNING: ' || l_still_generated ||
                    ' rows still at GENERATED after BIP reconciliation for ' || p_cemli_code ||
                    '. BIP query returned no matching rows for these records. ' ||
                    'Rows left at GENERATED for manual investigation — do NOT assume success.',
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, p_obj || ' > ' || C_PROC);
                IF l_import_ess_id IS NOT NULL THEN
                    DMT_ESS_UTIL_PKG.CAPTURE_ESS_OUTPUT(
                        p_run_id     => p_run_id,
                        p_request_id => TO_NUMBER(l_import_ess_id),
                        p_cemli_code => p_cemli_code);
                END IF;
            END IF;
        END;

        RETURN TRUE;
    END sup_after_generate;

    -- Shared tail: FAILED-row count warning + "object complete" log. Mirrors the
    -- grouped_finish tail of run_one_object_type for the Suppliers objects.
    PROCEDURE sup_finish (
        p_run_id     IN NUMBER,
        p_cemli_code IN VARCHAR2,
        p_obj        IN VARCHAR2
    ) IS
        C_PROC CONSTANT VARCHAR2(40) := 'SUP_FINISH';
        l_failed_count NUMBER;
    BEGIN
        l_failed_count := sup_count_status(p_run_id, p_cemli_code, 'FAILED');
        IF l_failed_count > 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                p_cemli_code || ': ' || l_failed_count || ' record(s) FAILED in Fusion. ' ||
                'Downstream object types will continue — check staging table for details.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, p_obj || ' > ' || C_PROC);
        END IF;
        DMT_UTIL_PKG.LOG(p_run_id,
            'Object type complete: ' || p_cemli_code, 'INFO', C_PKG, p_obj || ' > ' || C_PROC);
    END sup_finish;

    -- Shared preamble: BU-lookup refresh (standalone only) + object-start log.
    -- Mirrors the head of run_one_object_type before the per-object phases.
    PROCEDURE sup_preamble (
        p_run_id          IN NUMBER,
        p_cemli_code      IN VARCHAR2,
        p_obj             IN VARCHAR2,
        p_skip_bu_refresh IN BOOLEAN
    ) IS
        C_PROC CONSTANT VARCHAR2(40) := 'SUP_PREAMBLE';
    BEGIN
        IF NOT p_skip_bu_refresh THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'Refreshing BU lookups (standalone run).', 'INFO', C_PKG, p_obj || ' > ' || C_PROC);
            DMT_UTIL_PKG.REFRESH_BU_LOOKUPS;
        END IF;
        DMT_UTIL_PKG.LOG(p_run_id,
            'Object type start: ' || p_cemli_code, 'INFO', C_PKG, p_obj || ' > ' || C_PROC);
    END sup_preamble;

    -- ========================================================================
    -- PURCHASING FAMILY — self-contained runners (backlog #8, second family).
    --
    -- PurchaseOrders, BlanketPOs and Contracts NO LONGER route through the
    -- run_one_object_type p_cemli_code ladders. Each RUN_<object>() below is a
    -- self-contained recipe (same shape as the Suppliers runners): it calls its
    -- own validate + transform + per-BU generate directly and hands the
    -- object-agnostic per-BU phases (submit, poll, load-failure marking, import,
    -- reconcile) to the shared helpers in this block.
    --
    -- All three are GROUPED objects: one FBDI zip + one loadAndImportData +
    -- one BIP reconcile per distinct Procurement BU (PRC_BU_NAME). They are NOT
    -- spawn-per-partition (no row in DMT_CEMLI_SPLIT_CFG with a partition
    -- column), so g_partition_key is always NULL for them and the whole grouped
    -- loop runs inline in a single EXECUTE_ONE call for BOTH modes:
    --   * ASYNC (live queue) — po_submit_and_reconcile_one polls each BU's load
    --     + import and reconciles INLINE per BU; it sets g_reconciled_inline so
    --     EXECUTE_ONE settles the item through the accounting gate (NOT
    --     AWAITING_LOAD) and does NOT re-run RECON_PROC. g_load_ess_id stays
    --     NULL (grouped objects never set it) -- exactly as the monolith did.
    --   * SYNC (direct RUN_* call) — identical path; g_async_mode is unused here
    --     because the grouped helper always polls+reconciles inline regardless.
    --
    -- Behaviour is preserved byte-for-byte with the pre-refactor path through
    -- run_one_object_type + its nested submit_and_reconcile_one for these three
    -- objects. po_submit_and_reconcile_one mirrors that nested helper but takes
    -- the ERP-option values as explicit parameters (the nested one captured them
    -- from the enclosing scope) and omits the ARInvoices two-job and Items
    -- category special cases (never reachable for PO/BlanketPO/Contracts). The
    -- objects that REMAIN in the monolith (ARInvoices, Customers, APInvoices)
    -- still call the original nested submit_and_reconcile_one untouched.
    -- ========================================================================

    -- Shared helper: submit one BU's FBDI zip, poll load+import ESS, reconcile
    -- via BIP. Object-agnostic; the ERP options (job name, interface details,
    -- UCM account) and object label are passed in, not captured. Returns
    -- x_success = FALSE when the Load ESS fails so the caller marks that BU's
    -- GENERATED rows FAILED in its own (per-object) way. Sets g_reconciled_inline
    -- TRUE on success -- same signal EXECUTE_ONE reads to avoid a second reconcile.
    PROCEDURE po_submit_and_reconcile_one (
        p_run_id          IN NUMBER,
        p_cemli_code      IN VARCHAR2,
        p_obj             IN VARCHAR2,
        p_job_name        IN VARCHAR2,
        p_interface_details IN NUMBER,
        p_ucm_account     IN VARCHAR2,
        p_fbdi_zip        IN OUT NOCOPY BLOB,
        p_filename        IN VARCHAR2,
        p_fbdi_csv_id     IN NUMBER,
        p_param_list      IN VARCHAR2,
        p_group_label     IN VARCHAR2,
        p_username        IN VARCHAR2,
        p_password        IN VARCHAR2,
        x_load_ess_id     OUT VARCHAR2,
        x_import_ess_id   OUT VARCHAR2,
        x_success         OUT BOOLEAN
    ) IS
        C_PROC            CONSTANT VARCHAR2(40) := 'PO_SUBMIT_AND_RECONCILE_ONE';
        l_load_status     VARCHAR2(50);
    BEGIN
        x_success := FALSE;

        -- Submit loadAndImportData (combined load+import single call).
        x_load_ess_id := SUBMIT_LOAD(
            p_run_id            => p_run_id,
            p_fbdi_zip          => p_fbdi_zip,
            p_filename          => p_filename,
            p_job_name          => p_job_name,
            p_interface_details => p_interface_details,
            p_doc_account       => p_ucm_account,
            p_parameter_list    => p_param_list,
            p_log_context       => p_obj,
            p_username          => p_username,
            p_password          => p_password);
        DBMS_LOB.FREETEMPORARY(p_fbdi_zip);

        -- Stamp the parameter list on the zip row (keyed via the primary csv id).
        UPDATE DMT_FBDI_ZIP_TBL
        SET    PARAMETER_LIST  = p_param_list
        WHERE  FBDI_ZIP_ID = (SELECT FBDI_ZIP_ID FROM DMT_FBDI_CSV_TBL
                              WHERE FBDI_CSV_ID = p_fbdi_csv_id);
        COMMIT;

        -- Poll Load job.
        DMT_UTIL_PKG.LOG(p_run_id,
            'Polling Load ESS job: ' || x_load_ess_id || ' (' || p_group_label || ')',
            'INFO', C_PKG, p_obj || ' > ' || C_PROC);
        POLL_ESS_JOB(p_run_id, x_load_ess_id, 1800, FALSE, p_obj, p_cemli_code,
                     l_load_status, p_username => p_username, p_password => p_password);

        -- Load failed → caller marks that BU's GENERATED rows FAILED.
        IF l_load_status NOT IN (C_STATUS_SUCCEEDED, C_STATUS_WARNING) THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'Load ESS ' || x_load_ess_id || ' returned ' || l_load_status ||
                ' for ' || p_group_label ||
                '. No rows committed to interface table. Marking all GENERATED rows FAILED.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, p_obj || ' > ' || C_PROC);
            x_import_ess_id := NULL;
            RETURN;  -- x_success stays FALSE
        END IF;

        -- Find the Import ESS job ID.
        BEGIN
            x_import_ess_id := get_import_ess_id(p_run_id, p_cemli_code, x_load_ess_id);
        EXCEPTION
            WHEN OTHERS THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    'Could not find chained Import ESS for Load ' || x_load_ess_id,
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, p_obj || ' > ' || C_PROC);
                x_import_ess_id := NULL;
        END;

        -- Poll Import job.
        IF x_import_ess_id IS NOT NULL THEN
            COMMIT;
            DMT_UTIL_PKG.LOG(p_run_id,
                'Polling Import ESS job: ' || x_import_ess_id || ' (' || p_group_label || ')',
                'INFO', C_PKG, p_obj || ' > ' || C_PROC);
            POLL_ESS_JOB(p_run_id, x_import_ess_id, 1800, FALSE, p_obj, p_cemli_code,
                         l_load_status, p_username => p_username, p_password => p_password);
        END IF;

        -- Capture the Report child ESS job + parse import-report errors (generic;
        -- no-op for objects without a REPORT_JOB_DEF). Mirrors the nested helper.
        IF x_import_ess_id IS NOT NULL THEN
            DECLARE
                l_report_ess_id NUMBER;
            BEGIN
                l_report_ess_id := DMT_ESS_UTIL_PKG.CAPTURE_REPORT_ESS_JOB(
                    p_run_id        => p_run_id,
                    p_import_ess_id => TO_NUMBER(x_import_ess_id),
                    p_cemli_code    => p_cemli_code);
            END;

            BEGIN
                DECLARE
                    l_ir_count NUMBER;
                BEGIN
                    l_ir_count := DMT_IMPORT_REPORT_PKG.PARSE_AND_LOG_ERRORS(
                        p_run_id     => p_run_id,
                        p_request_id => TO_NUMBER(x_import_ess_id),
                        p_cemli_code => p_cemli_code);
                    IF l_ir_count > 0 THEN
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'Import Report captured ' || l_ir_count || ' error(s) for ' ||
                            p_cemli_code || ' (' || p_group_label || ', ESS ' || x_import_ess_id || ').',
                            'INFO', C_PKG, p_obj || ' > ' || C_PROC);
                    END IF;
                END;
            EXCEPTION
                WHEN OTHERS THEN
                    DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                        'Import Report capture failed for ' || p_cemli_code ||
                        ' (' || p_group_label || ', ESS ' || x_import_ess_id || '). Continuing to BIP.',
                        SQLERRM, C_PKG, p_obj || ' > ' || C_PROC);
            END;
        END IF;

        -- Backlog #70 (non-partitioned + spawn children): stamp this work item's own
        -- load + import ess ids on its own queue row. For a grouped object (several
        -- groups on one queue row) the last group with real ids wins — a representative
        -- id for the single tile. No-op for a direct/standalone call.
        stamp_item_ess_ids(x_load_ess_id, x_import_ess_id);

        -- Reconcile via BIP — single registry-driven dispatch (once per BU/group).
        DMT_QUEUE_WORKER_PKG.RECONCILE_VIA_REGISTRY(
            p_run_id        => p_run_id,
            p_cemli_code    => p_cemli_code,
            p_load_ess_id   => TO_NUMBER(x_load_ess_id),
            p_import_ess_id => TO_NUMBER(x_import_ess_id),
            p_work_queue_id => g_work_queue_id);

        -- Inline reconcile happened: EXECUTE_ONE must NOT re-reconcile via RECON_PROC.
        g_reconciled_inline := TRUE;

        x_success := TRUE;
    END po_submit_and_reconcile_one;

    -- Shared helper: fail this BU's GENERATED rows across the PO TFM table(s) with a
    -- reportable [LOAD_ERROR]. Static per-object statements (no dynamic SQL).
    -- PurchaseOrders cascades header→line→line-loc→dist (multi-CSV); BlanketPOs and
    -- Contracts fail the header table filtered by STYLE_DISPLAY_NAME. Each block is
    -- identical to the original per-object on-fail cascade in run_one_object_type.
    PROCEDURE po_mark_bu_failed (
        p_run_id       IN NUMBER,
        p_cemli_code   IN VARCHAR2,
        p_prc_bu_name  IN VARCHAR2,
        p_load_ess_id  IN VARCHAR2
    ) IS
        l_err VARCHAR2(500) :=
            '[LOAD_ERROR] Loading data to the Fusion interface failed. Check ESS job '
            || p_load_ess_id || ' logs for details.';
    BEGIN
        IF p_cemli_code = 'PurchaseOrders' THEN
            UPDATE DMT_PO_HEADERS_INT_TFM_TBL
            SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err)
            WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED' AND PRC_BU_NAME=p_prc_bu_name;
            UPDATE DMT_PO_LINES_INT_TFM_TBL
            SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err)
            WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED'
            AND INTERFACE_HEADER_KEY IN (SELECT INTERFACE_HEADER_KEY FROM DMT_PO_HEADERS_INT_TFM_TBL WHERE RUN_ID=p_run_id AND PRC_BU_NAME=p_prc_bu_name);
            UPDATE DMT_PO_LINE_LOCS_INT_TFM_TBL
            SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err)
            WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED'
            AND INTERFACE_LINE_KEY IN (SELECT INTERFACE_LINE_KEY FROM DMT_PO_LINES_INT_TFM_TBL WHERE RUN_ID=p_run_id
                AND INTERFACE_HEADER_KEY IN (SELECT INTERFACE_HEADER_KEY FROM DMT_PO_HEADERS_INT_TFM_TBL WHERE RUN_ID=p_run_id AND PRC_BU_NAME=p_prc_bu_name));
            UPDATE DMT_PO_DISTS_INT_TFM_TBL
            SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err)
            WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED'
            AND INTERFACE_LINE_LOCATION_KEY IN (SELECT INTERFACE_LINE_LOCATION_KEY FROM DMT_PO_LINE_LOCS_INT_TFM_TBL WHERE RUN_ID=p_run_id
                AND INTERFACE_LINE_KEY IN (SELECT INTERFACE_LINE_KEY FROM DMT_PO_LINES_INT_TFM_TBL WHERE RUN_ID=p_run_id
                AND INTERFACE_HEADER_KEY IN (SELECT INTERFACE_HEADER_KEY FROM DMT_PO_HEADERS_INT_TFM_TBL WHERE RUN_ID=p_run_id AND PRC_BU_NAME=p_prc_bu_name)));
            COMMIT;
        ELSIF p_cemli_code = 'BlanketPOs' THEN
            UPDATE DMT_PO_HEADERS_INT_TFM_TBL
            SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err),
                LAST_UPDATED_DATE=SYSDATE
            WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED' AND PRC_BU_NAME=p_prc_bu_name
            AND STYLE_DISPLAY_NAME='Blanket Purchase Agreement';
            COMMIT;
        ELSIF p_cemli_code = 'Contracts' THEN
            UPDATE DMT_PO_HEADERS_INT_TFM_TBL
            SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err),
                LAST_UPDATED_DATE=SYSDATE
            WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED' AND PRC_BU_NAME=p_prc_bu_name
            AND STYLE_DISPLAY_NAME='Contract Purchase Agreement';
            COMMIT;
        ELSE
            RAISE_APPLICATION_ERROR(-20047,
                'po_mark_bu_failed: unexpected CEMLI ''' || p_cemli_code || '''.');
        END IF;
    END po_mark_bu_failed;

    -- Shared tail: FAILED-row count warning + "object complete" log. Mirrors the
    -- grouped_finish tail of run_one_object_type for the three purchasing objects
    -- (all count the shared PO header TFM table). Static SELECT, no dynamic SQL.
    PROCEDURE po_finish (
        p_run_id     IN NUMBER,
        p_cemli_code IN VARCHAR2,
        p_obj        IN VARCHAR2
    ) IS
        C_PROC CONSTANT VARCHAR2(40) := 'PO_FINISH';
        l_failed_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO l_failed_count
        FROM DMT_PO_HEADERS_INT_TFM_TBL
        WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';

        IF l_failed_count > 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                p_cemli_code || ': ' || l_failed_count || ' record(s) FAILED in Fusion. ' ||
                'Downstream object types will continue — check staging table for details.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, p_obj || ' > ' || C_PROC);
        END IF;
        DMT_UTIL_PKG.LOG(p_run_id,
            'Object type complete: ' || p_cemli_code, 'INFO', C_PKG, p_obj || ' > ' || C_PROC);
    END po_finish;

    -- ========================================================================
    -- PARTITIONED P2P FAMILY — self-contained runners (backlog #8, third family).
    --
    -- Requisitions and Items (ItemCategories is bundled into the Items token, one
    -- FBDI ZIP) NO LONGER route through the run_one_object_type p_cemli_code
    -- ladders. Each RUN_<object>() below is a self-contained recipe.
    --
    -- CRITICAL DIFFERENCE from the Suppliers/Purchasing families: these two are
    -- SPAWN-PER-PARTITION objects (a row in DMT_CEMLI_SPLIT_CFG with
    -- CHILD_PARTITION_COLUMN = BATCH_ID). The queue worker drives them in TWO
    -- distinct EXECUTE_ONE calls, and the recipe below serves BOTH:
    --   1. PARENT transform-only pass. EXECUTE_ONE sees a parent row
    --      (PARTITION_KEY NULL), calls DMT_LOADER_PKG.RUN_TRANSFORM_ONLY, which now
    --      dispatches Requisitions/Items to THIS recipe with g_transform_only=TRUE.
    --      The recipe validates + transforms STG -> TFM STAGED and RETURNS before
    --      any generate/submit. EXECUTE_ONE then reads the object's registered
    --      GET_PARTITION_KEYS and spawns one READY child work item per distinct
    --      BATCH_ID. (The partition-spawn mechanic itself lives in EXECUTE_ONE and
    --      is UNTOUCHED by this refactor.)
    --   2. CHILD load pass. EXECUTE_ONE dispatches each child through the
    --      registered EXEC_PROC (RUN_REQUISITIONS / RUN_ITEMS) with g_partition_key
    --      set to that child's single BATCH_ID (JSON, e.g. {"BATCH_ID":"8102"}),
    --      g_work_queue_id and g_gen_queue_id both set to the child's QUEUE_ID.
    --      The recipe's batch loop then runs EXACTLY ONCE (scoped to that batch),
    --      generates + loads + reconciles ONLY that partition, and settles.
    --
    -- Both objects run their load INLINE inside the child's single EXECUTE_ONE call
    -- (submit + poll load + import + BIP reconcile), then set g_reconciled_inline
    -- so EXECUTE_ONE settles the child through the accounting gate rather than the
    -- AWAITING_LOAD queue states. This is byte-for-byte the pre-refactor behaviour:
    -- the monolith's Requisitions/Items grouped blocks also polled + reconciled
    -- inline via the nested submit_and_reconcile_one regardless of g_async_mode.
    --
    -- Backlog #70 (per-child ESS-id tiles) is completed here: because the child
    -- reconciles inline (never AWAITING_LOAD / AWAITING_IMPORT), the queue worker
    -- never stamped LOAD_ESS_JOB_ID / IMPORT_ESS_JOB_ID onto the child's queue row,
    -- so the run-detail tiles showed no ids for Requisitions/Items children. The
    -- recipe now stamps each child's OWN distinct load + import request ids onto its
    -- own DMT_WORK_QUEUE_TBL row via stamp_item_ess_ids (static SQL, keyed
    -- on the child's QUEUE_ID). The load/reconcile semantics are unchanged; only the
    -- id columns are now populated.
    --
    -- A direct RUN_REQUISITIONS / RUN_ITEMS call (e.g. from RUN_PROCURE_TO_PAY, or a
    -- one-off test) has g_partition_key NULL and g_transform_only FALSE: the recipe
    -- then loops ALL of the run's batches inline (the legacy standalone path) and
    -- stamps nothing on the queue (g_work_queue_id is NULL outside the queue).
    -- ========================================================================

    -- ========================================================================
    -- O2C FAMILY — self-contained runners (backlog #8, fourth family).
    --
    -- Customers, ARInvoices and MiscReceipts NO LONGER route through the
    -- run_one_object_type p_cemli_code ladders. Each RUN_<object>() below is a
    -- self-contained recipe:
    --   * Customers  — GROUPED by (BATCH_ID, source system). One FBDI zip + one
    --     "Import Bulk Customer Data" (CDMAutoBulkImportJob) load + one BIP
    --     reconcile per batch, all inline in a single work-queue item (it is NOT
    --     spawn-per-partition: no CHILD_PARTITION_COLUMN in DMT_CEMLI_SPLIT_CFG,
    --     no PARTITION_KEYS_PROC). Same shape as the Purchasing family; it reuses
    --     po_submit_and_reconcile_one and settles inline (g_reconciled_inline).
    --   * ARInvoices — GROUPED by (BU_NAME, BATCH_SOURCE_NAME). AR AutoInvoice is
    --     a TWO-job flow: loadAndImportData chains AutoInvoiceImportEss (staging
    --     only), then a SECOND AutoInvoiceMasterEss job actually creates the
    --     transactions. That extra job is NOT in po_submit_and_reconcile_one, so
    --     ARInvoices uses ar_submit_and_reconcile_one below (identical to the PO
    --     helper plus the AR Master block copied verbatim from the retired nested
    --     submit_and_reconcile_one).
    --   * MiscReceipts — SINGLE-LOAD SYNC. loadAndImportData does not chain an
    --     import for INV transactions (interfaceDetails is DMT-local, not a real
    --     Fusion FUN_ERP_INTERFACE_OPTIONS row), so the import step submits
    --     PollTMEssJob explicitly. Reconciles inline. Follows the single (Suppliers)
    --     pattern with the PollTMEssJob import substituted for get_import_ess_id.
    --
    -- Behaviour is preserved byte-for-byte with the pre-refactor path through
    -- run_one_object_type + its nested submit_and_reconcile_one for these three
    -- objects. None of the three is spawn-per-partition, so g_partition_key is
    -- always NULL for them and backlog #70's per-child ESS-id stamping does not
    -- apply (their ESS ids ride the single work-queue item exactly as PO's do).
    -- ========================================================================

    -- Shared helper for ARInvoices: submit one (BU, batch source) group's FBDI zip,
    -- poll load+import ESS, run the AutoInvoiceMasterEss second job, reconcile via
    -- BIP. Identical to po_submit_and_reconcile_one EXCEPT for the AR two-job Master
    -- block (copied verbatim from the retired nested submit_and_reconcile_one AR
    -- special case): once the import (staging) job SUCCEEDs, submit
    -- AutoInvoiceMasterEss and re-point x_import_ess_id at it -- THAT job creates the
    -- transactions and is the one reconciliation keys against. Sets g_reconciled_inline.
    PROCEDURE ar_submit_and_reconcile_one (
        p_run_id          IN NUMBER,
        p_cemli_code      IN VARCHAR2,
        p_obj             IN VARCHAR2,
        p_job_name        IN VARCHAR2,
        p_interface_details IN NUMBER,
        p_ucm_account     IN VARCHAR2,
        p_fbdi_zip        IN OUT NOCOPY BLOB,
        p_filename        IN VARCHAR2,
        p_fbdi_csv_id     IN NUMBER,
        p_param_list      IN VARCHAR2,
        p_group_label     IN VARCHAR2,
        p_username        IN VARCHAR2,
        p_password        IN VARCHAR2,
        x_load_ess_id     OUT VARCHAR2,
        x_import_ess_id   OUT VARCHAR2,
        x_success         OUT BOOLEAN
    ) IS
        C_PROC            CONSTANT VARCHAR2(40) := 'AR_SUBMIT_AND_RECONCILE_ONE';
        l_load_status     VARCHAR2(50);
    BEGIN
        x_success := FALSE;

        -- Submit loadAndImportData (combined load+import single call).
        x_load_ess_id := SUBMIT_LOAD(
            p_run_id            => p_run_id,
            p_fbdi_zip          => p_fbdi_zip,
            p_filename          => p_filename,
            p_job_name          => p_job_name,
            p_interface_details => p_interface_details,
            p_doc_account       => p_ucm_account,
            p_parameter_list    => p_param_list,
            p_log_context       => p_obj,
            p_username          => p_username,
            p_password          => p_password);
        DBMS_LOB.FREETEMPORARY(p_fbdi_zip);

        -- Stamp the parameter list on the zip row (keyed via the primary csv id).
        UPDATE DMT_FBDI_ZIP_TBL
        SET    PARAMETER_LIST  = p_param_list
        WHERE  FBDI_ZIP_ID = (SELECT FBDI_ZIP_ID FROM DMT_FBDI_CSV_TBL
                              WHERE FBDI_CSV_ID = p_fbdi_csv_id);
        COMMIT;

        -- Poll Load job.
        DMT_UTIL_PKG.LOG(p_run_id,
            'Polling Load ESS job: ' || x_load_ess_id || ' (' || p_group_label || ')',
            'INFO', C_PKG, p_obj || ' > ' || C_PROC);
        POLL_ESS_JOB(p_run_id, x_load_ess_id, 1800, FALSE, p_obj, p_cemli_code,
                     l_load_status, p_username => p_username, p_password => p_password);

        -- Load failed → caller marks that group's GENERATED rows FAILED.
        IF l_load_status NOT IN (C_STATUS_SUCCEEDED, C_STATUS_WARNING) THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'Load ESS ' || x_load_ess_id || ' returned ' || l_load_status ||
                ' for ' || p_group_label ||
                '. No rows committed to interface table. Marking all GENERATED rows FAILED.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, p_obj || ' > ' || C_PROC);
            x_import_ess_id := NULL;
            RETURN;  -- x_success stays FALSE
        END IF;

        -- Find the Import ESS job ID.
        BEGIN
            x_import_ess_id := get_import_ess_id(p_run_id, p_cemli_code, x_load_ess_id);
        EXCEPTION
            WHEN OTHERS THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    'Could not find chained Import ESS for Load ' || x_load_ess_id,
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, p_obj || ' > ' || C_PROC);
                x_import_ess_id := NULL;
        END;

        -- Poll Import (staging) job.
        IF x_import_ess_id IS NOT NULL THEN
            COMMIT;
            DMT_UTIL_PKG.LOG(p_run_id,
                'Polling Import ESS job: ' || x_import_ess_id || ' (' || p_group_label || ')',
                'INFO', C_PKG, p_obj || ' > ' || C_PROC);
            POLL_ESS_JOB(p_run_id, x_import_ess_id, 1800, FALSE, p_obj, p_cemli_code,
                         l_load_status, p_username => p_username, p_password => p_password);
        END IF;

        -- ============================================================
        -- AR AutoInvoice is a TWO-job flow.
        -- loadAndImportData chains AutoInvoiceImportEss, which ONLY stages
        -- rows into RA_INTERFACE_LINES_ALL and reports SUCCEEDED without
        -- importing anything. The transactions are actually created by a
        -- SECOND job, AutoInvoiceMasterEss ("Import Receivables Transactions
        -- Using AutoInvoice"). Without it, good invoices sit at
        -- INTERFACE_STATUS = NULL forever. So once the import (staging) job
        -- has SUCCEEDED, submit the Master job and make IT the job the
        -- reconciler waits on. (Proven contract: MCCS RICE_005 AR package.)
        -- ============================================================
        IF x_import_ess_id IS NOT NULL
           AND l_load_status IN (C_STATUS_SUCCEEDED, C_STATUS_WARNING) THEN
            DECLARE
                l_master_ess_id  VARCHAR2(100);
                l_trx_source_id  VARCHAR2(100);
                l_batch_source   VARCHAR2(500);
                l_bu_count       NUMBER;
                l_param_master   VARCHAR2(4000);
                l_resp           CLOB;
                l_tag_s          INTEGER;
                l_val_s          INTEGER;
                l_val_e          INTEGER;
                l_master_status  VARCHAR2(50);
            BEGIN
                -- Batch source name is the 2nd comma slot of the AR param list
                -- (built as BU_NAME,BATCH_SOURCE_NAME,DATE,...).
                l_batch_source := SUBSTR(p_param_list,
                                         INSTR(p_param_list, ',') + 1,
                                         INSTR(p_param_list, ',', 1, 2) - INSTR(p_param_list, ',') - 1);

                -- Resolve the batch source NAME to its numeric transaction-source id
                -- (no hardcoded Fusion ids -- setup table read at preflight).
                l_trx_source_id := DMT_UTIL_PKG.GET_LOOKUP('BATCH_SOURCE_NAME_TO_TRX_SOURCE_ID', l_batch_source);

                -- Distinct BU count across this run's AR rows -- position 1 of the
                -- Master param list.
                SELECT COUNT(DISTINCT BU_NAME) INTO l_bu_count
                FROM   DMT_RA_LINES_TFM_TBL
                WHERE  RUN_ID = p_run_id;

                -- Master param list: tilde(~)-separated with #NULL for empty
                -- slots (NOT empty strings -- empty strings make Fusion collapse
                -- the slots so the trailing flag lands in the wrong position;
                -- that was the documented run-179 blocker). Slot layout, matching
                -- MCCS exactly:
                --   pos1  = COUNT(DISTINCT BU_NAME)
                --   pos2  = #NULL
                --   pos3  = numeric trx_source_id
                --   pos4  = current date YYYY-MM-DD (an OPEN period)
                --   pos5..24 = #NULL
                --   then N, Y, trailing ~
                l_param_master :=
                    l_bu_count || '~#NULL~' || l_trx_source_id || '~' ||
                    TO_CHAR(SYSDATE, 'YYYY-MM-DD') ||
                    '~#NULL~#NULL~#NULL~#NULL~#NULL~#NULL~#NULL~#NULL~#NULL~#NULL~#NULL~' ||
                    '#NULL~#NULL~#NULL~#NULL~#NULL~#NULL~#NULL~#NULL~#NULL~N~Y~';

                DMT_UTIL_PKG.LOG(p_run_id,
                    'AR two-job flow: import (staging) job ' || x_import_ess_id ||
                    ' SUCCEEDED. Submitting AutoInvoiceMasterEss. ParameterList: ' || l_param_master,
                    'INFO', C_PKG, p_obj || ' > ' || C_PROC);

                -- Submit AutoInvoiceMasterEss via the same submitESSJobRequest
                -- SOAP envelope pattern used for PollTMEssJob (MiscReceipts).
                l_resp := soap_http(
                    p_url            => erp_soap_url,
                    p_soap_action    => 'http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/submitESSJobRequest',
                    p_body           => TO_CLOB(
                        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' ||
                        'xmlns:typ="http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/types/">' ||
                        '<soapenv:Header/><soapenv:Body>' ||
                        '<typ:submitESSJobRequest>' ||
                        '<typ:jobPackageName>/oracle/apps/ess/financials/receivables/transactions/autoInvoices</typ:jobPackageName>' ||
                        '<typ:jobDefinitionName>AutoInvoiceMasterEss</typ:jobDefinitionName>' ||
                        '<typ:paramList>' || l_param_master || '</typ:paramList>' ||
                        '</typ:submitESSJobRequest>' ||
                        '</soapenv:Body></soapenv:Envelope>'),
                    p_run_id         => p_run_id,
                    p_username       => p_username,
                    p_password       => p_password);

                l_tag_s := DBMS_LOB.INSTR(l_resp, '<result');
                IF l_tag_s > 0 THEN
                    l_val_s := DBMS_LOB.INSTR(l_resp, '>', l_tag_s) + 1;
                    l_val_e := DBMS_LOB.INSTR(l_resp, '</result>', l_val_s);
                    IF l_val_e > l_val_s THEN
                        l_master_ess_id := DBMS_LOB.SUBSTR(l_resp, l_val_e - l_val_s, l_val_s);
                    END IF;
                END IF;

                IF l_master_ess_id IS NULL THEN
                    RAISE_APPLICATION_ERROR(-20051,
                        'AR: failed to submit AutoInvoiceMasterEss. Response: ' ||
                        DBMS_LOB.SUBSTR(l_resp, 500, 1));
                END IF;

                DMT_UTIL_PKG.LOG(p_run_id,
                    'AutoInvoiceMasterEss submitted. ESS ID: ' || l_master_ess_id ||
                    ' (' || p_group_label || ').',
                    'INFO', C_PKG, p_obj || ' > ' || C_PROC);

                -- Poll the Master job to terminal -- do NOT raise on error.
                POLL_ESS_JOB(p_run_id, l_master_ess_id, 1800, FALSE, p_obj, p_cemli_code,
                             l_master_status, p_username => p_username, p_password => p_password);

                -- Re-point x_import_ess_id at the Master job: THIS is the job that
                -- creates the transactions, so it is the one reconciliation must
                -- wait on and key against.
                x_import_ess_id := l_master_ess_id;
            END;
        END IF;

        -- Capture the Report child ESS job + parse import-report errors (generic;
        -- no-op for objects without a REPORT_JOB_DEF). Mirrors the nested helper.
        IF x_import_ess_id IS NOT NULL THEN
            DECLARE
                l_report_ess_id NUMBER;
            BEGIN
                l_report_ess_id := DMT_ESS_UTIL_PKG.CAPTURE_REPORT_ESS_JOB(
                    p_run_id        => p_run_id,
                    p_import_ess_id => TO_NUMBER(x_import_ess_id),
                    p_cemli_code    => p_cemli_code);
            END;

            BEGIN
                DECLARE
                    l_ir_count NUMBER;
                BEGIN
                    l_ir_count := DMT_IMPORT_REPORT_PKG.PARSE_AND_LOG_ERRORS(
                        p_run_id     => p_run_id,
                        p_request_id => TO_NUMBER(x_import_ess_id),
                        p_cemli_code => p_cemli_code);
                    IF l_ir_count > 0 THEN
                        DMT_UTIL_PKG.LOG(p_run_id,
                            'Import Report captured ' || l_ir_count || ' error(s) for ' ||
                            p_cemli_code || ' (' || p_group_label || ', ESS ' || x_import_ess_id || ').',
                            'INFO', C_PKG, p_obj || ' > ' || C_PROC);
                    END IF;
                END;
            EXCEPTION
                WHEN OTHERS THEN
                    DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                        'Import Report capture failed for ' || p_cemli_code ||
                        ' (' || p_group_label || ', ESS ' || x_import_ess_id || '). Continuing to BIP.',
                        SQLERRM, C_PKG, p_obj || ' > ' || C_PROC);
            END;
        END IF;

        -- Backlog #70 (non-partitioned): stamp this work item's own load + import ess
        -- ids on its own queue row. For AR the import id is the AutoInvoiceMasterEss
        -- id (x_import_ess_id was re-pointed to it above), so the tile shows the job
        -- that actually created the transactions. Last group with real ids wins.
        stamp_item_ess_ids(x_load_ess_id, x_import_ess_id);

        -- Reconcile via BIP — single registry-driven dispatch (once per group).
        DMT_QUEUE_WORKER_PKG.RECONCILE_VIA_REGISTRY(
            p_run_id        => p_run_id,
            p_cemli_code    => p_cemli_code,
            p_load_ess_id   => TO_NUMBER(x_load_ess_id),
            p_import_ess_id => TO_NUMBER(x_import_ess_id),
            p_work_queue_id => g_work_queue_id);

        -- Inline reconcile happened: EXECUTE_ONE must NOT re-reconcile via RECON_PROC.
        g_reconciled_inline := TRUE;

        x_success := TRUE;
    END ar_submit_and_reconcile_one;

    -- ========================================================================
    -- FINANCIALS / PROJECTS SINGLE-LOAD FAMILY — shared helpers (backlog #8,
    -- fifth/final family). These serve the remaining single-load objects that
    -- migrated off run_one_object_type in this pass: Projects, BillingEvents,
    -- Grants, PlanningBudgets, ProjectBudgets, Assets. They are NOT grouped
    -- (one FBDI zip for the whole object) and, except Assets, not partitioned.
    --
    -- fin_after_generate is the single-load twin of sup_after_generate: same
    -- submit / async-gate / poll / load-failure / import / reconcile / count
    -- shape, but it takes the object's ParameterList explicitly (suppliers hard-
    -- coded 'NEW,N'; these objects each need their own list) and it adds the
    -- import-report-on-error capture the monolith ran for Projects/Expenditures/
    -- BillingEvents. The per-object mark-GENERATED-FAILED and status counts are
    -- static one-statement-per-object helpers (no dynamic SQL), each identical to
    -- the corresponding arm of the retired run_one_object_type ladders.
    -- ========================================================================

    -- Static per-object: fail every GENERATED row in the object's own TFM table
    -- (header table for multi-table objects) with a reportable [LOAD_ERROR].
    -- Identical to the mark-GENERATED-FAILED arms of run_one_object_type.
    PROCEDURE fin_mark_generated_failed (
        p_run_id      IN NUMBER,
        p_cemli_code  IN VARCHAR2,
        p_load_ess_id IN VARCHAR2
    ) IS
        l_err_msg VARCHAR2(500) :=
            '[LOAD_ERROR] Loading data to the Fusion interface failed. Check ESS job '
            || p_load_ess_id || ' logs for details.';
    BEGIN
        IF    p_cemli_code = 'Projects' THEN
            UPDATE DMT_PJF_PROJECTS_TFM_TBL    SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED';
        ELSIF p_cemli_code = 'BillingEvents' THEN
            UPDATE DMT_PJB_BILL_EVENTS_TFM_TBL SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED';
        ELSIF p_cemli_code = 'Grants' THEN
            UPDATE DMT_GMS_AWD_HEADERS_TFM_TBL SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED';
        ELSIF p_cemli_code = 'PlanningBudgets' THEN
            UPDATE DMT_PLAN_BUDGET_TFM_TBL     SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED';
        ELSIF p_cemli_code = 'ProjectBudgets' THEN
            UPDATE DMT_PRJ_BUDGET_TFM_TBL      SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED';
        ELSIF p_cemli_code = 'Assets' THEN
            UPDATE DMT_FA_ASSET_HDR_TFM_TBL    SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED';
        ELSIF p_cemli_code = 'Expenditures' THEN
            UPDATE DMT_PJC_EXPENDITURES_TFM_TBL SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED';
        ELSIF p_cemli_code = 'GLBudgets' THEN
            UPDATE DMT_GL_BUDGET_INT_TFM_TBL   SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED';
        ELSE
            RAISE_APPLICATION_ERROR(-20047,
                'fin_mark_generated_failed: unexpected CEMLI ''' || p_cemli_code || '''.');
        END IF;
        COMMIT;
    END fin_mark_generated_failed;

    -- Static per-object: count rows at a given status in the object's own TFM
    -- table (header table for multi-table objects). One literal SELECT per object,
    -- mirroring the still-GENERATED / FAILED counts of run_one_object_type.
    FUNCTION fin_count_status (
        p_run_id     IN NUMBER,
        p_cemli_code IN VARCHAR2,
        p_status     IN VARCHAR2
    ) RETURN NUMBER IS
        l_cnt NUMBER;
    BEGIN
        IF    p_cemli_code = 'Projects' THEN
            SELECT COUNT(*) INTO l_cnt FROM DMT_PJF_PROJECTS_TFM_TBL    WHERE RUN_ID=p_run_id AND TFM_STATUS=p_status;
        ELSIF p_cemli_code = 'BillingEvents' THEN
            SELECT COUNT(*) INTO l_cnt FROM DMT_PJB_BILL_EVENTS_TFM_TBL WHERE RUN_ID=p_run_id AND TFM_STATUS=p_status;
        ELSIF p_cemli_code = 'Grants' THEN
            SELECT COUNT(*) INTO l_cnt FROM DMT_GMS_AWD_HEADERS_TFM_TBL WHERE RUN_ID=p_run_id AND TFM_STATUS=p_status;
        ELSIF p_cemli_code = 'PlanningBudgets' THEN
            SELECT COUNT(*) INTO l_cnt FROM DMT_PLAN_BUDGET_TFM_TBL     WHERE RUN_ID=p_run_id AND TFM_STATUS=p_status;
        ELSIF p_cemli_code = 'ProjectBudgets' THEN
            SELECT COUNT(*) INTO l_cnt FROM DMT_PRJ_BUDGET_TFM_TBL      WHERE RUN_ID=p_run_id AND TFM_STATUS=p_status;
        ELSIF p_cemli_code = 'Assets' THEN
            SELECT COUNT(*) INTO l_cnt FROM DMT_FA_ASSET_HDR_TFM_TBL    WHERE RUN_ID=p_run_id AND TFM_STATUS=p_status;
        ELSIF p_cemli_code = 'Expenditures' THEN
            SELECT COUNT(*) INTO l_cnt FROM DMT_PJC_EXPENDITURES_TFM_TBL WHERE RUN_ID=p_run_id AND TFM_STATUS=p_status;
        ELSIF p_cemli_code = 'GLBudgets' THEN
            SELECT COUNT(*) INTO l_cnt FROM DMT_GL_BUDGET_INT_TFM_TBL   WHERE RUN_ID=p_run_id AND TFM_STATUS=p_status;
        ELSE
            RAISE_APPLICATION_ERROR(-20047,
                'fin_count_status: unexpected CEMLI ''' || p_cemli_code || '''.');
        END IF;
        RETURN l_cnt;
    END fin_count_status;

    -- Shared helper: everything after the FBDI zip is generated for a single-load
    -- financial/project object. Twin of sup_after_generate but ParameterList-driven
    -- and with the Projects/BillingEvents import-report-on-error capture. Preserves
    -- byte-for-byte the single-load path of run_one_object_type for these objects,
    -- including the g_async_mode gate (async submit-and-return; sync poll+reconcile).
    -- Returns FALSE for the empty-zip / load-failure skips, TRUE otherwise.
    FUNCTION fin_after_generate (
        p_run_id     IN NUMBER,
        p_cemli_code IN VARCHAR2,
        p_obj        IN VARCHAR2,          -- object label for logging
        p_zip        IN OUT NOCOPY BLOB,
        p_filename   IN VARCHAR2,
        p_param_list IN VARCHAR2
    ) RETURN BOOLEAN IS
        C_PROC        CONSTANT VARCHAR2(40) := 'FIN_AFTER_GENERATE';
        l_ucm_account       VARCHAR2(200);
        l_job_name          VARCHAR2(500);
        l_interface_details NUMBER;
        l_ess_user          VARCHAR2(100);
        l_ess_pass          VARCHAR2(100);
        l_load_ess_id       VARCHAR2(100);
        l_import_ess_id     VARCHAR2(100);
        l_load_status       VARCHAR2(50);
    BEGIN
        -- If no rows, skip this object type (mirrors the empty-zip guard).
        IF p_zip IS NULL OR DBMS_LOB.GETLENGTH(p_zip) = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'No rows for ' || p_cemli_code || '. Skipping.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, p_obj || ' > ' || C_PROC);
            RETURN FALSE;
        END IF;

        -- ERP options (UCM account, import job name, interface details id) + creds.
        get_erp_options(
            p_cemli_code           => p_cemli_code,
            x_ucm_account          => l_ucm_account,
            x_import_job_name      => l_job_name,
            x_interface_details_id => l_interface_details);
        DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS(p_cemli_code, l_ess_user, l_ess_pass);

        -- loadAndImportData — combined load+import single call.
        l_load_ess_id := SUBMIT_LOAD(
            p_run_id            => p_run_id,
            p_fbdi_zip          => p_zip,
            p_filename          => p_filename,
            p_job_name          => l_job_name,
            p_interface_details => l_interface_details,
            p_doc_account       => l_ucm_account,
            p_parameter_list    => p_param_list,
            p_log_context       => p_obj,
            p_username          => l_ess_user,
            p_password          => l_ess_pass);
        DBMS_LOB.FREETEMPORARY(p_zip);

        -- Stamp the parameter list on the ZIP row.
        UPDATE DMT_FBDI_ZIP_TBL
        SET    PARAMETER_LIST = p_param_list
        WHERE  RUN_ID = p_run_id
        AND    OBJECT_TYPE = SUBSTR(p_cemli_code, INSTR(p_cemli_code, '-') + 1);
        COMMIT;

        -- Async mode: stop here, let the queue poller handle ESS polling +
        -- reconciliation (the live path for every queue-driven ASYNC object).
        IF g_async_mode THEN
            g_load_ess_id := l_load_ess_id;
            RETURN TRUE;
        END IF;

        -- ---- SYNC path (direct RUN_* calls) ----

        -- Poll Load job.
        DMT_UTIL_PKG.LOG(p_run_id,
            'Polling Load ESS job: ' || l_load_ess_id, 'INFO', C_PKG, p_obj || ' > ' || C_PROC);
        POLL_ESS_JOB(p_run_id, l_load_ess_id, 1800, FALSE, p_obj, p_cemli_code, l_load_status,
                     p_username => l_ess_user, p_password => l_ess_pass);

        -- Load failed → no rows reached the interface table. Mark all GENERATED
        -- rows FAILED and return (no import job, no BIP).
        IF l_load_status NOT IN (C_STATUS_SUCCEEDED, C_STATUS_WARNING) THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'Load ESS ' || l_load_ess_id || ' returned ' || l_load_status ||
                '. No rows committed to interface table. Marking all GENERATED rows FAILED.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, p_obj || ' > ' || C_PROC);
            fin_mark_generated_failed(p_run_id, p_cemli_code, l_load_ess_id);
            RETURN FALSE;
        END IF;

        -- Find the Import ESS job ID (chained from loadAndImportData).
        l_import_ess_id := get_import_ess_id(p_run_id, p_cemli_code, l_load_ess_id);
        COMMIT;

        -- Backlog #70: stamp this item's own load + import ess ids on its own queue
        -- row (no-op for a direct/standalone call, g_gen_queue_id NULL).
        stamp_item_ess_ids(l_load_ess_id, l_import_ess_id);

        -- Poll Import job — do NOT raise on error.
        DMT_UTIL_PKG.LOG(p_run_id,
            'Polling Import ESS job: ' || l_import_ess_id, 'INFO', C_PKG, p_obj || ' > ' || C_PROC);
        POLL_ESS_JOB(p_run_id, l_import_ess_id, 1800, FALSE, p_obj, p_cemli_code, l_load_status,
                     p_username => l_ess_user, p_password => l_ess_pass);

        -- Capture the Report child ESS job into the hierarchy (generic).
        DECLARE l_report_ess_id NUMBER;
        BEGIN
            l_report_ess_id := DMT_ESS_UTIL_PKG.CAPTURE_REPORT_ESS_JOB(
                p_run_id        => p_run_id,
                p_import_ess_id => TO_NUMBER(l_import_ess_id),
                p_cemli_code    => p_cemli_code);
        END;

        -- For Projects/Expenditures/BillingEvents: capture Import Report errors from
        -- ESS output on a non-clean import, regardless of BIP outcome. Copied from
        -- the run_one_object_type single-load path.
        IF p_cemli_code IN ('Projects', 'Expenditures', 'BillingEvents')
           AND l_load_status IN (C_STATUS_ERROR, C_STATUS_WARNING, C_STATUS_FAILED) THEN
            DECLARE
                l_ir_count NUMBER;
            BEGIN
                l_ir_count := DMT_IMPORT_REPORT_PKG.PARSE_AND_LOG_ERRORS(
                    p_run_id     => p_run_id,
                    p_request_id => TO_NUMBER(l_import_ess_id),
                    p_cemli_code => p_cemli_code);
                DMT_UTIL_PKG.LOG(p_run_id,
                    'Import Report captured ' || l_ir_count || ' error(s) for ' || p_cemli_code ||
                    ' (ESS ' || l_import_ess_id || ', status ' || l_load_status || ').',
                    'INFO', C_PKG, p_obj || ' > ' || C_PROC);
            EXCEPTION
                WHEN OTHERS THEN
                    DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                        'Import Report capture failed for ' || p_cemli_code ||
                        ' (ESS ' || l_import_ess_id || '). Continuing to BIP reconciliation.',
                        SQLERRM, C_PKG, p_obj || ' > ' || C_PROC);
            END;
        END IF;

        -- BIP reconciliation — single registry-driven dispatch.
        DMT_QUEUE_WORKER_PKG.RECONCILE_VIA_REGISTRY(
            p_run_id        => p_run_id,
            p_cemli_code    => p_cemli_code,
            p_load_ess_id   => TO_NUMBER(l_load_ess_id),
            p_import_ess_id => TO_NUMBER(l_import_ess_id),
            p_work_queue_id => g_work_queue_id);
        g_reconciled_inline := TRUE;

        -- Rows still GENERATED after reconciliation → warn + capture ESS output.
        DECLARE
            l_still_generated NUMBER;
        BEGIN
            l_still_generated := fin_count_status(p_run_id, p_cemli_code, 'GENERATED');
            IF l_still_generated > 0 THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    'WARNING: ' || l_still_generated ||
                    ' rows still at GENERATED after BIP reconciliation for ' || p_cemli_code ||
                    '. BIP query returned no matching rows for these records. ' ||
                    'Rows left at GENERATED for manual investigation — do NOT assume success.',
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, p_obj || ' > ' || C_PROC);
                IF l_import_ess_id IS NOT NULL THEN
                    DMT_ESS_UTIL_PKG.CAPTURE_ESS_OUTPUT(
                        p_run_id     => p_run_id,
                        p_request_id => TO_NUMBER(l_import_ess_id),
                        p_cemli_code => p_cemli_code);
                END IF;
            END IF;
        END;

        RETURN TRUE;
    END fin_after_generate;

    -- Shared tail: FAILED-row count warning + "object complete" log for the
    -- single-load financial/project objects. Mirrors the grouped_finish tail.
    PROCEDURE fin_finish (
        p_run_id     IN NUMBER,
        p_cemli_code IN VARCHAR2,
        p_obj        IN VARCHAR2
    ) IS
        C_PROC CONSTANT VARCHAR2(40) := 'FIN_FINISH';
        l_failed_count NUMBER;
    BEGIN
        l_failed_count := fin_count_status(p_run_id, p_cemli_code, 'FAILED');
        IF l_failed_count > 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                p_cemli_code || ': ' || l_failed_count || ' record(s) FAILED in Fusion. ' ||
                'Downstream object types will continue — check staging table for details.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, p_obj || ' > ' || C_PROC);
        END IF;
        DMT_UTIL_PKG.LOG(p_run_id,
            'Object type complete: ' || p_cemli_code, 'INFO', C_PKG, p_obj || ' > ' || C_PROC);
    END fin_finish;

    -- --------------------------------------------------------
    -- RUN_SUPPLIER_PIPELINE
    -- Orchestrates all 5 object types in strict dependency order.
    -- --------------------------------------------------------
    PROCEDURE RUN_SUPPLIER_PIPELINE (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC  CONSTANT VARCHAR2(30) := 'RUN_SUPPLIER_PIPELINE';
        -- v_scenario_id is the OUT target of resolve_scenario, kept for its
        -- scenario-existence validation side effect (the per-object runners each
        -- re-resolve the scenario name themselves).
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

        -- Process in strict dependency order. Each object now runs through its own
        -- self-contained RUN_<object>() recipe (backlog #8) rather than the
        -- run_one_object_type ladders. The scenario name is passed through; the
        -- per-object runner re-resolves it (idempotent). p_skip_bu_refresh => TRUE
        -- so the pipeline refreshes BU lookups only once, up front.
        RUN_SUPPLIERS(p_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh);
        COMMIT;

        RUN_SUPPLIER_ADDRESSES(p_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh);
        COMMIT;

        RUN_SUPPLIER_SITES(p_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh);
        COMMIT;

        RUN_SUPPLIER_SITE_ASSIGNMENTS(p_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh);
        COMMIT;

        RUN_SUPPLIER_CONTACTS(p_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh);
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
        C_PROC   CONSTANT VARCHAR2(40) := 'RUN_SUPPLIERS';
        C_CEMLI  CONSTANT VARCHAR2(30) := 'Suppliers';
        C_OBJ    CONSTANT VARCHAR2(30) := 'Suppliers';
        v_scenario_id NUMBER;
        l_zip         BLOB;
        l_filename    VARCHAR2(200);
        l_ok          BOOLEAN;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_SUPPLIERS start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);

        sup_preamble(p_run_id, C_CEMLI, C_OBJ, p_skip_bu_refresh);

        -- Phase 1: pre-transform validation (marks staging rows FAILED on bad data).
        DMT_POZ_SUP_VALIDATOR_PKG.VALIDATE_SUPPLIERS(p_run_id);
        COMMIT;

        -- Phase 2: transform STG -> TFM.
        DMT_POZ_SUP_TRANSFORM_PKG.TRANSFORM_SUPPLIERS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;

        -- Phase 3: generate the FBDI zip.
        DMT_POZ_SUP_FBDI_GEN_PKG.GENERATE_FBDI(p_run_id, l_zip, l_filename);

        -- Phase 4: submit + (async return | poll + import + reconcile).
        l_ok := sup_after_generate(p_run_id, C_CEMLI, C_OBJ, l_zip, l_filename);

        -- Phase 5: FAILED-row accounting + completion log.
        sup_finish(p_run_id, C_CEMLI, C_OBJ);

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
        C_PROC   CONSTANT VARCHAR2(40) := 'RUN_SUPPLIER_ADDRESSES';
        C_CEMLI  CONSTANT VARCHAR2(30) := 'SupplierAddresses';
        C_OBJ    CONSTANT VARCHAR2(30) := 'SupplierAddresses';
        v_scenario_id NUMBER;
        l_zip         BLOB;
        l_filename    VARCHAR2(200);
        l_ok          BOOLEAN;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_SUPPLIER_ADDRESSES start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);

        sup_preamble(p_run_id, C_CEMLI, C_OBJ, p_skip_bu_refresh);

        DMT_POZ_SUP_VALIDATOR_PKG.VALIDATE_ADDRESSES(p_run_id);
        COMMIT;

        DMT_POZ_SUP_TRANSFORM_PKG.TRANSFORM_ADDRESSES(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;

        DMT_POZ_SUP_ADDR_FBDI_GEN_PKG.GENERATE_FBDI(p_run_id, l_zip, l_filename);

        l_ok := sup_after_generate(p_run_id, C_CEMLI, C_OBJ, l_zip, l_filename);

        sup_finish(p_run_id, C_CEMLI, C_OBJ);

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
        C_PROC   CONSTANT VARCHAR2(40) := 'RUN_SUPPLIER_SITES';
        C_CEMLI  CONSTANT VARCHAR2(30) := 'SupplierSites';
        C_OBJ    CONSTANT VARCHAR2(30) := 'SupplierSites';
        v_scenario_id NUMBER;
        l_zip         BLOB;
        l_filename    VARCHAR2(200);
        l_ok          BOOLEAN;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_SUPPLIER_SITES start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);

        sup_preamble(p_run_id, C_CEMLI, C_OBJ, p_skip_bu_refresh);

        DMT_POZ_SUP_VALIDATOR_PKG.VALIDATE_SITES(p_run_id);
        COMMIT;

        DMT_POZ_SUP_TRANSFORM_PKG.TRANSFORM_SITES(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;

        DMT_POZ_SUP_SITE_FBDI_GEN_PKG.GENERATE_FBDI(p_run_id, l_zip, l_filename);

        l_ok := sup_after_generate(p_run_id, C_CEMLI, C_OBJ, l_zip, l_filename);

        sup_finish(p_run_id, C_CEMLI, C_OBJ);

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
        C_PROC   CONSTANT VARCHAR2(40) := 'RUN_SUPPLIER_SITE_ASSIGNMENTS';
        C_CEMLI  CONSTANT VARCHAR2(30) := 'SupplierSiteAssignments';
        C_OBJ    CONSTANT VARCHAR2(30) := 'SupplierSiteAssignments';
        v_scenario_id NUMBER;
        l_zip         BLOB;
        l_filename    VARCHAR2(200);
        l_ok          BOOLEAN;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_SUPPLIER_SITE_ASSIGNMENTS start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);

        sup_preamble(p_run_id, C_CEMLI, C_OBJ, p_skip_bu_refresh);

        DMT_POZ_SUP_VALIDATOR_PKG.VALIDATE_SITE_ASSIGNMENTS(p_run_id);
        COMMIT;

        DMT_POZ_SUP_TRANSFORM_PKG.TRANSFORM_SITE_ASSIGNMENTS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;

        DMT_POZ_SUP_SITE_ASSN_FBDI_GEN_PKG.GENERATE_FBDI(p_run_id, l_zip, l_filename);

        l_ok := sup_after_generate(p_run_id, C_CEMLI, C_OBJ, l_zip, l_filename);

        sup_finish(p_run_id, C_CEMLI, C_OBJ);

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
        C_PROC   CONSTANT VARCHAR2(40) := 'RUN_SUPPLIER_CONTACTS';
        C_CEMLI  CONSTANT VARCHAR2(30) := 'SupplierContacts';
        C_OBJ    CONSTANT VARCHAR2(30) := 'SupplierContacts';
        v_scenario_id NUMBER;
        l_zip         BLOB;
        l_filename    VARCHAR2(200);
        l_ok          BOOLEAN;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_SUPPLIER_CONTACTS start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);

        sup_preamble(p_run_id, C_CEMLI, C_OBJ, p_skip_bu_refresh);

        DMT_POZ_SUP_VALIDATOR_PKG.VALIDATE_CONTACTS(p_run_id);
        COMMIT;

        DMT_POZ_SUP_TRANSFORM_PKG.TRANSFORM_CONTACTS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;

        DMT_POZ_SUP_CONT_FBDI_GEN_PKG.GENERATE_FBDI(p_run_id, l_zip, l_filename);

        l_ok := sup_after_generate(p_run_id, C_CEMLI, C_OBJ, l_zip, l_filename);

        sup_finish(p_run_id, C_CEMLI, C_OBJ);

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
        C_PROC   CONSTANT VARCHAR2(40) := 'RUN_PURCHASE_ORDERS';
        C_CEMLI  CONSTANT VARCHAR2(30) := 'PurchaseOrders';
        C_OBJ    CONSTANT VARCHAR2(30) := 'PurchaseOrders';
        v_scenario_id  NUMBER;
        l_ucm_account  VARCHAR2(200);
        l_job_name     VARCHAR2(500);
        l_ifd          NUMBER;
        l_po_user      VARCHAR2(100);
        l_po_pass      VARCHAR2(100);
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
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_PURCHASE_ORDERS start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);

        sup_preamble(p_run_id, C_CEMLI, C_OBJ, p_skip_bu_refresh);

        -- Phase 1: pre-transform validation (Purchase Order document type).
        DMT_PO_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id, p_doc_type_filter => 'Purchase Order');
        COMMIT;

        -- Phase 2: transform STG -> TFM (headers, lines, line locations, distributions).
        DMT_PO_TRANSFORM_PKG.TRANSFORM_HEADERS(p_run_id, p_doc_type_filter => 'Purchase Order', p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_PO_TRANSFORM_PKG.TRANSFORM_LINES(p_run_id, p_doc_type_filter => 'Purchase Order', p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_PO_TRANSFORM_PKG.TRANSFORM_LINE_LOCS(p_run_id, p_doc_type_filter => 'Purchase Order', p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_PO_TRANSFORM_PKG.TRANSFORM_DISTS(p_run_id, p_doc_type_filter => 'Purchase Order', p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;

        -- ERP options + credentials for the load submissions.
        get_erp_options(
            p_cemli_code           => C_CEMLI,
            x_ucm_account          => l_ucm_account,
            x_import_job_name      => l_job_name,
            x_interface_details_id => l_ifd);
        DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS(C_CEMLI, l_po_user, l_po_pass);

        -- Phase 3+4: multi-BU load cycle. Each distinct PRC_BU_NAME gets its own
        -- FBDI zip, loadAndImportData call, and BIP reconciliation (inline per BU).
        FOR bu_rec IN (
            SELECT DISTINCT PRC_BU_NAME
            FROM   DMT_PO_HEADERS_INT_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS = 'STAGED'
            ORDER BY PRC_BU_NAME
        ) LOOP
            l_bu_count := l_bu_count + 1;
            DMT_UTIL_PKG.LOG(p_run_id,
                'PO BU cycle start: ' || bu_rec.PRC_BU_NAME,
                'INFO', C_PKG, C_OBJ || ' > ' || C_PROC);

            DMT_PO_FBDI_GEN_PKG.GENERATE_FBDI(
                p_run_id      => p_run_id,
                p_prc_bu_name => bu_rec.PRC_BU_NAME,
                x_fbdi_zip    => l_bu_zip,
                x_filename    => l_bu_filename,
                x_fbdi_csv_id => l_bu_csv_id);

            IF l_bu_zip IS NULL OR DBMS_LOB.GETLENGTH(l_bu_zip) = 0 THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    'No rows for BU ' || bu_rec.PRC_BU_NAME || '. Skipping.',
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
                CONTINUE;
            END IF;

            -- BU id via the one common lookup accessor (raises -20040 with a clear
            -- halt message if the BU is not resolvable).
            l_bu_id := DMT_UTIL_PKG.GET_LOOKUP('BU_NAME_TO_BU_ID', bu_rec.PRC_BU_NAME);
            l_buyer_id := DMT_UTIL_PKG.GET_CONFIG('PO_DEFAULT_BUYER_ID');
            l_req_bu_id := DMT_UTIL_PKG.GET_CONFIG('PO_DEFAULT_REQ_BU_ID');

            -- Arg 5 (Batch ID) is left blank on purpose: Import Orders then processes
            -- all pending interface rows for this BU, so PO partitions by Procurement
            -- BU only. The user's batch id still rides through on the interface
            -- BATCH_ID column for traceability -- a tracking value, not a load filter.
            l_bu_param := l_bu_id || ',' || l_buyer_id || ',' || 'SUBMIT' || ',' ||
                          l_req_bu_id || ',,' || 'N' || ',,' || 'N' || ',' ||
                          l_bu_id || '_' || TO_CHAR(p_run_id);
            DMT_UTIL_PKG.LOG(p_run_id,
                'PO ParameterList for ' || bu_rec.PRC_BU_NAME || ': ' || l_bu_param,
                'INFO', C_PKG, C_OBJ || ' > ' || C_PROC);

            po_submit_and_reconcile_one(
                p_run_id            => p_run_id,
                p_cemli_code        => C_CEMLI,
                p_obj               => C_OBJ,
                p_job_name          => l_job_name,
                p_interface_details => l_ifd,
                p_ucm_account       => l_ucm_account,
                p_fbdi_zip          => l_bu_zip,
                p_filename          => l_bu_filename,
                p_fbdi_csv_id       => l_bu_csv_id,
                p_param_list        => l_bu_param,
                p_group_label       => 'BU: ' || bu_rec.PRC_BU_NAME,
                p_username          => l_po_user,
                p_password          => l_po_pass,
                x_load_ess_id       => l_bu_load_id,
                x_import_ess_id     => l_bu_import_id,
                x_success           => l_bu_ok);

            IF NOT l_bu_ok THEN
                po_mark_bu_failed(p_run_id, C_CEMLI, bu_rec.PRC_BU_NAME, l_bu_load_id);
                CONTINUE;
            END IF;

            DMT_UTIL_PKG.LOG(p_run_id,
                'PO BU cycle complete: ' || bu_rec.PRC_BU_NAME,
                'INFO', C_PKG, C_OBJ || ' > ' || C_PROC);
        END LOOP;

        IF l_bu_count = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'No STAGED PO headers found. Skipping PurchaseOrders.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
            RETURN;
        END IF;

        -- Phase 5: FAILED-row accounting + completion log.
        po_finish(p_run_id, C_CEMLI, C_OBJ);

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
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);

        SELECT DMT_PIPELINE_RUN_SEQ.NEXTVAL INTO l_run_id FROM DUAL;
        SELECT TO_CHAR(DMT_RUN_PREFIX_SEQ.NEXTVAL) INTO l_prefix FROM DUAL;

        INSERT INTO DMT_PIPELINE_RUN_TBL (
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

        -- Backlog #8: run_one_object_type is retired. Dispatch to the object's own
        -- self-contained RUN_<object>() recipe with a STATIC CASE over the CEMLI code
        -- -- no dynamic SQL (design doc Coding Standards). Each recipe defaults
        -- p_skip_bu_refresh => FALSE, so it refreshes BU lookups up front exactly as
        -- run_one_object_type did on a standalone (non-pipeline) run. The set of codes
        -- below is exactly the set run_one_object_type handled; anything else raises
        -- ORA-20043 'Unknown CEMLI_CODE', preserving the pre-refactor behaviour.
        CASE p_cemli_code
            WHEN 'Suppliers'               THEN RUN_SUPPLIERS(l_run_id, p_scenario_name, p_run_mode);
            WHEN 'SupplierAddresses'       THEN RUN_SUPPLIER_ADDRESSES(l_run_id, p_scenario_name, p_run_mode);
            WHEN 'SupplierSites'           THEN RUN_SUPPLIER_SITES(l_run_id, p_scenario_name, p_run_mode);
            WHEN 'SupplierSiteAssignments' THEN RUN_SUPPLIER_SITE_ASSIGNMENTS(l_run_id, p_scenario_name, p_run_mode);
            WHEN 'SupplierContacts'        THEN RUN_SUPPLIER_CONTACTS(l_run_id, p_scenario_name, p_run_mode);
            WHEN 'PurchaseOrders'          THEN RUN_PURCHASE_ORDERS(l_run_id, p_scenario_name, p_run_mode);
            WHEN 'BlanketPOs'              THEN RUN_BLANKET_POS(l_run_id, p_scenario_name, p_run_mode);
            WHEN 'Contracts'               THEN RUN_CONTRACTS(l_run_id, p_scenario_name, p_run_mode);
            WHEN 'Requisitions'            THEN RUN_REQUISITIONS(l_run_id, p_scenario_name, p_run_mode);
            WHEN 'Items'                   THEN RUN_ITEMS(l_run_id, p_scenario_name, p_run_mode);
            WHEN 'ItemCategories'          THEN RUN_ITEM_CATEGORIES(l_run_id, p_scenario_name, p_run_mode);
            WHEN 'Customers'               THEN RUN_CUSTOMERS(l_run_id, p_scenario_name, p_run_mode);
            WHEN 'ARInvoices'              THEN RUN_AR_INVOICES(l_run_id, p_scenario_name, p_run_mode);
            WHEN 'APInvoices'              THEN RUN_AP_INVOICES(l_run_id, p_scenario_name, p_run_mode);
            WHEN 'MiscReceipts'            THEN RUN_MISC_RECEIPTS(l_run_id, p_scenario_name, p_run_mode);
            WHEN 'Projects'                THEN RUN_PROJECTS(l_run_id, p_scenario_name, p_run_mode);
            WHEN 'BillingEvents'           THEN RUN_BILLING_EVENTS(l_run_id, p_scenario_name, p_run_mode);
            WHEN 'Expenditures'            THEN RUN_EXPENDITURES(l_run_id, p_scenario_name, p_run_mode);
            WHEN 'Grants'                  THEN RUN_GRANTS(l_run_id, p_scenario_name, p_run_mode);
            WHEN 'GLBalances'              THEN RUN_GL_BALANCES(l_run_id, p_scenario_name, p_run_mode);
            WHEN 'GLBudgets'               THEN RUN_GL_BUDGETS(l_run_id, p_scenario_name, p_run_mode);
            WHEN 'PlanningBudgets'         THEN RUN_PLAN_BUDGETS(l_run_id, p_scenario_name, p_run_mode);
            WHEN 'ProjectBudgets'          THEN RUN_PROJECT_BUDGETS(l_run_id, p_scenario_name, p_run_mode);
            WHEN 'Assets'                  THEN RUN_ASSETS(l_run_id, p_scenario_name, p_run_mode);
            ELSE
                RAISE_APPLICATION_ERROR(-20043,
                    'RUN_STANDALONE: Unknown CEMLI_CODE = ''' || p_cemli_code || '''.');
        END CASE;

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
        SELECT DMT_PIPELINE_RUN_SEQ.NEXTVAL INTO l_run_id FROM DUAL;
        SELECT TO_CHAR(DMT_RUN_PREFIX_SEQ.NEXTVAL) INTO l_prefix FROM DUAL;

        INSERT INTO DMT_PIPELINE_RUN_TBL (
            RUN_ID, INTEGRATION_ID, PIPELINE_CODES, RUN_TYPE,
            SUBMITTED_BY, RUN_STATUS, PREFIX, CEMLI_SEQUENCE,
            SCENARIO_NAME, RUN_MODE
        ) VALUES (
            l_run_id, l_run_id, 'ProcureToPay', 'PIPELINE',
            'MANUAL', 'IN_PROGRESS', l_prefix,
            'Suppliers,SupplierAddresses,SupplierSites,SupplierSiteAssignments,SupplierContacts,PurchaseOrders,BlanketPOs,ContractPOs,APInvoices,Requisitions',
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

        -- AP Invoices (headers + lines, grouped by operating unit).
        -- 1099 invoices are a filtered subset of AP (invoice type LIKE '%1099%'),
        -- not a separate object, so RUN_AP_INVOICES covers them — there is no
        -- separate 1099 run.
        RUN_AP_INVOICES(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);

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
    -- RUN_CUSTOMERS (public) — self-contained recipe (backlog #8, fourth family).
    -- GROUPED by (BATCH_ID, source system): one FBDI zip + one "Import Bulk
    -- Customer Data" (CDMAutoBulkImportJob) load + one BIP reconcile per batch, all
    -- inline in a single work-queue item. NOT spawn-per-partition (no
    -- CHILD_PARTITION_COLUMN / PARTITION_KEYS_PROC), so g_partition_key is always
    -- NULL and the whole batch loop runs in one EXECUTE_ONE call -- same shape as
    -- the Purchasing family. Behaviour is byte-for-byte the pre-refactor Customers
    -- block of run_one_object_type.
    -- --------------------------------------------------------
    PROCEDURE RUN_CUSTOMERS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC   CONSTANT VARCHAR2(40) := 'RUN_CUSTOMERS';
        C_CEMLI  CONSTANT VARCHAR2(30) := 'Customers';
        C_OBJ    CONSTANT VARCHAR2(30) := 'Customers';
        v_scenario_id  NUMBER;
        l_ucm_account  VARCHAR2(200);
        l_job_name     VARCHAR2(500);
        l_ifd          NUMBER;
        l_cu_user      VARCHAR2(100);
        l_cu_pass      VARCHAR2(100);
        l_cu_zip       BLOB;
        l_cu_filename  VARCHAR2(200);
        l_cu_csv_id    NUMBER;
        l_cu_load_id   VARCHAR2(100);
        l_cu_import_id VARCHAR2(100);
        l_cu_param     VARCHAR2(500);
        l_cu_count     NUMBER := 0;
        l_cu_ok        BOOLEAN;

        -- Fail every one of the 7 customer sub-object TFM tables' GENERATED rows for
        -- this batch, with a reportable error. Static SQL, identical to the original
        -- Customers on-fail cascade in run_one_object_type.
        PROCEDURE mark_batch_failed(p_bid IN NUMBER, p_msg IN VARCHAR2) IS
        BEGIN
            UPDATE DMT_HZ_PARTIES_TFM_TBL         SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,p_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED' AND BATCH_ID=p_bid;
            UPDATE DMT_HZ_LOCATIONS_TFM_TBL       SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,p_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED' AND BATCH_ID=p_bid;
            UPDATE DMT_HZ_PARTY_SITES_TFM_TBL     SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,p_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED' AND BATCH_ID=p_bid;
            UPDATE DMT_HZ_PARTY_SITE_USES_TFM_TBL SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,p_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED' AND BATCH_ID=p_bid;
            UPDATE DMT_HZ_ACCOUNTS_TFM_TBL        SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,p_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED' AND BATCH_ID=p_bid;
            UPDATE DMT_HZ_ACCT_SITES_TFM_TBL      SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,p_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED' AND BATCH_ID=p_bid;
            UPDATE DMT_HZ_ACCT_SITE_USES_TFM_TBL  SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,p_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED' AND BATCH_ID=p_bid;
            COMMIT;
        END mark_batch_failed;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_CUSTOMERS start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);

        sup_preamble(p_run_id, C_CEMLI, C_OBJ, p_skip_bu_refresh);

        -- Phase 1: pre-transform validation.
        DMT_CUST_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
        COMMIT;

        -- Phase 2: transform STG -> TFM across all 7 customer sub-object tables.
        DMT_CUST_TRANSFORM_PKG.TRANSFORM_PARTIES(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_CUST_TRANSFORM_PKG.TRANSFORM_LOCATIONS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_CUST_TRANSFORM_PKG.TRANSFORM_PARTY_SITES(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_CUST_TRANSFORM_PKG.TRANSFORM_PARTY_SITE_USES(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_CUST_TRANSFORM_PKG.TRANSFORM_ACCOUNTS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_CUST_TRANSFORM_PKG.TRANSFORM_ACCT_SITES(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_CUST_TRANSFORM_PKG.TRANSFORM_ACCT_SITE_USES(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;

        -- ERP options + credentials for the load submissions.
        get_erp_options(
            p_cemli_code           => C_CEMLI,
            x_ucm_account          => l_ucm_account,
            x_import_job_name      => l_job_name,
            x_interface_details_id => l_ifd);
        DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS(C_CEMLI, l_cu_user, l_cu_pass);

        -- Phase 3+4: per-batch load cycle. One FBDI + one load per (BATCH_ID, source
        -- system); the batch id comes from the CSV and one batch uses exactly one
        -- source system. The load job MUST be "Import Bulk Customer Data" (job def
        -- CDMAutoBulkImportJob), which CREATES the import batch from a 4-value
        -- positional ParameterList and processes it (proven by manual ESS run
        -- 9731634); the object arg MUST be the code 'CUSTOMER'.
        FOR grp_rec IN (
            SELECT BATCH_ID,
                   MIN(PARTY_ORIG_SYSTEM)            AS SOURCE_SYSTEM,
                   COUNT(DISTINCT PARTY_ORIG_SYSTEM) AS SRC_COUNT
            FROM   DMT_HZ_PARTIES_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS = 'STAGED'
            AND    BATCH_ID IS NOT NULL
            GROUP BY BATCH_ID
            ORDER BY BATCH_ID
        ) LOOP
            l_cu_count := l_cu_count + 1;

            -- One batch = one source system (a single positional ESS parameter).
            IF grp_rec.SRC_COUNT > 1 THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    'Customer batch ' || grp_rec.BATCH_ID || ' mixes ' || grp_rec.SRC_COUNT ||
                    ' source systems -- a batch must use exactly one. Marking FAILED.',
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
                mark_batch_failed(grp_rec.BATCH_ID,
                    '[PRE_VALIDATION] Batch ' || grp_rec.BATCH_ID ||
                    ' mixes multiple source systems; one batch must use exactly one source system.');
                CONTINUE;
            END IF;

            DMT_UTIL_PKG.LOG(p_run_id,
                'Customer batch cycle start: BATCH_ID=' || grp_rec.BATCH_ID ||
                ', Source=' || grp_rec.SOURCE_SYSTEM,
                'INFO', C_PKG, C_OBJ || ' > ' || C_PROC);

            DMT_CUST_FBDI_GEN_PKG.GENERATE_FBDI(
                p_run_id      => p_run_id,
                x_fbdi_zip    => l_cu_zip,
                x_filename    => l_cu_filename,
                x_fbdi_csv_id => l_cu_csv_id,
                p_batch_id    => grp_rec.BATCH_ID);

            IF l_cu_zip IS NULL OR DBMS_LOB.GETLENGTH(l_cu_zip) = 0 THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    'No rows for customer batch ' || grp_rec.BATCH_ID || '. Skipping.',
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
                CONTINUE;
            END IF;

            -- ParameterList for "Import Bulk Customer Data" (CDMAutoBulkImportJob),
            -- which CREATES the import batch from these 4 positional args:
            -- 1=Batch ID (from the CSV), 2=Batch Name, 3=Object CODE ('CUSTOMER' --
            -- NOT 'Customer and Consumer', which silently fails to create the batch),
            -- 4=Source System.
            l_cu_param := TO_CHAR(grp_rec.BATCH_ID)
                || ',Batch ID ' || TO_CHAR(grp_rec.BATCH_ID) || ' ' || grp_rec.SOURCE_SYSTEM
                || ',CUSTOMER'
                || ',' || grp_rec.SOURCE_SYSTEM;
            DMT_UTIL_PKG.LOG(p_run_id,
                'Customer ParameterList: ' || l_cu_param,
                'INFO', C_PKG, C_OBJ || ' > ' || C_PROC);

            po_submit_and_reconcile_one(
                p_run_id            => p_run_id,
                p_cemli_code        => C_CEMLI,
                p_obj               => C_OBJ,
                p_job_name          => l_job_name,
                p_interface_details => l_ifd,
                p_ucm_account       => l_ucm_account,
                p_fbdi_zip          => l_cu_zip,
                p_filename          => l_cu_filename,
                p_fbdi_csv_id       => l_cu_csv_id,
                p_param_list        => l_cu_param,
                p_group_label       => 'Batch: ' || grp_rec.BATCH_ID,
                p_username          => l_cu_user,
                p_password          => l_cu_pass,
                x_load_ess_id       => l_cu_load_id,
                x_import_ess_id     => l_cu_import_id,
                x_success           => l_cu_ok);

            IF NOT l_cu_ok THEN
                mark_batch_failed(grp_rec.BATCH_ID,
                    '[LOAD_ERROR] Loading customer batch ' || grp_rec.BATCH_ID ||
                    ' to the Fusion interface failed. Check ESS job ' || l_cu_load_id || ' logs.');
                CONTINUE;
            END IF;

            DMT_UTIL_PKG.LOG(p_run_id,
                'Customer batch cycle complete: BATCH_ID=' || grp_rec.BATCH_ID,
                'INFO', C_PKG, C_OBJ || ' > ' || C_PROC);
        END LOOP;

        IF l_cu_count = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'No STAGED Customer rows with a batch id found. Skipping Customers.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
            RETURN;
        END IF;

        -- Phase 5: FAILED-row accounting + completion log (counts the parties TFM
        -- table, as the monolith grouped_finish did for Customers).
        DECLARE
            l_failed_count NUMBER;
        BEGIN
            SELECT COUNT(*) INTO l_failed_count
            FROM DMT_HZ_PARTIES_TFM_TBL
            WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';
            IF l_failed_count > 0 THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    C_CEMLI || ': ' || l_failed_count || ' record(s) FAILED in Fusion. ' ||
                    'Downstream object types will continue — check staging table for details.',
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
            END IF;
        END;

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
    -- RUN_AR_INVOICES (public) — self-contained recipe (backlog #8, fourth family).
    -- GROUPED by (BU_NAME, BATCH_SOURCE_NAME): one FBDI zip + one loadAndImportData +
    -- the AutoInvoiceMasterEss second job + one BIP reconcile per group, all inline
    -- in a single work-queue item (NOT spawn-per-partition -- ARInvoices is in
    -- DMT_CEMLI_SPLIT_CFG with CHILD_PARTITION_COLUMN NULL, so it loads as one work
    -- item like the Purchasing family). Uses ar_submit_and_reconcile_one for the AR
    -- two-job flow. Upstream dependency: customers must be LOADED. Behaviour is
    -- byte-for-byte the pre-refactor ARInvoices block of run_one_object_type.
    -- --------------------------------------------------------
    PROCEDURE RUN_AR_INVOICES (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC   CONSTANT VARCHAR2(40) := 'RUN_AR_INVOICES';
        C_CEMLI  CONSTANT VARCHAR2(30) := 'ARInvoices';
        C_OBJ    CONSTANT VARCHAR2(30) := 'ARInvoices';
        v_scenario_id  NUMBER;
        l_ucm_account  VARCHAR2(200);
        l_job_name     VARCHAR2(500);
        l_ifd          NUMBER;
        l_ar_user      VARCHAR2(100);
        l_ar_pass      VARCHAR2(100);
        l_ar_zip       BLOB;
        l_ar_filename  VARCHAR2(200);
        l_ar_csv_id    NUMBER;
        l_ar_load_id   VARCHAR2(100);
        l_ar_import_id VARCHAR2(100);
        l_ar_param     VARCHAR2(500);
        l_ar_count     NUMBER := 0;
        l_ar_ok        BOOLEAN;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_AR_INVOICES start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);

        sup_preamble(p_run_id, C_CEMLI, C_OBJ, p_skip_bu_refresh);

        -- Phase 1: pre-transform validation.
        DMT_AR_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
        COMMIT;

        -- Phase 2: transform STG -> TFM (lines + distributions).
        DMT_AR_TRANSFORM_PKG.TRANSFORM_LINES(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_AR_TRANSFORM_PKG.TRANSFORM_DISTS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;

        -- ERP options + credentials for the load submissions.
        get_erp_options(
            p_cemli_code           => C_CEMLI,
            x_ucm_account          => l_ucm_account,
            x_import_job_name      => l_job_name,
            x_interface_details_id => l_ifd);
        DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS(C_CEMLI, l_ar_user, l_ar_pass);

        -- Phase 3+4: per-group load cycle. Each distinct (BU_NAME, BATCH_SOURCE_NAME)
        -- gets its own FBDI zip, loadAndImportData call, AutoInvoiceMasterEss second
        -- job, and BIP reconciliation (inline per group).
        FOR grp_rec IN (
            SELECT DISTINCT BU_NAME, BATCH_SOURCE_NAME
            FROM   DMT_RA_LINES_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS = 'STAGED'
            ORDER BY BU_NAME, BATCH_SOURCE_NAME
        ) LOOP
            l_ar_count := l_ar_count + 1;
            DMT_UTIL_PKG.LOG(p_run_id,
                'AR group cycle start: BU=' || grp_rec.BU_NAME ||
                ', Source=' || grp_rec.BATCH_SOURCE_NAME,
                'INFO', C_PKG, C_OBJ || ' > ' || C_PROC);

            DMT_AR_FBDI_GEN_PKG.GENERATE_FBDI(
                p_run_id            => p_run_id,
                p_bu_name           => grp_rec.BU_NAME,
                p_batch_source_name => grp_rec.BATCH_SOURCE_NAME,
                x_fbdi_zip          => l_ar_zip,
                x_filename          => l_ar_filename,
                x_fbdi_csv_id       => l_ar_csv_id);

            IF l_ar_zip IS NULL OR DBMS_LOB.GETLENGTH(l_ar_zip) = 0 THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    'No rows for BU=' || grp_rec.BU_NAME ||
                    ', Source=' || grp_rec.BATCH_SOURCE_NAME || '. Skipping.',
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
                CONTINUE;
            END IF;

            -- 24-arg ParameterList for AutoInvoiceImportEss.
            l_ar_param := grp_rec.BU_NAME || ',' || grp_rec.BATCH_SOURCE_NAME
                || ',' || TO_CHAR(SYSDATE, 'YYYY-MM-DD')
                || ',#NULL,#NULL,#NULL,#NULL,#NULL,#NULL,#NULL,#NULL,#NULL'
                || ',#NULL,#NULL,#NULL,#NULL,#NULL,#NULL,#NULL,#NULL,#NULL'
                || ',#NULL,N,#NULL';
            DMT_UTIL_PKG.LOG(p_run_id,
                'AR ParameterList: ' || l_ar_param,
                'INFO', C_PKG, C_OBJ || ' > ' || C_PROC);

            ar_submit_and_reconcile_one(
                p_run_id            => p_run_id,
                p_cemli_code        => C_CEMLI,
                p_obj               => C_OBJ,
                p_job_name          => l_job_name,
                p_interface_details => l_ifd,
                p_ucm_account       => l_ucm_account,
                p_fbdi_zip          => l_ar_zip,
                p_filename          => l_ar_filename,
                p_fbdi_csv_id       => l_ar_csv_id,
                p_param_list        => l_ar_param,
                p_group_label       => 'BU: ' || grp_rec.BU_NAME || ', Source: ' || grp_rec.BATCH_SOURCE_NAME,
                p_username          => l_ar_user,
                p_password          => l_ar_pass,
                x_load_ess_id       => l_ar_load_id,
                x_import_ess_id     => l_ar_import_id,
                x_success           => l_ar_ok);

            IF NOT l_ar_ok THEN
                DECLARE
                    l_err VARCHAR2(500) := '[LOAD_ERROR] Loading data to the Fusion interface failed. Check ESS job ' || l_ar_load_id || ' logs for details.';
                BEGIN
                    UPDATE DMT_RA_LINES_TFM_TBL
                    SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err)
                    WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED'
                    AND BU_NAME=grp_rec.BU_NAME AND BATCH_SOURCE_NAME=grp_rec.BATCH_SOURCE_NAME;
                    UPDATE DMT_RA_DISTS_TFM_TBL
                    SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err)
                    WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED'
                    AND BU_NAME=grp_rec.BU_NAME;
                    COMMIT;
                END;
                CONTINUE;
            END IF;

            -- Check for rows still at GENERATED after BIP reconciliation.
            DECLARE
                l_gen_count  NUMBER;
            BEGIN
                SELECT COUNT(*) INTO l_gen_count
                FROM   DMT_RA_LINES_TFM_TBL
                WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED'
                AND    BU_NAME = grp_rec.BU_NAME AND BATCH_SOURCE_NAME = grp_rec.BATCH_SOURCE_NAME;
                IF l_gen_count > 0 THEN
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'WARNING: ' || l_gen_count || ' AR rows still at GENERATED after BIP reconciliation ' ||
                        '(BU: ' || grp_rec.BU_NAME || ', Source: ' || grp_rec.BATCH_SOURCE_NAME || '). ' ||
                        'These rows were not matched by BIP and require manual investigation.',
                        DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
                END IF;
            END;

            DMT_UTIL_PKG.LOG(p_run_id,
                'AR group cycle complete: BU=' || grp_rec.BU_NAME ||
                ', Source=' || grp_rec.BATCH_SOURCE_NAME,
                'INFO', C_PKG, C_OBJ || ' > ' || C_PROC);
        END LOOP;

        IF l_ar_count = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'No STAGED AR invoice lines found. Skipping ARInvoices.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
            RETURN;
        END IF;

        -- Phase 5: FAILED-row accounting + completion log (counts the AR lines TFM
        -- table, as the monolith grouped_finish did for ARInvoices).
        DECLARE
            l_failed_count NUMBER;
        BEGIN
            SELECT COUNT(*) INTO l_failed_count
            FROM DMT_RA_LINES_TFM_TBL
            WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';
            IF l_failed_count > 0 THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    C_CEMLI || ': ' || l_failed_count || ' record(s) FAILED in Fusion. ' ||
                    'Downstream object types will continue — check staging table for details.',
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
            END IF;
        END;

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
    -- RUN_BILLING_EVENTS (public) — self-contained recipe (backlog #8, final family).
    -- SINGLE-LOAD FBDI object (one zip for the whole object; not grouped, not
    -- partitioned). ParameterList '#NULL'. Behaviour is byte-for-byte the pre-refactor
    -- BillingEvents single-load path of run_one_object_type.
    PROCEDURE RUN_BILLING_EVENTS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC   CONSTANT VARCHAR2(40) := 'RUN_BILLING_EVENTS';
        C_CEMLI  CONSTANT VARCHAR2(30) := 'BillingEvents';
        C_OBJ    CONSTANT VARCHAR2(30) := 'BillingEvents';
        v_scenario_id NUMBER;
        l_zip         BLOB;
        l_filename    VARCHAR2(200);
        l_csv_id      NUMBER;
        l_ok          BOOLEAN;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_BILLING_EVENTS start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);

        sup_preamble(p_run_id, C_CEMLI, C_OBJ, p_skip_bu_refresh);

        -- Phase 1: pre-transform validation.
        DMT_BILLING_EVENT_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
        COMMIT;

        -- Phase 2: transform STG -> TFM.
        DMT_BILLING_EVENT_TRANSFORM_PKG.TRANSFORM_EVENTS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;

        -- Phase 3: generate the FBDI zip.
        DMT_BILLING_EVENT_FBDI_GEN_PKG.GENERATE_FBDI(p_run_id, l_zip, l_filename, l_csv_id);

        -- Phase 4: submit + (async return | poll + import + reconcile). '#NULL' param list.
        l_ok := fin_after_generate(p_run_id, C_CEMLI, C_OBJ, l_zip, l_filename, '#NULL');

        -- Phase 5: FAILED-row accounting + completion log.
        fin_finish(p_run_id, C_CEMLI, C_OBJ);

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
    -- RUN_EXPENDITURES (public) — self-contained recipe (backlog #8, final family).
    -- SPAWN-PER-PARTITION by the COMPOSITE key (USER_TRANSACTION_SOURCE, DOCUMENT_NAME)
    -- -- "Import and Process Cost Transactions" filters on exactly one of each, so one
    -- child == one (source, document) group (row in DMT_CEMLI_SPLIT_CFG with
    -- CHILD_PARTITION_COLUMN=USER_TRANSACTION_SOURCE + a GET_PARTITION_KEYS). Serves
    -- the three passes: (1) PARENT transform-only pass validates + transforms once and
    -- returns before generate; (2) CHILD load pass (g_partition_key set to the composite
    -- JSON key) does the TWO-STEP load for ONLY that group; (3) legacy standalone.
    -- TWO-STEP: loadAndImportData only STAGES rows into PJC_TXN_XFACE_STAGE_ALL (it does
    -- NOT chain the costing import for PJC on this product), then a SEPARATE
    -- ImportProcessParallelEssJob (the "Import Costs" job) validates + costs into base
    -- PJC_EXP_ITEMS_ALL. Reconciles inline via DMT_EXPENDITURE_RESULTS_PKG (sets
    -- g_reconciled_inline). Behaviour is byte-for-byte the pre-refactor Expenditures
    -- block of run_one_object_type (both its top-of-function ParameterList build and
    -- its two-step load block, relocated here).
    PROCEDURE RUN_EXPENDITURES (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC   CONSTANT VARCHAR2(40) := 'RUN_EXPENDITURES';
        C_CEMLI  CONSTANT VARCHAR2(30) := 'Expenditures';
        C_OBJ    CONSTANT VARCHAR2(30) := 'Expenditures';
        v_scenario_id   NUMBER;
        l_ucm_account   VARCHAR2(200);
        l_job_name      VARCHAR2(500);
        l_ifd           NUMBER;
        l_param_list    VARCHAR2(500);
        l_ex_batch      VARCHAR2(60);
        l_ex_zip        BLOB;
        l_ex_filename   VARCHAR2(200);
        l_ex_csv_id     NUMBER;
        l_ex_load_id    VARCHAR2(100);
        l_ex_import_id  VARCHAR2(100);
        l_ex_status     VARCHAR2(50);
        l_ex_rows       NUMBER := 0;
        l_ex_user       VARCHAR2(100);
        l_ex_pass       VARCHAR2(100);
        -- Spawn-per-partition: a spawned CHILD is scoped to one (source, document)
        -- group. Decode the child's two partition names; both null on the parent /
        -- legacy standalone path.
        l_ex_src        VARCHAR2(240) := DMT_LOADER_PKG.DECODE_PARTITION_KEY(g_partition_key, 'USER_TRANSACTION_SOURCE');
        l_ex_doc        VARCHAR2(240) := DMT_LOADER_PKG.DECODE_PARTITION_KEY(g_partition_key, 'DOCUMENT_NAME');
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_EXPENDITURES start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);

        sup_preamble(p_run_id, C_CEMLI, C_OBJ, p_skip_bu_refresh);

        -- Phase 1+2 run ONLY on the parent transform-only pass (g_partition_key NULL).
        -- A spawned child was already validated + transformed by its parent;
        -- re-transforming would reset its STAGED rows. Mirrors the monolith gate.
        IF g_partition_key IS NULL THEN
            DMT_EXPENDITURE_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
            COMMIT;
            DMT_EXPENDITURE_TRANSFORM_PKG.TRANSFORM_EXPENDITURES(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
            COMMIT;
        END IF;

        -- Parent transform-only pass: stop here. The queue worker reads the distinct
        -- (source, document) keys and spawns one child work item per key. Mirrors the
        -- monolith transform-only gate.
        IF g_transform_only THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'RUN_EXPENDITURES transform-only pass complete (spawn-per-partition parent).',
                'INFO', C_PKG, C_PROC);
            RETURN;
        END IF;

        -- ERP options + credentials. l_job_name resolves to the comma form
        -- (onestop,ImportProcessParallelEssJob) via get_erp_options.
        get_erp_options(
            p_cemli_code           => C_CEMLI,
            x_ucm_account          => l_ucm_account,
            x_import_job_name      => l_job_name,
            x_interface_details_id => l_ifd);
        DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS(C_CEMLI, l_ex_user, l_ex_pass);

        -- Build the 13-arg ImportProcessParallelEssJob ("Import Costs") ParameterList
        -- (proven live, UI run 9777408). Relocated verbatim from the Expenditures arm
        -- of the retired run_one_object_type top-of-function ParameterList ladder.
        DECLARE
            l_exp_bu_name    VARCHAR2(240);
            l_exp_bu_id      VARCHAR2(30);
            l_exp_src_id     VARCHAR2(30);
            l_exp_doc_id     VARCHAR2(30);
            -- Source/document NAMES used only to resolve the ParameterList ids. On a
            -- spawned CHILD they are the decoded key (l_ex_src / l_ex_doc, both non-null).
            -- On the legacy standalone path (g_partition_key NULL) the key decodes to NULL,
            -- so read them informationally from the staged rows (first values seen), exactly
            -- as the retired run_one_object_type Expenditures arm did on its un-partitioned
            -- pass. These are LOCAL to the ParameterList build: the procedure-scoped
            -- l_ex_src / l_ex_doc stay NULL on the standalone path so the generate / update /
            -- count below scope over the WHOLE staged set (their "IS NULL OR ..." clauses),
            -- matching the monolith's standalone submit which never narrowed to one group.
            l_exp_src_name   VARCHAR2(240) := l_ex_src;
            l_exp_doc_name   VARCHAR2(240) := l_ex_doc;
        BEGIN
            l_exp_bu_name := DMT_UTIL_PKG.GET_CONFIG('EXPENDITURE_BU_NAME');
            l_exp_bu_id   := DMT_UTIL_PKG.GET_LOOKUP('BU_NAME_TO_BU_ID', l_exp_bu_name);

            -- Legacy standalone path: no spawn key, so populate the informational names.
            IF g_partition_key IS NULL THEN
                SELECT MAX(USER_TRANSACTION_SOURCE), MAX(DOCUMENT_NAME)
                INTO   l_exp_src_name, l_exp_doc_name
                FROM   DMT_PJC_EXPENDITURES_STG_TBL
                WHERE  (v_scenario_id IS NULL OR SCENARIO_ID = v_scenario_id)
                AND    (   (p_run_mode = 'NEW'    AND STG_STATUS IN ('NEW','RETRY'))
                        OR (p_run_mode = 'FAILED' AND STG_STATUS = 'FAILED')
                        OR (p_run_mode = 'ALL') );
            END IF;

            -- Guard the no-usable-source/document case on the CHILD path only. A spawned
            -- child whose decoded key is null cannot build the import filter safely.
            -- (GET_PARTITION_KEYS excludes null-source/document rows, so a real child
            -- always has both; this is a defensive backstop.) The legacy standalone path
            -- (g_partition_key NULL) must NOT raise here — it runs the whole staged set.
            IF g_partition_key IS NOT NULL AND (l_ex_src IS NULL OR l_ex_doc IS NULL) THEN
                RAISE_APPLICATION_ERROR(-20057,
                    'Expenditures: partition child carries no USER_TRANSACTION_SOURCE '||
                    'and DOCUMENT_NAME (key '||g_partition_key||'). Import and Process '||
                    'Cost Transactions needs both to build its source/document filter.');
            END IF;

            -- Source/document ids for the ParameterList. On the CHILD path (a real
            -- partitioned submit) these must resolve, so let GET_LOOKUP raise -20040
            -- loudly. On the legacy standalone path a picked informational source that
            -- happens not to resolve (or a null multi-source read) must not crash the
            -- run, so swallow it there and leave the id null — matching the monolith.
            IF g_partition_key IS NOT NULL THEN
                l_exp_src_id := DMT_UTIL_PKG.GET_LOOKUP('PJC_TXN_SOURCE_NAME_TO_ID', l_exp_src_name);
                l_exp_doc_id := DMT_UTIL_PKG.GET_LOOKUP('PJC_DOC_NAME_TO_ID', l_exp_doc_name);
            ELSE
                BEGIN
                    IF l_exp_src_name IS NOT NULL THEN
                        l_exp_src_id := DMT_UTIL_PKG.GET_LOOKUP('PJC_TXN_SOURCE_NAME_TO_ID', l_exp_src_name);
                    END IF;
                    IF l_exp_doc_name IS NOT NULL THEN
                        l_exp_doc_id := DMT_UTIL_PKG.GET_LOOKUP('PJC_DOC_NAME_TO_ID', l_exp_doc_name);
                    END IF;
                EXCEPTION WHEN OTHERS THEN
                    l_exp_src_id := NULL;
                    l_exp_doc_id := NULL;
                END;
            END IF;

            -- Expenditure Batch (arg 8): one batch name per (source, document) partition.
            -- Globally unique (a work-queue id) so it never collides on
            -- PJC_UNIQUE_BATCH_NAME and it isolates THIS child's rows from other pending
            -- interface rows at costing time. Same value stamped onto BATCH_NAME in this
            -- child's generated CSV rows below. Use g_work_queue_id (THIS child's queue
            -- id); fall back to the max queue id on the legacy/standalone path.
            IF g_work_queue_id IS NOT NULL THEN
                l_ex_batch := TO_CHAR(g_work_queue_id);
            ELSE
                SELECT TO_CHAR(MAX(QUEUE_ID)) INTO l_ex_batch
                FROM   DMT_WORK_QUEUE_TBL
                WHERE  RUN_ID = p_run_id AND CEMLI_CODE = C_CEMLI;
            END IF;

            -- 13 positions: 1 BU name  2 BU id  3 IMPORT_AND_PROCESS  4 PREV_NOT_IMPORTED
            --   5 (null)  6 txn-source id  7 document (null)  8 Expenditure Batch
            --   9-12 (null)  13 ORA_PJC_DETAIL (spawns the BIP detail report child).
            l_param_list := l_exp_bu_name
                || '~' || l_exp_bu_id
                || '~IMPORT_AND_PROCESS'
                || '~PREV_NOT_IMPORTED'
                || '~'
                || '~' || l_exp_src_id
                || '~'
                || '~' || l_ex_batch
                || '~~~~'
                || '~ORA_PJC_DETAIL';
        END;

        -- Stamp the run's single work-queue-id batch onto every one of this partition's
        -- rows' BATCH_NAME so the generated CSV carries it and it matches the arg-8
        -- Expenditure Batch filter. Scoped to this (source, document) partition.
        UPDATE DMT_PJC_EXPENDITURES_TFM_TBL
        SET    BATCH_NAME = l_ex_batch
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED'
        AND    (l_ex_src IS NULL OR USER_TRANSACTION_SOURCE = l_ex_src)
        AND    (l_ex_doc IS NULL OR DOCUMENT_NAME           = l_ex_doc);

        -- Phase 3: generate one FBDI zip for this partition's STAGED rows
        -- (rows move STAGED -> GENERATED).
        DMT_EXPENDITURE_FBDI_GEN_PKG.GENERATE_FBDI(
            p_run_id, l_ex_zip, l_ex_filename, l_ex_csv_id,
            p_txn_source => l_ex_src, p_document => l_ex_doc);

        -- Count only THIS partition's just-generated rows so an empty group skips cleanly.
        SELECT COUNT(*) INTO l_ex_rows
        FROM   DMT_PJC_EXPENDITURES_TFM_TBL
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED'
        AND    (l_ex_src IS NULL OR USER_TRANSACTION_SOURCE = l_ex_src)
        AND    (l_ex_doc IS NULL OR DOCUMENT_NAME           = l_ex_doc);

        IF l_ex_zip IS NULL OR DBMS_LOB.GETLENGTH(l_ex_zip) = 0 OR l_ex_rows = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'No STAGED Expenditure rows found. Skipping Expenditures.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
            COMMIT;
            RETURN;
        END IF;

        -- Step 1: Load File to Interface Tables (loadAndImportData). Stages the CSV into
        -- PJC_TXN_XFACE_STAGE_ALL at status 'P'. Takes NO costing ParameterList; the
        -- costing list is submitted with the SEPARATE import job in Step 2.
        l_ex_load_id := SUBMIT_LOAD(
            p_run_id            => p_run_id,
            p_fbdi_zip          => l_ex_zip,
            p_filename          => l_ex_filename,
            p_job_name          => l_job_name,
            p_interface_details => l_ifd,
            p_doc_account       => l_ucm_account,
            p_parameter_list    => '#NULL',
            p_log_context       => C_OBJ,
            p_username          => l_ex_user,
            p_password          => l_ex_pass);
        DBMS_LOB.FREETEMPORARY(l_ex_zip);

        UPDATE DMT_FBDI_ZIP_TBL SET PARAMETER_LIST = l_param_list
        WHERE  FBDI_ZIP_ID = (SELECT FBDI_ZIP_ID FROM DMT_FBDI_CSV_TBL
                              WHERE FBDI_CSV_ID = l_ex_csv_id);
        COMMIT;

        POLL_ESS_JOB(p_run_id, l_ex_load_id, 1800, FALSE, C_OBJ, C_CEMLI, l_ex_status,
                     p_username => l_ex_user, p_password => l_ex_pass);
        IF l_ex_status NOT IN (C_STATUS_SUCCEEDED, C_STATUS_WARNING) THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'Expenditure Load ESS ' || l_ex_load_id || ' returned ' || l_ex_status ||
                '. No rows staged. Marking GENERATED rows FAILED.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
            -- Fail only THIS partition's in-flight rows (spawn-per-partition isolation).
            UPDATE DMT_PJC_EXPENDITURES_TFM_TBL
            SET    TFM_STATUS = 'FAILED',
                   ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                       '[LOAD_ERROR] Load to PJC_TXN_XFACE_STAGE_ALL failed. Check ESS job ' || l_ex_load_id || '.'),
                   LAST_UPDATED_DATE = SYSDATE
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED'
            AND    (l_ex_src IS NULL OR USER_TRANSACTION_SOURCE = l_ex_src)
            AND    (l_ex_doc IS NULL OR DOCUMENT_NAME           = l_ex_doc);
            COMMIT;
            RETURN;
        END IF;

        -- Step 2: submit ImportProcessParallelEssJob (the "Import Costs" costing job) as
        -- a SEPARATE ESS request with the 13-arg ParameterList built above.
        DMT_UTIL_PKG.LOG(p_run_id,
            'Submitting Import Costs / ImportProcessParallelEssJob (separate ESS request). ParamList: '
            || l_param_list, 'INFO', C_PKG, C_OBJ || ' > ' || C_PROC);

        l_ex_import_id := SUBMIT_IMPORT_JOB(
            p_run_id     => p_run_id,
            p_job_name   => l_job_name,
            p_param_list => l_param_list);

        -- Poll the costing import to terminal. WARNING is normal when some rows reject.
        POLL_ESS_JOB(p_run_id, l_ex_import_id, 1800, FALSE, C_OBJ, C_CEMLI, l_ex_status,
                     p_username => l_ex_user, p_password => l_ex_pass);
        DMT_UTIL_PKG.LOG(p_run_id,
            'Import and Process Cost Transactions ' || l_ex_import_id || ' -> ' || l_ex_status,
            'INFO', C_PKG, C_OBJ || ' > ' || C_PROC);

        -- Capture the import report errors (per-record rejects) regardless of BIP outcome.
        BEGIN
            DECLARE l_ir_count NUMBER;
            BEGIN
                l_ir_count := DMT_IMPORT_REPORT_PKG.PARSE_AND_LOG_ERRORS(
                    p_run_id     => p_run_id,
                    p_request_id => TO_NUMBER(l_ex_import_id),
                    p_cemli_code => C_CEMLI);
            END;
        EXCEPTION WHEN OTHERS THEN NULL;
        END;

        -- Backlog #70: stamp THIS child's own load + import ess ids on its own queue row.
        stamp_item_ess_ids(l_ex_load_id, l_ex_import_id);

        -- Step 3: reconcile. Good rows appear in base PJC_EXP_ITEMS_ALL keyed by prefixed
        -- ORIG_TRANSACTION_REFERENCE -> LOADED. The reconciler decides per-record outcome.
        DMT_EXPENDITURE_RESULTS_PKG.RECONCILE_BATCH(
            p_run_id        => p_run_id,
            p_load_ess_id   => TO_NUMBER(l_ex_load_id),
            p_import_ess_id => TO_NUMBER(l_ex_import_id),
            p_work_queue_id => g_work_queue_id);

        -- Reconcile already ran inline here; EXECUTE_ONE must NOT re-reconcile. See #7.
        g_reconciled_inline := TRUE;

        -- Phase 5: FAILED-row accounting + completion log.
        fin_finish(p_run_id, C_CEMLI, C_OBJ);

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
    -- RUN_GRANTS (public) — self-contained recipe (backlog #8, final family).
    -- SINGLE-LOAD FBDI object (all award record types in one zip). ParameterList
    -- '#NULL,#NULL,#NULL' (AwardMassImportJob 3 optional args; discovered via MCCS,
    -- prior 'NEW,N' caused an ESS WAIT timeout). Behaviour is byte-for-byte the
    -- pre-refactor Grants single-load path of run_one_object_type.
    PROCEDURE RUN_GRANTS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC   CONSTANT VARCHAR2(40) := 'RUN_GRANTS';
        C_CEMLI  CONSTANT VARCHAR2(30) := 'Grants';
        C_OBJ    CONSTANT VARCHAR2(30) := 'Grants';
        v_scenario_id NUMBER;
        l_zip         BLOB;
        l_filename    VARCHAR2(200);
        l_csv_id      NUMBER;
        l_ok          BOOLEAN;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_GRANTS start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);

        sup_preamble(p_run_id, C_CEMLI, C_OBJ, p_skip_bu_refresh);

        -- Phase 1: pre-transform validation.
        DMT_GRANTS_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
        COMMIT;

        -- Phase 2: transform STG -> TFM across every award record type.
        DMT_GRANTS_TRANSFORM_PKG.TRANSFORM_HEADERS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_GRANTS_TRANSFORM_PKG.TRANSFORM_FUNDING(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_GRANTS_TRANSFORM_PKG.TRANSFORM_PROJECTS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_GRANTS_TRANSFORM_PKG.TRANSFORM_PERSONNEL(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_GRANTS_TRANSFORM_PKG.TRANSFORM_FUND_SOURCES(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_GRANTS_TRANSFORM_PKG.TRANSFORM_PRJ_FUND_SRCS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_GRANTS_TRANSFORM_PKG.TRANSFORM_KEYWORDS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_GRANTS_TRANSFORM_PKG.TRANSFORM_BUDGET_PERIODS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_GRANTS_TRANSFORM_PKG.TRANSFORM_CERTS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_GRANTS_TRANSFORM_PKG.TRANSFORM_CFDAS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_GRANTS_TRANSFORM_PKG.TRANSFORM_FUND_ALLOCS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_GRANTS_TRANSFORM_PKG.TRANSFORM_ORG_CREDITS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_GRANTS_TRANSFORM_PKG.TRANSFORM_PRJ_TASK_BURDEN(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_GRANTS_TRANSFORM_PKG.TRANSFORM_REFERENCES(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_GRANTS_TRANSFORM_PKG.TRANSFORM_TERMS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;

        -- Phase 3: generate the FBDI zip.
        DMT_GRANTS_FBDI_GEN_PKG.GENERATE_FBDI(p_run_id, l_zip, l_filename, l_csv_id);

        -- Phase 4: submit + (async return | poll + import + reconcile).
        l_ok := fin_after_generate(p_run_id, C_CEMLI, C_OBJ, l_zip, l_filename, '#NULL,#NULL,#NULL');

        -- Phase 5: FAILED-row accounting + completion log.
        fin_finish(p_run_id, C_CEMLI, C_OBJ);

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
    -- RUN_REQUISITIONS (public) — self-contained recipe (backlog #8, third family).
    -- Spawn-per-partition by BATCH_ID. Handles all three passes the queue / a direct
    -- caller can drive (see the family header above): parent transform-only, child
    -- single-batch load, and the legacy standalone all-batches loop.
    -- --------------------------------------------------------
    PROCEDURE RUN_REQUISITIONS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC   CONSTANT VARCHAR2(40) := 'RUN_REQUISITIONS';
        C_CEMLI  CONSTANT VARCHAR2(30) := 'Requisitions';
        C_OBJ    CONSTANT VARCHAR2(30) := 'Requisitions';
        v_scenario_id  NUMBER;
        l_ucm_account  VARCHAR2(200);
        l_job_name     VARCHAR2(500);
        l_ifd          NUMBER;
        l_rq_user      VARCHAR2(100);
        l_rq_pass      VARCHAR2(100);
        l_rq_zip       BLOB;
        l_rq_filename  VARCHAR2(200);
        l_rq_csv_id    NUMBER;
        l_rq_load_id   VARCHAR2(100);
        l_rq_import_id VARCHAR2(100);
        l_rq_param     VARCHAR2(500);
        l_rq_bu_id     VARCHAR2(30);
        l_rq_count     NUMBER := 0;
        l_rq_ok        BOOLEAN;

        -- Fail this batch's GENERATED rows across all 3 REQ TFM tables. Headers
        -- filter by BATCH_ID directly; lines/dists filter by their header's BATCH_ID
        -- (they carry no batch column). Static SQL, identical to the original
        -- Requisitions on-fail cascade in run_one_object_type.
        PROCEDURE mark_batch_failed(p_bid IN VARCHAR2, p_msg IN VARCHAR2) IS
        BEGIN
            UPDATE DMT_POR_REQ_HEADERS_TFM_TBL
            SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,p_msg)
            WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED' AND BATCH_ID=p_bid;

            UPDATE DMT_POR_REQ_LINES_TFM_TBL l
            SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,p_msg)
            WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED'
              AND EXISTS (SELECT 1 FROM DMT_POR_REQ_HEADERS_TFM_TBL h
                          WHERE h.RUN_ID=l.RUN_ID
                            AND h.INTERFACE_HEADER_KEY=l.INTERFACE_HEADER_KEY
                            AND h.BATCH_ID=p_bid);

            UPDATE DMT_POR_REQ_DISTS_TFM_TBL d
            SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,p_msg)
            WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED'
              AND EXISTS (SELECT 1
                          FROM DMT_POR_REQ_LINES_TFM_TBL l
                          JOIN DMT_POR_REQ_HEADERS_TFM_TBL h
                            ON h.RUN_ID=l.RUN_ID AND h.INTERFACE_HEADER_KEY=l.INTERFACE_HEADER_KEY
                          WHERE l.RUN_ID=d.RUN_ID
                            AND l.INTERFACE_LINE_KEY=d.INTERFACE_LINE_KEY
                            AND h.BATCH_ID=p_bid);
            COMMIT;
        END mark_batch_failed;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_REQUISITIONS start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);

        sup_preamble(p_run_id, C_CEMLI, C_OBJ, p_skip_bu_refresh);

        -- Phase 1+2 run ONLY on the parent transform-only pass (g_partition_key NULL,
        -- and not a spawned child). A spawned child (g_partition_key set) was already
        -- validated + transformed by its parent, so re-transforming would reset its
        -- STAGED rows — skip straight to the per-batch load. This mirrors the
        -- g_partition_key gate the monolith used for Requisitions.
        IF g_partition_key IS NULL THEN
            DMT_REQ_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
            COMMIT;
            DMT_REQ_TRANSFORM_PKG.TRANSFORM_HEADERS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
            DMT_REQ_TRANSFORM_PKG.TRANSFORM_LINES(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
            DMT_REQ_TRANSFORM_PKG.TRANSFORM_DISTS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
            COMMIT;
        END IF;

        -- Parent transform-only pass: stop here. The queue worker reads the distinct
        -- BATCH_IDs and spawns one child work item per batch (each re-enters this
        -- recipe with g_partition_key set). Mirrors the monolith transform-only gate.
        IF g_transform_only THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'RUN_REQUISITIONS transform-only pass complete (spawn-per-partition parent).',
                'INFO', C_PKG, C_PROC);
            RETURN;
        END IF;

        -- ERP options + credentials for the load submissions.
        get_erp_options(
            p_cemli_code           => C_CEMLI,
            x_ucm_account          => l_ucm_account,
            x_import_job_name      => l_job_name,
            x_interface_details_id => l_ifd);
        DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS(C_CEMLI, l_rq_user, l_rq_pass);

        -- Per-batch load cycle. A spawned child (g_partition_key set to its single
        -- BATCH_ID, JSON-encoded) runs the loop EXACTLY ONCE for that batch;
        -- DECODE_PARTITION_KEY yields the raw BATCH_ID to bind. The un-partitioned
        -- direct/standalone call (g_partition_key NULL) loops all of the run's
        -- batches. One batch = one requisitioning business unit = one FBDI zip =
        -- one RequisitionImportJob ESS run.
        FOR grp_rec IN (
            SELECT BATCH_ID,
                   MIN(REQ_BU_NAME)            AS REQ_BU_NAME,
                   COUNT(DISTINCT REQ_BU_NAME) AS BU_COUNT
            FROM   DMT_POR_REQ_HEADERS_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS = 'STAGED'
            AND    BATCH_ID IS NOT NULL
            AND    (g_partition_key IS NULL
                    OR BATCH_ID = DMT_LOADER_PKG.DECODE_PARTITION_KEY(g_partition_key, 'BATCH_ID'))
            GROUP BY BATCH_ID
            ORDER BY BATCH_ID
        ) LOOP
            l_rq_count := l_rq_count + 1;

            -- One batch = one requisitioning business unit.
            IF grp_rec.BU_COUNT > 1 THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    'Requisition batch ' || grp_rec.BATCH_ID || ' mixes ' || grp_rec.BU_COUNT ||
                    ' business units -- a batch must use exactly one. Marking FAILED.',
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
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
                'INFO', C_PKG, C_OBJ || ' > ' || C_PROC);

            DMT_REQ_FBDI_GEN_PKG.GENERATE_FBDI(
                p_run_id      => p_run_id,
                x_fbdi_zip    => l_rq_zip,
                x_filename    => l_rq_filename,
                x_fbdi_csv_id => l_rq_csv_id,
                p_batch_id    => grp_rec.BATCH_ID);

            IF l_rq_zip IS NULL OR DBMS_LOB.GETLENGTH(l_rq_zip) = 0 THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    'No rows for requisition batch ' || grp_rec.BATCH_ID || '. Skipping.',
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
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
                'INFO', C_PKG, C_OBJ || ' > ' || C_PROC);

            po_submit_and_reconcile_one(
                p_run_id            => p_run_id,
                p_cemli_code        => C_CEMLI,
                p_obj               => C_OBJ,
                p_job_name          => l_job_name,
                p_interface_details => l_ifd,
                p_ucm_account       => l_ucm_account,
                p_fbdi_zip          => l_rq_zip,
                p_filename          => l_rq_filename,
                p_fbdi_csv_id       => l_rq_csv_id,
                p_param_list        => l_rq_param,
                p_group_label       => 'Batch: ' || grp_rec.BATCH_ID,
                p_username          => l_rq_user,
                p_password          => l_rq_pass,
                x_load_ess_id       => l_rq_load_id,
                x_import_ess_id     => l_rq_import_id,
                x_success           => l_rq_ok);

            -- Backlog #70: stamp THIS child's own distinct load + import ess ids on
            -- its own queue row (no-op outside a queue-driven partition child).
            stamp_item_ess_ids(l_rq_load_id, l_rq_import_id);

            IF NOT l_rq_ok THEN
                mark_batch_failed(grp_rec.BATCH_ID,
                    '[LOAD_ERROR] Loading requisition batch ' || grp_rec.BATCH_ID ||
                    ' to the Fusion interface failed. Check ESS job ' || l_rq_load_id || ' logs.');
                CONTINUE;
            END IF;

            DMT_UTIL_PKG.LOG(p_run_id,
                'Requisition batch cycle complete: BATCH_ID=' || grp_rec.BATCH_ID,
                'INFO', C_PKG, C_OBJ || ' > ' || C_PROC);
        END LOOP;

        IF l_rq_count = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'No STAGED Requisition rows with a batch id found. Skipping Requisitions.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
            RETURN;
        END IF;

        -- FAILED-row accounting + completion log.
        DECLARE
            l_failed_count NUMBER;
        BEGIN
            SELECT COUNT(*) INTO l_failed_count
            FROM DMT_POR_REQ_HEADERS_TFM_TBL
            WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';
            IF l_failed_count > 0 THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    C_CEMLI || ': ' || l_failed_count || ' record(s) FAILED in Fusion. ' ||
                    'Downstream object types will continue — check staging table for details.',
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
            END IF;
        END;

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
    -- RUN_ITEMS (public) — self-contained recipe (backlog #8, third family).
    -- Spawn-per-partition by BATCH_ID. Items + bundled ItemCategories load in one
    -- FBDI ZIP under one ItemImportJobDef run. Handles the same three passes as
    -- RUN_REQUISITIONS (parent transform-only, child single-batch, standalone loop).
    -- --------------------------------------------------------
    PROCEDURE RUN_ITEMS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC   CONSTANT VARCHAR2(40) := 'RUN_ITEMS';
        C_CEMLI  CONSTANT VARCHAR2(30) := 'Items';
        C_OBJ    CONSTANT VARCHAR2(30) := 'Items';
        v_scenario_id  NUMBER;
        l_ucm_account  VARCHAR2(200);
        l_job_name     VARCHAR2(500);
        l_ifd          NUMBER;
        l_it_user      VARCHAR2(100);
        l_it_pass      VARCHAR2(100);
        l_it_zip       BLOB;
        l_it_filename  VARCHAR2(200);
        l_it_csv_id    NUMBER;
        l_it_load_id   VARCHAR2(100);
        l_it_import_id VARCHAR2(100);
        l_it_param     VARCHAR2(500);
        l_it_count     NUMBER := 0;
        l_it_ok        BOOLEAN;

        -- Fail this batch's GENERATED rows in BOTH bundled TFM tables. Each carries
        -- its own BATCH_ID column, so filter directly (no join). Static SQL,
        -- identical to the original Items on-fail cascade in run_one_object_type.
        PROCEDURE mark_batch_failed(p_bid IN VARCHAR2, p_msg IN VARCHAR2) IS
        BEGIN
            UPDATE DMT_EGP_ITEM_TFM_TBL
            SET TFM_STATUS='FAILED',
                ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,p_msg),
                LAST_UPDATED_DATE=SYSDATE
            WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED' AND BATCH_ID=TO_NUMBER(p_bid);

            UPDATE DMT_EGP_ITEM_CAT_TFM_TBL
            SET TFM_STATUS='FAILED',
                ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,p_msg),
                LAST_UPDATED_DATE=SYSDATE
            WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED' AND BATCH_ID=TO_NUMBER(p_bid);
            COMMIT;
        END mark_batch_failed;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_ITEMS start (includes ItemCategories bundled in same ZIP). Integration ID: ' || p_run_id,
            'INFO', C_PKG, C_PROC);

        sup_preamble(p_run_id, C_CEMLI, C_OBJ, p_skip_bu_refresh);

        -- Phase 1+2 run ONLY on the parent transform-only pass (g_partition_key NULL).
        -- A spawned child (g_partition_key set) was already validated + transformed by
        -- its parent, so skip straight to the per-batch load. Categories are validated
        -- + transformed under the Items token (bundled into the Items FBDI ZIP); there
        -- is no separate ItemCategories step in the pipeline sequence.
        IF g_partition_key IS NULL THEN
            DMT_EGP_ITEM_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
            DMT_EGP_ITEM_CAT_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
            COMMIT;
            DMT_EGP_ITEM_TRANSFORM_PKG.TRANSFORM(p_run_id, p_reprocess_errors => (p_run_mode = 'FAILED'), p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
            -- Transform bundled categories before the Items FBDI generator picks them up
            -- (DMT_EGP_ITEM_FBDI_GEN_PKG reads DMT_EGP_ITEM_CAT_TFM_TBL for the bundled CSV).
            DMT_EGP_ITEM_CAT_TRANSFORM_PKG.TRANSFORM(p_run_id, p_reprocess_errors => (p_run_mode = 'FAILED'), p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
            COMMIT;
        END IF;

        -- Parent transform-only pass: stop here. The queue worker reads the distinct
        -- BATCH_IDs and spawns one child work item per batch.
        IF g_transform_only THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'RUN_ITEMS transform-only pass complete (spawn-per-partition parent).',
                'INFO', C_PKG, C_PROC);
            RETURN;
        END IF;

        -- ERP options + credentials for the load submissions (Items submits under
        -- SCM_IMPL per the ItemImportJobDef interface-options row).
        get_erp_options(
            p_cemli_code           => C_CEMLI,
            x_ucm_account          => l_ucm_account,
            x_import_job_name      => l_job_name,
            x_interface_details_id => l_ifd);
        DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS(C_CEMLI, l_it_user, l_it_pass);

        -- Per-batch load cycle. A batch may have item rows, category rows, or both,
        -- so union both TFM tables for the complete set of distinct batch ids. A
        -- spawned child (g_partition_key set) runs the loop exactly once for its
        -- batch; the direct/standalone call (g_partition_key NULL) loops all batches.
        FOR grp_rec IN (
            SELECT TO_CHAR(BATCH_ID) AS BATCH_ID
            FROM   DMT_EGP_ITEM_TFM_TBL
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED' AND BATCH_ID IS NOT NULL
            AND    (g_partition_key IS NULL
                    OR TO_CHAR(BATCH_ID) = DMT_LOADER_PKG.DECODE_PARTITION_KEY(g_partition_key, 'BATCH_ID'))
            UNION
            SELECT TO_CHAR(BATCH_ID)
            FROM   DMT_EGP_ITEM_CAT_TFM_TBL
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED' AND BATCH_ID IS NOT NULL
            AND    (g_partition_key IS NULL
                    OR TO_CHAR(BATCH_ID) = DMT_LOADER_PKG.DECODE_PARTITION_KEY(g_partition_key, 'BATCH_ID'))
            ORDER BY 1
        ) LOOP
            l_it_count := l_it_count + 1;

            DMT_UTIL_PKG.LOG(p_run_id,
                'Item batch cycle start: BATCH_ID=' || grp_rec.BATCH_ID,
                'INFO', C_PKG, C_OBJ || ' > ' || C_PROC);

            DMT_EGP_ITEM_FBDI_GEN_PKG.GENERATE_FBDI(
                p_run_id      => p_run_id,
                x_fbdi_zip    => l_it_zip,
                x_filename    => l_it_filename,
                x_fbdi_csv_id => l_it_csv_id,
                p_batch_id    => grp_rec.BATCH_ID);

            IF l_it_zip IS NULL OR DBMS_LOB.GETLENGTH(l_it_zip) = 0 THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    'No rows for item batch ' || grp_rec.BATCH_ID || '. Skipping.',
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
                CONTINUE;
            END IF;

            -- ItemImportJobDef, 7 positional args (MCCS RICE_009 pattern).
            -- 1=BatchID (this batch), 2=Organization(null), 3=ProcessOnly=CREATE,
            -- 4=ProcessAllOrgs(null), 5=DeleteProcessedRows(null),
            -- 6=ReprocessError=N, 7=ProcessSequentially=Y.
            l_it_param := grp_rec.BATCH_ID || ',null,CREATE,null,null,N,Y';
            DMT_UTIL_PKG.LOG(p_run_id,
                'Item ParameterList: ' || l_it_param,
                'INFO', C_PKG, C_OBJ || ' > ' || C_PROC);

            po_submit_and_reconcile_one(
                p_run_id            => p_run_id,
                p_cemli_code        => C_CEMLI,
                p_obj               => C_OBJ,
                p_job_name          => l_job_name,
                p_interface_details => l_ifd,
                p_ucm_account       => l_ucm_account,
                p_fbdi_zip          => l_it_zip,
                p_filename          => l_it_filename,
                p_fbdi_csv_id       => l_it_csv_id,
                p_param_list        => l_it_param,
                p_group_label       => 'Batch: ' || grp_rec.BATCH_ID,
                p_username          => l_it_user,
                p_password          => l_it_pass,
                x_load_ess_id       => l_it_load_id,
                x_import_ess_id     => l_it_import_id,
                x_success           => l_it_ok);

            -- Items special case (kept from the monolith, deliberately NOT
            -- registry-expressible): the Items FBDI ZIP bundles the ItemCategories
            -- CSV, so on a successful load this item conditionally reconciles the
            -- categories too when this batch generated any category rows. A
            -- data-dependent secondary reconciler does not fit the one-RECON_PROC-
            -- per-object registry. Scoped by g_work_queue_id so a child touches only
            -- its own rows. po_submit_and_reconcile_one already ran the primary Items
            -- reconcile (RECONCILE_VIA_REGISTRY) and set g_reconciled_inline.
            IF l_it_ok THEN
                DECLARE l_cat_gen NUMBER;
                BEGIN
                    SELECT COUNT(*) INTO l_cat_gen FROM DMT_EGP_ITEM_CAT_TFM_TBL
                    WHERE RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED'
                    AND   (g_work_queue_id IS NULL OR WORK_QUEUE_ID = g_work_queue_id);
                    IF l_cat_gen > 0 THEN
                        DMT_EGP_ITEM_CAT_RESULTS_PKG.RECONCILE_BATCH(
                            p_run_id, TO_NUMBER(l_it_load_id), TO_NUMBER(l_it_import_id),
                            p_work_queue_id => g_work_queue_id);
                    END IF;
                END;
            END IF;

            -- Backlog #70: stamp THIS child's own distinct load + import ess ids on
            -- its own queue row (no-op outside a queue-driven partition child).
            stamp_item_ess_ids(l_it_load_id, l_it_import_id);

            IF NOT l_it_ok THEN
                mark_batch_failed(grp_rec.BATCH_ID,
                    '[LOAD_ERROR] Loading item batch ' || grp_rec.BATCH_ID ||
                    ' to the Fusion interface failed. Check ESS job ' || l_it_load_id || ' logs.');
                CONTINUE;
            END IF;

            DMT_UTIL_PKG.LOG(p_run_id,
                'Item batch cycle complete: BATCH_ID=' || grp_rec.BATCH_ID,
                'INFO', C_PKG, C_OBJ || ' > ' || C_PROC);
        END LOOP;

        IF l_it_count = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'No STAGED Item rows with a batch id found. Skipping Items.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
            RETURN;
        END IF;

        -- FAILED-row accounting (items + bundled categories) + completion log.
        DECLARE
            l_failed_count NUMBER;
        BEGIN
            SELECT COUNT(*) INTO l_failed_count
            FROM DMT_EGP_ITEM_TFM_TBL
            WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';
            SELECT l_failed_count + COUNT(*) INTO l_failed_count
            FROM DMT_EGP_ITEM_CAT_TFM_TBL
            WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';
            IF l_failed_count > 0 THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    C_CEMLI || ': ' || l_failed_count || ' record(s) FAILED in Fusion. ' ||
                    'Downstream object types will continue — check staging table for details.',
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
            END IF;
        END;

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
    -- RUN_MISC_RECEIPTS (public) — self-contained recipe (backlog #8, fourth family).
    -- SINGLE-LOAD SYNC object. loadAndImportData does NOT chain an import for INV
    -- transactions (interfaceDetails is a DMT-local id, not a real Fusion
    -- FUN_ERP_INTERFACE_OPTIONS row), so the import step submits PollTMEssJob
    -- explicitly -- it picks up all process_flag=1 rows and spawns SingleTMEssJob
    -- internally. Follows the single (Suppliers) pattern with that PollTMEssJob
    -- import substituted for get_import_ess_id. Reconciles inline. NOT
    -- spawn-per-partition (g_partition_key always NULL). Behaviour is byte-for-byte
    -- the pre-refactor MiscReceipts single-load path of run_one_object_type.
    --
    -- The dispatch registry marks MiscReceipts EXEC_MODE = SYNC, so the queue worker
    -- leaves g_async_mode FALSE and this recipe polls + reconciles inline. A direct
    -- RUN_MISC_RECEIPTS call is also g_async_mode FALSE. The g_async_mode guard is
    -- kept (returns after SUBMIT_LOAD) so the recipe is correct if the object is ever
    -- re-registered ASYNC -- mirrors sup_after_generate.
    -- --------------------------------------------------------
    PROCEDURE RUN_MISC_RECEIPTS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC   CONSTANT VARCHAR2(40) := 'RUN_MISC_RECEIPTS';
        C_CEMLI  CONSTANT VARCHAR2(30) := 'MiscReceipts';
        C_OBJ    CONSTANT VARCHAR2(30) := 'MiscReceipts';
        v_scenario_id  NUMBER;
        l_ucm_account  VARCHAR2(200);
        l_job_name     VARCHAR2(500);
        l_ifd          NUMBER;
        l_mr_user      VARCHAR2(100);
        l_mr_pass      VARCHAR2(100);
        l_zip          BLOB;
        l_filename     VARCHAR2(200);
        l_csv_id       NUMBER;
        l_load_ess_id  VARCHAR2(100);
        l_import_ess_id VARCHAR2(100);
        l_load_status  VARCHAR2(50);
        l_param_list   VARCHAR2(500) := '#NULL';  -- MCCS RICE_011/012: PollTMEssJob, no params
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_MISC_RECEIPTS start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);

        sup_preamble(p_run_id, C_CEMLI, C_OBJ, p_skip_bu_refresh);

        -- Phase 1: pre-transform validation.
        DMT_MISC_RECEIPT_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
        COMMIT;

        -- Phase 2: transform STG -> TFM.
        DMT_MISC_RECEIPT_TRANSFORM_PKG.TRANSFORM(p_run_id, p_reprocess_errors => (p_run_mode = 'FAILED'), p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;

        -- Phase 3: generate the FBDI zip.
        DMT_MISC_RECEIPT_FBDI_GEN_PKG.GENERATE_FBDI(p_run_id, l_zip, l_filename, l_csv_id);

        -- If no rows, skip this object type.
        IF l_zip IS NULL OR DBMS_LOB.GETLENGTH(l_zip) = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'No rows for ' || C_CEMLI || '. Skipping.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
            RETURN;
        END IF;

        -- ERP options + credentials for the load submission.
        get_erp_options(
            p_cemli_code           => C_CEMLI,
            x_ucm_account          => l_ucm_account,
            x_import_job_name      => l_job_name,
            x_interface_details_id => l_ifd);
        DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS(C_CEMLI, l_mr_user, l_mr_pass);

        -- loadAndImportData — combined load+import single call.
        l_load_ess_id := SUBMIT_LOAD(
            p_run_id            => p_run_id,
            p_fbdi_zip          => l_zip,
            p_filename          => l_filename,
            p_job_name          => l_job_name,
            p_interface_details => l_ifd,
            p_doc_account       => l_ucm_account,
            p_parameter_list    => l_param_list,
            p_log_context       => C_OBJ,
            p_username          => l_mr_user,
            p_password          => l_mr_pass);
        DBMS_LOB.FREETEMPORARY(l_zip);

        -- Stamp the parameter list on the ZIP row.
        UPDATE DMT_FBDI_ZIP_TBL
        SET    PARAMETER_LIST = l_param_list
        WHERE  RUN_ID = p_run_id
        AND    OBJECT_TYPE = SUBSTR(C_CEMLI, INSTR(C_CEMLI, '-') + 1);
        COMMIT;

        -- Async mode: stop here, let the queue poller handle ESS polling +
        -- reconciliation. (MiscReceipts is registered SYNC so this is not taken on
        -- the live path; kept for correctness if ever re-registered ASYNC.)
        IF g_async_mode THEN
            g_load_ess_id := l_load_ess_id;
            RETURN;
        END IF;

        -- ---- SYNC path (the live path for MiscReceipts) ----

        -- Poll Load job.
        DMT_UTIL_PKG.LOG(p_run_id,
            'Polling Load ESS job: ' || l_load_ess_id, 'INFO', C_PKG, C_OBJ || ' > ' || C_PROC);
        POLL_ESS_JOB(p_run_id, l_load_ess_id, 1800, FALSE, C_OBJ, C_CEMLI, l_load_status,
                     p_username => l_mr_user, p_password => l_mr_pass);

        -- Load failed → no rows reached the interface table. Mark all GENERATED rows
        -- FAILED and return (no import job, no BIP).
        IF l_load_status NOT IN (C_STATUS_SUCCEEDED, C_STATUS_WARNING) THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'Load ESS ' || l_load_ess_id || ' returned ' || l_load_status ||
                '. No rows committed to interface table. Marking all GENERATED rows FAILED.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
            DECLARE
                l_err_msg VARCHAR2(500) := '[LOAD_ERROR] Loading data to the Fusion interface failed. Check ESS job ' || l_load_ess_id || ' logs for details.';
            BEGIN
                UPDATE DMT_INV_TRX_TFM_TBL SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err_msg) WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED';
                COMMIT;
            END;
            RETURN;
        END IF;

        -- Import step: INV Transaction Manager doesn't chain from loadAndImportData,
        -- so submit PollTMEssJob explicitly. It picks up all process_flag=1 rows and
        -- spawns SingleTMEssJob internally to process them.
        DECLARE
            l_resp     CLOB;
            l_tag_s    INTEGER;
            l_val_s    INTEGER;
            l_val_e    INTEGER;
        BEGIN
            DMT_UTIL_PKG.LOG(p_run_id,
                'Submitting PollTMEssJob explicitly (INV transactions).', 'INFO', C_PKG, C_OBJ || ' > ' || C_PROC);
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
                p_run_id         => p_run_id,
                p_username       => l_mr_user,
                p_password       => l_mr_pass);
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
                'PollTMEssJob submitted. ESS ID: ' || l_import_ess_id, 'INFO', C_PKG, C_OBJ || ' > ' || C_PROC);
        END;
        COMMIT;

        -- Backlog #70 (non-partitioned): stamp this item's own load + import (the
        -- PollTMEssJob request) ess ids on its own queue row so the run-detail tiles
        -- show real ids. No-op for a direct/standalone call (g_gen_queue_id NULL).
        stamp_item_ess_ids(l_load_ess_id, l_import_ess_id);

        -- Poll Import job — do NOT raise on error.
        DMT_UTIL_PKG.LOG(p_run_id,
            'Polling Import ESS job: ' || l_import_ess_id, 'INFO', C_PKG, C_OBJ || ' > ' || C_PROC);
        POLL_ESS_JOB(p_run_id, l_import_ess_id, 1800, FALSE, C_OBJ, C_CEMLI, l_load_status,
                     p_username => l_mr_user, p_password => l_mr_pass);

        -- Capture the Report child ESS job into the hierarchy (generic).
        DECLARE l_report_ess_id NUMBER;
        BEGIN
            l_report_ess_id := DMT_ESS_UTIL_PKG.CAPTURE_REPORT_ESS_JOB(
                p_run_id        => p_run_id,
                p_import_ess_id => TO_NUMBER(l_import_ess_id),
                p_cemli_code    => C_CEMLI);
        END;

        -- BIP reconciliation — single registry-driven dispatch.
        DMT_QUEUE_WORKER_PKG.RECONCILE_VIA_REGISTRY(
            p_run_id        => p_run_id,
            p_cemli_code    => C_CEMLI,
            p_load_ess_id   => TO_NUMBER(l_load_ess_id),
            p_import_ess_id => TO_NUMBER(l_import_ess_id),
            p_work_queue_id => g_work_queue_id);
        g_reconciled_inline := TRUE;

        -- Rows still GENERATED after reconciliation → warn + capture ESS output.
        DECLARE
            l_still_generated NUMBER := 0;
        BEGIN
            SELECT COUNT(*) INTO l_still_generated FROM DMT_INV_TRX_TFM_TBL
            WHERE RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
            IF l_still_generated > 0 THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    'WARNING: ' || l_still_generated || ' rows still at GENERATED after BIP reconciliation for ' ||
                    C_CEMLI || '. BIP query returned no matching rows for these records. ' ||
                    'Rows left at GENERATED for manual investigation — do NOT assume success.',
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
                IF l_import_ess_id IS NOT NULL THEN
                    DMT_ESS_UTIL_PKG.CAPTURE_ESS_OUTPUT(
                        p_run_id     => p_run_id,
                        p_request_id => TO_NUMBER(l_import_ess_id),
                        p_cemli_code => C_CEMLI);
                END IF;
            END IF;
        END;

        -- FAILED-row accounting + completion log.
        DECLARE
            l_failed_count NUMBER;
        BEGIN
            SELECT COUNT(*) INTO l_failed_count
            FROM DMT_INV_TRX_TFM_TBL
            WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';
            IF l_failed_count > 0 THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    C_CEMLI || ': ' || l_failed_count || ' record(s) FAILED in Fusion. ' ||
                    'Downstream object types will continue — check staging table for details.',
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
            END IF;
        END;

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
    -- RUN_PROJECTS (public) — self-contained recipe (backlog #8, final family).
    -- SINGLE-LOAD FBDI object (headers + tasks + team members + txn controls in one
    -- zip). ParameterList ',,Y' (ImportProjectJobDef 3-arg). Behaviour is byte-for-byte
    -- the pre-refactor Projects single-load path of run_one_object_type. The known
    -- async-import race is tracked separately (backlog #71) and is NOT touched here —
    -- this preserves the current behaviour exactly.
    PROCEDURE RUN_PROJECTS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC   CONSTANT VARCHAR2(40) := 'RUN_PROJECTS';
        C_CEMLI  CONSTANT VARCHAR2(30) := 'Projects';
        C_OBJ    CONSTANT VARCHAR2(30) := 'Projects';
        v_scenario_id NUMBER;
        l_zip         BLOB;
        l_filename    VARCHAR2(200);
        l_csv_id      NUMBER;
        l_ok          BOOLEAN;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_PROJECTS start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);

        sup_preamble(p_run_id, C_CEMLI, C_OBJ, p_skip_bu_refresh);

        -- Phase 1: pre-transform validation.
        DMT_PROJECT_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id, p_scenario_id => v_scenario_id);
        COMMIT;

        -- Phase 2: transform STG -> TFM (projects, tasks, team members, txn controls).
        DMT_PROJECT_TRANSFORM_PKG.TRANSFORM_PROJECTS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_PROJECT_TRANSFORM_PKG.TRANSFORM_TASKS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_PROJECT_TRANSFORM_PKG.TRANSFORM_TEAM_MEMBERS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_PROJECT_TRANSFORM_PKG.TRANSFORM_TXN_CONTROLS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;

        -- Phase 3: generate the FBDI zip.
        DMT_PROJECT_FBDI_GEN_PKG.GENERATE_FBDI(p_run_id, l_zip, l_filename, l_csv_id);

        -- Phase 4: submit + (async return | poll + import + reconcile). ',,Y' param list
        -- (MCCS RICE_006 ImportProjectJobDef 3-arg).
        l_ok := fin_after_generate(p_run_id, C_CEMLI, C_OBJ, l_zip, l_filename, ',,Y');

        -- Phase 5: FAILED-row accounting + completion log.
        fin_finish(p_run_id, C_CEMLI, C_OBJ);

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
        C_PROC   CONSTANT VARCHAR2(40) := 'RUN_BLANKET_POS';
        C_CEMLI  CONSTANT VARCHAR2(30) := 'BlanketPOs';
        C_OBJ    CONSTANT VARCHAR2(30) := 'BlanketPOs';
        C_STYLE  CONSTANT VARCHAR2(60) := 'Blanket Purchase Agreement';
        v_scenario_id  NUMBER;
        l_ucm_account  VARCHAR2(200);
        l_job_name     VARCHAR2(500);
        l_ifd          NUMBER;
        l_po_user      VARCHAR2(100);
        l_po_pass      VARCHAR2(100);
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
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_BLANKET_POS start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);

        sup_preamble(p_run_id, C_CEMLI, C_OBJ, p_skip_bu_refresh);

        -- Phase 1: pre-transform validation (Blanket Purchase Agreement doc type).
        DMT_PO_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id, p_doc_type_filter => C_STYLE);
        COMMIT;

        -- Phase 2: transform STG -> TFM (headers + lines).
        DMT_PO_TRANSFORM_PKG.TRANSFORM_HEADERS(p_run_id, p_doc_type_filter => C_STYLE, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_PO_TRANSFORM_PKG.TRANSFORM_LINES(p_run_id, p_doc_type_filter => C_STYLE, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;

        get_erp_options(
            p_cemli_code           => C_CEMLI,
            x_ucm_account          => l_ucm_account,
            x_import_job_name      => l_job_name,
            x_interface_details_id => l_ifd);
        DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS(C_CEMLI, l_po_user, l_po_pass);

        -- Phase 3+4: multi-BU load cycle (same grouping as standard POs).
        FOR bu_rec IN (
            SELECT DISTINCT PRC_BU_NAME
            FROM   DMT_PO_HEADERS_INT_TFM_TBL
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED'
            AND    STYLE_DISPLAY_NAME = C_STYLE
            ORDER BY PRC_BU_NAME
        ) LOOP
            l_bu_count := l_bu_count + 1;
            DMT_UTIL_PKG.LOG(p_run_id,
                'BlanketPO BU cycle start: ' || bu_rec.PRC_BU_NAME,
                'INFO', C_PKG, C_OBJ || ' > ' || C_PROC);

            DMT_BLANKET_PO_FBDI_GEN_PKG.GENERATE_FBDI(
                p_run_id => p_run_id, p_prc_bu_name => bu_rec.PRC_BU_NAME,
                x_fbdi_zip => l_bu_zip, x_filename => l_bu_filename, x_fbdi_csv_id => l_bu_csv_id);

            IF l_bu_zip IS NULL OR DBMS_LOB.GETLENGTH(l_bu_zip) = 0 THEN
                DMT_UTIL_PKG.LOG(p_run_id, 'No blanket rows for BU ' || bu_rec.PRC_BU_NAME || '. Skipping.',
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
                CONTINUE;
            END IF;

            l_bu_id := DMT_UTIL_PKG.GET_LOOKUP('BU_NAME_TO_BU_ID', bu_rec.PRC_BU_NAME);
            l_buyer_id := DMT_UTIL_PKG.GET_CONFIG('PO_DEFAULT_BUYER_ID');

            -- ImportBPAJob: 8 args.
            l_bu_param := l_bu_id || ',' || l_buyer_id || ',N,SUBMIT,,,N,' || l_bu_id || '_' || TO_CHAR(p_run_id);

            po_submit_and_reconcile_one(
                p_run_id => p_run_id, p_cemli_code => C_CEMLI, p_obj => C_OBJ,
                p_job_name => l_job_name, p_interface_details => l_ifd, p_ucm_account => l_ucm_account,
                p_fbdi_zip => l_bu_zip, p_filename => l_bu_filename, p_fbdi_csv_id => l_bu_csv_id,
                p_param_list => l_bu_param, p_group_label => 'BU: ' || bu_rec.PRC_BU_NAME,
                p_username => l_po_user, p_password => l_po_pass,
                x_load_ess_id => l_bu_load_id, x_import_ess_id => l_bu_import_id, x_success => l_bu_ok);

            IF NOT l_bu_ok THEN
                po_mark_bu_failed(p_run_id, C_CEMLI, bu_rec.PRC_BU_NAME, l_bu_load_id);
                CONTINUE;
            END IF;
        END LOOP;

        IF l_bu_count = 0 THEN
            SELECT COUNT(*) INTO l_any_staged FROM DMT_PO_HEADERS_INT_TFM_TBL
            WHERE RUN_ID=p_run_id AND TFM_STATUS='STAGED'
            AND STYLE_DISPLAY_NAME=C_STYLE AND ROWNUM=1;
            IF l_any_staged = 0 THEN
                DMT_UTIL_PKG.LOG(p_run_id, 'No STAGED blanket PO headers. Skipping.',
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
                RETURN;
            END IF;
        END IF;

        po_finish(p_run_id, C_CEMLI, C_OBJ);

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
        C_PROC   CONSTANT VARCHAR2(40) := 'RUN_CONTRACTS';
        C_CEMLI  CONSTANT VARCHAR2(30) := 'Contracts';
        C_OBJ    CONSTANT VARCHAR2(30) := 'Contracts';
        C_STYLE  CONSTANT VARCHAR2(60) := 'Contract Purchase Agreement';
        v_scenario_id  NUMBER;
        l_ucm_account  VARCHAR2(200);
        l_job_name     VARCHAR2(500);
        l_ifd          NUMBER;
        l_po_user      VARCHAR2(100);
        l_po_pass      VARCHAR2(100);
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
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_CONTRACTS start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);

        sup_preamble(p_run_id, C_CEMLI, C_OBJ, p_skip_bu_refresh);

        -- Phase 1: pre-transform validation (Contract Purchase Agreement doc type).
        DMT_PO_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id, p_doc_type_filter => C_STYLE);
        COMMIT;

        -- Phase 2: transform STG -> TFM (headers only).
        DMT_PO_TRANSFORM_PKG.TRANSFORM_HEADERS(p_run_id, p_doc_type_filter => C_STYLE, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;

        get_erp_options(
            p_cemli_code           => C_CEMLI,
            x_ucm_account          => l_ucm_account,
            x_import_job_name      => l_job_name,
            x_interface_details_id => l_ifd);
        DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS(C_CEMLI, l_po_user, l_po_pass);

        -- Phase 3+4: multi-BU load cycle (headers only).
        FOR bu_rec IN (
            SELECT DISTINCT PRC_BU_NAME
            FROM   DMT_PO_HEADERS_INT_TFM_TBL
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED'
            AND    STYLE_DISPLAY_NAME = C_STYLE
            ORDER BY PRC_BU_NAME
        ) LOOP
            l_bu_count := l_bu_count + 1;
            DMT_UTIL_PKG.LOG(p_run_id,
                'Contract BU cycle start: ' || bu_rec.PRC_BU_NAME,
                'INFO', C_PKG, C_OBJ || ' > ' || C_PROC);

            DMT_CONTRACT_FBDI_GEN_PKG.GENERATE_FBDI(
                p_run_id => p_run_id, p_prc_bu_name => bu_rec.PRC_BU_NAME,
                x_fbdi_zip => l_bu_zip, x_filename => l_bu_filename, x_fbdi_csv_id => l_bu_csv_id);

            IF l_bu_zip IS NULL OR DBMS_LOB.GETLENGTH(l_bu_zip) = 0 THEN
                DMT_UTIL_PKG.LOG(p_run_id, 'No contract rows for BU ' || bu_rec.PRC_BU_NAME || '. Skipping.',
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
                CONTINUE;
            END IF;

            l_bu_id := DMT_UTIL_PKG.GET_LOOKUP('BU_NAME_TO_BU_ID', bu_rec.PRC_BU_NAME);
            l_buyer_id := DMT_UTIL_PKG.GET_CONFIG('PO_DEFAULT_BUYER_ID');

            -- ImportCPAJob: 7 args.
            l_bu_param := l_bu_id || ',' || l_buyer_id || ',SUBMIT,,,N,' || l_bu_id || '_' || TO_CHAR(p_run_id);

            po_submit_and_reconcile_one(
                p_run_id => p_run_id, p_cemli_code => C_CEMLI, p_obj => C_OBJ,
                p_job_name => l_job_name, p_interface_details => l_ifd, p_ucm_account => l_ucm_account,
                p_fbdi_zip => l_bu_zip, p_filename => l_bu_filename, p_fbdi_csv_id => l_bu_csv_id,
                p_param_list => l_bu_param, p_group_label => 'BU: ' || bu_rec.PRC_BU_NAME,
                p_username => l_po_user, p_password => l_po_pass,
                x_load_ess_id => l_bu_load_id, x_import_ess_id => l_bu_import_id, x_success => l_bu_ok);

            IF NOT l_bu_ok THEN
                po_mark_bu_failed(p_run_id, C_CEMLI, bu_rec.PRC_BU_NAME, l_bu_load_id);
                CONTINUE;
            END IF;
        END LOOP;

        IF l_bu_count = 0 THEN
            SELECT COUNT(*) INTO l_any_staged FROM DMT_PO_HEADERS_INT_TFM_TBL
            WHERE RUN_ID=p_run_id AND TFM_STATUS='STAGED'
            AND STYLE_DISPLAY_NAME=C_STYLE AND ROWNUM=1;
            IF l_any_staged = 0 THEN
                DMT_UTIL_PKG.LOG(p_run_id, 'No STAGED contract headers. Skipping.',
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
                RETURN;
            END IF;
        END IF;

        po_finish(p_run_id, C_CEMLI, C_OBJ);

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
    -- RUN_AP_INVOICES (public) — self-contained recipe (backlog #8, final family).
    -- GROUPED by OPERATING_UNIT: one FBDI zip + one loadAndImportData (APXIIMPT
    -- 14-arg) + one BIP reconcile per OU, all inline in a single work-queue item
    -- (NOT spawn-per-partition -- APInvoices is in DMT_CEMLI_SPLIT_CFG with
    -- CHILD_PARTITION_COLUMN NULL). AP's Import Payables Invoices chains its own import
    -- from loadAndImportData (unlike AR AutoInvoice's two-job flow), so it reuses the
    -- STANDARD po_submit_and_reconcile_one, not ar_submit_and_reconcile_one. 1099
    -- invoices are a filtered subset of AP, not a separate object. Behaviour is
    -- byte-for-byte the pre-refactor APInvoices grouped block of run_one_object_type.
    PROCEDURE RUN_AP_INVOICES (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC   CONSTANT VARCHAR2(40) := 'RUN_AP_INVOICES';
        C_CEMLI  CONSTANT VARCHAR2(30) := 'APInvoices';
        C_OBJ    CONSTANT VARCHAR2(30) := 'APInvoices';
        v_scenario_id  NUMBER;
        l_ucm_account  VARCHAR2(200);
        l_job_name     VARCHAR2(500);
        l_ifd          NUMBER;
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
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_AP_INVOICES start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);

        sup_preamble(p_run_id, C_CEMLI, C_OBJ, p_skip_bu_refresh);

        -- Phase 1: pre-transform validation.
        DMT_AP_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
        COMMIT;

        -- Phase 2: transform STG -> TFM (headers + lines).
        DMT_AP_TRANSFORM_PKG.TRANSFORM_HEADERS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_AP_TRANSFORM_PKG.TRANSFORM_LINES(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;

        -- ERP options for the load submissions (AP uses default Fusion credentials --
        -- the monolith passed none to submit_and_reconcile_one).
        get_erp_options(
            p_cemli_code           => C_CEMLI,
            x_ucm_account          => l_ucm_account,
            x_import_job_name      => l_job_name,
            x_interface_details_id => l_ifd);

        -- Phase 3+4: per-OU load cycle. Each distinct OPERATING_UNIT gets its own FBDI
        -- zip, loadAndImportData, and BIP reconciliation (inline per OU).
        FOR ou_rec IN (
            SELECT DISTINCT OPERATING_UNIT
            FROM   DMT_AP_INVOICES_INT_TFM_TBL
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED'
            ORDER BY OPERATING_UNIT
        ) LOOP
            l_ou_count := l_ou_count + 1;
            DMT_UTIL_PKG.LOG(p_run_id,
                'AP OU cycle start: ' || ou_rec.OPERATING_UNIT,
                'INFO', C_PKG, C_OBJ || ' > ' || C_PROC);

            DMT_AP_FBDI_GEN_PKG.GENERATE_FBDI(
                p_run_id => p_run_id, p_operating_unit => ou_rec.OPERATING_UNIT,
                x_fbdi_zip => l_ou_zip, x_filename => l_ou_filename, x_fbdi_csv_id => l_ou_csv_id);

            IF l_ou_zip IS NULL OR DBMS_LOB.GETLENGTH(l_ou_zip) = 0 THEN
                DMT_UTIL_PKG.LOG(p_run_id, 'No rows for OU ' || ou_rec.OPERATING_UNIT || '. Skipping.',
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
                CONTINUE;
            END IF;

            -- AP APXIIMPT 14-arg ParameterList.
            DECLARE
                l_ap_bu_id  VARCHAR2(50);
                l_ap_ledger VARCHAR2(50);
                l_ap_source VARCHAR2(100);
            BEGIN
                -- BU id + its primary ledger via the common lookup. Every active BU has
                -- a BU_NAME_TO_PRIMARY_LEDGER_ID row; it resolves to NULL when the BU
                -- has no primary ledger, so the NVL(...,'#NULL') below still applies
                -- (GET_LOOKUP raises only when the BU itself is unknown).
                l_ap_bu_id  := DMT_UTIL_PKG.GET_LOOKUP('BU_NAME_TO_BU_ID', ou_rec.OPERATING_UNIT);
                l_ap_ledger := DMT_UTIL_PKG.GET_LOOKUP('BU_NAME_TO_PRIMARY_LEDGER_ID', ou_rec.OPERATING_UNIT);
                SELECT SOURCE INTO l_ap_source FROM DMT_AP_INVOICES_INT_TFM_TBL
                WHERE RUN_ID=p_run_id AND OPERATING_UNIT=ou_rec.OPERATING_UNIT AND TFM_STATUS='GENERATED' AND ROWNUM=1;
                l_ou_param := ',' || l_ap_bu_id || ',N,' || TO_CHAR(SYSDATE,'YYYY-MM-DD') ||
                    ',#NULL,#NULL,1000,' || l_ap_source || ',' || TO_CHAR(p_run_id) ||
                    ',N,Y,' || NVL(l_ap_ledger,'#NULL') || ',#NULL,1';
            END;

            po_submit_and_reconcile_one(
                p_run_id            => p_run_id,
                p_cemli_code        => C_CEMLI,
                p_obj               => C_OBJ,
                p_job_name          => l_job_name,
                p_interface_details => l_ifd,
                p_ucm_account       => l_ucm_account,
                p_fbdi_zip          => l_ou_zip,
                p_filename          => l_ou_filename,
                p_fbdi_csv_id       => l_ou_csv_id,
                p_param_list        => l_ou_param,
                p_group_label       => 'OU: ' || ou_rec.OPERATING_UNIT,
                p_username          => NULL,
                p_password          => NULL,
                x_load_ess_id       => l_ou_load_id,
                x_import_ess_id     => l_ou_import_id,
                x_success           => l_ou_ok);

            IF NOT l_ou_ok THEN
                DECLARE
                    l_err VARCHAR2(500) := '[LOAD_ERROR] Loading data to the Fusion interface failed. Check ESS job ' || l_ou_load_id || ' logs for details.';
                BEGIN
                    UPDATE DMT_AP_INVOICES_INT_TFM_TBL
                    SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err)
                    WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED' AND OPERATING_UNIT=ou_rec.OPERATING_UNIT;
                    UPDATE DMT_AP_INVOICE_LINES_INT_TFM_TBL
                    SET TFM_STATUS='FAILED', ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,l_err)
                    WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED'
                    AND INVOICE_ID IN (SELECT INVOICE_ID FROM DMT_AP_INVOICES_INT_TFM_TBL WHERE RUN_ID=p_run_id AND OPERATING_UNIT=ou_rec.OPERATING_UNIT);
                    COMMIT;
                END;
                CONTINUE;
            END IF;

            -- Check for rows still at GENERATED after BIP.
            DECLARE l_gen_count NUMBER;
            BEGIN
                SELECT COUNT(*) INTO l_gen_count FROM DMT_AP_INVOICES_INT_TFM_TBL
                WHERE RUN_ID=p_run_id AND TFM_STATUS='GENERATED' AND OPERATING_UNIT=ou_rec.OPERATING_UNIT;
                IF l_gen_count > 0 THEN
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'WARNING: ' || l_gen_count || ' AP invoice rows still at GENERATED after BIP reconciliation (OU: ' || ou_rec.OPERATING_UNIT || '). Require manual investigation.',
                        DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
                END IF;
            END;
        END LOOP;

        IF l_ou_count = 0 THEN
            SELECT COUNT(*) INTO l_any_staged FROM DMT_AP_INVOICES_INT_TFM_TBL
            WHERE RUN_ID=p_run_id AND TFM_STATUS='STAGED' AND ROWNUM=1;
            IF l_any_staged = 0 THEN
                DMT_UTIL_PKG.LOG(p_run_id, 'No STAGED AP invoice headers found. Skipping APInvoices.',
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
                RETURN;
            END IF;
        END IF;

        -- Phase 5: FAILED-row accounting + completion log (counts the AP header TFM
        -- table, as the monolith grouped_finish did for APInvoices).
        DECLARE
            l_failed_count NUMBER;
        BEGIN
            SELECT COUNT(*) INTO l_failed_count
            FROM DMT_AP_INVOICES_INT_TFM_TBL
            WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';
            IF l_failed_count > 0 THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    C_CEMLI || ': ' || l_failed_count || ' record(s) FAILED in Fusion. ' ||
                    'Downstream object types will continue — check staging table for details.',
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
            END IF;
        END;

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

        SELECT DMT_PIPELINE_RUN_SEQ.NEXTVAL INTO l_run_id FROM DUAL;
        SELECT TO_CHAR(DMT_RUN_PREFIX_SEQ.NEXTVAL) INTO l_prefix FROM DUAL;

        INSERT INTO DMT_PIPELINE_RUN_TBL (
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
    -- RECONCILE_HDL_OBJECT (public) — re-run ONE HDL object's base-table
    -- reconciliation for a retry tick (HDL base-table lag). Uniform CASE over
    -- the 14 HDL base-proof objects; each object's RECONCILE_BATCH shares the
    -- (p_run_id, p_request_id, p_dataset_status) signature and is idempotent for
    -- the base tier (re-queries the Fusion base table, promotes only newly-
    -- confirmed rows to LOADED, never re-uploads). Static calls only — no dynamic
    -- SQL. Unknown CEMLI raises -20103 (only HDL base-proof objects are routed here
    -- by RECONCILE_ONE).
    -- --------------------------------------------------------
    PROCEDURE RECONCILE_HDL_OBJECT (
        p_cemli_code     IN VARCHAR2,
        p_run_id         IN NUMBER,
        p_request_id     IN VARCHAR2,
        p_dataset_status IN VARCHAR2 DEFAULT NULL
    ) IS
    BEGIN
        CASE p_cemli_code
            WHEN 'Workers' THEN
                -- Single Worker.dat carries the assignment components, so the
                -- Workers base-lag retry re-checks BOTH the person tiers and the
                -- assignment / work-rel tiers against the same HDL data set. There
                -- is no standalone 'Assignments' CEMLI anymore (2026-09-17 model
                -- correction), so its former retry arm is folded here.
                DMT_WORKER_RESULTS_PKG.RECONCILE_BATCH(p_run_id, p_request_id, p_dataset_status);
                DMT_ASSIGNMENT_RESULTS_PKG.RECONCILE_BATCH(p_run_id, p_request_id, p_dataset_status);
            WHEN 'Salaries' THEN
                DMT_SALARY_RESULTS_PKG.RECONCILE_BATCH(p_run_id, p_request_id, p_dataset_status);
            WHEN 'SalaryBases' THEN
                DMT_SAL_BASIS_RESULTS_PKG.RECONCILE_BATCH(p_run_id, p_request_id, p_dataset_status);
            WHEN 'Absences' THEN
                DMT_ABSENCE_RESULTS_PKG.RECONCILE_BATCH(p_run_id, p_request_id, p_dataset_status);
            WHEN 'W2Balances' THEN
                DMT_W2_BAL_RESULTS_PKG.RECONCILE_BATCH(p_run_id, p_request_id, p_dataset_status);
            WHEN 'BenParticipant' THEN
                DMT_BEN_PARTIC_RESULTS_PKG.RECONCILE_BATCH(p_run_id, p_request_id, p_dataset_status);
            WHEN 'BenDependent' THEN
                DMT_BEN_DEPEND_RESULTS_PKG.RECONCILE_BATCH(p_run_id, p_request_id, p_dataset_status);
            WHEN 'BenBeneficiary' THEN
                DMT_BEN_BENFY_RESULTS_PKG.RECONCILE_BATCH(p_run_id, p_request_id, p_dataset_status);
            WHEN 'TaxCards' THEN
                DMT_TAX_CARD_RESULTS_PKG.RECONCILE_BATCH(p_run_id, p_request_id, p_dataset_status);
            WHEN 'TalentProfiles' THEN
                DMT_TALENT_PROF_RESULTS_PKG.RECONCILE_BATCH(p_run_id, p_request_id, p_dataset_status);
            WHEN 'PerfEvaluations' THEN
                DMT_PERF_EVAL_RESULTS_PKG.RECONCILE_BATCH(p_run_id, p_request_id, p_dataset_status);
            WHEN 'WorkSchedules' THEN
                DMT_WORK_SCHED_RESULTS_PKG.RECONCILE_BATCH(p_run_id, p_request_id, p_dataset_status);
            -- 'PayrollRelationships' retired 2026-09-17: the payroll relationship
            -- is auto-created at hire by the Worker load, not a standalone HDL load,
            -- so there is no CEMLI to reconcile here. Its recon report survives as a
            -- read-only verifier only.
            ELSE
                RAISE_APPLICATION_ERROR(-20103,
                    'RECONCILE_HDL_OBJECT: no HDL reconciler mapped for CEMLI ' || p_cemli_code);
        END CASE;
    END RECONCILE_HDL_OBJECT;

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

        -- Step 2: Transform all 7 person business objects (STG → TFM)
        DMT_WORKER_TRANSFORM_PKG.TRANSFORM_WORKERS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_WORKER_TRANSFORM_PKG.TRANSFORM_PERSON_NAMES(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_WORKER_TRANSFORM_PKG.TRANSFORM_PERSON_EMAILS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_WORKER_TRANSFORM_PKG.TRANSFORM_PERSON_PHONES(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_WORKER_TRANSFORM_PKG.TRANSFORM_PERSON_ADDRESSES(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_WORKER_TRANSFORM_PKG.TRANSFORM_PERSON_NIDS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_WORKER_TRANSFORM_PKG.TRANSFORM_PERSON_LEGISL(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);

        -- Step 2b: Assignment + WorkRelationship components (2026-09-17 HCM object-
        -- model correction). WorkTerms and Assignment are COMPONENTS of the Worker
        -- business object, delivered in the ONE Worker.dat. There is no separate
        -- Assignments pipeline object anymore, so the Worker run itself validates and
        -- transforms the assignment / work-relationship staged rows here, BEFORE the
        -- generate step below reads DMT_ASSIGNMENT_TFM_TBL / DMT_WORK_REL_TFM_TBL.
        -- The [PRE_VALIDATION] exclusion and the prefixing in the assignment transform
        -- are preserved (those packages are unchanged; only their call site moved).
        DMT_ASSIGNMENT_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
        DMT_ASSIGNMENT_TRANSFORM_PKG.TRANSFORM_WORK_RELS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        DMT_ASSIGNMENT_TRANSFORM_PKG.TRANSFORM_ASSIGNMENTS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;

        -- Step 3: Post-validation (stub) — persons and assignment components
        DMT_WORKER_VALIDATOR_PKG.VALIDATE_POST_TRANSFORM(p_run_id);
        DMT_ASSIGNMENT_VALIDATOR_PKG.VALIDATE_POST_TRANSFORM(p_run_id);

        -- Step 4: Generate the single Worker.dat HDL file → ZIP. It emits
        -- Worker/PersonName/WorkRelationship/WorkTerms/Assignment (+ optional person
        -- child sections) — the complete Worker object in ONE data set.
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

        -- HDL base-lag retry: publish this cycle's HDL request id + data set status
        -- so EXECUTE_ONE can persist them and the queue can re-run the base proof on
        -- a later tick if the base rows lag.
        DMT_LOADER_PKG.g_hdl_request_id     := l_request_id;
        DMT_LOADER_PKG.g_hdl_dataset_status := l_dataset_status;

        -- Step 8: Reconcile — parse HDL errors, update TFM/STG. Both the person
        -- tiers (Worker + Person*) and the assignment component tiers
        -- (WorkRelationship + Assignment) are reconciled against the SAME single
        -- Worker.dat HDL data set (one request id), because they were loaded
        -- together. Worker reconcile covers the person tiers; the assignment
        -- reconcile covers DMT_WORK_REL_TFM_TBL / DMT_ASSIGNMENT_TFM_TBL. Every
        -- assignment / work-rel TFM row therefore still gets a LOADED/FAILED
        -- verdict (object-status-accounting rule) with no separate load.
        DMT_WORKER_RESULTS_PKG.RECONCILE_BATCH(
            p_run_id => p_run_id,
            p_request_id     => l_request_id,
            p_dataset_status => l_dataset_status);

        DMT_ASSIGNMENT_RESULTS_PKG.RECONCILE_BATCH(
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
    -- RUN_ASSIGNMENTS — RETIRED 2026-09-17 (HCM object-model correction).
    -- Assignments is no longer a standalone pipeline object. WorkTerms and
    -- Assignment are components of the Worker business object, delivered in the
    -- ONE Worker.dat. RUN_WORKERS now runs the assignment/work-rel validate +
    -- transform (feeding DMT_ASSIGNMENT_TFM_TBL / DMT_WORK_REL_TFM_TBL) before it
    -- generates the single Worker.dat, and reconciles those tiers against the same
    -- HDL data set. The assignment validate/transform/results packages are kept
    -- (they feed and reconcile the Worker load); only this standalone submission
    -- procedure and the standalone Assignment HDL generator were removed.
    -- --------------------------------------------------------

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
        -- HDL base-lag retry: publish this cycle's HDL request id + data set
        -- status so EXECUTE_ONE can persist them and the queue can re-run the
        -- base proof on a later tick if the base rows lag.
        DMT_LOADER_PKG.g_hdl_request_id     := l_request_id;
        DMT_LOADER_PKG.g_hdl_dataset_status := l_dataset_status;
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
        -- HDL base-lag retry: publish this cycle's HDL request id + data set
        -- status so EXECUTE_ONE can persist them and the queue can re-run the
        -- base proof on a later tick if the base rows lag.
        DMT_LOADER_PKG.g_hdl_request_id     := l_request_id;
        DMT_LOADER_PKG.g_hdl_dataset_status := l_dataset_status;
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
        -- HDL base-lag retry: publish this cycle's HDL request id + data set
        -- status so EXECUTE_ONE can persist them and the queue can re-run the
        -- base proof on a later tick if the base rows lag.
        DMT_LOADER_PKG.g_hdl_request_id     := l_request_id;
        DMT_LOADER_PKG.g_hdl_dataset_status := l_dataset_status;
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
        -- HDL base-lag retry: publish this cycle's HDL request id + data set
        -- status so EXECUTE_ONE can persist them and the queue can re-run the
        -- base proof on a later tick if the base rows lag.
        DMT_LOADER_PKG.g_hdl_request_id     := l_request_id;
        DMT_LOADER_PKG.g_hdl_dataset_status := l_dataset_status;
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
        -- HDL base-lag retry: publish this cycle's HDL request id + data set
        -- status so EXECUTE_ONE can persist them and the queue can re-run the
        -- base proof on a later tick if the base rows lag.
        DMT_LOADER_PKG.g_hdl_request_id     := l_request_id;
        DMT_LOADER_PKG.g_hdl_dataset_status := l_dataset_status;
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
        -- HDL base-lag retry: publish this cycle's HDL request id + data set
        -- status so EXECUTE_ONE can persist them and the queue can re-run the
        -- base proof on a later tick if the base rows lag.
        DMT_LOADER_PKG.g_hdl_request_id     := l_request_id;
        DMT_LOADER_PKG.g_hdl_dataset_status := l_dataset_status;
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
        -- HDL base-lag retry: publish this cycle's HDL request id + data set
        -- status so EXECUTE_ONE can persist them and the queue can re-run the
        -- base proof on a later tick if the base rows lag.
        DMT_LOADER_PKG.g_hdl_request_id     := l_request_id;
        DMT_LOADER_PKG.g_hdl_dataset_status := l_dataset_status;
        DMT_BEN_BENFY_RESULTS_PKG.RECONCILE_BATCH(p_run_id, l_request_id, l_dataset_status);

        DMT_UTIL_PKG.LOG(p_run_id, 'RUN_BEN_BENEFICIARY complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'RUN_BEN_BENEFICIARY failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_BEN_BENEFICIARY;

    -- --------------------------------------------------------
    -- RUN_PAYROLL_RELS — RETIRED 2026-09-17. A payroll relationship is NOT a
    -- loadable standalone HDL business object: Fusion auto-creates it when a
    -- person is hired (i.e. when the Worker/WorkRelationship loads). A standalone
    -- PayrollRelationship.dat is rejected as "not a supported business object"
    -- (see objects/PayrollRelationships/README.md, run 142). The object is retired
    -- from the pipeline; its Contract v1 recon report survives only as a read-only
    -- verifier that the payroll relationship was auto-created after the Worker load.
    -- --------------------------------------------------------

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
        -- HDL base-lag retry: publish this cycle's HDL request id + data set
        -- status so EXECUTE_ONE can persist them and the queue can re-run the
        -- base proof on a later tick if the base rows lag.
        DMT_LOADER_PKG.g_hdl_request_id     := l_request_id;
        DMT_LOADER_PKG.g_hdl_dataset_status := l_dataset_status;
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
        -- HDL base-lag retry: publish this cycle's HDL request id + data set
        -- status so EXECUTE_ONE can persist them and the queue can re-run the
        -- base proof on a later tick if the base rows lag.
        DMT_LOADER_PKG.g_hdl_request_id     := l_request_id;
        DMT_LOADER_PKG.g_hdl_dataset_status := l_dataset_status;
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
        -- HDL base-lag retry: publish this cycle's HDL request id + data set
        -- status so EXECUTE_ONE can persist them and the queue can re-run the
        -- base proof on a later tick if the base rows lag.
        DMT_LOADER_PKG.g_hdl_request_id     := l_request_id;
        DMT_LOADER_PKG.g_hdl_dataset_status := l_dataset_status;
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
        -- HDL base-lag retry: publish this cycle's HDL request id + data set
        -- status so EXECUTE_ONE can persist them and the queue can re-run the
        -- base proof on a later tick if the base rows lag.
        DMT_LOADER_PKG.g_hdl_request_id     := l_request_id;
        DMT_LOADER_PKG.g_hdl_dataset_status := l_dataset_status;
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
    -- RUN_GL_BALANCES (public) — self-contained recipe (backlog #8, final family).
    -- GROUPED by LEDGER_NAME: one FBDI zip + one JournalImportLauncher load + one BIP
    -- reconcile per ledger, all inline in a single work-queue item (NOT
    -- spawn-per-partition -- GLBalances is in DMT_CEMLI_SPLIT_CFG with
    -- CHILD_PARTITION_COLUMN NULL, so it loads as one work item like the Purchasing
    -- family). Reuses po_submit_and_reconcile_one for the per-ledger submit/poll/
    -- reconcile. Behaviour is byte-for-byte the pre-refactor GLBalances grouped block
    -- of run_one_object_type.
    PROCEDURE RUN_GL_BALANCES (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC   CONSTANT VARCHAR2(40) := 'RUN_GL_BALANCES';
        C_CEMLI  CONSTANT VARCHAR2(30) := 'GLBalances';
        C_OBJ    CONSTANT VARCHAR2(30) := 'GLBalances';
        v_scenario_id  NUMBER;
        l_ucm_account  VARCHAR2(200);
        l_job_name     VARCHAR2(500);
        l_ifd          NUMBER;
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
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_GL_BALANCES start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);

        sup_preamble(p_run_id, C_CEMLI, C_OBJ, p_skip_bu_refresh);

        -- Phase 1: pre-transform validation.
        DMT_GL_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
        COMMIT;

        -- Phase 2: transform STG -> TFM.
        DMT_GL_TRANSFORM_PKG.TRANSFORM(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;

        -- ERP options for the load submissions (GLBalances uses the default Fusion
        -- credentials -- the monolith passed none to submit_and_reconcile_one).
        get_erp_options(
            p_cemli_code           => C_CEMLI,
            x_ucm_account          => l_ucm_account,
            x_import_job_name      => l_job_name,
            x_interface_details_id => l_ifd);

        -- Phase 3+4: per-ledger load cycle. Each distinct LEDGER_NAME gets its own
        -- FBDI zip, JournalImportLauncher load, and BIP reconciliation (inline).
        FOR led_rec IN (
            SELECT DISTINCT LEDGER_NAME
            FROM   DMT_GL_INTERFACE_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS = 'STAGED'
            AND    LEDGER_NAME IS NOT NULL
            ORDER BY LEDGER_NAME
        ) LOOP
            l_gl_count := l_gl_count + 1;
            DMT_UTIL_PKG.LOG(p_run_id,
                'GL ledger cycle start: ' || led_rec.LEDGER_NAME,
                'INFO', C_PKG, C_OBJ || ' > ' || C_PROC);

            -- Generate FBDI for this ledger only.
            DMT_GL_FBDI_GEN_PKG.GENERATE_FBDI(
                p_run_id      => p_run_id,
                x_fbdi_zip    => l_gl_zip,
                x_filename    => l_gl_filename,
                x_fbdi_csv_id => l_gl_csv_id,
                p_ledger_name => led_rec.LEDGER_NAME);

            IF l_gl_zip IS NULL OR DBMS_LOB.GETLENGTH(l_gl_zip) = 0 THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    'No GL rows for ledger ' || led_rec.LEDGER_NAME || '. Skipping.',
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
                CONTINUE;
            END IF;

            -- Ledger id + data-access-set id via the one common lookup accessor. The
            -- canonical LEDGER_NAME_TO_LEDGER_ID return is ledger_id~access_set_id
            -- (the reserved ~ separator); GET_LOOKUP raises -20040 if unresolvable.
            DECLARE
                l_ledger_lkp VARCHAR2(500);
            BEGIN
                l_ledger_lkp   := DMT_UTIL_PKG.GET_LOOKUP('LEDGER_NAME_TO_LEDGER_ID', led_rec.LEDGER_NAME);
                l_gl_ledger_id := SUBSTR(l_ledger_lkp, 1, INSTR(l_ledger_lkp, '~') - 1);
                l_gl_das_id    := SUBSTR(l_ledger_lkp, INSTR(l_ledger_lkp, '~') + 1);
            END;

            -- Get source from TFM data — not hardcoded 'Spreadsheet'.
            BEGIN
                SELECT USER_JE_SOURCE_NAME INTO l_gl_source
                FROM   DMT_GL_INTERFACE_TFM_TBL
                WHERE  RUN_ID = p_run_id
                AND    LEDGER_NAME = led_rec.LEDGER_NAME
                AND    TFM_STATUS = 'GENERATED'
                AND    ROWNUM = 1;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    l_gl_source := 'Spreadsheet';  -- fallback
            END;

            -- JournalImportLauncher: 7 args -- DAS_ID, Source, LedgerID, GroupID, N, N, N.
            l_gl_param := NVL(l_gl_das_id, '#NULL') || ',' ||
                          l_gl_source || ',' ||
                          l_gl_ledger_id || ',' ||
                          TO_CHAR(p_run_id) || ',N,N,N';

            DMT_UTIL_PKG.LOG(p_run_id,
                'GL ParameterList for ' || led_rec.LEDGER_NAME || ': ' || l_gl_param,
                'INFO', C_PKG, C_OBJ || ' > ' || C_PROC);

            po_submit_and_reconcile_one(
                p_run_id            => p_run_id,
                p_cemli_code        => C_CEMLI,
                p_obj               => C_OBJ,
                p_job_name          => l_job_name,
                p_interface_details => l_ifd,
                p_ucm_account       => l_ucm_account,
                p_fbdi_zip          => l_gl_zip,
                p_filename          => l_gl_filename,
                p_fbdi_csv_id       => l_gl_csv_id,
                p_param_list        => l_gl_param,
                p_group_label       => 'Ledger: ' || led_rec.LEDGER_NAME,
                p_username          => NULL,
                p_password          => NULL,
                x_load_ess_id       => l_gl_load_id,
                x_import_ess_id     => l_gl_import_id,
                x_success           => l_gl_ok);

            IF NOT l_gl_ok THEN
                UPDATE DMT_GL_INTERFACE_TFM_TBL
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
                'INFO', C_PKG, C_OBJ || ' > ' || C_PROC);
        END LOOP;

        IF l_gl_count = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'No STAGED GL balance rows found. Skipping GLBalances.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
            RETURN;
        END IF;

        -- Phase 5: FAILED-row accounting + completion log (counts the GL interface
        -- TFM table, as the monolith grouped_finish did for GLBalances).
        DECLARE
            l_failed_count NUMBER;
        BEGIN
            SELECT COUNT(*) INTO l_failed_count
            FROM DMT_GL_INTERFACE_TFM_TBL
            WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';
            IF l_failed_count > 0 THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    C_CEMLI || ': ' || l_failed_count || ' record(s) FAILED in Fusion. ' ||
                    'Downstream object types will continue — check staging table for details.',
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
            END IF;
        END;

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
    -- RUN_GL_BUDGETS (public) — self-contained recipe (backlog #8, final family).
    -- TWO-STEP load (like Expenditures): loadAndImportData stages the CSV into
    -- GL_BUDGET_INTERFACE (its chained ValidateAndLoadBudgets with no run name is a
    -- throwaway), then a SEPARATE "Validate and Load Budgets" (ValidateAndLoadBudgets)
    -- is submitted STANDALONE once per distinct Run Name -- that is the real cube load.
    -- Reconciliation is cell-grain against GL_BUDGET_BALANCES over a run-start window
    -- (budgets carry no source-line identity), inline via DMT_GL_BUDGET_RESULTS_PKG,
    -- so it sets g_reconciled_inline. Not grouped, not partitioned. Behaviour is
    -- byte-for-byte the pre-refactor GLBudgets block of run_one_object_type.
    PROCEDURE RUN_GL_BUDGETS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC   CONSTANT VARCHAR2(40) := 'RUN_GL_BUDGETS';
        C_CEMLI  CONSTANT VARCHAR2(30) := 'GLBudgets';
        C_OBJ    CONSTANT VARCHAR2(30) := 'GLBudgets';
        v_scenario_id   NUMBER;
        l_ucm_account   VARCHAR2(200);
        l_job_name      VARCHAR2(500);
        l_ifd           NUMBER;
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
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_GL_BUDGETS start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);

        sup_preamble(p_run_id, C_CEMLI, C_OBJ, p_skip_bu_refresh);

        -- Phase 1: pre-transform validation.
        DMT_GL_BUDGET_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
        COMMIT;

        -- Phase 2: transform STG -> TFM.
        DMT_GL_BUDGET_TRANSFORM_PKG.TRANSFORM(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;

        -- ERP options (interface details id / import job name / UCM account).
        get_erp_options(
            p_cemli_code           => C_CEMLI,
            x_ucm_account          => l_ucm_account,
            x_import_job_name      => l_job_name,
            x_interface_details_id => l_ifd);

        -- Phase 3: generate one FBDI zip for all STAGED budget rows this run.
        DMT_GL_BUDGET_FBDI_GEN_PKG.GENERATE_FBDI(
            p_run_id      => p_run_id,
            x_fbdi_zip    => l_gb_zip,
            x_filename    => l_gb_filename,
            x_fbdi_csv_id => l_gb_csv_id);

        SELECT COUNT(*) INTO l_gb_rows
        FROM   DMT_GL_BUDGET_INT_TFM_TBL
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';

        IF l_gb_zip IS NULL OR DBMS_LOB.GETLENGTH(l_gb_zip) = 0 OR l_gb_rows = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'No STAGED GL budget rows found. Skipping GLBudgets.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
            COMMIT;
            RETURN;
        END IF;

        -- Step 1: Load Interface File for Import (loadAndImportData). Loads the CSV
        -- into GL_BUDGET_INTERFACE; its chained ValidateAndLoadBudgets (no run name)
        -- is ignored. ParameterList '#NULL'.
        l_gb_load_id := SUBMIT_LOAD(
            p_run_id            => p_run_id,
            p_fbdi_zip          => l_gb_zip,
            p_filename          => l_gb_filename,
            p_job_name          => l_job_name,
            p_interface_details => l_ifd,
            p_doc_account       => l_ucm_account,
            p_parameter_list    => '#NULL',
            p_log_context       => C_OBJ);
        DBMS_LOB.FREETEMPORARY(l_gb_zip);

        UPDATE DMT_FBDI_ZIP_TBL SET PARAMETER_LIST = '#NULL'
        WHERE  FBDI_ZIP_ID = (SELECT FBDI_ZIP_ID FROM DMT_FBDI_CSV_TBL
                              WHERE FBDI_CSV_ID = l_gb_csv_id);
        COMMIT;

        POLL_ESS_JOB(p_run_id, l_gb_load_id, 1800, FALSE, C_OBJ, C_CEMLI, l_gb_status);
        IF l_gb_status NOT IN (C_STATUS_SUCCEEDED, C_STATUS_WARNING) THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'GL Budget Load ESS ' || l_gb_load_id || ' returned ' || l_gb_status ||
                '. Marking GENERATED rows FAILED.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_OBJ || ' > ' || C_PROC);
            UPDATE DMT_GL_BUDGET_INT_TFM_TBL
            SET    TFM_STATUS = 'FAILED',
                   ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                       '[LOAD_ERROR] Load to GL_BUDGET_INTERFACE failed. Check ESS job ' || l_gb_load_id || '.'),
                   LAST_UPDATED_DATE = SYSDATE
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
            COMMIT;
            RETURN;
        END IF;

        -- Scope reconciliation to a single ledger when the run uses one.
        SELECT COUNT(DISTINCT LEDGER_ID), MAX(LEDGER_ID)
        INTO   l_gb_ledgers, l_gb_ledger
        FROM   DMT_GL_BUDGET_INT_TFM_TBL
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED' AND LEDGER_ID IS NOT NULL;
        IF l_gb_ledgers <> 1 THEN l_gb_ledger := NULL; END IF;

        -- Step 2+3: submit Validate and Load Budgets standalone per Run Name, THEN
        -- reconcile per Run Name with THAT run's own import ESS id.
        --
        -- The recon BASE tier scopes loaded cells to a run by a LAST_UPDATE_DATE
        -- window that opens at the ValidateAndLoadBudgets job's PROCESSSTART
        -- (:P_IMPORT_ESS_ID in bip/GLBudgets/query.sql). Each distinct Run Name is
        -- loaded by its OWN ValidateAndLoadBudgets job, and those jobs run at
        -- different times. A single reconcile after the loop could only pass ONE
        -- import id, so cells loaded by an EARLIER Run Name's job would fall before
        -- the window of the LAST job and never surface as BASE (they would sweep to
        -- UNACCOUNTED). Reconciling INSIDE the loop, once per Run Name with that
        -- iteration's l_gb_import_id, gives every Run Name a window aligned to its
        -- own load job. APPLY_CONTRACT_V1_GLBUDGETS keys on RECON_KEY and guards
        -- TFM_STATUS NOT IN ('LOADED','FAILED'), so calling it once per group never
        -- double-counts or re-touches an already-terminal cell -- whichever pass
        -- proves a cell first wins and later passes skip it.
        FOR rn IN (
            SELECT DISTINCT RUN_NAME
            FROM   DMT_GL_BUDGET_INT_TFM_TBL
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED'
            AND    RUN_NAME IS NOT NULL
            ORDER BY RUN_NAME
        ) LOOP
            l_gb_runs := l_gb_runs + 1;
            DMT_UTIL_PKG.LOG(p_run_id,
                'Submitting ValidateAndLoadBudgets for Run Name: ' || rn.RUN_NAME,
                'INFO', C_PKG, C_OBJ || ' > ' || C_PROC);
            l_gb_import_id := SUBMIT_IMPORT_JOB(
                p_run_id     => p_run_id,
                p_job_name   => l_job_name,
                p_param_list => rn.RUN_NAME);   -- single arg: the Run Name
            POLL_ESS_JOB(p_run_id, l_gb_import_id, 1800, FALSE, C_OBJ, C_CEMLI, l_gb_status);
            DMT_UTIL_PKG.LOG(p_run_id,
                'ValidateAndLoadBudgets ' || l_gb_import_id || ' for ' || rn.RUN_NAME ||
                ' -> ' || l_gb_status, 'INFO', C_PKG, C_OBJ || ' > ' || C_PROC);

            -- Reconcile THIS Run Name's cells with THIS job's import id so the BASE
            -- LAST_UPDATE_DATE window matches the cells this job just wrote.
            DMT_GL_BUDGET_RESULTS_PKG.RECONCILE_BATCH(
                p_run_id        => p_run_id,
                p_load_ess_id   => TO_NUMBER(l_gb_load_id),
                p_import_ess_id => TO_NUMBER(l_gb_import_id),
                p_run_start     => l_gb_run_start,
                p_ledger_id     => l_gb_ledger);
        END LOOP;

        -- Reconcile already ran inline here; tell EXECUTE_ONE not to re-route this work
        -- item to RECONCILING (which would double-reconcile). See backlog #7.
        g_reconciled_inline := TRUE;

        -- Phase 5: FAILED-row accounting + completion log.
        fin_finish(p_run_id, C_CEMLI, C_OBJ);

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
    -- DORMANT / OUT OF SCOPE (owner decision 2026-07-07). PlanningBudgets has no
    --   row in DMT_PIPELINE_DEF_TBL and none in the accounting catalog, so the
    --   queue can never dispatch it — this runner and the per-CEMLI PlanningBudgets
    --   arms below are intentionally kept, not dead-by-accident, so the object can
    --   be revived if EPBCS access appears. Do NOT wire it into a pipeline or the
    --   dispatch registry without an owner decision. Design doc §12 tracks this.
    -- --------------------------------------------------------
    -- RUN_PLAN_BUDGETS (public) — self-contained recipe (backlog #8, final family).
    -- DORMANT: PlanningBudgets has no queue dispatch (EXEC_PROC NULL in
    -- DMT_PIPELINE_DEF_TBL) and no accounting-catalog row, so the queue never runs
    -- it; it executes only via this direct RUN_PLAN_BUDGETS call. Migrated off the
    -- monolith anyway (so the shell can be deleted) as a self-contained SINGLE-LOAD
    -- recipe, ParameterList '#NULL', byte-for-byte the pre-refactor PlanningBudgets
    -- single-load path. Do NOT wire it into a pipeline / dispatch registry without an
    -- owner decision (design doc open-items list).
    PROCEDURE RUN_PLAN_BUDGETS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC   CONSTANT VARCHAR2(40) := 'RUN_PLAN_BUDGETS';
        C_CEMLI  CONSTANT VARCHAR2(30) := 'PlanningBudgets';
        C_OBJ    CONSTANT VARCHAR2(30) := 'PlanningBudgets';
        v_scenario_id NUMBER;
        l_zip         BLOB;
        l_filename    VARCHAR2(200);
        l_csv_id      NUMBER;
        l_ok          BOOLEAN;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_PLAN_BUDGETS start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);

        sup_preamble(p_run_id, C_CEMLI, C_OBJ, p_skip_bu_refresh);

        -- Phase 1: pre-transform validation.
        DMT_PLAN_BUDGET_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
        COMMIT;

        -- Phase 2: transform STG -> TFM.
        DMT_PLAN_BUDGET_TRANSFORM_PKG.TRANSFORM(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;

        -- Phase 3: generate the FBDI zip.
        DMT_PLAN_BUDGET_FBDI_GEN_PKG.GENERATE_FBDI(p_run_id, l_zip, l_filename, l_csv_id);

        -- Phase 4: submit + (async return | poll + import + reconcile). '#NULL' param list.
        l_ok := fin_after_generate(p_run_id, C_CEMLI, C_OBJ, l_zip, l_filename, '#NULL');

        -- Phase 5: FAILED-row accounting + completion log.
        fin_finish(p_run_id, C_CEMLI, C_OBJ);

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
    -- RUN_PROJECT_BUDGETS (public) — self-contained recipe (backlog #8, final family).
    -- SINGLE-LOAD FBDI object. ParameterList '#NULL'. Behaviour is byte-for-byte the
    -- pre-refactor ProjectBudgets single-load path of run_one_object_type.
    PROCEDURE RUN_PROJECT_BUDGETS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC   CONSTANT VARCHAR2(40) := 'RUN_PROJECT_BUDGETS';
        C_CEMLI  CONSTANT VARCHAR2(30) := 'ProjectBudgets';
        C_OBJ    CONSTANT VARCHAR2(30) := 'ProjectBudgets';
        v_scenario_id NUMBER;
        l_zip         BLOB;
        l_filename    VARCHAR2(200);
        l_csv_id      NUMBER;
        l_ok          BOOLEAN;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_PROJECT_BUDGETS start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);

        sup_preamble(p_run_id, C_CEMLI, C_OBJ, p_skip_bu_refresh);

        -- Phase 1: pre-transform validation.
        DMT_PRJ_BUDGET_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
        COMMIT;

        -- Phase 2: transform STG -> TFM.
        DMT_PRJ_BUDGET_TRANSFORM_PKG.TRANSFORM(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
        COMMIT;

        -- Phase 3: generate the FBDI zip.
        DMT_PRJ_BUDGET_FBDI_GEN_PKG.GENERATE_FBDI(p_run_id, l_zip, l_filename, l_csv_id);

        -- Phase 4: submit + (async return | poll + import + reconcile). '#NULL' param list.
        l_ok := fin_after_generate(p_run_id, C_CEMLI, C_OBJ, l_zip, l_filename, '#NULL');

        -- Phase 5: FAILED-row accounting + completion log.
        fin_finish(p_run_id, C_CEMLI, C_OBJ);

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
    -- RUN_ASSETS (public) — self-contained recipe (backlog #8, final family).
    -- SPAWN-PER-PARTITION by BOOK_TYPE_CODE (row in DMT_CEMLI_SPLIT_CFG with
    -- CHILD_PARTITION_COLUMN=BOOK_TYPE_CODE + a GET_PARTITION_KEYS). Like the
    -- Requisitions/Items recipes it serves all three passes the queue / a direct
    -- caller can drive: (1) PARENT transform-only pass (g_partition_key NULL,
    -- g_transform_only TRUE) validates + transforms once and returns before generate,
    -- after which the queue worker spawns one child per book; (2) CHILD load pass
    -- (g_partition_key set to {"BOOK_TYPE_CODE":"..."}) generates + loads ONLY that
    -- book and returns at the async gate for the queue to poll / post-run / reconcile;
    -- (3) legacy standalone (g_partition_key NULL, g_transform_only FALSE) loads all
    -- books in one zip. It is a SINGLE-LOAD object (one FBDI zip per pass, not a
    -- grouped loop): the generator scopes to the child's book via DECODE_PARTITION_KEY.
    -- The AWAITING_POSTRUN / PostMassAdditions report-job step is a queue-worker
    -- concern (untouched); this recipe only submits the load with the book's
    -- '<book>,,NORMAL' ParameterList. Behaviour is byte-for-byte the pre-refactor
    -- Assets path of run_one_object_type.
    PROCEDURE RUN_ASSETS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE) IS
        C_PROC   CONSTANT VARCHAR2(40) := 'RUN_ASSETS';
        C_CEMLI  CONSTANT VARCHAR2(30) := 'Assets';
        C_OBJ    CONSTANT VARCHAR2(30) := 'Assets';
        v_scenario_id NUMBER;
        l_zip         BLOB;
        l_filename    VARCHAR2(200);
        l_csv_id      NUMBER;
        l_param_list  VARCHAR2(500);
        l_ok          BOOLEAN;
    BEGIN
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id,
            'RUN_ASSETS start. Integration ID: ' || p_run_id, 'INFO', C_PKG, C_PROC);

        sup_preamble(p_run_id, C_CEMLI, C_OBJ, p_skip_bu_refresh);

        -- Phase 1+2 run ONLY on the parent transform-only pass (g_partition_key NULL).
        -- A spawned child (g_partition_key set to a book) was already validated +
        -- transformed by its parent; re-transforming would reset its STAGED rows.
        -- Mirrors the g_partition_key gate the monolith used for Assets.
        IF g_partition_key IS NULL THEN
            DMT_FA_ASSET_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(p_run_id);
            COMMIT;
            DMT_FA_ASSET_TRANSFORM_PKG.TRANSFORM_HEADERS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
            DMT_FA_ASSET_TRANSFORM_PKG.TRANSFORM_ASSIGNMENTS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
            DMT_FA_ASSET_TRANSFORM_PKG.TRANSFORM_BOOKS(p_run_id, p_scenario_id => v_scenario_id, p_run_mode => p_run_mode);
            COMMIT;
        END IF;

        -- Parent transform-only pass: stop here. The queue worker reads the distinct
        -- BOOK_TYPE_CODEs and spawns one child work item per book (each re-enters this
        -- recipe with g_partition_key set). Mirrors the monolith transform-only gate.
        IF g_transform_only THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'RUN_ASSETS transform-only pass complete (spawn-per-partition parent).',
                'INFO', C_PKG, C_PROC);
            RETURN;
        END IF;

        -- Phase 3: generate the FBDI zip for ONLY this book when partitioned.
        -- g_partition_key is JSON-encoded for a spawn child (e.g. {"BOOK_TYPE_CODE":
        -- "US CORP"}); decode to the raw book code the generator's static cursor
        -- filters on. NULL passes through (all books) on the standalone path.
        DMT_FA_ASSET_FBDI_GEN_PKG.GENERATE_FBDI(p_run_id, l_zip, l_filename, l_csv_id,
            DMT_LOADER_PKG.DECODE_PARTITION_KEY(g_partition_key, 'BOOK_TYPE_CODE'));

        -- PostMassAdditions ParameterList: '<BookTypeCode>,,NORMAL' (MCCS RICE_003).
        -- No hardcoded ids: the book is named config (ASSET_BOOK_TYPE), not a literal.
        l_param_list := DMT_UTIL_PKG.GET_CONFIG('ASSET_BOOK_TYPE') || ',,NORMAL';

        -- Phase 4: submit + (async return | poll + import + reconcile).
        l_ok := fin_after_generate(p_run_id, C_CEMLI, C_OBJ, l_zip, l_filename, l_param_list);

        -- Backlog #70: stamp THIS child's own load + import ess ids on its own queue
        -- row. fin_after_generate already did so on the sync path; this is a no-op
        -- outside a queue-driven partition child.
        -- (The async live path stamps via the queue poller; nothing extra needed here.)

        -- Phase 5: FAILED-row accounting + completion log.
        fin_finish(p_run_id, C_CEMLI, C_OBJ);

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
    BEGIN
        -- 2026-07-20: superseded by the generic RUN_TRANSFORM_ONLY (which sets
        -- g_transform_only so run_one_object_type returns right after transform).
        -- Kept only as a thin, contract-honoring wrapper so any legacy caller still
        -- gets the same transform-only behavior. The queue worker no longer calls
        -- this directly -- it drives Assets through RUN_TRANSFORM_ONLY like every
        -- other spawn-per-partition object.
        RUN_TRANSFORM_ONLY(
            p_run_id        => p_run_id,
            p_cemli_code    => 'Assets',
            p_scenario_name => p_scenario_name,
            p_run_mode      => p_run_mode);
    END RUN_ASSETS_TRANSFORM_ONLY;

    -- Generic transform-only pass for spawn-per-partition objects (2026-07-20).
    -- Sets g_transform_only so run_one_object_type validates + transforms (STG -> TFM
    -- STAGED) and returns before any generate/submit. Always clears the flag.
    PROCEDURE RUN_TRANSFORM_ONLY (
        p_run_id           IN NUMBER,
        p_cemli_code       IN VARCHAR2,
        p_scenario_name    IN VARCHAR2 DEFAULT NULL,
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        C_PROC CONSTANT VARCHAR2(40) := 'RUN_TRANSFORM_ONLY';
        v_scenario_id NUMBER;
    BEGIN
        -- resolve_scenario validates the scenario name exists (side effect); the
        -- recipes each re-resolve it themselves.
        resolve_scenario(p_scenario_name, v_scenario_id);
        DMT_UTIL_PKG.LOG(p_run_id, 'RUN_TRANSFORM_ONLY start for ' || p_cemli_code || '.',
            'INFO', C_PKG, C_PROC);
        g_transform_only := TRUE;
        -- Partitioned P2P family (backlog #8, third family) is migrated out of
        -- run_one_object_type, so its parent transform-only pass must dispatch to
        -- the object's own recipe instead of the (now guarded) monolith. Each
        -- recipe honours g_transform_only: it validates + transforms STG -> TFM
        -- STAGED and returns before any generate/submit, exactly as the monolith's
        -- transform-only gate did. Every other object still transforms through
        -- run_one_object_type unchanged.
        -- Backlog #8: run_one_object_type is retired. Every spawn-per-partition object
        -- (the only kind the queue worker drives through RUN_TRANSFORM_ONLY -- those
        -- with CHILD_PARTITION_COLUMN + a PARTITION_KEYS_PROC in the registry) now has
        -- its own self-contained recipe that honours g_transform_only: it validates +
        -- transforms STG -> TFM STAGED and returns before any generate/submit, exactly
        -- as the monolith's transform-only gate did. Dispatch each to its recipe with a
        -- static CASE (no new dynamic-SQL site; design doc Coding Standards).
        IF p_cemli_code = 'Requisitions' THEN
            RUN_REQUISITIONS(p_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);
        ELSIF p_cemli_code = 'Items' THEN
            RUN_ITEMS(p_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);
        ELSIF p_cemli_code = 'Assets' THEN
            RUN_ASSETS(p_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);
        ELSIF p_cemli_code = 'Expenditures' THEN
            RUN_EXPENDITURES(p_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);
        ELSE
            -- Only spawn-per-partition objects are dispatched here by the queue worker,
            -- and all four now have explicit cases above. A non-spawn object reaching
            -- this point means a mis-seeded registry (CHILD_PARTITION_COLUMN set without
            -- a matching recipe) -- fail loudly rather than silently no-op.
            RAISE_APPLICATION_ERROR(-20048,
                'RUN_TRANSFORM_ONLY: ' || p_cemli_code || ' has no spawn-per-partition '
                || 'transform-only recipe. Only Requisitions/Items/Assets/Expenditures '
                || 'are spawn-per-partition (backlog #8).');
        END IF;
        g_transform_only := FALSE;
        DMT_UTIL_PKG.LOG(p_run_id, 'RUN_TRANSFORM_ONLY complete for ' || p_cemli_code || '.',
            'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            g_transform_only := FALSE;
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'RUN_TRANSFORM_ONLY failed for ' || p_cemli_code || '.',
                SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RUN_TRANSFORM_ONLY;

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

        SELECT DMT_PIPELINE_RUN_SEQ.NEXTVAL INTO l_run_id FROM DUAL;
        SELECT TO_CHAR(DMT_RUN_PREFIX_SEQ.NEXTVAL) INTO l_prefix FROM DUAL;

        INSERT INTO DMT_PIPELINE_RUN_TBL (
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
        FROM   DMT_PJF_PROJECTS_TFM_TBL
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

        SELECT DMT_PIPELINE_RUN_SEQ.NEXTVAL INTO l_run_id FROM DUAL;
        SELECT TO_CHAR(DMT_RUN_PREFIX_SEQ.NEXTVAL) INTO l_prefix FROM DUAL;

        INSERT INTO DMT_PIPELINE_RUN_TBL (
            RUN_ID, INTEGRATION_ID, PIPELINE_CODES, RUN_TYPE,
            SUBMITTED_BY, RUN_STATUS, PREFIX, CEMLI_SEQUENCE,
            SCENARIO_NAME, RUN_MODE
        ) VALUES (
            l_run_id, l_run_id, 'HCM', 'PIPELINE',
            'MANUAL', 'IN_PROGRESS', l_prefix,
            'Workers,Salaries,SalaryBases,TaxCards,W2Balances,BenParticipant,BenDependent,BenBeneficiary,Absences',
            p_scenario_name, p_run_mode
        );
        COMMIT;

        x_run_id := l_run_id;

        DMT_UTIL_PKG.LOG(l_run_id,
            'RUN_HCM_PIPELINE start. Integration ID: ' || l_run_id ||
            ' | Prefix: ' || l_prefix, 'INFO', C_PKG, C_PROC);

        DMT_UTIL_PKG.REFRESH_BU_LOOKUPS;

        -- Workers first (master data — all other HCM objects depend on workers).
        -- The single Worker load now also carries the assignment + work-relationship
        -- components (2026-09-17 model correction), so there is no separate
        -- Assignments step. The payroll relationship is auto-created at hire, so
        -- there is no PayrollRelationships step either.
        RUN_WORKERS(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);

        -- Salary and salary basis depend on the worker's assignment (loaded above)
        RUN_SALARIES(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);
        RUN_SALARY_BASES(l_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE);

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

        SELECT DMT_PIPELINE_RUN_SEQ.NEXTVAL INTO l_run_id FROM DUAL;
        SELECT TO_CHAR(DMT_RUN_PREFIX_SEQ.NEXTVAL) INTO l_prefix FROM DUAL;

        INSERT INTO DMT_PIPELINE_RUN_TBL (
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
