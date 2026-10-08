-- ============================================================
-- test_bip_param_list.sql — unit tests for the BIP runReport parameter
-- list built by DMT_UTIL_PKG.BUILD_BIP_PARAM_ITEMS (backlog #414).
--
-- Self-contained SQLcl/SQL*Plus script (NOT a database object).
-- Run as DMT_OWNER against a full DMT2 install:
--   sql dmt_owner/...@//localhost:1523/FREEPDB1 @test/unit/test_bip_param_list.sql
--
-- Why: keyset paging (DMT_DESIGN.html section 5, "Volume — keyset
-- pagination") passes the last RECORD_KEY received as P_AFTER_KEY, and
-- several reports build RECORD_KEY with '~' (Customers
-- 'Customers.Parties~<ref>'). RUN_BIP_REPORT used to split p_params on
-- every '~', so the key was cut short and page 2 restarted near the first
-- key. The fix joins the pairs with DMT_UTIL_PKG.C_BIP_PARAM_SEP (CHR(30),
-- illegal in XML 1.0, so it can never occur in a key read back from a
-- report). These tests prove the key travels whole, that the legacy '~'
-- form every other caller uses is unchanged, and that both paging callers
-- (DMT_RECON_CONTRACT_PKG.FETCH_ROWS, DMT_RECON_ENGINE_PKG) use the safe
-- separator. No Fusion call is made; nothing is written to any table.
-- ============================================================

whenever sqlerror exit failure
set serveroutput on size unlimited
set feedback off
set define off

declare
    l_passed  pls_integer := 0;
    c_sep     constant varchar2(1) := dmt_util_pkg.c_bip_param_sep;
    c_key     constant varchar2(200) := 'Customers.Parties~DMT:93311:5001:CUST~001';
    l_items   clob;
    l_err     number;
    l_cnt     pls_integer;

    type t_pair is record (pname varchar2(4000), pval varchar2(4000));
    type t_pairs is table of t_pair index by pls_integer;
    l_pairs   t_pairs;

    procedure assert (p_cond boolean, p_num pls_integer, p_name varchar2) is
    begin
        if p_cond then
            l_passed := l_passed + 1;
            dbms_output.put_line('PASS  '||lpad(p_num,2)||'  '||p_name);
        else
            raise_application_error(-20999, 'FAIL test '||p_num||': '||p_name);
        end if;
    end assert;

    -- Build the item list and parse it back exactly as BIP would read it
    -- (namespace-qualified XML), so each assertion checks the decoded value.
    procedure build (p_params varchar2) is
    begin
        l_pairs.delete;
        dmt_util_pkg.build_bip_param_items(p_params, l_items, l_err);
        if l_err <> dmt_util_pkg.c_success then
            return;
        end if;
        select x.pname, x.pval
        bulk collect into l_pairs
        from xmltable(
                 xmlnamespaces('http://xmlns.oracle.com/oxp/service/v2' as "v2"),
                 '/r/v2:item'
                 passing xmltype('<r xmlns:v2="http://xmlns.oracle.com/oxp/service/v2">'
                                 || nvl(l_items, to_clob('')) || '</r>')
                 columns pname varchar2(4000) path 'v2:name',
                         pval  varchar2(4000) path 'v2:values/v2:item') x;
    end build;

    function val (p_name varchar2) return varchar2 is
    begin
        for i in 1 .. l_pairs.count loop
            if l_pairs(i).pname = p_name then
                return l_pairs(i).pval;
            end if;
        end loop;
        return '<<absent>>';
    end val;
begin
    -- 1. Legacy '~' form (every non-paging caller) is unchanged.
    build('P_RUN_ID|7~P_LOAD_REQUEST_ID|123~P_PREFIX|93311');
    assert(l_err = dmt_util_pkg.c_success and l_pairs.count = 3
           and val('P_RUN_ID') = '7' and val('P_LOAD_REQUEST_ID') = '123'
           and val('P_PREFIX') = '93311',
           1, 'legacy ~-joined list yields 3 pairs with the right values');

    -- 2. The defect, reproduced on the legacy form: a '~' inside a value is
    --    taken as a separator, so the key is cut at its first '~'. This is
    --    why the paging callers must not use the legacy form.
    build('P_RUN_ID|7~P_AFTER_KEY|' || c_key);
    assert(val('P_AFTER_KEY') = 'Customers.Parties',
           2, 'legacy form cuts a ~-bearing key short (documents the #414 defect)');

    -- 3. The fix: the C_BIP_PARAM_SEP-joined list carries the key whole.
    build('P_RUN_ID|7' || c_sep || 'P_LOAD_REQUEST_ID|123' || c_sep ||
          'P_IMPORT_ESS_ID|' || c_sep || 'P_PREFIX|93311' || c_sep ||
          'P_FUSION_BATCH_ID|933115001' || c_sep || 'P_CHUNK_SIZE|5000' || c_sep ||
          'P_AFTER_KEY|' || c_key);
    assert(l_err = dmt_util_pkg.c_success and l_pairs.count = 7
           and val('P_AFTER_KEY') = c_key,
           3, 'safe-separator list keeps a ~-bearing P_AFTER_KEY whole (7 pairs)');
    assert(val('P_RUN_ID') = '7' and val('P_CHUNK_SIZE') = '5000'
           and val('P_FUSION_BATCH_ID') = '933115001' and val('P_IMPORT_ESS_ID') is null,
           4, 'safe-separator list keeps every other pair, empty value stays empty');

    -- 5. A value containing '|' and XML-special characters round-trips: the
    --    name/value split is on the FIRST '|', and both are XML-escaped.
    build('P_RUN_ID|7' || c_sep || 'P_AFTER_KEY|A|B&C<D>"E''F~G');
    assert(l_err = dmt_util_pkg.c_success and l_pairs.count = 2
           and val('P_AFTER_KEY') = 'A|B&C<D>"E''F~G',
           5, 'value with | & < > quotes and ~ round-trips intact');

    -- 6. A single pair ending in the separator selects the safe mode, so a
    --    lone value may also carry '~'.
    build('P_AFTER_KEY|' || c_key || c_sep);
    assert(l_err = dmt_util_pkg.c_success and l_pairs.count = 1
           and val('P_AFTER_KEY') = c_key,
           6, 'single pair with trailing separator keeps its ~-bearing value');

    -- 7. First page: empty cursor is sent as an empty value, not dropped.
    build('P_CHUNK_SIZE|5000' || c_sep || 'P_AFTER_KEY|');
    assert(l_pairs.count = 2 and val('P_AFTER_KEY') is null,
           7, 'empty P_AFTER_KEY (first page) is still sent');

    -- 8/9. Both keyset-paging callers join their pairs with the safe
    --      separator; neither still builds the legacy '~P_AFTER_KEY|' pair.
    select count(*) into l_cnt
    from   user_source
    where  name in ('DMT_RECON_CONTRACT_PKG', 'DMT_RECON_ENGINE_PKG')
    and    type = 'PACKAGE BODY'
    and    instr(text, '''~P_AFTER_KEY|''') > 0;
    assert(l_cnt = 0, 8, 'no paging caller builds the legacy ''~P_AFTER_KEY|'' pair');

    select count(distinct name) into l_cnt
    from   user_source
    where  name in ('DMT_RECON_CONTRACT_PKG', 'DMT_RECON_ENGINE_PKG')
    and    type = 'PACKAGE BODY'
    and    instr(text, 'CONSTANT VARCHAR2(1)  := DMT_UTIL_PKG.C_BIP_PARAM_SEP') > 0;
    assert(l_cnt = 2, 9, 'both paging callers declare C_SEP from DMT_UTIL_PKG.C_BIP_PARAM_SEP');

    dbms_output.put_line('TEST_BIP_PARAM_LIST: '||l_passed||' passed, 0 failed');
end;
/

exit success
