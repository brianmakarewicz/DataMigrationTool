-- DMT_PIPELINE_RUN_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_PIPELINE_RUN_TBL" 
   (	"RUN_ID" NUMBER DEFAULT DMT_OWNER.DMT_PIPELINE_RUN_SEQ.NEXTVAL NOT NULL ENABLE, 
	"INTEGRATION_ID" NUMBER, 
	"PIPELINE_CODES" VARCHAR2(500) NOT NULL ENABLE, 
	"RUN_TYPE" VARCHAR2(30) DEFAULT ''PIPELINE'' NOT NULL ENABLE, 
	"SCHEDULER_JOB_NAME" VARCHAR2(128), 
	"SUBMITTED_BY" VARCHAR2(100), 
	"SUBMITTED_DATE" TIMESTAMP (6) DEFAULT SYSTIMESTAMP NOT NULL ENABLE, 
	"STARTED_DATE" TIMESTAMP (6), 
	"COMPLETED_DATE" TIMESTAMP (6), 
	"RUN_STATUS" VARCHAR2(30) DEFAULT ''QUEUED'' NOT NULL ENABLE, 
	"CURRENT_CEMLI" VARCHAR2(60), 
	"CURRENT_STEP" VARCHAR2(30), 
	"CEMLI_SEQUENCE" VARCHAR2(4000) NOT NULL ENABLE, 
	"COMPLETED_CEMLIS" VARCHAR2(4000), 
	"FAILED_CEMLI" VARCHAR2(60), 
	"ERROR_MESSAGE" VARCHAR2(4000), 
	"SCENARIO_NAME" VARCHAR2(100),
	"RUN_MODE" VARCHAR2(20) DEFAULT ''NEW'',
	"PREFIX" VARCHAR2(20),
	"ON_FAILURE_POLICY" VARCHAR2(30) DEFAULT ''HALT'', 
	"SCENARIO_ID" NUMBER GENERATED ALWAYS AS ("RUN_ID"+0) VIRTUAL , 
	 CONSTRAINT "DMT_PIPELINE_RUN_TYPE_CK" CHECK (
        RUN_TYPE IN (''PIPELINE'', ''STANDALONE'')
    ) ENABLE, 
	 CONSTRAINT "DMT_PIPELINE_RUN_PK" PRIMARY KEY ("RUN_ID")
  USING INDEX  ENABLE, 
	 CONSTRAINT "DMT_PIPELINE_RUN_STATUS_CK" CHECK (RUN_STATUS IN (''QUEUED'',''IN_PROGRESS'',''COMPLETED'',''COMPLETED_ERRORS'',''FAILED'',''NO_ROWS_PROCESSED'')) ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

-- ============================================================
-- Guarded idempotent migration blocks (A8, 2026-07-08): converge a
-- pre-existing database to the definition above.
--
-- 1) CANCELLED removed from the run-status vocabulary. Design
--    section 2: CANCEL_RUN is REMOVED — "There is no cancellation
--    (decided 2026-07-07) — runs always execute to their terminal
--    state"; the Overview run-status table defines exactly QUEUED /
--    IN_PROGRESS / COMPLETED / COMPLETED_ERRORS / FAILED /
--    NO_ROWS_PROCESSED. Drop + re-add of the check constraint
--    (-2443 = constraint does not exist, -2264 = name already in
--    use — both mean already converged). Any historical CANCELLED
--    row would block the re-add loudly — by design: such rows must
--    be triaged, not silently grandfathered.
-- ============================================================
begin
  execute immediate 'ALTER TABLE "DMT_PIPELINE_RUN_TBL" DROP CONSTRAINT "DMT_PIPELINE_RUN_STATUS_CK"';
exception when others then
  if sqlcode not in (-2443) then raise; end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_PIPELINE_RUN_TBL" ADD CONSTRAINT "DMT_PIPELINE_RUN_STATUS_CK" CHECK (RUN_STATUS IN (''QUEUED'',''IN_PROGRESS'',''COMPLETED'',''COMPLETED_ERRORS'',''FAILED'',''NO_ROWS_PROCESSED''))';
exception when others then
  if sqlcode not in (-2264) then raise; end if;
end;
/

-- ============================================================
-- 2) INCLUDE_UNTAGGED column dropped (A8, 2026-07-08). Scenarios
--    are mandatory at ingestion (Overview glossary, "Scenario": "A
--    named dataset tag on every staging row (mandatory at
--    ingestion)"), so an include-untagged-rows switch has no
--    population to act on and is not part of the decided run
--    parameters (RUN_MODE / SCENARIO_NAME / PREFIX / ON_FAILURE).
--    (-904 = column does not exist — already converged.)
-- ============================================================
begin
  execute immediate 'ALTER TABLE "DMT_PIPELINE_RUN_TBL" DROP COLUMN "INCLUDE_UNTAGGED"';
exception when others then
  if sqlcode not in (-904) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_PIPELINE_RUN_STATUS_IX" ON "DMT_PIPELINE_RUN_TBL" ("RUN_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_PIPELINE_RUN_TBL"."RUN_STATUS" IS 'QUEUED -> IN_PROGRESS -> COMPLETED | COMPLETED_ERRORS | FAILED | NO_ROWS_PROCESSED (Overview run-status table; written only by the heartbeat rollup)';
COMMENT ON COLUMN "DMT_PIPELINE_RUN_TBL"."CURRENT_CEMLI" IS 'Which object type is currently executing (updated via autonomous txn)';
COMMENT ON COLUMN "DMT_PIPELINE_RUN_TBL"."CURRENT_STEP" IS 'VALIDATE | GENERATE | LOAD | POLL_LOAD | POLL_IMPORT | RECONCILE';
COMMENT ON COLUMN "DMT_PIPELINE_RUN_TBL"."CEMLI_SEQUENCE" IS 'Ordered CSV of all CEMLIs to run in this pipeline';
COMMENT ON COLUMN "DMT_PIPELINE_RUN_TBL"."COMPLETED_CEMLIS" IS 'CSV of CEMLIs that have finished successfully';
COMMENT ON TABLE "DMT_PIPELINE_RUN_TBL"  IS 'Async pipeline execution tracking. One row per DBMS_SCHEDULER submission.';
