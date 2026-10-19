// dmt_upload_verify.js — browser half of the upload test (backlog #786).
//
// Driven by test/playwright/dmt_upload_verify.py, which builds the upload files,
// checks what landed in staging, runs the pipeline and judges every row. This
// script does only what a person does in the browser, in a real Chromium:
//
//   1. sign in as the end-user smoke account (same login as dmt_console_verify.js),
//   2. page 14 (Scenario Management): Create Scenario -> type the new scenario
//      name -> Save,
//   3. page 25 (Smart Upload): choose "Auto-detect by Filename", pick that
//      scenario, attach the file (setInputFiles), press Upload, and read back the
//      message the page shows and the batch id it stored.
//
// Input (environment, filled by the Python launcher from the one URL knob in
// scripts/dmt_apex_url_target.py; credentials are never hardcoded):
//   DMT2_UI_BASE, DMT2_UI_APP, DMT2_UI_APPID, DMT2_UI_USER, DMT2_UI_PASS
//   DMT2_PW_NODE_MODULES  node_modules folder that has 'playwright'
//   DMT2_UPL_JOBS         JSON file: [{ "scenario": "...", "description": "...",
//                                       "file": "C:/.../UPL-HDR-2610191200.zip" }]
//                         (several jobs run in one browser session, e.g. the negative tests)
//   DMT2_UPL_SHOTS        folder for a screenshot after each upload (optional)
// Output: one JSON object on stdout: { login, jobs: [{ scenario, scenarioCreated,
//   scenarioMessage, uploaded, successMessage, errorMessage, batchId, shot }] }.
// Exit codes: 0 = every job uploaded without an error message, 1 = otherwise,
// 2 = environment missing.

const fs = require('fs');
const path = require('path');

const PW_MODULES = process.env.DMT2_PW_NODE_MODULES
  || path.join('C:', 'Users', 'Monroe', 'workspace', 'fusion-config-migrator', 'node_modules');
const { chromium } = require(path.join(PW_MODULES, 'playwright'));

const BASE = (process.env.DMT2_UI_BASE || 'http://localhost:8182/ords').replace(/\/+$/, '');
const APP = (process.env.DMT2_UI_APP || 'r/dmt/livedmt2').replace(/^\/|\/$/g, '');
const APPID = process.env.DMT2_UI_APPID || '501';
const USER = process.env.DMT2_UI_USER;
const PASS = process.env.DMT2_UI_PASS;
const JOBS_FILE = process.env.DMT2_UPL_JOBS;
const SHOTS = process.env.DMT2_UPL_SHOTS || '';

if (!USER || !PASS || !JOBS_FILE) {
  console.error('Set DMT2_UI_USER, DMT2_UI_PASS and DMT2_UPL_JOBS (credentials come '
    + 'from the environment, never hardcoded).');
  process.exit(2);
}

const NAV_TIMEOUT_MS = 90000;
const LOGIN_RE = /P9999_USERNAME/;

(async () => {
  const jobs = JSON.parse(fs.readFileSync(JOBS_FILE, 'utf-8'));
  const out = { target: `${BASE}/${APP} (app ${APPID})`, login: null, jobs: [] };
  const browser = await chromium.launch({ headless: true });
  const ctx = await browser.newContext({ ignoreHTTPSErrors: true });
  const page = await ctx.newPage();
  page.setDefaultTimeout(NAV_TIMEOUT_MS);

  // Text of the APEX success message / error notification currently shown.
  async function pageMessages() {
    return page.evaluate(() => {
      const t = sel => Array.from(document.querySelectorAll(sel))
        .map(e => (e.innerText || '').replace(/\s+/g, ' ').trim()).filter(Boolean).join(' | ');
      return {
        success: t('#APEX_SUCCESS_MESSAGE .t-Alert-content, #APEX_SUCCESS_MESSAGE .t-Alert-title, .t-Alert--success .t-Alert-body'),
        error: t('#APEX_ERROR_MESSAGE .t-Alert-content, #APEX_ERROR_MESSAGE li, .a-Notification-item, .t-Alert--danger .t-Alert-body, .t-Form-error'),
      };
    }).catch(() => ({ success: '', error: '' }));
  }

  async function waitApex() {
    await page.waitForFunction(() => window.apex && window.apex.item && document.readyState === 'complete',
      null, { timeout: NAV_TIMEOUT_MS }).catch(() => {});
  }

  try {
    // ---- 1. sign in (same flow as dmt_console_verify.js) -------------------
    await page.goto(`${BASE}/${APP}/login`, { waitUntil: 'commit', timeout: NAV_TIMEOUT_MS });
    await page.locator('#P9999_USERNAME').first().waitFor({ state: 'visible' });
    await page.locator('#P9999_USERNAME').fill('');
    await page.locator('#P9999_USERNAME').fill(USER);
    await page.locator('#P9999_PASSWORD').fill('');
    await page.locator('#P9999_PASSWORD').fill(PASS);
    await waitApex();
    await Promise.all([
      page.waitForURL(u => !/\/login/i.test(String(u)), { timeout: NAV_TIMEOUT_MS }).catch(() => {}),
      page.evaluate(() => window.apex.submit('LOGIN')).catch(() => {}),
    ]);
    await waitApex();
    const loggedIn = !/\/login/i.test(page.url()) && !LOGIN_RE.test(await page.content().catch(() => ''));
    out.login = { ok: loggedIn, url: page.url().replace(/session=\d+/, 'session=…') };
    if (!loggedIn) throw new Error('login failed');
    const SESS = (page.url().match(/session=(\d+)/) || [])[1] || '0';
    const fp = pg => `${BASE}/f?p=${APPID}:${pg}:${SESS}::NO:::`;

    for (const job of jobs) {
      const r = { scenario: job.scenario, file: path.basename(job.file), scenarioCreated: false,
                  scenarioMessage: '', uploaded: false, successMessage: '', errorMessage: '',
                  batchId: null, shot: null };
      out.jobs.push(r);
      try {
        // ---- 2. page 14: create the scenario --------------------------------
        await page.goto(fp(14), { waitUntil: 'commit' });
        await waitApex();
        await page.getByRole('button', { name: 'Create Scenario' }).first().click();
        await page.locator('#P14_SCENARIO_NAME').waitFor({ state: 'visible' });
        await page.locator('#P14_SCENARIO_NAME').fill(job.scenario);
        if (job.description) await page.locator('#P14_DESCRIPTION').fill(job.description);
        await Promise.all([
          page.waitForEvent('load', { timeout: NAV_TIMEOUT_MS }).catch(() => {}),
          page.getByRole('button', { name: 'Save', exact: true }).first().click(),
        ]);
        await waitApex();
        const m14 = await pageMessages();
        r.scenarioMessage = m14.error || m14.success;
        r.scenarioCreated = /saved successfully/i.test(m14.success) && !m14.error;
        if (!r.scenarioCreated) throw new Error(`scenario not created: ${r.scenarioMessage}`);

        // ---- 3. page 25: upload the file into that scenario -----------------
        await page.goto(fp(25), { waitUntil: 'commit' });
        await waitApex();
        // Upload Mode = Auto-detect by Filename (the page routes by file name).
        await page.locator('input[name="P25_UPLOAD_MODE"][value="AUTO"]').check({ force: true });
        const mode = await page.evaluate(() => window.apex.item('P25_UPLOAD_MODE').getValue());
        if (mode !== 'AUTO') throw new Error(`upload mode not set (got ${mode})`);
        // Scenario: the new scenario must be in the list (it only lists ACTIVE ones).
        await page.locator('#P25_SCENARIO').selectOption({ label: job.scenario });
        const scen = await page.evaluate(() => window.apex.item('P25_SCENARIO').getValue());
        if (scen !== job.scenario) throw new Error(`scenario not selected (got ${scen})`);
        // The file item: APEX renders a real <input type=file> for P25_UPLOAD_FILE.
        const fileInput = page.locator('#P25_UPLOAD_FILE_CONTAINER input[type="file"], input[type="file"]#P25_UPLOAD_FILE').first();
        await fileInput.setInputFiles(job.file);
        await Promise.all([
          page.waitForEvent('load', { timeout: 600000 }).catch(() => {}),
          page.getByRole('button', { name: 'Upload', exact: true }).first().click(),
        ]);
        await waitApex();
        const m25 = await pageMessages();
        r.successMessage = m25.success;
        r.errorMessage = m25.error;
        r.batchId = await page.evaluate(() => {
          const e = document.getElementById('P25_LAST_BATCH_ID');
          return e ? (e.value || null) : null;
        }).catch(() => null);
        r.uploaded = !!m25.success && !m25.error;
      } catch (e) {
        r.errorMessage = (r.errorMessage ? r.errorMessage + ' | ' : '') + String(e.message || e).slice(0, 400);
      }
      if (SHOTS) {
        r.shot = path.join(SHOTS, `${job.scenario}.png`);
        await page.screenshot({ path: r.shot, fullPage: true }).catch(() => { r.shot = null; });
      }
    }
  } catch (e) {
    out.fatal = String(e.message || e).slice(0, 400);
  }
  await browser.close();
  console.log(JSON.stringify(out, null, 1));
  const ok = out.login && out.login.ok && out.jobs.length === jobs.length
    && out.jobs.every(j => j.uploaded);
  process.exit(ok ? 0 : 1);
})();
