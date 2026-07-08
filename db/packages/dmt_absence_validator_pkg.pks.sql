-- PACKAGE DMT_ABSENCE_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_ABSENCE_VALIDATOR_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_ABSENCE_VALIDATOR_PKG
-- Validation for AbsenceEntry HDL staging data.
-- Stub implementation -- no validation rules yet.
-- ============================================================

    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id IN NUMBER
    );

    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    );

END DMT_ABSENCE_VALIDATOR_PKG;
/
