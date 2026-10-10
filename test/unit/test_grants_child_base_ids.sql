-- ============================================================
-- test_grants_child_base_ids.sql -- six Grants award child types are LOADED
-- from their own Fusion base row, each with its own Fusion id (backlog #671).
--
-- What it proves (DMT_DESIGN.html section 5, "How each row's outcome is
-- resolved": LOADED only on a positive base-table match with the Fusion id;
-- "Cross-grain failure shapes": a child is LOADED only on its own Fusion
-- evidence, never by inheritance; and the row-grain Fusion id rule):
--   B1  APPLY_AWARD_CHILD_ROWS returns C_SUCCESS.
--   B2  under a LOADED award, a keyword, term, certification, CFDA, reference
--       and task burden schedule row whose own base row is in the report is
--       LOADED with that base row's id in its own FUSION_*_ID column.
--   B3  names are matched case-insensitively (the report upper-cases them).
--   B4  a child of an award that is NOT LOADED stays GENERATED with no id,
--       even when the report carries a matching base row.
--   B5  a child already FAILED with its own error is never touched.
--   B6  a base row that matches no TFM row (Fusion created it from the award
--       template) changes nothing.
--   B7  two identical rows and one base row: exactly one LOADED; a second
--       report line carrying the SAME Fusion id is not stored again.
--   B8  a second pass changes nothing (idempotent).
--   B9  INTERFACE and award-tier rows of the report are ignored here.
--
-- The report rows are synthetic, in the shape DMT_RECON_CONTRACT_PKG.FETCH_ROWS
-- returns for the Grants recon report V4 (bip/Grants/query.sql).
--
-- Isolation. Every row this test writes (one synthetic run and its award TFM
-- rows) lives in ONE transaction that is ROLLED BACK at the end (and on any
-- failure). No existing STG or TFM row is read or changed. The only committed
-- side effect is the activity-log entries DMT_UTIL_PKG.LOG writes in its own
-- autonomous transaction; the test deletes exactly those (matched on the
-- synthetic RUN_ID) after the rollback.
--
-- Run as DMT_OWNER:
--   sql dmt_owner/...@//localhost:1523/FREEPDB1 @test/unit/test_grants_child_base_ids.sql
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
    l_loaded number;
    l_code   number;
    l_n      number;
    l_st     varchar2(30);
    l_id     number;
    l_rows   dmt_recon_contract_pkg.t_recon_tbl;
    A        constant varchar2(30) := 'UTGNB-A';   -- award Fusion created (header LOADED)
    B        constant varchar2(30) := 'UTGNB-B';   -- award not confirmed (header GENERATED)

    procedure ok(p_name in varchar2, p_cond in boolean) is
    begin
        if p_cond then
            l_passed := l_passed + 1;
            dbms_output.put_line('PASS '||p_name);
        else
            raise_application_error(-20999, 'FAIL test '||p_name);
        end if;
    end;

    procedure line(p_type in varchar2, p_key in varchar2, p_id in number,
                   p_source in varchar2 default 'BASE', p_status in varchar2 default 'SUCCESS') is
        i pls_integer := l_rows.count + 1;
    begin
        l_rows(i).object_type   := p_type;
        l_rows(i).record_key    := p_key;
        l_rows(i).source_type   := p_source;
        l_rows(i).fusion_status := p_status;
        l_rows(i).fusion_id     := to_char(p_id);
    end;
begin
    insert into dmt_pipeline_run_tbl (pipeline_codes, run_type, submitted_by,
                                      cemli_sequence, scenario_name, run_status)
    values ('STANDALONE:Grants', 'PIPELINE', 'UNIT_TEST_GNT_BASE',
            'Grants', 'UNIT_TEST_GNT_BASE', 'IN_PROGRESS')
    returning run_id into l_run;
    :run1 := l_run;

    insert into dmt_gms_awd_headers_tfm_tbl (run_id, stg_sequence_id, tfm_status, award_number, fbdi_csv_id)
    values (l_run, -1, 'LOADED', A, -1);
    insert into dmt_gms_awd_headers_tfm_tbl (run_id, stg_sequence_id, tfm_status, award_number, fbdi_csv_id)
    values (l_run, -1, 'GENERATED', B, -1);

    -- Award A children (one of each type; two identical keywords).
    insert into dmt_gms_awd_keywords_tfm_tbl (run_id, stg_sequence_id, tfm_status, award_number, keyword_name, fbdi_csv_id)
    values (l_run, -1, 'GENERATED', A, 'Genetics', -1);
    insert into dmt_gms_awd_keywords_tfm_tbl (run_id, stg_sequence_id, tfm_status, award_number, keyword_name, fbdi_csv_id)
    values (l_run, -1, 'GENERATED', A, 'Genetics', -1);
    insert into dmt_gms_awd_terms_tfm_tbl (run_id, stg_sequence_id, tfm_status, award_number, term_category_name, term_name, fbdi_csv_id)
    values (l_run, -1, 'GENERATED', A, 'Scholarship Restrictions', 'Graduate Scholarships', -1);
    insert into dmt_gms_awd_certs_tfm_tbl (run_id, stg_sequence_id, tfm_status, award_number, certification_name, fbdi_csv_id)
    values (l_run, -1, 'GENERATED', A, 'Health Care Worker Certification', -1);
    insert into dmt_gms_awd_cfdas_tfm_tbl (run_id, stg_sequence_id, tfm_status, award_number, cfda, fbdi_csv_id)
    values (l_run, -1, 'GENERATED', A, '93.395', -1);
    insert into dmt_gms_awd_cfdas_tfm_tbl (run_id, stg_sequence_id, tfm_status, award_number, cfda, fbdi_csv_id, error_text)
    values (l_run, -1, 'FAILED', A, '47.074', -1, '[FUSION_ERROR] The CFDA isn''t valid.');
    insert into dmt_gms_awd_references_tfm_tbl (run_id, stg_sequence_id, tfm_status, award_number, reference_type, value, fbdi_csv_id)
    values (l_run, -1, 'GENERATED', A, 'InfoEd #', 'RT-INF-1', -1);
    insert into dmt_gms_awd_prj_tsk_brd_tfm_tbl (run_id, stg_sequence_id, tfm_status, award_number, project_number, task_number, burden_schedule, fbdi_csv_id)
    values (l_run, -1, 'GENERATED', A, 'PRG10008', '1.0', 'Progress US Burden Schedule', -1);
    -- Award B child.
    insert into dmt_gms_awd_keywords_tfm_tbl (run_id, stg_sequence_id, tfm_status, award_number, keyword_name, fbdi_csv_id)
    values (l_run, -1, 'GENERATED', B, 'Genetics', -1);

    line('Grants',               A, 900001);                                  -- award tier: ignored here
    line('Grants',               A, null, 'INTERFACE', 'ERROR');             -- interface tier: ignored
    line('Grants.Keyword',       A||'~GENETICS~',                        910001);
    line('Grants.Keyword',       A||'~GENETICS~',                        910001);  -- same id again
    line('Grants.Term',          A||'~SCHOLARSHIP RESTRICTIONS~GRADUATE SCHOLARSHIPS', 910002);
    line('Grants.Term',          A||'~TRAVEL~FOREIGN',                   910009);  -- template term
    line('Grants.Certification', A||'~HEALTH CARE WORKER CERTIFICATION~', 910003);
    line('Grants.Cfda',          A||'~93.395',                           910004);
    line('Grants.Cfda',          A||'~47.074',                           910008);  -- row already FAILED
    line('Grants.Reference',     A||'~INFOED #~~RT-INF-1',               910005);
    line('Grants.TaskBurden',    A||'~PRG10008~1.0',                     910006);
    line('Grants.Keyword',       B||'~GENETICS~',                        910007);  -- award not LOADED

    dmt_grants_results_pkg.apply_award_child_rows(
        p_run_id      => l_run,
        p_rows        => l_rows,
        x_rows_loaded => l_loaded,
        x_error_code  => l_code);
    ok('B1 C_SUCCESS', l_code = dmt_util_pkg.c_success);

    select tfm_status, fusion_term_id into l_st, l_id from dmt_gms_awd_terms_tfm_tbl where run_id = l_run;
    ok('B2a term LOADED with its own id', l_st = 'LOADED' and l_id = 910002);
    select tfm_status, fusion_cert_id into l_st, l_id from dmt_gms_awd_certs_tfm_tbl where run_id = l_run;
    ok('B2b certification LOADED with its own id', l_st = 'LOADED' and l_id = 910003);
    select tfm_status, fusion_cfda_id into l_st, l_id from dmt_gms_awd_cfdas_tfm_tbl where run_id = l_run and cfda = '93.395';
    ok('B2c CFDA LOADED with its own id', l_st = 'LOADED' and l_id = 910004);
    select tfm_status, fusion_reference_id into l_st, l_id from dmt_gms_awd_references_tfm_tbl where run_id = l_run;
    ok('B2d reference LOADED with its own id', l_st = 'LOADED' and l_id = 910005);
    select tfm_status, fusion_task_burden_id into l_st, l_id from dmt_gms_awd_prj_tsk_brd_tfm_tbl where run_id = l_run;
    ok('B2e task burden schedule LOADED with its own id', l_st = 'LOADED' and l_id = 910006);

    select count(case when tfm_status = 'LOADED' and fusion_keyword_id = 910001 then 1 end),
           count(case when tfm_status = 'GENERATED' and fusion_keyword_id is null then 1 end)
      into l_n, l_id
      from dmt_gms_awd_keywords_tfm_tbl where run_id = l_run and award_number = A;
    ok('B3/B7 keyword matched case-insensitively; two identical rows and one Fusion id: one LOADED, one GENERATED',
       l_n = 1 and l_id = 1);

    select tfm_status, fusion_keyword_id into l_st, l_id from dmt_gms_awd_keywords_tfm_tbl where run_id = l_run and award_number = B;
    ok('B4 child of an award that is not LOADED stays GENERATED with no id', l_st = 'GENERATED' and l_id is null);

    select tfm_status, fusion_cfda_id into l_st, l_id from dmt_gms_awd_cfdas_tfm_tbl where run_id = l_run and cfda = '47.074';
    ok('B5 a FAILED child is never touched', l_st = 'FAILED' and l_id is null);

    ok('B6/B9 only the six matching child rows changed (template term, award and interface rows ignored)', l_loaded = 6);

    dmt_grants_results_pkg.apply_award_child_rows(
        p_run_id      => l_run,
        p_rows        => l_rows,
        x_rows_loaded => l_loaded,
        x_error_code  => l_code);
    ok('B8 a second pass changes nothing', l_code = dmt_util_pkg.c_success and l_loaded = 0);

    select tfm_status into l_st from dmt_gms_awd_headers_tfm_tbl where run_id = l_run and award_number = B;
    ok('B9 the award header is not touched by the child pass', l_st = 'GENERATED');

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
    if :passed <> 12 then
        raise_application_error(-20998, 'test_grants_child_base_ids: '||:passed||' of 12 passed');
    end if;
    dbms_output.put_line('test_grants_child_base_ids: ALL 12 PASSED');
end;
/
exit
