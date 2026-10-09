-- DMT_FA_ASSET_BOOK_TFM_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_FA_ASSET_BOOK_TFM_TBL" 
   (	"TFM_SEQUENCE_ID" NUMBER DEFAULT DMT_FA_ASSET_BOOK_TFM_SEQ.NEXTVAL NOT NULL ENABLE, 
	"STG_SEQUENCE_ID" NUMBER NOT NULL ENABLE, 
	"FBDI_CSV_ID" NUMBER, 
	"ASSET_NUMBER" VARCHAR2(30), 
	"BOOK_TYPE_CODE" VARCHAR2(30), 
	"COST" NUMBER, 
	"ORIGINAL_COST" NUMBER, 
	"SALVAGE_VALUE" NUMBER, 
	"LIFE_IN_MONTHS" NUMBER, 
	"DEPRECIATION_METHOD" VARCHAR2(12), 
	"DATE_PLACED_IN_SERVICE" DATE, 
	"PRORATE_CONVENTION_CODE" VARCHAR2(10), 
	"DEPRN_START_DATE" DATE, 
	"CURRENT_UNITS" NUMBER, 
	"UNREVALUED_COST" NUMBER, 
	"YTD_DEPRN" NUMBER, 
	"DEPRN_RESERVE" NUMBER, 
	"BONUS_YTD_DEPRN" NUMBER, 
	"BONUS_DEPRN_RESERVE" NUMBER, 
	"TFM_STATUS" VARCHAR2(30) DEFAULT ''STAGED'' NOT NULL ENABLE, 
	"ERROR_TEXT" CLOB, 
	"RESULTS_UPDATED_DATE" DATE, 
	"LAST_UPDATED_DATE" DATE, 
	"RUN_ID" NUMBER, 
	"RECON_KEY" VARCHAR2(1000),
	"FUSION_ASSET_ID" VARCHAR2(100),
	"WORK_QUEUE_ID" NUMBER,
	 CONSTRAINT "DMT_FA_ASSET_BOOK_TFM_PK" PRIMARY KEY ("TFM_SEQUENCE_ID")
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
  where  table_name = 'DMT_FA_ASSET_BOOK_TFM_TBL' and column_name = 'STATUS';
  if l_n = 1 then
    execute immediate 'ALTER TABLE "DMT_FA_ASSET_BOOK_TFM_TBL" RENAME COLUMN "STATUS" TO "TFM_STATUS"';
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
  where  table_name = 'DMT_FA_ASSET_BOOK_TFM_TBL' and column_name = 'RECON_KEY';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_FA_ASSET_BOOK_TFM_TBL" ADD ("RECON_KEY" VARCHAR2(1000))';
  end if;
end;
/
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_FA_ASSET_BOOK_TFM_TBL' and column_name = 'FUSION_ASSET_ID';
  if l_n = 0 then
    -- VARCHAR2(100): the book row stores the per-book composite ASSET_ID~BOOK_TYPE_CODE
    -- (backlog #139) so the Fusion-id auditor's UNIQUE check holds at book grain. A
    -- pre-existing DB whose column is still NUMBER is converted by the
    -- db/migrations/2026-10-01_assets_book_composite_id.sql backfill-and-rename.
    execute immediate 'ALTER TABLE "DMT_FA_ASSET_BOOK_TFM_TBL" ADD ("FUSION_ASSET_ID" VARCHAR2(100))';
  end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_FA_ASSET_BOOK_TFM_N1" ON "DMT_FA_ASSET_BOOK_TFM_TBL" ("RUN_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_FA_ASSET_BOOK_TFM_N2" ON "DMT_FA_ASSET_BOOK_TFM_TBL" ("RUN_ID", "TFM_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_FA_ASSET_BOOK_TFM_N3" ON "DMT_FA_ASSET_BOOK_TFM_TBL" ("FBDI_CSV_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_FA_ASSET_BOOK_TFM_N4" ON "DMT_FA_ASSET_BOOK_TFM_TBL" ("STG_SEQUENCE_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_FA_ASSET_BOOK_TFM_N5" ON "DMT_FA_ASSET_BOOK_TFM_TBL" ("RECON_KEY")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_FA_ASSET_BOOK_TFM_TBL"."TFM_STATUS" IS 'Transform lifecycle: STAGED > GENERATED > LOADED / FAILED.';
COMMENT ON COLUMN "DMT_FA_ASSET_BOOK_TFM_TBL"."RECON_KEY" IS 'Pre-concatenated business key (run prefix included) that BIP reconciliation matches against Fusion rows.';
COMMENT ON COLUMN "DMT_FA_ASSET_BOOK_TFM_TBL"."FUSION_ASSET_ID" IS 'Positive proof of load at the asset-BOOK grain: the composite ASSET_ID~BOOK_TYPE_CODE (FA_ADDITIONS_B.ASSET_ID from the parent header, joined to this book row''s BOOK_TYPE_CODE). A corporate book and a tax book of the same asset therefore carry DIFFERENT values, so the Fusion-id auditor UNIQUE check is valid at book grain (backlog #139; mirrors GLBalances JE_HEADER_ID~JE_LINE_NUM). Written only by the DMT_FA_ASSET_RESULTS_PKG cascade.';

-- ---------------------------------------------------------------------------
-- 2026-07-09 conformance review F2 (STG/TFM infra-column dictionary, design
-- section 7 accepted 2026-07-08): TFM_STATUS is VARCHAR2(30) DEFAULT 'STAGED'
-- NOT NULL. Backfills any NULL statuses to the default, then converges a
-- pre-existing database; fresh installs get the shape from the CREATE above.
-- ---------------------------------------------------------------------------
declare
  l_nullable varchar2(1);
begin
  select nullable into l_nullable from user_tab_columns
   where table_name = 'DMT_FA_ASSET_BOOK_TFM_TBL' and column_name = 'TFM_STATUS';
  if l_nullable = 'Y' then
    execute immediate 'UPDATE "DMT_FA_ASSET_BOOK_TFM_TBL" SET "TFM_STATUS" = ''STAGED'' WHERE "TFM_STATUS" IS NULL';
    execute immediate 'ALTER TABLE "DMT_FA_ASSET_BOOK_TFM_TBL" MODIFY ("TFM_STATUS" DEFAULT ''STAGED'' NOT NULL)';
  end if;
end;
/

-- WORK_QUEUE_ID (work-queue-ID granularity foundation, accepted 2026-07-20;
-- docs/FIX_PLAN.md item 1). Guarded in-file ALTER so an existing DB converges
-- via db/install.sql (the CREATE above carries it for fresh installs). FK is
-- in db/tables/_foreign_keys.sql. NULLABLE for now; NOT NULL deferred.
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where table_name = 'DMT_FA_ASSET_BOOK_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_FA_ASSET_BOOK_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
COMMENT ON COLUMN "DMT_FA_ASSET_BOOK_TFM_TBL"."WORK_QUEUE_ID" IS 'The work queue item (DMT_WORK_QUEUE_TBL.QUEUE_ID) that processed this record. FK in _foreign_keys.sql. Stamped at generation; unit of per-work-item processing (design section 7, accepted 2026-07-20).';

-- ---------------------------------------------------------------------------
-- 2026-10-09 backlog #574 (owner rule: field width is constrained by the STG
-- and TFM tables). These columns now match the Fusion FBDI interface column
-- FA_MASS_ADDITIONS.METHOD_CODE (12) / PRORATE_CONVENTION_CODE (10), so a value too long for Fusion is
-- rejected here, when it is staged, with a clear error naming the column,
-- instead of by SQL*Loader (which rolls back the whole book). Re-runnable and
-- non-destructive: widening is always applied; narrowing is applied only when
-- no existing row is longer than the new width, otherwise the column is left as
-- it is and a line says so. Data is never truncated. Fresh installs get these
-- widths from the CREATE above.
-- ---------------------------------------------------------------------------
declare
  procedure fit_width (p_col in varchar2, p_len in pls_integer) is
    l_cur pls_integer;
    l_max pls_integer;
  begin
    select char_length into l_cur from user_tab_columns
     where table_name = 'DMT_FA_ASSET_BOOK_TFM_TBL' and column_name = p_col;
    if l_cur < p_len then
      execute immediate 'ALTER TABLE "DMT_FA_ASSET_BOOK_TFM_TBL" MODIFY ("' || p_col || '" VARCHAR2(' || p_len || '))';
    elsif l_cur > p_len then
      execute immediate 'SELECT NVL(MAX(LENGTH("' || p_col || '")), 0) FROM "DMT_FA_ASSET_BOOK_TFM_TBL"' into l_max;
      if l_max <= p_len then
        execute immediate 'ALTER TABLE "DMT_FA_ASSET_BOOK_TFM_TBL" MODIFY ("' || p_col || '" VARCHAR2(' || p_len || '))';
      else
        dbms_output.put_line('DMT_FA_ASSET_BOOK_TFM_TBL.' || p_col || ' left at ' || l_cur
          || ': existing rows hold values up to ' || l_max || ' characters (target ' || p_len || ').');
      end if;
    end if;
  end fit_width;
begin
  fit_width('DEPRECIATION_METHOD', 12);
  fit_width('PRORATE_CONVENTION_CODE', 10);
end;
/
