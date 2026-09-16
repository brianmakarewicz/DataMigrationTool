-- =========================================================================
-- Migration: Contract v1 registration columns on DMT_BIP_REPORT_TBL (2026-09-16)
-- docs/DMT_DESIGN.html section 5 ("BIP reconciliation report contract - v1").
--
-- Adds the four columns the single shared Contract v1 parser
-- (DMT_RECON_CONTRACT_PKG.RECONCILE) reads per object:
--   CONTRACT_VERSION  1 = conforms to Contract v1 (shared parser applies the
--                     seven-column response); NULL/0 = legacy bespoke reconciler.
--   TFM_TABLE         the object's TFM table the parser updates.
--   FUSION_ID_COLUMN  the TFM column the parser stamps the Fusion base-table id
--                     into on a BASE/SUCCESS row.
--   RECON_KEY_SQL     documents how RECON_KEY is built for the object.
--
-- ADDITIVE + NULLABLE. Idempotent (per-column guarded). Deploy as DMT2_OWNER
-- (never ADMIN). The create-table script db/tables/dmt_bip_report_tbl.sql
-- carries the same guarded ALTERs for fresh installs; this migration converges
-- an existing database and is logged once in DMT_MIGRATION_LOG.
-- =========================================================================
set define off
set serveroutput on

prompt == Contract v1 columns on DMT_BIP_REPORT_TBL ==
declare
  procedure add_col(p_col varchar2, p_ddl varchar2) is
    l_n pls_integer;
  begin
    select count(*) into l_n from user_tab_columns
    where  table_name = 'DMT_BIP_REPORT_TBL' and column_name = p_col;
    if l_n = 0 then
      execute immediate 'ALTER TABLE "DMT_BIP_REPORT_TBL" ADD (' || p_ddl || ')';
    end if;
  end;
begin
  add_col('CONTRACT_VERSION', '"CONTRACT_VERSION" NUMBER');
  add_col('TFM_TABLE',        '"TFM_TABLE" VARCHAR2(100)');
  add_col('FUSION_ID_COLUMN', '"FUSION_ID_COLUMN" VARCHAR2(100)');
  add_col('RECON_KEY_SQL',    '"RECON_KEY_SQL" VARCHAR2(1000)');
end;
/

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-09-16_bip_report_contract_v1_columns.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'contractv1cols', USER);

commit;
