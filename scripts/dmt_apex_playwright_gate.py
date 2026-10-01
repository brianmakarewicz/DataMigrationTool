#!/usr/bin/env python
"""
dmt_apex_playwright_gate.py — minimal Playwright UI gate for the local DMT2 console.

Phase 2 of the CI/CD pipeline (docs/cicd.md): after the deterministic regression
passes on local, this is a fast browser smoke test that proves the APEX console
still renders for a real logged-in user. It is deliberately small — a couple of
pages, not a full crawl. The exhaustive HTTP sweep + link crawl lives in
scripts/dmt_apex_smoke.py; the exhaustive browser drill lives in
scripts/playwright_verify.js. This gate is the quick "did the UI survive the
deploy" check wired into the self-hosted runner.

What it does:
  1. Launches headless Chromium (Playwright install reused from
     ../fusion-config-migrator/node_modules, matching playwright_verify.js — override
     with DMT2_PW_NODE_MODULES).
  2. Logs into the local console (Oracle APEX Accounts auth), carrying the real
     minted session into subsequent friendly-URL navigations (same session handling
     as playwright_verify.js).
  3. Asserts a couple of pages render for the logged-in user with no login bounce
     and no visible APEX error container.

Target (local Docker console by default; all overridable by env so the same gate
can point at any instance):
  DMT2_UI_BASE   base ORDS URL        (default http://localhost:8182/ords)
  DMT2_UI_APP    friendly app path    (default r/dmt/livedmt2)
  DMT2_UI_APPID  numeric app id       (default 501 — local console)
  DMT2_UI_USER   end-user login       (REQUIRED — a non-admin smoke account)
  DMT2_UI_PASS   password for that user (REQUIRED)
  DMT2_UI_PAGES  comma list of page ids to assert (default 1,80 — home + run history)

Creds come from the environment only — never hardcode (connections.json is the
source of truth; the caller/runner exports these before invoking). This mirrors
the creds-from-env contract in playwright_verify.js and dmt_apex_smoke.py.

Exit codes: 0 = all asserted pages rendered; 1 = a failure (login, bounce, error
container, or missing-page-item); 2 = required env not set (nothing run).

Usage:
  DMT2_UI_USER=SMOKE DMT2_UI_PASS=... python scripts/dmt_apex_playwright_gate.py
  DMT2_UI_PAGES=1,80,82 DMT2_UI_USER=SMOKE DMT2_UI_PASS=... python scripts/dmt_apex_playwright_gate.py

Node/Playwright runtime (not just the python interpreter) must be installed on the
self-hosted runner; see docs/cicd.md.
"""
import json
import os
import subprocess
import sys
import tempfile

BASE = os.environ.get("DMT2_UI_BASE", "http://localhost:8182/ords").rstrip("/")
APP = os.environ.get("DMT2_UI_APP", "r/dmt/livedmt2")
APPID = os.environ.get("DMT2_UI_APPID", "501")
USER = os.environ.get("DMT2_UI_USER")
PASS = os.environ.get("DMT2_UI_PASS")
PAGES = [p.strip() for p in os.environ.get("DMT2_UI_PAGES", "1,80").split(",") if p.strip()]
# Reuse the same Playwright install playwright_verify.js uses (no second download).
PW_NODE_MODULES = os.environ.get(
    "DMT2_PW_NODE_MODULES",
    r"C:\Users\Monroe\workspace\fusion-config-migrator\node_modules",
)

# The browser driving happens in a small Node program (Playwright is a Node
# library; there is no supported in-tree Python Playwright here). We generate it,
# run it with `node`, and read back a JSON verdict. Keeping the browser logic in
# Node also means this gate stays byte-compatible with playwright_verify.js's
# login/session handling, which is the proven path for this app.
NODE_TEMPLATE = r"""
const path = require('path');
const PW = path.join(process.env.DMT2_PW_NODE_MODULES, 'playwright');
const { chromium } = require(PW);

const BASE = process.env.DMT2_UI_BASE;
const APP = process.env.DMT2_UI_APP;
const APPID = process.env.DMT2_UI_APPID;
const USER = process.env.DMT2_UI_USER;
const PASS = process.env.DMT2_UI_PASS;
const PAGES = (process.env.DMT2_UI_PAGES || '1,80').split(',').map(s => s.trim()).filter(Boolean);

// visible APEX error markers (same spirit as dmt_apex_smoke.py ERROR_MARKERS) —
// this app legitimately shows ORA- text as DATA, so we only fail on error
// containers / known breakage strings, not a bare ORA- anywhere on the page.
const ERROR_RE = /Error during rendering of region|Contact your application administrator|Session state protection violation|The checksum computed|Unable to find item|No TFM table configuration found/i;

(async () => {
  const out = { ok: true, steps: [] };
  const step = (name, ok, detail) => {
    out.steps.push({ name, ok, detail: (detail || '').slice(0, 200) });
    if (!ok) out.ok = false;
  };
  const browser = await chromium.launch({ headless: true });
  const ctx = await browser.newContext({ ignoreHTTPSErrors: true });
  const page = await ctx.newPage();
  try {
    // 1. login
    await page.goto(`${BASE}/${APP}/login`, { waitUntil: 'networkidle', timeout: 60000 });
    // Hard-require the login form. Without this, a missing/renamed form would
    // silently fill+click nothing and (if the landing URL has no 'login'
    // substring) FALSE-PASS with zero assertions exercised. Fail loudly instead.
    const userFilled = await page.fill('input[name="P9999_USERNAME"], #P9999_USERNAME', USER)
      .then(() => true).catch(() => false);
    const passFilled = await page.fill('input[name="P9999_PASSWORD"], #P9999_PASSWORD', PASS)
      .then(() => true).catch(() => false);
    if (!userFilled || !passFilled) {
      step('login form present', false, `username=${userFilled} password=${passFilled} url=${page.url()}`);
      console.log(JSON.stringify(out));
      await browser.close();
      return;
    }
    await Promise.all([
      page.waitForNavigation({ waitUntil: 'networkidle', timeout: 60000 }).catch(() => {}),
      page.click('button:has-text("Sign In"), #P9999_LOGIN, button[type="submit"]').catch(() => {}),
    ]);
    // Post-login, the form must be GONE (APEX re-renders P9999_USERNAME on a
    // rejected login even when the friendly URL keeps no 'login' substring).
    const stillLogin = /P9999_USERNAME/.test(await page.content().catch(() => ''));
    const loggedIn = !/login/i.test(page.url()) && !stillLogin;
    step('login', loggedIn, `url=${page.url()} formStillShown=${stillLogin}`);
    // friendly-URL apps mint the session on login; carry the real one forward
    // (passing :0: starts a NEW unauthenticated session — see playwright_verify.js).
    const SESS = (page.url().match(/session=(\d+)/) || [])[1] || '0';
    if (!loggedIn) { out.ok = false; }
    else {
      // 2. assert each requested page renders for the logged-in user
      for (const pg of PAGES) {
        await page.goto(`${BASE}/f?p=${APPID}:${pg}:${SESS}`, { waitUntil: 'networkidle', timeout: 60000 }).catch(() => {});
        const body = await page.locator('body').innerText().catch(() => '');
        const onLogin = /\/login/i.test(page.url()) || /P9999_USERNAME/.test(await page.content().catch(() => ''));
        const err = ERROR_RE.test(body);
        step(`page ${pg} renders`, !onLogin && !err,
             err ? body.slice(0, 160) : `onLogin=${onLogin} len=${body.length}`);
      }
    }
  } catch (e) {
    step('exception', false, String(e));
  } finally {
    await browser.close();
  }
  console.log(JSON.stringify(out));
})();
"""


def main():
    if not USER or not PASS:
        print("FAIL: set DMT2_UI_USER and DMT2_UI_PASS (non-admin smoke account; "
              "creds come from the environment, never hardcoded).")
        sys.exit(2)

    env = dict(os.environ)
    env["DMT2_UI_BASE"] = BASE
    env["DMT2_UI_APP"] = APP
    env["DMT2_UI_APPID"] = APPID
    env["DMT2_UI_USER"] = USER
    env["DMT2_UI_PASS"] = PASS
    env["DMT2_UI_PAGES"] = ",".join(PAGES)
    env["DMT2_PW_NODE_MODULES"] = PW_NODE_MODULES

    with tempfile.NamedTemporaryFile("w", suffix=".js", delete=False, encoding="utf-8") as fh:
        fh.write(NODE_TEMPLATE)
        js_path = fh.name
    try:
        print(f"[playwright-gate] {BASE}/{APP} (app {APPID}) — asserting pages {PAGES} "
              f"for user {USER}")
        p = subprocess.run(["node", js_path], env=env, capture_output=True, text=True)
    finally:
        try:
            os.unlink(js_path)
        except OSError:
            pass

    stdout = (p.stdout or "").strip()
    try:
        result = json.loads(stdout.splitlines()[-1]) if stdout else {"ok": False, "steps": []}
    except (ValueError, IndexError):
        print("[playwright-gate] could not parse node output:")
        print(p.stdout)
        print(p.stderr)
        sys.exit(1)

    for s in result.get("steps", []):
        flag = "ok  " if s.get("ok") else "FAIL"
        print(f"    {flag}  {s.get('name')}: {s.get('detail', '')}")
    if p.stderr.strip():
        print("[playwright-gate] node stderr:\n" + p.stderr.strip()[-800:])

    verdict = "PASS" if result.get("ok") and p.returncode == 0 else "FAIL"
    print(f"[playwright-gate] VERDICT: {verdict}")
    sys.exit(0 if verdict == "PASS" else 1)


if __name__ == "__main__":
    main()
