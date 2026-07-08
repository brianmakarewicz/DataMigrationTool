-- PACKAGE DMT_PROJECT_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_PROJECT_VALIDATOR_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_PROJECT_VALIDATOR_PKG spec
-- Projects pre- and post-transform validation.
-- Pre-transform: stub (projects are top-level master data, no upstream deps).
-- Post-transform: stub.
-- ============================================================
    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id    IN NUMBER,
        p_dependent_prefix  IN VARCHAR2 DEFAULT NULL
    );
    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    );
END DMT_PROJECT_VALIDATOR_PKG;
/
