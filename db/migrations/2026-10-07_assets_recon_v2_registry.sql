-- Assets reconciliation report V2 registry repoint (find rows by job id).
--
-- Points the Assets Contract v1 registry row and its two auditor rows
-- (Assets.Book, Assets.Assignment) at
-- /Custom/DMT2/Assets/DMT_FA_ASSET_RECON_V2_DM.xdm and its report
-- DMT_FA_ASSET_RECON_V2_RPT.xdo. V2 finds rows only by the work item's load job
-- id (owner decision 2026-10-07): FA_ADDITIONS_B has no request id, so base
-- assets and their distributions are found through the POSTED FA_MASS_ADDITIONS
-- row of the load (LOAD_REQUEST_ID = the load job id, ASSET_ID = the created
-- asset), and interface rejections by LOAD_REQUEST_ID. V1 selected base assets
-- with LIKE on the run prefix. V2 is deployed ALONGSIDE V1 (BIP objects are never
-- overwritten).
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql so an
-- existing database converges without re-running the whole seed. Idempotent:
-- plain UPDATEs to fixed values (re-run is a no-op), migration-log MERGE.
-- Touches only the three Assets registry rows; no DDL.

prompt == Repoint Assets recon registry row to V2 ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Assets/DMT_FA_ASSET_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Assets/DMT_FA_ASSET_RECON_V2_RPT.xdo',
       NOTES               = 'Fixed asset mass additions reconciliation (Contract v1, single ASSET tier; book/assignment cascade; SQL*Loader all-or-nothing preserved). '
                          || 'V2 (2026-10-07): rows found only by the work item''s load job id (base assets through their POSTED '
                          || 'FA_MASS_ADDITIONS row, interface by LOAD_REQUEST_ID), never by the run prefix; deployed alongside V1.'
where  CEMLI_CODE = 'Assets';

prompt == Repoint the Assets book and assignment auditor rows to V2 ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Assets/DMT_FA_ASSET_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Assets/DMT_FA_ASSET_RECON_V2_RPT.xdo'
where  CEMLI_CODE IN ('Assets.Book', 'Assets.Assignment');

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-07_assets_recon_v2_registry.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'assetreconv2', USER);

commit;
