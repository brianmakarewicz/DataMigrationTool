-- Salaries reconciliation report V2 and "Verify in Fusion" key (backlog #291).
--
-- 1. Points the Salaries Contract v1 registry row (BIP_REPORT_ID 100000028) at
--    /Custom/DMT2/Salaries/DMT_SALARIES_RECON_V2_DM.xdm and its report
--    DMT_SALARIES_RECON_V2_RPT.xdo. V2 selects rows by the HDL request id (never
--    the run prefix), joins the key map on each row's own SourceSystemOwner and
--    confirms the salary in CMP_SALARY. V2 is deployed ALONGSIDE V1 (BIP objects
--    are never overwritten).
-- 2. The Salaries "Verify in Fusion" REST lookup filters the salaries resource by
--    AssignmentNumber but took its key from PERSON_NUMBER, so it never found a
--    salary. It now takes the TFM row's ASSIGNMENT_NUMBER (proven read-only
--    2026-10-07: salaries?q=AssignmentNumber=93322ET-RT-WKR-G1 returns SalaryId
--    300000334933788).
--
-- Mirrors the committed seed changes in db/seed/dmt_bip_report_tbl.sql and
-- db/seed/dmt_rest_lookup_tbl.sql. Idempotent: plain UPDATEs to fixed values,
-- migration-log MERGE. No DDL.

prompt == Repoint Salaries recon registry row to V2 ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Salaries/DMT_SALARIES_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Salaries/DMT_SALARIES_RECON_V2_RPT.xdo',
       NOTES               = 'Salary HDL base-table reconciliation (Contract v1). V2 (2026-10-07, backlog #291): '
                          || 'rows selected by the HDL request id, key map joined on each row''s own owner, '
                          || 'salary confirmed in CMP_SALARY. Deployed alongside V1, never overwriting it.'
where  BIP_REPORT_ID = 100000028
and    CEMLI_CODE    = 'Salaries';

prompt == Salaries Verify-in-Fusion lookup keys on the assignment number ==
update DMT_REST_LOOKUP_TBL
set    KEY_COLUMN = 'ASSIGNMENT_NUMBER'
where  OBJECT_TYPE = 'Salaries';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-07_salaries_recon_v2_registry.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'salreconv2', USER);

commit;
