# Run 234 Expenditures — Job ERROR diagnosis (ESS request 9773867)

Investigation date: 2026-07-21. READ-ONLY. No code changed, no pipeline/reconcile re-run.
Object: `Expenditures`, run_id 234, prefix `10115`.
Costing job: `ImportAndProcessTxnsJob`, ESS request 9773867, ess_job_id 8114, STATE 10 = ERROR.

---

## Bottom line

The costing job did NOT error because of a bad ParameterList and NOT because of the
project-number prefix. DMT submitted the **correct 10-argument `onestop,ImportAndProcessTxnsJob`
job with a well-formed ParameterList** (every numeric slot held a numeric value). The job
aborted inside Fusion's own costing code, in a step called `update_xface_id`, with:

> **ORA-01008: not all variables bound**

That is a job-level failure raised by Fusion's shadow procedure, not a data-quality reject and
not a DMT parameter type error. It aborted the whole run before any per-row rejection codes were
written, which is why all six rows are frozen at interface status 'P' and why DMT could not
reconcile them.

The `PROJECT_NUMBER` prefix (STG `PCS10037` → TFM `10115PCS10037`) is a **separate**
data-quality bug that would have rejected the good rows *after* costing on project resolution.
It is real and worth fixing, but it is NOT what made the job ERROR. Both issues are documented
below.

---

## DELIVERABLE 1 — the real job error (quoted from the actual ESS log)

I downloaded ESS output for request 9773867 with the same SOAP call DMT uses
(`downloadESSJobExecutionDetails` on `/fscmService/ErpIntegrationService`, fin_impl
credential), extracted the ZIP from the MTOM response, and read the single entry `9773867.log`.
Full relevant tail, verbatim:

```
2026-07-21 22:02:36.764911000 +00:00 : update_converted_flag => The enable flag for ORA_FUN_DATA_MAINT_KEY Lookup Code with lookup type PJC_37471064 is :
2026-07-21 22:02:36.766142000 +00:00 : update_xface_id => Exception occured
2026-07-21 22:02:36.766230000 +00:00 : update_xface_id => Error message is => ORA-01008: not all variables bound
2026-07-21 22:02:36.766834000 +00:00 : import_and_process => Unknown Exception occured in One stop process
2026-07-21 22:02:36.766895000 +00:00 : import_and_process => Error message is => ORA-01008: not all variables bound
```

So the definitive cause is **ORA-01008: not all variables bound**, thrown inside Fusion's
`update_xface_id` procedure (the step that stamps the interface-transaction id / batch linkage
onto the staged rows), which propagated up as "Unknown Exception occured in One stop process"
and set the job to ERROR (state 10).

It is NOT: a project-not-found error, NOT a costing validation reject, NOT the empty-batch-name
gotcha surfaced as a validation reject, and NOT the ORA-06502 non-numeric-in-numeric-slot crash
that the old 14-arg `ImportProcessParallelEssJob` used to throw. It is a bind-count mismatch
inside Fusion's own SQL.

## DELIVERABLE (primary) — actual submitted job path + ParameterList vs gold

From `dmt_ess_job_tbl` and `dmt_log_tbl` (local DMT DB, read-only):

- Job actually submitted (`dmt_ess_job_tbl`, request 9773867):
  `JobDefinition://oracle/apps/ess/projects/costing/transactions/onestop/ImportAndProcessTxnsJob`
  short name `ImportAndProcessTxnsJob`. **This is the correct 10-arg onestop job**, not the
  broken 13/14-arg `ImportProcessParallelEssJob`.

- ParameterList actually submitted (logged twice by `DMT_LOADER_PKG` at 22:02:27, verbatim):
  ```
  IMPORT_AND_PROCESS~300000046987012~ALL~#NULL~#NULL~300000049907116~300000049907117~#NULL~#NULL~#NULL
  ```

- Gold recipe template (`gold_regression/objects/Expenditures/recipe.json`):
  ```
  IMPORT_AND_PROCESS~${BU_ID}~ALL~#NULL~#NULL~${TXN_SOURCE_ID}~${DOCUMENT_ID}~#NULL~#NULL~#NULL
  ```

Position-by-position comparison — **they match**:

| Pos | Arg | Gold | Run 234 submitted | Numeric slot? | OK? |
|-----|-----|------|-------------------|---------------|-----|
| 1 | P_MODE | IMPORT_AND_PROCESS | IMPORT_AND_PROCESS | no | yes |
| 2 | P_BU_ID | ${BU_ID} | 300000046987012 | yes | yes (numeric) |
| 3 | P_TXN_STATUS | ALL | ALL | no | yes |
| 4 | P_BATCH_NAME | #NULL | #NULL | no | yes |
| 5 | P_INTERFACE_ID | #NULL | #NULL | no | yes |
| 6 | P_TXN_SOURCE_ID | ${TXN_SOURCE_ID} | 300000049907116 | yes | yes (numeric) |
| 7 | P_DOCUMENT_ID | ${DOCUMENT_ID} | 300000049907117 | yes | yes (numeric) |
| 8 | P_START_PROJECT_NO | #NULL | #NULL | no | yes |
| 9 | P_END_PROJECT_NO | #NULL | #NULL | no | yes |
| 10 | P_PROCESS_THROUGH_DATE | #NULL | #NULL | no | yes |

**No differing position.** The submitted ParameterList is well-formed and matches gold. The gold
README's ORA-06502 warning (non-numeric value in a numeric slot, or wrong parallel job) does NOT
apply here — every numeric slot (2, 6, 7) carries a numeric id, and the correct onestop job was
used. That failure mode was already fixed; run 234 did not hit it.

### So why ORA-01008 (not all variables bound)?

This is an error raised inside Fusion's `PJC_IMPORT_AND_PROCESS` / `update_xface_id` SQL, not by
DMT. ORA-01008 means a SQL statement that Fusion prepared with bind placeholders was executed
without every placeholder given a value. The failing step, `update_xface_id`, runs right after
`update_converted_flag` and is where the onestop proc links staged rows to a transaction/batch
id. The most likely trigger is that a value the onestop proc expects to have (from the staged
rows and/or from the `#NULL` parameter positions it turns into binds — batch name pos 4,
interface id pos 5, start/end project pos 8/9, process-through-date pos 10) resolved to an
unbound state in Fusion's dynamic SQL for this data shape. Because the failure is inside Fusion
and the per-row report XML was never produced (the ESS output ZIP is only 699 bytes and contains
only the log, no Import-Cost report), the exact bind that was missed cannot be pinned from
outside Fusion.

I attempted the recipe's suggested cross-check (read `submit.argument1..10` from Fusion's ESS
request-property table for the two SUCCEEDED reference runs 9719834 / 9719348) to diff DMT's
args against a known-good submission. That table is not reachable through the available BIP
query data source on this pod (it lives in the ESS runtime schema, not the FSCM application DB
the ad-hoc BIP query binds to — every attempted owner/column name returned invalid-identifier or
empty). This is a tooling limit, not a dead end: the `9773867.log` already gives the definitive
job-level cause. If the exact missing bind is needed, the next step is to run the same
ParameterList against the gold fixture's known-good staged data (which DOES cost successfully per
the gold evidence) and compare — i.e. the difference is in the **staged row data**, not the
parameters. The strongest candidate on the data side is that the prefixed, non-existent project
(`10115PCS10037`) plus NULL `PROJECT_ID`/`TASK_ID`/`EXPENDITURE_TYPE_ID` on all six rows leaves
`update_xface_id` without the ids it needs to bind — which ties the ORA-01008 back to the same
prefix bug in Deliverable 2, but as the data cause, distinct from the parameter path.

### Where the ParameterList is built (for reference — it is correct)

`db/packages/dmt_loader_pkg.pkb.sql`, lines 1362–1450 (the `ELSIF p_cemli_code = 'Expenditures'`
branch). The template is assembled at lines 1447–1449:
```
l_param_list := 'IMPORT_AND_PROCESS~' || l_exp_bu_id
    || '~ALL~#NULL~#NULL~' || l_exp_src_id || '~' || l_exp_doc_id
    || '~#NULL~#NULL~#NULL';
```
BU id, transaction-source id, and document id are resolved from lookups
(`BU_NAME_TO_BU_ID`, `PJC_TXN_SOURCE_NAME_TO_ID`, `PJC_DOC_NAME_TO_ID`). All three resolved to
numeric ids this run. **No fix needed here.**

## DELIVERABLE 2 — the project-number prefix bug (SEPARATE from the job error)

File: `db/packages/dmt_expenditure_transform_pkg.pkb.sql`
Procedure: `TRANSFORM_EXPENDITURES` (STG → TFM insert).

**The bug is on line 185:**
```
185:            DMT_UTIL_PKG.PREFIXED(l_dep_prefix, s.PROJECT_NUMBER, 25),
```
`PROJECT_NUMBER` is a **reference/linking key** — it must point at an existing Fusion project.
Prefixing it turns the real project `PCS10037` into `10115PCS10037`, which does not exist, so the
row can never resolve its project. (`DMT_UTIL_PKG.PREFIXED` simply prepends the prefix:
`RETURN SUBSTR(l_pfx || p_value, 1, p_max_len)`.)

The gold recipe confirms `PROJECT_NUMBER` must stay raw: its discovery query pulls a real
`PROJECT_NUMBER` (e.g. `PCS10037`) from live Fusion and binds it unmodified; only the isolation
key `ORIG_TRANSACTION_REFERENCE` (`RT-EXP-*`) carries the prefix.

### What IS correctly prefixed on this insert (should stay)
- Line 220 — `ORIG_TRANSACTION_REFERENCE` → prefixed. **Correct.** This is the isolation key
  that the base-table read verifies (`${PREFIX}RT-EXP-*`) and that must be unique per run.
- Line 175–176 — `BATCH_NAME` synthesised as `PREFIXED(prefix, ORIG_TRANSACTION_REFERENCE)`
  when the source has none. **Correct** — it derives from the isolation key, must be unique per
  row/run, and is not a link to a pre-existing Fusion record.
- Lines 208–210 — `SUPPLIER_NUMBER` prefixed only when present. **This is questionable but out
  of scope here**: SUPPLIER_NUMBER is a reference to an existing Fusion supplier, so by the same
  rule it should NOT be prefixed unless the supplier was itself migrated under this prefix. Flag
  for review; not the cause of this run's error (all six rows have SUPPLIER_NUMBER NULL).

### Reference/linking columns that are correctly NOT prefixed (verified — leave as-is)
`TASK_NUMBER` (188), `EXPENDITURE_TYPE` (191), `ORGANIZATION_NAME` (193),
`USER_TRANSACTION_SOURCE` (161), `DOCUMENT_NAME` (163), `UNIT_OF_MEASURE` (201) — all copied
straight from STG with no prefix. Correct. **`PROJECT_NUMBER` is the only reference key being
wrongly prefixed.**

### Proposed minimal fix (do NOT apply yet)
On line 185, stop prefixing. Change:
```
DMT_UTIL_PKG.PREFIXED(l_dep_prefix, s.PROJECT_NUMBER, 25),
```
to a straight pass-through:
```
s.PROJECT_NUMBER,
```
Keep line 220 (`ORIG_TRANSACTION_REFERENCE` prefixed) and lines 175–176 (`BATCH_NAME`) exactly
as they are. Separately decide on `SUPPLIER_NUMBER` (lines 208–210) under the same rule.

Caveat on the 25-char cap: the current call also enforces `p_max_len => 25` (the
`PROJECT_NUMBER` column width). Dropping the PREFIXED wrapper drops that truncation too; source
`PROJECT_NUMBER` values are already within Fusion's project-number width so this is fine, but if a
belt-and-suspenders length guard is wanted, use `SUBSTR(s.PROJECT_NUMBER, 1, 25)` instead of the
prefixing call.

---

## Confirmation of root cause

1. **Job-level ERROR (STATE 10) root cause = ORA-01008 "not all variables bound" inside
   Fusion's `update_xface_id` step of the onestop costing proc.** Quoted from the actual
   `9773867.log`. This is what stopped the run and left all six rows uncosted at interface
   status 'P'.
2. The submitted job path and ParameterList are correct and match gold — the parameter path is
   NOT the cause.
3. The `PROJECT_NUMBER` prefix is a real but **separate** data-quality defect
   (`dmt_expenditure_transform_pkg.pkb.sql:185`). It would reject the good rows on project
   resolution *after* costing; it is also the strongest candidate for the data condition that
   left `update_xface_id` without a project/task id to bind, but that link is inferential — the
   proven, quoted job error is ORA-01008, and the proven code defect is the line-185 prefix.
