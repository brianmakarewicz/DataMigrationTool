-- DMT_AP_PAY_TERM_LINE_STG_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_AP_PAY_TERM_LINE_STG_TBL" 
   (	"STG_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_AP_PAY_TERM_LINE_STG_SEQ.NEXTVAL NOT NULL ENABLE, 
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
	"STAGE_DATE" DATE DEFAULT SYSDATE, 
	"STG_STATUS" VARCHAR2(30) DEFAULT ''NEW'', 
	"ERROR_TEXT" CLOB, 
	"SOURCE_ID" VARCHAR2(240), 
	"LAST_UPDATED_DATE" DATE, 
	"SCENARIO_ID" NUMBER, 
	 CONSTRAINT "DMT_AP_PAY_TERM_LINE_STG_PK" PRIMARY KEY ("STG_SEQUENCE_ID")
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
  where  table_name = 'DMT_AP_PAY_TERM_LINE_STG_TBL' and column_name = 'STATUS';
  if l_n = 1 then
    execute immediate 'ALTER TABLE "DMT_AP_PAY_TERM_LINE_STG_TBL" RENAME COLUMN "STATUS" TO "STG_STATUS"';
  end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_AP_PAY_TERM_LINE_STG_N1" ON "DMT_AP_PAY_TERM_LINE_STG_TBL" ("STG_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_AP_PAY_TERM_LINE_STG_N2" ON "DMT_AP_PAY_TERM_LINE_STG_TBL" ("SCENARIO_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_AP_PAY_TERM_LINE_STG_TBL"."STG_STATUS" IS 'Staging lifecycle: NEW > TRANSFORMED / FAILED. Forward-only, never reset; errors accumulate in ERROR_TEXT.';
