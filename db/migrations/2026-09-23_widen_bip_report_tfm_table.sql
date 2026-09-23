-- =========================================================================
-- Migration: widen DMT_BIP_REPORT_TBL.TFM_TABLE 100 -> 240 (2026-09-23)
-- docs/DMT_DESIGN.html section 5 ("BIP reconciliation report contract - v1").
--
-- WHY: TFM_TABLE was introduced at VARCHAR2(100) by the Contract v1 columns
-- migration (2026-09-16). PR #386 later seeded the Customers / HZ_PARTIES row
-- with a descriptive multi-table value that is 120 chars
--   'DMT_HZ_PARTIES_TFM_TBL (+ 6 sibling TFM tables -- seven record types,
--    dispatched by OBJECT_TYPE in DMT_CUST_RESULTS_PKG)'
-- which overflows VARCHAR2(100) and aborts the seed phase of a fresh
-- db/install.sql with ORA-12899, rolling the whole seed transaction back and
-- leaving the recon registry partial.
--
-- TFM_TABLE is DOCUMENTATION-ONLY (never used in dynamic SQL; the shared
-- Contract v1 parser and per-object reconcilers reference their own
-- compile-time-known TFM tables). The durable fix is to widen the column so
-- the informative multi-table description fits and will not recur for other
-- multi-record-type objects -- NOT to trim the description.
--
-- The create-table script db/tables/dmt_bip_report_tbl.sql now creates
-- TFM_TABLE at VARCHAR2(240) for fresh installs (its guarded in-file ALTER).
-- This migration converges an EXISTING database whose column is still
-- VARCHAR2(100). MODIFY-to-a-wider-width is unconditionally safe (no data
-- loss, no truncation) and idempotent (re-running MODIFY 240 on a 240 column
-- is a no-op). Logged once in DMT_MIGRATION_LOG.
--
-- ADDITIVE (widen only). Idempotent (guarded on current width). Deploy as
-- DMT2_OWNER (never ADMIN).
-- =========================================================================
set define off
set serveroutput on

prompt == Widen DMT_BIP_REPORT_TBL.TFM_TABLE to VARCHAR2(240) ==
declare
  l_len pls_integer;
begin
  select char_length
    into l_len
    from user_tab_columns
   where table_name  = 'DMT_BIP_REPORT_TBL'
     and column_name = 'TFM_TABLE';
  if l_len < 240 then
    execute immediate
      'ALTER TABLE "DMT_BIP_REPORT_TBL" MODIFY ("TFM_TABLE" VARCHAR2(240))';
  end if;
exception
  when no_data_found then
    -- Column not present (pre-Contract-v1 database); the create-table script
    -- and the 2026-09-16 migration add it. Nothing to widen here.
    null;
end;
/

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-09-23_widen_bip_report_tfm_table.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'widentfmtbl240', USER);

commit;
