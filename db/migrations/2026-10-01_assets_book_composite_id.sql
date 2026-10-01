-- =========================================================================
-- Migration: DMT_FA_ASSET_BOOK_TFM_TBL.FUSION_ASSET_ID
--            NUMBER -> VARCHAR2(100), then re-stamp historical LOADED book rows
--            to the per-BOOK composite ASSET_ID~BOOK_TYPE_CODE  (2026-10-01)
-- Backlog #139. docs/DMT_DESIGN.html section 5 ("BIP reconciliation report
-- contract - v1") and section 7 ("Reconciliation captures the Fusion base-table
-- id"). Same pattern proven on GLBalances (PR #451,
-- db/migrations/2026-09-24_gl_fusion_line_key.sql) and Items (PR,
-- db/migrations/2026-09-24_item_fusion_org_key.sql).
--
-- WHY: DMT_FA_ASSET_BOOK_TFM_TBL is per-asset-per-BOOK grained (one asset can
-- have a corporate book AND a tax book), but the results package cascaded only
-- the parent header's bare FUSION_ASSET_ID (FA_ADDITIONS_B.ASSET_ID) onto every
-- book row. Two book rows for the SAME asset then carried the SAME id, so the
-- read-only Fusion-id auditor's UNIQUE check (scripts/dmt_fusion_id_audit.sql)
-- was only valid under one-book-per-asset -- a false uniqueness assumption at
-- the book grain the table is actually at. A transform row's Fusion id must be
-- positive proof of load AT THAT ROW'S GRAIN. The results package now stamps the
-- per-BOOK composite 'ASSET_ID~BOOK_TYPE_CODE' (the header's confirmed base-table
-- id joined to this book row's own BOOK_TYPE_CODE), which is a string -- so the
-- column must become VARCHAR2 to hold it, following the contract's '~'-joined
-- composite-key convention. A corporate book and a tax book of one asset then
-- get DIFFERENT proof values.
--
-- NOT a Fusion round-trip: the book composite is assembled LOCALLY in
-- DMT_FA_ASSET_RESULTS_PKG from two already-captured real values (the header's
-- confirmed FA_ADDITIONS_B.ASSET_ID and the book row's own BOOK_TYPE_CODE). The
-- book tier has no BIP report tier of its own and nothing is read back from
-- Fusion at book grain, so NO BIP data-model change and NO Fusion deploy are
-- required by this migration.
--
-- NON-DESTRUCTIVE (backfill-and-rename, then re-stamp). FUSION_ASSET_ID is
-- recon-derived proof of load. Any historical value is real proof and must NOT
-- be thrown away. A NUMBER -> VARCHAR2 MODIFY in place fails with ORA-01439
-- unless the column is empty, so instead of NULLing the data we:
--   1. add a new VARCHAR2(100) column FUSION_ASSET_ID_C,
--   2. backfill it with TO_CHAR of every existing (non-null) NUMBER value --
--      preserving each historical row's proof-of-load id as text,
--   3. drop the old NUMBER column, and
--   4. rename the new column to FUSION_ASSET_ID.
-- Then, because the Assets book composite is composed locally (not round-tripped
-- from Fusion), we immediately re-stamp every historical LOADED book row whose id
-- is still the bare asset id (no '~') to the composite 'ASSET_ID~BOOK_TYPE_CODE'
-- using that row's own BOOK_TYPE_CODE. This preserves the captured asset id (it
-- becomes the prefix of the composite) and makes existing LOADED rows satisfy the
-- book-grain UNIQUE check without a re-run. TFM_STATUS is never touched; only
-- LOADED rows with a non-null id and no '~' are suffixed, so a FAILED/GENERATED
-- row (null id) and an already-composite row are left alone.
--
-- IDEMPOTENT / GUARDED for ALL states, branching on USER_TAB_COLUMNS:
--   (a) already-converted (FUSION_ASSET_ID is VARCHAR2)  -> skip the type change;
--   (b) fresh NUMBER column, no _C column yet            -> full
--       add / backfill / drop / rename;
--   (c) partial/interrupted (FUSION_ASSET_ID_C exists)   -> resume.
-- The re-stamp step (d) runs every time but only touches bare-id LOADED rows
-- (WHERE ... NOT LIKE '%~%'), so re-running the file any number of times leaves a
-- single VARCHAR2(100) FUSION_ASSET_ID column holding the composite on every
-- LOADED book row, every historical value preserved, and changes nothing else.
--
-- The create-table script db/tables/dmt_fa_asset_book_tfm_tbl.sql now creates
-- FUSION_ASSET_ID at VARCHAR2(100) for fresh installs. This migration converges
-- an EXISTING database whose column is still NUMBER. Deploy as DMT2_OWNER (never
-- ADMIN). ci_promote runs every db/migrations file in chronological filename
-- order, so this deploys to GOLD.
-- =========================================================================
set define off
set serveroutput on

prompt == Convert DMT_FA_ASSET_BOOK_TFM_TBL.FUSION_ASSET_ID to VARCHAR2(100) (non-destructive) ==
declare
  l_old_type user_tab_columns.data_type%type;
  l_old_cnt  pls_integer;
  l_new_cnt  pls_integer;
begin
  -- Current state of the ORIGINAL column (may be absent, NUMBER, or already VARCHAR2).
  begin
    select data_type into l_old_type
      from user_tab_columns
     where table_name  = 'DMT_FA_ASSET_BOOK_TFM_TBL'
       and column_name = 'FUSION_ASSET_ID';
  exception
    when no_data_found then
      l_old_type := null;   -- original column not present
  end;

  -- Presence of the scratch/interim VARCHAR2 column.
  select count(*) into l_new_cnt
    from user_tab_columns
   where table_name  = 'DMT_FA_ASSET_BOOK_TFM_TBL'
     and column_name = 'FUSION_ASSET_ID_C';

  -- (a) Already converted -> nothing to do on the type change.
  if l_old_type like 'VARCHAR2%' and l_new_cnt = 0 then
    dbms_output.put_line(
      'FUSION_ASSET_ID already ' || l_old_type || ' -- no type change (idempotent).');

  else
    -- (b) fresh NUMBER column, or (c) partial/interrupted: add the interim
    -- column if it is not there yet.
    if l_new_cnt = 0 then
      execute immediate
        'ALTER TABLE "DMT_FA_ASSET_BOOK_TFM_TBL" ADD ("FUSION_ASSET_ID_C" VARCHAR2(100))';
      dbms_output.put_line('Added interim column FUSION_ASSET_ID_C VARCHAR2(100).');
    end if;

    -- Backfill from the OLD NUMBER column, but only while it still exists.
    -- Preserves every historical row's proof-of-load id as text.
    if l_old_type = 'NUMBER' then
      execute immediate
        'UPDATE "DMT_FA_ASSET_BOOK_TFM_TBL" '
        || 'SET "FUSION_ASSET_ID_C" = TO_CHAR("FUSION_ASSET_ID") '
        || 'WHERE "FUSION_ASSET_ID" IS NOT NULL '
        || 'AND "FUSION_ASSET_ID_C" IS NULL';
      l_old_cnt := sql%rowcount;
      commit;
      dbms_output.put_line(
        'Backfilled ' || l_old_cnt || ' historical id(s) into FUSION_ASSET_ID_C as text.');

      -- Drop the old NUMBER column (now that its values are preserved as text).
      execute immediate
        'ALTER TABLE "DMT_FA_ASSET_BOOK_TFM_TBL" DROP COLUMN "FUSION_ASSET_ID"';
      dbms_output.put_line('Dropped old NUMBER column FUSION_ASSET_ID.');
    end if;

    -- Rename the interim column into place.
    select count(*) into l_new_cnt
      from user_tab_columns
     where table_name  = 'DMT_FA_ASSET_BOOK_TFM_TBL'
       and column_name = 'FUSION_ASSET_ID_C';
    if l_new_cnt = 1 then
      execute immediate
        'ALTER TABLE "DMT_FA_ASSET_BOOK_TFM_TBL" '
        || 'RENAME COLUMN "FUSION_ASSET_ID_C" TO "FUSION_ASSET_ID"';
      dbms_output.put_line(
        'Renamed FUSION_ASSET_ID_C -> FUSION_ASSET_ID (now VARCHAR2(100), history preserved).');
    end if;
  end if;
end;
/

prompt == (d) Re-stamp historical LOADED book rows to the per-BOOK composite ASSET_ID~BOOK_TYPE_CODE ==
-- Only bare-id LOADED rows (no '~') are suffixed with their own BOOK_TYPE_CODE;
-- the captured asset id is preserved as the composite prefix. Null-id and
-- already-composite rows are left untouched, so this is idempotent.
declare
  l_n pls_integer;
begin
  update "DMT_FA_ASSET_BOOK_TFM_TBL"
     set "FUSION_ASSET_ID" = "FUSION_ASSET_ID" || '~' || "BOOK_TYPE_CODE",
         "LAST_UPDATED_DATE" = sysdate
   where "TFM_STATUS"      = 'LOADED'
     and "FUSION_ASSET_ID" is not null
     and "FUSION_ASSET_ID" not like '%~%'
     and "BOOK_TYPE_CODE"  is not null;
  l_n := sql%rowcount;
  commit;
  dbms_output.put_line('Re-stamped ' || l_n ||
    ' historical LOADED book row(s) to the ASSET_ID~BOOK_TYPE_CODE composite.');
end;
/

prompt == Set book-grain composite comment on FUSION_ASSET_ID ==
COMMENT ON COLUMN "DMT_FA_ASSET_BOOK_TFM_TBL"."FUSION_ASSET_ID" IS 'Positive proof of load at the asset-BOOK grain: the composite ASSET_ID~BOOK_TYPE_CODE (FA_ADDITIONS_B.ASSET_ID from the parent header, joined to this book row''s BOOK_TYPE_CODE). A corporate book and a tax book of the same asset therefore carry DIFFERENT values, so the Fusion-id auditor UNIQUE check is valid at book grain (backlog #139; mirrors GLBalances JE_HEADER_ID~JE_LINE_NUM). Written only by the DMT_FA_ASSET_RESULTS_PKG cascade.';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-01_assets_book_composite_id.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'assetsbookcomposite', USER);

commit;
