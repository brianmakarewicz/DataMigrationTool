# WorkSchedules — v2 seeded gold fixture (HDL WorkPattern) — the stateful case

Converted from the frozen v1 fixture (`../../objects/WorkSchedules/`). Same two good
work patterns + one bad, loaded via HCM Data Loader (upload → createFileDataSet → poll),
verified read-only against `HTS_WORK_PATTERNS_VL`. The difference from v1: the worker
assignments and the shift are **hard-coded to standard seeded values**, not discovered.
No DMT tool code and no DMT database are in the load path; verification is the read-only
BIP relay only.

The real HDL object is `WorkPattern` (there is no `WorkSchedule` business object). A work
pattern is a repeating set of shifts hung on an existing worker assignment. See the v1
README for the full object background (base tables, attribute rules, why `ShiftName`
resolves against `HTS_SHIFTS_VL`, and why the worker must be referenced by
`AssignmentNumber`).

## The hard-coded seeds (what v1 discovered → now literals)

| Reference | v1 discovered | v2 literal |
|---|---|---|
| Good assignment 1 | lowest clean pattern-free `E<n>` | `E8` |
| Good assignment 2 | next clean pattern-free `E<n>` | `E9` |
| Bad-row assignment | (same pool) | `E8` |
| Shift name | `9A - 5P General Shift` from `HTS_SHIFTS_VL` | `9A - 5P General Shift` (literal in `WorkPattern.dat`) |

`E8` and `E9` are seeded demo employees (person numbers 8 and 9) that we never loaded.
`9A - 5P General Shift` (480 min, `ORA_HTS_SHIFT_DAY`) is a seeded shift confirmed present
in `HTS_SHIFTS_VL` on the demo pod. The `discovery` block is removed from `recipe.json`;
the verify base read is unchanged (it keys on the prefix-stamped `WorkPatternName`, which
is distinct on every run).

## Why this is the stateful case, and how it is solved

A work pattern occupies a **date range** on its worker assignment. HDL rejects a second
pattern that overlaps an existing one on the same assignment
("Work patterns can't overlap..."). If you hard-code `E8`/`E9` with a fixed `DateFrom`,
a second run collides on those same assignments.

Two things make consecutive runs collision-free:

1. **A prefix-derived `DateFrom`.** The run's prefix is turned into a distinct date
   (`SAL_DATE` = `2020-01-01 + <prefix> days`, an existing harness-derived token). Every
   run gets a fresh prefix, so every run gets a distinct start date.
2. **A bounded window (`DateTo` = `DateFrom`).** A work pattern with no `DateTo` is
   **open-ended into the future**, so two open-ended patterns overlap no matter how far
   apart their start dates are (proven live — see the failed run below). Adding a `DateTo`
   equal to `DateFrom` makes each run a **single-day** window. Two single-day windows on
   different prefix-derived dates never overlap, so consecutive runs against the same
   `E8`/`E9` each insert a fresh, disjoint window instead of colliding.

`${PREFIX}` also stays on every `SourceSystemId`, `WorkPatternName`, and alt code, so the
verify keys (`<prefix> DMT Work Schedule 1/2`) are unique per run as well.

## The DAT (`WorkPattern.dat`, inside `WorkSchedules_gold.zip`)

Parent `WorkPattern` + child `WorkPatternShift`. Parent metadata now carries `DateTo`:

`SourceSystemOwner|SourceSystemId|AssignmentNumber|WorkPatternName|WorkPatternAltCode|RepeatNumber|RepeatCycle|ShiftPeriodType|DateFrom|DateTo`

| Row | WorkPatternName | Worker | Dates | Shift | Purpose |
|---|---|---|---|---|---|
| GOOD-1 | `${PREFIX} DMT Work Schedule 1` | `E8` | `${SAL_DATE}`..`${SAL_DATE}`, days 1 & 2 | `9A - 5P General Shift` | valid → base |
| GOOD-2 | `${PREFIX} DMT Work Schedule 2` | `E9` | `${SAL_DATE}`..`${SAL_DATE}`, days 1 & 2 | `9A - 5P General Shift` | valid → base |
| BAD-1  | `${PREFIX} DMT Work Schedule Bad` | `E8` | `${SAL_DATE}`..`${SAL_DATE}`, day 1 | `DMT NONEXISTENT SHIFT ${PREFIX}` | HDL error, no pattern |

`RepeatCycle=Weeks`, `RepeatNumber=1`, `ShiftPeriodType=ORA_ANC_WORK_SHIFT_TIME`. HDL date
format is `YYYY/MM/DD` (`${SAL_DATE}` supplies it).

**Bad row:** its single `WorkPatternShift` references a shift name that does not exist on
the pod, so the loader cannot resolve `ShiftId`. It errors deterministically in the loader
and creates no work pattern.

## Live evidence (v2, via `GOLD_OBJECTS_SUBDIR=objects_seeded`)

**2026-07-20 — LIVE-PROVEN. PASS. Two consecutive runs on the SAME seeded assignments both passed (re-run safe).**

Standalone load path only (HCM Data Loader REST); verification via the read-only BIP relay only.

### Run 1 (prefix 34027, req 9766812)

| Field | Value |
|---|---|
| Terminal DataSetStatusCode | `ORA_IN_ERROR` (expected: 2 good loaded, 1 bad errored) |
| Import / Load counts | import 8 ok / 0 err; load **2 ok / 1 err** |

Good → base `HTS_WORK_PATTERNS_VL` (2/2): `34027 DMT Work Schedule 1` = `300000331574434`;
`34027 DMT Work Schedule 2` = `300000331574417`.
Bad → HDL error, no pattern: `34027DMTWS-BAD` →
`You need to enter a valid value for the ShiftName attribute. The current value is DMT NONEXISTENT SHIFT 34027.`

### Run 2 (prefix 41657, req 9766836 — immediately after run 1, SAME assignments E8/E9)

| Field | Value |
|---|---|
| Terminal DataSetStatusCode | `ORA_IN_ERROR` (expected) |
| Import / Load counts | import 8 ok / 0 err; load **2 ok / 1 err** |

Good → base `HTS_WORK_PATTERNS_VL` (2/2): `41657 DMT Work Schedule 1` = `300000331578562`;
`41657 DMT Work Schedule 2` = `300000331578548` — **new work-pattern ids on the same
E8/E9 assignments**, at a new (disjoint) single-day window. Bad row errored the same way.

Both runs added fresh, non-overlapping work-pattern windows to the same seeded assignments
with no collision. **Re-runs work.** Gold zip `WorkSchedules_gold.zip` (last built at
prefix 41657) kept here.

### The overlap discovery (why `DateTo` is required)

An earlier v2 attempt hard-coded the assignments with a prefix-derived `DateFrom` but **no
`DateTo`** (open-ended). Run 1 (prefix 89094, req 9766654) passed, but the immediate re-run
(prefix 71355, req 9766738) failed with `load 0 ok / 3 err` and, per line,
`Work patterns can't overlap. Change the start or end time of this work pattern so it
doesn't overlap the existing work pattern from 12/7/63.` — because two open-ended patterns
overlap forever regardless of start date. Adding `DateTo = DateFrom` (single-day bounded
window) fixed it, proven by runs 1 and 2 above.

## How to run

```bash
cd gold_regression/harness
GOLD_OBJECTS_SUBDIR=objects_seeded python run_object.py WorkSchedules
# run it again immediately — a fresh prefix gives a distinct single-day window, so it
# passes again on the same E8/E9 assignments
```
