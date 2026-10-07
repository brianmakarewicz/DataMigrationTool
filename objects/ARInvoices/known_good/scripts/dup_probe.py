"""Re-submit ONE already-imported known-good line (same INTERFACE_LINE_ATTRIBUTE1/2 as prefix-97731
good row 1) to prove AutoInvoice rejects a non-run-unique Line Transactions Flexfield.
This is exactly what happens when DMT re-runs a scenario whose STG supplies an unprefixed
INTERFACE_LINE_ATTRIBUTE1."""
import csv, io, os, sys, zipfile, datetime
HERE = os.path.dirname(os.path.abspath(__file__))
KG = os.path.join(HERE, '..')  # objects/ARInvoices/known_good
sys.path.insert(0, os.path.join(HERE, '..', '..', '..', '..', 'gold_regression', 'harness'))
import conn, load_fbdi  # noqa: E402

rows = list(csv.reader(open(os.path.join(KG, 'RaInterfaceLinesAll_97731.csv'), newline='', encoding='utf-8')))
r = list(rows[0])
r[26] = 'DMT KG DUP flexfield re-run probe'
buf = io.StringIO()
csv.writer(buf, lineterminator='\r\n').writerow(r)
zn = os.path.join(KG,'ArAutoinvoiceImport_97731_dup.zip')
with zipfile.ZipFile(zn, 'w', zipfile.ZIP_DEFLATED) as z:
    z.writestr('RaInterfaceLinesAll.csv', buf.getvalue())
bu, bs = r[286], r[1]
plist = ','.join([bu, bs, datetime.date.today().strftime('%Y-%m-%d')] + ['#NULL'] * 19 + ['Y', '#NULL'])
recipe = {'doc_account': 'fin/receivables/import',
          'job_name': '/oracle/apps/ess/financials/receivables/transactions/autoInvoices,AutoInvoiceImportEss',
          'interface_details_id': 2, 'parameter_list': plist}
u, p = conn.fusion_creds('fin_impl')
lid, _ = load_fbdi.submit_load(recipe, zn, u, p, parameter_list=plist)
print('LOAD', lid, load_fbdi.poll(lid, u, p, interval=30))
