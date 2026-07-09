-- DMT_AP_PAY_TERM_LINE_TFM_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_AP_PAY_TERM_LINE_TFM_TBL" 
   (	"TFM_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_AP_PAY_TERM_LINE_TFM_SEQ.NEXTVAL NOT NULL ENABLE, 
	"STG_SEQUENCE_ID" NUMBER NOT NULL ENABLE, 
	"FBDI_CSV_ID" NUMBER, 
	"SOURCE_GROUP_ID" NUMBER, 
	"SEQUENCE_NUM" NUMBER, 
	"DUE_PERCENT" NUMBER, 
	"DUE_AMOUNT" NUMBER, 
	"DUE_DAYS" NUMBER, 
	"DUE_DATE" DATE, 
	"DISCOUNT_PERCENT" NUMBER, 
	"DISCOUNT_DAYS" NUMBER, 
	"DISCOUNT_PERCENT_2" NUMBER, 
	"DISCOUNT_DAYS_2" NUMBER, 
	"TFM_STATUS" VARCHAR2(30) DEFAULT ''STAGED'' NOT NULL ENABLE, 
	"ERROR_TEXT" CLOB, 
	"RESULTS_UPDATED_DATE" DATE, 
	"LAST_UPDATED_DATE" DATE, 
	"RUN_ID" NUMBER, 
	"RECON_KEY" VARCHAR2(1000), 
	"FUSION_TERM_ID" NUMBER, 
	 CONSTRAINT "DMT_AP_PAY_TERM_LINE_TFM_PK" PRIMARY KEY ("TFM_SEQUENCE_ID")
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
  where  table_name = 'DMT_AP_PAY_TERM_LINE_TFM_TBL' and column_name = 'RECON_KEY';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_AP_PAY_TERM_LINE_TFM_TBL" ADD ("RECON_KEY" VARCHAR2(1000))';
  end if;
end;
/
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_AP_PAY_TERM_LINE_TFM_TBL' and column_name = 'FUSION_TERM_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_AP_PAY_TERM_LINE_TFM_TBL" ADD ("FUSION_TERM_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_AP_PAY_TERM_LINE_TFM_N1" ON "DMT_AP_PAY_TERM_LINE_TFM_TBL" ("RUN_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_AP_PAY_TERM_LINE_TFM_N2" ON "DMT_AP_PAY_TERM_LINE_TFM_TBL" ("RUN_ID", "TFM_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_AP_PAY_TERM_LINE_TFM_N3" ON "DMT_AP_PAY_TERM_LINE_TFM_TBL" ("FBDI_CSV_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_AP_PAY_TERM_LINE_TFM_N4" ON "DMT_AP_PAY_TERM_LINE_TFM_TBL" ("STG_SEQUENCE_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_AP_PAY_TERM_LINE_TFM_N5" ON "DMT_AP_PAY_TERM_LINE_TFM_TBL" ("RECON_KEY")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_AP_PAY_TERM_LINE_TFM_TBL"."TFM_STATUS" IS 'Transform lifecycle: STAGED > GENERATED > LOADED / FAILED.';
COMMENT ON COLUMN "DMT_AP_PAY_TERM_LINE_TFM_TBL"."RECON_KEY" IS 'Pre-concatenated business key (run prefix included) that BIP reconciliation matches against Fusion rows.';
COMMENT ON COLUMN "DMT_AP_PAY_TERM_LINE_TFM_TBL"."FUSION_TERM_ID" IS 'Fusion-assigned identifier captured from the Fusion base tables - written only by BIP reconciliation (positive proof of load).';

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
   where table_name = 'DMT_AP_PAY_TERM_LINE_TFM_TBL' and column_name = 'TFM_STATUS';
  if l_nullable = 'Y' then
    execute immediate 'UPDATE "DMT_AP_PAY_TERM_LINE_TFM_TBL" SET "TFM_STATUS" = ''STAGED'' WHERE "TFM_STATUS" IS NULL';
    execute immediate 'ALTER TABLE "DMT_AP_PAY_TERM_LINE_TFM_TBL" MODIFY ("TFM_STATUS" DEFAULT ''STAGED'' NOT NULL)';
  end if;
end;
/
