-- PACKAGE DMT_EGP_ITEM_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_EGP_ITEM_VALIDATOR_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_EGP_ITEM_VALIDATOR_PKG
-- Items pre/post-transform validation.
-- Items are master data; upstream dependencies may be added later
-- (e.g. UOM validation against DMT_INV_UOM_TFM_TBL).
-- ============================================================

    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id   IN NUMBER,
        p_dependent_prefix IN VARCHAR2 DEFAULT NULL
    );

    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    );

END DMT_EGP_ITEM_VALIDATOR_PKG;
/
