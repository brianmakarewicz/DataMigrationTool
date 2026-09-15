-- =============================================================================
-- 09_grants_and_synonyms.sql
-- Run as ADMIN on ATP
-- Grants on new views + updated TYPE_CONFIG to the owner for APEX access.
--
-- Owning schema is passed in at deploy time as the first argument, so this
-- installs against any owner. Because this runs as ADMIN, both the grantee and
-- the synonym owner MUST be qualified with the passed-in owner -- unqualified,
-- the synonyms would be created in ADMIN's own schema and the owner would never
-- see them.
--   Example:  sql admin/pw@atp @09_grants_and_synonyms.sql DMT2_OWNER
-- =============================================================================
SET VERIFY OFF
DEFINE owner_schema = &1

-- View grants
GRANT SELECT ON DMT_LOOKUP.DMT_LKP_EBS_UNMATCHED_V     TO &owner_schema.;
GRANT SELECT ON DMT_LOOKUP.DMT_LKP_MAPPING_STATUS_V    TO &owner_schema.;

-- Synonyms created in the owner's schema (ADMIN needs CREATE ANY SYNONYM)
CREATE OR REPLACE SYNONYM &owner_schema..DMT_LKP_EBS_UNMATCHED_V
    FOR DMT_LOOKUP.DMT_LKP_EBS_UNMATCHED_V;

CREATE OR REPLACE SYNONYM &owner_schema..DMT_LKP_MAPPING_STATUS_V
    FOR DMT_LOOKUP.DMT_LKP_MAPPING_STATUS_V;
