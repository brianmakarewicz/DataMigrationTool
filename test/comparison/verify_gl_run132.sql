-- Verify the post-run comparison report for the two GL objects rolled out in
-- family D: GLBalances, GLBudgets. Run against the local Docker DB
-- (dmt_owner @ //localhost:1523/FREEPDB1) with real, already-run data from
-- RUN_ID 132 (prefix 93212, scenario RegressionTest2609231157).
--
-- Expected (see docs/superpowers/specs/discovery/{GLBalances,GLBudgets}.md
-- and family-D-report.md for the captured live output):
--   GLBalances: STG 3/14999.99, TFM err 1/9999.99, Fusion success 2/5000,
--               KEY_TYPE=STAMPED_REF, FUSION_MONEY_AVAILABLE=Y, IN_BALANCE=Y
--               (3 = 2+1, 14999.99 = 5000+9999.99)
--   GLBudgets:  STG 3/2500, TFM err 1/500, Fusion success 2/2000,
--               KEY_TYPE=CAPTURED_ID, FUSION_MONEY_AVAILABLE=Y, IN_BALANCE=Y
--               (3 = 2+1, 2500 = 2000+500)
--
-- Run with:
--   echo exit | sql -S dmt_owner/DmtLocal#2026@//localhost:1523/FREEPDB1 \
--       @test/comparison/verify_gl_run132.sql

set serveroutput on
declare
    l_cur sys_refcursor;
    l_row dmt_cmp_row_obj;
begin
    dmt_run_compare_pkg.get_run_comparison(132, l_cur);
    loop
        fetch l_cur into l_row;
        exit when l_cur%notfound;
        if l_row.cemli_code in ('GLBalances','GLBudgets') then
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

-- Individual function calls (same two objects), for isolating a single
-- object's comparison without running the whole run-132 grid.
set serveroutput on
declare
    l_row dmt_cmp_row_obj;
begin
    l_row := dmt_gl_compare_pkg.get_balances_comparison(132);
    dbms_output.put_line('GLBal: STG='||l_row.stg_count||'/'||l_row.stg_amount||
        ' ERR='||l_row.tfm_error_count||'/'||l_row.tfm_error_amount||
        ' FUS='||l_row.fusion_success_count||'/'||l_row.fusion_success_amount||
        ' KEY='||l_row.key_type||' BAL='||l_row.in_balance);

    l_row := dmt_gl_compare_pkg.get_budgets_comparison(132);
    dbms_output.put_line('GLBud: STG='||l_row.stg_count||'/'||l_row.stg_amount||
        ' ERR='||l_row.tfm_error_count||'/'||l_row.tfm_error_amount||
        ' FUS='||l_row.fusion_success_count||'/'||l_row.fusion_success_amount||
        ' KEY='||l_row.key_type||' BAL='||l_row.in_balance);

    -- Hard assertions -- fail loudly if either object does not balance on
    -- count AND money per the discovery numbers, or if the key type is wrong.
    l_row := dmt_gl_compare_pkg.get_balances_comparison(132);
    if l_row.key_type != 'STAMPED_REF' then
        raise_application_error(-20950, 'GLBalances KEY_TYPE wrong: '||l_row.key_type);
    end if;
    if l_row.in_balance != 'Y' then
        raise_application_error(-20951, 'GLBalances not balanced: var_cnt='||
            l_row.variance_count||' var_amt='||l_row.variance_amount);
    end if;

    l_row := dmt_gl_compare_pkg.get_budgets_comparison(132);
    if l_row.key_type != 'CAPTURED_ID' then
        raise_application_error(-20952, 'GLBudgets KEY_TYPE wrong: '||l_row.key_type);
    end if;
    if l_row.in_balance != 'Y' then
        raise_application_error(-20953, 'GLBudgets not balanced: var_cnt='||
            l_row.variance_count||' var_amt='||l_row.variance_amount);
    end if;

    dbms_output.put_line('PASS: both GL objects balanced, key types correct.');
end;
/
