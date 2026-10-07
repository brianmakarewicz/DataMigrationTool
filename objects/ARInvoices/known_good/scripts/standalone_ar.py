"""Standalone (outside DMT) AR AutoInvoice submission of the owner's known-good file.

Takes the known-good RaInterfaceLinesAll.csv (Fusion process 10071776), stamps a new
numeric prefix onto the Line Transactions Flexfield keys (INTERFACE_LINE_ATTRIBUTE1/2,
CSV cols 38/39), appends one deliberately BAD row (nonexistent bill-to account) and one
PROBE row (TRX_NUMBER supplied, as DMT does), re-zips, and submits with the SAME
loadAndImportData job + ParameterList shape as the known-good run.

Usage: python standalone_ar.py <PREFIX> [--build-only]
"""
import csv, io, os, sys, time, zipfile, datetime, json

HERE = os.path.dirname(os.path.abspath(__file__))
KG = os.path.join(HERE, '..')  # objects/ARInvoices/known_good (inputs + outputs)
sys.path.insert(0, os.path.join(HERE, '..', '..', '..', '..', 'gold_regression', 'harness'))
import conn  # noqa: E402
import load_fbdi  # noqa: E402

SRC_CSV = os.path.join(KG, 'RaInterfaceLinesAll.csv')
C_TRXNUM, C_BILLACCT, C_BILLSITE, C_DESC, C_A1, C_A2, C_BU = 7, 19, 20, 27, 38, 39, 287  # 1-indexed


def build(prefix):
    rows = list(csv.reader(open(SRC_CSV, newline='', encoding='utf-8')))
    out = []
    for r in rows:
        r = list(r)
        r[C_A1 - 1] = prefix + r[C_A1 - 1]
        r[C_A2 - 1] = prefix + r[C_A2 - 1]
        out.append(r)
    # BAD: clone good row 1, nonexistent bill-to customer account -> per-row AutoInvoice reject
    bad = list(out[0])
    bad[C_BILLACCT - 1] = '999999999'
    bad[C_DESC - 1] = 'DMT KG BAD nonexistent bill-to'
    bad[C_A1 - 1] = prefix + '86753096'
    bad[C_A2 - 1] = prefix + '867530917'
    out.append(bad)
    # PROBE: clone good row 2, but supply a TRX_NUMBER (DMT always does; source auto-numbers)
    probe = list(out[1])
    probe[C_TRXNUM - 1] = prefix + 'KGPROBE1'
    probe[C_DESC - 1] = 'DMT KG PROBE trx number supplied'
    probe[C_A1 - 1] = prefix + '86753097'
    probe[C_A2 - 1] = prefix + '867530918'
    out.append(probe)
    buf = io.StringIO()
    w = csv.writer(buf, lineterminator='\r\n', quoting=csv.QUOTE_MINIMAL)
    for r in out:
        w.writerow(r)
    csv_name = os.path.join(KG, f'RaInterfaceLinesAll_{prefix}.csv')
    open(csv_name, 'w', newline='', encoding='utf-8').write(buf.getvalue())
    zip_name = os.path.join(KG, f'ArAutoinvoiceImport_{prefix}.zip')
    with zipfile.ZipFile(zip_name, 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr('RaInterfaceLinesAll.csv', buf.getvalue())
    return zip_name, out


def main():
    prefix = sys.argv[1]
    zip_name, rows = build(prefix)
    bu = rows[0][C_BU - 1]
    bsrc = rows[0][1]
    print('built', zip_name, len(rows), 'rows; BU=', bu, 'source=', bsrc)
    if '--build-only' in sys.argv:
        return
    # ParameterList mirrors known-good 10071776: arg1 BU, arg2 source, arg3 default date,
    # args 4-22 empty, arg23 Y (Base Due Date on Trx Date), arg24 empty.
    # BU and batch source come FROM THE FILE, not hardcoded.
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
    json.dump({'prefix': prefix, 'load_request_id': load_id, 'load_status': st, 'parameter_list': plist},
              open(os.path.join(KG, f'run_{prefix}.json'), 'w'), indent=2)


if __name__ == '__main__':
    main()
