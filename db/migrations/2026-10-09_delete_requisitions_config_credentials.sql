delete from DMT_CONFIG_TBL where CONFIG_KEY in ('Requisitions_USERNAME', 'Requisitions_PASSWORD');
merge into DMT_MIGRATION_LOG t using (select '2026-10-09_delete_requisitions_config_credentials.sql' migration_name from dual) s on (t.migration_name = s.migration_name) when not matched then insert (migration_name, checksum, applied_by) values (s.migration_name, 'delreqcfgcreds', USER);
commit;
-- ----------------------------------------------------------------------
-- Migration 2026-10-09: delete the unused hand-set Requisitions credential
-- rows from DMT_CONFIG_TBL (backlog #305, owner-approved 2026-10-09).
--
-- The rows: CONFIG_KEY = 'Requisitions_USERNAME' and CONFIG_KEY =
-- 'Requisitions_PASSWORD', exactly these two keys (case-sensitive equality,
-- no LIKE). They were set by hand on ATP DMT2_OWNER.DMT_CONFIG_TBL for the old
-- "Verify in Fusion" per-object override, which built the key as
-- <object code> || '_USERNAME' / '_PASSWORD' in DMT_REST_LOOKUP_PKG. PR #624
-- (backlog #223) removed that override; Verify now runs as the object's load
-- user through DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS. Nothing reads these keys any
-- more: no package, view, APEX page or script in the repo, and no line of
-- USER_SOURCE on dmt2-local (checked 2026-10-09). They are in no seed, so a
-- fresh install never creates them. dmt2-local never had them, so this is a
-- no-op there; it takes effect on ATP through the normal promotion.
--
-- Nothing else is touched: the global FUSION_/BIP_/HCM_ credential rows and
-- every other config row stay as they are.
--
-- Idempotent: a second run deletes nothing, and the migration-log MERGE
-- inserts once. Executable statements lead and each is one physical line
-- (deploy runner splitting rule, backlog #81).
-- ----------------------------------------------------------------------
