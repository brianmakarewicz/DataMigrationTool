-- ============================================================
-- drop_retired_worker_sequences.sql
--
-- Workers HDL identity conversion (accepted coding standard
-- 2026-07-08: "Identity columns for keys; sequences only for shared,
-- meaningful values"): the Workers STG/TFM table and the six
-- Person* STG/TFM tables number their own rows with GENERATED
-- (ALWAYS/BY DEFAULT) AS IDENTITY primary keys, so the 14 per-table
-- ID sequences left enrolled in install.sql were dead. Their object
-- files and the 14 install.sql lines are removed in the same commit;
-- this tool drops the live objects from an existing database.
--
-- No package references any of these sequences (verified by grep
-- across db/ 2026-07-09 -- the only reference was the @@ line in
-- db/install.sql, now removed).
--
-- Guarded drop-if-exists: safe to run repeatedly; a fresh
-- `build_local_db.sh --fresh` install also converges because the
-- object files and their install.sql lines were removed.
--
-- Run as DMT_OWNER:
--   sql dmt_owner/...@//localhost:1523/FREEPDB1 @db/tools/drop_retired_worker_sequences.sql
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
    drop_if_exists('SEQUENCE', 'DMT_WORKER_STG_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_WORKER_TFM_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_PERSON_ADDR_STG_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_PERSON_ADDR_TFM_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_PERSON_EMAIL_STG_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_PERSON_EMAIL_TFM_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_PERSON_LEGISL_STG_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_PERSON_LEGISL_TFM_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_PERSON_NAME_STG_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_PERSON_NAME_TFM_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_PERSON_NID_STG_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_PERSON_NID_TFM_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_PERSON_PHONE_STG_SEQ');
    drop_if_exists('SEQUENCE', 'DMT_PERSON_PHONE_TFM_SEQ');
end;
/

exit success
