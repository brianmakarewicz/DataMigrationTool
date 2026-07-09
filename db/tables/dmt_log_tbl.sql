-- DMT_LOG_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_LOG_TBL" 
   (	"LOG_ID" NUMBER NOT NULL ENABLE, 
	"LOG_DATE" DATE DEFAULT SYSDATE NOT NULL ENABLE, 
	"LOG_TYPE" VARCHAR2(30) DEFAULT ''INFO'' NOT NULL ENABLE, 
	"PACKAGE_NAME" VARCHAR2(100), 
	"PROCEDURE_NAME" VARCHAR2(100), 
	"MESSAGE" CLOB, 
	"SQLERRM_TEXT" VARCHAR2(4000), 
	"RUN_ID" NUMBER,
	"QUEUE_ID" NUMBER,
	"INTEGRATION_ID" NUMBER GENERATED ALWAYS AS ("RUN_ID"+0) VIRTUAL ,
	 CONSTRAINT "DMT_LOG_TBL_PK" PRIMARY KEY ("LOG_ID")
  USING INDEX  ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_LOG_TBL_N2" ON "DMT_LOG_TBL" ("LOG_DATE")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_LOG_TBL_N3" ON "DMT_LOG_TBL" ("LOG_TYPE")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

-- ---------------------------------------------------------------------------
-- 2026-07-09 conformance review F2 (contract-index dictionary, design
-- section 7 accepted 2026-07-08: DMT_LOG_TBL must index RUN_ID and QUEUE_ID).
-- QUEUE_ID is the work-item attribution id decided in section 5 (nullable,
-- indexed, no FK by design - log rows may precede the run row). Guarded
-- blocks converge a pre-existing database; fresh installs get the column
-- from the CREATE above.
-- ---------------------------------------------------------------------------
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
   where table_name = 'DMT_LOG_TBL' and column_name = 'QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_LOG_TBL" ADD ("QUEUE_ID" NUMBER)';
  end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_LOG_N1" ON "DMT_LOG_TBL" ("RUN_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_LOG_N2" ON "DMT_LOG_TBL" ("QUEUE_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_LOG_TBL"."LOG_ID" IS 'PK - from DMT_LOG_ID_SEQ';
COMMENT ON COLUMN "DMT_LOG_TBL"."RUN_ID" IS 'Run attribution (section 5) - nullable: NULL means no run context exists. Indexed, no FK by design.';
COMMENT ON COLUMN "DMT_LOG_TBL"."QUEUE_ID" IS 'Work-item attribution (section 5) - the work item that wrote the entry. Nullable, indexed, no FK by design.';
COMMENT ON COLUMN "DMT_LOG_TBL"."LOG_TYPE" IS 'INFO = milestone, WARN = non-fatal issue, ERROR = exception with SQLERRM';
COMMENT ON COLUMN "DMT_LOG_TBL"."PACKAGE_NAME" IS 'Package where the log entry originated';
COMMENT ON COLUMN "DMT_LOG_TBL"."PROCEDURE_NAME" IS 'Procedure or function where the log entry originated';
COMMENT ON COLUMN "DMT_LOG_TBL"."MESSAGE" IS 'Log message - for ERROR entries this should describe the context before SQLERRM';
COMMENT ON COLUMN "DMT_LOG_TBL"."SQLERRM_TEXT" IS 'Oracle error text (SQLERRM) - populated for ERROR log type only';
COMMENT ON TABLE "DMT_LOG_TBL"  IS 'Execution log for all DMT packages. Written via autonomous transaction - survives rollbacks.';
