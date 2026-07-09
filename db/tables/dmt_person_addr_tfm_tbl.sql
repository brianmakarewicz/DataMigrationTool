-- DMT_PERSON_ADDR_TFM_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_PERSON_ADDR_TFM_TBL" 
   (	"TFM_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_PERSON_ADDR_TFM_SEQ.NEXTVAL NOT NULL ENABLE, 
	"STG_SEQUENCE_ID" NUMBER NOT NULL ENABLE, 
	"FBDI_CSV_ID" NUMBER, 
	"EFFECTIVE_START_DATE" VARCHAR2(240), 
	"EFFECTIVE_END_DATE" VARCHAR2(240), 
	"PERSON_NUMBER" VARCHAR2(240) NOT NULL ENABLE, 
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
	"FUSION_ADDRESS_ID" NUMBER, 
	"RESULTS_UPDATED_DATE" DATE, 
	"TFM_STATUS" VARCHAR2(30) DEFAULT ''STAGED'' NOT NULL ENABLE, 
	"ERROR_TEXT" CLOB, 
	"LAST_UPDATED_DATE" DATE, 
	"RUN_ID" NUMBER, 
	"RECON_KEY" VARCHAR2(1000), 
	 CONSTRAINT "DMT_PERSON_ADDR_TFM_PK" PRIMARY KEY ("TFM_SEQUENCE_ID")
  USING INDEX  ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_PERSON_ADDR_TFM_TBL"."TFM_SEQUENCE_ID" IS 'PK - from DMT_PERSON_ADDR_TFM_SEQ';
COMMENT ON COLUMN "DMT_PERSON_ADDR_TFM_TBL"."STG_SEQUENCE_ID" IS 'FK to DMT_PERSON_ADDR_STG_TBL â€” which staging row this was transformed from';
COMMENT ON COLUMN "DMT_PERSON_ADDR_TFM_TBL"."FBDI_CSV_ID" IS 'FK to DMT_FBDI_CSV_TBL â€” populated when DAT generator runs';
COMMENT ON COLUMN "DMT_PERSON_ADDR_TFM_TBL"."PERSON_NUMBER" IS 'Person number with run prefix applied';
COMMENT ON COLUMN "DMT_PERSON_ADDR_TFM_TBL"."FUSION_ADDRESS_ID" IS 'Fusion internal ADDRESS_ID - populated by reconciliation';
COMMENT ON COLUMN "DMT_PERSON_ADDR_TFM_TBL"."RESULTS_UPDATED_DATE" IS 'Timestamp of last reconciliation update';
COMMENT ON COLUMN "DMT_PERSON_ADDR_TFM_TBL"."ERROR_TEXT" IS 'Concatenated errors. Appended at each step - never overwritten. Prefixed: [TRANSFORM_ERROR] [POST_VALIDATION] [FUSION_ERROR]';
COMMENT ON TABLE "DMT_PERSON_ADDR_TFM_TBL"  IS 'Person address transformed. Run-specific data â€” one row per staging row per run attempt. HDL business object: PersonAddress.';

-- ---------------------------------------------------------------------------
-- 2026-07-08 conformance tranche (design section 7: STG/TFM infra-column
-- dictionary + contract-index dictionary): converges a pre-existing database.
-- Fresh installs already get the final shape from the CREATE above.
-- ---------------------------------------------------------------------------
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_PERSON_ADDR_TFM_TBL' and column_name = 'STATUS';
  if l_n = 1 then
    execute immediate 'ALTER TABLE "DMT_PERSON_ADDR_TFM_TBL" RENAME COLUMN "STATUS" TO "TFM_STATUS"';
  end if;
end;
/
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_PERSON_ADDR_TFM_TBL' and column_name = 'RECON_KEY';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_PERSON_ADDR_TFM_TBL" ADD ("RECON_KEY" VARCHAR2(1000))';
  end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_PERSON_ADDR_TFM_N1" ON "DMT_PERSON_ADDR_TFM_TBL" ("RUN_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_PERSON_ADDR_TFM_N2" ON "DMT_PERSON_ADDR_TFM_TBL" ("RUN_ID", "TFM_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_PERSON_ADDR_TFM_N3" ON "DMT_PERSON_ADDR_TFM_TBL" ("FBDI_CSV_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_PERSON_ADDR_TFM_N4" ON "DMT_PERSON_ADDR_TFM_TBL" ("STG_SEQUENCE_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_PERSON_ADDR_TFM_N5" ON "DMT_PERSON_ADDR_TFM_TBL" ("RECON_KEY")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_PERSON_ADDR_TFM_TBL"."TFM_STATUS" IS 'Transform lifecycle: STAGED > GENERATED > LOADED / FAILED.';
COMMENT ON COLUMN "DMT_PERSON_ADDR_TFM_TBL"."RECON_KEY" IS 'Pre-concatenated business key (run prefix included) that BIP reconciliation matches against Fusion rows.';
