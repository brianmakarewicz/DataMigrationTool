-- DMT_WORK_SCHED_DTL_TFM_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_WORK_SCHED_DTL_TFM_TBL" 
   (	"TFM_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_WORK_SCHED_DTL_TFM_SEQ.NEXTVAL NOT NULL ENABLE, 
	"STG_SEQUENCE_ID" NUMBER NOT NULL ENABLE, 
	"FBDI_CSV_ID" NUMBER, 
	"WORK_SCHEDULE_NAME" VARCHAR2(240) NOT NULL ENABLE, 
	"SHIFT_NAME" VARCHAR2(240), 
	"SHIFT_DATE" VARCHAR2(240), 
	"START_TIME" VARCHAR2(240), 
	"END_TIME" VARCHAR2(240), 
	"DURATION" VARCHAR2(240), 
	"UNIT_OF_MEASURE" VARCHAR2(240), 
	"RESULTS_UPDATED_DATE" DATE, 
	"TFM_STATUS" VARCHAR2(30) DEFAULT ''STAGED'' NOT NULL ENABLE, 
	"ERROR_TEXT" CLOB, 
	"LAST_UPDATED_DATE" DATE, 
	"RUN_ID" NUMBER, 
	"RECON_KEY" VARCHAR2(1000), 
	"FUSION_SCHEDULE_ID" NUMBER, 
	 CONSTRAINT "DMT_WORK_SCHED_DTL_TFM_PK" PRIMARY KEY ("TFM_SEQUENCE_ID")
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
  where  table_name = 'DMT_WORK_SCHED_DTL_TFM_TBL' and column_name = 'STATUS';
  if l_n = 1 then
    execute immediate 'ALTER TABLE "DMT_WORK_SCHED_DTL_TFM_TBL" RENAME COLUMN "STATUS" TO "TFM_STATUS"';
  end if;
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
  where  table_name = 'DMT_WORK_SCHED_DTL_TFM_TBL' and column_name = 'RECON_KEY';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_WORK_SCHED_DTL_TFM_TBL" ADD ("RECON_KEY" VARCHAR2(1000))';
  end if;
end;
/
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_WORK_SCHED_DTL_TFM_TBL' and column_name = 'FUSION_SCHEDULE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_WORK_SCHED_DTL_TFM_TBL" ADD ("FUSION_SCHEDULE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_WORK_SCHED_DTL_TFM_N1" ON "DMT_WORK_SCHED_DTL_TFM_TBL" ("RUN_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_WORK_SCHED_DTL_TFM_N2" ON "DMT_WORK_SCHED_DTL_TFM_TBL" ("RUN_ID", "TFM_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_WORK_SCHED_DTL_TFM_N3" ON "DMT_WORK_SCHED_DTL_TFM_TBL" ("FBDI_CSV_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_WORK_SCHED_DTL_TFM_N4" ON "DMT_WORK_SCHED_DTL_TFM_TBL" ("STG_SEQUENCE_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_WORK_SCHED_DTL_TFM_N5" ON "DMT_WORK_SCHED_DTL_TFM_TBL" ("RECON_KEY")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_WORK_SCHED_DTL_TFM_TBL"."TFM_STATUS" IS 'Transform lifecycle: STAGED > GENERATED > LOADED / FAILED.';
COMMENT ON COLUMN "DMT_WORK_SCHED_DTL_TFM_TBL"."RECON_KEY" IS 'Pre-concatenated business key (run prefix included) that BIP reconciliation matches against Fusion rows.';
COMMENT ON COLUMN "DMT_WORK_SCHED_DTL_TFM_TBL"."FUSION_SCHEDULE_ID" IS 'Fusion-assigned identifier captured from the Fusion base tables - written only by BIP reconciliation (positive proof of load).';
