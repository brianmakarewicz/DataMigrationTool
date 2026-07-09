-- DMT_RA_DISTS_STG_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_RA_DISTS_STG_TBL" 
   (	"STG_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_RA_DISTS_STG_SEQ.NEXTVAL NOT NULL ENABLE, 
	"ORG_ID" VARCHAR2(240), 
	"ACCOUNT_CLASS" VARCHAR2(20), 
	"AMOUNT" NUMBER, 
	"PERCENT" NUMBER, 
	"ACCTD_AMOUNT" NUMBER, 
	"INTERFACE_LINE_CONTEXT" VARCHAR2(30), 
	"INTERFACE_LINE_ATTRIBUTE1" VARCHAR2(150), 
	"INTERFACE_LINE_ATTRIBUTE2" VARCHAR2(150), 
	"INTERFACE_LINE_ATTRIBUTE3" VARCHAR2(150), 
	"INTERFACE_LINE_ATTRIBUTE4" VARCHAR2(150), 
	"INTERFACE_LINE_ATTRIBUTE5" VARCHAR2(150), 
	"INTERFACE_LINE_ATTRIBUTE6" VARCHAR2(150), 
	"INTERFACE_LINE_ATTRIBUTE7" VARCHAR2(150), 
	"INTERFACE_LINE_ATTRIBUTE8" VARCHAR2(150), 
	"INTERFACE_LINE_ATTRIBUTE9" VARCHAR2(150), 
	"INTERFACE_LINE_ATTRIBUTE10" VARCHAR2(150), 
	"INTERFACE_LINE_ATTRIBUTE11" VARCHAR2(150), 
	"INTERFACE_LINE_ATTRIBUTE12" VARCHAR2(150), 
	"INTERFACE_LINE_ATTRIBUTE13" VARCHAR2(150), 
	"INTERFACE_LINE_ATTRIBUTE14" VARCHAR2(150), 
	"INTERFACE_LINE_ATTRIBUTE15" VARCHAR2(150), 
	"SEGMENT1" VARCHAR2(25), 
	"SEGMENT2" VARCHAR2(25), 
	"SEGMENT3" VARCHAR2(25), 
	"SEGMENT4" VARCHAR2(25), 
	"SEGMENT5" VARCHAR2(25), 
	"SEGMENT6" VARCHAR2(25), 
	"SEGMENT7" VARCHAR2(25), 
	"SEGMENT8" VARCHAR2(25), 
	"SEGMENT9" VARCHAR2(25), 
	"SEGMENT10" VARCHAR2(25), 
	"SEGMENT11" VARCHAR2(25), 
	"SEGMENT12" VARCHAR2(25), 
	"SEGMENT13" VARCHAR2(25), 
	"SEGMENT14" VARCHAR2(25), 
	"SEGMENT15" VARCHAR2(25), 
	"SEGMENT16" VARCHAR2(25), 
	"SEGMENT17" VARCHAR2(25), 
	"SEGMENT18" VARCHAR2(25), 
	"SEGMENT19" VARCHAR2(25), 
	"SEGMENT20" VARCHAR2(25), 
	"SEGMENT21" VARCHAR2(25), 
	"SEGMENT22" VARCHAR2(25), 
	"SEGMENT23" VARCHAR2(25), 
	"SEGMENT24" VARCHAR2(25), 
	"SEGMENT25" VARCHAR2(25), 
	"SEGMENT26" VARCHAR2(25), 
	"SEGMENT27" VARCHAR2(25), 
	"SEGMENT28" VARCHAR2(25), 
	"SEGMENT29" VARCHAR2(25), 
	"SEGMENT30" VARCHAR2(25), 
	"COMMENTS" VARCHAR2(240), 
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
	"BU_NAME" VARCHAR2(240), 
	"STAGE_DATE" DATE DEFAULT SYSDATE, 
	"STG_STATUS" VARCHAR2(30) DEFAULT ''NEW'' NOT NULL ENABLE, 
	"ERROR_TEXT" CLOB, 
	"SOURCE_ID" VARCHAR2(240), 
	"LAST_UPDATED_DATE" DATE, 
	"SCENARIO_ID" NUMBER, 
	 CONSTRAINT "DMT_RA_DISTS_STG_PK" PRIMARY KEY ("STG_SEQUENCE_ID")
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
  where  table_name = 'DMT_RA_DISTS_STG_TBL' and column_name = 'STATUS';
  if l_n = 1 then
    execute immediate 'ALTER TABLE "DMT_RA_DISTS_STG_TBL" RENAME COLUMN "STATUS" TO "STG_STATUS"';
  end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_RA_DISTS_STG_TBL_N1" ON "DMT_RA_DISTS_STG_TBL" ("STG_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_RA_DISTS_STG_TBL"."STG_SEQUENCE_ID" IS 'PK - from DMT_RA_DISTS_STG_SEQ';
COMMENT ON COLUMN "DMT_RA_DISTS_STG_TBL"."INTERFACE_LINE_CONTEXT" IS 'Flexfield context â€” links this distribution to its parent line via INTERFACE_LINE_ATTRIBUTE1-15';
COMMENT ON COLUMN "DMT_RA_DISTS_STG_TBL"."ERROR_TEXT" IS 'Concatenated errors â€” appended at each step, never overwritten. Prefixed: [PRE_VALIDATION] [TRANSFORM_ERROR] [FUSION_ERROR].';
COMMENT ON TABLE "DMT_RA_DISTS_STG_TBL"  IS 'AR Invoice distributions staging. Raw user data only. Run-specific data in DMT_RA_DISTS_TFM_TBL. FBDI interface: RA_INTERFACE_DISTRIBUTIONS_ALL. CSV: RaInterfaceDistributionsAll.csv.';

-- ---------------------------------------------------------------------------
-- 2026-07-08 conformance tranche (design section 7: STG/TFM infra-column
-- dictionary + contract-index dictionary): converges a pre-existing database.
-- Fresh installs already get the final shape from the CREATE above.
-- ---------------------------------------------------------------------------
begin
  execute immediate 'CREATE INDEX "DMT_RA_DISTS_STG_N1" ON "DMT_RA_DISTS_STG_TBL" ("SCENARIO_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_RA_DISTS_STG_TBL"."STG_STATUS" IS 'Staging lifecycle: NEW > TRANSFORMED / FAILED. Forward-only, never reset; errors accumulate in ERROR_TEXT.';

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
   where table_name = 'DMT_RA_DISTS_STG_TBL' and column_name = 'STG_STATUS';
  if l_nullable = 'Y' then
    execute immediate 'UPDATE "DMT_RA_DISTS_STG_TBL" SET "STG_STATUS" = ''NEW'' WHERE "STG_STATUS" IS NULL';
    execute immediate 'ALTER TABLE "DMT_RA_DISTS_STG_TBL" MODIFY ("STG_STATUS" DEFAULT ''NEW'' NOT NULL)';
  end if;
end;
/
