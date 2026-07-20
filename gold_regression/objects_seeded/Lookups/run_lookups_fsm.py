"""Standalone FSM CSV-import runner for the Lookups gold fixture (v1 and v2).

run_object.py only routes FBDI and HDL; Lookups is an FSM "Setup Data Import from
CSV file" object, so it is driven here directly. This runner honors
GOLD_OBJECTS_SUBDIR exactly like the rest of the harness: it reads the artifact
from gold_regression/<GOLD_OBJECTS_SUBDIR>/Lookups/artifact/, stamps ${PREFIX}
into the two CSV members, zips the three root files, submits through the shared
harness/load_fsm_csv.py driver (fin_impl), polls to completion, then verifies
read-only through the shared BIP relay using the recipe's verify SQL.

  GOOD -> base: RT_GOLD_<prefix> in FND_LOOKUP_TYPES_VL; codes G1,G2 in
                FND_LOOKUP_VALUES_VL.
  BAD  -> absent: RT_NO_SUCH_TYPE_<prefix> code BAD1 skipped by the importer
                ('Parent row is missing') and absent from FND_LOOKUP_VALUES_VL.

Usage:
    GOLD_OBJECTS_SUBDIR=objects_seeded python objects_seeded/Lookups/run_lookups_fsm.py
    GOLD_OBJECTS_SUBDIR=objects_seeded python objects_seeded/Lookups/run_lookups_fsm.py --prefix 60416
"""
import os
import re
import sys
import json
import random
import zipfile
import argparse

HERE = os.path.dirname(os.path.abspath(__file__))
GOLD_ROOT = os.path.dirname(os.path.dirname(HERE))          # gold_regression/
HARNESS = os.path.join(GOLD_ROOT, 'harness')
sys.path.insert(0, HARNESS)

import bip                    # noqa: E402  read-only BIP relay
import load_fsm_csv           # noqa: E402  shared FSM CSV import driver
from recipe import load_recipe, object_dir  # noqa: E402  honors GOLD_OBJECTS_SUBDIR

OBJECT = 'Lookups'
# The three members sit at the ROOT of the zip (flat-CSV object, learned from a
# live export). The two CSVs are templated with ${PREFIX}; the manifest is not.
MEMBERS = ['FND_APP_STANDARD_LOOKUP.csv',
           'ORA_FND_APP_STANDARD_LOOKUP_CODE.csv',
           'ASM_SETUP_CSV_METADATA.xml']


def fresh_prefix():
    return str(random.randint(10000, 99999))


def build_zip(prefix, log=print):
    art = os.path.join(object_dir(OBJECT), 'artifact')
    zip_path = os.path.join(object_dir(OBJECT), f'{OBJECT}_gold.zip')
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zf:
        for name in MEMBERS:
            with open(os.path.join(art, name), 'r', newline='') as f:
                body = f.read()
            body = body.replace('${PREFIX}', prefix)
            leftover = re.findall(r'\$\{[A-Z0-9_]+\}', body)
            if leftover:
                raise RuntimeError(f'{name}: un-substituted tokens {set(leftover)}')
            zf.writestr(name, body)
    with open(zip_path, 'rb') as f:
        zb = f.read()
    log(f'built {zip_path} ({len(zb)} bytes, prefix {prefix})')
    return zip_path, zb


def _fill(sql, prefix):
    return sql.replace('${PREFIX}', str(prefix))


def verify(recipe, prefix, role='fin_impl', log=print):
    v = recipe['verify']
    # good: type reached base
    t = v['base_read_types']
    type_rows = bip.bip_select(_fill(t['sql'], prefix), t['cols'], role=role)
    good_type = any((r.get(t['key_col']) or '') == f'RT_GOLD_{prefix}'
                    for r in type_rows)
    # good: codes reached base
    c = v['base_read_values']
    code_rows = bip.bip_select(_fill(c['sql'], prefix), c['cols'], role=role)
    codes = {(r.get(c['key_col']) or '') for r in code_rows}
    good_codes = {'G1', 'G2'}.issubset(codes)
    # bad: absent from base
    b = v['bad_absent_read']
    bad_rows = bip.bip_select(_fill(b['sql'], prefix), b['cols'], role=role)
    bad_absent = (len(bad_rows) == 0)

    log(f'  type RT_GOLD_{prefix} in base : {good_type} ({type_rows})')
    log(f'  codes in base                : {sorted(codes)} -> G1,G2 present={good_codes}')
    log(f'  bad RT_NO_SUCH_TYPE_{prefix}  : {len(bad_rows)} base rows (expect 0) -> absent={bad_absent}')
    return {'good_type': good_type, 'good_codes': good_codes,
            'bad_absent': bad_absent,
            'pass': good_type and good_codes and bad_absent,
            'type_rows': type_rows, 'code_rows': code_rows}


def run(prefix=None, log=print):
    subdir = os.environ.get('GOLD_OBJECTS_SUBDIR', 'objects')
    prefix = str(prefix or fresh_prefix())
    recipe = load_recipe(OBJECT)
    task = recipe['task_code']
    role = recipe.get('cred_role', 'fin_impl')
    log(f'=== Lookups FSM CSV run | subdir {subdir} | prefix {prefix} | task {task} ===')

    _, zb = build_zip(prefix, log=log)
    loaded = load_fsm_csv.run_import(task, zb, role=role, log=log)
    log(f'  import ok={loaded.get("ok")} ProcessId={loaded.get("process_id")} '
        f'completed={loaded.get("completed")}')
    plog = loaded.get('process_log') or ''
    m = re.search(r'ESSRequestId[^0-9]*([0-9]+)', plog) or \
        re.search(r'request[^0-9]*([0-9]{6,})', plog, re.I)
    ess = m.group(1) if m else None
    # capture the deterministic bad-row rejection line for evidence
    badline = ''
    for ln in plog.splitlines():
        if 'Parent row is missing' in ln or 'will be skipped' in ln.lower():
            badline = ln.strip()
            break

    result = verify(recipe, prefix, role=role, log=log)
    summary = {'object': OBJECT, 'subdir': subdir, 'prefix': prefix,
               'process_id': loaded.get('process_id'), 'ess_request_id': ess,
               'import_completed': loaded.get('completed'),
               'bad_reject_line': badline, 'verify': result,
               'pass': result['pass']}
    log('=== SUMMARY ===')
    log(json.dumps({k: v for k, v in summary.items()
                    if k not in ('verify',)}, indent=2, default=str))
    log(json.dumps({'pass': result['pass'], 'good_type': result['good_type'],
                    'good_codes': result['good_codes'],
                    'bad_absent': result['bad_absent']}, indent=2))
    return summary


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--prefix', default=None)
    a = ap.parse_args()
    out = run(a.prefix)
    sys.exit(0 if out['pass'] else 1)
