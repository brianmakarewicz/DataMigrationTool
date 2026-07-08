-- PACKAGE DMT_FND_VS_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_FND_VS_VALIDATOR_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_FND_VS_VALIDATOR_PKG
-- Value Set pre/post-transform validation.
--
-- No upstream dependencies (value sets are standalone master data).
-- Post-transform validates orphan values (value rows without
-- a matching set row in the same integration run).
-- ============================================================

    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id   IN NUMBER,
        p_dependent_prefix IN VARCHAR2 DEFAULT NULL
    );

    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    );

END DMT_FND_VS_VALIDATOR_PKG;
/
