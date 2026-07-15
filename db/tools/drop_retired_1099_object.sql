-- ============================================================
-- drop_retired_1099_object.sql
--
-- Backlog §12 (P2, owner-approved 2026-07-14): 1099Invoices is NOT a
-- distinct object. It is APInvoices filtered to invoice type LIKE '%1099%'
-- and shares AP's upload CSV, interface files, and STG/TFM tables. The AP
-- load path (RUN_AP_INVOICES) already processes every invoice type,
-- including 1099, so the separate 1099 object was redundant.
--
-- Retirement removes: the 1099 packages (DMT_1099_FBDI_GEN_PKG,
-- DMT_1099_RESULTS_PKG), the loader arms + RUN_1099_INVOICES runner, the
-- registry/catalog/split/BIP/ERP seed rows, the object-detail / record-detail
-- / summary view branches, the bip/1099Invoices and objects/1099Invoices
-- folders, and the install.sql lines. The AP object now shows all invoice
-- types (the NOT LIKE '%1099%' exclusion was dropped from the AP branches).
-- 1099 remains visible as AP invoices filtered by invoice type.
--
-- Guarded / idempotent: safe to run repeatedly; a fresh
-- `build_local_db.sh --fresh` install converges because the object files,
-- seed rows, and install.sql lines were removed.
--
-- Run as DMT_OWNER:
--   sql dmt_owner/...@//localhost:1523/FREEPDB1 @db/tools/drop_retired_1099_object.sql
-- ============================================================

whenever sqlerror exit failure
set serveroutput on

declare
    procedure drop_if_exists (p_type in varchar2, p_name in varchar2) is
        l_cnt pls_integer;
    begin
        select count(*) into l_cnt
        from   user_objects
        where  object_name = p_name
        and    object_type = p_type;

        if l_cnt = 0 then
            dbms_output.put_line('SKIP  ' || p_type || ' ' || p_name || ' (does not exist)');
        else
            execute immediate 'drop ' || p_type || ' "' || p_name || '"';
            dbms_output.put_line('DROP  ' || p_type || ' ' || p_name);
        end if;
    end drop_if_exists;
begin
    drop_if_exists('PACKAGE', 'DMT_1099_FBDI_GEN_PKG');
    drop_if_exists('PACKAGE', 'DMT_1099_RESULTS_PKG');

    -- Remove the 1099 object's seed rows (fresh installs never create them).
    delete from DMT_BIP_REPORT_TBL            where CEMLI_CODE  = '1099Invoices';
    dbms_output.put_line('DELETE DMT_BIP_REPORT_TBL 1099Invoices: ' || sql%rowcount);
    delete from DMT_ERP_INTERFACE_OPTIONS_TBL where CEMLI_CODE  = '1099Invoices';
    dbms_output.put_line('DELETE DMT_ERP_INTERFACE_OPTIONS_TBL 1099Invoices: ' || sql%rowcount);
    delete from DMT_CEMLI_CATALOG_TBL         where CEMLI_CODE  = '1099Invoices';
    dbms_output.put_line('DELETE DMT_CEMLI_CATALOG_TBL 1099Invoices: ' || sql%rowcount);
    delete from DMT_CEMLI_SPLIT_CFG           where CEMLI_CODE  = '1099Invoices';
    dbms_output.put_line('DELETE DMT_CEMLI_SPLIT_CFG 1099Invoices: ' || sql%rowcount);
    delete from DMT_PIPELINE_DEF_TBL          where CEMLI_CODE  = '1099Invoices';
    dbms_output.put_line('DELETE DMT_PIPELINE_DEF_TBL 1099Invoices: ' || sql%rowcount);
    commit;
end;
/

exit success
