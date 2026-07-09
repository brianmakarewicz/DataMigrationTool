-- ============================================================
-- scrub_credentials_from_log.sql — one-time (re-runnable) DML tool
--
-- The 2026-07-08 Suppliers blind review found the Fusion password
-- logged in PLAINTEXT to DMT_LOG_TBL: the supplier reconciler logged
-- the raw BIP runReport SOAP envelope, whose body carries
-- <v2:userID>/<v2:password>. The code path is fixed (envelope logging
-- removed; DMT_UTIL_PKG.MASK_CREDENTIALS guards every envelope log);
-- this tool cleanses the rows already written.
--
-- What it does: rewrites DMT_LOG_TBL.MESSAGE through
-- DMT_UTIL_PKG.MASK_CREDENTIALS for every row whose message contains
-- a password/userID XML element or an Authorization header value.
--
-- Guarded + idempotent: only matching rows are touched, and masking
-- already-masked text is a no-op, so re-runs update rows that are
-- already clean to identical values (reported as 0 changed).
-- Run as DMT_OWNER (git-first rule: run only this committed file):
--   sql dmt_owner/...@//localhost:1523/FREEPDB1 @db/tools/scrub_credentials_from_log.sql
-- ============================================================

whenever sqlerror exit failure
set serveroutput on size unlimited

declare
    l_matched  pls_integer := 0;
    l_changed  pls_integer := 0;
    l_masked   clob;
begin
    for r in (
        select log_id, message
        from   dmt_owner.dmt_log_tbl
        where  regexp_like(message,
                   '<([a-z0-9_]+:)?(password|userid)[^>]*>|authorization["'']?\s*[:=]', 'i')
        for update of message
    ) loop
        l_matched := l_matched + 1;
        l_masked  := dmt_util_pkg.mask_credentials(r.message);
        if dbms_lob.compare(l_masked, r.message) != 0 then
            update dmt_owner.dmt_log_tbl
            set    message = l_masked
            where  log_id  = r.log_id;
            l_changed := l_changed + 1;
        end if;
    end loop;
    commit;
    dbms_output.put_line('SCRUB_CREDENTIALS_FROM_LOG: rows matched: ' || l_matched ||
                         ' | rows masked: ' || l_changed);

    -- Post-check: no unmasked password element content may remain.
    select count(*) into l_matched
    from   dmt_owner.dmt_log_tbl
    where  regexp_like(message,
               '<([a-z0-9_]+:)?password[^>]*>[^*<]', 'i');
    if l_matched > 0 then
        raise_application_error(-20999,
            'SCRUB_CREDENTIALS_FROM_LOG: ' || l_matched ||
            ' row(s) still carry unmasked password element content.');
    end if;
    dbms_output.put_line('SCRUB_CREDENTIALS_FROM_LOG: post-check clean — ' ||
                         'no unmasked password element content in DMT_LOG_TBL.');
end;
/
