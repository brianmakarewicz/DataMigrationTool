-- DMT_PERSON_ADDR_STG_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_PERSON_ADDR_STG_TBL" 
   (	"STG_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_PERSON_ADDR_STG_SEQ.NEXTVAL NOT NULL ENABLE, 
	"EFFECTIVE_START_DATE" VARCHAR2(240), 
	"EFFECTIVE_END_DATE" VARCHAR2(240), 
	"PERSON_NUMBER" VARCHAR2(240), 
	"ADDRESS_TYPE" VARCHAR2(240), 
	"ADDRESS_LINE_1" VARCHAR2(240), 
	"ADDRESS_LINE_2" VARCHAR2(240), 
	"ADDRESS_LINE_3" VARCHAR2(240), 
	"ADDRESS_LINE_4" VARCHAR2(240), 
	"TOWN_OR_CITY" VARCHAR2(240), 
	"REGION_1" VARCHAR2(240), 
	"REGION_2" VARCHAR2(240), 
	"REGION_3" VARCHAR2(240), 
	"POSTAL_CODE" VARCHAR2(240), 
	"COUNTRY" VARCHAR2(240), 
	"PRIMARY_FLAG" VARCHAR2(240), 
	"FROM_DATE" VARCHAR2(240), 
	"TO_DATE" VARCHAR2(240), 
	"ADD_INFORMATION13" VARCHAR2(240), 
	"ADD_INFORMATION14" VARCHAR2(240), 
	"ADD_INFORMATION15" VARCHAR2(240), 
	"ADD_INFORMATION16" VARCHAR2(240), 
	"ADD_INFORMATION17" VARCHAR2(240), 
	"ADD_INFORMATION18" VARCHAR2(240), 
	"ADD_INFORMATION19" VARCHAR2(240), 
	"ADD_INFORMATION20" VARCHAR2(240), 
	"ADD_INFORMATION21" VARCHAR2(240), 
	"ADD_INFORMATION22" VARCHAR2(240), 
	"ADD_INFORMATION23" VARCHAR2(240), 
	"ADD_INFORMATION24" VARCHAR2(240), 
	"ADD_INFORMATION25" VARCHAR2(240), 
	"ADD_INFORMATION26" VARCHAR2(240), 
	"ADD_INFORMATION27" VARCHAR2(240), 
	"ADD_INFORMATION28" VARCHAR2(240), 
	"ADD_INFORMATION29" VARCHAR2(240), 
	"ADD_INFORMATION30" VARCHAR2(240), 
	"SOURCE_ID" VARCHAR2(200), 
	"STAGE_DATE" DATE DEFAULT SYSDATE, 
	"STG_STATUS" VARCHAR2(30) DEFAULT ''NEW'' NOT NULL ENABLE, 
	"ERROR_TEXT" CLOB, 
	"LAST_UPDATED_DATE" DATE, 
	"SCENARIO_ID" NUMBER, 
	 CONSTRAINT "DMT_PERSON_ADDR_STG_PK" PRIMARY KEY ("STG_SEQUENCE_ID")
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
  where  table_name = 'DMT_PERSON_ADDR_STG_TBL' and column_name = 'STATUS';
  if l_n = 1 then
    execute immediate 'ALTER TABLE "DMT_PERSON_ADDR_STG_TBL" RENAME COLUMN "STATUS" TO "STG_STATUS"';
  end if;
end;
/

COMMENT ON COLUMN "DMT_PERSON_ADDR_STG_TBL"."STG_SEQUENCE_ID" IS 'PK - from DMT_PERSON_ADDR_STG_SEQ. Populated by DB default, never supplied by user.';
COMMENT ON COLUMN "DMT_PERSON_ADDR_STG_TBL"."PERSON_NUMBER" IS 'Worker person number â€” FK to Worker business object';
COMMENT ON COLUMN "DMT_PERSON_ADDR_STG_TBL"."ADDRESS_TYPE" IS 'Address type: HOME, MAIL';
COMMENT ON COLUMN "DMT_PERSON_ADDR_STG_TBL"."REGION_1" IS 'State or province';
COMMENT ON COLUMN "DMT_PERSON_ADDR_STG_TBL"."REGION_2" IS 'County';
COMMENT ON COLUMN "DMT_PERSON_ADDR_STG_TBL"."SOURCE_ID" IS 'Natural key from source system';
COMMENT ON COLUMN "DMT_PERSON_ADDR_STG_TBL"."ERROR_TEXT" IS 'Concatenated errors. Appended at each step - never overwritten.';
COMMENT ON TABLE "DMT_PERSON_ADDR_STG_TBL"  IS 'Person address staging. Raw user-loaded data only. Run-specific data in DMT_PERSON_ADDR_TFM_TBL. HDL business object: PersonAddress.';

-- ---------------------------------------------------------------------------
-- 2026-07-08 conformance tranche (design section 7: STG/TFM infra-column
-- dictionary + contract-index dictionary): converges a pre-existing database.
-- Fresh installs already get the final shape from the CREATE above.
-- ---------------------------------------------------------------------------
begin
  execute immediate 'CREATE INDEX "DMT_PERSON_ADDR_STG_N1" ON "DMT_PERSON_ADDR_STG_TBL" ("STG_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_PERSON_ADDR_STG_N2" ON "DMT_PERSON_ADDR_STG_TBL" ("SCENARIO_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_PERSON_ADDR_STG_TBL"."STG_STATUS" IS 'Staging lifecycle: NEW > TRANSFORMED / FAILED. Forward-only, never reset; errors accumulate in ERROR_TEXT.';

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
   where table_name = 'DMT_PERSON_ADDR_STG_TBL' and column_name = 'STG_STATUS';
  if l_nullable = 'Y' then
    execute immediate 'UPDATE "DMT_PERSON_ADDR_STG_TBL" SET "STG_STATUS" = ''NEW'' WHERE "STG_STATUS" IS NULL';
    execute immediate 'ALTER TABLE "DMT_PERSON_ADDR_STG_TBL" MODIFY ("STG_STATUS" DEFAULT ''NEW'' NOT NULL)';
  end if;
end;
/
