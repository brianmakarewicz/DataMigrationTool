# Stage B3 — CSV intake unit suite (2026-07-08)

Result: **16 passed / 0 failed** (`test/unit/test_csv_intake.sql`); both suites green on rerun.

## Defect found and FIXED
Scenario-mandatory (decided 2026-07-07) was never enforced: DMT_CSV_LOADER_PKG.LOAD_CSV
accepted NULL SCENARIO_NAME. Now guards: NULL scenario → landing FAILED with reportable
error, zero rows land.

## Documented for the Stage B blind review (not fixed)
1. **DMT_CSV_UPLOAD_PKG is INVALID on Docker** (APEX_ZIP dependency, no APEX installed) —
   the entire Smart Upload path is untestable locally. Needs an APEX seam (isolate the
   APEX_ZIP call) or waits for the Stage F APEX environment. Also scenario-mandatory is
   still unenforced across its 6 entry points — cannot fix what cannot compile locally.
2. No seed for DMT_UPLOAD_OBJECT_TBL / DMT_UPLOAD_DICT_TBL (infrastructure finding 15
   confirmed at the package level: SEED_DICTIONARY iterates an empty registry).
3. Loader standards violations: dynamic SQL via DBMS_SQL; **ALTER SESSION SET
   NLS_DATE_FORMAT with implicit conversion — and the altered NLS leaks to the caller**
   (session-NLS ban, section 7); NLS_NUMERIC_CHARACTERS never overridden; no error-code
   OUT params; v_ prefixes; nested BEGIN blocks. Loader is a Stage B port-target — rewrite
   to explicit masks when the intake layer is refactored.
4. Contract pins established by the tests (current behavior, review whether to keep):
   short rows NULL-padded / extra cells dropped silently (errors only on conversion);
   re-landing the same file appends duplicates (caller owns idempotency); LOAD_CSV does
   not guard terminal landing rows (only batch wrappers filter PENDING).
