-- DMT_RA_DISTS_TFM_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_RA_DISTS_TFM_TBL" 
   (	"TFM_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_RA_DISTS_TFM_SEQ.NEXTVAL NOT NULL ENABLE, 
	"STG_SEQUENCE_ID" NUMBER NOT NULL ENABLE, 
	"FBDI_CSV_ID" NUMBER, 
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
	"RESULTS_UPDATED_DATE" DATE, 
	"TFM_STATUS" VARCHAR2(30) DEFAULT ''STAGED'' NOT NULL ENABLE, 
	"ERROR_TEXT" CLOB, 
	"LAST_UPDATED_DATE" DATE, 
	"RUN_ID" NUMBER, 
	"RECON_KEY" VARCHAR2(1000), 
	"FUSION_CUST_TRX_LINE_GL_DIST_ID" NUMBER, 
	 CONSTRAINT "DMT_RA_DISTS_TFM_PK" PRIMARY KEY ("TFM_SEQUENCE_ID")
  USING INDEX  ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_RA_DISTS_TFM_TBL_N1" ON "DMT_RA_DISTS_TFM_TBL" ("STG_SEQUENCE_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_RA_DISTS_TFM_TBL_N4" ON "DMT_RA_DISTS_TFM_TBL" ("FBDI_CSV_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_RA_DISTS_TFM_TBL"."TFM_SEQUENCE_ID" IS 'PK - from DMT_RA_DISTS_TFM_SEQ';
COMMENT ON COLUMN "DMT_RA_DISTS_TFM_TBL"."STG_SEQUENCE_ID" IS 'FK to DMT_RA_DISTS_STG_TBL â€” which staging row this was transformed from';
COMMENT ON COLUMN "DMT_RA_DISTS_TFM_TBL"."FBDI_CSV_ID" IS 'FK to DMT_FBDI_CSV_TBL â€” populated when FBDI generator runs';
COMMENT ON COLUMN "DMT_RA_DISTS_TFM_TBL"."INTERFACE_LINE_CONTEXT" IS 'Flexfield context â€” links this distribution to its parent line via INTERFACE_LINE_ATTRIBUTE1-15';
COMMENT ON COLUMN "DMT_RA_DISTS_TFM_TBL"."ERROR_TEXT" IS 'Concatenated errors. Appended at each step â€” never overwritten. Prefixes: [TRANSFORM_ERROR] [POST_VALIDATION] [FUSION_ERROR]';
COMMENT ON TABLE "DMT_RA_DISTS_TFM_TBL"  IS 'AR Invoice distributions transformed. Run-specific â€” one row per staging row per run attempt. Account segments derived as needed. Reconciliation populated by BIP.';

-- ---------------------------------------------------------------------------
-- 2026-07-08 conformance tranche (design section 7: STG/TFM infra-column
-- dictionary + contract-index dictionary): converges a pre-existing database.
-- Fresh installs already get the final shape from the CREATE above.
-- ---------------------------------------------------------------------------
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_RA_DISTS_TFM_TBL' and column_name = 'STATUS';
  if l_n = 1 then
    execute immediate 'ALTER TABLE "DMT_RA_DISTS_TFM_TBL" RENAME COLUMN "STATUS" TO "TFM_STATUS"';
  end if;
end;
/
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_RA_DISTS_TFM_TBL' and column_name = 'RECON_KEY';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_RA_DISTS_TFM_TBL" ADD ("RECON_KEY" VARCHAR2(1000))';
  end if;
end;
/
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_RA_DISTS_TFM_TBL' and column_name = 'FUSION_CUST_TRX_LINE_GL_DIST_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_RA_DISTS_TFM_TBL" ADD ("FUSION_CUST_TRX_LINE_GL_DIST_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_RA_DISTS_TFM_N1" ON "DMT_RA_DISTS_TFM_TBL" ("RUN_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_RA_DISTS_TFM_N2" ON "DMT_RA_DISTS_TFM_TBL" ("RUN_ID", "TFM_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_RA_DISTS_TFM_N3" ON "DMT_RA_DISTS_TFM_TBL" ("RECON_KEY")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_RA_DISTS_TFM_TBL"."TFM_STATUS" IS 'Transform lifecycle: STAGED > GENERATED > LOADED / FAILED.';
COMMENT ON COLUMN "DMT_RA_DISTS_TFM_TBL"."RECON_KEY" IS 'Pre-concatenated business key (run prefix included) that BIP reconciliation matches against Fusion rows.';
COMMENT ON COLUMN "DMT_RA_DISTS_TFM_TBL"."FUSION_CUST_TRX_LINE_GL_DIST_ID" IS 'Fusion-assigned identifier captured from the Fusion base tables - written only by BIP reconciliation (positive proof of load).';
