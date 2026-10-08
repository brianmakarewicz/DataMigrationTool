-- GLBalances reconciliation report V4 registry repoint (backlog #173 follow-up).
--
-- Owner decision 2026-10-07: GROUP_ID is the work queue id (one group per load)
-- and Import Journals is submitted with exactly that group id, never ALL, so a
-- job never imports another user's pending journals. Points the GLBalances
-- registry row (BIP_REPORT_ID 100000016) at DMT_GL_BAL_RECON_V4_DM.xdm (+ _RPT),
-- which selects base batches by the import job's own GroupID / LedgerID
-- arguments, and points the post-run comparison back at GL_BAL_CMP_DM.xdm
-- (GROUP_ID = :P_BATCH_ID, now passed the work queue id). V4 is deployed
-- ALONGSIDE V1 and V3 (BIP objects are never overwritten).
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql so an
-- existing database converges without re-running the whole seed. Idempotent:
-- a plain UPDATE to fixed values (re-run is a no-op), migration-log MERGE.
-- Touches only the GLBalances registry row; no DDL.

prompt == Repoint GLBalances recon to V4 and comparison to GL_BAL_CMP_DM ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH         = '/Custom/DMT2/GLBalances/DMT_GL_BAL_RECON_V4_DM.xdm',
       REPORT_CATALOG_PATH     = '/Custom/DMT2/GLBalances/DMT_GL_BAL_RECON_V4_RPT.xdo',
       CMP_DM_CATALOG_PATH     = '/Custom/DMT2/GLBalances/GL_BAL_CMP_DM.xdm',
       CMP_REPORT_CATALOG_PATH = '/Custom/DMT2/GLBalances/GL_BAL_CMP_RPT.xdo',
       NOTES                   = 'GL journal import reconciliation (Contract v1 -- nine columns, keyset). '
                              || 'V4 (backlog #173): GROUP_ID = work queue id, Import Journals submitted with '
                              || 'that exact group (never ALL); ERROR_MESSAGE is only Journal Import''s own error '
                              || '(GL_INTERFACE.STATUS, plus '': '' STATUS_DESCRIPTION when Fusion wrote one); no '
                              || 'REFERENCE10, no composed unbalanced sentence. Rows selected by job id (import '
                              || 'job''s GroupID/LedgerID arguments; LOAD_REQUEST_ID). Deployed alongside V1 and '
                              || 'V3, never overwriting them.'
where  BIP_REPORT_ID = 100000016
and    CEMLI_CODE    = 'GLBalances';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-08_glbalances_recon_v4_registry.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'glreconv4', USER);

commit;
