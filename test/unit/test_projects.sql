-- ============================================================
-- test_projects.sql — Projects unit tests, OFFLINE steps only
-- (phase 1: no Fusion calls): CSV landing -> upstream validation
-- -> transform -> FBDI generation.
--
-- Projects is ONE object whose single FBDI zip carries four
-- record-type CSVs (Projects, Tasks, TeamMembers, TxnControls) —
-- like PurchaseOrders, not a family of separate objects.
--
-- Self-contained SQLcl/SQL*Plus script (NOT a database object).
-- Run as DMT_OWNER against a full DMT2 install:
--   sql dmt_owner/...@//localhost:1523/FREEPDB1 @test/unit/test_projects.sql
--
-- Behavior:
--   - Numbered assertions; any failure raises ORA-20999 with the
--     test number + name (whenever sqlerror exit failure).
--   - All test rows carry the scenario TEST_PROJECTS_SCN and are
--     deleted at start and end, so reruns are stable. STG statuses
--     are never reset — each rerun lands fresh rows + a new run.
--   - Spec citations reference the accepted DMT_DESIGN.html rules.
--
-- Note on nested blocks: the one-BEGIN/END rule applies to
-- database objects. This is a test script; it uses nested blocks
-- to assert expected exceptions.
-- ============================================================

whenever sqlerror exit failure
set serveroutput on size unlimited
set feedback off
set define off

variable passed  number
variable run_id  number
variable prefix  varchar2(30)

begin :passed := 0; end;
/

-- ------------------------------------------------------------
-- Pre-clean: remove residue from any earlier (failed) run.
-- TFM first (FK to STG), then STG (FK to scenario), then rest.
-- ------------------------------------------------------------
declare
    l_scn number;
begin
    select max(scenario_id) into l_scn
    from   dmt_scenario_tbl
    where  upper(scenario_name) = 'TEST_PROJECTS_SCN';
    if l_scn is not null then
        delete from dmt_pjf_projects_tfm_tbl
        where  stg_sequence_id in (select stg_sequence_id from dmt_pjf_projects_stg_tbl where scenario_id = l_scn);
        delete from dmt_pjf_tasks_tfm_tbl
        where  stg_sequence_id in (select stg_sequence_id from dmt_pjf_tasks_stg_tbl where scenario_id = l_scn);
        delete from dmt_pjf_team_members_tfm_tbl
        where  stg_sequence_id in (select stg_sequence_id from dmt_pjf_team_members_stg_tbl where scenario_id = l_scn);
        delete from dmt_pjc_txn_controls_tfm_tbl
        where  stg_sequence_id in (select stg_sequence_id from dmt_pjc_txn_controls_stg_tbl where scenario_id = l_scn);
        delete from dmt_pjf_projects_stg_tbl     where scenario_id = l_scn;
        delete from dmt_pjf_tasks_stg_tbl         where scenario_id = l_scn;
        delete from dmt_pjf_team_members_stg_tbl  where scenario_id = l_scn;
        delete from dmt_pjc_txn_controls_stg_tbl  where scenario_id = l_scn;
        delete from dmt_scenario_tbl where scenario_id = l_scn;
    end if;
    delete from dmt_csv_landing_tbl where batch_id like 'TEST_PRJ_%';
    delete from dmt_log_tbl where message like '%TEST_PROJECTS%';
    commit;
end;
/

-- ------------------------------------------------------------
-- Block A — step (a): land the four record-type CSVs into the
-- four STG tables via DMT_CSV_LOADER_PKG (scenario-mandatory,
-- header-driven).
-- ------------------------------------------------------------
declare
    l_passed  pls_integer := 0;
    l_scn     number;
    l_cnt     pls_integer;
    l_raised  boolean;

    procedure assert (p_cond boolean, p_num pls_integer, p_name varchar2) is
    begin
        if p_cond then
            l_passed := l_passed + 1;
            dbms_output.put_line('PASS  '||lpad(p_num,2)||'  '||p_name);
        else
            raise_application_error(-20999, 'FAIL test '||p_num||': '||p_name);
        end if;
    end assert;

    function land (p_batch varchar2, p_table varchar2, p_csv clob) return number is
        l_id     number;
        l_status varchar2(30);
        l_rows   number;
        l_err    clob;
    begin
        insert into dmt_csv_landing_tbl
            (batch_id, view_name, atp_table_name, file_name, csv_data, scenario_name)
        values
            (p_batch, p_batch||'_VIEW', p_table, p_batch||'.csv', p_csv, 'TEST_PROJECTS_SCN')
        returning csv_landing_id into l_id;
        commit;
        dmt_csv_loader_pkg.load_csv(p_csv_landing_id => l_id);
        select status, rows_loaded, error_text into l_status, l_rows, l_err
        from   dmt_csv_landing_tbl where csv_landing_id = l_id;
        if l_status <> 'LOADED' then
            raise_application_error(-20999, p_batch||' load failed ('||l_status||'): '||
                dbms_lob.substr(l_err, 3000, 1));
        end if;
        return l_rows;
    end land;
begin
    -- 1-4. Each record-type CSV lands through the scenario-mandatory
    --      path (CSV pipeline: DMT_CSV_LANDING_TBL ->
    --      DMT_CSV_LOADER_PKG.LOAD_CSV, header-driven).
    assert(land('TEST_PRJ_PROJECTS', 'DMT_PJF_PROJECTS_STG_TBL', to_clob(
        'PROJECT_NAME,PROJECT_NUMBER,SOURCE_TEMPLATE_NUMBER,ORGANIZATION_NAME,DESCRIPTION,PROJECT_START_DATE,PROJECT_FINISH_DATE,PROJECT_STATUS_NAME,PROJECT_CURRENCY_CODE,SOURCE_ID'||chr(10)||
        'RT Project Good-1,RTPRJ001,PRGUS Sponsored,Maintenance Prg US,RT test project one,2025/01/01,2025/12/31,Active,USD,RT-PRJ-RTPRJ001'||chr(10)||
        'RT Project Good-2,RTPRJ002,PRGUS Sponsored,Maintenance Prg US,RT test project two,2025/01/01,2025/12/31,Active,USD,RT-PRJ-RTPRJ002'||chr(10)||
        'RT Project Bad-1,RTPRJ-BAD1,PRGUS Sponsored,,BAD: missing org name,2025/01/01,2025/12/31,Active,USD,RT-PRJ-BAD1'||chr(10)))
        = 3, 1, 'Projects CSV lands 3 rows (2 GOOD + 1 BAD missing ORGANIZATION_NAME)');

    assert(land('TEST_PRJ_TASKS', 'DMT_PJF_TASKS_STG_TBL', to_clob(
        'PROJECT_NAME,PROJECT_NUMBER,TASK_NAME,TASK_NUMBER,PLANNING_START_DATE,PLANNING_END_DATE,CHARGEABLE_FLAG,BILLABLE_FLAG,SOURCE_TASK_REFERENCE,SOURCE_ID'||chr(10)||
        'RT Project Good-1,RTPRJ001,RT Design Phase,RTPRJ001.1,2025/01/01,2025/12/31,Y,Y,RTPRJ001.1,RT-TSK-RTPRJ001.1'||chr(10)||
        'RT Project Good-2,RTPRJ002,RT Build Phase,RTPRJ002.1,2025/01/01,2025/12/31,Y,Y,RTPRJ002.1,RT-TSK-RTPRJ002.1'||chr(10)||
        'NONEXISTENT PROJECT,NOPROJ999,Orphan Task,NOPROJ999.1,2025/01/01,2025/12/31,Y,Y,NOPROJ999.1,RT-TSK-BAD1'||chr(10)))
        = 3, 2, 'Tasks CSV lands 3 rows (2 GOOD + 1 orphan for a non-existent project)');

    assert(land('TEST_PRJ_TEAM', 'DMT_PJF_TEAM_MEMBERS_STG_TBL', to_clob(
        'PROJECT_NAME,TEAM_MEMBER_NAME,TEAM_MEMBER_EMAIL,PROJECT_ROLE_NAME,START_DATE_ACTIVE,TRACK_TIME_FLAG,SOURCE_ID'||chr(10)||
        'RT Project Good-1,Alan Cook,alan.cook_esew-dev28@oraclepdemos.com,Project Manager,2025/01/01,Y,RT-TM-G1'||chr(10)||
        'RT Project Good-2,Mandy Steward,mandy.steward_esew-dev28@oraclepdemos.com,Project Manager,2025/01/01,Y,RT-TM-G2'||chr(10)))
        = 2, 3, 'Team Members CSV lands 2 rows');

    assert(land('TEST_PRJ_TXN', 'DMT_PJC_TXN_CONTROLS_STG_TBL', to_clob(
        'TXN_CTRL_REFERENCE,PROJECT_NAME,PROJECT_NUMBER,EXPENDITURE_TYPE,CHARGEABLE_FLAG,START_DATE_ACTIVE,SOURCE_ID'||chr(10)||
        'RT-TXC-RTPRJ001,RT Project Good-1,RTPRJ001,Professional Services,Y,2025/01/01,RT-TXC-RTPRJ001'||chr(10)||
        'RT-TXC-RTPRJ002,RT Project Good-2,RTPRJ002,Professional Services,Y,2025/01/01,RT-TXC-RTPRJ002'||chr(10)))
        = 2, 4, 'Txn Controls CSV lands 2 rows');

    select scenario_id into l_scn
    from   dmt_scenario_tbl where upper(scenario_name) = 'TEST_PROJECTS_SCN';

    -- 5. Every landed STG row is scenario-stamped and STG_STATUS 'NEW'
    --    (accepted STG dictionary: STG_STATUS default 'NEW'; scenario
    --    bound in the ingesting INSERT).
    select count(*) into l_cnt from (
        select stg_status, scenario_id from dmt_pjf_projects_stg_tbl     where scenario_id = l_scn union all
        select stg_status, scenario_id from dmt_pjf_tasks_stg_tbl        where scenario_id = l_scn union all
        select stg_status, scenario_id from dmt_pjf_team_members_stg_tbl where scenario_id = l_scn union all
        select stg_status, scenario_id from dmt_pjc_txn_controls_stg_tbl where scenario_id = l_scn
    ) where stg_status = 'NEW';
    assert(l_cnt = 10, 5, 'all 10 landed STG rows scenario-stamped with STG_STATUS NEW (3+3+2+2)');

    -- 6. Identity-PK conversion tripwire (accepted standard "Identity
    --    columns for keys"): the PK is GENERATED ALWAYS, so supplying
    --    an explicit STG_SEQUENCE_ID must raise ORA-32795.
    l_raised := false;
    begin
        insert into dmt_pjf_projects_stg_tbl (stg_sequence_id, project_name, scenario_id)
        values (999999999, 'TEST explicit-id', l_scn);
    exception
        when others then
            l_raised := (sqlcode = -32795);  -- cannot insert into a generated always identity column
    end;
    assert(l_raised, 6, 'explicit PK insert raises ORA-32795 (GENERATED ALWAYS identity)');
    commit;

    :passed := :passed + l_passed;
end;
/

-- ------------------------------------------------------------
-- Block B — step (b): validator alone. Projects are top-level
-- master data with no upstream dependency, so VALIDATE_PRE_TRANSFORM
-- is a no-op: GOOD rows stay NEW. A pre-seeded ERROR_TEXT proves the
-- validator never overwrites accumulated errors (append-only).
-- ------------------------------------------------------------
declare
    l_passed  pls_integer := 0;
    l_scn     number;
    l_cnt     pls_integer;
    l_status  varchar2(30);
    l_err     clob;

    procedure assert (p_cond boolean, p_num pls_integer, p_name varchar2) is
    begin
        if p_cond then
            l_passed := l_passed + 1;
            dbms_output.put_line('PASS  '||lpad(p_num,2)||'  '||p_name);
        else
            raise_application_error(-20999, 'FAIL test '||p_num||': '||p_name);
        end if;
    end assert;
begin
    select scenario_id into l_scn
    from   dmt_scenario_tbl where upper(scenario_name) = 'TEST_PROJECTS_SCN';

    -- 7. INIT_RUN creates the run row with a 5-digit prefix
    --    (tests always run with USE_PREFIX=Y).
    dmt_pipeline_init_pkg.init_run(
        p_orchestration_code => 'Projects',
        p_scenario_name      => 'TEST_PROJECTS_SCN',
        p_source_filename    => 'test_projects.sql',
        p_instance_id        => 'UNIT_TEST',
        x_integration_id     => :run_id,
        x_prefix             => :prefix);
    assert(:run_id is not null and :prefix is not null and length(:prefix) = 5,
           7, 'INIT_RUN returns run id + 5-digit prefix');

    -- Seed prior error text on the BAD project row to prove APPEND
    -- (accepted rule: "Accumulate, never overwrite").
    update dmt_pjf_projects_stg_tbl
    set    error_text = '[SEED] prior error'
    where  scenario_id = l_scn and project_number = 'RTPRJ-BAD1';
    commit;

    -- 8. VALIDATE_PRE_TRANSFORM is a no-op for Projects (no upstream
    --    dependency): all 3 project rows stay NEW. The missing-org BAD
    --    row is a Fusion-tier rejection proven in phase 2, not offline.
    dmt_project_validator_pkg.validate_pre_transform(:run_id);
    select count(*) into l_cnt from dmt_pjf_projects_stg_tbl
    where  scenario_id = l_scn and stg_status = 'NEW';
    assert(l_cnt = 3, 8, 'VALIDATE_PRE_TRANSFORM is a no-op: all 3 project rows stay NEW');

    -- 9. Post-transform validator is also a no-op offline; no error
    --    added and the pre-seeded text is intact (never overwritten).
    dmt_project_validator_pkg.validate_post_transform(:run_id);
    select stg_status, error_text into l_status, l_err from dmt_pjf_projects_stg_tbl
    where  scenario_id = l_scn and project_number = 'RTPRJ-BAD1';
    assert(l_status = 'NEW' and l_err = '[SEED] prior error', 9,
           'validator leaves rows NEW and does not overwrite pre-seeded ERROR_TEXT');
    commit;

    :passed := :passed + l_passed;
end;
/

-- ------------------------------------------------------------
-- Block C — step (c): transformer alone. TFM rows are stamped with
-- RUN_ID + lineage, the run prefix is applied to PROJECT_NAME /
-- PROJECT_NUMBER, STG data is unchanged (STG_STATUS moves
-- NEW -> TRANSFORMED, forward-only).
-- ------------------------------------------------------------
declare
    l_passed  pls_integer := 0;
    l_scn     number;
    l_cnt     pls_integer;
    l_vc      varchar2(4000);
    l_vc2     varchar2(4000);

    procedure assert (p_cond boolean, p_num pls_integer, p_name varchar2) is
    begin
        if p_cond then
            l_passed := l_passed + 1;
            dbms_output.put_line('PASS  '||lpad(p_num,2)||'  '||p_name);
        else
            raise_application_error(-20999, 'FAIL test '||p_num||': '||p_name);
        end if;
    end assert;
begin
    select scenario_id into l_scn
    from   dmt_scenario_tbl where upper(scenario_name) = 'TEST_PROJECTS_SCN';

    dmt_project_transform_pkg.transform_projects(:run_id, p_scenario_id => l_scn);
    dmt_project_transform_pkg.transform_tasks(:run_id, p_scenario_id => l_scn);
    dmt_project_transform_pkg.transform_team_members(:run_id, p_scenario_id => l_scn);
    dmt_project_transform_pkg.transform_txn_controls(:run_id, p_scenario_id => l_scn);
    commit;

    -- 10. All 10 NEW rows transform (validator did not fail any offline).
    select (select count(*) from dmt_pjf_projects_tfm_tbl     where run_id = :run_id)
         + (select count(*) from dmt_pjf_tasks_tfm_tbl        where run_id = :run_id)
         + (select count(*) from dmt_pjf_team_members_tfm_tbl where run_id = :run_id)
         + (select count(*) from dmt_pjc_txn_controls_tfm_tbl where run_id = :run_id)
    into l_cnt from dual;
    assert(l_cnt = 10, 10, 'all 10 rows transform to TFM (3 projects + 3 tasks + 2 team + 2 txn)');

    -- 11. TFM rows stamped: RUN_ID, TFM_STATUS STAGED, STG_SEQUENCE_ID
    --     lineage populated.
    select count(*) into l_cnt from dmt_pjf_projects_tfm_tbl
    where  run_id = :run_id and tfm_status = 'STAGED' and stg_sequence_id is not null;
    assert(l_cnt = 3, 11, 'project TFM rows: STATUS STAGED + STG_SEQUENCE_ID lineage stamped');

    -- 12-13. Prefix applied to the project business keys at transform.
    select project_name, project_number into l_vc, l_vc2
    from   dmt_pjf_projects_tfm_tbl t
    where  t.run_id = :run_id
    and    t.stg_sequence_id = (select stg_sequence_id from dmt_pjf_projects_stg_tbl
                                where scenario_id = l_scn and source_id = 'RT-PRJ-RTPRJ001');
    assert(l_vc = :prefix||'RT Project Good-1', 12, 'TFM PROJECT_NAME = prefix || STG name');
    assert(l_vc2 = :prefix||'RTPRJ001', 13, 'TFM PROJECT_NUMBER = prefix || STG number');

    -- 14. Team members link by PROJECT_NAME (no PROJECT_NUMBER on that
    --     record type) and get the same prefixed name.
    select project_name into l_vc
    from   dmt_pjf_team_members_tfm_tbl
    where  run_id = :run_id and team_member_name = 'Alan Cook';
    assert(l_vc = :prefix||'RT Project Good-1', 14, 'team member TFM PROJECT_NAME prefixed');

    -- 15. TXN_CTRL_REFERENCE is NOT prefixed (it is a source reference,
    --     not a business key that Fusion de-duplicates on).
    select txn_ctrl_reference into l_vc
    from   dmt_pjc_txn_controls_tfm_tbl
    where  run_id = :run_id and project_number = :prefix||'RTPRJ001';
    assert(l_vc = 'RT-TXC-RTPRJ001', 15, 'TFM TXN_CTRL_REFERENCE left unprefixed');

    -- 16. Transformed STG rows move NEW -> TRANSFORMED (forward-only).
    select count(*) into l_cnt from (
        select 1 from dmt_pjf_projects_stg_tbl     where scenario_id = l_scn and stg_status = 'TRANSFORMED' union all
        select 1 from dmt_pjf_tasks_stg_tbl        where scenario_id = l_scn and stg_status = 'TRANSFORMED' union all
        select 1 from dmt_pjf_team_members_stg_tbl where scenario_id = l_scn and stg_status = 'TRANSFORMED' union all
        select 1 from dmt_pjc_txn_controls_stg_tbl where scenario_id = l_scn and stg_status = 'TRANSFORMED');
    assert(l_cnt = 10, 16, 'the 10 transformed STG rows move NEW -> TRANSFORMED');

    -- 17. STG data columns unchanged — the prefix lives only on TFM.
    select count(*) into l_cnt from dmt_pjf_projects_stg_tbl
    where  scenario_id = l_scn and project_name like :prefix||'%';
    assert(l_cnt = 0, 17, 'STG PROJECT_NAME still unprefixed (prefix applied only in TFM)');

    -- 18. Re-running the transform for the same run adds no duplicate
    --     TFM rows (NOT EXISTS guard on STG_SEQUENCE_ID + RUN_ID).
    dmt_project_transform_pkg.transform_projects(:run_id, p_scenario_id => l_scn);
    commit;
    select count(*) into l_cnt from dmt_pjf_projects_tfm_tbl where run_id = :run_id;
    assert(l_cnt = 3, 18, 're-transform of the same run is idempotent (still 3 project TFM rows)');

    :passed := :passed + l_passed;
end;
/

-- ------------------------------------------------------------
-- Block D — step (d): the FBDI generator. ONE zip carrying four
-- record-type CSVs; TFM rows advance STAGED -> GENERATED with
-- FBDI_CSV_ID lineage.
-- ------------------------------------------------------------
declare
    l_passed  pls_integer := 0;
    l_cnt     pls_integer;
    l_zip     blob;
    l_fn      varchar2(200);
    l_csv_id  number;
    l_csv     clob;
    l_rows    number;

    procedure assert (p_cond boolean, p_num pls_integer, p_name varchar2) is
    begin
        if p_cond then
            l_passed := l_passed + 1;
            dbms_output.put_line('PASS  '||lpad(p_num,2)||'  '||p_name);
        else
            raise_application_error(-20999, 'FAIL test '||p_num||': '||p_name);
        end if;
    end assert;
begin
    -- 19. GENERATE_FBDI returns one zip named Projects_<run>.zip.
    dmt_project_fbdi_gen_pkg.generate_fbdi(:run_id, l_zip, l_fn, l_csv_id);
    assert(l_zip is not null and l_fn = 'Projects_'||:run_id||'.zip' and l_csv_id is not null,
           19, 'GENERATE_FBDI returns a zip named Projects_<run>.zip with an FBDI_CSV_ID');

    -- 20. All four record types advance STAGED -> GENERATED with the
    --     same FBDI_CSV_ID (one zip carried them all).
    select (select count(*) from dmt_pjf_projects_tfm_tbl     where run_id = :run_id and tfm_status = 'GENERATED' and fbdi_csv_id = l_csv_id)
         + (select count(*) from dmt_pjf_tasks_tfm_tbl        where run_id = :run_id and tfm_status = 'GENERATED' and fbdi_csv_id = l_csv_id)
         + (select count(*) from dmt_pjf_team_members_tfm_tbl where run_id = :run_id and tfm_status = 'GENERATED' and fbdi_csv_id = l_csv_id)
         + (select count(*) from dmt_pjc_txn_controls_tfm_tbl where run_id = :run_id and tfm_status = 'GENERATED' and fbdi_csv_id = l_csv_id)
    into l_cnt from dual;
    assert(l_cnt = 10, 20, 'all 10 TFM rows advance to GENERATED with the shared FBDI_CSV_ID');

    -- 21. The persisted primary CSV carries the prefixed project keys.
    select csv_content into l_csv
    from   dmt_fbdi_csv_tbl
    where  run_id = :run_id and object_type = 'Projects';
    assert(dbms_lob.instr(l_csv, :prefix||'RTPRJ001') > 0
           and dbms_lob.instr(l_csv, :prefix||'RTPRJ-BAD1') > 0,
           21, 'persisted Projects CSV carries the prefixed project numbers (incl. the BAD row)');

    -- 22. The zip is persisted for the run.
    select count(*) into l_cnt from dmt_fbdi_zip_tbl
    where  run_id = :run_id and object_type = 'Projects' and zip_size_bytes > 0;
    assert(l_cnt = 1, 22, 'Projects zip persisted in DMT_FBDI_ZIP_TBL with content');
    commit;

    :passed := :passed + l_passed;
end;
/

-- ------------------------------------------------------------
-- Cleanup — remove every row this script created.
-- Order: TFM (FK to STG + CSV), ZIP (FK to CSV), CSV, STG,
-- landing, scenario, log.
-- ------------------------------------------------------------
declare
    l_scn number;
begin
    select max(scenario_id) into l_scn
    from   dmt_scenario_tbl
    where  upper(scenario_name) = 'TEST_PROJECTS_SCN';
    if l_scn is not null then
        delete from dmt_pjf_projects_tfm_tbl
        where  stg_sequence_id in (select stg_sequence_id from dmt_pjf_projects_stg_tbl where scenario_id = l_scn);
        delete from dmt_pjf_tasks_tfm_tbl
        where  stg_sequence_id in (select stg_sequence_id from dmt_pjf_tasks_stg_tbl where scenario_id = l_scn);
        delete from dmt_pjf_team_members_tfm_tbl
        where  stg_sequence_id in (select stg_sequence_id from dmt_pjf_team_members_stg_tbl where scenario_id = l_scn);
        delete from dmt_pjc_txn_controls_tfm_tbl
        where  stg_sequence_id in (select stg_sequence_id from dmt_pjc_txn_controls_stg_tbl where scenario_id = l_scn);
        delete from dmt_pjf_projects_stg_tbl     where scenario_id = l_scn;
        delete from dmt_pjf_tasks_stg_tbl         where scenario_id = l_scn;
        delete from dmt_pjf_team_members_stg_tbl  where scenario_id = l_scn;
        delete from dmt_pjc_txn_controls_stg_tbl  where scenario_id = l_scn;
        delete from dmt_scenario_tbl where scenario_id = l_scn;
    end if;
    if :run_id is not null then
        delete from dmt_fbdi_zip_tbl where run_id = :run_id;
        delete from dmt_fbdi_csv_tbl where run_id = :run_id;
    end if;
    delete from dmt_csv_landing_tbl where batch_id like 'TEST_PRJ_%';
    delete from dmt_log_tbl where message like '%TEST_PROJECTS%';
    commit;
end;
/

-- ------------------------------------------------------------
-- Summary — only reached when every assertion passed
-- ------------------------------------------------------------
begin
    dbms_output.put_line('TEST_PROJECTS: '||:passed||' passed, 0 failed');
end;
/
