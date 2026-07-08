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
--   NEW / RETRY  -> TRANSFORMED (success) or FAILED (exception)
--
-- TFM STATUS set on insert:
--   STAGED (ready for FBDI generation)
-- ============================================================

    -- Transform eligible Requisition header staging rows for this run.
    -- Applies run prefix to REQUISITION_NUMBER.
    -- Derives INTERFACE_HEADER_KEY = run_id || '_RQHDR_' || stg_seq_id.
    -- Sets INTERFACE_SOURCE_CODE = 'DMT', BATCH_ID = TO_CHAR(run_id).
    PROCEDURE TRANSFORM_HEADERS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

    -- Transform eligible Requisition line staging rows for this run.
    -- Derives INTERFACE_LINE_KEY = run_id || '_RQLN_' || stg_seq_id.
    -- INTERFACE_HEADER_KEY copied from staging (user must supply matching key).
    PROCEDURE TRANSFORM_LINES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

    -- Transform eligible Requisition distribution staging rows for this run.
    -- Derives INTERFACE_DISTRIBUTION_KEY = run_id || '_RQDIST_' || stg_seq_id.
    -- INTERFACE_LINE_KEY copied from staging.
    PROCEDURE TRANSFORM_DISTS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

END DMT_REQ_TRANSFORM_PKG;
/
