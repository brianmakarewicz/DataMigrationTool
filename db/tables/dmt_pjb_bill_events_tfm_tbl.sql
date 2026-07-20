-- DMT_PJB_BILL_EVENTS_TFM_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_PJB_BILL_EVENTS_TFM_TBL" 
   (	"TFM_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_PJB_BILL_EVENTS_TFM_SEQ.NEXTVAL NOT NULL ENABLE, 
	"STG_SEQUENCE_ID" NUMBER NOT NULL ENABLE, 
	"FBDI_CSV_ID" NUMBER, 
	"SOURCENAME" VARCHAR2(240), 
	"SOURCEREF" VARCHAR2(240), 
	"ORGANIZATION_NAME" VARCHAR2(240), 
	"CONTRACT_TYPE_NAME" VARCHAR2(240), 
	"CONTRACT_NUMBER" VARCHAR2(240), 
	"CONTRACT_LINE_NUMBER" VARCHAR2(240), 
	"EVENT_TYPE_NAME" VARCHAR2(240), 
	"EVENT_DESC" VARCHAR2(240), 
	"COMPLETION_DATE" DATE, 
	"BILL_TRNS_CURRENCY_CODE" VARCHAR2(15), 
	"BILL_TRNS_AMOUNT" NUMBER, 
	"PROJECT_NUMBER" VARCHAR2(25), 
	"TASK_NUMBER" VARCHAR2(100), 
	"BILL_HOLD_FLAG" VARCHAR2(1), 
	"REVENUE_HOLD_FLAG" VARCHAR2(1), 
	"ATTRIBUTE_CATEGORY" VARCHAR2(30), 
	"ATTRIBUTE1" VARCHAR2(150), 
	"ATTRIBUTE2" VARCHAR2(150), 
	"ATTRIBUTE3" VARCHAR2(150), 
	"ATTRIBUTE4" VARCHAR2(150), 
	"ATTRIBUTE5" VARCHAR2(150), 
	"ATTRIBUTE6" VARCHAR2(150), 
	"ATTRIBUTE7" VARCHAR2(150), 
	"ATTRIBUTE8" VARCHAR2(150), 
	"ATTRIBUTE9" VARCHAR2(150), 
	"ATTRIBUTE10" VARCHAR2(150), 
	"ATTRIBUTE_CHAR11" VARCHAR2(150), 
	"ATTRIBUTE_CHAR12" VARCHAR2(150), 
	"ATTRIBUTE_CHAR13" VARCHAR2(150), 
	"ATTRIBUTE_CHAR14" VARCHAR2(150), 
	"ATTRIBUTE_CHAR15" VARCHAR2(150), 
	"ATTRIBUTE_CHAR16" VARCHAR2(150), 
	"ATTRIBUTE_CHAR17" VARCHAR2(150), 
	"ATTRIBUTE_CHAR18" VARCHAR2(150), 
	"ATTRIBUTE_CHAR19" VARCHAR2(150), 
	"ATTRIBUTE_CHAR20" VARCHAR2(150), 
	"ATTRIBUTE_CHAR21" VARCHAR2(1000), 
	"ATTRIBUTE_CHAR22" VARCHAR2(1000), 
	"ATTRIBUTE_CHAR23" VARCHAR2(1000), 
	"ATTRIBUTE_CHAR24" VARCHAR2(1000), 
	"ATTRIBUTE_CHAR25" VARCHAR2(1000), 
	"ATTRIBUTE_CHAR26" VARCHAR2(1000), 
	"ATTRIBUTE_CHAR27" VARCHAR2(1000), 
	"ATTRIBUTE_CHAR28" VARCHAR2(1000), 
	"ATTRIBUTE_CHAR29" VARCHAR2(1000), 
	"ATTRIBUTE_CHAR30" VARCHAR2(1000), 
	"ATTRIBUTE_NUMBER1" NUMBER, 
	"ATTRIBUTE_NUMBER2" NUMBER, 
	"ATTRIBUTE_NUMBER3" NUMBER, 
	"ATTRIBUTE_NUMBER4" NUMBER, 
	"ATTRIBUTE_NUMBER5" NUMBER, 
	"ATTRIBUTE_NUMBER6" NUMBER, 
	"ATTRIBUTE_NUMBER7" NUMBER, 
	"ATTRIBUTE_NUMBER8" NUMBER, 
	"ATTRIBUTE_NUMBER9" NUMBER, 
	"ATTRIBUTE_NUMBER10" NUMBER, 
	"ATTRIBUTE_DATE1" DATE, 
	"ATTRIBUTE_DATE2" DATE, 
	"ATTRIBUTE_DATE3" DATE, 
	"ATTRIBUTE_DATE4" DATE, 
	"ATTRIBUTE_DATE5" DATE, 
	"ATTRIBUTE_DATE6" DATE, 
	"ATTRIBUTE_DATE7" DATE, 
	"ATTRIBUTE_DATE8" DATE, 
	"ATTRIBUTE_DATE9" DATE, 
	"ATTRIBUTE_DATE10" DATE, 
	"ATTRIBUTE_TIMESTAMP1" DATE, 
	"ATTRIBUTE_TIMESTAMP2" DATE, 
	"ATTRIBUTE_TIMESTAMP3" DATE, 
	"ATTRIBUTE_TIMESTAMP4" DATE, 
	"ATTRIBUTE_TIMESTAMP5" DATE, 
	"REVERSE_ACCRUAL_FLAG" VARCHAR2(1), 
	"ITEM_EVENT_FLAG" VARCHAR2(1), 
	"QUANTITY" VARCHAR2(240), 
	"ITEM_NUMBER" VARCHAR2(300), 
	"UNIT_OF_MEASURE" VARCHAR2(240), 
	"UNIT_PRICE" VARCHAR2(240), 
	"PREPAYMENT_REQ_EVENT_NUM" VARCHAR2(240), 
	"RESULTS_UPDATED_DATE" DATE, 
	"TFM_STATUS" VARCHAR2(30) DEFAULT ''STAGED'' NOT NULL ENABLE, 
	"ERROR_TEXT" CLOB, 
	"LAST_UPDATED_DATE" DATE, 
	"RUN_ID" NUMBER, 
	"RECON_KEY" VARCHAR2(1000), 
	"FUSION_EVENT_ID" NUMBER, 
	"WORK_QUEUE_ID" NUMBER, 
	 CONSTRAINT "DMT_PJB_BILL_EVENTS_TFM_PK" PRIMARY KEY ("TFM_SEQUENCE_ID")
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
  where  table_name = 'DMT_PJB_BILL_EVENTS_TFM_TBL' and column_name = 'STATUS';
  if l_n = 1 then
    execute immediate 'ALTER TABLE "DMT_PJB_BILL_EVENTS_TFM_TBL" RENAME COLUMN "STATUS" TO "TFM_STATUS"';
  end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_PJB_BILL_EVENTS_TFM_TBL_N1" ON "DMT_PJB_BILL_EVENTS_TFM_TBL" ("STG_SEQUENCE_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_PJB_BILL_EVENTS_TFM_TBL_N4" ON "DMT_PJB_BILL_EVENTS_TFM_TBL" ("FBDI_CSV_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_PJB_BILL_EVENTS_TFM_TBL"."TFM_SEQUENCE_ID" IS 'PK - from DMT_PJB_BILL_EVENTS_TFM_SEQ';
COMMENT ON COLUMN "DMT_PJB_BILL_EVENTS_TFM_TBL"."STG_SEQUENCE_ID" IS 'FK to DMT_PJB_BILL_EVENTS_STG_TBL â€” which staging row this was transformed from';
COMMENT ON COLUMN "DMT_PJB_BILL_EVENTS_TFM_TBL"."FBDI_CSV_ID" IS 'FK to DMT_FBDI_CSV_TBL â€” populated when FBDI generator runs';
COMMENT ON COLUMN "DMT_PJB_BILL_EVENTS_TFM_TBL"."PROJECT_NUMBER" IS 'Project number with dependent prefix applied: NVL(dep_prefix,'''') || stg.PROJECT_NUMBER';
COMMENT ON COLUMN "DMT_PJB_BILL_EVENTS_TFM_TBL"."ERROR_TEXT" IS 'Concatenated errors. Appended at each step â€” never overwritten. Prefixes: [TRANSFORM_ERROR] [POST_VALIDATION] [FUSION_ERROR]';
COMMENT ON TABLE "DMT_PJB_BILL_EVENTS_TFM_TBL"  IS 'Billing Events transformed. Run-specific â€” one row per staging row per run attempt. PROJECT_NUMBER has dependent prefix applied. Reconciliation populated by BIP.';

-- ---------------------------------------------------------------------------
-- 2026-07-08 conformance tranche (design section 7: STG/TFM infra-column
-- dictionary + contract-index dictionary): converges a pre-existing database.
-- Fresh installs already get the final shape from the CREATE above.
-- ---------------------------------------------------------------------------
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_PJB_BILL_EVENTS_TFM_TBL' and column_name = 'RECON_KEY';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_PJB_BILL_EVENTS_TFM_TBL" ADD ("RECON_KEY" VARCHAR2(1000))';
  end if;
end;
/
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_PJB_BILL_EVENTS_TFM_TBL' and column_name = 'FUSION_EVENT_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_PJB_BILL_EVENTS_TFM_TBL" ADD ("FUSION_EVENT_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_PJB_BILL_EVENTS_TFM_N1" ON "DMT_PJB_BILL_EVENTS_TFM_TBL" ("RUN_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_PJB_BILL_EVENTS_TFM_N2" ON "DMT_PJB_BILL_EVENTS_TFM_TBL" ("RUN_ID", "TFM_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_PJB_BILL_EVENTS_TFM_N3" ON "DMT_PJB_BILL_EVENTS_TFM_TBL" ("RECON_KEY")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_PJB_BILL_EVENTS_TFM_TBL"."TFM_STATUS" IS 'Transform lifecycle: STAGED > GENERATED > LOADED / FAILED.';
COMMENT ON COLUMN "DMT_PJB_BILL_EVENTS_TFM_TBL"."RECON_KEY" IS 'Pre-concatenated business key (run prefix included) that BIP reconciliation matches against Fusion rows.';
COMMENT ON COLUMN "DMT_PJB_BILL_EVENTS_TFM_TBL"."FUSION_EVENT_ID" IS 'Fusion-assigned identifier captured from the Fusion base tables - written only by BIP reconciliation (positive proof of load).';

-- WORK_QUEUE_ID (work-queue-ID granularity foundation, accepted 2026-07-20;
-- docs/FIX_PLAN.md item 1). Guarded in-file ALTER so an existing DB converges
-- via db/install.sql (the CREATE above carries it for fresh installs). FK is
-- in db/tables/_foreign_keys.sql. NULLABLE for now; NOT NULL deferred.
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where table_name = 'DMT_PJB_BILL_EVENTS_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_PJB_BILL_EVENTS_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
COMMENT ON COLUMN "DMT_PJB_BILL_EVENTS_TFM_TBL"."WORK_QUEUE_ID" IS 'The work queue item (DMT_WORK_QUEUE_TBL.QUEUE_ID) that processed this record. FK in _foreign_keys.sql. Stamped at generation; unit of per-work-item processing (design section 7, accepted 2026-07-20).';
