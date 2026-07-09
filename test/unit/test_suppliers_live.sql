-- ============================================================
-- test_suppliers_live.sql — Stage D phase 2 (Suppliers LIVE slice)
--
-- Cheap guards for the live supplier reconciliation path. The full
-- E2E (queue submit → UCM upload → ESS load/import → BIP reconcile →
-- LOADED/FAILED) is evidenced once in the Stage D phase-2 PR body —
-- it is NOT re-run per suite. This script only pins what must stay
-- true afterwards:
--
--   1-10. REGISTRY (offline, always run): the five supplier-family
--         rows in DMT_BIP_REPORT_TBL point BOTH catalog paths at
--         THIS stack's BIP folder /Custom/DMT2/{CEMLI}/ — never
--         /Custom/DMT/ (the frozen stack's catalog, read-only).
--         Seeded by the MERGE block in db/seed/dmt_bip_report_tbl.sql.
--  11-15. LIVE (skip-gated like test_fusion_calls.sql): each deployed
--         report answers a standalone DMT_UTIL_PKG.RUN_BIP_REPORT
--         call. The assertion is only that the report ANSWERS
--         (no HTTP error, no SOAP fault; any returned XML parses to
--         XMLTYPE via BIP_REPORT_XML). LEGACY CONTRACT NOTE: the
--         P_BATCH_ID parameter these reports take is the retired
--         pre-Contract-v1 shape — it is exercised here only because
--         it is what is deployed today, NOT endorsed as correct.
--         The parameter/column contract is replaced by the tracked
--         "Suppliers Contract v1 report rework" work item
--         (docs/tranche-reviews/2026-07-08-suppliers-review.md,
--         H6/H7); when that lands, this suite must assert the
--         Contract v1 parameters instead.
--
-- SKIP BEHAVIOR: without FUSION_URL / FUSION_USERNAME /
-- FUSION_PASSWORD in DMT_CONFIG_TBL the live tests are skipped and
-- the suite still passes on the registry assertions alone.
-- ============================================================

whenever sqlerror exit failure
set serveroutput on size unlimited
set feedback off
set define off

variable passed number
begin :passed := 0; end;
/

declare
    l_passed  pls_integer := 0;
    l_skipped pls_integer := 0;

    l_url  varchar2(500);
    l_user varchar2(200);
    l_pass varchar2(200);
    l_dm   varchar2(500);
    l_rpt  varchar2(500);
    l_xml  xmltype;
    l_num  pls_integer := 0;

    type t_cemli_tab is table of varchar2(30);
    l_cemlis constant t_cemli_tab := t_cemli_tab(
        'Suppliers', 'SupplierAddresses', 'SupplierSites',
        'SupplierSiteAssignments', 'SupplierContacts');

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
    -- --------------------------------------------------------
    -- 1-10. Registry rows point at /Custom/DMT2/ (offline)
    -- --------------------------------------------------------
    for i in 1 .. l_cemlis.count loop
        select dm_catalog_path, report_catalog_path
        into   l_dm, l_rpt
        from   dmt_bip_report_tbl
        where  cemli_code = l_cemlis(i);

        l_num := l_num + 1;
        assert(l_dm = '/Custom/DMT2/' || l_cemlis(i) || '/' ||
                   case l_cemlis(i)
                       when 'Suppliers'               then 'SUP_DM'
                       when 'SupplierAddresses'       then 'SUP_ADDR_DM'
                       when 'SupplierSites'           then 'SUP_SITE_DM'
                       when 'SupplierSiteAssignments' then 'SUP_SITE_ASSN_DM'
                       when 'SupplierContacts'        then 'SUP_CONT_DM'
                   end || '.xdm',
               l_num, l_cemlis(i) || ' DM_CATALOG_PATH under /Custom/DMT2/');

        l_num := l_num + 1;
        assert(l_rpt like '/Custom/DMT2/' || l_cemlis(i) || '/%.xdo'
               and l_rpt not like '/Custom/DMT/%',
               l_num, l_cemlis(i) || ' REPORT_CATALOG_PATH under /Custom/DMT2/');
    end loop;

    -- --------------------------------------------------------
    -- 11-15. Each deployed report responds standalone (live,
    --        skip-gated on Fusion config)
    -- --------------------------------------------------------
    l_url  := dmt_util_pkg.get_config('FUSION_URL');
    l_user := dmt_util_pkg.get_config('FUSION_USERNAME');
    l_pass := dmt_util_pkg.get_config('FUSION_PASSWORD');

    if l_url is null or l_user is null or l_pass is null then
        l_skipped := 5;
        dbms_output.put_line('SKIP  11-15  live report checks '
            || '(no Fusion config in DMT_CONFIG_TBL)');
    else
        for i in 1 .. l_cemlis.count loop
            l_num := l_num + 1;
            -- Raises -20030 (HTTP) / -20034 (SOAP fault) on failure;
            -- NULL return = zero rows (no <reportBytes>) — a valid
            -- standalone response for an unused P_BATCH_ID.
            -- P_BATCH_ID = legacy contract, pending the tracked
            -- "Suppliers Contract v1 report rework" (see header).
            l_xml := dmt_util_pkg.run_bip_report(
                         p_run_id     => null,
                         p_cemli_code => l_cemlis(i),
                         p_params     => 'P_BATCH_ID|0');
            assert(l_xml is null or l_xml.getrootelement() = 'DATA_DS',
                   l_num, l_cemlis(i) || ' report responds standalone from '
                          || '/Custom/DMT2/');
        end loop;
    end if;

    :passed := l_passed;
    if l_skipped > 0 then
        dbms_output.put_line('(' || l_skipped || ' live checks skipped)');
    end if;
end;
/

-- ------------------------------------------------------------
-- Summary — only reached when every executed assertion passed
-- ------------------------------------------------------------
begin
    dbms_output.put_line('TEST_SUPPLIERS_LIVE: '||:passed||' passed, 0 failed');
end;
/

exit success
