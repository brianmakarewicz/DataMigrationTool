-- PACKAGE DMT_UTIL_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_UTIL_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_UTIL_PKG
-- Core utilities called by every other DMT package.
-- Runs with AUTHID DEFINER so APEX users do not need direct
-- DB privileges.
--
-- Responsibilities:
--   - Configuration management (GET/SET_CONFIG, SET_FUSION_URL)
--   - Execution logging to DMT_LOG_TBL (autonomous transaction)
--   - Outbound HTTP wrapper (Fusion REST API calls)
--   - BIP report fetch (Fusion xmlpserver REST)
--   - Prefix management (DMT_PREFIX_MASTER_TBL)
--   - Error text append helper (never overwrites ERROR_TEXT)
--   - Base64 encode utility (used by FBDI generation)
-- ============================================================

    -- Log type constants
    C_LOG_INFO   CONSTANT VARCHAR2(5) := 'INFO';
    C_LOG_WARN   CONSTANT VARCHAR2(5) := 'WARN';
    C_LOG_ERROR  CONSTANT VARCHAR2(5) := 'ERROR';

    -- --------------------------------------------------------
    -- Configuration
    -- --------------------------------------------------------

    -- Set the active Fusion base URL.
    -- Manages the network ACL automatically (remove old host, add new).
    -- Safe to call repeatedly.
    PROCEDURE SET_FUSION_URL (p_url IN VARCHAR2);

    -- Return a config value by key. Returns NULL if key not found.
    FUNCTION GET_CONFIG (p_key IN VARCHAR2) RETURN VARCHAR2;

    -- Upsert a config value. Use for non-URL settings.
    PROCEDURE SET_CONFIG (
        p_key         IN VARCHAR2,
        p_value       IN VARCHAR2,
        p_description IN VARCHAR2 DEFAULT NULL
    );

    -- --------------------------------------------------------
    -- Logging â€” all writes use AUTONOMOUS TRANSACTION
    -- so log entries survive even if the caller rolls back
    -- --------------------------------------------------------

    -- Write an INFO or WARN log entry.
    PROCEDURE LOG (
        p_run_id IN NUMBER    DEFAULT NULL,
        p_message        IN VARCHAR2,
        p_log_type       IN VARCHAR2  DEFAULT 'INFO',
        p_package        IN VARCHAR2  DEFAULT NULL,
        p_procedure      IN VARCHAR2  DEFAULT NULL
    );

    -- Write an ERROR log entry including the Oracle error text.
    -- Call immediately in the EXCEPTION block before any other logic.
    PROCEDURE LOG_ERROR (
        p_run_id IN NUMBER    DEFAULT NULL,
        p_message        IN VARCHAR2,
        p_sqlerrm        IN VARCHAR2,
        p_package        IN VARCHAR2  DEFAULT NULL,
        p_procedure      IN VARCHAR2  DEFAULT NULL
    );

    -- --------------------------------------------------------
    -- HTTP â€” Fusion REST API calls
    -- --------------------------------------------------------

    -- General-purpose HTTP request (GET or POST).
    -- Raises an application error if the HTTP status code is not 2xx.
    -- Logs the call (URL, method, status) via autonomous transaction.
    PROCEDURE HTTP_REQUEST (
        p_url            IN  VARCHAR2,
        p_method         IN  VARCHAR2,              -- 'GET' or 'POST'
        p_body           IN  CLOB        DEFAULT NULL,
        p_content_type   IN  VARCHAR2    DEFAULT 'application/json',
        p_run_id IN  NUMBER      DEFAULT NULL,
        x_response       OUT CLOB,
        x_status_code    OUT NUMBER
    );

    -- --------------------------------------------------------
    -- BIP â€” Fusion BI Publisher report fetch (xmlpserver REST)
    -- --------------------------------------------------------

    -- Fetch a BIP report and return its content as a CLOB.
    -- p_params format: 'PARAM_NAME|VALUE~PARAM_NAME2|VALUE2'
    -- Output is the decoded report content (CSV, XML, etc.)
    PROCEDURE BIP_REQUEST (
        p_report_path    IN  VARCHAR2,
        p_params         IN  VARCHAR2    DEFAULT NULL,
        p_output_format  IN  VARCHAR2    DEFAULT 'csv',
        p_run_id IN  NUMBER      DEFAULT NULL,
        x_report_data    OUT CLOB
    );

    -- --------------------------------------------------------
    -- Prefix management
    -- --------------------------------------------------------

    -- Return the current prefix for a CEMLI WITHOUT incrementing it.
    -- Use for dependent upstream lookups.
    FUNCTION GET_PREFIX (p_cemli IN VARCHAR2) RETURN VARCHAR2;

    -- Increment the prefix for a CEMLI by 1, update PREFIX_MASTER,
    -- and return the new value. Uses AUTONOMOUS_TRANSACTION so the
    -- update commits even if the calling transaction rolls back.
    FUNCTION INCREMENT_AND_GET_PREFIX (
        p_cemli       IN VARCHAR2,
        p_instance_id IN VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2;

    -- Prepend prefix to a value, truncating the value so the result
    -- fits within p_max_len characters.  If the prefix is NULL or empty,
    -- returns the value unchanged (truncated to p_max_len).
    -- Usage:  PREFIXED(l_prefix, s.VENDOR_SITE_CODE, 15)
    FUNCTION PREFIXED (
        p_prefix  IN VARCHAR2,
        p_value   IN VARCHAR2,
        p_max_len IN NUMBER DEFAULT 240
    ) RETURN VARCHAR2 DETERMINISTIC;

    -- --------------------------------------------------------
    -- Credential resolution â€” per-CEMLI overrides
    -- --------------------------------------------------------

    -- Resolve Fusion credentials for a CEMLI.
    -- Checks DMT_ERP_INTERFACE_OPTIONS_TBL.FUSION_USERNAME/PASSWORD first.
    -- Falls back to DMT_CONFIG_TBL FUSION_USERNAME/PASSWORD if NULL.
    -- HCM CEMLIs fall back to HCM_USERNAME/PASSWORD instead.
    PROCEDURE GET_CEMLI_CREDENTIALS (
        p_cemli_code IN  VARCHAR2,
        x_username   OUT VARCHAR2,
        x_password   OUT VARCHAR2
    );

    -- Resolve Fusion credentials from an ESS request_id.
    -- Looks up: request_id -> DMT_ESS_JOB_TBL -> CONVERSION_MASTER -> CEMLI
    -- then calls GET_CEMLI_CREDENTIALS. Falls back to FUSION defaults if
    -- the request_id can't be resolved.
    PROCEDURE GET_CREDENTIALS_FOR_REQUEST (
        p_request_id IN  NUMBER,
        x_username   OUT VARCHAR2,
        x_password   OUT VARCHAR2
    );

    -- --------------------------------------------------------
    -- Error text utilities
    -- --------------------------------------------------------

    -- Append a new error message to an existing ERROR_TEXT CLOB.
    -- If ERROR_TEXT is null, returns the new message alone.
    -- If ERROR_TEXT already has content, appends ' | ' then the new message.
    -- Never overwrites existing errors.
    FUNCTION APPEND_ERROR (
        p_existing  IN CLOB,
        p_new_error IN VARCHAR2
    ) RETURN CLOB;

    -- --------------------------------------------------------
    -- FBDI utilities
    -- --------------------------------------------------------

    -- Convert a CLOB to a BLOB using AL32UTF8 charset conversion.
    -- Returns an empty BLOB (not NULL) when p_clob is NULL or empty.
    -- Centralised version â€” generators should call this instead of
    -- maintaining a local copy.
    FUNCTION CLOB_TO_BLOB (p_clob IN CLOB) RETURN BLOB;

    -- Base64-encode a BLOB and return the result as a CLOB.
    -- Processes in 12000-byte chunks (multiple of 3) to avoid
    -- mid-stream padding artefacts.
    FUNCTION BASE64_ENCODE (p_blob IN BLOB) RETURN CLOB;

    -- Decode a base64 CLOB of ANY size to a BLOB. Processes in 4-char-aligned
    -- chunks so the result is correct regardless of length. This is the counterpart
    -- to BASE64_ENCODE and the fix for the per-reconciler bug where the base64 was
    -- read into a VARCHAR2(32767) and truncated (corrupting any report over 32K).
    FUNCTION BASE64_DECODE_CLOB (p_b64 IN CLOB) RETURN BLOB;

    -- --------------------------------------------------------
    -- BIP report reconciliation (SOAP v2 ReportService)
    -- --------------------------------------------------------

    -- Run a deployed BIP report via SOAP runReport and return its data as XMLTYPE.
    -- Centralised replacement for the per-reconciler bip_soap_post + FETCH_BIP_RESULTS
    -- + b64_to_clob + <reportBytes> extraction (previously copy-pasted into 21 packages,
    -- each carrying the VARCHAR2(32767) truncation bug).
    --   p_cemli_code  : resolves REPORT_CATALOG_PATH from DMT_BIP_REPORT_TBL (unless
    --                   p_report_path is supplied).
    --   p_params      : 'NAME|VALUE~NAME2|VALUE2' (e.g. 'P_BATCH_ID|123~P_IMPORT_ESS_ID|456').
    -- Returns NULL when BIP produced no <reportBytes> (zero rows) so the caller can apply
    -- its own no-rows policy. Raises -20034 on SOAP fault, -20036 on decode/parse failure.
    FUNCTION RUN_BIP_REPORT (
        p_run_id      IN NUMBER,
        p_cemli_code  IN VARCHAR2,
        p_params      IN VARCHAR2,
        p_report_path IN VARCHAR2 DEFAULT NULL
    ) RETURN XMLTYPE;

    -- Given a BIP SOAP runReport response CLOB, extract <reportBytes>, decode it
    -- (any size, via BASE64_DECODE_CLOB) and return the report as XMLTYPE. Returns
    -- NULL when there is no <reportBytes> (zero rows). Raises -20036 on decode/parse
    -- failure. This is the shared replacement for each reconciler's local b64_to_clob
    -- + VARCHAR2(32767) <reportBytes> extraction; PARSE_AND_UPDATE calls this instead.
    FUNCTION BIP_REPORT_XML (p_soap_response IN CLOB) RETURN XMLTYPE;

    -- --------------------------------------------------------
    -- Scenario management
    -- --------------------------------------------------------

    -- Look up a scenario by name (case-insensitive). If it does not
    -- exist, create it and return the new SCENARIO_ID.
    -- Returns NULL if p_scenario_name is NULL.
    FUNCTION GET_OR_CREATE_SCENARIO (
        p_scenario_name IN VARCHAR2
    ) RETURN NUMBER;

    -- --------------------------------------------------------
    -- Deep link generation
    -- --------------------------------------------------------

    -- Build a Fusion deep link URL for a loaded record.
    -- Looks up the objType and key template from DMT_BIP_REPORT_TBL
    -- for the given CEMLI, replaces {ID} with p_fusion_id, and
    -- returns the full URL. Returns NULL if no deep link is
    -- configured, if the Fusion URL is not set, or if p_fusion_id
    -- is NULL.
    -- HCM objects use /hcmUI/faces/deeplink; ERP objects use
    -- /fscmUI/faces/deeplink.
    FUNCTION GET_DEEP_LINK (
        p_cemli_code IN VARCHAR2,
        p_fusion_id  IN VARCHAR2
    ) RETURN VARCHAR2;

    -- --------------------------------------------------------
    -- Lookup Refresh
    -- --------------------------------------------------------

    -- Run all lookup BIP data models and MERGE results into
    -- DMT_LOOKUP_TBL. Each DM returns the standard format:
    -- LOOKUP_TYPE, LOOKUP_CODE, LOOKUP_VALUE, LOOKUP_VALUE2.
    -- Currently registered lookups: BU, LEDGER.
    -- Safe to call at pipeline start to keep instance-specific
    -- IDs current. Replaces the old REFRESH_BU_LOOKUPS.
    PROCEDURE REFRESH_LOOKUPS;

    -- Legacy alias â€” calls REFRESH_LOOKUPS.
    PROCEDURE REFRESH_BU_LOOKUPS;

END DMT_UTIL_PKG;
/
