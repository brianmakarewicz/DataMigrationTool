-- ============================================================
-- test_misc_receipt_load_failure.sql -- MiscReceipts load failure reaches
-- every record type of the zip (backlog #633).
--
-- What it proves (DMT_DESIGN.html section 5, ERROR_TEXT tag table, the
-- [LOAD_ERROR] row: "every GENERATED row of that ZIP is marked FAILED with
-- this tag"; section 5, "Cross-grain failure shapes every object must
-- handle", shape (d): a job-level load failure reaches every row of the
-- load, all record types):
--   M1  DMT_MISC_RECEIPT_FBDI_GEN_PKG.FAIL_GENERATED_ROWS returns C_SUCCESS
--       and reports every GENERATED row it changed (transactions + lots +
--       serials).
--   M2  no transaction, lot or serial row of the run is left GENERATED.
--   M3  every formerly GENERATED row of all three tables is FAILED carrying
--       the same load error text as the transaction rows.
--   M4  LOADED, STAGED and already-FAILED rows are not touched (a FAILED
--       row keeps exactly its own earlier error).
--   M5  rows of another run are not touched.
--
-- Isolation. Every row this test writes (two synthetic runs and their
-- transaction / lot / serial TFM rows) lives in ONE transaction that is
-- ROLLED BACK at the end (and on any failure). No existing STG or TFM row is
-- read or changed. The only committed side effect is the activity-log entry
-- DMT_UTIL_PKG.LOG writes in its own autonomous transaction; the test deletes
-- exactly those entries (matched on the two synthetic RUN_IDs) after the
-- rollback.
--
-- Run as DMT_OWNER:
--   sql dmt_owner/...@//localhost:1523/FREEPDB1 @test/unit/test_misc_receipt_load_failure.sql
-- ============================================================

whenever sqlerror exit failure rollback
set serveroutput on size unlimited
set feedback off
set define off

variable passed number
variable run1 number
variable run2 number
begin :passed := 0; :run1 := null; :run2 := null; end;
/

declare
    C_ERR    constant varchar2(200) :=
        '[LOAD_ERROR] Loading data to the Fusion interface failed. Check ESS job 0 logs for details.';
    l_passed pls_integer := 0;
    l_run1   number;
    l_run2   number;
    l_rows   number;
    l_code   number;
    l_n      number;

    procedure ok(p_name in varchar2, p_cond in boolean) is
    begin
        if p_cond then
            l_passed := l_passed + 1;
            dbms_output.put_line('PASS '||p_name);
        else
            raise_application_error(-20999, 'FAIL test '||p_name);
        end if;
    end;

    function new_run(p_tag in varchar2) return number is
        l_id number;
    begin
        insert into dmt_pipeline_run_tbl (pipeline_codes, run_type, submitted_by,
                                          cemli_sequence, scenario_name, run_status)
        values ('STANDALONE:MiscReceipts', 'PIPELINE', 'UNIT_TEST_MR_LOADFAIL',
                'MiscReceipts', p_tag, 'IN_PROGRESS')
        returning run_id into l_id;
        return l_id;
    end;

    procedure trx(p_run in number, p_status in varchar2, p_err in varchar2 default null) is
    begin
        insert into dmt_inv_trx_tfm_tbl (run_id, stg_sequence_id, tfm_status, error_text)
        values (p_run, -1, p_status, p_err);
    end;

    procedure lot(p_run in number, p_status in varchar2, p_err in varchar2 default null) is
    begin
        insert into dmt_inv_trx_lots_tfm_tbl (run_id, stg_sequence_id, tfm_status, error_text)
        values (p_run, -1, p_status, p_err);
    end;

    procedure ser(p_run in number, p_status in varchar2, p_err in varchar2 default null) is
    begin
        insert into dmt_inv_trx_serials_tfm_tbl (run_id, stg_sequence_id, tfm_status, error_text)
        values (p_run, -1, p_status, p_err);
    end;
begin
    l_run1 := new_run('UNIT_TEST_MR_LOADFAIL_1');
    l_run2 := new_run('UNIT_TEST_MR_LOADFAIL_2');
    :run1 := l_run1; :run2 := l_run2;

    -- The failed load: 2 transactions, 2 lots, 1 serial were GENERATED into the zip.
    trx(l_run1, 'GENERATED'); trx(l_run1, 'GENERATED');
    lot(l_run1, 'GENERATED'); lot(l_run1, 'GENERATED');
    ser(l_run1, 'GENERATED');
    -- Rows outside the failed zip's GENERATED set.
    trx(l_run1, 'LOADED');
    trx(l_run1, 'STAGED');
    lot(l_run1, 'FAILED', '[PRE_VALIDATION] unit-test own error');
    ser(l_run1, 'LOADED');
    -- Another run's zip.
    trx(l_run2, 'GENERATED'); lot(l_run2, 'GENERATED'); ser(l_run2, 'GENERATED');

    dmt_misc_receipt_fbdi_gen_pkg.fail_generated_rows(
        p_run_id      => l_run1,
        p_error_text  => C_ERR,
        x_rows_failed => l_rows,
        x_error_code  => l_code);

    -- [LOAD_ERROR] row of the tag table: every GENERATED row of the zip.
    ok('M1 C_SUCCESS and 5 rows failed (2 transactions + 2 lots + 1 serial)',
       l_code = dmt_util_pkg.c_success and l_rows = 5);

    select count(*) into l_n from (
        select 1 from dmt_inv_trx_tfm_tbl         where run_id = l_run1 and tfm_status = 'GENERATED'
        union all
        select 1 from dmt_inv_trx_lots_tfm_tbl    where run_id = l_run1 and tfm_status = 'GENERATED'
        union all
        select 1 from dmt_inv_trx_serials_tfm_tbl where run_id = l_run1 and tfm_status = 'GENERATED');
    ok('M2 no transaction, lot or serial row of the run is left GENERATED', l_n = 0);

    select count(*) into l_n from (
        select error_text from dmt_inv_trx_tfm_tbl         where run_id = l_run1 and tfm_status = 'FAILED'
        union all
        select error_text from dmt_inv_trx_lots_tfm_tbl    where run_id = l_run1 and tfm_status = 'FAILED'
                                                          and dbms_lob.instr(error_text, '[PRE_VALIDATION]') = 0
        union all
        select error_text from dmt_inv_trx_serials_tfm_tbl where run_id = l_run1 and tfm_status = 'FAILED')
     where dbms_lob.instr(error_text, C_ERR) > 0;
    ok('M3 all 5 formerly GENERATED rows FAILED with the transaction rows'' load error', l_n = 5);

    select count(*) into l_n from (
        select 1 from dmt_inv_trx_tfm_tbl where run_id = l_run1 and tfm_status = 'LOADED' and error_text is null
        union all
        select 1 from dmt_inv_trx_tfm_tbl where run_id = l_run1 and tfm_status = 'STAGED' and error_text is null
        union all
        select 1 from dmt_inv_trx_lots_tfm_tbl where run_id = l_run1 and tfm_status = 'FAILED'
           and dbms_lob.compare(error_text, to_clob('[PRE_VALIDATION] unit-test own error')) = 0
        union all
        select 1 from dmt_inv_trx_serials_tfm_tbl where run_id = l_run1 and tfm_status = 'LOADED' and error_text is null);
    ok('M4 LOADED, STAGED and already-FAILED rows untouched', l_n = 4);

    select count(*) into l_n from (
        select 1 from dmt_inv_trx_tfm_tbl         where run_id = l_run2 and tfm_status = 'GENERATED'
        union all
        select 1 from dmt_inv_trx_lots_tfm_tbl    where run_id = l_run2 and tfm_status = 'GENERATED'
        union all
        select 1 from dmt_inv_trx_serials_tfm_tbl where run_id = l_run2 and tfm_status = 'GENERATED');
    ok('M5 another run''s rows untouched', l_n = 3);

    :passed := l_passed;
    rollback;
exception
    when others then
        rollback;
        raise;
end;
/

-- Autonomous log entries written for the two synthetic runs.
begin
    delete from dmt_log_tbl where run_id in (:run1, :run2);
    commit;
end;
/

begin
    if :passed <> 5 then
        raise_application_error(-20998, 'test_misc_receipt_load_failure: '||:passed||' of 5 passed');
    end if;
    dbms_output.put_line('test_misc_receipt_load_failure: ALL 5 PASSED');
end;
/
exit
