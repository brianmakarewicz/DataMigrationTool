-- ============================================================
-- test_assets_prepare_log_retry.sql -- backlog #797.
--
-- What it proves (DMT_DESIGN.html section 2, PROPOSED DEFER_RECONCILE note;
-- objects/Assets/README.md "Missing PrepareMassAdditions log: retry"):
--   R1  PrepareMassAdditions ended ERROR and its output has no .log (the real
--       job 10135384 of local run 420, whose output is only the summary .txt):
--       DMT_FA_ASSET_RESULTS_PKG.RECONCILE_BATCH defers the work item --
--       ERROR_MESSAGE '[RECONCILE_DEFER 1] ...', NEXT_POLL_AFTER about
--       ASSET_PREPARE_LOG_RETRY_SECONDS ahead, a DEFER_RECONCILE log entry
--       with "retry 1 of", and no header is settled.
--   R2  a second pass counts on: '[RECONCILE_DEFER 2]'.
--   R3  retries used up ('[RECONCILE_DEFER <max>]'): no further deferral, the
--       headers stay open for the unaccounted sweep (no error is invented),
--       and a WARN log names the missing .log.
--   R4  DEFER_RECONCILE never defers a work item that is not RECONCILING.
--   R5  the job's log IS there (job 10137173 of local run 423): no deferral,
--       the headers named in the log are FAILED with [IMPORT_REPORT].
--
-- Isolation. Uses two finished local runs' real Assets work items (420 item
-- 2952, 423 item 3087), found by their import job ids; everything the test
-- changes on them (work item status, TFM status) is in ONE transaction that is
-- ROLLED BACK at the end and on any failure, and a post-rollback check proves
-- the rows are as before. The Fusion calls are read-only (BIP report, ESS
-- output download as fin_impl). The only committed side effects are the
-- activity-log entries DMT_UTIL_PKG.LOG writes autonomously; the test deletes
-- exactly the entries of those two runs written after it started. If either
-- run is missing locally the script fails (a proof that did not run is not a
-- pass).
--
-- Run as DMT_OWNER:
--   sql dmt_owner/...@//localhost:1523/FREEPDB1 @test/unit/test_assets_prepare_log_retry.sql
-- ============================================================

whenever sqlerror exit failure rollback
set serveroutput on size unlimited
set feedback off
set define off

variable passed number
variable log_start number
begin :passed := 0; select nvl(max(log_id), 0) into :log_start from dmt_log_tbl; end;
/

declare
    C_RUN_NOLOG  constant number := 420;
    C_JOB_NOLOG  constant number := 10135384;
    C_RUN_LOG    constant number := 423;
    C_JOB_LOG    constant number := 10137173;
    l_passed  pls_integer := 0;
    l_q1      number; l_load1 number;
    l_q2      number; l_load2 number;
    l_msg     varchar2(4000);
    l_next    timestamp;
    l_secs    number;
    l_max     number;
    l_open    number;
    l_cnt     number;
    l_try     number;

    procedure ok(p_name in varchar2, p_cond in boolean) is
    begin
        if p_cond then
            l_passed := l_passed + 1;
            dbms_output.put_line('PASS '||p_name);
        else
            raise_application_error(-20999, 'FAIL test '||p_name);
        end if;
    end;

    procedure open_item(p_run in number, p_q in number) is
    begin
        update dmt_work_queue_tbl
           set work_status = 'RECONCILING', error_message = null, next_poll_after = null
         where queue_id = p_q;
        -- Reopen the item's rows the way a fresh reconcile sees them.
        update dmt_fa_asset_hdr_tfm_tbl set tfm_status = 'GENERATED', error_text = null
         where run_id = p_run and work_queue_id = p_q and tfm_status in ('UNACCOUNTED', 'FAILED')
           and (error_text is null or dbms_lob.instr(error_text, '[POST_VALIDATION]') = 0);
        update dmt_fa_asset_book_tfm_tbl set tfm_status = 'GENERATED', error_text = null
         where run_id = p_run and work_queue_id = p_q and tfm_status in ('UNACCOUNTED', 'FAILED')
           and (error_text is null or dbms_lob.instr(error_text, '[POST_VALIDATION]') = 0);
        update dmt_fa_asset_assign_tfm_tbl set tfm_status = 'GENERATED', error_text = null
         where run_id = p_run and work_queue_id = p_q and tfm_status in ('UNACCOUNTED', 'FAILED')
           and (error_text is null or dbms_lob.instr(error_text, '[POST_VALIDATION]') = 0);
    end;

    function open_headers(p_run in number, p_q in number) return number is
        l_n number;
    begin
        select count(*) into l_n from dmt_fa_asset_hdr_tfm_tbl
         where run_id = p_run and work_queue_id = p_q and tfm_status not in ('LOADED', 'FAILED');
        return l_n;
    end;
begin
    select queue_id, to_number(load_ess_job_id) into l_q1, l_load1 from dmt_work_queue_tbl
     where run_id = C_RUN_NOLOG and cemli_code = 'Assets' and import_ess_job_id = to_char(C_JOB_NOLOG);
    select queue_id, to_number(load_ess_job_id) into l_q2, l_load2 from dmt_work_queue_tbl
     where run_id = C_RUN_LOG and cemli_code = 'Assets' and import_ess_job_id = to_char(C_JOB_LOG);
    l_max  := to_number(nvl(dmt_util_pkg.get_config(p_key => 'ASSET_PREPARE_LOG_RETRIES'), '6'));
    l_secs := to_number(nvl(dmt_util_pkg.get_config(p_key => 'ASSET_PREPARE_LOG_RETRY_SECONDS'), '120'));
    ok('R0 config keys seeded (retries '||l_max||', seconds '||l_secs||')', l_max > 0 and l_secs > 0);

    -- R1: no .log -> deferred, nothing settled.
    open_item(C_RUN_NOLOG, l_q1);
    l_open := open_headers(C_RUN_NOLOG, l_q1);
    ok('R1 setup: item '||l_q1||' has open headers ('||l_open||')', l_open > 0);
    dmt_fa_asset_results_pkg.reconcile_batch(C_RUN_NOLOG, l_load1, C_JOB_NOLOG, l_q1);
    select error_message, next_poll_after into l_msg, l_next from dmt_work_queue_tbl where queue_id = l_q1;
    ok('R1 sentinel [RECONCILE_DEFER 1]: '||substr(l_msg, 1, 120), l_msg like '[RECONCILE_DEFER 1] %');
    ok('R1 NEXT_POLL_AFTER about '||l_secs||'s ahead',
       l_next between sys_extract_utc(systimestamp) + numtodsinterval(l_secs - 30, 'SECOND')
                  and sys_extract_utc(systimestamp) + numtodsinterval(l_secs + 5, 'SECOND'));
    select count(*) into l_cnt from dmt_log_tbl
     where log_id > :log_start and run_id = C_RUN_NOLOG and procedure_name = 'DEFER_RECONCILE'
       and dbms_lob.instr(message, 'retry 1 of '||l_max) > 0;
    ok('R1 retry 1 logged with its attempt number', l_cnt = 1);
    ok('R1 no header settled', open_headers(C_RUN_NOLOG, l_q1) = l_open);

    -- R2: next pass counts on.
    dmt_fa_asset_results_pkg.reconcile_batch(C_RUN_NOLOG, l_load1, C_JOB_NOLOG, l_q1);
    select error_message into l_msg from dmt_work_queue_tbl where queue_id = l_q1;
    ok('R2 sentinel [RECONCILE_DEFER 2]', l_msg like '[RECONCILE_DEFER 2] %');

    -- R3: retries used up -> settle as before, WARN names the missing log.
    update dmt_work_queue_tbl set error_message = '[RECONCILE_DEFER '||l_max||'] earlier'
     where queue_id = l_q1;
    dmt_fa_asset_results_pkg.reconcile_batch(C_RUN_NOLOG, l_load1, C_JOB_NOLOG, l_q1);
    select error_message into l_msg from dmt_work_queue_tbl where queue_id = l_q1;
    ok('R3 no further deferral', l_msg = '[RECONCILE_DEFER '||l_max||'] earlier');
    ok('R3 headers left open for the sweep, no invented error', open_headers(C_RUN_NOLOG, l_q1) = l_open);
    select count(*) into l_cnt from dmt_log_tbl
     where log_id > :log_start and run_id = C_RUN_NOLOG and procedure_name = 'APPLY_PREPARE_ERRORS'
       and log_type = 'WARN' and dbms_lob.instr(message, 'has no .log naming the failed assets after '||l_max) > 0;
    ok('R3 WARN log names the missing .log', l_cnt = 1);

    -- R4: an item that is not RECONCILING is never deferred.
    update dmt_work_queue_tbl set work_status = 'DONE', error_message = null where queue_id = l_q1;
    l_try := dmt_queue_worker_pkg.defer_reconcile(l_q1, 'unit test', l_max, l_secs);
    select error_message into l_msg from dmt_work_queue_tbl where queue_id = l_q1;
    ok('R4 not RECONCILING -> 0, item untouched', l_try = 0 and l_msg is null);

    -- R5: the log is there -> no deferral, named headers FAILED [IMPORT_REPORT].
    open_item(C_RUN_LOG, l_q2);
    l_open := open_headers(C_RUN_LOG, l_q2);
    ok('R5 setup: item '||l_q2||' has open headers ('||l_open||')', l_open > 0);
    dmt_fa_asset_results_pkg.reconcile_batch(C_RUN_LOG, l_load2, C_JOB_LOG, l_q2);
    select error_message into l_msg from dmt_work_queue_tbl where queue_id = l_q2;
    ok('R5 no deferral', l_msg is null);
    select count(*) into l_cnt from dmt_fa_asset_hdr_tfm_tbl
     where run_id = C_RUN_LOG and work_queue_id = l_q2 and tfm_status = 'FAILED'
       and dbms_lob.instr(error_text, '[IMPORT_REPORT]') > 0;
    ok('R5 '||l_cnt||' header(s) FAILED with [IMPORT_REPORT]', l_cnt > 0);

    rollback;
    :passed := l_passed;
exception
    when others then
        rollback;
        delete from dmt_log_tbl where log_id > :log_start and run_id in (420, 423);
        commit;
        raise;
end;
/

-- The rollback restored both items; prove it, then drop this test's log entries.
declare
    l_bad number;
begin
    select count(*) into l_bad from dmt_work_queue_tbl
     where run_id in (420, 423) and cemli_code = 'Assets'
       and (work_status = 'RECONCILING' or error_message like '[RECONCILE_DEFER%');
    if l_bad > 0 then
        raise_application_error(-20999, 'FAIL test cleanup: a work item kept the test''s changes');
    end if;
    select count(*) into l_bad from dmt_fa_asset_hdr_tfm_tbl
     where run_id in (420, 423) and tfm_status = 'GENERATED';
    if l_bad > 0 then
        raise_application_error(-20999, 'FAIL test cleanup: TFM rows kept the test''s changes');
    end if;
    delete from dmt_log_tbl where log_id > :log_start and run_id in (420, 423);
    commit;
    dbms_output.put_line('TEST_ASSETS_PREPARE_LOG_RETRY: '||:passed||' passed, 0 failed');
end;
/
