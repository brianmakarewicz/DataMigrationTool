-- =============================================================================
-- 08_create_unmatched_views.sql
-- Run as DMT_LOOKUP
-- Views for identifying EBS values that have no corresponding Fusion value
-- and the full mapping status of every EBS value.
-- =============================================================================

-- -----------------------------------------------------------------
-- DMT_LKP_EBS_UNMATCHED_V
-- EBS values where no Fusion value with the same name exists.
-- These can never be auto-mapped and require manual mapping or
-- a default value on the lookup type.
-- -----------------------------------------------------------------
CREATE OR REPLACE VIEW DMT_LKP_EBS_UNMATCHED_V AS
SELECT e.ebs_value_id,
       e.lookup_type,
       e.ebs_value,
       e.ebs_description,
       e.ebs_id,
       tc.description    AS type_description,
       tc.module,
       m.fusion_value    AS mapped_to,
       tc.default_fusion_value
FROM DMT_LKP_EBS_VALUES e
JOIN DMT_LKP_TYPE_CONFIG tc ON tc.lookup_type = e.lookup_type
LEFT JOIN DMT_LKP_MAPPING m
  ON m.lookup_type = e.lookup_type
 AND m.ebs_value   = e.ebs_value
 AND m.active_flag  = 'Y'
WHERE e.active_flag = 'Y'
AND NOT EXISTS (
    SELECT 1
    FROM DMT_LKP_FUSION_VALUES f
    WHERE f.lookup_type  = e.lookup_type
    AND   UPPER(f.fusion_value) = UPPER(e.ebs_value)
    AND   f.active_flag  = 'Y'
);

COMMENT ON TABLE DMT_LKP_EBS_UNMATCHED_V IS
    'EBS values with no corresponding Fusion value (case-insensitive match). Shows whether each is manually mapped or has a type-level default.';


-- -----------------------------------------------------------------
-- DMT_LKP_MAPPING_STATUS_V
-- Full mapping status for every active EBS value:
--   HAS_FUSION_MATCH  - a Fusion value with the same name exists
--   MAPPED_TO         - explicitly mapped Fusion value (from DMT_LKP_MAPPING)
--   EFFECTIVE_VALUE   - what get_fusion_value() will actually return:
--                       explicit mapping > default > pass-through
--   RESOLUTION        - how the effective value was determined
-- -----------------------------------------------------------------
CREATE OR REPLACE VIEW DMT_LKP_MAPPING_STATUS_V AS
SELECT e.ebs_value_id,
       e.lookup_type,
       tc.description    AS type_description,
       tc.module,
       e.ebs_value,
       e.ebs_description,
       e.ebs_id,
       -- Does a Fusion value with the same name exist?
       CASE WHEN f.fusion_value IS NOT NULL THEN 'Y' ELSE 'N' END
           AS has_fusion_match,
       f.fusion_value    AS matching_fusion_value,
       -- Explicit mapping
       m.fusion_value    AS mapped_to,
       m.active_flag     AS mapping_active,
       m.notes           AS mapping_notes,
       -- Type-level default
       tc.default_fusion_value,
       -- What the pipeline will actually use
       COALESCE(m.fusion_value, tc.default_fusion_value, e.ebs_value)
           AS effective_value,
       -- How it was resolved
       CASE
           WHEN m.fusion_value IS NOT NULL THEN 'EXPLICIT_MAPPING'
           WHEN tc.default_fusion_value IS NOT NULL THEN 'TYPE_DEFAULT'
           ELSE 'PASS_THROUGH'
       END AS resolution
FROM DMT_LKP_EBS_VALUES e
JOIN DMT_LKP_TYPE_CONFIG tc ON tc.lookup_type = e.lookup_type
LEFT JOIN DMT_LKP_FUSION_VALUES f
  ON f.lookup_type    = e.lookup_type
 AND UPPER(f.fusion_value) = UPPER(e.ebs_value)
 AND f.active_flag    = 'Y'
LEFT JOIN DMT_LKP_MAPPING m
  ON m.lookup_type = e.lookup_type
 AND m.ebs_value   = e.ebs_value
 AND m.active_flag  = 'Y'
WHERE e.active_flag = 'Y';

COMMENT ON TABLE DMT_LKP_MAPPING_STATUS_V IS
    'Complete mapping status for every active EBS value: explicit mapping, type default, Fusion match existence, and effective runtime value.';
