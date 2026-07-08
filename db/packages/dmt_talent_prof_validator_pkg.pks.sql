-- PACKAGE DMT_TALENT_PROF_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_TALENT_PROF_VALIDATOR_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_TALENT_PROF_VALIDATOR_PKG
-- Validation for TalentProfile HDL staging data.
-- Stub implementation -- no validation rules yet.
-- ============================================================

    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id IN NUMBER
    );

    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    );

END DMT_TALENT_PROF_VALIDATOR_PKG;
/
