#!/usr/bin/env python
"""
dmt_console_verify.py — URL-driven Playwright drill of the DMT2 console.

This is the thin Python launcher for test/playwright/dmt_console_verify.js. It
resolves the target through the one URL knob (scripts/dmt_apex_url_target.py),
passes it to the Node Playwright script via environment, and prints the verdict.
Because it shares that resolver with scripts/dmt_apex_smoke.py, retargeting from
the local console to ATP is a single URL change — the matching app id, alias,
workspace and the DMT_SMOKE end-user credentials come along with the URL.

Default target: the local Docker console (app 501) at
http://localhost:8182/ords/r/dmt/livedmt2/ as DMT_SMOKE (a NON-admin end-user
account whose password is read from connections.json, never hardcoded).

Why Node, not Playwright-for-Python: the repo already ships a proven Node
Playwright install (reused from ../fusion-config-migrator/node_modules, same as
scripts/dmt_apex_playwright_gate.py and scripts/playwright_verify.js), and there
is no Python Playwright dependency in-tree. This launcher keeps the single URL
knob in Python while the browser driving stays on the proven Node path.

Usage:
  python test/playwright/dmt_console_verify.py                      # local app 501 as DMT_SMOKE
  python test/playwright/dmt_console_verify.py --run-id 229         # drill run 229
  python test/playwright/dmt_console_verify.py --base-url https://<atp-host>/ords --run-id 351
  python test/playwright/dmt_console_verify.py --cemlis Suppliers,Customers --run-id 229
  python test/playwright/dmt_console_verify.py --run-id 229 --json-out result.json

Exit codes: 0 = all steps passed, 1 = a failure, 2 = env/creds missing.
"""
import argparse
import datetime
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.normpath(os.path.join(HERE, "..", "..", "scripts"))
sys.path.insert(0, SCRIPTS)
import dmt_apex_url_target as urltarget  # the one URL knob

JS = os.path.join(HERE, "dmt_console_verify.js")
PW_NODE_MODULES = os.environ.get(
    "DMT2_PW_NODE_MODULES",
    r"C:\Users\Monroe\workspace\fusion-config-migrator\node_modules")


def main():
    ap = argparse.ArgumentParser(description="URL-driven Playwright drill of the DMT2 console")
    ap.add_argument("--base-url", help="ORDS base URL — the one environment knob "
                    "(default http://localhost:8182/ords; env DMT2_UI_BASE)")
    ap.add_argument("--app", help="application id (default: resolved from the base URL)")
    ap.add_argument("--app-alias", help="friendly app path r/<ws>/<alias> (default: resolved)")
    ap.add_argument("--user", help="end-user login (default: DMT_SMOKE from connections.json)")
    ap.add_argument("--password", help="password for --user (default: resolved from connections.json)")
    ap.add_argument("--run-id", help="run id to drill (object/record detail, activity log)")
    ap.add_argument("--cmp-run-id", help="run id with comparison data for page 85 (default: --run-id)")
    ap.add_argument("--cemlis", help="comma object codes to drill "
                    "(default Suppliers,PurchaseOrders,GLBalances,Customers,Assets)")
    ap.add_argument("--json-out", help="also write the full result (verdict + every step) "
                    "to this JSON file; scripts/ci_promote.py records it as "
                    "promotion evidence")
    ap.add_argument("--click-verify", action="store_true",
                    help="actually CLICK the reconcile/read-back button (destructive: "
                         "re-submits reconcile). Default is presence-only.")
    args = ap.parse_args()

    tgt = urltarget.resolve(base_url=args.base_url, app_id=args.app,
                            app_path=args.app_alias, user=args.user,
                            password=args.password)
    if not tgt["password"]:
        print(f"FAIL: no password resolved for user {tgt['user']}. Set it in "
              f"connections.json (console.app_users) or pass --password / "
              f"$DMT2_UI_PASS. Credentials are never hardcoded.")
        sys.exit(2)

    env = dict(os.environ)
    env["DMT2_UI_BASE"] = tgt["base_url"]
    env["DMT2_UI_APP"] = tgt["app_path"]
    env["DMT2_UI_APPID"] = tgt["app_id"]
    env["DMT2_UI_USER"] = tgt["user"]
    env["DMT2_UI_PASS"] = tgt["password"]
    env["DMT2_PW_NODE_MODULES"] = PW_NODE_MODULES
    if args.run_id:
        env["DMT2_UI_RUN"] = str(args.run_id)
    if args.cmp_run_id:
        env["DMT2_UI_CMP_RUN"] = str(args.cmp_run_id)
    if args.cemlis:
        env["DMT2_UI_CEMLIS"] = args.cemlis
    if args.click_verify:
        env["DMT2_UI_CLICK_VERIFY"] = "1"

    print(f"[playwright-verify] {tgt['base_url']}/{tgt['app_path']} (app {tgt['app_id']}) "
          f"as {tgt['user']} — resolved from {tgt['source']}"
          + (f", drilling run {args.run_id}" if args.run_id else ""))

    p = subprocess.run(["node", JS], env=env, capture_output=True, text=True)
    stdout = (p.stdout or "").strip()
    result = None
    if stdout:
        # the JS prints one pretty-printed JSON object; take it whole
        try:
            result = json.loads(stdout)
        except ValueError:
            # fall back to the last JSON-looking line
            for line in reversed(stdout.splitlines()):
                try:
                    result = json.loads(line)
                    break
                except ValueError:
                    continue
    def write_json(res, verdict):
        if not args.json_out:
            return
        payload = {"verdict": verdict, "node_exit_code": p.returncode,
                   "base_url": tgt["base_url"], "app_path": tgt["app_path"],
                   "app_id": tgt["app_id"], "run_id": args.run_id,
                   "finished_at": datetime.datetime.now(datetime.timezone.utc)
                   .isoformat(timespec="seconds"),
                   "steps": (res or {}).get("steps", [])}
        with open(args.json_out, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, indent=1)

    if result is None:
        print("[playwright-verify] could not parse node output:")
        print(p.stdout)
        print(p.stderr[-1000:])
        write_json(None, "FAIL")
        sys.exit(1)

    for s in result.get("steps", []):
        flag = "ok  " if s.get("ok") else "FAIL"
        print(f"    {flag}  {s.get('name')}: {s.get('detail', '')}")
    if p.stderr.strip():
        print("[playwright-verify] node stderr:\n" + p.stderr.strip()[-800:])
    verdict = result.get("verdict", "FAIL")
    # A PASS verdict with a non-zero node exit is not a pass.
    if p.returncode != 0:
        verdict = "FAIL"
    print(f"[playwright-verify] VERDICT: {verdict}  ({tgt['base_url']}/{tgt['app_path']})")
    write_json(result, verdict)
    sys.exit(0 if verdict == "PASS" else 1)


if __name__ == "__main__":
    main()
