-- PACKAGE DMT_EGP_ITEM_CAT_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_EGP_ITEM_CAT_VALIDATOR_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_EGP_ITEM_CAT_VALIDATOR_PKG
-- Item Categories pre/post-transform validation.
-- Depends on Items (upstream master data).
-- ============================================================

    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id   IN NUMBER,
        p_dependent_prefix IN VARCHAR2 DEFAULT NULL
    );

    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    );

END DMT_EGP_ITEM_CAT_VALIDATOR_PKG;
/
