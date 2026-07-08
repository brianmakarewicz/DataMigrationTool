-- PACKAGE DMT_HDL_UTIL_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_HDL_UTIL_PKG" AS
-- ============================================================
-- DMT_HDL_UTIL_PKG — HCM Data Loader Utilities
-- ============================================================
-- Mirrors DMT_LOADER_PKG FBDI pattern but uses REST API for HCM.
-- Pipeline: DAT generation → ZIP → REST upload → REST submit
--           → REST poll → REST error retrieval → update STG/TFM.
--
-- REST endpoints (HCM Data Loader):
--   Upload:  POST /hcmRestApi/resources/11.13.18.05/dataLoadDataSets/action/uploadFile
--   Submit:  POST /hcmRestApi/resources/11.13.18.05/dataLoadDataSets/action/createFileDataSet
--   Status:  GET  /hcmRestApi/resources/11.13.18.05/dataLoadDataSets/{RequestId}
--   Errors:  GET  /hcmRestApi/resources/11.13.18.05/dataLoadDataSets/{RequestId}/child/messages
-- ============================================================

    C_PKG CONSTANT VARCHAR2(30) := 'DMT_HDL_UTIL_PKG';

    -- HCM REST API version path (may change with Fusion updates)
    C_HCM_REST_PATH CONSTANT VARCHAR2(100) := 'hcmRestApi/resources/11.13.18.05/dataLoadDataSets';

    -- --------------------------------------------------------
    -- REST HTTP: execute a REST call (GET or POST with JSON body).
    -- Returns the response CLOB. Raises on non-2xx status.
    -- --------------------------------------------------------
    FUNCTION REST_HTTP (
        p_url              IN VARCHAR2,
        p_method           IN VARCHAR2 DEFAULT 'GET',    -- GET or POST
        p_body             IN CLOB     DEFAULT NULL,     -- JSON body for POST
        p_run_id   IN NUMBER   DEFAULT NULL
    ) RETURN CLOB;

    -- --------------------------------------------------------
    -- UPLOAD_HDL: upload a ZIP file to Fusion UCM via HCM REST.
    -- Returns the UCM ContentId.
    -- --------------------------------------------------------
    FUNCTION UPLOAD_HDL (
        p_run_id IN NUMBER,
        p_hdl_zip        IN BLOB,
        p_filename       IN VARCHAR2,
        p_log_context    IN VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2;

    -- --------------------------------------------------------
    -- SUBMIT_HDL: trigger HCM Data Loader import via REST.
    -- Returns the HDL RequestId (data set ID).
    -- --------------------------------------------------------
    FUNCTION SUBMIT_HDL (
        p_run_id IN NUMBER,
        p_content_id     IN VARCHAR2,
        p_dataset_name   IN VARCHAR2 DEFAULT NULL,
        p_log_context    IN VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2;

    -- --------------------------------------------------------
    -- POLL_HDL: poll HCM Data Loader status until terminal state.
    -- Terminal states: ORA_COMPLETED, ORA_IN_ERROR, ORA_STOPPED.
    -- --------------------------------------------------------
    PROCEDURE POLL_HDL (
        p_run_id  IN NUMBER,
        p_request_id      IN VARCHAR2,
        p_timeout_sec     IN NUMBER   DEFAULT 1800,
        p_raise_on_error  IN BOOLEAN  DEFAULT FALSE,
        p_log_context     IN VARCHAR2 DEFAULT NULL,
        x_dataset_status  OUT VARCHAR2   -- ORA_COMPLETED / ORA_IN_ERROR / ORA_STOPPED / EXPIRED
    );

    -- --------------------------------------------------------
    -- GET_HDL_ERRORS: retrieve error messages from HCM Data Loader.
    -- Returns JSON CLOB of messages.
    -- --------------------------------------------------------
    FUNCTION GET_HDL_ERRORS (
        p_run_id IN NUMBER,
        p_request_id     IN VARCHAR2,
        p_log_context    IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB;

    -- --------------------------------------------------------
    -- RECONCILE_HDL: parse HDL error messages and update TFM/STG.
    -- Called by each HCM object's results package.
    -- p_stg_table / p_tfm_table: names of the staging/TFM tables.
    -- p_key_column: column in TFM that matches HDL SourceReference001.
    -- --------------------------------------------------------
    PROCEDURE RECONCILE_HDL (
        p_run_id  IN NUMBER,
        p_request_id      IN VARCHAR2,
        p_tfm_table       IN VARCHAR2,
        p_stg_table       IN VARCHAR2,
        p_key_column      IN VARCHAR2 DEFAULT 'SOURCE_REF',
        p_dataset_status  IN VARCHAR2 DEFAULT NULL,  -- ORA_COMPLETED / ORA_IN_ERROR from POLL_HDL
        p_log_context     IN VARCHAR2 DEFAULT NULL
    );

    -- --------------------------------------------------------
    -- BUILD_DAT_HEADER: build a METADATA| header line for a DAT file.
    -- p_business_object: e.g. 'Worker', 'PersonName', 'Grade'
    -- p_columns: pipe-delimited column list (e.g. 'EffectiveStartDate|PersonNumber|...')
    -- Returns: 'METADATA|Worker|EffectiveStartDate|PersonNumber|...' || CHR(10)
    -- --------------------------------------------------------
    FUNCTION BUILD_DAT_HEADER (
        p_business_object IN VARCHAR2,
        p_columns         IN VARCHAR2    -- pipe-delimited column names
    ) RETURN VARCHAR2;

    -- --------------------------------------------------------
    -- APPEND_DAT_LINE: append a MERGE| data line to a DAT CLOB.
    -- p_values: pipe-delimited values (caller builds from TFM row).
    -- p_discriminator: file discriminator / component name (e.g. Worker, PersonName).
    -- Appends: 'MERGE|discriminator|val1|val2|...' || CHR(10)
    -- --------------------------------------------------------
    PROCEDURE APPEND_DAT_LINE (
        p_clob          IN OUT NOCOPY CLOB,
        p_values        IN VARCHAR2,
        p_action        IN VARCHAR2 DEFAULT 'MERGE',    -- MERGE or DELETE
        p_discriminator IN VARCHAR2 DEFAULT NULL         -- HDL file discriminator
    );

    -- --------------------------------------------------------
    -- LOOKUP_FUSION_IDS: post-reconciliation HCM REST lookup.
    -- For each LOADED row in the relevant TFM table that has
    -- a NULL Fusion ID column, queries the HCM workers REST
    -- endpoint and populates the Fusion-assigned ID.
    -- p_object_type: 'Worker', 'Assignment', or 'Salary'.
    -- --------------------------------------------------------
    PROCEDURE LOOKUP_FUSION_IDS (
        p_run_id IN NUMBER,
        p_object_type    IN VARCHAR2,   -- 'Worker', 'Assignment', 'Salary'
        p_log_context    IN VARCHAR2 DEFAULT NULL
    );

END DMT_HDL_UTIL_PKG;
/
