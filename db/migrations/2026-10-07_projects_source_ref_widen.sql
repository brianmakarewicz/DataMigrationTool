-- =========================================================================
-- Migration: widen DMT_PJF_PROJECTS_TFM_TBL.SOURCE_PROJECT_REFERENCE 25 -> 100
-- (2026-10-07). docs/DMT_DESIGN.html section 5, the owner-approved Projects
-- reconciliation exception.
--
-- WHY: the Projects transform now stamps the FBDI Source Reference as
-- '<run_id>:<work_queue_id>:<legacy reference>' when prefixing is on, so the
-- reconciliation report can find the work item's projects by
-- PJF_PROJECTS_ALL_B.PM_PROJECT_REFERENCE (Fusion stamps no job id on the
-- project base tables). The value no longer fits VARCHAR2(25). The Fusion
-- target columns are VARCHAR2(100).
--
-- The create-table script db/tables/dmt_pjf_projects_tfm_tbl.sql carries the
-- new width (CREATE + guarded in-file ALTER). This migration converges an
-- EXISTING database. Widening is unconditionally safe (no truncation) and
-- idempotent (guarded on the current width). Logged once in DMT_MIGRATION_LOG.
-- Deploy as the schema owner (never ADMIN).
-- =========================================================================
set define off
set serveroutput on

prompt == Widen DMT_PJF_PROJECTS_TFM_TBL.SOURCE_PROJECT_REFERENCE to VARCHAR2(100) ==
declare
  l_len pls_integer;
begin
  select char_length
    into l_len
    from user_tab_columns
   where table_name  = 'DMT_PJF_PROJECTS_TFM_TBL'
     and column_name = 'SOURCE_PROJECT_REFERENCE';
  if l_len < 100 then
    execute immediate
      'ALTER TABLE "DMT_PJF_PROJECTS_TFM_TBL" MODIFY ("SOURCE_PROJECT_REFERENCE" VARCHAR2(100))';
  end if;
end;
/

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-07_projects_source_ref_widen.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'prjsrcrefwiden100', USER);

commit;
