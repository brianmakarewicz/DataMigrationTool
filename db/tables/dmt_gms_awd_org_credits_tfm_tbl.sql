-- DMT_GMS_AWD_ORG_CREDITS_TFM_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_GMS_AWD_ORG_CREDITS_TFM_TBL" 
   (	"TFM_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_GMS_AWD_ORGCR_TFM_SEQ.NEXTVAL NOT NULL ENABLE, 
	"STG_SEQUENCE_ID" NUMBER NOT NULL ENABLE, 
	"FBDI_CSV_ID" NUMBER, 
	"AWARD_NUMBER" VARCHAR2(300), 
	"PROJECT_NUMBER" VARCHAR2(25), 
	"ORGANIZATION" VARCHAR2(240), 
	"CREDIT_PERCENTAGE" NUMBER, 
	"STATUS" VARCHAR2(30) DEFAULT ''STAGED'' NOT NULL ENABLE, 
	"ERROR_TEXT" CLOB, 
	"LAST_UPDATED_DATE" DATE, 
	"RESULTS_UPDATED_DATE" DATE, 
	"RUN_ID" NUMBER, 
	 CONSTRAINT "DMT_GMS_AWD_ORGCR_TFM_PK" PRIMARY KEY ("TFM_SEQUENCE_ID")
  USING INDEX  ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_GMS_ORGCR_TFM_AWD_IX" ON "DMT_GMS_AWD_ORG_CREDITS_TFM_TBL" ("AWARD_NUMBER")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_GMS_ORGCR_TFM_STG_IX" ON "DMT_GMS_AWD_ORG_CREDITS_TFM_TBL" ("STG_SEQUENCE_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON TABLE "DMT_GMS_AWD_ORG_CREDITS_TFM_TBL"  IS 'Grant award organization credits transformed.';
