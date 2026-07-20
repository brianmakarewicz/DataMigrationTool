"""Standalone REST load + verify for ValueSets (flexfield value set VALUES).

Pure Python. No DMT database, no DMT PL/SQL. Mirrors the exact REST flow of the
reference PL/SQL loader (db/packages/dmt_fnd_vs_results_pkg.pkb.sql, phase 2:
POST .../valueSets/{ValueSetCode}/child/values) but reads its
endpoint/payloads/discovery from objects/ValueSets/recipe.json instead of the
tool, and verifies read-only via the BIP relay.

Value set VALUES attach to an EXISTING independent value set. Per the gold
portability rules (README rules 6-8) this fixture does NOT create a value set;
it DISCOVERS an existing editable independent value set on the TARGET pod at load
time (validation_type='I', not protected, not security-enabled) and adds NEW
values to it, each stamped with a fresh numeric ${PREFIX} so re-runs never
collide and nothing depends on a value set we loaded earlier.

Load path (single Financials REST resource, credential role fin_impl):
    POST /fscmRestApi/resources/11.13.18.05/valueSets/{ValueSetCode}/child/values
    body {"Value": "...", "EnabledFlag": "Y", "Description": "..."}   -> 201 + ValueId

Good rows -> HTTP 201, land in base FND_FLEX_VALUES (keyed by the value set's
FLEX_VALUE_SET_ID). Bad row -> HTTP 400 'The value ... is too long. (FND-2825)'
(Value longer than the value set MaximumSize); a rejected POST creates no
FND_FLEX_VALUES row, so the bad key is absent from base.

Usage:
    python load_rest_vsv.py ValueSets --prefix 91234
"""
import os
import re
import sys
import json
import random
import argparse
from urllib.parse import quote

import requests

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import conn  # noqa: E402
import bip  # noqa: E402
from recipe import load_recipe  # noqa: E402
from discover import run_discovery  # noqa: E402


def _stamp(obj, subs):
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
    return {k: v for k, v in payload.items() if v not in (None, '')}


def _post(url, body, user, pwd, log=print):
    log(f'POST {url}  {json.dumps(body)[:300]}')
    r = requests.post(url, json=body,
                      headers={'Content-Type': 'application/json',
                               'Accept': 'application/json'},
                      auth=(user, pwd), timeout=600)
    detail = None
    try:
        j = r.json()
        detail = j.get('detail') or j.get('title')
        if not detail and isinstance(j.get('o:errorDetails'), list) \
                and j['o:errorDetails']:
            detail = j['o:errorDetails'][0].get('detail')
    except Exception:
        pass
    # Some Fusion validation errors (e.g. FND-2825) come back as plain text.
    if not detail and r.status_code >= 400:
        detail = (r.text or '').strip()[:300]
    log(f'  -> HTTP {r.status_code}' + (f' detail={detail!r}' if detail else ''))
    return r.status_code, r.text, detail


def _extract_id(body_txt, field):
    try:
        return json.loads(body_txt).get(field)
    except Exception:
        m = re.search(rf'"{field}"\s*:\s*(\d+)', body_txt or '')
        return int(m.group(1)) if m else None


def load(object_name, prefix, role=None, log=print):
    recipe = load_recipe(object_name)
    role = role or recipe.get('cred_role', 'fin_impl')
    user, pwd = conn.fusion_creds(role)
    base = conn.fusion_url().rstrip('/')

    # ---- reference resolution ----
    # v1 (objects/): discover an existing editable value set at load time (rule 7).
    # v2 (objects_seeded/): the recipe carries a "seeded" block that hard-codes the
    # value set instead of discovering it; discovery returns {} for such a recipe.
    # Merging both is backward-compatible: a v1 recipe has no "seeded" key, and a
    # v2 recipe has no "discovery" block, so exactly one source populates the tokens.
    tokens = run_discovery(recipe, log=log)
    for _k, _v in (recipe.get('seeded') or {}).items():
        tokens.setdefault(_k, _v)
    tokens['PREFIX'] = str(prefix)
    log(f'tokens: {tokens}')

    # value set code goes in the PATH -> URL-encode (names carry spaces)
    vs_code = tokens['VS_CODE']
    path = recipe['rest']['values_path'].replace(
        '${VS_CODE}', quote(str(vs_code), safe=''))
    for k, v in tokens.items():
        path = path.replace('${' + k + '}', str(v))
    url = base + path

    results = {'object': object_name, 'prefix': str(prefix), 'role': role,
               'value_set_code': vs_code, 'value_set_id': tokens.get('VS_ID'),
               'values': [], 'tokens': tokens}

    for rec in recipe['records']['values']:
        payload = _prune_null(_stamp(rec['payload'], tokens))
        expect_bad = rec.get('expect') == 'bad'
        status, body_txt, detail = _post(url, payload, user, pwd, log=log)
        ok = status in (200, 201)
        value_id = _extract_id(body_txt, 'ValueId') if ok else None
        results['values'].append({
            'tag': rec.get('tag'), 'value': payload.get('Value'),
            'http_status': status, 'ok': ok, 'expect_bad': expect_bad,
            'value_id': value_id, 'error': None if ok else detail,
            'raw': body_txt[:400]})

    log('LOAD SUMMARY: '
        + f"good {sum(1 for v in results['values'] if v['ok'])} ok / "
        + f"{sum(1 for v in results['values'] if not v['ok'])} err "
        + f"(into value set {vs_code!r} id {tokens.get('VS_ID')})")
    return results


def _fill(sql, prefix, tokens):
    out = sql.replace('${PREFIX}', str(prefix))
    for k, v in (tokens or {}).items():
        out = out.replace('${' + k + '}', str(v))
    return out


def verify(object_name, prefix, load_result, role=None, log=print):
    prefix = str(prefix)
    recipe = load_recipe(object_name)
    v = recipe['verify']
    role = role or v.get('cred_role', recipe.get('cred_role', 'fin_impl'))
    tokens = (load_result or {}).get('tokens') or {}

    # GOOD -> base: direct read of FND_FLEX_VALUES for the discovered value set.
    b = v['base_read']
    rows = bip.bip_select(_fill(b['sql'], prefix, tokens), b['cols'], role=role)
    by_key = {}
    for r in rows:
        by_key.setdefault(r.get(b['key_col']), []).append(r)
    good_keys = [_fill(k, prefix, tokens) for k in v['good_keys']]
    good_in_base = []
    for gk in good_keys:
        hits = [r for r in by_key.get(gk, []) if r.get(b['id_col'])]
        if hits:
            good_in_base.append({'key': gk, 'id': hits[0][b['id_col']]})

    # BAD -> absent from base + rejected at POST time (error captured at load).
    bad_keys = [_fill(k, prefix, tokens) for k in v['bad_keys']]
    bad_rows = bip.bip_select(_fill(v['bad_read']['sql'], prefix, tokens),
                              v['bad_read']['cols'], role=role)
    bad_present = {r.get(v['bad_read']['key_col']) for r in bad_rows}
    bad_absent = {bk: (bk not in bad_present) for bk in bad_keys}
    bad_errors = [{'value': r.get('value'), 'http_status': r.get('http_status'),
                   'error': r.get('error')}
                  for r in (load_result or {}).get('values', [])
                  if r.get('expect_bad')]

    good_ok = len(good_in_base) == len(good_keys)
    bad_ok = (all(bad_absent.get(bk, False) for bk in bad_keys)
              and all(e.get('http_status', 0) >= 400 for e in bad_errors)
              and len(bad_errors) == len(bad_keys))

    result = {
        'object': object_name, 'prefix': prefix, 'role': role,
        'value_set_code': (load_result or {}).get('value_set_code'),
        'value_set_id': (load_result or {}).get('value_set_id'),
        'good_keys': good_keys, 'good_in_base': good_in_base,
        'bad_keys': bad_keys, 'bad_absent_from_base': bad_absent,
        'bad_errors': bad_errors,
        'pass': good_ok and bad_ok,
    }
    log(json.dumps(result, indent=2))
    return result


def run(object_name, prefix=None, role=None, log=print):
    prefix = str(prefix or random.randint(10000, 99999))
    log(f'=== {object_name} gold run | prefix {prefix} | type REST_VSV ===')
    loaded = load(object_name, prefix, role=role, log=log)
    result = verify(object_name, prefix, loaded, role=role, log=log)
    return {'load': loaded, 'verify': result}


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('object_name')
    ap.add_argument('--prefix', default=None)
    ap.add_argument('--role', default=None)
    a = ap.parse_args()
    _elog = lambda *m: print(*m, file=sys.stderr)  # noqa: E731
    out = run(a.object_name, a.prefix, a.role, log=_elog)
    print(json.dumps(out, indent=2, default=str))
    sys.exit(0 if out['verify'].get('pass') else 1)
