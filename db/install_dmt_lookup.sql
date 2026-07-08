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
-- NOT re-runnable (the numbered scripts are sequential migrations, not
-- guarded DDL) — use only on a --fresh build.
-- ============================================================================
set define off
whenever sqlerror exit failure rollback

prompt == DMT_LOOKUP tables (lookup) ==
@@../schema/lookup/02_dmt_lkp_type_config.sql
@@../schema/lookup/03_dmt_lkp_fusion_values.sql
@@../schema/lookup/04_dmt_lkp_ebs_values.sql
@@../schema/lookup/05_dmt_lkp_mapping.sql
@@../schema/lookup/06_seed_type_config.sql
@@../schema/lookup/07_add_default_fusion_value.sql
@@../schema/lookup/08_create_unmatched_views.sql
@@../schema/lookup/10_add_suggested_flag.sql
@@../schema/lookup/11_fix_mapping_identity_and_audit.sql

prompt == DMT_LOOKUP tables (COA) ==
-- Errors tolerated for this one file: line 133 creates DMT_COA_MAP_SRC_N1 on
-- the exact column list of constraint DMT_COA_MAP_UK -> ORA-01408. The index
-- does not exist on ATP either (the statement can never have succeeded);
-- fix belongs in schema/coa on main. Everything after it in the file is
-- created normally.
whenever sqlerror continue
@@../schema/coa/01_coa_tables.sql
whenever sqlerror exit failure rollback

prompt == DMT_LOOKUP packages ==
@@../packages/lookup/dmt_lkp_refresh_pkg.pks
@@../packages/lookup/dmt_lkp_suggest_pkg.pks
@@../packages/coa/dmt_coa_map_pkg.pks
@@../packages/coa/dmt_coa_suggest_pkg.pks
@@../packages/lookup/dmt_lkp_refresh_pkg.pkb
@@../packages/lookup/dmt_lkp_suggest_pkg.pkb
@@../packages/coa/dmt_coa_map_pkg.pkb
@@../packages/coa/dmt_coa_suggest_pkg.pkb

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
