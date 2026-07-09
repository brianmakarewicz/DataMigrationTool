-- DMT_FA_ASSET_ASSIGN_TFM_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_FA_ASSET_ASSIGN_TFM_TBL" 
   (	"TFM_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_FA_ASSET_ASSIGN_TFM_SEQ.NEXTVAL NOT NULL ENABLE, 
	"STG_SEQUENCE_ID" NUMBER NOT NULL ENABLE, 
	"FBDI_CSV_ID" NUMBER, 
	"ASSET_NUMBER" VARCHAR2(30), 
	"UNITS_ASSIGNED" NUMBER, 
	"EXPENSE_ACCOUNT_SEGMENT1" VARCHAR2(25), 
	"EXPENSE_ACCOUNT_SEGMENT2" VARCHAR2(25), 
	"EXPENSE_ACCOUNT_SEGMENT3" VARCHAR2(25), 
	"EXPENSE_ACCOUNT_SEGMENT4" VARCHAR2(25), 
	"EXPENSE_ACCOUNT_SEGMENT5" VARCHAR2(25), 
	"EXPENSE_ACCOUNT_SEGMENT6" VARCHAR2(25), 
	"EXPENSE_ACCOUNT_SEGMENT7" VARCHAR2(25), 
	"EXPENSE_ACCOUNT_SEGMENT8" VARCHAR2(25), 
	"EXPENSE_ACCOUNT_SEGMENT9" VARCHAR2(25), 
	"EXPENSE_ACCOUNT_SEGMENT10" VARCHAR2(25), 
	"LOCATION_SEGMENT1" VARCHAR2(30), 
	"LOCATION_SEGMENT2" VARCHAR2(30), 
	"LOCATION_SEGMENT3" VARCHAR2(30), 
	"LOCATION_SEGMENT4" VARCHAR2(30), 
	"LOCATION_SEGMENT5" VARCHAR2(30), 
	"LOCATION_SEGMENT6" VARCHAR2(30), 
	"LOCATION_SEGMENT7" VARCHAR2(30), 
	"TFM_STATUS" VARCHAR2(30) DEFAULT ''STAGED'', 
	"ERROR_TEXT" CLOB, 
	"RESULTS_UPDATED_DATE" DATE, 
	"LAST_UPDATED_DATE" DATE, 
	"RUN_ID" NUMBER, 
	"RECON_KEY" VARCHAR2(1000), 
	"FUSION_DISTRIBUTION_ID" NUMBER, 
	 CONSTRAINT "DMT_FA_ASSET_ASSIGN_TFM_PK" PRIMARY KEY ("TFM_SEQUENCE_ID")
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
  where  table_name = 'DMT_FA_ASSET_ASSIGN_TFM_TBL' and column_name = 'STATUS';
  if l_n = 1 then
    execute immediate 'ALTER TABLE "DMT_FA_ASSET_ASSIGN_TFM_TBL" RENAME COLUMN "STATUS" TO "TFM_STATUS"';
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
  where  table_name = 'DMT_FA_ASSET_ASSIGN_TFM_TBL' and column_name = 'RECON_KEY';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_FA_ASSET_ASSIGN_TFM_TBL" ADD ("RECON_KEY" VARCHAR2(1000))';
  end if;
end;
/
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_FA_ASSET_ASSIGN_TFM_TBL' and column_name = 'FUSION_DISTRIBUTION_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_FA_ASSET_ASSIGN_TFM_TBL" ADD ("FUSION_DISTRIBUTION_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_FA_ASSET_ASSIGN_TFM_N1" ON "DMT_FA_ASSET_ASSIGN_TFM_TBL" ("RUN_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_FA_ASSET_ASSIGN_TFM_N2" ON "DMT_FA_ASSET_ASSIGN_TFM_TBL" ("RUN_ID", "TFM_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_FA_ASSET_ASSIGN_TFM_N3" ON "DMT_FA_ASSET_ASSIGN_TFM_TBL" ("FBDI_CSV_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_FA_ASSET_ASSIGN_TFM_N4" ON "DMT_FA_ASSET_ASSIGN_TFM_TBL" ("STG_SEQUENCE_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_FA_ASSET_ASSIGN_TFM_N5" ON "DMT_FA_ASSET_ASSIGN_TFM_TBL" ("RECON_KEY")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_FA_ASSET_ASSIGN_TFM_TBL"."TFM_STATUS" IS 'Transform lifecycle: STAGED > GENERATED > LOADED / FAILED.';
COMMENT ON COLUMN "DMT_FA_ASSET_ASSIGN_TFM_TBL"."RECON_KEY" IS 'Pre-concatenated business key (run prefix included) that BIP reconciliation matches against Fusion rows.';
COMMENT ON COLUMN "DMT_FA_ASSET_ASSIGN_TFM_TBL"."FUSION_DISTRIBUTION_ID" IS 'Fusion-assigned identifier captured from the Fusion base tables - written only by BIP reconciliation (positive proof of load).';
