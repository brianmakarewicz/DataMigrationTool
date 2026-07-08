-- =============================================================================
-- 09_grants_and_synonyms.sql
-- Run as ADMIN on ATP
-- Grants on new views + updated TYPE_CONFIG to DMT_OWNER for APEX access.
-- =============================================================================

-- View grants
GRANT SELECT ON DMT_LOOKUP.DMT_LKP_EBS_UNMATCHED_V     TO DMT_OWNER;
GRANT SELECT ON DMT_LOOKUP.DMT_LKP_MAPPING_STATUS_V    TO DMT_OWNER;

-- Synonyms (run as DMT_OWNER or via ADMIN with CREATE ANY SYNONYM)
CREATE OR REPLACE SYNONYM DMT_OWNER.DMT_LKP_EBS_UNMATCHED_V
    FOR DMT_LOOKUP.DMT_LKP_EBS_UNMATCHED_V;

CREATE OR REPLACE SYNONYM DMT_OWNER.DMT_LKP_MAPPING_STATUS_V
    FOR DMT_LOOKUP.DMT_LKP_MAPPING_STATUS_V;
