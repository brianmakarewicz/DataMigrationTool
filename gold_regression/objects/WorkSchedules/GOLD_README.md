# WorkSchedules — gold regression fixture (HDL, WorkPattern business object)

A standalone, reloadable **HDL** fixture (2 good work schedules + 1 bad) that loads
directly into Oracle Fusion HCM via the HCM Data Loader REST service (upload →
createFileDataSet → poll), with read-only BIP verification against the HCM
work-pattern base table. No DMT tool code, no DMT database, is in the load path.

## What "WorkSchedule" means in HDL (important — the model was verified live)

There is **no `WorkSchedule` HDL business object** on the demo pod. The queryable HDL
business-object dictionary (`HRC_DL_BUSINESS_OBJECTS`) shows the loadable schedule-family
objects are:

- **`WorkPattern`** (V1) — the real "work schedule": a repeating pattern of shifts
  assigned to a worker. Children `WorkPatternShift` and `WorkPatternBreak`. **This is
  the object this fixture loads.**
- `ScheduleAssignment` (V2) — assigns an *existing named availability schedule* to a
  worker (references `ZMM_SR_SCHEDULES` by name).
- `AvailabilityPatterns`, `EnterpriseShift`, `ScheduleGenerationProfile`, `ScheduleRequest`.

The availability-schedule *library* itself (`ZMM_SR_SCHEDULES` / `ZMM_SR_SHIFTS` /
`ZMM_SR_PATTERNS`) is **not** HDL-loadable — it is built in the Work Schedules setup UI
or the scheduler REST. The predecessor DMT2 generator
(`dmt_work_sched_hdl_gen_pkg`) correctly targets `WorkPattern.dat` with discriminator
`WorkPattern` + child `WorkPatternShift`; this fixture uses the same object.

**Base table (proven by the dictionary VO `oracle.apps.hcm.schedules.v2.workPattern...WorkPatternDLVO`):**
`HTS_WORK_PATTERNS_B/_VL` (pattern), `HTS_WORK_PATTERN_SHIFTS` (per-day shift, FK
`SHIFT_ID` → `ZMM_SR_SHIFTS`), `HTS_WORK_PATTERN_ASSIGNMENTS` (pattern ↔ person/assignment).
The good-row base proof is `HTS_WORK_PATTERNS_VL.WORK_PATTERN_NAME LIKE '<prefix> DMT Work Schedule%'`.

## Portability (rules 6–8)

A work pattern is standalone setup data, but the HDL `WorkPattern` object **requires an
existing worker assignment** (`AssignmentNumber`) to hang the pattern on, and its shifts
reference an existing **enterprise shift** by name. Both are discovered at load time
against the target pod; nothing depends on our earlier loads:

- **`${ASSIGNMENT_NUMBER}`** — an active primary employee assignment that does **not**
  already have a work pattern (so re-runs don't collide). Demo pods ship many workers.
- **`${SHIFT_NAME}`** — the standard **`8 Hour Shift`** enterprise shift (TIME type,
  28,800,000 ms = 8 h), which ships in the demo pod.

The two good work patterns are created fresh (prefix-stamped name + alt code); their
assignment and shift references are borrowed from what already exists.

## The DAT (`WorkPattern.dat`, pipe-delimited HDL, inside `WorkSchedules_gold.zip`)

Two components. Parent `WorkPattern`, child `WorkPatternShift` (FK
`WorkPatternAssignmentId(SourceSystemId)` → the parent's SourceSystemId).

Parent METADATA:
`SourceSystemOwner|SourceSystemId|AssignmentNumber|WorkPatternName|WorkPatternAltCode|RepeatNumber|RepeatCycle|DateFrom`

Child METADATA:
`SourceSystemOwner|SourceSystemId|WorkPatternAssignmentId(SourceSystemId)|DayOfWorkPattern|ShiftName`

| Row | WorkPatternName | Shift ref | Purpose |
|---|---|---|---|
| GOOD-1 | `${PREFIX} DMT Work Schedule 1` | `${SHIFT_NAME}` (discovered `9A - 5P General Shift`), days 1 & 2, worker `${ASSIGNMENT_NUMBER_1}` | valid → base |
| GOOD-2 | `${PREFIX} DMT Work Schedule 2` | `${SHIFT_NAME}`, days 1 & 2, worker `${ASSIGNMENT_NUMBER_2}` | valid → base |
| BAD-1  | `${PREFIX} DMT Work Schedule Bad` (SourceSystemId `${PREFIX}DMTWS-BAD_WPAT`) | `DMT NONEXISTENT SHIFT ${PREFIX}` | HDL error, no pattern |

**Tokens:** `${PREFIX}` on every SourceSystemId / WorkPatternName / alt code;
`${ASSIGNMENT_NUMBER_1}`, `${ASSIGNMENT_NUMBER_2}` and `${SHIFT_NAME}` discovered.
`RepeatCycle=Weeks`, `RepeatNumber=1`, `ShiftPeriodType=ORA_ANC_WORK_SHIFT_TIME`,
`DateFrom=2024/01/01` for good rows (`2025/06/01` for the bad row) — HDL date format `YYYY/MM/DD`.

### Hard-won attribute rules (each proven by a live rejection, then fixed)

1. **`WorkPatternShift.ShiftName` resolves against `HTS_SHIFTS_VL`, NOT `ZMM_SR_SHIFTS`.**
   The availability-shift name `8 Hour Shift` is rejected ("enter a valid value for the
   ShiftName attribute"). The Time & Labor work-pattern catalog `HTS_SHIFTS_VL` is the
   right source; `9A - 5P General Shift` (480 min, `ORA_HTS_SHIFT_DAY`) is a valid value.
2. **`ShiftPeriodType` is required on the parent** and must be `ORA_ANC_WORK_SHIFT_TIME`
   for a time-based pattern (matches `HTS_WORK_PATTERNS_VL.WORK_SHIFT_TYPE`). Omitting it →
   "You must provide a value for the ShiftPeriodType attribute."
3. **Reference the worker by `AssignmentNumber` ONLY.** `PersonNumber` is rejected as
   "unknown for V1 version of the WorkPattern business object" (fails the whole file).
   Supplying `AssignmentId` gave "Attribute Assignment ID is required" churn. V1 resolves
   PersonId internally from a *valid* AssignmentNumber, so the assignment must be a clean
   demo worker (person_number numeric, assignment `E<person_number>`), not an odd test
   worker whose assignment number is non-standard.
4. **One work pattern per worker per date range.** Two good patterns on the SAME worker
   with the same `DateFrom` collide ("overlaps an existing work pattern"). The two good
   rows are therefore placed on two DIFFERENT discovered workers.

**Bad-row design:** the BAD pattern's single `WorkPatternShift` references a shift name
that does not exist on the pod, so the loader cannot resolve `ShiftId`. It errors in the
loader (deterministic, shows in the HDL child/messages error report) and creates no
work pattern.

## The exact call (HCM Data Loader REST, credential role `hcm_impl`)

| Step | Method + URL | Body / key |
|---|---|---|
| Upload | `POST {FUSION_URL}/hcmRestApi/resources/11.13.18.05/dataLoadDataSets/action/uploadFile` | `{content:<b64 zip>, fileName}` → `ContentId` |
| Submit | `POST .../dataLoadDataSets/action/createFileDataSet` | `{contentId, fileAction:"IMPORT_AND_LOAD"}` → `RequestId` |
| Poll | `GET .../dataLoadDataSets/{RequestId}` every 30s | `DataSetStatusCode` until terminal |
| Errors | `GET .../dataLoadDataSets/{RequestId}/child/messages?onlyData=true` | per-line `SourceSystemId` + `MessageText` |

Terminal statuses: `ORA_COMPLETED` / `ORA_SUCCESS` / `ORA_IN_ERROR` / `ORA_STOPPED`.
`ORA_IN_ERROR` is the **expected** terminal here because the one bad row errors on
purpose — the two good patterns still load (partial success).

## Discovery (run before build, read-only BIP, role `hcm_impl`)

```sql
-- ${ASSIGNMENT_NUMBER_1} / ${ASSIGNMENT_NUMBER_2}: the two lowest-numbered clean demo
-- employee assignments (person_number numeric, assignment = 'E'||person_number) that have
-- NO existing work pattern (so re-runs don't collide).
SELECT MAX(CASE WHEN rn=1 THEN anum END) AS anum1,
       MAX(CASE WHEN rn=2 THEN anum END) AS anum2
FROM (SELECT anum, ROWNUM rn FROM (
        SELECT paam.assignment_number AS anum
        FROM per_all_assignments_m paam
        JOIN per_all_people_f pap ON pap.person_id=paam.person_id
             AND SYSDATE BETWEEN pap.effective_start_date AND pap.effective_end_date
        WHERE paam.assignment_type='E' AND paam.effective_latest_change='Y'
          AND paam.assignment_status_type='ACTIVE' AND paam.primary_flag='Y'
          AND SYSDATE BETWEEN paam.effective_start_date AND paam.effective_end_date
          AND REGEXP_LIKE(pap.person_number,'^[0-9]+$')
          AND paam.assignment_number = 'E'||pap.person_number
          AND NOT EXISTS (SELECT 1 FROM hts_work_pattern_assignments hwpa
                          WHERE hwpa.assignment_id = paam.assignment_id)
        ORDER BY TO_NUMBER(pap.person_number)) WHERE ROWNUM<=2);

-- ${SHIFT_NAME}: the standard 8-hour day shift from the WORK-PATTERN shift catalog
-- (HTS_SHIFTS_VL — NOT the ZMM_SR availability catalog), preferring '9A - 5P General Shift'.
SELECT sname FROM (
  SELECT s.shift_name AS sname,
         CASE WHEN s.shift_name='9A - 5P General Shift' THEN 0 ELSE 1 END AS pref
  FROM hts_shifts_vl s
  WHERE s.active_flag='Y' AND s.work_duration=480 AND s.shift_category='ORA_HTS_SHIFT_DAY'
  ORDER BY pref, s.shift_name) WHERE ROWNUM=1;
```

## Verification (read-only, direct single-table read)

- **Good → base.** Direct read of `HTS_WORK_PATTERNS_VL` by the prefix on
  WorkPatternName: `WHERE work_pattern_name LIKE '<prefix> DMT Work Schedule%'`. Each
  good name present with a real `WORK_PATTERN_ID` = pass.
- **Bad → HDL error, absent from base.** The bad evidence is the load-time HDL message
  list keyed by `SourceSystemId` (`GET .../child/messages`); the base read above
  confirms the bad WorkPatternName is absent. The recipe's `bad_keys` is the
  SourceSystemId stem `${PREFIX}DMTWS-BAD` (not the WorkPatternName) because the HDL
  message reports the bad row by SourceSystemId; that stem is also correctly absent from
  the `WORK_PATTERN_NAME` base read.

```sql
SELECT work_pattern_name, MAX(work_pattern_id)
FROM hts_work_patterns_vl
WHERE work_pattern_name LIKE '<prefix> DMT Work Schedule%'
GROUP BY work_pattern_name;
```

## How to run it

```bash
cd gold_regression/harness
python run_object.py WorkSchedules --prefix <PREFIX>   # discover → build → upload/submit/poll → verify
```

## Live evidence

**2026-07-19 — LIVE-PROVEN. PASS.**

Standalone load path only (HCM Data Loader REST); verification via the read-only BIP relay only.

| Field | Value |
|---|---|
| Date | 2026-07-19 |
| Prefix | `57139` |
| HDL UCM ContentId | `UCMFA07637425` |
| HDL data set RequestId | `9764508` |
| Terminal DataSetStatusCode | `ORA_IN_ERROR` (expected: 2 good loaded, 1 bad errored) |
| Import / Load counts | import 8 ok / 0 err; load **2 ok / 1 err** |
| Discovered workers | `E4`, `E5` (clean demo assignments, no prior work pattern) |
| Discovered shift | `9A - 5P General Shift` (HTS_SHIFTS_VL, 480 min, day) |

**Good rows → base table `HTS_WORK_PATTERNS_VL` (2/2):**

| WorkPatternName | WORK_PATTERN_ID |
|---|---|
| `57139 DMT Work Schedule 1` | `300000331555913` |
| `57139 DMT Work Schedule 2` | `300000331555899` |

**Bad row → HDL error, no work pattern created (1/1):**

| SourceSystemId | HDL error |
|---|---|
| `57139DMTWS-BAD_WSHIFT_1` | `You need to enter a valid value for the ShiftName attribute. The current value is DMT NONEXISTENT SHIFT 57139.` |

The two good work schedules reached `HTS_WORK_PATTERNS_VL` with real work-pattern ids; the
bad row errored in the loader (nonexistent enterprise shift) and created no work pattern.
Gold zip `WorkSchedules_gold.zip` (last built at prefix 57139) kept here.

**Earlier live iterations (each a real rejection that drove a fix), same day:**
prefix 68121 / req 9764121 — wrong shift catalog (`8 Hour Shift` from ZMM_SR rejected);
prefix 76004 / req 9764173 — missing `ShiftPeriodType`; prefix 12274 / req 9764232 —
`AssignmentId is required` churn; prefix 28161 / req 9764278 — invalid PersonId from an
odd RT test worker; prefix 75428 / req 9764373 — `PersonNumber` unknown for V1; prefix
86348 / req 9764403 — two good patterns on ONE worker overlapped (1 loaded, 1 rejected);
prefix 94732 / req 9764468 — both good → base, bad → shift error (verify key aligned to
SourceSystemId thereafter). Base ids from 86348 (`300000331553350`) and 94732
(`300000331555741`, `300000331555726`) also remain in `HTS_WORK_PATTERNS_VL`.
