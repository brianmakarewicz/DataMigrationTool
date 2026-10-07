# DMT2 console — URL-driven Playwright verification

Browser-level verification of the Data Migration Console. It logs in as the
end-user smoke account, visits every real app page, walks the full drill chain,
and exercises the verify / ESS file-list / download / drill-hyperlink actions —
asserting each returns HTTP 200 and renders without an APEX error region.

**The environment switch is the base URL — nothing else.** Everything (app id,
friendly alias, workspace, and the `DMT_SMOKE` credentials) is resolved from
that one URL by `scripts/dmt_apex_url_target.py`, which matches
`connections.json`. Pointing at ATP instead of local is a find-and-replace of
the base URL.

## Files

| File | What it is |
|------|------------|
| `dmt_console_verify.py` | Python launcher. Resolves the target via the one URL knob and runs the Node drill. **Start here.** |
| `dmt_console_verify.js` | The Playwright drill (Node). Driven entirely by env vars; the launcher fills them. |
| `../../scripts/dmt_apex_url_target.py` | The single URL knob shared with `scripts/dmt_apex_smoke.py`. |

Playwright-for-Python is not installed in-tree, so the browser driving runs on
the proven Node Playwright install reused from
`../fusion-config-migrator/node_modules` (same path the existing
`scripts/dmt_apex_playwright_gate.py` and `scripts/playwright_verify.js` use).
Override with `DMT2_PW_NODE_MODULES`.

## Run it (local console, the default)

```bash
# full sweep + drill of a recent run, local app 501 as DMT_SMOKE
python test/playwright/dmt_console_verify.py --run-id 229

# page sweep only (no run to drill)
python test/playwright/dmt_console_verify.py

# drill specific objects
python test/playwright/dmt_console_verify.py --run-id 229 --cemlis Suppliers,Customers
```

No credentials on the command line: `DMT_SMOKE`'s password is read from
`connections.json` (`local_docker.containers.dmt2-local.console.app_users`).
`DMT_SMOKE` is an end-user (non-admin) account, so it satisfies the
no-admin-login rule. Never log in as `DMTADMIN` / a builder from automation.

## Retarget to another environment — change the URL

The base URL is the only knob. Point it at GOLD ATP:

```bash
python test/playwright/dmt_console_verify.py \
    --base-url https://<atp-ords-host>/ords \
    --run-id 351
```

The resolver looks that base URL up in `connections.json` and pulls the matching
app id (500), alias (`r/dmt2/livedmt2`), workspace, and the `DMT_SMOKE` password
for that instance — all from the URL. If the URL is not yet in
`connections.json`, pass the rest explicitly or set env vars:

```bash
export DMT2_UI_BASE=https://<host>/ords
export DMT2_UI_APP=r/dmt2/livedmt2
export DMT2_UI_APPID=500
export DMT2_UI_USER=DMT_SMOKE
export DMT2_UI_PASS=...        # or let it resolve from connections.json
python test/playwright/dmt_console_verify.py --run-id 351
```

To see exactly what a URL resolves to (password masked):

```bash
python scripts/dmt_apex_url_target.py https://<host>/ords/r/dmt2/livedmt2/
```

## Running the raw Node drill directly

```bash
DMT2_UI_BASE=http://localhost:8182/ords \
DMT2_UI_APP=r/dmt/livedmt2 \
DMT2_UI_APPID=501 \
DMT2_UI_USER=DMT_SMOKE \
DMT2_UI_PASS=... \
DMT2_UI_RUN=229 \
node test/playwright/dmt_console_verify.js
```

## What it checks

1. **Login** as the end-user smoke account (friendly-URL session carried into `f?p`).
2. **Every real app page** renders: Home, the P2P / GL / OTC / Projects / Workers /
   Time&Labor / Admin landing pages, Lookup Dashboard, Upload Reference Guide, and the
   operational pages 80 / 82 / 85 / 52 / 53 / 54 / 57 / 58 / 84.
3. **The drill chain** with real keyed URLs:
   run history 80 → run detail 82 → object detail 52 → record detail 57 →
   activity log 54, plus run comparison 85, and object detail 52 → ESS job detail 53 /
   ESS job output 58.
4. **The verify / action links:**
   - the post-run reconcile / read-back button on run detail 82 (presence by default;
     pass `--click-verify` to actually re-run it — destructive);
   - the ESS file-list read-back (page 58 `DOWNLOAD_ESS_FILE_V2` `LIST` action) over the
     authenticated session, asserting a 200 JSON response with no error;
   - the app's own checksummed drill hyperlinks scraped from Run History, followed and
     asserted 200 + no error region.

How each page is judged (hardened 2026-10-07, because the promotion gate depends on it):

- **Waits for content, not a fixed time.** After navigating, the script polls the main
  content region until it holds real text, no APEX "processing" spinner is showing, and the
  text has stopped changing for a second (up to 60 seconds). Before this, a page could be
  judged before its report rendered: Run History was measured with no rows, so its drill
  links were silently never followed.
- **Nearly empty pages fail.** A page whose main content region has fewer than 40
  characters of text (dropdown option lists excluded) fails, even with HTTP 200. The
  threshold is fixed in the script, not an environment setting.
- **HTTP 572 is retried once.** ORDS returns 572 when its connection pool is exhausted.
  The page (or login, or the ESS file-list call) is retried once after 15 seconds and the
  step says "retried once after HTTP 572". A second 572 fails.
- **Run detail must show the run.** The run-detail drill fails if the page does not show
  `Run #<id>`, and Run History must offer drill links when a run id is given.
- `--json-out FILE` writes the verdict and every step to a JSON file;
  `scripts/ci_promote.py` records it as promotion evidence.

Exit codes: `0` all passed, `1` a failure, `2` env/credentials missing.

## Known local gotcha — ORDS `/i/` static assets returning HTTP 500

Browser login needs the APEX client JS bundle
(`/i/libraries/apex/minified/desktop_all.min.js`). If the local ORDS container
is missing its APEX 26.1 image files, that bundle 500s, the Sign In button never
binds its handler, and the script reports:

> `login ... APEX client JS (/i/ assets) did not load — likely ORDS static-file
> 500s on this instance`

That is an ORDS/APEX-images provisioning problem in the container, **not** a
script bug. Confirm it with:

```bash
curl -s -o /dev/null -w "%{http_code}\n" \
  "http://localhost:8182/i/libraries/apex/minified/desktop_all.min.js?v=26.1.0"
```

A `500` means the container's `/opt/oracle/apex/images/` is incomplete; reseat
the APEX images in the ORDS container (or run against an instance whose `/i/`
serves 200). While local `/i/` is broken, use the no-browser HTTP smoke as the
local proof of life — it logs in and sweeps every page without the APEX JS
bundle:

```bash
python scripts/dmt_apex_smoke.py --run-id 229
```

On a healthy instance (e.g. ATP, or local once the images are fixed) the
Playwright drill logs in via `apex.submit('LOGIN')` and runs the full sweep.

## Relationship to the other APEX checks

| Tool | Scope |
|------|-------|
| `scripts/dmt_apex_smoke.py` | No-browser HTTP sweep + exhaustive link crawl. Same URL knob. |
| `scripts/dmt_apex_playwright_gate.py` | Fast CI gate — a couple of pages only. |
| `test/playwright/dmt_console_verify.py` | This — full browser drill + verify/action links. |

All three resolve their target from the same base URL, so retargeting the suite
is one URL change.
