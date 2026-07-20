-- =========================================================================
-- Migration: CHILD_PARTITION_COLUMN on DMT_CEMLI_SPLIT_CFG  (2026-07-20)
-- docs/FIX_PLAN.md item 1 (work-queue-ID core).
--
-- Adds one nullable column that names the SINGLE TFM column an object is
-- split on when it spawns one child work-queue item per distinct partition
-- value (the generalized Assets-per-book mechanism, now also used by Items
-- and Requisitions per BATCH_ID). This is DIFFERENT from PARTITION_COLUMNS,
-- which drives the in-zip FBDI split (POs by BU, GL by ledger) that still
-- loads as a single work-queue item.
--
--   CHILD_PARTITION_COLUMN NULL  -> object loads as one work-queue item.
--   CHILD_PARTITION_COLUMN set   -> parent transforms once, then spawns one
--                                   READY child per distinct value; each child
--                                   generates + loads + reconciles + sweeps only
--                                   its own partition (scoped by WORK_QUEUE_ID).
--
-- ADDITIVE + NULLABLE. Idempotent. Deploy as DMT_OWNER (never ADMIN).
-- Seed values are also carried in db/seed/dmt_cemli_split_cfg.sql for fresh
-- installs; this migration converges an existing database.
-- =========================================================================
set define off
set serveroutput on

prompt == CHILD_PARTITION_COLUMN on DMT_CEMLI_SPLIT_CFG ==
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_CEMLI_SPLIT_CFG' and column_name = 'CHILD_PARTITION_COLUMN';
  if l_n = 0 then
    execute immediate
      'ALTER TABLE "DMT_CEMLI_SPLIT_CFG" ADD ("CHILD_PARTITION_COLUMN" VARCHAR2(30))';
  end if;
end;
/

prompt == Seed / converge the three spawn-per-partition objects ==
-- Assets already had a split row via its per-book handler in code (not a config
-- row); Items and Requisitions had none. All three are seeded here with the
-- single column their children are spawned on.
merge into "DMT_CEMLI_SPLIT_CFG" t
using (
    select 'Assets'       cemli_code, 'DMT_FA_ASSET_BOOK_TFM_TBL'   tfm_table,
           'BOOK_TYPE_CODE' partition_columns, 'BOOK_TYPE_CODE' label_expression,
           'BOOK_TYPE_CODE = :partition_key' where_template, 'TFM_STATUS' status_column,
           'BOOK_TYPE_CODE' child_partition_column from dual
    union all select 'Items', 'DMT_EGP_ITEM_TFM_TBL',
           'BATCH_ID', 'BATCH_ID', 'BATCH_ID = :partition_key', 'TFM_STATUS', 'BATCH_ID' from dual
    union all select 'Requisitions', 'DMT_POR_REQ_HEADERS_TFM_TBL',
           'BATCH_ID', 'BATCH_ID', 'BATCH_ID = :partition_key', 'TFM_STATUS', 'BATCH_ID' from dual
) s
on (t."CEMLI_CODE" = s.cemli_code)
when matched then update set
    t."TFM_TABLE"              = s.tfm_table,
    t."PARTITION_COLUMNS"      = s.partition_columns,
    t."LABEL_EXPRESSION"       = s.label_expression,
    t."WHERE_TEMPLATE"         = s.where_template,
    t."STATUS_COLUMN"          = s.status_column,
    t."CHILD_PARTITION_COLUMN" = s.child_partition_column
when not matched then insert
    ("CEMLI_CODE","TFM_TABLE","PARTITION_COLUMNS","LABEL_EXPRESSION",
     "WHERE_TEMPLATE","STATUS_COLUMN","CHILD_PARTITION_COLUMN")
    values (s.cemli_code, s.tfm_table, s.partition_columns, s.label_expression,
            s.where_template, s.status_column, s.child_partition_column);

commit;
