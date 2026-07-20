"""Standalone REST load for gold-regression objects (Banks family).

Pure Python. No DMT database, no DMT PL/SQL. Mirrors the exact REST flow of the
reference PL/SQL loader (db/packages/dmt_ce_bank_results_pkg.pkb.sql) but reads
its endpoints/payloads/order from objects/{Name}/recipe.json instead of the tool.

Cash Management banks are a three-level chain, each level a separate POST:

  1. POST  /fscmRestApi/resources/11.13.18.05/cashBanks
           {CountryName, BankName, BankNumber, ...}          -> BankPartyId
  2. POST  /fscmRestApi/resources/11.13.18.05/cashBankBranches
           {BankName, BankBranchName, BranchNumber, CountryName, EFTSWIFTCode}
                                                             -> BranchPartyId
  3. POST  /fscmRestApi/resources/11.13.18.05/cashBankAccounts
           {BankAccountName, BankAccountNumber, CurrencyCode, BankName,
            BankBranchName, LegalEntityName, ...}            -> BankAccountId

The branch links to its bank by BankName; the account links to bank+branch by
BankName+BankBranchName and MUST carry a mandatory LegalEntityName (discovered).
All three use the fin_impl credential role (Cash Management is Financials).

A non-2xx response is NOT fatal here: it is the whole point of the bad row. The
loader records the HTTP status + Fusion error 'detail' for every POST and returns
a structured result so verify.py can prove good rows created and bad row rejected.

Usage:
    python load_rest.py Banks --prefix 91234
"""
import os
import re
import sys
import json
import argparse

import requests

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import conn  # noqa: E402
from recipe import load_recipe  # noqa: E402
from discover import run_discovery  # noqa: E402


def _aba_routing(first8):
    """Return a valid 9-digit ABA routing number: first8 (8 digits) plus the
    ABA check digit. US bank branches validate BranchNumber as a routing
    transit number (Fusion CE-660076); the check digit makes it pass.

    Rule: 3*(d1+d4+d7) + 7*(d2+d5+d8) + 1*(d3+d6+d9) is a multiple of 10.
    """
    d = [int(c) for c in first8]
    s = 3 * (d[0] + d[3] + d[6]) + 7 * (d[1] + d[4] + d[7]) + 1 * (d[2] + d[5])
    check = (10 - (s % 10)) % 10
    return first8 + str(check)


def _computed_tokens(prefix):
    """Deterministic, prefix-derived tokens usable in payload templates.

    ${ROUTING1}/${ROUTING2} are valid ABA routing numbers (9 digits, correct
    check digit) built from the numeric prefix so US branches pass routing
    validation and re-runs on a fresh prefix don't collide.
    """
    p = str(prefix)
    base8_1 = (p + '00000000')[:7] + '1'   # 8 digits, distinct per prefix
    base8_2 = (p + '00000000')[:7] + '2'
    return {
        'ROUTING1': _aba_routing(base8_1[:8]),
        'ROUTING2': _aba_routing(base8_2[:8]),
    }


def _stamp(obj, subs):
    """Recursively replace ${TOKEN} tokens in a JSON-like structure."""
    if isinstance(obj, str):
        out = obj
        for k, v in subs.items():
            out = out.replace('${' + k + '}', str(v))
        return out
    if isinstance(obj, dict):
        return {k: _stamp(v, subs) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_stamp(v, subs) for v in obj]
    return obj


def _prune_null(payload):
    """Drop keys whose stamped value is empty (optional fields left blank)."""
    return {k: v for k, v in payload.items() if v not in (None, '')}


def _post(base, path, body, user, pwd, log=print):
    url = base.rstrip('/') + path
    log(f'POST {url}  {json.dumps(body)[:300]}')
    r = requests.post(url, json=body,
                      headers={'Content-Type': 'application/json',
                               'Accept': 'application/json'},
                      auth=(user, pwd), timeout=600)
    body_txt = r.text
    detail = None
    try:
        j = r.json()
        detail = j.get('detail') or j.get('title')
        if not detail and isinstance(j.get('o:errorDetails'), list) \
                and j['o:errorDetails']:
            detail = j['o:errorDetails'][0].get('detail')
    except Exception:
        pass
    log(f'  -> HTTP {r.status_code}'
        + (f' detail={detail!r}' if detail else ''))
    return r.status_code, body_txt, detail


def _extract_id(body_txt, field):
    try:
        j = json.loads(body_txt)
        return j.get(field)
    except Exception:
        m = re.search(rf'"{field}"\s*:\s*(\d+)', body_txt or '')
        return int(m.group(1)) if m else None


def run(object_name, prefix, role=None, log=print):
    recipe = load_recipe(object_name)
    role = role or recipe.get('cred_role', 'fin_impl')
    user, pwd = conn.fusion_creds(role)
    base = conn.fusion_url()

    # ---- load-time discovery (portability rule 7) -----------------------
    tokens = run_discovery(recipe, log=log)
    tokens['PREFIX'] = prefix
    tokens.update(_computed_tokens(prefix))
    log(f'tokens: {tokens}')

    rest = recipe['rest']
    banks_path = rest['banks_path']
    branches_path = rest['branches_path']
    accounts_path = rest['accounts_path']

    results = {'object': object_name, 'prefix': str(prefix), 'role': role,
               'banks': [], 'branches': [], 'accounts': [],
               'bank_party_ids': {}, 'branch_party_ids': {}}

    # ---- Phase 1: banks -------------------------------------------------
    for rec in recipe['records']['banks']:
        tag = rec.get('tag')
        payload = _prune_null(_stamp(rec['payload'], tokens))
        expect_bad = rec.get('expect') == 'bad'
        status, body_txt, detail = _post(base, banks_path, payload,
                                         user, pwd, log=log)
        ok = status in (200, 201)
        bank_party_id = _extract_id(body_txt, 'BankPartyId') if ok else None
        entry = {'tag': tag, 'bank_name': payload.get('BankName'),
                 'http_status': status, 'ok': ok, 'expect_bad': expect_bad,
                 'bank_party_id': bank_party_id, 'error': None if ok else detail,
                 'raw': body_txt[:600]}
        results['banks'].append(entry)
        if ok and tag:
            results['bank_party_ids'][tag] = bank_party_id

    # ---- Phase 2: branches (only for banks that loaded) -----------------
    for rec in recipe['records'].get('branches', []):
        parent = rec.get('bank_tag')
        if parent and parent not in results['bank_party_ids']:
            log(f'skip branch (parent bank {parent!r} not loaded)')
            continue
        tag = rec.get('tag')
        payload = _prune_null(_stamp(rec['payload'], tokens))
        status, body_txt, detail = _post(base, branches_path, payload,
                                         user, pwd, log=log)
        ok = status in (200, 201)
        branch_party_id = _extract_id(body_txt, 'BranchPartyId') if ok else None
        entry = {'tag': tag, 'branch_name': payload.get('BankBranchName'),
                 'http_status': status, 'ok': ok,
                 'branch_party_id': branch_party_id,
                 'error': None if ok else detail, 'raw': body_txt[:600]}
        results['branches'].append(entry)
        if ok and tag:
            results['branch_party_ids'][tag] = branch_party_id

    # ---- Phase 3: accounts (only for branches that loaded) --------------
    for rec in recipe['records'].get('accounts', []):
        parent = rec.get('branch_tag')
        if parent and parent not in results['branch_party_ids']:
            log(f'skip account (parent branch {parent!r} not loaded)')
            continue
        payload = _prune_null(_stamp(rec['payload'], tokens))
        status, body_txt, detail = _post(base, accounts_path, payload,
                                         user, pwd, log=log)
        ok = status in (200, 201)
        acct_id = _extract_id(body_txt, 'BankAccountId') if ok else None
        entry = {'account_name': payload.get('BankAccountName'),
                 'http_status': status, 'ok': ok, 'bank_account_id': acct_id,
                 'error': None if ok else detail, 'raw': body_txt[:600]}
        results['accounts'].append(entry)

    log('LOAD SUMMARY: '
        + f"banks {sum(1 for b in results['banks'] if b['ok'])} ok / "
        + f"{sum(1 for b in results['banks'] if not b['ok'])} err | "
        + f"branches {sum(1 for b in results['branches'] if b['ok'])} ok | "
        + f"accounts {sum(1 for a in results['accounts'] if a['ok'])} ok")
    results['tokens'] = {k: v for k, v in tokens.items()}
    return results


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('object_name')
    ap.add_argument('--prefix', required=True)
    ap.add_argument('--role', default=None)
    a = ap.parse_args()
    _elog = lambda *m: print(*m, file=sys.stderr)  # noqa: E731
    out = run(a.object_name, a.prefix, a.role, log=_elog)
    print(json.dumps(out, indent=2))
