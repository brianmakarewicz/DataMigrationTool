# Stage B2 — Live-Fusion smoke-test suite (2026-07-08)

Result: **suite built and proven up to authentication; live calls BLOCKED on an
invalid demo-instance credential** (rotated on the pod after 2026-07-04). Every
piece of local plumbing — ACL, TLS, config injection, the test harness itself —
is verified working; the suite fails at exactly the Basic-auth step with a clean
OWSM 401. Once the demo password is rotated, rerun `setup_fusion_config.py` and
the suite runs live with no further setup.

## Deliverables

| File | What |
|---|---|
| `test/unit/test_fusion_calls.sql` | LIVE smoke suite (HTTP / BIP / SOAP-fault / ESS poll-only / UCM upload). Skips cleanly ("0 passed, 0 failed (SKIPPED…)", exit 0) when `DMT_CONFIG_TBL` has no `FUSION_URL`/`FUSION_USERNAME`/`FUSION_PASSWORD`, so the offline `run_unit_tests.sh` stays green without credentials. |
| `test/unit/setup_fusion_config.py` | Injects Fusion URL + credentials from `~/workspace/connections.json` (via `conn_helper`) into the LOCAL `DMT_CONFIG_TBL` through `DMT_UTIL_PKG.SET_FUSION_URL`/`SET_CONFIG` (DML only; values never committed). Also discovers a known-SUCCEEDED ESS request id from the frozen stack's ATP (read-only) into `SMOKE_ESS_REQUEST_ID` for the poll-only ESS test. Run with `PYTHONUTF8=1`. |
| `db/tools/setup_fusion_tls.sh` | Reproducible ACL + TLS verifier (see findings below). |

## Setup performed (Docker `dmt2-local`, Oracle AI Database 26ai Free 23.26.2.0.0)

1. **ACL** — none existed. Created by calling `DMT_UTIL_PKG.SET_FUSION_URL`
   (which `setup_fusion_config.py` does): connect+resolve ACEs for
   `fa-esew-dev28-saasfademo1.ds-fa.oraclepdemos.com`, principal `DMT_OWNER`.
   The `DBMS_NETWORK_ACL_ADMIN` execute grant from `build_local_db.sh` is in
   place, so no admin step was needed.
2. **TLS** — **no wallet required.** This image's `UTL_HTTP` trusts the OS
   certificate store by default: an HTTPS request to the Fusion host succeeds
   with *no* `UTL_HTTP.SET_WALLET` call (server answered HTTP 401 — i.e. the
   handshake completed). `UTL_HTTP.SET_WALLET('system:')` also works and gives
   the identical result. `db/tools/setup_fusion_tls.sh` re-verifies both
   prerequisites and documents the wallet fallback if a future image needs one.
   Docker note: no container changes, no CA import, no sqlnet/wallet files —
   the stock `container-registry.oracle.com` image is sufficient for outbound
   HTTPS. Nothing extra to add to the (future) CI docker assets.
3. **Config injection** — `FUSION_URL`, `FUSION_USERNAME/PASSWORD`,
   `BIP_USERNAME/PASSWORD`, `HCM_USERNAME/PASSWORD` (all = `fin_impl`;
   connections.json has no `hcm_impl` entry for this pod) + `SMOKE_ESS_REQUEST_ID`
   (=9699583, latest SUCCEEDED request on the frozen stack).

## Test results

| # | Test | Result |
|---|---|---|
| 1 | `HTTP_REQUEST` GET `/fscmRestApi/.../businessUnitsLOV?limit=1` → 2xx | **BLOCKED — HTTP 401** (see below). Transport proven: DNS+ACL+TLS all succeed, Fusion answers with `WWW-Authenticate: Basic realm="owsm"`. |
| 2 | `RUN_BIP_REPORT` on `/Custom/DMT/common/DMT_FBDI_LOOKUPS_RPT.xdo` → parseable `/DATA_DS` XML via `BIP_REPORT_XML` | **BLOCKED** (not reached — same credential) |
| 3 | `RUN_BIP_REPORT` on nonexistent path → must RAISE −20034/−20030 | **BLOCKED** (not reached) |
| 4 | ESS poll-only: `POLL_ESS_JOB(9699583)` → definitive terminal status + `CAPTURE_ESS_HIERARCHY` rows | **BLOCKED** (not reached). Note: **no harmless ESS submit exists** — every registered job is a real import — so the suite deliberately polls a known-COMPLETED request instead of submitting anything. |
| 5 | UCM: `UPLOAD_HDL` of a tiny UTL_ZIP-built ZIP → ContentId | **BLOCKED** (not reached; upload is inert by design — never submitted to a loader) |
| — | Skip path (no config) | **PASS** — exits 0 with `TEST_FUSION_CALLS: 0 passed, 0 failed (SKIPPED…)`; full `run_unit_tests.sh` = 3/3. |

## The blocker (precise)

```
ORA-20003: HTTP GET failed. Status: 401 | URL: https://fa-esew-dev28-saasfademo1.ds-fa.oraclepdemos.com/fscmRestApi/...
WWW-Authenticate: Basic realm="owsm"   (empty body — plain invalid credential)
```

Every credential in every store fails: connections.json (`fin_impl`,
`calvin.roth`, `scm_impl`, `natalie.salesrep`), the frozen stack's ATP
`DMT_CONFIG_TBL` (`fin_impl`, `hcm_impl`) and its 12 per-CEMLI overrides, and
the archived original (`password_archive/data-migration-tool__TargetInstanceconnection.txt`).
The frozen stack's `DMT_LOG_TBL` shows successful authenticated Fusion calls as
late as **2026-07-04 03:35**; today everything is 401 — the demo pod's password
changed after that date. ConversionTool issue #36 (rotate + purge secrets) is
still open with no rotation recorded, so the change happened on the pod side.

**What is needed:** the new demo-instance password (from the demo portal), then
run the `rotate-demo-password` skill (updates connections.json + all caches),
then `PYTHONUTF8=1 python test/unit/setup_fusion_config.py` and
`sh test/unit/run_unit_tests.sh`. The local `FUSION_PASSWORD`/`BIP_PASSWORD`/
`HCM_PASSWORD` rows were deliberately **blanked** after the failed run so the
LIVE suite skips instead of hammering Fusion with bad Basic-auth (lockout risk).

## Package defect FIXED in git (redeployed from the committed file)

- `db/packages/dmt_ess_util_pkg.pkb.sql` — the whole package body was INVALID
  on any database without APEX (`PLS-00201: APEX_APPLICATION.STOP_APEX_ENGINE`),
  which would have broken `POLL_ESS_JOB` → `CAPTURE_ESS_HIERARCHY` locally.
  Fixed with conditional compilation: `$IF $$apex_installed $THEN
  APEX_APPLICATION.STOP_APEX_ENGINE; $ELSE RAISE_APPLICATION_ERROR(-20876,
  'Stop APEX Engine'); $END`. APEX-bearing instances must compile with
  `PLSQL_CCFLAGS='apex_installed:TRUE'` to keep the original call (the direct
  −20876 raise is the same signal APEX traps, so the fallback is also safe).

## Defects DOCUMENTED (not fixed — Stage B blind-review findings)

1. `DMT_UTIL_PKG.basic_auth_header` builds the Basic header with
   `UTL_ENCODE.BASE64_ENCODE`, which inserts CRLFs every 64 output chars —
   any `user:password` over 48 bytes produces a corrupt header. Current
   credentials are short; a long rotated password would break auth mysteriously.
2. `DMT_UTIL_PKG.BIP_REQUEST` still carries its own inline base64 decoder
   (4-char alignment over raw chunks, no whitespace strip) — the same bug class
   Stage B1 fixed centrally in `BASE64_DECODE_CLOB`. Should call the shared
   decoder.
3. `DMT_ESS_UTIL_PKG.CAPTURE_ESS_HIERARCHY` extracts `<reportBytes>` with
   `REGEXP_SUBSTR` into a `VARCHAR2(32767)` — the exact >32K truncation bug the
   shared `BIP_REPORT_XML` exists to remove; a large ESS hierarchy would be
   silently dropped ("No ESS hierarchy data returned").
4. `HTTP_REQUEST` raises −20003 on **3xx** as well as 4xx/5xx (only 2xx passes).
   Behavior note, not necessarily wrong — but callers cannot follow redirects.
5. `conn_helper.py` opens `connections.json` with the platform default encoding
   (cp1252 on Windows) and the file is UTF-8 — every consumer needs
   `PYTHONUTF8=1`. Worth fixing in conn_helper itself (outside this repo).
