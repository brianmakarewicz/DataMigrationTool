-- GLBalances reconciliation report V2 registry repoint (backlog #173).
--
-- Points the GLBalances Contract v1 registry row (BIP_REPORT_ID 100000016) at
-- /Custom/DMT2/GLBalances/DMT_GL_BAL_RECON_V2_DM.xdm and its report
-- DMT_GL_BAL_RECON_V2_RPT.xdo. V2 returns only Journal Import's own error for a
-- rejected line (GL_INTERFACE.STATUS: STATUS_DESCRIPTION). V1 labelled
-- GL_INTERFACE.REFERENCE10 (the line description DMT sends) as the error and
-- composed its own "UNBALANCED: DR=.. CR=.." sentence for base journals. V2 also
-- selects base rows by the GroupID / LedgerID arguments of the Journal Import job
-- (read by the job's request id) instead of GROUP_ID = run id. V2 is deployed
-- ALONGSIDE V1 (BIP objects are never overwritten).
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql so an
-- existing database converges without re-running the whole seed. Idempotent:
-- a plain UPDATE to fixed values (re-run is a no-op), migration-log MERGE.
-- Touches only the GLBalances registry row; no DDL.

prompt == Repoint GLBalances recon registry row to V2 ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/GLBalances/DMT_GL_BAL_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/GLBalances/DMT_GL_BAL_RECON_V2_RPT.xdo',
       NOTES               = 'GL journal import reconciliation (Contract v1 -- nine columns, keyset). '
                          || 'V2 (backlog #173): ERROR_MESSAGE is only Journal Import''s own error '
                          || '(GL_INTERFACE.STATUS: STATUS_DESCRIPTION); no REFERENCE10, no composed '
                          || 'unbalanced sentence. Rows selected by job id (import job''s GroupID/LedgerID '
                          || 'arguments; LOAD_REQUEST_ID). Deployed alongside V1, never overwriting it.'
where  BIP_REPORT_ID = 100000016
and    CEMLI_CODE    = 'GLBalances';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-07_glbalances_recon_v2_registry.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'glreconv2', USER);

commit;
