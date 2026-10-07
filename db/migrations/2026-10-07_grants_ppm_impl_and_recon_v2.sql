-- Grants (Award import) known-good fixes (docs/findings/known_good_Grants.md,
-- PR #598). Converges an EXISTING database with the committed seed changes in
-- db/seed/dmt_erp_interface_options_tbl.sql and db/seed/dmt_bip_report_tbl.sql
-- (both seeds skip existing rows, so a seed re-run alone does not change them).
--
-- 1. Per-object Fusion user for Grants: interface options row 57 gets
--    FUSION_USERNAME 'ppm_impl'. Submitting as FIN_IMPL makes Fusion reject every
--    award with "requisite setup steps haven't been completed"; the same data
--    loads as PPM_IMPL. The password is set to the mask ONLY when the row had no
--    per-object user yet (so a re-run never clobbers a password already filled
--    in). db/tools/setup_runtime_config.py then sets the real password from
--    connections.json by username, exactly as for the calvin.roth / scm_impl rows.
--
-- 2. Grants recon registry row 100000007 repointed to the V2 data model
--    /Custom/DMT2/Grants/DMT_GRANT_RECON_V2_DM.xdm (+ report V2_RPT.xdo), keyed
--    on OKC_K_HEADERS_ALL_B.CONTRACT_NUMBER. V2 is deployed ALONGSIDE V1 (BIP
--    objects are never overwritten); V1 stays in the catalog untouched.
--
-- Idempotent: fixed-value UPDATEs guarded so a re-run is a no-op; migration-log
-- MERGE. No DDL. Touches only the Grants rows.

prompt == Grants: per-object Fusion user ppm_impl (row 57) ==
update DMT_ERP_INTERFACE_OPTIONS_TBL
set    FUSION_USERNAME = 'ppm_impl',
       FUSION_PASSWORD = '***MASKED-SET-ME***'
where  CEMLI_CODE = 'Grants'
and    ERP_INTERFACE_OPTIONS_ID = 57
and    FUSION_USERNAME is null;

prompt == Grants: recon registry -> V2 data model ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Grants/DMT_GRANT_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Grants/DMT_GRANT_RECON_V2_RPT.xdo',
       RECON_KEY_SQL       = 'AWARD_NUMBER -- V2 DM BASE key OKC_K_HEADERS_ALL_B.CONTRACT_NUMBER '
                          || '(prefixed award number); transform stamps the prefixed AWARD_NUMBER'
where  BIP_REPORT_ID = 100000007
and    CEMLI_CODE    = 'Grants';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-07_grants_ppm_impl_and_recon_v2.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'grantsppmv2', USER);

commit;
