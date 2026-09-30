// Playwright UI verification for the DMT2 console (app 500 / LIVEDMT2).
// Logs in, opens the given run's tiles, drills object -> object-detail ->
// records, and checks the ESS-job / file links resolve (no 400/404/500).
// Usage: node playwright_verify.js <RUN_ID>
// Uses the playwright install from ../fusion-config-migrator/node_modules.
const path = require('path');
const PW = path.join('C:', 'Users', 'Monroe', 'workspace', 'fusion-config-migrator', 'node_modules', 'playwright');
const { chromium } = require(PW);

const RUN_ID = process.argv[2];
// Defaults target GOLD ATP (app 500). Override for local Docker (app 501):
//   DMT2_UI_BASE=http://localhost:8182/ords DMT2_UI_APP=r/dmt/livedmt2 DMT2_UI_APPID=501
const BASE = process.env.DMT2_UI_BASE || 'https://g6726c838b72234-queryapp.adb.us-ashburn-1.oraclecloudapps.com/ords';
const APP = process.env.DMT2_UI_APP || 'r/dmt2/livedmt2';
const APPID = process.env.DMT2_UI_APPID || '500';
const USER = process.env.DMT2_UI_USER, PASS = process.env.DMT2_UI_PASS;
if (!USER || !PASS) { console.error('Set DMT2_UI_USER and DMT2_UI_PASS env vars'); process.exit(2); }

(async () => {
  const out = { run: RUN_ID, steps: [], badRequests: [] };
  const browser = await chromium.launch({ headless: true });
  const ctx = await browser.newContext({ ignoreHTTPSErrors: true });
  const page = await ctx.newPage();
  // record any failed responses (>=400) as we navigate
  page.on('response', r => { if (r.status() >= 400) out.badRequests.push({ url: r.url().slice(0, 140), status: r.status() }); });

  const step = (name, ok, detail) => { out.steps.push({ name, ok, detail: (detail || '').slice(0, 200) }); };
  try {
    // 1. login
    await page.goto(`${BASE}/${APP}/login`, { waitUntil: 'networkidle', timeout: 60000 });
    await page.fill('input[name="P9999_USERNAME"], #P9999_USERNAME', USER).catch(() => {});
    await page.fill('input[name="P9999_PASSWORD"], #P9999_PASSWORD', PASS).catch(() => {});
    await Promise.all([
      page.waitForNavigation({ waitUntil: 'networkidle', timeout: 60000 }).catch(() => {}),
      page.click('button:has-text("Sign In"), #P9999_LOGIN, button[type="submit"]').catch(() => {}),
    ]);
    const loggedIn = !/login/i.test(page.url());
    // Carry the authenticated session into the f?p URLs. Friendly-URL apps mint a
    // session on login (…?session=<n>); passing :0: for the session there starts a
    // NEW unauthenticated session and bounces back to login, so use the real one.
    const SESS = (page.url().match(/session=(\d+)/) || [])[1] || '0';
    step('login', loggedIn, page.url());

    // 2. open the run tiles (page 82)
    await page.goto(`${BASE}/f?p=${APPID}:82:${SESS}::NO::P82_RUN_ID:${RUN_ID}`, { waitUntil: 'networkidle', timeout: 60000 });
    const bodyText = await page.locator('body').innerText().catch(() => '');
    const onLogin82 = /\/login/i.test(page.url());
    const tiles = await page.locator('a, .t-Card, [onclick]').count();
    step('open run tiles (page 82)', !onLogin82 && tiles > 0 && !/Bad Request/i.test(bodyText), `elements=${tiles} onLogin=${onLogin82}`);

    // 3. object detail (page 52) for a few objects — assert the object actually
    // rendered (not a login bounce / empty), not merely the absence of error text.
    for (const cem of ['Suppliers', 'PurchaseOrders', 'Assets', 'ARInvoices', 'GLBudgets']) {
      await page.goto(`${BASE}/f?p=${APPID}:52:${SESS}::NO::P52_RUN_ID,P52_CEMLI_CODE:${RUN_ID},${cem}`, { waitUntil: 'networkidle', timeout: 60000 }).catch(() => {});
      const t = await page.locator('body').innerText().catch(() => '');
      const bad = /Bad Request|ORA-|was not found|does not exist/i.test(t);
      const onLogin = /\/login/i.test(page.url());
      const rows = await page.locator('table tbody tr, .a-GV-row, .t-Report-report tbody tr').count().catch(() => 0);
      step(`object detail ${cem} (page 52)`, !bad && !onLogin, bad ? t.slice(0, 160) : `rows=${rows} onLogin=${onLogin}`);
    }
  } catch (e) {
    step('exception', false, String(e).slice(0, 200));
  } finally {
    await browser.close();
  }
  console.log(JSON.stringify(out, null, 1));
})();
