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
        p_dependent_prefix IN VARCHAR2 DEFAULT NULL,
        p_scenario_id     IN NUMBER   DEFAULT NULL,
        p_run_mode        IN VARCHAR2 DEFAULT 'NEW'
    );

    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    );

    -- Backlog #651: fail every STAGED TFM row of the run whose CSV value holds a
    -- line break (CR/LF), naming the field. Called between transform and generate.
    PROCEDURE VALIDATE_LINE_BREAKS (p_run_id IN NUMBER);

END DMT_MISC_RECEIPT_VALIDATOR_PKG;
/
