-- PACKAGE DMT_PROJECT_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_PROJECT_VALIDATOR_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_PROJECT_VALIDATOR_PKG spec
-- Projects pre- and post-transform validation.
-- Pre-transform: rejects orphan tasks (a task whose parent project is absent
--   from the same source/scenario) before they can reach the FBDI.
-- Post-transform: stub.
-- ============================================================
    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id    IN NUMBER,
        p_dependent_prefix  IN VARCHAR2 DEFAULT NULL,
        p_scenario_id       IN NUMBER   DEFAULT NULL
    );
    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    );
END DMT_PROJECT_VALIDATOR_PKG;
/
