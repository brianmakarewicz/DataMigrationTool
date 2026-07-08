CREATE OR REPLACE PACKAGE DMT_LOOKUP.DMT_COA_SUGGEST_PKG AS
-- =============================================================================
-- DMT_COA_SUGGEST_PKG
-- Fuzzy-match and auto-map for COA segment values.
-- Same accept/reject pattern as DMT_LKP_SUGGEST_PKG.
-- =============================================================================

    -- Auto-map segment values that match exactly (case-insensitive).
    FUNCTION AUTO_MAP_EXACT (
        p_segment_map_id IN NUMBER
    ) RETURN NUMBER;

    -- Fuzzy-suggest segment value mappings using UTL_MATCH.
    FUNCTION SUGGEST_SEGMENT_VALUES (
        p_segment_map_id IN NUMBER,
        p_min_jw         IN NUMBER DEFAULT 85,
        p_min_ed         IN NUMBER DEFAULT 50
    ) RETURN NUMBER;

    -- Accept selected suggestions.
    PROCEDURE ACCEPT_SUGGESTIONS (p_value_ids IN VARCHAR2);

    -- Reject (delete) selected suggestions.
    PROCEDURE REJECT_SUGGESTIONS (p_value_ids IN VARCHAR2);

END DMT_COA_SUGGEST_PKG;
/
