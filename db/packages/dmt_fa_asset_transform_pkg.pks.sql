-- PACKAGE DMT_FA_ASSET_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_FA_ASSET_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_FA_ASSET_TRANSFORM_PKG
-- Transforms staged Asset records into TFM tables.
-- Three object types: headers, assignments, books.
-- ============================================================

    PROCEDURE TRANSFORM_HEADERS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

    PROCEDURE TRANSFORM_ASSIGNMENTS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

    PROCEDURE TRANSFORM_BOOKS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

END DMT_FA_ASSET_TRANSFORM_PKG;
/
