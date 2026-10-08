-- =========================================================================
-- Migration: Lookups natural-key proof of load (backlog #160)  2026-10-08
--   DMT_FND_LOOKUP_TYPE_TFM_TBL.FUSION_LOOKUP_TYPE_ID   NUMBER -> VARCHAR2(100)
--   DMT_FND_LOOKUP_VALUE_TFM_TBL.FUSION_LOOKUP_ID       NUMBER -> VARCHAR2(100)
--
-- docs/DMT_DESIGN.html section 7, "Standard LOADED-promotion shape" clauses
-- (2) and (5): the update that sets TFM_STATUS='LOADED' writes the captured
-- proof into the object's FUSION_*_ID column, and objects with no single
-- surrogate store their natural key under the same non-null guard.
--
-- WHY: FND lookups have no numeric surrogate id in Fusion (FND_LOOKUP_TYPES is
-- keyed by LOOKUP_TYPE, FND_LOOKUP_VALUES_B by LOOKUP_TYPE + LOOKUP_CODE).
-- DMT_FND_LOOKUP_RESULTS_PKG used to mark a confirmed row LOADED and leave
-- both columns NULL -- a LOADED row with no Fusion id (#160). The reconciler
-- now stamps the natural key read back from the base tables:
--   type  -> LOOKUP_TYPE
--   value -> LOOKUP_TYPE~LOOKUP_CODE
-- which is text, so both columns become VARCHAR2(100).
--
-- NON-DESTRUCTIVE (backfill-and-rename, same pattern as
-- 2026-09-24_item_fusion_org_key.sql): add <col>_C VARCHAR2(100), copy every
-- existing non-null value as text, drop the NUMBER column, rename _C into
-- place. TFM_STATUS and every other column are untouched.
--
-- IDEMPOTENT for every state: already VARCHAR2 -> no-op; NUMBER -> full
-- convert; interrupted (_C present) -> resume. The create-table scripts in
-- db/tables/ create both columns as VARCHAR2(100) on fresh installs. Deploy as
-- the schema owner (never ADMIN).
-- =========================================================================
set define off
set serveroutput on
-- Wait for a briefly-held DML lock instead of failing the DROP COLUMN with
-- ORA-00054 (seen on the first local deploy; the file resumed cleanly on rerun).
alter session set ddl_lock_timeout = 60;

prompt == Convert Lookups FUSION_*_ID columns to VARCHAR2(100) (non-destructive) ==
declare
  procedure convert_col (p_table in varchar2, p_col in varchar2) is
    l_old_type user_tab_columns.data_type%type;
    l_new_cnt  pls_integer;
    l_rows     pls_integer;
  begin
    begin
      select data_type into l_old_type
        from user_tab_columns
       where table_name = p_table and column_name = p_col;
    exception
      when no_data_found then l_old_type := null;
    end;

    select count(*) into l_new_cnt
      from user_tab_columns
     where table_name = p_table and column_name = p_col || '_C';

    if l_old_type like 'VARCHAR2%' and l_new_cnt = 0 then
      dbms_output.put_line(p_table || '.' || p_col || ' already ' || l_old_type || ' -- no change.');
      return;
    end if;

    if l_new_cnt = 0 then
      execute immediate 'ALTER TABLE "' || p_table || '" ADD ("' || p_col || '_C" VARCHAR2(100))';
    end if;

    if l_old_type = 'NUMBER' then
      execute immediate
        'UPDATE "' || p_table || '" SET "' || p_col || '_C" = TO_CHAR("' || p_col || '") '
        || 'WHERE "' || p_col || '" IS NOT NULL AND "' || p_col || '_C" IS NULL';
      l_rows := sql%rowcount;
      commit;
      dbms_output.put_line(p_table || ': backfilled ' || l_rows || ' historical value(s) as text.');
      execute immediate 'ALTER TABLE "' || p_table || '" DROP COLUMN "' || p_col || '"';
    end if;

    select count(*) into l_new_cnt
      from user_tab_columns
     where table_name = p_table and column_name = p_col || '_C';
    if l_new_cnt = 1 then
      execute immediate 'ALTER TABLE "' || p_table || '" RENAME COLUMN "' || p_col || '_C" TO "' || p_col || '"';
      dbms_output.put_line(p_table || '.' || p_col || ' is now VARCHAR2(100).');
    end if;
  end convert_col;
begin
  convert_col('DMT_FND_LOOKUP_TYPE_TFM_TBL',  'FUSION_LOOKUP_TYPE_ID');
  convert_col('DMT_FND_LOOKUP_VALUE_TFM_TBL', 'FUSION_LOOKUP_ID');
end;
/

COMMENT ON COLUMN "DMT_FND_LOOKUP_TYPE_TFM_TBL"."FUSION_LOOKUP_TYPE_ID" IS 'Natural-key proof of load (FND lookups have no numeric surrogate): LOOKUP_TYPE as read back from FND_LOOKUP_TYPES. Written only by reconciliation (DMT_FND_LOOKUP_RESULTS_PKG.PARSE_AND_UPDATE).';
COMMENT ON COLUMN "DMT_FND_LOOKUP_VALUE_TFM_TBL"."FUSION_LOOKUP_ID" IS 'Natural-key proof of load at the value grain (FND lookups have no numeric surrogate): LOOKUP_TYPE~LOOKUP_CODE as read back from FND_LOOKUP_VALUES_B. Written only by reconciliation (DMT_FND_LOOKUP_RESULTS_PKG.PARSE_AND_UPDATE).';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-08_lookups_fusion_natural_key.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'lookupsnaturalkey', USER);

commit;
