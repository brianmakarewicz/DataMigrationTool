-- ERR$_DMT_ZX_REGIME_STG_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "ERR$_DMT_ZX_REGIME_STG_TBL" 
   (	"ORA_ERR_NUMBER$" NUMBER, 
	"ORA_ERR_MESG$" VARCHAR2(2000), 
	"ORA_ERR_ROWID$" UROWID (4000), 
	"ORA_ERR_OPTYP$" VARCHAR2(2), 
	"ORA_ERR_TAG$" VARCHAR2(2000), 
	"STG_SEQUENCE_ID" VARCHAR2(4000), 
	"SOURCE_GROUP_ID" VARCHAR2(4000), 
	"TAX_REGIME_CODE" VARCHAR2(4000), 
	"TAX_REGIME_NAME" VARCHAR2(4000), 
	"DESCRIPTION" VARCHAR2(4000), 
	"EFFECTIVE_FROM" VARCHAR2(4000), 
	"EFFECTIVE_TO" VARCHAR2(4000), 
	"COUNTRY_CODE" VARCHAR2(4000), 
	"REGIME_TYPE_FLAG" VARCHAR2(4000), 
	"HAS_SUB_REGIME_FLAG" VARCHAR2(4000), 
	"PARENT_REGIME_CODE" VARCHAR2(4000), 
	"ATTRIBUTE_CATEGORY" VARCHAR2(4000), 
	"ATTRIBUTE1" VARCHAR2(4000), 
	"ATTRIBUTE2" VARCHAR2(4000), 
	"ATTRIBUTE3" VARCHAR2(4000), 
	"ATTRIBUTE4" VARCHAR2(4000), 
	"ATTRIBUTE5" VARCHAR2(4000), 
	"STAGE_DATE" VARCHAR2(4000), 
	"STG_STATUS" VARCHAR2(4000), 
	"SOURCE_ID" VARCHAR2(4000), 
	"LAST_UPDATED_DATE" VARCHAR2(4000), 
	"SCENARIO_ID" VARCHAR2(4000)
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
  where  table_name = 'ERR$_DMT_ZX_REGIME_STG_TBL' and column_name = 'STATUS';
  if l_n = 1 then
    execute immediate 'ALTER TABLE "ERR$_DMT_ZX_REGIME_STG_TBL" RENAME COLUMN "STATUS" TO "STG_STATUS"';
  end if;
end;
/
