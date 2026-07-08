-- DMT_ESS_JOB_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_ESS_JOB_TBL" 
   (	"ESS_JOB_ID" NUMBER DEFAULT DMT_OWNER.DMT_ESS_JOB_SEQ.NEXTVAL NOT NULL ENABLE, 
	"REQUEST_ID" NUMBER NOT NULL ENABLE, 
	"PARENT_REQUEST_ID" NUMBER, 
	"JOB_DEFINITION" VARCHAR2(500), 
	"JOB_SHORT_NAME" VARCHAR2(200), 
	"STATE" NUMBER, 
	"STATE_TEXT" VARCHAR2(30), 
	"SUBMITTER" VARCHAR2(100), 
	"SUBMIT_TIME" DATE, 
	"START_TIME" DATE, 
	"END_TIME" DATE, 
	"CEMLI_CODE" VARCHAR2(60), 
	"DEPTH_LEVEL" NUMBER DEFAULT 0, 
	"CREATED_DATE" DATE DEFAULT SYSDATE, 
	"RUN_ID" NUMBER, 
	"INTEGRATION_ID" NUMBER GENERATED ALWAYS AS ("RUN_ID"+0) VIRTUAL , 
	 CONSTRAINT "DMT_ESS_JOB_PK" PRIMARY KEY ("ESS_JOB_ID")
  USING INDEX  ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_ESS_JOB_REQ_IX" ON "DMT_ESS_JOB_TBL" ("REQUEST_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_ESS_JOB_RUN_IX" ON "DMT_ESS_JOB_TBL" ("RUN_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_ESS_JOB_TBL"."STATE" IS 'Fusion ESS state code: 1=Wait, 2=Ready, 3=Running, 4=Completed, 5=Blocked, 6=Hold, 7=Cancelling, 8=Cancelled, 9=Paused, 10=Error, 11=Warning, 12=Succeeded, 13=Expired';
COMMENT ON COLUMN "DMT_ESS_JOB_TBL"."STATE_TEXT" IS 'Human-readable state: SUCCEEDED, WARNING, ERROR, etc.';
COMMENT ON COLUMN "DMT_ESS_JOB_TBL"."DEPTH_LEVEL" IS '0=root (returned by loadAndImportData), 1=child, 2=grandchild, etc.';
COMMENT ON TABLE "DMT_ESS_JOB_TBL"  IS 'ESS job hierarchy â€” parent + all descendants captured after polling';
