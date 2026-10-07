-- ARInvoices reconciliation report V2 registry repoint (cross-grain propagation work).
--
-- Points the ARInvoices Contract v1 registry row (BIP_REPORT_ID 100000001) at
-- /Custom/DMT2/ARInvoices/DMT_AR_RECON_V2_DM.xdm and its report
-- DMT_AR_RECON_V2_RPT.xdo. V2 scopes both RA_INTERFACE_ERRORS_ALL aggregations
-- to the load's own interface lines / distributions. V1 grouped every error row
-- in the pod by INTERFACE_DISTRIBUTION_ID, and AutoInvoice writes some LINE
-- errors with INTERFACE_DISTRIBUTION_ID = 0, so one such error made the whole
-- report fail with ORA-01489 (run 246, load 10074714). Columns, keys and
-- parameters are unchanged. V2 is deployed ALONGSIDE V1 (BIP objects are never
-- overwritten); V1 stays in the catalog untouched.
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql so an
-- existing database converges without re-running the whole seed. Idempotent:
-- a plain UPDATE to fixed values (re-run is a no-op), migration-log MERGE.
-- Touches only the ARInvoices registry row; no DDL.

prompt == Repoint ARInvoices recon registry row to V2 ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/ARInvoices/DMT_AR_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/ARInvoices/DMT_AR_RECON_V2_RPT.xdo',
       NOTES               = 'AR AutoInvoice import reconciliation (Contract v1, multi-tier). V2 (2026-10-07): '
                          || 'interface error aggregation scoped to the load (V1 hit ORA-01489); '
                          || 'deployed alongside V1, never overwriting it.'
where  BIP_REPORT_ID = 100000001
and    CEMLI_CODE    = 'ARInvoices';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-07_ar_invoices_recon_v2_registry.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'arreconv2', USER);

commit;
