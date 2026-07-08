# Assignments

## Status
NOT BUILT (HDL)

## Pipeline
- Module: HCM
- HDL File: WorkRelationship.dat, Assignment.dat
- Loader Type: HDL (REST upload/submit/poll)
- Auth User: fin_impl

## Sub-Objects
1. WorkRelationship
2. Assignment

## Code References
- STG Table DDL (WorkRelationship): `schema/tables/110_dmt_work_rel_stg_tbl.sql`
- TFM Table DDL (WorkRelationship): `schema/tables/111_dmt_work_rel_tfm_tbl.sql`
- STG Table DDL (Assignment): `schema/tables/112_dmt_assignment_stg_tbl.sql`
- TFM Table DDL (Assignment): `schema/tables/113_dmt_assignment_tfm_tbl.sql`
- Validator: `packages/validators/dmt_assignment_validator_pkg.*`
- Transformer: `packages/transformers/dmt_assignment_transform_pkg.*`
- HDL Generator: `packages/generators/hdl/dmt_assignment_hdl_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_assignment_results_pkg.*`

## Reference Files
None.

## Known Issues
None -- not yet built.
