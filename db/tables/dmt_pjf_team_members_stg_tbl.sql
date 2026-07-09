-- DMT_PJF_TEAM_MEMBERS_STG_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_PJF_TEAM_MEMBERS_STG_TBL" 
   (	"STG_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_PJF_TEAM_MEMBERS_STG_SEQ.NEXTVAL NOT NULL ENABLE, 
	"PROJECT_NAME" VARCHAR2(240), 
	"TEAM_MEMBER_NUMBER" VARCHAR2(30), 
	"TEAM_MEMBER_NAME" VARCHAR2(240), 
	"TEAM_MEMBER_EMAIL" VARCHAR2(240), 
	"PROJECT_ROLE_NAME" VARCHAR2(240), 
	"START_DATE_ACTIVE" DATE, 
	"END_DATE_ACTIVE" DATE, 
	"TRACK_TIME_FLAG" VARCHAR2(1), 
	"ALLOCATION" NUMBER, 
	"EFFORT" NUMBER, 
	"COST_RATE" NUMBER, 
	"BILL_RATE" NUMBER, 
	"ASSIGNMENT_TYPE" VARCHAR2(30), 
	"BILLABLE_PERCENT" NUMBER, 
	"BILLABLE_PERCENT_REASON_CODE" VARCHAR2(30), 
	"STAGE_DATE" DATE DEFAULT SYSDATE, 
	"STG_STATUS" VARCHAR2(30) DEFAULT ''NEW'' NOT NULL ENABLE, 
	"ERROR_TEXT" CLOB, 
	"SOURCE_ID" VARCHAR2(240), 
	"LAST_UPDATED_DATE" DATE, 
	"SCENARIO_ID" NUMBER, 
	 CONSTRAINT "DMT_PJF_TEAM_MEMBERS_STG_PK" PRIMARY KEY ("STG_SEQUENCE_ID")
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
  where  table_name = 'DMT_PJF_TEAM_MEMBERS_STG_TBL' and column_name = 'STATUS';
  if l_n = 1 then
    execute immediate 'ALTER TABLE "DMT_PJF_TEAM_MEMBERS_STG_TBL" RENAME COLUMN "STATUS" TO "STG_STATUS"';
  end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_PJF_TEAM_MEMBERS_STG_TBL_N1" ON "DMT_PJF_TEAM_MEMBERS_STG_TBL" ("STG_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_PJF_TEAM_MEMBERS_STG_TBL"."STG_SEQUENCE_ID" IS 'PK - from DMT_PJF_TEAM_MEMBERS_STG_SEQ';
COMMENT ON COLUMN "DMT_PJF_TEAM_MEMBERS_STG_TBL"."PROJECT_NAME" IS 'Project name â€” links team member to parent project';
COMMENT ON COLUMN "DMT_PJF_TEAM_MEMBERS_STG_TBL"."TEAM_MEMBER_NUMBER" IS 'Employee/person number of the team member';
COMMENT ON COLUMN "DMT_PJF_TEAM_MEMBERS_STG_TBL"."ERROR_TEXT" IS 'Concatenated errors â€” appended at each step, never overwritten. Prefixed: [PRE_VALIDATION] [TRANSFORM_ERROR] [FUSION_ERROR].';
COMMENT ON TABLE "DMT_PJF_TEAM_MEMBERS_STG_TBL"  IS 'Project team members staging. Raw user data only. Run-specific data in DMT_PJF_TEAM_MEMBERS_TFM_TBL. FBDI interface: PJF_PROJECT_PARTIES_INT. CSV: PjfProjectPartiesInt.csv.';

-- ---------------------------------------------------------------------------
-- 2026-07-08 conformance tranche (design section 7: STG/TFM infra-column
-- dictionary + contract-index dictionary): converges a pre-existing database.
-- Fresh installs already get the final shape from the CREATE above.
-- ---------------------------------------------------------------------------
begin
  execute immediate 'CREATE INDEX "DMT_PJF_TEAM_MEMBERS_STG_N1" ON "DMT_PJF_TEAM_MEMBERS_STG_TBL" ("SCENARIO_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_PJF_TEAM_MEMBERS_STG_TBL"."STG_STATUS" IS 'Staging lifecycle: NEW > TRANSFORMED / FAILED. Forward-only, never reset; errors accumulate in ERROR_TEXT.';

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
   where table_name = 'DMT_PJF_TEAM_MEMBERS_STG_TBL' and column_name = 'STG_STATUS';
  if l_nullable = 'Y' then
    execute immediate 'UPDATE "DMT_PJF_TEAM_MEMBERS_STG_TBL" SET "STG_STATUS" = ''NEW'' WHERE "STG_STATUS" IS NULL';
    execute immediate 'ALTER TABLE "DMT_PJF_TEAM_MEMBERS_STG_TBL" MODIFY ("STG_STATUS" DEFAULT ''NEW'' NOT NULL)';
  end if;
end;
/
