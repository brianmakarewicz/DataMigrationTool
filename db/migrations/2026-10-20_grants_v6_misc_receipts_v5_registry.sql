-- Grants recon report V6 and MiscReceipts recon report V5 registry repoint
-- (backlog #789, #240 / #768).
--
-- Points the Grants Contract v1 registry row (BIP_REPORT_ID 100000007) at
-- /Custom/DMT2/Grants/DMT_GRANT_RECON_V6_DM.xdm (V4 plus the eight remaining award
-- child tiers, each with its own Fusion id, and awards found by the import job's
-- window instead of the prefix: approved exception, backlog #240 / #768) and the MiscReceipts row at
-- /Custom/DMT2/MiscReceipts/DMT_INV_TRX_RECON_V5_DM.xdm (V4 plus a lot tier, each
-- lot with its own row-grain id). Both are deployed ALONGSIDE the earlier versions
-- (BIP objects are never overwritten).
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql (which also
-- carries the new child-tier auditor rows) so an existing database converges
-- without re-running the whole seed. Idempotent: a plain UPDATE to fixed values
-- (re-run is a no-op). Deploy as the schema owner:
--   python scripts/dmt_deploy.py table --create db/tables/dmt_bip_report_tbl.sql --migration <this file>
-- (the deploy tool logs it in DMT_MIGRATION_LOG); this header ends with a semicolon;

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Grants/DMT_GRANT_RECON_V6_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Grants/DMT_GRANT_RECON_V6_RPT.xdo'
where  BIP_REPORT_ID = 100000007
and    CEMLI_CODE    = 'Grants';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/MiscReceipts/DMT_INV_TRX_RECON_V5_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/MiscReceipts/DMT_INV_TRX_RECON_V5_RPT.xdo'
where  CEMLI_CODE    = 'MiscReceipts';

commit;
