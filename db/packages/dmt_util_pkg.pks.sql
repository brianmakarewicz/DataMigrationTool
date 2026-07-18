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
--   - Prefix helper PREFIXED (run prefixes come from DMT_RUN_PREFIX_SEQ
--     at run creation and live on DMT_PIPELINE_RUN_TBL.PREFIX)
--   - Error text append helper (never overwrites ERROR_TEXT)
--   - Base64 encode utility (used by FBDI generation)
-- ============================================================

    -- Log type constants
    C_LOG_INFO   CONSTANT VARCHAR2(5) := 'INFO';
    C_LOG_WARN   CONSTANT VARCHAR2(5) := 'WARN';
    C_LOG_ERROR  CONSTANT VARCHAR2(5) := 'ERROR';

    -- Shared procedure-outcome constants (section 7 procedures-only
    -- contract): every pipeline procedure reports its outcome through
    -- an x_error_code OUT parameter set to one of these; callers test
    -- against the constants, never literals.
    C_SUCCESS    CONSTANT NUMBER := 0;
    C_ERROR      CONSTANT NUMBER := 1;

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

    -- Session log context. The queue worker sets the current work item's
    -- run and queue id once (per child-job session); every LOG / LOG_ERROR
    -- call in that session then stamps QUEUE_ID automatically, so callers do
    -- not thread the queue id through every logging call. Package globals are
    -- session-scoped, so a child job's context is isolated to its own session
    -- and vanishes when the job ends (nothing to clear across jobs).
    PROCEDURE SET_LOG_CONTEXT (
        p_run_id   IN NUMBER,
        p_queue_id IN NUMBER DEFAULT NULL
    );
    PROCEDURE CLEAR_LOG_CONTEXT;

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

    -- General-purpose HTTP request (GET or POST) — the ONE shared
    -- outbound transport (section 7 single-outbound-transport rule):
    -- request build, chunked write, response read, timeout and
    -- non-2xx raise implemented once. SOAP callers pass
    -- p_soap_action (sets the SOAPAction header) and p_accept
    -- ('text/xml'); callers whose credentials travel inside the
    -- envelope pass p_send_auth => FALSE to suppress the Basic
    -- Authorization header. p_raise_on_error => FALSE returns the
    -- non-2xx status to the caller instead of raising, for callers
    -- that map HTTP/SOAP failures to their own documented error
    -- codes — those callers MUST still check x_status_code.
    -- Logs the call (URL, method, status) via autonomous transaction;
    -- never logs the request body (envelopes carry credentials).
    PROCEDURE HTTP_REQUEST (
        p_url            IN  VARCHAR2,
        p_method         IN  VARCHAR2,              -- 'GET' or 'POST'
        p_body           IN  CLOB        DEFAULT NULL,
        p_content_type   IN  VARCHAR2    DEFAULT 'application/json',
        p_run_id IN  NUMBER      DEFAULT NULL,
        x_response       OUT CLOB,
        x_status_code    OUT NUMBER,
        p_soap_action    IN  VARCHAR2    DEFAULT NULL,
        p_accept         IN  VARCHAR2    DEFAULT 'application/json',
        p_send_auth      IN  BOOLEAN     DEFAULT TRUE,
        p_raise_on_error IN  BOOLEAN     DEFAULT TRUE,
        p_auth_header    IN  VARCHAR2    DEFAULT NULL   -- override the Basic header (per-credential probes); NULL => global
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
    -- Prefix helper
    -- (One prefix per run, assigned from DMT_RUN_PREFIX_SEQ at run
    --  creation and stored on DMT_PIPELINE_RUN_TBL.PREFIX — design
    --  section 6. The retired per-CEMLI prefix-master mechanism
    --  (GET_PREFIX / INCREMENT_AND_GET_PREFIX over the old
    --  prefix-master table) was removed 2026-07-08, Stage C.)
    -- --------------------------------------------------------

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

    -- ============================================================
    -- FBDI CSV<->ZIP helpers (one DMT_FBDI_CSV_TBL row per physical CSV).
    -- Generators call REGISTER_CSV once per file, then BUILD_ZIP_FROM_CSVS
    -- which zips the persisted CSV_CONTENT rows (not in-memory CLOBs).
    -- ============================================================

    -- Persist one physical CSV as a child of a pre-allocated zip id.
    -- Returns the new FBDI_CSV_ID via OUT (stamp it on that file's TFM rows).
    -- Procedure, not function: it writes a table (design section 7 -- pipeline
    -- functions may not have side effects).
    PROCEDURE REGISTER_CSV (
        p_run_id      IN NUMBER,
        p_fbdi_zip_id IN NUMBER,          -- pre-fetched DMT_FBDI_ZIP_ID_SEQ.NEXTVAL
        p_file_seq    IN NUMBER,          -- 1..N, preserves zip member order
        p_object_type IN VARCHAR2,
        p_filename    IN VARCHAR2,        -- CSV member name inside the zip
        p_row_count   IN NUMBER,
        p_csv         IN CLOB,
        x_fbdi_csv_id OUT NUMBER
    );

    -- Build the zip BLOB from the persisted CSV rows for p_fbdi_zip_id
    -- (ordered by FILE_SEQ), insert the DMT_FBDI_ZIP_TBL row, and return the BLOB.
    PROCEDURE BUILD_ZIP_FROM_CSVS (
        p_run_id       IN  NUMBER,
        p_fbdi_zip_id  IN  NUMBER,
        p_object_type  IN  VARCHAR2,
        p_zip_filename IN  VARCHAR2,
        x_fbdi_zip     OUT BLOB,
        x_zip_bytes    OUT NUMBER
    );

    -- Base64-encode a BLOB and return the result as a CLOB.
    -- Processes in 12000-byte chunks (multiple of 3) to avoid
    -- mid-stream padding artefacts.
    FUNCTION BASE64_ENCODE (p_blob IN BLOB) RETURN CLOB;

    -- Decode a base64 CLOB of ANY size to a BLOB. Processes in 4-char-aligned
    -- chunks so the result is correct regardless of length. This is the counterpart
    -- to BASE64_ENCODE and the fix for the per-reconciler bug where the base64 was
    -- read into a VARCHAR2(32767) and truncated (corrupting any report over 32K).
    FUNCTION BASE64_DECODE_CLOB (p_b64 IN CLOB) RETURN BLOB;

    -- Build an HTTP Basic Authorization header value ('Basic <base64>').
    -- Credentials default to FUSION_USERNAME/FUSION_PASSWORD from DMT_CONFIG_TBL;
    -- pass p_username/p_password to override (per-CEMLI credentials).
    -- Strips the CR/LF line breaks UTL_ENCODE.BASE64_ENCODE inserts every 64
    -- output chars — without the strip, any user:password over 48 bytes produced
    -- a corrupt multi-line header. Centralised so the SOAP/REST helpers stop
    -- carrying private copies of the encode+strip logic.
    -- Raises -20002 when a credential resolves to NULL.
    FUNCTION BASIC_AUTH_HEADER (
        p_username IN VARCHAR2 DEFAULT NULL,
        p_password IN VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2;

    -- Redact credential material from text that is about to be logged.
    -- Masks the CONTENT of any <...password...> and <...userID...> XML element
    -- (any namespace prefix, any case) and the value of any Authorization
    -- header ('Basic ...' / 'Bearer ...' / raw token) with ***MASKED***.
    -- EVERY log of a request envelope (SOAP/REST) MUST pass through this
    -- helper — logging a raw request envelope is a security defect (the
    -- 2026-07-08 Suppliers blind review found the Fusion password in
    -- DMT_LOG_TBL in plaintext). NULL-safe: returns NULL for NULL input.
    FUNCTION MASK_CREDENTIALS (p_text IN CLOB) RETURN CLOB;

    -- --------------------------------------------------------
    -- BIP report reconciliation (SOAP v2 ReportService)
    -- --------------------------------------------------------

    -- Run a deployed BIP report via SOAP runReport (through the shared
    -- HTTP_REQUEST transport) and return its data as XMLTYPE.
    -- Centralised replacement for the per-reconciler bip_soap_post + FETCH_BIP_RESULTS
    -- + b64_to_clob + <reportBytes> extraction (previously copy-pasted into 21 packages,
    -- each carrying the VARCHAR2(32767) truncation bug).
    --   p_cemli_code  : resolves REPORT_CATALOG_PATH from DMT_BIP_REPORT_TBL (unless
    --                   p_report_path is supplied).
    --   p_params      : 'NAME|VALUE~NAME2|VALUE2' (Contract v1:
    --                   'P_RUN_ID|1~P_LOAD_REQUEST_ID|2~P_IMPORT_ESS_ID|3~P_PREFIX|10001').
    -- PROCEDURE per the section 7 procedures-only contract (network call):
    --   x_report_xml : the decoded report data; NULL with x_error_code =
    --                  C_SUCCESS means BIP produced no <reportBytes>
    --                  (zero rows) — the caller applies its own no-rows policy.
    --   x_error_code : C_SUCCESS or C_ERROR. On C_ERROR the failure detail
    --                  (HTTP status / SOAP fault / decode failure, with the
    --                  step in flight) is in DMT_LOG_TBL; x_report_xml is NULL.
    --                  Exceptions never escape.
    PROCEDURE RUN_BIP_REPORT (
        p_run_id      IN  NUMBER,
        p_cemli_code  IN  VARCHAR2,
        p_params      IN  VARCHAR2,
        x_report_xml  OUT XMLTYPE,
        x_error_code  OUT NUMBER,
        p_report_path IN  VARCHAR2 DEFAULT NULL
    );

    -- Given a BIP SOAP runReport response CLOB, extract <reportBytes>, decode it
    -- (any size, via BASE64_DECODE_CLOB) and return the report as XMLTYPE. Returns
    -- NULL when there is no <reportBytes> (zero rows). Raises -20036 on decode/parse
    -- failure. This is the shared replacement for each reconciler's local b64_to_clob
    -- + VARCHAR2(32767) <reportBytes> extraction; PARSE_AND_UPDATE calls this instead.
    FUNCTION BIP_REPORT_XML (p_soap_response IN CLOB) RETURN XMLTYPE;

    -- --------------------------------------------------------
    -- Scenario management
    -- --------------------------------------------------------

    -- Look up a scenario by name (case-insensitive, trimmed). If it
    -- does not exist, create it. PROCEDURE per the section 7
    -- procedures-only contract (writes rows):
    --   x_scenario_id : the existing or newly created SCENARIO_ID;
    --                   NULL (with x_error_code = C_SUCCESS) when
    --                   p_scenario_name is NULL.
    --   x_error_code  : C_SUCCESS or C_ERROR (failure detail logged
    --                   to DMT_LOG_TBL; exceptions never escape).
    -- Does not commit — the caller owns the transaction.
    PROCEDURE GET_OR_CREATE_SCENARIO (
        p_scenario_name IN  VARCHAR2,
        x_scenario_id   OUT NUMBER,
        x_error_code    OUT NUMBER
    );

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

    -- Run all lookup BIP data models and refresh DMT_LOOKUP_TBL with the
    -- canonical lookup types (design section 7 "canonical lookup registry"):
    -- BU_NAME_TO_BU_ID, BU_NAME_TO_PRIMARY_LEDGER_ID, and
    -- LEDGER_NAME_TO_LEDGER_ID (RETURN_VALUE = ledger_id~access_set_id).
    -- Full refresh of the managed types (delete-then-insert). Safe to call at
    -- pipeline start to keep instance-specific ids current.
    PROCEDURE REFRESH_LOOKUPS;

    -- Legacy alias -- calls REFRESH_LOOKUPS.
    PROCEDURE REFRESH_BU_LOOKUPS;

    -- Resolve one canonical lookup: return the RETURN_VALUE for
    -- (LOOKUP_TYPE = p_type, LOOKUP_VALUE = p_value) from DMT_LOOKUP_TBL.
    -- The one accessor every caller uses instead of a scattered inline SELECT
    -- (design section 7 "One common lookup table"). Raises -20040 (a single,
    -- clear halt-the-run error) when the row is missing or not unique -- a
    -- function that signals failure ONLY by raising, per the section-7
    -- procedures-only contract's enumerated read-function carve-out.
    FUNCTION GET_LOOKUP (
        p_type  IN VARCHAR2,
        p_value IN VARCHAR2
    ) RETURN VARCHAR2;

    -- --------------------------------------------------------
    -- Pipeline preflight (run-start prerequisites)
    -- --------------------------------------------------------

    -- Verify one Fusion credential authenticates. Makes exactly ONE
    -- authenticated GET to the Fusion instance and reads the HTTP status.
    -- 401 => the credential is bad; any other status (200/403/404/...)
    -- proves the password signs in -- we care only that it authenticates,
    -- not what it may access, so this works uniformly for FSCM and HCM
    -- users. NEVER retries a 401 (project rule: on 401 stop, never retry
    -- into a lockout). Outcome is the section-7 error-code contract:
    -- x_error_code = C_SUCCESS if the credential authenticates, C_ERROR if
    -- it is rejected or cannot be verified; the reason is written to the
    -- activity log at the point of failure, never returned as text.
    PROCEDURE VERIFY_CREDENTIAL (
        p_username   IN  VARCHAR2,
        p_password   IN  VARCHAR2,
        x_error_code OUT NUMBER
    );

    -- Pipeline preflight, run once before a run dispatches any object.
    -- (1) REFRESH_LOOKUPS -- repopulate the name->id lookups from Fusion
    --     (this call also proves the global Fusion credential authenticates).
    -- (2) VERIFY_CREDENTIAL for every DISTINCT credential the run's objects
    --     use (per-object overrides + the global default).
    -- Returns x_error_code = C_SUCCESS when the refresh succeeds and every
    -- credential authenticates; C_ERROR on any failure, so the caller can
    -- halt the run cleanly before any FBDI is submitted (loads nothing on
    -- failure). Each failure is logged where it happens. Scope note
    -- (2026-07-10): the preflight does NOT pre-check that every lookup
    -- VALUE a run needs is present -- a genuinely missing value halts later
    -- at first use (GET_LOOKUP), not here. (Pipeline-preflight rationale for
    -- this PR; the DMT_DESIGN.html section-7 write-up is a pending follow-up.)
    PROCEDURE RUN_PREFLIGHT (
        p_run_id     IN  NUMBER,
        x_error_code OUT NUMBER
    );

END DMT_UTIL_PKG;
/
