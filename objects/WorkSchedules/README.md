# WorkSchedules

## Status
RE-MODELLED 2026-09-17 — split into two distinct Fusion HDL objects
(WorkPattern definition + ScheduleAssignment). Pattern side loads (proven by
prior '<prefix> DMT Work Schedule N' patterns in HTS_WORK_PATTERNS_VL);
ScheduleAssignment side is CONFIG-BLOCKED (needs a Work Schedule wrapper HDL
cannot create — see below).

## Pipeline
- Module: HCM
- HDL: ONE object zip carrying TWO .dat files (one DMT object, two HDL objects):
  - **WorkPattern.dat** — the pattern DEFINITION (+ WorkPatternShift child).
    Base view HTS_WORK_PATTERNS_VL (WORK_PATTERN_ID).
  - **ScheduleAssignment.dat** — assigns the schedule to the WORKER.
    Base table PER_SCHEDULE_ASSIGNMENTS (SCHEDULE_ASSIGNMENT_ID).
- Loader Type: HDL (REST upload/submit/poll)
- Auth User: hcm_impl

Object names verified live on this pod (--cred fin_impl, HRC_INTEGRATION_KEY_MAP):
WorkPattern, WorkPatternShift, WorkPatternBreak, ScheduleAssignment.

## SourceSystemId Convention
| Component | Suffix | Example |
|-----------|--------|---------|
| WorkPattern | _WPAT | DMT Test Sched A_WPAT |
| WorkPatternShift | _WSHIFT_{seq} | DMT Test Sched A_WSHIFT_123 |
| ScheduleAssignment | _WSASG | 10186WSTEST01_WSASG |

## METADATA — WorkPattern definition (AssignmentNumber removed — that was the conflation bug)
```
SourceSystemOwner|SourceSystemId|WorkPatternTypeName|RepeatNumber|RepeatCycle|DateFrom|WorkPatternAltCode
```
- `WorkPatternTypeName` = **required**. Demo instance value: `9A - 5P General Shift`
- `RepeatNumber|RepeatCycle` = 1 / 7 (one weekly cycle) by default
- `DateFrom` = schedule start date
- `WorkPatternAltCode` = the pattern name (stable reference; ties shift to parent)

## METADATA — WorkPatternShift child
```
SourceSystemOwner|SourceSystemId|WorkPatternAltCode|DayOfWorkPattern|ShiftStartTime|ShiftEndTime|DurationMinutes
```
Attribute names taken from Oracle doc (fahbo/example-of-deleting-work-patterns).
The old '_V1' guesses (DayNumber/StartTime/EndTime) were wrong.

## METADATA — ScheduleAssignment (assign schedule to worker)
```
SourceSystemOwner|SourceSystemId|ScheduleName|AssignmentNumber|ResourceType|PrimaryFlag|StartDate|EndDate
```
- `ScheduleName` = the Work Schedule name (must pre-exist — config prerequisite)
- `AssignmentNumber` = prefixed PERSON_NUMBER (the worker's assignment)
- `ResourceType` = `ASSIGN` (worker assignment); `PrimaryFlag` = `Y`

## CONFIG BLOCKER — ScheduleAssignment side
A ScheduleAssignment references a Work Schedule (ZMM_SR_SCHEDULES) by name. HDL
has NO business object that creates that Work Schedule wrapper — it is a UI task
("Manage Work Schedules"). The Fusion chain is
WorkPattern -> ZMM_SR_SCHEDULE_PATTERNS -> ZMM_SR_SCHEDULES -> ScheduleAssignment.
None of the migrated DMT patterns is wrapped in a schedule on this pod, so the
assignment side loads nothing until that config exists. The generator emits the
correct ScheduleAssignment.dat regardless; the recon report's assignment branch
returns zero base rows until the schedule wrapper is created.

## Code References
- STG Table DDL: `schema/tables/144_dmt_work_sched_stg_tbl.sql`
- STG Table DDL (Details): `schema/tables/146_dmt_work_sched_dtl_stg_tbl.sql`
- TFM Table DDL: `schema/tables/145_dmt_work_sched_tfm_tbl.sql`
- TFM Table DDL (Details): `schema/tables/147_dmt_work_sched_dtl_tfm_tbl.sql`
- Validator: `packages/validators/dmt_work_sched_validator_pkg.*`
- Transformer: `packages/transformers/dmt_work_sched_transform_pkg.*`
- HDL Generator: `packages/generators/hdl/dmt_work_sched_hdl_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_work_sched_results_pkg.*`

## Known Issues
1. **WorkPatternShift V1 attribute names unknown.** `DayNumber`, `StartTime`, `EndTime` all rejected. Need iterative discovery testing.
2. **At least 1 shift required.** Fusion rejects WorkPattern without any child shifts: "You need to add at least 1 shift before you can save the work pattern."
3. **STG design gap.** Original STG was modeled for schedule definitions (no person reference). PERSON_NUMBER column added in DB-20 to support the person-level WorkPattern HDL object.

## Lessons Learned
- HDL filename is **WorkPattern.dat** — NOT WorkSchedule.dat.
- Uses V1 format (not V2).
- `WorkPatternTypeName` is required (Fusion rejects without it). It's instance-specific — query `workPatterns` REST endpoint to discover valid values.
- Demo instance only has one type: `9A - 5P General Shift` (from REST query of existing work patterns).
- Child WorkPatternShift records are mandatory — not optional. A work pattern without shifts fails at load.
- Reconciliation key mismatch: error messages reference SourceSystemId but TFM uses WORK_SCHEDULE_NAME as key. Errors show as "HDL data set ended in error but no row-level error matched." Direct REST query to `/dataLoadDataSets/{id}/child/messages` is needed to see actual errors.

## History
- 2026-03-25: METADATA validated (parent only). WorkPattern.dat filename discovered. V1 confirmed.
- 2026-04-04 (DB-20): PERSON_NUMBER added to STG/TFM. Dynamic AssignmentNumber working. WorkPatternTypeName discovered. Child shift required but V1 attributes unknown.
