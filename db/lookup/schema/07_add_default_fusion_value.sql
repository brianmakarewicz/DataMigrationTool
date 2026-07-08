-- =============================================================================
-- 07_add_default_fusion_value.sql
-- Run as DMT_LOOKUP
-- Adds DEFAULT_FUSION_VALUE column to DMT_LKP_TYPE_CONFIG.
-- When set, any EBS value without a specific mapping will resolve to this
-- default rather than passing through the original EBS value.
-- =============================================================================

begin
  execute immediate q'[
ALTER TABLE DMT_LKP_TYPE_CONFIG ADD (
    DEFAULT_FUSION_VALUE  VARCHAR2(500)
)]';
exception when others then
  if sqlcode not in (-1430) then raise; end if;
end;
/

COMMENT ON COLUMN DMT_LKP_TYPE_CONFIG.DEFAULT_FUSION_VALUE IS
    'Fallback Fusion value used when an EBS value has no explicit mapping. NULL = pass-through (original EBS value returned).';
