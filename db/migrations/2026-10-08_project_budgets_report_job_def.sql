-- ProjectBudgets: the Import Budgets report job definition (backlog #522).
-- Converges an EXISTING database with the committed seed in
-- db/seed/dmt_erp_interface_options_tbl.sql (row 39, REPORT_JOB_DEF =
-- 'BudgetsXfaceBIP', added by commit cdfdb81 for backlog #79). The options seed
-- skips rows that already exist, so a database whose row 39 predates that change
-- never received the value.
--
-- Found on ATP run 178 (2026-10-08): row 39 had REPORT_JOB_DEF NULL, so
-- DMT_ESS_UTIL_PKG.CAPTURE_REPORT_ESS_JOB returned at once ("no report child for
-- this CEMLI"), DMT_PRJ_BUDGET_RESULTS_PKG.APPLY_IMPORT_REPORT logged "No
-- BudgetsXfaceBIP report captured for import ESS 10080446", and the BAD row
-- RT-PJB-BAD1 stayed UNACCOUNTED. Local run 308 (row 39 = 'BudgetsXfaceBIP') read
-- the same report and FAILED it with "The project number NOPROJ999 doesn't exist
-- in Oracle Fusion Project Portfolio Management."
--
-- Idempotent: guarded fixed-value UPDATE; migration-log MERGE. No DDL.
-- Touches only the ProjectBudgets row.

prompt == ProjectBudgets: REPORT_JOB_DEF = BudgetsXfaceBIP (row 39) ==
update DMT_ERP_INTERFACE_OPTIONS_TBL
set    REPORT_JOB_DEF = 'BudgetsXfaceBIP'
where  CEMLI_CODE = 'ProjectBudgets'
and    ERP_INTERFACE_OPTIONS_ID = '39'
and    REPORT_JOB_DEF is null;

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-08_project_budgets_report_job_def.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'pjbrptdef522', USER);

commit;
