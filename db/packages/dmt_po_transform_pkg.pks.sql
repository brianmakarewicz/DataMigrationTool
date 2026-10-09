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
--   NEW          -> TRANSFORMED (success) or FAILED (exception)
--
-- TFM STATUS set on insert:
--   STAGED (ready for FBDI generation)
-- ============================================================

    -- Transform eligible PO header staging rows for this run.
    -- Applies run prefix to DOCUMENT_NUM, dep_prefix to VENDOR_NUM.
    -- Derives INTERFACE_HEADER_KEY = TO_CHAR(TFM_SEQUENCE_ID) (backlog #218).
    PROCEDURE TRANSFORM_HEADERS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_doc_type_filter  IN VARCHAR2 DEFAULT NULL,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

    -- Transform eligible PO line staging rows for this run.
    -- Derives INTERFACE_LINE_KEY = TO_CHAR(TFM_SEQUENCE_ID); header key = parent header TFM id.
    -- The parent header is found through the staged INTERFACE_HEADER_KEY.
    PROCEDURE TRANSFORM_LINES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_doc_type_filter  IN VARCHAR2 DEFAULT NULL,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

    -- Transform eligible PO line location staging rows for this run.
    -- Derives INTERFACE_LINE_LOCATION_KEY = TO_CHAR(TFM_SEQUENCE_ID); line key = parent line TFM id.
    -- The parent line is found through the staged INTERFACE_LINE_KEY.
    PROCEDURE TRANSFORM_LINE_LOCS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_doc_type_filter  IN VARCHAR2 DEFAULT NULL,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

    -- Transform eligible PO distribution staging rows for this run.
    -- Derives INTERFACE_DISTRIBUTION_KEY = TO_CHAR(TFM_SEQUENCE_ID); location key = parent location TFM id.
    -- The parent schedule is found through the staged INTERFACE_LINE_LOCATION_KEY.
    PROCEDURE TRANSFORM_DISTS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_doc_type_filter  IN VARCHAR2 DEFAULT NULL,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

END DMT_PO_TRANSFORM_PKG;
/
