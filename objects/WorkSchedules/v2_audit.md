# Work Schedules — V2 Audit (2026-04-04)

## Status: PASS (METADATA) — V2 fixes applied, load blocked by AssignmentNumber

## Generator: DMT_WORK_SCHED_HDL_GEN_PKG
- DAT filename: `WorkPattern.dat` — correct (not WorkSchedule.dat)
- Version: **V1**
- Parent/child: WorkPattern + WorkPatternShift

## METADATA vs V2 Findings

Parent: `SSO|SSID|AssignmentNumber|DateFrom|WorkPatternTypeName`
- Minimal set after all guessed attrs rejected
- AssignmentNumber and DateFrom added after validation

Child: `SSO|SSID|WorkScheduleId(SSID)|ShiftName|ShiftDate|StartTime|EndTime|Duration|UnitOfMeasure`

## Discriminators: `WorkPattern`, `WorkPatternShift` — correct
## METADATA validated: Yes (2026-03-25) — parent only
## E2E LOADED: No — blocked by AssignmentNumber validation

## Potential Issue
Child FK uses `WorkScheduleId(SourceSystemId)` but parent object is WorkPattern.
May need `WorkPatternId(SourceSystemId)` instead — untested.

## Action Required
- Need valid AssignmentNumber from Fusion to test load
- Verify child FK hint name (WorkScheduleId vs WorkPatternId)
