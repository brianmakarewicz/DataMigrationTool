-- PACKAGE DMT_EGP_ITEM_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_EGP_ITEM_TRANSFORM_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_EGP_ITEM_TRANSFORM_PKG
-- Transforms Items from STG to TFM.
-- FBDI pattern via EgpItemImportTemplate.
-- ============================================================

    PROCEDURE TRANSFORM (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N',
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    );

END DMT_EGP_ITEM_TRANSFORM_PKG;
/
