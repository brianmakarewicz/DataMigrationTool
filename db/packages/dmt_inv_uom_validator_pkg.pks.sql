-- PACKAGE DMT_INV_UOM_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_INV_UOM_VALIDATOR_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_INV_UOM_VALIDATOR_PKG
-- Units of Measure pre/post-transform validation.
-- Standalone master data with no upstream dependencies.
-- ============================================================

    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id   IN NUMBER,
        p_dependent_prefix IN VARCHAR2 DEFAULT NULL
    );

    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    );

END DMT_INV_UOM_VALIDATOR_PKG;
/
