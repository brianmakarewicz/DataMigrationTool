-- Projects reconciliation report V2 registry repoint (owner-approved exception).
--
-- Points the Projects Contract v1 registry row and its three auditor rows
-- (Projects.Task, Projects.TeamMember, Projects.TxnControl) at
-- /Custom/DMT2/Projects/DMT_PROJECT_RECON_V2_DM.xdm and its report
-- DMT_PROJECT_RECON_V2_RPT.xdo. Fusion stamps no job id on the project base
-- tables, so V2 (owner decision 2026-10-07, design section 5) selects the work
-- item's base projects by PJF_PROJECTS_ALL_B.PM_PROJECT_REFERENCE LIKE
-- '<run_id>:<work_queue_id>:%' (the source reference the transform stamps),
-- reaches tasks, team members and transaction controls through their project,
-- and selects interface rows by LOAD_REQUEST_ID. V1 selected rows with LIKE on
-- the run prefix. V2 is deployed ALONGSIDE V1 (BIP objects are never
-- overwritten).
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql so an
-- existing database converges without re-running the whole seed. Idempotent:
-- plain UPDATEs to fixed values (re-run is a no-op), migration-log MERGE.
-- Touches only the four Projects registry rows; no DDL.

prompt == Repoint Projects recon registry row to V2 ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Projects/DMT_PROJECT_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Projects/DMT_PROJECT_RECON_V2_RPT.xdo',
       NOTES               = 'Project import reconciliation (Contract v1, multi-tier, 4 tiers). V2 (2026-10-07, '
                          || 'owner-approved exception): base projects found by PM_PROJECT_REFERENCE LIKE '
                          || '''<run_id>:<work_queue_id>:%'' (Fusion stamps no job id on the project base '
                          || 'tables), other base tiers through their project, interface rows by '
                          || 'LOAD_REQUEST_ID; called once per work item. Deployed alongside V1.'
where  CEMLI_CODE = 'Projects';

prompt == Repoint the Projects task, team-member and transaction-control auditor rows to V2 ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Projects/DMT_PROJECT_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Projects/DMT_PROJECT_RECON_V2_RPT.xdo'
where  CEMLI_CODE IN ('Projects.Task', 'Projects.TeamMember', 'Projects.TxnControl');

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-07_projects_recon_v2_registry.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'prjreconv2', USER);

commit;
