-- ============================================================
-- test_po_style_scope.sql -- the PurchaseOrders FBDI generator takes only
-- Purchase Order style rows (backlog #760).
--
-- Why. PurchaseOrders, BlanketPOs and Contracts share the PO TFM tables and one
-- pipeline run, and the queue can run them at the same time (BlanketPOs and
-- Contracts do not depend on PurchaseOrders). One object = one FBDI zip = one
-- load job (DMT_DESIGN.html section 1 and section 5), so the PO zip must never
-- carry, mark GENERATED or stamp a blanket or contract row of the same run and
-- business unit. The catalog registers PurchaseOrders' record types with
-- STYLE_DISPLAY_NAME = 'Purchase Order' (db/seed/dmt_cemli_catalog_tbl.sql).
--
--   S1  GENERATE_FBDI returns a zip, and the standard PO header, line, line
--       location and distribution are GENERATED with an FBDI_CSV_ID.
--   S2  the blanket header + line and the contract header of the same run and
--       BU stay STAGED, with no FBDI_CSV_ID and no ATTRIBUTE20 reference.
--   S3  the PO header and lines CSVs contain the PO's keys and no blanket or
--       contract key.
--
-- Isolation. Every row this test writes (one synthetic run, synthetic STG
-- parents, TFM rows, and the CSV / zip rows the generator registers) lives in
-- ONE transaction that is ROLLED BACK at the end (and on any failure). The only
-- committed side effect is the activity-log entries DMT_UTIL_PKG.LOG writes in
-- its own autonomous transaction; the test deletes exactly those entries
-- (matched on the synthetic RUN_ID) after the rollback.
--
-- Run as DMT_OWNER:
--   sql dmt_owner/...@//localhost:1523/FREEPDB1 @test/unit/test_po_style_scope.sql
-- ============================================================

whenever sqlerror exit failure rollback
set serveroutput on size unlimited
set feedback off
set define off

variable passed number
variable run1 number
begin :passed := 0; :run1 := null; end;
/

declare
    C_BU     constant varchar2(60) := 'UT BU 1';
    C_SPO    constant varchar2(60) := 'Purchase Order';
    C_BPA    constant varchar2(60) := 'Blanket Purchase Agreement';
    C_CPA    constant varchar2(60) := 'Contract Purchase Agreement';
    l_passed pls_integer := 0;
    l_run    number;
    l_zip    blob;
    l_file   varchar2(200);
    l_csv_id number;
    l_n      number;
    l_hdr    clob;
    l_lines  clob;
    s_poh number; s_pol number; s_pll number; s_pod number;

    procedure ok(p_name in varchar2, p_cond in boolean) is
    begin
        if p_cond then
            l_passed := l_passed + 1;
            dbms_output.put_line('PASS '||p_name);
        else
            raise_application_error(-20999, 'FAIL test '||p_name);
        end if;
    end;
begin
    insert into dmt_pipeline_run_tbl (pipeline_codes, run_type, submitted_by,
                                      cemli_sequence, scenario_name, run_status)
    values ('UNIT_TEST', 'PIPELINE', 'UNIT_TEST_PO_STYLE_SCOPE',
            'UNIT_TEST', 'UNIT_TEST_PO_STYLE_SCOPE', 'IN_PROGRESS')
    returning run_id into l_run;
    :run1 := l_run;

    -- Synthetic STG parents (the TFM STG_SEQUENCE_ID foreign keys need one); never a real STG row.
    insert into dmt_po_headers_int_stg_tbl    (stg_status) values ('NEW') returning stg_sequence_id into s_poh;
    insert into dmt_po_lines_int_stg_tbl      (stg_status) values ('NEW') returning stg_sequence_id into s_pol;
    insert into dmt_po_line_locs_int_stg_tbl  (stg_status) values ('NEW') returning stg_sequence_id into s_pll;
    insert into dmt_po_dists_int_stg_tbl      (stg_status) values ('NEW') returning stg_sequence_id into s_pod;

    -- Standard PO (this object's zip): header, line, line location, distribution.
    insert into dmt_po_headers_int_tfm_tbl (run_id, stg_sequence_id, interface_header_key, prc_bu_name, style_display_name, tfm_status)
    values (l_run, s_poh, 'UTSPO1', C_BU, C_SPO, 'STAGED');
    insert into dmt_po_lines_int_tfm_tbl (run_id, stg_sequence_id, interface_header_key, interface_line_key, tfm_status)
    values (l_run, s_pol, 'UTSPO1', 'UTSPO1-L1', 'STAGED');
    insert into dmt_po_line_locs_int_tfm_tbl (run_id, stg_sequence_id, interface_line_key, interface_line_location_key, tfm_status)
    values (l_run, s_pll, 'UTSPO1-L1', 'UTSPO1-LL1', 'STAGED');
    insert into dmt_po_dists_int_tfm_tbl (run_id, stg_sequence_id, interface_line_location_key, interface_distribution_key, tfm_status)
    values (l_run, s_pod, 'UTSPO1-LL1', 'UTSPO1-D1', 'STAGED');

    -- Same run and BU, other objects' rows, still STAGED (in flight in parallel).
    insert into dmt_po_headers_int_tfm_tbl (run_id, stg_sequence_id, interface_header_key, prc_bu_name, style_display_name, tfm_status)
    values (l_run, s_poh, 'UTBPA1', C_BU, C_BPA, 'STAGED');
    insert into dmt_po_lines_int_tfm_tbl (run_id, stg_sequence_id, interface_header_key, interface_line_key, tfm_status)
    values (l_run, s_pol, 'UTBPA1', 'UTBPA1-L1', 'STAGED');
    insert into dmt_po_headers_int_tfm_tbl (run_id, stg_sequence_id, interface_header_key, prc_bu_name, style_display_name, tfm_status)
    values (l_run, s_poh, 'UTCPA1', C_BU, C_CPA, 'STAGED');

    dmt_po_fbdi_gen_pkg.generate_fbdi(
        p_run_id      => l_run,
        p_prc_bu_name => C_BU,
        x_fbdi_zip    => l_zip,
        x_filename    => l_file,
        x_fbdi_csv_id => l_csv_id);

    select count(*) into l_n from (
        select 1 from dmt_po_headers_int_tfm_tbl   where run_id = l_run and interface_header_key = 'UTSPO1'
           and tfm_status = 'GENERATED' and fbdi_csv_id is not null
        union all
        select 1 from dmt_po_lines_int_tfm_tbl     where run_id = l_run and interface_line_key = 'UTSPO1-L1'
           and tfm_status = 'GENERATED' and fbdi_csv_id is not null
        union all
        select 1 from dmt_po_line_locs_int_tfm_tbl where run_id = l_run and interface_line_location_key = 'UTSPO1-LL1'
           and tfm_status = 'GENERATED' and fbdi_csv_id is not null
        union all
        select 1 from dmt_po_dists_int_tfm_tbl     where run_id = l_run and interface_distribution_key = 'UTSPO1-D1'
           and tfm_status = 'GENERATED' and fbdi_csv_id is not null);
    ok('S1 zip built; the standard PO header, line, location and distribution are GENERATED',
       l_zip is not null and dbms_lob.getlength(l_zip) > 0 and l_n = 4);

    select count(*) into l_n from (
        select 1 from dmt_po_headers_int_tfm_tbl where run_id = l_run and interface_header_key in ('UTBPA1','UTCPA1')
           and tfm_status = 'STAGED' and fbdi_csv_id is null and attribute20 is null
        union all
        select 1 from dmt_po_lines_int_tfm_tbl   where run_id = l_run and interface_line_key = 'UTBPA1-L1'
           and tfm_status = 'STAGED' and fbdi_csv_id is null);
    ok('S2 blanket header + line and contract header untouched (STAGED, no csv id, no reference stamp)', l_n = 3);

    select csv_content into l_hdr from dmt_fbdi_csv_tbl where fbdi_csv_id = l_csv_id;
    select c.csv_content into l_lines
    from   dmt_fbdi_csv_tbl c
    where  c.fbdi_csv_id = (select fbdi_csv_id from dmt_po_lines_int_tfm_tbl
                            where run_id = l_run and interface_line_key = 'UTSPO1-L1');
    ok('S3 PO header and lines CSVs carry the PO only (no blanket or contract key)',
       dbms_lob.instr(l_hdr, 'UTSPO1') > 0
       and dbms_lob.instr(l_hdr, 'UTBPA1') = 0 and dbms_lob.instr(l_hdr, 'UTCPA1') = 0
       and dbms_lob.instr(l_lines, 'UTSPO1-L1') > 0 and dbms_lob.instr(l_lines, 'UTBPA1') = 0);

    if l_zip is not null and dbms_lob.istemporary(l_zip) = 1 then
        dbms_lob.freetemporary(l_zip);
    end if;
    :passed := l_passed;
    rollback;
exception
    when others then
        rollback;
        raise;
end;
/

-- Autonomous log entries written for the synthetic run.
begin
    delete from dmt_log_tbl where run_id = :run1;
    commit;
end;
/

begin
    if :passed <> 3 then
        raise_application_error(-20998, 'test_po_style_scope: '||:passed||' of 3 passed');
    end if;
    dbms_output.put_line('TEST_PO_STYLE_SCOPE: 3 passed, 0 failed');
end;
/
exit
