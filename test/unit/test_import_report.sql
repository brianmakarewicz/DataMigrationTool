-- ============================================================
-- test_import_report.sql — Stage B5 unit tests for the ESS-output /
-- import-report parsing layer:
--   DMT_IMPORT_REPORT_PKG (PARSE_ERRORS, PARSE_AND_LOG_ERRORS)
--   DMT_UTIL_PKG.BIP_REPORT_XML (BIP Contract v1 response extraction)
--   DMT_UTIL_PKG.BASIC_AUTH_HEADER (>48-byte credential CRLF defect)
--   base64-decode consolidation (the 32K truncation bug family)
--
-- Self-contained SQLcl/SQL*Plus script (NOT a database object).
-- Run as DMT_OWNER against a full DMT2 install:
--   sql dmt_owner/...@//localhost:1523/FREEPDB1 @test/unit/test_import_report.sql
--
-- FULLY OFFLINE — makes no Fusion/network call. The one procedure that
-- would call Fusion (PARSE_AND_LOG_ERRORS -> GET_ESS_OUTPUT_XML) is
-- exercised with FUSION_URL temporarily NULLed (saved and restored in
-- the same block) so the HTTP layer fails before any socket opens.
--
-- Fixtures: embedded as literals because the Docker DB cannot read host
-- files. Canonical copies + provenance: test/unit/fixtures/README.md.
--
-- Behavior (suite conventions per test_dmt_util_pkg.sql):
--   - Numbered assertions; any failure raises ORA-20999 and the script
--     exits nonzero (whenever sqlerror exit failure).
--   - Test log rows carry run_id 991100599 / marker TEST_IMPORT_REPORT_MARKER
--     and are deleted at start and end — reruns are stable.
--   - Design-contract gaps are reported as "GAP:" lines, not failures.
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
    delete from dmt_log_tbl where run_id = 991100599
        or message like 'TEST_IMPORT_REPORT_MARKER%';
    commit;
end;
/

-- ------------------------------------------------------------
-- Block A — DMT_IMPORT_REPORT_PKG.PARSE_ERRORS against fixtures
-- ------------------------------------------------------------
declare
    l_passed  pls_integer := 0;
    l_errors  dmt_import_report_pkg.t_error_list;
    l_clob    clob;
    l_num     number;
    l_num2    number;

    -- fixture: test/unit/fixtures/import_report_projects_rejects.xml
    -- (REAL structure + real PROJECT_ERROR row from ESS request 9401822;
    --  see fixtures/README.md for provenance)
    c_rejects_xml constant varchar2(4000) := q'[<?xml version="1.0" encoding="UTF-8"?>
<DATA_DS>
  <G_REQUEST_ID>9401822</G_REQUEST_ID>
  <LIST_PROJECT_SUMMARY>
    <PROJECT_SUMMARY>
      <PROJECT_ACCEPTED>0</PROJECT_ACCEPTED>
      <PROJECT_REJECTED>3</PROJECT_REJECTED>
      <PROJECT_WARNING>2</PROJECT_WARNING>
    </PROJECT_SUMMARY>
  </LIST_PROJECT_SUMMARY>
  <LIST_TASK_SUMMARY>
    <TASK_SUMMARY>
      <TASK_ACCEPTED>0</TASK_ACCEPTED>
      <TASK_REJECTED>2</TASK_REJECTED>
    </TASK_SUMMARY>
  </LIST_TASK_SUMMARY>
  <LIST_PROJECT_ERROR>
    <PROJECT_ERROR>
      <PROJECT_ERROR_LINE>1</PROJECT_ERROR_LINE>
      <ERROR_PROJECT_NAME>RT Project Bad-1</ERROR_PROJECT_NAME>
      <ERROR_PROJECT_NUMBER>9173RTPRJ-BAD1</ERROR_PROJECT_NUMBER>
      <PRJ_ERR_SRC_REFERENCE>DMT-RTPRJ-BAD1</PRJ_ERR_SRC_REFERENCE>
      <PROJECT_ERR_MSG>The source application code isn&apos;t valid.</PROJECT_ERR_MSG>
    </PROJECT_ERROR>
  </LIST_PROJECT_ERROR>
  <LIST_TASK_ERROR>
    <TASK_ERROR>
      <TASK_ERROR_LINE>1</TASK_ERROR_LINE>
      <ERROR_TASK_NAME>RT Task Bad-1</ERROR_TASK_NAME>
      <ERROR_TASK_NUMBER>9173RTTSK-BAD1</ERROR_TASK_NUMBER>
      <TASK_ERR_MSG>The task references a project that was rejected.</TASK_ERR_MSG>
    </TASK_ERROR>
  </LIST_TASK_ERROR>
  <LIST_TXN_CTRL_ERROR>
    <TXN_CTRL_ERROR>
      <TC_ERR_PROJECT_NAME>RT Project Bad-1</TC_ERR_PROJECT_NAME>
      <TC_ERR_SOURCE_REFERENCE>DMT-RTTC-BAD1</TC_ERR_SOURCE_REFERENCE>
      <TC_ERR_TASK_MSG>The transaction control references a project that was rejected.</TC_ERR_TASK_MSG>
    </TXN_CTRL_ERROR>
  </LIST_TXN_CTRL_ERROR>
  <LIST_DISPLAY_SECTIONS>
    <DISPLAY_SECTIONS>
      <PROJECT_ERROR_FOUND>Y</PROJECT_ERROR_FOUND>
      <PROJECT_SUCCESS_FOUND>N</PROJECT_SUCCESS_FOUND>
      <TASK_ERROR_FOUND>Y</TASK_ERROR_FOUND>
    </DISPLAY_SECTIONS>
  </LIST_DISPLAY_SECTIONS>
</DATA_DS>]';

    -- fixture: test/unit/fixtures/import_report_projects_success.xml
    -- (reconstructed all-success report — see fixtures/README.md)
    c_success_xml constant varchar2(4000) := q'[<?xml version="1.0" encoding="UTF-8"?>
<DATA_DS>
  <G_REQUEST_ID>9401899</G_REQUEST_ID>
  <LIST_PROJECT_SUMMARY>
    <PROJECT_SUMMARY>
      <PROJECT_ACCEPTED>3</PROJECT_ACCEPTED>
      <PROJECT_REJECTED>0</PROJECT_REJECTED>
      <PROJECT_WARNING>0</PROJECT_WARNING>
    </PROJECT_SUMMARY>
  </LIST_PROJECT_SUMMARY>
  <LIST_TASK_SUMMARY>
    <TASK_SUMMARY>
      <TASK_ACCEPTED>2</TASK_ACCEPTED>
      <TASK_REJECTED>0</TASK_REJECTED>
    </TASK_SUMMARY>
  </LIST_TASK_SUMMARY>
  <LIST_PROJECT_SUCCESS>
    <PROJECT_SUCCESS>
      <SUCCESS_PROJECT_NAME>9179RT Project Good-1</SUCCESS_PROJECT_NAME>
      <SUCCESS_PROJECT_NUMBER>9179RTPRJ-GOOD1</SUCCESS_PROJECT_NUMBER>
    </PROJECT_SUCCESS>
    <PROJECT_SUCCESS>
      <SUCCESS_PROJECT_NAME>9179RT Project Good-2</SUCCESS_PROJECT_NAME>
      <SUCCESS_PROJECT_NUMBER>9179RTPRJ-GOOD2</SUCCESS_PROJECT_NUMBER>
    </PROJECT_SUCCESS>
    <PROJECT_SUCCESS>
      <SUCCESS_PROJECT_NAME>9179RT Project Good-3</SUCCESS_PROJECT_NAME>
      <SUCCESS_PROJECT_NUMBER>9179RTPRJ-GOOD3</SUCCESS_PROJECT_NUMBER>
    </PROJECT_SUCCESS>
  </LIST_PROJECT_SUCCESS>
  <LIST_DISPLAY_SECTIONS>
    <DISPLAY_SECTIONS>
      <PROJECT_ERROR_FOUND>N</PROJECT_ERROR_FOUND>
      <PROJECT_SUCCESS_FOUND>Y</PROJECT_SUCCESS_FOUND>
      <TASK_ERROR_FOUND>N</TASK_ERROR_FOUND>
    </DISPLAY_SECTIONS>
  </LIST_DISPLAY_SECTIONS>
</DATA_DS>]';

    -- fixture: test/unit/fixtures/ess_output_rcv_9417057.log
    -- (REAL plain-text ESS output, frozen ATP; abbreviated to the shape-
    --  significant head + real rejection lines — non-XML is the property
    --  under test, full file in fixtures/)
    c_rcv_log constant varchar2(4000) :=
'+===========================================================================+' || chr(10) ||
'Receiving: Version V1.0' || chr(10) ||
' ' || chr(10) ||
'+---------------------------------------------------------------------------+' || chr(10) ||
'RCV Module: Manage Receiving Transaction' || chr(10) || chr(10) ||
'Process Number: 9417057' || chr(10) ||
'An error occurred for the transaction line 493908.' || chr(10) ||
'You must enter a valid value in the SHIP_TO_ORGANIZATION_CODE column. The current value is V1.' || chr(10) ||
'An error occurred for the transaction line 493908.' || chr(10) ||
'The receiving transaction cannot be processed because an error occurred in package name default_header with error code 1 and error text User-Defined Exception.' || chr(10) ||
'Process End Time: 06-04-2026 03:04:48';

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
    -- ----------------------------------------------------------
    -- 1. Rejects fixture parses to exactly 3 errors (one per
    --    *_ERROR container; summaries / success / display-section
    --    groups are never misread as errors)
    -- ----------------------------------------------------------
    l_errors := dmt_import_report_pkg.parse_errors(to_clob(c_rejects_xml));
    assert(l_errors.count = 3,
       1, 'PARSE_ERRORS extracts exactly 3 rejection rows from the Projects import report');

    -- ----------------------------------------------------------
    -- 2. Project rejection fully attributed: source derived from the
    --    container tag, identifier from NAME/NUMBER/REFERENCE fields,
    --    the real Fusion message from PROJECT_ERR_MSG
    -- ----------------------------------------------------------
    assert(l_errors(1).error_source = 'PROJECT'
       and l_errors(1).object_type  = 'PROJECT_ERROR'
       and l_errors(1).row_identifier = 'RT Project Bad-1/9173RTPRJ-BAD1/DMT-RTPRJ-BAD1'
       and l_errors(1).error_message like 'The source application code isn%t valid.',
       2, 'Project rejection: source=PROJECT, key incl. 9173RTPRJ-BAD1, real Fusion message');

    -- ----------------------------------------------------------
    -- 3. Task rejection attributed to the task row
    -- ----------------------------------------------------------
    assert(l_errors(2).error_source = 'TASK'
       and l_errors(2).row_identifier = 'RT Task Bad-1/9173RTTSK-BAD1'
       and l_errors(2).error_message = 'The task references a project that was rejected.',
       3, 'Task rejection: source=TASK with task name/number key and message');

    -- ----------------------------------------------------------
    -- 4. Transaction-control rejection (TC_ERR_* field family)
    -- ----------------------------------------------------------
    assert(l_errors(3).error_source = 'TXN_CTRL'
       and l_errors(3).row_identifier = 'RT Project Bad-1/DMT-RTTC-BAD1'
       and l_errors(3).error_message = 'The transaction control references a project that was rejected.',
       4, 'Txn-control rejection: source=TXN_CTRL with project/reference key and message');

    -- ----------------------------------------------------------
    -- 5. Every rejection is reportable: non-null identifier AND
    --    non-null message — the two ingredients of the section-5
    --    [IMPORT_REPORT] tag ("SOURCE > key: message") that
    --    PARSE_AND_LOG_ERRORS / the row-matching UPDATE emit
    -- ----------------------------------------------------------
    assert(l_errors(1).row_identifier is not null and l_errors(1).error_message is not null
       and l_errors(2).row_identifier is not null and l_errors(2).error_message is not null
       and l_errors(3).row_identifier is not null and l_errors(3).error_message is not null,
       5, 'All rejections carry non-null key + message (reportable per [IMPORT_REPORT] convention)');

    -- ----------------------------------------------------------
    -- 6. Success counts are present and correct in both fixtures''
    --    summary sections (accepted/rejected per object). NOTE:
    --    DMT_IMPORT_REPORT_PKG exposes no API for these — extracted
    --    here directly; see GAP report.
    -- ----------------------------------------------------------
    select xmltype(c_rejects_xml).extract('/DATA_DS/LIST_PROJECT_SUMMARY/PROJECT_SUMMARY/PROJECT_REJECTED/text()').getnumberval(),
           xmltype(c_success_xml).extract('/DATA_DS/LIST_PROJECT_SUMMARY/PROJECT_SUMMARY/PROJECT_ACCEPTED/text()').getnumberval()
    into   l_num, l_num2 from dual;
    assert(l_num = 3 and l_num2 = 3,
       6, 'Summary sections carry the success/reject counts (rejects: 3 rejected; success: 3 accepted)');

    -- ----------------------------------------------------------
    -- 7. All-success report -> zero errors (success and summary
    --    groups are not error containers)
    -- ----------------------------------------------------------
    l_errors := dmt_import_report_pkg.parse_errors(to_clob(c_success_xml));
    assert(l_errors.count = 0,
       7, 'PARSE_ERRORS returns empty list for an all-success import report');

    -- ----------------------------------------------------------
    -- 8. REAL plain-text ESS output (RCV log, request 9417057) is
    --    not XML: empty list, never an exception
    -- ----------------------------------------------------------
    l_errors := dmt_import_report_pkg.parse_errors(to_clob(c_rcv_log));
    assert(l_errors.count = 0,
       8, 'PARSE_ERRORS on real non-XML ESS log text returns empty list (no raise)');

    -- ----------------------------------------------------------
    -- 9. NULL / empty CLOB -> empty list
    -- ----------------------------------------------------------
    dbms_lob.createtemporary(l_clob, true);   -- zero-length
    assert(dmt_import_report_pkg.parse_errors(null).count = 0
       and dmt_import_report_pkg.parse_errors(l_clob).count = 0,
       9, 'PARSE_ERRORS(NULL) and PARSE_ERRORS(empty CLOB) return empty lists');
    dbms_lob.freetemporary(l_clob);

    -- ----------------------------------------------------------
    -- 10. Error item with no recognizable *_MSG field falls back to
    --     the raw item XML as the message (nothing is dropped)
    -- ----------------------------------------------------------
    l_errors := dmt_import_report_pkg.parse_errors(to_clob(
        '<DATA_DS><LIST_FOO_ERROR><FOO_ERROR>' ||
        '<FOO_NUMBER>F1</FOO_NUMBER><DETAIL>Widget exploded</DETAIL>' ||
        '</FOO_ERROR></LIST_FOO_ERROR></DATA_DS>'));
    assert(l_errors.count = 1
       and l_errors(1).error_source = 'FOO'
       and l_errors(1).row_identifier = 'F1'
       and l_errors(1).error_message like '%Widget exploded%',
       10, 'No-message error item falls back to raw item XML as the message');

    :passed := :passed + l_passed;
end;
/

-- ------------------------------------------------------------
-- Block B — PARSE_AND_LOG_ERRORS offline behavior.
-- FUSION_URL is saved, NULLed, and restored around the call so the
-- download layer fails before any network socket opens (offline rule).
-- ------------------------------------------------------------
declare
    c_run_id  constant number := 991100599;
    l_passed  pls_integer := 0;
    l_saved_url varchar2(4000);
    l_ret     number;
    l_cnt     pls_integer;
    l_tagged  pls_integer;
    l_raised  pls_integer := 0;
    l_code    pls_integer;

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
    l_saved_url := dmt_util_pkg.get_config('FUSION_URL');
    dmt_util_pkg.set_config('FUSION_URL', null);
    begin
        -- Contract (tranche findings 9/23): download failure RAISES out of
        -- PARSE_AND_LOG_ERRORS. The return value only ever means "count of
        -- errors found" — 0 no longer doubles as a failure signal.
        l_ret := dmt_import_report_pkg.parse_and_log_errors(
                     p_run_id     => c_run_id,
                     p_request_id => 999999999,
                     p_cemli_code => 'UNIT_TEST');
    exception
        when others then
            l_raised := 1;
            l_code   := sqlcode;
    end;
    dmt_util_pkg.set_config('FUSION_URL', l_saved_url);

    -- ----------------------------------------------------------
    -- 11. Offline: download failure RAISES (ORA-20037 from
    --     GET_ESS_OUTPUT_XML, propagated — never swallowed into a
    --     0 return), writes attributed diagnostics (package/run_id)
    --     to DMT_LOG_TBL, and no [IMPORT_REPORT]-tagged rows appear
    --     (nothing was parsed).
    -- ----------------------------------------------------------
    select count(*),
           count(case when dbms_lob.substr(message, 15, 1) = '[IMPORT_REPORT]' then 1 end)
    into   l_cnt, l_tagged
    from   dmt_log_tbl
    where  run_id = c_run_id
    and    package_name = 'DMT_IMPORT_REPORT_PKG';

    assert(l_raised = 1 and l_code = -20037 and l_cnt >= 1 and l_tagged = 0,
       11, 'PARSE_AND_LOG_ERRORS offline: raises ORA-20037 (download failure is never a 0 return), '||
           'logs attributed diagnostics, no [IMPORT_REPORT] rows');

    :passed := :passed + l_passed;
end;
/

-- ------------------------------------------------------------
-- Block C — DMT_UTIL_PKG.BIP_REPORT_XML: Contract v1 response
-- (DMT_DESIGN.html section 5) + zero-rows + malformed + >32K.
-- ------------------------------------------------------------
declare
    l_passed  pls_integer := 0;
    l_b64     clob;
    l_resp    clob;
    l_xml     xmltype;
    l_big     clob;
    l_cnt     number;
    l_first   varchar2(240);
    l_last    varchar2(240);

    -- fixture: test/unit/fixtures/bip_contract_v1_response.xml
    -- (synthetic per section-5 seven-column contract — see fixtures/README.md)
    c_contract_xml constant varchar2(4000) := q'[<?xml version="1.0" encoding="UTF-8"?>
<DATA_DS>
  <G_1>
    <OBJECT_TYPE>SUPPLIER</OBJECT_TYPE>
    <RECORD_KEY>9001ACME SUPPLY CO</RECORD_KEY>
    <SOURCE_TYPE>BASE</SOURCE_TYPE>
    <FUSION_STATUS>SUCCESS</FUSION_STATUS>
    <FUSION_ID>300000123456789</FUSION_ID>
    <ERROR_MESSAGE></ERROR_MESSAGE>
    <LOAD_REQUEST_ID>9699001</LOAD_REQUEST_ID>
  </G_1>
  <G_1>
    <OBJECT_TYPE>SUPPLIER_SITE</OBJECT_TYPE>
    <RECORD_KEY>9001ACME SUPPLY CO~MAIN</RECORD_KEY>
    <SOURCE_TYPE>INTERFACE</SOURCE_TYPE>
    <FUSION_STATUS>ERROR</FUSION_STATUS>
    <FUSION_ID></FUSION_ID>
    <ERROR_MESSAGE>[LINE] The address country code is invalid.</ERROR_MESSAGE>
    <LOAD_REQUEST_ID>9699001</LOAD_REQUEST_ID>
  </G_1>
  <G_1>
    <OBJECT_TYPE>SUPPLIER</OBJECT_TYPE>
    <RECORD_KEY>9001BAD VENDOR LLC</RECORD_KEY>
    <SOURCE_TYPE>INTERFACE</SOURCE_TYPE>
    <FUSION_STATUS>ERROR</FUSION_STATUS>
    <FUSION_ID></FUSION_ID>
    <ERROR_MESSAGE>#IMPORT_REPORT#</ERROR_MESSAGE>
    <LOAD_REQUEST_ID>9699001</LOAD_REQUEST_ID>
  </G_1>
</DATA_DS>]';

    procedure assert (p_cond boolean, p_num pls_integer, p_name varchar2) is
    begin
        if p_cond then
            l_passed := l_passed + 1;
            dbms_output.put_line('PASS  '||lpad(p_num,2)||'  '||p_name);
        else
            raise_application_error(-20999, 'FAIL test '||p_num||': '||p_name);
        end if;
    end assert;

    -- wrap a payload CLOB in a runReport-shaped SOAP response
    function soapify (p_payload clob) return clob is
        l clob;
    begin
        dbms_lob.createtemporary(l, true);
        dbms_lob.append(l, to_clob(
            '<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">' ||
            '<env:Body><runReportResponse><runReportReturn><reportBytes>'));
        dbms_lob.append(l, dmt_util_pkg.base64_encode(dmt_util_pkg.clob_to_blob(p_payload)));
        dbms_lob.append(l, to_clob(
            '</reportBytes><reportContentType>text/xml</reportContentType>' ||
            '</runReportReturn></runReportResponse></env:Body></env:Envelope>'));
        return l;
    end soapify;

begin
    -- ----------------------------------------------------------
    -- 12. Contract v1 fixture: BIP_REPORT_XML decodes the SOAP
    --     <reportBytes> into /DATA_DS/G_1 rows carrying all seven
    --     contract columns in order
    -- ----------------------------------------------------------
    l_resp := soapify(to_clob(c_contract_xml));
    l_xml  := dmt_util_pkg.bip_report_xml(l_resp);

    select count(*) into l_cnt
    from xmltable('/DATA_DS/G_1' passing l_xml
         columns object_type     varchar2(100)  path 'OBJECT_TYPE',
                 record_key      varchar2(240)  path 'RECORD_KEY',
                 source_type     varchar2(30)   path 'SOURCE_TYPE',
                 fusion_status   varchar2(30)   path 'FUSION_STATUS',
                 fusion_id       varchar2(100)  path 'FUSION_ID',
                 error_message   varchar2(4000) path 'ERROR_MESSAGE',
                 load_request_id varchar2(30)   path 'LOAD_REQUEST_ID')
    where object_type is not null and record_key is not null
      and source_type is not null and fusion_status is not null
      and load_request_id is not null;
    assert(l_cnt = 3,
       12, 'Contract v1 response: 3 G_1 rows, all seven columns addressable');

    -- ----------------------------------------------------------
    -- 13. BASE/SUCCESS row carries the mandatory FUSION_ID
    --     ("positive success + Fusion IDs" made structural);
    --     INTERFACE rows have NULL FUSION_ID
    -- ----------------------------------------------------------
    select count(case when source_type='BASE' and fusion_status='SUCCESS'
                       and fusion_id = '300000123456789' then 1 end),
           count(case when source_type='INTERFACE' and fusion_id is not null then 1 end)
    into   l_cnt, l_first
    from xmltable('/DATA_DS/G_1' passing l_xml
         columns source_type   varchar2(30)  path 'SOURCE_TYPE',
                 fusion_status varchar2(30)  path 'FUSION_STATUS',
                 fusion_id     varchar2(100) path 'FUSION_ID');
    assert(l_cnt = 1 and to_number(l_first) = 0,
       13, 'BASE/SUCCESS row has non-null FUSION_ID; INTERFACE rows have NULL FUSION_ID');

    -- ----------------------------------------------------------
    -- 14. ERROR rows: level-tagged reportable text ([LINE] ...) and
    --     the #IMPORT_REPORT# fallback marker pass through verbatim
    -- ----------------------------------------------------------
    select count(case when fusion_status='ERROR'
                       and error_message = '[LINE] The address country code is invalid.' then 1 end),
           count(case when error_message = '#IMPORT_REPORT#' then 1 end)
    into   l_cnt, l_first
    from xmltable('/DATA_DS/G_1' passing l_xml
         columns fusion_status varchar2(30)   path 'FUSION_STATUS',
                 error_message varchar2(4000) path 'ERROR_MESSAGE');
    assert(l_cnt = 1 and to_number(l_first) = 1,
       14, 'ERROR rows: [LINE]-tagged message and #IMPORT_REPORT# fallback marker intact');

    -- ----------------------------------------------------------
    -- 15. Zero-rows response (no <reportBytes>) -> NULL per contract
    --     (the caller applies its no-rows policy; zero rows is never
    --     success — section 5)
    -- ----------------------------------------------------------
    l_xml := dmt_util_pkg.bip_report_xml(to_clob(
        '<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">' ||
        '<env:Body><runReportResponse/></env:Body></env:Envelope>'));
    assert(l_xml is null,
       15, 'Zero-rows BIP response (no reportBytes) returns NULL per contract');

    -- ----------------------------------------------------------
    -- 16. Malformed <reportBytes> (unterminated) raises ORA-20035
    -- ----------------------------------------------------------
    begin
        l_xml := dmt_util_pkg.bip_report_xml(to_clob('<resp><reportBytes>QUJD'));
        assert(false, 16, 'malformed reportBytes should have raised');
    exception
        when others then
            assert(sqlcode = -20035, 16,
                'Malformed <reportBytes> raises ORA-20035 (got '||sqlcode||')');
    end;

    -- ----------------------------------------------------------
    -- 17. Well-formed tags, undecodable/unparseable payload raises
    --     ORA-20036 (the -20035 family: never silent NULL)
    -- ----------------------------------------------------------
    begin
        l_xml := dmt_util_pkg.bip_report_xml(
                     to_clob('<resp><reportBytes>####!!!!</reportBytes></resp>'));
        assert(false, 17, 'garbage payload should have raised');
    exception
        when others then
            assert(sqlcode = -20036, 17,
                'Undecodable report payload raises ORA-20036 (got '||sqlcode||')');
    end;

    -- ----------------------------------------------------------
    -- 18. >32K round trip — SYNTHETIC 400-row Contract v1 payload
    --     (~90KB decoded; base64 ~120K chars incl. the CR/LFs
    --     UTL_ENCODE emits every 64 chars). This is the fixture that
    --     exposed the truncation-defect family: any decoder that
    --     reads <reportBytes> into a VARCHAR2(32767) (the pre-fix
    --     CAPTURE_ESS_HIERARCHY / CAPTURE_REPORT_ESS_JOB path) or
    --     4-aligns raw un-stripped chunks (pre-fix BIP_REQUEST)
    --     loses or corrupts this payload.
    -- ----------------------------------------------------------
    dbms_lob.createtemporary(l_big, true);
    dbms_lob.append(l_big, to_clob('<DATA_DS>'));
    for i in 1 .. 400 loop
        dbms_lob.append(l_big, to_clob(
            '<G_1><OBJECT_TYPE>SUPPLIER</OBJECT_TYPE>' ||
            '<RECORD_KEY>9001SYNTH SUPPLIER ' || lpad(i, 6, '0') || '</RECORD_KEY>' ||
            '<SOURCE_TYPE>BASE</SOURCE_TYPE><FUSION_STATUS>SUCCESS</FUSION_STATUS>' ||
            '<FUSION_ID>3000001' || lpad(i, 8, '0') || '</FUSION_ID>' ||
            '<ERROR_MESSAGE>' || rpad('x', 80, 'x') || '</ERROR_MESSAGE>' ||
            '<LOAD_REQUEST_ID>9699001</LOAD_REQUEST_ID></G_1>'));
    end loop;
    dbms_lob.append(l_big, to_clob('</DATA_DS>'));

    l_resp := soapify(l_big);
    assert(dbms_lob.getlength(l_resp) > 32767, 18,
        'big-fixture sanity: encoded response exceeds 32767 chars (' ||
        dbms_lob.getlength(l_resp) || ')');

    l_xml := dmt_util_pkg.bip_report_xml(l_resp);
    select count(*), min(record_key), max(record_key)
    into   l_cnt, l_first, l_last
    from xmltable('/DATA_DS/G_1' passing l_xml
         columns record_key varchar2(240) path 'RECORD_KEY');
    assert(l_cnt = 400
       and l_first = '9001SYNTH SUPPLIER 000001'
       and l_last  = '9001SYNTH SUPPLIER 000400',
       19, '>32K reportBytes round trip: all 400 rows survive, first/last keys intact');
    dbms_lob.freetemporary(l_big);

    :passed := :passed + l_passed;
end;
/

-- ------------------------------------------------------------
-- Block D — defect-family regression guards:
-- (a) base64-decode consolidation onto DMT_UTIL_PKG.BASE64_DECODE_CLOB
--     (static USER_SOURCE assertions — the private HTTP-calling
--     procedures cannot be executed offline, so the guard is that no
--     inline decoder exists to regress);
-- (b) BASIC_AUTH_HEADER >48-byte credential (the UTL_ENCODE CRLF bug).
-- ------------------------------------------------------------
declare
    l_passed  pls_integer := 0;
    l_cnt     pls_integer;
    l_cnt2    pls_integer;
    l_hdr     varchar2(500);
    l_user    constant varchar2(30) := 'unittestuser';
    l_pass    constant varchar2(60) := rpad('Pw', 60, 'x');  -- user:pass = 73 bytes > 48
    l_decoded varchar2(500);

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
    -- ----------------------------------------------------------
    -- 20. DMT_ESS_UTIL_PKG carries NO inline base64 decoder and no
    --     VARCHAR2-bound reportBytes REGEXP extraction (pre-fix:
    --     CAPTURE_ESS_HIERARCHY + CAPTURE_REPORT_ESS_JOB both did —
    --     the third/fourth sightings of the 32K bug family)
    -- ----------------------------------------------------------
    select count(case when upper(text) like '%UTL_ENCODE.BASE64_DECODE%' then 1 end),
           count(case when upper(text) like '%REGEXP_SUBSTR%' and upper(text) like '%REPORTBYTES%' then 1 end)
    into   l_cnt, l_cnt2
    from   user_source
    where  name = 'DMT_ESS_UTIL_PKG' and type = 'PACKAGE BODY';
    assert(l_cnt = 0 and l_cnt2 = 0,
       20, 'DMT_ESS_UTIL_PKG body: no inline base64 decode, no VARCHAR2 reportBytes extraction');

    -- ----------------------------------------------------------
    -- 21. DMT_UTIL_PKG: the ONLY base64-decode call site is inside
    --     BASE64_DECODE_CLOB itself (pre-fix: BIP_REQUEST carried a
    --     second, whitespace-unsafe copy)
    -- ----------------------------------------------------------
    select count(case when upper(text) like '%UTL_ENCODE.BASE64_DECODE%' then 1 end)
    into   l_cnt
    from   user_source
    where  name = 'DMT_UTIL_PKG' and type = 'PACKAGE BODY';
    assert(l_cnt = 1,
       21, 'DMT_UTIL_PKG body: exactly one base64-decode call site (inside BASE64_DECODE_CLOB)');

    -- ----------------------------------------------------------
    -- 22. BASIC_AUTH_HEADER with a >48-byte user:password — the
    --     UTL_ENCODE.BASE64_ENCODE CRLF-every-64-chars defect:
    --     header must be one line, decode back to the exact creds
    -- ----------------------------------------------------------
    l_hdr := dmt_util_pkg.basic_auth_header(l_user, l_pass);
    l_decoded := utl_raw.cast_to_varchar2(
                     dmt_util_pkg.base64_decode_clob(
                         to_clob(substr(l_hdr, 7))));
    assert(l_hdr like 'Basic %'
       and instr(l_hdr, chr(13)) = 0
       and instr(l_hdr, chr(10)) = 0
       and l_decoded = l_user || ':' || l_pass,
       22, 'BASIC_AUTH_HEADER >48-byte credential: single-line header, exact round trip');

    -- ----------------------------------------------------------
    -- 23. BASIC_AUTH_HEADER short credential still exact
    -- ----------------------------------------------------------
    l_hdr := dmt_util_pkg.basic_auth_header('u1', 'pw');
    l_decoded := utl_raw.cast_to_varchar2(
                     dmt_util_pkg.base64_decode_clob(to_clob(substr(l_hdr, 7))));
    assert(l_decoded = 'u1:pw' and instr(l_hdr, chr(10)) = 0,
       23, 'BASIC_AUTH_HEADER short credential exact round trip');

    :passed := :passed + l_passed;
end;
/

-- ------------------------------------------------------------
-- Block E — design-contract gap report (informational, no failures).
-- Section-5 (DMT_DESIGN.html) requirements this layer does not yet
-- meet — findings for the Stage B blind review.
-- ------------------------------------------------------------
declare
    l_cnt pls_integer;
begin
    dbms_output.put_line('--- Design-contract gap report (DMT_DESIGN.html section 5) ---');

    -- Shared APPLY_ERRORS (section 5 end-state: matching UPDATE shared,
    -- not copy-pasted per reconciler)
    select count(*) into l_cnt
    from   user_procedures
    where  object_name = 'DMT_IMPORT_REPORT_PKG' and procedure_name = 'APPLY_ERRORS';
    if l_cnt = 0 then
        dbms_output.put_line('GAP: DMT_IMPORT_REPORT_PKG.APPLY_ERRORS(p_tfm_table, p_key_column, p_run_id) '||
            'does not exist. Section 5 end-state: the [IMPORT_REPORT] row-matching UPDATE becomes a shared '||
            'procedure; in the frozen stack it is duplicated inline in the Projects/Expenditures reconcilers.');
    else
        dbms_output.put_line('OK : APPLY_ERRORS exists.');
    end if;

    dbms_output.put_line('GAP: PARSE_AND_LOG_ERRORS has no XML-injection seam (always downloads via '||
        'GET_ESS_OUTPUT_XML) — the [IMPORT_REPORT] log-tag emission is untestable offline. Proposed: '||
        'an overload taking p_xml IN CLOB so the parse+tag+log path is separable from the transport.');

    dbms_output.put_line('FIXED (finding 23): PARSE_AND_LOG_ERRORS no longer returns 0 for failures — '||
        'download/parse failures are logged and RAISED (test 11 asserts ORA-20037); 0 now only means '||
        '"report downloaded, no errors". Remaining: no error-code OUT parameter (section 7 contract).');

    dbms_output.put_line('FIXED (finding 9): DMT_ESS_UTIL_PKG.GET_ESS_OUTPUT_XML / GET_ESS_OUTPUT_TEXT no '||
        'longer return error text as the content CLOB — failures are logged via LOG_ERROR and raised as '||
        'ORA-20037 with request-id context. NULL still means "no output/no matching file in the ZIP".');

    dbms_output.put_line('GAP: PARSE_ERRORS extracts error rows only — no API for the report summary '||
        '(PROJECT_ACCEPTED/REJECTED/WARNING counts) or success lists (test 6 read them directly from the '||
        'fixture). Success counts are corroborating evidence for the section-5 accounting rule.');

    dbms_output.put_line('NOTE: t_import_error.error_message is VARCHAR2(4000) (SUBSTRed) — messages '||
        'longer than 4000 chars are truncated even though DMT_LOG_TBL.MESSAGE and TFM ERROR_TEXT are CLOBs.');
end;
/

-- ------------------------------------------------------------
-- Cleanup — remove every row this script created
-- ------------------------------------------------------------
begin
    delete from dmt_log_tbl where run_id = 991100599
        or message like 'TEST_IMPORT_REPORT_MARKER%';
    commit;
end;
/

-- ------------------------------------------------------------
-- Summary — only reached when every assertion passed
-- ------------------------------------------------------------
begin
    dbms_output.put_line('TEST_IMPORT_REPORT: '||:passed||' passed, 0 failed');
end;
/

exit success
