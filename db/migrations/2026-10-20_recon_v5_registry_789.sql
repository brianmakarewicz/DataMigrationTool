-- Grants and MiscReceipts reconciliation report V5 registry repoint (backlog #789).
--
-- Points the Grants Contract v1 registry row (BIP_REPORT_ID 100000007) at
-- /Custom/DMT2/Grants/DMT_GRANT_RECON_V5_DM.xdm (V4 plus the eight remaining award
-- child tiers, each with its own Fusion id) and the MiscReceipts row at
-- /Custom/DMT2/MiscReceipts/DMT_INV_TRX_RECON_V5_DM.xdm (V4 plus a lot tier, each
-- lot with its own row-grain id). Both V5 reports are deployed ALONGSIDE V1-V4
-- (BIP objects are never overwritten).
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql (which also
-- carries the new child-tier auditor rows) so an existing database converges
-- without re-running the whole seed. Idempotent: a plain UPDATE to fixed values
-- (re-run is a no-op). Deploy as the schema owner:
--   python scripts/dmt_deploy.py table --create db/tables/dmt_bip_report_tbl.sql --migration <this file>
-- (the deploy tool logs it in DMT_MIGRATION_LOG); this header ends with a semicolon;

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Grants/DMT_GRANT_RECON_V5_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Grants/DMT_GRANT_RECON_V5_RPT.xdo'
where  BIP_REPORT_ID = 100000007
and    CEMLI_CODE    = 'Grants';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/MiscReceipts/DMT_INV_TRX_RECON_V5_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/MiscReceipts/DMT_INV_TRX_RECON_V5_RPT.xdo'
where  CEMLI_CODE    = 'MiscReceipts';

commit;
