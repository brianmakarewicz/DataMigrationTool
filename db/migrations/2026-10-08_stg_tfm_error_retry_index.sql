-- FAILED-mode selection from the run-stamped attempt record (backlog #310).
--
-- Adds DMT_STG_TFM_ERROR_N3 (SUB_OBJECT, STG_SEQUENCE_ID) so the per-row lookup
-- DMT_UTIL_PKG.FAILED_RETRY_SELECTED -> DMT_STG_ATTEMPT_V does not scan the
-- whole error table. Mirrors the committed block in
-- db/tables/dmt_stg_tfm_error_tbl.sql. Idempotent: ORA-00955 / ORA-01408 are
-- tolerated, the migration-log row is a MERGE.

prompt == Index DMT_STG_TFM_ERROR_N3 ==
begin
  execute immediate 'CREATE INDEX "DMT_STG_TFM_ERROR_N3" ON "DMT_STG_TFM_ERROR_TBL" ("SUB_OBJECT", "STG_SEQUENCE_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-08_stg_tfm_error_retry_index.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'retryidx310', USER);

commit;
