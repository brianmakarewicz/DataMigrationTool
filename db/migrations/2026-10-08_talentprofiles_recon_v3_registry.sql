-- TalentProfiles reconciliation report V3 registry repoint (backlog #451).
--
-- Points the TalentProfiles Contract v1 registry row (BIP_REPORT_ID 100000036) at
-- /Custom/DMT2/TalentProfiles/DMT_TALENTPROFILES_RECON_V3_DM.xdm and its report.
-- Fusion records the talent profile in HRC_INTEGRATION_KEY_MAP under object name
-- 'Profile'; V2 filtered on 'TalentProfile' and never returned a loaded profile
-- (proof run 298, prefix 93352, left it UNACCOUNTED). V3 matches 'Profile' and
-- returns it as OBJECT_TYPE 'TalentProfile'. V3 is deployed ALONGSIDE V1 and V2.
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql.
-- Idempotent: plain UPDATE to fixed values, migration-log MERGE. No DDL.

prompt == Repoint TalentProfiles recon registry row to V3 ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/TalentProfiles/DMT_TALENTPROFILES_RECON_V3_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/TalentProfiles/DMT_TALENTPROFILES_RECON_V3_RPT.xdo',
       NOTES               = 'Talent profile HDL base-table reconciliation (Contract v1). V2 (2026-10-08, backlog #451): '
                          || 'rows selected by the HDL request id, key map joined on each row''s own owner, '
                          || 'profile and items each proven on their own base row. V3: profile matched on key-map '
                          || 'object Profile. Deployed alongside V1 and V2.'
where  BIP_REPORT_ID = 100000036
and    CEMLI_CODE    = 'TalentProfiles';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-08_talentprofiles_recon_v3_registry.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'tprofreconv3', USER);

commit;
