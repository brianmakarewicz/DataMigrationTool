-- PACKAGE DMT_AP_PAY_TERM_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_AP_PAY_TERM_VALIDATOR_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_AP_PAY_TERM_VALIDATOR_PKG
-- Payment Terms pre/post-transform validation.
--
-- No upstream dependencies (payment terms are standalone master
-- data). Post-transform validates orphan lines (line rows whose
-- SOURCE_GROUP_ID does not match any header in the same run).
-- ============================================================

    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id   IN NUMBER,
        p_dependent_prefix IN VARCHAR2 DEFAULT NULL
    );

    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    );

END DMT_AP_PAY_TERM_VALIDATOR_PKG;
/
