"""Standalone FSM CSV-import runner for the UnitsOfMeasure gold fixture (v2 seeded).

run_object.py only routes FBDI and HDL; UnitsOfMeasure is an FSM "Setup Data
Import from CSV file" object, so it is driven here directly -- the same shape as
objects_seeded/Lookups/run_lookups_fsm.py. It honors GOLD_OBJECTS_SUBDIR exactly
like the rest of the harness: it reads the artifact from
gold_regression/<GOLD_OBJECTS_SUBDIR>/UnitsOfMeasure/artifact/, stamps ${PREFIX}
and the derived 3-char codes into the two CSV members, zips the three root files,
submits through the shared harness/load_fsm_csv.py driver (scm_impl), polls to
completion, then verifies read-only through the shared BIP relay.

v2 seeded: NO discovery. The UOM class is the hard-coded seeded literal '5'
(Quantity) already in the CSV template. UOM_CODE is 3-char capped so the codes are
derived deterministically from the prefix (a 2-char base36 stem + suffix A/B/C);
the ${PREFIX} rides in the UOM name and verification is by name -- so new UOMs are
naturally re-runnable via distinct codes/names on each prefix.

  GOOD -> base: two UOMs named 'GldRegUOM <prefix> A/B' in class 5 reach
                INV_UNITS_OF_MEASURE_B/_TL.
  BAD  -> absent: 'GldRegUOM <prefix> BAD' (UomClassCode ZZ_NO_SUCH_CLASS) rejected
                by the importer ('UomClass does not exist; skipping record') and
                absent from INV_UNITS_OF_MEASURE_B.

Usage:
    GOLD_OBJECTS_SUBDIR=objects_seeded python objects_seeded/UnitsOfMeasure/run_uom_fsm.py
    GOLD_OBJECTS_SUBDIR=objects_seeded python objects_seeded/UnitsOfMeasure/run_uom_fsm.py --prefix 91173
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

OBJECT = 'UnitsOfMeasure'
# Three members at the ROOT of the zip (flat-CSV FSM object). The two CSVs are
# templated; the manifest is copied verbatim.
MEMBERS = ['ASM_SETUP_CSV_METADATA.xml',
           'INV_UNIT_OF_MEASURE.csv',
           'INV_UNIT_OF_MEASURE_TRANSLATION.csv']

_B36 = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'


def fresh_prefix():
    return str(random.randint(10000, 99999))


def _stem(prefix):
    """A 2-char base36 stem derived from the prefix (int(prefix) % 1296)."""
    n = int(prefix) % 1296
    return _B36[n // 36] + _B36[n % 36]


def codes_for(prefix):
    """Three distinct 3-char UOM codes: <stem>A (good1), <stem>B (good2),
    <stem>C (bad). Deterministic from the prefix -- no discovery query."""
    s = _stem(prefix)
    return {'C1': s + 'A', 'C2': s + 'B', 'C3': s + 'C'}


def build_zip(prefix, log=print):
    art = os.path.join(object_dir(OBJECT), 'artifact')
    zip_path = os.path.join(object_dir(OBJECT), f'{OBJECT}_gold.zip')
    codes = codes_for(prefix)
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zf:
        for name in MEMBERS:
            with open(os.path.join(art, name), 'r', newline='') as f:
                body = f.read()
            body = body.replace('${PREFIX}', prefix)
            for k, v in codes.items():
                body = body.replace('${' + k + '}', v)
            leftover = re.findall(r'\$\{[A-Z0-9_]+\}', body)
            if leftover:
                raise RuntimeError(f'{name}: un-substituted tokens {set(leftover)}')
            zf.writestr(name, body)
    with open(zip_path, 'rb') as f:
        zb = f.read()
    log(f'built {zip_path} ({len(zb)} bytes, prefix {prefix}, '
        f'codes {codes["C1"]}/{codes["C2"]}/{codes["C3"]})')
    return zip_path, zb, codes


def _fill(sql, prefix, bad_code=None):
    sql = sql.replace('${PREFIX}', str(prefix))
    if bad_code is not None:
        sql = sql.replace('${BAD_CODE}', bad_code)
    return sql


def verify(recipe, prefix, codes, role='scm_impl', log=print):
    v = recipe['verify']
    g = v['base_read_good']
    good_rows = bip.bip_select(_fill(g['sql'], prefix), g['cols'], role=role)
    good_ok = len(good_rows) == 2 and all(
        (r.get('UOM_ID') or '').strip() and (r.get('UOM_CLASS') or '') == '5'
        for r in good_rows)

    b = v['bad_absent_read']
    bad_rows = bip.bip_select(_fill(b['sql'], prefix, codes['C3']),
                              b['cols'], role=role)
    bad_absent = len(bad_rows) == 0

    log(f'  good UOMs in base : {len(good_rows)} rows -> ok={good_ok}')
    for r in good_rows:
        log(f'    {r.get("UOM_CODE")} id={r.get("UOM_ID")} '
            f'class={r.get("UOM_CLASS")} name={r.get("NM")!r}')
    log(f'  bad UOM {codes["C3"]} in base : {len(bad_rows)} rows (expect 0) '
        f'-> absent={bad_absent}')
    return {'good_ok': good_ok, 'bad_absent': bad_absent,
            'pass': good_ok and bad_absent,
            'good_rows': good_rows, 'bad_rows': bad_rows}


def run(prefix=None, log=print):
    subdir = os.environ.get('GOLD_OBJECTS_SUBDIR', 'objects')
    prefix = str(prefix or fresh_prefix())
    recipe = load_recipe(OBJECT)
    task = recipe['task_code']
    role = recipe.get('cred_role', 'scm_impl')
    log(f'=== UnitsOfMeasure FSM CSV run | subdir {subdir} | prefix {prefix} '
        f'| task {task} ===')

    _, zb, codes = build_zip(prefix, log=log)
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
        if 'UomClass does not exist' in ln or 'skipping record' in ln.lower():
            badline = ln.strip()
            break

    result = verify(recipe, prefix, codes, role=role, log=log)
    summary = {'object': OBJECT, 'subdir': subdir, 'prefix': prefix,
               'class_code': recipe['seeded_reference']['UOM_CLASS_CODE'],
               'good_codes': [codes['C1'], codes['C2']], 'bad_code': codes['C3'],
               'process_id': loaded.get('process_id'), 'ess_request_id': ess,
               'import_completed': loaded.get('completed'),
               'bad_reject_line': badline, 'pass': result['pass']}
    log('=== SUMMARY ===')
    log(json.dumps(summary, indent=2, default=str))
    log(json.dumps({'pass': result['pass'], 'good_ok': result['good_ok'],
                    'bad_absent': result['bad_absent']}, indent=2))
    return {**summary, 'verify': result}


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--prefix', default=None)
    a = ap.parse_args()
    out = run(a.prefix)
    sys.exit(0 if out['pass'] else 1)
