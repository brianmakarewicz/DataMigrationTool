-- Verify the post-run comparison report for the three finance objects rolled
-- out in family C: APInvoices, Customers, ARInvoices. Run against the local
-- Docker DB (dmt_owner @ //localhost:1523/FREEPDB1) with real, already-run
-- data from RUN_ID 132 (prefix 93212, scenario RegressionTest26092311).
--
-- Expected (see docs/superpowers/specs/discovery/{APInvoices,Customers,
-- ARInvoices}.md and family-C-report.md for the captured live output):
--   APInvoices: STG 4/9250, TFM err 2/5000, Fusion success 2/4250,
--               KEY_TYPE=IMPORT_ID, FUSION_MONEY_AVAILABLE=Y, IN_BALANCE=Y
--               (4 = 2+2, 9250 = 4250+5000)
--   Customers:  STG 4, TFM err 2, Fusion success 2, KEY_TYPE=CAPTURED_ID,
--               FUSION_MONEY_AVAILABLE=N, IN_BALANCE=Y (4 = 2+2)
--   ARInvoices: STG 3/5500, TFM err 3/5500, Fusion success 0/0 (AutoInvoice
--               is env-blocked this run -- honest 0-LOADED result),
--               KEY_TYPE=IMPORT_ID, IN_BALANCE=Y (3 = 0+3)
--
-- Run with:
--   echo exit | sql -S dmt_owner/DmtLocal#2026@//localhost:1523/FREEPDB1 \
--       @test/comparison/verify_finance_run132.sql

set serveroutput on
declare
    l_cur sys_refcursor;
    l_row dmt_cmp_row_obj;
begin
    dmt_run_compare_pkg.get_run_comparison(132, l_cur);
    loop
        fetch l_cur into l_row;
        exit when l_cur%notfound;
        if l_row.cemli_code in ('APInvoices','Customers','ARInvoices') then
            dbms_output.put_line('=== '||l_row.cemli_code||' ===');
            dbms_output.put_line(
                'KEY_TYPE='||l_row.key_type||
                ' STG='||l_row.stg_count||'/'||l_row.stg_amount||
                ' ERR='||l_row.tfm_error_count||'/'||l_row.tfm_error_amount||
                ' FUS='||l_row.fusion_success_count||'/'||l_row.fusion_success_amount||
                ' CCY='||l_row.amount_currency||
                ' MONEY_OK='||l_row.fusion_money_available||
                ' VAR_CNT='||l_row.variance_count||
                ' VAR_AMT='||l_row.variance_amount||
                ' BAL='||l_row.in_balance||
                ' NOTE='||l_row.note);
        end if;
    end loop;
    close l_cur;
end;
/

-- Individual function calls (same three objects), for isolating a single
-- object's comparison without running the whole run-132 grid.
set serveroutput on
declare
    l_row dmt_cmp_row_obj;
begin
    l_row := dmt_ap_compare_pkg.get_comparison(132);
    dbms_output.put_line('AP  : STG='||l_row.stg_count||'/'||l_row.stg_amount||
        ' ERR='||l_row.tfm_error_count||'/'||l_row.tfm_error_amount||
        ' FUS='||l_row.fusion_success_count||'/'||l_row.fusion_success_amount||
        ' BAL='||l_row.in_balance);

    l_row := dmt_cust_compare_pkg.get_comparison(132);
    dbms_output.put_line('CUST: STG='||l_row.stg_count||
        ' ERR='||l_row.tfm_error_count||
        ' FUS='||l_row.fusion_success_count||
        ' BAL='||l_row.in_balance);

    l_row := dmt_ar_compare_pkg.get_comparison(132);
    dbms_output.put_line('AR  : STG='||l_row.stg_count||'/'||l_row.stg_amount||
        ' ERR='||l_row.tfm_error_count||'/'||l_row.tfm_error_amount||
        ' FUS='||l_row.fusion_success_count||'/'||l_row.fusion_success_amount||
        ' BAL='||l_row.in_balance);
end;
/

-- Hard assertions -- fail loudly (RAISE_APPLICATION_ERROR) if any of the three
-- finance objects does not match its documented run-132 expected values. The
-- rows are pulled from the framework dispatcher DMT_RUN_COMPARE_PKG.
-- GET_RUN_COMPARISON(132) (the same path production uses), collected into an
-- index-by-CEMLI table. A missing object raises (row-present guard) rather than
-- silently passing. Expected values are the discovery-proven numbers -- see
-- docs/superpowers/specs/discovery/{APInvoices,Customers,ARInvoices}.md and
-- .superpowers/sdd/comparison-rollout/family-C-report.md. Do NOT weaken these
-- to make the script pass; if a value differs, fix the root cause.
set serveroutput on
declare
    type t_rows is table of dmt_cmp_row_obj index by varchar2(60);
    l_rows t_rows;
    l_cur  sys_refcursor;
    l_row  dmt_cmp_row_obj;

    procedure assert_num(p_cemli varchar2, p_field varchar2,
                         p_actual number, p_expected number) is
    begin
        if p_actual is null or p_actual != p_expected then
            raise_application_error(-20960,
                p_cemli||' '||p_field||' wrong: expected '||p_expected||
                ', got '||nvl(to_char(p_actual),'NULL'));
        end if;
    end;

    procedure assert_str(p_cemli varchar2, p_field varchar2,
                         p_actual varchar2, p_expected varchar2) is
    begin
        if p_actual is null or p_actual != p_expected then
            raise_application_error(-20961,
                p_cemli||' '||p_field||' wrong: expected '''||p_expected||
                ''', got '''||nvl(p_actual,'NULL')||'''');
        end if;
    end;

    function must_get(p_cemli varchar2) return dmt_cmp_row_obj is
    begin
        if not l_rows.exists(p_cemli) then
            raise_application_error(-20962,
                p_cemli||' row MISSING from GET_RUN_COMPARISON(132) -- object '||
                'not registered with a CMP_FUNCTION, or its comparison function '||
                'raised and was skipped from the grid.');
        end if;
        return l_rows(p_cemli);
    end;
begin
    dmt_run_compare_pkg.get_run_comparison(132, l_cur);
    loop
        fetch l_cur into l_row;
        exit when l_cur%notfound;
        l_rows(l_row.cemli_code) := l_row;
    end loop;
    close l_cur;

    -- APInvoices -- money-bearing, balanced on count AND money.
    l_row := must_get('APInvoices');
    assert_str('APInvoices', 'KEY_TYPE',              l_row.key_type,              'IMPORT_ID');
    assert_num('APInvoices', 'STG_COUNT',             l_row.stg_count,             4);
    assert_num('APInvoices', 'STG_AMOUNT',            l_row.stg_amount,            9250);
    assert_num('APInvoices', 'TFM_ERROR_COUNT',       l_row.tfm_error_count,       2);
    assert_num('APInvoices', 'TFM_ERROR_AMOUNT',      l_row.tfm_error_amount,      5000);
    assert_num('APInvoices', 'FUSION_SUCCESS_COUNT',  l_row.fusion_success_count,  2);
    assert_num('APInvoices', 'FUSION_SUCCESS_AMOUNT', l_row.fusion_success_amount, 4250);
    assert_str('APInvoices', 'IN_BALANCE',            l_row.in_balance,            'Y');

    -- Customers -- count-only (money side is NULL, FUSION_MONEY_AVAILABLE=N).
    l_row := must_get('Customers');
    assert_str('Customers', 'KEY_TYPE',               l_row.key_type,              'CAPTURED_ID');
    assert_num('Customers', 'STG_COUNT',              l_row.stg_count,             4);
    assert_num('Customers', 'TFM_ERROR_COUNT',        l_row.tfm_error_count,       2);
    assert_num('Customers', 'FUSION_SUCCESS_COUNT',   l_row.fusion_success_count,  2);
    assert_str('Customers', 'FUSION_MONEY_AVAILABLE', l_row.fusion_money_available,'N');
    assert_str('Customers', 'IN_BALANCE',             l_row.in_balance,            'Y');

    -- ARInvoices -- 0-loaded this run (AutoInvoice env-blocked); honest 0
    -- Fusion successes, still balanced on count (3 = 0 + 3). KEY_TYPE is the
    -- value the function actually emits, confirmed from a live run.
    l_row := must_get('ARInvoices');
    assert_str('ARInvoices', 'KEY_TYPE',              l_row.key_type,              'IMPORT_ID');
    assert_num('ARInvoices', 'STG_COUNT',             l_row.stg_count,             3);
    assert_num('ARInvoices', 'TFM_ERROR_COUNT',       l_row.tfm_error_count,       3);
    assert_num('ARInvoices', 'FUSION_SUCCESS_COUNT',  l_row.fusion_success_count,  0);
    assert_str('ARInvoices', 'IN_BALANCE',            l_row.in_balance,            'Y');

    dbms_output.put_line('PASS: APInvoices balanced on count AND money (4=2+2, 9250=4250+5000), KEY_TYPE=IMPORT_ID.');
    dbms_output.put_line('PASS: Customers count-balanced (4=2+2), KEY_TYPE=CAPTURED_ID, money N.');
    dbms_output.put_line('PASS: ARInvoices count-balanced (3=0+3), Fusion success 0, honest 0-loaded.');
    dbms_output.put_line('PASS: all three finance objects present and every assertion held.');
end;
/
