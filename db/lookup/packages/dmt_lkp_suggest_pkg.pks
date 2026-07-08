CREATE OR REPLACE PACKAGE DMT_LOOKUP.DMT_LKP_SUGGEST_PKG AS
-- =============================================================================
-- DMT_LKP_SUGGEST_PKG
-- Fuzzy-matches unmatched EBS values against Fusion values using UTL_MATCH.
-- Inserts best candidates into DMT_LKP_MAPPING with SUGGESTED_FLAG='Y'
-- and ACTIVE_FLAG='N'. Mappings do not take effect until a user accepts them.
-- =============================================================================

    -- Generate suggestions for a single lookup type.
    -- p_min_jw       : minimum Jaro-Winkler score (0-100, default 85)
    -- p_min_ed       : minimum Edit Distance Similarity score (0-100, default 50)
    -- p_max_per_type : maximum suggestions to generate per type (default 500)
    -- Returns the number of suggestions inserted.
    FUNCTION SUGGEST_MAPPINGS (
        p_lookup_type   IN VARCHAR2,
        p_min_jw        IN NUMBER DEFAULT 85,
        p_min_ed        IN NUMBER DEFAULT 50,
        p_max_per_type  IN NUMBER DEFAULT 500
    ) RETURN NUMBER;

    -- Generate suggestions for ALL active lookup types.
    -- Returns total suggestions inserted across all types.
    FUNCTION SUGGEST_ALL_MAPPINGS (
        p_min_jw        IN NUMBER DEFAULT 85,
        p_min_ed        IN NUMBER DEFAULT 50,
        p_max_per_type  IN NUMBER DEFAULT 500
    ) RETURN NUMBER;

    -- Accept selected suggestions: set ACTIVE_FLAG='Y', SUGGESTED_FLAG='N'.
    -- Called from APEX with a colon-delimited list of MAPPING_IDs.
    PROCEDURE ACCEPT_SUGGESTIONS (
        p_mapping_ids   IN VARCHAR2
    );

    -- Reject (delete) selected suggestions.
    -- Called from APEX with a colon-delimited list of MAPPING_IDs.
    PROCEDURE REJECT_SUGGESTIONS (
        p_mapping_ids   IN VARCHAR2
    );

    -- Accept ALL pending suggestions for a lookup type.
    PROCEDURE ACCEPT_ALL_FOR_TYPE (
        p_lookup_type   IN VARCHAR2
    );

    -- Reject (delete) ALL pending suggestions for a lookup type.
    PROCEDURE REJECT_ALL_FOR_TYPE (
        p_lookup_type   IN VARCHAR2
    );

    -- Clear all pending suggestions (delete where SUGGESTED_FLAG='Y' AND ACTIVE_FLAG='N').
    PROCEDURE CLEAR_ALL_SUGGESTIONS;

END DMT_LKP_SUGGEST_PKG;
/
