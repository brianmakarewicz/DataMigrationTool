# Assignments — v2 seeded gold fixture (HDL) — the stateful date-effective case

Converted from the frozen v1 fixture (`../../objects/Assignments/`). Same shape — two good
assignment working-hours changes plus one bad — loaded through HCM Data Loader (upload →
createFileDataSet → poll) and verified read-only against the base table
`PER_ALL_ASSIGNMENTS_M`. The difference from v1: the existing assignments this fixture updates
are **hard-coded to standard seeded values**, not discovered at load time. No DMT tool code and
no DMT database are in the load path.

## What the fixture does (unchanged from v1)

Assignments is proven as an **update to existing assignments**, not a new hire. Each good row
makes a **date-effective working-hours change** (`NormalHours` → 37.5,
`ActionCode = WORK_HOURS_CHANGE`) on an assignment that already exists on the target pod, and
carries a matching `WorkTerms` split (same effective date, `EffectiveSequence = 1`,
`EffectiveLatestChange = Y`) because HDL requires the parent WorkTerms split whenever an
assignment is changed. The bad row attempts the same change with an invalid `ActionCode`
(`DMT_INVALID_ACTION`), which HDL rejects, changing nothing.

The file supplies **no `SourceSystemOwner`/`SourceSystemId` columns** and addresses each record
purely by **user key** (AssignmentNumber + PersonNumber + LegalEmployerName + DateStart). Seeded
demo employees have no `HRC_SQLLOADER` source key, so user-key addressing is the only way to
reach them. The zip member is named **`Worker.dat`** (HDL requires the member named after the
top-level object, Worker) even though it carries only WorkTerms and Assignment sections.

## The hard-coded seeds (what v1 discovered → now literals)

Confirmed on the target pod via the read-only BIP relay (`hcm_impl`) before being written as
literals. All three are seeded US1-legislative-data-group demo employees with plain numeric
person numbers that we never loaded (never carry one of our prefixes).

| Reference | Literal value | Confirmed seeded |
|---|---|---|
| Good assignment 1 | `E2` (WorkTerms `ET2`, person `2`, DateStart `2004/12/29`) | yes |
| Good assignment 2 | `E3` (WorkTerms `ET3`, person `3`, DateStart `2003/02/14`) | yes |
| Bad assignment | `E4` (WorkTerms `ET4`, person `4`, DateStart `2004/09/30`) | yes |
| Legal employer name | `US1 Legal Entity` | yes (US1 LDG `300000046974970`) |

The discovery block is removed from `recipe.json`. The verify base read scopes on
`assignment_number IN ('E2','E3','E4')`, `effective_latest_change='Y'`,
`effective_start_date = ${BEN_DATE_DASH}` (this run's effective date), and `normal_hours = 37.5`.

## Why this is a stateful case, and how re-run safety is achieved

An assignment working-hours change is **date-effective**: HDL keys the new split on the
assignment plus its `EffectiveStartDate`. v1 dated the change at `${GL_DATE_SLASH}` (today), so a
second run on the same calendar day would try to write a split at the same date on the same
assignment.

There is a second, harder constraint specific to date-effective assignment changes: **the new
split's date must not fall before the assignment's existing splits.** E2 and E3 already carry a
latest-change split at `2026/07/19` (left over from the v1 run), and E4 sits at `2015/01/02`. A
prefix-derived date (like Salaries' `${SAL_DATE}`, which can be as early as 2020 for a small
prefix) could land *before* those and be rejected.

**The re-run-safe design: a WALL-CLOCK-monotonic effective date, `${BEN_DATE}`.**

`${BEN_DATE}` is base `2300-01-01 + days-since-2020` (currently `2306/07/21`). It is:

- **Always far in the future**, so it is strictly after every existing split on these
  assignments — the date-effective change is never rejected for preceding an existing record.
- **Monotonic with the real calendar and independent of the prefix**, so a later run's date is
  never *earlier* than a prior run's — consecutive runs never book a backwards-dated split.
- **Identical for two runs on the same calendar day**, which is fine: because the fixture
  addresses the record by user key with a MERGE, a same-day re-run simply **updates our own
  split** at that date instead of colliding. A run on a later day gets a strictly later date and
  books a fresh split.

`${PREFIX}` still labels the run and keys the bad-row verification id (`${PREFIX}DMTASG-BAD`); it
does not appear in the DAT body because the fixture supplies no source key. Record uniqueness
across runs comes from the monotonic effective date, not the prefix.

## The DAT (`Assignment.dat` template → zipped as `Worker.dat`)

```
SET PURGE_FUTURE_CHANGES N
METADATA|WorkTerms|AssignmentNumber|PersonNumber|LegalEmployerName|DateStart|WorkerType|ActionCode|EffectiveStartDate|EffectiveEndDate|EffectiveSequence|EffectiveLatestChange|PrimaryWorkTermsFlag
MERGE|WorkTerms|ET2|2|US1 Legal Entity|2004/12/29|E|WORK_HOURS_CHANGE|${BEN_DATE}|4712/12/31|1|Y|Y
MERGE|WorkTerms|ET3|3|US1 Legal Entity|2003/02/14|E|WORK_HOURS_CHANGE|${BEN_DATE}|4712/12/31|1|Y|Y
MERGE|WorkTerms|ET4|4|US1 Legal Entity|2004/09/30|E|DMT_INVALID_ACTION|${BEN_DATE}|4712/12/31|1|Y|Y
METADATA|Assignment|AssignmentNumber|PersonNumber|LegalEmployerName|DateStart|WorkerType|WorkTermsNumber|ActionCode|EffectiveStartDate|EffectiveEndDate|EffectiveSequence|EffectiveLatestChange|PrimaryAssignmentFlag|NormalHours
MERGE|Assignment|E2|2|US1 Legal Entity|2004/12/29|E|ET2|WORK_HOURS_CHANGE|${BEN_DATE}|4712/12/31|1|Y|Y|37.5
MERGE|Assignment|E3|3|US1 Legal Entity|2003/02/14|E|ET3|WORK_HOURS_CHANGE|${BEN_DATE}|4712/12/31|1|Y|Y|37.5
MERGE|Assignment|E4|4|US1 Legal Entity|2004/09/30|E|ET4|DMT_INVALID_ACTION|${BEN_DATE}|4712/12/31|1|Y|Y|37.5
```

| Row | AssignmentNumber | ActionCode | NormalHours | Purpose |
|---|---|---|---|---|
| GOOD-1 | `E2` (seeded literal) | `WORK_HOURS_CHANGE` | 37.5 | valid → `PER_ALL_ASSIGNMENTS_M` |
| GOOD-2 | `E3` (seeded literal) | `WORK_HOURS_CHANGE` | 37.5 | valid → `PER_ALL_ASSIGNMENTS_M` |
| BAD-1  | `E4` (seeded literal) | `DMT_INVALID_ACTION` | 37.5 | HDL error, no change |

Attributes intentionally supplied: `WorkerType = E`, `EffectiveEndDate = 4712/12/31`
(open-ended), `EffectiveSequence = 1`, `EffectiveLatestChange = Y`, the primary flags. `SET
PURGE_FUTURE_CHANGES N` protects any future-dated rows.

**Bad-row design.** `ActionCode = DMT_INVALID_ACTION` is not a valid assignment action; HDL
rejects it with *"You must enter a valid value for the ActionCode field."* and makes no change.
Its WorkTerms line carries the same invalid action so the whole bad split is rejected together.
Because the fixture supplies no `SourceSystemId`, the rejection comes back with a **null
`SourceSystemId`**, so verification matches it by the expected error text (the recipe declares
`bad_error_contains: "valid value for the ActionCode field"`).

## The exact call (HCM Data Loader REST, credential role `hcm_impl`)

Upload → `.../dataLoadDataSets/action/uploadFile` → ContentId; submit →
`.../dataLoadDataSets/action/createFileDataSet` (`fileAction: IMPORT_AND_LOAD`) → RequestId; poll
`.../dataLoadDataSets/{RequestId}` every 30s; errors from
`.../dataLoadDataSets/{RequestId}/child/messages`. `ORA_IN_ERROR` is the EXPECTED terminal here
(the one bad row errors on purpose; the two good rows still load — partial success, load 2 ok /
1 err). Poll takes ~150s to reach terminal. The first GET immediately after createFileDataSet may
404 (data set not yet queryable); the poller retries.

## Verification (read-only, single-table read)

Direct read of `PER_ALL_ASSIGNMENTS_M` for `E2`/`E3`/`E4` where the latest-change split has
`normal_hours = 37.5` and `effective_start_date = ${BEN_DATE_DASH}` (this run's far-future
effective date). A row present with a real `ASSIGNMENT_ID` for each good assignment = pass. The
bad assignment `E4` produces no 37.5 split at that date (its change was rejected in the loader),
so it is absent from the base read; the bad evidence is the load-time HDL error message.

## Live evidence (v2, via `GOLD_OBJECTS_SUBDIR=objects_seeded`)

**2026-07-20 — LIVE-PROVEN. PASS. Two consecutive runs both passed (re-run safe).**

Standalone HDL load path only; verification via the read-only BIP relay only. Effective date for
both runs (same calendar day): `2306/07/21`.

### Run 1

| Field | Value |
|---|---|
| Prefix | `30059` |
| HDL UCM ContentId | `UCMFA07639937` |
| HDL data set RequestId | `9766657` |
| Terminal DataSetStatusCode | `ORA_IN_ERROR` (expected: 2 loaded, 1 errored) |
| Import / Load counts | import 6 ok / 0 err; load **2 ok / 1 err** |

Good → base `PER_ALL_ASSIGNMENTS_M` (2/2): `E2` assignment_id `300000047339531` (37.5 @
2306/07/21); `E3` assignment_id `300000047340518` (37.5 @ 2306/07/21).
Bad → HDL error, absent from base: `30059DMTASG-BAD` (assignment `E4`) →
`You must enter a valid value for the ActionCode field.`

### Run 2 (immediately after run 1 — proves re-runs don't collide)

| Field | Value |
|---|---|
| Prefix | `39099` |
| HDL UCM ContentId | `UCMFA07640031` |
| HDL data set RequestId | `9766740` |
| Terminal DataSetStatusCode | `ORA_IN_ERROR` (expected) |
| Import / Load counts | import 6 ok / 0 err; load **2 ok / 1 err** |

Good → base `PER_ALL_ASSIGNMENTS_M` (2/2): `E2` → **same** assignment_id `300000047339531`; `E3`
→ **same** `300000047340518` — the MERGE updated *our own* same-day split at 2306/07/21 via the
user key, same assignment ids, no collision. Bad row errored the same way.

Both runs booked/updated a `NormalHours = 37.5` date-effective split at the monotonic far-future
date on the same seeded assignments; the bad assignment change was rejected in the loader and
left its assignment unchanged. **Re-runs work** — a same-day re-run updates our own split at the
monotonic date instead of colliding, and a later-day run gets a strictly later date that is
still after every existing split.

## Harness note

No harness code was changed. The monotonic effective-date token `${BEN_DATE}` / `${BEN_DATE_DASH}`
already existed in `harness/build_artifact.py` (added for the BenParticipant v2 fixture); this
object reuses it. The recipe resolves through `GOLD_OBJECTS_SUBDIR=objects_seeded` like every
other v2 object.

## How to run

```bash
cd gold_regression/harness
GOLD_OBJECTS_SUBDIR=objects_seeded python run_object.py Assignments
# run it again immediately — the monotonic date makes the second run update our own
# same-day split via the user key, so it passes again
```
