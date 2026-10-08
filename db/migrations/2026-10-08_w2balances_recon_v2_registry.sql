-- W2Balances reconciliation report V2 registry repoint (backlog #413; owner rule
-- 2026-10-07: reports find rows by Fusion job or batch id, never by the run
-- prefix).
--
-- V1 found the balance batch with PAY_BAL_BATCH_HEADERS.BATCH_NAME LIKE the run
-- prefix followed by anything. V2 finds it only by the exact BatchName the run's
-- generator wrote (the W2Balances TFM RECON_KEY: run prefix followed by the
-- work-queue id), passed as report parameter P_FUSION_BATCH_ID.
--
-- Points the W2Balances Contract v1 registry row (BIP_REPORT_ID 100000035) at
-- /Custom/DMT2/W2Balances/DMT_W2_BAL_RECON_V2_DM.xdm and its report
-- DMT_W2_BAL_RECON_V2_RPT.xdo. V2 is deployed ALONGSIDE V1 (BIP objects are
-- never overwritten).
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql so an
-- existing database converges without re-running the whole seed. Idempotent:
-- a plain UPDATE to fixed values (re-run is a no-op), migration-log MERGE.
-- Touches only the one W2Balances registry row; no DDL.

prompt == Repoint W2Balances recon registry row to V2 ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/W2Balances/DMT_W2_BAL_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/W2Balances/DMT_W2_BAL_RECON_V2_RPT.xdo',
       NOTES               = 'W2Balances HDL base-table reconciliation (Contract v1). V2: the batch is '
                          || 'selected by the exact BatchName the run wrote (P_FUSION_BATCH_ID: run '
                          || 'prefix followed by the work-queue id), never by a prefix match. '
                          || 'Deployed alongside V1, never overwriting it.',
       RECON_KEY_SQL       = 'run_prefix || work_queue_id  (the HDL BatchName)'
where  BIP_REPORT_ID = 100000035
and    CEMLI_CODE    = 'W2Balances';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-08_w2balances_recon_v2_registry.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'w2balreconv2', USER);

commit;
