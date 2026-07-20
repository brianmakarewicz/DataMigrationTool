-- DMT_GMS_AWD_PERSONNEL_TFM_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_GMS_AWD_PERSONNEL_TFM_TBL" 
   (	"TFM_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_GMS_AWD_PERS_TFM_SEQ.NEXTVAL NOT NULL ENABLE, 
	"STG_SEQUENCE_ID" NUMBER NOT NULL ENABLE, 
	"FBDI_CSV_ID" NUMBER, 
	"AWARD_NUMBER" VARCHAR2(300), 
	"PROJECT_NUMBER" VARCHAR2(25), 
	"INTERNAL" VARCHAR2(1), 
	"PERSON_EMAIL" VARCHAR2(240), 
	"PERSON_NAME" VARCHAR2(240), 
	"PERSON_NUMBER" VARCHAR2(30), 
	"ROLE" VARCHAR2(240), 
	"START_DATE" DATE, 
	"END_DATE" DATE, 
	"CREDIT_PERCENTAGE" NUMBER, 
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
	"ATTRIBUTE11" VARCHAR2(150), 
	"ATTRIBUTE12" VARCHAR2(150), 
	"ATTRIBUTE13" VARCHAR2(150), 
	"ATTRIBUTE14" VARCHAR2(150), 
	"ATTRIBUTE15" VARCHAR2(150), 
	"ATTRIBUTE16" VARCHAR2(150), 
	"ATTRIBUTE17" VARCHAR2(150), 
	"ATTRIBUTE18" VARCHAR2(150), 
	"ATTRIBUTE19" VARCHAR2(150), 
	"ATTRIBUTE20" VARCHAR2(150), 
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
	"ATTRIBUTE_TIMESTAMP6" DATE, 
	"ATTRIBUTE_TIMESTAMP7" DATE, 
	"ATTRIBUTE_TIMESTAMP8" DATE, 
	"ATTRIBUTE_TIMESTAMP9" DATE, 
	"ATTRIBUTE_TIMESTAMP10" DATE, 
	"TFM_STATUS" VARCHAR2(30) DEFAULT ''STAGED'' NOT NULL ENABLE, 
	"ERROR_TEXT" CLOB, 
	"LAST_UPDATED_DATE" DATE, 
	"RESULTS_UPDATED_DATE" DATE, 
	"RUN_ID" NUMBER, 
	"RECON_KEY" VARCHAR2(1000), 
	"FUSION_AWARD_ID" NUMBER, 
	"WORK_QUEUE_ID" NUMBER, 
	 CONSTRAINT "DMT_GMS_AWD_PERS_TFM_PK" PRIMARY KEY ("TFM_SEQUENCE_ID")
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
  where  table_name = 'DMT_GMS_AWD_PERSONNEL_TFM_TBL' and column_name = 'STATUS';
  if l_n = 1 then
    execute immediate 'ALTER TABLE "DMT_GMS_AWD_PERSONNEL_TFM_TBL" RENAME COLUMN "STATUS" TO "TFM_STATUS"';
  end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_GMS_AWD_PERS_TFM_AWD_IX" ON "DMT_GMS_AWD_PERSONNEL_TFM_TBL" ("AWARD_NUMBER")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_GMS_AWD_PERS_TFM_STG_IX" ON "DMT_GMS_AWD_PERSONNEL_TFM_TBL" ("STG_SEQUENCE_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON TABLE "DMT_GMS_AWD_PERSONNEL_TFM_TBL"  IS 'Grant award personnel transformed. FBDI interface: GMS_AWARD_PERSONNEL_INT.';

-- ---------------------------------------------------------------------------
-- 2026-07-08 conformance tranche (design section 7: STG/TFM infra-column
-- dictionary + contract-index dictionary): converges a pre-existing database.
-- Fresh installs already get the final shape from the CREATE above.
-- ---------------------------------------------------------------------------
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_GMS_AWD_PERSONNEL_TFM_TBL' and column_name = 'RECON_KEY';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_GMS_AWD_PERSONNEL_TFM_TBL" ADD ("RECON_KEY" VARCHAR2(1000))';
  end if;
end;
/
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_GMS_AWD_PERSONNEL_TFM_TBL' and column_name = 'FUSION_AWARD_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_GMS_AWD_PERSONNEL_TFM_TBL" ADD ("FUSION_AWARD_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_GMS_AWD_PERSONNEL_TFM_N1" ON "DMT_GMS_AWD_PERSONNEL_TFM_TBL" ("RUN_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_GMS_AWD_PERSONNEL_TFM_N2" ON "DMT_GMS_AWD_PERSONNEL_TFM_TBL" ("RUN_ID", "TFM_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_GMS_AWD_PERSONNEL_TFM_N3" ON "DMT_GMS_AWD_PERSONNEL_TFM_TBL" ("FBDI_CSV_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_GMS_AWD_PERSONNEL_TFM_N4" ON "DMT_GMS_AWD_PERSONNEL_TFM_TBL" ("RECON_KEY")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_GMS_AWD_PERSONNEL_TFM_TBL"."TFM_STATUS" IS 'Transform lifecycle: STAGED > GENERATED > LOADED / FAILED.';
COMMENT ON COLUMN "DMT_GMS_AWD_PERSONNEL_TFM_TBL"."RECON_KEY" IS 'Pre-concatenated business key (run prefix included) that BIP reconciliation matches against Fusion rows.';
COMMENT ON COLUMN "DMT_GMS_AWD_PERSONNEL_TFM_TBL"."FUSION_AWARD_ID" IS 'Fusion-assigned identifier captured from the Fusion base tables - written only by BIP reconciliation (positive proof of load).';

-- WORK_QUEUE_ID (work-queue-ID granularity foundation, accepted 2026-07-20;
-- docs/FIX_PLAN.md item 1). Guarded in-file ALTER so an existing DB converges
-- via db/install.sql (the CREATE above carries it for fresh installs). FK is
-- in db/tables/_foreign_keys.sql. NULLABLE for now; NOT NULL deferred.
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where table_name = 'DMT_GMS_AWD_PERSONNEL_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_GMS_AWD_PERSONNEL_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
COMMENT ON COLUMN "DMT_GMS_AWD_PERSONNEL_TFM_TBL"."WORK_QUEUE_ID" IS 'The work queue item (DMT_WORK_QUEUE_TBL.QUEUE_ID) that processed this record. FK in _foreign_keys.sql. Stamped at generation; unit of per-work-item processing (design section 7, accepted 2026-07-20).';
