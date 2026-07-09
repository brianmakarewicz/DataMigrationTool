-- ============================================================
-- test_suppliers.sql — Stage D unit tests for the Suppliers
-- vertical slice, OFFLINE steps only (phase 1: no Fusion calls):
-- CSV landing -> upstream validation -> transform -> FBDI
-- generation, for all five supplier-family sub-objects.
--
-- Self-contained SQLcl/SQL*Plus script (NOT a database object).
-- Run as DMT_OWNER against a full DMT2 install:
--   sql dmt_owner/...@//localhost:1523/FREEPDB1 @test/unit/test_suppliers.sql
--
-- Behavior:
--   - Numbered assertions; any failure raises ORA-20999 with the
--     test number + name (whenever sqlerror exit failure).
--   - All test rows carry the TESTSUP marker (scenario
--     TEST_SUPPLIERS_SCN) and are deleted at start and end, so
--     reruns are stable. STG statuses are never reset — each
--     rerun lands fresh rows and creates a new run.
--   - Spec citations reference docs/DMT_DESIGN.html sections.
--
-- Fixture note (parent-LOADED rows): the upstream validator
-- (DMT_POZ_SUP_VALIDATOR_PKG, section 5 [PRE_VALIDATION] tag row)
-- requires the parent STG row STATUS = 'LOADED'. Offline, LOADED
-- can only exist as inserted fixture state (a real LOADED needs a
-- Fusion load — phase 2), so this script direct-inserts one
-- LOADED supplier and one LOADED site, exactly the pattern the
-- old stack's insert_regression_test_data.py used for its
-- pre-existing Fusion rows. That is insert-time state, not a
-- status reset.
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
    where  upper(scenario_name) = 'TEST_SUPPLIERS_SCN';
    if l_scn is not null then
        delete from dmt_poz_suppliers_tfm_tbl
        where  stg_sequence_id in (select stg_sequence_id from dmt_poz_suppliers_stg_tbl where scenario_id = l_scn);
        delete from dmt_poz_sup_addr_tfm_tbl
        where  stg_sequence_id in (select stg_sequence_id from dmt_poz_sup_addr_stg_tbl where scenario_id = l_scn);
        delete from dmt_poz_sup_site_tfm_tbl
        where  stg_sequence_id in (select stg_sequence_id from dmt_poz_sup_site_stg_tbl where scenario_id = l_scn);
        delete from dmt_poz_sup_site_assn_tfm_tbl
        where  stg_sequence_id in (select stg_sequence_id from dmt_poz_sup_site_assn_stg_tbl where scenario_id = l_scn);
        delete from dmt_poz_sup_contacts_tfm_tbl
        where  stg_sequence_id in (select stg_sequence_id from dmt_poz_sup_contacts_stg_tbl where scenario_id = l_scn);
        delete from dmt_poz_suppliers_stg_tbl     where scenario_id = l_scn;
        delete from dmt_poz_sup_addr_stg_tbl      where scenario_id = l_scn;
        delete from dmt_poz_sup_site_stg_tbl      where scenario_id = l_scn;
        delete from dmt_poz_sup_site_assn_stg_tbl where scenario_id = l_scn;
        delete from dmt_poz_sup_contacts_stg_tbl  where scenario_id = l_scn;
        delete from dmt_scenario_tbl where scenario_id = l_scn;
    end if;
    delete from dmt_csv_landing_tbl where batch_id like 'TEST_SUP_%';
    delete from dmt_log_tbl where message like '%TESTSUP%';
    commit;
end;
/

-- ------------------------------------------------------------
-- Block A — step (a): land the five input CSVs into the five
-- STG tables via DMT_CSV_LOADER_PKG (scenario-mandatory,
-- header-driven), plus the LOADED parent fixtures.
-- ------------------------------------------------------------
declare
    l_passed  pls_integer := 0;
    l_scn     number;
    l_cnt     pls_integer;
    l_raised  boolean;

    procedure assert (p_cond boolean, p_num pls_integer, p_name varchar2) is
    begin
        if p_cond then
            l_passed := l_passed + 1;
            dbms_output.put_line('PASS  '||lpad(p_num,2)||'  '||p_name);
        else
            raise_application_error(-20999, 'FAIL test '||p_num||': '||p_name);
        end if;
    end assert;

    function land (p_batch varchar2, p_table varchar2, p_csv clob) return number is
        l_id     number;
        l_status varchar2(30);
        l_rows   number;
        l_err    clob;
    begin
        insert into dmt_csv_landing_tbl
            (batch_id, view_name, atp_table_name, file_name, csv_data, scenario_name)
        values
            (p_batch, p_batch||'_VIEW', p_table, p_batch||'.csv', p_csv, 'TEST_SUPPLIERS_SCN')
        returning csv_landing_id into l_id;
        commit;
        dmt_csv_loader_pkg.load_csv(p_csv_landing_id => l_id);
        select status, rows_loaded, error_text into l_status, l_rows, l_err
        from   dmt_csv_landing_tbl where csv_landing_id = l_id;
        if l_status <> 'LOADED' then
            raise_application_error(-20999, p_batch||' load failed ('||l_status||'): '||
                dbms_lob.substr(l_err, 3000, 1));
        end if;
        return l_rows;
    end land;

begin
    -- 1-5. Each sub-object CSV lands through the scenario-mandatory
    --      path (section 6 / CSV pipeline: DMT_CSV_LANDING_TBL ->
    --      DMT_CSV_LOADER_PKG.LOAD_CSV, header-driven).
    assert(land('TEST_SUP_SUPPLIERS', 'DMT_POZ_SUPPLIERS_STG_TBL', to_clob(
        'IMPORT_ACTION,VENDOR_NAME,SEGMENT1,ORGANIZATION_TYPE_LOOKUP_CODE,BUSINESS_RELATIONSHIP,VENDOR_TYPE_LOOKUP_CODE,SOURCE_ID'||chr(10)||
        'CREATE,TESTSUP Good-1,TSUP-G1,CORPORATION,SPEND_AUTHORIZED,SUPPLIER,TESTSUP-G1'||chr(10)||
        'CREATE,TESTSUP Good-2,TSUP-G2,CORPORATION,SPEND_AUTHORIZED,SUPPLIER,TESTSUP-G2'||chr(10)||
        'CREATE,TESTSUP Bad-1,TSUP-BAD1,INVALID_ORG_TYPE,SPEND_AUTHORIZED,SUPPLIER,TESTSUP-BAD1'||chr(10)))
        = 3, 1, 'Suppliers CSV lands 3 rows (2 GOOD + 1 Fusion-tier BAD)');

    assert(land('TEST_SUP_ADDRESSES', 'DMT_POZ_SUP_ADDR_STG_TBL', to_clob(
        'IMPORT_ACTION,VENDOR_NAME,PARTY_SITE_NAME,COUNTRY,ADDRESS_LINE1,CITY,STATE,POSTAL_CODE,SOURCE_ID'||chr(10)||
        'CREATE,TESTSUP LoadedSup,TESTSUP HQ,US,1 Test St,Testville,NY,10001,TESTSUP-ADDR-G1'||chr(10)||
        'CREATE,TESTSUP Ghost,Ghost HQ,US,9 Nowhere,Void,XX,00000,TESTSUP-ADDR-BAD1'||chr(10)))
        = 2, 2, 'Addresses CSV lands 2 rows (1 GOOD + 1 ghost-supplier BAD)');

    assert(land('TEST_SUP_SITES', 'DMT_POZ_SUP_SITE_STG_TBL', to_clob(
        'IMPORT_ACTION,VENDOR_NAME,PROCUREMENT_BUSINESS_UNIT_NAME,PARTY_SITE_NAME,VENDOR_SITE_CODE,PURCHASING_SITE_FLAG,PAY_SITE_FLAG,SOURCE_ID'||chr(10)||
        'CREATE,TESTSUP LoadedSup,US1 Business Unit,TESTSUP HQ,TSUP-SITE-G1,Y,Y,TESTSUP-SITE-G1'||chr(10)||
        'CREATE,TESTSUP Ghost,US1 Business Unit,Ghost HQ,TSUP-SITE-BAD1,Y,Y,TESTSUP-SITE-BAD1'||chr(10)))
        = 2, 3, 'Sites CSV lands 2 rows (1 GOOD + 1 ghost-supplier BAD)');

    assert(land('TEST_SUP_ASSIGNMENTS', 'DMT_POZ_SUP_SITE_ASSN_STG_TBL', to_clob(
        'IMPORT_ACTION,VENDOR_NAME,VENDOR_SITE_CODE,PROCUREMENT_BUSINESS_UNIT_NAME,BUSINESS_UNIT_NAME,SOURCE_ID'||chr(10)||
        'CREATE,TESTSUP LoadedSup,TSUP-SITE-L1,US1 Business Unit,US1 Business Unit,TESTSUP-ASSN-G1'||chr(10)||
        'CREATE,TESTSUP LoadedSup,TSUP-SITE-G1,US1 Business Unit,US1 Business Unit,TESTSUP-ASSN-BAD1'||chr(10)))
        = 2, 4, 'Assignments CSV lands 2 rows (1 GOOD [LOADED site] + 1 BAD [site not LOADED])');

    assert(land('TEST_SUP_CONTACTS', 'DMT_POZ_SUP_CONTACTS_STG_TBL', to_clob(
        'IMPORT_ACTION,VENDOR_NAME,FIRST_NAME,LAST_NAME,EMAIL_ADDRESS,PRIMARY_ADMIN_CONTACT,SOURCE_ID'||chr(10)||
        'CREATE,TESTSUP LoadedSup,Alice,Test,alice@testsup.test,Y,TESTSUP-CON-G1'||chr(10)||
        'CREATE,TESTSUP Ghost,Ghost,Contact,ghost@testsup.test,Y,TESTSUP-CON-BAD1'||chr(10)))
        = 2, 5, 'Contacts CSV lands 2 rows (1 GOOD + 1 ghost-supplier BAD)');

    select scenario_id into l_scn
    from   dmt_scenario_tbl where upper(scenario_name) = 'TEST_SUPPLIERS_SCN';

    -- 6. Every landed STG row is scenario-stamped and STATUS 'NEW'
    --    (section 3: STG STATUS default 'NEW'; scenario bound in the
    --    ingesting INSERT — "Scenario guard is structural").
    select count(*) into l_cnt from (
        select status, scenario_id from dmt_poz_suppliers_stg_tbl     where scenario_id = l_scn union all
        select status, scenario_id from dmt_poz_sup_addr_stg_tbl      where scenario_id = l_scn union all
        select status, scenario_id from dmt_poz_sup_site_stg_tbl      where scenario_id = l_scn union all
        select status, scenario_id from dmt_poz_sup_site_assn_stg_tbl where scenario_id = l_scn union all
        select status, scenario_id from dmt_poz_sup_contacts_stg_tbl  where scenario_id = l_scn
    ) where status = 'NEW';
    assert(l_cnt = 11, 6, 'all 11 landed STG rows scenario-stamped with STATUS NEW');

    -- 7. Identity PK conversion tripwire (section 7 accepted standard
    --    "Identity columns for keys"): the PK is GENERATED ALWAYS, so
    --    supplying an explicit STG_SEQUENCE_ID must raise ORA-32795.
    l_raised := false;
    begin
        insert into dmt_poz_suppliers_stg_tbl (stg_sequence_id, vendor_name, scenario_id)
        values (999999999, 'TESTSUP explicit-id', l_scn);
    exception
        when others then
            l_raised := (sqlcode = -32795);  -- cannot insert into a generated always identity column
    end;
    assert(l_raised, 7, 'explicit PK insert raises ORA-32795 (GENERATED ALWAYS identity)');

    -- Parent fixtures: LOADED supplier + LOADED site (see header note).
    insert into dmt_poz_suppliers_stg_tbl (vendor_name, segment1, status, scenario_id, source_id)
    values ('TESTSUP LoadedSup', 'TSUP-L1', 'LOADED', l_scn, 'TESTSUP_FIXTURE');
    insert into dmt_poz_sup_site_stg_tbl (vendor_name, vendor_site_code, procurement_business_unit_name, party_site_name, status, scenario_id, source_id)
    values ('TESTSUP LoadedSup', 'TSUP-SITE-L1', 'US1 Business Unit', 'TESTSUP HQ', 'LOADED', l_scn, 'TESTSUP_FIXTURE');
    commit;

    :passed := :passed + l_passed;
end;
/

-- ------------------------------------------------------------
-- Block B — step (b): upstream validator per sub-object.
-- GOOD rows (parent LOADED) pass; the BAD row is tagged
-- [PRE_VALIDATION] with ERROR_TEXT appended, never overwritten.
-- ------------------------------------------------------------
declare
    l_passed  pls_integer := 0;
    l_scn     number;
    l_status  varchar2(30);
    l_err     clob;
    l_cnt     pls_integer;

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
    from   dmt_scenario_tbl where upper(scenario_name) = 'TEST_SUPPLIERS_SCN';

    -- 8. INIT_RUN creates the run row with a prefix (tests always run
    --    with USE_PREFIX=Y; prefix is 5-digit from DMT_RUN_PREFIX_SEQ,
    --    section 6 prefix consolidation).
    dmt_pipeline_init_pkg.init_run(
        p_orchestration_code => 'Suppliers',
        p_scenario_name      => 'TEST_SUPPLIERS_SCN',
        p_source_filename    => 'test_suppliers.sql',
        p_instance_id        => 'UNIT_TEST',
        x_integration_id     => :run_id,
        x_prefix             => :prefix);
    assert(:run_id is not null and :prefix is not null and length(:prefix) = 5,
           8, 'INIT_RUN returns run id + 5-digit prefix');

    -- Seed prior error text on the ghost address row to prove APPEND
    -- (section 5: "Accumulate, never overwrite").
    update dmt_poz_sup_addr_stg_tbl
    set    error_text = '[SEED] prior error'
    where  scenario_id = l_scn and vendor_name = 'TESTSUP Ghost';
    commit;

    -- 9. Suppliers have no upstream dependency: VALIDATE_SUPPLIERS is
    --    a no-op; all 3 landed rows stay NEW (pipeline def section 6:
    --    Suppliers row has DEPENDS_ON = none). The INVALID_ORG_TYPE
    --    row deliberately passes offline validation — an invalid
    --    lookup is a Fusion-tier rejection ([FUSION_ERROR], section 5
    --    resolution order) proven in phase 2, not here.
    dmt_poz_sup_validator_pkg.validate_suppliers(:run_id);
    select count(*) into l_cnt from dmt_poz_suppliers_stg_tbl
    where  scenario_id = l_scn and status = 'NEW';
    assert(l_cnt = 3, 9, 'VALIDATE_SUPPLIERS is a no-op: all 3 supplier rows stay NEW');

    -- 10-13. Addresses (section 5 tag table, [PRE_VALIDATION] row:
    -- "required parent object/row is not LOADED ... row never
    -- proceeds to transform", written by the validators).
    dmt_poz_sup_validator_pkg.validate_addresses(:run_id);
    select status into l_status from dmt_poz_sup_addr_stg_tbl
    where  scenario_id = l_scn and vendor_name = 'TESTSUP LoadedSup';
    assert(l_status = 'NEW', 10, 'GOOD address (parent supplier LOADED) passes: stays NEW');
    select status, error_text into l_status, l_err from dmt_poz_sup_addr_stg_tbl
    where  scenario_id = l_scn and vendor_name = 'TESTSUP Ghost';
    assert(l_status = 'FAILED', 11, 'BAD address (ghost supplier) marked FAILED');
    assert(l_err like '%[PRE_VALIDATION]%', 12, 'BAD address ERROR_TEXT carries the [PRE_VALIDATION] tag');
    assert(l_err like '[SEED] prior error%[PRE_VALIDATION]%', 13,
           'ERROR_TEXT appended after the seeded text, never overwritten (section 5)');

    -- 14-15. Sites: parent supplier must be LOADED.
    dmt_poz_sup_validator_pkg.validate_sites(:run_id);
    select status into l_status from dmt_poz_sup_site_stg_tbl
    where  scenario_id = l_scn and vendor_name = 'TESTSUP LoadedSup' and vendor_site_code = 'TSUP-SITE-G1';
    assert(l_status = 'NEW', 14, 'GOOD site (parent supplier LOADED) passes: stays NEW');
    select status, error_text into l_status, l_err from dmt_poz_sup_site_stg_tbl
    where  scenario_id = l_scn and vendor_name = 'TESTSUP Ghost';
    assert(l_status = 'FAILED' and l_err like '%[PRE_VALIDATION]%', 15,
           'BAD site (ghost supplier) FAILED with [PRE_VALIDATION] tag');

    -- 16-17. Site assignments: parent SITE must be LOADED.
    dmt_poz_sup_validator_pkg.validate_site_assignments(:run_id);
    select status into l_status from dmt_poz_sup_site_assn_stg_tbl
    where  scenario_id = l_scn and vendor_site_code = 'TSUP-SITE-L1';
    assert(l_status = 'NEW', 16, 'GOOD assignment (parent site LOADED) passes: stays NEW');
    select status, error_text into l_status, l_err from dmt_poz_sup_site_assn_stg_tbl
    where  scenario_id = l_scn and vendor_site_code = 'TSUP-SITE-G1' and source_id = 'TESTSUP-ASSN-BAD1';
    assert(l_status = 'FAILED' and l_err like '%[PRE_VALIDATION]%', 17,
           'BAD assignment (site not LOADED) FAILED with [PRE_VALIDATION] tag');

    -- 18-19. Contacts: parent supplier must be LOADED.
    dmt_poz_sup_validator_pkg.validate_contacts(:run_id);
    select status into l_status from dmt_poz_sup_contacts_stg_tbl
    where  scenario_id = l_scn and vendor_name = 'TESTSUP LoadedSup';
    assert(l_status = 'NEW', 18, 'GOOD contact (parent supplier LOADED) passes: stays NEW');
    select status, error_text into l_status, l_err from dmt_poz_sup_contacts_stg_tbl
    where  scenario_id = l_scn and vendor_name = 'TESTSUP Ghost';
    assert(l_status = 'FAILED' and l_err like '%[PRE_VALIDATION]%', 19,
           'BAD contact (ghost supplier) FAILED with [PRE_VALIDATION] tag');
    commit;

    :passed := :passed + l_passed;
end;
/

-- ------------------------------------------------------------
-- Block C — step (c): transformer alone. TFM rows are stamped
-- with RUN_ID + lineage, the run prefix is applied to the
-- supplier business keys, STG data is unchanged (STG STATUS
-- moves NEW -> TRANSFORMED, the decided forward-only stage
-- status; FAILED rows never transform).
-- ------------------------------------------------------------
declare
    l_passed  pls_integer := 0;
    l_scn     number;
    l_cnt     pls_integer;
    l_vc      varchar2(4000);
    l_vc2     varchar2(4000);

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
    from   dmt_scenario_tbl where upper(scenario_name) = 'TEST_SUPPLIERS_SCN';

    dmt_poz_sup_transform_pkg.transform_suppliers(:run_id, p_scenario_id => l_scn);
    dmt_poz_sup_transform_pkg.transform_addresses(:run_id, p_scenario_id => l_scn);
    dmt_poz_sup_transform_pkg.transform_sites(:run_id, p_scenario_id => l_scn);
    dmt_poz_sup_transform_pkg.transform_site_assignments(:run_id, p_scenario_id => l_scn);
    dmt_poz_sup_transform_pkg.transform_contacts(:run_id, p_scenario_id => l_scn);
    commit;

    -- 20. Supplier TFM: the 3 NEW rows transform; the LOADED fixture
    --     is excluded (transform selects NEW/RETRY in NEW mode —
    --     Overview run-mode table).
    select count(*) into l_cnt from dmt_poz_suppliers_tfm_tbl
    where  run_id = :run_id;
    assert(l_cnt = 3, 20, 'suppliers: 3 NEW rows transform; LOADED fixture excluded');

    -- 21. TFM rows stamped: RUN_ID, STATUS STAGED (section 3 TFM
    --     lifecycle), STG_SEQUENCE_ID lineage populated.
    select count(*) into l_cnt from dmt_poz_suppliers_tfm_tbl
    where  run_id = :run_id and status = 'STAGED' and stg_sequence_id is not null;
    assert(l_cnt = 3, 21, 'supplier TFM rows: STATUS STAGED + STG_SEQUENCE_ID lineage stamped');

    -- 22-23. Prefix applied to the supplier business keys at
    --        transform (section 3: "apply the run prefix to business
    --        keys"; STG comment: "Prefix applied in TFM table").
    select vendor_name, segment1 into l_vc, l_vc2
    from   dmt_poz_suppliers_tfm_tbl t
    where  t.run_id = :run_id
    and    t.stg_sequence_id = (select stg_sequence_id from dmt_poz_suppliers_stg_tbl
                                where scenario_id = l_scn and source_id = 'TESTSUP-G1');
    assert(l_vc = :prefix||'TESTSUP Good-1', 22, 'TFM VENDOR_NAME = prefix || STG name');
    assert(l_vc2 = :prefix||'TSUP-G1', 23, 'TFM SEGMENT1 = prefix || STG segment1');

    -- 24. VENDOR_SITE_CODE is PREFIXED(...,15): 5-digit prefix +
    --     12-char code truncates to 15 chars (matches the old-stack
    --     behavior baked into the run-116 golden).
    select vendor_site_code into l_vc
    from   dmt_poz_sup_site_tfm_tbl
    where  run_id = :run_id;
    assert(l_vc = substr(:prefix||'TSUP-SITE-G1', 1, 15) and length(l_vc) = 15,
           24, 'TFM VENDOR_SITE_CODE prefixed and truncated to 15 chars');

    -- 25-26. Children: only rows that passed validation transform;
    --        FAILED rows never proceed (section 5 [PRE_VALIDATION]
    --        row: "Row never proceeds to transform").
    select count(*) into l_cnt from dmt_poz_sup_addr_tfm_tbl where run_id = :run_id;
    assert(l_cnt = 1, 25, 'addresses: only the GOOD row transforms (FAILED ghost excluded)');
    select count(*) into l_cnt from (
        select 1 from dmt_poz_sup_site_tfm_tbl      where run_id = :run_id union all
        select 1 from dmt_poz_sup_site_assn_tfm_tbl where run_id = :run_id union all
        select 1 from dmt_poz_sup_contacts_tfm_tbl  where run_id = :run_id);
    assert(l_cnt = 3, 26, 'sites/assignments/contacts: exactly the 1 GOOD row each transforms');

    -- 27. Transformed STG rows move to TRANSFORMED — the decided
    --     forward-only stage status (section 5, run-stamped-home
    --     decision: "NEW -> TRANSFORMED or FAILED, written only by
    --     the stage->transform step").
    select count(*) into l_cnt from (
        select 1 from dmt_poz_suppliers_stg_tbl     where scenario_id = l_scn and status = 'TRANSFORMED' union all
        select 1 from dmt_poz_sup_addr_stg_tbl      where scenario_id = l_scn and status = 'TRANSFORMED' union all
        select 1 from dmt_poz_sup_site_stg_tbl      where scenario_id = l_scn and status = 'TRANSFORMED' union all
        select 1 from dmt_poz_sup_site_assn_stg_tbl where scenario_id = l_scn and status = 'TRANSFORMED' union all
        select 1 from dmt_poz_sup_contacts_stg_tbl  where scenario_id = l_scn and status = 'TRANSFORMED');
    assert(l_cnt = 7, 27, 'the 7 transformed STG rows move NEW -> TRANSFORMED (3+1+1+1+1)');

    -- 28. FAILED STG rows are untouched by transform: still FAILED,
    --     no TFM row.
    select count(*) into l_cnt from dmt_poz_sup_addr_stg_tbl s
    where  s.scenario_id = l_scn and s.vendor_name = 'TESTSUP Ghost'
    and    s.status = 'FAILED'
    and    not exists (select 1 from dmt_poz_sup_addr_tfm_tbl t
                       where t.stg_sequence_id = s.stg_sequence_id);
    assert(l_cnt = 1, 28, 'FAILED ghost address untouched: still FAILED, no TFM row');

    -- 29. STG data columns unchanged — the prefix lives only on the
    --     TFM row (section 3: raw staging data kept cleanly separate
    --     from run-specific data; STG rows are never deleted).
    select count(*) into l_cnt from dmt_poz_suppliers_stg_tbl
    where  scenario_id = l_scn and vendor_name like :prefix||'%';
    assert(l_cnt = 0, 29, 'STG VENDOR_NAME still unprefixed (prefix applied only in TFM)');

    -- 30. Re-running the transform for the same run adds no duplicate
    --     TFM rows (NOT EXISTS guard on STG_SEQUENCE_ID + RUN_ID).
    dmt_poz_sup_transform_pkg.transform_suppliers(:run_id, p_scenario_id => l_scn);
    commit;
    select count(*) into l_cnt from dmt_poz_suppliers_tfm_tbl where run_id = :run_id;
    assert(l_cnt = 3, 30, 're-transform of the same run is idempotent (still 3 TFM rows)');

    :passed := :passed + l_passed;
end;
/

-- ------------------------------------------------------------
-- Block D — step (d): all five FBDI generators.
-- ------------------------------------------------------------
declare
    l_passed  pls_integer := 0;
    l_cnt     pls_integer;
    l_zip     blob;
    l_fn      varchar2(200);
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
    -- 31-33. Suppliers generator: zip + canonical filename; TFM rows
    --        advance STAGED -> GENERATED with FBDI_CSV_ID lineage
    --        (section 3: TFM.FBDI_CSV_ID -> CSV); the persisted CSV
    --        row counts the file's records (section 1: Suppliers zip
    --        contains PoSupplierImport.csv).
    dmt_poz_sup_fbdi_gen_pkg.generate_fbdi(:run_id, l_zip, l_fn);
    assert(l_zip is not null and l_fn = 'Suppliers_'||:run_id||'.zip',
           31, 'Suppliers GENERATE_FBDI returns a zip named Suppliers_<run>.zip');
    select count(*) into l_cnt from dmt_poz_suppliers_tfm_tbl
    where  run_id = :run_id and status = 'GENERATED' and fbdi_csv_id is not null;
    assert(l_cnt = 3, 32, 'supplier TFM rows advance to GENERATED with FBDI_CSV_ID stamped');
    select row_count, csv_content into l_rows, l_csv
    from   dmt_fbdi_csv_tbl
    where  run_id = :run_id and object_type = 'Suppliers' and filename = 'PoSupplierImport.csv';
    assert(l_rows = 3
           and dbms_lob.instr(l_csv, :prefix||'TESTSUP Good-1') > 0
           and dbms_lob.substr(l_csv, 2, dbms_lob.getlength(l_csv) - 1) = chr(13)||chr(10),
           33, 'persisted PoSupplierImport.csv: 3 rows, prefixed keys, CRLF-terminated');

    -- 34. The zip row is persisted for the run (section 3 FBDI_ZIP layer).
    select count(*) into l_cnt from dmt_fbdi_zip_tbl
    where  run_id = :run_id and object_type = 'Suppliers' and zip_size_bytes > 0;
    assert(l_cnt = 1, 34, 'Suppliers zip persisted in DMT_FBDI_ZIP_TBL with content');

    -- 35-38. The four child generators, one GOOD row each.
    dmt_poz_sup_addr_fbdi_gen_pkg.generate_fbdi(:run_id, l_zip, l_fn);
    assert(l_zip is not null and l_fn = 'SupplierAddresses_'||:run_id||'.zip',
           35, 'Addresses GENERATE_FBDI returns SupplierAddresses_<run>.zip (1 row)');
    dmt_poz_sup_site_fbdi_gen_pkg.generate_fbdi(:run_id, l_zip, l_fn);
    assert(l_zip is not null and l_fn = 'SupplierSites_'||:run_id||'.zip',
           36, 'Sites GENERATE_FBDI returns SupplierSites_<run>.zip (1 row)');
    dmt_poz_sup_site_assn_fbdi_gen_pkg.generate_fbdi(:run_id, l_zip, l_fn);
    assert(l_zip is not null and l_fn = 'SupplierSiteAssignments_'||:run_id||'.zip',
           37, 'Assignments GENERATE_FBDI returns SupplierSiteAssignments_<run>.zip (1 row)');
    dmt_poz_sup_cont_fbdi_gen_pkg.generate_fbdi(:run_id, l_zip, l_fn);
    assert(l_zip is not null and l_fn = 'SupplierContacts_'||:run_id||'.zip',
           38, 'Contacts GENERATE_FBDI returns SupplierContacts_<run>.zip (1 row)');

    -- 39. Every generated file's persisted CSV row count is the TFM
    --     GENERATED count for its object — nothing dropped, nothing
    --     invented (accounting spirit of section 5).
    select count(*) into l_cnt
    from   dmt_fbdi_csv_tbl
    where  run_id = :run_id
    and    ((object_type = 'Suppliers'               and row_count = 3)
         or (object_type = 'SupplierAddresses'       and row_count = 1)
         or (object_type = 'SupplierSites'           and row_count = 1)
         or (object_type = 'SupplierSiteAssignments' and row_count = 1)
         or (object_type = 'SupplierContacts'        and row_count = 1));
    assert(l_cnt = 5, 39, 'all 5 persisted CSV rows carry the exact per-object row counts');
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
    where  upper(scenario_name) = 'TEST_SUPPLIERS_SCN';
    if l_scn is not null then
        delete from dmt_poz_suppliers_tfm_tbl
        where  stg_sequence_id in (select stg_sequence_id from dmt_poz_suppliers_stg_tbl where scenario_id = l_scn);
        delete from dmt_poz_sup_addr_tfm_tbl
        where  stg_sequence_id in (select stg_sequence_id from dmt_poz_sup_addr_stg_tbl where scenario_id = l_scn);
        delete from dmt_poz_sup_site_tfm_tbl
        where  stg_sequence_id in (select stg_sequence_id from dmt_poz_sup_site_stg_tbl where scenario_id = l_scn);
        delete from dmt_poz_sup_site_assn_tfm_tbl
        where  stg_sequence_id in (select stg_sequence_id from dmt_poz_sup_site_assn_stg_tbl where scenario_id = l_scn);
        delete from dmt_poz_sup_contacts_tfm_tbl
        where  stg_sequence_id in (select stg_sequence_id from dmt_poz_sup_contacts_stg_tbl where scenario_id = l_scn);
        delete from dmt_poz_suppliers_stg_tbl     where scenario_id = l_scn;
        delete from dmt_poz_sup_addr_stg_tbl      where scenario_id = l_scn;
        delete from dmt_poz_sup_site_stg_tbl      where scenario_id = l_scn;
        delete from dmt_poz_sup_site_assn_stg_tbl where scenario_id = l_scn;
        delete from dmt_poz_sup_contacts_stg_tbl  where scenario_id = l_scn;
        delete from dmt_scenario_tbl where scenario_id = l_scn;
    end if;
    if :run_id is not null then
        delete from dmt_fbdi_zip_tbl where run_id = :run_id;
        delete from dmt_fbdi_csv_tbl where run_id = :run_id;
    end if;
    delete from dmt_csv_landing_tbl where batch_id like 'TEST_SUP_%';
    delete from dmt_log_tbl where message like '%TESTSUP%';
    commit;
end;
/

-- ------------------------------------------------------------
-- Summary — only reached when every assertion passed
-- ------------------------------------------------------------
begin
    dbms_output.put_line('TEST_SUPPLIERS: '||:passed||' passed, 0 failed');
end;
/

exit success
