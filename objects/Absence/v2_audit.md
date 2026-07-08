# Absence — V2 Audit (2026-04-04)

## Status: PASS (METADATA) — V2 fixes applied, load blocked by AbsenceStatus LOV

## Generator: DMT_ABSENCE_HDL_GEN_PKG
- DAT filename: `PersonAbsenceEntry.dat` — correct (not AbsenceEntry.dat)
- Version: **V1** (not V2)
- Standalone (no parent chain)

## METADATA vs V2 Findings

| Attribute | Status |
|-----------|--------|
| EmployerName | Removed — uses `Employer` (V1 name) | PASS |
| AbsenceName | Removed (V1 invalid) | PASS |
| AbsenceCategory | Removed (V1 invalid) | PASS |
| ApprovalStatusCode | Removed (V1 invalid) | PASS |
| SubmissionDate | Removed (V1 invalid) | PASS |
| EffectiveStartDate/EndDate | Removed | PASS |
| PersonNumber | Removed — uses PersonId(SourceSystemId) FK | PASS |

Generator METADATA: `SSO|SSID|PersonId(SSID)|Employer|AbsenceType|AbsenceStatus|StartDate|EndDate|StartTime|EndTime|Duration|AbsenceReason|Comments`

Matches V2 validated METADATA exactly.

## Discriminator: `PersonAbsenceEntry` — correct
## METADATA validated: Yes (2026-03-25)
## E2E LOADED: No — BLOCKED

## Blocker
AbsenceStatus values are instance-specific. SUBMITTED, APPROVED, COMPLETED, CONFIRMED, ORA_SUBMITTED, ORA_APPROVED, ORA_CONFIRMED all failed on demo instance. Need to discover valid values per target.
