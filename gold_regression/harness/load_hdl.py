"""Standalone HDL load: HCM Data Loader REST upload -> submit -> poll.

Pure Python. No DMT database, no DMT PL/SQL. Mirrors the exact REST flow of the
reference PL/SQL loader (db/packages/dmt_hdl_util_pkg.pkb.sql):

  1. uploadFile        POST hcmRestApi/resources/11.13.18.05/hcmDataLoader
                       /action/uploadFile   {content(b64 zip), fileName}
                       -> ContentId
  2. createFileDataSet POST .../action/createFileDataSet
                       {contentId, fileAction:"IMPORT_AND_LOAD"}   -> RequestId
  3. GET .../{RequestId}  poll DataSetStatusCode until terminal
     (ORA_COMPLETED / ORA_SUCCESS / ORA_IN_ERROR / ORA_STOPPED / ERROR ...)
  4. on non-clean status, GET .../{RequestId}/child/messages for the error text.

HCM uses the hcm_impl credential role. The .dat is delivered inside a zip (the
build step produced Workers_gold.zip containing Worker.dat).

Usage:
    python load_hdl.py Workers ../objects/Workers/Workers_gold.zip
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
from recipe import load_recipe  # noqa: E402

HCM_REST_PATH = 'hcmRestApi/resources/11.13.18.05/dataLoadDataSets'
TERMINAL = {'ORA_COMPLETED', 'ORA_SUCCESS', 'ORA_IN_ERROR', 'ORA_STOPPED',
            'SUCCESS', 'ERROR', 'WARNING'}
POLL_INTERVAL = 30
POLL_TIMEOUT = 1800


def _base(role):
    return conn.fusion_url().rstrip('/') + '/' + HCM_REST_PATH


def _post(url, body, user, pwd):
    headers = {'Content-Type': 'application/vnd.oracle.adf.action+json',
               'Accept': 'application/json'}
    r = requests.post(url, data=json.dumps(body), headers=headers,
                      auth=(user, pwd), timeout=600)
    if r.status_code < 200 or r.status_code >= 300:
        raise RuntimeError(f'HDL POST failed {r.status_code} @ {url} :: '
                           f'{r.text[:500]}')
    return r.json()


def _get(url, user, pwd):
    r = requests.get(url, headers={'Accept': 'application/json'},
                     auth=(user, pwd), timeout=600)
    if r.status_code < 200 or r.status_code >= 300:
        raise RuntimeError(f'HDL GET failed {r.status_code} @ {url} :: '
                           f'{r.text[:500]}')
    return r.json()


def upload(zip_path, user, pwd, role, log=print):
    with open(zip_path, 'rb') as f:
        b64 = base64.b64encode(f.read()).decode('ascii')
    filename = os.path.basename(zip_path)
    url = _base(role) + '/action/uploadFile'
    resp = _post(url, {'content': b64, 'fileName': filename}, user, pwd)
    content_id = (resp.get('result') or {}).get('ContentId') if isinstance(
        resp.get('result'), dict) else None
    if not content_id:
        # result may be a JSON string
        res = resp.get('result')
        if isinstance(res, str):
            try:
                content_id = json.loads(res).get('ContentId')
            except Exception:
                pass
    if not content_id:
        raise RuntimeError('uploadFile: no ContentId in response: '
                           + json.dumps(resp)[:800])
    log(f'uploadFile ok. ContentId={content_id} file={filename}')
    return content_id


def submit(content_id, user, pwd, role, log=print):
    url = _base(role) + '/action/createFileDataSet'
    resp = _post(url, {'contentId': content_id,
                       'fileAction': 'IMPORT_AND_LOAD'}, user, pwd)
    res = resp.get('result')
    request_id = None
    if isinstance(res, dict):
        request_id = res.get('RequestId')
    elif isinstance(res, str):
        try:
            request_id = json.loads(res).get('RequestId')
        except Exception:
            request_id = res.strip() or None
    if not request_id:
        raise RuntimeError('createFileDataSet: no RequestId in response: '
                           + json.dumps(resp)[:800])
    log(f'createFileDataSet ok. RequestId={request_id}')
    return str(request_id)


def poll(request_id, user, pwd, role, timeout=POLL_TIMEOUT,
         interval=POLL_INTERVAL, log=print):
    url = _base(role) + '/' + request_id
    time.sleep(10)  # data set not queryable immediately after create
    elapsed = 0
    last = {}
    while True:
        status = None
        try:
            last = _get(url, user, pwd)
            status = last.get('DataSetStatusCode')
        except Exception as e:
            log(f'poll transient (elapsed {elapsed}s): {str(e)[:200]}')
        log(f'HDL poll {request_id} | status={status or "(none)"} | '
            f'import {last.get("FileLineImportSuccessCount","?")} ok/'
            f'{last.get("FileLineImportErrorCount","?")} err | '
            f'load {last.get("ObjectSuccessCount","?")} ok/'
            f'{last.get("ObjectLoadErrorCount","?")} err | elapsed={elapsed}s')
        if status in TERMINAL:
            return status, last
        if elapsed >= timeout:
            log(f'HDL poll {request_id} timed out at {elapsed}s -> EXPIRED')
            return 'EXPIRED', last
        time.sleep(interval)
        elapsed += interval


def get_errors(request_id, user, pwd, role, log=print):
    url = (_base(role) + '/' + request_id +
           '/child/messages?onlyData=true&orderBy=DatFileName,FileLine&limit=500')
    try:
        resp = _get(url, user, pwd)
        return resp.get('items', [])
    except Exception as e:
        log(f'get_errors failed: {str(e)[:200]}')
        return []


def run(object_name, zip_path, role=None, log=print):
    recipe = load_recipe(object_name)
    role = role or recipe.get('cred_role', 'hcm_impl')
    user, pwd = conn.fusion_creds(role)
    content_id = upload(zip_path, user, pwd, role, log=log)
    request_id = submit(content_id, user, pwd, role, log=log)
    status, detail = poll(request_id, user, pwd, role, log=log)
    log(f'terminal HDL status for {request_id}: {status}')
    messages = get_errors(request_id, user, pwd, role, log=log)
    if messages:
        log(f'HDL messages ({len(messages)}):')
        for m in messages[:50]:
            log('  ' + json.dumps({k: m.get(k) for k in
                ('SourceSystemId', 'DatFileName', 'FileLine', 'MessageText',
                 'MessageType') if k in m}))
    return {'content_id': content_id, 'request_id': request_id,
            'terminal_status': status, 'detail': detail, 'messages': messages}


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('object_name')
    ap.add_argument('zip_path')
    ap.add_argument('--role', default=None)
    a = ap.parse_args()
    out = run(a.object_name, a.zip_path, a.role)
    print(json.dumps({k: out[k] for k in
          ('content_id', 'request_id', 'terminal_status')}, indent=2))
