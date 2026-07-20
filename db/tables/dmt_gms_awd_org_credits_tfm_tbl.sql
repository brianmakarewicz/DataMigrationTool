-- DMT_GMS_AWD_ORG_CREDITS_TFM_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_GMS_AWD_ORG_CREDITS_TFM_TBL" 
   (	"TFM_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_GMS_AWD_ORGCR_TFM_SEQ.NEXTVAL NOT NULL ENABLE, 
	"STG_SEQUENCE_ID" NUMBER NOT NULL ENABLE, 
	"FBDI_CSV_ID" NUMBER, 
	"AWARD_NUMBER" VARCHAR2(300), 
	"PROJECT_NUMBER" VARCHAR2(25), 
	"ORGANIZATION" VARCHAR2(240), 
	"CREDIT_PERCENTAGE" NUMBER, 
	"TFM_STATUS" VARCHAR2(30) DEFAULT ''STAGED'' NOT NULL ENABLE, 
	"ERROR_TEXT" CLOB, 
	"LAST_UPDATED_DATE" DATE, 
	"RESULTS_UPDATED_DATE" DATE, 
	"RUN_ID" NUMBER, 
	"RECON_KEY" VARCHAR2(1000), 
	"FUSION_AWARD_ID" NUMBER, 
	"WORK_QUEUE_ID" NUMBER, 
	 CONSTRAINT "DMT_GMS_AWD_ORGCR_TFM_PK" PRIMARY KEY ("TFM_SEQUENCE_ID")
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
  where  table_name = 'DMT_GMS_AWD_ORG_CREDITS_TFM_TBL' and column_name = 'STATUS';
  if l_n = 1 then
    execute immediate 'ALTER TABLE "DMT_GMS_AWD_ORG_CREDITS_TFM_TBL" RENAME COLUMN "STATUS" TO "TFM_STATUS"';
  end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_GMS_ORGCR_TFM_AWD_IX" ON "DMT_GMS_AWD_ORG_CREDITS_TFM_TBL" ("AWARD_NUMBER")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_GMS_ORGCR_TFM_STG_IX" ON "DMT_GMS_AWD_ORG_CREDITS_TFM_TBL" ("STG_SEQUENCE_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON TABLE "DMT_GMS_AWD_ORG_CREDITS_TFM_TBL"  IS 'Grant award organization credits transformed.';

-- ---------------------------------------------------------------------------
-- 2026-07-08 conformance tranche (design section 7: STG/TFM infra-column
-- dictionary + contract-index dictionary): converges a pre-existing database.
-- Fresh installs already get the final shape from the CREATE above.
-- ---------------------------------------------------------------------------
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_GMS_AWD_ORG_CREDITS_TFM_TBL' and column_name = 'RECON_KEY';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_GMS_AWD_ORG_CREDITS_TFM_TBL" ADD ("RECON_KEY" VARCHAR2(1000))';
  end if;
end;
/
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_GMS_AWD_ORG_CREDITS_TFM_TBL' and column_name = 'FUSION_AWARD_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_GMS_AWD_ORG_CREDITS_TFM_TBL" ADD ("FUSION_AWARD_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_GMS_AWD_ORG_CREDITS_TFM_N1" ON "DMT_GMS_AWD_ORG_CREDITS_TFM_TBL" ("RUN_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_GMS_AWD_ORG_CREDITS_TFM_N2" ON "DMT_GMS_AWD_ORG_CREDITS_TFM_TBL" ("RUN_ID", "TFM_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_GMS_AWD_ORG_CREDITS_TFM_N3" ON "DMT_GMS_AWD_ORG_CREDITS_TFM_TBL" ("FBDI_CSV_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_GMS_AWD_ORG_CREDITS_TFM_N4" ON "DMT_GMS_AWD_ORG_CREDITS_TFM_TBL" ("RECON_KEY")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_GMS_AWD_ORG_CREDITS_TFM_TBL"."TFM_STATUS" IS 'Transform lifecycle: STAGED > GENERATED > LOADED / FAILED.';
COMMENT ON COLUMN "DMT_GMS_AWD_ORG_CREDITS_TFM_TBL"."RECON_KEY" IS 'Pre-concatenated business key (run prefix included) that BIP reconciliation matches against Fusion rows.';
COMMENT ON COLUMN "DMT_GMS_AWD_ORG_CREDITS_TFM_TBL"."FUSION_AWARD_ID" IS 'Fusion-assigned identifier captured from the Fusion base tables - written only by BIP reconciliation (positive proof of load).';
