-- ItemCategories registry row: re-point off the retired report (backlog #480).
--
-- Item categories are not a separate pipeline object: they ride in the Items
-- FBDI zip and are reconciled by the Items report V3 (record type ItemCategory,
-- DMT_EGP_ITEM_RESULTS_PKG.APPLY_CONTRACT_V1_ITEMS). Row 100000026 still named
-- the retired /Custom/DMT2/ItemCategories/ITEM_CAT_DM.xdm / ITEM_CAT_RPT.xdo,
-- whose reconciler DMT_EGP_ITEM_CAT_RESULTS_PKG no pipeline, queue or reconcile
-- path calls. The row now names the live Items V3 report. No Fusion object is
-- touched (the V3 report is already deployed under /Custom/DMT2/Items/).
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql so an
-- existing database converges without re-running the whole seed. Idempotent:
-- a plain UPDATE to fixed values (re-run is a no-op), migration-log MERGE.
-- Touches only the ItemCategories registry row; no DDL.

prompt == Repoint ItemCategories registry row to the Items V3 report ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Items/DMT_ITEM_RECON_V3_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Items/DMT_ITEM_RECON_V3_RPT.xdo',
       NOTES               = 'Item categories reconcile through the Items report V3 '
                          || '(record type ItemCategory); the ItemCategories ITEM_CAT_DM / '
                          || 'ITEM_CAT_RPT pair is retired (backlog #480).'
where  CEMLI_CODE = 'ItemCategories';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-08_itemcategories_registry_repoint.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'itemcatrepoint', USER);

commit;
