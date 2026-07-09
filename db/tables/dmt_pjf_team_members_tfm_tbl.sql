-- DMT_PJF_TEAM_MEMBERS_TFM_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_PJF_TEAM_MEMBERS_TFM_TBL" 
   (	"TFM_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_PJF_TEAM_MEMBERS_TFM_SEQ.NEXTVAL NOT NULL ENABLE, 
	"STG_SEQUENCE_ID" NUMBER NOT NULL ENABLE, 
	"FBDI_CSV_ID" NUMBER, 
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
	"RESULTS_UPDATED_DATE" DATE, 
	"TFM_STATUS" VARCHAR2(30) DEFAULT ''STAGED'' NOT NULL ENABLE, 
	"ERROR_TEXT" CLOB, 
	"LAST_UPDATED_DATE" DATE, 
	"RUN_ID" NUMBER, 
	"RECON_KEY" VARCHAR2(1000), 
	"FUSION_PROJECT_PARTY_ID" NUMBER, 
	 CONSTRAINT "DMT_PJF_TEAM_MEMBERS_TFM_PK" PRIMARY KEY ("TFM_SEQUENCE_ID")
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
  where  table_name = 'DMT_PJF_TEAM_MEMBERS_TFM_TBL' and column_name = 'STATUS';
  if l_n = 1 then
    execute immediate 'ALTER TABLE "DMT_PJF_TEAM_MEMBERS_TFM_TBL" RENAME COLUMN "STATUS" TO "TFM_STATUS"';
  end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_PJF_TEAM_MEMBERS_TFM_TBL_N1" ON "DMT_PJF_TEAM_MEMBERS_TFM_TBL" ("STG_SEQUENCE_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_PJF_TEAM_MEMBERS_TFM_TBL_N4" ON "DMT_PJF_TEAM_MEMBERS_TFM_TBL" ("FBDI_CSV_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_PJF_TEAM_MEMBERS_TFM_TBL"."TFM_SEQUENCE_ID" IS 'PK - from DMT_PJF_TEAM_MEMBERS_TFM_SEQ';
COMMENT ON COLUMN "DMT_PJF_TEAM_MEMBERS_TFM_TBL"."STG_SEQUENCE_ID" IS 'FK to DMT_PJF_TEAM_MEMBERS_STG_TBL â€” which staging row this was transformed from';
COMMENT ON COLUMN "DMT_PJF_TEAM_MEMBERS_TFM_TBL"."FBDI_CSV_ID" IS 'FK to DMT_FBDI_CSV_TBL â€” populated when FBDI generator runs';
COMMENT ON COLUMN "DMT_PJF_TEAM_MEMBERS_TFM_TBL"."PROJECT_NAME" IS 'Project name â€” links team member to parent project';
COMMENT ON COLUMN "DMT_PJF_TEAM_MEMBERS_TFM_TBL"."ERROR_TEXT" IS 'Concatenated errors. Appended at each step â€” never overwritten. Prefixes: [TRANSFORM_ERROR] [POST_VALIDATION] [FUSION_ERROR]';
COMMENT ON TABLE "DMT_PJF_TEAM_MEMBERS_TFM_TBL"  IS 'Project team members transformed. Run-specific â€” one row per staging row per run attempt. Reconciliation populated by BIP.';

-- ---------------------------------------------------------------------------
-- 2026-07-08 conformance tranche (design section 7: STG/TFM infra-column
-- dictionary + contract-index dictionary): converges a pre-existing database.
-- Fresh installs already get the final shape from the CREATE above.
-- ---------------------------------------------------------------------------
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_PJF_TEAM_MEMBERS_TFM_TBL' and column_name = 'RECON_KEY';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_PJF_TEAM_MEMBERS_TFM_TBL" ADD ("RECON_KEY" VARCHAR2(1000))';
  end if;
end;
/
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_PJF_TEAM_MEMBERS_TFM_TBL' and column_name = 'FUSION_PROJECT_PARTY_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_PJF_TEAM_MEMBERS_TFM_TBL" ADD ("FUSION_PROJECT_PARTY_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_PJF_TEAM_MEMBERS_TFM_N1" ON "DMT_PJF_TEAM_MEMBERS_TFM_TBL" ("RUN_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_PJF_TEAM_MEMBERS_TFM_N2" ON "DMT_PJF_TEAM_MEMBERS_TFM_TBL" ("RUN_ID", "TFM_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_PJF_TEAM_MEMBERS_TFM_N3" ON "DMT_PJF_TEAM_MEMBERS_TFM_TBL" ("RECON_KEY")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_PJF_TEAM_MEMBERS_TFM_TBL"."TFM_STATUS" IS 'Transform lifecycle: STAGED > GENERATED > LOADED / FAILED.';
COMMENT ON COLUMN "DMT_PJF_TEAM_MEMBERS_TFM_TBL"."RECON_KEY" IS 'Pre-concatenated business key (run prefix included) that BIP reconciliation matches against Fusion rows.';
COMMENT ON COLUMN "DMT_PJF_TEAM_MEMBERS_TFM_TBL"."FUSION_PROJECT_PARTY_ID" IS 'Fusion-assigned identifier captured from the Fusion base tables - written only by BIP reconciliation (positive proof of load).';
