-- DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL" 
   (	"TFM_SEQUENCE_ID" NUMBER DEFAULT DMT_GMS_AWD_PFSRC_TFM_SEQ.NEXTVAL NOT NULL ENABLE, 
	"STG_SEQUENCE_ID" NUMBER NOT NULL ENABLE, 
	"FBDI_CSV_ID" NUMBER, 
	"AWARD_NUMBER" VARCHAR2(300), 
	"PROJECT_NUMBER" VARCHAR2(25), 
	"FUNDING_SOURCE_NAME" VARCHAR2(360), 
	"FUNDING_SOURCE_NUMBER" VARCHAR2(240), 
	"ENABLE_BURDENING_FLAG" VARCHAR2(1), 
	"TFM_STATUS" VARCHAR2(30) DEFAULT ''STAGED'' NOT NULL ENABLE, 
	"ERROR_TEXT" CLOB, 
	"LAST_UPDATED_DATE" DATE, 
	"RESULTS_UPDATED_DATE" DATE, 
	"RUN_ID" NUMBER, 
	"RECON_KEY" VARCHAR2(1000), 
	"FUSION_AWARD_ID" NUMBER, 
	"FUSION_PRJ_FUND_SOURCE_ID" NUMBER, 
	"WORK_QUEUE_ID" NUMBER, 
	 CONSTRAINT "DMT_GMS_AWD_PFSRC_TFM_PK" PRIMARY KEY ("TFM_SEQUENCE_ID")
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
  where  table_name = 'DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL' and column_name = 'STATUS';
  if l_n = 1 then
    execute immediate 'ALTER TABLE "DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL" RENAME COLUMN "STATUS" TO "TFM_STATUS"';
  end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_GMS_AWD_PFSRC_TFM_AWD_IX" ON "DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL" ("AWARD_NUMBER")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_GMS_AWD_PFSRC_TFM_STG_IX" ON "DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL" ("STG_SEQUENCE_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON TABLE "DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL"  IS 'Grant award project funding sources transformed.';

-- ---------------------------------------------------------------------------
-- 2026-07-08 conformance tranche (design section 7: STG/TFM infra-column
-- dictionary + contract-index dictionary): converges a pre-existing database.
-- Fresh installs already get the final shape from the CREATE above.
-- ---------------------------------------------------------------------------
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL' and column_name = 'RECON_KEY';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL" ADD ("RECON_KEY" VARCHAR2(1000))';
  end if;
end;
/
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL' and column_name = 'FUSION_AWARD_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL" ADD ("FUSION_AWARD_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_GMS_AWD_PRJ_FUND_SRC_TFM_N1" ON "DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL" ("RUN_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_GMS_AWD_PRJ_FUND_SRC_TFM_N2" ON "DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL" ("RUN_ID", "TFM_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_GMS_AWD_PRJ_FUND_SRC_TFM_N3" ON "DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL" ("FBDI_CSV_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_GMS_AWD_PRJ_FUND_SRC_TFM_N4" ON "DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL" ("RECON_KEY")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL"."TFM_STATUS" IS 'Transform lifecycle: STAGED > GENERATED > LOADED / FAILED.';
COMMENT ON COLUMN "DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL"."RECON_KEY" IS 'Pre-concatenated business key (run prefix included) that BIP reconciliation matches against Fusion rows.';
COMMENT ON COLUMN "DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL"."FUSION_AWARD_ID" IS 'Fusion-assigned identifier captured from the Fusion base tables - written only by BIP reconciliation (positive proof of load).';

-- WORK_QUEUE_ID (work-queue-ID granularity foundation, accepted 2026-07-20;
-- docs/FIX_PLAN.md item 1). Guarded in-file ALTER so an existing DB converges
-- via db/install.sql (the CREATE above carries it for fresh installs). FK is
-- in db/tables/_foreign_keys.sql. NULLABLE for now; NOT NULL deferred.
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where table_name = 'DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
COMMENT ON COLUMN "DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL"."WORK_QUEUE_ID" IS 'The work queue item (DMT_WORK_QUEUE_TBL.QUEUE_ID) that processed this record. FK in _foreign_keys.sql. Stamped at generation; unit of per-work-item processing (design section 7, accepted 2026-07-20).';

-- FUSION_PRJ_FUND_SOURCE_ID (backlog #789, 2026-10-20): this project funding source row's own Fusion id,
-- GMS_AWD_PRJ_FND_SOURCES.AWD_PRJ_FUND_SOURCE_ID, stamped by reconciliation (DMT_GRANTS_RESULTS_PKG) when the
-- Grants recon report V5 finds the row in Fusion (owner rule 2026-10-19: LOADED only with the row's
-- own row-grain Fusion id). Guarded in-file ALTER so an existing DB converges via
-- db/install.sql (the CREATE above carries it for fresh installs).
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where table_name = 'DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL' and column_name = 'FUSION_PRJ_FUND_SOURCE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL" ADD ("FUSION_PRJ_FUND_SOURCE_ID" NUMBER)';
  end if;
end;
/
COMMENT ON COLUMN "DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL"."FUSION_PRJ_FUND_SOURCE_ID" IS 'Fusion GMS_AWD_PRJ_FND_SOURCES.AWD_PRJ_FUND_SOURCE_ID of this project funding source row - written only by BIP reconciliation (row-grain positive proof of load, backlog #789).';
