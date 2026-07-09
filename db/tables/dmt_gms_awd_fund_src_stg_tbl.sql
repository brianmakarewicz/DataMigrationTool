-- DMT_GMS_AWD_FUND_SRC_STG_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_GMS_AWD_FUND_SRC_STG_TBL" 
   (	"STG_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_GMS_AWD_FSRC_STG_SEQ.NEXTVAL NOT NULL ENABLE, 
	"AWARD_NUMBER" VARCHAR2(300), 
	"FUNDING_SOURCE_NAME" VARCHAR2(360), 
	"FUNDING_SOURCE_NUMBER" VARCHAR2(240), 
	"COST_SHARE_REQ_BY_SPONSOR" VARCHAR2(1), 
	"COST_SHARE_APPROVED_BY_EMAIL" VARCHAR2(240), 
	"COST_SHARE_APPROVED_BY_NAME" VARCHAR2(240), 
	"COST_SHARE_APPROVED_BY_NUMBER" VARCHAR2(30), 
	"COST_SHARE_APPROVAL_DATE" DATE, 
	"STAGE_DATE" DATE DEFAULT SYSDATE, 
	"STG_STATUS" VARCHAR2(30) DEFAULT ''NEW'', 
	"ERROR_TEXT" CLOB, 
	"SOURCE_ID" VARCHAR2(240), 
	"LAST_UPDATED_DATE" DATE, 
	"SCENARIO_ID" NUMBER, 
	 CONSTRAINT "DMT_GMS_AWD_FSRC_STG_PK" PRIMARY KEY ("STG_SEQUENCE_ID")
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
  where  table_name = 'DMT_GMS_AWD_FUND_SRC_STG_TBL' and column_name = 'STATUS';
  if l_n = 1 then
    execute immediate 'ALTER TABLE "DMT_GMS_AWD_FUND_SRC_STG_TBL" RENAME COLUMN "STATUS" TO "STG_STATUS"';
  end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_GMS_AWD_FSRC_STG_AWD_IX" ON "DMT_GMS_AWD_FUND_SRC_STG_TBL" ("AWARD_NUMBER")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_GMS_AWD_FSRC_STG_STS_IX" ON "DMT_GMS_AWD_FUND_SRC_STG_TBL" ("STG_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON TABLE "DMT_GMS_AWD_FUND_SRC_STG_TBL"  IS 'Grant award funding sources staging. FBDI interface: GMS_AWD_FND_SRC_INT. CSV: GmsAwardFundSrcInterface.csv.';

-- ---------------------------------------------------------------------------
-- 2026-07-08 conformance tranche (design section 7: STG/TFM infra-column
-- dictionary + contract-index dictionary): converges a pre-existing database.
-- Fresh installs already get the final shape from the CREATE above.
-- ---------------------------------------------------------------------------
begin
  execute immediate 'CREATE INDEX "DMT_GMS_AWD_FUND_SRC_STG_N1" ON "DMT_GMS_AWD_FUND_SRC_STG_TBL" ("SCENARIO_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_GMS_AWD_FUND_SRC_STG_TBL"."STG_STATUS" IS 'Staging lifecycle: NEW > TRANSFORMED / FAILED. Forward-only, never reset; errors accumulate in ERROR_TEXT.';
