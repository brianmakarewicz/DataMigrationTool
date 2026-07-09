-- PACKAGE DMT_EXPENDITURE_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_EXPENDITURE_VALIDATOR_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_EXPENDITURE_VALIDATOR_PKG spec
-- Expenditures pre- and post-transform validation.
-- Pre-transform: check PROJECT_NUMBER exists in DMT_PJF_PROJECTS_STG_TBL
--                with STG_STATUS='LOADED' (using dependent prefix).
-- Post-transform: stub.
-- ============================================================
    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id    IN NUMBER,
        p_dependent_prefix  IN VARCHAR2 DEFAULT NULL
    );
    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    );
END DMT_EXPENDITURE_VALIDATOR_PKG;
/
