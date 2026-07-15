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
        WORK_STATUS IN (''PENDING'',''READY'',''SPLITTING'',''PROCESSING'',''GENERATING'',
                        ''LOADING'',''AWAITING_LOAD'',''AWAITING_IMPORT'',''AWAITING_POSTRUN'',''RECONCILING'',
                        ''DONE'',''FAILED'',''SKIPPED'')) ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

-- ---------------------------------------------------------------------------
-- Status rename VALIDATING -> PROCESSING (DMT_DESIGN section 12, P2). The
-- claimed data-phase status covers pre-validate -> transform -> post-validate
-- -> generate -> submit, so PROCESSING is the accurate name. Guarded +
-- idempotent so it converges an existing DB (the inline constraint above
-- already carries PROCESSING for fresh installs): migrate any lingering rows,
-- then swap the CHECK constraint. Re-running is a no-op.
-- ---------------------------------------------------------------------------
begin
  execute immediate q'[UPDATE DMT_WORK_QUEUE_TBL SET WORK_STATUS = 'PROCESSING' WHERE WORK_STATUS = 'VALIDATING']';
  commit;
exception when others then
  if sqlcode not in (-942) then raise; end if;  -- -942: table not yet present on first fresh pass
end;
/

declare
  l_bad number;
begin
  -- Only swap the constraint if it still allows VALIDATING (i.e. an old DB).
  select count(*) into l_bad from user_constraints
   where constraint_name = 'DMT_WORK_QUEUE_STATUS_CK'
     and search_condition_vc like '%VALIDATING%';
  if l_bad > 0 then
    execute immediate 'ALTER TABLE DMT_WORK_QUEUE_TBL DROP CONSTRAINT DMT_WORK_QUEUE_STATUS_CK';
    execute immediate 'ALTER TABLE DMT_WORK_QUEUE_TBL ADD CONSTRAINT DMT_WORK_QUEUE_STATUS_CK CHECK (
        WORK_STATUS IN (''PENDING'',''READY'',''SPLITTING'',''PROCESSING'',''GENERATING'',
                        ''LOADING'',''AWAITING_LOAD'',''AWAITING_IMPORT'',''AWAITING_POSTRUN'',''RECONCILING'',
                        ''DONE'',''FAILED'',''SKIPPED'')) ENABLE';
  end if;
exception when others then
  if sqlcode not in (-942) then raise; end if;
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

-- ---------------------------------------------------------------------------
-- 2026-07-09 conformance review F2 (contract-index dictionary, design
-- section 7 accepted 2026-07-08: DMT_WORK_QUEUE_TBL must index RUN_ID,
-- WORK_STATUS, NEXT_POLL_AFTER). RUN_ID and WORK_STATUS are covered above;
-- NEXT_POLL_AFTER (the poller's ready-to-poll scan) was missing. Named per
-- the accepted constraint/index naming pattern ({table-minus-_TBL}_N{n});
-- the legacy _IX-suffixed names above are left to the tracked naming sweep.
-- ---------------------------------------------------------------------------
begin
  execute immediate 'CREATE INDEX "DMT_WORK_QUEUE_N1" ON "DMT_WORK_QUEUE_TBL" ("NEXT_POLL_AFTER")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
