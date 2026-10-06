// dmt_console_verify.js — URL-driven Playwright drill of the DMT2 console.
//
// Logs in as the end-user smoke account, visits every real app page, walks the
// full drill chain, and exercises the verify / ESS file-list / download / drill
// action links on those pages. Every navigation asserts HTTP 200 (no >=400
// response for the main document) and no visible APEX error region.
//
// THE ENVIRONMENT SWITCH IS THE BASE URL. Everything is read from env, and the
// Python launcher (dmt_console_verify.py) fills those from the one URL knob in
// scripts/dmt_apex_url_target.py. To retarget from local to ATP you change the
// base URL only; the app id / alias come with it. You can also run this file
// directly by exporting the env vars yourself (see the README).
//
//   DMT2_UI_BASE   ORDS base, no trailing slash   (e.g. http://localhost:8182/ords)
//   DMT2_UI_APP    friendly app path               (e.g. r/dmt/livedmt2)
//   DMT2_UI_APPID  numeric app id                  (e.g. 501)
//   DMT2_UI_USER   end-user login                  (e.g. DMT_SMOKE)
//   DMT2_UI_PASS   password for that user          (never hardcoded)
//   DMT2_UI_RUN    run id to drill                 (optional; a recent run)
//   DMT2_UI_CMP_RUN run id with comparison data    (optional; for page 85)
//   DMT2_UI_CEMLIS comma object codes to drill     (optional)
//   DMT2_PW_NODE_MODULES  path to a node_modules with 'playwright' installed
//
// Credentials come from the environment only — never hardcoded here.
// Exit codes: 0 = all steps passed, 1 = at least one failure, 2 = env missing.

const path = require('path');

const PW_MODULES = process.env.DMT2_PW_NODE_MODULES
  || path.join('C:', 'Users', 'Monroe', 'workspace', 'fusion-config-migrator', 'node_modules');
const { chromium } = require(path.join(PW_MODULES, 'playwright'));

const BASE = (process.env.DMT2_UI_BASE || 'http://localhost:8182/ords').replace(/\/+$/, '');
const APP = (process.env.DMT2_UI_APP || 'r/dmt/livedmt2').replace(/^\/|\/$/g, '');
const APPID = process.env.DMT2_UI_APPID || '501';
const USER = process.env.DMT2_UI_USER;
const PASS = process.env.DMT2_UI_PASS;
const RUN = process.env.DMT2_UI_RUN || '';
const CMP_RUN = process.env.DMT2_UI_CMP_RUN || RUN;
const CEMLIS = (process.env.DMT2_UI_CEMLIS
  || 'Suppliers,PurchaseOrders,GLBalances,Customers,Assets')
  .split(',').map(s => s.trim()).filter(Boolean);

if (!USER || !PASS) {
  console.error('Set DMT2_UI_USER and DMT2_UI_PASS (end-user smoke account; '
    + 'creds come from the environment, never hardcoded).');
  process.exit(2);
}

// This app legitimately DISPLAYS ORA- text as migration DATA, so we only fail
// on APEX error containers / known breakage strings, not a bare ORA- anywhere.
const ERROR_RE = /Error during rendering of region|Contact your application administrator|Session state protection violation|The checksum computed|Unable to find item|No TFM table configuration found|Error processing request/i;
const LOGIN_RE = /P9999_USERNAME/;

// Every real app page (the top navigation + the drill + admin pages). The drill
// chain (80/82/52/57/54/85) and the ESS output pages (53/58) are covered both
// here and again via real in-app links below.
const PAGES = [
  [1, 'Home'], [2, 'P2P'], [3, 'GL'], [4, 'OTC'], [5, 'Projects'],
  [6, 'Workers'], [7, 'Time & Labor'], [8, 'Admin'],
  [9, 'Upload Reference Guide'], [16, 'Lookup Dashboard'],
  [80, 'Run History'], [82, 'Run Detail'], [85, 'Run Comparison'],
  [52, 'Object Detail'], [53, 'ESS Job Detail'], [54, 'Activity Log'],
  [57, 'Record Detail'], [58, 'ESS Job Output'], [84, 'Run Pipeline'],
];

(async () => {
  const out = { target: `${BASE}/${APP} (app ${APPID})`, run: RUN, steps: [], badRequests: [] };
  let ok = true;
  const step = (name, passed, detail) => {
    out.steps.push({ name, ok: passed, detail: (detail || '').slice(0, 220) });
    if (!passed) ok = false;
  };

  const browser = await chromium.launch({ headless: true });
  const ctx = await browser.newContext({ ignoreHTTPSErrors: true });
  const page = await ctx.newPage();
  // Record any >=400 response for the main document URLs we drive. (Static asset
  // 404s are noise; we only flag document responses whose status >= 400.)
  const docBad = [];
  page.on('response', r => {
    if (r.status() >= 400 && r.request().resourceType() === 'document') {
      docBad.push({ url: r.url().slice(0, 140), status: r.status() });
    }
  });

  // Navigation wait strategy — do NOT hinge on `networkidle` or even
  // `domcontentloaded`. Some pages (e.g. Admin, page 8) keep a request pending
  // (long-poll / keep-alive) that prevents the browser from ever reaching the
  // `networkidle` state AND prevents the `DOMContentLoaded` event from firing,
  // so both of those waits false-fail at the 60s timeout even though the server
  // returns the page (HTTP 200) in ~3 seconds and the content paints right
  // away. Instead we navigate with `commit` (resolves as soon as the server
  // responds with the document) and then wait, bounded, for the main APEX
  // content region to become visible. That settle completes on a healthy page.
  // The region wait is NOT itself the pass/fail signal; the real assertions
  // below (HTTP 200, content rendered, no error region, not bounced to login)
  // do the judging, so a genuinely broken or blank page still fails.
  const CONTENT_SEL = '#t_Body_content, .t-Body-contentInner, .t-Body-main, .t-Region, #wwvFlowForm';
  async function settle(timeout = 25000) {
    await page.locator(CONTENT_SEL).first()
      .waitFor({ state: 'visible', timeout }).catch(() => {});
  }

  // visit a URL, assert 200 + content region rendered + no error region + not
  // bounced to login.
  async function visit(label, url) {
    docBad.length = 0;
    let status = 0;
    try {
      const resp = await page.goto(url, { waitUntil: 'commit', timeout: 60000 });
      status = resp ? resp.status() : 0;
      await settle();
    } catch (e) {
      step(label, false, 'navigation error: ' + String(e));
      return { ok: false, body: '' };
    }
    const body = await page.locator('body').innerText().catch(() => '');
    const html = await page.content().catch(() => '');
    const onLogin = /\/login/i.test(page.url()) || LOGIN_RE.test(html);
    const errRegion = ERROR_RE.test(body);
    // A healthy APEX page paints a main content region. Require it so a blank
    // or half-broken page (document 200 but nothing rendered) still fails even
    // though we no longer wait on networkidle.
    const contentRendered = await page.locator(CONTENT_SEL).first()
      .isVisible().catch(() => false);
    const http200 = status === 200 && docBad.length === 0;
    const passed = http200 && !onLogin && !errRegion && contentRendered;
    step(label, passed,
      passed ? `HTTP ${status} len=${body.length}`
        : `HTTP ${status} onLogin=${onLogin} errRegion=${errRegion} content=${contentRendered} `
          + (docBad.length ? `bad=${JSON.stringify(docBad[0])} ` : '')
          + (errRegion ? body.slice(0, 120) : ''));
    return { ok: passed, body, html };
  }

  try {
    // ---- 1. login as the end-user smoke account --------------------------
    await page.goto(`${BASE}/${APP}/login`, { waitUntil: 'commit', timeout: 60000 });
    await page.locator('#P9999_USERNAME').first()
      .waitFor({ state: 'visible', timeout: 25000 }).catch(() => {});
    // The login page can arrive pre-filled by the browser credential manager,
    // so clear each field before filling and then VERIFY the value stuck (a
    // stale autofill is the classic cause of a silent login rejection).
    const uBox = page.locator('#P9999_USERNAME');
    const pBox = page.locator('#P9999_PASSWORD');
    const formPresent = await uBox.count().then(c => c > 0).catch(() => false);
    if (!formPresent) {
      step('login form present', false, `url=${page.url()}`);
      console.log(JSON.stringify(out, null, 1));
      await browser.close();
      process.exit(1);
    }
    await uBox.fill('');
    await uBox.fill(USER);
    await pBox.fill('');
    await pBox.fill(PASS);
    const uVal = await uBox.inputValue().catch(() => '');
    step('login form filled', uVal === USER, `username field=${uVal}`);

    // The APEX "Sign In" button runs apex.submit('LOGIN') via the client JS
    // bundle (/i/.../desktop_all.min.js). Give that bundle a moment to attach,
    // then submit the APEX way if it is loaded, else fall back to clicking the
    // button / pressing Enter. Finally wait for the URL to leave /login.
    const apexReady = await page
      .waitForFunction(() => window.apex && typeof window.apex.submit === 'function',
                       null, { timeout: 15000 })
      .then(() => true).catch(() => false);
    await Promise.all([
      page.waitForURL(u => !/\/login/i.test(String(u)), { timeout: 60000 }).catch(() => {}),
      (async () => {
        if (apexReady) {
          await page.evaluate(() => window.apex.submit('LOGIN')).catch(() => {});
        } else {
          await page.locator('button:has-text("Sign In"), button[type="submit"]')
            .first().click().catch(async () => { await pBox.press('Enter').catch(() => {}); });
        }
      })(),
    ]);
    // Post-submit, wait for the authenticated landing page to paint its main
    // content region rather than networkidle (the home page keeps a connection
    // open, so networkidle would burn the full timeout).
    await page.locator(CONTENT_SEL).first()
      .waitFor({ state: 'visible', timeout: 25000 }).catch(() => {});
    const stillLogin = LOGIN_RE.test(await page.content().catch(() => ''));
    const loggedIn = !/login/i.test(page.url()) && !stillLogin;
    // If login never submitted AND the APEX client JS never loaded, the likely
    // cause is the ORDS static file server returning 500 for /i/ assets (an
    // instance/infra problem, not a script bug) — surface that explicitly.
    const diag = loggedIn ? ''
      : (apexReady ? 'apex JS loaded but login was rejected (check credentials)'
         : 'APEX client JS (/i/ assets) did not load — likely ORDS static-file '
           + '500s on this instance; the no-browser HTTP smoke is the local proof');
    step('login', loggedIn, `url=${page.url()} formStillShown=${stillLogin} ${diag}`);
    // Friendly-URL apps mint the session on login; carry the real one into the
    // f?p URLs (passing :0: starts a NEW unauthenticated session -> bounce).
    const SESS = (page.url().match(/session=(\d+)/) || [])[1] || '0';
    const fp = (pg, items, vals) =>
      `${BASE}/f?p=${APPID}:${pg}:${SESS}::NO::` + (items ? `${items}:${vals}` : '');

    if (!loggedIn) { throw new Error('login failed; skipping sweep'); }

    // ---- 2. every real app page renders ----------------------------------
    for (const [pg, name] of PAGES) {
      await visit(`page ${pg} (${name})`, fp(pg));
    }

    // ---- 3. walk the drill chain with real keyed URLs --------------------
    // run history 80 -> run detail 82 -> object detail 52 -> record detail 57
    //   -> activity log 54, plus run comparison 85.
    if (RUN) {
      await visit(`drill: run detail 82 [run ${RUN}]`, fp(82, 'P82_RUN_ID', RUN));
      await visit(`drill: activity log 54 [run ${RUN}]`, fp(54, 'P54_RUN_ID', RUN));
      for (const cem of CEMLIS) {
        const r = await visit(`drill: object detail 52 [${cem} run ${RUN}]`,
          fp(52, 'P52_RUN_ID,P52_CEMLI_CODE', `${RUN},${cem}`));
        if (!r.ok) continue;
        // object detail 52 -> ESS job detail 53 and record detail 57
        await visit(`drill: ESS job detail 53 [${cem} run ${RUN}]`,
          fp(53, 'P53_RUN_ID,P53_CEMLI_CODE', `${RUN},${cem}`));
        await visit(`drill: ESS job output 58 [${cem} run ${RUN}]`,
          fp(58, 'P53_RUN_ID,P53_CEMLI_CODE', `${RUN},${cem}`));
        for (const st of ['LOADED', 'FAILED']) {
          await visit(`drill: record detail 57 [${cem} ${st} run ${RUN}]`,
            fp(57, 'P57_RUN_ID,P57_SUB_OBJECT,P57_STATUS', `${RUN},${cem},${st}`));
        }
      }
    } else {
      step('drill chain', true, 'no DMT2_UI_RUN given — drill chain skipped (page sweep still ran)');
    }
    if (CMP_RUN) {
      await visit(`drill: run comparison 85 [run ${CMP_RUN}]`, fp(85, 'P85_RUN_ID', CMP_RUN));
    }

    // ---- 4. exercise the verify / action links -----------------------------
    // (a) the run-scoped reconcile read-back on page 82. This control is GATED
    //     BY RUN CONTEXT: it only renders once a run is selected. With no run,
    //     page 82 renders an empty shell (~157 bytes, no run-scoped links); with
    //     the run carried in (the way the drill navigates), page 82 paints the
    //     run header whose read-back action links reconcile the run's outcome —
    //     "View run comparison report for this run" (the per-run reconciliation
    //     read-back, page 85) and "View activity log for this run" (page 54).
    //     We navigate page 82 WITH the run, assert those run-scoped read-back
    //     links render, then FOLLOW the run-comparison read-back and assert it
    //     resolves (HTTP 200, no APEX error region). Exercising it context-less
    //     would see zero controls — that was the old false failure.
    if (RUN) {
      const rd = await visit(`verify link: run-scoped reconcile read-back on run detail 82 [run ${RUN}]`,
        fp(82, 'P82_RUN_ID', RUN));
      if (rd.ok) {
        // The run header renders two run-scoped read-back action links; both
        // carry this run id. They are absent on the context-less page 82.
        const links = await page.evaluate((runId) => {
          const as = Array.from(document.querySelectorAll('a[href]'));
          const carries = (a) => a.href.includes('run_id=' + runId)
            || a.href.includes(':' + runId) || a.href.includes('=' + runId);
          const cmp = as.find(a => /comparison report for this run/i.test(a.textContent) && carries(a));
          const act = as.find(a => /activity log for this run/i.test(a.textContent) && carries(a));
          return {
            cmpHref: cmp ? cmp.href : '',
            actHref: act ? act.href : '',
          };
        }, RUN).catch(() => ({ cmpHref: '', actHref: '' }));
        const haveReadBack = !!(links.cmpHref && links.actHref);
        step('verify link: reconcile read-back controls render on run detail 82',
          haveReadBack,
          `comparison-read-back=${!!links.cmpHref} activity-log-read-back=${!!links.actHref}`);
        // Follow the run-comparison read-back (the per-run reconciliation view)
        // and assert it actually resolves for this run.
        if (links.cmpHref) {
          await visit(`verify link: run-comparison reconcile read-back resolves [run ${RUN}]`,
            links.cmpHref);
        }
        // Optional destructive re-run (left for parity with the newer app build
        // that exposes a "Re-run reconcile" button; the installed app reconciles
        // on run, so there is nothing to re-submit here).
        if (process.env.DMT2_UI_CLICK_VERIFY === '1') {
          const reBtn = await page.locator(
            'button:has-text("Re-run reconcile"), [id*="RERUN_RECONCILE"]').count().catch(() => 0);
          if (reBtn > 0) {
            await page.goto(fp(82, 'P82_RUN_ID', RUN), { waitUntil: 'commit', timeout: 60000 }).catch(() => {});
            await settle();
            await page.locator('button:has-text("Re-run reconcile"), [id*="RERUN_RECONCILE"]').first().click().catch(() => {});
            await settle();
            const body = await page.locator('body').innerText().catch(() => '');
            step('verify link: reconcile action completes', !ERROR_RE.test(body), body.slice(0, 120));
          }
        }
      }
    }

    // (b) the ESS file-list AJAX read-back (page 58 "Fetch File List from
    //     Fusion" -> APPLICATION_PROCESS DOWNLOAD_ESS_FILE_V2 action=LIST).
    //     We call the LIST action over the authenticated session and assert a
    //     200 JSON response with no error key — this is the real "verify the
    //     ESS output" read link exercised headlessly.
    if (RUN) {
      const listUrl = `${BASE}/wwv_flow.show?p_flow_id=${APPID}`
        + `&p_flow_step_id=58&p_instance=${SESS}`
        + `&p_request=APPLICATION_PROCESS%3DDOWNLOAD_ESS_FILE_V2`
        + `&x01=${encodeURIComponent(RUN)}&x03=LIST`;
      const res = await page.evaluate(async (u) => {
        try {
          const r = await fetch(u, { credentials: 'include' });
          const t = await r.text();
          return { status: r.status, body: t.slice(0, 300) };
        } catch (e) { return { status: -1, body: String(e) }; }
      }, listUrl).catch(e => ({ status: -1, body: String(e) }));
      // A healthy response is HTTP 200 JSON. An "error" key means the process
      // itself threw; absence of a hard error is the pass condition here (the
      // request id may legitimately have no cached files).
      const healthy = res.status === 200 && !/"error"\s*:/.test(res.body);
      step('verify link: ESS file-list read-back (page 58 LIST action)', healthy,
        `HTTP ${res.status} ${res.body.slice(0, 120)}`);
    }

    // (c) the in-app drill hyperlinks actually resolve: scrape Run History (80)
    //     for its real checksummed f?p / friendly links and follow the first
    //     few, asserting each renders 200 with no error region. This exercises
    //     the app's OWN links (with live checksums), not just synthesized URLs.
    const hist = await visit('page 80 (Run History) for link scrape', fp(80));
    if (hist.ok) {
      const html = hist.html || '';
      const hrefs = Array.from(html.matchAll(/href="([^"]*f\?p=[^"]+)"/gi))
        .map(m => m[1].replace(/&amp;/g, '&'))
        .filter(h => /:(52|57|82|85|54|53|58):/.test(h))
        .slice(0, 6);
      if (hrefs.length === 0) {
        step('in-app drill links present on Run History', true,
          'no drill hyperlinks found (run list may be empty) — not a failure');
      } else {
        let good = 0;
        for (const h of hrefs) {
          const u = h.startsWith('http') ? h : `${BASE}/${h.replace(/^\/?ords\//, '').replace(/^\//, '')}`;
          const r = await visit(`in-app drill link ${h.match(/:(\d+):/) ? h.match(/f\?p=\d+:(\d+)/)[1] : '?'}`, u);
          if (r.ok) good++;
        }
        step('in-app drill hyperlinks resolve', good === hrefs.length,
          `${good}/${hrefs.length} followed clean`);
      }
    }
  } catch (e) {
    step('exception', false, String(e));
  } finally {
    await browser.close();
  }

  const fails = out.steps.filter(s => !s.ok);
  out.verdict = (ok && fails.length === 0) ? 'PASS' : 'FAIL';
  console.log(JSON.stringify(out, null, 1));
  process.exit(out.verdict === 'PASS' ? 0 : 1);
})();
