# Salary

## Status
E2E LOADED (2 GOOD + 1 BAD correctly rejected, 2026-04-04)

## Pipeline
- Module: HCM
- HDL File: Salary.dat
- Loader Type: HDL (REST upload/submit/poll)
- UCM Account: hcm$/dataloader$/import$
- Auth User: hcm_impl (password: m?CDa6^6)
- Standalone object, uses AssignmentId(SourceSystemId) FK to link to Workers

## V2 Audit — Invalid Attributes
These attributes exist in the V2 template but are rejected by the Fusion REST API:

| Invalid Attribute | Notes |
|-------------------|-------|
| EffectiveStartDate | |
| PersonNumber | Derived from AssignmentId FK |
| AnnualSalary | Auto-calculated |
| CurrencyCode | Derived from salary basis |
| FrequencyName | Derived from salary basis |

See `v2_audit.md` for full attribute audit details.

## FK Dependency
- **Must use the same prefix as Workers** for the AssignmentId(SourceSystemId) FK to resolve correctly.
- AssignmentId references the Assignment SourceSystemId from the Workers load (e.g., DMTW001_ASG).

## Code References
- STG Table DDL: `schema/tables/114_dmt_salary_stg_tbl.sql`
- TFM Table DDL: `schema/tables/115_dmt_salary_tfm_tbl.sql`
- Validator: `packages/validators/dmt_salary_validator_pkg.*`
- Transformer: `packages/transformers/dmt_salary_transform_pkg.*`
- HDL Generator: `packages/generators/hdl/dmt_salary_hdl_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_salary_results_pkg.*`

## Known Good Test Data
| Field | Value |
|-------|-------|
| PERSON_NUMBER | DMTW001 |
| ASSIGNMENT_NUMBER | DMTW001 |
| SALARY_AMOUNT | 75000 |
| SALARY_BASIS_NAME | US1 Annual Salary |
| ACTION_CODE | HIRE |
| DATE_FROM | 2026/01/01 |
| SALARY_APPROVED | Y |

## Known Bad Test Data
| PERSON_NUMBER | Failure Mode | Expected Error |
|---------------|-------------|----------------|
| DMTW-BAD | SALARY_BASIS_NAME = NONEXISTENT_BASIS | Correctly rejected |

## Instance-Specific Values
- `SALARY_BASIS_NAME`: Must match an existing salary basis on the target instance. On the demo instance, use `US1 Annual Salary`.
- `ACTION_CODE`: Must be `HIRE` for initial salary assignment.

## Lessons Learned
- ActionCode must be HIRE for the first salary record for a worker. Other action codes (e.g., SAL_CHG) are for subsequent salary changes.
- SalaryBasisName is instance-specific — it must match a salary basis that already exists on the target. The V2 attribute list includes several attributes that Fusion auto-derives and rejects if supplied.
- The prefix used for Salary must match the prefix used for the corresponding Workers load, otherwise the AssignmentId FK will not resolve.

## History
- 2026-04-04: E2E LOADED confirmed. 2/2 good records loaded, 1 bad record correctly rejected (nonexistent salary basis).
