-- TalentProfiles reconciliation report V2 registry repoint (backlog #451).
--
-- Points the TalentProfiles Contract v1 registry row (BIP_REPORT_ID 100000036) at
-- /Custom/DMT2/TalentProfiles/DMT_TALENTPROFILES_RECON_V2_DM.xdm and its report.
-- V2 selects rows by the HDL request id, joins the key map on each row's own
-- SourceSystemOwner (V1 filtered on HRC_SQLLOADER) and proves the profile and
-- each item on their own base rows. V2 is deployed ALONGSIDE V1.
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql.
-- Idempotent: plain UPDATE to fixed values, migration-log MERGE. No DDL.

prompt == Repoint TalentProfiles recon registry row to V2 ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/TalentProfiles/DMT_TALENTPROFILES_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/TalentProfiles/DMT_TALENTPROFILES_RECON_V2_RPT.xdo',
       NOTES               = 'Talent profile HDL base-table reconciliation (Contract v1). V2 (2026-10-08, backlog #451): '
                          || 'rows selected by the HDL request id, key map joined on each row''s own owner, '
                          || 'profile and items each proven on their own base row. Deployed alongside V1.'
where  BIP_REPORT_ID = 100000036
and    CEMLI_CODE    = 'TalentProfiles';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-08_talentprofiles_recon_v2_registry.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'tprofreconv2', USER);

commit;
