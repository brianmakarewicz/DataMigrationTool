-- Requisitions reconciliation report V2 registry repoint (find rows by job id).
--
-- Points the Requisitions Contract v1 registry row and its two auditor rows
-- (Requisitions.Line, Requisitions.Distribution) at
-- /Custom/DMT2/Requisitions/DMT_REQ_RECON_V2_DM.xdm and its report
-- DMT_REQ_RECON_V2_RPT.xdo. V2 finds rows only by the work item's own Fusion
-- job ids (owner decision 2026-10-07): base headers and lines by
-- REQUEST_ID = the import job id, base distributions through their loaded line,
-- interface rows and import errors by LOAD_REQUEST_ID = the load job id AND
-- REQUEST_ID = the import job id. V1 selected rows with LIKE on the run prefix
-- and run id. V2 is deployed ALONGSIDE V1 (BIP objects are never overwritten).
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql so an
-- existing database converges without re-running the whole seed. Idempotent:
-- plain UPDATEs to fixed values (re-run is a no-op), migration-log MERGE.
-- Touches only the three Requisitions registry rows; no DDL.

prompt == Repoint Requisitions recon registry row to V2 ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Requisitions/DMT_REQ_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Requisitions/DMT_REQ_RECON_V2_RPT.xdo',
       NOTES               = 'Requisition import reconciliation (Contract v1, multi-tier). V2 (2026-10-07): '
                          || 'rows found only by the work item''s Fusion job ids (base by the import '
                          || 'REQUEST_ID, interface and errors by LOAD_REQUEST_ID + REQUEST_ID), never by '
                          || 'the run prefix or run id; called once per work item. Deployed alongside V1, '
                          || 'never overwriting it.'
where  CEMLI_CODE = 'Requisitions';

prompt == Repoint the Requisitions line and distribution auditor rows to V2 ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Requisitions/DMT_REQ_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Requisitions/DMT_REQ_RECON_V2_RPT.xdo'
where  CEMLI_CODE IN ('Requisitions.Line', 'Requisitions.Distribution');

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-07_requisitions_recon_v2_registry.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'reqreconv2', USER);

commit;
