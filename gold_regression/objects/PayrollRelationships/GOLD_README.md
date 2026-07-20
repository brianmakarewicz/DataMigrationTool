# PayrollRelationships — gold regression fixture (HDL, AssignedPayroll)

A standalone, reloadable **HDL** fixture (2 good rows + 1 bad row) that assigns a
payroll to existing employees through the HCM Data Loader REST service (upload →
createFileDataSet → poll), verified read-only via BIP against the base table
`PAY_ASSIGNED_PAYROLLS_DN`. No DMT tool code and no DMT database are in the load path.

## What "PayrollRelationship" means for a portable gold fixture

A payroll relationship is created automatically by Fusion when a work relationship
exists; you do not load a bare payroll relationship on its own. The loadable,
data-carrying piece of the payroll-relationship area is the **assigned payroll** —
attaching an existing person's assignment to an existing **payroll definition**.
The HDL business object for that is **`AssignedPayroll`**.

So this fixture loads `AssignedPayroll` rows. Each row references:

- an **existing employee assignment** (by its user key `AssignmentNumber`), and
- an **existing payroll definition** (by `PayrollDefinitionCode`, which on this pod
  is the payroll name), and
- the **legislative data group** the payroll belongs to.

Nothing is created upstream. There is **no dependency on our earlier Workers or
Salaries loads** — the persons, their payroll relationships, and the payroll
definition all already ship on the pod.

## Why this fixture is portable (no upstream dependency)

At load time it runs one read-only BIP query against the target pod and discovers:

- the **US legislative data group** name (`US Legislative Data Group`,
  id `300000046974970`),
- an **existing US payroll definition** (`Biweekly`, payroll id `300000051084930`), and
- **three existing US employee assignments that have a payroll relationship but no
  assigned payroll yet** and that have a work location set (seeded demo employees
  like `E2`, `E3`, `E4`).

Those `AssignmentNumber` values, the payroll name, and the LDG name are stamped into
`AssignedPayroll.dat`. The assigned-payroll records are new (effective date
`2026/07/19`), so the fixture reloads cleanly: the discovery query excludes any
assignment that already has an assigned payroll, so a re-run automatically picks the
next set of payroll-free assignments.

### Two references that make the fixture self-sufficient

- **Reference the assignment by `AssignmentNumber`, not by a source key.** Seeded
  demo employees were never loaded through HDL, so an `AssignmentId(SourceSystemId)`
  hint (what the DMT generator emits, `PERSON_NUMBER || '_POS'`) cannot resolve for
  them. `AssignmentNumber` is the existing-record user key and resolves on any pod.
- **Reference the payroll by `PayrollDefinitionCode`.** On this pod no separate
  payroll code column exists, so the payroll name (`Biweekly`) is the code.

### Discovery must require a work location on the assignment

The very-high-numbered assignments (candidate/incomplete records, e.g. `E7775`) have
**no work location**, and Fusion rejects the payroll assignment with *"You must
specify a work location address for this person."* The discovery query therefore adds
`a.location_id IS NOT NULL` and orders by `assignment_id ASC`, which selects the
established seeded employees (`E2`, `E3`, …) that do have a location.

## The DAT (`AssignedPayroll.dat`, pipe-delimited HDL)

One `AssignedPayroll.dat` inside `PayrollRelationships_gold.zip`. One `AssignedPayroll`
section, three MERGE lines:

```
METADATA|AssignedPayroll|EffectiveStartDate|AssignmentNumber|PayrollDefinitionCode|LegislativeDataGroupName|StartDate
MERGE|AssignedPayroll|2026/07/19|${ASG1}|${PAYROLL_NAME}|${LDG_NAME}|2026/07/19
MERGE|AssignedPayroll|2026/07/19|${ASG2}|${PAYROLL_NAME}|${LDG_NAME}|2026/07/19
MERGE|AssignedPayroll|2026/07/19|${ASG3}|DMT NONEXISTENT PAYROLL|${LDG_NAME}|2026/07/19
```

| Row | AssignmentNumber | PayrollDefinitionCode | Purpose |
|---|---|---|---|
| GOOD-1 | `${ASG1}` (discovered) | `${PAYROLL_NAME}` (discovered) | valid → `PAY_ASSIGNED_PAYROLLS_DN` |
| GOOD-2 | `${ASG2}` (discovered) | `${PAYROLL_NAME}` (discovered) | valid → `PAY_ASSIGNED_PAYROLLS_DN` |
| BAD-1  | `${ASG3}` (discovered) | `DMT NONEXISTENT PAYROLL` | HDL error, no assigned payroll |

**The .dat file name must be `AssignedPayroll.dat`.** HDL derives the business object
from the file name; a file named `PayrollRelationship.dat` is rejected with *"The
PayrollRelationship file name isn't valid. You need to use the name of a top-level
supported business object as the file name."* The recipe's `archive_name` is set to
`AssignedPayroll.dat` for this reason (the template on disk is still
`PayrollRelationship.dat`, only the name inside the zip is `AssignedPayroll.dat`).

**`StartDate` is required.** Without it the loader rejects every line with *"The line
for component AssignedPayroll with instruction MERGE doesn't include values that
define a unique reference to the record."* `StartDate` (the payroll assignment's own
start) plus `AssignmentNumber` is what uniquely identifies the record.

**Tokens stamped**

- `${ASG1}`, `${ASG2}`, `${ASG3}` — discovered `AssignmentNumber`s of existing
  payroll-free US demo employees (that have a work location).
- `${PAYROLL_NAME}` — discovered payroll definition name (`Biweekly`), used as the
  `PayrollDefinitionCode`.
- `${LDG_NAME}` — discovered legislative data group name (`US Legislative Data Group`).

**Bad-row design.** The bad row uses a `PayrollDefinitionCode` that does not exist
(`DMT NONEXISTENT PAYROLL`). HDL rejects it with a `PayrollId` error and creates no
assigned payroll. It reaches the loader and errors there deterministically. (The
`AssignmentNumber` on the bad row is a real assignment, so the failure is squarely
the invalid payroll — the assignment is unchanged.)

## The exact call (HCM Data Loader REST, credential role `hcm_impl`)

| Step | Method + URL | Body / key |
|---|---|---|
| Upload | `POST {FUSION_URL}/hcmRestApi/resources/11.13.18.05/dataLoadDataSets/action/uploadFile` | `{content:<b64 zip>, fileName}` → `ContentId` |
| Submit | `POST .../dataLoadDataSets/action/createFileDataSet` | `{contentId, fileAction:"IMPORT_AND_LOAD"}` → `RequestId` |
| Poll | `GET .../dataLoadDataSets/{RequestId}` every 30s | `DataSetStatusCode` until terminal |
| Errors | `GET .../dataLoadDataSets/{RequestId}/child/messages?onlyData=true` | per-line `DatFileName` + `FileLine` + `MessageText` |

- **REST resource is `dataLoadDataSets`** (not `hcmDataLoader`, which 404s).
- Terminal statuses: `ORA_COMPLETED` / `ORA_SUCCESS` / `ORA_IN_ERROR` / `ORA_STOPPED`.
  In-flight statuses seen: `ORA_IN_PROGRESS`, `ORA_UNPROCESSED`.
- **`ORA_IN_ERROR` is the EXPECTED terminal here** — the one bad row errors on
  purpose. The two good rows still load (partial success: load 2 ok / 1 err).
- Immediately after `createFileDataSet` the data set is not yet queryable, so the
  first GET may 404; the poller treats that as not-ready and retries.
- The import phase converts the file to stage rows first (import counts climb), then
  the load phase applies them (load counts climb). A full pass takes ~2 minutes.

## Discovery (run before build, read-only BIP, role `hcm_impl`)

One query returns a single row with the LDG name, the payroll name + id, and three
payroll-free assignment numbers. The US LDG id is `300000046974970`; the `Biweekly`
payroll id is `300000051084930`.

```sql
SELECT ldg.name AS LDG_NAME,
       pl.payroll_name AS PAYROLL_NAME,
       TO_CHAR(pl.payroll_id) AS PAYROLL_ID,
       MAX(CASE WHEN c.rn=1 THEN c.assignment_number END) AS ASG1,
       MAX(CASE WHEN c.rn=2 THEN c.assignment_number END) AS ASG2,
       MAX(CASE WHEN c.rn=3 THEN c.assignment_number END) AS ASG3
FROM pay_legislative_data_groups ldg
CROSS JOIN (
  SELECT pd.payroll_name, pd.payroll_id
  FROM pay_all_payrolls_f pd
  WHERE pd.legislative_data_group_id = 300000046974970
    AND pd.payroll_name = 'Biweekly'
    AND SYSDATE BETWEEN pd.effective_start_date AND pd.effective_end_date
    AND ROWNUM = 1
) pl
CROSS JOIN (
  SELECT a.assignment_number,
         ROW_NUMBER() OVER (ORDER BY a.assignment_id ASC) rn
  FROM per_all_assignments_m a
  JOIN per_all_people_f p
    ON p.person_id = a.person_id
   AND SYSDATE BETWEEN p.effective_start_date AND p.effective_end_date
  JOIN pay_pay_relationships_dn pr
    ON pr.person_id = a.person_id
   AND pr.legislative_data_group_id = 300000046974970           -- US1 LDG
  WHERE a.effective_latest_change = 'Y'
    AND SYSDATE BETWEEN a.effective_start_date AND a.effective_end_date
    AND a.assignment_type = 'E'
    AND a.primary_flag = 'Y'
    AND a.location_id IS NOT NULL                                -- must have a work location
    AND REGEXP_LIKE(p.person_number, '^[0-9]+$')                 -- seeded demo employees only
    AND NOT EXISTS (                                             -- no assigned payroll yet
      SELECT 1 FROM pay_rel_groups_dn g
      JOIN pay_assigned_payrolls_dn ap ON ap.payroll_term_id = g.term_id
      WHERE g.payroll_relationship_id = pr.payroll_relationship_id)
) c
WHERE ldg.legislative_data_group_id = 300000046974970 AND c.rn <= 3
GROUP BY ldg.name, pl.payroll_name, pl.payroll_id
```

→ e.g. `${LDG_NAME}='US Legislative Data Group'`, `${PAYROLL_NAME}='Biweekly'`,
`${PAYROLL_ID}='300000051084930'`, `${ASG1}='E2'`, `${ASG2}='E3'`, `${ASG3}='E4'`
(values shift on re-runs because payroll-free assignments are consumed).

Notes on the HCM tables (reached through the `ApplicationDB_FSCM` BIP relay with
`hcm_impl` credentials — no separate HCM data source needed):

- `per_all_assignments_m` has no legislative-data-group column. Link the assignment to
  its LDG through `pay_pay_relationships_dn.legislative_data_group_id`.
- `pay_all_payrolls_f` carries the payroll `name` and `payroll_id`; there is no
  separate payroll-code column on this pod, so the name is the code.
- `pay_rel_groups_dn` (the payroll term/group table) is a **lagging replica** in this
  BIP relay: the term rows for newly-loaded assigned payrolls are not visible for
  hours, and even established term rows are sparse. Do **not** verify through it.

## Verification (read-only, direct single-table read)

- **Good → base.** Direct read of `PAY_ASSIGNED_PAYROLLS_DN`, correlated to the
  discovered person/assignment through `PAY_PAY_RELATIONSHIPS_DN` (NOT through the
  lagging `pay_rel_groups_dn`). The assigned payroll's `payroll_term_id` is the
  relationship-level term, whose id sits just above the `payroll_relationship_id`
  (confirmed live: term = payroll_relationship_id + 2). The read is scoped to the
  discovered `Biweekly` payroll id and today's `start_date`, so any row it returns is
  unambiguously this run's. An `ASSIGNED_PAYROLL_ID` present for each good
  `AssignmentNumber` = pass.

```sql
SELECT a.assignment_number AS ASG_NUM,
       MAX(ap.assigned_payroll_id) AS ASSIGNED_PAYROLL_ID,
       MAX(ap.payroll_id)          AS PAYROLL_ID
FROM pay_assigned_payrolls_dn ap
JOIN pay_pay_relationships_dn pr
  ON pr.legislative_data_group_id = 300000046974970
 AND ap.payroll_term_id BETWEEN pr.payroll_relationship_id AND pr.payroll_relationship_id + 5
JOIN per_all_assignments_m a
  ON a.person_id = pr.person_id
 AND a.effective_latest_change = 'Y'
 AND a.assignment_type = 'E' AND a.primary_flag = 'Y'
WHERE ap.legislative_data_group_id = 300000046974970
  AND ap.payroll_id = <discovered ${PAYROLL_ID}>
  AND ap.start_date = DATE '2026-07-19'
  AND a.assignment_number IN ('<ASG1>','<ASG2>','<ASG3>')
GROUP BY a.assignment_number
```

- **Bad → HDL error, absent from base.** The bad evidence is the load-time HDL message
  list keyed by file line (`GET .../{RequestId}/child/messages`). The base read above
  returns no row for the bad assignment, confirming absence.

## How to run it

```bash
cd gold_regression/harness
python run_object.py PayrollRelationships   # discover -> build -> upload/submit/poll -> verify
```

`run_object.py` passes the discovered `tokens` into the HDL verify call, so the base
read is scoped to exactly the discovered payroll id + assignments it just loaded.

## Live evidence

**2026-07-19 — LIVE-PROVEN. PASS.**

Standalone load path only; verification via the read-only BIP relay only.

| Field | Value |
|---|---|
| Date | 2026-07-19 |
| Prefix | `42961` (prefix does not appear in the AssignedPayroll keys; it is the run tag) |
| HDL UCM ContentId | `UCMFA07636442` |
| HDL data set RequestId | `9763689` |
| Terminal DataSetStatusCode | `ORA_IN_ERROR` (expected: 2 good loaded, 1 bad errored) |
| Import / Load counts | import 3 ok / 0 err; load **2 ok / 1 err** |
| Discovered LDG | `US Legislative Data Group` (id `300000046974970`) |
| Discovered payroll | `Biweekly` (payroll id `300000051084930`) |
| Discovered assignments | GOOD `E2`, `E3`; BAD `E4` (payroll-free demo employees) |

**Good rows → base table `PAY_ASSIGNED_PAYROLLS_DN` (2/2):**

| AssignmentNumber | ASSIGNED_PAYROLL_ID | PAYROLL_ID | StartDate |
|---|---|---|---|
| `E2` | `300000331543036` | `300000051084930` (Biweekly) | 2026-07-19 |
| `E3` | `300000331543033` | `300000051084930` (Biweekly) | 2026-07-19 |

**Bad row → HDL error, no assigned payroll created (1/1):**

| AssignmentNumber (file line 4) | HDL error |
|---|---|
| `E4` | `You need to enter a valid value for the PayrollId attribute. The current values are DMT NONEXISTENT PAYROLL,300000046974970.` |

The two good rows reached `PAY_ASSIGNED_PAYROLLS_DN` with real assigned-payroll ids on
existing demo-employee assignments; the bad row errored in the loader (file line 4)
and created no assigned payroll (absent from the base read). Gold zip
`PayrollRelationships_gold.zip` (last built at prefix 42961) kept here.

**Earlier-attempt notes (all fixed, same load session):**

1. File named `PayrollRelationship.dat` with an `AssignedPayroll` METADATA line →
   rejected ("file name isn't valid"). Fixed by naming the zip member
   `AssignedPayroll.dat`.
2. `AssignedPayroll` without `StartDate` → every line rejected ("doesn't include
   values that define a unique reference"). Fixed by adding `StartDate`.
3. Good rows on candidate assignments (`E7775`/`E7774`) with no work location →
   rejected ("You must specify a work location address for this person"). Fixed by
   requiring `a.location_id IS NOT NULL` and ordering by `assignment_id ASC` in
   discovery, which selects established employees (`E2`, `E3`, …).

## Harness note

No harness code change was needed. The recipe uses the existing generic HDL path
(`run_object.py` → `discover` → `build_artifact` → `load_hdl` → `verify`). The only
object-specific pieces are `recipe.json` (discovery + verify SQL, `archive_name`
`AssignedPayroll.dat`) and the `PayrollRelationship.dat` template.
