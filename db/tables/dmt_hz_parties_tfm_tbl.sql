-- DMT_HZ_PARTIES_TFM_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_HZ_PARTIES_TFM_TBL" 
   (	"TFM_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_HZ_PARTIES_TFM_SEQ.NEXTVAL NOT NULL ENABLE, 
	"STG_SEQUENCE_ID" NUMBER NOT NULL ENABLE, 
	"FBDI_CSV_ID" NUMBER, 
	"BATCH_ID" NUMBER, 
	"PARTY_ORIG_SYSTEM" VARCHAR2(30), 
	"PARTY_ORIG_SYSTEM_REFERENCE" VARCHAR2(240), 
	"INSERT_UPDATE_FLAG" VARCHAR2(1), 
	"PARTY_TYPE" VARCHAR2(30), 
	"PARTY_NUMBER" VARCHAR2(30), 
	"SALUTATION" VARCHAR2(60), 
	"PARTY_USAGE_CODE" VARCHAR2(30), 
	"JGZZ_FISCAL_CODE" VARCHAR2(20), 
	"ORGANIZATION_NAME" VARCHAR2(360), 
	"DUNS_NUMBER_C" VARCHAR2(30), 
	"PERSON_FIRST_NAME" VARCHAR2(150), 
	"PERSON_LAST_NAME" VARCHAR2(150), 
	"PERSON_LAST_NAME_PREFIX" VARCHAR2(30), 
	"PERSON_SECOND_LAST_NAME" VARCHAR2(150), 
	"PERSON_MIDDLE_NAME" VARCHAR2(60), 
	"PERSON_NAME_SUFFIX" VARCHAR2(30), 
	"PERSON_TITLE" VARCHAR2(60), 
	"ATTRIBUTE_CATEGORY" VARCHAR2(30), 
	"ATTRIBUTE1" VARCHAR2(150), 
	"ATTRIBUTE2" VARCHAR2(150), 
	"ATTRIBUTE3" VARCHAR2(150), 
	"ATTRIBUTE4" VARCHAR2(150), 
	"ATTRIBUTE5" VARCHAR2(150), 
	"ATTRIBUTE6" VARCHAR2(150), 
	"ATTRIBUTE7" VARCHAR2(150), 
	"ATTRIBUTE8" VARCHAR2(150), 
	"ATTRIBUTE9" VARCHAR2(150), 
	"ATTRIBUTE10" VARCHAR2(150), 
	"ATTRIBUTE11" VARCHAR2(150), 
	"ATTRIBUTE12" VARCHAR2(150), 
	"ATTRIBUTE13" VARCHAR2(150), 
	"ATTRIBUTE14" VARCHAR2(150), 
	"ATTRIBUTE15" VARCHAR2(150), 
	"ATTRIBUTE16" VARCHAR2(150), 
	"ATTRIBUTE17" VARCHAR2(150), 
	"ATTRIBUTE18" VARCHAR2(150), 
	"ATTRIBUTE19" VARCHAR2(150), 
	"ATTRIBUTE20" VARCHAR2(150), 
	"FUSION_PARTY_ID" NUMBER, 
	"FUSION_PARTY_NUMBER" VARCHAR2(30), 
	"RESULTS_UPDATED_DATE" DATE, 
	"TFM_STATUS" VARCHAR2(30) DEFAULT ''STAGED'' NOT NULL ENABLE, 
	"ERROR_TEXT" CLOB, 
	"LAST_UPDATED_DATE" DATE, 
	"RUN_ID" NUMBER, 
	"RECON_KEY" VARCHAR2(1000), 
	 CONSTRAINT "DMT_HZ_PARTIES_TFM_PK" PRIMARY KEY ("TFM_SEQUENCE_ID")
  USING INDEX  ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_HZ_PARTIES_TFM_TBL_N1" ON "DMT_HZ_PARTIES_TFM_TBL" ("STG_SEQUENCE_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_HZ_PARTIES_TFM_TBL_N4" ON "DMT_HZ_PARTIES_TFM_TBL" ("FBDI_CSV_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_HZ_PARTIES_TFM_TBL"."TFM_SEQUENCE_ID" IS 'PK - from DMT_HZ_PARTIES_TFM_SEQ';
COMMENT ON COLUMN "DMT_HZ_PARTIES_TFM_TBL"."STG_SEQUENCE_ID" IS 'FK to DMT_HZ_PARTIES_STG_TBL â€” which staging row this was transformed from';
COMMENT ON COLUMN "DMT_HZ_PARTIES_TFM_TBL"."FBDI_CSV_ID" IS 'FK to DMT_FBDI_CSV_TBL â€” populated when FBDI generator runs';
COMMENT ON COLUMN "DMT_HZ_PARTIES_TFM_TBL"."PARTY_ORIG_SYSTEM_REFERENCE" IS 'Party reference with run prefix applied: NVL(prefix,'''') || stg.PARTY_ORIG_SYSTEM_REFERENCE';
COMMENT ON COLUMN "DMT_HZ_PARTIES_TFM_TBL"."FUSION_PARTY_ID" IS 'Fusion internal PARTY_ID â€” populated by BIP reconciliation';
COMMENT ON COLUMN "DMT_HZ_PARTIES_TFM_TBL"."FUSION_PARTY_NUMBER" IS 'Fusion-assigned party number â€” populated by BIP reconciliation';
COMMENT ON COLUMN "DMT_HZ_PARTIES_TFM_TBL"."ERROR_TEXT" IS 'Concatenated errors. Appended at each step â€” never overwritten. Prefixes: [TRANSFORM_ERROR] [POST_VALIDATION] [FUSION_ERROR]';
COMMENT ON TABLE "DMT_HZ_PARTIES_TFM_TBL"  IS 'Customer party transformed. Run-specific â€” one row per staging row per run attempt. PARTY_ORIG_SYSTEM_REFERENCE has run prefix applied. Reconciliation populated by BIP.';

-- ---------------------------------------------------------------------------
-- 2026-07-08 conformance tranche (design section 7: STG/TFM infra-column
-- dictionary + contract-index dictionary): converges a pre-existing database.
-- Fresh installs already get the final shape from the CREATE above.
-- ---------------------------------------------------------------------------
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_HZ_PARTIES_TFM_TBL' and column_name = 'STATUS';
  if l_n = 1 then
    execute immediate 'ALTER TABLE "DMT_HZ_PARTIES_TFM_TBL" RENAME COLUMN "STATUS" TO "TFM_STATUS"';
  end if;
end;
/
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_HZ_PARTIES_TFM_TBL' and column_name = 'RECON_KEY';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_HZ_PARTIES_TFM_TBL" ADD ("RECON_KEY" VARCHAR2(1000))';
  end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_HZ_PARTIES_TFM_N1" ON "DMT_HZ_PARTIES_TFM_TBL" ("RUN_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_HZ_PARTIES_TFM_N2" ON "DMT_HZ_PARTIES_TFM_TBL" ("RUN_ID", "TFM_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_HZ_PARTIES_TFM_N3" ON "DMT_HZ_PARTIES_TFM_TBL" ("RECON_KEY")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_HZ_PARTIES_TFM_TBL"."TFM_STATUS" IS 'Transform lifecycle: STAGED > GENERATED > LOADED / FAILED.';
COMMENT ON COLUMN "DMT_HZ_PARTIES_TFM_TBL"."RECON_KEY" IS 'Pre-concatenated business key (run prefix included) that BIP reconciliation matches against Fusion rows.';
