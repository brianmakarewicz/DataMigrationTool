-- DMT_GMS_AWD_REFERENCES_STG_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_GMS_AWD_REFERENCES_STG_TBL" 
   (	"STG_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_GMS_AWD_REF_STG_SEQ.NEXTVAL NOT NULL ENABLE, 
	"AWARD_NUMBER" VARCHAR2(300), 
	"PROJECT_NUMBER" VARCHAR2(25), 
	"REFERENCE_TYPE" VARCHAR2(240), 
	"VALUE" VARCHAR2(240), 
	"COMMENTS" VARCHAR2(240), 
	"STAGE_DATE" DATE DEFAULT SYSDATE, 
	"STATUS" VARCHAR2(30) DEFAULT ''NEW'', 
	"ERROR_TEXT" CLOB, 
	"SOURCE_ID" VARCHAR2(240), 
	"LAST_UPDATED_DATE" DATE, 
	"SCENARIO_ID" NUMBER, 
	 CONSTRAINT "DMT_GMS_AWD_REF_STG_PK" PRIMARY KEY ("STG_SEQUENCE_ID")
  USING INDEX  ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_GMS_AWD_REF_STG_AWD_IX" ON "DMT_GMS_AWD_REFERENCES_STG_TBL" ("AWARD_NUMBER")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_GMS_AWD_REF_STG_STS_IX" ON "DMT_GMS_AWD_REFERENCES_STG_TBL" ("STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON TABLE "DMT_GMS_AWD_REFERENCES_STG_TBL"  IS 'Grant award references staging. CSV: GmsAwardReferencesInterface.csv.';
