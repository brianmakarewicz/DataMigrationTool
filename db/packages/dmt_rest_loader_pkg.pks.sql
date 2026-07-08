-- PACKAGE DMT_REST_LOADER_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_REST_LOADER_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_REST_LOADER_PKG
-- Shared infrastructure for REST API-based data loading into
-- Oracle Fusion Cloud.  Mirrors the FBDI pipeline pattern
-- (generate payload -> submit -> reconcile) but uses direct
-- REST POST/PATCH instead of UCM + ESS.
--
-- Consumers: Payment Terms, Tax Regimes/Rates, Banks/Branches/
-- Accounts, and any future object types that load via Fusion
-- REST rather than FBDI.
--
-- HTTP layer delegates to DMT_UTIL_PKG.HTTP_REQUEST for wallet,
-- timeout, and Basic auth.  All logging goes through
-- DMT_UTIL_PKG.LOG / LOG_ERROR.
-- ============================================================

    -- --------------------------------------------------------
    -- POST_TO_FUSION
    -- Make a REST POST to a Fusion endpoint with a JSON payload.
    -- p_endpoint is the relative path (e.g.
    --   '/fscmRestApi/resources/11.13.18.05/standardTerms').
    -- The base URL is resolved from DMT_CONFIG_TBL FUSION_URL.
    -- Returns the HTTP status code and the raw response body
    -- so the caller can decide how to handle non-2xx responses
    -- without an automatic raise.
    -- --------------------------------------------------------
    PROCEDURE POST_TO_FUSION (
        p_endpoint       IN  VARCHAR2,
        p_payload        IN  CLOB,
        p_run_id IN  NUMBER   DEFAULT NULL,
        p_object_type    IN  VARCHAR2 DEFAULT NULL,
        x_http_status    OUT NUMBER,
        x_response       OUT CLOB
    );

    -- --------------------------------------------------------
    -- PATCH_FUSION
    -- Make a REST PATCH to update an existing Fusion resource.
    -- p_resource_id is appended to p_endpoint to form the full
    -- resource URL (e.g. endpoint + '/' + resource_id).
    -- --------------------------------------------------------
    PROCEDURE PATCH_FUSION (
        p_endpoint       IN  VARCHAR2,
        p_payload        IN  CLOB,
        p_resource_id    IN  VARCHAR2,
        p_run_id IN  NUMBER   DEFAULT NULL,
        p_object_type    IN  VARCHAR2 DEFAULT NULL,
        x_http_status    OUT NUMBER,
        x_response       OUT CLOB
    );

    -- --------------------------------------------------------
    -- PARSE_REST_RESPONSE
    -- Parse a Fusion REST response to determine success/failure
    -- and extract the Fusion-assigned ID.
    -- HTTP 200/201 = success; extracts the ID from the JSON
    -- field named by p_id_field (default 'BankId').
    -- 4xx/5xx = failure; extracts the error message from the
    -- standard Fusion error response envelope.
    -- --------------------------------------------------------
    PROCEDURE PARSE_REST_RESPONSE (
        p_http_status    IN  NUMBER,
        p_response       IN  CLOB,
        p_id_field       IN  VARCHAR2 DEFAULT 'BankId',
        x_success        OUT BOOLEAN,
        x_fusion_id      OUT NUMBER,
        x_error_message  OUT VARCHAR2
    );

    -- --------------------------------------------------------
    -- LOAD_OBJECT_REST
    -- High-level entry point for REST-based loading.
    -- Given an object code and run_id, reads TFM rows
    -- with STATUS = GENERATED, builds JSON per row from a
    -- config-driven column map, POSTs each to Fusion, and
    -- updates TFM status to LOADED or FAILED.
    --
    -- This is the REST equivalent of RUN_ONE_OBJECT_TYPE in
    -- DMT_LOADER_PKG.
    --
    -- NOTE: This is a STUB.  The actual implementation requires
    -- a config table mapping object codes to REST endpoints and
    -- column-to-JSON field mappings, which will be built later.
    -- --------------------------------------------------------
    PROCEDURE LOAD_OBJECT_REST (
        p_object_code    IN VARCHAR2,
        p_run_id IN NUMBER
    );

END DMT_REST_LOADER_PKG;
/
