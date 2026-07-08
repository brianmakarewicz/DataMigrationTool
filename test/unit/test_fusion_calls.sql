-- ============================================================
-- test_fusion_calls.sql — Stage B2 LIVE-Fusion smoke tests
--
-- *** LIVE TEST — talks to the real Oracle Fusion demo instance. ***
-- Read-only on Fusion except test 5, which uploads one tiny throwaway
-- ZIP to UCM (inert — nothing processes an unsubmitted UCM document).
-- Nothing is deployed to or deleted from Fusion. BIP reports executed
-- are pre-existing reports under /Custom/DMT/ (frozen stack's catalog,
-- run read-only, never modified).
--
-- Prerequisites (values are NEVER committed):
--   PYTHONUTF8=1 python test/unit/setup_fusion_config.py
-- which injects FUSION_URL / FUSION_USERNAME / FUSION_PASSWORD (+ BIP_*,
-- HCM_* aliases and SMOKE_ESS_REQUEST_ID) into the local DMT_CONFIG_TBL
-- via DMT_UTIL_PKG.SET_FUSION_URL / SET_CONFIG. SET_FUSION_URL also
-- maintains the network ACL. TLS needs no wallet on Oracle 23ai/26ai
-- Free — the DB trusts the OS certificate store by default (verified:
-- HTTPS to the Fusion host succeeds with no UTL_HTTP.SET_WALLET call).
--
-- SKIP BEHAVIOR: if DMT_CONFIG_TBL has no FUSION_URL (or no
-- FUSION_USERNAME/FUSION_PASSWORD), every test is skipped and the
-- script still exits success with a "0 passed" summary line, so the
-- offline unit suite (run_unit_tests.sh) stays green without
-- credentials.
--
-- Tests:
--   1. HTTP  — DMT_UTIL_PKG.HTTP_REQUEST GET returns 2xx
--              (proves ACL + TLS + Basic-auth plumbing end to end)
--   2. BIP   — DMT_UTIL_PKG.RUN_BIP_REPORT on the shared lookup report
--              /Custom/DMT/common/DMT_FBDI_LOOKUPS_RPT.xdo (read-only,
--              no side effects) returns XML parseable by BIP_REPORT_XML
--   3. FAULT — RUN_BIP_REPORT on a nonexistent report path RAISES
--              (-20034 SOAP fault / -20030 HTTP family) — never a
--              silent retry or an empty success (design section 5)
--   4. ESS   — poll-only: DMT_LOADER_PKG.POLL_ESS_JOB on a known
--              COMPLETED request id (SMOKE_ESS_REQUEST_ID, discovered
--              read-only from the frozen stack) returns a definitive
--              terminal status; DMT_ESS_UTIL_PKG.CAPTURE_ESS_HIERARCHY
--              (called inside POLL) lands rows in DMT_ESS_JOB_TBL.
--              No ESS job is SUBMITTED: every submit path available
--              (loadAndImportData, submitESSJobRequest import jobs)
--              triggers real interface processing — no harmless no-op
--              submit exists, so the poll-only variant is used.
--   5. UCM   — DMT_HDL_UTIL_PKG.UPLOAD_HDL uploads a tiny ZIP built
--              with UTL_ZIP and returns a UCM ContentId.
--
-- Conventions follow test_dmt_util_pkg.sql: numbered assertions, any
-- failure raises ORA-20999, marker-tagged rows cleaned at start/end.
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
-- (test run id 991300199 is distinctive; no FKs on RUN_ID)
-- ------------------------------------------------------------
begin
    delete from dmt_ess_job_file_tbl
    where  ess_job_id in (select ess_job_id from dmt_ess_job_tbl where run_id = 991300199);
    delete from dmt_ess_job_tbl where run_id = 991300199;
    delete from dmt_log_tbl     where run_id = 991300199;
    commit;
end;
/

-- ------------------------------------------------------------
-- All live tests in one block so a missing-config skip is clean
-- ------------------------------------------------------------
declare
    c_run_id  constant number := 991300199;
    -- Read-only shared lookup report on the frozen stack's catalog.
    -- Chosen from the COMMON_LOOKUPS seed row in DMT_BIP_REPORT_TBL:
    -- queries FUN_ALL_BUSINESS_UNITS_V / ledgers only, takes no
    -- parameters, has no side effects.
    c_lookup_rpt constant varchar2(200) := '/Custom/DMT/common/DMT_FBDI_LOOKUPS_RPT.xdo';
    c_bogus_rpt  constant varchar2(200) := '/Custom/DMT/common/DMT2_SMOKE_NO_SUCH_RPT.xdo';

    l_passed   pls_integer := 0;
    l_skipped  pls_integer := 0;

    l_url      varchar2(500);
    l_user     varchar2(200);
    l_pass     varchar2(200);
    l_resp     clob;
    l_status   number;
    l_xml      xmltype;
    l_ess_id   varchar2(50);
    l_fstatus  varchar2(50);
    l_cnt      pls_integer;
    l_zip      blob;
    l_txt      blob;
    l_doc_id   varchar2(100);

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
    l_url  := dmt_util_pkg.get_config('FUSION_URL');
    l_user := dmt_util_pkg.get_config('FUSION_USERNAME');
    l_pass := dmt_util_pkg.get_config('FUSION_PASSWORD');

    if l_url is null or l_user is null or l_pass is null then
        dbms_output.put_line('SKIP  live Fusion config not present in DMT_CONFIG_TBL '||
            '(FUSION_URL/FUSION_USERNAME/FUSION_PASSWORD). '||
            'Run: PYTHONUTF8=1 python test/unit/setup_fusion_config.py');
        :passed := 0;
        return;
    end if;

    dbms_output.put_line('LIVE  target: '||l_url||'  user: '||l_user);

    -- ----------------------------------------------------------
    -- 1. HTTP_REQUEST GET returns 2xx (ACL + TLS + auth plumbing).
    --    businessUnitsLOV?limit=1 is a standard pure-read REST LOV.
    --    Note: HTTP_REQUEST raises -20003 on ANY non-2xx (including
    --    3xx), so reaching the assertion already proves 2xx.
    -- ----------------------------------------------------------
    dmt_util_pkg.http_request(
        p_url         => rtrim(l_url, '/') ||
                         '/fscmRestApi/resources/11.13.18.05/businessUnitsLOV?limit=1&onlyData=true',
        p_method      => 'GET',
        p_run_id      => c_run_id,
        x_response    => l_resp,
        x_status_code => l_status);

    assert(l_status between 200 and 299
       and l_resp is not null
       and dbms_lob.getlength(l_resp) > 0,
       1, 'HTTP_REQUEST GET Fusion REST returns 2xx with a body (ACL+TLS+auth OK)');

    -- ----------------------------------------------------------
    -- 2. RUN_BIP_REPORT on the existing shared lookup report returns
    --    XML that parsed through BIP_REPORT_XML (RUN_BIP_REPORT calls
    --    it internally; a non-null XMLTYPE proves decode + parse).
    -- ----------------------------------------------------------
    l_xml := dmt_util_pkg.run_bip_report(
        p_run_id      => c_run_id,
        p_cemli_code  => null,
        p_params      => null,
        p_report_path => c_lookup_rpt);

    assert(l_xml is not null
       and l_xml.existsnode('/DATA_DS') = 1,
       2, 'RUN_BIP_REPORT('||c_lookup_rpt||') returns parseable /DATA_DS XML');

    -- ----------------------------------------------------------
    -- 3. Nonexistent report path RAISES the SOAP-fault error family
    --    (-20034 SOAP fault, or -20030 if BIP answers with HTTP error)
    --    — never NULL, never empty success (design section 5).
    -- ----------------------------------------------------------
    begin
        l_xml := dmt_util_pkg.run_bip_report(
            p_run_id      => c_run_id,
            p_cemli_code  => null,
            p_params      => null,
            p_report_path => c_bogus_rpt);
        assert(false, 3, 'nonexistent report should have raised, got '||
            case when l_xml is null then 'NULL' else 'XML' end);
    exception
        when others then
            if sqlcode = -20999 then raise; end if;
            assert(sqlcode in (-20034, -20030), 3,
                'nonexistent BIP report raises -20034/-20030 (got '||sqlcode||')');
    end;

    -- ----------------------------------------------------------
    -- 4. ESS poll-only smoke: definitive terminal status for a known
    --    COMPLETED request id. No submit — no harmless ESS submit
    --    exists (all registered jobs are real imports), so the test
    --    polls a finished job instead. POLL_ESS_JOB internally calls
    --    DMT_ESS_UTIL_PKG.CAPTURE_ESS_HIERARCHY (BIP query of
    --    ESS_REQUEST_HISTORY) and ENUMERATE_ALL_ESS_FILES.
    -- ----------------------------------------------------------
    l_ess_id := dmt_util_pkg.get_config('SMOKE_ESS_REQUEST_ID');
    if l_ess_id is null then
        l_skipped := l_skipped + 1;
        dbms_output.put_line('SKIP   4  ESS poll-only test: SMOKE_ESS_REQUEST_ID not configured '||
            '(setup_fusion_config.py could not reach the frozen-stack ATP to discover one)');
    else
        dmt_loader_pkg.poll_ess_job(
            p_run_id         => c_run_id,
            p_ess_job_id     => l_ess_id,
            p_timeout_sec    => 120,
            p_raise_on_error => false,      -- FAILED/ERROR is still a definitive answer
            p_log_context    => 'FUSION_SMOKE',
            x_fusion_status  => l_fstatus);

        -- EXPIRED here means the status call never got an answer — that is
        -- NOT definitive and fails the test (poll timeouts must not be
        -- conflated with job outcomes — design section 2).
        assert(l_fstatus in ('SUCCEEDED', 'WARNING', 'FAILED', 'ERROR'),
           4, 'POLL_ESS_JOB('||l_ess_id||') returns definitive terminal status (got '||
              nvl(l_fstatus, 'NULL')||')');

        select count(*) into l_cnt from dmt_ess_job_tbl where run_id = c_run_id;
        assert(l_cnt >= 1,
           5, 'CAPTURE_ESS_HIERARCHY landed '||l_cnt||' job row(s) in DMT_ESS_JOB_TBL '||
              '(BIP query of ESS_REQUEST_HISTORY works)');
    end if;

    -- ----------------------------------------------------------
    -- 6. UCM upload: tiny throwaway ZIP via UPLOAD_HDL returns a
    --    ContentId. Inert on Fusion — the document is never submitted
    --    to any loader, nothing processes it.
    -- ----------------------------------------------------------
    dbms_lob.createtemporary(l_zip, true);
    l_txt := dmt_util_pkg.clob_to_blob(to_clob(
        'DMT2 Stage B2 live smoke test — throwaway UCM upload, safe to ignore/delete.'));
    utl_zip.add1file(l_zip, 'dmt2_smoke.txt', l_txt);
    utl_zip.finish_zip(l_zip);

    l_doc_id := dmt_hdl_util_pkg.upload_hdl(
        p_run_id      => c_run_id,
        p_hdl_zip     => l_zip,
        p_filename    => 'DMT2_SMOKE_' || to_char(sysdate, 'YYYYMMDDHH24MISS') || '.zip',
        p_log_context => 'FUSION_SMOKE');
    dbms_lob.freetemporary(l_zip);

    assert(l_doc_id is not null,
       6, 'UPLOAD_HDL returns UCM ContentId ('||l_doc_id||') for throwaway ZIP');

    if l_skipped > 0 then
        dbms_output.put_line('NOTE: '||l_skipped||' test(s) skipped — see SKIP lines above.');
    end if;

    :passed := :passed + l_passed;
end;
/

-- ------------------------------------------------------------
-- Cleanup — remove every local row this script created
-- (Fusion-side: only the inert UCM document remains, by design)
-- ------------------------------------------------------------
begin
    delete from dmt_ess_job_file_tbl
    where  ess_job_id in (select ess_job_id from dmt_ess_job_tbl where run_id = 991300199);
    delete from dmt_ess_job_tbl where run_id = 991300199;
    delete from dmt_log_tbl     where run_id = 991300199;
    commit;
end;
/

-- ------------------------------------------------------------
-- Summary — only reached when every executed assertion passed
-- ------------------------------------------------------------
begin
    if :passed = 0 then
        dbms_output.put_line('TEST_FUSION_CALLS: 0 passed, 0 failed (SKIPPED — live Fusion config not present)');
    else
        dbms_output.put_line('TEST_FUSION_CALLS: '||:passed||' passed, 0 failed (LIVE)');
    end if;
end;
/

exit success
