-- DMT_GL_BUDGET_INT_STG_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_GL_BUDGET_INT_STG_TBL" 
   (	"STG_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_GL_BUDGET_INT_STG_SEQ.NEXTVAL NOT NULL ENABLE, 
	"RUN_NAME" VARCHAR2(240), 
	"LEDGER_ID" NUMBER, 
	"BUDGET_NAME" VARCHAR2(100), 
	"BUDGET_ENTITY_NAME" VARCHAR2(240), 
	"PERIOD_NAME" VARCHAR2(15), 
	"CURRENCY_CODE" VARCHAR2(15), 
	"JOURNAL_STATUS" VARCHAR2(50), 
	"SEGMENT1" VARCHAR2(25), 
	"SEGMENT2" VARCHAR2(25), 
	"SEGMENT3" VARCHAR2(25), 
	"SEGMENT4" VARCHAR2(25), 
	"SEGMENT5" VARCHAR2(25), 
	"SEGMENT6" VARCHAR2(25), 
	"SEGMENT7" VARCHAR2(25), 
	"SEGMENT8" VARCHAR2(25), 
	"SEGMENT9" VARCHAR2(25), 
	"SEGMENT10" VARCHAR2(25), 
	"SEGMENT11" VARCHAR2(25), 
	"SEGMENT12" VARCHAR2(25), 
	"SEGMENT13" VARCHAR2(25), 
	"SEGMENT14" VARCHAR2(25), 
	"SEGMENT15" VARCHAR2(25), 
	"SEGMENT16" VARCHAR2(25), 
	"SEGMENT17" VARCHAR2(25), 
	"SEGMENT18" VARCHAR2(25), 
	"SEGMENT19" VARCHAR2(25), 
	"SEGMENT20" VARCHAR2(25), 
	"SEGMENT21" VARCHAR2(25), 
	"SEGMENT22" VARCHAR2(25), 
	"SEGMENT23" VARCHAR2(25), 
	"SEGMENT24" VARCHAR2(25), 
	"SEGMENT25" VARCHAR2(25), 
	"SEGMENT26" VARCHAR2(25), 
	"SEGMENT27" VARCHAR2(25), 
	"SEGMENT28" VARCHAR2(25), 
	"SEGMENT29" VARCHAR2(25), 
	"SEGMENT30" VARCHAR2(25), 
	"BUDGET_AMOUNT" NUMBER, 
	"LEDGER_NAME" VARCHAR2(240), 
	"STAGE_DATE" DATE DEFAULT SYSDATE, 
	"STG_STATUS" VARCHAR2(30) DEFAULT ''NEW'' NOT NULL ENABLE, 
	"ERROR_TEXT" CLOB, 
	"SOURCE_ID" VARCHAR2(240), 
	"LAST_UPDATED_DATE" DATE, 
	"SCENARIO_ID" NUMBER, 
	 CONSTRAINT "DMT_GL_BUDGET_INT_STG_PK" PRIMARY KEY ("STG_SEQUENCE_ID")
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
  where  table_name = 'DMT_GL_BUDGET_INT_STG_TBL' and column_name = 'STATUS';
  if l_n = 1 then
    execute immediate 'ALTER TABLE "DMT_GL_BUDGET_INT_STG_TBL" RENAME COLUMN "STATUS" TO "STG_STATUS"';
  end if;
end;
/

-- ---------------------------------------------------------------------------
-- 2026-07-08 conformance tranche (design section 7: STG/TFM infra-column
-- dictionary + contract-index dictionary): converges a pre-existing database.
-- Fresh installs already get the final shape from the CREATE above.
-- ---------------------------------------------------------------------------
begin
  execute immediate 'CREATE INDEX "DMT_GL_BUDGET_INT_STG_N1" ON "DMT_GL_BUDGET_INT_STG_TBL" ("STG_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_GL_BUDGET_INT_STG_N2" ON "DMT_GL_BUDGET_INT_STG_TBL" ("SCENARIO_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_GL_BUDGET_INT_STG_TBL"."STG_STATUS" IS 'Staging lifecycle: NEW > TRANSFORMED / FAILED. Forward-only, never reset; errors accumulate in ERROR_TEXT.';

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
   where table_name = 'DMT_GL_BUDGET_INT_STG_TBL' and column_name = 'STG_STATUS';
  if l_nullable = 'Y' then
    execute immediate 'UPDATE "DMT_GL_BUDGET_INT_STG_TBL" SET "STG_STATUS" = ''NEW'' WHERE "STG_STATUS" IS NULL';
    execute immediate 'ALTER TABLE "DMT_GL_BUDGET_INT_STG_TBL" MODIFY ("STG_STATUS" DEFAULT ''NEW'' NOT NULL)';
  end if;
end;
/
