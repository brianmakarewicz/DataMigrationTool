-- ============================================================
-- drop_retired_supplier_sequences.sql
--
-- Stage D Suppliers identity conversion (accepted coding standard
-- 2026-07-08: "Identity columns for keys; sequences only for shared,
-- meaningful values"): the 10 supplier-family STG/TFM tables now number
-- their own rows with GENERATED ALWAYS AS IDENTITY primary keys, so the
-- 10 per-table ID sequences are retired. Their object files and
-- install.sql lines are removed in the same commit; this tool drops the
-- live objects from an existing database.
--
-- No package references any of these sequences (verified by grep across
-- db/ 2026-07-08 -- the only NEXTVAL callers were the table DEFAULTs
-- replaced by the identity columns).
--
-- Guarded drop-if-exists: safe to run repeatedly; a fresh
-- `build_local_db.sh --fresh` install also converges because the
-- object files and their install.sql lines were removed.
--
-- Run as DMT_OWNER:
--   sql dmt_owner/...@//localhost:1523/FREEPDB1 @db/tools/drop_retired_supplier_sequences.sql
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
    drop_if_exists('SEQUENCE', 'DMT_POZ_SUPPLIERS_ID_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_POZ_SUPPLIERS_TFM_ID_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_POZ_SUP_ADDR_ID_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_POZ_SUP_ADDR_TFM_ID_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_POZ_SUP_SITE_ID_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_POZ_SUP_SITE_TFM_ID_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_POZ_SUP_SITE_ASSN_ID_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_POZ_SUP_SITE_ASSN_TFM_ID_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_POZ_SUP_CONTACTS_ID_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_POZ_SUP_CONTACTS_TFM_ID_SEQ');
end;
/

exit success
