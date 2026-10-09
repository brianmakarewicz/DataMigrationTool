-- ============================================================
-- test_cancel_run.sql -- DMT_QUEUE_PKG.CANCEL_RUN and the orphaned-
-- preflight recovery (backlog #635 / #565, owner-approved 2026-10-08).
--
-- What it proves (DMT_DESIGN.html section 2, run-status and work-item
-- status tables, CANCELLED rows; Entry points, CANCEL_RUN row):
--   * CANCEL_RUN refuses a blank reason, an unknown run and a run that
--     already finished, and leaves them untouched.
--   * On an active run it stops the run's running scheduler job, marks
--     every not-yet-terminal work item CANCELLED, keeps a DONE item DONE,
--     sets the run CANCELLED with who / when / why, writes a WARN entry
--     to the activity log, and never touches a TFM row.
--   * A second CANCEL_RUN on the same run is a harmless no-op.
--   * The one-active-run-per-object submission check blocks while the run
--     is active and ignores it once it is CANCELLED.
--   * RECOVER_ORPHAN_PREFLIGHT releases a PREFLIGHTING claim whose
--     DMT_PF_ job is gone the first time, and fails the run (items FAILED,
--     PREFLIGHT_STATUS FAILED, clear message) the second time.
--
-- No heartbeat ticks are run and nothing reaches Fusion: the test builds
-- its own run rows directly with work statuses the heartbeat does not act
-- on (PROCESSING, PENDING behind an unmet dependency, DONE), and its one
-- scheduler job only sleeps. Rows are scoped by the MOCK_CANCEL_* scenario
-- names and removed at start and end.
--
-- Run as DMT_OWNER:
--   sql dmt_owner/...@//localhost:1523/FREEPDB1 @test/unit/test_cancel_run.sql
-- ============================================================

whenever sqlerror exit failure
set serveroutput on size unlimited
set feedback off
set define off

-- MockObject / MockChild registrations (idempotent MERGE) for the
-- SUBMIT_OBJECTS guard check.
@@setup_mock_objects.sql

variable passed number
begin :passed := 0; end;
/

-- ------------------------------------------------------------
-- Clean up residue from an earlier (failed) run of this script.
-- ------------------------------------------------------------
declare
    l_code number;
begin
    for r in (select run_id from dmt_pipeline_run_tbl
              where scenario_name in ('MOCK_CANCEL_A','MOCK_CANCEL_B',
                                      'MOCK_CANCEL_C','MOCK_CANCEL_D')
                and run_status in ('QUEUED','IN_PROGRESS')) loop
        dmt_queue_pkg.cancel_run(p_run_id => r.run_id,
                                 p_reason => 'test_cancel_run pre-clean',
                                 p_cancelled_by => 'UNIT_TEST',
                                 x_error_code => l_code);
    end loop;
    delete from dmt_mock_tfm_tbl where run_id in (select run_id from dmt_pipeline_run_tbl
        where scenario_name in ('MOCK_CANCEL_A','MOCK_CANCEL_B','MOCK_CANCEL_C','MOCK_CANCEL_D'));
    delete from dmt_log_tbl where run_id in (select run_id from dmt_pipeline_run_tbl
        where scenario_name in ('MOCK_CANCEL_A','MOCK_CANCEL_B','MOCK_CANCEL_C','MOCK_CANCEL_D'));
    delete from dmt_work_queue_tbl where run_id in (select run_id from dmt_pipeline_run_tbl
        where scenario_name in ('MOCK_CANCEL_A','MOCK_CANCEL_B','MOCK_CANCEL_C','MOCK_CANCEL_D'));
    delete from dmt_pipeline_run_tbl
     where scenario_name in ('MOCK_CANCEL_A','MOCK_CANCEL_B','MOCK_CANCEL_C','MOCK_CANCEL_D');
    commit;
end;
/

declare
    l_passed   pls_integer := 0;
    l_run_a    number;
    l_run_c    number;
    l_run_d    number;
    l_run_b    number;
    l_q_proc   number;
    l_q_pend   number;
    l_q_done   number;
    l_job      varchar2(30);
    l_code     number;
    l_cnt      pls_integer;
    l_status   varchar2(30);
    l_pf       varchar2(30);
    l_msg      varchar2(4000);
    l_done_dt  timestamp;
    l_reject   varchar2(4000);

    procedure assert (p_cond boolean, p_num pls_integer, p_name varchar2) is
    begin
        if p_cond then
            l_passed := l_passed + 1;
            dbms_output.put_line('PASS  '||lpad(p_num,2)||'  '||p_name);
        else
            raise_application_error(-20999, 'FAIL test '||p_num||': '||p_name);
        end if;
    end assert;

    function new_run (p_scenario varchar2, p_status varchar2, p_preflight varchar2)
        return number is
        l_id number;
    begin
        insert into dmt_pipeline_run_tbl
            (pipeline_codes, run_type, submitted_by, run_status, cemli_sequence,
             scenario_name, run_mode, prefix, preflight_status)
        values ('STANDALONE:MockObject', 'STANDALONE', 'UNIT_TEST', p_status,
                'MockObject,MockChild', p_scenario, 'NEW', NULL, p_preflight)
        returning run_id into l_id;
        return l_id;
    end new_run;

    function new_item (p_run number, p_code varchar2, p_status varchar2,
                       p_sort number, p_depends varchar2 default null) return number is
        l_id number;
    begin
        insert into dmt_work_queue_tbl
            (run_id, pipeline, cemli_code, sort_order, depends_on, work_status, started_at)
        values (p_run, 'STANDALONE', p_code, p_sort, p_depends, p_status,
                case when p_status <> 'PENDING' then systimestamp end)
        returning queue_id into l_id;
        return l_id;
    end new_item;

    function item_status (p_queue number) return varchar2 is
        l_s varchar2(30);
    begin
        select work_status into l_s from dmt_work_queue_tbl where queue_id = p_queue;
        return l_s;
    end item_status;

    function job_exists (p_job varchar2) return boolean is
        l_n pls_integer;
    begin
        select count(*) into l_n from user_scheduler_jobs where job_name = p_job;
        return l_n > 0;
    end job_exists;

begin
    -- ----------------------------------------------------------
    -- Fixture A: an IN_PROGRESS run (preflight OK) with one item
    -- PROCESSING (its DMT_WQ_ job is a real scheduler job that sleeps),
    -- one PENDING behind it, and one already DONE. Plus one GENERATED
    -- mock TFM row for the run.
    -- ----------------------------------------------------------
    l_run_a  := new_run('MOCK_CANCEL_A', 'IN_PROGRESS', 'OK');
    l_q_done := new_item(l_run_a, 'MockObject', 'DONE', 1);
    l_q_proc := new_item(l_run_a, 'MockObject', 'PROCESSING', 2);
    l_q_pend := new_item(l_run_a, 'MockChild', 'PENDING', 3, 'MockObject');
    insert into dmt_mock_tfm_tbl (run_id, cemli_code, record_key, tfm_status)
    values (l_run_a, 'MockObject', 'CANCEL-TEST-ROW', 'GENERATED');
    commit;

    l_job := 'DMT_WQ_' || l_q_proc;
    dbms_scheduler.create_job(job_name   => l_job,
                              job_type   => 'PLSQL_BLOCK',
                              job_action => 'BEGIN DBMS_SESSION.SLEEP(300); END;',
                              enabled    => TRUE,
                              auto_drop  => TRUE);
    for i in 1 .. 30 loop
        select count(*) into l_cnt from user_scheduler_running_jobs where job_name = l_job;
        exit when l_cnt > 0;
        dbms_session.sleep(1);
    end loop;
    assert(l_cnt = 1, 1, 'fixture: the run''s DMT_WQ_ job is running');

    -- Section 2 concurrency rule: an object may be part of only one active
    -- run -- run A (IN_PROGRESS, MockObject PROCESSING) must block a new one.
    begin
        dmt_scheduler_pkg.submit_objects(p_objects => 'MockObject',
                                         p_scenario_name => 'MOCK_CANCEL_B',
                                         p_submitted_by => 'UNIT_TEST',
                                         x_run_id => l_run_b);
        l_reject := null;
    exception when others then
        l_reject := sqlerrm;
    end;
    assert(l_reject is not null and instr(l_reject, 'ORA-20105') > 0, 2,
           'active run A blocks a second MockObject submission (ORA-20105)');

    -- ----------------------------------------------------------
    -- Refusals leave everything untouched.
    -- ----------------------------------------------------------
    dmt_queue_pkg.cancel_run(p_run_id => l_run_a, p_reason => '   ',
                             p_cancelled_by => 'UNIT_TEST', x_error_code => l_code);
    select run_status into l_status from dmt_pipeline_run_tbl where run_id = l_run_a;
    assert(l_code = dmt_util_pkg.c_error and l_status = 'IN_PROGRESS', 3,
           'blank reason is refused; run stays IN_PROGRESS');

    dmt_queue_pkg.cancel_run(p_run_id => -1, p_reason => 'no such run',
                             p_cancelled_by => 'UNIT_TEST', x_error_code => l_code);
    assert(l_code = dmt_util_pkg.c_error, 4, 'unknown run is refused');

    -- ----------------------------------------------------------
    -- Cancel run A.
    -- ----------------------------------------------------------
    dmt_queue_pkg.cancel_run(p_run_id => l_run_a,
                             p_reason => 'unit test: run can never finish',
                             p_cancelled_by => 'UNIT_TEST',
                             x_error_code => l_code);
    assert(l_code = dmt_util_pkg.c_success, 5, 'CANCEL_RUN returns success');

    -- Section 2 run-status table, CANCELLED row: the run ends CANCELLED,
    -- stamped with who / when / why.
    select run_status, error_message, completed_date
      into l_status, l_msg, l_done_dt
      from dmt_pipeline_run_tbl where run_id = l_run_a;
    assert(l_status = 'CANCELLED', 6, 'run A is CANCELLED');
    assert(l_done_dt is not null, 7, 'run A has a COMPLETED_DATE');
    assert(instr(l_msg, 'Cancelled by UNIT_TEST at ') = 1
           and instr(l_msg, 'unit test: run can never finish') > 0, 8,
           'run A ERROR_MESSAGE records who, when and why');

    -- Section 2 work-item status table, CANCELLED row: every item that was
    -- not yet terminal is CANCELLED; a DONE item keeps its verdict.
    assert(item_status(l_q_proc) = 'CANCELLED', 9, 'PROCESSING item is CANCELLED');
    assert(item_status(l_q_pend) = 'CANCELLED', 10, 'PENDING item is CANCELLED');
    assert(item_status(l_q_done) = 'DONE', 11, 'DONE item stays DONE');
    select error_message into l_msg from dmt_work_queue_tbl where queue_id = l_q_proc;
    assert(instr(l_msg, 'unit test: run can never finish') > 0, 12,
           'cancelled item carries the reason');

    assert(not job_exists(l_job), 13, 'the run''s DMT_WQ_ scheduler job was stopped and dropped');

    select count(*) into l_cnt from dmt_mock_tfm_tbl
     where run_id = l_run_a and record_key = 'CANCEL-TEST-ROW'
       and tfm_status = 'GENERATED' and error_text is null;
    assert(l_cnt = 1, 14, 'TFM row untouched (still GENERATED, no error text)');

    select count(*) into l_cnt from dmt_log_tbl
     where run_id = l_run_a and package_name = 'DMT_QUEUE_PKG'
       and procedure_name = 'CANCEL_RUN' and log_type = 'WARN';
    assert(l_cnt = 1, 15, 'one WARN activity-log entry records the cancel');

    -- Idempotent: cancelling again is a no-op success.
    dmt_queue_pkg.cancel_run(p_run_id => l_run_a, p_reason => 'again',
                             p_cancelled_by => 'UNIT_TEST', x_error_code => l_code);
    select run_status into l_status from dmt_pipeline_run_tbl where run_id = l_run_a;
    assert(l_code = dmt_util_pkg.c_success and l_status = 'CANCELLED', 16,
           'second CANCEL_RUN is a no-op success');

    -- The per-object guard ignores a CANCELLED run: a new MockObject run
    -- is accepted now (then cancelled straight away -- it is a fixture).
    begin
        dmt_scheduler_pkg.submit_objects(p_objects => 'MockObject',
                                         p_scenario_name => 'MOCK_CANCEL_B',
                                         p_submitted_by => 'UNIT_TEST',
                                         x_run_id => l_run_b);
        l_reject := null;
    exception when others then
        l_reject := sqlerrm;
    end;
    if l_run_b is not null then
        dmt_queue_pkg.cancel_run(p_run_id => l_run_b, p_reason => 'unit test fixture',
                                 p_cancelled_by => 'UNIT_TEST', x_error_code => l_code);
    end if;
    assert(l_reject is null and l_run_b is not null, 17,
           'CANCELLED run A no longer blocks a MockObject submission');

    -- A finished run cannot be cancelled.
    l_run_c := new_run('MOCK_CANCEL_C', 'COMPLETED', 'OK');
    commit;
    dmt_queue_pkg.cancel_run(p_run_id => l_run_c, p_reason => 'should be refused',
                             p_cancelled_by => 'UNIT_TEST', x_error_code => l_code);
    select run_status into l_status from dmt_pipeline_run_tbl where run_id = l_run_c;
    assert(l_code = dmt_util_pkg.c_error and l_status = 'COMPLETED', 18,
           'COMPLETED run is refused and stays COMPLETED');

    -- ----------------------------------------------------------
    -- Orphaned preflight (backlog #565): QUEUED + PREFLIGHTING with no
    -- DMT_PF_ job. First recovery releases the claim; second fails the run.
    -- ----------------------------------------------------------
    l_run_d := new_run('MOCK_CANCEL_D', 'QUEUED', 'PREFLIGHTING');
    l_q_pend := new_item(l_run_d, 'MockObject', 'PENDING', 1, 'MockChild');
    commit;
    assert(not job_exists('DMT_PF_' || l_run_d), 19, 'fixture: no DMT_PF_ job for run D');

    dmt_queue_pkg.recover_orphan_preflight(p_run_id => l_run_d, x_error_code => l_code);
    select preflight_status into l_pf from dmt_pipeline_run_tbl where run_id = l_run_d;
    -- Simulate the re-spawned preflight dying the same way: claim it again.
    update dmt_pipeline_run_tbl set preflight_status = 'PREFLIGHTING'
     where run_id = l_run_d and preflight_status is null;
    commit;
    assert(l_code = dmt_util_pkg.c_success and l_pf is null, 20,
           'first orphan recovery releases the PREFLIGHTING claim');

    dmt_queue_pkg.recover_orphan_preflight(p_run_id => l_run_d, x_error_code => l_code);
    select preflight_status into l_pf from dmt_pipeline_run_tbl where run_id = l_run_d;
    select error_message into l_msg from dmt_work_queue_tbl where queue_id = l_q_pend;
    assert(l_code = dmt_util_pkg.c_success and l_pf = 'FAILED', 21,
           'second orphan recovery sets PREFLIGHT_STATUS FAILED');
    -- Section 2 work-item status table, FAILED row: "the item hit an
    -- unrecoverable infrastructure error".
    assert(item_status(l_q_pend) = 'FAILED'
           and instr(l_msg, 'DMT_PF_' || l_run_d) > 0, 22,
           'run D item FAILED with a message naming the dead preflight job');

    -- A run whose preflight is not orphaned is left alone.
    dmt_queue_pkg.recover_orphan_preflight(p_run_id => l_run_c, x_error_code => l_code);
    select run_status, preflight_status into l_status, l_pf
      from dmt_pipeline_run_tbl where run_id = l_run_c;
    assert(l_status = 'COMPLETED' and l_pf = 'OK', 23,
           'recovery ignores a run that is not an orphaned preflight');

    :passed := l_passed;
end;
/

-- ------------------------------------------------------------
-- Remove the test rows (all are this script's own fixtures).
-- ------------------------------------------------------------
declare
    l_code number;
begin
    for r in (select run_id from dmt_pipeline_run_tbl
              where scenario_name in ('MOCK_CANCEL_A','MOCK_CANCEL_B',
                                      'MOCK_CANCEL_C','MOCK_CANCEL_D')
                and run_status in ('QUEUED','IN_PROGRESS')) loop
        dmt_queue_pkg.cancel_run(p_run_id => r.run_id,
                                 p_reason => 'test_cancel_run cleanup',
                                 p_cancelled_by => 'UNIT_TEST',
                                 x_error_code => l_code);
    end loop;
    -- the refusal entry test 4 wrote for the non-existent run id -1
    delete from dmt_log_tbl where run_id = -1 and package_name = 'DMT_QUEUE_PKG'
       and procedure_name = 'CANCEL_RUN';
    delete from dmt_mock_tfm_tbl where run_id in (select run_id from dmt_pipeline_run_tbl
        where scenario_name in ('MOCK_CANCEL_A','MOCK_CANCEL_B','MOCK_CANCEL_C','MOCK_CANCEL_D'));
    delete from dmt_log_tbl where run_id in (select run_id from dmt_pipeline_run_tbl
        where scenario_name in ('MOCK_CANCEL_A','MOCK_CANCEL_B','MOCK_CANCEL_C','MOCK_CANCEL_D'));
    delete from dmt_work_queue_tbl where run_id in (select run_id from dmt_pipeline_run_tbl
        where scenario_name in ('MOCK_CANCEL_A','MOCK_CANCEL_B','MOCK_CANCEL_C','MOCK_CANCEL_D'));
    delete from dmt_pipeline_run_tbl
     where scenario_name in ('MOCK_CANCEL_A','MOCK_CANCEL_B','MOCK_CANCEL_C','MOCK_CANCEL_D');
    commit;
end;
/

begin
    dbms_output.put_line('TEST_CANCEL_RUN: '||:passed||' passed, 0 failed');
end;
/

exit success
