-- HCM SourceSystemOwner per DMT instance (backlog #287) and the Assignments
-- reconciliation report V2 registry repoint.
--
-- 1. Adds the DMT_CONFIG_TBL key HDL_SOURCE_SYSTEM_OWNER when it is missing:
--    DMT_ATP on an Autonomous Database (SYS_CONTEXT CLOUD_SERVICE is set there),
--    DMT_LOCAL everywhere else (the Docker instance). Every HDL generator now reads
--    it through DMT_HDL_UTIL_PKG.GET_SOURCE_SYSTEM_OWNER instead of the hardcoded
--    'HRC_SQLLOADER'. Insert-only, so an administrator's later value is kept.
-- 2. Points the Assignments Contract v1 registry row (BIP_REPORT_ID 100000032) at
--    DMT_ASSIGNMENTS_RECON_V2_DM / _RPT, which select rows by the HDL request id and
--    join the key map on each row's own owner. V1 filtered the key map on
--    'HRC_SQLLOADER', so with the new owner it would prove nothing. V2 is deployed
--    ALONGSIDE V1 (BIP objects are never overwritten).
--
-- Mirrors the committed seed changes in db/seed/dmt_config_tbl.sql and
-- db/seed/dmt_bip_report_tbl.sql so an existing database converges without
-- re-running the whole seed. Idempotent: insert-if-missing MERGE, a plain UPDATE
-- to fixed values, migration-log MERGE. No DDL.

prompt == Add HDL_SOURCE_SYSTEM_OWNER (insert only when missing) ==
merge into DMT_CONFIG_TBL t
using (select 'HDL_SOURCE_SYSTEM_OWNER' config_key,
              case when sys_context('USERENV', 'CLOUD_SERVICE') is not null
                   then 'DMT_ATP' else 'DMT_LOCAL' end config_value,
              'HCM HDL SourceSystemOwner written on every .dat line by every HDL generator (backlog #287). One owner per DMT instance so SourceSystemIds from different DMT databases never collide in Fusion HRC_INTEGRATION_KEY_MAP. Must be an enabled HRC_SOURCE_SYSTEM_OWNER lookup code. Seeded DMT_ATP on ATP, DMT_LOCAL on Docker.' description
       from dual) s
on (t.CONFIG_KEY = s.config_key)
when not matched then insert (CONFIG_KEY, CONFIG_VALUE, DESCRIPTION, LAST_UPDATED_DATE, LAST_UPDATED_BY)
     values (s.config_key, s.config_value, s.description, sysdate, 'DMT_OWNER');

prompt == Repoint Assignments recon registry row to V2 ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Assignments/DMT_ASSIGNMENTS_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Assignments/DMT_ASSIGNMENTS_RECON_V2_RPT.xdo',
       NOTES               = 'Assignment HDL base-table reconciliation (Contract v1). ONE report, '
                          || 'two base tiers via OBJECT_TYPE: WorkRelationship '
                          || '(DMT_WORK_REL_TFM_TBL <- PER_PERIODS_OF_SERVICE) and Assignment '
                          || '(DMT_ASSIGNMENT_TFM_TBL <- PER_ALL_ASSIGNMENTS_M). V2 (2026-10-07, '
                          || 'backlog #287/#290): rows selected by the HDL request id, key map joined '
                          || 'on each row''s own SourceSystemOwner (no HRC_SQLLOADER literal). '
                          || 'Deployed alongside V1, never overwriting it.'
where  BIP_REPORT_ID = 100000032
and    CEMLI_CODE    = 'Assignments';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-07_hdl_source_system_owner.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'hdlsso287', USER);

commit;
