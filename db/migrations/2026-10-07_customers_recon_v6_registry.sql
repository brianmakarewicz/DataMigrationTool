-- Customers reconciliation report V6 registry repoint (owner rule 2026-10-07:
-- reports find rows by Fusion job or batch id, never by the run prefix).
--
-- V5 selected every base tier by a run-prefix pattern match on
-- HZ_ORIG_SYS_REFERENCES.ORIG_SYSTEM_REFERENCE. V6 selects each HZ base table by
-- REQUEST_ID equal to the Fusion import batch id the load sent (report parameter
-- P_FUSION_BATCH_ID; DMT sends the run prefix followed by the source batch id and
-- the customer bulk import copies it into REQUEST_ID on every HZ base row).
-- Interface rows are still selected by LOAD_REQUEST_ID. Error text, keys and
-- keyset paging are V5 unchanged.
--
-- Points the Customers Contract v1 registry row (BIP_REPORT_ID 100000012) and
-- the seven Customers.* record-type auditor rows (100000053..100000059) at the
-- new data model /Custom/DMT2/Customers/DMT_CUST_RECON_V6_DM.xdm and its report
-- DMT_CUST_RECON_V6_RPT.xdo. V6 is deployed ALONGSIDE V5 (BIP objects are never
-- overwritten); V5 and older stay in the catalog untouched.
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql so an
-- existing database converges without re-running the whole seed. Idempotent:
-- a plain UPDATE to fixed values (re-run is a no-op), migration-log MERGE.
-- Touches only the eight Customers registry rows named below; no DDL.

prompt == Repoint Customers recon registry rows to V6 ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Customers/DMT_CUST_RECON_V6_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Customers/DMT_CUST_RECON_V6_RPT.xdo'
where  BIP_REPORT_ID in (100000012, 100000053, 100000054, 100000055,
                         100000056, 100000057, 100000058, 100000059);

update DMT_BIP_REPORT_TBL
set    NOTES = 'Customer party import reconciliation (Contract v1). V6: base rows are '
            || 'selected by REQUEST_ID equal to the Fusion import batch id the load '
            || 'sent (P_FUSION_BATCH_ID: run prefix followed by the source batch id), '
            || 'never by a prefix match. An interface row is returned as ERROR only '
            || 'with its OWN HZ_IMP_ERRORS text; a row with no error of its own is not '
            || 'returned. Deployed alongside V5, V4, V3, V2 and v1, never overwriting '
            || 'them.'
where  BIP_REPORT_ID = 100000012
and    CEMLI_CODE    = 'Customers';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-07_customers_recon_v6_registry.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'custreconv6', USER);

commit;
