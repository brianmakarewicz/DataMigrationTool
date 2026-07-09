-- PACKAGE DMT_PRJ_BUDGET_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_PRJ_BUDGET_VALIDATOR_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_PRJ_BUDGET_VALIDATOR_PKG spec
-- Project Budgets pre- and post-transform validation.
-- Pre-transform: check PROJECT_NAME exists in DMT_PJF_PROJECTS_TFM_TBL
--                with TFM_STATUS='LOADED' (project must be loaded first).
-- Post-transform: required fields check.
-- ============================================================
    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id    IN NUMBER,
        p_dependent_prefix  IN VARCHAR2 DEFAULT NULL
    );
    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    );
END DMT_PRJ_BUDGET_VALIDATOR_PKG;
/
