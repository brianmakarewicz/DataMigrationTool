-- ============================================================
-- test_queue_engine.sql -- Stage C engine tests (DMT_DESIGN.html
-- section 2: heartbeat, work-queue states, catalog-driven dispatch,
-- one-active-run-per-object, halt-vs-continue, failure handling,
-- the accounting gate, the run-status rollup, and the offline
-- poll-timeout path).
--
-- Uses the Mock engine-test objects (test/unit/setup_mock_objects.sql
-- + DMT_MOCK_PKG + DMT_MOCK_TFM_TBL): MockObject / MockChild in the
-- TEST pipeline, EXEC_MODE = LOCAL, so the whole walk runs with NO
-- Fusion instance. Each mock stage writes a DMT_LOG_TBL marker row
-- proving it ran via the registry dispatch; the data phase writes
-- MOCK_ROW_COUNT GENERATED rows into DMT_MOCK_TFM_TBL so the
-- accounting gate and rollup count real rows. DMT_CONFIG_TBL
-- MOCK_FAIL_STAGE / MOCK_FAIL_OBJECT inject failures and
-- MOCK_RECON_OUTCOME / MOCK_ROW_COUNT steer reconcile outcomes.
--
-- SPEC-CITED ASSERTIONS (proposed rule "Engine assertions quote the
-- spec status tables", 2026-07-08): every status assertion carries a
-- comment citing the DMT_DESIGN.html status-table row that makes the
-- expected value correct.
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

-- E1 (2026-07-08): the mock registrations are test-setup, not part of the
-- production install -- register them (idempotent MERGE) before the walk.
@@setup_mock_objects.sql

variable passed number

begin :passed := 0; end;
/

-- ------------------------------------------------------------
-- Pre-clean: remove residue from any earlier (failed) run and
-- reset the mock config keys to inert values.
-- ------------------------------------------------------------
declare
    type t_scn is table of varchar2(30);
    l_scenarios t_scn := t_scn('MOCK_ENGINE_A','MOCK_ENGINE_B','MOCK_ENGINE_C1',
                               'MOCK_ENGINE_D1','MOCK_ENGINE_D2','MOCK_ENGINE_E',
                               'MOCK_ENGINE_F','MOCK_ENGINE_G','MOCK_ENGINE_H',
                               'MOCK_ENGINE_I');
begin
    for i in 1 .. l_scenarios.count loop
        delete from dmt_mock_tfm_tbl
         where run_id in (select run_id from dmt_pipeline_run_tbl
                          where scenario_name = l_scenarios(i));
        delete from dmt_log_tbl
         where run_id in (select run_id from dmt_pipeline_run_tbl
                          where scenario_name = l_scenarios(i));
        delete from dmt_work_queue_tbl
         where run_id in (select run_id from dmt_pipeline_run_tbl
                          where scenario_name = l_scenarios(i));
        delete from dmt_pipeline_run_tbl
         where scenario_name = l_scenarios(i);
    end loop;
    dmt_util_pkg.set_config(p_key => 'MOCK_FAIL_STAGE',    p_value => 'NONE');
    dmt_util_pkg.set_config(p_key => 'MOCK_FAIL_OBJECT',   p_value => 'MockObject');
    dmt_util_pkg.set_config(p_key => 'MOCK_ROW_COUNT',     p_value => '2');
    dmt_util_pkg.set_config(p_key => 'MOCK_RECON_OUTCOME', p_value => 'LOADED');
    dmt_util_pkg.set_config(p_key => 'ESS_POLL_TIMEOUT_MINUTES', p_value => '30');
    -- Restore the registry edge in case an earlier failed run of scenario (k)
    -- left the deliberately-bad token in place.
    update dmt_pipeline_def_tbl set depends_on = 'MockObject'
     where cemli_code = 'MockChild';
    commit;
end;
/

-- ------------------------------------------------------------
-- The engine walk -- one block, sequential scenarios (a)-(k)
-- ------------------------------------------------------------
declare
    l_passed  pls_integer := 0;
    l_run_a   number;
    l_run_b   number;
    l_run_c1  number;
    l_run_d1  number;
    l_run_d2  number;
    l_run_e   number;
    l_run_f   number;
    l_run_g   number;
    l_run_h   number;
    l_run_i   number;
    l_queue_i number;
    l_run_dup number;
    l_status  varchar2(30);
    l_wstatus varchar2(30);
    l_errmsg  varchar2(4000);
    l_cnt     pls_integer;
    l_cnt2    pls_integer;
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
    -- Terminal set = the Overview run-status table's terminal rows:
    -- COMPLETED, COMPLETED_ERRORS, FAILED, NO_ROWS_PROCESSED.
    procedure wait_for_run (p_run_id in number, x_status out varchar2) is
        l_max_ticks constant pls_integer := 90;
    begin
        for i in 1 .. l_max_ticks loop
            dmt_queue_pkg.heartbeat_tick;
            dbms_session.sleep(2);
            select run_status into x_status
              from dmt_pipeline_run_tbl where run_id = p_run_id;
            exit when x_status in ('COMPLETED','COMPLETED_ERRORS','FAILED',
                                   'NO_ROWS_PROCESSED');
        end loop;
        if x_status not in ('COMPLETED','COMPLETED_ERRORS','FAILED',
                            'NO_ROWS_PROCESSED') then
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
    -- Work-item status table, READY row: "Dependencies satisfied;
    -- eligible for pickup by the heartbeat."
    assert(l_wstatus = 'READY', 2,
        'MockObject work item created READY (no dependencies)');

    wait_for_run(l_run_a, l_status);
    -- Run-status table, COMPLETED row: "All work items finished; every
    -- record accounted for with no failures." (2 mock rows, reconciled
    -- LOADED by MOCK_RECON_OUTCOME = LOADED.)
    assert(l_status = 'COMPLETED', 3,
        'run rolled up to COMPLETED (got '||l_status||')');

    select work_status into l_wstatus
      from dmt_work_queue_tbl
     where run_id = l_run_a and cemli_code = 'MockObject';
    -- Work-item status table, DONE row: "Item finished and every row is
    -- accounted for -- each row ended either LOADED (confirmed in Fusion
    -- base tables) or FAILED with a reportable error."
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
    -- Run-status table, FAILED row: "The run itself could not finish --
    -- an unaccounted-for record or infrastructure failure." The injected
    -- transform exception is an infrastructure failure -> item FAILED ->
    -- run FAILED.
    assert(l_status = 'FAILED', 9,
        'transform-injected run rolled up to FAILED (got '||l_status||')');

    select work_status, substr(error_message, 1, 4000)
      into l_wstatus, l_errmsg
      from dmt_work_queue_tbl
     where run_id = l_run_b and cemli_code = 'MockObject';
    -- Work-item status table, FAILED row: "... or the item hit an
    -- unrecoverable infrastructure error."
    assert(l_wstatus = 'FAILED', 10, 'MockObject work item ended FAILED');
    -- Section 5 tag table, [TRANSFORM_ERROR] row: "Exception raised
    -- during STG->TFM transformation."
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
    -- (c) 14-16. One-active-run-per-object (section 2, decided
    --     2026-07-07): a second submission naming MockObject while
    --     the first run is active is REJECTED at submission with a
    --     message naming the object and the blocking run. The check
    --     is serialized on the USE_PREFIX config-row lock (A9a).
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

    -- 40 (engine re-review ITEM 1, 2026-07-08; numbered after the
    -- pre-existing assertions): DMT_SUBMIT_RUN_V2 — the standalone
    -- submission entry point the archived APEX export calls — is now
    -- a thin wrapper over DMT_SCHEDULER_PKG.SUBMIT_PIPELINE, so it
    -- must enforce the same one-active-run-per-object rule instead
    -- of bypassing it as its old duplicated body did.
    l_reject := null;
    begin
        dmt_submit_run_v2(
            p_pipeline_codes => 'STANDALONE:MockObject',
            p_scenario_name  => 'MOCK_ENGINE_C1',
            p_submitted_by   => 'TEST_QUEUE_ENGINE',
            x_run_id         => l_run_dup);
    exception
        when others then l_reject := sqlerrm;
    end;
    assert(l_reject is not null and instr(l_reject, 'MockObject') > 0
       and instr(l_reject, 'active run #'||l_run_c1) > 0, 40,
        'DMT_SUBMIT_RUN_V2 rejected while MockObject run active — wrapper '
        ||'enforces the one-active-run rule (got: '
        ||substr(nvl(l_reject,'no error raised'),1,150)||')');

    wait_for_run(l_run_c1, l_status);
    -- Run-status table, COMPLETED row (clean walk again).
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
    -- Work-item status table, SKIPPED row: "Not run because a
    -- dependency failed."
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
    -- Run-status table, FAILED row: "The run itself could not finish --
    -- an unaccounted-for record or infrastructure failure." MockObject
    -- ended FAILED (infrastructure exception), so the run is FAILED even
    -- though MockChild finished DONE. COMPLETED_ERRORS (its table row:
    -- "All work items finished; some rows ended FAILED (with reportable
    -- errors)") requires every work item to have FINISHED -- a FAILED
    -- work item is not that. (This assertion previously pinned the
    -- inverted COMPLETED_ERRORS -- A1/A2 engine-review finding.)
    assert(l_status = 'FAILED', 20,
        'CONTINUE: run with a FAILED work item rolled up to FAILED per the '
        ||'run-status table (got '||l_status||')');

    select work_status into l_wstatus
      from dmt_work_queue_tbl
     where run_id = l_run_d2 and cemli_code = 'MockChild';
    -- Section 2 promote rule (decided 2026-07-07): with On Failure =
    -- Continue, dependents launch when predecessors are terminal (DONE
    -- or FAILED). Work-item DONE row for the child itself.
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
    -- Run-status table, FAILED row (infrastructure failure in the
    -- reconcile child job).
    assert(l_status = 'FAILED', 23,
        'reconcile-injected run rolled up to FAILED, not hung (got '||l_status||')');

    select work_status, substr(error_message, 1, 4000)
      into l_wstatus, l_errmsg
      from dmt_work_queue_tbl
     where run_id = l_run_e and cemli_code = 'MockObject';
    assert(l_wstatus = 'FAILED', 24,
        'work item FAILED from the unhandled reconciler RAISE');
    -- Section 5 tag table, [RECONCILE_ERROR] row: "Reconciliation itself
    -- cannot account for the row" (the mock's injected reconcile failure
    -- carries the section-5 tag -- no invented [RECON_ERROR] vocabulary).
    assert(instr(l_errmsg, 'Reconciliation failed') > 0
       and instr(l_errmsg, '[RECONCILE_ERROR]') > 0
       and instr(l_errmsg, 'injected failure at RECONCILE') > 0, 25,
        'reconcile ERROR_MESSAGE captured the raised, section-5-tagged error (got: '
        ||substr(l_errmsg,1,120)||')');

    dmt_util_pkg.set_config(p_key => 'MOCK_FAIL_STAGE', p_value => 'NONE');

    -- ----------------------------------------------------------
    -- (f) 26-28. Rows-failed-with-errors rollup: reconcile marks
    --     every row FAILED + [FUSION_ERROR] (accounted!), so the
    --     ITEM is DONE and the RUN is COMPLETED_ERRORS.
    -- ----------------------------------------------------------
    dmt_util_pkg.set_config(p_key => 'MOCK_RECON_OUTCOME', p_value => 'FAILED_ERROR');

    dmt_scheduler_pkg.submit_objects(
        p_objects       => 'MockObject',
        p_scenario_name => 'MOCK_ENGINE_F',
        p_submitted_by  => 'TEST_QUEUE_ENGINE',
        x_run_id        => l_run_f);
    wait_for_run(l_run_f, l_status);

    select work_status into l_wstatus
      from dmt_work_queue_tbl
     where run_id = l_run_f and cemli_code = 'MockObject';
    -- Work-item status table, DONE row: "Rows may have failed; DONE
    -- means nothing is unexplained." + the accounting rule: "Row
    -- failures alone never fail the work item -- unexplained rows do."
    assert(l_wstatus = 'DONE', 26,
        'item with all rows FAILED-with-errors is DONE (accounting rule; got '
        ||l_wstatus||')');
    -- Run-status table, COMPLETED_ERRORS row: "All work items finished;
    -- some rows ended FAILED (with reportable errors)."
    assert(l_status = 'COMPLETED_ERRORS', 27,
        'run rolled up to COMPLETED_ERRORS from ROW outcomes (got '||l_status||')');
    select count(*) into l_cnt
      from dmt_mock_tfm_tbl
     where run_id = l_run_f and cemli_code = 'MockObject'
       and status = 'FAILED'
       and dbms_lob.instr(error_text, '[FUSION_ERROR]') > 0;
    -- Section 5 tag table, [FUSION_ERROR] row: "Row rejected by the
    -- Fusion import -- interface-table error text."
    assert(l_cnt = 2, 28,
        'both mock rows FAILED with reportable [FUSION_ERROR] text (got '||l_cnt||')');

    dmt_util_pkg.set_config(p_key => 'MOCK_RECON_OUTCOME', p_value => 'LOADED');

    -- ----------------------------------------------------------
    -- (g) 29-30. Zero rows selected: the run finishes and every
    --     work item selected zero rows -> NO_ROWS_PROCESSED; the
    --     zero-row ITEM itself is simply DONE with zero counts.
    -- ----------------------------------------------------------
    dmt_util_pkg.set_config(p_key => 'MOCK_ROW_COUNT', p_value => '0');

    dmt_scheduler_pkg.submit_objects(
        p_objects       => 'MockObject',
        p_scenario_name => 'MOCK_ENGINE_G',
        p_submitted_by  => 'TEST_QUEUE_ENGINE',
        x_run_id        => l_run_g);
    wait_for_run(l_run_g, l_status);

    select work_status into l_wstatus
      from dmt_work_queue_tbl
     where run_id = l_run_g and cemli_code = 'MockObject';
    -- Run-status table, NO_ROWS_PROCESSED row: "An individual zero-row
    -- item is simply DONE with zero counts (grey tile) (decided
    -- 2026-07-07)."
    assert(l_wstatus = 'DONE', 29,
        'zero-row work item is DONE with zero counts (got '||l_wstatus||')');
    -- Run-status table, NO_ROWS_PROCESSED row: "Run finished and every
    -- work item selected zero rows -- nothing in the whole run matched
    -- the scenario/mode."
    assert(l_status = 'NO_ROWS_PROCESSED', 30,
        'zero-row run rolled up to NO_ROWS_PROCESSED (got '||l_status||')');

    dmt_util_pkg.set_config(p_key => 'MOCK_ROW_COUNT', p_value => '2');

    -- ----------------------------------------------------------
    -- (h) 31-33. Accounting gate: reconcile leaves every row
    --     GENERATED (no positive success, no positive failure) --
    --     the item must be FAILED, never DONE.
    -- ----------------------------------------------------------
    dmt_util_pkg.set_config(p_key => 'MOCK_RECON_OUTCOME', p_value => 'UNACCOUNTED');

    dmt_scheduler_pkg.submit_objects(
        p_objects       => 'MockObject',
        p_scenario_name => 'MOCK_ENGINE_H',
        p_submitted_by  => 'TEST_QUEUE_ENGINE',
        x_run_id        => l_run_h);
    wait_for_run(l_run_h, l_status);

    select work_status, substr(error_message, 1, 4000)
      into l_wstatus, l_errmsg
      from dmt_work_queue_tbl
     where run_id = l_run_h and cemli_code = 'MockObject';
    -- The accounting rule (Overview): "A work item is DONE if and only
    -- if every record is accounted for (base-table LOADED or interface-
    -- errored FAILED); it is FAILED only if any record is unaccounted
    -- for." Two rows left GENERATED = unaccounted -> FAILED.
    assert(l_wstatus = 'FAILED', 31,
        'item with unaccounted rows FAILED at the accounting gate (got '||l_wstatus||')');
    assert(instr(l_errmsg, 'unaccounted') > 0, 32,
        'accounting-gate message reports the unaccounted rows (got: '
        ||substr(l_errmsg,1,120)||')');
    -- Run-status table, FAILED row: "an unaccounted-for record" fails
    -- the run.
    assert(l_status = 'FAILED', 33,
        'run with unaccounted records rolled up to FAILED (got '||l_status||')');

    dmt_util_pkg.set_config(p_key => 'MOCK_RECON_OUTCOME', p_value => 'LOADED');

    -- ----------------------------------------------------------
    -- (i) 34-37. Poll timeout, fully offline: a work item stuck in
    --     AWAITING_LOAD past ESS_POLL_TIMEOUT_MINUTES has its
    --     GENERATED rows marked FAILED [LOAD_ERROR] and routes to
    --     RECONCILING -- the timeout is a trigger, never a verdict;
    --     the item then settles by the accounting rule alone.
    --     (The queue/run rows are fabricated directly: the mock is
    --     LOCAL and never enters AWAITING_LOAD on its own.)
    -- ----------------------------------------------------------
    insert into dmt_pipeline_run_tbl
        (pipeline_codes, run_type, submitted_by, cemli_sequence,
         scenario_name, run_mode, run_status)
    values
        ('STANDALONE:MockObject', 'STANDALONE', 'TEST_QUEUE_ENGINE', 'MockObject',
         'MOCK_ENGINE_I', 'NEW', 'IN_PROGRESS')
    returning run_id into l_run_i;
    insert into dmt_work_queue_tbl
        (run_id, pipeline, cemli_code, sort_order, work_status,
         load_ess_job_id, poll_count, started_at)
    values
        (l_run_i, 'TEST', 'MockObject', 1, 'AWAITING_LOAD',
         '999999', 5, systimestamp)
    returning queue_id into l_queue_i;
    insert into dmt_mock_tfm_tbl (run_id, cemli_code, record_key, status)
        select l_run_i, 'MockObject', 'MockObject-'||level, 'GENERATED'
          from dual connect by level <= 2;
    commit;

    -- POLL_COUNT (5) >= ESS_POLL_TIMEOUT_MINUTES (1) -> timeout fires
    -- before any Fusion call (section 2 Timeouts: "ESS_POLL_TIMEOUT_
    -- MINUTES in DMT_CONFIG_TBL (default 30), maintained at the
    -- administrator level").
    dmt_util_pkg.set_config(p_key => 'ESS_POLL_TIMEOUT_MINUTES', p_value => '1');
    dmt_queue_worker_pkg.poll_one(l_queue_i);

    select count(*) into l_cnt
      from dmt_mock_tfm_tbl
     where run_id = l_run_i and status = 'FAILED'
       and dbms_lob.instr(error_text, '[LOAD_ERROR]') > 0;
    -- Section 2 Timeouts: "when it expires, every GENERATED row of the
    -- file is marked FAILED with a [LOAD_ERROR]-tagged timeout message
    -- (the all-or-nothing rule)."
    assert(l_cnt = 2, 34,
        'timeout marked both GENERATED rows FAILED with [LOAD_ERROR] (got '||l_cnt||')');

    select work_status into l_wstatus
      from dmt_work_queue_tbl where queue_id = l_queue_i;
    -- Section 2 Timeouts: "and reconciliation still runs" -- the item
    -- routes to RECONCILING (work-item status table, RECONCILING row),
    -- never straight to a verdict from the timer.
    assert(l_wstatus = 'RECONCILING', 35,
        'timeout routed the item to RECONCILING, not to a terminal verdict (got '
        ||l_wstatus||')');

    wait_for_run(l_run_i, l_status);
    select work_status into l_wstatus
      from dmt_work_queue_tbl where queue_id = l_queue_i;
    -- Section 2 Timeouts: "The work item ends DONE or FAILED by the
    -- accounting rule alone, never directly from the timer." All rows
    -- are FAILED with reportable [LOAD_ERROR] text = accounted -> DONE.
    assert(l_wstatus = 'DONE', 36,
        'post-timeout item settled DONE by the accounting rule (got '||l_wstatus||')');
    -- Run-status table, COMPLETED_ERRORS row (rows ended FAILED with
    -- reportable errors; all items finished).
    assert(l_status = 'COMPLETED_ERRORS', 37,
        'post-timeout run rolled up to COMPLETED_ERRORS (got '||l_status||')');

    dmt_util_pkg.set_config(p_key => 'ESS_POLL_TIMEOUT_MINUTES', p_value => '30');

    -- ----------------------------------------------------------
    -- (j) 38. ALL mode without a scenario is rejected at submit --
    --     Overview run-mode table, ALL row: "ALL (requires a
    --     scenario)".
    -- ----------------------------------------------------------
    l_reject := null;
    begin
        dmt_scheduler_pkg.submit_objects(
            p_objects       => 'MockObject',
            p_scenario_name => null,
            p_run_mode      => 'ALL',
            p_submitted_by  => 'TEST_QUEUE_ENGINE',
            x_run_id        => l_run_dup);
    exception
        when others then l_reject := sqlerrm;
    end;
    assert(l_reject is not null
       and instr(l_reject, 'ALL run mode requires a scenario') > 0, 38,
        'ALL mode without a scenario rejected at submission (got: '
        ||substr(nvl(l_reject,'no error raised'),1,150)||')');

    -- ----------------------------------------------------------
    -- (k) 39. DEPENDS_ON unknown token is rejected at submit (A13):
    --     section 6 -- DEPENDS_ON is "comma-separated canonical
    --     CEMLI codes"; a registry typo must fail loudly instead of
    --     running with the dependency silently ignored.
    -- ----------------------------------------------------------
    update dmt_pipeline_def_tbl set depends_on = 'NoSuchObject'
     where cemli_code = 'MockChild';
    commit;
    l_reject := null;
    begin
        dmt_scheduler_pkg.submit_objects(
            p_objects       => 'MockChild',
            p_scenario_name => 'MOCK_ENGINE_A',
            p_submitted_by  => 'TEST_QUEUE_ENGINE',
            x_run_id        => l_run_dup);
    exception
        when others then l_reject := sqlerrm;
    end;
    update dmt_pipeline_def_tbl set depends_on = 'MockObject'
     where cemli_code = 'MockChild';
    commit;
    assert(l_reject is not null
       and instr(l_reject, 'NoSuchObject') > 0
       and instr(l_reject, 'not a registered CEMLI code') > 0, 39,
        'unknown DEPENDS_ON token rejected at submission (got: '
        ||substr(nvl(l_reject,'no error raised'),1,150)||')');

    :passed := :passed + l_passed;
end;
/

-- ------------------------------------------------------------
-- Cleanup -- remove every mock run/queue/log/TFM row this script
-- created and leave the mock config keys inert.
-- ------------------------------------------------------------
declare
    type t_scn is table of varchar2(30);
    l_scenarios t_scn := t_scn('MOCK_ENGINE_A','MOCK_ENGINE_B','MOCK_ENGINE_C1',
                               'MOCK_ENGINE_D1','MOCK_ENGINE_D2','MOCK_ENGINE_E',
                               'MOCK_ENGINE_F','MOCK_ENGINE_G','MOCK_ENGINE_H',
                               'MOCK_ENGINE_I');
begin
    for i in 1 .. l_scenarios.count loop
        delete from dmt_mock_tfm_tbl
         where run_id in (select run_id from dmt_pipeline_run_tbl
                          where scenario_name = l_scenarios(i));
        delete from dmt_log_tbl
         where run_id in (select run_id from dmt_pipeline_run_tbl
                          where scenario_name = l_scenarios(i));
        delete from dmt_work_queue_tbl
         where run_id in (select run_id from dmt_pipeline_run_tbl
                          where scenario_name = l_scenarios(i));
        delete from dmt_pipeline_run_tbl
         where scenario_name = l_scenarios(i);
    end loop;
    dmt_util_pkg.set_config(p_key => 'MOCK_FAIL_STAGE',    p_value => 'NONE');
    dmt_util_pkg.set_config(p_key => 'MOCK_FAIL_OBJECT',   p_value => 'MockObject');
    dmt_util_pkg.set_config(p_key => 'MOCK_ROW_COUNT',     p_value => '2');
    dmt_util_pkg.set_config(p_key => 'MOCK_RECON_OUTCOME', p_value => 'LOADED');
    dmt_util_pkg.set_config(p_key => 'ESS_POLL_TIMEOUT_MINUTES', p_value => '30');
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
