r"""
setup_fusion_config.py — inject live-Fusion connection config into the LOCAL
Docker DMT2 database (DML only; never commits credential values to git).

Reads credentials from ~/workspace/connections.json via conn_helper
(get_fusion_url / get_fusion_user) and writes them into DMT_CONFIG_TBL through
the package API (DMT_UTIL_PKG.SET_FUSION_URL / SET_CONFIG). SET_FUSION_URL
also maintains the network ACL for the Fusion host, so running this script is
the complete DB-side setup for the Stage B2 live smoke tests
(test/unit/test_fusion_calls.sql).

Also (best-effort, read-only) discovers a known-terminal ESS request id from
the frozen stack's ATP (queryapp / DMT_OWNER / DMT_ESS_JOB_TBL) and stores it
as SMOKE_ESS_REQUEST_ID so the ESS status smoke test can poll a completed job
instead of submitting anything. If the ATP is unreachable the key is left
unset and the ESS test skips itself with a message.

Usage:
    PYTHONUTF8=1 python test/unit/setup_fusion_config.py
    (PYTHONUTF8=1 because connections.json is UTF-8 and conn_helper opens it
    with the platform default encoding, which is cp1252 on Windows.)
Env overrides:
    DMT2_DSN  (default localhost:1523/FREEPDB1)
    DMT2_USER (default dmt_owner)
    DMT2_PWD  (default the local dev password from run_unit_tests.sh)
"""

import os
import sys

sys.path.insert(0, r'C:\Users\Monroe\workspace')
from conn_helper import get_fusion_url, get_fusion_user  # noqa: E402

import oracledb  # noqa: E402

DSN = os.environ.get('DMT2_DSN', 'localhost:1523/FREEPDB1')
USER = os.environ.get('DMT2_USER', 'dmt_owner')
PWD = os.environ.get('DMT2_PWD', 'DmtLocal#2026')


def main():
    url = get_fusion_url().rstrip('/')
    fin_user, fin_pwd = get_fusion_user('fin_impl')

    conn = oracledb.connect(user=USER, password=PWD, dsn=DSN)
    cur = conn.cursor()

    # Fusion base URL — SET_FUSION_URL also creates/updates the network ACL.
    cur.callproc('dmt_util_pkg.set_fusion_url', [url])

    def set_config(key, value, desc):
        cur.callproc('dmt_util_pkg.set_config', [key, value, desc])

    set_config('FUSION_USERNAME', fin_user, 'Fusion REST/SOAP user (injected, not committed)')
    set_config('FUSION_PASSWORD', fin_pwd,  'Fusion REST/SOAP password (injected, not committed)')
    set_config('BIP_USERNAME',    fin_user, 'BIP SOAP user (injected, not committed)')
    set_config('BIP_PASSWORD',    fin_pwd,  'BIP SOAP password (injected, not committed)')
    # connections.json has no hcm_impl user for this pod; the HCM REST path
    # (UCM uploadFile) is exercised with fin_impl. Override any stale snapshot
    # values so DMT_HDL_UTIL_PKG.get_auth resolves to a live credential.
    set_config('HCM_USERNAME', fin_user, 'HCM REST user (injected, not committed)')
    set_config('HCM_PASSWORD', fin_pwd,  'HCM REST password (injected, not committed)')
    print(f'Config injected: FUSION_URL={url}  user={fin_user}  (+BIP_*, HCM_* aliases)')

    # Best-effort: a known-terminal ESS request id from the frozen stack's ATP.
    try:
        from conn_helper import connect_atp
        atp = connect_atp('queryapp', 'DMT_OWNER')
        acur = atp.cursor()
        acur.execute("""
            select to_char(max(request_id))
            from   dmt_ess_job_tbl
            where  state_text = 'SUCCEEDED'
        """)
        row = acur.fetchone()
        atp.close()
        if row and row[0]:
            set_config('SMOKE_ESS_REQUEST_ID', row[0],
                       'Known SUCCEEDED ESS request id for poll-only smoke test')
            print(f'SMOKE_ESS_REQUEST_ID = {row[0]} (from frozen-stack ATP, read-only)')
        else:
            print('No SUCCEEDED ESS request found on ATP — ESS smoke test will skip.')
    except Exception as e:  # noqa: BLE001 — setup must not fail on the optional part
        print(f'ATP lookup skipped ({type(e).__name__}: {e}) — ESS smoke test will skip '
              'unless SMOKE_ESS_REQUEST_ID is set manually.')

    conn.commit()
    conn.close()
    print('Done.')


if __name__ == '__main__':
    main()
