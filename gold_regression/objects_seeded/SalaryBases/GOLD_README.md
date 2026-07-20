# SalaryBases — v2 seeded gold fixture (HDL)

Converted from the frozen v1 fixture (`../../objects/SalaryBases/`). Same two good + one
bad salary-basis definitions, loaded via HCM Data Loader (upload → createFileDataSet →
poll), verified read-only against the base table `CMP_SALARY_BASES`. No DMT tool code and
no DMT database are in the load path.

The difference from v1: the three upstream references (payroll element, its input value,
the legislative data group) are **hard-coded to standard seeded values**, not discovered.

## The hard-coded seeds (what v1 discovered → now literals)

v1 ran one read-only BIP query that mimicked the seeded salary basis `US1 Annual Salary`
to discover three references. Those exact values are now literals in `SalaryBasis.dat`:

| Reference | Literal value |
|---|---|
| Payroll element name (`ElementName`) | `Regular Salary` |
| Input value name (`InputValueName`) | `Amount` |
| Legislative data group (`LegislativeDataGroupName`) | `US Legislative Data Group` |

These are standard seeded demo data (the element/input value/LDG behind `US1 Annual
Salary`) that we never loaded — confirmed seeded and prefix-free on 2026-07-20 by running
the v1 discovery query read-only through the BIP relay (`hcm_impl`), which returned exactly
`Regular Salary` / `Amount` / `US Legislative Data Group`. The `discovery` block is removed
from `recipe.json`.

`${PREFIX}` stays on the new record's own keys (`SourceSystemId` and `SalaryBasisName`), so
each run inserts uniquely-named salary bases and reloads cleanly without colliding.

## The DAT (`SalaryBasis.dat`, pipe-delimited HDL)

One `SalaryBasis` section, three MERGE lines:

```
METADATA|SalaryBasis|SourceSystemOwner|SourceSystemId|SalaryBasisName|ElementName|InputValueName|SalaryBasisCode|SalaryAnnualizationFactor|LegislativeDataGroupName|Description
MERGE|SalaryBasis|HRC_SQLLOADER|${PREFIX}DMTSB001|${PREFIX} DMT Annual Salary|Regular Salary|Amount|ANNUAL|1|US Legislative Data Group|Gold regression annual salary basis
MERGE|SalaryBasis|HRC_SQLLOADER|${PREFIX}DMTSB002|${PREFIX} DMT Annual Salary 2|Regular Salary|Amount|ANNUAL|1|US Legislative Data Group|Gold regression annual salary basis 2
MERGE|SalaryBasis|HRC_SQLLOADER|${PREFIX}DMTSB-BAD|${PREFIX} DMT Bad Basis|DMT NONEXISTENT ELEMENT ${PREFIX}|Amount|ANNUAL|1|US Legislative Data Group|Gold regression bad basis
```

| Row | SourceSystemId | SalaryBasisName | ElementName | Purpose |
|---|---|---|---|---|
| GOOD-1 | `${PREFIX}DMTSB001` | `${PREFIX} DMT Annual Salary` | `Regular Salary` (seeded) | valid → `CMP_SALARY_BASES` |
| GOOD-2 | `${PREFIX}DMTSB002` | `${PREFIX} DMT Annual Salary 2` | `Regular Salary` (seeded) | valid → `CMP_SALARY_BASES` |
| BAD-1  | `${PREFIX}DMTSB-BAD` | `${PREFIX} DMT Bad Basis` | `DMT NONEXISTENT ELEMENT ${PREFIX}` | HDL error, no basis created |

### `SalaryBasisCode` is a FREQUENCY code, not a free-text code

`SalaryBasisCode` is not an arbitrary code. It is the pay frequency and must be one of the
fixed list **`ANNUAL` | `HOURLY` | `MONTHLY` | `PERIOD`**. This fixture uses `ANNUAL`
(mimicking `US1 Annual Salary`), with `SalaryAnnualizationFactor = 1`.

### Bad-row design

The bad row references a payroll element that does not exist (`DMT NONEXISTENT ELEMENT
${PREFIX}`). HDL rejects it in the loader with an `ElementTypeId` error and creates no
salary basis. The two good rows still load (partial success: load 2 ok / 1 err, terminal
`ORA_IN_ERROR`).

## The exact call (HCM Data Loader REST, credential role `hcm_impl`)

| Step | Method + URL | Body / key |
|---|---|---|
| Upload | `POST {FUSION_URL}/hcmRestApi/resources/11.13.18.05/dataLoadDataSets/action/uploadFile` | `{content:<b64 zip>, fileName}` → `ContentId` |
| Submit | `POST .../dataLoadDataSets/action/createFileDataSet` | `{contentId, fileAction:"IMPORT_AND_LOAD"}` → `RequestId` |
| Poll | `GET .../dataLoadDataSets/{RequestId}` every 30s | `DataSetStatusCode` until terminal |
| Errors | `GET .../dataLoadDataSets/{RequestId}/child/messages?onlyData=true` | per-line `SourceSystemId` + `MessageText` |

`ORA_IN_ERROR` is the **expected** terminal status here: the one bad row errors on purpose;
the two good rows still load.

## Verification (read-only via BIP)

- **Good → base.** Read of `CMP_SALARY_BASES` filtered by the run's name prefix. A
  `SALARY_BASIS_ID` present for each good `SalaryBasisName` = pass.
- **Bad → HDL error, absent from base.** The bad evidence is the load-time HDL message
  keyed by `SourceSystemId`; the base read returns only the two good rows.

## How to run it

```bash
cd gold_regression/harness
GOLD_OBJECTS_SUBDIR=objects_seeded python run_object.py SalaryBases
```

## Live evidence

**2026-07-20 — LIVE-PROVEN (v2 seeded). PASS.**

Standalone HDL load path only; verification via the read-only BIP relay only.

| Field | Value |
|---|---|
| Prefix | `45660` |
| HDL data set RequestId | `9766380` |
| Terminal DataSetStatusCode | `ORA_IN_ERROR` (expected: 2 good loaded, 1 bad errored) |
| Import / Load counts | import 3 ok / 0 err; load **2 ok / 1 err** |
| Seeded element | `Regular Salary` (literal) |
| Seeded input value | `Amount` (literal) |
| Seeded LDG | `US Legislative Data Group` (literal) |

**Good rows → base table `CMP_SALARY_BASES` (2/2):**

| SalaryBasisName | SALARY_BASIS_ID |
|---|---|
| `45660 DMT Annual Salary` | `300000331569612` |
| `45660 DMT Annual Salary 2` | `300000331569603` |

**Bad row → HDL error, no basis created (1/1):**

| SourceSystemId | HDL error |
|---|---|
| `45660DMTSB-BAD` | `You need to enter a valid value for the ElementTypeId attribute. The current values are DMT NONEXISTENT ELEMENT 45660,US Legislative Data Group.` |

The two good salary bases reached `CMP_SALARY_BASES` with real ids; the bad basis errored
in the loader (file line 4) and created nothing. Gold zip `SalaryBases_gold.zip` (last
built at prefix 45660) kept here.
