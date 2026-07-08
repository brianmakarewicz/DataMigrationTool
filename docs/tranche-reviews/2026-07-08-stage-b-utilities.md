# Blind Tranche Review — Common Utilities (Stage B, 2026-07-08)

Reviewer: blind subagent. Scope: dmt_util_pkg, dmt_ess_util_pkg, dmt_import_report_pkg,
dmt_csv_loader_pkg, dmt_csv_upload_pkg + all unit suites.
**Verdict: PASS-WITH-FINDINGS.** Test suites rated "well above baseline" (hard-fail
assertions, hostile-NLS + >32K fixtures, honest GAP blocks); consolidation direction
endorsed. But 7 correctness-bearing HIGHs must be fixed or waived before Stage C.

Proposed rules: 8, added to the canonical doc's red block.

## The 7 correctness HIGHs — dispositions

| # | Finding | Disposition |
|---|---------|-------------|
| 1 | Retired prefix-master mechanism (GET_PREFIX / INCREMENT_AND_GET_PREFIX over DMT_PREFIX_MASTER_TBL) shipped in the common package; per-CEMLI semantics contradict decided per-run prefixes; tests 15/16/31 pin it green | **FIRST TASK OF STAGE C** — prefix consolidation (single DMT_RUN_PREFIX_SEQ, per-run) must land with the scheduler/init callers; tests converted to retirement tripwires NOW (fix agent). |
| 6 | ALTER SESSION NLS in both intake packages, leaks to caller, implicit conversions, NLS_NUMERIC_CHARACTERS unset | **FIX with the intake-parser consolidation** (see below) — explicit masks per standard. |
| 7 | Dynamic SQL throughout intake incl. runtime DDL (ensure_err_log_table) | **DEFER to the intake refactor** (same work item as 6/33) — structural. |
| 8 | Error-code contract (c_success/x_error_code) implemented nowhere; four signaling styles coexist | **USER DECISION** — retrofit the contract across the shared layer, or record an accepted exception: "the common utility layer signals via raised -20xxx exceptions; the error-code contract applies from the validator/transformer layer up." Recommendation: the exception — utilities raising is idiomatic and every test pins it; retrofitting adds churn without catching more errors. |
| 9 | GET_ESS_OUTPUT_TEXT/XML return error text AS report content | **FIX NOW** (agent dispatched). |
| 19 | bip_soap checks neither HTTP status nor SOAP fault — silent-fault path; three fault idioms coexist | **FIX NOW** (agent dispatched) — fault+status check; full transport consolidation (proposed rule 1) is the Stage C-adjacent refactor. |
| 20/25 | Upload package: scenario-mandatory unenforced on all 6 entry points; key-range scenario tagging concurrency-unsafe | **DEFER to the upload-package work** (cannot compile locally — APEX dependency; needs the parse/transport seam per proposed rule 5). Must be fixed before Stage F wires Smart Upload. |

## Other findings — grouped dispositions
- **Duplication (31-36: five HTTP copies, three envelope builders, three CSV parsers, two
  ZIP readers, param-string/LOB dupes):** one consolidated "single transport + one parser
  per format" refactor work item, scheduled between Stage C engine port and Stage D (the
  engine exercises these paths; consolidating first avoids porting call sites twice).
- **Standards style debt (11-18: positional LOG calls, v_ prefixes, no breadcrumbs, nested
  blocks, missing NAME/PURPOSE headers, dead locals, commit discipline):** rolling cleanup —
  each package gets brought to standard the next time it is opened for functional work;
  positional-notation and header fixes are mechanical (candidate for one sweep commit).
- **Contract gaps (21-23: SET_LOG_CONTEXT/QUEUE_ID, Contract v1 pagination/columns, shared
  APPLY_ERRORS, PARSE_AND_LOG_ERRORS 0-ambiguity):** already-tracked build items — log
  attribution + BIP pagination land in Stage C; APPLY_ERRORS lands with the first Stage D
  reconciler so it is shared from day one.
- **Retired-concept residue (2-5: P_BATCH_ID doc example, /Custom/DMT/ literals, legacy
  alias, stale comments):** literals fixed by the fix agent (registry/config lookup);
  comment/doc cleanups fold into the rolling cleanup.
- **Test gaps (38, 40-41):** upload package untestable until its seam (deferred with it);
  offline ZIP/MTOM fixtures for dmt_ess_util_pkg queued as a Stage C-entry test task;
  minor untested paths listed in the suite GAP blocks.
- **Mojibake (42):** covered by the pending red rule; swept when accepted.

## Positives recorded by the reviewer
Suites: numbered hard-fail assertions, pre+post cleanup, hostile-NLS blocks, >32K
regression fixtures with USER_SOURCE guards, Contract v1 fixture incl. marker rules,
skip-safe live suite, honest GAP self-reports. Credentials handling largely conformant —
no plaintext leakage into logs on any reviewed path.
