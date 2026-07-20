"""Load-time discovery of Fusion reference values (portability rule 7).

A fixture must not depend on data we loaded earlier. Any FK-style reference
(supplier, business unit, ledger, legal employer, ...) is discovered at load
time by a read-only BIP query against the TARGET pod and stamped into the
template alongside ${PREFIX}.

A recipe's optional "discovery" block is a list of steps:

  { "name": "AP_SUPPLIER",
    "role": "fin_impl",
    "cols": ["VNAME","VNUM","SITE","BUNAME"],
    "sql":  "SELECT ... WHERE ROWNUM<=1",
    "bind": { "SUPPLIER_NAME":"VNAME", "SUPPLIER_NUM":"VNUM",
              "SUPPLIER_SITE":"SITE", "BU_NAME":"BUNAME" },
    "required": true }

run_discovery(recipe) executes each step, takes the first returned row, and maps
its columns to template tokens via "bind" (token -> column alias). The result is
a dict of ${TOKEN} -> value that build_artifact stamps into the template just
like ${PREFIX}. If a required step returns no row, it raises -- we never load a
fixture whose reference could not be confirmed present on the target pod.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bip  # noqa: E402


def run_discovery(recipe, log=print):
    """Return {TOKEN: value} discovered from the target pod for this recipe.

    Empty dict when the recipe has no discovery block.
    """
    steps = recipe.get('discovery') or []
    tokens = {}
    for step in steps:
        name = step.get('name', '(unnamed)')
        role = step.get('role', recipe.get('cred_role', 'fin_impl'))
        cols = step['cols']
        sql = step['sql']
        # A later step may reference a token discovered by an earlier step
        # (e.g. AR bill-to customer filtered by the discovered ${BU_ID}). Only
        # already-resolved tokens are substituted; a step never forward-refs.
        for tok, val in tokens.items():
            sql = sql.replace('${' + tok + '}', str(val))
        rows = bip.bip_select(sql, cols, role=role)
        if not rows:
            if step.get('required', True):
                raise RuntimeError(
                    f'Discovery step {name!r} returned no row on the target '
                    f'pod. Cannot stamp a portable reference. SQL: {sql[:200]}')
            log(f'discovery {name}: no row (optional) -- skipping')
            continue
        row = rows[0]
        for token, col in step['bind'].items():
            val = row.get(col)
            if val is None and step.get('required', True):
                raise RuntimeError(
                    f'Discovery step {name!r} row missing column {col!r} for '
                    f'token ${{{token}}}. Row: {row}')
            tokens[token] = val if val is not None else ''
        log(f'discovery {name}: ' +
            ', '.join(f'${{{t}}}={tokens.get(t)!r}' for t in step['bind']))
    return tokens


if __name__ == '__main__':
    import json
    from recipe import load_recipe
    name = sys.argv[1]
    print(json.dumps(run_discovery(load_recipe(name)), indent=2))
