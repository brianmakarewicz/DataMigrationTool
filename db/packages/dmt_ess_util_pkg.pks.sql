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
-- DOWNLOAD_ESS_FILE: Calls downloadESSJobExecutionDetails SOAP
--   to fetch log/output files on demand. Returns CLOB.
-- ============================================================

    -- Capture the full ESS job hierarchy (parent + all descendants)
    -- into DMT_ESS_JOB_TBL. Call after POLL_ESS_JOB reaches terminal status.
    PROCEDURE CAPTURE_ESS_HIERARCHY (
        p_run_id   IN NUMBER,
        p_parent_request_id IN NUMBER,
        p_cemli_code       IN VARCHAR2 DEFAULT NULL
    );

    -- Download ESS job output/log file from Fusion (CLOB — legacy, loses binary).
    FUNCTION DOWNLOAD_ESS_FILE (
        p_request_id IN NUMBER,
        p_file_type  IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB;

    -- Download ESS output as BLOB (binary-safe, handles MTOM).
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
    FUNCTION GET_ESS_OUTPUT_TEXT (
        p_request_id IN NUMBER,
        p_file_type  IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB;

    -- Download ESS output ZIP, extract the BIP XML report, return as CLOB.
    -- Use for Import Report error parsing (e.g. ImportProjectReportJob output).
    FUNCTION GET_ESS_OUTPUT_XML (
        p_request_id IN NUMBER
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
    PROCEDURE ENUMERATE_ESS_FILES (
        p_ess_job_id   IN NUMBER,
        p_request_id   IN NUMBER,
        p_username     IN VARCHAR2 DEFAULT NULL,
        p_password     IN VARCHAR2 DEFAULT NULL
    );

    -- Enumerate files for ALL child jobs of an integration run.
    -- Called after CAPTURE_ESS_HIERARCHY to populate DMT_ESS_JOB_FILE_TBL.
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
