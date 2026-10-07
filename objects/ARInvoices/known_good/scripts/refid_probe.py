"""Probe: does a value in the line descriptive flexfield ATTRIBUTE1 (CSV col 204, where DMT
writes its 'DMT:run:wq:tfm' reference id) break or survive AutoInvoice? Submits ONE known-good
line (fresh flexfield keys, prefix 97732) with col 204 populated and no ATTRIBUTE_CATEGORY,
exactly as DMT's generator emits it."""
import csv, io, os, sys, zipfile, datetime
HERE = os.path.dirname(os.path.abspath(__file__))
KG = os.path.join(HERE, '..')
sys.path.insert(0, os.path.join(HERE, '..', '..', '..', '..', 'gold_regression', 'harness'))
import conn, load_fbdi  # noqa: E402

# Usage: python refid_probe.py <PREFIX> [--control]
#   (no flag) -> col 204 populated like DMT does   (run with prefix 97732)
#   --control -> identical row, col 204 left blank  (run with prefix 97733)
PFX = sys.argv[1] if len(sys.argv) > 1 else '97732'
CONTROL = '--control' in sys.argv
r = list(list(csv.reader(open(os.path.join(KG, 'RaInterfaceLinesAll.csv'), newline='', encoding='utf-8')))[0])
r[37] = PFX + r[37]
r[38] = PFX + r[38]
r[26] = 'DMT KG REFID ' + ('control (blank line DFF)' if CONTROL else 'probe (line DFF ATTRIBUTE1)')
if not CONTROL:
    r[203] = 'DMT:0:0:' + PFX
buf = io.StringIO()
csv.writer(buf, lineterminator='\r\n').writerow(r)
zn = os.path.join(KG, f'ArAutoinvoiceImport_{PFX}_' + ('control' if CONTROL else 'refid') + '.zip')
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
