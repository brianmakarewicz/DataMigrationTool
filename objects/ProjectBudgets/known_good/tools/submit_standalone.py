"""Standalone ProjectBudgets submit OUTSIDE the DMT pipeline.

Same loadAndImportData SOAP call DMT_LOADER_PKG.SUBMIT_LOAD builds (account
prj/projectControl/import, interfaceDetails 39, jobList ImportBudgetsInterfaceData,
ParameterList '#NULL'), then polls load + import to terminal state.
Usage: python submit_standalone.py <zip path>
"""
import sys, os, re, time, base64, subprocess
import requests
sys.path.insert(0, os.path.expanduser('~/workspace'))
from conn_helper import get_fusion_url, get_fusion_user

URL = get_fusion_url()
USER, PW = get_fusion_user('fin_impl')
ERP = URL + '/fscmService/ErpIntegrationService'
NS = ('xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" '
      'xmlns:typ="http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/types/" '
      'xmlns:erp="http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/"')
ACT = 'http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/'
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = HERE
while not os.path.exists(os.path.join(REPO, 'scripts', 'fusion_bip_query.py')):  # walk up to the repo root
    REPO = os.path.dirname(REPO)


def soap(op, body):
    r = requests.post(ERP, data=f'<soapenv:Envelope {NS}><soapenv:Header/><soapenv:Body>{body}</soapenv:Body></soapenv:Envelope>',
                      headers={'Content-Type': 'text/xml; charset=utf-8', 'SOAPAction': ACT + op},
                      auth=(USER, PW), timeout=300)
    if r.status_code != 200:
        raise SystemExit(f'{op} HTTP {r.status_code}: {r.text[:3000]}')
    return r.text


def status(rid):
    t = soap('getESSJobStatus', f'<typ:getESSJobStatus><typ:requestId>{rid}</typ:requestId></typ:getESSJobStatus>')
    return re.search(r'<result[^>]*>([^<]*)</result>', t).group(1)


def poll(rid, label):
    for _ in range(120):
        s = status(rid)
        print(f'  {label} {rid}: {s}', flush=True)
        if s in ('SUCCEEDED', 'ERROR', 'WARNING', 'CANCELLED', 'EXPIRED'):
            return s
        time.sleep(15)
    return 'TIMEOUT'


def fq(sql, cols):
    out = subprocess.run([sys.executable, os.path.join(REPO, 'scripts', 'fusion_bip_query.py'), '--cred', 'fin_impl',
                          '--cols', cols, sql], capture_output=True, text=True).stdout
    return out


def main(zp):
    fn = os.path.basename(zp)
    b64 = base64.b64encode(open(zp, 'rb').read()).decode()
    title = os.path.splitext(fn)[0] + time.strftime('%y%m%d%H%M%S')
    body = ('<typ:loadAndImportData><typ:document>'
            f'<erp:Content>{b64}</erp:Content><erp:FileName>{fn}</erp:FileName><erp:ContentType>ZIP</erp:ContentType>'
            f'<erp:DocumentTitle>{title}</erp:DocumentTitle><erp:DocumentAuthor>InterfaceUser</erp:DocumentAuthor>'
            '<erp:DocumentSecurityGroup></erp:DocumentSecurityGroup><erp:DocumentAccount>prj/projectControl/import</erp:DocumentAccount>'
            '<erp:DocumentName></erp:DocumentName><erp:DocumentId></erp:DocumentId></typ:document>'
            '<typ:jobList><erp:JobName>/oracle/apps/ess/projects/control/budgetsAndForecasts,ImportBudgetsInterfaceData</erp:JobName>'
            '<erp:ParameterList>#NULL</erp:ParameterList></typ:jobList>'
            '<typ:interfaceDetails>39</typ:interfaceDetails><typ:notificationCode>10</typ:notificationCode>'
            '<typ:callbackURL></typ:callbackURL></typ:loadAndImportData>')
    t = soap('loadAndImportData', body)
    load_id = re.search(r'<result[^>]*>([^<]*)</result>', t).group(1)
    print('LOAD request id:', load_id, flush=True)
    poll(load_id, 'load')
    imp = None
    for _ in range(40):
        x = fq(f"SELECT requestid ID FROM fusion.ess_request_history WHERE requestid > {load_id} AND requestid < {int(load_id)+400} "
               "AND definition LIKE '%ImportBudgetsInterfaceData' AND UPPER(submitter)='FIN_IMPL' ORDER BY requestid", 'ID')
        m = re.findall(r'<ID>(\d+)</ID>', x)
        if m:
            imp = m[0]
            break
        time.sleep(15)
    print('IMPORT request id:', imp, flush=True)
    if imp:
        poll(imp, 'import')
        time.sleep(30)
        print(fq(f"SELECT requestid ID, parentrequestid PARENT, definition DEF, state STATE FROM fusion.ess_request_history "
                 f"WHERE requestid BETWEEN {load_id} AND {int(imp)+60} AND UPPER(submitter) IN ('FIN_IMPL') ORDER BY requestid",
                 'ID,PARENT,DEF,STATE'))


if __name__ == '__main__':
    main(sys.argv[1])
