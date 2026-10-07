-- ARInvoices reconciliation report V3 registry repoint (keyset paging fix).
--
-- Points the ARInvoices Contract v1 registry row (BIP_REPORT_ID 100000001) at
-- /Custom/DMT2/ARInvoices/DMT_AR_RECON_V3_DM.xdm and its report
-- DMT_AR_RECON_V3_RPT.xdo. V3 keys each LINE row on
-- INTERFACE_LINE_ATTRIBUTE1 || '/' || INTERFACE_LINE_ATTRIBUTE2, unique per line.
-- V2 keyed lines on ATTRIBUTE1 alone, which every line of one DMT invoice
-- shares, so a keyset page boundary inside a run of equal keys dropped rows
-- (the shared fetch asks for keys strictly greater than the last one received).
-- Ordering and the keyset comparison are pinned to BINARY. V3 is deployed
-- ALONGSIDE V1 and V2 (BIP objects are never overwritten).
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql so an
-- existing database converges without re-running the whole seed. Idempotent:
-- a plain UPDATE to fixed values (re-run is a no-op), migration-log MERGE.
-- Touches only the ARInvoices registry row; no DDL.

prompt == Repoint ARInvoices recon registry row to V3 ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/ARInvoices/DMT_AR_RECON_V3_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/ARInvoices/DMT_AR_RECON_V3_RPT.xdo',
       NOTES               = 'AR AutoInvoice import reconciliation (Contract v1, multi-tier). V3 (2026-10-07): '
                          || 'line RECORD_KEY = ATTRIBUTE1/ATTRIBUTE2, unique per line, so keyset paging '
                          || 'never drops a row; V2 scoped interface errors to the load. Deployed alongside '
                          || 'V1 and V2, never overwriting them.',
       RECON_KEY_SQL       = 'multi-tier: lines=INTERFACE_LINE_ATTRIBUTE1||''/''||INTERFACE_LINE_ATTRIBUTE2 '
                          || '(run-prefixed invoice key / line id, unique per line, report V3); '
                          || 'dists=INTERFACE_LINE_ATTRIBUTE1||'':''||ACCOUNT_CLASS||'':''||ROW_NUMBER() OVER '
                          || '(PARTITION BY parent_line_key,account_class ORDER BY amount,acctd_amount,percent,dist_id) '
                          || '(parent line key + per-distribution ordinal discriminator, transitive)'
where  BIP_REPORT_ID = 100000001
and    CEMLI_CODE    = 'ARInvoices';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-07_ar_invoices_recon_v3_registry.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'arreconv3', USER);

commit;
