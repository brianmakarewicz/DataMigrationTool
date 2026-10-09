#!/usr/bin/env python3
"""
check_line_break_validation.py -- conformance checker for the line-break rule
(backlog #651; DMT_DESIGN.html section 5, [POST_VALIDATION] tag, and section 7,
"Values with line breaks never reach an FBDI CSV").

The rule: a value holding a carriage return or line feed splits its FBDI CSV
record and SQL*Loader rejects or misaligns the row. Every ERP FBDI object
therefore fails such a row in its validator, after the transform and before
its generator writes the CSV, with a [POST_VALIDATION] message naming the
field. The value is never silently stripped.

WHAT THIS CHECKS (per the "Checker fidelity" standard -- everything the rule
states is asserted, or explicitly declared NOT CHECKED):

  1. DMT_UTIL_PKG declares and defines the one shared check
     LINE_BREAK_ERROR (p_row_json IN CLOB) RETURN VARCHAR2. Its body parses the
     row with JSON_OBJECT_T (structured parsing, no string arithmetic over the
     JSON), skips ERROR_TEXT, tests both CHR(13) and CHR(10), and writes the
     [POST_VALIDATION] tag.
  2. Every FBDI generator package (db/packages/*_fbdi_gen_pkg.pkb.sql) is mapped
     below to its object's validator procedure and loader recipe, or is listed
     as EXEMPT with a reason. An unmapped generator fails -- a new FBDI object
     cannot ship without the check.
  3. Each mapped validator package declares the procedure in its spec and
     defines it in its body.
  4. The procedure holds exactly one MERGE block per TFM table that its
     generator(s) read (the *_TFM_TBL names in the generator source) -- no table
     missing, no extra table -- and every block is byte-identical to the
     template except the table name (the EDIT-TABLE region names it twice:
     MERGE INTO and FROM; both must be the same table).
  5. The procedure contains no COMMIT (the caller owns the transaction).
  6. The object's loader recipe (RUN_<object> in DMT_LOADER_PKG) calls the
     procedure with p_run_id => p_run_id AFTER its last *_TRANSFORM_PKG call and
     BEFORE its first GENERATE_FBDI call.

NOT CHECKED (declared, so a green run stays honest):
  * Runtime behaviour -- that a real value with a line break is failed with the
    message. Proven by test/unit/test_line_break_validation.py (SELECT-only
    checks of LINE_BREAK_ERROR) and by a pipeline run of the regression row
    RT-SUP-BADLB (see the PR that introduced this checker).
  * HCM (HDL) and configuration (FBL / setup CSV) objects -- out of scope by
    owner decision 2026-10-09 (HDL is not FBDI; configuration objects deferred).
  * Generator-derived values (columns a generator computes while writing the
    CSV rather than reading from the TFM row) -- none carry free text today.

Exit 0 = conforms, 1 = violation(s). Reads committed files only.
"""
import os
import re
import sys

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
PKG = os.path.join(REPO, 'db', 'packages')

# generator stem -> (validator stem, procedure, loader recipe)
MAP = {
    'poz_sup':           ('poz_sup', 'VALIDATE_SUPPLIERS_LINE_BREAKS', 'RUN_SUPPLIERS'),
    'poz_sup_addr':      ('poz_sup', 'VALIDATE_ADDRESSES_LINE_BREAKS', 'RUN_SUPPLIER_ADDRESSES'),
    'poz_sup_site':      ('poz_sup', 'VALIDATE_SITES_LINE_BREAKS', 'RUN_SUPPLIER_SITES'),
    'poz_sup_site_assn': ('poz_sup', 'VALIDATE_SITE_ASSIGNMENTS_LINE_BREAKS',
                          'RUN_SUPPLIER_SITE_ASSIGNMENTS'),
    'poz_sup_cont':      ('poz_sup', 'VALIDATE_CONTACTS_LINE_BREAKS', 'RUN_SUPPLIER_CONTACTS'),
    'po':                ('po', 'VALIDATE_LINE_BREAKS', 'RUN_PURCHASE_ORDERS'),
    'blanket_po':        ('po', 'VALIDATE_LINE_BREAKS', 'RUN_BLANKET_POS'),
    'contract':          ('po', 'VALIDATE_LINE_BREAKS', 'RUN_CONTRACTS'),
    'ap':                ('ap', 'VALIDATE_LINE_BREAKS', 'RUN_AP_INVOICES'),
    'ar':                ('ar', 'VALIDATE_LINE_BREAKS', 'RUN_AR_INVOICES'),
    'req':               ('req', 'VALIDATE_LINE_BREAKS', 'RUN_REQUISITIONS'),
    'misc_receipt':      ('misc_receipt', 'VALIDATE_LINE_BREAKS', 'RUN_MISC_RECEIPTS'),
    'cust':              ('cust', 'VALIDATE_LINE_BREAKS', 'RUN_CUSTOMERS'),
    'gl':                ('gl', 'VALIDATE_LINE_BREAKS', 'RUN_GL_BALANCES'),
    'gl_budget':         ('gl_budget', 'VALIDATE_LINE_BREAKS', 'RUN_GL_BUDGETS'),
    'fa_asset':          ('fa_asset', 'VALIDATE_LINE_BREAKS', 'RUN_ASSETS'),
    'project':           ('project', 'VALIDATE_LINE_BREAKS', 'RUN_PROJECTS'),
    'expenditure':       ('expenditure', 'VALIDATE_LINE_BREAKS', 'RUN_EXPENDITURES'),
    'prj_budget':        ('prj_budget', 'VALIDATE_LINE_BREAKS', 'RUN_PROJECT_BUDGETS'),
    'billing_event':     ('billing_event', 'VALIDATE_LINE_BREAKS', 'RUN_BILLING_EVENTS'),
    'grants':            ('grants', 'VALIDATE_LINE_BREAKS', 'RUN_GRANTS'),
    'egp_item':          ('egp_item', 'VALIDATE_LINE_BREAKS', 'RUN_ITEMS'),
}
EXEMPT = {
    'plan_budget': 'PlanningBudgets is out of scope (no catalog row; design section 1).',
    'egp_item_cat': 'Item categories ride in the Items zip; DMT_EGP_ITEM_FBDI_GEN_PKG reads '
                    'DMT_EGP_ITEM_CAT_TFM_TBL and the Items check covers it. This standalone '
                    'ItemCategories generator is the stray registry row listed for retirement.',
}

# The fixed template of one block; {tbl} is the only editable region.
BLOCK = """        MERGE INTO {tbl} t
        USING (SELECT q.rid, q.msg
               FROM   (SELECT s.ROWID AS rid,
                              DMT_UTIL_PKG.LINE_BREAK_ERROR(
                                  p_row_json => JSON_OBJECT(s.* RETURNING CLOB)) AS msg
                       FROM   {tbl} s
        -- <<END EDIT-TABLE -- everything below is FIXED>>
                       WHERE  s.RUN_ID     = p_run_id
                       AND    s.TFM_STATUS = 'STAGED') q
               WHERE  q.msg IS NOT NULL) lb
        ON (t.ROWID = lb.rid)
        WHEN MATCHED THEN UPDATE
        SET    t.TFM_STATUS        = 'FAILED',
               t.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(p_existing  => t.ERROR_TEXT,
                                                               p_new_error => lb.msg),
               t.LAST_UPDATED_DATE = SYSDATE
        WHERE  t.TFM_STATUS = 'STAGED';
        l_failed := l_failed + SQL%ROWCOUNT;"""

errors = []


def read(name):
    with open(os.path.join(PKG, name), encoding='utf-8') as f:
        return f.read().replace('\r\n', '\n')


def strip_comment_lines(text):
    return '\n'.join(l for l in text.split('\n') if not l.strip().startswith('--'))


def proc_body(text, proc):
    m = re.search(r'(?im)^\s*PROCEDURE\s+' + proc + r'\s*\(.*?^\s*END\s+' + proc + r'\s*;',
                  text, re.S)
    return m.group(0) if m else None


def tfm_tables(text):
    return set(t.upper() for t in re.findall(r'(?i)\bDMT_\w+_TFM_TBL\b', strip_comment_lines(text)))


def check_util():
    spec, body = read('dmt_util_pkg.pks.sql'), read('dmt_util_pkg.pkb.sql')
    if not re.search(r'(?is)FUNCTION\s+LINE_BREAK_ERROR\s*\(\s*p_row_json\s+IN\s+CLOB\s*\)\s*'
                     r'RETURN\s+VARCHAR2\s*;', spec):
        errors.append('DMT_UTIL_PKG spec: LINE_BREAK_ERROR (p_row_json IN CLOB) RETURN VARCHAR2 '
                      'is not declared.')
    m = re.search(r'(?is)FUNCTION\s+LINE_BREAK_ERROR\s*\(.*?END\s+LINE_BREAK_ERROR\s*;', body)
    if not m:
        errors.append('DMT_UTIL_PKG body: LINE_BREAK_ERROR is not defined.')
        return
    f = m.group(0)
    for needle, why in (('JSON_OBJECT_T.PARSE', 'parse the row with JSON_OBJECT_T'),
                        ("'ERROR_TEXT'", 'skip ERROR_TEXT'),
                        ('CHR(13)', 'test carriage return CHR(13)'),
                        ('CHR(10)', 'test line feed CHR(10)'),
                        ('[POST_VALIDATION]', 'tag the message [POST_VALIDATION]')):
        if needle not in f:
            errors.append(f'DMT_UTIL_PKG.LINE_BREAK_ERROR must {why} ({needle} not found).')
    if re.search(r'(?i)\b(INSTR|SUBSTR|REGEXP_\w+)\s*\(\s*p_row_json', f):
        errors.append('DMT_UTIL_PKG.LINE_BREAK_ERROR applies string functions to the JSON '
                      'payload; parse it with JSON_OBJECT_T instead.')


def check_objects():
    gens = sorted(f[len('dmt_'):-len('_fbdi_gen_pkg.pkb.sql')]
                  for f in os.listdir(PKG) if f.endswith('_fbdi_gen_pkg.pkb.sql'))
    for g in gens:
        if g not in MAP and g not in EXEMPT:
            errors.append(f'FBDI generator dmt_{g}_fbdi_gen_pkg is not mapped to a line-break '
                          f'check (add it to MAP, or to EXEMPT with a reason).')
    for g in MAP:
        if g not in gens:
            errors.append(f'MAP names generator dmt_{g}_fbdi_gen_pkg, which does not exist.')

    # procedure -> union of generator tables
    need = {}
    for g, (v, proc, _) in MAP.items():
        if g in gens:
            need.setdefault((v, proc), set()).update(tfm_tables(read(f'dmt_{g}_fbdi_gen_pkg.pkb.sql')))

    for (v, proc), tables in sorted(need.items()):
        vname = f'DMT_{v.upper()}_VALIDATOR_PKG'
        spec, body = read(f'dmt_{v}_validator_pkg.pks.sql'), read(f'dmt_{v}_validator_pkg.pkb.sql')
        if not re.search(r'(?im)^\s*PROCEDURE\s+' + proc + r'\s*\(\s*p_run_id\s+IN\s+NUMBER\s*\)\s*;',
                         spec):
            errors.append(f'{vname} spec: PROCEDURE {proc} (p_run_id IN NUMBER) not declared.')
        pb = proc_body(body, proc)
        if not pb:
            errors.append(f'{vname} body: PROCEDURE {proc} not defined.')
            continue
        if re.search(r'(?im)^\s*COMMIT\s*;', strip_comment_lines(pb)):
            errors.append(f'{vname}.{proc} commits; the caller owns the transaction.')
        found = re.findall(r'(?m)^        MERGE INTO (DMT_\w+_TFM_TBL) t$', pb)
        if len(found) != len(set(found)):
            errors.append(f'{vname}.{proc}: a TFM table is checked more than once.')
        got = set(found)
        for t in sorted(tables - got):
            errors.append(f'{vname}.{proc}: no line-break block for {t} (its generator reads it).')
        for t in sorted(got - tables):
            errors.append(f'{vname}.{proc}: block for {t}, which no mapped generator reads.')
        for t in found:
            if BLOCK.format(tbl=t) not in pb:
                errors.append(f'{vname}.{proc}: the block for {t} differs from the fixed template '
                              f'(only the table name may vary).')


def check_loader():
    loader = read('dmt_loader_pkg.pkb.sql')
    for g, (v, proc, run) in sorted(MAP.items()):
        rb = proc_body(loader, run)
        if not rb:
            errors.append(f'DMT_LOADER_PKG.{run} not found (mapped for generator {g}).')
            continue
        rb = strip_comment_lines(rb)
        call = f'DMT_{v.upper()}_VALIDATOR_PKG.{proc}(p_run_id => p_run_id);'
        pos = rb.find(call)
        if pos < 0:
            errors.append(f'DMT_LOADER_PKG.{run} does not call {call}')
            continue
        last_tfm = max((m.start() for m in re.finditer(r'_TRANSFORM_PKG\.\w+\s*\(', rb)), default=-1)
        first_gen = min((m.start() for m in re.finditer(r'\bGENERATE_FBDI\s*\(', rb)), default=-1)
        if last_tfm < 0 or pos < last_tfm:
            errors.append(f'DMT_LOADER_PKG.{run}: {proc} must run after the last transform call.')
        if first_gen < 0 or pos > first_gen:
            errors.append(f'DMT_LOADER_PKG.{run}: {proc} must run before GENERATE_FBDI.')


def main():
    check_util()
    check_objects()
    check_loader()
    for g, why in sorted(EXEMPT.items()):
        print(f'EXEMPT: dmt_{g}_fbdi_gen_pkg -- {why}')
    print('NOT CHECKED: runtime behaviour (test/unit/test_line_break_validation.py and the '
          'RT-SUP-BADLB regression row prove it).')
    print('NOT CHECKED: HDL and configuration objects -- out of scope (owner decision 2026-10-09).')
    print('NOT CHECKED: values a generator computes while writing the CSV (none carry free text).')
    if errors:
        for e in errors:
            print('FAIL: ' + e)
        print(f'{len(errors)} line-break rule violation(s).')
        return 1
    print(f'OK: line-break check present and wired for {len(MAP)} FBDI generators.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
