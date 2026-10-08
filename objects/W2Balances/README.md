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
- Key model: one run = one batch. The BatchName links lines to the header and is the
  reconciliation key (PAY_BAL_BATCH_HEADERS.BATCH_NAME, BATCH_ID = Fusion id).
- BatchName (backlog #413, owner decision 2026-10-07): the run prefix followed by the
  work-queue id (prefix 93460 + work item 1700 = 934601700); the work-queue id alone with
  USE_PREFIX = N, so it is never a constant at cutover. The STG tables carry no source batch.
  The transform writes it as the TFM RECON_KEY and the HDL generator reads it back.
- Reconciliation report V2 `DMT_W2_BAL_RECON_V2_DM` / `_RPT` (deployed alongside V1, never
  overwritten) finds the batch only by that exact BatchName, sent as `P_FUSION_BATCH_ID`.
  V1 used `BATCH_NAME LIKE prefix || '%'`, which searched by the prefix and could also match
  a longer prefix with the same leading digits. PAY_BAL_BATCH_HEADERS has no request id, so
  the name is the only exact selector. Proven 2026-10-08 against the live pod (no W2 run
  exists yet): `DMTW232147` returns its one batch (BATCH_ID 300000331552768), while the
  leading characters `DMTW2` and an unknown name return no rows.

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
