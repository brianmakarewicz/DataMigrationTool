-- DMT_HZ_ACCT_SITE_USES_STG_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_HZ_ACCT_SITE_USES_STG_TBL" 
   (	"STG_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_HZ_ACCT_SITE_USES_STG_SEQ.NEXTVAL NOT NULL ENABLE, 
	"BATCH_ID" NUMBER, 
	"CUST_SITE_ORIG_SYSTEM" VARCHAR2(30), 
	"CUST_SITE_ORIG_SYS_REF" VARCHAR2(240), 
	"CUST_SITEUSE_ORIG_SYSTEM" VARCHAR2(30), 
	"CUST_SITEUSE_ORIG_SYS_REF" VARCHAR2(240), 
	"SITE_USE_CODE" VARCHAR2(30), 
	"PRIMARY_FLAG" VARCHAR2(1), 
	"INSERT_UPDATE_FLAG" VARCHAR2(1), 
	"LOCATION" VARCHAR2(240), 
	"SET_CODE" VARCHAR2(30), 
	"START_DATE" DATE, 
	"END_DATE" DATE, 
	"ACCOUNT_NUMBER" VARCHAR2(30), 
	"PARTY_SITE_NUMBER" VARCHAR2(30), 
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
	"STAGE_DATE" DATE DEFAULT SYSDATE, 
	"STG_STATUS" VARCHAR2(30) DEFAULT ''NEW'', 
	"ERROR_TEXT" CLOB, 
	"SOURCE_ID" VARCHAR2(240), 
	"LAST_UPDATED_DATE" DATE, 
	"SCENARIO_ID" NUMBER, 
	 CONSTRAINT "DMT_HZ_ACCT_SITE_USES_STG_PK" PRIMARY KEY ("STG_SEQUENCE_ID")
  USING INDEX  ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_HZ_ACCT_SITE_USES_STG_TBL_N1" ON "DMT_HZ_ACCT_SITE_USES_STG_TBL" ("STG_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_HZ_ACCT_SITE_USES_STG_TBL"."STG_SEQUENCE_ID" IS 'PK - from DMT_HZ_ACCT_SITE_USES_STG_SEQ';
COMMENT ON COLUMN "DMT_HZ_ACCT_SITE_USES_STG_TBL"."CUST_SITE_ORIG_SYS_REF" IS 'Account site reference â€” links this use back to the parent account site in HZ_IMP_ACCTSITES_T';
COMMENT ON COLUMN "DMT_HZ_ACCT_SITE_USES_STG_TBL"."SITE_USE_CODE" IS 'Site use purpose code â€” e.g. BILL_TO, SHIP_TO';
COMMENT ON COLUMN "DMT_HZ_ACCT_SITE_USES_STG_TBL"."ERROR_TEXT" IS 'Concatenated errors â€” appended at each step, never overwritten. Prefixed: [PRE_VALIDATION] [TRANSFORM_ERROR] [FUSION_ERROR].';
COMMENT ON TABLE "DMT_HZ_ACCT_SITE_USES_STG_TBL"  IS 'Customer account site use staging. Raw user data only. Run-specific data in TFM table. FBDI interface: HZ_IMP_ACCTSITEUSES_T. CSV: HzImpAcctSiteUsesT.csv.';

-- ---------------------------------------------------------------------------
-- 2026-07-08 conformance tranche (design section 7: STG/TFM infra-column
-- dictionary + contract-index dictionary): converges a pre-existing database.
-- Fresh installs already get the final shape from the CREATE above.
-- ---------------------------------------------------------------------------
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_HZ_ACCT_SITE_USES_STG_TBL' and column_name = 'STATUS';
  if l_n = 1 then
    execute immediate 'ALTER TABLE "DMT_HZ_ACCT_SITE_USES_STG_TBL" RENAME COLUMN "STATUS" TO "STG_STATUS"';
  end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_HZ_ACCT_SITE_USES_STG_N1" ON "DMT_HZ_ACCT_SITE_USES_STG_TBL" ("SCENARIO_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_HZ_ACCT_SITE_USES_STG_TBL"."STG_STATUS" IS 'Staging lifecycle: NEW > TRANSFORMED / FAILED. Forward-only, never reset; errors accumulate in ERROR_TEXT.';
