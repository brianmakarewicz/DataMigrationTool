-- ============================================================
-- test_customers.sql — Wave-1 unit tests for the Customers
-- object, OFFLINE steps only (no Fusion calls):
-- CSV landing -> pre-validation -> transform -> FBDI generation.
--
-- Customers is ONE object whose single FBDI zip carries SEVEN HZ
-- CSVs (parties, locations, party sites, party site uses,
-- accounts, account sites, account site uses) — record types of
-- one object, not seven objects (contrast the five-object
-- supplier family). See db/seed/dmt_cemli_catalog_tbl.sql.
--
-- Self-contained SQLcl/SQL*Plus script (NOT a database object).
-- Run as DMT_OWNER against a full DMT2 install:
--   sql dmt_owner/...@//localhost:1523/FREEPDB1 @test/unit/test_customers.sql
--
-- Behavior:
--   - Numbered assertions; any failure raises ORA-20999 with the
--     test number + name (whenever sqlerror exit failure).
--   - All test rows carry scenario TEST_CUSTOMERS_SCN and are
--     deleted at start and end, so reruns are stable. STG statuses
--     are never reset — each rerun lands fresh rows + a new run.
--   - Spec citations reference docs/DMT_DESIGN.html sections.
--
-- Data note: the seven record types load 2 GOOD + 1 BAD rows each
-- (the exact old-stack run-116 regression rows, also behind the
-- golden Customers_116.zip). Those BAD rows are invalid-lookup or
-- ghost-parent-not-in-batch cases that only Fusion rejects, so
-- pre-validation leaves them NEW by design. To prove the
-- pre-validation contract itself (a genuine [PRE_VALIDATION] tag
-- plus the parent->child cascade), Block B lands a dedicated bad
-- fixture: one party with NULL PARTY_TYPE and one child party site
-- referencing it. This is insert-time fixture data, not a status
-- reset.
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
    where  upper(scenario_name) = 'TEST_CUSTOMERS_SCN';
    if l_scn is not null then
        delete from dmt_hz_parties_tfm_tbl         where stg_sequence_id in (select stg_sequence_id from dmt_hz_parties_stg_tbl         where scenario_id = l_scn);
        delete from dmt_hz_locations_tfm_tbl       where stg_sequence_id in (select stg_sequence_id from dmt_hz_locations_stg_tbl       where scenario_id = l_scn);
        delete from dmt_hz_party_sites_tfm_tbl     where stg_sequence_id in (select stg_sequence_id from dmt_hz_party_sites_stg_tbl     where scenario_id = l_scn);
        delete from dmt_hz_party_site_uses_tfm_tbl where stg_sequence_id in (select stg_sequence_id from dmt_hz_party_site_uses_stg_tbl where scenario_id = l_scn);
        delete from dmt_hz_accounts_tfm_tbl        where stg_sequence_id in (select stg_sequence_id from dmt_hz_accounts_stg_tbl        where scenario_id = l_scn);
        delete from dmt_hz_acct_sites_tfm_tbl      where stg_sequence_id in (select stg_sequence_id from dmt_hz_acct_sites_stg_tbl      where scenario_id = l_scn);
        delete from dmt_hz_acct_site_uses_tfm_tbl  where stg_sequence_id in (select stg_sequence_id from dmt_hz_acct_site_uses_stg_tbl  where scenario_id = l_scn);
        delete from dmt_hz_parties_stg_tbl         where scenario_id = l_scn;
        delete from dmt_hz_locations_stg_tbl       where scenario_id = l_scn;
        delete from dmt_hz_party_sites_stg_tbl     where scenario_id = l_scn;
        delete from dmt_hz_party_site_uses_stg_tbl where scenario_id = l_scn;
        delete from dmt_hz_accounts_stg_tbl        where scenario_id = l_scn;
        delete from dmt_hz_acct_sites_stg_tbl      where scenario_id = l_scn;
        delete from dmt_hz_acct_site_uses_stg_tbl  where scenario_id = l_scn;
        delete from dmt_scenario_tbl where scenario_id = l_scn;
    end if;
    delete from dmt_csv_landing_tbl where batch_id like 'TEST_CUST_%';
    delete from dmt_log_tbl where message like '%TESTCUST%';
    commit;
end;
/

-- ------------------------------------------------------------
-- Block A — step (a): land the seven input CSVs into the seven
-- HZ STG tables via DMT_CSV_LOADER_PKG (scenario-mandatory,
-- header-driven). Assert landed rows are NEW + scenario-stamped,
-- and that the identity PK rejects an explicit insert.
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
            (p_batch, p_batch||'_VIEW', p_table, p_batch||'.csv', p_csv, 'TEST_CUSTOMERS_SCN')
        returning csv_landing_id into l_id;
        commit;
        dmt_csv_loader_pkg.load_csv(p_csv_landing_id => l_id);
        select status, rows_loaded, error_text into l_status, l_rows, l_err
        from   dmt_csv_landing_tbl where csv_landing_id = l_id;
        if l_status <> 'LOADED' then
            raise_application_error(-20999,
                p_batch||' load failed ('||l_status||'): '||dbms_lob.substr(l_err,2000,1));
        end if;
        return l_rows;
    end land;
begin
    -- 1-7. Each record-type CSV loads its 3 rows (header-driven mapping;
    --      section 8 CSV landing -> STG). LOAD_CSV is scenario-mandatory.
    assert(land('TEST_CUST_PARTIES', 'DMT_HZ_PARTIES_STG_TBL', to_clob(
'PARTY_ORIG_SYSTEM,PARTY_ORIG_SYSTEM_REFERENCE,INSERT_UPDATE_FLAG,PARTY_TYPE,ORGANIZATION_NAME,SOURCE_ID'||chr(10)||
'RT_ORIG,RT-CUST-G1,I,ORGANIZATION,RT Customer Good-1,RT-PTY-RT-CUST-G1'||chr(10)||
'RT_ORIG,RT-CUST-G2,I,ORGANIZATION,RT Customer Good-2,RT-PTY-RT-CUST-G2'||chr(10)||
'RT_ORIG,RT-CUST-BAD1,I,INVALID_TYPE,RT Customer Bad-1,RT-PTY-BAD1'||chr(10)
    )) = 3, 1, 'Parties CSV lands 3 rows');

    assert(land('TEST_CUST_LOCATIONS', 'DMT_HZ_LOCATIONS_STG_TBL', to_clob(
'LOCATION_ORIG_SYSTEM,LOCATION_ORIG_SYSTEM_REFERENCE,INSERT_UPDATE_FLAG,COUNTRY,ADDRESS1,CITY,STATE,POSTAL_CODE,SOURCE_ID'||chr(10)||
'RT_ORIG,RT-LOC-G1,I,US,100 Good Blvd,New York,NY,10001,RT-LOC-RT-LOC-G1'||chr(10)||
'RT_ORIG,RT-LOC-G2,I,US,200 Good Lane,Los Angeles,CA,90001,RT-LOC-RT-LOC-G2'||chr(10)||
'RT_ORIG,RT-LOC-BAD1,I,,999 Bad Ave,Nowhere,XX,00000,RT-LOC-BAD1'||chr(10)
    )) = 3, 2, 'Locations CSV lands 3 rows');

    assert(land('TEST_CUST_PSITES', 'DMT_HZ_PARTY_SITES_STG_TBL', to_clob(
'PARTY_ORIG_SYSTEM,PARTY_ORIG_SYSTEM_REFERENCE,SITE_ORIG_SYSTEM,SITE_ORIG_SYSTEM_REFERENCE,LOCATION_ORIG_SYSTEM,LOCATION_ORIG_SYSTEM_REFERENCE,INSERT_UPDATE_FLAG,PARTY_SITE_NAME,SOURCE_ID'||chr(10)||
'RT_ORIG,RT-CUST-G1,RT_ORIG,RT-PSITE-G1,RT_ORIG,RT-LOC-G1,I,RT Good-1 Office,RT-PSITE-RT-PSITE-G1'||chr(10)||
'RT_ORIG,RT-CUST-G2,RT_ORIG,RT-PSITE-G2,RT_ORIG,RT-LOC-G2,I,RT Good-2 Office,RT-PSITE-RT-PSITE-G2'||chr(10)||
'RT_ORIG,RT-CUST-NONEXIST,RT_ORIG,RT-PSITE-BAD1,RT_ORIG,RT-LOC-G1,I,RT Bad-1 Office,RT-PSITE-BAD1'||chr(10)
    )) = 3, 3, 'Party Sites CSV lands 3 rows');

    assert(land('TEST_CUST_PSUSES', 'DMT_HZ_PARTY_SITE_USES_STG_TBL', to_clob(
'PARTY_ORIG_SYSTEM,PARTY_ORIG_SYSTEM_REFERENCE,SITE_ORIG_SYSTEM,SITE_ORIG_SYSTEM_REFERENCE,SITE_USE_TYPE,PRIMARY_FLAG,INSERT_UPDATE_FLAG,SOURCE_ID'||chr(10)||
'RT_ORIG,RT-CUST-G1,RT_ORIG,RT-PSITE-G1,BILL_TO,Y,I,RT-PSUSE-RT-PSITE-G1'||chr(10)||
'RT_ORIG,RT-CUST-G2,RT_ORIG,RT-PSITE-G2,BILL_TO,Y,I,RT-PSUSE-RT-PSITE-G2'||chr(10)||
'RT_ORIG,RT-CUST-G1,RT_ORIG,RT-PSITE-G1,INVALID_USE,Y,I,RT-PSUSE-BAD1'||chr(10)
    )) = 3, 4, 'Party Site Uses CSV lands 3 rows');

    assert(land('TEST_CUST_ACCTS', 'DMT_HZ_ACCOUNTS_STG_TBL', to_clob(
'CUST_ORIG_SYSTEM,CUST_ORIG_SYSTEM_REFERENCE,PARTY_ORIG_SYSTEM,PARTY_ORIG_SYSTEM_REFERENCE,ACCOUNT_NUMBER,INSERT_UPDATE_FLAG,CUSTOMER_TYPE,ACCOUNT_NAME,SOURCE_ID'||chr(10)||
'RT_ORIG,RT-ACCT-G1,RT_ORIG,RT-CUST-G1,RTG001,I,R,RT Customer Good-1,RT-ACCT-RT-ACCT-G1'||chr(10)||
'RT_ORIG,RT-ACCT-G2,RT_ORIG,RT-CUST-G2,RTG002,I,R,RT Customer Good-2,RT-ACCT-RT-ACCT-G2'||chr(10)||
'RT_ORIG,RT-ACCT-BAD1,RT_ORIG,RT-CUST-NONEXIST,RTBAD01,I,R,RT Customer Bad-1,RT-ACCT-BAD1'||chr(10)
    )) = 3, 5, 'Accounts CSV lands 3 rows');

    assert(land('TEST_CUST_ASITES', 'DMT_HZ_ACCT_SITES_STG_TBL', to_clob(
'CUST_ORIG_SYSTEM,CUST_ORIG_SYSTEM_REFERENCE,CUST_SITE_ORIG_SYSTEM,CUST_SITE_ORIG_SYS_REF,SITE_ORIG_SYSTEM,SITE_ORIG_SYSTEM_REFERENCE,INSERT_UPDATE_FLAG,SET_CODE,SOURCE_ID'||chr(10)||
'RT_ORIG,RT-ACCT-G1,RT_ORIG,RT-ASITE-G1,RT_ORIG,RT-PSITE-G1,I,US1 Business Unit,RT-ASITE-RT-ASITE-G1'||chr(10)||
'RT_ORIG,RT-ACCT-G2,RT_ORIG,RT-ASITE-G2,RT_ORIG,RT-PSITE-G2,I,US1 Business Unit,RT-ASITE-RT-ASITE-G2'||chr(10)||
'RT_ORIG,RT-ACCT-NONEXIST,RT_ORIG,RT-ASITE-BAD1,RT_ORIG,RT-PSITE-G1,I,US1 Business Unit,RT-ASITE-BAD1'||chr(10)
    )) = 3, 6, 'Account Sites CSV lands 3 rows');

    assert(land('TEST_CUST_ASUSES', 'DMT_HZ_ACCT_SITE_USES_STG_TBL', to_clob(
'CUST_SITE_ORIG_SYSTEM,CUST_SITE_ORIG_SYS_REF,CUST_SITEUSE_ORIG_SYSTEM,CUST_SITEUSE_ORIG_SYS_REF,SITE_USE_CODE,PRIMARY_FLAG,INSERT_UPDATE_FLAG,SET_CODE,SOURCE_ID'||chr(10)||
'RT_ORIG,RT-ASITE-G1,RT_ORIG,RT-SITEUSE-G1,BILL_TO,Y,I,US1 Business Unit,RT-SUSE-RT-SITEUSE-G1'||chr(10)||
'RT_ORIG,RT-ASITE-G2,RT_ORIG,RT-SITEUSE-G2,BILL_TO,Y,I,US1 Business Unit,RT-SUSE-RT-SITEUSE-G2'||chr(10)||
'RT_ORIG,RT-ASITE-G1,RT_ORIG,RT-SITEUSE-BAD1,INVALID_USE,Y,I,US1 Business Unit,RT-SUSE-BAD1'||chr(10)
    )) = 3, 7, 'Account Site Uses CSV lands 3 rows');

    -- 8. Every landed STG row is scenario-stamped and STG_STATUS 'NEW'
    --    (section 7 STG dictionary: STG_STATUS default 'NEW'; SCENARIO_ID
    --    bound in the creating INSERT).
    select scenario_id into l_scn
    from   dmt_scenario_tbl where upper(scenario_name)='TEST_CUSTOMERS_SCN';
    select
        (select count(*) from dmt_hz_parties_stg_tbl         where scenario_id=l_scn and stg_status='NEW')
      + (select count(*) from dmt_hz_locations_stg_tbl       where scenario_id=l_scn and stg_status='NEW')
      + (select count(*) from dmt_hz_party_sites_stg_tbl     where scenario_id=l_scn and stg_status='NEW')
      + (select count(*) from dmt_hz_party_site_uses_stg_tbl where scenario_id=l_scn and stg_status='NEW')
      + (select count(*) from dmt_hz_accounts_stg_tbl        where scenario_id=l_scn and stg_status='NEW')
      + (select count(*) from dmt_hz_acct_sites_stg_tbl      where scenario_id=l_scn and stg_status='NEW')
      + (select count(*) from dmt_hz_acct_site_uses_stg_tbl  where scenario_id=l_scn and stg_status='NEW')
      into l_cnt from dual;
    assert(l_cnt = 21, 8, 'all 21 landed STG rows scenario-stamped with STG_STATUS NEW');

    -- 9. The PK is a GENERATED ALWAYS identity: an explicit STG_SEQUENCE_ID
    --    insert must raise ORA-32795 (section 7 identity-PK rule).
    l_raised := false;
    begin
        insert into dmt_hz_parties_stg_tbl (stg_sequence_id, party_orig_system_reference, party_type, organization_name, scenario_id)
        values (999999999, 'RT-ID-PROBE', 'ORGANIZATION', 'probe', l_scn);
    exception when others then
        if sqlcode = -32795 then l_raised := true; else raise; end if;
    end;
    assert(l_raised, 9, 'explicit PK insert raises ORA-32795 (GENERATED ALWAYS identity)');

    :passed := :passed + l_passed;
end;
/

-- ------------------------------------------------------------
-- Block B — step (b): pre-validation alone. A dedicated bad
-- fixture (party with NULL PARTY_TYPE + one child party site
-- pointing at it) proves the [PRE_VALIDATION] tag and the
-- parent->child cascade. INIT_RUN provides the run + prefix.
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
    from   dmt_scenario_tbl where upper(scenario_name)='TEST_CUSTOMERS_SCN';

    dmt_pipeline_init_pkg.init_run(
        p_orchestration_code => 'Customers',
        p_scenario_name      => 'TEST_CUSTOMERS_SCN',
        p_source_filename    => 'test_customers.sql',
        p_instance_id        => 'UNIT_TEST',
        x_integration_id     => :run_id,
        x_prefix             => :prefix);
    -- 10. INIT_RUN returns a run id + 5-digit prefix (prefix system always on).
    assert(:run_id is not null and :prefix is not null and length(:prefix) = 5,
           10, 'INIT_RUN returns run id + 5-digit prefix');

    -- Dedicated pre-validation fixture: a party missing PARTY_TYPE, plus a
    -- child party site referencing it (to exercise the cascade). These carry
    -- a distinct reference so they do not collide with the golden rows.
    insert into dmt_hz_parties_stg_tbl (party_orig_system, party_orig_system_reference, insert_update_flag, party_type, organization_name, source_id, scenario_id)
    values ('RT_ORIG', 'RT-CUST-NOTYPE', 'I', NULL, 'RT No Type', 'RT-PTY-NOTYPE', l_scn);
    insert into dmt_hz_party_sites_stg_tbl (party_orig_system, party_orig_system_reference, site_orig_system, site_orig_system_reference, location_orig_system, location_orig_system_reference, insert_update_flag, party_site_name, source_id, scenario_id)
    values ('RT_ORIG', 'RT-CUST-NOTYPE', 'RT_ORIG', 'RT-PSITE-NOTYPE', 'RT_ORIG', 'RT-LOC-G1', 'I', 'No Type Office', 'RT-PSITE-NOTYPE', l_scn);
    commit;

    dmt_cust_validator_pkg.validate_pre_transform(:run_id);

    -- 11. The NULL-PARTY_TYPE party is FAILED and carries [PRE_VALIDATION]
    --     (section 5 error-tag table; ERROR_TEXT append-only).
    select stg_status, error_text into l_status, l_err
    from   dmt_hz_parties_stg_tbl where party_orig_system_reference='RT-CUST-NOTYPE' and scenario_id=l_scn;
    assert(l_status = 'FAILED' and l_err like '%[PRE_VALIDATION]%', 11,
           'party missing PARTY_TYPE marked FAILED with [PRE_VALIDATION] tag');

    -- 12. Cascade: the child party site of the failed party is FAILED and
    --     also tagged [PRE_VALIDATION].
    select stg_status, error_text into l_status, l_err
    from   dmt_hz_party_sites_stg_tbl where site_orig_system_reference='RT-PSITE-NOTYPE' and scenario_id=l_scn;
    assert(l_status = 'FAILED' and l_err like '%[PRE_VALIDATION]%', 12,
           'child party site of failed party cascade-FAILED with [PRE_VALIDATION] tag');

    -- 13. The two GOOD parties stay NEW (a clean row is never touched).
    select count(*) into l_cnt
    from   dmt_hz_parties_stg_tbl
    where  scenario_id=l_scn and party_orig_system_reference in ('RT-CUST-G1','RT-CUST-G2') and stg_status='NEW';
    assert(l_cnt = 2, 13, 'the 2 GOOD parties stay NEW after pre-validation');

    -- 14. The invalid-lookup BAD party (PARTY_TYPE=INVALID_TYPE, non-null)
    --     is NOT pre-validation FAILED: an invalid lookup value is a
    --     Fusion-tier rejection, so the row proceeds and is caught at load.
    select stg_status into l_status
    from   dmt_hz_parties_stg_tbl where party_orig_system_reference='RT-CUST-BAD1' and scenario_id=l_scn;
    assert(l_status = 'NEW', 14, 'invalid-lookup party (INVALID_TYPE) stays NEW: rejected at Fusion, not pre-validation');

    :passed := :passed + l_passed;
end;
/

-- ------------------------------------------------------------
-- Block C — step (c): transformer alone. TFM rows are stamped
-- (RUN_ID, prefix applied, TFM_STATUS STAGED); STG business data
-- is untouched (prefix lives only in TFM); STG rows advance
-- forward-only NEW -> TRANSFORMED. Only non-FAILED rows transform.
-- ------------------------------------------------------------
declare
    l_passed  pls_integer := 0;
    l_scn     number;
    l_cnt     pls_integer;
    l_ref     varchar2(240);
    l_status  varchar2(30);
begin
    select scenario_id into l_scn
    from   dmt_scenario_tbl where upper(scenario_name)='TEST_CUSTOMERS_SCN';

    declare
        procedure assert (p_cond boolean, p_num pls_integer, p_name varchar2) is
        begin
            if p_cond then
                dbms_output.put_line('PASS  '||lpad(p_num,2)||'  '||p_name);
            else
                raise_application_error(-20999, 'FAIL test '||p_num||': '||p_name);
            end if;
        end assert;
    begin
        dmt_cust_transform_pkg.transform_parties(:run_id, p_scenario_id => l_scn);
        dmt_cust_transform_pkg.transform_locations(:run_id, p_scenario_id => l_scn);
        dmt_cust_transform_pkg.transform_party_sites(:run_id, p_scenario_id => l_scn);
        dmt_cust_transform_pkg.transform_party_site_uses(:run_id, p_scenario_id => l_scn);
        dmt_cust_transform_pkg.transform_accounts(:run_id, p_scenario_id => l_scn);
        dmt_cust_transform_pkg.transform_acct_sites(:run_id, p_scenario_id => l_scn);
        dmt_cust_transform_pkg.transform_acct_site_uses(:run_id, p_scenario_id => l_scn);

        -- 15. Parties: 2 GOOD + 1 invalid-lookup BAD transform (all 3 are
        --     non-FAILED); the pre-validation NULL-type fixture is excluded.
        select count(*) into l_cnt from dmt_hz_parties_tfm_tbl where run_id=:run_id;
        assert(l_cnt = 3, 15, 'parties: 3 non-FAILED STG rows transform (NULL-type fixture excluded)');

        -- 16. TFM rows carry TFM_STATUS STAGED + STG_SEQUENCE_ID lineage
        --     (section 7 TFM dictionary).
        select count(*) into l_cnt
        from   dmt_hz_parties_tfm_tbl
        where  run_id=:run_id and tfm_status='STAGED' and stg_sequence_id is not null;
        assert(l_cnt = 3, 16, 'party TFM rows: TFM_STATUS STAGED + STG_SEQUENCE_ID lineage stamped');

        -- 17. Prefix is applied in TFM only: TFM PARTY_ORIG_SYSTEM_REFERENCE
        --     = prefix || STG reference (section on prefix scope).
        select party_orig_system_reference into l_ref
        from   dmt_hz_parties_tfm_tbl t
        where  t.run_id=:run_id
        and    t.stg_sequence_id = (select stg_sequence_id from dmt_hz_parties_stg_tbl
                                    where party_orig_system_reference='RT-CUST-G1' and scenario_id=l_scn);
        assert(l_ref = :prefix||'RT-CUST-G1', 17, 'TFM reference = prefix || STG reference');

        -- 18. TFM PARTY_ORIG_SYSTEM is set to 'DMT' by the transform.
        select count(*) into l_cnt from dmt_hz_parties_tfm_tbl where run_id=:run_id and party_orig_system='DMT';
        assert(l_cnt = 3, 18, 'TFM PARTY_ORIG_SYSTEM stamped ''DMT''');

        -- 19. STG is untouched by the transform apart from the forward-only
        --     status flip: the GOOD STG rows still carry the UNPREFIXED
        --     reference (no write-back of run-specific data to staging).
        select count(*) into l_cnt
        from   dmt_hz_parties_stg_tbl
        where  scenario_id=l_scn and party_orig_system_reference like :prefix||'%';
        assert(l_cnt = 0, 19, 'STG reference still unprefixed (prefix applied only in TFM)');

        -- 20. Transformed GOOD STG rows moved NEW -> TRANSFORMED (forward-only).
        select stg_status into l_status
        from   dmt_hz_parties_stg_tbl where party_orig_system_reference='RT-CUST-G1' and scenario_id=l_scn;
        assert(l_status = 'TRANSFORMED', 20, 'GOOD STG party advanced NEW -> TRANSFORMED');

        -- 21. The pre-validation FAILED fixture never transforms and stays
        --     FAILED (FAILED rows do not proceed).
        select count(*) into l_cnt
        from   dmt_hz_parties_tfm_tbl t
        where  t.run_id=:run_id
        and    t.stg_sequence_id = (select stg_sequence_id from dmt_hz_parties_stg_tbl
                                    where party_orig_system_reference='RT-CUST-NOTYPE' and scenario_id=l_scn);
        assert(l_cnt = 0, 21, 'pre-validation FAILED party never transforms (no TFM row)');

        -- 22. All seven record types produced TFM rows (locations 3, party
        --     sites 3, uses 3, accounts 3, acct sites 3, acct site uses 3).
        select
            (select count(*) from dmt_hz_locations_tfm_tbl       where run_id=:run_id)
          + (select count(*) from dmt_hz_party_sites_tfm_tbl     where run_id=:run_id)
          + (select count(*) from dmt_hz_party_site_uses_tfm_tbl where run_id=:run_id)
          + (select count(*) from dmt_hz_accounts_tfm_tbl        where run_id=:run_id)
          + (select count(*) from dmt_hz_acct_sites_tfm_tbl      where run_id=:run_id)
          + (select count(*) from dmt_hz_acct_site_uses_tfm_tbl  where run_id=:run_id)
          into l_cnt from dual;
        assert(l_cnt = 18, 22, 'the six child record types each produce 3 TFM rows (18 total)');

        -- 23. Re-transform of the same run is idempotent (NOT EXISTS guard):
        --     still 3 party TFM rows.
        dmt_cust_transform_pkg.transform_parties(:run_id, p_scenario_id => l_scn);
        select count(*) into l_cnt from dmt_hz_parties_tfm_tbl where run_id=:run_id;
        assert(l_cnt = 3, 23, 're-transform of the same run is idempotent (still 3 party TFM rows)');
    end;
    :passed := :passed + 9;
end;
/

-- ------------------------------------------------------------
-- Block D — step (d): the FBDI generator. One call builds the
-- single zip carrying all seven CSVs; TFM rows advance to
-- GENERATED with FBDI_CSV_ID stamped; the zip is persisted.
-- ------------------------------------------------------------
declare
    l_passed  pls_integer := 0;
    l_zip     blob;
    l_fn      varchar2(200);
    l_csv_id  number;
    l_cnt     pls_integer;
    l_names   varchar2(4000);

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
    dmt_cust_fbdi_gen_pkg.generate_fbdi(:run_id, l_zip, l_fn, l_csv_id);

    -- 24. GENERATE_FBDI returns a non-null zip named Customers_<run>.zip.
    assert(l_zip is not null and l_fn = 'Customers_'||:run_id||'.zip', 24,
           'GENERATE_FBDI returns a zip named Customers_<run>.zip');

    -- 25. All seven party TFM rows advance STAGED -> GENERATED with the
    --     FBDI_CSV_ID stamped (section 7: FBDI_CSV_ID on TFM).
    select count(*) into l_cnt
    from   dmt_hz_parties_tfm_tbl where run_id=:run_id and tfm_status='GENERATED' and fbdi_csv_id=l_csv_id;
    assert(l_cnt = 3, 25, 'party TFM rows advance to GENERATED with FBDI_CSV_ID stamped');

    -- 26. Every child record type also advanced to GENERATED (18 child rows).
    select
        (select count(*) from dmt_hz_locations_tfm_tbl       where run_id=:run_id and tfm_status='GENERATED')
      + (select count(*) from dmt_hz_party_sites_tfm_tbl     where run_id=:run_id and tfm_status='GENERATED')
      + (select count(*) from dmt_hz_party_site_uses_tfm_tbl where run_id=:run_id and tfm_status='GENERATED')
      + (select count(*) from dmt_hz_accounts_tfm_tbl        where run_id=:run_id and tfm_status='GENERATED')
      + (select count(*) from dmt_hz_acct_sites_tfm_tbl      where run_id=:run_id and tfm_status='GENERATED')
      + (select count(*) from dmt_hz_acct_site_uses_tfm_tbl  where run_id=:run_id and tfm_status='GENERATED')
      into l_cnt from dual;
    assert(l_cnt = 18, 26, 'all six child record types advance to GENERATED');

    -- 27. The zip is persisted in DMT_FBDI_ZIP_TBL with content.
    select count(*) into l_cnt
    from   dmt_fbdi_zip_tbl where run_id=:run_id and object_type='Customers' and dbms_lob.getlength(zip_content) > 0;
    assert(l_cnt = 1, 27, 'Customers zip persisted in DMT_FBDI_ZIP_TBL with content');

    :passed := :passed + l_passed;
end;
/

-- ------------------------------------------------------------
-- Cleanup — remove all fixtures so reruns are stable.
-- ------------------------------------------------------------
declare
    l_scn number;
begin
    select max(scenario_id) into l_scn
    from   dmt_scenario_tbl where upper(scenario_name)='TEST_CUSTOMERS_SCN';
    if l_scn is not null then
        delete from dmt_hz_parties_tfm_tbl         where stg_sequence_id in (select stg_sequence_id from dmt_hz_parties_stg_tbl         where scenario_id = l_scn);
        delete from dmt_hz_locations_tfm_tbl       where stg_sequence_id in (select stg_sequence_id from dmt_hz_locations_stg_tbl       where scenario_id = l_scn);
        delete from dmt_hz_party_sites_tfm_tbl     where stg_sequence_id in (select stg_sequence_id from dmt_hz_party_sites_stg_tbl     where scenario_id = l_scn);
        delete from dmt_hz_party_site_uses_tfm_tbl where stg_sequence_id in (select stg_sequence_id from dmt_hz_party_site_uses_stg_tbl where scenario_id = l_scn);
        delete from dmt_hz_accounts_tfm_tbl        where stg_sequence_id in (select stg_sequence_id from dmt_hz_accounts_stg_tbl        where scenario_id = l_scn);
        delete from dmt_hz_acct_sites_tfm_tbl      where stg_sequence_id in (select stg_sequence_id from dmt_hz_acct_sites_stg_tbl      where scenario_id = l_scn);
        delete from dmt_hz_acct_site_uses_tfm_tbl  where stg_sequence_id in (select stg_sequence_id from dmt_hz_acct_site_uses_stg_tbl  where scenario_id = l_scn);
        delete from dmt_hz_parties_stg_tbl         where scenario_id = l_scn;
        delete from dmt_hz_locations_stg_tbl       where scenario_id = l_scn;
        delete from dmt_hz_party_sites_stg_tbl     where scenario_id = l_scn;
        delete from dmt_hz_party_site_uses_stg_tbl where scenario_id = l_scn;
        delete from dmt_hz_accounts_stg_tbl        where scenario_id = l_scn;
        delete from dmt_hz_acct_sites_stg_tbl      where scenario_id = l_scn;
        delete from dmt_hz_acct_site_uses_stg_tbl  where scenario_id = l_scn;
        delete from dmt_scenario_tbl where scenario_id = l_scn;
    end if;
    if :run_id is not null then
        delete from dmt_fbdi_zip_tbl where run_id = :run_id;
        delete from dmt_fbdi_csv_tbl where run_id = :run_id;
    end if;
    delete from dmt_csv_landing_tbl where batch_id like 'TEST_CUST_%';
    delete from dmt_log_tbl where message like '%TESTCUST%';
    commit;
end;
/

-- ------------------------------------------------------------
-- Summary — only reached when every assertion passed
-- ------------------------------------------------------------
begin
    dbms_output.put_line('TEST_CUSTOMERS: '||:passed||' passed, 0 failed');
end;
/

exit success
