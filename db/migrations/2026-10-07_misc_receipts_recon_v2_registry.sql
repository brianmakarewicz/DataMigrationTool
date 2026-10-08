-- MiscReceipts reconciliation report V2 registry repoint (find rows by job id).
--
-- Points the MiscReceipts Contract v1 registry row at
-- /Custom/DMT2/MiscReceipts/DMT_INV_TRX_RECON_V2_DM.xdm and its report
-- DMT_INV_TRX_RECON_V2_RPT.xdo. V2 finds rows only by the work item's own
-- Fusion load job id (owner decision 2026-10-07, backlog #262): posted
-- transactions by INV_MATERIAL_TXNS.LOAD_REQUEST_ID, rejections by
-- INV_TRANSACTIONS_INTERFACE.LOAD_REQUEST_ID (PROCESS_FLAG = 3), serials
-- through a transaction of that load. V1 selected rows by the
-- 'DMT-' || run id TRANSACTION_REFERENCE. V2 is deployed ALONGSIDE V1 (BIP
-- objects are never overwritten).
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql so an
-- existing database converges without re-running the whole seed. Idempotent:
-- a plain UPDATE to fixed values (re-run is a no-op), migration-log MERGE.
-- Touches only the MiscReceipts registry row; no DDL.

prompt == Repoint MiscReceipts recon registry row to V2 ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/MiscReceipts/DMT_INV_TRX_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/MiscReceipts/DMT_INV_TRX_RECON_V2_RPT.xdo',
       NOTES               = 'Miscellaneous receiving receipt import reconciliation (Contract v1, single-tier). '
                          || 'V2 (2026-10-07): rows found only by the work item''s Fusion load job id '
                          || '(LOAD_REQUEST_ID on the posted transaction and the rejected interface row), never by '
                          || 'the run id. Deployed alongside V1, never overwriting it.'
where  CEMLI_CODE = 'MiscReceipts';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-07_misc_receipts_recon_v2_registry.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'mrreconv2', USER);

commit;
