-- =========================================================================
-- Migration: DMT_EGP_ITEM_TFM_TBL.FUSION_INVENTORY_ITEM_ID
--            NUMBER -> VARCHAR2(100)  (2026-09-24)
-- docs/DMT_DESIGN.html section 5 ("BIP reconciliation report contract - v1")
-- and section 7 ("Reconciliation captures the Fusion base-table id").
-- Backlog #86 (Items per-org grain Fusion id). Same pattern proven on
-- GLBalances (PR #451, db/migrations/2026-09-24_gl_fusion_line_key.sql) and
-- AP Invoice lines (PR #456, db/migrations/2026-09-24_ap_invoice_lines_fusion_line_key.sql).
--
-- WHY: DMT_EGP_ITEM_TFM_TBL is per-item-per-ORG grained (an inventory item is
-- loaded PER ORGANIZATION), but the reconciler stamped only the bare
-- INVENTORY_ITEM_ID into FUSION_INVENTORY_ITEM_ID, dropping the org. Two rows
-- for the same item in different orgs then carried the SAME id, so a row's
-- proof did not confirm the RIGHT org. A transform row's Fusion id must be
-- positive proof of load AT THAT ROW'S GRAIN. The reconciler now stamps the
-- per-org composite 'INVENTORY_ITEM_ID~ORGANIZATION_ID' (from EGP_SYSTEM_ITEMS_B,
-- the base table), which is a string -- so the column must become VARCHAR2 to
-- hold it, following the contract's '~'-joined composite-key convention. Two
-- orgs of one item then get DIFFERENT proof values. (Item CATEGORIES are a
-- separate tier with their own FUSION_CATEGORY_ID and are unchanged here.)
--
-- NON-DESTRUCTIVE (backfill-and-rename). FUSION_INVENTORY_ITEM_ID is
-- recon-derived proof of load. Any historical value is real proof and must NOT
-- be thrown away. A NUMBER -> VARCHAR2 MODIFY in place fails with ORA-01439
-- unless the column is empty, so instead of NULLing the data we:
--   1. add a new VARCHAR2(100) column FUSION_INVENTORY_ITEM_ID_C,
--   2. backfill it with TO_CHAR of every existing (non-null) NUMBER value --
--      preserving each historical row's proof-of-load as text,
--   3. drop the old NUMBER column, and
--   4. rename the new column to FUSION_INVENTORY_ITEM_ID.
-- The next reconcile re-stamps LOADED rows with the per-org composite; until
-- then, historical rows keep their (text) value. TFM_STATUS is never touched.
-- This preserves historical run data (carried-over rule 4) and never
-- manufactures a LOADED-with-NULL-id false positive.
--
-- IDEMPOTENT / GUARDED for ALL states, branching on USER_TAB_COLUMNS:
--   (a) already-converted (FUSION_INVENTORY_ITEM_ID is VARCHAR2)  -> no-op;
--   (b) fresh NUMBER column, no _C column yet                     -> full
--       add / backfill / drop / rename;
--   (c) partial/interrupted (FUSION_INVENTORY_ITEM_ID_C exists)   -> resume.
-- Re-running this file any number of times leaves a single VARCHAR2(100)
-- FUSION_INVENTORY_ITEM_ID column with every historical value preserved as
-- text and changes nothing else.
--
-- The create-table script db/tables/dmt_egp_item_tfm_tbl.sql now creates
-- FUSION_INVENTORY_ITEM_ID at VARCHAR2(100) for fresh installs. This migration
-- converges an EXISTING database whose column is still NUMBER. Deploy as
-- DMT2_OWNER (never ADMIN). ci_promote runs every db/migrations file in
-- chronological filename order, so this deploys to GOLD.
-- =========================================================================
set define off
set serveroutput on

prompt == Convert DMT_EGP_ITEM_TFM_TBL.FUSION_INVENTORY_ITEM_ID to VARCHAR2(100) (non-destructive) ==
declare
  l_old_type user_tab_columns.data_type%type;
  l_old_cnt  pls_integer;
  l_new_cnt  pls_integer;
begin
  -- Current state of the ORIGINAL column (may be absent, NUMBER, or already VARCHAR2).
  begin
    select data_type into l_old_type
      from user_tab_columns
     where table_name  = 'DMT_EGP_ITEM_TFM_TBL'
       and column_name = 'FUSION_INVENTORY_ITEM_ID';
  exception
    when no_data_found then
      l_old_type := null;   -- original column not present
  end;

  -- Presence of the scratch/interim VARCHAR2 column.
  select count(*) into l_new_cnt
    from user_tab_columns
   where table_name  = 'DMT_EGP_ITEM_TFM_TBL'
     and column_name = 'FUSION_INVENTORY_ITEM_ID_C';

  -- (a) Already converted -> nothing to do.
  if l_old_type like 'VARCHAR2%' and l_new_cnt = 0 then
    dbms_output.put_line(
      'FUSION_INVENTORY_ITEM_ID already ' || l_old_type || ' -- no change (idempotent).');

  else
    -- (b) fresh NUMBER column, or (c) partial/interrupted: add the interim
    -- column if it is not there yet.
    if l_new_cnt = 0 then
      execute immediate
        'ALTER TABLE "DMT_EGP_ITEM_TFM_TBL" ADD ("FUSION_INVENTORY_ITEM_ID_C" VARCHAR2(100))';
      dbms_output.put_line('Added interim column FUSION_INVENTORY_ITEM_ID_C VARCHAR2(100).');
    end if;

    -- Backfill from the OLD NUMBER column, but only while it still exists.
    -- Preserves every historical row's proof-of-load id as text.
    if l_old_type = 'NUMBER' then
      execute immediate
        'UPDATE "DMT_EGP_ITEM_TFM_TBL" '
        || 'SET "FUSION_INVENTORY_ITEM_ID_C" = TO_CHAR("FUSION_INVENTORY_ITEM_ID") '
        || 'WHERE "FUSION_INVENTORY_ITEM_ID" IS NOT NULL '
        || 'AND "FUSION_INVENTORY_ITEM_ID_C" IS NULL';
      l_old_cnt := sql%rowcount;
      commit;
      dbms_output.put_line(
        'Backfilled ' || l_old_cnt || ' historical id(s) into FUSION_INVENTORY_ITEM_ID_C as text.');

      -- Drop the old NUMBER column (now that its values are preserved as text).
      execute immediate
        'ALTER TABLE "DMT_EGP_ITEM_TFM_TBL" DROP COLUMN "FUSION_INVENTORY_ITEM_ID"';
      dbms_output.put_line('Dropped old NUMBER column FUSION_INVENTORY_ITEM_ID.');
    end if;

    -- Rename the interim column into place.
    select count(*) into l_new_cnt
      from user_tab_columns
     where table_name  = 'DMT_EGP_ITEM_TFM_TBL'
       and column_name = 'FUSION_INVENTORY_ITEM_ID_C';
    if l_new_cnt = 1 then
      execute immediate
        'ALTER TABLE "DMT_EGP_ITEM_TFM_TBL" '
        || 'RENAME COLUMN "FUSION_INVENTORY_ITEM_ID_C" TO "FUSION_INVENTORY_ITEM_ID"';
      dbms_output.put_line(
        'Renamed FUSION_INVENTORY_ITEM_ID_C -> FUSION_INVENTORY_ITEM_ID (now VARCHAR2(100), history preserved).');
    end if;
  end if;
end;
/

prompt == Set per-org composite comment on FUSION_INVENTORY_ITEM_ID ==
COMMENT ON COLUMN "DMT_EGP_ITEM_TFM_TBL"."FUSION_INVENTORY_ITEM_ID" IS 'line-grain proof: INVENTORY_ITEM_ID~ORGANIZATION_ID from EGP_SYSTEM_ITEMS_B. Written only by BIP reconciliation (positive proof of load at the per-org grain).';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-09-24_item_fusion_org_key.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'itemfusionorgkey', USER);

commit;
