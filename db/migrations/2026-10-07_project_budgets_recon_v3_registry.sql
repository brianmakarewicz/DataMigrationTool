-- ProjectBudgets reconciliation report V3 registry repoint (find rows by job id).
--
-- Points the ProjectBudgets Contract v1 registry row (BIP_REPORT_ID 100000019)
-- at /Custom/DMT2/ProjectBudgets/DMT_PRJ_BUDGET_RECON_V3_DM.xdm and its report
-- DMT_PRJ_BUDGET_RECON_V3_RPT.xdo. V3 finds rows only by the work item's own
-- Fusion job ids (owner decision 2026-10-07): plan versions by
-- PJO_PLAN_VERSIONS_B.REQUEST_ID = the import job id, interface rows by
-- PJO_PLAN_VERSIONS_XFACE.LOAD_REQUEST_ID = the load job id. V2 selected rows
-- with LIKE on the run prefix. V3 is deployed ALONGSIDE V1 and V2 (BIP objects
-- are never overwritten).
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql so an
-- existing database converges without re-running the whole seed. Idempotent:
-- a plain UPDATE to fixed values (re-run is a no-op), migration-log MERGE.
-- Touches only the ProjectBudgets registry row; no DDL.

prompt == Repoint ProjectBudgets recon registry row to V3 ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/ProjectBudgets/DMT_PRJ_BUDGET_RECON_V3_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/ProjectBudgets/DMT_PRJ_BUDGET_RECON_V3_RPT.xdo',
       NOTES               = 'Project budget import reconciliation (Contract v1) - '
                          || 'PjoPlanVersionsXface.csv via prj/projectControl/import. V3 '
                          || '(2026-10-07): rows found only by the work item''s Fusion job ids (plan '
                          || 'versions by the import REQUEST_ID, interface by the load LOAD_REQUEST_ID), '
                          || 'never by the run prefix; called once per work item. Deployed alongside '
                          || 'V1 and V2, never overwriting them.',
       RECON_KEY_SQL       = 'SRC_BUDGET_LINE_REFERENCE -- run-prefixed source budget line ref, survives '
                          || 'as PM_BUDGET_REFERENCE on the base row (a match key only, never a row selector)'
where  BIP_REPORT_ID = 100000019
and    CEMLI_CODE    = 'ProjectBudgets';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-07_project_budgets_recon_v3_registry.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'prjbudgetreconv3', USER);

commit;
