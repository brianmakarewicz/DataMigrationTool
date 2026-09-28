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
