-- ARInvoices reconciliation report V5 registry repoint (header paging, line id).
--
-- Points the ARInvoices Contract v1 registry row (BIP_REPORT_ID 100000001) at
-- /Custom/DMT2/ARInvoices/DMT_AR_RECON_V5_DM.xdm and its report
-- DMT_AR_RECON_V5_RPT.xdo, and sets FUSION_ID_COLUMN to the line's row-grain id
-- FUSION_CUSTOMER_TRX_LINE_ID (added to DMT_RA_LINES_TFM_TBL by the guarded ALTER
-- in db/tables/dmt_ra_lines_tfm_tbl.sql, which db/install.sql runs first).
-- V5 pages on header boundaries (owner direction 2026-10-09, backlog #224): each
-- page is the next BIP_CHUNK_SIZE DMT invoices plus every line and distribution
-- row of them, so no fixed rows-per-sent-row allowance can cut a document short.
-- A loaded line's FUSION_ID is CUSTOMER_TRX_ID~CUSTOMER_TRX_LINE_ID (backlog #85).
-- Row selection by the load's Fusion job ids is unchanged from V4. V5 is
-- deployed ALONGSIDE V1-V4 (BIP objects are never overwritten).
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql so an
-- existing database converges without re-running the whole seed. Idempotent:
-- a plain UPDATE to fixed values (re-run is a no-op), migration-log MERGE.
-- Touches only the ARInvoices registry row; no DDL.

prompt == Repoint ARInvoices recon registry row to V5 ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/ARInvoices/DMT_AR_RECON_V5_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/ARInvoices/DMT_AR_RECON_V5_RPT.xdo',
       FUSION_ID_COLUMN    = 'FUSION_CUSTOMER_TRX_LINE_ID',
       NOTES               = 'AR AutoInvoice import reconciliation (Contract v1, multi-tier). V5 (2026-10-09): '
                          || 'pages by header: each page is the next BIP_CHUNK_SIZE DMT invoices plus every '
                          || 'line and distribution of them (PAGE_KEY = invoice key, backlog #224); a loaded '
                          || 'line returns CUSTOMER_TRX_ID~CUSTOMER_TRX_LINE_ID (backlog #85). V4 found rows '
                          || 'only by the work item''s Fusion job ids, never by the run prefix. Deployed '
                          || 'alongside V1-V4, never overwriting them.'
where  BIP_REPORT_ID = 100000001
and    CEMLI_CODE    = 'ARInvoices';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-09_ar_invoices_recon_v5_registry.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'arreconv5', USER);

commit;
