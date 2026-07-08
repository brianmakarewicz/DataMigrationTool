-- PACKAGE DMT_BIP_SETUP_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_BIP_SETUP_PKG" AS
-- ============================================================
-- DMT_BIP_SETUP_PKG
-- One-time admin utility for creating and testing BIP objects
-- in Fusion BI Publisher from ATP via UTL_HTTP.
--
-- Uses BIP v2 SOAP session API:
--   SecurityService  — login / get session token
--   CatalogService   — createObjectInSession / deleteObjectInSession
--   ReportService    — runDataModelInSession / runReport
--
-- This package is NOT called during the normal conversion run.
-- Use it to:
--   1. Verify the BIP v2 SOAP channel works from ATP
--   2. Test data model XML before deploying permanently
--   3. Confirm a data model returns the expected output
--
-- For the normal workflow, BIP objects are deployed once via
-- this package and then called directly by path (e.g. from
-- DMT_POZ_SUP_RESULTS_PKG).
-- ============================================================

    -- --------------------------------------------------------
    -- GET_SESSION_TOKEN
    -- Login to BIP via SecurityService.
    -- Returns the bipSessionToken string.
    -- Raises -20050 if login fails or no token is returned.
    -- --------------------------------------------------------
    FUNCTION GET_SESSION_TOKEN RETURN VARCHAR2;

    -- --------------------------------------------------------
    -- CREATE_DM
    -- Upload a data model (XDM XML) to the BIP personal folder
    -- (/~username) via CatalogService createObjectInSession.
    --
    -- p_session_token : from GET_SESSION_TOKEN
    -- p_xdm_name      : filename without extension (e.g. 'DMT_POC_DM')
    -- p_xdm_xml       : raw XML content of the .xdm file
    -- --------------------------------------------------------
    PROCEDURE CREATE_DM (
        p_session_token IN VARCHAR2,
        p_xdm_name      IN VARCHAR2,
        p_xdm_xml       IN CLOB
    );

    -- --------------------------------------------------------
    -- RUN_DM
    -- Execute a data model from the BIP personal folder via
    -- ReportService runDataModelInSession.
    -- Returns the full SOAP response CLOB.
    -- Extract data with: REGEXP_SUBSTR(resp, '<reportBytes>(.*?)</reportBytes>',1,1,NULL,1)
    -- then base64-decode to get the XML dataset.
    -- --------------------------------------------------------
    FUNCTION RUN_DM (
        p_session_token IN VARCHAR2,
        p_xdm_name      IN VARCHAR2
    ) RETURN CLOB;

    -- --------------------------------------------------------
    -- DELETE_DM
    -- Remove a data model (.xdm) from the BIP personal folder.
    -- All errors are swallowed — safe to call in a finally block.
    -- --------------------------------------------------------
    PROCEDURE DELETE_DM (
        p_session_token IN VARCHAR2,
        p_xdm_name      IN VARCHAR2
    );

    -- --------------------------------------------------------
    -- CREATE_RPT
    -- Upload a report definition (.xdo) to the BIP personal
    -- folder via CatalogService createObjectInSession.
    -- The report references a data model by its full catalog path.
    --
    -- p_session_token : from GET_SESSION_TOKEN
    -- p_rpt_name      : filename without extension (e.g. 'DMT_POC_RPT')
    -- p_dm_path       : full catalog path to the XDM file
    --                   e.g. '/~fin_impl/DMT_POC_DM.xdm'
    -- --------------------------------------------------------
    PROCEDURE CREATE_RPT (
        p_session_token IN VARCHAR2,
        p_rpt_name      IN VARCHAR2,
        p_dm_path       IN VARCHAR2
    );

    -- --------------------------------------------------------
    -- RUN_RPT
    -- Run a report (.xdo) from the BIP personal folder via
    -- ReportService runReport.
    -- Unlike the session operations, runReport authenticates with
    -- userID/password (from DMT_CONFIG_TBL) rather than a session token.
    -- Returns the full SOAP response CLOB (reportBytes = base64 XML).
    -- Raises -20054 if a SOAP Fault is returned.
    -- --------------------------------------------------------
    FUNCTION RUN_RPT (
        p_rpt_name IN VARCHAR2
    ) RETURN CLOB;

    -- --------------------------------------------------------
    -- DELETE_RPT
    -- Remove a report definition (.xdo) from the BIP personal folder.
    -- All errors are swallowed — safe to call in a finally block.
    -- --------------------------------------------------------
    PROCEDURE DELETE_RPT (
        p_session_token IN VARCHAR2,
        p_rpt_name      IN VARCHAR2
    );

    -- --------------------------------------------------------
    -- RUN_POC_TEST
    -- End-to-end connectivity test — data model + report pipeline.
    -- 1. Logs in to get a session token
    -- 2. Cleans up any objects left from a previous run
    -- 3. Creates DMT_POC_DM.xdm in /~username (2 cols, 2 rows, DUAL)
    -- 4. Creates DMT_POC_RPT.xdo in /~username referencing the DM
    -- 5. Runs the report and logs the response preview
    -- Objects are NOT deleted — browse them in the BIP UI after running.
    -- Safe to re-run; cleanup step handles existing objects.
    -- --------------------------------------------------------
    PROCEDURE RUN_POC_TEST (
        p_run_id IN NUMBER DEFAULT NULL
    );

END DMT_BIP_SETUP_PKG;
/
