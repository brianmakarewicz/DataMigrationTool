-- DMT_ESS_JOB_FILE_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_ESS_JOB_FILE_TBL" 
   (	"ESS_FILE_ID" NUMBER DEFAULT DMT_OWNER.DMT_ESS_FILE_SEQ.NEXTVAL NOT NULL ENABLE, 
	"ESS_JOB_ID" NUMBER NOT NULL ENABLE, 
	"REQUEST_ID" NUMBER NOT NULL ENABLE, 
	"FILE_TYPE" VARCHAR2(30), 
	"FILE_NAME" VARCHAR2(500), 
	"CONTENT_TYPE" VARCHAR2(100), 
	"CREATED_DATE" DATE DEFAULT SYSDATE, 
	 CONSTRAINT "DMT_ESS_JOB_FILE_PK" PRIMARY KEY ("ESS_FILE_ID")
  USING INDEX  ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_ESS_FILE_JOB_IX" ON "DMT_ESS_JOB_FILE_TBL" ("ESS_JOB_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_ESS_FILE_REQ_IX" ON "DMT_ESS_JOB_FILE_TBL" ("REQUEST_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

begin
  execute immediate 'CREATE UNIQUE INDEX "DMT_ESS_FILE_UQ" ON "DMT_ESS_JOB_FILE_TBL" ("ESS_JOB_ID", "FILE_NAME")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_ESS_JOB_FILE_TBL"."FILE_TYPE" IS 'LOG or OUT â€” passed to downloadESSJobExecutionDetails';
COMMENT ON TABLE "DMT_ESS_JOB_FILE_TBL"  IS 'ESS job output file metadata â€” files downloaded on-demand via DOWNLOAD_ESS_FILE';
