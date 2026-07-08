-- PACKAGE DMT_PO_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_PO_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_PO_TRANSFORM_PKG
-- Transforms staged PO records into the transformed tables.
-- Applies run prefix to DOCUMENT_NUM, dependent prefix to VENDOR_NUM,
-- and derives INTERFACE_*_KEY values for Fusion FBDI cross-referencing.
--
-- One procedure per PO object type.
-- Called by DMT_LOADER_PKG before FBDI generation.
--
-- When p_doc_type_filter is non-NULL, only processes staging rows with
-- matching STYLE_DISPLAY_NAME (or for lines/locs/dists, rows whose parent
-- header has a matching STYLE_DISPLAY_NAME). This allows Blanket POs and
-- Contracts to share the same staging tables while being processed independently.
--
-- Staging STATUS lifecycle managed here:
--   NEW / RETRY  -> TRANSFORMED (success) or FAILED (exception)
--
-- TFM STATUS set on insert:
--   STAGED (ready for FBDI generation)
-- ============================================================

    -- Transform eligible PO header staging rows for this run.
    -- Applies run prefix to DOCUMENT_NUM, dep_prefix to VENDOR_NUM.
    -- Derives INTERFACE_HEADER_KEY = run_id || '_HDR_' || stg_seq_id.
    PROCEDURE TRANSFORM_HEADERS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_doc_type_filter  IN VARCHAR2 DEFAULT NULL,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

    -- Transform eligible PO line staging rows for this run.
    -- Derives INTERFACE_LINE_KEY = run_id || '_LN_' || stg_seq_id.
    -- INTERFACE_HEADER_KEY copied verbatim from staging (user must supply matching key).
    PROCEDURE TRANSFORM_LINES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_doc_type_filter  IN VARCHAR2 DEFAULT NULL,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

    -- Transform eligible PO line location staging rows for this run.
    -- Derives INTERFACE_LINE_LOCATION_KEY = run_id || '_LOC_' || stg_seq_id.
    -- INTERFACE_LINE_KEY copied verbatim from staging.
    PROCEDURE TRANSFORM_LINE_LOCS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_doc_type_filter  IN VARCHAR2 DEFAULT NULL,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

    -- Transform eligible PO distribution staging rows for this run.
    -- Derives INTERFACE_DISTRIBUTION_KEY = run_id || '_DIST_' || stg_seq_id.
    -- INTERFACE_LINE_LOCATION_KEY copied verbatim from staging.
    PROCEDURE TRANSFORM_DISTS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_doc_type_filter  IN VARCHAR2 DEFAULT NULL,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

END DMT_PO_TRANSFORM_PKG;
/
