-- ============================================================
-- test_central_fusion_user.sql -- unit check of the central Fusion user
-- utility, DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS (backlog #309, #303).
--
-- Self-contained SQLcl/SQL*Plus script (NOT a database object). Run as
-- DMT_OWNER against a DMT2 install whose credentials were filled by
-- db/tools/setup_runtime_config.py:
--   sql dmt_owner/...@//localhost:1523/FREEPDB1 @test/unit/test_central_fusion_user.sql
--
-- What it proves (owner rule 2026-10-07: the user and password are taken
-- TOGETHER from one place):
--   * an object with its own user gets that user AND that row's password
--     (Requisitions = calvin.roth, Grants = ppm_impl, Workers = hcm_impl);
--   * an object whose options row has a password but NO username
--     (ARInvoices) gets the default user AND the default user's own
--     password -- never the row's password (#303). To make that observable
--     the test gives the ARInvoices row a different password inside its own
--     transaction and rolls it back;
--   * no CEMLI / an unknown CEMLI / an unknown ESS request id -> default pair;
--   * a row with a username but no password raises -20002 (never mixed);
--   * BASIC_AUTH_HEADER refuses half a pair.
-- Passwords are only compared, never printed.
--
-- Every temporary change is made in this session's transaction and rolled
-- back; whenever sqlerror ... rollback guarantees nothing is committed even
-- on failure. Nested blocks assert expected exceptions (test script, not a
-- database object).
-- ============================================================

whenever sqlerror exit failure rollback
set serveroutput on size unlimited
set feedback off
set define off

variable passed number

begin :passed := 0; end;
/

declare
    l_passed    pls_integer := 0;
    l_user      varchar2(500);
    l_pass      varchar2(500);
    l_row_pass  varchar2(500);
    l_def_user  varchar2(500);
    l_def_pass  varchar2(500);
    l_raised    number;
    l_hdr       varchar2(2000);

    procedure assert (p_cond boolean, p_num pls_integer, p_name varchar2) is
    begin
        if p_cond then
            l_passed := l_passed + 1;
            dbms_output.put_line('PASS  '||lpad(p_num,2)||'  '||p_name);
        else
            raise_application_error(-20999, 'FAIL test '||p_num||': '||p_name);
        end if;
    end assert;

    function row_pass (p_cemli varchar2) return varchar2 is
        l_p varchar2(500);
    begin
        select fusion_password into l_p
        from   dmt_erp_interface_options_tbl
        where  cemli_code = p_cemli;
        return l_p;
    end row_pass;
begin
    l_def_user := dmt_util_pkg.get_config('FUSION_USERNAME');
    l_def_pass := dmt_util_pkg.get_config('FUSION_PASSWORD');
    assert(l_def_user is not null and l_def_pass is not null
           and l_def_pass <> '***MASKED-SET-ME***',
           0, 'precondition: default user '||l_def_user||' has a real password (run setup_runtime_config.py)');

    -- 1. Requisitions: its own user, with its own row's password
    dmt_util_pkg.get_cemli_credentials(p_cemli_code => 'Requisitions', x_username => l_user, x_password => l_pass);
    assert(l_user = 'calvin.roth' and l_pass = row_pass('Requisitions'),
           1, 'Requisitions -> calvin.roth with the Requisitions row''s password');

    -- 2. Grants: its own user, with its own row's password
    dmt_util_pkg.get_cemli_credentials(p_cemli_code => 'Grants', x_username => l_user, x_password => l_pass);
    assert(l_user = 'ppm_impl' and l_pass = row_pass('Grants'),
           2, 'Grants -> ppm_impl with the Grants row''s password');

    -- 3. ARInvoices: password-only row -> default user + default user's own password.
    select count(*) into l_raised
    from   dmt_erp_interface_options_tbl
    where  cemli_code = 'ARInvoices' and fusion_username is null;
    assert(l_raised = 1, 3, 'precondition: the ARInvoices options row has no username');
    update dmt_erp_interface_options_tbl
    set    fusion_password = 'TEST_309_NOT_THE_DEFAULT_PASSWORD'
    where  cemli_code = 'ARInvoices';
    dmt_util_pkg.get_cemli_credentials(p_cemli_code => 'ARInvoices', x_username => l_user, x_password => l_pass);
    assert(l_user = l_def_user and l_pass = l_def_pass
           and l_pass <> 'TEST_309_NOT_THE_DEFAULT_PASSWORD',
           4, 'ARInvoices (password but no username) -> '||l_def_user||' with '||l_def_user||'''s own password, not the row''s');
    rollback;

    -- 5. The default user: no CEMLI
    dmt_util_pkg.get_cemli_credentials(p_cemli_code => null, x_username => l_user, x_password => l_pass);
    assert(l_user = l_def_user and l_pass = l_def_pass, 5, 'NULL CEMLI -> default pair ('||l_def_user||')');

    -- 6. A CEMLI with no options row -> default pair
    dmt_util_pkg.get_cemli_credentials(p_cemli_code => 'TEST_309_NO_SUCH_CEMLI', x_username => l_user, x_password => l_pass);
    assert(l_user = l_def_user and l_pass = l_def_pass, 6, 'unknown CEMLI -> default pair');

    -- 7. HCM object: hcm_impl from its options row (HDL and preflight use the same)
    dmt_util_pkg.get_cemli_credentials(p_cemli_code => 'Workers', x_username => l_user, x_password => l_pass);
    assert(l_user = 'hcm_impl' and l_pass = row_pass('Workers'), 7, 'Workers -> hcm_impl with the Workers row''s password');

    -- 8. A request id DMT never recorded -> default pair
    dmt_util_pkg.get_credentials_for_request(p_request_id => -309, x_username => l_user, x_password => l_pass);
    assert(l_user = l_def_user and l_pass = l_def_pass, 8, 'unknown ESS request id -> default pair');

    -- 9. A row with a username but no password raises instead of mixing halves
    update dmt_erp_interface_options_tbl set fusion_password = null where cemli_code = 'Requisitions';
    l_raised := 0;
    begin
        dmt_util_pkg.get_cemli_credentials(p_cemli_code => 'Requisitions', x_username => l_user, x_password => l_pass);
    exception when others then
        if sqlcode = -20002 then l_raised := 1; end if;
    end;
    rollback;
    assert(l_raised = 1, 9, 'Requisitions with no password raises -20002 (never paired with the default password)');

    -- 10. BASIC_AUTH_HEADER refuses half a pair
    l_raised := 0;
    begin
        l_hdr := dmt_util_pkg.basic_auth_header(p_username => 'calvin.roth', p_password => null);
    exception when others then
        if sqlcode = -20002 then l_raised := 1; end if;
    end;
    assert(l_raised = 1, 10, 'BASIC_AUTH_HEADER with a username and no password raises -20002');

    -- 11. BASIC_AUTH_HEADER with no pair = the default user's header
    l_hdr := dmt_util_pkg.basic_auth_header;
    assert(l_hdr = dmt_util_pkg.basic_auth_header(p_username => l_def_user, p_password => l_def_pass),
           11, 'BASIC_AUTH_HEADER with no pair = header of the default pair');

    rollback;
    :passed := :passed + l_passed;
end;
/

begin
    dbms_output.put_line('TEST_CENTRAL_FUSION_USER: '||:passed||' passed, 0 failed');
end;
/

exit success
