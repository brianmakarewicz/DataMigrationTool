-- =============================================================================
-- 10_add_suggested_flag.sql
-- Run as DMT_LOOKUP (or ADMIN with ALTER ANY TABLE)
-- Adds SUGGESTED_FLAG and MATCH_SCORE to DMT_LKP_MAPPING.
-- Suggested mappings are inserted with ACTIVE_FLAG='N', SUGGESTED_FLAG='Y'.
-- They do NOT affect the pipeline until a user reviews and accepts them,
-- which flips ACTIVE_FLAG='Y' and SUGGESTED_FLAG='N'.
-- =============================================================================

begin
  execute immediate q'[
ALTER TABLE DMT_LKP_MAPPING ADD (
    SUGGESTED_FLAG  VARCHAR2(1) DEFAULT 'N' NOT NULL
)]';
exception when others then
  if sqlcode not in (-1430) then raise; end if;
end;
/

begin
  execute immediate q'[
ALTER TABLE DMT_LKP_MAPPING ADD (
    MATCH_SCORE     NUMBER
)]';
exception when others then
  if sqlcode not in (-1430) then raise; end if;
end;
/

COMMENT ON COLUMN DMT_LKP_MAPPING.SUGGESTED_FLAG IS
    'Y = auto-suggested by fuzzy match, pending user review. N = user-created or accepted.';
COMMENT ON COLUMN DMT_LKP_MAPPING.MATCH_SCORE IS
    'Combined Jaro-Winkler + Edit Distance similarity score (0-200). NULL for manual mappings.';
