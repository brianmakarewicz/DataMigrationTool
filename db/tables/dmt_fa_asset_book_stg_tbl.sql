-- DMT_FA_ASSET_BOOK_STG_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_FA_ASSET_BOOK_STG_TBL" 
   (	"STG_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_FA_ASSET_BOOK_STG_SEQ.NEXTVAL NOT NULL ENABLE, 
	"ASSET_NUMBER" VARCHAR2(30), 
	"BOOK_TYPE_CODE" VARCHAR2(30), 
	"COST" NUMBER, 
	"ORIGINAL_COST" NUMBER, 
	"SALVAGE_VALUE" NUMBER, 
	"LIFE_IN_MONTHS" NUMBER, 
	"DEPRECIATION_METHOD" VARCHAR2(30), 
	"DATE_PLACED_IN_SERVICE" DATE, 
	"PRORATE_CONVENTION_CODE" VARCHAR2(30), 
	"DEPRN_START_DATE" DATE, 
	"CURRENT_UNITS" NUMBER, 
	"UNREVALUED_COST" NUMBER, 
	"YTD_DEPRN" NUMBER, 
	"DEPRN_RESERVE" NUMBER, 
	"BONUS_YTD_DEPRN" NUMBER, 
	"BONUS_DEPRN_RESERVE" NUMBER, 
	"STAGE_DATE" DATE DEFAULT SYSDATE, 
	"STG_STATUS" VARCHAR2(30) DEFAULT ''NEW'', 
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
