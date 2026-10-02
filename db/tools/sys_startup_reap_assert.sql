-- ===========================================================================
-- Backlog #144 build-time assertion: confirm the startup reap trigger and the
-- job_queue_processes slot raise both took. CREATE OR REPLACE "succeeds" even
-- on an invalid trigger body, so this prints one machine-readable line the
-- build greps for. Kept in its OWN committed .sql file (run as sysdba,
-- container=FREEPDB1) so the string literals live here, not nested inside a
-- bash single-quoted echo in build_local_db.sh (where '' would close/reopen the
-- echo string and strip the quotes, giving sqlplus an unquoted identifier ->
-- ORA-00904). Emits exactly:
--     REAP144 <trigger-status> <job_queue_processes>
-- e.g. "REAP144 ENABLED 32". A bad trigger prints the real status (not ENABLED)
-- or nothing, so the build's equality check fails loudly.
-- ===========================================================================
set heading off feedback off pagesize 0 verify off echo off termout on trimspool on
alter session set container=FREEPDB1;

select 'REAP144 '
       || NVL( (SELECT status FROM dba_triggers
                WHERE trigger_name = 'DMT_REAP_ORPHAN_JOBS_TRG'), 'MISSING')
       || ' '
       || (SELECT value FROM v$parameter WHERE name = 'job_queue_processes')
  from dual;

exit
