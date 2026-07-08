-- PACKAGE DMT_POZ_SUP_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_POZ_SUP_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_POZ_SUP_TRANSFORM_PKG
-- Transforms staged supplier records into the transformed tables.
-- Applies run prefix to SEGMENT1 (supplier number) only.
-- All other key fields (VENDOR_SITE_CODE, VENDOR_NAME, etc.) are
-- copied verbatim — prefix applies to the supplier number only.
--
-- One procedure per supplier object type.
-- Called by DMT_LOADER_PKG before FBDI generation.
--
-- Staging STATUS lifecycle managed here:
--   NEW / RETRY  -> TRANSFORMED (success) or FAILED (exception)
--
-- TFM STATUS set on insert:
--   STAGED (ready for FBDI generation)
-- ============================================================

    -- Transform eligible supplier header staging rows for this run.
    -- Applies run prefix to SEGMENT1.
    -- p_reprocess_errors = TRUE also picks up FAILED staging rows
    -- (clears ERROR_TEXT and inserts a fresh TFM row).
    PROCEDURE TRANSFORM_SUPPLIERS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

    -- Transform eligible supplier address staging rows for this run.
    -- No prefix applied — addresses use VENDOR_NAME + PARTY_SITE_NAME as key.
    PROCEDURE TRANSFORM_ADDRESSES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

    -- Transform eligible supplier site staging rows for this run.
    -- VENDOR_SITE_CODE copied verbatim — prefix applies to supplier SEGMENT1 only.
    PROCEDURE TRANSFORM_SITES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

    -- Transform eligible supplier site assignment staging rows for this run.
    -- All columns copied verbatim.
    PROCEDURE TRANSFORM_SITE_ASSIGNMENTS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

    -- Transform eligible supplier contact staging rows for this run.
    -- All columns copied verbatim (contacts have no prefix-keyed fields).
    PROCEDURE TRANSFORM_CONTACTS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

END DMT_POZ_SUP_TRANSFORM_PKG;
/
