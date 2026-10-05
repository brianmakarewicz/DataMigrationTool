#!/usr/bin/env python
"""
DMT APEX smoke / link checker — verifies the Data Migration Console renders
over real HTTP, with no browser.

What it does:
  1. Finds the latest Data Migration Console app (max APPLICATION_ID visible
     to DMT_OWNER, alias DMC%) and its page inventory from APEX metadata.
  2. Logs in over HTTP (Oracle APEX Accounts auth — workspace credentials
     from ~/workspace/connections.json) by replaying the login form POST.
  3. Sweeps EVERY application page: GET f?p=APP:PAGE:SESSION and asserts
     HTTP 200, no login bounce, and no error markers in the HTML
     (ORA-xxxxx, region render errors, 'No TFM table configuration found',
     session state protection violations, ...).
  4. Link crawl: extracts every f?p= / friendly-URL / apex.navigation.dialog
     link from each rendered page and follows links inside the app (BFS,
     capped) — this exercises the real drill chain Run History (80) ->
     Run Detail (82) -> Object Detail (52) -> Record Detail (57) with the
     app's own checksummed URLs.
  5. Sweeps APEX_WORKSPACE_ACTIVITY_LOG for our user+window: region-level
     errors that render inside an HTTP-200 page are caught here even when
     no marker is visible in the HTML.

TARGET IS URL-DRIVEN. The environment switch is a single base-URL knob, not a
special-case per instance or app name. Everything — app id, friendly alias,
workspace, schema, and the DMT_SMOKE end-user credentials — is resolved from
that base URL via scripts/dmt_apex_url_target.py (which matches connections.json).
Point this at ATP instead of local by find-and-replacing the base URL only.

  * --base-url   ORDS base            (default http://localhost:8182/ords; env DMT2_UI_BASE)
  * --app        application id       (default: resolved from the base URL, 501 local)
  * --app-alias  friendly app path    (default: resolved, r/dmt/livedmt2 local; env DMT2_UI_APP)
  * --workspace  APEX workspace        (default: resolved; env DMT2_WORKSPACE)
  * --schema     DB schema for metadata queries (default: resolved; env DMT2_SCHEMA)

Credentials: the default login is the end-user smoke account DMT_SMOKE, whose
password is read from connections.json (never hardcoded). DMT_SMOKE is a
NON-admin end-user account, so using it satisfies the no-admin-login guard.
Pass --user/--password to override; pass --no-login for an unauthenticated
reachability probe of the login page only.

The DB connection (used only for page inventory + activity-log queries) honors
$DMT2_CONN, else an ATP connection for --schema from connections.json. When the
metadata DB is NOT reachable (e.g. hitting a local console whose DB is not in
the ATP wallet), the sweep degrades gracefully: it falls back to the known
page inventory and skips the server-side activity-log step with a warning — the
HTTP page sweep + link crawl still run in full.

Usage:
  python scripts/dmt_apex_smoke.py                         # local app 501 as DMT_SMOKE (full sweep)
  python scripts/dmt_apex_smoke.py --no-login              # unauth reachability probe only
  python scripts/dmt_apex_smoke.py --base-url https://<atp-host>/ords   # retarget to ATP by URL
  python scripts/dmt_apex_smoke.py --run-id 229            # assert run 229 is drillable
  python scripts/dmt_apex_smoke.py --json out.json --max-urls 250

Exit codes: 0 = pass, 1 = failures (login/page/link/activity errors),
2 = pass with warnings only.
"""
import argparse
import datetime
import html as htmllib
import io
import json
import os
import re
import sys
import time
import urllib.parse

import oracledb

try:
    import requests
except ImportError:
    print("The 'requests' package is required: pip install requests")
    raise

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dmt_apex_url_target as urltarget  # the one URL knob (see its docstring)

CONNECTIONS = os.environ.get(
    'DMT2_CONNECTIONS', r'C:\Users\Monroe\workspace\connections.json')

# Known page inventory fallback — used when the metadata DB is not reachable
# (e.g. a local console whose DB is not in the ATP wallet). The HTTP sweep +
# link crawl still exercise the full drill chain; this just seeds the page list.
KNOWN_PAGES = [
    (1, 'Home'), (2, 'P2P'), (3, 'GL'), (4, 'OTC'), (5, 'Projects'),
    (6, 'Workers'), (7, 'Time & Labor'), (8, 'Admin'),
    (9, 'Upload Reference Guide'), (16, 'Lookup Dashboard'),
    (52, 'Object Detail'), (53, 'ESS Job Detail'), (54, 'Activity Log'),
    (57, 'Record Detail'), (58, 'ESS Job Output'),
    (80, 'Run History'), (82, 'Run Detail'), (84, 'Run Pipeline'),
    (85, 'Run Comparison'),
]

# Markers that indicate a broken page/region even when HTTP status is 200.
# Deliberately specific — this app legitimately DISPLAYS migration error text
# (ERROR_TEXT columns full of ORA-/[FUSION_ERROR] strings) inside report
# cells, so a bare ORA- match is only a failure when it sits inside an APEX
# error container; elsewhere it is reported as a warning (probably data).
ERROR_MARKERS = [
    (re.compile(r'Error during rendering of region', re.I), 'region render error'),
    (re.compile(r'No TFM table configuration found', re.I), 'TFM catalog miss'),
    (re.compile(r'Contact your application administrator', re.I), 'APEX internal error'),
    (re.compile(r'Session state protection violation', re.I), 'session state protection'),
    (re.compile(r'The checksum computed', re.I), 'checksum failure'),
    (re.compile(r'Error processing request', re.I), 'request processing error'),
    (re.compile(r'Unable to find item', re.I), 'missing page item (dead link target)'),
]
ORA_RE = re.compile(r'ORA-\d{4,5}')
# APEX error containers: ORA- inside one of these = real render/exec failure
ERROR_CONTAINER_RE = re.compile(
    r'class="(?:a-Form-error|a-IRR-error|t-Alert[^"]*|a-Notification[^"]*|htmldbStdErr)"[^>]*>'
    r'(?:(?!</div>).){0,400}?ORA-\d{4,5}', re.S)
LOGIN_MARKER = 'P9999_USERNAME'


# ---------------------------------------------------------------------------
# Config / metadata
# ---------------------------------------------------------------------------

def connect(schema):
    """Connect to the target schema for APEX metadata queries. Prefer $DMT2_CONN
    (user/password@dsn); otherwise build an ATP connection for `schema` from
    connections.json (atp_queryapp wallet)."""
    conn_str = os.environ.get('DMT2_CONN')
    if conn_str:
        m = re.match(r'^([^/]+)/(.+)@(?://)?(.+)$', conn_str)
        if not m:
            sys.exit(f"Cannot parse DMT2_CONN: {conn_str!r}")
        user, password, dsn = m.groups()
        w = os.environ.get('DMT2_WALLET')
        kw = dict(config_dir=w, wallet_location=w,
                  wallet_password=os.environ.get('DMT2_WALLET_PW')) if w else {}
        return oracledb.connect(user=user, password=password, dsn=dsn, **kw)
    with open(CONNECTIONS, encoding='utf-8') as fh:
        atp = json.load(fh)['atp_queryapp']
    schemas = atp.get('schemas', {})
    if 'password' not in (schemas.get(schema) or {}):
        sys.exit(f"No password for schema {schema!r} in {CONNECTIONS}; set $DMT2_CONN.")
    w = atp['wallet_dir']
    return oracledb.connect(user=schema, password=schemas[schema]['password'],
                            dsn=atp['dsn'], config_dir=w, wallet_location=w,
                            wallet_password=atp['wallet_password'])


def app_inventory(app_id, schema, workspace):
    """Return (pages, db_now, db_ok). Queries APEX metadata for the live page
    list; if the metadata DB is not reachable (common when the target is a
    local console not in the ATP wallet), falls back to KNOWN_PAGES and a None
    clock so the HTTP sweep still runs in full."""
    try:
        conn = connect(schema)
    except Exception as e:
        print(f"    note: metadata DB not reachable ({str(e)[:80]}); "
              f"using known page inventory, activity-log step will be skipped")
        return list(KNOWN_PAGES), None, False
    try:
        cur = conn.cursor()
        cur.execute("""SELECT page_id, page_name FROM apex_application_pages
                       WHERE application_id = :1 ORDER BY page_id""", [int(app_id)])
        pages = cur.fetchall()
        # activity-log timestamps run on the DB clock (UTC on ATP) — window must too
        cur.execute("SELECT SYSDATE FROM DUAL")
        db_now = cur.fetchone()[0]
        conn.close()
        if not pages:
            print(f"    note: no pages found for app {app_id} in metadata; "
                  f"using known page inventory")
            return list(KNOWN_PAGES), db_now, True
        return pages, db_now, True
    except Exception as e:
        print(f"    note: metadata query failed ({str(e)[:80]}); "
              f"using known page inventory")
        try:
            conn.close()
        except Exception:
            pass
        return list(KNOWN_PAGES), None, False


def activity_errors(app_id, since, user, schema):
    conn = connect(schema)
    cur = conn.cursor()
    cur.execute("""SELECT TO_CHAR(view_date,'HH24:MI:SS'), page_id,
                          SUBSTR(error_message, 1, 300)
                   FROM apex_workspace_activity_log
                   WHERE application_id = :1 AND apex_user = :2
                     AND view_date >= :3 AND error_message IS NOT NULL
                   ORDER BY view_date""", [app_id, user, since])
    rows = cur.fetchall()
    conn.close()
    return rows


# ---------------------------------------------------------------------------
# Login
# ---------------------------------------------------------------------------

def hidden(html, name):
    """Extract a hidden input's value by name= or id=, tolerating any attribute
    order (pSalt renders value-before-id) and HTML entity escaping (&#x2F;)."""
    for attr in ('name', 'id'):
        for m in re.finditer(r'<input[^>]*\b' + attr + r'="' + re.escape(name) + r'"[^>]*>', html):
            v = re.search(r'value="([^"]*)"', m.group(0))
            if v:
                return htmllib.unescape(v.group(1))
    return ''


def login(session, ords_base, app_id, user, password):
    """Replay the APEX 24.2 login-page form POST. Returns the APEX session id."""
    r = session.get(f"{ords_base}/f?p={app_id}:1", timeout=60)
    r.raise_for_status()
    html = r.text
    if LOGIN_MARKER not in html:
        raise RuntimeError("did not land on the login page — unexpected auth flow")

    fields = {n: hidden(html, n) for n in
              ('p_flow_id', 'p_flow_step_id', 'p_instance',
               'p_page_submission_id', 'p_reload_on_submit')}
    salt = hidden(html, 'pSalt')
    protected = hidden(html, 'pPageItemsProtected')
    row_version = hidden(html, 'pPageItemsRowVersion')

    m = re.search(r'action="(wwv_flow\.accept[^"]*)"', html)
    accept_url = f"{ords_base}/" + htmllib.unescape(m.group(1)) if m else f"{ords_base}/wwv_flow.accept"

    p_json = json.dumps({
        "pageItems": {
            "itemsToSubmit": [
                {"n": "P9999_USERNAME", "v": user},
                {"n": "P9999_PASSWORD", "v": password},
                {"n": "P9999_REMEMBER", "v": "N"},
            ],
            "protected": protected,
            "rowVersion": row_version,
            "formRegionChecksums": [],
        },
        "salt": salt,
    })
    data = dict(fields)
    data.update({'p_request': 'LOGIN', 'p_json': p_json})
    r2 = session.post(accept_url, data=data, timeout=60, allow_redirects=True)

    if LOGIN_MARKER in r2.text:
        m_err = re.search(r'a-Notification-link">([^<]{5,200})', r2.text) or \
                re.search(r'class="t-Alert-body"[^>]*>\s*([^<]{5,120})', r2.text)
        raise RuntimeError("login rejected"
                           + (f": {htmllib.unescape(m_err.group(1).strip())}" if m_err else ''))
    m_sess = re.search(r'[?&:]session=(\d+)', r2.url) or \
             re.search(r'f\?p=\d+:\d+:(\d+)', r2.url)
    apex_session = m_sess.group(1) if m_sess else fields['p_instance']
    return apex_session


# ---------------------------------------------------------------------------
# URL handling
# ---------------------------------------------------------------------------

FP_RE = re.compile(r'''(?:href="|apex\.navigation\.dialog\(\s*['"]|window\.open\(\s*['"])'''
                   r'''((?:/ords/)?(?:r/[\w\-]+/[\w\-]+/[^"'\\)#]+|f\?p=[^"'\\)#]+))''')


def parse_fp(url):
    """Split an f?p= payload -> (app, page, request, items, values). Non-f?p -> None."""
    m = re.search(r'f\?p=([^&#]*)', url)
    if not m:
        return None
    parts = urllib.parse.unquote(htmllib.unescape(m.group(1))).split(':')
    parts += [''] * (9 - len(parts))
    return {'app': parts[0], 'page': parts[1], 'request': parts[3],
            'items': parts[6], 'values': parts[7]}


def extract_links(html, ords_base):
    # APEX entity-encodes entire href values in report cells
    # (href="&#x2F;ords&#x2F;...&#x3F;p82_run_id&#x3D;113...") — unescape first.
    html = htmllib.unescape(html)
    links = set()
    for raw in FP_RE.findall(html):
        u = raw.replace('\\u0026', '&').replace('\\/', '/')
        if u.startswith('f?p='):
            u = f"{ords_base}/{u}"
        elif u.startswith('/ords/'):
            u = ords_base[: -len('/ords')] + u
        elif u.startswith('r/'):
            u = f"{ords_base}/{u}"
        links.add(u)
    return links


def url_params(url):
    return {k.lower(): v for k, v in
            urllib.parse.parse_qsl(urllib.parse.urlsplit(url).query)}


def check_html(page_label, status, html_text, findings, warnings=None):
    """Append (label, problem) tuples to findings; return count added."""
    n0 = len(findings)
    if status != 200:
        findings.append((page_label, f"HTTP {status}"))
        return len(findings) - n0
    if LOGIN_MARKER in html_text:
        findings.append((page_label, "bounced to login page (session lost or page requires re-auth)"))
        return len(findings) - n0
    for rx, what in ERROR_MARKERS:
        m = rx.search(html_text)
        if m:
            ctx = ' '.join(html_text[max(0, m.start() - 60):m.end() + 120].split())
            findings.append((page_label, f"{what}: ...{ctx[:200]}..."))
    m = ERROR_CONTAINER_RE.search(html_text)
    if m:
        ctx = ' '.join(m.group(0).split())
        findings.append((page_label, f"ORA- error in error container: ...{ctx[-200:]}"))
    elif warnings is not None:
        m2 = ORA_RE.search(html_text)
        if m2:
            ctx = ' '.join(html_text[max(0, m2.start() - 60):m2.end() + 100].split())
            warnings.append((page_label,
                             f"ORA- text visible outside an error container "
                             f"(probably displayed migration data): ...{ctx[:160]}..."))
    return len(findings) - n0


# ---------------------------------------------------------------------------

def main():
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace',
                                  line_buffering=True)
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace',
                                  line_buffering=True)
    ap = argparse.ArgumentParser(description='DMT APEX HTTP smoke / link checker (URL-driven)')
    ap.add_argument('--base-url', help='ORDS base URL — the one environment knob '
                    '(default http://localhost:8182/ords; env DMT2_UI_BASE)')
    ap.add_argument('--app', help='application id (default: resolved from the base URL)')
    ap.add_argument('--app-alias', help='friendly app path r/<ws>/<alias> '
                    '(default: resolved from the base URL; env DMT2_UI_APP)')
    ap.add_argument('--workspace', help='APEX workspace (default: resolved; env DMT2_WORKSPACE)')
    ap.add_argument('--schema', help='DB schema for metadata queries (default: resolved; env DMT2_SCHEMA)')
    ap.add_argument('--user', help='end-user login (default: DMT_SMOKE from connections.json). '
                    'Do NOT pass the workspace admin (DMTADMIN/builder).')
    ap.add_argument('--password', help='password for --user (default: resolved from connections.json)')
    ap.add_argument('--no-login', action='store_true',
                    help='unauthenticated reachability probe of the login page only')
    ap.add_argument('--run-id', type=int, help='assert this run id is drillable from Run History')
    ap.add_argument('--max-urls', type=int, default=350, help='crawl cap (unique URLs)')
    ap.add_argument('--per-family', type=int, default=3,
                    help='max visits per link shape (same page+item names, different values); '
                         'a family that fails once is not revisited')
    ap.add_argument('--json', metavar='PATH')
    args = ap.parse_args()

    # One URL knob resolves everything (app id, alias, workspace, schema, creds).
    tgt = urltarget.resolve(base_url=args.base_url, app_id=args.app,
                            app_path=args.app_alias, user=args.user,
                            password=args.password, workspace=args.workspace,
                            schema=args.schema)
    ords_base = tgt['base_url']
    app_id = int(tgt['app_id'])
    ws_user = tgt['user']
    ws_pass = tgt['password']

    print(f"Target: {ords_base}/{tgt['app_path']} (app {app_id}, workspace "
          f"{tgt['workspace']}) — resolved from {tgt['source']}")

    print("\n[0] Page inventory")
    pages, db_started, db_ok = app_inventory(app_id, tgt['schema'], tgt['workspace'])
    started = datetime.datetime.now()
    print(f"    {len(pages)} pages")

    failures, warnings = [], []
    sess = requests.Session()
    sess.headers['User-Agent'] = 'DMT-regression-smoke/1.0'

    # Login is the default (DMT_SMOKE, a non-admin end-user account). --no-login
    # drops to an unauthenticated reachability probe of the login page only.
    if args.no_login:
        print("\n[1] Unauthenticated reachability probe (--no-login)...")
        try:
            r = sess.get(f"{ords_base}/f?p={app_id}:1", timeout=60)
            if r.status_code == 200 and LOGIN_MARKER in r.text:
                print(f"    OK  login page renders (HTTP 200, {LOGIN_MARKER} present)")
            else:
                failures.append(('login-page',
                                 f"HTTP {r.status_code}, login marker "
                                 f"{'present' if LOGIN_MARKER in r.text else 'ABSENT'}"))
                print(f"    FAIL  login page: HTTP {r.status_code}")
        except Exception as e:
            failures.append(('login-page', str(e)))
            print(f"    FAIL  {e}")
        report(args, app_id, failures, warnings, {}, started)
        sys.exit(1 if failures else 2)

    if not ws_pass:
        print(f"\nFAIL: no password resolved for user {ws_user}. Set it in "
              f"connections.json (console.app_users) or pass --password / "
              f"$DMT2_UI_PASS. Credentials are never hardcoded.")
        sys.exit(1)

    print("\n[1] Login (Oracle APEX Accounts)...")
    try:
        apex_session = login(sess, ords_base, app_id, ws_user, ws_pass)
        print(f"    OK  session={apex_session} user={ws_user}")
    except Exception as e:
        print(f"    FAIL  {e}")
        failures.append(('login', str(e)))
        report(args, app_id, failures, warnings, {}, started)
        sys.exit(1)

    # ---- 2. full page sweep ------------------------------------------------
    print(f"\n[2] Page sweep — {len(pages)} pages")
    page_results = {}
    seen_urls = set()
    to_crawl = []
    for page_id, page_name in pages:
        if page_id in (0, 9999):        # 0 = global page (not directly renderable),
            continue                    # 9999 = login page — skip both
        url = f"{ords_base}/f?p={app_id}:{page_id}:{apex_session}"
        t0 = time.time()
        try:
            r = sess.get(url, timeout=90)
            elapsed = time.time() - t0
            label = f"page {page_id} ({page_name})"
            n_bad = check_html(label, r.status_code, r.text, failures, warnings)
            page_results[page_id] = {'name': page_name, 'status': r.status_code,
                                     'elapsed': round(elapsed, 1), 'problems': n_bad}
            flag = 'FAIL' if n_bad else ('slow' if elapsed > 15 else 'ok  ')
            print(f"    {flag}  p{page_id:<5} {elapsed:5.1f}s  {page_name}")
            if elapsed > 15:
                warnings.append((label, f"slow render: {elapsed:.1f}s"))
            if not n_bad:
                for link in extract_links(r.text, ords_base):
                    to_crawl.append((link, f"found on page {page_id}"))
        except Exception as e:
            failures.append((f"page {page_id} ({page_name})", f"request failed: {e}"))
            print(f"    FAIL  p{page_id:<5} request failed: {str(e)[:100]}")

    # ---- 3. link crawl -------------------------------------------------------
    print(f"\n[3] Link crawl (cap {args.max_urls} unique URLs; run-{args.run_id} drills "
          f"prioritized)" if args.run_id else f"\n[3] Link crawl (cap {args.max_urls} unique URLs)")
    from collections import deque
    crawled = crawl_ok = 0
    run_id_seen = False
    queue = deque()
    link_results = []
    family_visits, family_failed = {}, {}

    def link_label(url, fp):
        if fp:
            return (f"link p{fp['page']}"
                    + (f" [{fp['items'][:38]}={fp['values'][:38]}]" if fp['items'] else ''))
        tail = re.sub(r'^.*?/r/[\w\-]+/[\w\-]+/', '', url).split('?')[0]
        params = '&'.join(f"{k}={v}" for k, v in url_params(url).items()
                          if k not in ('session', 'cs'))
        return f"link r/{tail[:40]}" + (f" [{params[:44]}]" if params else '')

    def carries_run_id(link, fp):
        if not args.run_id:
            return False
        rid = str(args.run_id)
        if fp:
            return rid in (fp['values'] or '')
        q = url_params(link)
        return any(v == rid for k, v in q.items() if k not in ('session', 'cs', 'clear'))

    def family_of(link, fp):
        if fp:
            return (fp['page'], fp['request'], fp['items'])
        items = tuple(sorted(k for k in url_params(link) if k not in ('session', 'cs')))
        return (urllib.parse.urlsplit(link).path, items)

    def key_of(link, fp):
        if fp:
            return (fp['page'], fp['request'], fp['items'], fp['values'])
        items = tuple(sorted((k, v) for k, v in url_params(link).items()
                             if k not in ('session', 'cs')))
        return (urllib.parse.urlsplit(link).path, items)

    enqueued = set()

    def enqueue(link, origin):
        nonlocal run_id_seen
        fp = parse_fp(link)
        prioritized = carries_run_id(link, fp)
        if prioritized:
            run_id_seen = True
        k = key_of(link, fp)
        if k in enqueued or k in seen_urls:
            return
        fam = family_of(link, fp)
        # prune at enqueue: families already failed or fully sampled add nothing
        if fam in family_failed:
            family_failed[fam] += 1
            return
        if family_visits.get(fam, 0) >= args.per_family and not prioritized:
            return
        enqueued.add(k)
        if prioritized:
            queue.appendleft((link, origin))    # walk the run-under-test drills first
        else:
            queue.append((link, origin))

    for link, origin in to_crawl:
        enqueue(link, origin)

    while queue and crawled < args.max_urls:
        url, origin = queue.popleft()
        fp = parse_fp(url)
        if fp:
            if fp['app'] != str(app_id):
                continue                                    # other app
            if fp['page'] in ('9999', '') or fp['request'].upper().startswith('LOGOUT'):
                continue                                    # never follow logout
            if 'APPLICATION_PROCESS' in url:
                continue                                    # data downloads etc.
            key = (fp['page'], fp['request'], fp['items'], fp['values'])
            family = (fp['page'], fp['request'], fp['items'])
        else:
            if '/r/' not in url:
                continue
            path = urllib.parse.urlsplit(url).path
            items = tuple(sorted((k, v) for k, v in url_params(url).items()
                                 if k not in ('session', 'cs')))
            key = (path, items)
            family = (path, tuple(k for k, _ in items))
        if key in seen_urls:
            continue
        seen_urls.add(key)
        # A link family = same page + item names, different values (e.g. one
        # Object Detail drill per historical run). Sampling a few per family
        # keeps legacy list pages from exploding the crawl; a family that
        # already failed is not revisited (same break, more noise).
        prioritized = carries_run_id(url, fp)
        if family in family_failed:
            family_failed[family] += 1
            continue
        if family_visits.get(family, 0) >= args.per_family and not prioritized:
            continue
        family_visits[family] = family_visits.get(family, 0) + 1
        # re-stamp our session into f?p URLs (links carry the rendering session)
        if fp:
            url = re.sub(r'(f\?p=\d+:[\w\-]*:)\d*', rf'\g<1>{apex_session}', url)
        crawled += 1
        t0 = time.time()
        label = link_label(url, fp)
        try:
            r = sess.get(url, timeout=90)
            n_bad = check_html(f"{label} ({origin})", r.status_code, r.text, failures, warnings)
            if n_bad == 0:
                crawl_ok += 1
                for link in extract_links(r.text, ords_base):
                    enqueue(link, label)
            else:
                family_failed[family] = 0
                print(f"    FAIL  {label} ({origin})")
            link_results.append({'url': url[:200], 'origin': origin, 'problems': n_bad,
                                 'elapsed': round(time.time() - t0, 1)})
        except Exception as e:
            failures.append((f"{label} ({origin})", f"request failed: {e}"))
            family_failed[family] = 0
    for family, skipped in family_failed.items():
        if skipped:
            failures.append((f"link family {family}",
                             f"{skipped} more link(s) of this shape skipped after first failure"))
    print(f"    {crawled} links followed, {crawl_ok} clean"
          + (f", {len(queue)} left unvisited (cap)" if queue else ''))
    if queue:
        warnings.append(('crawl', f"{len(queue)} discovered links not visited (over --max-urls cap)"))
    if args.run_id:
        if run_id_seen:
            print(f"    OK  run {args.run_id} is linked from the UI")
        else:
            failures.append(('crawl', f"run {args.run_id} never appeared in any drill link "
                                      f"(not visible on Run History?)"))

    # ---- 4. server-side activity log sweep -----------------------------------
    if not db_ok or db_started is None:
        print("\n[4] APEX activity log sweep — SKIPPED (metadata DB not reachable "
              "for this target)")
        warnings.append(('activity log', 'skipped — metadata DB not reachable; the '
                         'HTTP page sweep + link crawl above still ran in full'))
        report(args, app_id, failures, warnings, page_results, started,
               link_results=link_results)
        sys.exit(1 if failures else (2 if warnings else 0))
    print(f"\n[4] APEX activity log sweep (user {ws_user}, since {db_started:%H:%M:%S} DB time)")
    try:
        act = activity_errors(app_id, db_started, ws_user, tgt['schema'])
        groups = {}
        for when, pg, err in act:
            err1 = ' '.join(str(err).split())[:220]
            g = groups.setdefault((pg, err1), [0, when])
            g[0] += 1
        for (pg, err1), (n, when) in sorted(groups.items()):
            failures.append((f"activity log p{pg}", f"x{n} [{when}] {err1}"))
            print(f"    FAIL  p{pg} x{n} {err1[:130]}")
        if not act:
            print("    OK    no server-side page errors recorded for this session")
    except Exception as e:
        warnings.append(('activity log', f"sweep failed: {e}"))

    report(args, app_id, failures, warnings, page_results, started,
           link_results=link_results)
    sys.exit(1 if failures else (2 if warnings else 0))


def report(args, app_id, failures, warnings, page_results, started, link_results=None):
    print(f"\n{'=' * 70}")
    verdict = 'PASS' if not failures else 'FAIL'
    if not failures and warnings:
        verdict = 'PASS (with warnings)'
    print(f"APEX SMOKE VERDICT: {verdict} — app {app_id}: "
          f"{len(failures)} failure(s), {len(warnings)} warning(s)")
    print('=' * 70)
    for where, what in failures:
        print(f"  FAIL  {where}: {what}")
    for where, what in warnings:
        print(f"  warn  {where}: {what}")
    if args.json:
        with open(args.json, 'w', encoding='utf-8') as fh:
            json.dump({'app_id': app_id, 'verdict': verdict,
                       'failures': [f"{w}: {x}" for w, x in failures],
                       'warnings': [f"{w}: {x}" for w, x in warnings],
                       'pages': page_results, 'links': link_results or [],
                       'started': str(started)}, fh, indent=2, default=str)
        print(f"\nJSON summary written to {args.json}")


if __name__ == '__main__':
    main()
