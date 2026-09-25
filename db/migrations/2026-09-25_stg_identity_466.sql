-- =========================================================================
-- Migration: convert STG_SEQUENCE_ID on the sequence-default STG tables to
-- GENERATED ALWAYS AS IDENTITY  (GitHub issue #466)  (2026-09-25)
-- docs/DMT_DESIGN.html section 7 accepted coding standard 2026-07-08:
-- "Identity columns for keys; sequences only for shared, meaningful values."
--
-- WHY: dmt_csv_loader_pkg.load_batch failed with
--   ORA-00001: unique constraint (..._STG_PK) violated  on STG_SEQUENCE_ID
-- for the 73 STG tables whose primary key was populated by a column DEFAULT of
-- "<TABLE>_STG_SEQ.NEXTVAL" rather than a real identity column. On any database
-- that already holds staging rows, the sequence value can sit at or behind
-- MAX(STG_SEQUENCE_ID) (rows were loaded, sequences were reset/reinstalled, or
-- ids were supplied explicitly by the regression seeder). The next load then
-- draws a NEXTVAL that already exists and the PK insert collides. The 24 STG
-- tables that already used GENERATED ALWAYS AS IDENTITY never collide because
-- the database, not a detached sequence, owns the high-water mark.
--
-- FIX (durable): make STG_SEQUENCE_ID a real identity column on all 73 tables,
-- matching the 24 that already work. The create-table scripts under db/tables/
-- (dmt_*_stg_tbl.sql) now emit
--     "STG_SEQUENCE_ID" NUMBER GENERATED ALWAYS AS IDENTITY NOT NULL ENABLE
-- for fresh installs. THIS migration converges an EXISTING database in place,
-- WITHOUT dropping or rebuilding any table (every STG PK is the target of a
-- TFM->STG foreign key, so a drop/recreate would be high-risk), and WITHOUT
-- losing a single staging row.
--
-- HOW, per table (only for tables not yet converted):
--   1. Clear the sequence DEFAULT:
--        ALTER TABLE t MODIFY (STG_SEQUENCE_ID DEFAULT NULL)
--      A column that still carries a DEFAULT expression cannot be turned into
--      an identity column, so the default must go first.
--   2. Convert to identity, seeded above the current data:
--        ALTER TABLE t MODIFY STG_SEQUENCE_ID
--          GENERATED ALWAYS AS IDENTITY (START WITH LIMIT VALUE)
--      START WITH LIMIT VALUE tells Oracle to seed the identity sequence at
--      MAX(STG_SEQUENCE_ID)+1 for the existing data -- exactly the high-water
--      reset this bug needs. Existing rows keep their existing ids untouched.
--
-- IDEMPOTENT / SAFE TO RE-RUN: the driver only selects STG tables whose
-- STG_SEQUENCE_ID is NOT already an identity column (checked against
-- user_tab_identity_cols). A converted table is simply not selected on the next
-- run. Each table is converted inside its own block; any ORA error on one table
-- is caught, logged via DBMS_OUTPUT, and does NOT abort the rest -- so one
-- problem table can never leave the other 72 unconverted. The set of tables is
-- discovered from the data dictionary (not hardcoded), so it self-limits to
-- whatever still needs converting.
--
-- Deploy git-first as DMT2_OWNER / DMT_OWNER (never ADMIN). ci_promote runs
-- every db/migrations file in chronological filename order, so this deploys to
-- GOLD as well as local Docker.
-- =========================================================================
set define off
set serveroutput on
set feedback off

prompt == Issue #466: convert sequence-default STG_SEQUENCE_ID columns to GENERATED ALWAYS AS IDENTITY ==
declare
  l_converted pls_integer := 0;
  l_skipped   pls_integer := 0;
  l_failed    pls_integer := 0;
begin
  for r in (
    -- Every real STG_TBL (exclude the err$ DML-error shadow tables) that HAS a
    -- STG_SEQUENCE_ID column which is NOT yet an identity column. This naturally
    -- covers exactly the tables still on a sequence default, and returns nothing
    -- once they are all converted (idempotent).
    select tc.table_name
      from user_tab_columns tc
     where tc.column_name = 'STG_SEQUENCE_ID'
       and tc.table_name like 'DMT#_%STG#_TBL' escape '#'
       and tc.table_name not like 'ERR$%'
       and not exists (
             select 1 from user_tab_identity_cols ic
              where ic.table_name  = tc.table_name
                and ic.column_name = 'STG_SEQUENCE_ID')
     order by tc.table_name
  ) loop
    begin
      -- Step 1: clear the sequence DEFAULT (a defaulted column cannot become
      -- an identity column). Harmless if there is no default.
      execute immediate
        'ALTER TABLE "' || r.table_name || '" MODIFY ("STG_SEQUENCE_ID" DEFAULT NULL)';

      -- Step 2: convert to identity, seeded above the existing high-water mark.
      execute immediate
        'ALTER TABLE "' || r.table_name || '" MODIFY "STG_SEQUENCE_ID" ' ||
        'GENERATED ALWAYS AS IDENTITY (START WITH LIMIT VALUE)';

      l_converted := l_converted + 1;
      dbms_output.put_line('466 converted ' || r.table_name ||
        ' -> STG_SEQUENCE_ID GENERATED ALWAYS AS IDENTITY (seeded above MAX).');
    exception
      when others then
        l_failed := l_failed + 1;
        dbms_output.put_line('466 SKIP ' || r.table_name || ': ' || sqlerrm);
    end;
  end loop;

  select count(*) into l_skipped
    from user_tab_columns tc
   where tc.column_name = 'STG_SEQUENCE_ID'
     and tc.table_name like 'DMT#_%STG#_TBL' escape '#'
     and tc.table_name not like 'ERR$%'
     and exists (
           select 1 from user_tab_identity_cols ic
            where ic.table_name  = tc.table_name
              and ic.column_name = 'STG_SEQUENCE_ID');

  dbms_output.put_line('466 summary: converted this run=' || l_converted ||
    ', failed this run=' || l_failed ||
    ', total STG tables now identity=' || l_skipped || ' (target 97).');
end;
/

prompt == Refresh STG_SEQUENCE_ID comment on the converted tables ==
-- The 73 tables carried "PK - from <TABLE>_STG_SEQ" comments describing the old
-- sequence wiring. Re-stamp them to the identity description used by the 24
-- always-identity tables. Data-driven; safe to re-run.
declare
begin
  for r in (
    select ic.table_name
      from user_tab_identity_cols ic
     where ic.column_name = 'STG_SEQUENCE_ID'
       and ic.table_name like 'DMT#_%STG#_TBL' escape '#'
       and ic.table_name not like 'ERR$%'
     order by ic.table_name
  ) loop
    begin
      execute immediate
        'COMMENT ON COLUMN "' || r.table_name || '"."STG_SEQUENCE_ID" IS ' ||
        '''PK - identity column (GENERATED ALWAYS). Populated by the DB, never supplied by user.''';
    exception
      when others then
        dbms_output.put_line('466 comment skip ' || r.table_name || ': ' || sqlerrm);
    end;
  end loop;
end;
/

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-09-25_stg_identity_466.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'stgidentity466', USER);

commit;
set feedback on
