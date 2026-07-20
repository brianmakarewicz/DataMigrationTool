"""End-to-end gold run for one object: discover -> build -> load -> verify.

Runs the whole standalone path in one process so discovery happens once and the
discovered reference values flow into BOTH the artifact and (for FBDI) the
import ParameterList. No DMT database, no DMT pipeline code in the load path;
verification is the read-only BIP relay only.

  FBDI: loadAndImportData (load + chained import), poll, optional downstream
        ESS programs, then direct base/interface reads.
  HDL:  REST uploadFile -> createFileDataSet -> poll, then base read
        (PER_ALL_PEOPLE_F by prefix) + the load-time HDL error messages.

Usage:
    python run_object.py APInvoices          # picks a fresh random prefix
    python run_object.py Workers --prefix 90212
"""
import os
import sys
import json
import random
import argparse

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from recipe import load_recipe  # noqa: E402
import discover  # noqa: E402
import build_artifact  # noqa: E402
import verify as verify_mod  # noqa: E402


def fresh_prefix():
    # numeric-only prefix, sequence-ish; 5 digits keeps keys short
    return str(random.randint(10000, 99999))


def run(object_name, prefix=None, log=print):
    recipe = load_recipe(object_name)
    prefix = str(prefix or fresh_prefix())
    log(f'=== {object_name} gold run | prefix {prefix} | type {recipe.get("type")} ===')

    tokens = discover.run_discovery(recipe, log=log)
    zip_path = build_artifact.build(object_name, prefix, tokens=tokens, recipe=recipe, log=log)
    # Prefix-derived tokens (e.g. ${SAL_DATE_DASH}) are stamped into the artifact
    # by build_artifact; a verify base read that scopes on such a value needs them
    # too. Merge them into the tokens passed to verify (discovered tokens win).
    for _k, _v in build_artifact.derived_tokens(prefix).items():
        tokens.setdefault(_k, _v)

    if recipe.get('type') == 'HDL':
        import load_hdl
        loaded = load_hdl.run(object_name, zip_path, log=log)
        result = verify_mod.verify(object_name, loaded.get('request_id'), prefix,
                                   log=log, hdl_messages=loaded.get('messages'),
                                   tokens=tokens)
        summary = {'load': {'request_id': loaded.get('request_id'),
                            'terminal_status': loaded.get('terminal_status')},
                   'verify': result}
    else:
        import load_fbdi
        loaded = load_fbdi.run(object_name, zip_path, log=log,
                               prefix=prefix, tokens=tokens)
        result = verify_mod.verify(object_name, loaded.get('load_request_id'),
                                   prefix, log=log, tokens=tokens)
        summary = {'load': loaded, 'verify': result}

    log('=== SUMMARY ===')
    log(json.dumps({'object': object_name, 'prefix': prefix,
                    'pass': result.get('pass'),
                    'load': summary['load']}, indent=2, default=str))
    return summary


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('object_name')
    ap.add_argument('--prefix', default=None)
    a = ap.parse_args()
    out = run(a.object_name, a.prefix)
    sys.exit(0 if out['verify'].get('pass') else 1)
