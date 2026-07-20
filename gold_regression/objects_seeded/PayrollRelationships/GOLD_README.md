# PayrollRelationships — v2 seeded gold fixture (HDL, AssignedPayroll) — the stateful case

Converted from the frozen v1 fixture (`../../objects/PayrollRelationships/`). Same shape — two
good assigned-payroll rows plus one bad — loaded through HCM Data Loader (upload →
createFileDataSet → poll) and verified read-only against the base table
`PAY_ASSIGNED_PAYROLLS_DN`. The difference from v1: the legislative data group, the payroll
definition, and the specific employee assignments are **hard-coded to standard seeded values**,
not discovered at load time. No DMT tool code and no DMT database are in the load path.

## What this object loads

A payroll relationship is created automatically by Fusion when a work relationship exists; you
do not load a bare payroll relationship. The loadable, data-carrying piece is the **assigned
payroll** — attaching an existing person's assignment to an existing payroll definition. The
HDL business object is **`AssignedPayroll`**. Each row references an existing employee
assignment (by `AssignmentNumber`), an existing payroll definition (by `PayrollDefinitionCode`,
which on this pod is the payroll name), and the legislative data group. Nothing is created
upstream.

## The hard-coded seeds (what v1 discovered → now literals)

| Reference | Literal value | Confirmed seeded (read-only BIP) |
|---|---|---|
| Legislative data group name | `US Legislative Data Group` (in the .dat) | yes — `pay_legislative_data_groups` id `300000046974970`, no prefix |
| Payroll definition code | `Biweekly` (in the .dat) | yes — `pay_all_payrolls_f` id `300000051084930`, no prefix |
| Good assignment 1 | `E15` (person number 15) | yes — seeded US-LDG demo employee we never loaded |
| Good assignment 2 | `E16` (person number 16) | yes — seeded US-LDG demo employee we never loaded |
| Bad assignment | `E6` (person number 6) | yes — seeded US-LDG demo employee we never loaded |

The discovery block is removed from `recipe.json`; the verify base read scopes on the seeded
`Biweekly` payroll id `300000051084930`, this run's start date, and assignment numbers
`E15`/`E16`/`E6`.

### Why E15 / E16 specifically (a real constraint, not a free choice)

v1 discovered "US demo employees that have a payroll relationship but NO assigned payroll and a
work location" and ordered by `assignment_id`, which happened to land on the lowest-numbered
established employees (`E2`, `E3`, …). Two extra constraints surfaced during this conversion
that the hard-coded employees MUST satisfy, confirmed live on the pod:

- **The person must have a date of birth.** `E9`/`E10` have a work location but no DOB, and the
  loader rejects them: *"This person doesn't have a date of birth. You to need to give them one
  before trying to add a payroll."*
- **The person must be a fully-configured demo employee.** Some low-numbered seeded persons
  (`E5`, `E7`) are rejected with *"Only one payroll at a time can be designated as the primary
  payroll for a single payroll terms record"* even though the BIP replica shows them
  payroll-free — their person/relationship setup is incomplete.

`E15` and `E16` are well-formed: each has a date of birth (1981-08-11 / 1966-03-11), a work
location, and was payroll-free before this fixture. `E6` (DOB 1967-09-06, has a location) is
used only as the bad row, so it never actually acquires a payroll. All three were confirmed on
the target pod through the read-only BIP relay before being written as literals.

## Why this is a stateful case, and how re-run safety is achieved

Assigning a payroll to an employee who has none is stateful: an `AssignedPayroll` MERGE is keyed
on the `AssignmentNumber` plus its `StartDate`. If each run used a fixed date, a second run
against the same hard-coded assignment would collide on the existing assigned payroll.

**Solution (approach (a) from the task, the same mechanism as Salaries): hard-code the
assignment, but put the run prefix into the assigned payroll's own date-effective key.** An
assigned payroll is date-effective. Each run stamps a distinct `StartDate` derived uniquely from
the prefix (`PAY_DATE = 2020-01-01 + <prefix> days`, a new harness derived token), so each run
inserts a **new date-effective assigned-payroll segment** on the same seeded assignment instead
of colliding. Because every run gets a fresh prefix, every run gets a distinct future
`StartDate`.

**One caveat found live, and why E15/E16 avoid it:** a far-future first segment that runs
open-ended (`end_date = 4712-12-31`) can make a *later, earlier-dated* second segment collide on
the primary-payroll rule. With prefix-derived dates that land at genuinely distinct future dates
per run, each run's segment sits at its own date and the second run is accepted cleanly —
verified live below (run 1 date 2205-01-23, run 2 date 2073-10-18, both employees, both
segments present with distinct assigned-payroll ids, no collision).

## The DAT (`AssignedPayroll.dat`, pipe-delimited HDL)

```
METADATA|AssignedPayroll|EffectiveStartDate|AssignmentNumber|PayrollDefinitionCode|LegislativeDataGroupName|StartDate
MERGE|AssignedPayroll|${PAY_DATE}|E15|Biweekly|US Legislative Data Group|${PAY_DATE}
MERGE|AssignedPayroll|${PAY_DATE}|E16|Biweekly|US Legislative Data Group|${PAY_DATE}
MERGE|AssignedPayroll|${PAY_DATE}|E6|DMT NONEXISTENT PAYROLL|US Legislative Data Group|${PAY_DATE}
```

| Row | AssignmentNumber | PayrollDefinitionCode | Purpose |
|---|---|---|---|
| GOOD-1 | `E15` (fixed seed) | `Biweekly` (fixed seed) | valid → `PAY_ASSIGNED_PAYROLLS_DN` |
| GOOD-2 | `E16` (fixed seed) | `Biweekly` (fixed seed) | valid → `PAY_ASSIGNED_PAYROLLS_DN` |
| BAD-1  | `E6` (fixed seed) | `DMT NONEXISTENT PAYROLL` | HDL error, no assigned payroll |

- **The .dat file name inside the zip must be `AssignedPayroll.dat`.** HDL derives the business
  object from the file name (recipe `archive_name`); the on-disk template is
  `PayrollRelationship.dat`, renamed to `AssignedPayroll.dat` in the zip.
- **`StartDate` is required.** Without it the loader rejects every line ("doesn't include values
  that define a unique reference to the record"). `StartDate` + `AssignmentNumber` is the unique
  key; it carries `${PAY_DATE}` so each run adds a distinct date-effective segment.
- **Bad-row design.** `E6` uses a `PayrollDefinitionCode` that does not exist
  (`DMT NONEXISTENT PAYROLL`). HDL rejects it with a `PayrollId` error and creates no assigned
  payroll. The assignment itself is real and unchanged, so the failure is squarely the invalid
  payroll.

## The exact call (HCM Data Loader REST, credential role `hcm_impl`)

Upload → `.../dataLoadDataSets/action/uploadFile` → ContentId; submit →
`.../dataLoadDataSets/action/createFileDataSet` (`fileAction: IMPORT_AND_LOAD`) → RequestId;
poll `.../dataLoadDataSets/{RequestId}` every 30s; errors from
`.../dataLoadDataSets/{RequestId}/child/messages`. `ORA_IN_ERROR` is the EXPECTED terminal here
(the one bad row errors on purpose; the two good rows still load — partial success, 2 loaded /
1 errored).

## Verification (read-only, single-table read)

Direct read of `PAY_ASSIGNED_PAYROLLS_DN`, correlated to the person/assignment through
`PAY_PAY_RELATIONSHIPS_DN` (the assigned payroll's `payroll_term_id` sits just above the
`payroll_relationship_id`; the lagging `pay_rel_groups_dn` replica is deliberately avoided).
The read is scoped to the seeded `Biweekly` payroll id `300000051084930` and this run's
prefix-derived `start_date` (`${PAY_DATE_DASH}`), so any row it returns is unambiguously this
run's segment. An `ASSIGNED_PAYROLL_ID` present for each good `AssignmentNumber` = pass. The bad
`E6` never appears in base; its evidence is the load-time HDL message list.

## Live evidence (v2, via `GOLD_OBJECTS_SUBDIR=objects_seeded`)

**2026-07-20 — LIVE-PROVEN. PASS. Two consecutive runs both passed (re-run safe).**

Standalone HDL load path only; verification via the read-only BIP relay only.

### Run 1

| Field | Value |
|---|---|
| Prefix | `67592` (StartDate `2205-01-23`) |
| HDL data set RequestId | `9766870` |
| Terminal DataSetStatusCode | `ORA_IN_ERROR` (expected: 2 loaded, 1 errored) |

Good → base `PAY_ASSIGNED_PAYROLLS_DN` (2/2): `E15` → `ASSIGNED_PAYROLL_ID` `300000331578632`
(payroll `300000051084930` Biweekly); `E16` → `300000331578635`.
Bad → HDL error, no assigned payroll: `E6` (file line 4) →
`You need to enter a valid value for the PayrollId attribute. The current values are
DMT NONEXISTENT PAYROLL,300000046974970.` — absent from base.

### Run 2 (immediately after run 1 — proves re-runs don't collide)

| Field | Value |
|---|---|
| Prefix | `19649` (StartDate `2073-10-18`, a different date) |
| HDL data set RequestId | `9766879` |
| Terminal DataSetStatusCode | `ORA_IN_ERROR` (expected) |

Good → base `PAY_ASSIGNED_PAYROLLS_DN` (2/2): `E15` → **new** `ASSIGNED_PAYROLL_ID`
`300000331578654`; `E16` → **new** `300000331578660` — new assigned-payroll ids on the same
assignments, at a new date-effective segment. Bad row errored the same way.

Confirmed live in base afterward — both segments coexist per employee, no collision:

| AssignmentNumber | ASSIGNED_PAYROLL_ID | StartDate | Run |
|---|---|---|---|
| `E15` | `300000331578632` | 2205-01-23 | run 1 |
| `E15` | `300000331578654` | 2073-10-18 | run 2 |
| `E16` | `300000331578635` | 2205-01-23 | run 1 |
| `E16` | `300000331578660` | 2073-10-18 | run 2 |

Both runs added fresh date-effective assigned-payroll segments to the same seeded assignments
with no collision. **Re-runs work** — because each run's prefix gives a distinct `StartDate`, a
second run inserts a new date-effective segment instead of colliding on the existing one.

## Additive harness change

`harness/build_artifact.py` gained one derived token, `PAY_DATE` / `PAY_DATE_DASH` (base
2020-01-01 + prefix days, YYYY/MM/DD and YYYY-MM-DD). It mirrors the existing `SAL_DATE` token
used by Salaries. Additive only; no existing token or behavior changed.

## How to run

```bash
cd gold_regression/harness
GOLD_OBJECTS_SUBDIR=objects_seeded python run_object.py PayrollRelationships
# run it again immediately — a fresh prefix gives a fresh StartDate, so the second run adds a
# new date-effective assigned-payroll segment and passes again
```
