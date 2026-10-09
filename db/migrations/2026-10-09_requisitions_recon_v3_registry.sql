-- Requisitions reconciliation report V3 registry repoint (backlog #621).
--
-- Points the Requisitions Contract v1 registry row and its two auditor rows
-- (Requisitions.Line, Requisitions.Distribution) at
-- /Custom/DMT2/Requisitions/DMT_REQ_RECON_V3_DM.xdm and its report
-- DMT_REQ_RECON_V3_RPT.xdo. V3 returns the same rows and the same nine
-- columns as V2 (rows found only by the work item's Fusion job ids). It
-- changes only the keyset paging: since backlog #218 the line RECORD_KEY is
-- the line TFM id (all digits), so a numeric source requisition number, once
-- prefixed, can equal a line key. With the strict "> P_AFTER_KEY" cursor of
-- V2, two equal keys straddling a page boundary would lose one row. V3 keeps
-- every row tied on the page's last RECORD_KEY on that page (FETCH FIRST ...
-- WITH TIES) and orders rows by RECORD_KEY, then OBJECT_TYPE. V1 and V2 stay
-- deployed (BIP objects are never overwritten).
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql so an
-- existing database converges without re-running the whole seed. Idempotent:
-- plain UPDATEs to fixed values (re-run is a no-op), migration-log MERGE.
-- Touches only the three Requisitions registry rows; no DDL.

prompt == Repoint Requisitions recon registry row to V3 ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Requisitions/DMT_REQ_RECON_V3_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Requisitions/DMT_REQ_RECON_V3_RPT.xdo',
       NOTES               = 'Requisition import reconciliation (Contract v1, multi-tier). V2 (2026-10-07): '
                          || 'rows found only by the work item''s Fusion job ids (base by the import '
                          || 'REQUEST_ID, interface and errors by LOAD_REQUEST_ID + REQUEST_ID), never by '
                          || 'the run prefix or run id; called once per work item. V3 (2026-10-09): tie-safe '
                          || 'keyset paging (WITH TIES, OBJECT_TYPE tiebreak). Deployed alongside V1 and V2, '
                          || 'never overwriting them.'
where  CEMLI_CODE = 'Requisitions';

prompt == Repoint the Requisitions line and distribution auditor rows to V3 ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Requisitions/DMT_REQ_RECON_V3_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Requisitions/DMT_REQ_RECON_V3_RPT.xdo'
where  CEMLI_CODE IN ('Requisitions.Line', 'Requisitions.Distribution');

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-09_requisitions_recon_v3_registry.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'reqreconv3', USER);

commit;
