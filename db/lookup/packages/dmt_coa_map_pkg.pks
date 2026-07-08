CREATE OR REPLACE PACKAGE DMT_LOOKUP.DMT_COA_MAP_PKG AS
-- =============================================================================
-- DMT_COA_MAP_PKG
-- COA mapping generation and utilities.
-- Primary workflow:
--   1. Seed COA sets, segment defs, and mapping config
--   2. Load source combos (push_ebs_combos or CSV upload)
--   3. Define segment rules and segment value crosswalks
--   4. Call GENERATE_MAPPINGS to produce full-string crosswalk rows
--   5. Review/edit on APEX UI
--   6. EBS pulls from DMT_COA_MAPPING via pull_coa_mappings
-- =============================================================================

    -- Generate full COA-to-COA mappings from segment rules.
    -- For each source combo, applies segment rules to derive the target string.
    -- Inserts into DMT_COA_MAPPING with SOURCE_TYPE='GENERATED'.
    -- Does NOT overwrite MANUAL or IMPORTED rows.
    -- Returns count of rows generated.
    FUNCTION GENERATE_MAPPINGS (
        p_config_code   IN VARCHAR2
    ) RETURN NUMBER;

    -- Delete all GENERATED rows for a config (to re-generate).
    PROCEDURE CLEAR_GENERATED (
        p_config_code   IN VARCHAR2
    );

    -- Validate: check each mapping's TARGET_CONCAT exists in DMT_COA_TARGET_COMBOS.
    -- Updates NOTES with 'VALID' or 'INVALID: target combo not in Fusion'.
    -- Returns count of invalid mappings.
    FUNCTION VALIDATE_MAPPINGS (
        p_config_code   IN VARCHAR2
    ) RETURN NUMBER;

    -- Utility: extract segment N from a delimited string.
    FUNCTION GET_SEGMENT (
        p_concat    IN VARCHAR2,
        p_delimiter IN VARCHAR2,
        p_seg_num   IN NUMBER
    ) RETURN VARCHAR2 DETERMINISTIC;

END DMT_COA_MAP_PKG;
/
