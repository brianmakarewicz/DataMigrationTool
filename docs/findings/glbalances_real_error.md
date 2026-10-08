# GLBalances: where Journal Import records the real error (backlog #173)

Date: 2026-10-07. Object: GLBalances (one FBDI zip, `GlInterface.csv`, load into `GL_INTERFACE`,
then the Import Journals job `JournalImportLauncher`, which spawns a `JournalImport` child).

All Fusion reads were read-only (`scripts/fusion_bip_query.py --cred fin_impl`). The only Fusion
write was the proof run described at the end.

## Short answer

1. **The real error is on the rejected interface row itself.** Journal Import leaves a rejected
   line in `GL_INTERFACE` with its error code(s) in `STATUS` (for example `EF04`, or `EF04,EC03`
   when a line has two errors) and Fusion's message text in `STATUS_DESCRIPTION`. Both are on the
   same row, so the message joins to the row directly, with no lookup.
2. **`REFERENCE10` was never an error.** It is the line description DMT sends (for example
   `GLT ledger2 journal - debit`). Report V1 labelled it as the Fusion error.
3. **An unbalanced journal is not a Fusion error on this pod.** Journal Import accepts it: the
   journal lands in `GL_JE_BATCHES` / `GL_JE_HEADERS` / `GL_JE_LINES` (batch status `U`,
   unposted), `GL_JE_BATCHES.ERROR_MESSAGE` stays empty, nothing is left in `GL_INTERFACE`, and
   `GL_JI_ERROR_CODES` has no row for the request. Fusion records no per-row error, so V1's
   `UNBALANCED: DR=.. CR=.. Will not post.` was our own sentence. Report V2 leaves such a row
   UNACCOUNTED (the owner's rule for "no Fusion error").
4. **Base rows can be selected by the import job id.** `GL_JE_BATCHES.REQUEST_ID` is always NULL,
   but the Import Journals job's own submission arguments are readable by its request id in
   `FUSION_ORA_ESS.REQUEST_PROPERTY`: `submit.argument4` is the GroupID and `submit.argument3`
   the LedgerID. V2 selects base batches by those two values for `:P_IMPORT_ESS_ID`, and
   interface rows by `LOAD_REQUEST_ID = :P_LOAD_REQUEST_ID`. Neither branch of the prototype searches on the run id
   or the prefix any more. (This also answers backlog #260, which recorded the base branch as
   "not possible as a column".)
5. **Not fixed yet: one rejected line rejects the whole import group.** Proof run 263 got the BAD
   row FAILED with `[FUSION_ERROR] EF04: FLEX-VALUE DOES NOT EXIST ...`, but Journal Import then
   imported nothing for the group, so the GOOD journal stayed in `GL_INTERFACE` (status `P`) and
   landed UNACCOUNTED. DMT sends a whole run as one group, so GOOD LOADED and BAD FAILED cannot
   both happen in one GL run. That needs the whole-document rule (#198) and an owner decision on
   the regression shape, so this stopped with a proposal (below) instead of a merged fix.

## Evidence

### Rejected rows carry code and message on the row

`GL_INTERFACE` grouped by status, whole pod:

| STATUS | Rows | Sample `STATUS_DESCRIPTION` | LOAD_REQUEST_ID | REQUEST_ID |
|---|---|---|---|---|
| `P` | 159 | (empty) | 9128286 | 9128293 |
| `EG01` | 107 | (empty) | 8140542 | 8140568 |
| `EF04` | 44 | `FLEX-VALUE DOES NOT EXIST (SEGMENT=Fund) (VALUESET=University Fund) (VALUE=121)` | 9128078 | 9128293 |
| `NEW` | 32 | (empty) | (null) | 7861632 |
| `EF04,EC03` | 2 | `FLEX-VALUE DOES NOT EXIST (SEGMENT=Fund) (VALUESET=Fund AU Council) (VALUE=101)` | 9540237 | 9540248 |

The two `EF04,EC03` rows (load 9540237) have `REFERENCE10` = `GLT ledger2 journal - debit` /
`- credit`, which confirms `REFERENCE10` is the description, not the error. The gold fixture
(`gold_regression/objects/GLBalances/GOLD_README.md`, prefix 90219) recorded the same shape for
an invalid natural account: `STATUS = EF04`, `STATUS_DESCRIPTION = FLEX-VALUE DOES NOT EXIST
(SEGMENT=Account) (VALUESET=Corporate Account) (VALUE=99999)`.

Status `P` marks a line that passed validation. It is not an error of its own. In load 9128078,
21 `EF04` lines and 29 `P` lines belong to the same journals (`JNL Jan26 Balance`,
`JNL Feb26 Balance`), and no base batch was created for that import, so `P` lines of a rejected
journal did not load either. V2 does not return `P` rows (see "Not done" below).

### Where else the text was looked for

- `GL_JI_ERROR_CODES` exists but holds one summary row per import request (totals such as
  `CR 160650.0000;DR 642.8000;DIF 160007.2000;`), not per-row messages. It has no row for our
  runs 236 / 238.
- `FND_NEW_MESSAGES` has the Journal Import execution-report strings (`R_LEZL0001` ...), for
  example `R_LEZL0041` "The journal entry is unbalanced. Suspense posting is allowed in this
  ledger and processed the entry." (code WU01) and `R_LEZL0042` "The journal entry is unbalanced
  and suspense posting isn't allowed in the ledger." (code EU02). These are report layout
  strings: the code (`R_LEZL0025` = `EU02`) and its text are separate messages tied only by the
  report's layout, so there is no key that joins a row's code to its text. They cannot be used
  to build a message.
- `FND_LOOKUP_VALUES` has no lookup for the codes (`EF04`, `EG01`, `EU02`, `EC03`).

### The unbalanced BAD row of the old scenario (runs 236 and 238)

| Batch | Status | ERROR_MESSAGE | GROUP_ID | REQUEST_ID | JE_HEADER_ID | DR | CR |
|---|---|---|---|---|---|---|---|
| `93294RT-JNL-G1 Spreadsheet A 238 10070490 N` | U | (empty) | 238 | (null) | 2484750 | 5000 | 5000 |
| `93294RT-JNL-BAD1 Spreadsheet A 238 10070490 N` | U | (empty) | 238 | (null) | 2484751 | 9999.99 | 0 |

`HAS_WARNINGS_FLAG`, `POSTING_ELIGIBILITY_CODE` and `BALANCED_JE_FLAG` are all empty for both.
`GL_INTERFACE` has no rows for load 10070485 or group 238. Fusion accepted the journal and
recorded no error anywhere a row can be joined to.

### Job-id selection

`FUSION_ORA_ESS.REQUEST_PROPERTY` for request 10070489 (run 238's `JournalImportLauncher`):
`submit.argument1` = 300000046975980 (data access set), `submit.argument2` = Spreadsheet,
`submit.argument3` = 300000046975971 (ledger), `submit.argument4` = 238 (GroupID),
`submit.argument5..7` = N. Its child is 10070490 (`JournalImport`), whose id Fusion also writes
into the batch name. Selecting `GL_JE_BATCHES.GROUP_ID = submit.argument4` and
`GL_JE_HEADERS.LEDGER_ID = submit.argument3` for request 10070489 returns exactly run 238's three
journal lines (keys 441 and 442 balanced, 443 unbalanced). The deployed V2 report, run through the
shared fetch (`DMT_RECON_CONTRACT_PKG.FETCH_ROWS`) for run 238, returned the same three rows:
441 and 442 `BASE / SUCCESS`, 443 `BASE / ERROR` with no message.

## Why this stopped short of a fix: Journal Import rejects the whole group

The report change itself works, but proving it showed the fix is not straightforward.

**Proof run 263** (local, prefix 93319, new write-once scenario `RegressionTest2610072005`, id 361,
whose GL BAD row is a line on natural account 99999; load request 10075443, Import Journals
10075446, child `JournalImport` 10075448), reconciled with report V2:

| TFM key | Line | Outcome | ERROR_TEXT |
|---|---|---|---|
| 463 | `93319RT-JNL-BAD1`, account 99999 | FAILED | `[FUSION_ERROR] EF04: FLEX-VALUE DOES NOT EXIST (SEGMENT=Account) (VALUESET=Corporate Account) (VALUE=99999)` |
| 461 | `93319RT-JNL-G1` debit, 78630 | UNACCOUNTED | `[UNACCOUNTED]` |
| 462 | `93319RT-JNL-G1` credit, 77600 | UNACCOUNTED | `[UNACCOUNTED]` |

The BAD row is exactly what the owner asked for: FAILED with Fusion's own code and message. But
the GOOD balanced journal did **not** load. In Fusion, all three lines are still in `GL_INTERFACE`
(request 10075448, group 263): 461 and 462 with status `P`, 463 with `EF04`. No `GL_JE_BATCHES`
row exists for group 263 (the highest batch id on the pod is still run 238's), and
`GL_JI_ERROR_CODES` holds one row for request 10075448 with group 263 and the totals
`CR 5000 / DR 14999.99 / DIF -9999.99`. So with "post account errors to suspense" = N (argument 5
of the job), one rejected line makes Journal Import reject **every journal of the import group**,
not just its own journal. DMT puts every line of a run in one group (GroupID = run id), so a run
can never show a GOOD journal LOADED next to a BAD journal that Fusion rejects. Regression
`dmt_regression_run.py --pipelines STANDALONE:GLBalances --scenario RegressionTest2610072005`
therefore FAILS (run 263: 0 LOADED, 1 FAILED, 2 UNACCOUNTED).

This also explains the old scenario: its unbalanced BAD row was the only kind of BAD row that
does not take the good journal down, because Fusion does not reject it at all. The gold
fixture's note that `P` means "imported" (`gold_regression/objects/GLBalances/GOLD_README.md`)
was never confirmed against the base tables (its base read was tabled) and is wrong when the
group has an error: `P` only means "this line passed validation".

The local database was put back to `origin/main` after the proof (registry row 100000016 back on
V1, the migration-log row removed, `DMT_GL_RESULTS_PKG` recompiled from `origin/main`). The V2
data model stays deployed in Fusion at `/Custom/DMT2/GLBalances/DMT_GL_BAL_RECON_V2_DM.xdm`
(additive, nothing points at it).

## Proposed design

The prototype is on branch `fix/173-glbalances-real-fusion-error` (not merged): report V2, its
registry seed + migration, `query.sql` mirror, the checker allow-list for
`GL_INTERFACE.STATUS_DESCRIPTION`, removal of the ten resolved known-violation entries, and the
regression seed's BAD row moved to account 99999.

1. **Take report V2 as is** for the row's own error: `[FUSION_ERROR] <STATUS>: <STATUS_DESCRIPTION>`,
   rows selected by job id (import job's GroupID / LedgerID arguments, `LOAD_REQUEST_ID`).
2. **Whole-group propagation (backlog #198, needs an owner decision on the "document").** For GL the
   document is the import group, proven above. When a load has any error line, every `P` line of
   the same load must land FAILED quoting the rejected line's real error, in the shared format
   `[FUSION_ERROR] Rejected with document: line 463 (...): EF04: FLEX-VALUE DOES NOT EXIST ...`
   (`DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR`), the same way `PROPAGATE_DOCUMENT_ERRORS` works for AR,
   Requisitions and Purchase Orders. The report could return the `P` rows of an errored load as
   INTERFACE rows so the reconciler can quote them.
3. **Regression shape (owner decision).** With one group per run, the GL scenario can show either
   "good journal LOADED" or "bad line FAILED with its real error", not both. Options:
   a. expected outcomes for the GL scenario: G1 lines `FAILED_WITH_DOCUMENT`, BAD1 `FAILED`, and
      prove LOADED with a second, clean GL scenario;
   b. give each journal its own GroupID and submit Import Journals once per group, so a bad journal
      only takes down itself (more ESS jobs per run, and the GroupID is then not the run id);
   c. set "post account errors to suspense" = Y. Rejected: invalid accounts would then import to
      suspense instead of reporting their error.
4. **Codes with no description and unbalanced journals** stay as listed below until decided.

## Other open points

1. **Error codes Fusion writes without a description** (seen: `EG01`; expected: `EU02` and the
   other non-flexfield codes). The row carries only the code; the matching text exists only in
   the Journal Import execution report. V2 returns no message for such rows, so they land
   UNACCOUNTED. Reading the text would mean parsing the execution report output of the
   `JournalImport` child request (the `[IMPORT_REPORT]` route), which is a design question.
2. **Lines of a rejected journal that have no error of their own** (status `P`). They do not load
   but carry no error. Under the whole-document rule they must quote the rejected line's real
   error; that is cross-grain backlog #198 and is not part of this change. Today they land
   UNACCOUNTED.
3. **Unbalanced journals** now land UNACCOUNTED although the journal is in the base table. If the
   owner wants such a journal treated as LOADED (Fusion accepted it, warning WU01), that is a
   one-line change in the BASE branch.
