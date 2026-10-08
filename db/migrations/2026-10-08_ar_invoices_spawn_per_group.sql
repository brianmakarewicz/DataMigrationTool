-- ARInvoices: one child work item per (BU, batch source) group (backlog #313).
--
-- AR Invoices loads one FBDI zip per (BU_NAME, BATCH_SOURCE_NAME) group, each with
-- its own load and AutoInvoice import ESS ids. It used to load every group inside
-- ONE work item, which kept only the last group's two ids, so a reconcile-only
-- rerun re-read only that group. This makes ARInvoices a spawn-per-partition object
-- (the same mechanism Requisitions, Items, Assets and Expenditures use): the parent
-- work item transforms once, then the queue worker spawns one child work item per
-- group (PARENT_QUEUE_ID = the parent), and each child loads, reconciles and records
-- its own group's ids.
--
-- Mirrors the committed seed changes in db/seed/dmt_cemli_split_cfg.sql and
-- db/seed/dmt_pipeline_def_tbl.sql so an existing database converges without
-- re-running the whole seed. Idempotent: MERGE / UPDATE to fixed values (a re-run
-- is a no-op), migration-log MERGE. No DDL.

prompt == ARInvoices split config: spawn one child per (BU, batch source) group ==
merge into DMT_CEMLI_SPLIT_CFG t
using (
    select 'ARInvoices' cemli_code, 'DMT_RA_LINES_TFM_TBL' tfm_table,
           'BU_NAME,BATCH_SOURCE_NAME' partition_columns, 'BATCH_SOURCE_NAME' label_expression,
           'BU_NAME = :bu_name AND BATCH_SOURCE_NAME = :batch_source_name' where_template,
           'TFM_STATUS' status_column, 'BATCH_SOURCE_NAME' child_partition_column
    from dual
) s
on (t.CEMLI_CODE = s.cemli_code)
when matched then update set
    t.TFM_TABLE              = s.tfm_table,
    t.PARTITION_COLUMNS      = s.partition_columns,
    t.LABEL_EXPRESSION       = s.label_expression,
    t.WHERE_TEMPLATE         = s.where_template,
    t.STATUS_COLUMN          = s.status_column,
    t.CHILD_PARTITION_COLUMN = s.child_partition_column
when not matched then insert
    (CEMLI_CODE, TFM_TABLE, PARTITION_COLUMNS, LABEL_EXPRESSION, WHERE_TEMPLATE,
     STATUS_COLUMN, CHILD_PARTITION_COLUMN)
    values (s.cemli_code, s.tfm_table, s.partition_columns, s.label_expression,
            s.where_template, s.status_column, s.child_partition_column);

prompt == ARInvoices pipeline registry: partition-keys function ==
update DMT_PIPELINE_DEF_TBL
set    PARTITION_KEYS_PROC = 'DMT_AR_RESULTS_PKG.GET_PARTITION_KEYS'
where  CEMLI_CODE = 'ARInvoices';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-08_ar_invoices_spawn_per_group.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'arspawn313', USER);

commit;
