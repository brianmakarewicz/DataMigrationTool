-- ============================================================
-- test_dmt_util_pkg.sql — Stage B1 unit tests for DMT_UTIL_PKG
--
-- Self-contained SQLcl/SQL*Plus script (NOT a database object).
-- Run as DMT_OWNER against a full DMT2 install:
--   sql dmt_owner/...@//localhost:1523/FREEPDB1 @test/unit/test_dmt_util_pkg.sql
--
-- Behavior:
--   - Numbered assertions; any failure raises ORA-20999 with the
--     test number + name, and the script exits nonzero
--     (whenever sqlerror exit failure).
--   - All test rows carry the marker TEST_DMT_UTIL_PKG_MARKER and
--     are deleted at start and end, so reruns are stable.
--   - Design-doc (DMT_DESIGN.html section 5/7) contract gaps that
--     are NOT yet implemented in the package are reported as
--     "GAP:" lines, not failures — they feed the tranche findings.
--
-- Note on EXECUTE IMMEDIATE / nested blocks: the section-7 bans
-- apply to database objects (packages/views/etc.). This is a test
-- script; it uses nested blocks to assert expected exceptions.
-- ============================================================

whenever sqlerror exit failure
set serveroutput on size unlimited
set feedback off
set define off

variable passed number

begin :passed := 0; end;
/

-- ------------------------------------------------------------
-- Pre-clean: remove residue from any earlier (failed) run
-- ------------------------------------------------------------
begin
    delete from dmt_log_tbl           where message    like 'TEST_DMT_UTIL_PKG_MARKER%';
    delete from dmt_config_tbl        where config_key like 'TEST_DMT_UTIL_PKG_MARKER%';
    delete from dmt_scenario_tbl      where upper(scenario_name) like 'TEST_DMT_UTIL_PKG_MARKER%';
    delete from dmt_prefix_master_tbl where cemli      like 'TEST_DMT_UTIL_PKG_MARKER%';
    commit;
end;
/

-- ------------------------------------------------------------
-- Block A — main functional tests (default session NLS)
-- ------------------------------------------------------------
declare
    c_marker   constant varchar2(40) := 'TEST_DMT_UTIL_PKG_MARKER';
    c_run_id   constant number       := 991100199;   -- distinctive, no FK on DMT_LOG_TBL by design
    l_passed   pls_integer := 0;

    l_cnt      pls_integer;
    l_vc       varchar2(4000);
    l_clob     clob;
    l_clob2    clob;
    l_blob     blob;
    l_blob2    blob;
    l_b64      clob;
    l_xml      xmltype;
    l_num      number;
    l_num2     number;
    l_type     varchar2(30);
    l_pkg      varchar2(100);
    l_proc     varchar2(100);
    l_run      number;
    l_sqlerrm  varchar2(4000);

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
    -- 1. Log-type constants exist with the documented values
    -- ----------------------------------------------------------
    assert(dmt_util_pkg.c_log_info  = 'INFO'
       and dmt_util_pkg.c_log_warn  = 'WARN'
       and dmt_util_pkg.c_log_error = 'ERROR',
       1, 'C_LOG_INFO/WARN/ERROR constants have documented values');

    -- ----------------------------------------------------------
    -- 2. LOG writes a retrievable row with correct type/message/
    --    attribution (RUN_ID, PACKAGE_NAME, PROCEDURE_NAME)
    -- ----------------------------------------------------------
    dmt_util_pkg.log(
        p_run_id    => c_run_id,
        p_message   => c_marker||' T2 basic log row',
        p_log_type  => dmt_util_pkg.c_log_warn,
        p_package   => 'TEST_PKG',
        p_procedure => 'TEST_PROC');

    select max(log_type), max(package_name), max(procedure_name),
           max(run_id), count(*)
    into   l_type, l_pkg, l_proc, l_run, l_cnt
    from   dmt_log_tbl
    where  message like c_marker||' T2%';

    assert(l_cnt = 1
       and l_type = 'WARN'
       and l_pkg  = 'TEST_PKG'
       and l_proc = 'TEST_PROC'
       and l_run  = c_run_id,
       2, 'LOG row retrievable with correct type/message/run_id/package/procedure');

    -- ----------------------------------------------------------
    -- 3. LOG defaults: no run id, no type -> INFO, NULL RUN_ID
    -- ----------------------------------------------------------
    dmt_util_pkg.log(p_message => c_marker||' T3 defaults');

    select max(log_type), max(run_id), count(*)
    into   l_type, l_run, l_cnt
    from   dmt_log_tbl
    where  message like c_marker||' T3%';

    assert(l_cnt = 1 and l_type = 'INFO' and l_run is null,
       3, 'LOG defaults to INFO log type and NULL run_id');

    -- ----------------------------------------------------------
    -- 4. LOG with explicit NULL log type falls back to INFO (NVL path)
    -- ----------------------------------------------------------
    dmt_util_pkg.log(p_message => c_marker||' T4 null type', p_log_type => null);

    select max(log_type) into l_type
    from   dmt_log_tbl
    where  message like c_marker||' T4%';

    assert(l_type = 'INFO', 4, 'LOG with NULL log type stores INFO');

    -- ----------------------------------------------------------
    -- 5. LOG is autonomous — the entry survives a caller ROLLBACK
    --    (section 5: diagnostics must survive the caller''s rollback)
    -- ----------------------------------------------------------
    dmt_util_pkg.log(p_message => c_marker||' T5 survives rollback');
    rollback;

    select count(*) into l_cnt
    from   dmt_log_tbl
    where  message like c_marker||' T5%';

    assert(l_cnt = 1, 5, 'LOG entry survives caller rollback (autonomous txn)');

    -- ----------------------------------------------------------
    -- 6. LOG_ERROR writes an ERROR row carrying SQLERRM_TEXT
    -- ----------------------------------------------------------
    dmt_util_pkg.log_error(
        p_run_id    => c_run_id,
        p_message   => c_marker||' T6 error row',
        p_sqlerrm   => 'ORA-01403: no data found (test)',
        p_package   => 'TEST_PKG',
        p_procedure => 'TEST_PROC');

    select max(log_type), max(sqlerrm_text), max(run_id), count(*)
    into   l_type, l_sqlerrm, l_run, l_cnt
    from   dmt_log_tbl
    where  message like c_marker||' T6%';

    assert(l_cnt = 1
       and l_type = 'ERROR'
       and l_sqlerrm = 'ORA-01403: no data found (test)'
       and l_run = c_run_id,
       6, 'LOG_ERROR writes ERROR row with SQLERRM_TEXT and run_id');

    -- ----------------------------------------------------------
    -- 7. APPEND_ERROR on NULL returns the new message alone
    -- ----------------------------------------------------------
    l_clob := dmt_util_pkg.append_error(null, '[PRE_VALIDATION] first error');
    assert(dbms_lob.compare(l_clob, to_clob('[PRE_VALIDATION] first error')) = 0,
       7, 'APPEND_ERROR(NULL, msg) returns msg alone');

    -- ----------------------------------------------------------
    -- 8. APPEND_ERROR accumulates — two appends preserve BOTH
    --    errors in order, joined by " | " (never overwrites)
    -- ----------------------------------------------------------
    l_clob := dmt_util_pkg.append_error(null,   '[PRE_VALIDATION] first error');
    l_clob := dmt_util_pkg.append_error(l_clob, '[FUSION_ERROR] second error');
    assert(dbms_lob.compare(l_clob,
             to_clob('[PRE_VALIDATION] first error | [FUSION_ERROR] second error')) = 0,
       8, 'APPEND_ERROR accumulates both errors with " | " separator, never overwrites');

    -- ----------------------------------------------------------
    -- 9. APPEND_ERROR on an empty (zero-length) CLOB behaves like NULL
    -- ----------------------------------------------------------
    l_clob := dmt_util_pkg.append_error(empty_clob(), 'only error');
    assert(dbms_lob.compare(l_clob, to_clob('only error')) = 0,
       9, 'APPEND_ERROR(empty_clob, msg) returns msg alone');

    -- ----------------------------------------------------------
    -- 10. PREFIXED: prepend, NULL handling, truncation to max_len
    -- ----------------------------------------------------------
    assert(dmt_util_pkg.prefixed('9001', 'VENDOR1', 240) = '9001VENDOR1'
       and dmt_util_pkg.prefixed(null,   'VENDOR1', 240) = 'VENDOR1'
       and dmt_util_pkg.prefixed('9001', null,      240) is null
       and dmt_util_pkg.prefixed('9001', 'ABCDEFGH', 6)  = '9001AB'
       and length(dmt_util_pkg.prefixed('9001', rpad('X', 300, 'X'))) = 240,
       10, 'PREFIXED prepends, passes through NULLs, truncates to max_len (default 240)');

    -- ----------------------------------------------------------
    -- 11. GET_CONFIG on a missing key returns NULL (documented)
    -- ----------------------------------------------------------
    assert(dmt_util_pkg.get_config(c_marker||'_NO_SUCH_KEY') is null,
       11, 'GET_CONFIG returns NULL for a missing key');

    -- ----------------------------------------------------------
    -- 12. SET_CONFIG / GET_CONFIG round trip + upsert on re-set
    -- ----------------------------------------------------------
    dmt_util_pkg.set_config(c_marker||'_KEY', 'VALUE1', 'unit test row');
    l_vc := dmt_util_pkg.get_config(c_marker||'_KEY');
    dmt_util_pkg.set_config(c_marker||'_KEY', 'VALUE2');

    assert(l_vc = 'VALUE1'
       and dmt_util_pkg.get_config(c_marker||'_KEY') = 'VALUE2',
       12, 'SET_CONFIG upserts and GET_CONFIG round-trips the value');

    select count(*) into l_cnt
    from   dmt_config_tbl where config_key = c_marker||'_KEY';
    assert(l_cnt = 1, 13, 'SET_CONFIG re-set updates in place (no duplicate key row)');

    -- ----------------------------------------------------------
    -- 14. GET_PREFIX on an unknown CEMLI raises ORA-20010
    -- ----------------------------------------------------------
    begin
        l_vc := dmt_util_pkg.get_prefix(c_marker||'_NO_SUCH_CEMLI');
        assert(false, 14, 'GET_PREFIX unknown CEMLI should have raised');
    exception
        when others then
            assert(sqlcode = -20010, 14,
                'GET_PREFIX unknown CEMLI raises ORA-20010 (got '||sqlcode||')');
    end;

    -- ----------------------------------------------------------
    -- 15/16. TRIPWIRE: retired prefix-master mechanism (GET_PREFIX /
    --        INCREMENT_AND_GET_PREFIX over DMT_PREFIX_MASTER_TBL).
    --        Per-CEMLI prefixes are RETIRED — MUST be removed with the
    --        Stage C prefix consolidation (design section 6 P1, single
    --        per-run DMT_RUN_PREFIX_SEQ). These tests deliberately keep
    --        executing the retired code so its removal is loud: if
    --        GET_PREFIX / INCREMENT_AND_GET_PREFIX have been dropped,
    --        DELETE these tests (14/15/16 here, 31 in the hostile-NLS
    --        block) — a failure
    --        here is the retirement landing, NOT a regression.
    -- ----------------------------------------------------------
    insert into dmt_prefix_master_tbl (prefix_id, cemli, prefix, last_updated_date)
    values (999999901, c_marker||'_CEMLI', '9001', sysdate);
    commit;

    assert(dmt_util_pkg.get_prefix(c_marker||'_CEMLI') = '9001',
       15, 'TRIPWIRE (retired prefix-master): GET_PREFIX still reads current prefix — '||
           'if this fails, the retired mechanism was removed (Stage C prefix consolidation): '||
           'delete this tripwire, not a regression');

    l_vc := dmt_util_pkg.increment_and_get_prefix(c_marker||'_CEMLI', 'UNIT_TEST');
    rollback;   -- must not undo the increment (autonomous)

    assert(l_vc = '9002'
       and dmt_util_pkg.get_prefix(c_marker||'_CEMLI') = '9002',
       16, 'TRIPWIRE (retired prefix-master): INCREMENT_AND_GET_PREFIX still increments — '||
           'if this fails, the retired mechanism was removed (Stage C prefix consolidation): '||
           'delete this tripwire, not a regression');

    -- ----------------------------------------------------------
    -- 17. CLOB_TO_BLOB: NULL-safe (empty BLOB, not NULL) + correct length
    -- ----------------------------------------------------------
    l_blob := dmt_util_pkg.clob_to_blob(null);
    l_blob2 := dmt_util_pkg.clob_to_blob(to_clob('Hello'));
    assert(l_blob is not null
       and dbms_lob.getlength(l_blob) = 0
       and dbms_lob.getlength(l_blob2) = 5,
       17, 'CLOB_TO_BLOB returns empty BLOB for NULL and correct bytes otherwise');

    -- ----------------------------------------------------------
    -- 18. BASE64 round trip — small payload (single chunk)
    -- ----------------------------------------------------------
    l_blob := dmt_util_pkg.clob_to_blob(to_clob('The quick brown fox, 0123456789.'));
    l_b64  := dmt_util_pkg.base64_encode(l_blob);
    l_blob2 := dmt_util_pkg.base64_decode_clob(l_b64);
    assert(dbms_lob.compare(l_blob, l_blob2) = 0,
       18, 'BASE64 encode/decode round trip — small payload');

    -- ----------------------------------------------------------
    -- 19. BASE64 round trip — large payload (> both chunk sizes:
    --     12000-byte encode chunks, 32764-char decode chunks).
    --     Exercises multi-chunk alignment incl. CRLFs UTL_ENCODE
    --     inserts into the encoded stream.
    -- ----------------------------------------------------------
    dbms_lob.createtemporary(l_clob, true);
    for i in 1 .. 500 loop
        dbms_lob.append(l_clob, to_clob(
            'Row '||lpad(i, 6, '0')||': '||rpad('ABCDEFGHIJ', 90, 'x')||chr(10)));
    end loop;                                     -- ~50,000 bytes
    l_blob := dmt_util_pkg.clob_to_blob(l_clob);
    l_b64  := dmt_util_pkg.base64_encode(l_blob);
    l_blob2 := dmt_util_pkg.base64_decode_clob(l_b64);
    assert(dbms_lob.getlength(l_blob) > 45000
       and dbms_lob.compare(l_blob, l_blob2) = 0,
       19, 'BASE64 encode/decode round trip — 50KB multi-chunk payload');
    dbms_lob.freetemporary(l_clob);

    -- ----------------------------------------------------------
    -- 20. BASE64 edge cases: NULL decode -> empty BLOB;
    --     empty BLOB encode -> zero-length CLOB
    -- ----------------------------------------------------------
    l_blob2 := dmt_util_pkg.base64_decode_clob(null);
    dbms_lob.createtemporary(l_blob, true);       -- empty blob
    l_b64 := dmt_util_pkg.base64_encode(l_blob);
    assert(l_blob2 is not null
       and dbms_lob.getlength(l_blob2) = 0
       and nvl(dbms_lob.getlength(l_b64), 0) = 0,
       20, 'BASE64_DECODE_CLOB(NULL) -> empty BLOB; BASE64_ENCODE(empty) -> empty CLOB');

    -- ----------------------------------------------------------
    -- 21. BIP_REPORT_XML: NULL response and no <reportBytes> -> NULL
    --     (zero-rows policy belongs to the caller — section 5)
    -- ----------------------------------------------------------
    l_xml := dmt_util_pkg.bip_report_xml(null);
    assert(l_xml is null, 21, 'BIP_REPORT_XML(NULL) returns NULL');

    l_xml := dmt_util_pkg.bip_report_xml(to_clob('<env><body>no report here</body></env>'));
    assert(l_xml is null, 22, 'BIP_REPORT_XML without <reportBytes> returns NULL (no-rows)');

    -- ----------------------------------------------------------
    -- 23. BIP_REPORT_XML decodes a valid base64 payload to XMLTYPE
    -- ----------------------------------------------------------
    l_b64 := dmt_util_pkg.base64_encode(
                 dmt_util_pkg.clob_to_blob(
                     to_clob('<DATA_DS><G_1><RECORD_KEY>K1</RECORD_KEY></G_1></DATA_DS>')));
    l_xml := dmt_util_pkg.bip_report_xml(
                 to_clob('<resp><reportBytes>')||l_b64||to_clob('</reportBytes></resp>'));
    assert(l_xml is not null
       and l_xml.extract('/DATA_DS/G_1/RECORD_KEY/text()').getstringval() = 'K1',
       23, 'BIP_REPORT_XML decodes <reportBytes> base64 into parseable XMLTYPE');

    -- ----------------------------------------------------------
    -- 24. BIP_REPORT_XML: malformed <reportBytes> raises ORA-20035
    -- ----------------------------------------------------------
    begin
        l_xml := dmt_util_pkg.bip_report_xml(to_clob('<resp><reportBytes>abcd'));
        assert(false, 24, 'BIP_REPORT_XML malformed should have raised');
    exception
        when others then
            assert(sqlcode = -20035, 24,
                'BIP_REPORT_XML malformed <reportBytes> raises ORA-20035 (got '||sqlcode||')');
    end;

    -- ----------------------------------------------------------
    -- 25. BIP_REPORT_XML: undecodable garbage raises ORA-20036
    -- ----------------------------------------------------------
    begin
        l_xml := dmt_util_pkg.bip_report_xml(
                     to_clob('<resp><reportBytes>####!!!!</reportBytes></resp>'));
        assert(false, 25, 'BIP_REPORT_XML garbage bytes should have raised');
    exception
        when others then
            assert(sqlcode = -20036, 25,
                'BIP_REPORT_XML undecodable payload raises ORA-20036 (got '||sqlcode||')');
    end;

    -- ----------------------------------------------------------
    -- 26/27. GET_OR_CREATE_SCENARIO: NULL passthrough; creates once,
    --        case-insensitive + trimmed match returns the same id
    -- ----------------------------------------------------------
    assert(dmt_util_pkg.get_or_create_scenario(null) is null,
       26, 'GET_OR_CREATE_SCENARIO(NULL) returns NULL');

    l_num  := dmt_util_pkg.get_or_create_scenario(c_marker||'_Scenario');
    l_num2 := dmt_util_pkg.get_or_create_scenario('  '||upper(c_marker||'_Scenario')||' ');
    select count(*) into l_cnt
    from   dmt_scenario_tbl
    where  upper(scenario_name) = upper(c_marker||'_SCENARIO');
    commit;   -- GET_OR_CREATE_SCENARIO does not commit; persist for cleanup visibility

    assert(l_num is not null and l_num = l_num2 and l_cnt = 1,
       27, 'GET_OR_CREATE_SCENARIO creates once; case-insensitive/trimmed lookup reuses id');

    -- ----------------------------------------------------------
    -- 28. GET_DEEP_LINK NULL-safety: NULL fusion id and unknown
    --     CEMLI both return NULL (never raise)
    -- ----------------------------------------------------------
    assert(dmt_util_pkg.get_deep_link('Suppliers', null) is null
       and dmt_util_pkg.get_deep_link(c_marker||'_NO_CEMLI', '123') is null,
       28, 'GET_DEEP_LINK returns NULL for NULL id / unregistered CEMLI');

    :passed := :passed + l_passed;
end;
/

-- ------------------------------------------------------------
-- Block B — session-NLS independence (design section 7:
-- "No session NLS dependence — explicit format masks").
-- Set a deliberately hostile date mask, then prove package
-- outputs are unchanged.
-- ------------------------------------------------------------
alter session set nls_date_format = 'YYYY"x"MM';

declare
    c_marker constant varchar2(40) := 'TEST_DMT_UTIL_PKG_MARKER';
    l_passed pls_integer := 0;
    l_cnt    pls_integer;
    l_vc     varchar2(4000);
    l_clob   clob;
    l_date   date;

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
    -- 29. String helpers identical under hostile NLS_DATE_FORMAT
    -- ----------------------------------------------------------
    l_clob := dmt_util_pkg.append_error(null, 'e1');
    l_clob := dmt_util_pkg.append_error(l_clob, 'e2');
    assert(dmt_util_pkg.prefixed('9001', 'VENDOR1', 240) = '9001VENDOR1'
       and dbms_lob.compare(l_clob, to_clob('e1 | e2')) = 0,
       29, 'PREFIXED / APPEND_ERROR output unchanged under NLS_DATE_FORMAT=''YYYY"x"MM''');

    -- ----------------------------------------------------------
    -- 30. LOG still writes a valid row (LOG_DATE stored as DATE,
    --     no implicit char conversion) under hostile NLS
    -- ----------------------------------------------------------
    dmt_util_pkg.log(p_message => c_marker||' T30 nls log');
    select max(log_date), count(*) into l_date, l_cnt
    from   dmt_log_tbl
    where  message like c_marker||' T30%';
    assert(l_cnt = 1 and l_date between sysdate - 1/24 and sysdate + 1/24,
       30, 'LOG writes correct LOG_DATE under hostile session NLS');

    -- ----------------------------------------------------------
    -- 31. TRIPWIRE: retired prefix-master mechanism — MUST be removed
    --     with the Stage C prefix consolidation (design section 6 P1).
    --     If GET_PREFIX/INCREMENT_AND_GET_PREFIX have been dropped,
    --     DELETE this test (with 15/16 above). Until then it also
    --     guards NLS-safe prefix arithmetic on the retired path.
    -- ----------------------------------------------------------
    l_vc := dmt_util_pkg.increment_and_get_prefix(c_marker||'_CEMLI', 'UNIT_TEST_NLS');
    assert(l_vc = '9003',
       31, 'TRIPWIRE (retired prefix-master): INCREMENT_AND_GET_PREFIX NLS round trip — '||
           'if this fails, the retired mechanism was removed (Stage C prefix consolidation): '||
           'delete this tripwire, not a regression');

    :passed := :passed + l_passed;
end;
/

alter session set nls_date_format = 'DD-MON-RR';

-- ------------------------------------------------------------
-- Block C — design-contract gap report (informational, no failures).
-- These are documented section 5/7 requirements the package does
-- not yet implement; they feed the tranche findings.
-- ------------------------------------------------------------
declare
    l_cnt pls_integer;
begin
    dbms_output.put_line('--- Design-contract gap report (DMT_DESIGN.html sections 5/7) ---');

    -- SET_LOG_CONTEXT (section 5 log-attribution contract)
    select count(*) into l_cnt
    from   user_procedures
    where  object_name = 'DMT_UTIL_PKG' and procedure_name = 'SET_LOG_CONTEXT';
    if l_cnt = 0 then
        dbms_output.put_line('GAP: DMT_UTIL_PKG.SET_LOG_CONTEXT(p_run_id, p_queue_id) does not exist. '||
            'Section 5 contract: worker sets session log context once; LOG stamps RUN_ID+QUEUE_ID '||
            'automatically; procedures do not pass ids for logging. Current API takes p_run_id per call.');
    else
        dbms_output.put_line('OK : SET_LOG_CONTEXT exists.');
    end if;

    -- QUEUE_ID column on DMT_LOG_TBL (section 5: both ids, both indexed)
    select count(*) into l_cnt
    from   user_tab_columns
    where  table_name = 'DMT_LOG_TBL' and column_name = 'QUEUE_ID';
    if l_cnt = 0 then
        dbms_output.put_line('GAP: DMT_LOG_TBL has no QUEUE_ID column (section 5: every entry carries '||
            'RUN_ID and QUEUE_ID, both nullable, both indexed, no FKs).');
    else
        dbms_output.put_line('OK : DMT_LOG_TBL.QUEUE_ID exists.');
    end if;

    -- RUN_ID / QUEUE_ID indexes on DMT_LOG_TBL (section 5 + contract-index rule)
    select count(*) into l_cnt
    from   user_ind_columns
    where  table_name = 'DMT_LOG_TBL' and column_name = 'RUN_ID';
    if l_cnt = 0 then
        dbms_output.put_line('GAP: DMT_LOG_TBL.RUN_ID is not indexed (section 5: both attribution ids indexed).');
    end if;

    -- c_success / c_error error-code constants (section 7:
    -- "Every procedure returns an error code" / "Success/error constants, never literals")
    select count(*) into l_cnt
    from   user_source
    where  name = 'DMT_UTIL_PKG' and type = 'PACKAGE'
    and    upper(text) like '%C_SUCCESS%';
    if l_cnt = 0 then
        dbms_output.put_line('GAP: no c_success/c_error error-code constants in DMT_UTIL_PKG spec; no '||
            'procedure exposes an x_error_code parameter. Section 7: every procedure reports outcome '||
            'via an error-code OUT parameter tested against shared constants. Current API signals '||
            'by raised exceptions (-20001..-20036).');
    else
        dbms_output.put_line('OK : c_success constant found in spec.');
    end if;

    -- Date/number formatting helpers
    dbms_output.put_line('NOTE: DMT_UTIL_PKG exposes no date/number formatting helpers (no TO_CHAR '||
        'wrappers); NLS-independence was asserted over PREFIXED/APPEND_ERROR/LOG/prefix arithmetic '||
        '(tests 29-31). FBDI date formatting lives in the generators - test there with golden files.');

    -- Retired-concept observations (tables tranche rules)
    dbms_output.put_line('NOTE: package still reads DMT_PREFIX_MASTER_TBL and DMT_LOG_TBL still carries '||
        'the virtual INTEGRATION_ID (RUN_ID+0) - both flagged retired concepts in the tables-tranche '||
        'proposed rules; keep on the Stage B port list.');
end;
/

-- ------------------------------------------------------------
-- Cleanup — remove every row this script created
-- ------------------------------------------------------------
begin
    delete from dmt_log_tbl           where message    like 'TEST_DMT_UTIL_PKG_MARKER%';
    delete from dmt_config_tbl        where config_key like 'TEST_DMT_UTIL_PKG_MARKER%';
    delete from dmt_scenario_tbl      where upper(scenario_name) like 'TEST_DMT_UTIL_PKG_MARKER%';
    delete from dmt_prefix_master_tbl where cemli      like 'TEST_DMT_UTIL_PKG_MARKER%';
    commit;
end;
/

-- ------------------------------------------------------------
-- Summary — only reached when every assertion passed
-- ------------------------------------------------------------
begin
    dbms_output.put_line('TEST_DMT_UTIL_PKG: '||:passed||' passed, 0 failed');
end;
/

exit success
