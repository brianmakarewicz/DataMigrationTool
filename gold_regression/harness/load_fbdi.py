"""Standalone FBDI load: loadAndImportData SOAP call + getESSJobStatus poll.

Pure Python. No DMT database, no DMT PL/SQL. This mirrors the exact SOAP
envelope, SOAPAction headers, and response parsing of the reference PL/SQL
loader (db/packages/dmt_loader_pkg.pkb.sql: SUBMIT_LOAD ~228, POLL_ESS_JOB ~538)
but calls the Fusion ERP Integration SOAP service directly with HTTP Basic auth.

loadAndImportData is a single call that:
  1. base64-embeds the FBDI zip and uploads it to UCM under DocumentAccount,
  2. runs "Load File to Interface Tables" to unpack the zip into the interface
     table (e.g. POZ_SUPPLIERS_INT), and
  3. chains the import job named in <JobName> (e.g. ImportSuppliers) with
     <ParameterList>.

It returns the LOAD ESS request id (the <result> element). We poll that id with
getESSJobStatus every 60s until a terminal status.

Usage:
    python load_fbdi.py Suppliers <zip_path> [--role fin_impl]
"""
import os
import sys
import base64
import argparse
import time

import requests

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import conn  # noqa: E402
from recipe import load_recipe  # noqa: E402

# SOAP namespaces -- byte-mirrored from dmt_loader_pkg.pkb.sql
NS_ACTION = ('http://xmlns.oracle.com/apps/financials/commonModules/'
             'shared/model/erpIntegrationService/')
SOAP_NS = (
    'xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" '
    'xmlns:typ="http://xmlns.oracle.com/apps/financials/commonModules/'
    'shared/model/erpIntegrationService/types/" '
    'xmlns:erp="http://xmlns.oracle.com/apps/financials/commonModules/'
    'shared/model/erpIntegrationService/"'
)
GETSTATUS_NS = (
    'xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" '
    'xmlns:typ="http://xmlns.oracle.com/apps/financials/commonModules/'
    'shared/model/erpIntegrationService/types/"'
)

TERMINAL = {'SUCCEEDED', 'WARNING', 'FAILED', 'ERROR', 'EXPIRED'}
POLL_INTERVAL = 60
POLL_TIMEOUT = 1800


def _extract(xml, tag='result'):
    """Pull the text between the first <tag ...> and </tag>, mirroring the
    PL/SQL DBMS_LOB.INSTR parse (it keys on the opening '<result' and the
    next '>')."""
    start = xml.find('<' + tag)
    if start < 0:
        return None
    gt = xml.find('>', start)
    if gt < 0:
        return None
    end = xml.find('</' + tag + '>', gt + 1)
    if end < 0:
        return None
    return xml[gt + 1:end].strip()


def _post(url, action, body, user, pwd):
    headers = {
        'Content-Type': 'text/xml; charset=utf-8',
        'SOAPAction': '"' + action + '"',
        'Accept': 'text/xml',
    }
    r = requests.post(url, data=body.encode('utf-8'), headers=headers,
                      auth=(user, pwd), timeout=600)
    if r.status_code < 200 or r.status_code >= 300:
        raise RuntimeError(f'SOAP call failed. Status: {r.status_code} | '
                           f'Action: {action} | Response: {r.text[:500]}')
    return r.text


def _stamp(text, prefix, tokens):
    """Substitute ${PREFIX}, ${GL_DATE}, and discovered ${TOKEN}s into a string
    (used for the import ParameterList, which may carry discovered BU/ledger
    ids and the run prefix)."""
    import datetime
    out = text.replace('${PREFIX}', str(prefix))
    out = out.replace('${GL_DATE}', datetime.date.today().strftime('%Y-%m-%d'))
    for k, v in (tokens or {}).items():
        out = out.replace('${' + k + '}', str(v))
    return out


def submit_load(recipe, zip_path, user, pwd, log=print, parameter_list=None):
    url = conn.erp_soap_url()
    with open(zip_path, 'rb') as f:
        b64 = base64.b64encode(f.read()).decode('ascii')  # no newlines
    filename = os.path.basename(zip_path)
    if parameter_list is None:
        parameter_list = recipe['parameter_list']

    body = (
        f'<soapenv:Envelope {SOAP_NS}>'
        '<soapenv:Header/><soapenv:Body>'
        '<typ:loadAndImportData>'
        '<typ:document>'
        '<erp:Content>' + b64 + '</erp:Content>'
        f'<erp:FileName>{filename}</erp:FileName>'
        '<erp:ContentType>ZIP</erp:ContentType>'
        f'<erp:DocumentTitle>{filename}</erp:DocumentTitle>'
        '<erp:DocumentAuthor>InterfaceUser</erp:DocumentAuthor>'
        '<erp:DocumentSecurityGroup></erp:DocumentSecurityGroup>'
        f'<erp:DocumentAccount>{recipe["doc_account"]}</erp:DocumentAccount>'
        '<erp:DocumentName></erp:DocumentName>'
        '<erp:DocumentId></erp:DocumentId>'
        '</typ:document>'
        '<typ:jobList>'
        f'<erp:JobName>{recipe["job_name"]}</erp:JobName>'
        f'<erp:ParameterList>{parameter_list}</erp:ParameterList>'
        '</typ:jobList>'
        f'<typ:interfaceDetails>{recipe["interface_details_id"]}</typ:interfaceDetails>'
        '<typ:notificationCode>10</typ:notificationCode>'
        '<typ:callbackURL></typ:callbackURL>'
        '</typ:loadAndImportData>'
        '</soapenv:Body></soapenv:Envelope>'
    )
    log(f'loadAndImportData: account={recipe["doc_account"]} '
        f'job={recipe["job_name"]} interfaceDetails={recipe["interface_details_id"]} '
        f'params={parameter_list} file={filename} ({len(b64)} b64 chars)')
    resp = _post(url, NS_ACTION + 'loadAndImportData', body, user, pwd)
    load_id = _extract(resp, 'result')
    if not load_id:
        raise RuntimeError('Could not parse Load ESS job id from response. '
                           'First 1000 chars: ' + resp[:1000])
    log(f'Load ESS request id: {load_id}')
    return load_id, resp


def poll(ess_id, user, pwd, timeout=POLL_TIMEOUT, interval=POLL_INTERVAL,
         log=print):
    url = conn.erp_soap_url()
    body = (
        f'<soapenv:Envelope {GETSTATUS_NS}>'
        '<soapenv:Header/><soapenv:Body>'
        '<typ:getESSJobStatus>'
        f'<typ:requestId>{ess_id}</typ:requestId>'
        '</typ:getESSJobStatus>'
        '</soapenv:Body></soapenv:Envelope>'
    )
    elapsed = 0
    while True:
        status = None
        try:
            resp = _post(url, NS_ACTION + 'getESSJobStatus', body, user, pwd)
            status = _extract(resp, 'result')
        except Exception as e:  # transient transport faults: log + retry
            log(f'poll transient fault (elapsed {elapsed}s): {str(e)[:200]}')
        log(f'ESS poll {ess_id} | status={status or "(none)"} | elapsed={elapsed}s')
        if status in TERMINAL:
            return status
        if elapsed >= timeout:
            log(f'ESS poll {ess_id} timed out at {elapsed}s -> EXPIRED')
            return 'EXPIRED'
        time.sleep(interval)
        elapsed += interval


def run(object_name, zip_path, role=None, log=print, prefix=None, tokens=None):
    recipe = load_recipe(object_name)
    role = role or recipe.get('cred_role', 'fin_impl')
    user, pwd = conn.fusion_creds(role)
    plist = _stamp(recipe['parameter_list'], prefix, tokens) if prefix else \
        recipe['parameter_list']
    load_id, _ = submit_load(recipe, zip_path, user, pwd, log=log,
                             parameter_list=plist)
    status = poll(load_id, user, pwd, log=log)
    log(f'terminal status for load {load_id}: {status}')

    # Optional downstream ESS programs that must complete before base-table
    # verification (e.g. a separate "Import" or an accounting/validation
    # program submitted by name). loadAndImportData already chains the import
    # named in job_name; declare "downstream_jobs" only for a further program.
    # Downstream params may carry ${PREFIX}/${GL_DATE}/discovered ${TOKEN}s just
    # like the main import ParameterList -- stamp them the same way (e.g. the GL
    # Budget "Validate and Load Budgets" job whose only argument is the prefixed
    # Run Name, which must equal the good rows' RUN_NAME).
    #
    # A downstream job may declare its own "cred_role" when the load user
    # cannot submit it. PurchaseOrders is exactly this case: the FBDI zip is
    # loaded to the interface tables under fin_impl (calvin.roth gets 401 on the
    # loadAndImportData SOAP call), but the Import Orders program (ImportSPOJob)
    # can only be submitted by the procurement functional user calvin.roth --
    # fin_impl gets FUN-720397 "user doesn't have access to ESS job definition".
    # When "cred_role" is absent the downstream job keeps using the load creds.
    downstream = []
    for job in recipe.get('downstream_jobs', []) or []:
        dparams = _stamp(job.get('parameter_list', ''), prefix, tokens) \
            if prefix else job.get('parameter_list', '')
        d_user, d_pwd = (conn.fusion_creds(job['cred_role'])
                         if job.get('cred_role') else (user, pwd))
        req_id = submit_ess(job['job_path'], dparams,
                            d_user, d_pwd, log=log)
        dstatus = poll(req_id, d_user, d_pwd, log=log)
        log(f'downstream {job.get("name", job["job_path"])} '
            f'req {req_id}: {dstatus}')
        downstream.append({'name': job.get('name'), 'request_id': req_id,
                           'terminal_status': dstatus})

    return {'load_request_id': load_id, 'terminal_status': status,
            'downstream': downstream}


def submit_ess(job_path, parameter_list, user, pwd, log=print):
    """submitESSJobRequest for a standalone downstream program; returns its
    request id. job_path uses the comma form (last ';' -> ',').

    Each positional ESS argument is sent as its own <typ:paramList> element.
    Fusion's ParameterList delimiter is '~' (tilde) -- e.g. AutoInvoice Master
    Program 'Import Receivables Transactions Using AutoInvoice' takes
    '<num_workers>~#NULL~<trx_source_id>~<date>~...~N~Y'. If the string carries
    no '~' we fall back to comma so simpler single/comma jobs still work. Empty
    positions must be '#NULL' (a truly empty token would collapse and shift the
    positional arguments)."""
    url = conn.erp_soap_url()
    sep = '~' if '~' in (parameter_list or '') else ','
    # Keep EVERY positional slot, including empty ones and a trailing empty --
    # Fusion maps ESS args strictly by position, so a dropped empty shifts every
    # later argument. AutoInvoice Master, for example, needs its final
    # load_request_id slot present-but-empty (from a trailing '~'); stripping it
    # makes the validator read the preceding flag as the load request id and
    # abort. Empty tokens survive the SOAP round-trip in the raw argv, verified
    # live against the AutoInvoice ESS log.
    params = parameter_list.split(sep) if parameter_list else []
    body = (
        f'<soapenv:Envelope {SOAP_NS}>'
        '<soapenv:Header/><soapenv:Body>'
        '<typ:submitESSJobRequest>'
        '<typ:jobPackageName>' + job_path.rsplit(',', 1)[0] + '</typ:jobPackageName>'
        '<typ:jobDefinitionName>' + job_path.rsplit(',', 1)[-1] + '</typ:jobDefinitionName>'
        + ''.join(f'<typ:paramList>{p}</typ:paramList>' for p in params)
        + '</typ:submitESSJobRequest>'
        '</soapenv:Body></soapenv:Envelope>'
    )
    resp = _post(url, NS_ACTION + 'submitESSJobRequest', body, user, pwd)
    req_id = _extract(resp, 'result')
    if not req_id:
        raise RuntimeError('submitESSJobRequest: no request id. '
                           + resp[:800])
    log(f'submitESSJobRequest {job_path} -> {req_id}')
    return req_id


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('object_name')
    ap.add_argument('zip_path')
    ap.add_argument('--role', default=None)
    a = ap.parse_args()
    result = run(a.object_name, a.zip_path, a.role)
    print(result)
