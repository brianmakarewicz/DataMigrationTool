-- ============================================================
-- test_queue_engine.sql -- Stage C engine tests (DMT_DESIGN.html
-- section 2: heartbeat, work-queue states, catalog-driven dispatch,
-- one-active-run-per-object, halt-vs-continue, failure handling).
--
-- Uses the Mock engine-test objects (db/seed/dmt_mock_object.sql +
-- DMT_MOCK_PKG): MockObject / MockChild in the TEST pipeline,
-- EXEC_MODE = LOCAL, so the whole walk runs with NO Fusion instance.
-- Each mock stage writes a DMT_LOG_TBL marker row proving it ran via
-- the registry dispatch; DMT_CONFIG_TBL MOCK_FAIL_STAGE /
-- MOCK_FAIL_OBJECT inject failures.
--
-- Self-contained SQLcl/SQL*Plus script (NOT a database object).
-- Run as DMT_OWNER against a full DMT2 install:
--   sql dmt_owner/...@//localhost:1523/FREEPDB1 @test/unit/test_queue_engine.sql
--
-- Behavior:
--   - Statuses are walked by calling DMT_QUEUE_PKG.HEARTBEAT_TICK
--     directly in a bounded loop (never by waiting on the 60-second
--     DMT_QUEUE_POLLER job). The heavy work still runs in the real
--     one-shot DBMS_SCHEDULER child jobs the tick spawns, so this
--     exercises the production execution path end to end. Expect
--     this suite to take a few minutes.
--   - Numbered assertions; any failure raises ORA-20999 and the
--     script exits nonzero (whenever sqlerror exit failure).
--   - All rows are scoped by the MOCK_ENGINE_* scenario names and
--     cleaned at start and end, so reruns are stable.
-- ============================================================

whenever sqlerror exit failure
set serveroutput on size unlimited
set feedback off
set define off

variable passed number

begin :passed := 0; end;
/

-- ------------------------------------------------------------
-- Pre-clean: remove residue from any earlier (failed) run and
-- reset the failure-injection config to inert values.
-- ------------------------------------------------------------
declare
    type t_scn is table of varchar2(30);
    l_scenarios t_scn := t_scn('MOCK_ENGINE_A','MOCK_ENGINE_B','MOCK_ENGINE_C1',
                               'MOCK_ENGINE_D1','MOCK_ENGINE_D2','MOCK_ENGINE_E');
begin
    for i in 1 .. l_scenarios.count loop
        delete from dmt_log_tbl
         where run_id in (select run_id from dmt_pipeline_run_tbl
                          where scenario_name = l_scenarios(i));
        delete from dmt_work_queue_tbl
         where run_id in (select run_id from dmt_pipeline_run_tbl
                          where scenario_name = l_scenarios(i));
        delete from dmt_pipeline_run_tbl
         where scenario_name = l_scenarios(i);
    end loop;
    dmt_util_pkg.set_config(p_key => 'MOCK_FAIL_STAGE',  p_value => 'NONE');
    dmt_util_pkg.set_config(p_key => 'MOCK_FAIL_OBJECT', p_value => 'MockObject');
    commit;
end;
/

-- ------------------------------------------------------------
-- The engine walk -- one block, sequential scenarios (a)-(e)
-- ------------------------------------------------------------
declare
    l_passed  pls_integer := 0;
    l_run_a   number;
    l_run_b   number;
    l_run_c1  number;
    l_run_d1  number;
    l_run_d2  number;
    l_run_e   number;
    l_run_dup number;
    l_status  varchar2(30);
    l_wstatus varchar2(30);
    l_errmsg  varchar2(4000);
    l_cnt     pls_integer;
    l_reject  varchar2(4000);

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

    -- Tick the heartbeat directly in a bounded loop until the run is
    -- terminal. The tick spawns the real child jobs (EXECUTE_ONE /
    -- RECONCILE_ONE); the sleep lets them run. A run that never goes
    -- terminal within the bound is a hung engine -- hard failure.
    procedure wait_for_run (p_run_id in number, x_status out varchar2) is
        l_max_ticks constant pls_integer := 90;
    begin
        for i in 1 .. l_max_ticks loop
            dmt_queue_pkg.heartbeat_tick;
            dbms_session.sleep(2);
            select run_status into x_status
              from dmt_pipeline_run_tbl where run_id = p_run_id;
            exit when x_status in ('COMPLETED','COMPLETED_ERRORS','FAILED');
        end loop;
        if x_status not in ('COMPLETED','COMPLETED_ERRORS','FAILED') then
            raise_application_error(-20999,
                'FAIL: run '||p_run_id||' never reached a terminal status '
                ||'(last: '||x_status||') -- engine hung');
        end if;
    end wait_for_run;

    -- Count one mock stage's marker rows for one object in one run.
    function marker_count (p_run_id in number, p_code in varchar2,
                           p_stage in varchar2) return pls_integer is
        l_n pls_integer;
    begin
        select count(*) into l_n
          from dmt_log_tbl
         where run_id = p_run_id
           and package_name = 'DMT_MOCK_PKG'
           and procedure_name = p_stage
           and dbms_lob.instr(message,
                   'DMT_MOCK '||p_code||' '||p_stage||' ran') > 0;
        return l_n;
    end marker_count;

begin
    -- ----------------------------------------------------------
    -- (a) 1-8. Clean walk: submit MockObject via the scheduler,
    --     work item walks READY -> ... -> DONE, with a marker row
    --     per stage proving catalog dispatch ran VALIDATE /
    --     TRANSFORM / GENERATE via EXEC_PROC and RECONCILE via
    --     RECON_PROC (the RECONCILE_ONE path -- LOCAL objects
    --     route through RECONCILING, not straight to DONE).
    -- ----------------------------------------------------------
    dmt_scheduler_pkg.submit_objects(
        p_objects       => 'MockObject',
        p_scenario_name => 'MOCK_ENGINE_A',
        p_submitted_by  => 'TEST_QUEUE_ENGINE',
        x_run_id        => l_run_a);
    assert(l_run_a is not null, 1, 'SUBMIT_OBJECTS created a run for MockObject');

    select work_status into l_wstatus
      from dmt_work_queue_tbl
     where run_id = l_run_a and cemli_code = 'MockObject';
    assert(l_wstatus = 'READY', 2,
        'MockObject work item created READY (no dependencies)');

    wait_for_run(l_run_a, l_status);
    assert(l_status = 'COMPLETED', 3,
        'run rolled up to COMPLETED (got '||l_status||')');

    select work_status into l_wstatus
      from dmt_work_queue_tbl
     where run_id = l_run_a and cemli_code = 'MockObject';
    assert(l_wstatus = 'DONE', 4, 'MockObject work item ended DONE');

    assert(marker_count(l_run_a, 'MockObject', 'VALIDATE')  = 1, 5,
        'VALIDATE marker written via catalog EXEC_PROC dispatch');
    assert(marker_count(l_run_a, 'MockObject', 'TRANSFORM') = 1, 6,
        'TRANSFORM marker written via catalog EXEC_PROC dispatch');
    assert(marker_count(l_run_a, 'MockObject', 'GENERATE')  = 1, 7,
        'GENERATE marker written via catalog EXEC_PROC dispatch');
    assert(marker_count(l_run_a, 'MockObject', 'RECONCILE') = 1, 8,
        'RECONCILE marker written via catalog RECON_PROC dispatch (RECONCILE_ONE ran)');

    -- ----------------------------------------------------------
    -- (b) 9-13. Failure injection at TRANSFORM: work item FAILED
    --     with the stage-tagged error text; later stages never ran.
    -- ----------------------------------------------------------
    dmt_util_pkg.set_config(p_key => 'MOCK_FAIL_STAGE',  p_value => 'TRANSFORM');
    dmt_util_pkg.set_config(p_key => 'MOCK_FAIL_OBJECT', p_value => 'MockObject');

    dmt_scheduler_pkg.submit_objects(
        p_objects       => 'MockObject',
        p_scenario_name => 'MOCK_ENGINE_B',
        p_submitted_by  => 'TEST_QUEUE_ENGINE',
        x_run_id        => l_run_b);
    wait_for_run(l_run_b, l_status);
    assert(l_status = 'FAILED', 9,
        'transform-injected run rolled up to FAILED (got '||l_status||')');

    select work_status, substr(error_message, 1, 4000)
      into l_wstatus, l_errmsg
      from dmt_work_queue_tbl
     where run_id = l_run_b and cemli_code = 'MockObject';
    assert(l_wstatus = 'FAILED', 10, 'MockObject work item ended FAILED');
    assert(instr(l_errmsg, '[TRANSFORM_ERROR]') > 0
       and instr(l_errmsg, 'injected failure at TRANSFORM') > 0, 11,
        'ERROR_MESSAGE carries the stage tag + injected text (got: '
        ||substr(l_errmsg,1,120)||')');
    assert(marker_count(l_run_b, 'MockObject', 'VALIDATE') = 1, 12,
        'VALIDATE ran before the injected TRANSFORM failure');
    assert(marker_count(l_run_b, 'MockObject', 'GENERATE')  = 0
       and marker_count(l_run_b, 'MockObject', 'RECONCILE') = 0, 13,
        'GENERATE / RECONCILE never ran after the TRANSFORM failure');

    dmt_util_pkg.set_config(p_key => 'MOCK_FAIL_STAGE', p_value => 'NONE');

    -- ----------------------------------------------------------
    -- (c) 14-16. One-active-run-per-object (section 2): a second
    --     submission naming MockObject while the first run is
    --     active is REJECTED at submission with a message naming
    --     the object and the blocking run.
    -- ----------------------------------------------------------
    dmt_scheduler_pkg.submit_objects(
        p_objects       => 'MockObject',
        p_scenario_name => 'MOCK_ENGINE_C1',
        p_submitted_by  => 'TEST_QUEUE_ENGINE',
        x_run_id        => l_run_c1);
    assert(l_run_c1 is not null, 14, 'first MockObject run submitted (QUEUED, active)');

    l_reject := null;
    begin
        dmt_scheduler_pkg.submit_objects(
            p_objects       => 'MockObject',
            p_scenario_name => 'MOCK_ENGINE_C1',
            p_submitted_by  => 'TEST_QUEUE_ENGINE',
            x_run_id        => l_run_dup);
    exception
        when others then l_reject := sqlerrm;
    end;
    assert(l_reject is not null and instr(l_reject, 'MockObject') > 0
       and instr(l_reject, 'active run #'||l_run_c1) > 0, 15,
        'second submit rejected naming the object and blocking run (got: '
        ||substr(nvl(l_reject,'no error raised'),1,150)||')');

    wait_for_run(l_run_c1, l_status);
    assert(l_status = 'COMPLETED', 16,
        'blocking run then completed normally (got '||l_status||')');

    -- ----------------------------------------------------------
    -- (d) 17-22. Dependency halt vs continue, MockChild DEPENDS_ON
    --     MockObject (registry edge read by the scheduler).
    --     HALT: parent fails -> child cascade-SKIPPED, never runs.
    --     CONTINUE: parent fails -> child promotes on the terminal
    --     parent, runs, and ends DONE.
    -- ----------------------------------------------------------
    dmt_util_pkg.set_config(p_key => 'MOCK_FAIL_STAGE', p_value => 'TRANSFORM');

    dmt_scheduler_pkg.submit_objects(
        p_objects       => 'MockObject|MockChild',
        p_scenario_name => 'MOCK_ENGINE_D1',
        p_on_failure    => 'HALT',
        p_submitted_by  => 'TEST_QUEUE_ENGINE',
        x_run_id        => l_run_d1);
    wait_for_run(l_run_d1, l_status);

    select work_status into l_wstatus
      from dmt_work_queue_tbl
     where run_id = l_run_d1 and cemli_code = 'MockChild';
    assert(l_wstatus = 'SKIPPED', 17,
        'HALT: MockChild cascade-SKIPPED after MockObject failed (got '||l_wstatus||')');
    select substr(error_message, 1, 4000) into l_errmsg
      from dmt_work_queue_tbl
     where run_id = l_run_d1 and cemli_code = 'MockChild';
    assert(instr(l_errmsg, 'MockObject') > 0, 18,
        'HALT: skip message names the failed upstream object');
    assert(marker_count(l_run_d1, 'MockChild', 'VALIDATE') = 0, 19,
        'HALT: MockChild never executed');

    dmt_scheduler_pkg.submit_objects(
        p_objects       => 'MockObject|MockChild',
        p_scenario_name => 'MOCK_ENGINE_D2',
        p_on_failure    => 'CONTINUE',
        p_submitted_by  => 'TEST_QUEUE_ENGINE',
        x_run_id        => l_run_d2);
    wait_for_run(l_run_d2, l_status);
    assert(l_status = 'COMPLETED_ERRORS', 20,
        'CONTINUE: run rolled up to COMPLETED_ERRORS (got '||l_status||')');

    select work_status into l_wstatus
      from dmt_work_queue_tbl
     where run_id = l_run_d2 and cemli_code = 'MockChild';
    assert(l_wstatus = 'DONE', 21,
        'CONTINUE: MockChild promoted on the terminal (FAILED) parent and ended DONE');
    assert(marker_count(l_run_d2, 'MockChild', 'VALIDATE')  = 1
       and marker_count(l_run_d2, 'MockChild', 'RECONCILE') = 1, 22,
        'CONTINUE: MockChild ran its full stage walk');

    -- ----------------------------------------------------------
    -- (e) 23-25. Unhandled RAISE inside the dispatched reconciler:
    --     RECONCILE_ONE's handler must land the work item in FAILED
    --     with the error captured -- never hung (wait_for_run itself
    --     hard-fails on a non-terminal run).
    -- ----------------------------------------------------------
    dmt_util_pkg.set_config(p_key => 'MOCK_FAIL_STAGE', p_value => 'RECONCILE');

    dmt_scheduler_pkg.submit_objects(
        p_objects       => 'MockObject',
        p_scenario_name => 'MOCK_ENGINE_E',
        p_submitted_by  => 'TEST_QUEUE_ENGINE',
        x_run_id        => l_run_e);
    wait_for_run(l_run_e, l_status);
    assert(l_status = 'FAILED', 23,
        'reconcile-injected run rolled up to FAILED, not hung (got '||l_status||')');

    select work_status, substr(error_message, 1, 4000)
      into l_wstatus, l_errmsg
      from dmt_work_queue_tbl
     where run_id = l_run_e and cemli_code = 'MockObject';
    assert(l_wstatus = 'FAILED', 24,
        'work item FAILED from the unhandled reconciler RAISE');
    assert(instr(l_errmsg, 'Reconciliation failed') > 0
       and instr(l_errmsg, 'injected failure at RECONCILE') > 0, 25,
        'reconcile ERROR_MESSAGE captured the raised error (got: '
        ||substr(l_errmsg,1,120)||')');

    dmt_util_pkg.set_config(p_key => 'MOCK_FAIL_STAGE', p_value => 'NONE');

    :passed := :passed + l_passed;
end;
/

-- ------------------------------------------------------------
-- Cleanup -- remove every mock run/queue/log row this script
-- created and leave the injection config inert.
-- ------------------------------------------------------------
declare
    type t_scn is table of varchar2(30);
    l_scenarios t_scn := t_scn('MOCK_ENGINE_A','MOCK_ENGINE_B','MOCK_ENGINE_C1',
                               'MOCK_ENGINE_D1','MOCK_ENGINE_D2','MOCK_ENGINE_E');
begin
    for i in 1 .. l_scenarios.count loop
        delete from dmt_log_tbl
         where run_id in (select run_id from dmt_pipeline_run_tbl
                          where scenario_name = l_scenarios(i));
        delete from dmt_work_queue_tbl
         where run_id in (select run_id from dmt_pipeline_run_tbl
                          where scenario_name = l_scenarios(i));
        delete from dmt_pipeline_run_tbl
         where scenario_name = l_scenarios(i);
    end loop;
    dmt_util_pkg.set_config(p_key => 'MOCK_FAIL_STAGE',  p_value => 'NONE');
    dmt_util_pkg.set_config(p_key => 'MOCK_FAIL_OBJECT', p_value => 'MockObject');
    commit;
end;
/

-- ------------------------------------------------------------
-- Summary -- only reached when every assertion passed
-- ------------------------------------------------------------
begin
    dbms_output.put_line('TEST_QUEUE_ENGINE: '||:passed||' passed, 0 failed');
end;
/

exit success
