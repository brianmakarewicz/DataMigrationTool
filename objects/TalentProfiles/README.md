# TalentProfiles

## Status
E2E LOADED (1 GOOD + 2 BAD, 1 correctly rejected, 2026-04-04)

## Pipeline
- Module: HCM
- HDL File: TalentProfile.dat
- Loader Type: HDL (REST upload/submit/poll)
- UCM Account: hcm$/dataloader$/import$
- Auth User: hcm_impl (password: m?CDa6^6)

## Key Attributes — Valid LOV Values
Discovered 2026-04-04 (15 values tested against demo instance):

| Attribute | Code | Description |
|-----------|------|-------------|
| ProfileUsageCode | P | Person |
| ProfileUsageCode | R | Role |
| ProfileUsageCode | J | Job |
| ProfileUsageCode | PO | Position |
| ProfileStatusCode | A | Active |
| ProfileTypeCode | PERSON | Person profile |

## Code References
- STG Table DDL: `schema/tables/136_dmt_talent_prof_stg_tbl.sql`
- STG Table DDL (Items): `schema/tables/138_dmt_talent_prof_item_stg_tbl.sql`
- TFM Table DDL: `schema/tables/137_dmt_talent_prof_tfm_tbl.sql`
- TFM Table DDL (Items): `schema/tables/139_dmt_talent_prof_item_tfm_tbl.sql`
- Validator: `packages/validators/dmt_talent_prof_validator_pkg.*`
- Transformer: `packages/transformers/dmt_talent_prof_transform_pkg.*`
- HDL Generator: `packages/generators/hdl/dmt_talent_prof_hdl_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_talent_prof_results_pkg.*`

## Known Good Test Data
| Field | Value |
|-------|-------|
| PERSON_NUMBER | DMTW002 |
| PROFILE_CODE | DMTW002_PROF2 |
| PROFILE_TYPE_CODE | PERSON |
| PROFILE_STATUS_CODE | A |
| PROFILE_USAGE_CODE | P |

## Known Bad Test Data
| PROFILE_CODE | Failure Mode | Expected Error |
|-------------|-------------|----------------|
| BAD_PROF | PROFILE_STATUS_CODE = INVALID | Correctly rejected — invalid status code |

## Lessons Learned
- ProfileUsageCode `O` (used in early test data) is NOT valid. The correct code for person profiles is `P`.
- ProfileStatusCode must be a valid LOV code (A for Active). Arbitrary strings are rejected.
- ProfileTypeCode = PERSON is the correct value for person-linked profiles.

## History
- 2026-04-04: E2E LOADED confirmed. 1/2 good records loaded (DMTW002_PROF2 with correct P usage code), 1 correctly rejected (INVALID status code). Earlier test data with usage code O was also rejected.
