-- =========================================================================
-- Migration: DMT_GL_INTERFACE_TFM_TBL.FUSION_JE_HEADER_ID NUMBER -> VARCHAR2(100)
-- (2026-09-24)
-- docs/DMT_DESIGN.html section 5 ("BIP reconciliation report contract - v1")
-- and section 7 ("Reconciliation captures the Fusion base-table id").
--
-- WHY: GLBalances' TFM table is journal-LINE grained, but the reconciler used
-- to stamp the journal-HEADER id (JE_HEADER_ID) into FUSION_JE_HEADER_ID -- so
-- every line of one journal carried the SAME id and the lines collided in the
-- Fusion-id uniqueness audit. The reconciler now stamps the per-LINE composite
-- 'JE_HEADER_ID~JE_LINE_NUM' (from GL_JE_LINES, the base table), which is a
-- string. The column must therefore become VARCHAR2 to hold that composite,
-- following the contract's '~'-joined composite-key convention.
--
-- NON-DESTRUCTIVE (backfill-and-rename). FUSION_JE_HEADER_ID is recon-derived
-- positive proof of load. Every historical LOADED row already carries its
-- header-grain id, and that value is real proof that the row loaded -- it must
-- NOT be thrown away. A NUMBER -> VARCHAR2 MODIFY in place fails with ORA-01439
-- unless the column is empty, so instead of NULLing the data we:
--   1. add a new VARCHAR2(100) column FUSION_JE_HEADER_ID_C,
--   2. backfill it with TO_CHAR of every existing (non-null) NUMBER value --
--      preserving each historical row's proof-of-load as text,
--   3. drop the old NUMBER column, and
--   4. rename the new column to FUSION_JE_HEADER_ID.
-- The next reconcile re-stamps LOADED rows with the finer line-grain composite;
-- until then, historical rows keep their (text) header-grain id. TFM_STATUS is
-- never touched. This preserves historical run data (carried-over rule 4) and
-- never manufactures a LOADED-with-NULL-id false positive.
--
-- IDEMPOTENT / GUARDED for ALL states, branching on USER_TAB_COLUMNS:
--   (a) already-converted (FUSION_JE_HEADER_ID is VARCHAR2)  -> clean no-op;
--   (b) fresh NUMBER column, no _C column yet                -> full
--       add / backfill / drop / rename;
--   (c) partial/interrupted (FUSION_JE_HEADER_ID_C exists)   -> resume from
--       wherever it stopped (backfill-if-old-still-there, drop-if-present,
--       rename), converging to the same end state.
-- Re-running this file any number of times leaves a single VARCHAR2(100)
-- FUSION_JE_HEADER_ID column with every historical value preserved as text and
-- changes nothing else.
--
-- The create-table script db/tables/dmt_gl_interface_tfm_tbl.sql now creates
-- FUSION_JE_HEADER_ID at VARCHAR2(100) for fresh installs. This migration
-- converges an EXISTING database whose column is still NUMBER. Deploy as
-- DMT2_OWNER (never ADMIN). ci_promote runs every db/migrations file in
-- chronological filename order, so this deploys to GOLD.
-- =========================================================================
set define off
set serveroutput on

prompt == Convert DMT_GL_INTERFACE_TFM_TBL.FUSION_JE_HEADER_ID to VARCHAR2(100) (non-destructive) ==
declare
  l_old_type user_tab_columns.data_type%type;
  l_old_cnt  pls_integer;
  l_new_cnt  pls_integer;
begin
  -- Current state of the ORIGINAL column (may be absent, NUMBER, or already VARCHAR2).
  begin
    select data_type into l_old_type
      from user_tab_columns
     where table_name  = 'DMT_GL_INTERFACE_TFM_TBL'
       and column_name = 'FUSION_JE_HEADER_ID';
  exception
    when no_data_found then
      l_old_type := null;   -- original column not present (pre-recon DB)
  end;

  -- Presence of the scratch/interim VARCHAR2 column.
  select count(*) into l_new_cnt
    from user_tab_columns
   where table_name  = 'DMT_GL_INTERFACE_TFM_TBL'
     and column_name = 'FUSION_JE_HEADER_ID_C';

  -- (a) Already converted: FUSION_JE_HEADER_ID is VARCHAR2 and no interim
  -- column remains -> nothing to do.
  if l_old_type like 'VARCHAR2%' and l_new_cnt = 0 then
    dbms_output.put_line(
      'FUSION_JE_HEADER_ID already ' || l_old_type || ' -- no change (idempotent).');

  else
    -- (b) fresh NUMBER column, or (c) partial/interrupted: add the interim
    -- column if it is not there yet.
    if l_new_cnt = 0 then
      execute immediate
        'ALTER TABLE "DMT_GL_INTERFACE_TFM_TBL" ADD ("FUSION_JE_HEADER_ID_C" VARCHAR2(100))';
      dbms_output.put_line('Added interim column FUSION_JE_HEADER_ID_C VARCHAR2(100).');
    end if;

    -- Backfill from the OLD NUMBER column, but only while it still exists (a
    -- resumed run that already dropped the old column skips this cleanly).
    -- Preserves every historical row's proof-of-load id as text.
    if l_old_type = 'NUMBER' then
      execute immediate
        'UPDATE "DMT_GL_INTERFACE_TFM_TBL" '
        || 'SET "FUSION_JE_HEADER_ID_C" = TO_CHAR("FUSION_JE_HEADER_ID") '
        || 'WHERE "FUSION_JE_HEADER_ID" IS NOT NULL '
        || 'AND "FUSION_JE_HEADER_ID_C" IS NULL';
      l_old_cnt := sql%rowcount;
      commit;
      dbms_output.put_line(
        'Backfilled ' || l_old_cnt || ' historical id(s) into FUSION_JE_HEADER_ID_C as text.');

      -- Drop the old NUMBER column (now that its values are preserved as text).
      execute immediate
        'ALTER TABLE "DMT_GL_INTERFACE_TFM_TBL" DROP COLUMN "FUSION_JE_HEADER_ID"';
      dbms_output.put_line('Dropped old NUMBER column FUSION_JE_HEADER_ID.');
    end if;

    -- Rename the interim column into place. If a resumed run already renamed
    -- it, FUSION_JE_HEADER_ID_C is gone and this is skipped.
    select count(*) into l_new_cnt
      from user_tab_columns
     where table_name  = 'DMT_GL_INTERFACE_TFM_TBL'
       and column_name = 'FUSION_JE_HEADER_ID_C';
    if l_new_cnt = 1 then
      execute immediate
        'ALTER TABLE "DMT_GL_INTERFACE_TFM_TBL" '
        || 'RENAME COLUMN "FUSION_JE_HEADER_ID_C" TO "FUSION_JE_HEADER_ID"';
      dbms_output.put_line(
        'Renamed FUSION_JE_HEADER_ID_C -> FUSION_JE_HEADER_ID (now VARCHAR2(100), history preserved).');
    end if;
  end if;
end;
/

prompt == Set line-grain composite comment on FUSION_JE_HEADER_ID ==
COMMENT ON COLUMN "DMT_GL_INTERFACE_TFM_TBL"."FUSION_JE_HEADER_ID" IS 'Positive proof of load at journal-LINE grain: JE_HEADER_ID~JE_LINE_NUM from GL_JE_LINES (base table). Written only by BIP reconciliation.';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-09-24_gl_fusion_line_key.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'glfusionlinekey', USER);

commit;
