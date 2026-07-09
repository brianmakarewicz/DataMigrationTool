-- DMT_EGP_ITEM_CAT_TFM_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_EGP_ITEM_CAT_TFM_TBL" 
   (	"TFM_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_EGP_ITEM_CAT_TFM_SEQ.NEXTVAL NOT NULL ENABLE, 
	"STG_SEQUENCE_ID" NUMBER NOT NULL ENABLE, 
	"FBDI_CSV_ID" NUMBER, 
	"TRANSACTION_TYPE" VARCHAR2(10), 
	"BATCH_ID" NUMBER, 
	"BATCH_NUMBER" VARCHAR2(40), 
	"ORGANIZATION_CODE" VARCHAR2(18), 
	"ITEM_NUMBER" VARCHAR2(300), 
	"CATEGORY_SET_NAME" VARCHAR2(30), 
	"CATEGORY_CODE" VARCHAR2(250), 
	"CATEGORY_NAME" VARCHAR2(250), 
	"OLD_CATEGORY_CODE" VARCHAR2(250), 
	"OLD_CATEGORY_NAME" VARCHAR2(250), 
	"SOURCE_SYSTEM_CODE" VARCHAR2(30), 
	"SOURCE_SYSTEM_REFERENCE" VARCHAR2(255), 
	"TFM_STATUS" VARCHAR2(30) DEFAULT ''STAGED'', 
	"ERROR_TEXT" CLOB, 
	"RESULTS_UPDATED_DATE" DATE, 
	"LAST_UPDATED_DATE" DATE, 
	"RUN_ID" NUMBER, 
	"RECON_KEY" VARCHAR2(1000), 
	"FUSION_CATEGORY_ID" NUMBER, 
	 CONSTRAINT "DMT_EGP_ITEM_CAT_TFM_PK" PRIMARY KEY ("TFM_SEQUENCE_ID")
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
  where  table_name = 'DMT_EGP_ITEM_CAT_TFM_TBL' and column_name = 'RECON_KEY';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_EGP_ITEM_CAT_TFM_TBL" ADD ("RECON_KEY" VARCHAR2(1000))';
  end if;
end;
/
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_EGP_ITEM_CAT_TFM_TBL' and column_name = 'FUSION_CATEGORY_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_EGP_ITEM_CAT_TFM_TBL" ADD ("FUSION_CATEGORY_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_EGP_ITEM_CAT_TFM_N1" ON "DMT_EGP_ITEM_CAT_TFM_TBL" ("RUN_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_EGP_ITEM_CAT_TFM_N2" ON "DMT_EGP_ITEM_CAT_TFM_TBL" ("RUN_ID", "TFM_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_EGP_ITEM_CAT_TFM_N3" ON "DMT_EGP_ITEM_CAT_TFM_TBL" ("FBDI_CSV_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_EGP_ITEM_CAT_TFM_N4" ON "DMT_EGP_ITEM_CAT_TFM_TBL" ("STG_SEQUENCE_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_EGP_ITEM_CAT_TFM_N5" ON "DMT_EGP_ITEM_CAT_TFM_TBL" ("RECON_KEY")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_EGP_ITEM_CAT_TFM_TBL"."TFM_STATUS" IS 'Transform lifecycle: STAGED > GENERATED > LOADED / FAILED.';
COMMENT ON COLUMN "DMT_EGP_ITEM_CAT_TFM_TBL"."RECON_KEY" IS 'Pre-concatenated business key (run prefix included) that BIP reconciliation matches against Fusion rows.';
COMMENT ON COLUMN "DMT_EGP_ITEM_CAT_TFM_TBL"."FUSION_CATEGORY_ID" IS 'Fusion-assigned identifier captured from the Fusion base tables - written only by BIP reconciliation (positive proof of load).';
