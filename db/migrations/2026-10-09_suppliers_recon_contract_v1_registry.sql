-- Supplier family reconciliation reports V2 registry repoint (backlog #217).
--
-- Points the five supplier-family registry rows (Suppliers, SupplierAddresses,
-- SupplierSites, SupplierSiteAssignments, SupplierContacts) at their new
-- Contract v1 nine-column reports /Custom/DMT2/<Object>/DMT_SUP*_RECON_V2_DM.xdm
-- and sets CONTRACT_VERSION = 1, which the shared fetch
-- DMT_RECON_CONTRACT_PKG.FETCH_ROWS requires, plus RECON_KEY_SQL (the
-- '~'-joined business key each reconciler matches RECORD_KEY against). The V1
-- reports SUP_*_DM stay deployed (BIP objects are never overwritten).
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql so an
-- existing database converges without re-running the whole seed. Idempotent:
-- plain UPDATEs to fixed values (re-run is a no-op), migration-log MERGE.
-- Touches only the five supplier registry rows; no DDL.

prompt == Repoint Suppliers recon registry row to V2 (Contract v1) ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Suppliers/DMT_SUP_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Suppliers/DMT_SUP_RECON_V2_RPT.xdo',
       CONTRACT_VERSION    = 1,
       RECON_KEY_SQL       = q'[VENDOR_NAME || '~' || SEGMENT1]',
       NOTES               = 'Supplier header import reconciliation (Contract v1, nine-column, keyset). V2 (2026-10-09, backlog #217): rows found only by the load job id (interface LOAD_REQUEST_ID; base row reached from the interface row); RECORD_KEY = SOURCE_REF = the business key VENDOR_NAME~SEGMENT1. Deployed alongside V1 (SUP_DM), never overwriting it.'
where  CEMLI_CODE = 'Suppliers';

prompt == Repoint SupplierAddresses recon registry row to V2 (Contract v1) ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/SupplierAddresses/DMT_SUP_ADDR_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/SupplierAddresses/DMT_SUP_ADDR_RECON_V2_RPT.xdo',
       CONTRACT_VERSION    = 1,
       RECON_KEY_SQL       = q'[VENDOR_NAME || '~' || PARTY_SITE_NAME]',
       NOTES               = 'Supplier address import reconciliation (Contract v1, nine-column, keyset). V2 (2026-10-09, backlog #217): rows found only by the load job id (interface LOAD_REQUEST_ID; base row reached from the interface row); RECORD_KEY = SOURCE_REF = the business key VENDOR_NAME~PARTY_SITE_NAME. Deployed alongside V1 (SUP_ADDR_DM), never overwriting it.'
where  CEMLI_CODE = 'SupplierAddresses';

prompt == Repoint SupplierSites recon registry row to V2 (Contract v1) ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/SupplierSites/DMT_SUP_SITE_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/SupplierSites/DMT_SUP_SITE_RECON_V2_RPT.xdo',
       CONTRACT_VERSION    = 1,
       RECON_KEY_SQL       = q'[VENDOR_NAME || '~' || VENDOR_SITE_CODE]',
       NOTES               = 'Supplier site import reconciliation (Contract v1, nine-column, keyset). V2 (2026-10-09, backlog #217): rows found only by the load job id (interface LOAD_REQUEST_ID; base row reached from the interface row); RECORD_KEY = SOURCE_REF = the business key VENDOR_NAME~VENDOR_SITE_CODE. Deployed alongside V1 (SUP_SITE_DM), never overwriting it.'
where  CEMLI_CODE = 'SupplierSites';

prompt == Repoint SupplierSiteAssignments recon registry row to V2 (Contract v1) ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/SupplierSiteAssignments/DMT_SUP_SITE_ASSN_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/SupplierSiteAssignments/DMT_SUP_SITE_ASSN_RECON_V2_RPT.xdo',
       CONTRACT_VERSION    = 1,
       RECON_KEY_SQL       = q'[VENDOR_NAME || '~' || VENDOR_SITE_CODE || '~' || BUSINESS_UNIT_NAME]',
       NOTES               = 'Supplier site assignment import reconciliation (Contract v1, nine-column, keyset). V2 (2026-10-09, backlog #217): rows found only by the load job id (interface LOAD_REQUEST_ID; base row reached from the interface row); RECORD_KEY = SOURCE_REF = the business key VENDOR_NAME~VENDOR_SITE_CODE~BUSINESS_UNIT_NAME. Deployed alongside V1 (SUP_SITE_ASSN_DM), never overwriting it.'
where  CEMLI_CODE = 'SupplierSiteAssignments';

prompt == Repoint SupplierContacts recon registry row to V2 (Contract v1) ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/SupplierContacts/DMT_SUP_CONT_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/SupplierContacts/DMT_SUP_CONT_RECON_V2_RPT.xdo',
       CONTRACT_VERSION    = 1,
       RECON_KEY_SQL       = q'[VENDOR_NAME || '~' || FIRST_NAME || '~' || LAST_NAME]',
       NOTES               = 'Supplier contact import reconciliation (Contract v1, nine-column, keyset). V2 (2026-10-09, backlog #217): rows found only by the load job id (interface LOAD_REQUEST_ID; base row reached from the interface row); RECORD_KEY = SOURCE_REF = the business key VENDOR_NAME~FIRST_NAME~LAST_NAME. Deployed alongside V1 (SUP_CONT_DM), never overwriting it.'
where  CEMLI_CODE = 'SupplierContacts';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-09_suppliers_recon_contract_v1_registry.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'supreconv2', USER);

commit;
