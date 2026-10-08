-- SalaryBases reconciliation report V2 registry repoint (backlog #292; owner
-- rule 2026-10-07: reports find rows by Fusion job id, never by the run prefix).
--
-- Points the SalaryBases Contract v1 registry row (BIP_REPORT_ID 100000029) at
-- /Custom/DMT2/SalaryBases/DMT_SALARYBASES_RECON_V2_DM.xdm and its report
-- DMT_SALARYBASES_RECON_V2_RPT.xdo. V2 selects rows by the HDL request id (never
-- the run prefix), joins the key map on each row's own SourceSystemOwner and
-- confirms the salary basis in CMP_SALARY_BASES. V2 is deployed ALONGSIDE V1
-- (BIP objects are never overwritten).
--
-- The SalaryBasis SourceSystemId is now the TFM row's TFM_SEQUENCE_ID (the
-- SalaryBasisName stays the business key), so RECON_KEY_SQL records that.
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql so an
-- existing database converges without re-running the whole seed. Idempotent:
-- a plain UPDATE to fixed values (re-run is a no-op), migration-log MERGE.
-- Touches only the one SalaryBases registry row; no DDL.

prompt == Repoint SalaryBases recon registry row to V2 ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/SalaryBases/DMT_SALARYBASES_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/SalaryBases/DMT_SALARYBASES_RECON_V2_RPT.xdo',
       NOTES               = 'Salary basis HDL base-table reconciliation (Contract v1). V2 (2026-10-08, backlog #292): '
                          || 'rows selected by the HDL request id, key map joined on each row''s own owner, '
                          || 'salary basis confirmed in CMP_SALARY_BASES. Deployed alongside V1, never overwriting it.',
       RECON_KEY_SQL       = 'TO_CHAR(TFM_SEQUENCE_ID) -- the .dat SourceSystemId'
where  BIP_REPORT_ID = 100000029
and    CEMLI_CODE    = 'SalaryBases';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-08_salarybases_recon_v2_registry.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'salbasreconv2', USER);

commit;
