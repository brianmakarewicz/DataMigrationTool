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
//   DMT2_UI_ACTIVE_RUN a QUEUED/IN_PROGRESS run id (optional; Cancel form check)
//   DMT2_UI_EXPECT_ADMIN '1' when DMT2_UI_USER is an administrator (optional;
//                  the Cancel form is admin-only, backlog #722, so a non-admin
//                  such as DMT_SMOKE must NOT see it on an active run)
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
const ACTIVE_RUN = process.env.DMT2_UI_ACTIVE_RUN || '';
const EXPECT_ADMIN = process.env.DMT2_UI_EXPECT_ADMIN === '1';
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
  // so both of those waits false-fail even though the server returns the page
  // (HTTP 200) in ~3 seconds. We navigate with `commit` (resolves as soon as
  // the server responds with the document) and then WAIT FOR THE CONTENT
  // ITSELF (waitForContent below): poll the main content region until it
  // holds real text, no APEX "processing" spinner is showing, and the text
  // length has stopped changing for a moment. That replaced an earlier wait
  // that returned as soon as an (empty) region container became visible,
  // which let the script judge pages before their reports had rendered — e.g.
  // Run History was measured at ~900 characters with no rows, so its drill
  // links were never found. The wait is NOT the pass/fail signal; visit()
  // judges the page on what is actually there once the wait ends.
  const CONTENT_SEL = '#t_Body_content, .t-Body-contentInner, .t-Body-main, .t-Region, #wwvFlowForm';
  const CONTENT_TIMEOUT_MS = 60000;  // longest we wait for a page's content
  const STABLE_MS = 1000;            // text length unchanged this long = rendered
  // Nearly-empty threshold: characters of real text in the main content
  // region, after removing the text of <select> dropdowns (a filter list of
  // scenario names is not page content). A healthy page here has 100+; an
  // APEX shell that rendered only its footer ("Release 1.0") has ~11. The
  // sparsest legitimate page is Run Detail with no run selected (~100 chars:
  // "Run not found." plus its two read-back links). Fixed on purpose — not an
  // env knob, so it can never be turned down to make an empty page pass.
  const MIN_CONTENT_CHARS = 40;
  // ORDS answers HTTP 572 when its connection pool is exhausted (overloaded).
  // Retry such a navigation exactly once after a pause; a second 572 fails.
  const ORDS_OVERLOADED = 572;
  const RETRY_572_DELAY_MS = 15000;

  // Read the current state of the page from inside the browser.
  async function probe() {
    return page.evaluate(({ sel, errSrc, loginSrc }) => {
      const region = document.querySelector('#t_Body_content')
        || document.querySelector(sel);
      let text = region ? (region.innerText || '') : '';
      if (region) {
        for (const s of region.querySelectorAll('select')) {
          const st = s.innerText || '';
          if (st) text = text.replace(st, '');
        }
      }
      text = text.replace(/\s+/g, ' ').trim();
      const bodyText = document.body ? (document.body.innerText || '') : '';
      const busy = Array.from(document.querySelectorAll('.u-Processing, .a-IRR-loader, .a-GV-loadingIndicator'))
        .some(e => e.offsetParent !== null);
      return {
        hasRegion: !!region,
        len: text.length,
        busy,
        error: new RegExp(errSrc, 'i').test(bodyText),
        login: new RegExp(loginSrc).test(document.documentElement.outerHTML),
      };
    }, { sel: CONTENT_SEL, errSrc: ERROR_RE.source, loginSrc: LOGIN_RE.source })
      .catch(() => null);   // context destroyed mid-navigation: poll again
  }

  // Wait until the page's content has actually rendered (or an error / login
  // page is showing, which visit() then reports). Returns the last probe plus
  // settled=true/false and how long it took.
  async function waitForContent(timeoutMs = CONTENT_TIMEOUT_MS) {
    const t0 = Date.now();
    let last = null, lastLen = -1, stableSince = 0;
    while (Date.now() - t0 < timeoutMs) {
      const s = await probe();
      if (s) {
        last = s;
        if (s.error || s.login) return { ...s, settled: true, waitedMs: Date.now() - t0 };
        if (s.hasRegion && s.len >= MIN_CONTENT_CHARS && !s.busy) {
          if (s.len !== lastLen) { lastLen = s.len; stableSince = Date.now(); }
          else if (Date.now() - stableSince >= STABLE_MS) {
            return { ...s, settled: true, waitedMs: Date.now() - t0 };
          }
        } else {
          lastLen = -1;
        }
      }
      await page.waitForTimeout(250);
    }
    return { ...(last || { hasRegion: false, len: 0, busy: false, error: false, login: false }),
             settled: false, waitedMs: Date.now() - t0 };
  }

  // Navigate; on HTTP 572 (ORDS overloaded) wait and retry exactly once.
  async function gotoWithRetry(url) {
    docBad.length = 0;
    let resp = await page.goto(url, { waitUntil: 'commit', timeout: 60000 });
    let status = resp ? resp.status() : 0;
    let retried = false;
    if (status === ORDS_OVERLOADED) {
      retried = true;
      await page.waitForTimeout(RETRY_572_DELAY_MS);
      docBad.length = 0;   // judge only the retry's responses
      resp = await page.goto(url, { waitUntil: 'commit', timeout: 60000 });
      status = resp ? resp.status() : 0;
    }
    return { status, retried };
  }

  // visit a URL and judge it: HTTP 200, content rendered and not nearly empty,
  // no APEX error region, not bounced to login, and (if given) the page text
  // matches opts.mustMatch.
  async function visit(label, url, opts = {}) {
    let status = 0, retried = false, w;
    try {
      ({ status, retried } = await gotoWithRetry(url));
      // Only a 200 document can render content; an error status fails below
      // without burning the content timeout.
      w = status === 200 ? await waitForContent()
        : { hasRegion: false, len: 0, busy: false, settled: true, waitedMs: 0 };
    } catch (e) {
      step(label, false, 'navigation error: ' + String(e).split('\n')[0]);
      // Park the tab on a blank page so a half-finished navigation (e.g. a
      // Chromium error page still loading) cannot interrupt the NEXT page and
      // make every later page fail for this page's reason.
      await page.goto('about:blank').catch(() => {});
      return { ok: false, body: '' };
    }
    const body = await page.locator('body').innerText().catch(() => '');
    const html = await page.content().catch(() => '');
    const onLogin = /\/login/i.test(page.url()) || LOGIN_RE.test(html);
    const errRegion = ERROR_RE.test(body);
    // A healthy APEX page paints a main content region with real text in it.
    const contentRendered = await page.locator(CONTENT_SEL).first()
      .isVisible().catch(() => false);
    const nearlyEmpty = !w.hasRegion || w.len < MIN_CONTENT_CHARS;
    const matchOk = !opts.mustMatch || opts.mustMatch.test(body);
    const http200 = status === 200 && docBad.length === 0;
    const passed = http200 && !onLogin && !errRegion && contentRendered
      && !nearlyEmpty && matchOk;
    const notes = (retried ? 'retried once after HTTP 572; ' : '')
      + (w.settled ? ''
        : (nearlyEmpty ? `no content after waiting ${Math.round(w.waitedMs / 1000)}s; `
          : `content still changing after ${Math.round(w.waitedMs / 1000)}s; `));
    step(label, passed,
      passed ? `${notes}HTTP ${status} content=${w.len} chars len=${body.length} in ${w.waitedMs}ms`
        : `${notes}HTTP ${status} onLogin=${onLogin} errRegion=${errRegion} content=${contentRendered} `
          + (nearlyEmpty ? `NEARLY EMPTY (${w.len} chars of content, need ${MIN_CONTENT_CHARS}) ` : '')
          + (!matchOk ? `expected text ${opts.mustMatch} not found ` : '')
          + (docBad.length ? `bad=${JSON.stringify(docBad[0])} ` : '')
          + (errRegion ? body.slice(0, 120) : ''));
    return { ok: passed, body, html };
  }

  // Which run-action controls the current page 82 shows. The Cancel button
  // carries the DOM id P82_CANCEL_RUN_BTN; its form has a reason field and a
  // confirmation checkbox (no JavaScript confirm dialog).
  async function runDetailActions() {
    return page.evaluate(() => {
      const visible = (el) => !!el && el.offsetParent !== null;
      const btn = (re) => Array.from(document.querySelectorAll('button'))
        .some(b => re.test(b.textContent || '') && visible(b));
      return {
        rerun: btn(/Re-run reconcile/i),
        back: btn(/Run History/i),
        cancel: visible(document.getElementById('P82_CANCEL_RUN_BTN')),
        reason: !!document.getElementById('P82_CANCEL_REASON'),
        confirm: !!document.querySelector('[id^="P82_CANCEL_CONFIRM"]'),
      };
    }).catch(() => ({ rerun: false, back: false, cancel: false, reason: false, confirm: false }));
  }

  try {
    // ---- 1. login as the end-user smoke account --------------------------
    // One login attempt. Returns { loggedIn, stillLogin, apexReady, saw572 }.
    async function attemptLogin(attempt) {
      const lg = await gotoWithRetry(`${BASE}/${APP}/login`);
      if (lg.retried) step(`login page load (attempt ${attempt})`, lg.status === 200,
        `retried once after HTTP 572; HTTP ${lg.status}`);
      await page.locator('#P9999_USERNAME').first()
        .waitFor({ state: 'visible', timeout: CONTENT_TIMEOUT_MS }).catch(() => {});
      // The login page can arrive pre-filled by the browser credential manager,
      // so clear each field before filling and then VERIFY the value stuck (a
      // stale autofill is the classic cause of a silent login rejection).
      const uBox = page.locator('#P9999_USERNAME');
      const pBox = page.locator('#P9999_PASSWORD');
      const formPresent = await uBox.count().then(c => c > 0).catch(() => false);
      if (!formPresent) {
        step('login form present', false, `HTTP ${lg.status} url=${page.url()}`);
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
      docBad.length = 0;
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
      // Post-submit, wait for the authenticated landing page's content (not
      // networkidle: the home page keeps a connection open).
      await waitForContent();
      const stillLogin = LOGIN_RE.test(await page.content().catch(() => ''));
      const loggedIn = !/login/i.test(page.url()) && !stillLogin;
      const saw572 = docBad.some(d => d.status === ORDS_OVERLOADED);
      return { loggedIn, stillLogin, apexReady, saw572 };
    }

    let li = await attemptLogin(1);
    if (!li.loggedIn && li.saw572) {
      // ORDS was overloaded during sign-in: retry the whole login exactly once.
      // (Reported on the final login step below; attempt 2 decides the result.)
      await page.waitForTimeout(RETRY_572_DELAY_MS);
      li = await attemptLogin(2);
      li.retriedAfter572 = true;
    }
    const { loggedIn, stillLogin, apexReady } = li;
    // If login never submitted AND the APEX client JS never loaded, the likely
    // cause is the ORDS static file server returning 500 for /i/ assets (an
    // instance/infra problem, not a script bug) — surface that explicitly.
    const diag = loggedIn ? ''
      : (li.saw572 ? 'ORDS returned HTTP 572 (overloaded) during sign-in'
        : apexReady ? 'apex JS loaded but login was rejected (check credentials)'
         : 'APEX client JS (/i/ assets) did not load — likely ORDS static-file '
           + '500s on this instance; the no-browser HTTP smoke is the local proof');
    step('login', loggedIn, (li.retriedAfter572 ? 'retried once after HTTP 572 during sign-in; ' : '')
      + `url=${page.url()} formStillShown=${stillLogin} ${diag}`);
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
      // Run detail must actually show this run (an empty "Run not found." page
      // renders fine but means the drill is broken).
      await visit(`drill: run detail 82 [run ${RUN}]`, fp(82, 'P82_RUN_ID', RUN),
        { mustMatch: new RegExp(`Run #${RUN}\\b`) });
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
        // Run actions (backlog #158, #642): the "Re-run reconcile" button must
        // render (it used to sit in a slot APEX 26.1 rejects, so it never
        // showed), and the Cancel run form must NOT render for a finished run.
        const acts = await runDetailActions();
        step(`run actions: Re-run reconcile button renders on run detail 82 [run ${RUN}]`,
          acts.rerun, `rerun=${acts.rerun} back=${acts.back}`);
        step(`run actions: no Cancel button on a finished run [run ${RUN}]`,
          !acts.cancel, `cancel-button=${acts.cancel} reason-field=${acts.reason}`);
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
            await waitForContent();
            await page.locator('button:has-text("Re-run reconcile"), [id*="RERUN_RECONCILE"]').first().click().catch(() => {});
            await waitForContent();
            const body = await page.locator('body').innerText().catch(() => '');
            step('verify link: reconcile action completes', !ERROR_RE.test(body), body.slice(0, 120));
          }
        }
      }
    }

    // (a2) the Cancel run form on a run that has not finished (backlog #642).
    //      Only checked when a QUEUED / IN_PROGRESS run id is given, because a
    //      regression run is always finished by the time the click-through
    //      runs. The form is admin-only (backlog #722, authorization scheme
    //      Administration Rights): an administrator must see it, a non-admin
    //      end user (DMT_SMOKE) must not. The button is never pressed here.
    if (ACTIVE_RUN) {
      const ar = await visit(`run actions: run detail 82 [active run ${ACTIVE_RUN}]`,
        fp(82, 'P82_RUN_ID', ACTIVE_RUN), { mustMatch: new RegExp(`Run #${ACTIVE_RUN}\\b`) });
      if (ar.ok) {
        const acts = await runDetailActions();
        if (EXPECT_ADMIN) {
          step(`run actions: Cancel run form renders for an administrator on an unfinished run [run ${ACTIVE_RUN}]`,
            acts.cancel && acts.reason && acts.confirm,
            `cancel-button=${acts.cancel} reason-field=${acts.reason} confirm-box=${acts.confirm}`);
        } else {
          step(`run actions: Cancel run form absent for non-admin ${USER} on an unfinished run [run ${ACTIVE_RUN}]`,
            !acts.cancel && !acts.reason && !acts.confirm,
            `cancel-button=${acts.cancel} reason-field=${acts.reason} confirm-box=${acts.confirm}`);
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
      const fetchList = () => page.evaluate(async (u) => {
        try {
          const r = await fetch(u, { credentials: 'include' });
          const t = await r.text();
          return { status: r.status, body: t.slice(0, 300) };
        } catch (e) { return { status: -1, body: String(e) }; }
      }, listUrl).catch(e => ({ status: -1, body: String(e) }));
      let res = await fetchList();
      if (res.status === ORDS_OVERLOADED) {   // ORDS overloaded: retry exactly once
        await page.waitForTimeout(RETRY_572_DELAY_MS);
        res = await fetchList();
        res.body = 'retried once after HTTP 572; ' + res.body;
      }
      // A healthy response is HTTP 200 JSON carrying a "files" array (it may be
      // empty: the request id may legitimately have no cached files). An
      // "error" key means the process itself threw. An EMPTY 200 body is a
      // failure: it is what APEX returns when the process block does not
      // compile (backlog #307: a call to a procedure that did not exist made
      // every action of the page-58 process return an empty 200).
      const healthy = res.status === 200 && /^\s*\{\s*"files"\s*:\s*\[/.test(res.body)
        && !/"error"\s*:/.test(res.body);
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
      // The app renders drill links in BOTH forms: classic f?p=APP:PAGE:... and
      // friendly checksummed URLs (/r/<ws>/<alias>/p82-run-detail?...). Run
      // History's run links are the friendly form, so match both.
      const pageOf = (h) => {
        const a = h.match(/f\?p=\d+:(\d+):/);
        if (a) return a[1];
        const b = h.match(/\/r\/[^/]+\/[^/]+\/p(\d+)-/);
        return b ? b[1] : null;
      };
      const DRILL_PAGES = new Set(['52', '53', '54', '57', '58', '82', '85']);
      const hrefs = Array.from(new Set(Array.from(html.matchAll(/href="([^"]+)"/gi))
        .map(m => m[1].replace(/&amp;/g, '&'))
        .filter(h => DRILL_PAGES.has(pageOf(h)) && /run_id/i.test(h))))
        .slice(0, 6);
      if (hrefs.length === 0) {
        // With a run to drill, Run History cannot be empty, so finding no run
        // drill links means the page did not render its runs: a failure.
        // Without a run id the run list may legitimately be empty.
        step('in-app drill links present on Run History', !RUN,
          RUN ? `no run drill hyperlinks found on Run History although run ${RUN} exists`
              : 'no drill hyperlinks found (no run id given; run list may be empty)');
      } else {
        let good = 0;
        for (const h of hrefs) {
          const u = h.startsWith('http') ? h : `${BASE}/${h.replace(/^\/?ords\//, '').replace(/^\//, '')}`;
          const rid = (h.match(/run_id[=:]?(\d+)/i) || [])[1] || '';
          const r = await visit(`in-app drill link p${pageOf(h)}${rid ? ' run ' + rid : ''}`, u);
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
