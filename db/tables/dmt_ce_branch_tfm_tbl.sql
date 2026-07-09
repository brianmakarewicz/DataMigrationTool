-- DMT_CE_BRANCH_TFM_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_CE_BRANCH_TFM_TBL" 
   (	"TFM_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_CE_BRANCH_TFM_SEQ.NEXTVAL NOT NULL ENABLE, 
	"STG_SEQUENCE_ID" NUMBER NOT NULL ENABLE, 
	"FBDI_CSV_ID" NUMBER, 
	"SOURCE_GROUP_ID" NUMBER, 
	"SOURCE_LINE_ID" NUMBER, 
	"BANK_NAME" VARCHAR2(360), 
	"BRANCH_NAME" VARCHAR2(360), 
	"BRANCH_NUMBER" VARCHAR2(30), 
	"BIC_CODE" VARCHAR2(15), 
	"ALTERNATE_NAME" VARCHAR2(320), 
	"DESCRIPTION" VARCHAR2(240), 
	"EFT_SWIFT_CODE" VARCHAR2(12), 
	"COUNTRY_CODE" VARCHAR2(2), 
	"ADDRESS_LINE1" VARCHAR2(240), 
	"CITY" VARCHAR2(60), 
	"STATE" VARCHAR2(60), 
	"POSTAL_CODE" VARCHAR2(30), 
	"END_DATE" DATE, 
	"TFM_STATUS" VARCHAR2(30) DEFAULT ''STAGED'', 
	"ERROR_TEXT" CLOB, 
	"RESULTS_UPDATED_DATE" DATE, 
	"LAST_UPDATED_DATE" DATE, 
	"RUN_ID" NUMBER, 
	"RECON_KEY" VARCHAR2(1000), 
	"FUSION_BRANCH_PARTY_ID" NUMBER, 
	 CONSTRAINT "DMT_CE_BRANCH_TFM_PK" PRIMARY KEY ("TFM_SEQUENCE_ID")
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
  where  table_name = 'DMT_CE_BRANCH_TFM_TBL' and column_name = 'RECON_KEY';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_CE_BRANCH_TFM_TBL" ADD ("RECON_KEY" VARCHAR2(1000))';
  end if;
end;
/
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_CE_BRANCH_TFM_TBL' and column_name = 'FUSION_BRANCH_PARTY_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_CE_BRANCH_TFM_TBL" ADD ("FUSION_BRANCH_PARTY_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_CE_BRANCH_TFM_N1" ON "DMT_CE_BRANCH_TFM_TBL" ("RUN_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_CE_BRANCH_TFM_N2" ON "DMT_CE_BRANCH_TFM_TBL" ("RUN_ID", "TFM_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_CE_BRANCH_TFM_N3" ON "DMT_CE_BRANCH_TFM_TBL" ("FBDI_CSV_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_CE_BRANCH_TFM_N4" ON "DMT_CE_BRANCH_TFM_TBL" ("STG_SEQUENCE_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_CE_BRANCH_TFM_N5" ON "DMT_CE_BRANCH_TFM_TBL" ("RECON_KEY")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_CE_BRANCH_TFM_TBL"."TFM_STATUS" IS 'Transform lifecycle: STAGED > GENERATED > LOADED / FAILED.';
COMMENT ON COLUMN "DMT_CE_BRANCH_TFM_TBL"."RECON_KEY" IS 'Pre-concatenated business key (run prefix included) that BIP reconciliation matches against Fusion rows.';
COMMENT ON COLUMN "DMT_CE_BRANCH_TFM_TBL"."FUSION_BRANCH_PARTY_ID" IS 'Fusion-assigned identifier captured from the Fusion base tables - written only by BIP reconciliation (positive proof of load).';
