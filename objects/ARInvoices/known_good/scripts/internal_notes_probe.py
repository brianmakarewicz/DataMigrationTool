"""Standalone (outside DMT) probe: does INTERNAL_NOTES split AutoInvoice grouping?

INTERNAL_NOTES is one of Oracle's mandatory AutoInvoice grouping attributes. In the
FBDI lines CSV (after the template's GenCSV column move) it is position 289, labelled
"Notes from Source" in AutoInvoiceImportTemplate1.xlsm (288 = Comments, 287 = BU name).

Load 1 (all rows: same BU, source, type, terms, currency, bill-to 122133/1430587,
trx/gl date 2026/03/19 -- identical grouping attributes except INTERNAL_NOTES):
  A  good line, INTERNAL_NOTES 'DMT <p>A'
  B  good line, INTERNAL_NOTES 'DMT <p>B'           -> expect a SECOND invoice
  C  bad line (nonexistent memo line), 'DMT <p>C'    -> rejected, left in interface
Load 2 (after load 1's import; C is still in the interface):
  D  good line, same grouping attributes, INTERNAL_NOTES 'DMT <p2>D'
                                                     -> expect LOADED (not held by C)

Usage: python internal_notes_probe.py <PREFIX> load1|load2
Builds from the owner's known-good RaInterfaceLinesAll.csv row 1.
"""
import csv, io, os, sys, zipfile, datetime, json

HERE = os.path.dirname(os.path.abspath(__file__))
KG = os.path.join(HERE, '..')
sys.path.insert(0, r'C:\Users\Monroe\workspace\DMT2\gold_regression\harness')
import conn  # noqa: E402
import load_fbdi  # noqa: E402

SRC_CSV = os.path.join(KG, 'RaInterfaceLinesAll.csv')
# 1-indexed CSV positions
C_TRXDATE, C_GLDATE, C_DESC, C_AMT, C_PRICE, C_A1, C_A2, C_MEMO, C_BU, C_NOTES = \
    5, 6, 27, 32, 35, 38, 39, 111, 287, 289


def row(base, prefix, tag, amount, memo=None, desc=None):
    r = list(base)
    r[C_TRXDATE - 1] = '2026/03/19'
    r[C_GLDATE - 1] = '2026/03/19'
    r[C_A1 - 1] = prefix + tag
    r[C_A2 - 1] = '1'
    r[C_AMT - 1] = r[C_PRICE - 1] = f'{amount:.2f}'
    r[C_NOTES - 1] = f'DMT {prefix}{tag}'
    r[C_DESC - 1] = desc or f'DMT INTERNAL_NOTES probe {prefix}{tag}'
    if memo:
        r[C_MEMO - 1] = memo
    return r


def build(prefix, which):
    base = list(csv.reader(open(SRC_CSV, newline='', encoding='utf-8')))[0]
    if which == 'load1':
        rows = [row(base, prefix, 'A', 101), row(base, prefix, 'B', 102),
                row(base, prefix, 'C', 103, memo='DMT PROBE INVALID MEMO LINE',
                    desc='DMT INTERNAL_NOTES probe BAD memo line')]
    else:
        rows = [row(base, prefix, 'D', 104)]
    buf = io.StringIO()
    w = csv.writer(buf, lineterminator='\r\n', quoting=csv.QUOTE_MINIMAL)
    for r in rows:
        w.writerow(r)
    zip_name = os.path.join(KG, f'ArAutoinvoiceImport_{prefix}_notes_{which}.zip')
    with zipfile.ZipFile(zip_name, 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr('RaInterfaceLinesAll.csv', buf.getvalue())
    return zip_name, rows


def main():
    prefix, which = sys.argv[1], sys.argv[2]
    zip_name, rows = build(prefix, which)
    bu, bsrc = rows[0][C_BU - 1], rows[0][1]
    plist = ','.join([bu, bsrc, datetime.date.today().strftime('%Y-%m-%d')] + ['#NULL'] * 19 + ['Y', '#NULL'])
    recipe = {
        'doc_account': 'fin/receivables/import',
        'job_name': '/oracle/apps/ess/financials/receivables/transactions/autoInvoices,AutoInvoiceImportEss',
        'interface_details_id': 2,
        'parameter_list': plist,
    }
    user, pwd = conn.fusion_creds('fin_impl')
    load_id, _ = load_fbdi.submit_load(recipe, zip_name, user, pwd, parameter_list=plist)
    st = load_fbdi.poll(load_id, user, pwd, interval=30)
    print('LOAD', load_id, st)
    json.dump({'prefix': prefix, 'which': which, 'load_request_id': load_id, 'load_status': st,
               'parameter_list': plist},
              open(os.path.join(KG, f'run_{prefix}_notes_{which}.json'), 'w'), indent=2)


if __name__ == '__main__':
    main()
