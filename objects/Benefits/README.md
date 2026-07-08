# Benefits

## Status
BLOCKED — employee benefit enrollment not configured on demo instance (2026-04-04 DB-20)

## Pipeline
- Module: HCM
- HDL File: **PersonBenefitBalance.dat** (for ALL three sub-objects)
- Discriminator: **PersonBenefitBalance** (V2)
- Loader Type: HDL (REST upload/submit/poll)
- Auth User: hcm_impl (password: m?CDa6^6)

## Sub-Objects
All three share the same DAT filename and discriminator:
1. **Participant Enrollment** — DMT_BEN_PARTIC_HDL_GEN_PKG
2. **Dependent Enrollment** — DMT_BEN_DEPEND_HDL_GEN_PKG
3. **Beneficiary Enrollment** — DMT_BEN_BENFY_HDL_GEN_PKG

## METADATA (Import OK, Load blocked by instance config)
```
SourceSystemOwner|SourceSystemId|PersonId(SourceSystemId)|EffectiveStartDate|BenefitBalanceName
```

- `PersonId(SourceSystemId)` — FK hint to loaded Worker
- `BenefitBalanceName` — must be a valid balance name AND correspond to the employee's enrollment
- Generator maps STG `PLAN_NAME` to DAT `BenefitBalanceName`

## Valid BenefitBalanceName Values (from REST)
Queried from `personBenefitBalances` REST endpoint (80+ values):
- `401k Employee Balance`
- `401k Vested Employer Balance`
- `403b Employee Balance`

**BLOCKER:** These values exist globally but the error is "Invalid Benefit Balance Name, enter Global or Legal Employer specific Balance Name that corresponds to the employee." The loaded test workers are not enrolled in any benefit plans.

## Code References
- STG Table DDL (Participant): `schema/tables/124_dmt_ben_partic_stg_tbl.sql`
- TFM Table DDL (Participant): `schema/tables/125_dmt_ben_partic_tfm_tbl.sql`
- STG Table DDL (Dependent): `schema/tables/126_dmt_ben_depend_stg_tbl.sql`
- TFM Table DDL (Dependent): `schema/tables/127_dmt_ben_depend_tfm_tbl.sql`
- STG Table DDL (Beneficiary): `schema/tables/128_dmt_ben_benfy_stg_tbl.sql`
- TFM Table DDL (Beneficiary): `schema/tables/129_dmt_ben_benfy_tfm_tbl.sql`
- Validators: `packages/validators/dmt_ben_partic_validator_pkg.*`, `dmt_ben_depend_validator_pkg.*`, `dmt_ben_benfy_validator_pkg.*`
- Transformers: `packages/transformers/dmt_ben_partic_transform_pkg.*`, `dmt_ben_depend_transform_pkg.*`, `dmt_ben_benfy_transform_pkg.*`
- HDL Generators: `packages/generators/hdl/dmt_ben_partic_hdl_gen_pkg.*`, `dmt_ben_depend_hdl_gen_pkg.*`, `dmt_ben_benfy_hdl_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_ben_partic_results_pkg.*`, `dmt_ben_depend_results_pkg.*`, `dmt_ben_benfy_results_pkg.*`

## Known Bad Test Data
| PERSON_NUMBER | Failure Mode | Notes |
|---------------|-------------|-------|
| DMTW1BAD | NONEXISTENT_BALANCE | Correctly rejected: "enter a valid value for the BnftsBalId attribute" |

## Lessons Learned
- All three benefit sub-objects use the SAME DAT filename `PersonBenefitBalance.dat` and discriminator `PersonBenefitBalance`. NOT separate files.
- `DependentBenefitBalance` and `BeneficiaryBenefitBalance` are NOT valid discriminators.
- STG modeled for enrollment (PROGRAM_NAME, PLAN_NAME) but HDL object is PersonBenefitBalance. Generator maps PLAN_NAME to BenefitBalanceName.
- BenefitBalanceName values exist but are employee-specific. Employee must be enrolled in benefit plan before balances can be loaded.
- Instance configuration required (outside Claude scope).

## History
- 2026-03-25: METADATA validated. PersonBenefitBalance.dat filename confirmed.
- 2026-04-04 (DB-19): V2 audit completed. Load blocked by BenefitBalanceName LOV.
- 2026-04-04 (DB-20): Valid balance names discovered from REST. Still blocked — employees need benefit enrollment.
