-- ProjectBudgets reconciliation report V2 registry repoint (known-good fix,
-- docs/findings/known_good_ProjectBudgets.md, change 3).
--
-- Points the ProjectBudgets Contract v1 registry row (BIP_REPORT_ID 100000019)
-- at the new data model /Custom/DMT2/ProjectBudgets/DMT_PRJ_BUDGET_RECON_V2_DM.xdm and its
-- report DMT_PRJ_BUDGET_RECON_V2_RPT.xdo. V2 scopes the run by
-- PJO_PLAN_VERSIONS_B.PM_BUDGET_REFERENCE LIKE :P_PREFIX || '%' (OR the old
-- prefixed project number), so a budget loaded onto an EXISTING Fusion project
-- is matched. V2 is deployed ALONGSIDE V1 (BIP objects are never overwritten);
-- V1 stays in the catalog untouched.
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql so an
-- existing database converges without re-running the whole seed. Idempotent:
-- a plain UPDATE to fixed values (re-run is a no-op), migration-log MERGE.
-- Touches only the ProjectBudgets registry row; no DDL.

prompt == Repoint ProjectBudgets recon registry row to V2 ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/ProjectBudgets/DMT_PRJ_BUDGET_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/ProjectBudgets/DMT_PRJ_BUDGET_RECON_V2_RPT.xdo',
       NOTES               = 'Project budget import reconciliation (Contract v1) - '
                          || 'PjoPlanVersionsXface.csv via prj/projectControl/import. V2 '
                          || '(2026-10-07): run scoped by PM_BUDGET_REFERENCE LIKE prefix OR '
                          || 'prefixed project number; deployed alongside V1, never overwriting it.',
       RECON_KEY_SQL       = 'SRC_BUDGET_LINE_REFERENCE -- run-prefixed source budget line ref, '
                          || 'survives as PM_BUDGET_REFERENCE on the base row'
where  BIP_REPORT_ID = 100000019
and    CEMLI_CODE    = 'ProjectBudgets';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-07_project_budgets_recon_v2_registry.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'prjbudgetreconv2', USER);

commit;
