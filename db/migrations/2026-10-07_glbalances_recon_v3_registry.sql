-- GLBalances reconciliation report V3 + comparison report V2 registry repoint
-- (backlog #173).
--
-- Points the GLBalances registry row (BIP_REPORT_ID 100000016) at
-- /Custom/DMT2/GLBalances/DMT_GL_BAL_RECON_V3_DM.xdm (+ _RPT.xdo) and its
-- post-run comparison at GL_BAL_CMP_V2_DM.xdm (+ _RPT.xdo).
--
-- Why: each journal now carries its own GROUP_ID (run id * 1000000 + journal
-- number) and Import Journals runs once per load with GroupID = ALL, so Journal
-- Import's all-or-nothing rejection covers one journal instead of the whole run.
-- V3 returns only Journal Import's own error for a rejected line
-- (GL_INTERFACE.STATUS, plus ': ' STATUS_DESCRIPTION when Fusion wrote one) and
-- selects base rows by the Journal Import child request id, interface rows by
-- LOAD_REQUEST_ID. V1 labelled REFERENCE10 (our line description) as the error
-- and composed an "UNBALANCED" sentence. The comparison V2 reads the run's
-- GROUP_ID range instead of GROUP_ID = run id. Both are deployed ALONGSIDE the
-- old versions (BIP objects are never overwritten).
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql so an
-- existing database converges without re-running the whole seed. Idempotent:
-- a plain UPDATE to fixed values (re-run is a no-op), migration-log MERGE.
-- Touches only the GLBalances registry row; no DDL.

prompt == Repoint GLBalances recon + comparison registry to V3 / CMP V2 ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH         = '/Custom/DMT2/GLBalances/DMT_GL_BAL_RECON_V3_DM.xdm',
       REPORT_CATALOG_PATH     = '/Custom/DMT2/GLBalances/DMT_GL_BAL_RECON_V3_RPT.xdo',
       CMP_DM_CATALOG_PATH     = '/Custom/DMT2/GLBalances/GL_BAL_CMP_V2_DM.xdm',
       CMP_REPORT_CATALOG_PATH = '/Custom/DMT2/GLBalances/GL_BAL_CMP_V2_RPT.xdo',
       NOTES                   = 'GL journal import reconciliation (Contract v1 -- nine columns, keyset). '
                              || 'V3 (backlog #173): one GROUP_ID per journal, Import Journals GroupID=ALL; '
                              || 'ERROR_MESSAGE is only Journal Import''s own error (GL_INTERFACE.STATUS, plus '
                              || ''': '' STATUS_DESCRIPTION when Fusion wrote one); no REFERENCE10, no composed '
                              || 'unbalanced sentence. Rows selected by job id (Journal Import child request id '
                              || 'in the batch name; LOAD_REQUEST_ID). Deployed alongside V1, never overwriting it.'
where  BIP_REPORT_ID = 100000016
and    CEMLI_CODE    = 'GLBalances';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-07_glbalances_recon_v3_registry.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'glreconv3', USER);

commit;
