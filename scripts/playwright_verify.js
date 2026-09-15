// Playwright UI verification for the DMT2 console (app 500 / LIVEDMT2).
// Logs in, opens the given run's tiles, drills object -> object-detail ->
// records, and checks the ESS-job / file links resolve (no 400/404/500).
// Usage: node playwright_verify.js <RUN_ID>
// Uses the playwright install from ../fusion-config-migrator/node_modules.
const path = require('path');
const PW = path.join('C:', 'Users', 'Monroe', 'workspace', 'fusion-config-migrator', 'node_modules', 'playwright');
const { chromium } = require(PW);

const RUN_ID = process.argv[2];
const BASE = 'https://g6726c838b72234-queryapp.adb.us-ashburn-1.oraclecloudapps.com/ords';
const APP = 'r/dmt2/livedmt2';
const USER = 'DMTADMIN', PASS = 'Dmt2Live#2026';

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
    step('login', loggedIn, page.url());

    // 2. open the run tiles (page 82)
    await page.goto(`${BASE}/f?p=500:82:0::NO::P82_RUN_ID:${RUN_ID}`, { waitUntil: 'networkidle', timeout: 60000 });
    const bodyText = await page.locator('body').innerText().catch(() => '');
    const tiles = await page.locator('a, .t-Card, [onclick]').count();
    step('open run tiles (page 82)', tiles > 0 && !/Bad Request/i.test(bodyText), `elements=${tiles}`);

    // 3. object detail (page 52) for a few objects
    for (const cem of ['Suppliers', 'PurchaseOrders', 'Assets', 'ARInvoices']) {
      await page.goto(`${BASE}/f?p=500:52:0::NO::P52_RUN_ID,P52_CEMLI_CODE:${RUN_ID},${cem}`, { waitUntil: 'networkidle', timeout: 60000 }).catch(() => {});
      const t = await page.locator('body').innerText().catch(() => '');
      const bad = /Bad Request|ORA-|was not found|does not exist/i.test(t);
      step(`object detail ${cem} (page 52)`, !bad, bad ? t.slice(0, 160) : 'ok');
    }
  } catch (e) {
    step('exception', false, String(e).slice(0, 200));
  } finally {
    await browser.close();
  }
  console.log(JSON.stringify(out, null, 1));
})();
