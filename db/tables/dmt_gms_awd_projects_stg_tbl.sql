-- DMT_GMS_AWD_PROJECTS_STG_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_GMS_AWD_PROJECTS_STG_TBL" 
   (	"STG_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_GMS_AWD_PROJ_STG_SEQ.NEXTVAL NOT NULL ENABLE, 
	"AWARD_NUMBER" VARCHAR2(300), 
	"FUNDING_SOURCE_NAME" VARCHAR2(360), 
	"PROJECT_NUMBER" VARCHAR2(25), 
	"AWARD_PRJ_BRD_SCHEDULE" VARCHAR2(240), 
	"FIXED_DATE" DATE, 
	"ATTRIBUTE_CATEGORY" VARCHAR2(30), 
	"ATTRIBUTE1" VARCHAR2(150), 
	"ATTRIBUTE2" VARCHAR2(150), 
	"ATTRIBUTE3" VARCHAR2(150), 
	"ATTRIBUTE4" VARCHAR2(150), 
	"ATTRIBUTE5" VARCHAR2(150), 
	"ATTRIBUTE6" VARCHAR2(150), 
	"ATTRIBUTE7" VARCHAR2(150), 
	"ATTRIBUTE8" VARCHAR2(150), 
	"ATTRIBUTE9" VARCHAR2(150), 
	"ATTRIBUTE10" VARCHAR2(150), 
	"ATTRIBUTE11" VARCHAR2(150), 
	"ATTRIBUTE12" VARCHAR2(150), 
	"ATTRIBUTE13" VARCHAR2(150), 
	"ATTRIBUTE14" VARCHAR2(150), 
	"ATTRIBUTE15" VARCHAR2(150), 
	"ATTRIBUTE16" VARCHAR2(150), 
	"ATTRIBUTE17" VARCHAR2(150), 
	"ATTRIBUTE18" VARCHAR2(150), 
	"ATTRIBUTE19" VARCHAR2(150), 
	"ATTRIBUTE20" VARCHAR2(150), 
	"ATTRIBUTE_NUMBER1" NUMBER, 
	"ATTRIBUTE_NUMBER2" NUMBER, 
	"ATTRIBUTE_NUMBER3" NUMBER, 
	"ATTRIBUTE_NUMBER4" NUMBER, 
	"ATTRIBUTE_NUMBER5" NUMBER, 
	"ATTRIBUTE_NUMBER6" NUMBER, 
	"ATTRIBUTE_NUMBER7" NUMBER, 
	"ATTRIBUTE_NUMBER8" NUMBER, 
	"ATTRIBUTE_NUMBER9" NUMBER, 
	"ATTRIBUTE_NUMBER10" NUMBER, 
	"ATTRIBUTE_DATE1" DATE, 
	"ATTRIBUTE_DATE2" DATE, 
	"ATTRIBUTE_DATE3" DATE, 
	"ATTRIBUTE_DATE4" DATE, 
	"ATTRIBUTE_DATE5" DATE, 
	"ATTRIBUTE_DATE6" DATE, 
	"ATTRIBUTE_DATE7" DATE, 
	"ATTRIBUTE_DATE8" DATE, 
	"ATTRIBUTE_DATE9" DATE, 
	"ATTRIBUTE_DATE10" DATE, 
	"ATTRIBUTE_TIMESTAMP1" DATE, 
	"ATTRIBUTE_TIMESTAMP2" DATE, 
	"ATTRIBUTE_TIMESTAMP3" DATE, 
	"ATTRIBUTE_TIMESTAMP4" DATE, 
	"ATTRIBUTE_TIMESTAMP5" DATE, 
	"ATTRIBUTE_TIMESTAMP6" DATE, 
	"ATTRIBUTE_TIMESTAMP7" DATE, 
	"ATTRIBUTE_TIMESTAMP8" DATE, 
	"ATTRIBUTE_TIMESTAMP9" DATE, 
	"ATTRIBUTE_TIMESTAMP10" DATE, 
	"STAGE_DATE" DATE DEFAULT SYSDATE, 
	"STG_STATUS" VARCHAR2(30) DEFAULT ''NEW'' NOT NULL ENABLE, 
	"ERROR_TEXT" CLOB, 
	"SOURCE_ID" VARCHAR2(240), 
	"LAST_UPDATED_DATE" DATE, 
	"SCENARIO_ID" NUMBER, 
	 CONSTRAINT "DMT_GMS_AWD_PROJ_STG_PK" PRIMARY KEY ("STG_SEQUENCE_ID")
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
  where  table_name = 'DMT_GMS_AWD_PROJECTS_STG_TBL' and column_name = 'STATUS';
  if l_n = 1 then
    execute immediate 'ALTER TABLE "DMT_GMS_AWD_PROJECTS_STG_TBL" RENAME COLUMN "STATUS" TO "STG_STATUS"';
  end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_GMS_AWD_PROJ_STG_AWD_IX" ON "DMT_GMS_AWD_PROJECTS_STG_TBL" ("AWARD_NUMBER")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_GMS_AWD_PROJ_STG_STS_IX" ON "DMT_GMS_AWD_PROJECTS_STG_TBL" ("STG_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON TABLE "DMT_GMS_AWD_PROJECTS_STG_TBL"  IS 'Grant award-project link staging. FBDI interface: GMS_AWARD_PROJECTS_INT. CSV: GmsAwardProjectsInterface.csv.';

-- ---------------------------------------------------------------------------
-- 2026-07-08 conformance tranche (design section 7: STG/TFM infra-column
-- dictionary + contract-index dictionary): converges a pre-existing database.
-- Fresh installs already get the final shape from the CREATE above.
-- ---------------------------------------------------------------------------
begin
  execute immediate 'CREATE INDEX "DMT_GMS_AWD_PROJECTS_STG_N1" ON "DMT_GMS_AWD_PROJECTS_STG_TBL" ("SCENARIO_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_GMS_AWD_PROJECTS_STG_TBL"."STG_STATUS" IS 'Staging lifecycle: NEW > TRANSFORMED / FAILED. Forward-only, never reset; errors accumulate in ERROR_TEXT.';

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
   where table_name = 'DMT_GMS_AWD_PROJECTS_STG_TBL' and column_name = 'STG_STATUS';
  if l_nullable = 'Y' then
    execute immediate 'UPDATE "DMT_GMS_AWD_PROJECTS_STG_TBL" SET "STG_STATUS" = ''NEW'' WHERE "STG_STATUS" IS NULL';
    execute immediate 'ALTER TABLE "DMT_GMS_AWD_PROJECTS_STG_TBL" MODIFY ("STG_STATUS" DEFAULT ''NEW'' NOT NULL)';
  end if;
end;
/
