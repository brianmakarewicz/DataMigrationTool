# Stage B1 — DMT_UTIL_PKG unit suite (2026-07-08)

Result: **31 passed / 0 failed**, run twice (rerun-stable, self-cleaning).
Suite: `test/unit/test_dmt_util_pkg.sql`; runner: `test/unit/run_unit_tests.sh` (CI hook).

## Defect found and FIXED
`BASE64_DECODE_CLOB` (db/packages/dmt_util_pkg.pkb.sql): the decoder counted CR/LF line
breaks toward its 4-character base64 alignment, silently corrupting any payload beyond one
chunk (~24KB decoded). Base64 streams legally carry line breaks (UTL_ENCODE emits one every
64 chars; BIP responses too) — this is the exact function that exists to fix the >32K
reconciler truncation, and it was corrupting the large payloads it was built for. Fix:
strip whitespace before computing the quantum, carry the 0–3 char remainder across chunks.
Exposed by test 19 (50KB round trip). Redeployed from the committed file.

## Gaps vs the design doc's section 5/7 contract (findings for the Stage B blind review — not fixed)
1. No `SET_LOG_CONTEXT(p_run_id, p_queue_id)` — section 5 wants session context set once by
   the queue worker; current API takes p_run_id per LOG call.
2. `DMT_LOG_TBL` has no QUEUE_ID column (known — tables-tranche finding 7; lands with the
   log-attribution work).
3. `DMT_LOG_TBL.RUN_ID` unindexed (contract-index red rule).
4. No c_success/c_error constants and no x_error_code parameters — the package signals via
   raised exceptions (-20001..-20036), against the section 7 "every procedure returns an
   error code" standard. Decision needed at the Stage B blind review: retrofit the error-code
   contract into DMT_UTIL_PKG or record an accepted exception for the shared-utility layer.
5. No date/number formatting helpers in the package — FBDI date formatting lives in the
   generators; NLS-independence covered there by golden files.
6. Retired-concept residue: package reads DMT_PREFIX_MASTER_TBL; DMT_LOG_TBL carries the
   virtual INTEGRATION_ID — both already tracked for the Stage C sweep.
7. Package body lacks the NAME/PURPOSE/REVISIONS header block (section 7).
