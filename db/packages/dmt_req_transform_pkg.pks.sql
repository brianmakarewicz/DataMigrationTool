-- PACKAGE DMT_REQ_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_REQ_TRANSFORM_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_REQ_TRANSFORM_PKG
-- Transforms staged Requisition records into the transformed tables.
-- Applies run prefix to REQUISITION_NUMBER and derives
-- INTERFACE_*_KEY values for Fusion FBDI cross-referencing.
--
-- One procedure per Requisition object type.
-- Called by DMT_LOADER_PKG before FBDI generation.
--
-- Staging STATUS lifecycle managed here:
--   NEW          -> TRANSFORMED (success) or FAILED (exception)
--
-- TFM STATUS set on insert:
--   STAGED (ready for FBDI generation)
-- ============================================================

    -- Transform eligible Requisition header staging rows for this run.
    -- Applies run prefix to REQUISITION_NUMBER.
    -- Derives INTERFACE_HEADER_KEY = TO_CHAR(TFM_SEQUENCE_ID) (backlog #218).
    -- Sets INTERFACE_SOURCE_CODE = 'DMT', BATCH_ID = TO_CHAR(run_id).
    PROCEDURE TRANSFORM_HEADERS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

    -- Transform eligible Requisition line staging rows for this run.
    -- Derives INTERFACE_LINE_KEY = TO_CHAR(TFM_SEQUENCE_ID); header key = parent header TFM id.
    -- The parent header is found through the staged INTERFACE_HEADER_KEY.
    PROCEDURE TRANSFORM_LINES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

    -- Transform eligible Requisition distribution staging rows for this run.
    -- Derives INTERFACE_DISTRIBUTION_KEY = TO_CHAR(TFM_SEQUENCE_ID); line key = parent line TFM id.
    -- The parent line is found through the staged INTERFACE_LINE_KEY.
    PROCEDURE TRANSFORM_DISTS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

END DMT_REQ_TRANSFORM_PKG;
/
