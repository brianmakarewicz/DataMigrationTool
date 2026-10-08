-- Contracts reconciliation report V2 registry repoint (find rows by job id).
--
-- Points the Contracts Contract v1 registry row at
-- /Custom/DMT2/Contracts/DMT_CONTRACT_RECON_V2_DM.xdm and its report
-- DMT_CONTRACT_RECON_V2_RPT.xdo. V2 finds rows only by the work item's own
-- Fusion job ids and the Contract document style (owner decision 2026-10-07,
-- backlog #259): base headers by REQUEST_ID = the import job id, interface
-- headers by LOAD_REQUEST_ID = the load job id AND REQUEST_ID = the import job
-- id, and PO_INTERFACE_ERRORS by REQUEST_ID = the import job id. V1 also
-- narrowed the interface rows with LIKE on the run id. V2 is deployed
-- ALONGSIDE V1 (BIP objects are never overwritten).
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql so an
-- existing database converges without re-running the whole seed. Idempotent:
-- a plain UPDATE to fixed values (re-run is a no-op), migration-log MERGE.
-- Touches only the Contracts registry row; no DDL.

prompt == Repoint Contracts recon registry row to V2 ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Contracts/DMT_CONTRACT_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Contracts/DMT_CONTRACT_RECON_V2_RPT.xdo',
       NOTES               = 'Contract purchase agreement import reconciliation (Contract v1, headers only). '
                          || 'V2 (2026-10-07): rows found only by the work item''s Fusion job ids (base by the import '
                          || 'REQUEST_ID, interface by LOAD_REQUEST_ID + the import REQUEST_ID) and the Contract '
                          || 'document style, never by the run id. Deployed alongside V1, never overwriting it.'
where  CEMLI_CODE = 'Contracts';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-07_contracts_recon_v2_registry.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'cpareconv2', USER);

commit;
