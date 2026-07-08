-- ============================================================
-- test_control_tables.sql -- Stage C unit tests for the three
-- DECIDED control tables (DMT_DESIGN.html sections 5, 6, 11):
--   DMT_STG_TFM_ERROR_TBL   (section 5  -- pre-TFM failure home)
--   DMT_PIPELINE_DEF_TBL    (section 6  -- pipeline membership/order)
--   DMT_CEMLI_CATALOG_TBL   (section 11 -- object display catalog)
--
-- Self-contained SQLcl/SQL*Plus script (NOT a database object).
-- Run as DMT_OWNER against a full DMT2 install:
--   sql dmt_owner/...@//localhost:1523/FREEPDB1 @test/unit/test_control_tables.sql
--
-- Behavior:
--   - Numbered assertions; any failure raises ORA-20999 with the
--     test number + name, and the script exits nonzero
--     (whenever sqlerror exit failure).
--   - Test rows carry the marker TEST_CONTROL_TABLES_MARKER and are
--     deleted at start and end, so reruns are stable.
--   - The seed-convergence tests deliberately corrupt a seeded value,
--     re-run the committed seed files (registry seeds MERGE on their
--     business key), and assert the committed value is restored.
-- ============================================================

whenever sqlerror exit failure
set serveroutput on size unlimited
set feedback off
set define off

variable passed number

begin :passed := 0; end;
/

-- ------------------------------------------------------------
-- Pre-clean: remove residue from any earlier (failed) run
-- ------------------------------------------------------------
begin
    delete from dmt_stg_tfm_error_tbl where cemli_code = 'TEST_CONTROL_TABLES_MARKER';
    commit;
end;
/

-- ------------------------------------------------------------
-- Block A -- structure, seed counts, canonical-code spot checks
-- ------------------------------------------------------------
declare
    l_passed   pls_integer := 0;
    l_cnt      pls_integer;
    l_cnt2     pls_integer;

    procedure assert (p_cond boolean, p_num pls_integer, p_name varchar2) is
    begin
        if p_cond then
            l_passed := l_passed + 1;
            dbms_output.put_line('PASS  '||lpad(p_num,2)||'  '||p_name);
        else
            raise_application_error(-20999,
                'FAIL test '||p_num||': '||p_name);
        end if;
    end assert;

    function col_exists (p_table varchar2, p_col varchar2) return boolean is
        l_n pls_integer;
    begin
        select count(*) into l_n
          from user_tab_columns
         where table_name = p_table and column_name = p_col;
        return l_n = 1;
    end col_exists;

begin
    -- ----------------------------------------------------------
    -- 1-3. The three tables exist with their key columns
    -- ----------------------------------------------------------
    assert(col_exists('DMT_STG_TFM_ERROR_TBL','ERROR_ID')
       and col_exists('DMT_STG_TFM_ERROR_TBL','RUN_ID')
       and col_exists('DMT_STG_TFM_ERROR_TBL','QUEUE_ID')
       and col_exists('DMT_STG_TFM_ERROR_TBL','CEMLI_CODE')
       and col_exists('DMT_STG_TFM_ERROR_TBL','SUB_OBJECT')
       and col_exists('DMT_STG_TFM_ERROR_TBL','STG_SEQUENCE_ID')
       and col_exists('DMT_STG_TFM_ERROR_TBL','ERROR_TEXT')
       and col_exists('DMT_STG_TFM_ERROR_TBL','CREATED_DATE'),
       1, 'DMT_STG_TFM_ERROR_TBL exists with the section-5 column list');

    assert(col_exists('DMT_PIPELINE_DEF_TBL','PIPELINE_DEF_ID')
       and col_exists('DMT_PIPELINE_DEF_TBL','PIPELINE_CODE')
       and col_exists('DMT_PIPELINE_DEF_TBL','CEMLI_CODE')
       and col_exists('DMT_PIPELINE_DEF_TBL','SORT_ORDER')
       and col_exists('DMT_PIPELINE_DEF_TBL','DEPENDS_ON')
       and col_exists('DMT_PIPELINE_DEF_TBL','POSTRUN_JOB'),
       2, 'DMT_PIPELINE_DEF_TBL exists with the section-6 column list');

    assert(col_exists('DMT_CEMLI_CATALOG_TBL','CATALOG_ID')
       and col_exists('DMT_CEMLI_CATALOG_TBL','CEMLI_CODE')
       and col_exists('DMT_CEMLI_CATALOG_TBL','DISPLAY_NAME')
       and col_exists('DMT_CEMLI_CATALOG_TBL','TFM_TABLE')
       and col_exists('DMT_CEMLI_CATALOG_TBL','STATUS_COLUMN')
       and col_exists('DMT_CEMLI_CATALOG_TBL','ROW_FILTER')
       and col_exists('DMT_CEMLI_CATALOG_TBL','SORT_ORDER'),
       3, 'DMT_CEMLI_CATALOG_TBL exists with the section-11 column list');

    -- ----------------------------------------------------------
    -- 4-5. Catalog seed counts match the design
    --      (section 1: 45 in-scope objects = 23 FBDI + 14 HDL +
    --       6 FBL + 2 REST; PlanningBudgets out of scope;
    --       86 record-type rows as seeded).
    --      MockObject / MockChild are engine-test fixtures in the
    --      TEST pipeline (db/seed/dmt_mock_object.sql), not canonical
    --      objects -- excluded by exact code.
    -- ----------------------------------------------------------
    select count(distinct cemli_code), count(*)
      into l_cnt, l_cnt2
      from dmt_cemli_catalog_tbl
     where cemli_code not in ('MockObject','MockChild');
    assert(l_cnt = 45, 4, 'catalog covers exactly the 45 in-scope canonical objects (got '||l_cnt||')');
    assert(l_cnt2 = 86, 5, 'catalog has the 86 seeded record-type rows (got '||l_cnt2||')');

    -- ----------------------------------------------------------
    -- 6. PlanningBudgets (out of scope) and retired code spellings
    --    (PayrollRels, GLBudgetBalances) are NOT in the catalog
    -- ----------------------------------------------------------
    select count(*) into l_cnt
      from dmt_cemli_catalog_tbl
     where cemli_code in ('PlanningBudgets','PayrollRels','GLBudgetBalances');
    assert(l_cnt = 0, 6, 'no out-of-scope or retired code spellings in the catalog');

    -- ----------------------------------------------------------
    -- 7-11. Canonical-code spot checks, character-exact (binary
    --       equality; the codes come from DMT_DESIGN.html section 1)
    -- ----------------------------------------------------------
    select count(*) into l_cnt from dmt_cemli_catalog_tbl where cemli_code = 'Suppliers';
    assert(l_cnt = 1, 7, 'catalog code ''Suppliers'' character-exact (1 record type)');

    select count(*) into l_cnt from dmt_cemli_catalog_tbl where cemli_code = 'PurchaseOrders';
    assert(l_cnt = 4, 8, 'catalog code ''PurchaseOrders'' character-exact (4 record types)');

    select count(*) into l_cnt from dmt_cemli_catalog_tbl where cemli_code = 'GLBalances';
    assert(l_cnt = 1, 9, 'catalog code ''GLBalances'' character-exact (1 record type)');

    select count(*) into l_cnt from dmt_cemli_catalog_tbl where cemli_code = 'Workers';
    assert(l_cnt = 7, 10, 'catalog code ''Workers'' character-exact (7 person record types)');

    select count(*) into l_cnt from dmt_cemli_catalog_tbl where cemli_code = 'PaymentTerms';
    assert(l_cnt = 2, 11, 'catalog code ''PaymentTerms'' character-exact (2 record types)');

    -- ----------------------------------------------------------
    -- 12. Section-11 canonical drill labels present, byte-exact
    -- ----------------------------------------------------------
    select count(*) into l_cnt
      from dmt_cemli_catalog_tbl
     where (cemli_code, display_name) in (
            ('GLBalances',      'GL Journals'),
            ('Expenditures',    'Project Expenditures'),
            ('Projects',        'Project Tasks'),
            ('Projects',        'Txn Controls'),
            ('PerfEvaluations', 'Performance Docs'));
    assert(l_cnt = 5, 12, 'the 5 section-11 canonical drill labels are seeded byte-exact');

    -- ----------------------------------------------------------
    -- 13-14. Pipeline-def seed counts and one-home rule
    --        (TEST pipeline = the Mock engine-test fixtures,
    --         excluded from the canonical 45)
    -- ----------------------------------------------------------
    select count(*), count(distinct cemli_code)
      into l_cnt, l_cnt2
      from dmt_pipeline_def_tbl
     where pipeline_code <> 'TEST';
    assert(l_cnt = 45, 13, 'pipeline definitions seed all 45 in-scope objects (got '||l_cnt||')');
    assert(l_cnt = l_cnt2, 14, 'every object has exactly one pipeline home');

    -- ----------------------------------------------------------
    -- 15-17. Decided membership spot checks (section 6 seed table):
    --        Requisitions, MiscReceipts and Items all run in P2P
    -- ----------------------------------------------------------
    select count(*) into l_cnt from dmt_pipeline_def_tbl
     where cemli_code = 'Requisitions' and pipeline_code = 'P2P'
       and depends_on = 'Items,SupplierSiteAssignments';
    assert(l_cnt = 1, 15, 'Requisitions is in P2P, waiting for Items,SupplierSiteAssignments');

    select count(*) into l_cnt from dmt_pipeline_def_tbl
     where cemli_code = 'MiscReceipts' and pipeline_code = 'P2P'
       and depends_on = 'Items';
    assert(l_cnt = 1, 16, 'MiscReceipts is in P2P (decided 2026-07-07), waiting for Items');

    select count(*) into l_cnt from dmt_pipeline_def_tbl
     where cemli_code = 'Items' and pipeline_code = 'P2P'
       and sort_order = 10 and depends_on is null;
    assert(l_cnt = 1, 17, 'Items opens P2P (sort 10, no dependencies)');

    -- ----------------------------------------------------------
    -- 18. Requisitions runs before PurchaseOrders (decided ordering)
    -- ----------------------------------------------------------
    select count(*) into l_cnt
      from dmt_pipeline_def_tbl r, dmt_pipeline_def_tbl p
     where r.cemli_code = 'Requisitions' and p.cemli_code = 'PurchaseOrders'
       and r.pipeline_code = p.pipeline_code
       and r.sort_order < p.sort_order;
    assert(l_cnt = 1, 18, 'Requisitions sorts before PurchaseOrders in P2P');

    :passed := :passed + l_passed;
end;
/

-- ------------------------------------------------------------
-- Block B -- seed MERGE convergence setup: corrupt one seeded
-- value in each registry, exactly as ad-hoc drift would
-- ------------------------------------------------------------
begin
    update dmt_cemli_catalog_tbl
       set display_name = 'TEST_CONTROL_TABLES_MARKER drifted label'
     where cemli_code = 'Suppliers';
    if sql%rowcount != 1 then
        raise_application_error(-20999,
            'FAIL convergence setup: expected 1 Suppliers catalog row, got '||sql%rowcount);
    end if;

    update dmt_pipeline_def_tbl
       set depends_on = 'TEST_CONTROL_TABLES_MARKER'
     where cemli_code = 'Requisitions';
    if sql%rowcount != 1 then
        raise_application_error(-20999,
            'FAIL convergence setup: expected 1 Requisitions pipeline-def row, got '||sql%rowcount);
    end if;
    commit;
end;
/

-- Re-run the committed seed files (MERGE on business key must converge)
@@../../db/seed/dmt_cemli_catalog_tbl.sql
@@../../db/seed/dmt_pipeline_def_tbl.sql

-- ------------------------------------------------------------
-- Block C -- convergence assertions + error-table round trip
-- ------------------------------------------------------------
declare
    l_passed   pls_integer := 0;
    l_cnt      pls_integer;
    l_error_id number;
    l_text     varchar2(4000);

    procedure assert (p_cond boolean, p_num pls_integer, p_name varchar2) is
    begin
        if p_cond then
            l_passed := l_passed + 1;
            dbms_output.put_line('PASS  '||lpad(p_num,2)||'  '||p_name);
        else
            raise_application_error(-20999,
                'FAIL test '||p_num||': '||p_name);
        end if;
    end assert;

begin
    -- ----------------------------------------------------------
    -- 19-20. Registry seeds converge on re-run (proposed rule,
    --        infrastructure-tranche review 2026-07-07): the
    --        committed values are restored over the drifted ones
    -- ----------------------------------------------------------
    select count(*) into l_cnt from dmt_cemli_catalog_tbl
     where cemli_code = 'Suppliers' and display_name = 'Suppliers';
    assert(l_cnt = 1, 19, 'catalog seed MERGE restored the committed Suppliers display name');

    select count(*) into l_cnt from dmt_pipeline_def_tbl
     where cemli_code = 'Requisitions'
       and depends_on = 'Items,SupplierSiteAssignments';
    assert(l_cnt = 1, 20, 'pipeline-def seed MERGE restored the committed Requisitions dependencies');

    select count(*) into l_cnt from dmt_cemli_catalog_tbl
     where display_name like 'TEST_CONTROL_TABLES_MARKER%';
    assert(l_cnt = 0, 21, 'no drifted marker rows survive the reseed');

    -- ----------------------------------------------------------
    -- 22-24. Error-table insert/select round trip
    --        (no FKs by design -- the diagnostic row must write
    --        without referential ordering; ERROR_ID is identity)
    -- ----------------------------------------------------------
    insert into dmt_stg_tfm_error_tbl
        (run_id, queue_id, cemli_code, sub_object, stg_sequence_id, error_text)
    values
        (991300199, null, 'TEST_CONTROL_TABLES_MARKER', 'PO Lines', 12345,
         '[PRE_VALIDATION] TEST_CONTROL_TABLES_MARKER round-trip row')
    returning error_id into l_error_id;
    assert(l_error_id is not null, 22, 'ERROR_ID identity assigned on insert');

    select dbms_lob.substr(error_text, 4000, 1), count(*) over ()
      into l_text, l_cnt
      from dmt_stg_tfm_error_tbl
     where run_id = 991300199
       and cemli_code = 'TEST_CONTROL_TABLES_MARKER'
       and stg_sequence_id = 12345;
    assert(l_cnt = 1
       and l_text = '[PRE_VALIDATION] TEST_CONTROL_TABLES_MARKER round-trip row',
       23, 'error row selects back by RUN_ID with intact tag + text');

    select count(*) into l_cnt
      from user_indexes i
      join user_ind_columns c
        on c.index_name = i.index_name
     where i.table_name = 'DMT_STG_TFM_ERROR_TBL'
       and c.column_name = 'RUN_ID'
       and c.column_position = 1;
    assert(l_cnt >= 1, 24, 'RUN_ID contract index present on DMT_STG_TFM_ERROR_TBL (USER_INDEXES)');

    delete from dmt_stg_tfm_error_tbl where cemli_code = 'TEST_CONTROL_TABLES_MARKER';
    commit;

    :passed := :passed + l_passed;
end;
/

-- ------------------------------------------------------------
-- Cleanup -- remove every row this script created
-- ------------------------------------------------------------
begin
    delete from dmt_stg_tfm_error_tbl where cemli_code = 'TEST_CONTROL_TABLES_MARKER';
    commit;
end;
/

-- ------------------------------------------------------------
-- Summary -- only reached when every assertion passed
-- ------------------------------------------------------------
begin
    dbms_output.put_line('TEST_CONTROL_TABLES: '||:passed||' passed, 0 failed');
end;
/

exit success
