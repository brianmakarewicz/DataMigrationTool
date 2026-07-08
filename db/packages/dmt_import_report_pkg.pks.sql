-- PACKAGE DMT_IMPORT_REPORT_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_IMPORT_REPORT_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_IMPORT_REPORT_PKG
-- Generic parser for Fusion Import Report XML (ESS output).
--
-- Fusion import ESS jobs produce a BIP XML report with
-- module-specific error/success rows. This package extracts
-- error details into a standard format regardless of module.
--
-- Known XML structures:
--   Projects: LIST_PROJECT_ERROR/PROJECT_ERROR, LIST_TASK_ERROR, etc.
--   AP: LIST_AP_INV_ERROR/AP_INV_ERROR
--   PO: LIST_PO_ERROR/PO_ERROR
--   FA: (errors in PrepareMassAdditions output, not XML report)
--
-- Usage:
--   l_xml := DMT_ESS_UTIL_PKG.GET_ESS_OUTPUT_XML(import_ess_id);
--   l_errors := DMT_IMPORT_REPORT_PKG.PARSE_ERRORS(l_xml);
--   FOR i IN 1..l_errors.COUNT LOOP ...
-- ============================================================

    TYPE t_import_error IS RECORD (
        row_identifier VARCHAR2(500),
        error_message  VARCHAR2(4000),
        object_type    VARCHAR2(100),
        error_source   VARCHAR2(100)
    );

    TYPE t_error_list IS TABLE OF t_import_error;

    -- Parse import report XML and extract all error rows.
    -- Returns empty collection if XML is NULL or contains no errors.
    FUNCTION PARSE_ERRORS (
        p_xml_clob IN CLOB
    ) RETURN t_error_list;

    -- Parse and log errors directly to DMT_LOG_TBL for an integration run.
    -- Calls GET_ESS_OUTPUT_XML internally, parses errors, logs each one,
    -- and returns the count of errors found.
    FUNCTION PARSE_AND_LOG_ERRORS (
        p_run_id IN NUMBER,
        p_request_id     IN NUMBER,
        p_cemli_code     IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

END DMT_IMPORT_REPORT_PKG;
/
