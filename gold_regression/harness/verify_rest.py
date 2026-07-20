"""Read-only verification for a REST-loaded gold fixture (Banks family).

Proves the point with INDEPENDENT direct single-table base reads through the
read-only BIP relay (bip.py). No DMT database, no joins whose NULLs are ambiguous.

  GOOD -> base.  Direct read of each base level filtered by the run prefix on the
                 natural key (bank/branch/account name). Present with a real
                 Fusion id == pass.
  BAD  -> reject + absent. The bad bank's POST was rejected at load time (HTTP
                 4xx/5xx with a Fusion error 'detail', captured by load_rest.py);
                 here we confirm the bad key is ABSENT from the base table. A
                 rejected cashBanks POST creates no party, so absence is proof.

The recipe's "verify" block declares base_read / branch_read / account_read
(each: sql, cols, key_col, id_col), good_keys, bad_keys, and the bad error text.

Usage:
    python verify_rest.py Banks <prefix> [--load-json load_result.json]
"""
import os
import sys
import json
import argparse

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bip  # noqa: E402
from recipe import load_recipe  # noqa: E402


def _fill(sql, prefix, tokens=None):
    out = sql.replace('${PREFIX}', str(prefix)).replace(':PREFIX', f"'{prefix}'")
    for k, v in (tokens or {}).items():
        out = out.replace('${' + k + '}', str(v))
    return out


def _read_level(v, block, prefix, role, tokens):
    if block not in v:
        return None
    b = v[block]
    rows = bip.bip_select(_fill(b['sql'], prefix, tokens), b['cols'], role=role)
    by_key = {}
    for r in rows:
        by_key.setdefault(r.get(b['key_col']), []).append(r)
    return b, by_key


def _matched(keys, by_key, id_col, prefix, tokens):
    def _k(k):
        return _fill(k, prefix, tokens)
    found = []
    for gk in [_k(k) for k in keys]:
        hits = [r for r in by_key.get(gk, []) if r.get(id_col)]
        if hits:
            found.append({'key': gk, 'id': hits[0][id_col]})
    return found


def verify(object_name, prefix, load_result=None, role=None, log=print):
    prefix = str(prefix)
    recipe = load_recipe(object_name)
    v = recipe['verify']
    role = role or v.get('cred_role', recipe.get('cred_role', 'fin_impl'))
    tokens = (load_result or {}).get('tokens') or {}

    def _k(k):
        return _fill(k, prefix, tokens)
    good_keys = [_k(k) for k in v['good_keys']]
    bad_keys = [_k(k) for k in v['bad_keys']]

    _, banks_by_key = _read_level(v, 'base_read', prefix, role, tokens)
    good_in_base = _matched(v['good_keys'], banks_by_key,
                            v['base_read']['id_col'], prefix, tokens)
    bad_absent = {bk: (bk not in banks_by_key) for bk in bad_keys}

    branches = _read_level(v, 'branch_read', prefix, role, tokens)
    branches_in_base = []
    if branches:
        bb, br_by_key = branches
        branches_in_base = [{'key': k, 'id': rs[0][bb['id_col']]}
                            for k, rs in br_by_key.items() if rs and rs[0].get(bb['id_col'])]

    accounts = _read_level(v, 'account_read', prefix, role, tokens)
    accounts_in_base = []
    if accounts:
        ab, ac_by_key = accounts
        accounts_in_base = [{'key': k, 'id': rs[0][ab['id_col']]}
                            for k, rs in ac_by_key.items() if rs and rs[0].get(ab['id_col'])]

    # bad-row error text from the load result (rejected at POST time)
    bad_errors = []
    for rec in (load_result or {}).get('banks', []):
        if rec.get('expect_bad'):
            bad_errors.append({'bank_name': rec.get('bank_name'),
                               'http_status': rec.get('http_status'),
                               'error': rec.get('error') or rec.get('raw')})

    good_ok = len(good_in_base) == len(good_keys)
    bad_ok = all(bad_absent.get(bk, False) for bk in bad_keys)

    result = {
        'object': object_name, 'prefix': prefix, 'role': role,
        'good_keys': good_keys,
        'good_banks_in_base': good_in_base,
        'branches_in_base': branches_in_base,
        'accounts_in_base': accounts_in_base,
        'bad_keys': bad_keys,
        'bad_absent_from_base': bad_absent,
        'bad_errors': bad_errors,
        'pass': good_ok and bad_ok,
    }
    log(json.dumps(result, indent=2))
    return result


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('object_name')
    ap.add_argument('prefix')
    ap.add_argument('--load-json', default=None)
    ap.add_argument('--role', default=None)
    a = ap.parse_args()
    lr = None
    if a.load_json and os.path.exists(a.load_json):
        with open(a.load_json) as f:
            lr = json.load(f)
    verify(a.object_name, a.prefix, load_result=lr, role=a.role)
