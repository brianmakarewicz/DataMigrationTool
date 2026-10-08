-- ARInvoices reconciliation report V4 registry repoint (find rows by job id).
--
-- Points the ARInvoices Contract v1 registry row (BIP_REPORT_ID 100000001) at
-- /Custom/DMT2/ARInvoices/DMT_AR_RECON_V4_DM.xdm and its report
-- DMT_AR_RECON_V4_RPT.xdo. V4 finds rows only by the load's own Fusion job ids
-- (owner decision 2026-10-07): base lines by REQUEST_ID = the AutoInvoiceImportEss
-- request id, base distributions through their loaded line, interface rows and
-- errors by LOAD_REQUEST_ID = the load request id. V3 selected base lines with
-- LIKE on the run prefix. Keys, columns and keyset paging are unchanged from V3.
-- V4 is deployed ALONGSIDE V1-V3 (BIP objects are never overwritten).
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql so an
-- existing database converges without re-running the whole seed. Idempotent:
-- a plain UPDATE to fixed values (re-run is a no-op), migration-log MERGE.
-- Touches only the ARInvoices registry row; no DDL.

prompt == Repoint ARInvoices recon registry row to V4 ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/ARInvoices/DMT_AR_RECON_V4_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/ARInvoices/DMT_AR_RECON_V4_RPT.xdo',
       NOTES               = 'AR AutoInvoice import reconciliation (Contract v1, multi-tier). V4 (2026-10-07): '
                          || 'rows found only by the work item''s Fusion job ids (base lines by the '
                          || 'AutoInvoice import REQUEST_ID, interface rows and errors by LOAD_REQUEST_ID), '
                          || 'never by the run prefix; called with each load''s own ids. V3 made the line '
                          || 'RECORD_KEY ATTRIBUTE1/ATTRIBUTE2. Deployed alongside V1-V3, never overwriting them.'
where  BIP_REPORT_ID = 100000001
and    CEMLI_CODE    = 'ARInvoices';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-07_ar_invoices_recon_v4_registry.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'arreconv4', USER);

commit;
