-- PACKAGE DMT_ZX_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_ZX_VALIDATOR_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_ZX_VALIDATOR_PKG
-- Tax Regime and Rate pre/post-transform validation.
--
-- No upstream dependencies (tax config is standalone master data).
-- Post-transform validates orphan rates (rate rows without
-- a matching regime row in the same integration run).
-- ============================================================

    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id   IN NUMBER,
        p_dependent_prefix IN VARCHAR2 DEFAULT NULL
    );

    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    );

END DMT_ZX_VALIDATOR_PKG;
/
