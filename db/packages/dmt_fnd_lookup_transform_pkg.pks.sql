-- PACKAGE DMT_FND_LOOKUP_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_FND_LOOKUP_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_FND_LOOKUP_TRANSFORM_PKG
-- Transforms Lookup Types and Values from STG to TFM tables.
-- Handles both FND_LOOKUP_TYPE and FND_LOOKUP_VALUE in one
-- package, mirroring the MiscReceipt header/transaction pattern.
-- ============================================================

    PROCEDURE TRANSFORM_TYPES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N',
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    );

    PROCEDURE TRANSFORM_VALUES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N',
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    );

END DMT_FND_LOOKUP_TRANSFORM_PKG;
/
