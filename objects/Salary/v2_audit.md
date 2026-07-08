# Salary — V2 Audit (2026-04-04)

## Status: PASS — V2 fixes applied, code complete

## Generator: DMT_SALARY_HDL_GEN_PKG
- DAT filename: `Salary.dat` — correct
- Version: V2
- Standalone (no parent chain)

## METADATA vs V2 Findings

| Attribute | Status |
|-----------|--------|
| EffectiveStartDate | Removed (V2 invalid) | PASS |
| PersonNumber | Removed (V2 invalid) | PASS |
| AnnualSalary | Removed (V2 invalid) | PASS |
| AnnualFullTimeSalary | Removed (V2 invalid) | PASS |
| CurrencyCode | Removed (V2 invalid) | PASS |
| FrequencyName | Removed (V2 invalid) | PASS |
| AssignmentId(SourceSystemId) | Uses FK hint (correct) | PASS |

Generator METADATA: `SSO|SSID|AssignmentId(SSID)|DateFrom|SalaryAmount|SalaryBasisName|SalaryApproved|ActionCode|NextSalReviewDate|DateTo`

Matches V2 validated METADATA exactly.

## Discriminator: `Salary` — correct
## Confirmed E2E LOADED: Yes (2026-03-22)

## Notes
- ActionCode must be HIRE for initial salary
- SalaryBasisName is instance-specific ('US1 Annual Salary' on demo)
