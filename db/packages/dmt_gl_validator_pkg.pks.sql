-- PACKAGE DMT_GL_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_GL_VALIDATOR_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_GL_VALIDATOR_PKG
-- Validation for GL Balances staging data.
-- Validation always runs even if empty.
-- ============================================================

    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id    IN NUMBER,
        p_dependent_prefix  IN VARCHAR2 DEFAULT NULL
    );

    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    );

END DMT_GL_VALIDATOR_PKG;
/
