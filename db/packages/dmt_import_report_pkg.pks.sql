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
    -- Contract: the return value only ever means "count of errors found"
    -- (0 = report downloaded, no errors). Download/parse failures are logged
    -- and RAISED — never swallowed into a 0 return (tranche findings 9/23).
    FUNCTION PARSE_AND_LOG_ERRORS (
        p_run_id IN NUMBER,
        p_request_id     IN NUMBER,
        p_cemli_code     IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

    -- --------------------------------------------------------
    -- APPLY_ERRORS — shared "match import-report error rows back to our
    -- records" writer (backlog item 28). The same per-row loop was
    -- copy-pasted across results packages: for each parsed error whose
    -- row_identifier is not null, mark the matching still-GENERATED TFM
    -- row FAILED and append the real Fusion message to ERROR_TEXT under
    -- the [IMPORT_REPORT] tag. Extracted here once, parameterized by the
    -- TFM table + the key column that carries the report's row identifier.
    --
    -- Behavior contract (must stay byte-identical to the inlined loops it
    -- replaces — ERROR_TEXT is accounting evidence):
    --   * Only rows with RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED' are
    --     touched; a row already LOADED or FAILED is never revisited.
    --   * Match key: p_key_column = row_identifier. When p_parent_column is
    --     supplied, the object's inline predicate ALSO accepted the
    --     '/'-joined compound (parent || '/' || key = row_identifier); that
    --     exact OR branch is reproduced and NOTHING else. (INSTR/token
    --     matches are object-specific and stay inline in their package.)
    --   * ERROR_TEXT is written via DMT_UTIL_PKG.APPEND_ERROR (accumulate,
    --     never overwrite) with p_tag || NVL(error_message, p_default_msg).
    --   * Errors with a NULL row_identifier are skipped (never fabricated).
    -- Returns the number of TFM rows matched (SUM of SQL%ROWCOUNT), so the
    -- caller's matched-count accumulation is unchanged. Does NOT commit.
    -- p_table_name / p_key_column / p_parent_column are compile-time
    -- identifiers supplied by DMT code (never user input); every value is
    -- bound, so the stored ERROR_TEXT and matched set are identical to the
    -- static UPDATE this replaces.
    -- --------------------------------------------------------
    FUNCTION APPLY_ERRORS (
        p_run_id        IN NUMBER,
        p_errors        IN t_error_list,
        p_table_name    IN VARCHAR2,
        p_key_column    IN VARCHAR2,
        p_parent_column IN VARCHAR2 DEFAULT NULL,
        p_default_msg   IN VARCHAR2 DEFAULT 'Import error (no details)',
        p_tag           IN VARCHAR2 DEFAULT '[IMPORT_REPORT] '
    ) RETURN NUMBER;

END DMT_IMPORT_REPORT_PKG;
/
