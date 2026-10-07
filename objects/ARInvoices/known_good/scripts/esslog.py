import sys, io, zipfile, os, requests
sys.path.insert(0, r'C:\Users\Monroe\workspace')
from conn_helper import get_fusion_url, get_fusion_user
NS = 'http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/types/'
HERE = os.path.dirname(os.path.abspath(__file__))


def get(rid, ftype='LOG', cred='fin_impl'):
    u, p = get_fusion_user(cred)
    body = (f'<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:typ="{NS}">'
            f'<soapenv:Header/><soapenv:Body><typ:downloadESSJobExecutionDetails><typ:requestId>{rid}</typ:requestId>'
            f'<typ:fileType>{ftype}</typ:fileType></typ:downloadESSJobExecutionDetails></soapenv:Body></soapenv:Envelope>')
    r = requests.post(get_fusion_url().rstrip('/') + '/fscmService/ErpIntegrationService', data=body.encode(),
                      headers={'Content-Type': 'text/xml; charset=utf-8',
                               'SOAPAction': NS + 'downloadESSJobExecutionDetails'},
                      auth=(u, p), timeout=300)
    b = r.content
    i = b.find(b'PK\x03\x04')
    if i < 0:
        return 'NOZIP status=%s %s' % (r.status_code, b[:1500])
    out = []
    z = zipfile.ZipFile(io.BytesIO(b[i:]))
    for n in z.namelist():
        out.append('=== ' + n + '\n' + z.read(n).decode('utf-8', 'replace'))
    return '\n'.join(out)


if __name__ == '__main__':
    ft = sys.argv[2] if len(sys.argv) > 2 else 'LOG'
    for rid in sys.argv[1].split(','):
        t = get(rid, ft)
        fn = os.path.join(HERE, f'log_{rid}_{ft}.txt')
        open(fn, 'w', encoding='utf-8').write(t)
        print(rid, len(t), fn)
