# Planning Budgets

## Status
DORMANT (EPBCS table not accessible on demo instance)

## Pipeline
- Module: Financials
- FBDI Template: TBD
- Interface Table: EPBCS planning table (not accessible)
- UCM Account: TBD
- ESS Job: TBD
- ParameterList: UNKNOWN
- Loader Type: SQLLOADER
- Auth User: fin_impl

## Code References
- STG Table DDL: `schema/tables/152_dmt_plan_budget_stg_tbl.sql`
- TFM Table DDL: `schema/tables/153_dmt_plan_budget_tfm_tbl.sql`
- Validator: `packages/validators/dmt_plan_budget_validator_pkg.*`
- Transformer: `packages/transformers/dmt_plan_budget_transform_pkg.*`
- FBDI Generator: `packages/generators/fbdi/planning/dmt_plan_budget_fbdi_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_plan_budget_results_pkg.*`
- BIP Data Model/Report: `bip/PlanningBudgets/`

## Reference Files
None in this folder.

## Known Issues
- Intentionally dormant. EPBCS table not accessible on demo instance.

## History
- Marked DORMANT intentionally. Will revisit if EPBCS access becomes available.
