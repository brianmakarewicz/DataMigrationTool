-- ============================================================
-- test_csv_intake.sql — Stage B3 unit tests for the CSV intake
-- layer: DMT_CSV_LANDING_TBL + DMT_CSV_LOADER_PKG.
--
-- Self-contained SQLcl/SQL*Plus script (NOT a database object).
-- Run as DMT_OWNER against a full DMT2 install:
--   sql dmt_owner/...@//localhost:1523/FREEPDB1 @test/unit/test_csv_intake.sql
--
-- Behavior:
--   - Numbered assertions; any failure raises ORA-20999 with the
--     test number + name, and the script exits nonzero
--     (whenever sqlerror exit failure).
--   - All test rows carry the marker TEST_CSV_INTAKE_MARKER and
--     are deleted at start and end, so reruns are stable.
--   - Fixture STG table: DMT_POZ_SUPPLIERS_STG_TBL (has DATE,
--     NUMBER, VARCHAR2 columns, SCENARIO_ID, STG_STATUS default 'NEW').
--   - Design-doc contract gaps (DMT_DESIGN.html sections 4/6/7)
--     that are NOT failures are reported as "GAP:" lines — they
--     feed the Stage B blind review.
--
-- Scope note: DMT_CSV_UPLOAD_PKG (the Smart Upload / APEX path)
-- cannot be unit-tested on the local Docker DB — its body is
-- INVALID because APEX (APEX_ZIP / APEX_DATA_PARSER) is not
-- installed. See the gap report block at the end.
--
-- Note on nested blocks: the section-7 one-BEGIN/END rule applies
-- to database objects. This is a test script; it uses nested
-- blocks to assert expected exceptions.
-- ============================================================

whenever sqlerror exit failure
set serveroutput on size unlimited
set feedback off
set define off

variable passed number

begin :passed := 0; end;
/

-- ------------------------------------------------------------
-- Pre-clean: remove residue from any earlier (failed) run.
-- STG rows first (FK to DMT_SCENARIO_TBL), then scenarios.
-- ------------------------------------------------------------
begin
    delete from dmt_poz_suppliers_stg_tbl where vendor_name  like 'TEST_CSV_INTAKE_MARKER%';
    delete from dmt_csv_landing_tbl       where batch_id     like 'TEST_CSV_INTAKE_MARKER%';
    delete from dmt_scenario_tbl          where upper(scenario_name) like 'TEST_CSV_INTAKE_MARKER%';
    delete from dmt_log_tbl               where message      like '%TEST_CSV_INTAKE_MARKER%';
    commit;
end;
/

-- ------------------------------------------------------------
-- Block A — main functional tests (default session NLS)
-- ------------------------------------------------------------
declare
    c_marker  constant varchar2(40)  := 'TEST_CSV_INTAKE_MARKER';
    c_view    constant varchar2(100) := 'TEST_CSV_INTAKE_MARKER_VIEW';
    c_stg     constant varchar2(100) := 'DMT_POZ_SUPPLIERS_STG_TBL';
    l_passed  pls_integer := 0;

    l_good_csv  clob;
    l_id        number;
    l_id2       number;
    l_status    varchar2(30);
    l_loaded    number;
    l_err       clob;
    l_cnt       pls_integer;
    l_scn_id    number;
    l_scn_cnt   pls_integer;
    l_vc        varchar2(4000);
    l_date      date;
    l_num       number;
    l_raised    boolean;

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

    -- Land one CSV CLOB into DMT_CSV_LANDING_TBL and return its id.
    function land (
        p_batch    varchar2,
        p_csv      clob,
        p_scenario varchar2
    ) return number is
        l_new_id number;
    begin
        insert into dmt_csv_landing_tbl
            (batch_id, view_name, atp_table_name, file_name, csv_data, scenario_name)
        values
            (p_batch, c_view, c_stg, p_batch||'.csv', p_csv, p_scenario)
        returning csv_landing_id into l_new_id;
        commit;
        return l_new_id;
    end land;

    -- Well-formed 3-row fixture: junk header column, quoted field with
    -- comma + escaped quotes, quoted field with an embedded newline,
    -- DATE and NUMBER cells, empty cells, CRLF on row 1.
    function good_csv return clob is
    begin
        return to_clob(
            'VENDOR_NAME,SEGMENT1,END_DATE_ACTIVE,SETTLEMENT_PRIORITY,NOT_A_REAL_COL'||chr(13)||chr(10)||
            c_marker||' V1,SUP1,2025/12/31 00:00:00,10,junk1'||chr(10)||
            '"'||c_marker||' V2, ""The"" Corp",SUP2,,42.5,junk2'||chr(10)||
            '"'||c_marker||' V3'||chr(10)||'line2",SUP3,2026/01/15 08:30:00,,junk3'||chr(10));
    end good_csv;

begin
    -- ----------------------------------------------------------
    -- 1. Well-formed CSV with a scenario loads: landing row ends
    --    TFM_STATUS='LOADED' with ROWS_LOADED = 3
    -- ----------------------------------------------------------
    l_good_csv := good_csv;
    l_id := land(c_marker||'_B1', l_good_csv, c_marker||'_S1');

    dmt_csv_loader_pkg.load_csv(p_csv_landing_id => l_id);

    select status, rows_loaded, error_text
    into   l_status, l_loaded, l_err
    from   dmt_csv_landing_tbl
    where  csv_landing_id = l_id;

    assert(l_status = 'LOADED' and l_loaded = 3 and l_err is null,
       1, 'Well-formed CSV lands with landing STATUS=LOADED, ROWS_LOADED=3, no error');

    -- ----------------------------------------------------------
    -- 2. Exactly 3 STG rows exist for the fixture
    -- ----------------------------------------------------------
    select count(*) into l_cnt
    from   dmt_poz_suppliers_stg_tbl
    where  vendor_name like c_marker||' V%';

    assert(l_cnt = 3, 2, 'Exactly 3 STG rows created from the 3-row CSV');

    -- ----------------------------------------------------------
    -- 3. Column mapping is by name, not position: values land in
    --    the right columns; DATE and NUMBER cells convert; the
    --    junk CSV header (NOT_A_REAL_COL) is skipped without error
    -- ----------------------------------------------------------
    select segment1, end_date_active, settlement_priority
    into   l_vc, l_date, l_num
    from   dmt_poz_suppliers_stg_tbl
    where  vendor_name = c_marker||' V1';

    assert(l_vc = 'SUP1'
       and to_char(l_date, 'YYYY-MM-DD HH24:MI:SS') = '2025-12-31 00:00:00'
       and l_num = 10,
       3, 'Header-name mapping: SEGMENT1/END_DATE_ACTIVE/SETTLEMENT_PRIORITY correct; junk column skipped');

    -- ----------------------------------------------------------
    -- 4. Quoted field with embedded comma and escaped "" quotes
    --    round-trips exactly; empty DATE cell stores NULL
    -- ----------------------------------------------------------
    select count(*) into l_cnt
    from   dmt_poz_suppliers_stg_tbl
    where  vendor_name = c_marker||' V2, "The" Corp'
    and    end_date_active is null
    and    settlement_priority = 42.5;

    assert(l_cnt = 1,
       4, 'Quoted field with comma + escaped quotes round-trips; empty cell -> NULL');

    -- ----------------------------------------------------------
    -- 5. Quoted field with an embedded newline round-trips
    -- ----------------------------------------------------------
    select count(*) into l_cnt
    from   dmt_poz_suppliers_stg_tbl
    where  vendor_name = c_marker||' V3'||chr(10)||'line2'
    and    segment1 = 'SUP3';

    assert(l_cnt = 1, 5, 'Quoted field with embedded newline round-trips as one row');

    -- ----------------------------------------------------------
    -- 6. Infra columns left to DB defaults: STG_STATUS='NEW' on every
    --    row, STAGE_DATE populated, ERROR_TEXT empty
    -- ----------------------------------------------------------
    select count(*) into l_cnt
    from   dmt_poz_suppliers_stg_tbl
    where  vendor_name like c_marker||' V%'
    and    stg_status = 'NEW'
    and    stage_date is not null
    and    error_text is null;

    assert(l_cnt = 3, 6, 'All STG rows arrive STATUS=NEW with STAGE_DATE set and no ERROR_TEXT');

    -- ----------------------------------------------------------
    -- 7. Scenario stamping: SCENARIO_ID on every row resolves to
    --    the landing row''s SCENARIO_NAME in DMT_SCENARIO_TBL
    -- ----------------------------------------------------------
    select scenario_id into l_scn_id
    from   dmt_scenario_tbl
    where  upper(scenario_name) = upper(c_marker||'_S1');

    select count(*) into l_cnt
    from   dmt_poz_suppliers_stg_tbl
    where  vendor_name like c_marker||' V%'
    and    scenario_id = l_scn_id;

    assert(l_cnt = 3, 7, 'SCENARIO_ID stamped on all rows and resolves to the named scenario');

    -- ----------------------------------------------------------
    -- 8. Re-landing the same file: CONTRACT PIN — the loader has
    --    no duplicate detection. A second landing row with the
    --    identical payload loads again and APPENDS 3 more STG rows
    --    (dedup/idempotency is the caller''s job, e.g. via prefix
    --    or scenario discipline).
    -- ----------------------------------------------------------
    l_id2 := land(c_marker||'_B1', good_csv, c_marker||'_S1');
    dmt_csv_loader_pkg.load_csv(p_csv_landing_id => l_id2);

    select status into l_status from dmt_csv_landing_tbl where csv_landing_id = l_id2;

    select count(*) into l_cnt
    from   dmt_poz_suppliers_stg_tbl
    where  vendor_name like c_marker||' V%';

    assert(l_status = 'LOADED' and l_cnt = 6 and l_id2 != l_id,
       8, 'Re-landing same file APPENDS duplicates (contract: no duplicate rejection in the loader)');

    select count(*) into l_scn_cnt
    from   dmt_scenario_tbl
    where  upper(scenario_name) = upper(c_marker||'_S1');
    assert(l_scn_cnt = 1, 9, 'Scenario reused on re-land — no duplicate scenario row');

    -- ----------------------------------------------------------
    -- 10. Scenario is MANDATORY (decided 2026-07-07): a landing
    --     row without SCENARIO_NAME must FAIL with a reportable
    --     error and land ZERO staging rows — no silent default.
    -- ----------------------------------------------------------
    l_id := land(c_marker||'_B2', to_clob(
        'VENDOR_NAME,SEGMENT1'||chr(10)||
        c_marker||' NOSCN,SUPX'||chr(10)), null);

    dmt_csv_loader_pkg.load_csv(p_csv_landing_id => l_id);

    select status, error_text into l_status, l_err
    from   dmt_csv_landing_tbl where csv_landing_id = l_id;

    select count(*) into l_cnt
    from   dmt_poz_suppliers_stg_tbl
    where  vendor_name = c_marker||' NOSCN';

    assert(l_status = 'FAILED'
       and l_err like '%SCENARIO_NAME is required%'
       and l_cnt = 0,
       10, 'No scenario -> landing FAILED with reportable error, zero STG rows (no silent default)');

    -- ----------------------------------------------------------
    -- 11. Empty CSV_DATA fails with a reportable error
    -- ----------------------------------------------------------
    l_id := land(c_marker||'_B3', empty_clob(), c_marker||'_S2');
    dmt_csv_loader_pkg.load_csv(p_csv_landing_id => l_id);

    select status, error_text into l_status, l_err
    from   dmt_csv_landing_tbl where csv_landing_id = l_id;

    assert(l_status = 'FAILED' and l_err like '%CSV_DATA is empty%',
       11, 'Empty CSV_DATA -> landing FAILED with reportable error');

    -- ----------------------------------------------------------
    -- 12. Malformed CSV — wrong column count mid-file (an extra
    --     comma shifts a text value into the DATE column) —
    --     ALL-OR-NOTHING: the good row 1 is rolled back too,
    --     zero STG rows land, the landing row records the exact
    --     failing row number, and the error is raised to the
    --     caller (LOAD_CSV re-raises after recording).
    -- ----------------------------------------------------------
    l_id := land(c_marker||'_B4', to_clob(
        'VENDOR_NAME,SEGMENT1,END_DATE_ACTIVE,SETTLEMENT_PRIORITY'||chr(10)||
        c_marker||' M1,SUP1,2025/12/31 00:00:00,10'||chr(10)||
        c_marker||' M2,EXTRA,SHIFTED,SUP2,2025/12/31 00:00:00'||chr(10)||
        c_marker||' M3,SUP3,2026/01/15 00:00:00,30'||chr(10)), c_marker||'_S3');

    l_raised := false;
    begin
        dmt_csv_loader_pkg.load_csv(p_csv_landing_id => l_id);
    exception
        when others then
            l_raised := true;
    end;

    select status, error_text into l_status, l_err
    from   dmt_csv_landing_tbl where csv_landing_id = l_id;

    select count(*) into l_cnt
    from   dmt_poz_suppliers_stg_tbl
    where  vendor_name like c_marker||' M%';

    assert(l_raised
       and l_status = 'FAILED'
       and l_err like 'Row 2 of%'
       and l_cnt = 0,
       12, 'Malformed row mid-file -> all-or-nothing: 0 STG rows, landing FAILED naming Row 2, error raised');

    -- ----------------------------------------------------------
    -- 13. LOAD_BATCH: processes only PENDING rows of the batch,
    --     survives a failing member (good row LOADED, bad row
    --     FAILED, no exception escapes), leaves non-PENDING alone
    -- ----------------------------------------------------------
    l_id := land(c_marker||'_B5', to_clob(
        'VENDOR_NAME,SEGMENT1'||chr(10)||
        c_marker||' BATCH1,SUPB1'||chr(10)), c_marker||'_S4');

    l_id2 := land(c_marker||'_B5', to_clob(
        'VENDOR_NAME,END_DATE_ACTIVE'||chr(10)||
        c_marker||' BATCH2,not-a-date'||chr(10)), c_marker||'_S4');

    -- a third member already terminal: must not be touched
    insert into dmt_csv_landing_tbl
        (batch_id, view_name, atp_table_name, csv_data, scenario_name, status)
    values
        (c_marker||'_B5', c_view, c_stg,
         to_clob('VENDOR_NAME'||chr(10)||c_marker||' BATCH3'||chr(10)),
         c_marker||'_S4', 'LOADED');
    commit;

    dmt_csv_loader_pkg.load_batch(p_batch_id => c_marker||'_B5');

    select count(*) into l_cnt
    from   dmt_csv_landing_tbl
    where  batch_id = c_marker||'_B5' and status = 'LOADED';
    -- 2 LOADED: the good member + the pre-terminal member
    select count(*) into l_scn_cnt
    from   dmt_csv_landing_tbl
    where  batch_id = c_marker||'_B5' and status = 'FAILED';

    assert(l_cnt = 2 and l_scn_cnt = 1,
       13, 'LOAD_BATCH: good member LOADED, bad member FAILED, pre-terminal member untouched, no raise');

    select count(*) into l_cnt
    from   dmt_poz_suppliers_stg_tbl
    where  vendor_name in (c_marker||' BATCH1', c_marker||' BATCH2', c_marker||' BATCH3');
    assert(l_cnt = 1,
       14, 'LOAD_BATCH: only the good member''s row landed (bad rolled back, terminal skipped)');

    :passed := :passed + l_passed;
end;
/

-- ------------------------------------------------------------
-- Block B — session-NLS independence (design section 7:
-- "No session NLS dependence"). Poison the session date mask,
-- then prove DATE and NUMBER cells parse to the same values
-- as under the default NLS.
-- ------------------------------------------------------------
alter session set nls_date_format = 'YYYY"x"MM';

declare
    c_marker  constant varchar2(40)  := 'TEST_CSV_INTAKE_MARKER';
    c_view    constant varchar2(100) := 'TEST_CSV_INTAKE_MARKER_VIEW';
    c_stg     constant varchar2(100) := 'DMT_POZ_SUPPLIERS_STG_TBL';
    l_passed  pls_integer := 0;
    l_id      number;
    l_status  varchar2(30);
    l_date    date;
    l_num     number;

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
begin
    -- ----------------------------------------------------------
    -- 15/16. Load under a hostile NLS_DATE_FORMAT: the parse must
    --     yield the identical DATE and NUMBER values as Block A.
    -- ----------------------------------------------------------
    insert into dmt_csv_landing_tbl
        (batch_id, view_name, atp_table_name, csv_data, scenario_name)
    values
        (c_marker||'_B6', c_view, c_stg,
         to_clob('VENDOR_NAME,END_DATE_ACTIVE,SETTLEMENT_PRIORITY'||chr(10)||
                 c_marker||' NLS1,2025/12/31 00:00:00,42.5'||chr(10)),
         c_marker||'_S5')
    returning csv_landing_id into l_id;
    commit;

    dmt_csv_loader_pkg.load_csv(p_csv_landing_id => l_id);

    select status into l_status from dmt_csv_landing_tbl where csv_landing_id = l_id;
    assert(l_status = 'LOADED',
       15, 'Load succeeds under poisoned session NLS_DATE_FORMAT=''YYYY"x"MM''');

    select end_date_active, settlement_priority
    into   l_date, l_num
    from   dmt_poz_suppliers_stg_tbl
    where  vendor_name = c_marker||' NLS1';

    assert(to_char(l_date, 'YYYY-MM-DD HH24:MI:SS') = '2025-12-31 00:00:00'
       and l_num = 42.5,
       16, 'DATE and NUMBER cells parse to identical values under poisoned NLS');

    :passed := :passed + l_passed;
end;
/

alter session set nls_date_format = 'DD-MON-RR';

-- ------------------------------------------------------------
-- Block C — design-contract gap report (informational, no
-- failures). Sections 4/6/7 requirements the intake layer does
-- not yet meet; feeds the Stage B blind review.
-- ------------------------------------------------------------
declare
    l_cnt pls_integer;
begin
    dbms_output.put_line('--- Design-contract gap report (DMT_DESIGN.html sections 4/6/7) ---');

    -- DMT_CSV_UPLOAD_PKG untestable locally: APEX dependency
    select count(*) into l_cnt
    from   user_objects
    where  object_name = 'DMT_CSV_UPLOAD_PKG'
    and    object_type = 'PACKAGE BODY'
    and    status = 'INVALID';
    if l_cnt = 1 then
        dbms_output.put_line('GAP: DMT_CSV_UPLOAD_PKG body is INVALID on this install '||
            '(PLS-00201 APEX_ZIP.T_FILES — APEX not installed on local Docker). The whole Smart '||
            'Upload path (6 entry points incl. the legacy non-APEX loader mode) is uncallable and '||
            'untested here; needs an APEX-bearing environment or an APEX-free seam.');
    else
        dbms_output.put_line('OK : DMT_CSV_UPLOAD_PKG body is valid on this install.');
    end if;

    -- Scenario-mandatory rule (decided 2026-07-07) in the upload package
    select count(*) into l_cnt
    from   user_source
    where  name = 'DMT_CSV_UPLOAD_PKG' and type = 'PACKAGE'
    and    upper(text) like '%P_SCENARIO_NAME%DEFAULT NULL%';
    if l_cnt > 0 then
        dbms_output.put_line('GAP: DMT_CSV_UPLOAD_PKG still accepts P_SCENARIO_NAME DEFAULT NULL on '||
            'every entry point and loads untagged rows (batch tag literally uses ''none''). Section '||
            '4/6 decided rule: every ingestion path errors without a scenario. Enforced in '||
            'DMT_CSV_LOADER_PKG (this suite, test 10); the upload package still needs the guard.');
    end if;

    -- Upload registry seed state
    select count(*) into l_cnt from dmt_upload_object_tbl;
    if l_cnt = 0 then
        dbms_output.put_line('GAP: DMT_UPLOAD_OBJECT_TBL has 0 rows and no seed file exists in db/seed. '||
            'Section 6 calls it the upload registry behind Smart Upload; on a greenfield install no '||
            'object is uploadable. DMT_UPLOAD_DICT_PKG.SEED_DICTIONARY iterates this registry, so the '||
            'documented bootstrap seeds nothing until the registry itself is seeded.');
    end if;
    select count(*) into l_cnt from dmt_upload_dict_tbl;
    if l_cnt = 0 then
        dbms_output.put_line('GAP: DMT_UPLOAD_DICT_TBL is empty (blocked on the registry seed above). '||
            'This suite therefore tests the landing-table path (DMT_CSV_LOADER_PKG), which maps by '||
            'header/column-name intersection and does not use the dictionary.');
    end if;

    -- Section 7 standards not met by DMT_CSV_LOADER_PKG (structural — not fixed here)
    dbms_output.put_line('GAP: DMT_CSV_LOADER_PKG is built on dynamic SQL (DBMS_SQL parse/bind/execute '||
        'of a built INSERT) — section 7 bans dynamic SQL in database code objects; only deploy '||
        'scripts are exempt. Structural: the generic-target design requires it; flag for Stage B port.');
    dbms_output.put_line('GAP: DMT_CSV_LOADER_PKG.LOAD_CSV does ALTER SESSION SET NLS_DATE_FORMAT/'||
        'NLS_TIMESTAMP_FORMAT and relies on implicit VARCHAR2->DATE conversion — section 7: never '||
        'ALTER SESSION NLS, every conversion carries its mask. It also LEAKS the altered NLS to the '||
        'caller''s session (no restore). Tests 15/16 pass only because the override runs after the '||
        'poison; NLS_NUMERIC_CHARACTERS is NOT overridden, so numeric cells still depend on session NLS.');
    dbms_output.put_line('GAP: no error-code OUT parameter on LOAD_CSV/LOAD_BATCH/LOAD_ALL_PENDING — '||
        'section 7: every procedure reports outcome via an error-code parameter tested against shared '||
        'constants. LOAD_CSV signals by status+RAISE; LOAD_BATCH swallows per-member errors into a log line.');
    dbms_output.put_line('GAP: identifier prefixes — the package uses v_ locals throughout (standard: '||
        'l_), and LOAD_CSV contains nested BEGIN blocks (one-BEGIN/END rule). Sweep with the Stage B port.');
    dbms_output.put_line('NOTE: column-count mismatch alone is NOT an error — short rows are padded with '||
        'NULLs and extra trailing fields are silently dropped; rejection happens only when the shift '||
        'causes a conversion/constraint error (test 12). If the landing contract requires strict column '||
        'counts, the loader needs an explicit per-row field-count check.');
    dbms_output.put_line('NOTE: re-landing contract pinned by test 8 = append duplicates (no dedup/'||
        'idempotency in the loader). Landing lifecycle observed: PENDING -> PROCESSING -> LOADED/FAILED; '||
        'LOAD_CSV does not guard against re-running a terminal landing row directly (only LOAD_BATCH/'||
        'LOAD_ALL_PENDING filter on PENDING).');
end;
/

-- ------------------------------------------------------------
-- Cleanup — remove every row this script created
-- (STG rows first: FK to DMT_SCENARIO_TBL)
-- ------------------------------------------------------------
begin
    delete from dmt_poz_suppliers_stg_tbl where vendor_name  like 'TEST_CSV_INTAKE_MARKER%';
    delete from dmt_csv_landing_tbl       where batch_id     like 'TEST_CSV_INTAKE_MARKER%';
    delete from dmt_scenario_tbl          where upper(scenario_name) like 'TEST_CSV_INTAKE_MARKER%';
    delete from dmt_log_tbl               where message      like '%TEST_CSV_INTAKE_MARKER%';
    commit;
end;
/

-- ------------------------------------------------------------
-- Summary — only reached when every assertion passed
-- ------------------------------------------------------------
begin
    dbms_output.put_line('TEST_CSV_INTAKE: '||:passed||' passed, 0 failed');
end;
/

exit success
