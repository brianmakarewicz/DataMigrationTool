-- Seed data for the Mock engine-test objects (Stage C task 3).
-- MockObject / MockChild prove the queue engine end-to-end -- submission,
-- catalog-driven dispatch, dependency promotion, failure policies, and the
-- RECONCILE_ONE path -- with no Fusion instance (EXEC_MODE = LOCAL).
--
-- They live in the dedicated TEST pipeline so they can never be swept into a
-- real pipeline submission (a CONFIGURATION registration would have made them
-- members of every registry-driven CONFIGURATION run). MockChild carries a
-- DEPENDS_ON edge to MockObject for the halt-vs-continue tests.
--
-- DMT_MOCK_PKG stubs write DMT_LOG_TBL marker rows per stage and honor the
-- failure-injection config keys seeded below (test/unit/test_queue_engine.sql
-- drives them; see the package spec for the contract).
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

-- Catalog rows: the mocks have no TFM tables (the ARReceipts precedent --
-- TFM_TABLE is nullable for objects whose record types are not built).
merge into "DMT_CEMLI_CATALOG_TBL" t
using (
    select 'MockObject' cemli_code, 'Mock Records' display_name, 1 sort_order from dual
    union all
    select 'MockChild', 'Mock Child Records', 1 from dual
) s
on (t."CEMLI_CODE" = s.cemli_code)
when matched then update set
    t."DISPLAY_NAME"  = s.display_name,
    t."TFM_TABLE"     = null,
    t."STATUS_COLUMN" = null,
    t."ROW_FILTER"    = null,
    t."SORT_ORDER"    = s.sort_order
when not matched then insert
    ("CEMLI_CODE","DISPLAY_NAME","TFM_TABLE","STATUS_COLUMN","ROW_FILTER","SORT_ORDER")
    values (s.cemli_code, s.display_name, null, null, null, s.sort_order);

commit;

-- Failure-injection config keys (idempotent; the engine test flips them).
-- MOCK_FAIL_STAGE: NONE | VALIDATE | TRANSFORM | GENERATE | RECONCILE
-- MOCK_FAIL_OBJECT: which mock object the injection applies to.
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY")
  values ('MOCK_FAIL_STAGE','NONE',
          'DMT_MOCK_PKG failure injection: NONE, VALIDATE, TRANSFORM, GENERATE or RECONCILE',
          sysdate,'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY")
  values ('MOCK_FAIL_OBJECT','MockObject',
          'DMT_MOCK_PKG failure injection: CEMLI code the MOCK_FAIL_STAGE applies to',
          sysdate,'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
commit;
