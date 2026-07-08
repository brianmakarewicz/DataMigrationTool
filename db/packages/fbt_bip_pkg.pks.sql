-- PACKAGE FBT_BIP_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "FBT_BIP_PKG" AS
-- ============================================================
-- FBT_BIP_PKG â€” Fusion BIP Toolkit
-- Standalone PL/SQL package for managing BIP data models and
-- reports on Oracle Fusion via BIP v2 SOAP from ATP (UTL_HTTP).
--
-- No config table dependency. All connection params are passed
-- as arguments. Callers own their config.
--
-- BIP v2 SOAP endpoints used:
--   SecurityService  â€” login (session token)
--   CatalogService   â€” createObjectInSession / deleteObjectInSession
--   ReportService    â€” runDataModelInSession / runReport
--
-- No Authorization header on any call. Credentials go in the
-- SecurityService SOAP body; all subsequent calls use the
-- returned bipSessionToken.
-- ============================================================

    -- --------------------------------------------------------
    -- Parameter types
    -- Used to pass BIP data model parameters to DEPLOY_DATA_MODEL
    -- and BUILD_PARAMS_XML without building the XML manually.
    -- --------------------------------------------------------
    TYPE fbt_param_t IS RECORD (
        name      VARCHAR2(100),
        label     VARCHAR2(200),
        data_type VARCHAR2(50)
    );
    TYPE fbt_param_tab_t IS TABLE OF fbt_param_t INDEX BY PLS_INTEGER;

    -- --------------------------------------------------------
    -- GET_SESSION_TOKEN
    -- Login to BIP via SecurityService.
    -- Returns the bipSessionToken string.
    -- Raises -20001 if login fails or no token is returned.
    -- --------------------------------------------------------
    FUNCTION GET_SESSION_TOKEN (
        p_base_url IN VARCHAR2,
        p_username IN VARCHAR2,
        p_password IN VARCHAR2
    ) RETURN VARCHAR2;

    -- --------------------------------------------------------
    -- DEPLOY_DATA_MODEL
    -- Upload an XDM data model to the BIP catalog (persistent).
    -- p_folder: BIP folder path, e.g. '/~calvin.roth'.
    --           Required â€” raises -20009 if NULL.
    -- --------------------------------------------------------
    PROCEDURE DEPLOY_DATA_MODEL (
        p_session_token IN VARCHAR2,
        p_base_url      IN VARCHAR2,
        p_name          IN VARCHAR2,
        p_xdm_xml       IN CLOB,
        p_folder        IN VARCHAR2 DEFAULT NULL
    );

    -- --------------------------------------------------------
    -- BUILD_PARAMS_XML
    -- Build the <parameters>...</parameters> XML block from a
    -- collection of fbt_param_t records.
    -- Each entry produces:
    --   <parameter name="..." dataType="..." rowPlacement="N">
    --     <input label="..."/>
    --   </parameter>
    -- data_type defaults to 'xsd:string' if NULL.
    -- label defaults to name if NULL.
    -- --------------------------------------------------------
    FUNCTION BUILD_PARAMS_XML (
        p_params IN fbt_param_tab_t
    ) RETURN CLOB;

    -- --------------------------------------------------------
    -- DEPLOY_DATA_MODEL (params overload)
    -- Same as DEPLOY_DATA_MODEL above, but accepts a collection
    -- of parameters. Replaces <parameters/> in p_xdm_xml with
    -- the built parameters block before deploying.
    -- Pass an empty collection (fbt_param_tab_t()) to skip.
    -- --------------------------------------------------------
    PROCEDURE DEPLOY_DATA_MODEL (
        p_session_token IN VARCHAR2,
        p_base_url      IN VARCHAR2,
        p_name          IN VARCHAR2,
        p_xdm_xml       IN CLOB,
        p_folder        IN VARCHAR2      DEFAULT NULL,
        p_params        IN fbt_param_tab_t
    );

    -- --------------------------------------------------------
    -- TEST_DATA_MODEL
    -- Run a deployed data model; return the XML CLOB.
    -- Does NOT delete the data model after running.
    -- p_folder: BIP folder path. Required â€” raises -20009 if NULL.
    -- --------------------------------------------------------
    FUNCTION TEST_DATA_MODEL (
        p_session_token IN VARCHAR2,
        p_base_url      IN VARCHAR2,
        p_name          IN VARCHAR2,
        p_folder        IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB;

    -- --------------------------------------------------------
    -- DELETE_DATA_MODEL
    -- Remove a data model (.xdm) from the BIP catalog.
    -- All errors swallowed â€” safe to call in cleanup blocks.
    -- p_folder: BIP folder path. Required â€” raises -20009 if NULL.
    -- --------------------------------------------------------
    PROCEDURE DELETE_DATA_MODEL (
        p_session_token IN VARCHAR2,
        p_base_url      IN VARCHAR2,
        p_name          IN VARCHAR2,
        p_folder        IN VARCHAR2 DEFAULT NULL
    );

    -- --------------------------------------------------------
    -- RUN_DATA_MODEL_EPHEMERAL
    -- Fire-and-forget: login, create DM in /~p_username,
    -- run it, delete it. DELETE always runs even on failure.
    -- Returns the raw XML CLOB from runDataModelInSession.
    -- Raises on login, create, or run failure.
    -- --------------------------------------------------------
    FUNCTION RUN_DATA_MODEL_EPHEMERAL (
        p_base_url IN VARCHAR2,
        p_username IN VARCHAR2,
        p_password IN VARCHAR2,
        p_xdm_xml  IN CLOB,
        p_name     IN VARCHAR2 DEFAULT 'FBT_EPHEMERAL'
    ) RETURN CLOB;

    -- --------------------------------------------------------
    -- DEPLOY_REPORT
    -- Upload a report definition (.xdo) to the BIP catalog.
    -- p_dm_path: full catalog path to the XDM referenced by
    --            this report, e.g. '/~calvin.roth/MyDM.xdm'.
    -- p_folder:  BIP folder for the report. Required if NULL.
    -- --------------------------------------------------------
    PROCEDURE DEPLOY_REPORT (
        p_session_token IN VARCHAR2,
        p_base_url      IN VARCHAR2,
        p_name          IN VARCHAR2,
        p_dm_path       IN VARCHAR2,
        p_folder        IN VARCHAR2 DEFAULT NULL
    );

    -- --------------------------------------------------------
    -- DEPLOY_TEMPLATE
    -- Attach a layout template (.rtf or .xsl) to a deployed
    -- report. The template is stored as a sub-object of the
    -- report in the BIP catalog.
    -- p_report_path:  full path to the .xdo report, e.g.
    --                 '/~calvin.roth/MyReport.xdo'.
    -- p_template_name: name without extension.
    -- p_template_data: raw template content (CLOB).
    -- p_template_type: 'rtf' or 'xsl' (default 'rtf').
    -- --------------------------------------------------------
    PROCEDURE DEPLOY_TEMPLATE (
        p_session_token IN VARCHAR2,
        p_base_url      IN VARCHAR2,
        p_report_path   IN VARCHAR2,
        p_template_name IN VARCHAR2,
        p_template_data IN CLOB,
        p_template_type IN VARCHAR2 DEFAULT 'rtf'
    );

    -- --------------------------------------------------------
    -- RUN_REPORT
    -- Execute a deployed report via ReportService runReport.
    -- runReport authenticates with userID/password (not session
    -- token). Returns the full SOAP response CLOB.
    -- p_report_path: full catalog path to the .xdo report.
    -- --------------------------------------------------------
    FUNCTION RUN_REPORT (
        p_base_url    IN VARCHAR2,
        p_username    IN VARCHAR2,
        p_password    IN VARCHAR2,
        p_report_path IN VARCHAR2
    ) RETURN CLOB;

    -- --------------------------------------------------------
    -- DELETE_REPORT
    -- Remove a report definition (.xdo) from the BIP catalog.
    -- All errors swallowed â€” safe to call in cleanup blocks.
    -- p_folder: BIP folder path. Required â€” raises -20009 if NULL.
    -- --------------------------------------------------------
    PROCEDURE DELETE_REPORT (
        p_session_token IN VARCHAR2,
        p_base_url      IN VARCHAR2,
        p_name          IN VARCHAR2,
        p_folder        IN VARCHAR2 DEFAULT NULL
    );

    -- --------------------------------------------------------
    -- GET_TEMPLATE
    -- Download a layout template from a deployed report via
    -- ReportService.getTemplateInSession.
    -- p_report_path: full catalog path to the .xdo report.
    -- p_template_id: template name/ID (e.g. 'default').
    -- p_locale:      locale string (default 'en-US').
    -- Returns the raw template as a BLOB.
    -- Raises -20007 on SOAP fault.
    -- --------------------------------------------------------
    FUNCTION GET_TEMPLATE (
        p_session_token IN VARCHAR2,
        p_base_url      IN VARCHAR2,
        p_report_path   IN VARCHAR2,
        p_template_id   IN VARCHAR2,
        p_locale        IN VARCHAR2 DEFAULT 'en-US'
    ) RETURN BLOB;

    -- --------------------------------------------------------
    -- CREATE_REPORT_WITH_TEMPLATE
    -- Create a report and upload its layout template in one
    -- call via ReportService.createReportInSession.
    -- p_name:           report name without extension.
    -- p_folder:         target catalog folder.
    -- p_dm_path:        full catalog path to the .xdm.
    -- p_template_name:  template filename with extension
    --                   (e.g. 'default.rtf').
    -- p_template_data:  raw binary template (BLOB).
    -- p_update_existing: 'true' to overwrite if report exists.
    -- Returns the full catalog path of the created report.
    -- Raises -20008 on SOAP fault.
    -- --------------------------------------------------------
    FUNCTION CREATE_REPORT_WITH_TEMPLATE (
        p_session_token   IN VARCHAR2,
        p_base_url        IN VARCHAR2,
        p_name            IN VARCHAR2,
        p_folder          IN VARCHAR2,
        p_dm_path         IN VARCHAR2,
        p_template_name   IN VARCHAR2,
        p_template_data   IN BLOB,
        p_update_existing IN VARCHAR2 DEFAULT 'false'
    ) RETURN VARCHAR2;

    -- --------------------------------------------------------
    -- UPLOAD_TEMPLATE_FOR_REPORT
    -- Upload or replace a layout template on an existing report
    -- via ReportService.uploadTemplateForReportInSession.
    -- p_report_path:  full catalog path to the .xdo report.
    -- p_template_name: template name (without extension).
    -- p_template_type: 'rtf', 'xsl', etc.
    -- p_locale:        locale string (default 'en-US').
    -- p_template_data: raw binary template (BLOB).
    -- Raises -20010 on SOAP fault.
    -- --------------------------------------------------------
    PROCEDURE UPLOAD_TEMPLATE_FOR_REPORT (
        p_session_token IN VARCHAR2,
        p_base_url      IN VARCHAR2,
        p_report_path   IN VARCHAR2,
        p_template_name IN VARCHAR2,
        p_template_type IN VARCHAR2,
        p_locale        IN VARCHAR2 DEFAULT 'en-US',
        p_template_data IN BLOB
    );

    -- --------------------------------------------------------
    -- GET_CATALOG_OBJECT (session-token overload)
    -- Download any catalog object from BIP by its absolute path.
    -- Uses CatalogService.getObjectInSession.
    -- Returns the decoded content as a CLOB (UTF-8 text).
    -- Suitable for .xdm, .xdo, and other XML catalog objects.
    -- p_object_path: full catalog path including extension,
    --                e.g. '/Custom/DMT/POC1.xdm'.
    -- Raises -20011 on SOAP fault.
    -- --------------------------------------------------------
    FUNCTION GET_CATALOG_OBJECT (
        p_session_token IN VARCHAR2,
        p_base_url      IN VARCHAR2,
        p_object_path   IN VARCHAR2
    ) RETURN CLOB;

    -- --------------------------------------------------------
    -- PRINT_CATALOG_OBJECT
    -- Download a catalog object and print its content to
    -- DBMS_OUTPUT in 4000-char chunks.
    -- Call from SQL*Plus / APEX SQL Workshop â€” no script needed.
    --
    -- Example:
    --   SET SERVEROUTPUT ON SIZE UNLIMITED
    --   EXEC FBT_BIP_PKG.PRINT_CATALOG_OBJECT(
    --       'https://host', 'fin_impl', 'password',
    --       '/Custom/DMT/POC1.xdm');
    -- --------------------------------------------------------
    PROCEDURE PRINT_CATALOG_OBJECT (
        p_base_url    IN VARCHAR2,
        p_username    IN VARCHAR2,
        p_password    IN VARCHAR2,
        p_object_path IN VARCHAR2
    );

    -- --------------------------------------------------------
    -- RUN_POC_TEST
    -- End-to-end connectivity test.
    -- 1. Login to get a session token.
    -- 2. Clean up any FBT_POC_DM from a previous run.
    -- 3. Deploy a minimal data model (SELECT 1, 'Alpha' FROM DUAL).
    -- 4. Run it with TEST_DATA_MODEL; log response preview.
    -- Object is NOT deleted â€” inspect in BIP UI after running.
    -- Safe to re-run: step 2 handles leftover objects.
    -- Writes progress to DBMS_OUTPUT.
    -- --------------------------------------------------------
    PROCEDURE RUN_POC_TEST (
        p_base_url IN VARCHAR2,
        p_username IN VARCHAR2,
        p_password IN VARCHAR2
    );

    -- --------------------------------------------------------
    -- DOWNLOAD_CATALOG
    -- Download a single catalog object (report or data model)
    -- as a .catalog archive (ZIP) via
    -- CatalogService.downloadObjectInSession.
    -- p_object_path: full catalog path to a single object,
    --   e.g. '/POC/MyReport.xdo' or '/POC/MyDM.xdm'.
    -- Returns the raw ZIP binary as a BLOB. Save as
    -- .xdo.catalog or .xdm.catalog for manual import, or
    -- pass directly to UPLOAD_CATALOG for migration.
    -- Raises -20013 on SOAP fault.
    -- --------------------------------------------------------
    FUNCTION DOWNLOAD_CATALOG (
        p_session_token IN VARCHAR2,
        p_base_url      IN VARCHAR2,
        p_object_path   IN VARCHAR2
    ) RETURN BLOB;

    -- --------------------------------------------------------
    -- DOWNLOAD_CATALOG_FOLDER
    -- Download an entire BIP folder and all its contents as a
    -- single ZIP archive via CatalogService.downloadObjectInSession
    -- with objectType='folder'.
    -- p_folder_path: catalog folder path, e.g. '/POC' or
    --                '/Custom/DMT/Suppliers'.
    -- Returns the raw ZIP binary. Save as .xdrz for
    -- BIPCatalogUtil compatibility, or pass to UPLOAD_CATALOG.
    -- Raises -20013 on SOAP fault.
    -- --------------------------------------------------------
    FUNCTION DOWNLOAD_CATALOG_FOLDER (
        p_session_token IN VARCHAR2,
        p_base_url      IN VARCHAR2,
        p_folder_path   IN VARCHAR2
    ) RETURN BLOB;

    -- --------------------------------------------------------
    -- UPLOAD_CATALOG
    -- Upload a .catalog archive (ZIP) to a target BIP instance
    -- via CatalogService.uploadObjectInSession.
    -- p_object_path: target catalog path, e.g.
    --   '/Custom/Reports/MyReport.xdo' for a single object, or
    --   '/Custom/Reports' for a folder archive.
    -- p_object_type: 'xdo' (report), 'xdm' (data model),
    --   'xsb' (sub-template), 'xss' (style template),
    --   'xdr' (folder).
    -- p_catalog_data: the raw ZIP binary (from DOWNLOAD_CATALOG
    --   or DOWNLOAD_CATALOG_FOLDER).
    -- Raises -20014 on SOAP fault.
    -- --------------------------------------------------------
    PROCEDURE UPLOAD_CATALOG (
        p_session_token IN VARCHAR2,
        p_base_url      IN VARCHAR2,
        p_object_path   IN VARCHAR2,
        p_object_type   IN VARCHAR2,
        p_catalog_data  IN BLOB
    );

    -- --------------------------------------------------------
    -- Dataset types for BUILD_NESTED_XDM
    -- Represents one dataset (query) in a parent-child hierarchy.
    -- Chain them via parent_dataset_id for arbitrary nesting depth.
    -- --------------------------------------------------------
    TYPE fbt_dataset_t IS RECORD (
        dataset_id        PLS_INTEGER,        -- unique ID within this collection
        parent_dataset_id PLS_INTEGER,        -- NULL = root, else FK to another entry's dataset_id
        dataset_name      VARCHAR2(100),       -- e.g. 'HEADERS', 'LINES', 'DISTRIBUTIONS'
        group_name        VARCHAR2(30),        -- e.g. 'G_1', 'G_2', 'G_3'
        sql_text          VARCHAR2(32767),     -- the query (must use explicit column aliases)
        parent_join_column VARCHAR2(100),      -- join column in parent dataset (NULL for root)
        child_join_column  VARCHAR2(100)       -- join column in this dataset (NULL for root)
    );
    TYPE fbt_dataset_tab_t IS TABLE OF fbt_dataset_t INDEX BY PLS_INTEGER;

    -- --------------------------------------------------------
    -- BUILD_NESTED_XDM
    -- Build a complete XDM data model with arbitrarily nested
    -- parent-child groups from a collection of dataset definitions.
    --
    -- Column names and types are parsed from SQL aliases:
    --   _ID, _NUM, _AMOUNT, _TOTAL, _PRICE, _QTY -> xsd:double
    --   _DATE                                      -> xsd:date
    --   everything else                            -> xsd:string
    --
    -- The returned CLOB is a complete XDM ready to pass to
    -- DEPLOY_DATA_MODEL. Contains <parameters/> placeholder
    -- for optional parameter injection via the params overload.
    --
    -- p_datasets: collection of dataset definitions with parent-child links
    -- p_params:   optional parameter collection (same as DEPLOY_DATA_MODEL)
    -- --------------------------------------------------------
    FUNCTION BUILD_NESTED_XDM (
        p_datasets IN fbt_dataset_tab_t,
        p_params   IN fbt_param_tab_t DEFAULT fbt_param_tab_t()
    ) RETURN CLOB;

END FBT_BIP_PKG;
/
