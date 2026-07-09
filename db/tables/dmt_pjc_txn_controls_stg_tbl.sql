-- DMT_PJC_TXN_CONTROLS_STG_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_PJC_TXN_CONTROLS_STG_TBL" 
   (	"STG_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_PJC_TXN_CONTROLS_STG_SEQ.NEXTVAL NOT NULL ENABLE, 
	"TXN_CTRL_REFERENCE" VARCHAR2(240), 
	"PROJECT_NAME" VARCHAR2(240), 
	"PROJECT_NUMBER" VARCHAR2(25), 
	"TASK_NUMBER" VARCHAR2(100), 
	"TASK_NAME" VARCHAR2(240), 
	"EXPENDITURE_CATEGORY_NAME" VARCHAR2(240), 
	"EXPENDITURE_TYPE" VARCHAR2(240), 
	"NON_LABOR_RESOURCE" VARCHAR2(240), 
	"PERSON_NUMBER" VARCHAR2(30), 
	"PERSON_NAME" VARCHAR2(2000), 
	"PERSON_EMAILID" VARCHAR2(240), 
	"PERSON_TYPE" VARCHAR2(30), 
	"JOB_NAME" VARCHAR2(240), 
	"ORGANIZATION_NAME" VARCHAR2(240), 
	"CHARGEABLE_FLAG" VARCHAR2(1), 
	"BILLABLE_FLAG" VARCHAR2(1), 
	"CAPITALIZABLE_FLAG" VARCHAR2(1), 
	"START_DATE_ACTIVE" DATE, 
	"END_DATE_ACTIVE" DATE, 
	"STAGE_DATE" DATE DEFAULT SYSDATE, 
	"STG_STATUS" VARCHAR2(30) DEFAULT ''NEW'' NOT NULL ENABLE, 
	"ERROR_TEXT" CLOB, 
	"SOURCE_ID" VARCHAR2(240), 
	"LAST_UPDATED_DATE" DATE, 
	"SCENARIO_ID" NUMBER, 
	 CONSTRAINT "DMT_PJC_TXN_CONTROLS_STG_PK" PRIMARY KEY ("STG_SEQUENCE_ID")
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
  where  table_name = 'DMT_PJC_TXN_CONTROLS_STG_TBL' and column_name = 'STATUS';
  if l_n = 1 then
    execute immediate 'ALTER TABLE "DMT_PJC_TXN_CONTROLS_STG_TBL" RENAME COLUMN "STATUS" TO "STG_STATUS"';
  end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_PJC_TXN_CONTROLS_STG_TBL_N1" ON "DMT_PJC_TXN_CONTROLS_STG_TBL" ("STG_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_PJC_TXN_CONTROLS_STG_TBL"."STG_SEQUENCE_ID" IS 'PK - from DMT_PJC_TXN_CONTROLS_STG_SEQ';
COMMENT ON COLUMN "DMT_PJC_TXN_CONTROLS_STG_TBL"."PROJECT_NUMBER" IS 'Project number â€” links transaction control to parent project';
COMMENT ON COLUMN "DMT_PJC_TXN_CONTROLS_STG_TBL"."TASK_NUMBER" IS 'Task number â€” optional; if populated, control applies at task level';
COMMENT ON COLUMN "DMT_PJC_TXN_CONTROLS_STG_TBL"."ERROR_TEXT" IS 'Concatenated errors â€” appended at each step, never overwritten. Prefixed: [PRE_VALIDATION] [TRANSFORM_ERROR] [FUSION_ERROR].';
COMMENT ON TABLE "DMT_PJC_TXN_CONTROLS_STG_TBL"  IS 'Project transaction controls staging. Raw user data only. Run-specific data in DMT_PJC_TXN_CONTROLS_TFM_TBL. FBDI interface: PJC_TXN_CONTROLS_STAGE. CSV: PjcTxnControlsStage.csv.';

-- ---------------------------------------------------------------------------
-- 2026-07-08 conformance tranche (design section 7: STG/TFM infra-column
-- dictionary + contract-index dictionary): converges a pre-existing database.
-- Fresh installs already get the final shape from the CREATE above.
-- ---------------------------------------------------------------------------
begin
  execute immediate 'CREATE INDEX "DMT_PJC_TXN_CONTROLS_STG_N1" ON "DMT_PJC_TXN_CONTROLS_STG_TBL" ("SCENARIO_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_PJC_TXN_CONTROLS_STG_TBL"."STG_STATUS" IS 'Staging lifecycle: NEW > TRANSFORMED / FAILED. Forward-only, never reset; errors accumulate in ERROR_TEXT.';

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
   where table_name = 'DMT_PJC_TXN_CONTROLS_STG_TBL' and column_name = 'STG_STATUS';
  if l_nullable = 'Y' then
    execute immediate 'UPDATE "DMT_PJC_TXN_CONTROLS_STG_TBL" SET "STG_STATUS" = ''NEW'' WHERE "STG_STATUS" IS NULL';
    execute immediate 'ALTER TABLE "DMT_PJC_TXN_CONTROLS_STG_TBL" MODIFY ("STG_STATUS" DEFAULT ''NEW'' NOT NULL)';
  end if;
end;
/
