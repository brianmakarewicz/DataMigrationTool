-- =========================================================================
-- Migration: generic recon-engine columns on DMT_BIP_REPORT_TBL (2026-09-20)
-- docs/DMT_DESIGN.html section 5 ("BIP reconciliation report contract - v1").
--
-- The shared generic reconciler DMT_RECON_ENGINE_PKG.RECONCILE builds its two
-- set-based MERGEs from registry-named identifiers. It reuses the existing
-- CONTRACT_VERSION / TFM_TABLE / FUSION_ID_COLUMN columns and adds two more it
-- consumes AS SQL IDENTIFIERS (both pattern-asserted before concatenation, same
-- posture as DMT_QUEUE_WORKER_PKG.ACCOUNT_ROWS / assert_catalog_identifier):
--   STATUS_COLUMN     the TFM status column marked LOADED/FAILED.
--   RECON_KEY_COLUMN  the TFM column matched to the report RECORD_KEY.
-- Both default in the engine (TFM_STATUS / RECON_KEY) when left NULL, so an
-- object need only set one that differs from the universal DMT convention.
--
-- ADDITIVE + NULLABLE. Idempotent (per-column guarded). Deploy as DMT2_OWNER
-- (never ADMIN). The create-table script db/tables/dmt_bip_report_tbl.sql
-- carries the same guarded ALTERs for fresh installs; this migration converges
-- an existing database and is logged once in DMT_MIGRATION_LOG.
-- =========================================================================
set define off
set serveroutput on

prompt == Generic recon-engine columns on DMT_BIP_REPORT_TBL ==
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
  add_col('STATUS_COLUMN',    '"STATUS_COLUMN" VARCHAR2(100)');
  add_col('RECON_KEY_COLUMN', '"RECON_KEY_COLUMN" VARCHAR2(100)');
end;
/

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-09-20_bip_report_recon_engine_columns.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'reconenginecols', USER);

commit;
