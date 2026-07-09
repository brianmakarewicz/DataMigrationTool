-- DMT_HZ_ACCOUNTS_STG_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_HZ_ACCOUNTS_STG_TBL" 
   (	"STG_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_HZ_ACCOUNTS_STG_SEQ.NEXTVAL NOT NULL ENABLE, 
	"BATCH_ID" NUMBER, 
	"CUST_ORIG_SYSTEM" VARCHAR2(30), 
	"CUST_ORIG_SYSTEM_REFERENCE" VARCHAR2(240), 
	"PARTY_ORIG_SYSTEM" VARCHAR2(30), 
	"PARTY_ORIG_SYSTEM_REFERENCE" VARCHAR2(240), 
	"ACCOUNT_NUMBER" VARCHAR2(30), 
	"INSERT_UPDATE_FLAG" VARCHAR2(1), 
	"CUSTOMER_TYPE" VARCHAR2(30), 
	"CUSTOMER_CLASS_CODE" VARCHAR2(30), 
	"ACCOUNT_NAME" VARCHAR2(360), 
	"ACCOUNT_ESTABLISHED_DATE" DATE, 
	"ACCOUNT_TERMINATION_DATE" DATE, 
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
	"STG_STATUS" VARCHAR2(30) DEFAULT ''NEW'' NOT NULL ENABLE, 
	"ERROR_TEXT" CLOB, 
	"SOURCE_ID" VARCHAR2(240), 
	"LAST_UPDATED_DATE" DATE, 
	"SCENARIO_ID" NUMBER, 
	 CONSTRAINT "DMT_HZ_ACCOUNTS_STG_PK" PRIMARY KEY ("STG_SEQUENCE_ID")
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
  where  table_name = 'DMT_HZ_ACCOUNTS_STG_TBL' and column_name = 'STATUS';
  if l_n = 1 then
    execute immediate 'ALTER TABLE "DMT_HZ_ACCOUNTS_STG_TBL" RENAME COLUMN "STATUS" TO "STG_STATUS"';
  end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_HZ_ACCOUNTS_STG_TBL_N1" ON "DMT_HZ_ACCOUNTS_STG_TBL" ("STG_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_HZ_ACCOUNTS_STG_TBL"."STG_SEQUENCE_ID" IS 'PK - from DMT_HZ_ACCOUNTS_STG_SEQ';
COMMENT ON COLUMN "DMT_HZ_ACCOUNTS_STG_TBL"."CUST_ORIG_SYSTEM_REFERENCE" IS 'Unique customer account reference in the source system â€” primary business key';
COMMENT ON COLUMN "DMT_HZ_ACCOUNTS_STG_TBL"."PARTY_ORIG_SYSTEM_REFERENCE" IS 'Party reference â€” links this account back to the parent party in HZ_IMP_PARTIES_T';
COMMENT ON COLUMN "DMT_HZ_ACCOUNTS_STG_TBL"."ACCOUNT_NUMBER" IS 'Customer account number from source system';
COMMENT ON COLUMN "DMT_HZ_ACCOUNTS_STG_TBL"."ERROR_TEXT" IS 'Concatenated errors â€” appended at each step, never overwritten. Prefixed: [PRE_VALIDATION] [TRANSFORM_ERROR] [FUSION_ERROR].';
COMMENT ON TABLE "DMT_HZ_ACCOUNTS_STG_TBL"  IS 'Customer account staging. Raw user data only. Run-specific data in TFM table. FBDI interface: HZ_IMP_ACCOUNTS_T. CSV: HzImpAccountsT.csv.';

-- ---------------------------------------------------------------------------
-- 2026-07-08 conformance tranche (design section 7: STG/TFM infra-column
-- dictionary + contract-index dictionary): converges a pre-existing database.
-- Fresh installs already get the final shape from the CREATE above.
-- ---------------------------------------------------------------------------
begin
  execute immediate 'CREATE INDEX "DMT_HZ_ACCOUNTS_STG_N1" ON "DMT_HZ_ACCOUNTS_STG_TBL" ("SCENARIO_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_HZ_ACCOUNTS_STG_TBL"."STG_STATUS" IS 'Staging lifecycle: NEW > TRANSFORMED / FAILED. Forward-only, never reset; errors accumulate in ERROR_TEXT.';

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
   where table_name = 'DMT_HZ_ACCOUNTS_STG_TBL' and column_name = 'STG_STATUS';
  if l_nullable = 'Y' then
    execute immediate 'UPDATE "DMT_HZ_ACCOUNTS_STG_TBL" SET "STG_STATUS" = ''NEW'' WHERE "STG_STATUS" IS NULL';
    execute immediate 'ALTER TABLE "DMT_HZ_ACCOUNTS_STG_TBL" MODIFY ("STG_STATUS" DEFAULT ''NEW'' NOT NULL)';
  end if;
end;
/
