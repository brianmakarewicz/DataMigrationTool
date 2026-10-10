-- Grants reconciliation report V4 registry repoint (backlog #671).
--
-- Points the Grants Contract v1 registry row (BIP_REPORT_ID 100000007) at
-- /Custom/DMT2/Grants/DMT_GRANT_RECON_V4_DM.xdm and its report
-- DMT_GRANT_RECON_V4_RPT.xdo. V4 keeps the award tiers of V3 and also returns
-- the keyword, term, certification, CFDA, reference and task burden schedule
-- rows of the awards it confirms (only those Fusion created while the run's
-- import job ran), each with its own Fusion id, paged by award (PAGE_KEY).
-- V4 is deployed ALONGSIDE V1-V3 (BIP objects are never overwritten).
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql so an
-- existing database converges without re-running the whole seed. Idempotent:
-- a plain UPDATE to fixed values (re-run is a no-op). Touches only the Grants
-- registry row. Deploy as the schema owner:
--   python scripts/dmt_deploy.py table --create db/tables/dmt_bip_report_tbl.sql --migration <this file>
-- (the deploy tool logs it in DMT_MIGRATION_LOG); this header ends with a semicolon;

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Grants/DMT_GRANT_RECON_V4_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Grants/DMT_GRANT_RECON_V4_RPT.xdo'
where  BIP_REPORT_ID = 100000007
and    CEMLI_CODE    = 'Grants';

commit;
