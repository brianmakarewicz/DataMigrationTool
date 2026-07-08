-- ============================================================================
-- install_dmt_lookup.sql — full DMT_LOOKUP schema install for the LOCAL
-- Docker DB. Run as DMT_LOOKUP from the db_full/ directory:
--     sql dmt_lookup/<pw>@//localhost:1522/FREEPDB1 @install_dmt_lookup.sql
--
-- Unlike db_full/install.sql (a DBMS_METADATA snapshot), DMT_LOOKUP cannot be
-- snapshotted from the DMT_OWNER connection (no cross-schema metadata
-- privilege), so this runs the COMMITTED git files under schema/lookup,
-- schema/coa, packages/lookup and packages/coa — which are the deploy source
-- of truth for that schema anyway (git-first discipline).
--
-- Skipped on purpose:
--   schema/lookup/01_create_dmt_lookup.sql — user creation; local equivalent
--     is tools/local_lookup_setup.sql (SYSTEM).
--   schema/lookup/09_grants_and_synonyms.sql, schema/coa/02_* — ADMIN-on-ATP
--     grant/synonym scripts; locally the grants are made by the owning
--     schemas (below + build_local_db.sh) and the DMT_OWNER synonyms come
--     from db_full/synonyms/.
--
-- Re-runnable: every DDL statement in the lookup/coa scripts is guarded
-- (already-exists errors swallowed) and the seed is re-run-safe, so this
-- script can be run repeatedly with zero errors.
-- ============================================================================
set define off
whenever sqlerror exit failure rollback

prompt == DMT_LOOKUP tables (lookup) ==
@@lookup/schema/02_dmt_lkp_type_config.sql
@@lookup/schema/03_dmt_lkp_fusion_values.sql
@@lookup/schema/04_dmt_lkp_ebs_values.sql
@@lookup/schema/05_dmt_lkp_mapping.sql
@@lookup/schema/06_seed_type_config.sql
@@lookup/schema/07_add_default_fusion_value.sql
@@lookup/schema/08_create_unmatched_views.sql
@@lookup/schema/10_add_suggested_flag.sql
@@lookup/schema/11_fix_mapping_identity_and_audit.sql

prompt == DMT_LOOKUP tables (COA) ==
@@lookup/coa/01_coa_tables.sql

prompt == DMT_LOOKUP packages ==
@@lookup/packages/dmt_lkp_refresh_pkg.pks
@@lookup/packages/dmt_lkp_suggest_pkg.pks
@@lookup/packages/dmt_coa_map_pkg.pks
@@lookup/packages/dmt_coa_suggest_pkg.pks
@@lookup/packages/dmt_lkp_refresh_pkg.pkb
@@lookup/packages/dmt_lkp_suggest_pkg.pkb
@@lookup/packages/dmt_coa_map_pkg.pkb
@@lookup/packages/dmt_coa_suggest_pkg.pkb

prompt == Grants to DMT_OWNER (mirrors live ATP all_tab_privs, 2026-07-03) ==
grant select, insert, update, delete on DMT_LKP_TYPE_CONFIG to DMT_OWNER;
grant select on DMT_LKP_FUSION_VALUES to DMT_OWNER;
grant select, insert, update, delete on DMT_LKP_EBS_VALUES to DMT_OWNER;
grant select, insert, update, delete on DMT_LKP_MAPPING to DMT_OWNER;
grant select on DMT_LKP_EBS_UNMATCHED_V to DMT_OWNER;
grant select on DMT_LKP_MAPPING_STATUS_V to DMT_OWNER;
grant execute on DMT_LKP_REFRESH_PKG to DMT_OWNER;
grant execute on DMT_LKP_SUGGEST_PKG to DMT_OWNER;
grant select, insert, update, delete on DMT_COA_SET to DMT_OWNER;
grant select, insert, update, delete on DMT_COA_SEGMENT_DEF to DMT_OWNER;
grant select, insert, update, delete on DMT_COA_SEGMENT_MAP to DMT_OWNER;
grant select, insert, update, delete on DMT_COA_SEGMENT_VALUES to DMT_OWNER;
grant select, insert, update, delete on DMT_COA_MAP_CONFIG to DMT_OWNER;
grant select, insert, update, delete on DMT_COA_SOURCE_COMBOS to DMT_OWNER;
grant select, insert, update, delete on DMT_COA_TARGET_COMBOS to DMT_OWNER;
grant select, insert, update, delete on DMT_COA_MAPPING to DMT_OWNER;
grant execute on DMT_COA_MAP_PKG to DMT_OWNER;
grant execute on DMT_COA_SUGGEST_PKG to DMT_OWNER;

prompt == Compile + invalid listing ==
exec dbms_utility.compile_schema(schema => 'DMT_LOOKUP', compile_all => false)
select object_type, object_name from user_objects where status = 'INVALID' order by 1, 2;

prompt == install_dmt_lookup.sql complete ==
