# Salaries — gold regression fixture (HDL)

A standalone, reloadable **HDL** fixture (2 good salary records + 1 bad) that
loads directly into Oracle Fusion HCM through the HCM Data Loader REST service
(upload → createFileDataSet → poll), verified read-only via BIP against the base
salary table `CMP_SALARY`. No DMT tool code and no DMT database are in the load
path.

## Why this fixture is portable (no upstream dependency)

A salary attaches to an **existing assignment** of an **existing worker** and
references an **existing salary basis**. This fixture does **not** load a worker
first, and it does **not** reference the prefixed workers we created earlier.

At load time it runs one read-only BIP query against the target pod and
discovers:

- an **existing valid salary basis** for the US legislative data group
  (`US1 Annual Salary`), and
- **three existing employee assignments that currently have NO salary** (seeded
  demo employees in the US1 legislative data group, e.g. `E6`, `E8`, `E10`, ...).

Those discovered `AssignmentNumber` values and the salary-basis name are stamped
into `Salary.dat`. The salary records themselves are new (fresh effective date
`2026/07/19`, prefix-stamped `SourceSystemId`), so the fixture reloads cleanly on
any future run without colliding — the discovery query excludes any assignment
that already has a salary, so a re-run automatically picks the next set of
salary-free assignments.

### The key portability decision — reference by AssignmentNumber, not by source key

The DMT pipeline generator (`dmt_salary_hdl_gen_pkg`) references the assignment
with the source-key hint `AssignmentId(SourceSystemId)` set to
`PERSON_NUMBER || '_ASG'`. That only resolves if the worker/assignment was loaded
in the **same** HDL batch under `HRC_SQLLOADER` source keys — i.e. it depends on
our own upstream Workers load. Seeded demo employees have **no** HDL source key,
so that hint cannot resolve for them.

HCM Data Loader also lets you reference an existing assignment by its **user key**
`AssignmentNumber` directly. This fixture uses `AssignmentNumber`, which is what
makes it self-sufficient against a fresh pod. (Confirmed against Oracle HDL docs:
"If you are supplying the user-key value, use the `AssignmentNumber` attribute;"
the `AssignmentId(SourceSystemId)` hint is only for assignments you loaded with a
source key.)

## The DAT (`Salary.dat`, pipe-delimited HDL)

One `Salary.dat` inside `Salaries_gold.zip`. One `Salary` section, three MERGE
lines:

```
METADATA|Salary|SourceSystemOwner|SourceSystemId|AssignmentNumber|DateFrom|SalaryAmount|SalaryBasisName|SalaryApproved|ActionCode
MERGE|Salary|HRC_SQLLOADER|${PREFIX}DMTSAL001|${ASG1}|2026/07/19|75000|${SALARY_BASIS}|Y|CHANGE_SALARY
MERGE|Salary|HRC_SQLLOADER|${PREFIX}DMTSAL002|${ASG2}|2026/07/19|85000|${SALARY_BASIS}|Y|CHANGE_SALARY
MERGE|Salary|HRC_SQLLOADER|${PREFIX}DMTSAL-BAD|${ASG3}|2026/07/19|50000|DMT NONEXISTENT SALARY BASIS|Y|CHANGE_SALARY
```

| Row | SourceSystemId | AssignmentNumber | SalaryBasisName | Purpose |
|---|---|---|---|---|
| GOOD-1 | `${PREFIX}DMTSAL001` | `${ASG1}` (discovered) | `${SALARY_BASIS}` (discovered) | valid → `CMP_SALARY` |
| GOOD-2 | `${PREFIX}DMTSAL002` | `${ASG2}` (discovered) | `${SALARY_BASIS}` (discovered) | valid → `CMP_SALARY` |
| BAD-1  | `${PREFIX}DMTSAL-BAD` | `${ASG3}` (discovered) | `DMT NONEXISTENT SALARY BASIS` | HDL error, no salary |

**Tokens stamped**

- `${PREFIX}` on each salary `SourceSystemId` — keeps the new records unique and reloadable.
- `${ASG1}`, `${ASG2}`, `${ASG3}` — discovered `AssignmentNumber`s of existing salary-free demo employees.
- `${SALARY_BASIS}` — discovered salary-basis name (`US1 Annual Salary`).

**Metadata attributes that are intentionally NOT supplied** (Fusion V2 rejects
them as auto-derived): `EffectiveStartDate`, `PersonNumber`, `AnnualSalary`,
`CurrencyCode`, `FrequencyName`. Reference the assignment only, not the person.

**`ActionCode` must be a real salary action name.** The valid value for a net-new
salary on an existing assignment is **`CHANGE_SALARY`**. A first attempt used
`SAL_CHANGE`, which HDL rejected with *"You need to enter a valid value for the
ActionId attribute. The current values are SAL_CHANGE."* (`HIRE` is only valid
for the first salary at the moment of hire — not for these already-hired demo
employees.)

**Bad-row design.** The bad row uses a `SalaryBasisName` that does not exist
(`DMT NONEXISTENT SALARY BASIS`). HDL rejects it with a `SalaryBasisId` error and
creates no salary. It reaches the loader and errors there deterministically.

## The exact call (HCM Data Loader REST, credential role `hcm_impl`)

| Step | Method + URL | Body / key |
|---|---|---|
| Upload | `POST {FUSION_URL}/hcmRestApi/resources/11.13.18.05/dataLoadDataSets/action/uploadFile` | `{content:<b64 zip>, fileName}` → `ContentId` |
| Submit | `POST .../dataLoadDataSets/action/createFileDataSet` | `{contentId, fileAction:"IMPORT_AND_LOAD"}` → `RequestId` |
| Poll | `GET .../dataLoadDataSets/{RequestId}` every 30s | `DataSetStatusCode` until terminal |
| Errors | `GET .../dataLoadDataSets/{RequestId}/child/messages?onlyData=true` | per-line `SourceSystemId` + `MessageText` |

- **REST resource is `dataLoadDataSets`** (not `hcmDataLoader`, which 404s).
- **Dataset naming** is Fusion's own `RequestId` returned by `createFileDataSet`; there is no client-chosen dataset name for this flow.
- Terminal statuses: `ORA_COMPLETED` / `ORA_SUCCESS` / `ORA_IN_ERROR` / `ORA_STOPPED`. In-flight statuses seen: `ORA_IN_PROGRESS`, `ORA_UNPROCESSED`.
- **`ORA_IN_ERROR` is the EXPECTED terminal here** — the one bad row errors on purpose. The two good rows still load (partial success: load 2 ok / 1 err).
- Immediately after `createFileDataSet` the data set is not yet queryable, so the first GET may 404; the poller treats that as not-ready and retries.

## Discovery (run before build, read-only BIP, role `hcm_impl`)

One query returns a single row with the salary basis and three salary-free
assignment numbers. The US1 legislative data group id is `300000046974970`; the
`US1 Annual Salary` basis id is `300000048365126`.

```sql
SELECT b.name AS BASIS_NAME,
       TO_CHAR(b.salary_basis_id) AS BASIS_ID,
       MAX(CASE WHEN c.rn=1 THEN c.assignment_number END) AS ASG1,
       MAX(CASE WHEN c.rn=2 THEN c.assignment_number END) AS ASG2,
       MAX(CASE WHEN c.rn=3 THEN c.assignment_number END) AS ASG3
FROM cmp_salary_bases b
CROSS JOIN (
  SELECT a.assignment_number,
         ROW_NUMBER() OVER (ORDER BY a.assignment_id) rn
  FROM per_all_assignments_m a
  JOIN per_all_people_f p
    ON p.person_id = a.person_id
   AND SYSDATE BETWEEN p.effective_start_date AND p.effective_end_date
  JOIN pay_pay_relationships_dn pr
    ON pr.person_id = a.person_id
   AND pr.legislative_data_group_id = 300000046974970   -- US1 LDG
  WHERE a.effective_latest_change = 'Y'
    AND SYSDATE BETWEEN a.effective_start_date AND a.effective_end_date
    AND a.assignment_type = 'E'
    AND a.primary_flag = 'Y'
    AND NOT EXISTS (SELECT 1 FROM cmp_salary s WHERE s.assignment_id = a.assignment_id)
    AND REGEXP_LIKE(p.person_number, '^[0-9]+$')          -- seeded demo employees only
) c
WHERE b.name = 'US1 Annual Salary' AND c.rn <= 3
GROUP BY b.name, b.salary_basis_id
```

→ e.g. `${SALARY_BASIS}='US1 Annual Salary'`, `${SALARY_BASIS_ID}='300000048365126'`,
`${ASG1}='E6'`, `${ASG2}='E8'`, `${ASG3}='E10'` (values shift on re-runs because
salary-free assignments are consumed).

Notes on the HCM tables (reached through the `ApplicationDB_FSCM` BIP relay with
`hcm_impl` credentials — no separate HCM data source needed):

- `per_all_assignments_m` has **no** legislative-data-group column. Link the
  assignment to its legislative data group through
  `pay_pay_relationships_dn.legislative_data_group_id`.
- `cmp_salary_bases` carries the basis `name` directly (no TL join needed).
- The `hrc_integration_key_map` source-key map is **not** queryable through this
  BIP relay (SOAP fault), so verification keys good rows on `AssignmentNumber`,
  not on the salary `SourceSystemId`.

## Verification (read-only, direct single-table reads)

- **Good → base.** Direct read of `CMP_SALARY` joined to `PER_ALL_ASSIGNMENTS_M`,
  scoped to the discovered `US1 Annual Salary` basis id, the fresh effective date
  `2026-07-19`, and the discovered assignment numbers. A `SALARY_ID` present for
  each good `AssignmentNumber` = pass. (The discovered assignments were salary-free
  at load time, so any `CMP_SALARY` row for them at that date is unambiguously ours.)

```sql
SELECT a.assignment_number AS ASG_NUM,
       MAX(s.salary_id)    AS SALARY_ID,
       MAX(s.salary_amount) AS SALARY_AMOUNT
FROM cmp_salary s
JOIN per_all_assignments_m a
  ON a.assignment_id = s.assignment_id AND a.effective_latest_change = 'Y'
WHERE s.salary_basis_id = <discovered ${SALARY_BASIS_ID}>
  AND s.date_from = DATE '2026-07-19'
  AND a.assignment_number IN ('<ASG1>','<ASG2>','<ASG3>')
GROUP BY a.assignment_number
```

- **Bad → HDL error, absent from base.** The bad evidence is the load-time HDL
  message list keyed by `SourceSystemId` (`GET .../{RequestId}/child/messages`).
  The base read above returns no row for the bad assignment, confirming absence.

## How to run it

```bash
cd gold_regression/harness
python run_object.py Salaries --prefix <PREFIX>   # discover -> build -> upload/submit/poll -> verify
```

## Live evidence

**2026-07-19 — LIVE-PROVEN. PASS.**

Standalone load path only; verification via the read-only BIP relay only.

| Field | Value |
|---|---|
| Date | 2026-07-19 |
| Prefix | `90221` |
| HDL data set RequestId | `9763105` |
| Terminal DataSetStatusCode | `ORA_IN_ERROR` (expected: 2 good loaded, 1 bad errored) |
| Import / Load counts | import 3 ok / 0 err; load **2 ok / 1 err** |
| Discovered salary basis | `US1 Annual Salary` (id `300000048365126`, US1 LDG `300000046974970`) |
| Discovered assignments | GOOD `E10`, `E12`; BAD `E13` (salary-free demo employees) |

**Good rows → base table `CMP_SALARY` (2/2):**

| AssignmentNumber | SALARY_ID | SalaryAmount | DateFrom |
|---|---|---|---|
| `E10` | `300000331542638` | 75000 | 2026-07-19 |
| `E12` | `300000331542641` | 85000 | 2026-07-19 |

**Bad row → HDL error, no salary created (1/1):**

| SourceSystemId | HDL error |
|---|---|
| `90221DMTSAL-BAD` | `You need to enter a valid value for the SalaryBasisId attribute. The current values are DMT NONEXISTENT SALARY BASIS.` |

The two good salaries reached `CMP_SALARY` with real salary ids on existing
demo-employee assignments; the bad salary errored in the loader (file line 4) and
created no salary. Gold zip `Salaries_gold.zip` (last built at prefix 90221) kept
here.

**Earlier-attempt note (fixed):** prefix 90219 used `ActionCode=SAL_CHANGE`, which
HDL rejected as an invalid `ActionId` — all three rows failed the load step
(import still succeeded 3/3). Changed to `CHANGE_SALARY` and the good rows loaded
(prefix 90220, then a clean full pass on 90221).

## Harness note

`run_object.py` now passes the discovered `tokens` into the HDL verify call (the
FBDI branch already did). This lets a fixture whose base-table key is a discovered
value — here the `AssignmentNumber` — scope its verification read to exactly the
references it just loaded. No other harness change was needed.
