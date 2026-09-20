-- =========================================================================
-- Migration: APPLY_PROC column on DMT_BIP_REPORT_TBL (2026-09-20)
-- docs/DMT_DESIGN.html section 5 / section 7 (dynamic-SQL three-site rule).
--
-- The generic recon engine (DMT_RECON_ENGINE_PKG, Option 1) pages + parses +
-- stages an object's Contract v1 report into DMT_RECON_STAGE_GTT, then
-- dispatches the object's OWN thin static apply (APPLY_<OBJ>) through the
-- sanctioned invoke_registered site. APPLY_PROC is the PKG.PROC the engine
-- dispatches — a procedure name (invoke_registered validates the PKG.PROC
-- allow-pattern), never a table or column name, so no new dynamic-SQL site is
-- introduced.
--
-- ADDITIVE + NULLABLE. Idempotent (guarded). Deploy as DMT2_OWNER (never
-- ADMIN). The create-table script db/tables/dmt_bip_report_tbl.sql carries the
-- same guarded ALTER for fresh installs; this migration converges an existing
-- database and is logged once in DMT_MIGRATION_LOG.
-- =========================================================================
set define off
set serveroutput on

prompt == APPLY_PROC column on DMT_BIP_REPORT_TBL ==
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
  add_col('APPLY_PROC', '"APPLY_PROC" VARCHAR2(200)');
end;
/

prompt == Point GLBalances at the generic engine + its static apply ==
-- Converge the GLBalances registry: Contract v1 columns + APPLY_PROC (the
-- engine dispatches DMT_GL_RESULTS_PKG.APPLY_GL after staging the report).
merge into "DMT_BIP_REPORT_TBL" t
using (
    select 'GLBalances'                     cemli_code,
           1                                contract_version,
           'DMT_GL_INTERFACE_TFM_TBL'       tfm_table,
           'FUSION_JE_HEADER_ID'            fusion_id_column,
           'DMT_GL_RESULTS_PKG.APPLY_GL'    apply_proc
    from dual
) s
on (t."CEMLI_CODE" = s.cemli_code)
when matched then update set
    t."CONTRACT_VERSION" = s.contract_version,
    t."TFM_TABLE"        = s.tfm_table,
    t."FUSION_ID_COLUMN" = s.fusion_id_column,
    t."APPLY_PROC"       = s.apply_proc;

-- Route GLBalances' RECON_PROC through the generic engine (RECON_HAS_CEMLI_ARG
-- = 'Y' so the engine gets p_cemli_code).
update "DMT_PIPELINE_DEF_TBL"
   set "RECON_PROC"          = 'DMT_RECON_ENGINE_PKG.RECONCILE_BATCH',
       "RECON_HAS_CEMLI_ARG" = 'Y'
 where "CEMLI_CODE" = 'GLBalances';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-09-20_bip_report_apply_proc_column.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'applyproccol', USER);

commit;
