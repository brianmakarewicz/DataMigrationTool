-- DMT_RUN_COMPARISON_TBL -- cached post-run comparison grid, one row per
-- (RUN_ID, OBJECT_TYPE). Populated by DMT_RUN_COMPARE_PKG.SAVE_RUN_COMPARISON,
-- which makes the ~23 live Fusion BIP calls ONCE and stores the result, so the
-- APEX comparison page (app 501 page 85) renders instantly from stored rows
-- instead of calling Fusion on every load. A "Refresh from Fusion" button on
-- that page re-computes on demand. Columns mirror DMT_CMP_ROW_OBJ plus RUN_ID
-- and COMPUTED_DATE. Idempotent create (-955 = already exists).
begin
  execute immediate 'CREATE TABLE "DMT_RUN_COMPARISON_TBL"
   ( "RUN_ID"                 NUMBER          NOT NULL,
     "OBJECT_TYPE"            VARCHAR2(100)   NOT NULL,
     "CEMLI_CODE"             VARCHAR2(60),
     "KEY_TYPE"               VARCHAR2(20),
     "STG_COUNT"              NUMBER,
     "STG_AMOUNT"             NUMBER,
     "TFM_ERROR_COUNT"        NUMBER,
     "TFM_ERROR_AMOUNT"       NUMBER,
     "FUSION_SUCCESS_COUNT"   NUMBER,
     "FUSION_SUCCESS_AMOUNT"  NUMBER,
     "AMOUNT_CURRENCY"        VARCHAR2(15),
     "FUSION_MONEY_AVAILABLE" VARCHAR2(1),
     "VARIANCE_COUNT"         NUMBER,
     "VARIANCE_AMOUNT"        NUMBER,
     "IN_BALANCE"             VARCHAR2(1),
     "NOTE"                   VARCHAR2(400),
     "COMPUTED_DATE"          TIMESTAMP,
     "STG_KEY_CHECKSUM"       VARCHAR2(80),
     "FUSION_KEY_CHECKSUM"    VARCHAR2(80),
     "KEY_MATCH"              VARCHAR2(1),
     CONSTRAINT "DMT_RUN_COMPARISON_PK" PRIMARY KEY ("RUN_ID","OBJECT_TYPE")
   )';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

-- Business-key checksum columns (backlog #94). Guarded ADDs converge an
-- existing table that pre-dates these columns; on a fresh install they are
-- already in the CREATE above and these are no-ops. Mirrors the three new
-- DMT_CMP_ROW_OBJ attributes STG_KEY_CHECKSUM / FUSION_KEY_CHECKSUM / KEY_MATCH
-- that SAVE_RUN_COMPARISON stores. Idempotent (re-runnable; skips existing).
declare
  procedure add_col(p_col varchar2, p_def varchar2) is
    n number;
  begin
    select count(*) into n from user_tab_columns
     where table_name = 'DMT_RUN_COMPARISON_TBL' and column_name = p_col;
    if n = 0 then
      execute immediate 'ALTER TABLE "DMT_RUN_COMPARISON_TBL" ADD ("'||p_col||'" '||p_def||')';
    end if;
  end;
begin
  add_col('STG_KEY_CHECKSUM',    'VARCHAR2(80)');
  add_col('FUSION_KEY_CHECKSUM', 'VARCHAR2(80)');
  add_col('KEY_MATCH',           'VARCHAR2(1)');
end;
/
