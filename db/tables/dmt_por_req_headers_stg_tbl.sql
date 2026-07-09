-- DMT_POR_REQ_HEADERS_STG_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_POR_REQ_HEADERS_STG_TBL" 
   (	"STG_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_POR_REQ_HEADERS_STG_SEQ.NEXTVAL NOT NULL ENABLE, 
	"INTERFACE_HEADER_KEY" VARCHAR2(50), 
	"INTERFACE_SOURCE_CODE" VARCHAR2(25), 
	"REQ_BU_NAME" VARCHAR2(240), 
	"BATCH_ID" VARCHAR2(50), 
	"INTERFACE_SOURCE_LINE_ID" VARCHAR2(50), 
	"DOCUMENT_STATUS" VARCHAR2(25), 
	"APPROVER_EMAIL_ADDR" VARCHAR2(240), 
	"PREPARER_EMAIL_ADDR" VARCHAR2(240), 
	"PRC_BU_NAME" VARCHAR2(240), 
	"REQUISITION_NUMBER" VARCHAR2(64), 
	"DESCRIPTION" VARCHAR2(240), 
	"EMERGENCY_PO_NUMBER" VARCHAR2(20), 
	"DEFAULT_TAXATION_COUNTRY" VARCHAR2(80), 
	"DEFAULT_TAXATION_TERRITORY" VARCHAR2(80), 
	"DOCUMENT_SUB_TYPE" VARCHAR2(240), 
	"DOCUMENT_SUB_TYPE_NAME" VARCHAR2(240), 
	"JUSTIFICATION" VARCHAR2(1000), 
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
	"ATTRIBUTE_DATE1" VARCHAR2(240), 
	"ATTRIBUTE_DATE2" VARCHAR2(240), 
	"ATTRIBUTE_DATE3" VARCHAR2(240), 
	"ATTRIBUTE_DATE4" VARCHAR2(240), 
	"ATTRIBUTE_DATE5" VARCHAR2(240), 
	"ATTRIBUTE_DATE6" VARCHAR2(240), 
	"ATTRIBUTE_DATE7" VARCHAR2(240), 
	"ATTRIBUTE_DATE8" VARCHAR2(240), 
	"ATTRIBUTE_DATE9" VARCHAR2(240), 
	"ATTRIBUTE_DATE10" VARCHAR2(240), 
	"ATTRIBUTE_TIMESTAMP1" VARCHAR2(240), 
	"ATTRIBUTE_TIMESTAMP2" VARCHAR2(240), 
	"ATTRIBUTE_TIMESTAMP3" VARCHAR2(240), 
	"ATTRIBUTE_TIMESTAMP4" VARCHAR2(240), 
	"ATTRIBUTE_TIMESTAMP5" VARCHAR2(240), 
	"ATTRIBUTE_TIMESTAMP6" VARCHAR2(240), 
	"ATTRIBUTE_TIMESTAMP7" VARCHAR2(240), 
	"ATTRIBUTE_TIMESTAMP8" VARCHAR2(240), 
	"ATTRIBUTE_TIMESTAMP9" VARCHAR2(240), 
	"ATTRIBUTE_TIMESTAMP10" VARCHAR2(240), 
	"ATTRIBUTE_NUMBER1" NUMBER, 
	"ATTRIBUTE_NUMBER2" NUMBER, 
	"ATTRIBUTE_NUMBER3" NUMBER, 
	"ATTRIBUTE_NUMBER4" NUMBER, 
	"ATTRIBUTE_NUMBER5" NUMBER, 
	"ATTRIBUTE_NUMBER6" NUMBER, 
	"ATTRIBUTE_NUMBER7" NUMBER, 
	"ATTRIBUTE_NUMBER8" NUMBER, 
	"ATTRIBUTE_NUMBER9" NUMBER, 
	"ATTRIBUTE_NUMBER10" NUMBER, 
	"ATTRIBUTE_CATEGORY" VARCHAR2(30), 
	"SOLDTO_LE_NAME" VARCHAR2(240), 
	"SOURCE_ID" VARCHAR2(200), 
	"STAGE_DATE" DATE DEFAULT SYSDATE, 
	"STG_STATUS" VARCHAR2(30) DEFAULT ''NEW'' NOT NULL ENABLE, 
	"ERROR_TEXT" CLOB, 
	"LAST_UPDATED_DATE" DATE, 
	"SCENARIO_ID" NUMBER, 
	 CONSTRAINT "DMT_POR_REQ_HDR_STG_PK" PRIMARY KEY ("STG_SEQUENCE_ID")
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
  where  table_name = 'DMT_POR_REQ_HEADERS_STG_TBL' and column_name = 'STATUS';
  if l_n = 1 then
    execute immediate 'ALTER TABLE "DMT_POR_REQ_HEADERS_STG_TBL" RENAME COLUMN "STATUS" TO "STG_STATUS"';
  end if;
end;
/

COMMENT ON TABLE "DMT_POR_REQ_HEADERS_STG_TBL"  IS 'Requisition header staging. Raw user-loaded data. Run-specific data in DMT_POR_REQ_HEADERS_TFM_TBL.';

-- ---------------------------------------------------------------------------
-- 2026-07-08 conformance tranche (design section 7: STG/TFM infra-column
-- dictionary + contract-index dictionary): converges a pre-existing database.
-- Fresh installs already get the final shape from the CREATE above.
-- ---------------------------------------------------------------------------
begin
  execute immediate 'CREATE INDEX "DMT_POR_REQ_HEADERS_STG_N1" ON "DMT_POR_REQ_HEADERS_STG_TBL" ("STG_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_POR_REQ_HEADERS_STG_N2" ON "DMT_POR_REQ_HEADERS_STG_TBL" ("SCENARIO_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_POR_REQ_HEADERS_STG_TBL"."STG_STATUS" IS 'Staging lifecycle: NEW > TRANSFORMED / FAILED. Forward-only, never reset; errors accumulate in ERROR_TEXT.';

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
   where table_name = 'DMT_POR_REQ_HEADERS_STG_TBL' and column_name = 'STG_STATUS';
  if l_nullable = 'Y' then
    execute immediate 'UPDATE "DMT_POR_REQ_HEADERS_STG_TBL" SET "STG_STATUS" = ''NEW'' WHERE "STG_STATUS" IS NULL';
    execute immediate 'ALTER TABLE "DMT_POR_REQ_HEADERS_STG_TBL" MODIFY ("STG_STATUS" DEFAULT ''NEW'' NOT NULL)';
  end if;
end;
/
