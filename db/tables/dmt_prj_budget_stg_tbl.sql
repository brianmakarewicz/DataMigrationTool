-- DMT_PRJ_BUDGET_STG_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_PRJ_BUDGET_STG_TBL" 
   (	"AWARD_NUMBER" VARCHAR2(240), 
	"FINANCIAL_PLAN_TYPE" VARCHAR2(150), 
	"PROJECT_NUMBER" VARCHAR2(25), 
	"PROJECT_NAME" VARCHAR2(240), 
	"TASK_NAME" VARCHAR2(255), 
	"TASK_NUMBER" VARCHAR2(100), 
	"PLAN_VERSION_NAME" VARCHAR2(240), 
	"PLAN_VERSION_DESCRIPTION" VARCHAR2(2000), 
	"PLAN_VERSION_STATUS" VARCHAR2(30), 
	"RESOURCE_NAME" VARCHAR2(240), 
	"PERIOD_NAME" VARCHAR2(50), 
	"PLANNING_CURRENCY" VARCHAR2(15), 
	"TOTAL_QUANTITY" NUMBER, 
	"TOTAL_TC_RAW_COST" NUMBER, 
	"TOTAL_TC_REVENUE" NUMBER, 
	"SRC_BUDGET_LINE_REFERENCE" VARCHAR2(240), 
	"FUNDING_SOURCE_NUMBER" VARCHAR2(240), 
	"FUNDING_SOURCE_NAME" VARCHAR2(240), 
	"PC_RAW_COST" NUMBER, 
	"PC_REVENUE" NUMBER, 
	"PFC_RAW_COST" NUMBER, 
	"PFC_REVENUE" NUMBER, 
	"TOTAL_TC_BRDND_COST" NUMBER, 
	"PC_BRDND_COST" NUMBER, 
	"PFC_BRDND_COST" NUMBER, 
	"LINE_TYPE" VARCHAR2(30), 
	"PLANNING_START_DATE" DATE, 
	"PLANNING_END_DATE" DATE, 
	"ATTRIBUTE_CATEGORY" VARCHAR2(150), 
	"ATTRIBUTE1" VARCHAR2(240), 
	"ATTRIBUTE2" VARCHAR2(240), 
	"ATTRIBUTE3" VARCHAR2(240), 
	"ATTRIBUTE4" VARCHAR2(240), 
	"ATTRIBUTE5" VARCHAR2(240), 
	"ATTRIBUTE6" VARCHAR2(240), 
	"ATTRIBUTE7" VARCHAR2(240), 
	"ATTRIBUTE8" VARCHAR2(240), 
	"ATTRIBUTE9" VARCHAR2(240), 
	"ATTRIBUTE10" VARCHAR2(240), 
	"ATTRIBUTE11" VARCHAR2(240), 
	"ATTRIBUTE12" VARCHAR2(240), 
	"ATTRIBUTE13" VARCHAR2(240), 
	"ATTRIBUTE14" VARCHAR2(240), 
	"ATTRIBUTE15" VARCHAR2(240), 
	"ATTRIBUTE16" VARCHAR2(240), 
	"ATTRIBUTE17" VARCHAR2(240), 
	"ATTRIBUTE18" VARCHAR2(240), 
	"ATTRIBUTE19" VARCHAR2(240), 
	"ATTRIBUTE20" VARCHAR2(240), 
	"ATTRIBUTE21" VARCHAR2(240), 
	"ATTRIBUTE22" VARCHAR2(240), 
	"ATTRIBUTE23" VARCHAR2(240), 
	"ATTRIBUTE24" VARCHAR2(240), 
	"ATTRIBUTE25" VARCHAR2(240), 
	"ATTRIBUTE26" VARCHAR2(240), 
	"ATTRIBUTE27" VARCHAR2(240), 
	"ATTRIBUTE28" VARCHAR2(240), 
	"ATTRIBUTE29" VARCHAR2(240), 
	"ATTRIBUTE30" VARCHAR2(240), 
	"PLAN_VERSION_NUMBER" NUMBER, 
	"PROCESSING_MODE" VARCHAR2(30), 
	"STG_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_PRJ_BUDGET_STG_SEQ.NEXTVAL NOT NULL ENABLE, 
	"SCENARIO_ID" NUMBER, 
	"STAGE_DATE" DATE DEFAULT SYSDATE, 
	"STG_STATUS" VARCHAR2(30) DEFAULT ''NEW'' NOT NULL ENABLE, 
	"ERROR_TEXT" CLOB, 
	"SOURCE_ID" VARCHAR2(240), 
	"LAST_UPDATED_DATE" DATE, 
	 CONSTRAINT "DMT_PRJ_BUDGET_STG_PK" PRIMARY KEY ("STG_SEQUENCE_ID")
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
  where  table_name = 'DMT_PRJ_BUDGET_STG_TBL' and column_name = 'STATUS';
  if l_n = 1 then
    execute immediate 'ALTER TABLE "DMT_PRJ_BUDGET_STG_TBL" RENAME COLUMN "STATUS" TO "STG_STATUS"';
  end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_PRJ_BUDGET_STG_TBL_N1" ON "DMT_PRJ_BUDGET_STG_TBL" ("STG_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

-- ---------------------------------------------------------------------------
-- 2026-07-08 conformance tranche (design section 7: STG/TFM infra-column
-- dictionary + contract-index dictionary): converges a pre-existing database.
-- Fresh installs already get the final shape from the CREATE above.
-- ---------------------------------------------------------------------------
begin
  execute immediate 'CREATE INDEX "DMT_PRJ_BUDGET_STG_N1" ON "DMT_PRJ_BUDGET_STG_TBL" ("SCENARIO_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_PRJ_BUDGET_STG_TBL"."STG_STATUS" IS 'Staging lifecycle: NEW > TRANSFORMED / FAILED. Forward-only, never reset; errors accumulate in ERROR_TEXT.';

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
   where table_name = 'DMT_PRJ_BUDGET_STG_TBL' and column_name = 'STG_STATUS';
  if l_nullable = 'Y' then
    execute immediate 'UPDATE "DMT_PRJ_BUDGET_STG_TBL" SET "STG_STATUS" = ''NEW'' WHERE "STG_STATUS" IS NULL';
    execute immediate 'ALTER TABLE "DMT_PRJ_BUDGET_STG_TBL" MODIFY ("STG_STATUS" DEFAULT ''NEW'' NOT NULL)';
  end if;
end;
/
