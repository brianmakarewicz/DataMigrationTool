# Salaries — v2 seeded gold fixture (HDL) — the stateful case

Converted from the frozen v1 fixture (`../../objects/Salaries/`). Same two good + one bad
salary records, loaded via HCM Data Loader (upload → createFileDataSet → poll), verified
read-only against `CMP_SALARY`. The difference from v1: the assignments and the salary
basis are **hard-coded to standard seeded values**, not discovered.

## Why this is the stateful case, and how it is solved

v1 discovered "existing assignments that have NO salary yet" and excluded any already
salaried, so each run consumed the next salary-free assignments. If you simply hard-code
one assignment, a second run collides: after run 1 that assignment now has a salary at
that date.

**Solution (approach (a) from the task): hard-code the assignment, but put the run
prefix into the salary's own date-effective key.** A salary is date-effective. HDL keys a
`Salary` MERGE on the assignment plus `DateFrom`. If each run uses a **different**
`DateFrom`, each run inserts a **new date-effective salary segment** on the same
assignment instead of colliding — Fusion allows repeated date-effective salary changes on
an assignment that already has a salary.

The date is derived uniquely from the prefix: `SAL_DATE = 2020-01-01 + <prefix> days`
(a new harness derived token, `SAL_DATE` / `SAL_DATE_DASH`). Because every run gets a
fresh prefix, every run gets a distinct future `DateFrom`, so consecutive runs never
collide. `${PREFIX}` also stays on each salary `SourceSystemId`.

Proven live: E10 and E12 already carried a salary at `2026-07-19` (left over from the v1
run). Both v2 runs below still succeeded — they added new date-effective segments at the
prefix-derived dates — which is exactly the collision-free behavior we needed.

## The hard-coded seeds (what v1 discovered → now literals)

| Reference | Literal value |
|---|---|
| Salary basis name | `US1 Annual Salary` (in `Salary.dat`) |
| Salary basis id | `300000048365126` (verify base read) |
| Good assignment 1 | `E10` |
| Good assignment 2 | `E12` |
| Bad assignment | `E14` |

These are seeded US1-legislative-data-group demo employees (person numbers 10/12/14) we
never loaded. `US1 Annual Salary` (id 300000048365126) is the seeded US salary basis. The
discovery block is removed from `recipe.json`; the verify base read scopes on
`salary_basis_id = 300000048365126`, `date_from = ${SAL_DATE_DASH}` (this run's date), and
`assignment_number IN ('E10','E12','E14')`.

## Bad row

BAD-1 uses a salary basis that does not exist (`DMT NONEXISTENT SALARY BASIS`). HDL rejects
it with a `SalaryBasisId` error and creates no salary.

## Live evidence (v2, via `GOLD_OBJECTS_SUBDIR=objects_seeded`)

**2026-07-20 — LIVE-PROVEN. PASS. Two consecutive runs both passed (re-run safe).**

### Run 1

| Field | Value |
|---|---|
| Prefix | `71334` (DateFrom `2225-07-25`) |
| HDL data set RequestId | `9766113` |
| Terminal status | `ORA_IN_ERROR` (expected: 2 loaded, 1 errored) |

Good → base `CMP_SALARY` (2/2): `E10` salary_id `300000331562320` (75000);
`E12` salary_id `300000331562323` (85000).
Bad → HDL error, no salary: `71334DMTSAL-BAD` →
`You need to enter a valid value for the SalaryBasisId attribute...`.

### Run 2 (immediately after run 1 — proves re-runs don't collide)

| Field | Value |
|---|---|
| Prefix | `83145` (a different DateFrom) |
| HDL data set RequestId | `9766135` |
| Terminal status | `ORA_IN_ERROR` (expected) |

Good → base `CMP_SALARY` (2/2): `E10` salary_id `300000331562342`;
`E12` salary_id `300000331562345` — **new salary ids on the same assignments**, at a new
date-effective segment. Bad row errored the same way.

Both runs added fresh date-effective salary segments to the same seeded assignments with
no collision. **Re-runs work.**

## How to run

```bash
cd gold_regression/harness
GOLD_OBJECTS_SUBDIR=objects_seeded python run_object.py Salaries
# run it again immediately — a fresh prefix gives a fresh DateFrom, so it passes again
```
