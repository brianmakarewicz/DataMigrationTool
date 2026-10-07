"""Standalone (outside the DMT pipeline) replay of the owner's known-good Grants
award import (Fusion process 10070355), with a fresh numeric prefix on every
unique key plus one deliberately BAD award.

Usage:
    python kg_grants_standalone.py build  <prefix> [--subset all|one]
    python kg_grants_standalone.py submit <prefix> --role ppm_impl|fin_impl [--plist "#NULL,#NULL,true"]

build  : writes variant_<prefix>.zip next to this script from the original
         GmsAwardsImport.zip (all 9 CSVs, END column kept, original order).
submit : loadAndImportData (same call DMT makes) -> poll load -> find the
         chained AwardMassImportJob + ImportAwardReportJob -> poll -> download
         the report XML -> read base tables for the prefixed award numbers.
"""
import argparse, base64, csv, io, json, os, re, sys, time, zipfile
HERE = os.path.dirname(os.path.abspath(__file__))
WT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(WT, 'gold_regression', 'harness'))
sys.path.insert(0, os.path.join(WT, 'scripts'))
import conn  # noqa: E402
import load_fbdi  # noqa: E402
import requests  # noqa: E402

ORIG = os.path.join(HERE, 'GmsAwardsImport.zip')
RECIPE = {
    'doc_account': 'prj/grantsManagement/import',
    'job_name': '/oracle/apps/ess/projects/grantsManagement/award,AwardMassImportJob',
    'interface_details_id': 57,
}
BAD_SRC = 'AWDTST04B'           # bad award = copy of award 4 ...
BAD_NUM = 'AWDTST06X'
BAD_SPONSOR = 'No Such Sponsor DMT'  # ... with a sponsor that does not exist
ONE = {'AWDTST03B'}             # subset 'one' = a single 1-year award


def rows(z, name):
    return list(csv.reader(io.StringIO(z.read(name).decode('utf-8'))))


def build(prefix, subset):
    z = zipfile.ZipFile(ORIG)
    out_path = os.path.join(HERE, f'variant_{prefix}.zip')
    zo = zipfile.ZipFile(out_path, 'w', zipfile.ZIP_DEFLATED)
    for name in z.namelist():
        out = []
        is_hdr = name == 'GmsAwardHeadersInterface.csv'
        key_col = 1 if is_hdr else 0
        src = rows(z, name)
        for r in src:
            num = r[key_col]
            if subset == 'one' and num not in ONE:
                continue
            g = list(r)
            g[key_col] = f'{prefix}{num}'
            if is_hdr:
                g[0] = f'{prefix} {r[0]}'
            out.append(g)
        if subset == 'all':
            for r in src:
                if r[key_col] != BAD_SRC:
                    continue
                b = list(r)
                b[key_col] = f'{prefix}{BAD_NUM}'
                if is_hdr:
                    b[0] = f'{prefix} BAD Test AWD 6X'
                    b[6] = BAD_SPONSOR
                out.append(b)
        buf = io.StringIO()
        w = csv.writer(buf, lineterminator='\n', quoting=csv.QUOTE_MINIMAL)
        w.writerows(out)
        zo.writestr(name, buf.getvalue().encode('utf-8'))
        print(f'{name}: {len(out)} rows')
    zo.close()
    print('wrote', out_path)
    return out_path


def bip(sql, cols, cred='fin_impl'):
    import fusion_bip_query as f
    import contextlib
    s = io.StringIO()
    with contextlib.redirect_stdout(s):
        f.run(sql, cols, cred)
    txt = s.getvalue()
    res = []
    for g in re.findall(r'<G_1>(.*?)</G_1>', txt, re.S):
        res.append({c: (re.search(f'<{c}>(.*?)</{c}>', g, re.S) or [None, None])[1] for c in cols})
    return res


def download(ess_id, user, pwd, ftype):
    body = ('<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" '
            'xmlns:typ="http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/types/">'
            '<soapenv:Header/><soapenv:Body><typ:downloadESSJobExecutionDetails>'
            f'<typ:requestId>{ess_id}</typ:requestId><typ:fileType>{ftype}</typ:fileType>'
            '</typ:downloadESSJobExecutionDetails></soapenv:Body></soapenv:Envelope>')
    r = requests.post(conn.erp_soap_url(), data=body.encode(), auth=(user, pwd), timeout=300,
                      headers={'Content-Type': 'text/xml; charset=utf-8',
                               'SOAPAction': '"' + load_fbdi.NS_ACTION + 'downloadESSJobExecutionDetails"'})
    data = r.content
    files = {}
    i = data.find(b'PK\x03\x04')
    if i >= 0:
        try:
            zz = zipfile.ZipFile(io.BytesIO(data[i:]))
            for n in zz.namelist():
                files[n] = zz.read(n)
        except Exception:
            # trailing MIME boundary: trim to last end-of-central-directory
            j = data.rfind(b'PK\x05\x06')
            zz = zipfile.ZipFile(io.BytesIO(data[i:j + 22]))
            for n in zz.namelist():
                files[n] = zz.read(n)
    else:
        m = re.search(rb'<Content>(.*?)</Content>', data, re.S)
        if m:
            zz = zipfile.ZipFile(io.BytesIO(base64.b64decode(m.group(1))))
            for n in zz.namelist():
                files[n] = zz.read(n)
    return files


def submit(prefix, role, plist):
    zp = os.path.join(HERE, f'variant_{prefix}.zip')
    user, pwd = conn.fusion_creds(role)
    ev = {'prefix': prefix, 'role': role, 'user': user, 'parameter_list': plist}
    load_id, _ = load_fbdi.submit_load(RECIPE, zp, user, pwd, parameter_list=plist)
    ev['load_request_id'] = load_id
    ev['load_status'] = load_fbdi.poll(load_id, user, pwd, interval=20)
    # find the chained import + report requests
    imp = rep = None
    for _ in range(40):
        jobs = bip("SELECT requestid RID, parentrequestid PID, definition DEF, state ST, submitter SUB "
                   f"FROM fusion_ora_ess.request_history WHERE requestid > {load_id} AND requestid < {int(load_id)+400} "
                   "AND definition LIKE '%grantsManagement/award%' ORDER BY requestid",
                   ['RID', 'PID', 'DEF', 'ST', 'SUB'])
        for j in jobs:
            if j['DEF'].endswith('AwardMassImportJob') and j['SUB'].upper() == user.upper() and not imp:
                imp = j['RID']
        if imp:
            for j in jobs:
                if j['DEF'].endswith('ImportAwardReportJob') and int(j['RID']) > int(imp):
                    rep = j['RID']
                    break
        if imp and rep:
            break
        time.sleep(15)
    ev['import_request_id'] = imp
    ev['report_request_id'] = rep
    if imp:
        ev['import_status'] = load_fbdi.poll(imp, user, pwd, interval=20)
        props = bip(f"SELECT name NM, value VAL FROM fusion_ora_ess.request_property WHERE requestid={imp} "
                    "AND (name LIKE 'submit.argument_' OR name LIKE '%RECORDS%')", ['NM', 'VAL'])
        ev['import_props'] = {p['NM'].strip(): p['VAL'] for p in props}
    if rep:
        ev['report_status'] = load_fbdi.poll(rep, user, pwd, interval=20)
        for ftype in ('out', 'all'):
            files = download(rep, user, pwd, ftype)
            if files:
                break
        for n, b in files.items():
            p = os.path.join(HERE, f'report_{prefix}_{os.path.basename(n)}')
            open(p, 'wb').write(b)
        ev['report_files'] = list(files)
        xmls = [b.decode('utf-8', 'replace') for n, b in files.items() if n.lower().endswith('.xml')]
        recs = []
        for x in xmls:
            for g in re.findall(r'<G_4>(.*?)</G_4>', x, re.S):
                def t(tag):
                    m = re.search(f'<{tag}>(.*?)</{tag}>', g, re.S)
                    return m.group(1) if m else None
                recs.append({'award': t('PARENT_AWARD_NUMBER'), 'status': t('PROCESSED_STATUS'),
                             'code': t('MESSAGE_CODE'), 'message': t('PROCESSED_MESSAGE')})
            for tag in ('TOTAL_COUNT', 'SUCCESS_COUNT', 'FAILURE_COUNT', 'BATCH_STATUS'):
                m = re.search(f'<{tag}>(.*?)</{tag}>', x)
                if m:
                    ev[tag] = m.group(1)
        ev['report_rows'] = recs
    ev['base'] = bip("SELECT k.contract_number NUM, h.id ID, h.business_unit_id BU, h.created_by CB, "
                     "to_char(h.creation_date,'YYYY-MM-DD HH24:MI:SS') CD FROM gms_award_headers_b h, okc_k_headers_all_b k "
                     f"WHERE k.id=h.id AND k.version_type='C' AND k.contract_number LIKE '{prefix}%' ORDER BY 1",
                     ['NUM', 'ID', 'BU', 'CB', 'CD'])
    out = os.path.join(HERE, f'evidence_{prefix}.json')
    json.dump(ev, open(out, 'w'), indent=2)
    print(json.dumps(ev, indent=2))


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('cmd')
    ap.add_argument('prefix')
    ap.add_argument('--subset', default='all')
    ap.add_argument('--role', default='ppm_impl')
    ap.add_argument('--plist', default='#NULL,#NULL,true')
    a = ap.parse_args()
    if a.cmd == 'build':
        build(a.prefix, a.subset)
    else:
        submit(a.prefix, a.role, a.plist)
