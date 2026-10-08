-- BillingEvents reconciliation report V2 registry repoint (find rows by job id).
--
-- Points the BillingEvents Contract v1 registry row at
-- /Custom/DMT2/BillingEvents/DMT_BILLING_EVENT_RECON_V2_DM.xdm and its report
-- DMT_BILLING_EVENT_RECON_V2_RPT.xdo. V2 finds rows only by the work item's
-- Fusion job ids (owner decision 2026-10-07): base events by
-- PJB_BILLING_EVENTS.REQUEST_ID = the Import Billing Events job id, interface
-- rows by LOAD_REQUEST_ID = the load job id. V1 selected base events with LIKE on
-- the run prefix. V2 is deployed ALONGSIDE V1 (BIP objects are never overwritten).
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql so an
-- existing database converges without re-running the whole seed. Idempotent:
-- a plain UPDATE to fixed values (re-run is a no-op), migration-log MERGE.
-- Touches only the BillingEvents registry row; no DDL.

prompt == Repoint BillingEvents recon registry row to V2 ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/BillingEvents/DMT_BILLING_EVENT_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/BillingEvents/DMT_BILLING_EVENT_RECON_V2_RPT.xdo',
       NOTES               = 'Project billing event import reconciliation (Contract v1 -- nine columns, keyset; interface tier is the #IMPORT_REPORT# no-carrier special case). '
                          || 'V2 (2026-10-07): rows found only by the work item''s Fusion job ids (base by the import REQUEST_ID, '
                          || 'interface by LOAD_REQUEST_ID), never by the run prefix; deployed alongside V1.'
where  CEMLI_CODE = 'BillingEvents';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-07_billing_events_recon_v2_registry.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'bereconv2', USER);

commit;
