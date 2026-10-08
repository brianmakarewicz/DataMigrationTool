-- Items reconciliation report V3 registry repoint (find rows by job id).
--
-- Points the Items Contract v1 registry row at
-- /Custom/DMT2/Items/DMT_ITEM_RECON_V3_DM.xdm and its report
-- DMT_ITEM_RECON_V3_RPT.xdo. V3 finds rows only by the work item's own Fusion
-- job ids (owner decision 2026-10-07): base items (EGP_SYSTEM_ITEMS_B) and base
-- category assignments (EGP_ITEM_CATEGORIES) by REQUEST_ID = the Item Import
-- job id; interface rows and EGP_IMPORT_ERRORS by LOAD_REQUEST_ID = the load job
-- id or REQUEST_ID = the import job id. V2 selected item master rows with LIKE on
-- the run prefix and kept a prefix arm on both category tiers. V3 is deployed
-- ALONGSIDE V1 and V2 (BIP objects are never overwritten).
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql so an
-- existing database converges without re-running the whole seed. Idempotent:
-- a plain UPDATE to fixed values (re-run is a no-op), migration-log MERGE.
-- Touches only the Items registry row; no DDL.

prompt == Repoint Items recon registry row to V3 ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Items/DMT_ITEM_RECON_V3_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Items/DMT_ITEM_RECON_V3_RPT.xdo',
       NOTES               = 'Item Import base-table reconciliation (Contract v1 -- nine columns, '
                          || 'keyset). ONE report, two record types via OBJECT_TYPE: Item '
                          || '(DMT_EGP_ITEM_TFM_TBL <- EGP_SYSTEM_ITEMS_B) and ItemCategory '
                          || '(DMT_EGP_ITEM_CAT_TFM_TBL <- EGP_ITEM_CATEGORIES). V3 (2026-10-07): '
                          || 'rows found only by the work item''s Fusion job ids (base by the Item '
                          || 'Import REQUEST_ID, interface and errors by LOAD_REQUEST_ID or REQUEST_ID), '
                          || 'never by the run prefix; deployed alongside V1 and V2.'
where  CEMLI_CODE = 'Items';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-07_items_recon_v3_registry.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'itemreconv3', USER);

commit;
