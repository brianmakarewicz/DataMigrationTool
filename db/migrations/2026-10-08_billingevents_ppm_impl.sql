-- BillingEvents runs as the Projects user ppm_impl (backlog #462, owner
-- decision 2026-10-08). Converges an EXISTING database with the committed seed
-- changes in db/seed/dmt_erp_interface_options_tbl.sql (row 68) and
-- db/seed/dmt_rest_lookup_tbl.sql (BillingEvents NOTES); the options seed skips
-- existing rows, so a seed re-run alone does not change them.
--
-- Before: row 68 had no FUSION_USERNAME, so DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS
-- fell back to the global user fin_impl, and Verify-in-Fusion on
-- /projectBillingEvents got HTTP 403 (fin_impl has no Projects billing role;
-- ppm_impl reads the event). Same pattern as Grants (row 57, PR #598): the load,
-- the ESS polls/downloads, reconciliation and the REST verify all resolve the
-- user AND password together from this one row.
--
-- The password is set to the mask ONLY when the row had no per-object user yet,
-- so a re-run never clobbers a password already filled in.
-- db/tools/setup_runtime_config.py (python scripts/ci_promote.py runtime-config)
-- then sets the real password from connections.json by username.
--
-- Idempotent: guarded fixed-value UPDATEs; migration-log MERGE. No DDL.
-- Touches only the BillingEvents rows.

prompt == BillingEvents: per-object Fusion user ppm_impl (row 68) ==
update DMT_ERP_INTERFACE_OPTIONS_TBL
set    FUSION_USERNAME = 'ppm_impl',
       FUSION_PASSWORD = '***MASKED-SET-ME***'
where  CEMLI_CODE = 'BillingEvents'
and    ERP_INTERFACE_OPTIONS_ID = 68
and    FUSION_USERNAME is null;

prompt == BillingEvents: REST verify notes name the ppm_impl user ==
update DMT_REST_LOOKUP_TBL
set    NOTES = 'projectBillingEvents queried by EventId = the Fusion event id reconciliation stamped (FUSION_EVENT_ID). The resource needs a Projects billing role: fin_impl gets HTTP 403, ppm_impl reads it, so BillingEvents runs as ppm_impl (its DMT_ERP_INTERFACE_OPTIONS_TBL row, resolved by GET_CEMLI_CREDENTIALS; backlog #462). Verified live on the demo pod 2026-10-08.'
where  OBJECT_TYPE = 'BillingEvents'
and    NOTES like '%fin_impl (the BillingEvents load user via GET_CEMLI_CREDENTIALS)%';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-08_billingevents_ppm_impl.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'billevppm462', USER);

commit;
