"""Read-only verification of a gold load via the BIP ephemeral relay.

Proves the two directions with INDEPENDENT single-table reads -- never a relayed
multi-table LEFT JOIN whose NULLs are ambiguous (a confirmed false-negative on
Suppliers: the join returned NULL for a base row that genuinely existed):

  GOOD -> base table.   Direct read of the BASE table, filtered by the run's
                        prefix on the natural key (e.g.
                        SELECT invoice_num,invoice_id FROM ap_invoices_all
                        WHERE invoice_num LIKE '<prefix>%'). A row present with
                        a real Fusion id == pass.
  BAD  -> interface.    Direct read of the INTERFACE table (by request id) plus
                        the REJECTIONS table (by request id) -- the bad key
                        present with an error. And a direct base read confirming
                        the bad key is absent from the base table.

The recipe's "verify" block declares, per object, the base read (table, key
column, key expression, id column) and the interface/reject reads. For HDL, the
base read is a person-number prefix read of PER_ALL_PEOPLE_F and the "bad"
evidence is the HDL message list captured at load time.

Usage:
    python verify.py APInvoices <load_request_id> <prefix>
    python verify.py Workers    -                 <prefix>   # HDL: no request id key on base
"""
import os
import sys
import json
import argparse

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bip  # noqa: E402
from recipe import load_recipe  # noqa: E402


def _fill(sql, prefix, request_id, tokens=None):
    out = (sql.replace(':PREFIX', f"'{prefix}'")
              .replace('${PREFIX}', str(prefix))
              .replace(':LRID', str(request_id))
              .replace(':REQUEST_ID', str(request_id)))
    # Discovered ${TOKEN}s (ledger/budget/period/account etc.) let a cell-grained
    # object (GL Budgets has no prefix-bearing base key) scope its base read to
    # the exact discovered references it just loaded.
    for k, val in (tokens or {}).items():
        out = out.replace('${' + k + '}', str(val))
    return out


def verify(object_name, load_request_id, prefix, role=None, log=print,
           hdl_messages=None, tokens=None):
    prefix = str(prefix)
    recipe = load_recipe(object_name)
    v = recipe['verify']
    role = role or v.get('cred_role', recipe.get('cred_role', 'fin_impl'))

    # ---- GOOD: direct base-table read by prefix on the natural key ----------
    base = v['base_read']
    base_sql = _fill(base['sql'], prefix, load_request_id, tokens)
    base_rows = bip.bip_select(base_sql, base['cols'], role=role)
    key_col = base['key_col']
    id_col = base['id_col']
    def _key(k):
        k = k.replace('${PREFIX}', prefix)
        for tk, tv in (tokens or {}).items():
            k = k.replace('${' + tk + '}', str(tv))
        return k
    good_keys = [_key(k) for k in v['good_keys']]
    bad_keys = [_key(k) for k in v['bad_keys']]

    base_by_key = {}
    for r in base_rows:
        base_by_key.setdefault(r.get(key_col), []).append(r)

    good_in_base = []
    for gk in good_keys:
        hits = [r for r in base_by_key.get(gk, []) if r.get(id_col)]
        if hits:
            good_in_base.append({'key': gk, 'id': hits[0].get(id_col),
                                 'row': hits[0]})

    # bad key must be ABSENT from base
    bad_absent = {bk: (bk not in base_by_key) for bk in bad_keys}

    # ---- BAD: direct interface + rejection read -----------------------------
    bad_in_interface = []
    if v.get('interface_read'):
        ir = v['interface_read']
        i_sql = _fill(ir['sql'], prefix, load_request_id, tokens)
        i_rows = bip.bip_select(i_sql, ir['cols'], role=role)
        i_key = ir['key_col']
        err_col = ir.get('error_col', 'ERROR_MESSAGE')
        for bk in bad_keys:
            match = [r for r in i_rows if (r.get(i_key) or '').strip() == bk]
            if match and (match[0].get(err_col) or '').strip():
                bad_in_interface.append({'key': bk,
                                         'error': match[0].get(err_col)})
            elif match:
                bad_in_interface.append({'key': bk,
                                         'error': '(in interface, error text '
                                         'not captured by this read)',
                                         'partial': True})
    elif hdl_messages is not None:
        # HDL: the bad evidence is a load-time message keyed by SourceSystemId.
        # Some update-by-user-key loads (no SourceSystemId supplied) return the
        # rejection with a NULL SourceSystemId. When the recipe declares the
        # expected error snippet via "bad_error_contains", we also match a
        # SourceSystemId-less error message that carries that snippet.
        bad_snippet = (v.get('bad_error_contains') or '').lower()
        for bk in bad_keys:
            msgs = [m for m in hdl_messages
                    if bk in (m.get('SourceSystemId') or '')
                    and (m.get('MessageType') in (None, 'ERROR', 'ORA_ERROR')
                         or 'error' in (m.get('MessageText') or '').lower())]
            if not msgs and bad_snippet:
                msgs = [m for m in hdl_messages
                        if not (m.get('SourceSystemId') or '')
                        and bad_snippet in (m.get('MessageText') or '').lower()]
            if msgs:
                bad_in_interface.append(
                    {'key': bk,
                     'error': '; '.join(m.get('MessageText', '') for m in msgs[:3])})

    # Some Fusion imports UNCONDITIONALLY purge their interface table after the
    # import job completes -- both accepted and rejected rows are deleted (e.g.
    # Project Billing Events, MOS 2534525.1). For such an object the rejected row
    # is never readable in the interface, and its error text lives only in the
    # import report XML (not a BIP-reachable table). A recipe declares
    # "bad_proof_is_absence": true to say: the authoritative BAD proof is that
    # the bad key is ABSENT from the base table (it was rejected, never created)
    # while the good keys from the SAME load reached the base with real ids. This
    # is opt-in; every other object keeps the interface-error requirement.
    bad_proof_absence = bool(v.get('bad_proof_is_absence'))
    # A recipe may supply its own object-accurate note for the absence fallback
    # (e.g. Item Import purges error rows from EGP_SYSTEM_ITEMS_INTERFACE after the
    # batch completes). Default keeps the original Billing-Events wording so any
    # existing recipe that relied on it is unchanged.
    default_absence_note = (
        'interface table purged after import (unconditional purge; 0 rows for '
        'this load_request_id) -- rejection proven by ABSENCE from base table '
        'PJB_BILLING_EVENTS while good rows from the same load reached base; '
        'per-row error text is only in the ImportBillingEventReportJob XML')
    absence_note = v.get('bad_absence_note', default_absence_note)
    if bad_proof_absence and not bad_in_interface:
        for bk in bad_keys:
            bad_in_interface.append({
                'key': bk,
                'error': absence_note,
                'proof': 'absent_from_base'})

    good_ok = len(good_in_base) == len(good_keys)
    bad_ok = (len(bad_in_interface) == len(bad_keys)
              and all(bad_absent.get(bk, False) for bk in bad_keys))

    result = {
        'object': object_name,
        'load_request_id': str(load_request_id),
        'prefix': prefix,
        'good_keys': good_keys,
        'good_in_base': good_in_base,
        'good_in_base_count': len(good_in_base),
        'bad_keys': bad_keys,
        'bad_in_interface': bad_in_interface,
        'bad_absent_from_base': bad_absent,
        'pass': good_ok and bad_ok,
    }
    log(json.dumps(result, indent=2))
    return result


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('object_name')
    ap.add_argument('load_request_id')
    ap.add_argument('prefix')
    ap.add_argument('--role', default=None)
    a = ap.parse_args()
    verify(a.object_name, a.load_request_id, a.prefix, a.role)
