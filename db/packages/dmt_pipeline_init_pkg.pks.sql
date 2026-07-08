-- PACKAGE DMT_PIPELINE_INIT_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_PIPELINE_INIT_PKG" AS
-- ============================================================
-- DMT_PIPELINE_INIT_PKG
-- Single point of entry for creating pipeline runs.
-- Enforces one prefix per run from DMT_RUN_PREFIX_SEQ (4-digit,
-- 1000-9999, design section 6) unless USE_PREFIX='N'.
-- ============================================================

    -- Creates a CONVERSION_MASTER row and returns the integration_id.
    -- p_orchestration_code: identifies the pipeline (e.g. 'Suppliers', 'CONFIG_TEST')
    -- p_scenario_name: optional scenario to tag the run
    -- p_source_filename: optional source file description
    -- x_integration_id: OUT â the generated integration_id
    -- x_prefix: OUT â the generated prefix (or NULL if USE_PREFIX='N')
    PROCEDURE INIT_RUN (
        p_orchestration_code IN  VARCHAR2,
        p_scenario_name      IN  VARCHAR2 DEFAULT NULL,
        p_source_filename    IN  VARCHAR2 DEFAULT 'manual_run',
        p_instance_id        IN  VARCHAR2 DEFAULT 'MANUAL',
        x_integration_id     OUT NUMBER,
        x_prefix             OUT VARCHAR2
    );

    -- Convenience function: returns integration_id only (for simple callers)
    FUNCTION INIT_RUN_F (
        p_orchestration_code IN  VARCHAR2,
        p_scenario_name      IN  VARCHAR2 DEFAULT NULL,
        p_source_filename    IN  VARCHAR2 DEFAULT 'manual_run',
        p_instance_id        IN  VARCHAR2 DEFAULT 'MANUAL'
    ) RETURN NUMBER;

END DMT_PIPELINE_INIT_PKG;
/
