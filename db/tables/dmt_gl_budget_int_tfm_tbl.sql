-- DMT_GL_BUDGET_INT_TFM_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_GL_BUDGET_INT_TFM_TBL" 
   (	"TFM_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_GL_BUDGET_INT_TFM_SEQ.NEXTVAL NOT NULL ENABLE, 
	"STG_SEQUENCE_ID" NUMBER NOT NULL ENABLE, 
	"FBDI_CSV_ID" NUMBER, 
	"RUN_NAME" VARCHAR2(240), 
	"STATUS_FBDI" VARCHAR2(30), 
	"LEDGER_ID" NUMBER, 
	"BUDGET_NAME" VARCHAR2(100), 
	"PERIOD_NAME" VARCHAR2(15), 
	"CURRENCY_CODE" VARCHAR2(15), 
	"SEGMENT1" VARCHAR2(25), 
	"SEGMENT2" VARCHAR2(25), 
	"SEGMENT3" VARCHAR2(25), 
	"SEGMENT4" VARCHAR2(25), 
	"SEGMENT5" VARCHAR2(25), 
	"SEGMENT6" VARCHAR2(25), 
	"SEGMENT7" VARCHAR2(25), 
	"SEGMENT8" VARCHAR2(25), 
	"SEGMENT9" VARCHAR2(25), 
	"SEGMENT10" VARCHAR2(25), 
	"SEGMENT11" VARCHAR2(25), 
	"SEGMENT12" VARCHAR2(25), 
	"SEGMENT13" VARCHAR2(25), 
	"SEGMENT14" VARCHAR2(25), 
	"SEGMENT15" VARCHAR2(25), 
	"SEGMENT16" VARCHAR2(25), 
	"SEGMENT17" VARCHAR2(25), 
	"SEGMENT18" VARCHAR2(25), 
	"SEGMENT19" VARCHAR2(25), 
	"SEGMENT20" VARCHAR2(25), 
	"SEGMENT21" VARCHAR2(25), 
	"SEGMENT22" VARCHAR2(25), 
	"SEGMENT23" VARCHAR2(25), 
	"SEGMENT24" VARCHAR2(25), 
	"SEGMENT25" VARCHAR2(25), 
	"SEGMENT26" VARCHAR2(25), 
	"SEGMENT27" VARCHAR2(25), 
	"SEGMENT28" VARCHAR2(25), 
	"SEGMENT29" VARCHAR2(25), 
	"SEGMENT30" VARCHAR2(25), 
	"BUDGET_AMOUNT" NUMBER, 
	"LEDGER_NAME" VARCHAR2(240), 
	"TFM_STATUS" VARCHAR2(30) DEFAULT ''STAGED'' NOT NULL ENABLE, 
	"ERROR_TEXT" CLOB, 
	"RESULTS_UPDATED_DATE" DATE, 
	"LAST_UPDATED_DATE" DATE, 
	"RUN_ID" NUMBER, 
	"RECON_KEY" VARCHAR2(1000), 
	"FUSION_BUDGET_VERSION_ID" NUMBER, 
	"WORK_QUEUE_ID" NUMBER, 
	 CONSTRAINT "DMT_GL_BUDGET_INT_TFM_PK" PRIMARY KEY ("TFM_SEQUENCE_ID")
  USING INDEX  ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
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
  where  table_name = 'DMT_GL_BUDGET_INT_TFM_TBL' and column_name = 'RECON_KEY';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_GL_BUDGET_INT_TFM_TBL" ADD ("RECON_KEY" VARCHAR2(1000))';
  end if;
end;
/
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_GL_BUDGET_INT_TFM_TBL' and column_name = 'FUSION_BUDGET_VERSION_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_GL_BUDGET_INT_TFM_TBL" ADD ("FUSION_BUDGET_VERSION_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_GL_BUDGET_INT_TFM_N1" ON "DMT_GL_BUDGET_INT_TFM_TBL" ("RUN_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_GL_BUDGET_INT_TFM_N2" ON "DMT_GL_BUDGET_INT_TFM_TBL" ("RUN_ID", "TFM_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_GL_BUDGET_INT_TFM_N3" ON "DMT_GL_BUDGET_INT_TFM_TBL" ("FBDI_CSV_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_GL_BUDGET_INT_TFM_N4" ON "DMT_GL_BUDGET_INT_TFM_TBL" ("STG_SEQUENCE_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_GL_BUDGET_INT_TFM_N5" ON "DMT_GL_BUDGET_INT_TFM_TBL" ("RECON_KEY")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_GL_BUDGET_INT_TFM_TBL"."TFM_STATUS" IS 'Transform lifecycle: STAGED > GENERATED > LOADED / FAILED.';
COMMENT ON COLUMN "DMT_GL_BUDGET_INT_TFM_TBL"."RECON_KEY" IS 'Pre-concatenated business key (run prefix included) that BIP reconciliation matches against Fusion rows.';
COMMENT ON COLUMN "DMT_GL_BUDGET_INT_TFM_TBL"."FUSION_BUDGET_VERSION_ID" IS 'Fusion-assigned identifier captured from the Fusion base tables - written only by BIP reconciliation (positive proof of load).';

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
   where table_name = 'DMT_GL_BUDGET_INT_TFM_TBL' and column_name = 'TFM_STATUS';
  if l_nullable = 'Y' then
    execute immediate 'UPDATE "DMT_GL_BUDGET_INT_TFM_TBL" SET "TFM_STATUS" = ''STAGED'' WHERE "TFM_STATUS" IS NULL';
    execute immediate 'ALTER TABLE "DMT_GL_BUDGET_INT_TFM_TBL" MODIFY ("TFM_STATUS" DEFAULT ''STAGED'' NOT NULL)';
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
  where table_name = 'DMT_GL_BUDGET_INT_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_GL_BUDGET_INT_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
COMMENT ON COLUMN "DMT_GL_BUDGET_INT_TFM_TBL"."WORK_QUEUE_ID" IS 'The work queue item (DMT_WORK_QUEUE_TBL.QUEUE_ID) that processed this record. FK in _foreign_keys.sql. Stamped at generation; unit of per-work-item processing (design section 7, accepted 2026-07-20).';
