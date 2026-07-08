# PerformanceEvaluations

## Status
E2E LOADED (2L/1F, prefix 9210, 2026-04-04 DB-20)

## Pipeline
- Module: HCM
- HDL File: **GoalPlan.dat** (NOT PerformanceDocument.dat)
- Discriminator: **GoalPlan** (V1)
- Child: GoalPlanGoal (V1)
- Loader Type: HDL (REST upload/submit/poll)
- Auth User: hcm_impl (password: m?CDa6^6)

## SourceSystemId Convention
| Component | Suffix | Example |
|-----------|--------|---------|
| GoalPlan | _GOAL | 9210DMTW101_GOAL |
| GoalPlanGoal (rating) | _PERFRTG | 9210DMTW101_PERFRTG |

## METADATA (Validated — E2E LOADED)
```
SourceSystemOwner|SourceSystemId|GoalPlanName|GoalPlanTypeCode|StartDate|EndDate|ReqSubmittedByPersonId(SourceSystemId)
```

- `ReqSubmittedByPersonId(SourceSystemId)` — FK hint resolves to Fusion PersonId. Value = Worker's SourceSystemId (prefixed PERSON_NUMBER). Worker MUST be LOADED in Fusion before GoalPlan can reference them.
- `GoalPlanTypeCode` — from ORA_HRG_GOAL_PLAN_TYPE LOV. Valid: `ORA_HRG_WORKER`.

## Code References
- STG Table DDL: `schema/tables/140_dmt_perf_eval_stg_tbl.sql`
- STG Table DDL (Ratings): `schema/tables/142_dmt_perf_eval_rating_stg_tbl.sql`
- TFM Table DDL: `schema/tables/141_dmt_perf_eval_tfm_tbl.sql`
- TFM Table DDL (Ratings): `schema/tables/143_dmt_perf_eval_rating_tfm_tbl.sql`
- Validator: `packages/validators/dmt_perf_eval_validator_pkg.*`
- Transformer: `packages/transformers/dmt_perf_eval_transform_pkg.*`
- HDL Generator: `packages/generators/hdl/dmt_perf_eval_hdl_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_perf_eval_results_pkg.*`

## Known Good Test Data (E2E LOADED prefix 9210)
| Field | Value |
|-------|-------|
| PERSON_NUMBER | DMTW101, DMTW102 (must match loaded Workers) |
| DOCUMENT_NAME | DMT Goal Plan 2024 A, DMT Goal Plan 2024 B |
| DOCUMENT_TYPE | ORA_HRG_WORKER |
| REVIEW_PERIOD_NAME | 2024 Annual Review |
| START_DATE | 2024/01/01 |
| END_DATE | 2024/12/31 |

## Known Bad Test Data
| PERSON_NUMBER | Failure Mode | Notes |
|---------------|-------------|-------|
| DMTW1BAD | INVALID_TYPE for GoalPlanTypeCode | Correctly rejected: "doesn't exist in ORA_HRG_GOAL_PLAN_TYPE list" |

## Lessons Learned
- HDL filename is **GoalPlan.dat** — NOT PerformanceDocument.dat. The original object matrix referenced PerformanceDocument.dat which is rejected by Fusion.
- Uses V1 format (not V2 like most other HCM objects).
- `ReqSubmittedByPersonId` was initially hardcoded as a raw Fusion PersonId. Changed to `(SourceSystemId)` FK hint pattern which resolves dynamically — much cleaner and works across prefixes.
- Worker must be LOADED in Fusion (same prefix run) BEFORE GoalPlan can reference them via the FK hint.
- GoalPlanGoal (rating child) was not tested in this run — no rating STG data inserted. Parent GoalPlan loads fine without ratings.
- `ORA_HRG_WORKER` is confirmed valid for GoalPlanTypeCode. `INVALID_TYPE` correctly rejected.

## History
- 2026-03-25: METADATA validated. GoalPlan.dat filename discovered.
- 2026-04-04 (DB-19): V2 audit completed. ReqSubmittedByPersonId hardcoded — blocked by PersonId lookup.
- 2026-04-04 (DB-20): **E2E LOADED.** ReqSubmittedByPersonId changed to FK hint. 2L/1F (BAD correctly failed).
