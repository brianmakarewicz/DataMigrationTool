# Workers — v2 seeded gold fixture (HDL)

Converted from the frozen v1 fixture (`../../objects/Workers/`). Same two good new-hires
plus one bad worker, loaded via HCM Data Loader (upload → createFileDataSet → poll) as
`hcm_impl`, verified read-only against `PER_ALL_PEOPLE_F`. The one difference from v1:
the legal employer and business unit are **hard-coded to standard seeded values**, not
discovered at load time.

This is a top-level new-hire. Each run creates brand-new persons (prefix-stamped
PersonNumber, run-unique SSN), so there is no stateful collision to solve — the seed
references are simply the pod's standard demo org data that every new hire attaches to.
PersonAddress is deliberately omitted (as in v1): the demo pod has US address verification
enabled and the sample street addresses fail it, which would fail the whole worker. Address
is optional, so it is left out.

## The hard-coded seeds (what v1 discovered → now literals)

| Reference | v1 token | Literal value (in `Worker.dat`) |
|---|---|---|
| Legal employer name | `${LEGAL_EMPLOYER}` | `US1 Legal Entity` |
| Business unit short code | `${BU_SHORT}` | `US1 Business Unit` |

Both are standard seeded demo org units that ship in every `fa-esew-devN-saasfademo1` pod
and that we never loaded. Confirmed seeded (present, unprefixed) by a read-only BIP query
on 2026-07-20:

```sql
SELECT otl.name FROM hr_organization_units_f_tl otl
 WHERE otl.language='US' AND otl.name IN ('US1 Legal Entity','US1 Business Unit')
```

→ returned both names exactly, no prefix. The v1 discovery block is removed from
`recipe.json`.

## What still carries a prefix (unchanged from v1)

`${PREFIX}` stays on every SourceSystemId / PersonNumber / component key, so each run
creates fresh persons that never collide. `${SSN1}` / `${SSN2}` are the harness's derived
run-unique SSN tokens (`1<prefix5>001` / `1<prefix5>002` — start with 1, never 9xx/000/666),
auto-stamped by the harness; they keep re-runs from colliding on the national-id uniqueness
rule.

## The DAT (`Worker.dat`, pipe-delimited HDL)

One `Worker.dat` inside `Workers_gold.zip`, sections in the mandatory five-for-a-hire order
plus contact/legislative components: `Worker`, `PersonName`, `WorkRelationship`, `WorkTerms`,
`Assignment`, `PersonEmail`, `PersonPhone`, `PersonNationalIdentifier`, `PersonLegislativeData`.
Three workers, all `ActionCode=HIRE`:

| Row | PersonNumber | LegalEmployer | Purpose |
|---|---|---|---|
| GOOD-1 | `${PREFIX}DMTW001` | `US1 Legal Entity` (seeded) | valid → base |
| GOOD-2 | `${PREFIX}DMTW002` | `US1 Legal Entity` (seeded) | valid → base |
| BAD-1  | `${PREFIX}DMTW-BAD` | `DMT NONEXISTENT LEGAL EMPLOYER` | HDL error, no person |

The BAD worker's `WorkRelationship.LegalEmployerName` cannot resolve, so HCM Data Loader
rejects it with a `LegalEntityId` error at load time and creates no person.

## Verification (read-only)

- **Good → base.** Direct read of `PER_ALL_PEOPLE_F` filtered by
  `person_number LIKE '<prefix>DMTW%'`. Each good PersonNumber present with a real
  `PERSON_ID` = pass.
- **Bad → HDL error, absent from base.** The bad evidence is the load-time HDL message list
  keyed by `SourceSystemId`; the base read confirms the bad PersonNumber is absent.

## Live evidence (v2, via `GOLD_OBJECTS_SUBDIR=objects_seeded`)

**2026-07-20 — LIVE-PROVEN. PASS.**

| Field | Value |
|---|---|
| Prefix | `54685` |
| HDL data set RequestId | `9766252` |
| Terminal DataSetStatusCode | `ORA_IN_ERROR` (expected: 2 good loaded, 1 bad errored) |
| Import / Load counts | import 23 ok / 0 err; load **2 ok / 1 err** |
| Legal employer / BU (seeded) | `US1 Legal Entity` / `US1 Business Unit` |

**Good rows → base table `PER_ALL_PEOPLE_F` (2/2):**

| PersonNumber | PERSON_ID |
|---|---|
| `54685DMTW001` | `300000331562447` |
| `54685DMTW002` | `300000331562504` |

**Bad row → HDL error, no person created (1/1):**

| PersonNumber | HDL error (file line 11, WorkRelationship) |
|---|---|
| `54685DMTW-BAD` | `You need to enter a valid value for the LegalEntityId attribute. The current values are DMT NONEXISTENT LEGAL EMPLOYER.` |

The two good workers reached `PER_ALL_PEOPLE_F` with real person ids; the bad worker errored
in the loader and created no person.

## How to run

```bash
cd gold_regression/harness
GOLD_OBJECTS_SUBDIR=objects_seeded python run_object.py Workers
```
