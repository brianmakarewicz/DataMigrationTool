-- ============================================================
-- test_glbalances.sql — Stage E unit tests for the GLBalances
-- vertical slice, OFFLINE steps only (no Fusion calls):
-- CSV landing -> validator -> transform -> FBDI generation.
--
-- GLBalances is the simplest FBDI object: ONE object, ONE zip,
-- ONE CSV (GlInterface.csv). It has NO upstream dependency, so
-- its validator (DMT_GL_VALIDATOR_PKG) is a no-op offline — the
-- one intentional BAD row (an unbalanced journal) is a Fusion-tier
-- rejection proven in the live gate (phase 2), never offline. The
-- generator is already golden-proven byte-identical
-- (test/golden/test_glbalances_golden.sh); here we only assert it
-- runs and the rows land GENERATED with lineage.
--
-- Self-contained SQLcl/SQL*Plus script (NOT a database object).
-- Run as DMT_OWNER against a full DMT2 install:
--   sql dmt_owner/...@//localhost:1523/FREEPDB1 @test/unit/test_glbalances.sql
--
-- Behavior:
--   - Numbered assertions; any failure raises ORA-20999 with the
--     test number + name (whenever sqlerror exit failure).
--   - All test rows carry the scenario TEST_GLBAL_SCN and are
--     deleted at start and end, so reruns are stable. STG statuses
--     are never reset — each rerun lands fresh rows and a new run.
--   - Spec citations reference docs/DMT_DESIGN.html sections.
--
-- Input provenance: the 3 rows mirror the golden input
-- (test/golden/inputs/GLBalances_input.csv) — 2 GOOD balanced
-- lines of one journal (RT-JNL-G1: debit + credit) and 1 BAD
-- unbalanced line (RT-JNL-BAD1). REFERENCE1 is the journal key.
--
-- Note on nested blocks: the section-7 one-BEGIN/END rule applies
-- to database objects. This is a test script; it uses nested
-- blocks to assert expected exceptions.
-- ============================================================

whenever sqlerror exit failure
set serveroutput on size unlimited
set feedback off
set define off

variable passed  number
variable run_id  number
variable prefix  varchar2(30)

begin :passed := 0; end;
/

-- ------------------------------------------------------------
-- Pre-clean: remove residue from any earlier (failed) run.
-- TFM first (FK to STG), then STG (FK to scenario), then rest.
-- ------------------------------------------------------------
declare
    l_scn number;
begin
    select max(scenario_id) into l_scn
    from   dmt_scenario_tbl
    where  upper(scenario_name) = 'TEST_GLBAL_SCN';
    if l_scn is not null then
        delete from dmt_gl_interface_tfm_tbl
        where  stg_sequence_id in (select stg_sequence_id from dmt_gl_interface_stg_tbl where scenario_id = l_scn);
        delete from dmt_gl_interface_stg_tbl where scenario_id = l_scn;
        delete from dmt_scenario_tbl where scenario_id = l_scn;
    end if;
    delete from dmt_csv_landing_tbl where batch_id = 'TEST_GLBAL';
    delete from dmt_log_tbl where message like '%TEST_GLBAL%';
    commit;
end;
/

-- ------------------------------------------------------------
-- Block A — step (a): land the input CSV into the STG table via
-- DMT_CSV_LOADER_PKG (scenario-mandatory, header-driven).
-- ------------------------------------------------------------
declare
    l_passed  pls_integer := 0;
    l_scn     number;
    l_cnt     pls_integer;
    l_raised  boolean;
    l_id      number;
    l_status  varchar2(30);
    l_rows    number;
    l_err     clob;

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
    -- 1. The input CSV lands through the scenario-mandatory path
    --    (section 6 / CSV pipeline: DMT_CSV_LANDING_TBL ->
    --    DMT_CSV_LOADER_PKG.LOAD_CSV, header-driven). 3 rows:
    --    2 GOOD balanced lines + 1 BAD unbalanced line.
    insert into dmt_csv_landing_tbl
        (batch_id, view_name, atp_table_name, file_name, csv_data, scenario_name)
    values
        ('TEST_GLBAL', 'TEST_GLBAL_VIEW', 'DMT_GL_INTERFACE_STG_TBL', 'TEST_GLBAL.csv',
         to_clob(
            'JOURNAL_STATUS,LEDGER_NAME,ACCOUNTING_DATE,CURRENCY_CODE,ACTUAL_FLAG,USER_JE_CATEGORY_NAME,USER_JE_SOURCE_NAME,SEGMENT1,SEGMENT2,SEGMENT3,SEGMENT4,SEGMENT5,SEGMENT6,ENTERED_DR,ENTERED_CR,REFERENCE1,REFERENCE4,REFERENCE10,PERIOD_NAME,SOURCE_ID'||chr(10)||
            'NEW,US Primary Ledger,2026/04/01 00:00:00,USD,A,Adjustment,Spreadsheet,101,10,78630,120,000,000,5000,,RT-JNL-G1,RT-JNL-G1,RT good journal - debit,04-26,RT-GL-RT-JNL-G1-78630'||chr(10)||
            'NEW,US Primary Ledger,2026/04/01 00:00:00,USD,A,Adjustment,Spreadsheet,101,10,77600,120,000,000,,5000,RT-JNL-G1,RT-JNL-G1,RT good journal - credit,04-26,RT-GL-RT-JNL-G1-77600'||chr(10)||
            'NEW,US Primary Ledger,2026/04/01 00:00:00,USD,A,Adjustment,Spreadsheet,101,10,78630,120,000,000,9999.99,,RT-JNL-BAD1,RT-JNL-BAD1,BAD: unbalanced debit only,04-26,RT-GL-RT-JNL-BAD1-78630'||chr(10)),
         'TEST_GLBAL_SCN')
    returning csv_landing_id into l_id;
    commit;

    dmt_csv_loader_pkg.load_csv(p_csv_landing_id => l_id);
    select status, rows_loaded, error_text into l_status, l_rows, l_err
    from   dmt_csv_landing_tbl where csv_landing_id = l_id;
    if l_status <> 'LOADED' then
        raise_application_error(-20999, 'GLBalances load failed ('||l_status||'): '||
            dbms_lob.substr(l_err, 3000, 1));
    end if;
    assert(l_rows = 3, 1, 'GLBalances CSV lands 3 rows (2 GOOD balanced + 1 Fusion-tier BAD)');

    select scenario_id into l_scn
    from   dmt_scenario_tbl where upper(scenario_name) = 'TEST_GLBAL_SCN';

    -- 2. Every landed STG row is scenario-stamped and STG_STATUS 'NEW'
    --    (section 3: STG STG_STATUS default 'NEW'; scenario bound in the
    --    ingesting INSERT — "Scenario guard is structural").
    select count(*) into l_cnt from dmt_gl_interface_stg_tbl
    where  scenario_id = l_scn and stg_status = 'NEW';
    assert(l_cnt = 3, 2, 'all 3 landed STG rows scenario-stamped with STATUS NEW');

    -- 3. Identity PK conversion tripwire (section 7 accepted standard
    --    "Identity columns for keys"): the PK is GENERATED ALWAYS, so
    --    supplying an explicit STG_SEQUENCE_ID must raise ORA-32795.
    l_raised := false;
    begin
        insert into dmt_gl_interface_stg_tbl (stg_sequence_id, reference1, scenario_id)
        values (999999999, 'TEST_GLBAL explicit-id', l_scn);
    exception
        when others then
            l_raised := (sqlcode = -32795);  -- cannot insert into a generated always identity column
    end;
    assert(l_raised, 3, 'explicit PK insert raises ORA-32795 (GENERATED ALWAYS identity)');
    commit;

    :passed := :passed + l_passed;
end;
/

-- ------------------------------------------------------------
-- Block B — step (b): validator alone. GLBalances has NO upstream
-- dependency, so VALIDATE_PRE_TRANSFORM is a no-op: all 3 rows —
-- including the unbalanced BAD row — stay NEW. The unbalanced
-- journal is a Fusion-tier rejection ([FUSION_ERROR], section 5
-- resolution order) proven in the live gate, not offline. This
-- block also proves the validator honours ERROR_TEXT append-only
-- (section 5: "Accumulate, never overwrite") by seeding prior
-- text on a row and confirming the validator never clobbers it.
-- ------------------------------------------------------------
declare
    l_passed  pls_integer := 0;
    l_scn     number;
    l_cnt     pls_integer;
    l_status  varchar2(30);
    l_err     clob;

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
    from   dmt_scenario_tbl where upper(scenario_name) = 'TEST_GLBAL_SCN';

    -- 4. INIT_RUN creates the run row with a prefix (tests always run
    --    with USE_PREFIX=Y; prefix is 5-digit from DMT_RUN_PREFIX_SEQ,
    --    section 6 prefix consolidation).
    dmt_pipeline_init_pkg.init_run(
        p_orchestration_code => 'GLBalances',
        p_scenario_name      => 'TEST_GLBAL_SCN',
        p_source_filename    => 'test_glbalances.sql',
        p_instance_id        => 'UNIT_TEST',
        x_integration_id     => :run_id,
        x_prefix             => :prefix);
    assert(:run_id is not null and :prefix is not null and length(:prefix) = 5,
           4, 'INIT_RUN returns run id + 5-digit prefix');

    -- Seed prior error text on the BAD row to prove APPEND-only: the
    -- validator (and later steps) must never overwrite it.
    update dmt_gl_interface_stg_tbl
    set    error_text = '[SEED] prior error'
    where  scenario_id = l_scn and reference1 = 'RT-JNL-BAD1';
    commit;

    -- 5. VALIDATE_PRE_TRANSFORM is a no-op (no upstream dependency for
    --    GL balances): all 3 rows stay NEW, none flipped to FAILED.
    dmt_gl_validator_pkg.validate_pre_transform(:run_id);
    select count(*) into l_cnt from dmt_gl_interface_stg_tbl
    where  scenario_id = l_scn and stg_status = 'NEW';
    assert(l_cnt = 3, 5, 'VALIDATE_PRE_TRANSFORM is a no-op: all 3 rows stay NEW');

    -- 6. The BAD unbalanced row is NOT tagged offline — its rejection is
    --    Fusion-tier, proven live. It stays NEW here (not FAILED).
    select stg_status into l_status from dmt_gl_interface_stg_tbl
    where  scenario_id = l_scn and reference1 = 'RT-JNL-BAD1';
    assert(l_status = 'NEW', 6, 'BAD unbalanced row stays NEW offline (Fusion-tier rejection, live gate)');

    -- 7. Seeded ERROR_TEXT survives the validator untouched — proves
    --    the append-only contract (section 5): the validator never
    --    overwrites or clears accumulated error text.
    select error_text into l_err from dmt_gl_interface_stg_tbl
    where  scenario_id = l_scn and reference1 = 'RT-JNL-BAD1';
    assert(l_err = '[SEED] prior error', 7,
           'seeded ERROR_TEXT preserved (append-only; validator never overwrites)');
    commit;

    :passed := :passed + l_passed;
end;
/

-- ------------------------------------------------------------
-- Block C — step (c): transformer alone. TFM rows are stamped with
-- RUN_ID + lineage, the run prefix is applied to the journal key
-- (REFERENCE1), STG data is unchanged (STG STATUS moves NEW ->
-- TRANSFORMED, the decided forward-only stage status).
-- ------------------------------------------------------------
declare
    l_passed  pls_integer := 0;
    l_scn     number;
    l_cnt     pls_integer;
    l_ref     varchar2(100);

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
    from   dmt_scenario_tbl where upper(scenario_name) = 'TEST_GLBAL_SCN';

    dmt_gl_transform_pkg.transform(p_run_id => :run_id, p_scenario_id => l_scn);
    commit;

    -- 8. TFM: all 3 NEW rows transform for this run.
    select count(*) into l_cnt from dmt_gl_interface_tfm_tbl
    where  run_id = :run_id;
    assert(l_cnt = 3, 8, 'all 3 NEW rows transform into TFM for this run');

    -- 9. TFM rows stamped: RUN_ID, TFM_STATUS STAGED (section 3 TFM
    --    lifecycle), STG_SEQUENCE_ID lineage populated.
    select count(*) into l_cnt from dmt_gl_interface_tfm_tbl
    where  run_id = :run_id and tfm_status = 'STAGED' and stg_sequence_id is not null;
    assert(l_cnt = 3, 9, 'TFM rows: STATUS STAGED + STG_SEQUENCE_ID lineage stamped');

    -- 10. Prefix applied to the journal key REFERENCE1 at transform
    --     (section 3: "apply the run prefix to business keys"; the GL
    --     transform prefixes REFERENCE1 via DMT_UTIL_PKG.PREFIXED).
    select reference1 into l_ref
    from   dmt_gl_interface_tfm_tbl t
    where  t.run_id = :run_id
    and    t.stg_sequence_id = (select stg_sequence_id from dmt_gl_interface_stg_tbl
                                where scenario_id = l_scn and source_id = 'RT-GL-RT-JNL-G1-78630');
    assert(l_ref = :prefix||'RT-JNL-G1', 10, 'TFM REFERENCE1 = prefix || STG REFERENCE1');

    -- 11. STG data unchanged — the prefix lives only on the TFM row
    --     (section 3: raw staging data kept cleanly separate from
    --     run-specific data; STG rows are never deleted or reprefixed).
    select count(*) into l_cnt from dmt_gl_interface_stg_tbl
    where  scenario_id = l_scn and reference1 like :prefix||'%';
    assert(l_cnt = 0, 11, 'STG REFERENCE1 still unprefixed (prefix applied only in TFM)');

    -- 12. Transformed STG rows move NEW -> TRANSFORMED (section 5,
    --     forward-only stage status).
    select count(*) into l_cnt from dmt_gl_interface_stg_tbl
    where  scenario_id = l_scn and stg_status = 'TRANSFORMED';
    assert(l_cnt = 3, 12, 'the 3 transformed STG rows move NEW -> TRANSFORMED');

    -- 13. Re-running the transform for the same run adds no duplicate
    --     TFM rows (transform selects only NEW/RETRY STG rows in NEW mode;
    --     the rows are now TRANSFORMED, so a re-run inserts nothing).
    dmt_gl_transform_pkg.transform(p_run_id => :run_id, p_scenario_id => l_scn);
    commit;
    select count(*) into l_cnt from dmt_gl_interface_tfm_tbl where run_id = :run_id;
    assert(l_cnt = 3, 13, 're-transform of the same run is idempotent (still 3 TFM rows)');

    :passed := :passed + l_passed;
end;
/

-- ------------------------------------------------------------
-- Block D — step (d): the FBDI generator (already golden-proven
-- byte-identical). Here we only assert it runs, returns the
-- canonical zip, advances the rows to GENERATED with lineage, and
-- persists the single CSV (GlInterface.csv) with the row count.
-- ------------------------------------------------------------
declare
    l_passed  pls_integer := 0;
    l_cnt     pls_integer;
    l_zip     blob;
    l_fn      varchar2(200);
    l_csv_id  number;
    l_csv     clob;
    l_rows    number;

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
    -- 14. GENERATE_FBDI returns a zip named GLBalances_<run>.zip.
    dmt_gl_fbdi_gen_pkg.generate_fbdi(
        p_run_id      => :run_id,
        x_fbdi_zip    => l_zip,
        x_filename    => l_fn,
        x_fbdi_csv_id => l_csv_id);
    commit;
    assert(l_zip is not null and l_fn = 'GLBalances_'||:run_id||'.zip',
           14, 'GLBalances GENERATE_FBDI returns a zip named GLBalances_<run>.zip');

    -- 15. TFM rows advance STAGED -> GENERATED with FBDI_CSV_ID lineage
    --     (section 3: TFM.FBDI_CSV_ID -> CSV).
    select count(*) into l_cnt from dmt_gl_interface_tfm_tbl
    where  run_id = :run_id and tfm_status = 'GENERATED' and fbdi_csv_id is not null;
    assert(l_cnt = 3, 15, 'all 3 TFM rows advance to GENERATED with FBDI_CSV_ID stamped');

    -- 16. The single persisted CSV for the run carries the 3-row count
    --     and the prefixed journal key (section 1: GLBalances zip
    --     contains one CSV, GlInterface.csv — DMT_FBDI_CSV_TBL.FILENAME
    --     stores the zip name, so we key the row by object + run).
    select count(*) into l_cnt from dmt_fbdi_csv_tbl
    where  run_id = :run_id and object_type = 'GLBalances';
    assert(l_cnt = 1, 16, 'exactly one CSV row persisted for the GLBalances run');
    select row_count, csv_content into l_rows, l_csv
    from   dmt_fbdi_csv_tbl
    where  run_id = :run_id and object_type = 'GLBalances';
    assert(l_rows = 3
           and dbms_lob.instr(l_csv, :prefix||'RT-JNL-G1') > 0,
           17, 'persisted CSV: 3 rows, prefixed journal key present');

    -- 18. The zip row is persisted for the run (section 3 FBDI_ZIP layer).
    select count(*) into l_cnt from dmt_fbdi_zip_tbl
    where  run_id = :run_id and object_type = 'GLBalances' and zip_size_bytes > 0;
    assert(l_cnt = 1, 18, 'GLBalances zip persisted in DMT_FBDI_ZIP_TBL with content');
    commit;

    :passed := :passed + l_passed;
end;
/

-- ------------------------------------------------------------
-- Cleanup — remove every row this script created.
-- Order: TFM (FK to STG + CSV), ZIP (FK to CSV), CSV, STG,
-- landing, scenario, log.
-- ------------------------------------------------------------
declare
    l_scn number;
begin
    select max(scenario_id) into l_scn
    from   dmt_scenario_tbl
    where  upper(scenario_name) = 'TEST_GLBAL_SCN';
    if l_scn is not null then
        delete from dmt_gl_interface_tfm_tbl
        where  stg_sequence_id in (select stg_sequence_id from dmt_gl_interface_stg_tbl where scenario_id = l_scn);
        delete from dmt_gl_interface_stg_tbl where scenario_id = l_scn;
        delete from dmt_scenario_tbl where scenario_id = l_scn;
    end if;
    if :run_id is not null then
        delete from dmt_fbdi_zip_tbl where run_id = :run_id;
        delete from dmt_fbdi_csv_tbl where run_id = :run_id;
    end if;
    delete from dmt_csv_landing_tbl where batch_id = 'TEST_GLBAL';
    delete from dmt_log_tbl where message like '%TEST_GLBAL%';
    commit;
end;
/

-- ------------------------------------------------------------
-- Summary — only reached when every assertion passed
-- ------------------------------------------------------------
begin
    dbms_output.put_line('TEST_GLBALANCES: '||:passed||' passed, 0 failed');
end;
/

exit success
