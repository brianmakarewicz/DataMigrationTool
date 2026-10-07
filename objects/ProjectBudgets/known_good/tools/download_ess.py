"""Download an ESS request's output/log (downloadESSJobExecutionDetails) and unzip it.
Usage: python download_ess.py <request_id> [out|log|all]"""
import sys, os, re, base64, io, zipfile
import requests
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from submit_standalone import ERP, NS, ACT, USER, PW, HERE

rid = sys.argv[1]
ft = sys.argv[2] if len(sys.argv) > 2 else 'all'
body = (f'<soapenv:Envelope {NS}><soapenv:Header/><soapenv:Body>'
        f'<typ:downloadESSJobExecutionDetails><typ:requestId>{rid}</typ:requestId><typ:fileType>{ft}</typ:fileType>'
        '</typ:downloadESSJobExecutionDetails></soapenv:Body></soapenv:Envelope>')
r = requests.post(ERP, data=body, auth=(USER, PW), timeout=300,
                  headers={'Content-Type': 'text/xml; charset=utf-8', 'SOAPAction': ACT + 'downloadESSJobExecutionDetails'})
print('HTTP', r.status_code, len(r.content))
raw = r.content
out = os.path.join(HERE, 'ess', rid)
os.makedirs(out, exist_ok=True)
i = raw.find(b'PK\x03\x04')
if i >= 0:
    data = raw[i:]
else:
    m = re.search(rb'Content>([A-Za-z0-9+/=\s]{20,})</', raw)
    data = base64.b64decode(m.group(1)) if m else raw
try:
    zipfile.ZipFile(io.BytesIO(data)).extractall(out)
except Exception as e:
    open(os.path.join(out, 'raw.bin'), 'wb').write(raw)
    print('not a clean zip:', e)
for f in os.listdir(out):
    print(os.path.join(out, f), os.path.getsize(os.path.join(out, f)))
