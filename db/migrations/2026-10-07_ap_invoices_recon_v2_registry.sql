-- APInvoices reconciliation report V2 registry repoint (backlog #166).
--
-- Points the APInvoices Contract v1 registry row and the APInvoices.Line
-- auditor row (100000047) at /Custom/DMT2/APInvoices/DMT_AP_RECON_V2_DM.xdm and
-- its report DMT_AP_RECON_V2_RPT.xdo. V2 finds rows by Fusion job id only (base
-- rows by the Payables Import REQUEST_ID, interface rows and their rejections by
-- LOAD_REQUEST_ID, never by the run prefix) and returns only real
-- AP_INTERFACE_REJECTIONS text: V1's composed "Rejected by Payables Import
-- (status=...)" and "Parent invoice rejected:" strings are gone. Rows Payables
-- rejected with their invoice get the quoted error from
-- DMT_AP_RESULTS_PKG.PROPAGATE_DOCUMENT_ERRORS. V2 is deployed ALONGSIDE V1
-- (BIP objects are never overwritten).
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql so an
-- existing database converges without re-running the whole seed. Idempotent:
-- a plain UPDATE to fixed values (re-run is a no-op), migration-log MERGE.
-- Touches only the two APInvoices registry rows; no DDL.

prompt == Repoint APInvoices recon registry rows to V2 ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/APInvoices/DMT_AP_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/APInvoices/DMT_AP_RECON_V2_RPT.xdo',
       NOTES               = 'AP invoice import reconciliation (Contract v1, multi-tier). V2 (2026-10-07): '
                          || 'rows found by Fusion job id only (base by import REQUEST_ID, interface and '
                          || 'rejections by LOAD_REQUEST_ID); only real AP_INTERFACE_REJECTIONS text; '
                          || 'deployed alongside V1, never overwriting it.'
where  CEMLI_CODE = 'APInvoices';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/APInvoices/DMT_AP_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/APInvoices/DMT_AP_RECON_V2_RPT.xdo'
where  CEMLI_CODE = 'APInvoices.Line';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-07_ap_invoices_recon_v2_registry.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'apreconv2', USER);

commit;
