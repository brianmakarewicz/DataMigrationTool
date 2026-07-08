# SalaryBasis

## Status
E2E LOADED (2 GOOD + 1 BAD correctly rejected, 2026-04-04)

## Pipeline
- Module: HCM
- HDL File: SalaryBasis.dat
- Loader Type: HDL (REST upload/submit/poll)
- UCM Account: hcm$/dataloader$/import$
- Auth User: hcm_impl (password: m?CDa6^6)
- Standalone config object — no parent chain, no FK dependencies

## V2 Audit — Attribute Name Corrections
| V2 Name (incorrect) | Correct Name |
|---------------------|-------------|
| AnnualizationFactor | SalaryAnnualizationFactor |

See `v2_audit.md` for full attribute audit details.

## Code References
- STG Table DDL: `schema/tables/116_dmt_sal_basis_stg_tbl.sql`
- TFM Table DDL: `schema/tables/117_dmt_sal_basis_tfm_tbl.sql`
- Validator: `packages/validators/dmt_sal_basis_validator_pkg.*`
- Transformer: `packages/transformers/dmt_sal_basis_transform_pkg.*`
- HDL Generator: `packages/generators/hdl/dmt_sal_basis_hdl_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_sal_basis_results_pkg.*`

## Known Good Test Data
| Field | Value |
|-------|-------|
| SALARY_BASIS_NAME | DMT Test Hourly |
| ELEMENT_NAME | Regular Wages |
| INPUT_VALUE_NAME | Rate |
| SALARY_BASIS_CODE | HOURLY |
| ANNUALIZATION_FACTOR | 2080 |
| LEGISLATIVE_DATA_GROUP_NAME | US Legislative Data Group |

## Known Bad Test Data
| Name | Failure Mode | Expected Error |
|------|-------------|----------------|
| DMT Bad Basis | ELEMENT_NAME = NONEXISTENT_ELEMENT | "valid value for ElementTypeId" |

## Lessons Learned
- The attribute is `SalaryAnnualizationFactor`, not `AnnualizationFactor`. The V2 template name is wrong.
- Standalone object — no dependency on Workers or any other object. Can be loaded independently.
- ElementName must match an existing payroll element. Invalid element names produce a clear Fusion error.

## History
- 2026-04-04: E2E LOADED confirmed. 2/2 good records loaded, 1 bad record correctly rejected with "valid value for ElementTypeId" error.
