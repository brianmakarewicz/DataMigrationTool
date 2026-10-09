-- ============================================================
-- test_grants_child_accounting.sql -- Grants award children are accounted on
-- their own Fusion evidence, never by inheritance (backlog #568).
--
-- What it proves (DMT_DESIGN.html section 5, "Cross-grain failure shapes
-- every object must handle" and section 7, record accounting: LOADED needs
-- the record's own proof, FAILED needs a real Fusion error):
--   G1  APPLY_AWARD_REPORT_XML returns C_SUCCESS.
--   G2  shape (c), child rejected under a LOADED award: the child is FAILED
--       with its OWN Fusion error and is not quoted as a document rejection;
--       the award header stays LOADED with no error added.
--   G3  a child of a LOADED award is LOADED only on its own success line
--       (personnel, budget period).
--   G4  a child of a LOADED award with NO success line of its own stays
--       GENERATED (funding with no line; keyword, a record type Fusion's
--       report has no success group for) -- never LOADED by inheritance.
--   G5  two identical child rows and one success line: exactly one LOADED,
--       the other stays GENERATED.
--   G6  the LOADED award's siblings are not given the rejected child's error.
--   G7  shape (b), child rejected and the award rejected with it: the child
--       keeps its own error; header and sibling FAILED quoting it ("Rejected
--       with document: award <n> (personnel <key>)").
--   G8  shape (a), award header rejected itself: the header keeps its own
--       error; its child FAILED quoting it.
--
-- The report XML is synthetic, in Fusion's AwardBatchImportReportDm shape
-- (LIST_G_3 successful awards with child success groups; LIST_G_4 rejected
-- awards with nested child failure groups). Shape (c) has NOT been observed
-- live: probes 77141 / 77142 (2026-10-09) sent eleven different child
-- defects and Fusion rejected the whole award every time. The test proves
-- the reconciler accounts that shape honestly if Fusion ever produces it.
--
-- Isolation. Every row this test writes (one synthetic run and its award TFM
-- rows) lives in ONE transaction that is ROLLED BACK at the end (and on any
-- failure). No existing STG or TFM row is read or changed. The only committed
-- side effect is the activity-log entries DMT_UTIL_PKG.LOG writes in its own
-- autonomous transaction; the test deletes exactly those (matched on the
-- synthetic RUN_ID) after the rollback.
--
-- Run as DMT_OWNER:
--   sql dmt_owner/...@//localhost:1523/FREEPDB1 @test/unit/test_grants_child_accounting.sql
-- ============================================================

whenever sqlerror exit failure rollback
set serveroutput on size unlimited
set feedback off
set define off

variable passed number
variable run1 number
begin :passed := 0; :run1 := null; end;
/

declare
    l_passed pls_integer := 0;
    l_run    number;
    l_failed number;
    l_loaded number;
    l_code   number;
    l_n      number;
    l_st     varchar2(30);
    l_err    clob;
    l_xml    clob;
    A        constant varchar2(30) := 'UTGNT-A';   -- award Fusion created
    B        constant varchar2(30) := 'UTGNT-B';   -- award rejected by a child
    C        constant varchar2(30) := 'UTGNT-C';   -- award rejected by its header
    C_EMAIL  constant varchar2(80) := 'brock.phillips_esew-dev28@oraclepdemos.com';

    procedure ok(p_name in varchar2, p_cond in boolean) is
    begin
        if p_cond then
            l_passed := l_passed + 1;
            dbms_output.put_line('PASS '||p_name);
        else
            raise_application_error(-20999, 'FAIL test '||p_name);
        end if;
    end;

    procedure hdr(p_award in varchar2, p_status in varchar2) is
    begin
        insert into dmt_gms_awd_headers_tfm_tbl (run_id, stg_sequence_id, tfm_status, award_number, fbdi_csv_id)
        values (l_run, -1, p_status, p_award, -1);
    end;

    procedure pers(p_award in varchar2, p_email in varchar2, p_num in varchar2) is
    begin
        insert into dmt_gms_awd_personnel_tfm_tbl (run_id, stg_sequence_id, tfm_status, award_number,
                                                   person_email, person_number, fbdi_csv_id)
        values (l_run, -1, 'GENERATED', p_award, p_email, p_num, -1);
    end;

    procedure proj(p_award in varchar2, p_proj in varchar2) is
    begin
        insert into dmt_gms_awd_projects_tfm_tbl (run_id, stg_sequence_id, tfm_status, award_number,
                                                  project_number, fbdi_csv_id)
        values (l_run, -1, 'GENERATED', p_award, p_proj, -1);
    end;

    function status_of(p_tbl in varchar2, p_award in varchar2, p_key in varchar2) return varchar2 is
        l_s varchar2(30);
    begin
        if p_tbl = 'HDR' then
            select tfm_status, error_text into l_s, l_err from dmt_gms_awd_headers_tfm_tbl
             where run_id = l_run and award_number = p_award;
        elsif p_tbl = 'PERS' then
            select tfm_status, error_text into l_s, l_err from dmt_gms_awd_personnel_tfm_tbl
             where run_id = l_run and award_number = p_award
               and nvl(person_number, person_email) = p_key;
        elsif p_tbl = 'PROJ' then
            select tfm_status, error_text into l_s, l_err from dmt_gms_awd_projects_tfm_tbl
             where run_id = l_run and award_number = p_award and project_number = p_key;
        elsif p_tbl = 'BP' then
            select tfm_status, error_text into l_s, l_err from dmt_gms_awd_bdgt_prds_tfm_tbl
             where run_id = l_run and award_number = p_award;
        elsif p_tbl = 'FUND' then
            select tfm_status, error_text into l_s, l_err from dmt_gms_awd_funding_tfm_tbl
             where run_id = l_run and award_number = p_award;
        elsif p_tbl = 'KW' then
            select tfm_status, error_text into l_s, l_err from dmt_gms_awd_keywords_tfm_tbl
             where run_id = l_run and award_number = p_award;
        end if;
        return l_s;
    end;

    function has(p_text in varchar2) return boolean is
    begin
        return nvl(dbms_lob.instr(l_err, p_text), 0) > 0;
    end;
begin
    insert into dmt_pipeline_run_tbl (pipeline_codes, run_type, submitted_by,
                                      cemli_sequence, scenario_name, run_status)
    values ('STANDALONE:Grants', 'PIPELINE', 'UNIT_TEST_GNT_CHILD',
            'Grants', 'UNIT_TEST_GNT_CHILD', 'IN_PROGRESS')
    returning run_id into l_run;
    :run1 := l_run;

    -- Award A: header already LOADED by the base-table pass.
    hdr(A, 'LOADED');
    pers(A, C_EMAIL, null);              -- success line -> LOADED
    pers(A, null, '99999999');           -- rejected under the LOADED award
    proj(A, 'PRG10008');                 -- two identical rows, one success line
    proj(A, 'PRG10008');
    insert into dmt_gms_awd_bdgt_prds_tfm_tbl (run_id, stg_sequence_id, tfm_status, award_number, budget_period, fbdi_csv_id)
    values (l_run, -1, 'GENERATED', A, 'Period 1', -1);                 -- success line -> LOADED
    insert into dmt_gms_awd_funding_tfm_tbl (run_id, stg_sequence_id, tfm_status, award_number, issue_number, fbdi_csv_id)
    values (l_run, -1, 'GENERATED', A, 'Base 1', -1);                   -- no line -> GENERATED
    insert into dmt_gms_awd_keywords_tfm_tbl (run_id, stg_sequence_id, tfm_status, award_number, keyword_name, fbdi_csv_id)
    values (l_run, -1, 'GENERATED', A, 'Cancer', -1);                   -- no success group -> GENERATED

    -- Award B: rejected because of its personnel row.
    hdr(B, 'GENERATED');
    pers(B, null, '88888888');
    proj(B, 'PRG10008');

    -- Award C: rejected because of its own header.
    hdr(C, 'GENERATED');
    proj(C, 'PRG10008');

    l_xml :=
      '<DATA_DS><LIST_G_1><G_1>'
    ||  '<LIST_G_4>'
    ||    '<G_4><PARENT_AWARD_NUMBER>'||B||'</PARENT_AWARD_NUMBER>'
    ||      '<PROCESSED_MESSAGE>The award isn''t imported because errors exist in the personnel data.</PROCESSED_MESSAGE>'
    ||      '<LIST_G_33><G_33><AWARD_NUMBER>'||B||'</AWARD_NUMBER><PERSON_NUMBER>88888888</PERSON_NUMBER>'
    ||        '<PROCESSED_STATUS>FAILURE</PROCESSED_STATUS>'
    ||        '<PROCESSED_MESSAGE>The value of the attribute Person Number isn''t valid.</PROCESSED_MESSAGE></G_33></LIST_G_33>'
    ||    '</G_4>'
    ||    '<G_4><PARENT_AWARD_NUMBER>'||C||'</PARENT_AWARD_NUMBER>'
    ||      '<PROCESSED_MESSAGE>The value of the attribute Primary Sponsor isn''t valid.</PROCESSED_MESSAGE></G_4>'
    ||  '</LIST_G_4>'
    ||  '<LIST_G_3><G_3><AWARD_NUMBER>'||A||'</AWARD_NUMBER>'
    ||    '<LIST_G_35><G_35><AWARD_NUMBER>'||A||'</AWARD_NUMBER><PERSON_EMAIL>'||C_EMAIL||'</PERSON_EMAIL></G_35></LIST_G_35>'
    ||    '<LIST_G_33><G_33><AWARD_NUMBER>'||A||'</AWARD_NUMBER><PERSON_NUMBER>99999999</PERSON_NUMBER>'
    ||      '<PROCESSED_STATUS>FAILURE</PROCESSED_STATUS>'
    ||      '<PROCESSED_MESSAGE>The value of the attribute Role isn''t valid.</PROCESSED_MESSAGE></G_33></LIST_G_33>'
    ||    '<LIST_G_26><G_26><AWARD_NUMBER>'||A||'</AWARD_NUMBER><PROJECT_NUMBER>PRG10008</PROJECT_NUMBER></G_26></LIST_G_26>'
    ||    '<LIST_G_32><G_32><AWARD_NUMBER>'||A||'</AWARD_NUMBER><BUDGET_PERIOD>Period 1</BUDGET_PERIOD></G_32></LIST_G_32>'
    ||  '</G_3></LIST_G_3>'
    || '</G_1></LIST_G_1></DATA_DS>';

    dmt_grants_results_pkg.apply_award_report_xml(
        p_run_id      => l_run,
        p_report_xml  => l_xml,
        x_rows_failed => l_failed,
        x_rows_loaded => l_loaded,
        x_error_code  => l_code);
    ok('G1 C_SUCCESS', l_code = dmt_util_pkg.c_success);

    -- Shape (c): own error, no document quote; award stays LOADED.
    l_st := status_of('PERS', A, '99999999');
    ok('G2a child rejected under a LOADED award is FAILED with its own error',
       l_st = 'FAILED' and has('[FUSION_ERROR] The value of the attribute Role isn''t valid.')
       and not has('Rejected with document'));
    l_st := status_of('HDR', A, null);
    ok('G2b the award header stays LOADED with no error added', l_st = 'LOADED' and l_err is null);

    l_st := status_of('PERS', A, C_EMAIL);
    ok('G3a personnel with its own success line LOADED', l_st = 'LOADED');
    l_st := status_of('BP', A, null);
    ok('G3b budget period with its own success line LOADED', l_st = 'LOADED');

    l_st := status_of('FUND', A, null);
    ok('G4a funding with no success line stays GENERATED', l_st = 'GENERATED' and l_err is null);
    l_st := status_of('KW', A, null);
    ok('G4b keyword (no success group in the report) stays GENERATED', l_st = 'GENERATED' and l_err is null);

    select count(case when tfm_status = 'LOADED' then 1 end),
           count(case when tfm_status = 'GENERATED' then 1 end)
      into l_n, l_failed
      from dmt_gms_awd_projects_tfm_tbl where run_id = l_run and award_number = A;
    ok('G5 two identical project rows, one success line: one LOADED, one GENERATED',
       l_n = 1 and l_failed = 1);

    select count(*) into l_n from (
        select error_text from dmt_gms_awd_projects_tfm_tbl  where run_id = l_run and award_number = A
        union all
        select error_text from dmt_gms_awd_funding_tfm_tbl   where run_id = l_run and award_number = A
        union all
        select error_text from dmt_gms_awd_keywords_tfm_tbl  where run_id = l_run and award_number = A
        union all
        select error_text from dmt_gms_awd_bdgt_prds_tfm_tbl where run_id = l_run and award_number = A)
     where error_text is not null;
    ok('G6 no sibling of the LOADED award carries the rejected child''s error', l_n = 0);

    -- Shape (b).
    l_st := status_of('PERS', B, '88888888');
    ok('G7a rejected child keeps its own error',
       l_st = 'FAILED' and has('[FUSION_ERROR] The value of the attribute Person Number isn''t valid.')
       and not has('Rejected with document'));
    l_st := status_of('HDR', B, null);
    ok('G7b header FAILED quoting the child',
       l_st = 'FAILED' and has('Rejected with document: award '||B||' (personnel 88888888)'));
    l_st := status_of('PROJ', B, 'PRG10008');
    ok('G7c sibling FAILED quoting the child',
       l_st = 'FAILED' and has('Rejected with document: award '||B||' (personnel 88888888)'));

    -- Shape (a).
    l_st := status_of('HDR', C, null);
    ok('G8a header keeps its own error',
       l_st = 'FAILED' and has('[FUSION_ERROR] The value of the attribute Primary Sponsor isn''t valid.')
       and not has('Rejected with document'));
    l_st := status_of('PROJ', C, 'PRG10008');
    ok('G8b child FAILED quoting the header',
       l_st = 'FAILED' and has('Rejected with document: award '||C||': ')
       and has('Primary Sponsor isn''t valid.'));

    :passed := l_passed;
    rollback;
exception
    when others then
        rollback;
        raise;
end;
/

begin
    delete from dmt_log_tbl where run_id = :run1;
    commit;
end;
/

begin
    if :passed <> 14 then
        raise_application_error(-20998, 'test_grants_child_accounting: '||:passed||' of 14 passed');
    end if;
    dbms_output.put_line('test_grants_child_accounting: ALL 14 PASSED');
end;
/
exit
