-- ============================================================
-- drop_retired_prefix_objects.sql
--
-- Stage C prefix consolidation (design section 6, 2026-07-08):
-- one prefix per run, assigned at run creation from the single
-- sequence DMT_RUN_PREFIX_SEQ and stored on
-- DMT_PIPELINE_RUN_TBL.PREFIX. The retired per-CEMLI prefix-master
-- mechanism and the second prefix sequence are dropped here.
--
-- Guarded drop-if-exists: safe to run repeatedly; a fresh
-- `build_local_db.sh --fresh` install also converges because the
-- object files and their install.sql lines were removed.
--
-- Run as DMT_OWNER:
--   sql dmt_owner/...@//localhost:1523/FREEPDB1 @db/tools/drop_retired_prefix_objects.sql
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
            if p_type = 'TABLE' then
                execute immediate 'drop table "' || p_name || '" cascade constraints';
            else
                execute immediate 'drop ' || p_type || ' "' || p_name || '"';
            end if;
            dbms_output.put_line('DROP  ' || p_type || ' ' || p_name);
        end if;
    end drop_if_exists;
begin
    drop_if_exists('SEQUENCE', 'DMT_PREFIX_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_PREFIX_MASTER_ID_SEQ');
    drop_if_exists('TABLE',    'DMT_PREFIX_MASTER_TBL');
end;
/

exit success
