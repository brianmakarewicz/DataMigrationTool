-- PACKAGE DMT_ESS_UTIL_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_ESS_UTIL_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_ESS_UTIL_PKG
-- ESS job hierarchy capture and output file download.
--
-- CAPTURE_ESS_HIERARCHY: After a parent ESS job reaches terminal
--   status, queries ESS_REQUEST_HISTORY via BIP for all descendants
--   and populates DMT_ESS_JOB_TBL.
--
-- DOWNLOAD_ESS_FILE_BLOB / GET_ESS_ZIP / GET_ESS_OUTPUT_*: call
--   downloadESSJobExecutionDetails as the Fusion user that submitted the
--   request (central resolver, backlog #309).
-- ============================================================

    -- Capture the full ESS job hierarchy (parent + all descendants)
    -- into DMT_ESS_JOB_TBL. Call after POLL_ESS_JOB reaches terminal status.
    PROCEDURE CAPTURE_ESS_HIERARCHY (
        p_run_id   IN NUMBER,
        p_parent_request_id IN NUMBER,
        p_cemli_code       IN VARCHAR2 DEFAULT NULL
    );

    -- Download ESS output as BLOB (binary-safe, handles MTOM).
    -- p_username / p_password: a pair from DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS.
    -- Both NULL = trace the request id to the CEMLI that submitted it
    -- (DMT_UTIL_PKG.GET_CREDENTIALS_FOR_REQUEST); Fusion refuses another
    -- user's ESS output with HTTP 500. Every ESS download funnels through here.
    FUNCTION DOWNLOAD_ESS_FILE_BLOB (
        p_request_id IN NUMBER,
        p_file_type  IN VARCHAR2 DEFAULT NULL,
        p_username   IN VARCHAR2 DEFAULT NULL,
        p_password   IN VARCHAR2 DEFAULT NULL
    ) RETURN BLOB;

    -- Download ESS output, extract ZIP from MTOM, return ZIP as BLOB.
    -- Use UTL_ZIP.get_file_list / get_file to extract individual entries.
    FUNCTION GET_ESS_ZIP (
        p_request_id IN NUMBER,
        p_username   IN VARCHAR2 DEFAULT NULL,
        p_password   IN VARCHAR2 DEFAULT NULL
    ) RETURN BLOB;

    -- Download ESS output ZIP, extract .log file, return as CLOB.
    -- Falls back to .xml if no .log found.
    -- p_username / p_password: as DOWNLOAD_ESS_FILE_BLOB. p_cemli_code: when no
    -- pair is passed, download as that object's central Fusion user
    -- (DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS) -- the preferred form for callers.
    FUNCTION GET_ESS_OUTPUT_TEXT (
        p_request_id IN NUMBER,
        p_file_type  IN VARCHAR2 DEFAULT NULL,
        p_username   IN VARCHAR2 DEFAULT NULL,
        p_password   IN VARCHAR2 DEFAULT NULL,
        p_cemli_code IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB;

    -- Download ESS output ZIP, extract the BIP XML report, return as CLOB.
    -- Use for Import Report error parsing (e.g. ImportProjectReportJob output).
    -- p_username / p_password: download as the Fusion user that SUBMITTED the
    -- request (Fusion refuses another user's ESS output with HTTP 500). Pass
    -- the pair from DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS; both NULL = resolved
    -- from the request id (see DOWNLOAD_ESS_FILE_BLOB). p_cemli_code: as
    -- GET_ESS_OUTPUT_TEXT.
    FUNCTION GET_ESS_OUTPUT_XML (
        p_request_id IN NUMBER,
        p_username   IN VARCHAR2 DEFAULT NULL,
        p_password   IN VARCHAR2 DEFAULT NULL,
        p_cemli_code IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB;

    -- Download ESS output for the given Import ESS job and log it.
    -- Called automatically when BIP reconciliation finds 0 matching rows.
    -- Also callable manually for diagnostics.
    PROCEDURE CAPTURE_ESS_OUTPUT (
        p_run_id IN NUMBER,
        p_request_id     IN NUMBER,
        p_cemli_code     IN VARCHAR2 DEFAULT NULL
    );

    -- Enumerate available output files for a single ESS child job.
    -- Downloads the MTOM response, parses the ZIP central directory to
    -- discover filenames, inserts metadata rows into DMT_ESS_JOB_FILE_TBL.
    -- File content is NOT stored — only filenames and types.
    --
    -- LIVE / ON-DEMAND ONLY. This downloads a file to read its filenames, so it is
    -- never called during a pipeline run (run-time polling is status-only — see the
    -- ESS-download rework). It is invoked lazily by the drill page (APEX page 58,
    -- "Fetch File List from Fusion") for the single request the user is viewing.
    PROCEDURE ENUMERATE_ESS_FILES (
        p_ess_job_id   IN NUMBER,
        p_request_id   IN NUMBER,
        p_username     IN VARCHAR2 DEFAULT NULL,
        p_password     IN VARCHAR2 DEFAULT NULL
    );

    -- Enumerate files for ALL child jobs of an integration run.
    --
    -- NOT part of the pipeline anymore. It downloads + unzips every output file of
    -- every job in the run just to read filenames, so calling it per poll cycle was
    -- the O(cycles × files) cost the ESS-download rework removed. Filename discovery
    -- is now deferred to live user action, one request at a time, via
    -- ENUMERATE_ESS_FILES. Retained only as a manual bulk-diagnostic helper; do NOT
    -- wire it back into POLL_ESS_JOB or any run-time path.
    PROCEDURE ENUMERATE_ALL_ESS_FILES (
        p_run_id IN NUMBER,
        p_username       IN VARCHAR2 DEFAULT NULL,
        p_password       IN VARCHAR2 DEFAULT NULL
    );

    -- Download a specific file from an ESS job and stream to browser.
    -- Called from APEX AJAX callback. Sends proper Content-Disposition
    -- and Content-Type headers for browser download.
    -- p_request_id: Fusion ESS request ID
    -- p_file_name:  exact filename to extract from the ZIP (as stored in DMT_ESS_JOB_FILE_TBL)
    PROCEDURE DOWNLOAD_ESS_FILE_TO_BROWSER (
        p_request_id IN NUMBER,
        p_file_name  IN VARCHAR2,
        p_username   IN VARCHAR2 DEFAULT NULL,
        p_password   IN VARCHAR2 DEFAULT NULL
    );

    -- Find the Report child ESS job spawned by the Import ESS job and
    -- insert it into DMT_ESS_JOB_TBL as a logical child of the import.
    -- Looks up the exact job definition from REPORT_JOB_DEF in
    -- DMT_ERP_INTERFACE_OPTIONS_TBL. CEMLIs without REPORT_JOB_DEF return NULL.
    -- Uses the pre-deployed DMT_ESS_CHILD_JOB_RPT.xdo with the exact P_JOB_DEF.
    -- Fusion doesn't model the report as a child (parentrequestid=0), but
    -- this procedure stores it with PARENT_REQUEST_ID = p_import_ess_id
    -- so the UI renders it in the correct hierarchy.
    -- Also enumerates the report job's output files into DMT_ESS_JOB_FILE_TBL.
    -- Non-blocking: logs and returns NULL on any failure.
    FUNCTION CAPTURE_REPORT_ESS_JOB (
        p_run_id IN NUMBER,
        p_import_ess_id  IN NUMBER,
        p_cemli_code     IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

END DMT_ESS_UTIL_PKG;
/
