-- Customers reconciliation report V3 registry repoint (run 236 findings R1,
-- docs/findings/run236_Customers_Items_unaccounted.md).
--
-- Points the Customers Contract v1 registry row (BIP_REPORT_ID 100000012) and
-- the seven Customers.* record-type auditor rows (100000053..100000059) at the
-- new data model /Custom/DMT2/Customers/DMT_CUST_RECON_V3_DM.xdm and its report
-- DMT_CUST_RECON_V3_RPT.xdo. V3 is deployed ALONGSIDE V2 (BIP objects are never
-- overwritten); V2 stays in the catalog untouched.
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql so an
-- existing database converges without re-running the whole seed. Idempotent:
-- a plain UPDATE to fixed values (re-run is a no-op), migration-log MERGE.
-- Touches only DMT_BIP_REPORT_TBL rows whose CEMLI_CODE is Customers or
-- Customers.*; no DDL, no other object's registry row.

prompt == Repoint Customers recon registry rows to V3 ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Customers/DMT_CUST_RECON_V3_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Customers/DMT_CUST_RECON_V3_RPT.xdo'
where  (CEMLI_CODE = 'Customers' or CEMLI_CODE like 'Customers.%')
and    BIP_REPORT_ID in (100000012, 100000053, 100000054, 100000055,
                         100000056, 100000057, 100000058, 100000059);

update DMT_BIP_REPORT_TBL
set    NOTES = 'Customer party import reconciliation (Contract v1). V3: every interface '
            || 'row carries its OWN outcome (own HZ_IMP_ERRORS row joined on '
            || 'error_id+batch_id, full FND_NEW_MESSAGES text with tokens; or, for a '
            || 'held/cascaded row with no error of its own, the failed parent chain '
            || 'from the same load). Replaces V2''s batch-wide message LISTAGG (run 236 '
            || 'findings R1). Deployed alongside V2 and v1, never overwriting them.'
where  BIP_REPORT_ID = 100000012
and    CEMLI_CODE    = 'Customers';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-06_customers_recon_v3_registry.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'custreconv3', USER);

commit;
