-- PACKAGE DMT_PRJ_BUDGET_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_PRJ_BUDGET_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_PRJ_BUDGET_TRANSFORM_PKG
-- Transforms staged Project Budget records into TFM.
-- No prefix transformations needed for project budgets —
-- all business columns copied as-is from STG to TFM.
-- ============================================================

    PROCEDURE TRANSFORM (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

END DMT_PRJ_BUDGET_TRANSFORM_PKG;
/
