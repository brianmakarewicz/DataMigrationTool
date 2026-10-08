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

    -- DMT_CONFIG_TBL key holding this DMT instance's HDL SourceSystemOwner
    -- (backlog #287). Seeded DMT_LOCAL on the Docker instance and DMT_ATP on ATP.
    C_SSO_CONFIG_KEY CONSTANT VARCHAR2(30) := 'HDL_SOURCE_SYSTEM_OWNER';

    -- --------------------------------------------------------
    -- GET_SOURCE_SYSTEM_OWNER: the SourceSystemOwner every HDL generator writes
    -- on every .dat line, read at run time from DMT_CONFIG_TBL
    -- (HDL_SOURCE_SYSTEM_OWNER). One owner per DMT instance, so SourceSystemIds
    -- written by different DMT databases (Docker, ATP, a --fresh rebuild) never
    -- collide in Fusion's HRC_INTEGRATION_KEY_MAP. The value must be an enabled
    -- code of Fusion's HRC_SOURCE_SYSTEM_OWNER lookup. Raises -20130 when the key
    -- is missing or blank (a generator must never write an empty owner).
    -- --------------------------------------------------------
    FUNCTION GET_SOURCE_SYSTEM_OWNER RETURN VARCHAR2;

    -- --------------------------------------------------------
    -- REST HTTP: execute a REST call (GET or POST with JSON body).
    -- Returns the response CLOB. Raises on non-2xx status.
    -- --------------------------------------------------------
    --   p_log_errors: when TRUE (default), a failed call writes an ERROR row to
    --     DMT_LOG_TBL before re-raising. POLL_HDL passes FALSE for its status GETs
    --     because it ALREADY handles a failed GET (it treats it as "data set not
    --     registered yet" and keeps polling) and logs its own INFO status line each
    --     tick. Otherwise the expected 404 on the first poll — the data set is not
    --     queryable the instant after createFileDataSet returns — would be recorded
    --     as a scary ERROR even though the next poll 30s later succeeds on the same
    --     URL (backlog #156). Every other caller keeps loud ERROR logging.
    -- Every routine below that reaches Fusion takes p_cemli_code: the HCM
    -- object's CEMLI code. The Fusion user comes from
    -- DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS(p_cemli_code) -- hcm_impl via the
    -- object's DMT_ERP_INTERFACE_OPTIONS_TBL row (backlog #309). A NULL
    -- p_cemli_code raises -20060 rather than silently using the default user.
    FUNCTION REST_HTTP (
        p_url              IN VARCHAR2,
        p_method           IN VARCHAR2 DEFAULT 'GET',    -- GET or POST
        p_body             IN CLOB     DEFAULT NULL,     -- JSON body for POST
        p_run_id   IN NUMBER   DEFAULT NULL,
        p_log_errors       IN BOOLEAN  DEFAULT TRUE,
        p_cemli_code       IN VARCHAR2 DEFAULT NULL   -- the object's CEMLI: picks its central Fusion user (backlog #309); required
    ) RETURN CLOB;

    -- --------------------------------------------------------
    -- UPLOAD_HDL: upload a ZIP file to Fusion UCM via HCM REST.
    -- Returns the UCM ContentId.
    -- --------------------------------------------------------
    FUNCTION UPLOAD_HDL (
        p_run_id IN NUMBER,
        p_hdl_zip        IN BLOB,
        p_filename       IN VARCHAR2,
        p_log_context    IN VARCHAR2 DEFAULT NULL,
        p_cemli_code       IN VARCHAR2 DEFAULT NULL   -- the object's CEMLI: picks its central Fusion user (backlog #309); required
    ) RETURN VARCHAR2;

    -- --------------------------------------------------------
    -- SUBMIT_HDL: trigger HCM Data Loader import via REST.
    -- Returns the HDL RequestId (data set ID).
    -- --------------------------------------------------------
    FUNCTION SUBMIT_HDL (
        p_run_id IN NUMBER,
        p_content_id     IN VARCHAR2,
        p_dataset_name   IN VARCHAR2 DEFAULT NULL,
        p_log_context    IN VARCHAR2 DEFAULT NULL,
        p_cemli_code       IN VARCHAR2 DEFAULT NULL   -- the object's CEMLI: picks its central Fusion user (backlog #309); required
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
        x_dataset_status  OUT VARCHAR2,  -- ORA_COMPLETED / ORA_IN_ERROR / ORA_STOPPED / EXPIRED
        p_cemli_code       IN VARCHAR2 DEFAULT NULL   -- the object's CEMLI: picks its central Fusion user (backlog #309); required
    );

    -- --------------------------------------------------------
    -- STAGE_HDL_MESSAGES (backlog #288): read EVERY page of the data set's
    -- messages (GET .../dataLoadDataSets/{RequestId}/child/messages, following
    -- hasMore until Fusion says there are no more) and stage each ERROR message
    -- (MessageTypeCode ERROR, or no type) in the session table
    -- DMT_HDL_MESSAGE_GTT, keyed by the request id, with its SourceSystemId,
    -- .dat file, file line and the named error text from FORMAT_HDL_ERROR.
    -- Replaces the request's earlier rows, so it is safe to call again (the base
    -- lag retry). Touches no TFM or STG table: each object's results package
    -- applies the staged rows to its own TFM tables with static SQL, matching the
    -- exact SourceSystemId its generator wrote. Static SQL only.
    -- x_message_count = the number of error messages staged.
    -- --------------------------------------------------------
    PROCEDURE STAGE_HDL_MESSAGES (
        p_run_id         IN  NUMBER,
        p_request_id     IN  VARCHAR2,
        p_log_context    IN  VARCHAR2 DEFAULT NULL,
        x_message_count  OUT NUMBER,
        p_cemli_code       IN VARCHAR2 DEFAULT NULL   -- the object's CEMLI: picks its central Fusion user (backlog #309); required
    );

    -- --------------------------------------------------------
    -- FORMAT_HDL_ERROR (backlog #288): name the record a Fusion HDL message is
    -- about. Returns
    --   [FUSION_ERROR] <SourceSystemId> (<file> line <n>): <message>
    -- dropping ' line <n>' when there is no file line, the parenthesis when there
    -- is no file, and the id when there is no SourceSystemId (file-level
    -- messages read '<file> line <n>: <message>' or '<file>: <message>'). The
    -- message text is Fusion's own, verbatim. NULL message -> NULL. Pure.
    -- --------------------------------------------------------
    FUNCTION FORMAT_HDL_ERROR (
        p_source_system_id IN VARCHAR2,
        p_dat_file_name    IN VARCHAR2,
        p_file_line        IN NUMBER,
        p_message_text     IN VARCHAR2
    ) RETURN VARCHAR2 DETERMINISTIC;

    -- --------------------------------------------------------
    -- ROW_ERRORS (backlog #288): the staged, named error text of every message
    -- whose SourceSystemId EQUALS p_source_system_id (or p_source_system_id_2,
    -- for a TFM row that carries two HDL records, e.g. WorkTerms + Assignment),
    -- joined with ' | ' in file-line order. NULL when there is none. Exact
    -- equality only: never LIKE, never a prefix. Read-only on the session table.
    -- --------------------------------------------------------
    FUNCTION ROW_ERRORS (
        p_request_id         IN VARCHAR2,
        p_source_system_id   IN VARCHAR2,
        p_source_system_id_2 IN VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2;

    -- --------------------------------------------------------
    -- FILE_LEVEL_ERRORS (backlog #288): the staged, named error text of every
    -- message that names no record (no SourceSystemId) and is about the given
    -- .dat file or about the whole data set (no file), joined with ' | '. These
    -- are whole-file rejections (an invalid METADATA line, an unknown file name):
    -- the results package applies them to the rows of that file still open after
    -- the per-record messages and the base-table proof. NULL when there is none.
    -- --------------------------------------------------------
    FUNCTION FILE_LEVEL_ERRORS (
        p_request_id    IN VARCHAR2,
        p_dat_file_name IN VARCHAR2
    ) RETURN VARCHAR2;

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
        p_log_context    IN VARCHAR2 DEFAULT NULL,
        p_cemli_code       IN VARCHAR2 DEFAULT NULL   -- the object's CEMLI: picks its central Fusion user (backlog #309); required
    );

END DMT_HDL_UTIL_PKG;
/
