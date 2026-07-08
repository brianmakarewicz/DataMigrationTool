# Assignments — V2 Audit (2026-04-04)

## Status: PASS — V2 fixes applied, code complete

## Generator: DMT_ASSIGNMENT_HDL_GEN_PKG
- DAT filename: `Worker.dat` (parent chain required) — correct
- Version: V2
- Emits full parent chain: Worker -> PersonName -> WorkRelationship -> WorkTerms -> Assignment

## METADATA vs V2 Findings

| Component | V2 Fix Applied | Match |
|-----------|---------------|-------|
| Worker | Same as Worker generator | PASS |
| PersonName | Required in chain (LastName required) | PASS |
| WorkRelationship | EffectiveStartDate/EndDate removed | PASS |
| WorkTerms | OK | PASS |
| Assignment | ManagerPersonNumber/ManagerAssignmentNumber removed. Extra attrs: JobCode, GradeCode, LocationCode, DepartmentName, PositionCode, WorkerCategory, AssignmentCategory, FullPartTime, PermanentTemporary, NormalHours, Frequency | PASS |

## Discriminators: All correct
## Confirmed E2E LOADED: Yes (2026-03-22)
