-- PACKAGE DMT_FND_LOOKUP_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_FND_LOOKUP_VALIDATOR_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_FND_LOOKUP_VALIDATOR_PKG
-- Lookup Types and Values pre/post-transform validation.
--
-- No upstream dependencies (lookups are standalone master data).
-- Post-transform validates orphan values (value rows without
-- a matching type row in the same integration run).
-- ============================================================

    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id   IN NUMBER,
        p_dependent_prefix IN VARCHAR2 DEFAULT NULL
    );

    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    );

END DMT_FND_LOOKUP_VALIDATOR_PKG;
/
