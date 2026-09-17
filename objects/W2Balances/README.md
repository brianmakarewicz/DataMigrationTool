# W2Balances

## Status
NOT BUILT (HDL)

## Pipeline
- Module: HCM
- HDL Object: Balance Initialization (two objects in one zip)
- HDL Files: InitializeBalanceBatchHeader.dat + InitializeBalanceBatchLine.dat
- Loader Type: HDL (REST upload/submit/poll)
- Auth User: fin_impl
- Post-load: "Load Initial Balances" (Transfer Batch) payroll flow run in Fusion
  applies the staged batch to balances (functional step, not part of the HDL file).
- Key model: one run = one batch; BatchName = <prefix>_W2BAL links lines to header
  and is the reconciliation key (PAY_BAL_BATCH_HEADERS.BATCH_NAME, BATCH_ID = Fusion id).

## Code References
- STG Table DDL: `schema/tables/120_dmt_w2_bal_stg_tbl.sql`
- STG Table DDL (Detail): `schema/tables/122_dmt_w2_bal_dtl_stg_tbl.sql`
- TFM Table DDL: `schema/tables/121_dmt_w2_bal_tfm_tbl.sql`
- TFM Table DDL (Detail): `schema/tables/123_dmt_w2_bal_dtl_tfm_tbl.sql`
- Validator: `packages/validators/dmt_w2_bal_validator_pkg.*`
- Transformer: `packages/transformers/dmt_w2_bal_transform_pkg.*`
- HDL Generator: `packages/generators/hdl/dmt_w2_bal_hdl_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_w2_bal_results_pkg.*`

## Reference Files
None.

## Known Issues
None -- not yet built.
