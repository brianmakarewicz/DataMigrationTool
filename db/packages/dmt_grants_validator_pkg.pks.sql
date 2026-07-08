-- PACKAGE DMT_GRANTS_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_GRANTS_VALIDATOR_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_GRANTS_VALIDATOR_PKG spec
-- Grants pre- and post-transform validation.
-- Pre-transform: check upstream Projects LOADED.
-- Post-transform: stub.
-- ============================================================
    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id    IN NUMBER,
        p_dependent_prefix  IN VARCHAR2 DEFAULT NULL
    );
    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    );
END DMT_GRANTS_VALIDATOR_PKG;
/
