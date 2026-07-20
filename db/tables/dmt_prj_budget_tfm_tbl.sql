-- DMT_PRJ_BUDGET_TFM_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_PRJ_BUDGET_TFM_TBL" 
   (	"TFM_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_PRJ_BUDGET_TFM_SEQ.NEXTVAL NOT NULL ENABLE, 
	"STG_SEQUENCE_ID" NUMBER NOT NULL ENABLE, 
	"FBDI_CSV_ID" NUMBER, 
	"AWARD_NUMBER" VARCHAR2(240), 
	"FINANCIAL_PLAN_TYPE" VARCHAR2(150), 
	"PROJECT_NUMBER" VARCHAR2(25), 
	"PROJECT_NAME" VARCHAR2(240), 
	"TASK_NAME" VARCHAR2(255), 
	"TASK_NUMBER" VARCHAR2(100), 
	"PLAN_VERSION_NAME" VARCHAR2(240), 
	"PLAN_VERSION_DESCRIPTION" VARCHAR2(2000), 
	"PLAN_VERSION_STATUS" VARCHAR2(30), 
	"RESOURCE_NAME" VARCHAR2(240), 
	"PERIOD_NAME" VARCHAR2(50), 
	"PLANNING_CURRENCY" VARCHAR2(15), 
	"TOTAL_QUANTITY" NUMBER, 
	"TOTAL_TC_RAW_COST" NUMBER, 
	"TOTAL_TC_REVENUE" NUMBER, 
	"SRC_BUDGET_LINE_REFERENCE" VARCHAR2(240), 
	"FUNDING_SOURCE_NUMBER" VARCHAR2(240), 
	"FUNDING_SOURCE_NAME" VARCHAR2(240), 
	"PC_RAW_COST" NUMBER, 
	"PC_REVENUE" NUMBER, 
	"PFC_RAW_COST" NUMBER, 
	"PFC_REVENUE" NUMBER, 
	"TOTAL_TC_BRDND_COST" NUMBER, 
	"PC_BRDND_COST" NUMBER, 
	"PFC_BRDND_COST" NUMBER, 
	"LINE_TYPE" VARCHAR2(30), 
	"PLANNING_START_DATE" DATE, 
	"PLANNING_END_DATE" DATE, 
	"ATTRIBUTE_CATEGORY" VARCHAR2(150), 
	"ATTRIBUTE1" VARCHAR2(240), 
	"ATTRIBUTE2" VARCHAR2(240), 
	"ATTRIBUTE3" VARCHAR2(240), 
	"ATTRIBUTE4" VARCHAR2(240), 
	"ATTRIBUTE5" VARCHAR2(240), 
	"ATTRIBUTE6" VARCHAR2(240), 
	"ATTRIBUTE7" VARCHAR2(240), 
	"ATTRIBUTE8" VARCHAR2(240), 
	"ATTRIBUTE9" VARCHAR2(240), 
	"ATTRIBUTE10" VARCHAR2(240), 
	"ATTRIBUTE11" VARCHAR2(240), 
	"ATTRIBUTE12" VARCHAR2(240), 
	"ATTRIBUTE13" VARCHAR2(240), 
	"ATTRIBUTE14" VARCHAR2(240), 
	"ATTRIBUTE15" VARCHAR2(240), 
	"ATTRIBUTE16" VARCHAR2(240), 
	"ATTRIBUTE17" VARCHAR2(240), 
	"ATTRIBUTE18" VARCHAR2(240), 
	"ATTRIBUTE19" VARCHAR2(240), 
	"ATTRIBUTE20" VARCHAR2(240), 
	"ATTRIBUTE21" VARCHAR2(240), 
	"ATTRIBUTE22" VARCHAR2(240), 
	"ATTRIBUTE23" VARCHAR2(240), 
	"ATTRIBUTE24" VARCHAR2(240), 
	"ATTRIBUTE25" VARCHAR2(240), 
	"ATTRIBUTE26" VARCHAR2(240), 
	"ATTRIBUTE27" VARCHAR2(240), 
	"ATTRIBUTE28" VARCHAR2(240), 
	"ATTRIBUTE29" VARCHAR2(240), 
	"ATTRIBUTE30" VARCHAR2(240), 
	"PLAN_VERSION_NUMBER" NUMBER, 
	"PROCESSING_MODE" VARCHAR2(30), 
	"TFM_STATUS" VARCHAR2(30) DEFAULT ''STAGED'' NOT NULL ENABLE, 
	"ERROR_TEXT" CLOB, 
	"RESULTS_UPDATED_DATE" DATE, 
	"LAST_UPDATED_DATE" DATE, 
	"RUN_ID" NUMBER, 
	"RECON_KEY" VARCHAR2(1000), 
	"FUSION_BUDGET_VERSION_ID" NUMBER, 
	"WORK_QUEUE_ID" NUMBER, 
	 CONSTRAINT "DMT_PRJ_BUDGET_TFM_PK" PRIMARY KEY ("TFM_SEQUENCE_ID")
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
  where  table_name = 'DMT_PRJ_BUDGET_TFM_TBL' and column_name = 'STATUS';
  if l_n = 1 then
    execute immediate 'ALTER TABLE "DMT_PRJ_BUDGET_TFM_TBL" RENAME COLUMN "STATUS" TO "TFM_STATUS"';
  end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_PRJ_BUDGET_TFM_TBL_N1" ON "DMT_PRJ_BUDGET_TFM_TBL" ("STG_SEQUENCE_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_PRJ_BUDGET_TFM_TBL_N4" ON "DMT_PRJ_BUDGET_TFM_TBL" ("FBDI_CSV_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

-- ---------------------------------------------------------------------------
-- 2026-07-08 conformance tranche (design section 7: STG/TFM infra-column
-- dictionary + contract-index dictionary): converges a pre-existing database.
-- Fresh installs already get the final shape from the CREATE above.
-- ---------------------------------------------------------------------------
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_PRJ_BUDGET_TFM_TBL' and column_name = 'RECON_KEY';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_PRJ_BUDGET_TFM_TBL" ADD ("RECON_KEY" VARCHAR2(1000))';
  end if;
end;
/
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_PRJ_BUDGET_TFM_TBL' and column_name = 'FUSION_BUDGET_VERSION_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_PRJ_BUDGET_TFM_TBL" ADD ("FUSION_BUDGET_VERSION_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_PRJ_BUDGET_TFM_N1" ON "DMT_PRJ_BUDGET_TFM_TBL" ("RUN_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_PRJ_BUDGET_TFM_N2" ON "DMT_PRJ_BUDGET_TFM_TBL" ("RUN_ID", "TFM_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_PRJ_BUDGET_TFM_N3" ON "DMT_PRJ_BUDGET_TFM_TBL" ("RECON_KEY")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_PRJ_BUDGET_TFM_TBL"."TFM_STATUS" IS 'Transform lifecycle: STAGED > GENERATED > LOADED / FAILED.';
COMMENT ON COLUMN "DMT_PRJ_BUDGET_TFM_TBL"."RECON_KEY" IS 'Pre-concatenated business key (run prefix included) that BIP reconciliation matches against Fusion rows.';
COMMENT ON COLUMN "DMT_PRJ_BUDGET_TFM_TBL"."FUSION_BUDGET_VERSION_ID" IS 'Fusion-assigned identifier captured from the Fusion base tables - written only by BIP reconciliation (positive proof of load).';

-- ---------------------------------------------------------------------------
-- 2026-07-09 conformance review F2 (STG/TFM infra-column dictionary, design
-- section 7 accepted 2026-07-08): TFM_STATUS is VARCHAR2(30) DEFAULT 'STAGED'
-- NOT NULL. Backfills any NULL statuses to the default, then converges a
-- pre-existing database; fresh installs get the shape from the CREATE above.
-- ---------------------------------------------------------------------------
declare
  l_nullable varchar2(1);
begin
  select nullable into l_nullable from user_tab_columns
   where table_name = 'DMT_PRJ_BUDGET_TFM_TBL' and column_name = 'TFM_STATUS';
  if l_nullable = 'Y' then
    execute immediate 'UPDATE "DMT_PRJ_BUDGET_TFM_TBL" SET "TFM_STATUS" = ''STAGED'' WHERE "TFM_STATUS" IS NULL';
    execute immediate 'ALTER TABLE "DMT_PRJ_BUDGET_TFM_TBL" MODIFY ("TFM_STATUS" DEFAULT ''STAGED'' NOT NULL)';
  end if;
end;
/

-- WORK_QUEUE_ID (work-queue-ID granularity foundation, accepted 2026-07-20;
-- docs/FIX_PLAN.md item 1). Guarded in-file ALTER so an existing DB converges
-- via db/install.sql (the CREATE above carries it for fresh installs). FK is
-- in db/tables/_foreign_keys.sql. NULLABLE for now; NOT NULL deferred.
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where table_name = 'DMT_PRJ_BUDGET_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_PRJ_BUDGET_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
COMMENT ON COLUMN "DMT_PRJ_BUDGET_TFM_TBL"."WORK_QUEUE_ID" IS 'The work queue item (DMT_WORK_QUEUE_TBL.QUEUE_ID) that processed this record. FK in _foreign_keys.sql. Stamped at generation; unit of per-work-item processing (design section 7, accepted 2026-07-20).';
