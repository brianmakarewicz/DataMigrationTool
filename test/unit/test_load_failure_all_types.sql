-- ============================================================
-- test_load_failure_all_types.sql -- a failed load reaches every record type
-- of the zip for Projects (backlog #672), Assets (#673) and Blanket POs (#674).
--
-- What it proves (DMT_DESIGN.html section 5, ERROR_TEXT tag table, the
-- [LOAD_ERROR] row: "every GENERATED row of that ZIP is marked FAILED with
-- this tag"; section 5, "Cross-grain failure shapes every object must
-- handle", shape (d): a job-level load failure reaches every row of the
-- load, all record types). Each object's FAIL_GENERATED_ROWS is the procedure
-- DMT_LOADER_PKG's synchronous load-failure path calls (fin_mark_generated_failed
-- for Projects / Assets, po_mark_bu_failed for Blanket POs).
--
--   Projects (DMT_PROJECT_FBDI_GEN_PKG.FAIL_GENERATED_ROWS)
--   P1  C_SUCCESS and every GENERATED row changed (projects + tasks + team
--       members + transaction controls).
--   P2  no row of the run in any of the four tables is left GENERATED.
--   P3  every formerly GENERATED row is FAILED carrying the same load error.
--   P4  LOADED, STAGED and already-FAILED rows untouched (own error kept).
--   P5  rows of another run untouched.
--
--   Assets (DMT_FA_ASSET_FBDI_GEN_PKG.FAIL_GENERATED_ROWS, book partition)
--   A1  C_SUCCESS and every GENERATED row of the failed book changed
--       (headers + books + assignments).
--   A2  no row of the failed book is left GENERATED in any of the three tables.
--   A3  every formerly GENERATED row of the failed book is FAILED carrying the
--       same load error.
--   A4  the other book's GENERATED rows (its own zip) are untouched.
--   A5  LOADED and already-FAILED rows untouched; another run untouched.
--   A6  p_book NULL (standalone, all books) fails every GENERATED row of the run.
--
--   Blanket POs (DMT_BLANKET_PO_FBDI_GEN_PKG.FAIL_GENERATED_ROWS, BU partition)
--   B1  C_SUCCESS and every GENERATED row of the failed BU's blanket zip
--       changed (agreement headers + agreement lines).
--   B2  no blanket header or line of the failed BU is left GENERATED.
--   B3  every formerly GENERATED row is FAILED carrying the same load error.
--   B4  the other BU's blanket rows, and a standard PO of the same BU (another
--       object's zip, sharing the PO TFM tables), are untouched.
--   B5  LOADED and already-FAILED rows untouched; another run untouched.
--
-- Isolation. Every row this test writes (three synthetic runs and their TFM
-- rows) lives in ONE transaction that is ROLLED BACK at the end (and on any
-- failure). No existing STG or TFM row is read or changed. The only committed
-- side effect is the activity-log entry DMT_UTIL_PKG.LOG writes in its own
-- autonomous transaction; the test deletes exactly those entries (matched on
-- the synthetic RUN_IDs) after the rollback.
--
-- Run as DMT_OWNER:
--   sql dmt_owner/...@//localhost:1523/FREEPDB1 @test/unit/test_load_failure_all_types.sql
-- ============================================================

whenever sqlerror exit failure rollback
set serveroutput on size unlimited
set feedback off
set define off

variable passed number
variable run1 number
variable run2 number
variable run3 number
begin :passed := 0; :run1 := null; :run2 := null; :run3 := null; end;
/

declare
    C_ERR    constant varchar2(200) :=
        '[LOAD_ERROR] Loading data to the Fusion interface failed. Check ESS job 0 logs for details.';
    C_OWN    constant varchar2(100) := '[PRE_VALIDATION] unit-test own error';
    C_BPA    constant varchar2(60)  := 'Blanket Purchase Agreement';
    C_SPO    constant varchar2(60)  := 'Standard Purchase Order';
    l_passed pls_integer := 0;
    l_run1   number;
    l_run2   number;
    l_run3   number;
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
        values ('UNIT_TEST', 'PIPELINE', 'UNIT_TEST_LOADFAIL_ALL_TYPES',
                'UNIT_TEST', p_tag, 'IN_PROGRESS')
        returning run_id into l_id;
        return l_id;
    end;

    -- Projects record types
    procedure prj(p_run number, p_status varchar2, p_err varchar2 default null) is
    begin insert into dmt_pjf_projects_tfm_tbl (run_id, stg_sequence_id, tfm_status, error_text)
          values (p_run, -1, p_status, p_err); end;
    procedure tsk(p_run number, p_status varchar2, p_err varchar2 default null) is
    begin insert into dmt_pjf_tasks_tfm_tbl (run_id, stg_sequence_id, tfm_status, error_text)
          values (p_run, -1, p_status, p_err); end;
    procedure tm(p_run number, p_status varchar2, p_err varchar2 default null) is
    begin insert into dmt_pjf_team_members_tfm_tbl (run_id, stg_sequence_id, tfm_status, error_text)
          values (p_run, -1, p_status, p_err); end;
    procedure txc(p_run number, p_status varchar2, p_err varchar2 default null) is
    begin insert into dmt_pjc_txn_controls_tfm_tbl (run_id, stg_sequence_id, tfm_status, error_text)
          values (p_run, -1, p_status, p_err); end;

    -- Assets record types (book scope rides on ASSET_NUMBER, as GENERATE_FBDI does)
    procedure ahdr(p_run number, p_asset varchar2, p_status varchar2, p_err varchar2 default null) is
    begin insert into dmt_fa_asset_hdr_tfm_tbl (run_id, stg_sequence_id, asset_number, tfm_status, error_text)
          values (p_run, -1, p_asset, p_status, p_err); end;
    procedure abook(p_run number, p_asset varchar2, p_book varchar2, p_status varchar2, p_err varchar2 default null) is
    begin insert into dmt_fa_asset_book_tfm_tbl (run_id, stg_sequence_id, asset_number, book_type_code, tfm_status, error_text)
          values (p_run, -1, p_asset, p_book, p_status, p_err); end;
    procedure aasg(p_run number, p_asset varchar2, p_status varchar2, p_err varchar2 default null) is
    begin insert into dmt_fa_asset_assign_tfm_tbl (run_id, stg_sequence_id, asset_number, tfm_status, error_text)
          values (p_run, -1, p_asset, p_status, p_err); end;

    -- Blanket PO record types (headers carry style + BU; lines link by header key)
    procedure poh(p_run number, p_key varchar2, p_bu varchar2, p_style varchar2, p_status varchar2, p_err varchar2 default null) is
    begin insert into dmt_po_headers_int_tfm_tbl (run_id, stg_sequence_id, interface_header_key, prc_bu_name,
                                                  style_display_name, tfm_status, error_text)
          values (p_run, -1, p_key, p_bu, p_style, p_status, p_err); end;
    procedure pol(p_run number, p_key varchar2, p_status varchar2, p_err varchar2 default null) is
    begin insert into dmt_po_lines_int_tfm_tbl (run_id, stg_sequence_id, interface_header_key, tfm_status, error_text)
          values (p_run, -1, p_key, p_status, p_err); end;

    function failed_with_load_error(p_tbl varchar2, p_run number, p_where varchar2 default '1=1') return number is
        l_c number;
    begin
        execute immediate 'select count(*) from '||p_tbl||' where run_id = :r and tfm_status = ''FAILED'''
            ||' and dbms_lob.instr(error_text, :e) > 0 and '||p_where
            into l_c using p_run, C_ERR;
        return l_c;
    end;

    function cnt(p_tbl varchar2, p_run number, p_status varchar2, p_where varchar2 default '1=1') return number is
        l_c number;
    begin
        execute immediate 'select count(*) from '||p_tbl||' where run_id = :r and tfm_status = :s and '||p_where
            into l_c using p_run, p_status;
        return l_c;
    end;
begin
    l_run1 := new_run('UNIT_TEST_LOADFAIL_ALL_TYPES_1');
    l_run2 := new_run('UNIT_TEST_LOADFAIL_ALL_TYPES_2');
    l_run3 := new_run('UNIT_TEST_LOADFAIL_ALL_TYPES_3');
    :run1 := l_run1; :run2 := l_run2; :run3 := l_run3;

    -- ======================= Projects (#672) =======================
    -- The failed load: 1 project, 2 tasks, 1 team member, 1 transaction control GENERATED.
    prj(l_run1, 'GENERATED'); tsk(l_run1, 'GENERATED'); tsk(l_run1, 'GENERATED');
    tm(l_run1, 'GENERATED');  txc(l_run1, 'GENERATED');
    -- Outside the failed zip's GENERATED set.
    prj(l_run1, 'LOADED'); tsk(l_run1, 'STAGED'); tm(l_run1, 'FAILED', C_OWN); txc(l_run1, 'LOADED');
    -- Another run's zip.
    prj(l_run2, 'GENERATED'); tsk(l_run2, 'GENERATED'); tm(l_run2, 'GENERATED'); txc(l_run2, 'GENERATED');

    dmt_project_fbdi_gen_pkg.fail_generated_rows(
        p_run_id => l_run1, p_error_text => C_ERR, x_rows_failed => l_rows, x_error_code => l_code);

    ok('P1 C_SUCCESS and 5 rows failed (1 project + 2 tasks + 1 team member + 1 txn control)',
       l_code = dmt_util_pkg.c_success and l_rows = 5);
    ok('P2 no project, task, team member or txn control row of the run left GENERATED',
       cnt('dmt_pjf_projects_tfm_tbl', l_run1, 'GENERATED') + cnt('dmt_pjf_tasks_tfm_tbl', l_run1, 'GENERATED')
     + cnt('dmt_pjf_team_members_tfm_tbl', l_run1, 'GENERATED') + cnt('dmt_pjc_txn_controls_tfm_tbl', l_run1, 'GENERATED') = 0);
    ok('P3 all 5 formerly GENERATED rows FAILED with the project rows'' load error',
       failed_with_load_error('dmt_pjf_projects_tfm_tbl', l_run1) = 1
       and failed_with_load_error('dmt_pjf_tasks_tfm_tbl', l_run1) = 2
       and failed_with_load_error('dmt_pjf_team_members_tfm_tbl', l_run1) = 1
       and failed_with_load_error('dmt_pjc_txn_controls_tfm_tbl', l_run1) = 1);
    select count(*) into l_n from (
        select 1 from dmt_pjf_projects_tfm_tbl     where run_id = l_run1 and tfm_status = 'LOADED' and error_text is null
        union all
        select 1 from dmt_pjf_tasks_tfm_tbl        where run_id = l_run1 and tfm_status = 'STAGED' and error_text is null
        union all
        select 1 from dmt_pjf_team_members_tfm_tbl where run_id = l_run1 and tfm_status = 'FAILED'
           and dbms_lob.compare(error_text, to_clob(C_OWN)) = 0
        union all
        select 1 from dmt_pjc_txn_controls_tfm_tbl where run_id = l_run1 and tfm_status = 'LOADED' and error_text is null);
    ok('P4 LOADED, STAGED and already-FAILED rows untouched', l_n = 4);
    ok('P5 another run''s rows untouched',
       cnt('dmt_pjf_projects_tfm_tbl', l_run2, 'GENERATED') + cnt('dmt_pjf_tasks_tfm_tbl', l_run2, 'GENERATED')
     + cnt('dmt_pjf_team_members_tfm_tbl', l_run2, 'GENERATED') + cnt('dmt_pjc_txn_controls_tfm_tbl', l_run2, 'GENERATED') = 4);

    -- ======================= Assets (#673) =======================
    -- Failed book 'UT BOOK A': assets UTA1, UTA2 (header + book + assignment each GENERATED).
    ahdr(l_run1, 'UTA1', 'GENERATED'); abook(l_run1, 'UTA1', 'UT BOOK A', 'GENERATED'); aasg(l_run1, 'UTA1', 'GENERATED');
    ahdr(l_run1, 'UTA2', 'GENERATED'); abook(l_run1, 'UTA2', 'UT BOOK A', 'GENERATED'); aasg(l_run1, 'UTA2', 'GENERATED');
                                                                                        aasg(l_run1, 'UTA2', 'GENERATED');
    -- Same book, outside the GENERATED set: a LOADED asset and an already-FAILED assignment.
    ahdr(l_run1, 'UTA3', 'LOADED'); abook(l_run1, 'UTA3', 'UT BOOK A', 'LOADED'); aasg(l_run1, 'UTA3', 'FAILED', C_OWN);
    -- Another book of the same run (its own zip / load job): must stay GENERATED.
    ahdr(l_run1, 'UTB1', 'GENERATED'); abook(l_run1, 'UTB1', 'UT BOOK B', 'GENERATED'); aasg(l_run1, 'UTB1', 'GENERATED');
    -- Another run.
    ahdr(l_run2, 'UTA1', 'GENERATED'); abook(l_run2, 'UTA1', 'UT BOOK A', 'GENERATED'); aasg(l_run2, 'UTA1', 'GENERATED');

    dmt_fa_asset_fbdi_gen_pkg.fail_generated_rows(
        p_run_id => l_run1, p_book => 'UT BOOK A', p_error_text => C_ERR,
        x_rows_failed => l_rows, x_error_code => l_code);

    ok('A1 C_SUCCESS and 7 rows of the failed book failed (2 headers + 2 books + 3 assignments)',
       l_code = dmt_util_pkg.c_success and l_rows = 7);
    ok('A2 no header, book or assignment row of the failed book left GENERATED',
       cnt('dmt_fa_asset_hdr_tfm_tbl',    l_run1, 'GENERATED', 'asset_number like ''UTA%''')
     + cnt('dmt_fa_asset_book_tfm_tbl',   l_run1, 'GENERATED', 'asset_number like ''UTA%''')
     + cnt('dmt_fa_asset_assign_tfm_tbl', l_run1, 'GENERATED', 'asset_number like ''UTA%''') = 0);
    ok('A3 all 7 formerly GENERATED rows of the book FAILED with the same load error',
       failed_with_load_error('dmt_fa_asset_hdr_tfm_tbl',    l_run1, 'asset_number in (''UTA1'',''UTA2'')') = 2
       and failed_with_load_error('dmt_fa_asset_book_tfm_tbl',   l_run1, 'asset_number in (''UTA1'',''UTA2'')') = 2
       and failed_with_load_error('dmt_fa_asset_assign_tfm_tbl', l_run1, 'asset_number in (''UTA1'',''UTA2'')') = 3);
    ok('A4 the other book''s GENERATED rows untouched (header + book + assignment)',
       cnt('dmt_fa_asset_hdr_tfm_tbl',    l_run1, 'GENERATED', 'asset_number = ''UTB1''')
     + cnt('dmt_fa_asset_book_tfm_tbl',   l_run1, 'GENERATED', 'asset_number = ''UTB1''')
     + cnt('dmt_fa_asset_assign_tfm_tbl', l_run1, 'GENERATED', 'asset_number = ''UTB1''') = 3);
    select count(*) into l_n from (
        select 1 from dmt_fa_asset_hdr_tfm_tbl    where run_id = l_run1 and asset_number = 'UTA3' and tfm_status = 'LOADED' and error_text is null
        union all
        select 1 from dmt_fa_asset_book_tfm_tbl   where run_id = l_run1 and asset_number = 'UTA3' and tfm_status = 'LOADED' and error_text is null
        union all
        select 1 from dmt_fa_asset_assign_tfm_tbl where run_id = l_run1 and asset_number = 'UTA3' and tfm_status = 'FAILED'
           and dbms_lob.compare(error_text, to_clob(C_OWN)) = 0
        union all
        select 1 from dmt_fa_asset_hdr_tfm_tbl    where run_id = l_run2 and tfm_status = 'GENERATED'
        union all
        select 1 from dmt_fa_asset_book_tfm_tbl   where run_id = l_run2 and tfm_status = 'GENERATED'
        union all
        select 1 from dmt_fa_asset_assign_tfm_tbl where run_id = l_run2 and tfm_status = 'GENERATED');
    ok('A5 LOADED and already-FAILED rows untouched; another run untouched', l_n = 6);

    -- Standalone path (no partition): every GENERATED row of the run, every book.
    dmt_fa_asset_fbdi_gen_pkg.fail_generated_rows(
        p_run_id => l_run1, p_book => null, p_error_text => C_ERR,
        x_rows_failed => l_rows, x_error_code => l_code);
    ok('A6 p_book NULL fails the remaining book''s 3 GENERATED rows; none left GENERATED in the run',
       l_code = dmt_util_pkg.c_success and l_rows = 3
       and cnt('dmt_fa_asset_hdr_tfm_tbl', l_run1, 'GENERATED') + cnt('dmt_fa_asset_book_tfm_tbl', l_run1, 'GENERATED')
         + cnt('dmt_fa_asset_assign_tfm_tbl', l_run1, 'GENERATED') = 0
       and failed_with_load_error('dmt_fa_asset_assign_tfm_tbl', l_run1, 'asset_number = ''UTB1''') = 1);

    -- ======================= Blanket POs (#674) =======================
    -- Run 3 (its own run, so the Assets/Projects rows above cannot interfere).
    -- Failed BU 'UT BU 1': blanket UTK1 (2 lines) and UTK2 (1 line) GENERATED.
    poh(l_run3, 'UTK1', 'UT BU 1', C_BPA, 'GENERATED'); pol(l_run3, 'UTK1', 'GENERATED'); pol(l_run3, 'UTK1', 'GENERATED');
    poh(l_run3, 'UTK2', 'UT BU 1', C_BPA, 'GENERATED'); pol(l_run3, 'UTK2', 'GENERATED');
    -- Same BU, outside the GENERATED set: a LOADED blanket with a LOADED line and an already-FAILED line.
    poh(l_run3, 'UTK3', 'UT BU 1', C_BPA, 'LOADED');    pol(l_run3, 'UTK3', 'LOADED'); pol(l_run3, 'UTK3', 'FAILED', C_OWN);
    -- Same BU, a standard PO (another object's zip in the shared PO tables).
    poh(l_run3, 'UTS1', 'UT BU 1', C_SPO, 'GENERATED'); pol(l_run3, 'UTS1', 'GENERATED');
    -- Another BU's blanket (its own zip / load job).
    poh(l_run3, 'UTK9', 'UT BU 2', C_BPA, 'GENERATED'); pol(l_run3, 'UTK9', 'GENERATED');
    -- Another run, same BU.
    poh(l_run2, 'UTK1', 'UT BU 1', C_BPA, 'GENERATED'); pol(l_run2, 'UTK1', 'GENERATED');

    dmt_blanket_po_fbdi_gen_pkg.fail_generated_rows(
        p_run_id => l_run3, p_prc_bu_name => 'UT BU 1', p_error_text => C_ERR,
        x_rows_failed => l_rows, x_error_code => l_code);

    ok('B1 C_SUCCESS and 5 rows failed (2 agreement headers + 3 agreement lines)',
       l_code = dmt_util_pkg.c_success and l_rows = 5);
    ok('B2 no blanket header or line of the failed BU left GENERATED',
       cnt('dmt_po_headers_int_tfm_tbl', l_run3, 'GENERATED', 'interface_header_key in (''UTK1'',''UTK2'')')
     + cnt('dmt_po_lines_int_tfm_tbl',   l_run3, 'GENERATED', 'interface_header_key in (''UTK1'',''UTK2'')') = 0);
    ok('B3 all 5 formerly GENERATED rows FAILED with the header rows'' load error',
       failed_with_load_error('dmt_po_headers_int_tfm_tbl', l_run3, 'interface_header_key in (''UTK1'',''UTK2'')') = 2
       and failed_with_load_error('dmt_po_lines_int_tfm_tbl', l_run3, 'interface_header_key in (''UTK1'',''UTK2'')') = 3);
    ok('B4 the other BU''s blanket and the same BU''s standard PO untouched (2 headers + 2 lines GENERATED)',
       cnt('dmt_po_headers_int_tfm_tbl', l_run3, 'GENERATED', 'interface_header_key in (''UTS1'',''UTK9'')') = 2
       and cnt('dmt_po_lines_int_tfm_tbl', l_run3, 'GENERATED', 'interface_header_key in (''UTS1'',''UTK9'')') = 2);
    select count(*) into l_n from (
        select 1 from dmt_po_headers_int_tfm_tbl where run_id = l_run3 and interface_header_key = 'UTK3' and tfm_status = 'LOADED' and error_text is null
        union all
        select 1 from dmt_po_lines_int_tfm_tbl   where run_id = l_run3 and interface_header_key = 'UTK3' and tfm_status = 'LOADED' and error_text is null
        union all
        select 1 from dmt_po_lines_int_tfm_tbl   where run_id = l_run3 and interface_header_key = 'UTK3' and tfm_status = 'FAILED'
           and dbms_lob.compare(error_text, to_clob(C_OWN)) = 0
        union all
        select 1 from dmt_po_headers_int_tfm_tbl where run_id = l_run2 and tfm_status = 'GENERATED'
        union all
        select 1 from dmt_po_lines_int_tfm_tbl   where run_id = l_run2 and tfm_status = 'GENERATED');
    ok('B5 LOADED and already-FAILED rows untouched; another run untouched', l_n = 5);

    :passed := l_passed;
    rollback;
exception
    when others then
        rollback;
        raise;
end;
/

-- Autonomous log entries written for the synthetic runs.
begin
    delete from dmt_log_tbl where run_id in (:run1, :run2, :run3);
    commit;
end;
/

begin
    if :passed <> 16 then
        raise_application_error(-20998, 'test_load_failure_all_types: '||:passed||' of 16 passed');
    end if;
    dbms_output.put_line('TEST_LOAD_FAILURE_ALL_TYPES: 16 passed, 0 failed');
end;
/
exit
