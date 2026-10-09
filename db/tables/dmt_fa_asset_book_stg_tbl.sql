-- DMT_FA_ASSET_BOOK_STG_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_FA_ASSET_BOOK_STG_TBL" 
   (	"STG_SEQUENCE_ID" NUMBER GENERATED ALWAYS AS IDENTITY NOT NULL ENABLE, 
	"ASSET_NUMBER" VARCHAR2(30), 
	"BOOK_TYPE_CODE" VARCHAR2(30), 
	"COST" NUMBER, 
	"ORIGINAL_COST" NUMBER, 
	"SALVAGE_VALUE" NUMBER, 
	"LIFE_IN_MONTHS" NUMBER, 
	"DEPRECIATION_METHOD" VARCHAR2(12), 
	"DATE_PLACED_IN_SERVICE" DATE, 
	"PRORATE_CONVENTION_CODE" VARCHAR2(10), 
	"DEPRN_START_DATE" DATE, 
	"CURRENT_UNITS" NUMBER, 
	"UNREVALUED_COST" NUMBER, 
	"YTD_DEPRN" NUMBER, 
	"DEPRN_RESERVE" NUMBER, 
	"BONUS_YTD_DEPRN" NUMBER, 
	"BONUS_DEPRN_RESERVE" NUMBER, 
	"STAGE_DATE" DATE DEFAULT SYSDATE, 
	"STG_STATUS" VARCHAR2(30) DEFAULT ''NEW'' NOT NULL ENABLE, 
	"ERROR_TEXT" CLOB, 
	"SOURCE_ID" VARCHAR2(240), 
	"LAST_UPDATED_DATE" DATE, 
	"SCENARIO_ID" NUMBER, 
	 CONSTRAINT "DMT_FA_ASSET_BOOK_STG_PK" PRIMARY KEY ("STG_SEQUENCE_ID")
  USING INDEX  ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

-- 2026-07-08 conformance tranche: rename must precede the index DDL below
-- (a pre-existing database still has the old column when the index runs).
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_FA_ASSET_BOOK_STG_TBL' and column_name = 'STATUS';
  if l_n = 1 then
    execute immediate 'ALTER TABLE "DMT_FA_ASSET_BOOK_STG_TBL" RENAME COLUMN "STATUS" TO "STG_STATUS"';
  end if;
end;
/

-- ---------------------------------------------------------------------------
-- 2026-07-08 conformance tranche (design section 7: STG/TFM infra-column
-- dictionary + contract-index dictionary): converges a pre-existing database.
-- Fresh installs already get the final shape from the CREATE above.
-- ---------------------------------------------------------------------------
begin
  execute immediate 'CREATE INDEX "DMT_FA_ASSET_BOOK_STG_N1" ON "DMT_FA_ASSET_BOOK_STG_TBL" ("STG_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_FA_ASSET_BOOK_STG_N2" ON "DMT_FA_ASSET_BOOK_STG_TBL" ("SCENARIO_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_FA_ASSET_BOOK_STG_TBL"."STG_STATUS" IS 'Staging lifecycle: NEW > TRANSFORMED / FAILED. Forward-only, never reset; errors accumulate in ERROR_TEXT.';

-- ---------------------------------------------------------------------------
-- 2026-07-09 conformance review F2 (STG/TFM infra-column dictionary, design
-- section 7 accepted 2026-07-08): STG_STATUS is VARCHAR2(30) DEFAULT 'NEW'
-- NOT NULL. Backfills any NULL statuses to the default, then converges a
-- pre-existing database; fresh installs get the shape from the CREATE above.
-- ---------------------------------------------------------------------------
declare
  l_nullable varchar2(1);
begin
  select nullable into l_nullable from user_tab_columns
   where table_name = 'DMT_FA_ASSET_BOOK_STG_TBL' and column_name = 'STG_STATUS';
  if l_nullable = 'Y' then
    execute immediate 'UPDATE "DMT_FA_ASSET_BOOK_STG_TBL" SET "STG_STATUS" = ''NEW'' WHERE "STG_STATUS" IS NULL';
    execute immediate 'ALTER TABLE "DMT_FA_ASSET_BOOK_STG_TBL" MODIFY ("STG_STATUS" DEFAULT ''NEW'' NOT NULL)';
  end if;
end;
/

-- ---------------------------------------------------------------------------
-- 2026-10-09 backlog #574 (owner rule: field width is constrained by the STG
-- and TFM tables). These columns now match the Fusion FBDI interface column
-- FA_MASS_ADDITIONS.METHOD_CODE (12) / PRORATE_CONVENTION_CODE (10), so a value too long for Fusion is
-- rejected here, when it is staged, with a clear error naming the column,
-- instead of by SQL*Loader (which rolls back the whole book). Re-runnable and
-- non-destructive: widening is always applied; narrowing is applied only when
-- no existing row is longer than the new width, otherwise the column is left as
-- it is and a line says so. Data is never truncated. Fresh installs get these
-- widths from the CREATE above.
-- ---------------------------------------------------------------------------
declare
  procedure fit_width (p_col in varchar2, p_len in pls_integer) is
    l_cur pls_integer;
    l_max pls_integer;
  begin
    select char_length into l_cur from user_tab_columns
     where table_name = 'DMT_FA_ASSET_BOOK_STG_TBL' and column_name = p_col;
    if l_cur < p_len then
      execute immediate 'ALTER TABLE "DMT_FA_ASSET_BOOK_STG_TBL" MODIFY ("' || p_col || '" VARCHAR2(' || p_len || '))';
    elsif l_cur > p_len then
      execute immediate 'SELECT NVL(MAX(LENGTH("' || p_col || '")), 0) FROM "DMT_FA_ASSET_BOOK_STG_TBL"' into l_max;
      if l_max <= p_len then
        execute immediate 'ALTER TABLE "DMT_FA_ASSET_BOOK_STG_TBL" MODIFY ("' || p_col || '" VARCHAR2(' || p_len || '))';
      else
        dbms_output.put_line('DMT_FA_ASSET_BOOK_STG_TBL.' || p_col || ' left at ' || l_cur
          || ': existing rows hold values up to ' || l_max || ' characters (target ' || p_len || ').');
      end if;
    end if;
  end fit_width;
begin
  fit_width('DEPRECIATION_METHOD', 12);
  fit_width('PRORATE_CONVENTION_CODE', 10);
end;
/
