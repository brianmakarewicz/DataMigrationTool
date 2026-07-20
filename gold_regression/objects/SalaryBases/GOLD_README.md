# SalaryBases — gold regression fixture (HDL)

A standalone, reloadable **HDL** fixture (2 good salary-basis definitions + 1 bad)
that loads directly into Oracle Fusion HCM through the HCM Data Loader REST service
(upload → createFileDataSet → poll), verified read-only via BIP against the base
table `CMP_SALARY_BASES`. No DMT tool code and no DMT database are in the load path.

## Why this fixture is portable (no upstream dependency)

A salary basis is a *definition* that references an **existing payroll element** (a
base-pay/salary earnings element), that element's **input value**, and a
**legislative data group**. This fixture does **not** create an element first and
does **not** reference anything we loaded earlier.

At load time it runs one read-only BIP query against the target pod and, by
mimicking an already-shipped salary basis (`US1 Annual Salary`), discovers:

- the **element name** that basis uses (`Regular Salary`),
- that element's **input value name** (`Amount`), and
- the **legislative data group name** (`US Legislative Data Group`).

Those three discovered values are stamped into `SalaryBasis.dat`. The salary-basis
records themselves are new (prefix-stamped `SourceSystemId`, `SalaryBasisName`, so
they reload cleanly on any future run without colliding). Because the references are
discovered from whatever salary basis already exists on the target, the fixture is
self-sufficient against a fresh demo pod.

## The DAT (`SalaryBasis.dat`, pipe-delimited HDL)

One `SalaryBasis.dat` inside `SalaryBases_gold.zip`. One `SalaryBasis` section,
three MERGE lines:

```
METADATA|SalaryBasis|SourceSystemOwner|SourceSystemId|SalaryBasisName|ElementName|InputValueName|SalaryBasisCode|SalaryAnnualizationFactor|LegislativeDataGroupName|Description
MERGE|SalaryBasis|HRC_SQLLOADER|${PREFIX}DMTSB001|${PREFIX} DMT Annual Salary|${ELEM_NAME}|${IV_NAME}|ANNUAL|1|${LDG_NAME}|Gold regression annual salary basis
MERGE|SalaryBasis|HRC_SQLLOADER|${PREFIX}DMTSB002|${PREFIX} DMT Annual Salary 2|${ELEM_NAME}|${IV_NAME}|ANNUAL|1|${LDG_NAME}|Gold regression annual salary basis 2
MERGE|SalaryBasis|HRC_SQLLOADER|${PREFIX}DMTSB-BAD|${PREFIX} DMT Bad Basis|DMT NONEXISTENT ELEMENT ${PREFIX}|${IV_NAME}|ANNUAL|1|${LDG_NAME}|Gold regression bad basis
```

| Row | SourceSystemId | SalaryBasisName | ElementName | Purpose |
|---|---|---|---|---|
| GOOD-1 | `${PREFIX}DMTSB001` | `${PREFIX} DMT Annual Salary` | `${ELEM_NAME}` (discovered) | valid → `CMP_SALARY_BASES` |
| GOOD-2 | `${PREFIX}DMTSB002` | `${PREFIX} DMT Annual Salary 2` | `${ELEM_NAME}` (discovered) | valid → `CMP_SALARY_BASES` |
| BAD-1  | `${PREFIX}DMTSB-BAD` | `${PREFIX} DMT Bad Basis` | `DMT NONEXISTENT ELEMENT ${PREFIX}` | HDL error, no basis created |

**Tokens stamped**

- `${PREFIX}` on each `SourceSystemId` and `SalaryBasisName` — keeps the new records
  unique and reloadable, and lets the base read find them by name prefix.
- `${ELEM_NAME}` — discovered base-pay element name (`Regular Salary`).
- `${IV_NAME}` — discovered input value name on that element (`Amount`).
- `${LDG_NAME}` — discovered legislative data group name (`US Legislative Data Group`).

### `SalaryBasisCode` is a FREQUENCY code, not a free-text code (key gotcha)

`SalaryBasisCode` is **not** an arbitrary code you invent. It is the pay frequency
and must be one of the fixed list of values **`ANNUAL` | `HOURLY` | `MONTHLY` |
`PERIOD`**. The first attempt (prefix 90261) put the prefixed source id in this
field and **all three rows failed** with:

> The `<value>` value for the SalaryBasisCode attribute is invalid and doesn't exist
> in the list of values.

Fixed by setting `SalaryBasisCode = ANNUAL` (this is an annual salary basis, mimicking
`US1 Annual Salary`). For `PERIOD`, leave `SalaryAnnualizationFactor` blank; for
`ANNUAL` here we use factor `1`. (Confirmed against Oracle HCM Data Loader docs — see
Sources at the end.)

**Bad-row design.** The bad row references an element that does not exist
(`DMT NONEXISTENT ELEMENT ${PREFIX}`). HDL rejects it in the loader with an
`ElementTypeId` error and creates no salary basis. It reaches the loader and errors
there deterministically. The two good rows still load (partial success: load 2 ok /
1 err, terminal `ORA_IN_ERROR`).

## The exact call (HCM Data Loader REST, credential role `hcm_impl`)

| Step | Method + URL | Body / key |
|---|---|---|
| Upload | `POST {FUSION_URL}/hcmRestApi/resources/11.13.18.05/dataLoadDataSets/action/uploadFile` | `{content:<b64 zip>, fileName}` → `ContentId` |
| Submit | `POST .../dataLoadDataSets/action/createFileDataSet` | `{contentId, fileAction:"IMPORT_AND_LOAD"}` → `RequestId` |
| Poll | `GET .../dataLoadDataSets/{RequestId}` every 30s | `DataSetStatusCode` until terminal |
| Errors | `GET .../dataLoadDataSets/{RequestId}/child/messages?onlyData=true` | per-line `SourceSystemId` + `MessageText` |

- **REST resource is `dataLoadDataSets`** (not `hcmDataLoader`, which 404s).
- Dataset name is Fusion's own `RequestId` from `createFileDataSet`; there is no
  client-chosen dataset name.
- Terminal statuses: `ORA_COMPLETED` / `ORA_SUCCESS` / `ORA_IN_ERROR` / `ORA_STOPPED`.
  In-flight statuses seen: `ORA_IN_PROGRESS`, `ORA_UNPROCESSED`.
- **`ORA_IN_ERROR` is the EXPECTED terminal here** — the one bad row errors on
  purpose; the two good rows still load.
- Immediately after `createFileDataSet` the data set is not yet queryable, so the
  first GET may 404; the poller treats that as not-ready and retries.

## Discovery (run before build, read-only BIP, role `hcm_impl`)

One query returns a single row with the element name, input value name, and LDG
name, derived from an existing salary basis on the target pod. HCM base tables are
reached through the `ApplicationDB_FSCM` BIP relay with `hcm_impl` credentials — no
separate HCM data source needed.

```sql
SELECT et.base_element_name AS ELEM_NAME,
       iv.base_name         AS IV_NAME,
       ldg.name             AS LDG_NAME
FROM   cmp_salary_bases b
JOIN   pay_element_types_f et
  ON   et.element_type_id = b.element_type_id
 AND   SYSDATE BETWEEN et.effective_start_date AND et.effective_end_date
JOIN   pay_input_values_f iv
  ON   iv.input_value_id = b.input_value_id
 AND   SYSDATE BETWEEN iv.effective_start_date AND iv.effective_end_date
JOIN   pay_legislative_data_groups ldg
  ON   ldg.legislative_data_group_id = b.legislative_data_group_id
WHERE  b.name = 'US1 Annual Salary'
  AND  ROWNUM = 1
```

→ `${ELEM_NAME}='Regular Salary'`, `${IV_NAME}='Amount'`,
`${LDG_NAME}='US Legislative Data Group'`.

Notes on the HCM tables:

- `cmp_salary_bases` carries the reference ids `element_type_id`, `input_value_id`,
  and `legislative_data_group_id` directly (mimic an existing basis to stay portable).
- Element names come from `pay_element_types_f.base_element_name`; input value names
  from `pay_input_values_f.base_name` (date-effective — filter on SYSDATE).
- LDG names come from `pay_legislative_data_groups.name`. The `_vl`/`_tl` name-view
  variants SOAP-fault through this relay; the base table works.

## Verification (read-only, direct single-table reads)

- **Good → base.** Direct read of `CMP_SALARY_BASES` filtered by the run's name
  prefix. A `SALARY_BASIS_ID` present for each good `SalaryBasisName` = pass.

```sql
SELECT b.name AS BASIS_NAME,
       TO_CHAR(MAX(b.salary_basis_id)) AS SALARY_BASIS_ID
FROM   cmp_salary_bases b
WHERE  b.name LIKE '<prefix> DMT%'
GROUP BY b.name
```

- **Bad → HDL error, absent from base.** The bad evidence is the load-time HDL
  message keyed by `SourceSystemId` (`GET .../{RequestId}/child/messages`). The base
  read above returns only the two good rows — no `<prefix> DMT Bad Basis` — confirming
  the bad basis was never created.

Note: `good_keys` are the prefixed `SalaryBasisName`s (base is keyed on name);
`bad_keys` is the prefixed `SourceSystemId` (`${PREFIX}DMTSB-BAD`, which the HDL
error message is keyed on). A `SourceSystemId` is never a basis name, so the
bad-absent-from-base check holds trivially and is reinforced by the base read
returning exactly the two good rows.

## How to run it

```bash
cd gold_regression/harness
python run_object.py SalaryBases --prefix <PREFIX>   # discover -> build -> upload/submit/poll -> verify
```

## Live evidence

**2026-07-19 — LIVE-PROVEN. PASS.**

Standalone load path only; verification via the read-only BIP relay only.

| Field | Value |
|---|---|
| Date | 2026-07-19 |
| Prefix | `90263` |
| HDL data set RequestId | `9763638` |
| Terminal DataSetStatusCode | `ORA_IN_ERROR` (expected: 2 good loaded, 1 bad errored) |
| Import / Load counts | import 3 ok / 0 err; load **2 ok / 1 err** |
| Discovered element | `Regular Salary` |
| Discovered input value | `Amount` |
| Discovered LDG | `US Legislative Data Group` |

**Good rows → base table `CMP_SALARY_BASES` (2/2):**

| SalaryBasisName | SALARY_BASIS_ID |
|---|---|
| `90263 DMT Annual Salary` | `300000331542962` |
| `90263 DMT Annual Salary 2` | `300000331542960` |

**Bad row → HDL error, no basis created (1/1):**

| SourceSystemId | HDL error |
|---|---|
| `90263DMTSB-BAD` | `You need to enter a valid value for the ElementTypeId attribute. The current values are DMT NONEXISTENT ELEMENT 90263,US Legislative Data Group.` |

The two good salary bases reached `CMP_SALARY_BASES` with real ids; the bad basis
errored in the loader (file line 4) and created nothing. Gold zip
`SalaryBases_gold.zip` (last built at prefix 90263) kept here.

**Earlier-attempt note (fixed):** prefix 90261 used the prefixed source id as
`SalaryBasisCode` — all three rows failed with *"SalaryBasisCode … doesn't exist in
the list of values."* `SalaryBasisCode` is a frequency LOV (`ANNUAL`/`HOURLY`/
`MONTHLY`/`PERIOD`); set to `ANNUAL` and the good rows loaded (prefix 90262, then a
clean full pass on 90263).

## Sources (SalaryBasisCode frequency LOV)

- Oracle docs — Guidelines for Loading Salary Basis Components Using HCM Data Loader:
  https://docs.oracle.com/en/cloud/saas/human-resources/fahbo/guidelines-for-loading-salary-basis-components-using-hcm-data-loader.html
- Loading Salary and Salary Basis Using HCM Data Loader (SalaryBasisCode = ANNUAL/HOURLY/MONTHLY/PERIOD).
