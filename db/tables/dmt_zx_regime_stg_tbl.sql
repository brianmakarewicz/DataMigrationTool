-- DMT_ZX_REGIME_STG_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_ZX_REGIME_STG_TBL" 
   (	"STG_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_ZX_REGIME_STG_SEQ.NEXTVAL NOT NULL ENABLE, 
	"SOURCE_GROUP_ID" NUMBER, 
	"TAX_REGIME_CODE" VARCHAR2(30), 
	"TAX_REGIME_NAME" VARCHAR2(240), 
	"DESCRIPTION" VARCHAR2(240), 
	"EFFECTIVE_FROM" DATE, 
	"EFFECTIVE_TO" DATE, 
	"COUNTRY_CODE" VARCHAR2(2), 
	"REGIME_TYPE_FLAG" VARCHAR2(1), 
	"HAS_SUB_REGIME_FLAG" VARCHAR2(1), 
	"PARENT_REGIME_CODE" VARCHAR2(30), 
	"ATTRIBUTE_CATEGORY" VARCHAR2(30), 
	"ATTRIBUTE1" VARCHAR2(150), 
	"ATTRIBUTE2" VARCHAR2(150), 
	"ATTRIBUTE3" VARCHAR2(150), 
	"ATTRIBUTE4" VARCHAR2(150), 
	"ATTRIBUTE5" VARCHAR2(150), 
	"STAGE_DATE" DATE DEFAULT SYSDATE, 
	"STG_STATUS" VARCHAR2(30) DEFAULT ''NEW'' NOT NULL ENABLE, 
	"ERROR_TEXT" CLOB, 
	"SOURCE_ID" VARCHAR2(240), 
	"LAST_UPDATED_DATE" DATE, 
	"SCENARIO_ID" NUMBER, 
	 CONSTRAINT "DMT_ZX_REGIME_STG_PK" PRIMARY KEY ("STG_SEQUENCE_ID")
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
  where  table_name = 'DMT_ZX_REGIME_STG_TBL' and column_name = 'STATUS';
  if l_n = 1 then
    execute immediate 'ALTER TABLE "DMT_ZX_REGIME_STG_TBL" RENAME COLUMN "STATUS" TO "STG_STATUS"';
  end if;
end;
/

-- ---------------------------------------------------------------------------
-- 2026-07-08 conformance tranche (design section 7: STG/TFM infra-column
-- dictionary + contract-index dictionary): converges a pre-existing database.
-- Fresh installs already get the final shape from the CREATE above.
-- ---------------------------------------------------------------------------
begin
  execute immediate 'CREATE INDEX "DMT_ZX_REGIME_STG_N1" ON "DMT_ZX_REGIME_STG_TBL" ("STG_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_ZX_REGIME_STG_N2" ON "DMT_ZX_REGIME_STG_TBL" ("SCENARIO_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_ZX_REGIME_STG_TBL"."STG_STATUS" IS 'Staging lifecycle: NEW > TRANSFORMED / FAILED. Forward-only, never reset; errors accumulate in ERROR_TEXT.';

-- ---------------------------------------------------------------------------
-- 2026-07-09 conformance review F2 (STG/TFM infra-column dictionary, design
-- section 7 accepted 2026-07-08): STG_STATUS is VARCHAR2(30) DEFAULT 'NEW'
-- NOT NULL. Backfills any NULL statuses to the default, then converges a
-- pre-existing database; fresh installs get the shape from the CREATE above.
-- ---------------------------------------------------------------------------
declare
  l_nullable varchar2(1);
begin
  select nullable into l_nullable from user_tab_columns
   where table_name = 'DMT_ZX_REGIME_STG_TBL' and column_name = 'STG_STATUS';
  if l_nullable = 'Y' then
    execute immediate 'UPDATE "DMT_ZX_REGIME_STG_TBL" SET "STG_STATUS" = ''NEW'' WHERE "STG_STATUS" IS NULL';
    execute immediate 'ALTER TABLE "DMT_ZX_REGIME_STG_TBL" MODIFY ("STG_STATUS" DEFAULT ''NEW'' NOT NULL)';
  end if;
end;
/
