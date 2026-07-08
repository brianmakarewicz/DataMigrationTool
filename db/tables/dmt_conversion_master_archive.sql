-- DMT_CONVERSION_MASTER_ARCHIVE (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_CONVERSION_MASTER_ARCHIVE" 
   (	"INTEGRATION_ID" NUMBER NOT NULL ENABLE, 
	"INSTANCE_ID" VARCHAR2(200), 
	"ORCHESTRATION_CODE" VARCHAR2(100) NOT NULL ENABLE, 
	"SOURCE_FILENAME" VARCHAR2(500), 
	"STATUS" VARCHAR2(30) DEFAULT ''OPEN'' NOT NULL ENABLE, 
	"START_DATE" DATE DEFAULT SYSDATE NOT NULL ENABLE, 
	"END_DATE" DATE, 
	"ESS_JOB_ID" VARCHAR2(100), 
	"FBDI_FILENAME" VARCHAR2(500), 
	"RESULT" CLOB, 
	"TOTAL_RECORDS" NUMBER DEFAULT 0, 
	"VALID_RECORDS" NUMBER DEFAULT 0, 
	"INVALID_RECORDS" NUMBER DEFAULT 0, 
	"SUCCESSFUL_RECORDS" NUMBER DEFAULT 0, 
	"ERRORED_RECORDS" NUMBER DEFAULT 0, 
	"PREFIX" VARCHAR2(10), 
	"DEPENDENT_PREFIX" VARCHAR2(10), 
	"FOLDER" VARCHAR2(100), 
	"LAST_UPDATED_DATE" DATE, 
	"SCENARIO_ID" NUMBER, 
	 CONSTRAINT "DMT_CONV_MASTER_TBL_PK" PRIMARY KEY ("INTEGRATION_ID")
  USING INDEX  ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_CONVERSION_MASTER_TBL_N1" ON "DMT_CONVERSION_MASTER_ARCHIVE" ("ORCHESTRATION_CODE")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_CONVERSION_MASTER_TBL_N2" ON "DMT_CONVERSION_MASTER_ARCHIVE" ("STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_CONVERSION_MASTER_TBL_N3" ON "DMT_CONVERSION_MASTER_ARCHIVE" ("ORCHESTRATION_CODE", "STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_CONV_MASTER_SCENARIO_IX" ON "DMT_CONVERSION_MASTER_ARCHIVE" ("SCENARIO_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_CONVERSION_MASTER_ARCHIVE"."INTEGRATION_ID" IS 'PK - from DMT_INTEGRATION_ID_SEQ';
COMMENT ON COLUMN "DMT_CONVERSION_MASTER_ARCHIVE"."INSTANCE_ID" IS 'OIC instance ID of the main orchestration flow';
COMMENT ON COLUMN "DMT_CONVERSION_MASTER_ARCHIVE"."ORCHESTRATION_CODE" IS 'CEMLI code identifying the conversion e.g. C001-Suppliers';
COMMENT ON COLUMN "DMT_CONVERSION_MASTER_ARCHIVE"."SOURCE_FILENAME" IS 'Archived zip filename on SFTP - trace back to original inbound file';
COMMENT ON COLUMN "DMT_CONVERSION_MASTER_ARCHIVE"."STATUS" IS 'OPEN > STAGED > VALIDATED > FBDI_GENERATED > LOADED / FAILED';
COMMENT ON COLUMN "DMT_CONVERSION_MASTER_ARCHIVE"."START_DATE" IS 'Start date and time of orchestration - time is required, not just date';
COMMENT ON COLUMN "DMT_CONVERSION_MASTER_ARCHIVE"."END_DATE" IS 'End date and time set by callback orchestration - time is required';
COMMENT ON COLUMN "DMT_CONVERSION_MASTER_ARCHIVE"."ESS_JOB_ID" IS 'Fusion ESS job ID returned after UCM upload and import submission';
COMMENT ON COLUMN "DMT_CONVERSION_MASTER_ARCHIVE"."FBDI_FILENAME" IS 'Name of the FBDI zip submitted to Fusion UCM';
COMMENT ON COLUMN "DMT_CONVERSION_MASTER_ARCHIVE"."RESULT" IS 'Full XML/text of OIC callback response including job IDs and child process results';
COMMENT ON COLUMN "DMT_CONVERSION_MASTER_ARCHIVE"."TOTAL_RECORDS" IS 'Total rows across all staging tables for this run';
COMMENT ON COLUMN "DMT_CONVERSION_MASTER_ARCHIVE"."VALID_RECORDS" IS 'Rows that passed validation and were included in FBDI';
COMMENT ON COLUMN "DMT_CONVERSION_MASTER_ARCHIVE"."INVALID_RECORDS" IS 'Rows that failed validation and were excluded from FBDI';
COMMENT ON COLUMN "DMT_CONVERSION_MASTER_ARCHIVE"."SUCCESSFUL_RECORDS" IS 'Rows confirmed loaded successfully by BIP reconciliation';
COMMENT ON COLUMN "DMT_CONVERSION_MASTER_ARCHIVE"."ERRORED_RECORDS" IS 'Rows that failed in Fusion including downstream records blocked by upstream failures';
COMMENT ON COLUMN "DMT_CONVERSION_MASTER_ARCHIVE"."PREFIX" IS '4-digit incremental prefix applied to unique identifiers e.g. 1035 turns Acme into 1035Acme';
COMMENT ON COLUMN "DMT_CONVERSION_MASTER_ARCHIVE"."DEPENDENT_PREFIX" IS 'Prefix from upstream CEMLI used for validation lookups - not incremented by this run';
COMMENT ON COLUMN "DMT_CONVERSION_MASTER_ARCHIVE"."FOLDER" IS 'YYMMDD24HHMISS subfolder created on SFTP for this run (archive, FBDIOutput, results)';
COMMENT ON COLUMN "DMT_CONVERSION_MASTER_ARCHIVE"."SCENARIO_ID" IS 'FK to DMT_SCENARIO_TBL â€” identifies which scenario this run belongs to';
COMMENT ON TABLE "DMT_CONVERSION_MASTER_ARCHIVE"  IS 'One row per CEMLI zip file run. Updated by OIC at each pipeline stage. STATUS: OPEN > STAGED > VALIDATED > FBDI_GENERATED > LOADED / FAILED.';
