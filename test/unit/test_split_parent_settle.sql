-- ============================================================
-- test_split_parent_settle.sql -- DMT_QUEUE_WORKER_PKG.SETTLE_SPLIT_PARENT
-- (backlog #515, PR #693; proof for backlog #615).
--
-- What it proves (DMT_DESIGN.html section 2, work-item status table:
-- DONE "Item finished and every row is accounted for", FAILED "Item ended
-- with at least one row unaccounted for"; owner decision 2026-10-08 on
-- split parents: a spawn-per-partition parent is DONE when it splits, and
-- is set FAILED once its children settle if rows of the run that no child
-- took are unaccounted):
--   S1  a DONE parent whose run has no unowned rows stays DONE, no message.
--   S2  a parent that is not DONE is never touched.
--   S3  while any child is still open the parent is left DONE (a later
--       child settles it), even when unowned rows exist.
--   S4  THE FAILED PATH: every child terminal and the run has N unowned,
--       unaccounted rows of the object -> parent FAILED, COMPLETED_AT set,
--       ERROR_MESSAGE starts with N and says no child took the rows, and a
--       WARN activity-log entry names the parent.
--   S5  the call never changes a TFM row (ACCOUNT_ROWS counts identical
--       before and after).
--
-- Isolation. Everything this test writes to the work queue and run tables
-- is synthetic and lives in ONE transaction that is ROLLED BACK at the end
-- (and on any failure). No STG or TFM row is inserted, updated or deleted:
-- S3/S4 attach synthetic parent/child queue rows to an existing local run
-- that already has unowned, unaccounted rows of a split object (found by a
-- read-only ACCOUNT_ROWS scan), so SETTLE_SPLIT_PARENT counts real rows
-- without anything being written to them. The only committed side effect
-- is the activity-log entry DMT_UTIL_PKG.LOG writes in its own autonomous
-- transaction; the test deletes exactly those entries (matched on the
-- synthetic parent's QUEUE_ID) after the rollback. If no local run has such
-- rows, S3/S4 report SKIPPED and the script still fails (a proof that did
-- not run is not a pass).
--
-- Run as DMT_OWNER:
--   sql dmt_owner/...@//localhost:1523/FREEPDB1 @test/unit/test_split_parent_settle.sql
-- ============================================================

whenever sqlerror exit failure rollback
set serveroutput on size unlimited
set feedback off
set define off

variable passed number
variable fail_parent number
variable fail_run number
begin :passed := 0; :fail_parent := null; :fail_run := null; end;
/

declare
    l_passed  pls_integer := 0;
    l_run     number;      -- synthetic run (S1, S2)
    l_real    number;      -- existing run with unowned rows (S3, S4)
    l_cemli   varchar2(60);
    l_parent  number;
    l_child1  number;
    l_child2  number;
    l_status  varchar2(30);
    l_msg     varchar2(4000);
    l_done_at timestamp;
    l_t number; l_l number; l_f number; l_u number; l_a number;
    l_t2 number; l_l2 number; l_f2 number; l_u2 number; l_a2 number;
    l_logs    number;

    procedure ok(p_name in varchar2, p_cond in boolean) is
    begin
        if p_cond then
            l_passed := l_passed + 1;
            dbms_output.put_line('PASS '||p_name);
        else
            raise_application_error(-20999, 'FAIL test '||p_name);
        end if;
    end;

    function new_item(p_run in number, p_cemli in varchar2, p_status in varchar2,
                      p_parent in number, p_pkey in varchar2) return number is
        l_id number;
    begin
        insert into dmt_work_queue_tbl (run_id, pipeline, cemli_code, sort_order,
                                        work_status, partition_key, parent_queue_id)
        values (p_run, 'STANDALONE', p_cemli, 1, p_status, p_pkey, p_parent)
        returning queue_id into l_id;
        return l_id;
    end;

    procedure item(p_id in number) is
    begin
        select work_status, error_message, completed_at into l_status, l_msg, l_done_at
          from dmt_work_queue_tbl where queue_id = p_id;
    end;
begin
    -- ---------------- S1 / S2: synthetic run, no TFM rows ----------------
    select min(s.cemli_code) into l_cemli
      from dmt_cemli_split_cfg s
     where s.child_partition_column is not null;
    ok('S0 a spawn-per-partition object is registered', l_cemli is not null);

    insert into dmt_pipeline_run_tbl (pipeline_codes, run_type, submitted_by,
                                      cemli_sequence, scenario_name, run_status)
    values ('STANDALONE:'||l_cemli, 'PIPELINE', 'UNIT_TEST_SPLIT_SETTLE',
            l_cemli, 'UNIT_TEST_SPLIT_SETTLE', 'IN_PROGRESS')
    returning run_id into l_run;

    -- spec, work-item status table, DONE row: a split parent is DONE when it
    -- splits; with no unowned rows nothing is unaccounted, so it stays DONE.
    l_parent := new_item(l_run, l_cemli, 'DONE', null, null);
    l_child1 := new_item(l_run, l_cemli, 'DONE', l_parent, 'K1');
    l_child2 := new_item(l_run, l_cemli, 'FAILED', l_parent, 'K2');
    dmt_queue_worker_pkg.settle_split_parent(p_parent_queue_id => l_parent);
    item(l_parent);
    ok('S1 parent with no unowned rows stays DONE, no message',
       l_status = 'DONE' and l_msg is null);

    -- SETTLE_SPLIT_PARENT spec: "It never writes DONE" and only a parent
    -- still claiming DONE needs the check.
    update dmt_work_queue_tbl set work_status = 'FAILED', error_message = 'unit-test marker'
     where queue_id = l_parent;
    dmt_queue_worker_pkg.settle_split_parent(p_parent_queue_id => l_parent);
    item(l_parent);
    ok('S2 a parent that is not DONE is untouched',
       l_status = 'FAILED' and l_msg = 'unit-test marker');

    -- ---------------- S3 / S4: existing run with unowned rows ----------------
    for c in (select q.run_id, q.cemli_code
                from dmt_work_queue_tbl q
                join dmt_cemli_split_cfg s on s.cemli_code = q.cemli_code
                                          and s.child_partition_column is not null
               where q.parent_queue_id is null
                 and q.partition_key is null
               group by q.run_id, q.cemli_code
               order by q.run_id desc
               fetch first 200 rows only) loop
        dmt_queue_worker_pkg.account_rows(c.run_id, c.cemli_code, l_t, l_l, l_f, l_u,
                                          x_awaiting_base => l_a, p_unowned_only => 'Y');
        if l_u > 0 then
            l_real := c.run_id; l_cemli := c.cemli_code;
            exit;
        end if;
    end loop;

    if l_real is null then
        raise_application_error(-20999, 'FAIL test S3/S4 SKIPPED: no local run has unowned, '
            ||'unaccounted rows of a split object, so the FAILED path could not be exercised');
    end if;
    dbms_output.put_line('using run '||l_real||' / '||l_cemli||': '||l_u
                         ||' unowned unaccounted of '||l_t||' unowned rows');

    -- SETTLE_SPLIT_PARENT spec: "Once every child ... is terminal"; an open
    -- child means a later child settles it.
    l_parent := new_item(l_real, l_cemli, 'DONE', null, null);
    :fail_parent := l_parent; :fail_run := l_real;
    l_child1 := new_item(l_real, l_cemli, 'DONE', l_parent, 'K1');
    l_child2 := new_item(l_real, l_cemli, 'PROCESSING', l_parent, 'K2');
    dmt_queue_worker_pkg.settle_split_parent(p_parent_queue_id => l_parent);
    item(l_parent);
    ok('S3 parent stays DONE while a child is still open', l_status = 'DONE' and l_msg is null);

    -- spec, work-item status table, FAILED row: "Item ended with at least one
    -- row unaccounted for" -- the unowned rows were never sent to Fusion.
    update dmt_work_queue_tbl set work_status = 'FAILED' where queue_id = l_child2;
    dmt_queue_worker_pkg.settle_split_parent(p_parent_queue_id => l_parent);
    item(l_parent);
    ok('S4a every child terminal + unowned rows -> parent FAILED', l_status = 'FAILED');
    ok('S4b message carries the unowned count and says no child took the rows',
       l_msg like l_u||' record(s) transformed by this run were not taken by any partition child%');
    ok('S4c COMPLETED_AT is set', l_done_at is not null);
    select count(*) into l_logs from dmt_log_tbl
     where run_id = l_real and log_type = 'WARN'
       and procedure_name = 'SETTLE_SPLIT_PARENT'
       and dbms_lob.instr(message, 'split parent '||l_parent||' FAILED') > 0;
    ok('S4d a WARN activity-log entry names the parent', l_logs = 1);

    dmt_queue_worker_pkg.account_rows(l_real, l_cemli, l_t2, l_l2, l_f2, l_u2,
                                      x_awaiting_base => l_a2, p_unowned_only => 'Y');
    ok('S5 no TFM row changed', l_t2 = l_t and l_l2 = l_l and l_f2 = l_f and l_u2 = l_u);

    :passed := l_passed;
    rollback;
exception
    when others then
        rollback;
        if l_real is not null and :fail_parent is not null then
            delete from dmt_log_tbl
             where run_id = l_real
               and procedure_name = 'SETTLE_SPLIT_PARENT'
               and dbms_lob.instr(message, 'split parent '||:fail_parent||' ') > 0;
            commit;
        end if;
        raise;
end;
/

-- The synthetic rows are gone; remove only the log entries the autonomous
-- LOG call wrote for the synthetic parent.
declare
    l_left number;
begin
    select count(*) into l_left from dmt_pipeline_run_tbl
     where submitted_by = 'UNIT_TEST_SPLIT_SETTLE';
    if l_left > 0 then
        raise_application_error(-20999, 'FAIL test cleanup: synthetic run rows survived the rollback');
    end if;
    if :fail_parent is not null then
        select count(*) into l_left from dmt_work_queue_tbl where queue_id = :fail_parent;
        if l_left > 0 then
            raise_application_error(-20999, 'FAIL test cleanup: synthetic queue rows survived the rollback');
        end if;
        delete from dmt_log_tbl
         where run_id = :fail_run
           and procedure_name = 'SETTLE_SPLIT_PARENT'
           and dbms_lob.instr(message, 'split parent '||:fail_parent||' ') > 0;
        commit;
    end if;
    dbms_output.put_line('TEST_SPLIT_PARENT_SETTLE: '||:passed||' passed, 0 failed');
end;
/
