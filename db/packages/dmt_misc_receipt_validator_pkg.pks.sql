-- PACKAGE DMT_MISC_RECEIPT_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_MISC_RECEIPT_VALIDATOR_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_MISC_RECEIPT_VALIDATOR_PKG
-- MiscReceipts pre/post-transform validation.
--
-- Upstream dependency: Items for a specific inventory org.
-- No upstream dependency currently enforced (items are
-- pre-existing in Fusion). Stub — ready for future rules.
-- ============================================================

    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id   IN NUMBER,
        p_dependent_prefix IN VARCHAR2 DEFAULT NULL
    );

    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    );

END DMT_MISC_RECEIPT_VALIDATOR_PKG;
/
