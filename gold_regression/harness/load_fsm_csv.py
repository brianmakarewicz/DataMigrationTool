"""Standalone FSM 'Setup Data Import from CSV file' loader for gold-regression.

Pure Python. No DMT database, no DMT PL/SQL. Drives the Functional Setup Manager
CSV-package import mechanism directly over REST, the same non-UI path the
GLCalendar investigation found:

  1. GET  setupTasks?q=TaskName LIKE ...            -> discover the TaskCode
  2. GET  setupTaskCSVImports/{TaskCode}            -> ImportSupportedFlag
  3. POST setupTaskCSVImports                       -> submit a base64 zip
       body {TaskCode, SetupTaskCSVImportProcess:[{TaskCode, FileContent, SourceTargetDiffOkFlag}]}
       Content-Type application/vnd.oracle.adf.resourceitem+json
  4. GET  .../SetupTaskCSVImportProcess/{id}        -> poll ProcessCompletedFlag
  5. GET  .../SetupTaskCSVImportProcessResult/{id}/enclosure/ProcessLog
          .../SetupTaskCSVImportProcessResult/{id}/enclosure/ProcessResultsReport

Unlike GLCalendar (an "External Loading" object whose batch is service-loaded
XML that never round-tripped), Units of Measure exports as flat CSVs at the zip
root -- so we can mimic the real exported shape exactly and re-import it.

This helper is object-agnostic: it takes the package zip bytes + a TaskCode and
runs the round-trip. Package construction lives in the per-object build step.

Usage (import a prebuilt zip):
    python load_fsm_csv.py --task INV_MANAGE_UNITS_OF_MEASURE --zip pkg.zip
"""
import os
import sys
import json
import time
import base64
import argparse

import requests

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import conn  # noqa: E402

RES = '/fscmRestApi/resources/11.13.18.05'
RES_ITEM_CT = 'application/vnd.oracle.adf.resourceitem+json'


def find_task(name_like, role='fin_impl', log=print):
    """Return list of {TaskCode, TaskName} matching a TaskName LIKE pattern."""
    user, pwd = conn.fusion_creds(role)
    base = conn.fusion_url()
    r = requests.get(base.rstrip('/') + RES + '/setupTasks',
                     params={'q': "TaskName LIKE '%s'" % name_like,
                             'fields': 'TaskCode,TaskName', 'limit': 100},
                     auth=(user, pwd), timeout=120)
    r.raise_for_status()
    return r.json().get('items', [])


def import_supported(task_code, role='fin_impl', log=print):
    user, pwd = conn.fusion_creds(role)
    base = conn.fusion_url()
    r = requests.get(base.rstrip('/') + RES + '/setupTaskCSVImports/' + task_code,
                     auth=(user, pwd), timeout=120)
    if r.status_code != 200:
        return None
    return r.json().get('ImportSupportedFlag')


def run_import(task_code, zip_bytes, role='fin_impl', poll_secs=15,
               max_polls=80, log=print):
    """Submit a CSV package zip and poll to completion. Returns a result dict
    with process_id, ess_request_id, completed, process_log, results_report."""
    user, pwd = conn.fusion_creds(role)
    base = conn.fusion_url()
    b64 = base64.b64encode(zip_bytes).decode('ascii')
    body = {'TaskCode': task_code,
            'SetupTaskCSVImportProcess': [
                {'TaskCode': task_code, 'FileContent': b64,
                 'SourceTargetDiffOkFlag': True}]}
    url = base.rstrip('/') + RES + '/setupTaskCSVImports'
    log('POST %s  (zip %d bytes, b64 %d)' % (url, len(zip_bytes), len(b64)))
    r = requests.post(url, data=json.dumps(body),
                      headers={'Content-Type': RES_ITEM_CT,
                               'Accept': 'application/json'},
                      auth=(user, pwd), timeout=600)
    log('  -> HTTP %s' % r.status_code)
    if r.status_code not in (200, 201):
        return {'ok': False, 'http_status': r.status_code, 'raw': r.text[:1000]}
    j = r.json()
    pid = None
    for c in (j.get('SetupTaskCSVImportProcess') or []):
        pid = c.get('ProcessId')
    log('  ProcessId=%s' % pid)

    prow = (base.rstrip('/') + RES + '/setupTaskCSVImports/' + task_code
            + '/child/SetupTaskCSVImportProcess/' + str(pid))
    completed = False
    for i in range(max_polls):
        rr = requests.get(prow, auth=(user, pwd), timeout=120)
        f = rr.json().get('ProcessCompletedFlag')
        log('  poll %d ProcessCompletedFlag=%s' % (i, f))
        if str(f).lower() in ('true', 'y', 'completed'):
            completed = True
            break
        time.sleep(poll_secs)

    def _enc(name):
        eu = (prow + '/child/SetupTaskCSVImportProcessResult/' + str(pid)
              + '/enclosure/' + name)
        er = requests.get(eu, auth=(user, pwd), timeout=200)
        return er.text if er.status_code == 200 else '(%s: %s)' % (er.status_code, er.text[:200])

    plog = _enc('ProcessLog')
    prpt = _enc('ProcessResultsReport')
    return {'ok': True, 'http_status': r.status_code, 'process_id': pid,
            'completed': completed, 'process_log': plog,
            'results_report': prpt}


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--task', required=True)
    ap.add_argument('--zip', required=True)
    ap.add_argument('--role', default='fin_impl')
    a = ap.parse_args()
    with open(a.zip, 'rb') as fh:
        zb = fh.read()
    res = run_import(a.task, zb, role=a.role)
    print(json.dumps(res, indent=2)[:6000])
