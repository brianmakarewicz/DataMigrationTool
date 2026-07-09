-- PACKAGE DMT_BIP_DEPLOY_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_BIP_DEPLOY_PKG" AS
-- ============================================================
-- DMT_BIP_DEPLOY_PKG
-- Runs a BIP data model against Fusion and returns XML data,
-- using the BIP v2 SOAP session API (SecurityService +
-- CatalogService + ReportService) from ATP via UTL_HTTP.
--
-- Approach (ephemeral session objects):
--   1. GET_SESSION_TOKEN  — login via SecurityService
--   2. CREATE_DM          — createObjectInSession (CatalogService)
--                           stores XDM in /~username personal folder
--   3. RUN_DM             — runDataModelInSession (ReportService)
--                           returns XML CLOB
--   4. DELETE_DM          — deleteObjectInSession (CatalogService)
--                           cleanup; always called even on error
--
-- No persistent BIP catalog objects are created.
-- Auth:   credentials in SOAP body for login; session token
--         in subsequent SOAP calls — no Authorization header.
-- ============================================================

    -- --------------------------------------------------------
    -- GET_SESSION_TOKEN
    -- Login to BIP via SecurityService.
    -- Returns the bipSessionToken string.
    -- Raises -20050 if login fails or token is not returned.
    -- --------------------------------------------------------
    FUNCTION GET_SESSION_TOKEN RETURN VARCHAR2;

    -- --------------------------------------------------------
    -- CREATE_DM
    -- Upload a data model (XDM XML) to the BIP personal folder
    -- (/~username) via CatalogService createObjectInSession.
    -- p_xdm_name: filename without extension (e.g. 'DMT_POC')
    -- p_xdm_xml:  the raw XML content of the .xdm file
    -- --------------------------------------------------------
    PROCEDURE CREATE_DM (
        p_session_token IN VARCHAR2,
        p_xdm_name      IN VARCHAR2,
        p_xdm_xml       IN CLOB
    );

    -- --------------------------------------------------------
    -- RUN_DM
    -- Execute a data model in the BIP personal folder via
    -- ReportService runDataModelInSession.
    -- Returns the full SOAP response CLOB (contains reportBytes).
    -- --------------------------------------------------------
    FUNCTION RUN_DM (
        p_session_token IN VARCHAR2,
        p_xdm_name      IN VARCHAR2
    ) RETURN CLOB;

    -- --------------------------------------------------------
    -- DELETE_DM
    -- Remove a data model from the BIP personal folder via
    -- CatalogService deleteObjectInSession.
    -- Errors are swallowed — safe to call in a FINALLY block.
    -- --------------------------------------------------------
    PROCEDURE DELETE_DM (
        p_session_token IN VARCHAR2,
        p_xdm_name      IN VARCHAR2
    );

    -- --------------------------------------------------------
    -- RUN_DATA_MODEL
    -- Convenience wrapper: login, create DM, run it, delete it.
    -- Returns the raw XML CLOB from runDataModelInSession.
    -- Always deletes the DM even if RUN_DM raises an error.
    -- Raises on login, create, or run failure.
    -- --------------------------------------------------------
    FUNCTION RUN_DATA_MODEL (
        p_xdm_name      IN VARCHAR2,
        p_xdm_xml       IN CLOB,
        p_run_id IN NUMBER DEFAULT NULL
    ) RETURN CLOB;

    -- --------------------------------------------------------
    -- Persistent catalog deployment (Stage D, 2026-07-08).
    -- This stack's BIP catalog root is /Custom/DMT2 — every
    -- DEPLOY_*/DELETE_* below raises -20055 if the target is not
    -- under it, protecting the frozen stack's /Custom/DMT catalog
    -- (reading/running its reports is allowed; writing never is).
    -- --------------------------------------------------------
    C_CATALOG_ROOT CONSTANT VARCHAR2(20) := '/Custom/DMT2';

    -- --------------------------------------------------------
    -- DEPLOY_CATALOG_OBJECT
    -- Create (or overwrite) a persistent object in the BIP
    -- catalog via CatalogService createObjectInSession.
    -- p_object_type: 'xdm' (data model) or 'xdo' (report).
    -- Raises -20053 on SOAP Fault, -20055 on a folder outside
    -- C_CATALOG_ROOT.
    -- --------------------------------------------------------
    PROCEDURE DEPLOY_CATALOG_OBJECT (
        p_session_token IN VARCHAR2,
        p_folder        IN VARCHAR2,
        p_object_name   IN VARCHAR2,
        p_object_type   IN VARCHAR2,
        p_object_data   IN CLOB
    );

    -- --------------------------------------------------------
    -- DELETE_CATALOG_OBJECT
    -- Delete a persistent catalog object (absolute path incl.
    -- extension). SOAP errors are swallowed (object may not
    -- exist) but the -20055 folder guard still applies.
    -- --------------------------------------------------------
    PROCEDURE DELETE_CATALOG_OBJECT (
        p_session_token IN VARCHAR2,
        p_object_path   IN VARCHAR2
    );

    -- --------------------------------------------------------
    -- DEPLOY_RECON_REPORT
    -- Convenience wrapper for one reconciliation report pair:
    -- login, delete any existing DM + report in p_folder, deploy
    -- the data model (p_xdm_xml), then deploy a generated
    -- XML-output report wrapper (.xdo) linked to it.
    -- p_folder e.g. '/Custom/DMT2/Suppliers' (folder guard
    -- applies); p_dm_name/p_rpt_name without extension.
    -- --------------------------------------------------------
    PROCEDURE DEPLOY_RECON_REPORT (
        p_folder   IN VARCHAR2,
        p_dm_name  IN VARCHAR2,
        p_rpt_name IN VARCHAR2,
        p_xdm_xml  IN CLOB
    );

    -- --------------------------------------------------------
    -- RUN_POC_TEST
    -- End-to-end connectivity test.
    -- Creates a simple supplier-count data model in the BIP
    -- personal folder, runs it, logs the first 500 chars of
    -- the XML response, then deletes the DM.
    -- No production data is written. Safe to re-run.
    -- --------------------------------------------------------
    PROCEDURE RUN_POC_TEST (
        p_run_id IN NUMBER DEFAULT NULL
    );

END DMT_BIP_DEPLOY_PKG;
/
