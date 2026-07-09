-- DMT_EGP_ITEM_CAT_STG_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_EGP_ITEM_CAT_STG_TBL" 
   (	"STG_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_EGP_ITEM_CAT_STG_SEQ.NEXTVAL NOT NULL ENABLE, 
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
	"STAGE_DATE" DATE DEFAULT SYSDATE, 
	"STG_STATUS" VARCHAR2(30) DEFAULT ''NEW'', 
	"ERROR_TEXT" CLOB, 
	"SOURCE_ID" VARCHAR2(240), 
	"LAST_UPDATED_DATE" DATE, 
	"SCENARIO_ID" NUMBER, 
	 CONSTRAINT "DMT_EGP_ITEM_CAT_STG_PK" PRIMARY KEY ("STG_SEQUENCE_ID")
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
  where  table_name = 'DMT_EGP_ITEM_CAT_STG_TBL' and column_name = 'STATUS';
  if l_n = 1 then
    execute immediate 'ALTER TABLE "DMT_EGP_ITEM_CAT_STG_TBL" RENAME COLUMN "STATUS" TO "STG_STATUS"';
  end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_EGP_ITEM_CAT_STG_N1" ON "DMT_EGP_ITEM_CAT_STG_TBL" ("STG_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_EGP_ITEM_CAT_STG_N2" ON "DMT_EGP_ITEM_CAT_STG_TBL" ("SCENARIO_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_EGP_ITEM_CAT_STG_TBL"."STG_STATUS" IS 'Staging lifecycle: NEW > TRANSFORMED / FAILED. Forward-only, never reset; errors accumulate in ERROR_TEXT.';
