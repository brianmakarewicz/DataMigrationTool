-- Customers reconciliation report V4 registry repoint (standards fix of PR #589).
--
-- V3 returned an ERROR row for every not-created interface row and, when the
-- row had no Fusion error of its own, composed a sentence from import status
-- codes and held parent rows. The reconciler stamped that sentence
-- [FUSION_ERROR] although Fusion never returned an error for the row. V4
-- returns an interface ERROR row only with the row's OWN HZ_IMP_ERRORS text;
-- every other not-created row is left for the shared unaccounted sweep.
--
-- Points the Customers Contract v1 registry row (BIP_REPORT_ID 100000012) and
-- the seven Customers.* record-type auditor rows (100000053..100000059) at the
-- new data model /Custom/DMT2/Customers/DMT_CUST_RECON_V4_DM.xdm and its report
-- DMT_CUST_RECON_V4_RPT.xdo. V4 is deployed ALONGSIDE V3 (BIP objects are never
-- overwritten); V3 stays in the catalog untouched.
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql so an
-- existing database converges without re-running the whole seed. Idempotent:
-- a plain UPDATE to fixed values (re-run is a no-op), migration-log MERGE.
-- Touches only the eight Customers registry rows named below; no DDL.

prompt == Repoint Customers recon registry rows to V4 ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Customers/DMT_CUST_RECON_V4_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Customers/DMT_CUST_RECON_V4_RPT.xdo'
where  BIP_REPORT_ID in (100000012, 100000053, 100000054, 100000055,
                         100000056, 100000057, 100000058, 100000059);

update DMT_BIP_REPORT_TBL
set    NOTES = 'Customer party import reconciliation (Contract v1). V4: an interface '
            || 'row is returned as ERROR only with its OWN HZ_IMP_ERRORS text (joined '
            || 'on error_id+batch_id, full FND_NEW_MESSAGES text with tokens); a row '
            || 'with no error of its own is not returned and falls to the unaccounted '
            || 'sweep. Replaces V3''s composed status-code sentences. Deployed alongside '
            || 'V3, V2 and v1, never overwriting them.'
where  BIP_REPORT_ID = 100000012
and    CEMLI_CODE    = 'Customers';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-07_customers_recon_v4_registry.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'custreconv4', USER);

commit;
