-- ============================================================
-- drop_retired_customer_sequences.sql
--
-- Customers Wave-1 offline identity conversion (accepted coding
-- standard 2026-07-08: "Identity columns for keys; sequences only
-- for shared, meaningful values"): the 14 Customers HZ STG/TFM
-- tables now number their own rows with GENERATED ALWAYS AS
-- IDENTITY primary keys, so the 14 per-table ID sequences are
-- retired. Their object files and install.sql lines are removed in
-- the same commit; this tool drops the live objects from an
-- existing database. Mirrors db/tools/drop_retired_supplier_sequences.sql.
--
-- No package references any of these sequences (verified by grep
-- across db/ 2026-07-09 -- the only NEXTVAL callers were the table
-- DEFAULTs replaced by the identity columns).
--
-- Guarded drop-if-exists: safe to run repeatedly; a fresh
-- `build_local_db.sh --fresh` install also converges because the
-- object files and their install.sql lines were removed.
--
-- Run as DMT_OWNER:
--   sql dmt_owner/...@//localhost:1523/FREEPDB1 @db/tools/drop_retired_customer_sequences.sql
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
    drop_if_exists('SEQUENCE', 'DMT_HZ_PARTIES_STG_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_HZ_PARTIES_TFM_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_HZ_LOCATIONS_STG_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_HZ_LOCATIONS_TFM_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_HZ_PARTY_SITES_STG_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_HZ_PARTY_SITES_TFM_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_HZ_PARTY_SITE_USES_STG_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_HZ_PARTY_SITE_USES_TFM_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_HZ_ACCOUNTS_STG_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_HZ_ACCOUNTS_TFM_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_HZ_ACCT_SITES_STG_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_HZ_ACCT_SITES_TFM_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_HZ_ACCT_SITE_USES_STG_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_HZ_ACCT_SITE_USES_TFM_SEQ');
end;
/

exit success
