# Assignments — gold regression fixture (HDL)

A standalone, reloadable **HDL** fixture (2 good assignment changes + 1 bad) that
loads directly into Oracle Fusion HCM through the HCM Data Loader REST service
(upload → createFileDataSet → poll), verified read-only via BIP against the base
assignment table `PER_ALL_ASSIGNMENTS_M`. No DMT tool code and no DMT database are
in the load path.

## What this fixture does (the portable scenario)

Assignments is proven as an **update to existing assignments**, not a new hire.
Each good row makes a **date-effective working-hours change** (`NormalHours`
40 → 37.5, `ActionCode = WORK_HOURS_CHANGE`) on an assignment that already exists
on the target pod. The bad row attempts the same change with an invalid
`ActionCode`, which HCM Data Loader rejects, changing nothing.

### Why it is portable (no upstream dependency)

This fixture does **not** create a worker first and does **not** reference any
worker/assignment we loaded earlier. At load time it runs one read-only BIP query
against the target pod and discovers **three existing active employee assignments**
in the US1 legislative data group (seeded demo employees with numeric person
numbers, e.g. `E2`/`E3`/`E4` on persons `2`/`3`/`4`). It discovers, for each, the
full set of user-key values needed to address the record:

- `AssignmentNumber` (e.g. `E2`) — the assignment itself,
- `WorkTerms` assignment number (e.g. `ET2`) — the parent employment terms,
- `PersonNumber` (e.g. `2`),
- `LegalEmployerName` (e.g. `US1 Legal Entity`),
- `DateStart` — the period-of-service start date (e.g. `2004/12/29`).

Those discovered user-key values are stamped into the DAT. The change itself is new
(effective this run's date, `NormalHours = 37.5`), so it reloads cleanly on any
future run.

### The key portability decision — reference existing records by USER KEY, no source key

The DMT pipeline generator (`dmt_assignment_hdl_gen_pkg`) re-states the whole
parent chain (Worker → WorkRelationship → WorkTerms → Assignment) using
`HRC_SQLLOADER` **source keys** (`PERSON_NUMBER || '_POS'`, `_TRM`, `_ASG`). That
only resolves if the worker/assignment was loaded in the same source-key namespace —
i.e. it depends on our own upstream Workers load. Seeded demo employees have **no**
`HRC_SQLLOADER` source key, so that pattern cannot address them.

HCM Data Loader also lets you address an existing record by its **user key**. This
fixture supplies **no `SourceSystemOwner`/`SourceSystemId` columns at all** and
identifies each record purely by user key. That is what makes it self-sufficient
against a fresh pod.

Two lessons learned the hard way (both cost a failed run):

1. **Do not invent a fresh `SourceSystemId` for a record that already exists but has
   no source key.** HDL then reports *"You can't update this record because the
   SourceSystemId … and SourceSystemOwner HRC_SQLLOADER are invalid."* The fix is to
   drop the source-key columns entirely and let the user key match.
2. **An Assignment date-effective change requires the same date-effective split on
   its WorkTerms.** With only an `Assignment` section HDL returns *"Work terms
   records are required when you create or update assignments."* So the file carries
   a matching `WorkTerms` MERGE (same `EffectiveStartDate`, `EffectiveSequence = 1`,
   `EffectiveLatestChange = Y`, `ActionCode = WORK_HOURS_CHANGE`) for every good row.

## The DAT (`Assignment.dat` template → zipped as `Worker.dat`)

The top-level HCM business object is **Worker**; `Assignment`/`WorkTerms` are its
components. HDL requires the DAT/zip member to be named after a **top-level**
object, so the file inside `Assignments_gold.zip` is named **`Worker.dat`** even
though it only carries `WorkTerms` and `Assignment` sections. (Naming it
`Assignment.dat` fails with *"The Assignment file name isn't valid…"*.)

```
SET PURGE_FUTURE_CHANGES N
METADATA|WorkTerms|AssignmentNumber|PersonNumber|LegalEmployerName|DateStart|WorkerType|ActionCode|EffectiveStartDate|EffectiveEndDate|EffectiveSequence|EffectiveLatestChange|PrimaryWorkTermsFlag
MERGE|WorkTerms|${WT1}|${PN1}|${LE1}|${DS1}|E|WORK_HOURS_CHANGE|${GL_DATE_SLASH}|4712/12/31|1|Y|Y
MERGE|WorkTerms|${WT2}|${PN2}|${LE2}|${DS2}|E|WORK_HOURS_CHANGE|${GL_DATE_SLASH}|4712/12/31|1|Y|Y
MERGE|WorkTerms|${WT3}|${PN3}|${LE3}|${DS3}|E|DMT_INVALID_ACTION|${GL_DATE_SLASH}|4712/12/31|1|Y|Y
METADATA|Assignment|AssignmentNumber|PersonNumber|LegalEmployerName|DateStart|WorkerType|WorkTermsNumber|ActionCode|EffectiveStartDate|EffectiveEndDate|EffectiveSequence|EffectiveLatestChange|PrimaryAssignmentFlag|NormalHours
MERGE|Assignment|${ASG1}|${PN1}|${LE1}|${DS1}|E|${WT1}|WORK_HOURS_CHANGE|${GL_DATE_SLASH}|4712/12/31|1|Y|Y|37.5
MERGE|Assignment|${ASG2}|${PN2}|${LE2}|${DS2}|E|${WT2}|WORK_HOURS_CHANGE|${GL_DATE_SLASH}|4712/12/31|1|Y|Y|37.5
MERGE|Assignment|${ASG3}|${PN3}|${LE3}|${DS3}|E|${WT3}|DMT_INVALID_ACTION|${GL_DATE_SLASH}|4712/12/31|1|Y|Y|37.5
```

| Row | AssignmentNumber | ActionCode | NormalHours | Purpose |
|---|---|---|---|---|
| GOOD-1 | `${ASG1}` (discovered) | `WORK_HOURS_CHANGE` | 37.5 | valid → `PER_ALL_ASSIGNMENTS_M` |
| GOOD-2 | `${ASG2}` (discovered) | `WORK_HOURS_CHANGE` | 37.5 | valid → `PER_ALL_ASSIGNMENTS_M` |
| BAD-1  | `${ASG3}` (discovered) | `DMT_INVALID_ACTION` | 37.5 | HDL error, no change |

**Tokens stamped**

- `${PREFIX}` — this fixture supplies no source key, so the prefix does not appear
  in the DAT body. It is still passed to the harness (it keys the bad-row user id
  `${PREFIX}DMTASG-BAD` used only for verification bookkeeping) and keeps the run
  labelled; the record uniqueness comes from the fresh effective date instead.
- `${ASG1..3}`, `${WT1..3}`, `${PN1..3}`, `${LE1..3}`, `${DS1..3}` — the discovered
  user-key values (assignment number, work-terms number, person number, legal
  employer, period-of-service start date) for three existing assignments.
- `${GL_DATE_SLASH}` — today's date (`YYYY/MM/DD`), the effective date of the change.

**Attributes intentionally supplied.** `WorkerType = E`, `EffectiveEndDate =
4712/12/31` (open-ended), `EffectiveSequence = 1`, `EffectiveLatestChange = Y`, and
the primary flags are required for a date-effective assignment change. `SET
PURGE_FUTURE_CHANGES N` protects any future-dated rows on the assignment.

**Bad-row design.** The bad row uses `ActionCode = DMT_INVALID_ACTION`, which is not
a valid assignment action. HDL rejects it with *"You must enter a valid value for
the ActionCode field."* and makes no change to the assignment. Its work-terms line
carries the same invalid action so the whole bad split is rejected together. Because
this fixture supplies no `SourceSystemId`, the HDL rejection message comes back with
a **null `SourceSystemId`**; verification matches it by the expected error text (see
below), not by source key.

## The exact call (HCM Data Loader REST, credential role `hcm_impl`)

| Step | Method + URL | Body / key |
|---|---|---|
| Upload | `POST {FUSION_URL}/hcmRestApi/resources/11.13.18.05/dataLoadDataSets/action/uploadFile` | `{content:<b64 zip>, fileName}` → `ContentId` |
| Submit | `POST .../dataLoadDataSets/action/createFileDataSet` | `{contentId, fileAction:"IMPORT_AND_LOAD"}` → `RequestId` |
| Poll | `GET .../dataLoadDataSets/{RequestId}` every 30s | `DataSetStatusCode` until terminal |
| Errors | `GET .../dataLoadDataSets/{RequestId}/child/messages?onlyData=true` | per-line `MessageText` (`SourceSystemId` null for user-key updates) |

- **REST resource is `dataLoadDataSets`** (not `hcmDataLoader`, which 404s).
- **Dataset naming** is Fusion's own `RequestId` returned by `createFileDataSet`;
  there is no client-chosen dataset name for this flow.
- Terminal statuses: `ORA_COMPLETED` / `ORA_SUCCESS` / `ORA_IN_ERROR` / `ORA_STOPPED`.
  In-flight statuses seen: `ORA_IN_PROGRESS`, `ORA_UNPROCESSED`.
- **`ORA_IN_ERROR` is the EXPECTED terminal here** — the one bad row errors on
  purpose. The two good rows still load (partial success: load 2 ok / 1 err). The
  poll may take ~150s to reach terminal; poll patiently.
- Immediately after `createFileDataSet` the data set is not yet queryable, so the
  first GET may 404; the poller treats that as not-ready and retries.

## Discovery (run before build, read-only BIP, role `hcm_impl`)

One query returns a single row with three existing active assignments and, for each,
the full user-key set. US1 legislative data group id is `300000046974970`.

```sql
SELECT MAX(CASE WHEN c.rn=1 THEN c.asg END) AS ASG1, MAX(CASE WHEN c.rn=1 THEN c.wt END) AS WT1,
       MAX(CASE WHEN c.rn=1 THEN c.pn END) AS PN1, MAX(CASE WHEN c.rn=1 THEN c.le END) AS LE1,
       MAX(CASE WHEN c.rn=1 THEN c.ds END) AS DS1,
       MAX(CASE WHEN c.rn=2 THEN c.asg END) AS ASG2, ... (rn=2 columns) ...,
       MAX(CASE WHEN c.rn=3 THEN c.asg END) AS ASG3, ... (rn=3 columns) ...
FROM (
  SELECT a.assignment_number AS asg,
         wt.assignment_number AS wt,           -- parent WorkTerms user key (ET-number)
         p.person_number      AS pn,
         le_tl.name           AS le,           -- legal employer name
         TO_CHAR(pos.date_start,'YYYY/MM/DD') AS ds,  -- period-of-service start
         ROW_NUMBER() OVER (ORDER BY a.assignment_id) rn
  FROM per_all_assignments_m a
  JOIN per_all_people_f p
    ON p.person_id = a.person_id AND SYSDATE BETWEEN p.effective_start_date AND p.effective_end_date
  JOIN pay_pay_relationships_dn pr
    ON pr.person_id = a.person_id AND pr.legislative_data_group_id = 300000046974970  -- US1 LDG
  JOIN per_all_assignments_m wt
    ON wt.period_of_service_id = a.period_of_service_id
   AND wt.assignment_type='ET' AND wt.effective_latest_change='Y'
   AND SYSDATE BETWEEN wt.effective_start_date AND wt.effective_end_date
  JOIN per_periods_of_service pos ON pos.period_of_service_id = a.period_of_service_id
  JOIN hr_organization_units_f_tl le_tl
    ON le_tl.organization_id = pos.legal_entity_id AND le_tl.language='US'
   AND SYSDATE BETWEEN le_tl.effective_start_date AND le_tl.effective_end_date
  WHERE a.effective_latest_change='Y'
    AND SYSDATE BETWEEN a.effective_start_date AND a.effective_end_date
    AND a.assignment_type='E' AND a.primary_flag='Y'
    AND a.assignment_status_type='ACTIVE'
    AND REGEXP_LIKE(p.person_number,'^[0-9]+$')   -- seeded demo employees only
) c
WHERE c.rn <= 3
```

→ e.g. `${ASG1}='E2' ${WT1}='ET2' ${PN1}='2' ${LE1}='US1 Legal Entity' ${DS1}='2004/12/29'`,
and likewise for E3 / E4.

Notes on the HCM tables (reached through the `ApplicationDB_FSCM` BIP relay with
`hcm_impl` credentials — no separate HCM data source):

- `per_all_assignments_m` on this pod has **no** `worker_category` column (an early
  probe hit `ORA-00904: "A"."WORKER_CATEGORY"`); use `employment_category` instead.
- The work-terms record is the same table with `assignment_type='ET'`, linked to the
  employee assignment (`assignment_type='E'`) by `period_of_service_id`.
- Legislative data group is reached through `pay_pay_relationships_dn`, not from the
  assignment directly.

## Verification (read-only, direct single-table reads)

- **Good → base.** Direct read of `PER_ALL_ASSIGNMENTS_M` for the discovered
  assignment numbers where the latest-change split has `normal_hours = 37.5` and an
  effective start on/after this run. A row present with a real `ASSIGNMENT_ID` for
  each good `AssignmentNumber` = pass. (The assignments were at 40 hours with no
  recent split before the load, so any 37.5 split at the run date is unambiguously
  ours.)

```sql
SELECT a.assignment_number, MAX(a.assignment_id), MAX(a.normal_hours)
FROM   per_all_assignments_m a
WHERE  a.assignment_number IN ('<ASG1>','<ASG2>','<ASG3>')
  AND  a.effective_latest_change='Y'
  AND  a.effective_start_date >= TRUNC(SYSDATE) - 2   -- covers pod/local timezone skew
  AND  a.normal_hours = 37.5
GROUP BY a.assignment_number
```

  **Timezone note:** the Fusion pod's `SYSDATE` ran one day ahead of the build
  machine, so the split lands at the build date (`2026/07/19`) while the pod thinks
  "today" is `2026/07/20`. The verify window `>= TRUNC(SYSDATE) - 2` absorbs that
  skew without widening scope enough to catch anything but this run's change.

- **Bad → HDL error, absent from base.** The bad evidence is the load-time HDL
  message (*"You must enter a valid value for the ActionCode field."*). Because a
  user-key update returns that message with a null `SourceSystemId`, the recipe
  declares `"bad_error_contains": "valid value for the ActionCode field"` and the
  verifier matches the source-key-less error by that text. The base read above
  returns no 37.5 split for the bad assignment (`E4`), confirming no change.

## Harness note (one additive change)

`harness/verify.py` gained one additive, opt-in branch: when a recipe declares
`bad_error_contains`, the HDL bad-row check also accepts a rejection message whose
`SourceSystemId` is null but whose text contains that snippet. This is needed only
for user-key updates (like this object) where HDL returns no source key on the
error line. Objects that address records by source key (Workers, Salaries) are
unaffected — they never set `bad_error_contains` and keep matching on
`SourceSystemId`.

## How to run it

```bash
cd gold_regression/harness
python run_object.py Assignments --prefix <PREFIX>   # discover -> build -> upload/submit/poll -> verify
```

## Live evidence

**2026-07-19 — LIVE-PROVEN. PASS.**

Standalone load path only; verification via the read-only BIP relay only.

| Field | Value |
|---|---|
| Date | 2026-07-19 (pod SYSDATE 2026-07-20) |
| Prefix | `90264` |
| HDL UCM ContentId | `UCMFA07636988` |
| HDL data set RequestId | `9764168` |
| Terminal DataSetStatusCode | `ORA_IN_ERROR` (expected: 2 good loaded, 1 bad errored) |
| Import / Load counts | import 6 ok / 0 err; load **2 ok / 1 err** |
| Discovered assignments | GOOD `E2`, `E3`; BAD `E4` (persons 2/3/4, US1 Legal Entity) |

**Good rows → base table `PER_ALL_ASSIGNMENTS_M` (2/2):**

| AssignmentNumber | ASSIGNMENT_ID | NormalHours | Effective start |
|---|---|---|---|
| `E2` | `300000047339531` | 37.5 | 2026/07/19 |
| `E3` | `300000047340518` | 37.5 | 2026/07/19 |

**Bad row → HDL error, no change (1/1):**

| AssignmentNumber | HDL error |
|---|---|
| `E4` (user id `90264DMTASG-BAD`) | `You must enter a valid value for the ActionCode field.` |

The two good assignments received a new date-effective split with `NormalHours =
37.5` on existing demo-employee assignments; the bad assignment change was rejected
in the loader and left the assignment unchanged (no 37.5 split for `E4`). Gold zip
`Assignments_gold.zip` (last built at prefix 90264) kept here.

**Earlier-attempt notes (all fixed, in order):**

1. Member named `Assignment.dat` → *"The Assignment file name isn't valid."* Fixed by
   naming the zip member `Worker.dat` (top-level object).
2. Assignment-only file → *"You must provide a valid reference to the parent record."*
   The Assignment needs its parent WorkTerms in the file.
3. `WorkTermsAssignmentId(WorkTermsNumber)` hint → *"The key resolution hint
   WorkTermsNumber … is invalid."* Fixed by using the plain `WorkTermsNumber` column.
4. Full source-key chain with a `Worker` line → *"…SourceSystemId … invalid"* on the
   Worker, because the seeded person has no HDL source key.
5. `PersonId(PersonNumber)` / `PeriodOfServiceId(PersonNumber,LegalEmployerName,DateStart)`
   hints → *"key resolution hint … is invalid."* Multi-attribute user-key hints are
   not valid syntax.
6. Supplying a fresh `SourceSystemId` on the WorkTerms/Assignment → *"…SourceSystemId
   … invalid"*. Fixed by dropping source-key columns entirely and matching purely on
   user key — the pattern that finally loaded the good rows.
7. `ActionCode = ASG_CHANGE` was tried before landing on `WORK_HOURS_CHANGE`, the
   valid action for a working-hours change.
