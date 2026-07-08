-- DMT_WORK_QUEUE_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_WORK_QUEUE_TBL" 
   (	"QUEUE_ID" NUMBER DEFAULT "DMT_OWNER"."DMT_WORK_QUEUE_SEQ"."NEXTVAL" NOT NULL ENABLE, 
	"RUN_ID" NUMBER NOT NULL ENABLE, 
	"PIPELINE" VARCHAR2(30), 
	"CEMLI_CODE" VARCHAR2(60) NOT NULL ENABLE, 
	"PARTITION_KEY" VARCHAR2(500), 
	"PARTITION_LABEL" VARCHAR2(200), 
	"FBDI_ZIP_ID" NUMBER, 
	"SORT_ORDER" NUMBER NOT NULL ENABLE, 
	"DEPENDS_ON" VARCHAR2(4000), 
	"WORK_STATUS" VARCHAR2(30) DEFAULT ''PENDING'' NOT NULL ENABLE, 
	"LOAD_ESS_JOB_ID" VARCHAR2(30), 
	"IMPORT_ESS_JOB_ID" VARCHAR2(30), 
	"POSTRUN_ESS_JOB_ID" VARCHAR2(30), 
	"POLL_COUNT" NUMBER DEFAULT 0, 
	"LAST_POLL_AT" TIMESTAMP (6), 
	"NEXT_POLL_AFTER" TIMESTAMP (6), 
	"ERROR_MESSAGE" VARCHAR2(4000), 
	"STARTED_AT" TIMESTAMP (6), 
	"COMPLETED_AT" TIMESTAMP (6), 
	 CONSTRAINT "DMT_WORK_QUEUE_PK" PRIMARY KEY ("QUEUE_ID")
  USING INDEX  ENABLE, 
	 CONSTRAINT "DMT_WORK_QUEUE_STATUS_CK" CHECK (
        WORK_STATUS IN (''PENDING'',''READY'',''SPLITTING'',''VALIDATING'',''GENERATING'',
                        ''LOADING'',''AWAITING_LOAD'',''AWAITING_IMPORT'',''AWAITING_POSTRUN'',''RECONCILING'',
                        ''DONE'',''FAILED'',''SKIPPED'')) ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_WQ_RUN_IX" ON "DMT_WORK_QUEUE_TBL" ("RUN_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_WQ_STATUS_IX" ON "DMT_WORK_QUEUE_TBL" ("WORK_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_WQ_ZIP_IX" ON "DMT_WORK_QUEUE_TBL" ("FBDI_ZIP_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
