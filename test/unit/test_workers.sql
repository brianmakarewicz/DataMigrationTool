-- ============================================================
-- test_workers.sql - unit tests for the Workers HDL object,
-- OFFLINE steps only (no Fusion calls):
--   land -> validator alone -> transform alone -> HDL generate.
--
-- Self-contained SQLcl/SQL*Plus script (NOT a database object).
-- Run as DMT_OWNER against a full DMT2 install:
--   sql dmt_owner/...@//localhost:1523/FREEPDB1 @test/unit/test_workers.sql
--
-- Behavior:
--   - Numbered assertions; any failure raises ORA-20999 with the
--     test number + name (whenever sqlerror exit failure).
--   - All test rows carry scenario TEST_WORKERS_SCN and are
--     deleted at start and end, so reruns are stable. STG statuses
--     are never reset - each rerun lands fresh rows + a new run.
--   - Workers is the FIRST HDL object: the generator emits ONE
--     Worker.dat (pipe-delimited METADATA/MERGE), not an FBDI CSV.
--
-- Test data (own scenario, distinct from the golden run):
--   GOOD  UTWORK01, UTWORK02  - full workers (name + optional bits).
--   BAD   UTWORKBAD           - ACTION_CODE 'TERMINATE' (violates the
--                               validator rule HIRE/ADD_CWK), so the
--                               validator tags it FAILED and it never
--                               transforms. (This BAD is a validation
--                               failure, distinct from the golden's
--                               DMTW-BAD, whose only quirk is a missing
--                               DOB - DOB is optional, so DMTW-BAD is a
--                               valid pipeline row that DOES load.)
-- ============================================================

whenever sqlerror exit failure
set serveroutput on size unlimited
set feedback off
set define off

variable passed number
variable run_id number
variable tprefix varchar2(20)
begin :passed := 0; end;
/

-- Pre-clean residue from any earlier run (TFM first for FKs).
declare
    l_scn number;
begin
    select max(scenario_id) into l_scn
    from   dmt_scenario_tbl
    where  upper(scenario_name) = 'TEST_WORKERS_SCN';
    if l_scn is not null then
        delete from dmt_worker_tfm_tbl where stg_sequence_id in (select stg_sequence_id from dmt_worker_stg_tbl where scenario_id = l_scn);
        delete from dmt_person_name_tfm_tbl where stg_sequence_id in (select stg_sequence_id from dmt_person_name_stg_tbl where scenario_id = l_scn);
        delete from dmt_person_email_tfm_tbl where stg_sequence_id in (select stg_sequence_id from dmt_person_email_stg_tbl where scenario_id = l_scn);
        delete from dmt_person_phone_tfm_tbl where stg_sequence_id in (select stg_sequence_id from dmt_person_phone_stg_tbl where scenario_id = l_scn);
        delete from dmt_person_addr_tfm_tbl where stg_sequence_id in (select stg_sequence_id from dmt_person_addr_stg_tbl where scenario_id = l_scn);
        delete from dmt_person_nid_tfm_tbl where stg_sequence_id in (select stg_sequence_id from dmt_person_nid_stg_tbl where scenario_id = l_scn);
        delete from dmt_person_legisl_tfm_tbl where stg_sequence_id in (select stg_sequence_id from dmt_person_legisl_stg_tbl where scenario_id = l_scn);
        delete from dmt_worker_stg_tbl where scenario_id = l_scn;
        delete from dmt_person_name_stg_tbl where scenario_id = l_scn;
        delete from dmt_person_email_stg_tbl where scenario_id = l_scn;
        delete from dmt_person_phone_stg_tbl where scenario_id = l_scn;
        delete from dmt_person_addr_stg_tbl where scenario_id = l_scn;
        delete from dmt_person_nid_stg_tbl where scenario_id = l_scn;
        delete from dmt_person_legisl_stg_tbl where scenario_id = l_scn;
        delete from dmt_scenario_tbl where scenario_id = l_scn;
    end if;
    delete from dmt_csv_landing_tbl where batch_id like 'TEST_WRK_%';
    commit;
end;
/
-- ------------------------------------------------------------
-- Block A - land the 7 input CSVs into the 7 STG tables via
-- DMT_CSV_LOADER_PKG (scenario-mandatory, header-driven).
-- ------------------------------------------------------------
declare
    l_passed pls_integer := 0;
    l_scn    number;
    l_cnt    pls_integer;
    l_raised boolean;

    procedure assert (p_cond boolean, p_num pls_integer, p_name varchar2) is
    begin
        if p_cond then
            l_passed := l_passed + 1;
            dbms_output.put_line('PASS  '||lpad(p_num,2)||'  '||p_name);
        else
            raise_application_error(-20999, 'FAIL test '||p_num||': '||p_name);
        end if;
    end assert;

    procedure land (p_batch varchar2, p_table varchar2, p_csv clob) is
        l_id     number;
        l_status varchar2(30);
        l_err    clob;
    begin
        insert into dmt_csv_landing_tbl
            (batch_id, view_name, atp_table_name, file_name, csv_data, scenario_name)
        values
            (p_batch, p_batch||'_VIEW', p_table, p_batch||'.csv', p_csv, 'TEST_WORKERS_SCN')
        returning csv_landing_id into l_id;
        commit;
        dmt_csv_loader_pkg.load_csv(p_csv_landing_id => l_id);
        select status, error_text into l_status, l_err
        from   dmt_csv_landing_tbl where csv_landing_id = l_id;
        if l_status <> 'LOADED' then
            raise_application_error(-20999,
                p_batch||' CSV load failed ('||l_status||'): '||dbms_lob.substr(l_err,3000,1));
        end if;
    end land;
begin
    land('TEST_WRK_1', 'DMT_WORKER_STG_TBL', to_clob(
'PERSON_NUMBER,DATE_OF_BIRTH,ACTION_CODE,START_DATE,LEGAL_ENTITY_NAME,EFFECTIVE_START_DATE,SOURCE_ID'||chr(10)||
'UTWORK01,1985/03/15,HIRE,2026/01/01,US1 Legal Entity,2026/01/01,UTWORK01'||chr(10)||
'UTWORKBAD,1970/01/01,TERMINATE,2026/01/01,US1 Legal Entity,2026/01/01,UTWORKBAD'||chr(10)||
'UTWORK02,1990/07/22,HIRE,2026/01/01,US1 Legal Entity,2026/01/01,UTWORK02'||chr(10)));

    land('TEST_WRK_2', 'DMT_PERSON_NAME_STG_TBL', to_clob(
'PERSON_NUMBER,LEGISLATION_CODE,NAME_TYPE,LAST_NAME,FIRST_NAME,SOURCE_ID'||chr(10)||
'UTWORK01,US,GLOBAL,UnitWorkerOne,Alice,UTWORK01_NME'||chr(10)||
'UTWORK02,US,GLOBAL,UnitWorkerTwo,Bob,UTWORK02_NME'||chr(10)));

    land('TEST_WRK_3', 'DMT_PERSON_EMAIL_STG_TBL', to_clob(
'PERSON_NUMBER,EMAIL_TYPE,EMAIL_ADDRESS,PRIMARY_FLAG,SOURCE_ID'||chr(10)||
'UTWORK01,W1,alice.unit@example.com,Y,UTWORK01_EML'||chr(10)||
'UTWORK02,W1,bob.unit@example.com,Y,UTWORK02_EML'||chr(10)));

    land('TEST_WRK_4', 'DMT_PERSON_PHONE_STG_TBL', to_clob(
'PERSON_NUMBER,PHONE_TYPE,COUNTRY_CODE_NUMBER,AREA_CODE,PHONE_NUMBER,PRIMARY_FLAG,SOURCE_ID'||chr(10)||
'UTWORK01,W1,1,555,1112222,Y,UTWORK01_PHN'||chr(10)||
'UTWORK02,W1,1,555,3334444,Y,UTWORK02_PHN'||chr(10)));

    land('TEST_WRK_5', 'DMT_PERSON_ADDR_STG_TBL', to_clob(
'PERSON_NUMBER,EFFECTIVE_START_DATE,ADDRESS_TYPE,ADDRESS_LINE_1,TOWN_OR_CITY,REGION_2,POSTAL_CODE,COUNTRY,PRIMARY_FLAG,SOURCE_ID'||chr(10)||
'UTWORK01,2026/01/01,HOME,1 Unit St,Redwood City,CA,94065,US,Y,UTWORK01_ADR'||chr(10)||
'UTWORK02,2026/01/01,HOME,2 Unit Ave,San Jose,CA,95110,US,Y,UTWORK02_ADR'||chr(10)));

    land('TEST_WRK_6', 'DMT_PERSON_NID_STG_TBL', to_clob(
'PERSON_NUMBER,LEGISLATION_CODE,NATIONAL_IDENTIFIER_TYPE,NATIONAL_IDENTIFIER_NUMBER,PRIMARY_FLAG,SOURCE_ID'||chr(10)||
'UTWORK01,US,SSN,111223333,Y,UTWORK01_NID'||chr(10)||
'UTWORK02,US,SSN,222334444,Y,UTWORK02_NID'||chr(10)));

    land('TEST_WRK_7', 'DMT_PERSON_LEGISL_STG_TBL', to_clob(
'PERSON_NUMBER,EFFECTIVE_START_DATE,LEGISLATION_CODE,SEX,MARITAL_STATUS,SOURCE_ID'||chr(10)||
'UTWORK01,2026/01/01,US,F,S,UTWORK01_LEG'||chr(10)||
'UTWORK02,2026/01/01,US,M,M,UTWORK02_LEG'||chr(10)));

    select scenario_id into l_scn
    from   dmt_scenario_tbl where upper(scenario_name) = 'TEST_WORKERS_SCN';

    select count(*) into l_cnt from dmt_worker_stg_tbl where scenario_id = l_scn;
    assert(l_cnt = 3, 1, 'landed 3 Worker STG rows (2 GOOD + 1 BAD)');

    select count(*) into l_cnt from dmt_person_name_stg_tbl where scenario_id = l_scn;
    assert(l_cnt = 2, 2, 'landed 2 PersonName STG rows');

    select count(*) into l_cnt
    from ( select scenario_id from dmt_person_email_stg_tbl where scenario_id = l_scn
           union all select scenario_id from dmt_person_phone_stg_tbl where scenario_id = l_scn
           union all select scenario_id from dmt_person_addr_stg_tbl where scenario_id = l_scn
           union all select scenario_id from dmt_person_nid_stg_tbl where scenario_id = l_scn
           union all select scenario_id from dmt_person_legisl_stg_tbl where scenario_id = l_scn );
    assert(l_cnt = 10, 3, 'landed 10 optional-component STG rows (2 each x 5 tables)');

    select count(*) into l_cnt from dmt_worker_stg_tbl
    where scenario_id = l_scn and stg_status = 'NEW';
    assert(l_cnt = 3, 4, 'all 3 Worker STG rows land as STG_STATUS=NEW');

    -- Identity PK tripwire: an explicit STG_SEQUENCE_ID is rejected (GENERATED ALWAYS).
    l_raised := false;
    begin
        insert into dmt_worker_stg_tbl (stg_sequence_id, person_number, action_code, scenario_id)
        values (999999999, 'UTWORK_X', 'HIRE', l_scn);
    exception when others then
        l_raised := true;  -- ORA-32795: cannot insert into a generated always identity column
    end;
    assert(l_raised, 5, 'identity PK rejects an explicit STG_SEQUENCE_ID (ORA-32795)');

    :passed := :passed + l_passed;
end;
/
-- ------------------------------------------------------------
-- Block B - validator ALONE. Init a run, run VALIDATE_PRE_TRANSFORM.
-- GOOD workers stay NEW; the BAD (TERMINATE) is tagged FAILED with an
-- appended [PRE_VALIDATION] message (accumulate, never overwrite).
-- ------------------------------------------------------------
declare
    l_passed pls_integer := 0;
    l_scn    number;
    l_run    number;
    l_prefix varchar2(20);
    l_cnt    pls_integer;
    l_status varchar2(30);
    l_err    clob;

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
    from   dmt_scenario_tbl where upper(scenario_name) = 'TEST_WORKERS_SCN';

    dmt_pipeline_init_pkg.init_run(
        p_orchestration_code => 'Workers',
        p_scenario_name      => 'TEST_WORKERS_SCN',
        p_source_filename    => 'test_workers.sql',
        p_instance_id        => 'UNIT_TEST',
        x_integration_id     => l_run,
        x_prefix             => l_prefix);
    :run_id  := l_run;
    :tprefix := l_prefix;
    assert(l_run is not null and l_prefix is not null
           and length(l_prefix) between 4 and 6, 6,
           'INIT_RUN returns a run id + numeric prefix (USE_PREFIX=Y)');

    dmt_worker_validator_pkg.validate_pre_transform(l_run);

    select count(*) into l_cnt from dmt_worker_stg_tbl
    where scenario_id = l_scn and stg_status = 'NEW';
    assert(l_cnt = 2, 7, 'validator leaves the 2 GOOD workers NEW');

    select stg_status, error_text into l_status, l_err
    from   dmt_worker_stg_tbl
    where  scenario_id = l_scn and person_number = 'UTWORKBAD';
    assert(l_status = 'FAILED', 8, 'validator tags the BAD worker FAILED');
    assert(l_err is not null
           and dbms_lob.instr(l_err, '[PRE_VALIDATION]') > 0, 9,
           'BAD worker ERROR_TEXT carries an appended [PRE_VALIDATION] message');

    select count(*) into l_cnt from dmt_worker_stg_tbl
    where  scenario_id = l_scn and person_number in ('UTWORK01','UTWORK02')
    and    error_text is not null;
    assert(l_cnt = 0, 10, 'validator does not tag the GOOD workers');

    :passed := :passed + l_passed;
end;
/
-- ------------------------------------------------------------
-- Block C - transform ALONE. Only NEW rows transform; the FAILED
-- BAD worker does not. TFM carries RUN_ID + prefixed PERSON_NUMBER;
-- STG data columns are never rewritten (no writeback to staging).
-- ------------------------------------------------------------
declare
    l_passed  pls_integer := 0;
    l_scn     number;
    l_run     number;
    l_prefix  varchar2(20);
    l_cnt     pls_integer;
    l_tfm_pn  varchar2(240);
    l_stg_pn  varchar2(240);
    l_tfm_st  varchar2(30);

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
    from   dmt_scenario_tbl where upper(scenario_name) = 'TEST_WORKERS_SCN';
    l_run    := :run_id;
    l_prefix := :tprefix;

    dmt_worker_transform_pkg.transform_workers(l_run, p_scenario_id => l_scn);
    dmt_worker_transform_pkg.transform_person_names(l_run, p_scenario_id => l_scn);
    dmt_worker_transform_pkg.transform_person_emails(l_run, p_scenario_id => l_scn);
    dmt_worker_transform_pkg.transform_person_phones(l_run, p_scenario_id => l_scn);
    dmt_worker_transform_pkg.transform_person_addresses(l_run, p_scenario_id => l_scn);
    dmt_worker_transform_pkg.transform_person_nids(l_run, p_scenario_id => l_scn);
    dmt_worker_transform_pkg.transform_person_legisl(l_run, p_scenario_id => l_scn);

    select count(*) into l_cnt from dmt_worker_tfm_tbl where run_id = l_run;
    assert(l_cnt = 2, 11, 'transform creates 2 Worker TFM rows (BAD excluded)');

    select count(*) into l_cnt from dmt_worker_tfm_tbl
    where run_id = l_run and tfm_status = 'STAGED';
    assert(l_cnt = 2, 12, 'new Worker TFM rows are STAGED');

    select t.person_number, s.person_number
    into   l_tfm_pn, l_stg_pn
    from   dmt_worker_tfm_tbl t
    join   dmt_worker_stg_tbl s on s.stg_sequence_id = t.stg_sequence_id
    where  t.run_id = l_run and s.source_id = 'UTWORK01';
    assert(l_tfm_pn = l_prefix||'UTWORK01', 13,
           'TFM PERSON_NUMBER has the run prefix applied');
    assert(l_stg_pn = 'UTWORK01', 14,
           'STG PERSON_NUMBER is unchanged (prefix lives only on TFM)');

    select count(*) into l_cnt from dmt_worker_stg_tbl
    where scenario_id = l_scn and stg_status = 'TRANSFORMED';
    assert(l_cnt = 2, 15, 'GOOD Worker STG rows advance NEW to TRANSFORMED');

    select stg_status into l_tfm_st from dmt_worker_stg_tbl
    where scenario_id = l_scn and person_number = 'UTWORKBAD';
    assert(l_tfm_st = 'FAILED', 16, 'BAD Worker STG row stays FAILED (no TFM row)');

    select count(*) into l_cnt from dmt_worker_tfm_tbl t
    join dmt_worker_stg_tbl s on s.stg_sequence_id = t.stg_sequence_id
    where t.run_id = l_run and s.person_number = 'UTWORKBAD';
    assert(l_cnt = 0, 17, 'no TFM row exists for the FAILED BAD worker');

    select count(*) into l_cnt from dmt_person_name_tfm_tbl where run_id = l_run;
    assert(l_cnt = 2, 18, 'transform creates 2 PersonName TFM rows');

    dmt_worker_transform_pkg.transform_workers(l_run, p_scenario_id => l_scn);
    select count(*) into l_cnt from dmt_worker_tfm_tbl where run_id = l_run;
    assert(l_cnt = 2, 19, 're-transform is idempotent (NOT EXISTS guard)');

    :passed := :passed + l_passed;
end;
/
-- ------------------------------------------------------------
-- Block D - HDL generator. GENERATE_HDL emits one Worker.dat zip;
-- TFM rows advance STAGED to GENERATED with FBDI_CSV_ID stamped.
-- ------------------------------------------------------------
declare
    l_passed pls_integer := 0;
    l_scn    number;
    l_run    number;
    l_zip    blob;
    l_fn     varchar2(200);
    l_csv_id number;
    l_cnt    pls_integer;
    l_dat    clob;
    l_prefix varchar2(20);

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
    from   dmt_scenario_tbl where upper(scenario_name) = 'TEST_WORKERS_SCN';
    l_run    := :run_id;
    l_prefix := :tprefix;

    dmt_worker_hdl_gen_pkg.generate_hdl(l_run, l_zip, l_fn, l_csv_id);

    assert(l_zip is not null and dbms_lob.getlength(l_zip) > 0, 20,
           'GENERATE_HDL returns a non-empty zip');
    assert(l_fn = 'Worker_'||l_run||'.zip', 21,
           'zip filename is Worker_<run>.zip');

    select count(*) into l_cnt from dmt_worker_tfm_tbl
    where run_id = l_run and tfm_status = 'GENERATED' and fbdi_csv_id = l_csv_id;
    assert(l_cnt = 2, 22, 'Worker TFM rows advance STAGED to GENERATED with FBDI_CSV_ID');

    select csv_content into l_dat from dmt_fbdi_csv_tbl where fbdi_csv_id = l_csv_id;
    assert(dbms_lob.instr(l_dat, 'METADATA|Worker|') > 0, 23,
           'DAT content has a METADATA|Worker header line');
    assert(dbms_lob.instr(l_dat, 'MERGE|Worker|HRC_SQLLOADER|'||l_prefix||'UTWORK01') > 0, 24,
           'DAT content has a prefixed MERGE|Worker data line');
    assert(dbms_lob.instr(l_dat, 'METADATA|PersonLegislativeData|') > 0, 25,
           'DAT content includes the optional PersonLegislativeData section');
    assert(dbms_lob.instr(l_dat, 'MERGE|WorkTerms|HRC_SQLLOADER|'||l_prefix||'UTWORK01_TRM') > 0, 26,
           'DAT content has the auto-generated WorkTerms line');

    :passed := :passed + l_passed;
end;
/

-- ------------------------------------------------------------
-- Cleanup (scenario-scoped): TFM first (FK), then STG, then rest.
-- ------------------------------------------------------------
declare
    l_scn number;
begin
    select max(scenario_id) into l_scn
    from   dmt_scenario_tbl where upper(scenario_name) = 'TEST_WORKERS_SCN';
    if l_scn is not null then
        delete from dmt_worker_tfm_tbl where stg_sequence_id in (select stg_sequence_id from dmt_worker_stg_tbl where scenario_id = l_scn);
        delete from dmt_person_name_tfm_tbl where stg_sequence_id in (select stg_sequence_id from dmt_person_name_stg_tbl where scenario_id = l_scn);
        delete from dmt_person_email_tfm_tbl where stg_sequence_id in (select stg_sequence_id from dmt_person_email_stg_tbl where scenario_id = l_scn);
        delete from dmt_person_phone_tfm_tbl where stg_sequence_id in (select stg_sequence_id from dmt_person_phone_stg_tbl where scenario_id = l_scn);
        delete from dmt_person_addr_tfm_tbl where stg_sequence_id in (select stg_sequence_id from dmt_person_addr_stg_tbl where scenario_id = l_scn);
        delete from dmt_person_nid_tfm_tbl where stg_sequence_id in (select stg_sequence_id from dmt_person_nid_stg_tbl where scenario_id = l_scn);
        delete from dmt_person_legisl_tfm_tbl where stg_sequence_id in (select stg_sequence_id from dmt_person_legisl_stg_tbl where scenario_id = l_scn);
        delete from dmt_worker_stg_tbl where scenario_id = l_scn;
        delete from dmt_person_name_stg_tbl where scenario_id = l_scn;
        delete from dmt_person_email_stg_tbl where scenario_id = l_scn;
        delete from dmt_person_phone_stg_tbl where scenario_id = l_scn;
        delete from dmt_person_addr_stg_tbl where scenario_id = l_scn;
        delete from dmt_person_nid_stg_tbl where scenario_id = l_scn;
        delete from dmt_person_legisl_stg_tbl where scenario_id = l_scn;
        delete from dmt_scenario_tbl where scenario_id = l_scn;
    end if;
    delete from dmt_csv_landing_tbl where batch_id like 'TEST_WRK_%';
    commit;
end;
/

set feedback on
begin
    dbms_output.put_line('TEST_WORKERS: '||:passed||' passed, 0 failed');
end;
/
exit success
