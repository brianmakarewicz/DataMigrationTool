-- Expenditures reconciliation report V2 registry repoint (find rows by job id).
--
-- Points the Expenditures Contract v1 registry row at
-- /Custom/DMT2/Expenditures/DMT_EXP_RECON_V2_DM.xdm and its report
-- DMT_EXP_RECON_V2_RPT.xdo. V2 finds rows only by the work item's own Fusion
-- job ids (owner decision 2026-10-07): base expenditure items by
-- PJC_EXP_ITEMS_ALL.REQUEST_ID = the import job id, import rejections by
-- PJC_TXN_XFACE_ALL.REQUEST_ID = the import job id, and rows left in staging
-- by PJC_TXN_XFACE_STAGE_ALL.LOAD_REQUEST_ID = the load job id. V1 selected
-- rows with LIKE on the run prefix. V2 is deployed ALONGSIDE V1 (BIP objects
-- are never overwritten).
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql so an
-- existing database converges without re-running the whole seed. Idempotent:
-- a plain UPDATE to fixed values (re-run is a no-op), migration-log MERGE.
-- Touches only the Expenditures registry row; no DDL.

prompt == Repoint Expenditures recon registry row to V2 ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Expenditures/DMT_EXP_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Expenditures/DMT_EXP_RECON_V2_RPT.xdo',
       NOTES               = 'Project expenditure cost import reconciliation (Contract v1, nine-column). V2 (2026-10-07): '
                          || 'rows found only by the work item''s Fusion job ids (base by the import REQUEST_ID, '
                          || 'interface by the import REQUEST_ID and the load LOAD_REQUEST_ID), never by the run '
                          || 'prefix; called once per work item. Deployed alongside V1, never overwriting it.',
       RECON_KEY_SQL       = 'ORIG_TRANSACTION_REFERENCE -- run-prefixed native reference, survives verbatim onto the base row (report RECORD_KEY matched to TFM.RECON_KEY; a match key only, never a row selector)'
where  CEMLI_CODE = 'Expenditures';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-07_expenditures_recon_v2_registry.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'expreconv2', USER);

commit;
