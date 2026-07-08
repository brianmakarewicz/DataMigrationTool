-- PACKAGE DMT_CE_BANK_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_CE_BANK_VALIDATOR_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_CE_BANK_VALIDATOR_PKG
-- Cash Management Banks/Branches/Accounts pre/post-transform
-- validation.
--
-- No upstream dependencies (banks are standalone master data).
-- Post-transform validates:
--   1. Orphan branches (SOURCE_GROUP_ID not matching any bank)
--   2. Orphan accounts (SOURCE_LINE_ID not matching any branch)
-- ============================================================

    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id   IN NUMBER,
        p_dependent_prefix IN VARCHAR2 DEFAULT NULL
    );

    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    );

END DMT_CE_BANK_VALIDATOR_PKG;
/
