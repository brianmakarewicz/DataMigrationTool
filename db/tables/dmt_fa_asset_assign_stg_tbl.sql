-- DMT_FA_ASSET_ASSIGN_STG_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_FA_ASSET_ASSIGN_STG_TBL" 
   (	"STG_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_FA_ASSET_ASSIGN_STG_SEQ.NEXTVAL NOT NULL ENABLE, 
	"ASSET_NUMBER" VARCHAR2(30), 
	"UNITS_ASSIGNED" NUMBER, 
	"EXPENSE_ACCOUNT_SEGMENT1" VARCHAR2(25), 
	"EXPENSE_ACCOUNT_SEGMENT2" VARCHAR2(25), 
	"EXPENSE_ACCOUNT_SEGMENT3" VARCHAR2(25), 
	"EXPENSE_ACCOUNT_SEGMENT4" VARCHAR2(25), 
	"EXPENSE_ACCOUNT_SEGMENT5" VARCHAR2(25), 
	"EXPENSE_ACCOUNT_SEGMENT6" VARCHAR2(25), 
	"EXPENSE_ACCOUNT_SEGMENT7" VARCHAR2(25), 
	"EXPENSE_ACCOUNT_SEGMENT8" VARCHAR2(25), 
	"EXPENSE_ACCOUNT_SEGMENT9" VARCHAR2(25), 
	"EXPENSE_ACCOUNT_SEGMENT10" VARCHAR2(25), 
	"LOCATION_SEGMENT1" VARCHAR2(30), 
	"LOCATION_SEGMENT2" VARCHAR2(30), 
	"LOCATION_SEGMENT3" VARCHAR2(30), 
	"LOCATION_SEGMENT4" VARCHAR2(30), 
	"LOCATION_SEGMENT5" VARCHAR2(30), 
	"LOCATION_SEGMENT6" VARCHAR2(30), 
	"LOCATION_SEGMENT7" VARCHAR2(30), 
	"STAGE_DATE" DATE DEFAULT SYSDATE, 
	"STG_STATUS" VARCHAR2(30) DEFAULT ''NEW'' NOT NULL ENABLE, 
	"ERROR_TEXT" CLOB, 
	"SOURCE_ID" VARCHAR2(240), 
	"LAST_UPDATED_DATE" DATE, 
	"SCENARIO_ID" NUMBER, 
	 CONSTRAINT "DMT_FA_ASSET_ASSIGN_STG_PK" PRIMARY KEY ("STG_SEQUENCE_ID")
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
  where  table_name = 'DMT_FA_ASSET_ASSIGN_STG_TBL' and column_name = 'STATUS';
  if l_n = 1 then
    execute immediate 'ALTER TABLE "DMT_FA_ASSET_ASSIGN_STG_TBL" RENAME COLUMN "STATUS" TO "STG_STATUS"';
  end if;
end;
/

-- ---------------------------------------------------------------------------
-- 2026-07-08 conformance tranche (design section 7: STG/TFM infra-column
-- dictionary + contract-index dictionary): converges a pre-existing database.
-- Fresh installs already get the final shape from the CREATE above.
-- ---------------------------------------------------------------------------
begin
  execute immediate 'CREATE INDEX "DMT_FA_ASSET_ASSIGN_STG_N1" ON "DMT_FA_ASSET_ASSIGN_STG_TBL" ("STG_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_FA_ASSET_ASSIGN_STG_N2" ON "DMT_FA_ASSET_ASSIGN_STG_TBL" ("SCENARIO_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_FA_ASSET_ASSIGN_STG_TBL"."STG_STATUS" IS 'Staging lifecycle: NEW > TRANSFORMED / FAILED. Forward-only, never reset; errors accumulate in ERROR_TEXT.';

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
   where table_name = 'DMT_FA_ASSET_ASSIGN_STG_TBL' and column_name = 'STG_STATUS';
  if l_nullable = 'Y' then
    execute immediate 'UPDATE "DMT_FA_ASSET_ASSIGN_STG_TBL" SET "STG_STATUS" = ''NEW'' WHERE "STG_STATUS" IS NULL';
    execute immediate 'ALTER TABLE "DMT_FA_ASSET_ASSIGN_STG_TBL" MODIFY ("STG_STATUS" DEFAULT ''NEW'' NOT NULL)';
  end if;
end;
/
