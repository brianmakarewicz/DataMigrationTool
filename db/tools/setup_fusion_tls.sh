#!/bin/sh
# ============================================================
# setup_fusion_tls.sh — verify (and document) the local Docker DB's
# ability to make HTTPS calls to the Oracle Fusion demo instance.
#
# FINDING (2026-07-08, container dmt2-local, Oracle AI Database 26ai
# Free 23.26.2.0.0): NO wallet setup is required. UTL_HTTP in this
# image trusts the OS default certificate store out of the box — an
# HTTPS request to the Fusion host succeeds (returns the server's
# HTTP status) with no UTL_HTTP.SET_WALLET call at all. So this
# script only VERIFIES the two prerequisites instead of building a
# wallet:
#
#   1. Network ACL — created/maintained by
#      DMT_UTIL_PKG.SET_FUSION_URL (connect+resolve ACEs for the
#      Fusion host, principal DMT_OWNER). Run
#      `PYTHONUTF8=1 python test/unit/setup_fusion_config.py`
#      (which calls SET_FUSION_URL) before this check.
#      DBMS_NETWORK_ACL_ADMIN is granted to DMT_OWNER by
#      build_local_db.sh (as sysdba inside the container).
#
#   2. TLS trust — verified by an in-database HTTPS probe below.
#      Any HTTP status (200/302/401/...) = TLS handshake OK.
#      ORA-29024 / ORA-28759 / ORA-29273 with certificate text =
#      trust failure; only then is a wallet needed — create one in
#      the container with orapki, import the Fusion CA chain, and
#      call UTL_HTTP.SET_WALLET('file:<path>') before requests
#      (not needed on this image; see docs/tranche-reviews/
#      2026-07-08-stage-b2-notes.md).
#
# Usage:  sh db/tools/setup_fusion_tls.sh
# Env:    DMT2_CONN, SQLCL, JAVA_HOME (same defaults as run_unit_tests.sh)
# ============================================================

set -u

JAVA_HOME="${JAVA_HOME:-/c/Users/Monroe/tools/jdk-21.0.11+10}"
export JAVA_HOME
PATH="$JAVA_HOME/bin:$PATH"
export PATH

SQLCL="${SQLCL:-/c/Users/Monroe/tools/sqlcl/bin/sql}"
DMT2_CONN="${DMT2_CONN:-dmt_owner/DmtLocal#2026@//localhost:1523/FREEPDB1}"

echo exit | "$SQLCL" -S "$DMT2_CONN" <<'SQL'
set serveroutput on feedback off
declare
    l_url  varchar2(500);
    l_host varchar2(500);
    l_cnt  pls_integer;
    l_req  utl_http.req;
    l_resp utl_http.resp;
begin
    l_url := dmt_util_pkg.get_config('FUSION_URL');
    if l_url is null then
        dbms_output.put_line('FAIL: FUSION_URL not set in DMT_CONFIG_TBL. '||
            'Run: PYTHONUTF8=1 python test/unit/setup_fusion_config.py');
        return;
    end if;
    l_host := regexp_substr(l_url, '://([^/]+)', 1, 1, 'i', 1);

    select count(*) into l_cnt
    from   user_host_aces
    where  host = l_host and privilege in ('CONNECT', 'RESOLVE');
    if l_cnt >= 2 then
        dbms_output.put_line('OK  : ACL present for '||l_host||' (connect+resolve).');
    else
        dbms_output.put_line('FAIL: ACL missing/incomplete for '||l_host||
            ' — run setup_fusion_config.py (SET_FUSION_URL creates it).');
        return;
    end if;

    begin
        l_req  := utl_http.begin_request(l_url, 'GET', 'HTTP/1.1');
        l_resp := utl_http.get_response(l_req);
        dbms_output.put_line('OK  : TLS handshake succeeded with NO wallet '||
            '(OS trust store). Server answered HTTP '||l_resp.status_code||'.');
        utl_http.end_response(l_resp);
    exception
        when others then
            dbms_output.put_line('FAIL: HTTPS probe failed: '||sqlerrm);
            dbms_output.put_line('      If this is ORA-29024/28759 (certificate '||
                'validation), this image needs a wallet — see header comments.');
    end;
end;
/
exit
SQL
