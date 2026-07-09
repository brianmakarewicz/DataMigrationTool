-- TEST-SETUP seed for the Mock engine-test objects (Stage C tasks 3 + 4).
-- E1 (2026-07-08): this file is deliberately NOT enrolled in db/install.sql.
-- MockObject / MockChild registrations (pipeline def, catalog, MOCK_* config
-- keys) exist only where an engine test has run this setup — a production
-- install never carries dispatchable mock objects or test config keys.
-- (DMT_MOCK_PKG and DMT_MOCK_TFM_TBL are installed so the package compiles,
-- but they are inert without these registration rows.)
-- Run by test/unit/test_queue_engine.sql (@@setup_mock_objects.sql).
--
-- MockObject / MockChild prove the queue engine end-to-end -- submission,
-- catalog-driven dispatch, dependency promotion, failure policies, the
-- RECONCILE_ONE path, the accounting gate, and the run-tfm_status rollup --
-- with no Fusion instance (EXEC_MODE = LOCAL).
--
-- They live in the dedicated TEST pipeline so they can never be swept into a
-- real pipeline submission (a CONFIGURATION registration would have made them
-- members of every registry-driven CONFIGURATION run). The TEST pipeline code
-- exists in DMT_PIPELINE_DEF_CK1 for exactly this purpose and never appears
-- in production seed rows. MockChild carries a DEPENDS_ON edge to MockObject
-- for the halt-vs-continue tests.
-- MERGE on the business key (CEMLI_CODE) so re-running converges.

merge into "DMT_PIPELINE_DEF_TBL" t
using (
    select 'TEST' pipeline_code, 10 sort_order, 'MockObject' cemli_code,
           cast(null as varchar2(4000)) depends_on,
           'DMT_MOCK_PKG.RUN_MOCK_OBJECT' exec_proc, 'LOCAL' exec_mode,
           'DMT_MOCK_PKG.RECONCILE_BATCH' recon_proc, 'Y' recon_has_cemli_arg
    from dual
    union all
    select 'TEST', 20, 'MockChild', 'MockObject',
           'DMT_MOCK_PKG.RUN_MOCK_CHILD', 'LOCAL',
           'DMT_MOCK_PKG.RECONCILE_BATCH', 'Y'
    from dual
) s
on (t."CEMLI_CODE" = s.cemli_code)
when matched then update set
    t."PIPELINE_CODE"       = s.pipeline_code,
    t."SORT_ORDER"          = s.sort_order,
    t."DEPENDS_ON"          = s.depends_on,
    t."POSTRUN_JOB"         = null,
    t."EXEC_PROC"           = s.exec_proc,
    t."EXEC_MODE"           = s.exec_mode,
    t."RECON_PROC"          = s.recon_proc,
    t."RECON_HAS_CEMLI_ARG" = s.recon_has_cemli_arg
when not matched then insert
    ("PIPELINE_CODE","CEMLI_CODE","SORT_ORDER","DEPENDS_ON","POSTRUN_JOB",
     "EXEC_PROC","EXEC_MODE","RECON_PROC","RECON_HAS_CEMLI_ARG")
    values (s.pipeline_code, s.cemli_code, s.sort_order, s.depends_on, null,
            s.exec_proc, s.exec_mode, s.recon_proc, s.recon_has_cemli_arg);

commit;

-- Catalog rows: point at the committed DMT_MOCK_TFM_TBL so the catalog-
-- driven accounting gate (DMT_QUEUE_WORKER_PKG.ACCOUNT_ROWS -- design
-- section 5 "Object-tfm_status accounting") counts real mock rows. ROW_FILTER
-- discriminates the two mocks sharing one table (the shared-table-children
-- pattern the catalog contract defines).
merge into "DMT_CEMLI_CATALOG_TBL" t
using (
    select 'MockObject' cemli_code, 'Mock Records' display_name,
           'DMT_MOCK_TFM_TBL' tfm_table, 'TFM_STATUS' status_column,
           'CEMLI_CODE = ''MockObject''' row_filter, 1 sort_order from dual
    union all
    select 'MockChild', 'Mock Child Records',
           'DMT_MOCK_TFM_TBL', 'TFM_STATUS',
           'CEMLI_CODE = ''MockChild''', 1 from dual
) s
on (t."CEMLI_CODE" = s.cemli_code)
when matched then update set
    t."DISPLAY_NAME"  = s.display_name,
    t."TFM_TABLE"     = s.tfm_table,
    t."STATUS_COLUMN" = s.status_column,
    t."ROW_FILTER"    = s.row_filter,
    t."SORT_ORDER"    = s.sort_order
when not matched then insert
    ("CEMLI_CODE","DISPLAY_NAME","TFM_TABLE","STATUS_COLUMN","ROW_FILTER","SORT_ORDER")
    values (s.cemli_code, s.display_name, s.tfm_table, s.status_column,
            s.row_filter, s.sort_order);

commit;

-- Mock behavior config keys (idempotent; the engine test flips them).
-- MOCK_FAIL_STAGE:    NONE | VALIDATE | TRANSFORM | GENERATE | RECONCILE
-- MOCK_FAIL_OBJECT:   which mock object the injection applies to.
-- MOCK_ROW_COUNT:     rows written GENERATED per mock data phase (default 2).
-- MOCK_RECON_OUTCOME: LOADED | FAILED_ERROR | UNACCOUNTED (see DMT_MOCK_PKG).
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY")
  values ('MOCK_FAIL_STAGE','NONE',
          'DMT_MOCK_PKG failure injection: NONE, VALIDATE, TRANSFORM, GENERATE or RECONCILE (test-only key)',
          sysdate,'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY")
  values ('MOCK_FAIL_OBJECT','MockObject',
          'DMT_MOCK_PKG failure injection: CEMLI code the MOCK_FAIL_STAGE applies to (test-only key)',
          sysdate,'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY")
  values ('MOCK_ROW_COUNT','2',
          'DMT_MOCK_PKG: rows written GENERATED to DMT_MOCK_TFM_TBL per mock data phase (test-only key)',
          sysdate,'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY")
  values ('MOCK_RECON_OUTCOME','LOADED',
          'DMT_MOCK_PKG reconcile outcome: LOADED, FAILED_ERROR or UNACCOUNTED (test-only key)',
          sysdate,'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
commit;
