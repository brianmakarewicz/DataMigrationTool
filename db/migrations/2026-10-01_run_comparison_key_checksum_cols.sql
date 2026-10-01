-- =========================================================================
-- Migration: business-key checksum columns on DMT_RUN_COMPARISON_TBL (2026-10-01)
-- Backlog #94 -- "Business-key checksum for money-less comparison objects".
--
-- Objects with no monetary amount (Suppliers, Customers, Projects, Contracts,
-- Workers, and the env-blocked ones) leave the money columns of the post-run
-- comparison report (APEX page 85) blank, so count is the only cross-check.
-- These three columns add a non-money equality signal: a deterministic
-- set-checksum over each object's ordered, normalized business key(s), computed
-- identically on the STG/TFM side and the Fusion side, so an equal key set
-- yields an equal checksum.
--
--   STG_KEY_CHECKSUM     checksum of the staged/transformed business keys.
--   FUSION_KEY_CHECKSUM  checksum of the loaded business keys read back from
--                        Fusion (same expression, Fusion base-table side).
--   KEY_MATCH            Y | N | ? -- equality verdict (? when either side is
--                        unavailable); NULL on objects not yet wired.
--
-- ADDITIVE + NULLABLE. Idempotent (per-column guarded). Deploy as DMT_OWNER
-- (never ADMIN). The create-table script db/tables/dmt_run_comparison_tbl.sql
-- carries the same guarded ALTERs for fresh installs; this migration converges
-- an existing database and is logged once in DMT_MIGRATION_LOG.
--
-- Scope: Suppliers is the first object wired to compute these (prototype).
-- The remaining money-less objects are a documented follow-on, not coded here.
-- =========================================================================
set define off
set serveroutput on

prompt == Business-key checksum columns on DMT_RUN_COMPARISON_TBL ==
declare
  procedure add_col(p_col varchar2, p_def varchar2) is
    n number;
  begin
    select count(*) into n from user_tab_columns
     where table_name = 'DMT_RUN_COMPARISON_TBL' and column_name = p_col;
    if n = 0 then
      execute immediate 'ALTER TABLE "DMT_RUN_COMPARISON_TBL" ADD ("'||p_col||'" '||p_def||')';
    end if;
  end;
begin
  add_col('STG_KEY_CHECKSUM',    'VARCHAR2(80)');
  add_col('FUSION_KEY_CHECKSUM', 'VARCHAR2(80)');
  add_col('KEY_MATCH',           'VARCHAR2(1)');
end;
/

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-01_run_comparison_key_checksum_cols.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'keychecksumcols', USER);

commit;
