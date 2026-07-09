-- DMT_CE_BANK_ACCT_TFM_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_CE_BANK_ACCT_TFM_TBL" 
   (	"TFM_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_CE_BANK_ACCT_TFM_SEQ.NEXTVAL NOT NULL ENABLE, 
	"STG_SEQUENCE_ID" NUMBER NOT NULL ENABLE, 
	"FBDI_CSV_ID" NUMBER, 
	"SOURCE_GROUP_ID" NUMBER, 
	"SOURCE_LINE_ID" NUMBER, 
	"BANK_NAME" VARCHAR2(360), 
	"BRANCH_NAME" VARCHAR2(360), 
	"ACCOUNT_NAME" VARCHAR2(80), 
	"ACCOUNT_NUMBER" VARCHAR2(30), 
	"CURRENCY_CODE" VARCHAR2(15), 
	"ACCOUNT_TYPE" VARCHAR2(25), 
	"LEGAL_ENTITY_NAME" VARCHAR2(240), 
	"DESCRIPTION" VARCHAR2(240), 
	"IBAN" VARCHAR2(50), 
	"CHECK_DIGITS" VARCHAR2(30), 
	"MULTI_CURRENCY_ALLOWED_FLAG" VARCHAR2(1), 
	"ACCOUNT_SUFFIX" VARCHAR2(30), 
	"SECONDARY_ACCOUNT_REFERENCE" VARCHAR2(30), 
	"END_DATE" DATE, 
	"ATTRIBUTE_CATEGORY" VARCHAR2(30), 
	"ATTRIBUTE1" VARCHAR2(150), 
	"ATTRIBUTE2" VARCHAR2(150), 
	"ATTRIBUTE3" VARCHAR2(150), 
	"ATTRIBUTE4" VARCHAR2(150), 
	"ATTRIBUTE5" VARCHAR2(150), 
	"TFM_STATUS" VARCHAR2(30) DEFAULT ''STAGED'', 
	"ERROR_TEXT" CLOB, 
	"RESULTS_UPDATED_DATE" DATE, 
	"LAST_UPDATED_DATE" DATE, 
	"RUN_ID" NUMBER, 
	"RECON_KEY" VARCHAR2(1000), 
	"FUSION_BANK_ACCOUNT_ID" NUMBER, 
	 CONSTRAINT "DMT_CE_BANK_ACCT_TFM_PK" PRIMARY KEY ("TFM_SEQUENCE_ID")
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
  where  table_name = 'DMT_CE_BANK_ACCT_TFM_TBL' and column_name = 'RECON_KEY';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_CE_BANK_ACCT_TFM_TBL" ADD ("RECON_KEY" VARCHAR2(1000))';
  end if;
end;
/
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_CE_BANK_ACCT_TFM_TBL' and column_name = 'FUSION_BANK_ACCOUNT_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_CE_BANK_ACCT_TFM_TBL" ADD ("FUSION_BANK_ACCOUNT_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_CE_BANK_ACCT_TFM_N1" ON "DMT_CE_BANK_ACCT_TFM_TBL" ("RUN_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_CE_BANK_ACCT_TFM_N2" ON "DMT_CE_BANK_ACCT_TFM_TBL" ("RUN_ID", "TFM_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_CE_BANK_ACCT_TFM_N3" ON "DMT_CE_BANK_ACCT_TFM_TBL" ("FBDI_CSV_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_CE_BANK_ACCT_TFM_N4" ON "DMT_CE_BANK_ACCT_TFM_TBL" ("STG_SEQUENCE_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_CE_BANK_ACCT_TFM_N5" ON "DMT_CE_BANK_ACCT_TFM_TBL" ("RECON_KEY")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_CE_BANK_ACCT_TFM_TBL"."TFM_STATUS" IS 'Transform lifecycle: STAGED > GENERATED > LOADED / FAILED.';
COMMENT ON COLUMN "DMT_CE_BANK_ACCT_TFM_TBL"."RECON_KEY" IS 'Pre-concatenated business key (run prefix included) that BIP reconciliation matches against Fusion rows.';
COMMENT ON COLUMN "DMT_CE_BANK_ACCT_TFM_TBL"."FUSION_BANK_ACCOUNT_ID" IS 'Fusion-assigned identifier captured from the Fusion base tables - written only by BIP reconciliation (positive proof of load).';
