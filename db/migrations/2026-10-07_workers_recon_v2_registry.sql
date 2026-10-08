-- Workers reconciliation report V2 registry repoint (backlog #289).
--
-- Points the Workers Contract v1 registry row (BIP_REPORT_ID 100000027) at
-- /Custom/DMT2/Workers/DMT_WORKERS_RECON_V2_DM.xdm and its report
-- DMT_WORKERS_RECON_V2_RPT.xdo. V2 selects rows by the HDL request id (never the
-- run prefix), joins the key map on each row's own SourceSystemOwner, and proves
-- every person component (name, email, phone, address, national identifier,
-- legislative data) on its own key-map row and base table, so each component TFM
-- row is LOADED from its own proof. V2 is deployed ALONGSIDE V1 (BIP objects are
-- never overwritten).
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql so an
-- existing database converges without re-running the whole seed. Idempotent: a
-- plain UPDATE to fixed values, migration-log MERGE. No DDL.

prompt == Repoint Workers recon registry row to V2 ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Workers/DMT_WORKERS_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Workers/DMT_WORKERS_RECON_V2_RPT.xdo',
       NOTES               = 'Worker HDL base-table reconciliation (Contract v1). V2 (2026-10-07, backlog #289): '
                          || 'rows selected by the HDL request id; every person component (name, email, '
                          || 'phone, address, national id, legislative data) proven on its own key-map '
                          || 'row and base table. Deployed alongside V1, never overwriting it.'
where  BIP_REPORT_ID = 100000027
and    CEMLI_CODE    = 'Workers';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-07_workers_recon_v2_registry.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'wkrreconv2', USER);

commit;
