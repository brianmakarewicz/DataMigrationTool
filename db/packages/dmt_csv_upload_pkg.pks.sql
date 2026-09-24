-- PACKAGE DMT_CSV_UPLOAD_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_CSV_UPLOAD_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_CSV_UPLOAD_PKG
-- Parses CSV files uploaded via APEX and inserts rows into
-- the target staging table. Fully metadata-driven — uses
-- DMT_UPLOAD_OBJECT_TBL for table lookup and
-- DMT_UPLOAD_DICT_TBL for column validation/mapping.
--
-- Two loading modes:
--   Fast (default): APEX_DATA_PARSER + single INSERT...SELECT
--                   Handles 500K+ rows in seconds.
--   Legacy:         PL/SQL row-by-row with DBMS_SQL.
--                   Per-row error handling, useful for debugging.
--
-- Entry points:
--   UPLOAD_CSV           — single CSV from APEX_APPLICATION_TEMP_FILES
--   UPLOAD_CSV_FROM_BLOB — single CSV from a BLOB (used by ZIP handler)
--   UPLOAD_ZIP_BUNDLE    — ZIP containing multiple CSVs
--
-- Called by APEX page After Submit processes.
-- ============================================================

    -- Main entry point: parse one CSV file and load into staging.
    -- p_file_name:       name from APEX_APPLICATION_TEMP_FILES
    -- p_object_code:     from the page select list (e.g. 'POZ_SUPPLIERS')
    -- p_batch_id:        optional — if NULL, creates a new batch
    -- p_use_fast_loader: TRUE = APEX_DATA_PARSER (default), FALSE = PL/SQL row-by-row
    PROCEDURE UPLOAD_CSV (
        p_file_name       IN  VARCHAR2,
        p_object_code     IN  VARCHAR2,
        p_batch_id        IN  NUMBER   DEFAULT NULL,
        p_rows_loaded     OUT NUMBER,
        p_rows_errored    OUT NUMBER,
        p_batch_id_out    OUT NUMBER,
        p_error_msg       OUT VARCHAR2,
        p_use_fast_loader IN  BOOLEAN  DEFAULT TRUE,
        p_scenario_name   IN  VARCHAR2 DEFAULT NULL
    );

    -- BLOB overload: parse CSV from an in-memory BLOB.
    -- Used by UPLOAD_ZIP_BUNDLE to avoid round-tripping through
    -- APEX_APPLICATION_TEMP_FILES (which is read-only).
    PROCEDURE UPLOAD_CSV_FROM_BLOB (
        p_blob            IN  BLOB,
        p_file_label      IN  VARCHAR2,
        p_object_code     IN  VARCHAR2,
        p_batch_id        IN  NUMBER   DEFAULT NULL,
        p_rows_loaded     OUT NUMBER,
        p_rows_errored    OUT NUMBER,
        p_batch_id_out    OUT NUMBER,
        p_error_msg       OUT VARCHAR2,
        p_use_fast_loader IN  BOOLEAN  DEFAULT TRUE,
        p_scenario_name   IN  VARCHAR2 DEFAULT NULL
    );

    -- ZIP bundle upload: unpack ZIP, route each CSV to the
    -- correct object based on DMT_UPLOAD_OBJECT_TBL.CSV_FILENAME.
    PROCEDURE UPLOAD_ZIP_BUNDLE (
        p_file_name       IN  VARCHAR2,
        p_batch_id        IN  NUMBER   DEFAULT NULL,
        p_summary         OUT CLOB,
        p_batch_id_out    OUT NUMBER,
        p_error_msg       OUT VARCHAR2,
        p_use_fast_loader IN  BOOLEAN  DEFAULT TRUE,
        p_scenario_name   IN  VARCHAR2 DEFAULT NULL
    );

    -- Remote upload: called by EBS over DB link.
    -- All SQL-compatible types (no BOOLEAN, no OUT params).
    -- Converts CLOB to BLOB internally, delegates to UPLOAD_CSV_FROM_BLOB.
    -- Results written to DMT_UPLOAD_LOG_TBL (caller queries log for status).
    PROCEDURE UPLOAD_FROM_REMOTE (
        p_csv_clob      IN  CLOB,
        p_object_code   IN  VARCHAR2,
        p_file_label    IN  VARCHAR2 DEFAULT 'EBS_REMOTE',
        p_scenario_name IN  VARCHAR2 DEFAULT NULL
    );

    -- FBDI ZIP upload: unpack a Fusion FBDI zip file and load the
    -- headerless, position-based CSVs into staging tables.
    -- Routes each CSV by matching its filename to
    -- DMT_UPLOAD_OBJECT_TBL.FBDI_CSV_FILENAME.
    -- Column mapping is positional (COLUMN_ORDER from DMT_UPLOAD_DICT_TBL).
    PROCEDURE UPLOAD_FBDI_ZIP (
        p_file_name       IN  VARCHAR2,
        p_batch_id        IN  NUMBER   DEFAULT NULL,
        p_summary         OUT CLOB,
        p_batch_id_out    OUT NUMBER,
        p_error_msg       OUT VARCHAR2,
        p_scenario_name   IN  VARCHAR2 DEFAULT NULL
    );

    -- BLOB overload for FBDI ZIP upload (no APEX temp file dependency).
    PROCEDURE UPLOAD_FBDI_ZIP_FROM_BLOB (
        p_zip_blob        IN  BLOB,
        p_file_label      IN  VARCHAR2,
        p_batch_id        IN  NUMBER   DEFAULT NULL,
        p_summary         OUT CLOB,
        p_batch_id_out    OUT NUMBER,
        p_error_msg       OUT VARCHAR2,
        p_scenario_name   IN  VARCHAR2 DEFAULT NULL
    );

    -- ------------------------------------------------------------
    -- UPLOAD_ZIP_AUTO — "Auto detect by filename" entry point.
    -- Unpacks one ZIP that may contain a MIX of proprietary CSVs
    -- (named DMT_<OBJECT>_STG_TBL.csv, with a header row) and
    -- Oracle FBDI CSVs (named by the FBDI convention, headerless,
    -- positional). Each member file is routed by its filename:
    --   * matches DMT_UPLOAD_OBJECT_TBL.CSV_FILENAME       -> proprietary loader
    --   * else matches DMT_UPLOAD_OBJECT_TBL.FBDI_CSV_FILENAME -> FBDI loader
    --   * else                                             -> skipped with a warning
    -- Parent-before-child order (DISPLAY_ORDER) is honoured across
    -- the whole mixed bundle. Reuses the proprietary and FBDI
    -- loaders — no duplicated load logic.
    PROCEDURE UPLOAD_ZIP_AUTO (
        p_file_name       IN  VARCHAR2,
        p_batch_id        IN  NUMBER   DEFAULT NULL,
        p_summary         OUT CLOB,
        p_batch_id_out    OUT NUMBER,
        p_error_msg       OUT VARCHAR2,
        p_use_fast_loader IN  BOOLEAN  DEFAULT TRUE,
        p_scenario_name   IN  VARCHAR2 DEFAULT NULL
    );

    -- BLOB overload for auto-detect (no APEX temp file dependency).
    PROCEDURE UPLOAD_ZIP_AUTO_FROM_BLOB (
        p_zip_blob        IN  BLOB,
        p_file_label      IN  VARCHAR2,
        p_batch_id        IN  NUMBER   DEFAULT NULL,
        p_summary         OUT CLOB,
        p_batch_id_out    OUT NUMBER,
        p_error_msg       OUT VARCHAR2,
        p_use_fast_loader IN  BOOLEAN  DEFAULT TRUE,
        p_scenario_name   IN  VARCHAR2 DEFAULT NULL
    );

END DMT_CSV_UPLOAD_PKG;
/
