"""Standalone FSM CSV-import runner for the PaymentTerms gold fixture (v2 seeded).

run_object.py only routes FBDI and HDL; PaymentTerms is an FSM "Setup Data Import
from CSV file" object (TaskCode AP_MANAGE_PAYMENT_TERMS), so it is driven here
directly, exactly like objects_seeded/Lookups/run_lookups_fsm.py.

This runner honors GOLD_OBJECTS_SUBDIR: it reads the artifact from
gold_regression/<GOLD_OBJECTS_SUBDIR>/PaymentTerms/artifact/, stamps ${PREFIX}
into the four CSV members (the manifest XML is copied verbatim), zips the five
root files, submits through the shared harness/load_fsm_csv.py driver (fin_impl),
polls to completion, then verifies read-only through the shared BIP relay using
the recipe's verify SQL.

Seeded (v2): the reference set is HARD-CODED to the seeded 'COMMON' set in
AP_TERM_SUBSCRIPTION.csv -- no discovery. The bad row names 'ZZ_NO_SUCH_SET'
(a set that does not exist) so the importer rejects that term deterministically.

  GOOD -> base: GldRegTerm <prefix> A/B in AP_TERMS_B/_TL with real TERM_IDs;
                one line each in AP_TERMS_LINES (100% / 30 or 45 days).
  BAD  -> absent: GldRegTerm <prefix> BAD rejected (SetId required, set has none)
                and absent from AP_TERMS_TL/_B.

Usage:
    GOLD_OBJECTS_SUBDIR=objects_seeded python objects_seeded/PaymentTerms/run_paymentterms_fsm.py
    GOLD_OBJECTS_SUBDIR=objects_seeded python objects_seeded/PaymentTerms/run_paymentterms_fsm.py --prefix 90333
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

OBJECT = 'PaymentTerms'
# The five members sit at the ROOT of the zip (flat-CSV object). The four CSVs
# are templated with ${PREFIX}; the manifest is copied verbatim.
CSV_MEMBERS = ['AP_TERM_HEADER.csv',
               'AP_TERM_LINE.csv',
               'AP_TERM_HEADER_TRANSLATION.csv',
               'AP_TERM_SUBSCRIPTION.csv']
XML_MEMBER = 'ASM_SETUP_CSV_METADATA.xml'


def fresh_prefix():
    return str(random.randint(10000, 99999))


def build_zip(prefix, log=print):
    art = os.path.join(object_dir(OBJECT), 'artifact')
    zip_path = os.path.join(object_dir(OBJECT), f'{OBJECT}_gold.zip')
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zf:
        for name in CSV_MEMBERS:
            with open(os.path.join(art, name), 'r', newline='') as f:
                body = f.read()
            body = body.replace('${PREFIX}', prefix)
            leftover = re.findall(r'\$\{[A-Z0-9_]+\}', body)
            if leftover:
                raise RuntimeError(f'{name}: un-substituted tokens {set(leftover)}')
            zf.writestr(name, body)
        with open(os.path.join(art, XML_MEMBER), 'r', newline='') as f:
            zf.writestr(XML_MEMBER, f.read())
    with open(zip_path, 'rb') as f:
        zb = f.read()
    log(f'built {zip_path} ({len(zb)} bytes, prefix {prefix})')
    return zip_path, zb


def _fill(sql, prefix):
    return sql.replace('${PREFIX}', str(prefix))


def verify(recipe, prefix, role='fin_impl', log=print):
    v = recipe['verify']
    # good: two terms reached base with real TERM_IDs
    g = v['base_read_good']
    good_rows = bip.bip_select(_fill(g['sql'], prefix), g['cols'], role=role)
    good_names = {(r.get(g['key_col']) or '') for r in good_rows}
    want_names = {f'GldRegTerm {prefix} A', f'GldRegTerm {prefix} B'}
    good_terms = want_names.issubset(good_names) and \
        all((r.get(g['id_col']) or '').strip() for r in good_rows
            if (r.get(g['key_col']) or '') in want_names)
    term_ids = {(r.get(g['key_col']) or ''): (r.get(g['id_col']) or '')
                for r in good_rows}
    # good: one line per term in AP_TERMS_LINES
    ln = v['base_read_lines']
    line_rows = bip.bip_select(_fill(ln['sql'], prefix), ln['cols'], role=role)
    good_lines = len(line_rows) >= 2
    # bad: absent from base
    b = v['bad_absent_read']
    bad_rows = bip.bip_select(_fill(b['sql'], prefix), b['cols'], role=role)
    bad_absent = (len(bad_rows) == 0)

    log(f'  good terms in base : {good_terms} ids={term_ids}')
    log(f'  good lines in base : {len(line_rows)} rows {line_rows}')
    log(f'  bad GldRegTerm {prefix} BAD : {len(bad_rows)} base rows (expect 0) '
        f'-> absent={bad_absent}')
    return {'good_terms': good_terms, 'good_lines': good_lines,
            'bad_absent': bad_absent,
            'pass': good_terms and good_lines and bad_absent,
            'term_ids': term_ids, 'good_rows': good_rows, 'line_rows': line_rows}


def run(prefix=None, log=print):
    subdir = os.environ.get('GOLD_OBJECTS_SUBDIR', 'objects')
    prefix = str(prefix or fresh_prefix())
    recipe = load_recipe(OBJECT)
    task = recipe['task_code']
    role = recipe.get('cred_role', 'fin_impl')
    log(f'=== PaymentTerms FSM CSV run | subdir {subdir} | prefix {prefix} '
        f'| task {task} ===')

    _, zb = build_zip(prefix, log=log)
    loaded = load_fsm_csv.run_import(task, zb, role=role, log=log)
    log(f'  import ok={loaded.get("ok")} ProcessId={loaded.get("process_id")} '
        f'completed={loaded.get("completed")}')
    plog = loaded.get('process_log') or ''
    m = re.search(r'ESSRequestId[^0-9]*([0-9]+)', plog) or \
        re.search(r'request[^0-9]*([0-9]{6,})', plog, re.I)
    ess = m.group(1) if m else None
    # capture the processed/failed row summary + any JBO rejection line for evidence
    summary_line = ''
    bad_error = ''
    for lstr in plog.splitlines():
        s = lstr.strip()
        if 'rows were processed' in s or 'rows of them failed' in s:
            summary_line = s
        if 'JBO-' in s or 'SetId' in s:
            bad_error = s

    result = verify(recipe, prefix, role=role, log=log)
    summary = {'object': OBJECT, 'subdir': subdir, 'prefix': prefix,
               'process_id': loaded.get('process_id'), 'ess_request_id': ess,
               'import_completed': loaded.get('completed'),
               'process_log_summary': summary_line, 'bad_error': bad_error,
               'term_ids': result['term_ids'], 'verify': result,
               'pass': result['pass']}
    log('=== SUMMARY ===')
    log(json.dumps({k: v for k, v in summary.items() if k != 'verify'},
                   indent=2, default=str))
    log(json.dumps({'pass': result['pass'], 'good_terms': result['good_terms'],
                    'good_lines': result['good_lines'],
                    'bad_absent': result['bad_absent']}, indent=2))
    return summary


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--prefix', default=None)
    a = ap.parse_args()
    out = run(a.prefix)
    sys.exit(0 if out['pass'] else 1)
