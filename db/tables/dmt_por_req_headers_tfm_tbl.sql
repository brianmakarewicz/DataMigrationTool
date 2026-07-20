-- DMT_POR_REQ_HEADERS_TFM_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_POR_REQ_HEADERS_TFM_TBL" 
   (	"TFM_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_POR_REQ_HEADERS_TFM_SEQ.NEXTVAL NOT NULL ENABLE, 
	"STG_SEQUENCE_ID" NUMBER NOT NULL ENABLE, 
	"FBDI_CSV_ID" NUMBER, 
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
	"TFM_STATUS" VARCHAR2(30) DEFAULT ''STAGED'' NOT NULL ENABLE, 
	"ERROR_TEXT" CLOB, 
	"RESULTS_UPDATED_DATE" DATE, 
	"LAST_UPDATED_DATE" DATE, 
	"RUN_ID" NUMBER, 
	"RECON_KEY" VARCHAR2(1000), 
	"FUSION_REQUISITION_HEADER_ID" NUMBER, 
	"WORK_QUEUE_ID" NUMBER, 
	 CONSTRAINT "DMT_POR_REQ_HDR_TFM_PK" PRIMARY KEY ("TFM_SEQUENCE_ID")
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
  where  table_name = 'DMT_POR_REQ_HEADERS_TFM_TBL' and column_name = 'STATUS';
  if l_n = 1 then
    execute immediate 'ALTER TABLE "DMT_POR_REQ_HEADERS_TFM_TBL" RENAME COLUMN "STATUS" TO "TFM_STATUS"';
  end if;
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
  where  table_name = 'DMT_POR_REQ_HEADERS_TFM_TBL' and column_name = 'RECON_KEY';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_POR_REQ_HEADERS_TFM_TBL" ADD ("RECON_KEY" VARCHAR2(1000))';
  end if;
end;
/
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_POR_REQ_HEADERS_TFM_TBL' and column_name = 'FUSION_REQUISITION_HEADER_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_POR_REQ_HEADERS_TFM_TBL" ADD ("FUSION_REQUISITION_HEADER_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_POR_REQ_HEADERS_TFM_N1" ON "DMT_POR_REQ_HEADERS_TFM_TBL" ("RUN_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_POR_REQ_HEADERS_TFM_N2" ON "DMT_POR_REQ_HEADERS_TFM_TBL" ("RUN_ID", "TFM_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_POR_REQ_HEADERS_TFM_N3" ON "DMT_POR_REQ_HEADERS_TFM_TBL" ("FBDI_CSV_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_POR_REQ_HEADERS_TFM_N4" ON "DMT_POR_REQ_HEADERS_TFM_TBL" ("STG_SEQUENCE_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_POR_REQ_HEADERS_TFM_N5" ON "DMT_POR_REQ_HEADERS_TFM_TBL" ("RECON_KEY")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_POR_REQ_HEADERS_TFM_TBL"."TFM_STATUS" IS 'Transform lifecycle: STAGED > GENERATED > LOADED / FAILED.';
COMMENT ON COLUMN "DMT_POR_REQ_HEADERS_TFM_TBL"."RECON_KEY" IS 'Pre-concatenated business key (run prefix included) that BIP reconciliation matches against Fusion rows.';
COMMENT ON COLUMN "DMT_POR_REQ_HEADERS_TFM_TBL"."FUSION_REQUISITION_HEADER_ID" IS 'Fusion-assigned identifier captured from the Fusion base tables - written only by BIP reconciliation (positive proof of load).';

-- WORK_QUEUE_ID (work-queue-ID granularity foundation, accepted 2026-07-20;
-- docs/FIX_PLAN.md item 1). Guarded in-file ALTER so an existing DB converges
-- via db/install.sql (the CREATE above carries it for fresh installs). FK is
-- in db/tables/_foreign_keys.sql. NULLABLE for now; NOT NULL deferred.
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where table_name = 'DMT_POR_REQ_HEADERS_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_POR_REQ_HEADERS_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
COMMENT ON COLUMN "DMT_POR_REQ_HEADERS_TFM_TBL"."WORK_QUEUE_ID" IS 'The work queue item (DMT_WORK_QUEUE_TBL.QUEUE_ID) that processed this record. FK in _foreign_keys.sql. Stamped at generation; unit of per-work-item processing (design section 7, accepted 2026-07-20).';
