# Misc Receipts (On Hand Qty)

## Overview
On-hand inventory quantities migrated into Fusion via miscellaneous receiving receipts.
Dual-table CEMLI: receipt headers + receipt transactions.

## Load Method
FBDI
- Template: RcvHeadersInterface.xlsm
- Interface Tables: RCV_HEADERS_INTERFACE, RCV_TRANSACTIONS_INTERFACE
- Pipeline: Standard FBDI pipeline via run_one_object_type

## Parent/Child
- Parent: Items (items must exist in Fusion before receipts reference them)
- Linkage: ITEM_NUMBER in transactions references imported items

## Staging Tables
- STG (Headers): `DMT_RCV_HEADERS_STG_TBL` (DDL: `schema/tables/92_dmt_rcv_headers_stg_tbl.sql`)
- STG (Transactions): `DMT_RCV_TRANSACTIONS_STG_TBL` (DDL: `schema/tables/93_dmt_rcv_transactions_stg_tbl.sql`)
- TFM (Headers): `DMT_RCV_HEADERS_TFM_TBL` (DDL: `schema/tables/94_dmt_rcv_headers_tfm_tbl.sql`)
- TFM (Transactions): `DMT_RCV_TRANSACTIONS_TFM_TBL` (DDL: `schema/tables/95_dmt_rcv_transactions_tfm_tbl.sql`)

## Code References
- Validator: `packages/validators/dmt_misc_receipt_validator_pkg`
- Transformer: `packages/transformers/dmt_misc_receipt_transform_pkg`
- FBDI Generator: `packages/generators/fbdi/receiving/dmt_misc_receipt_fbdi_gen_pkg`
  - Outputs 2 CSVs in single ZIP: `RcvHeadersInterface.csv` + `RcvTransactionsInterface.csv`
- Results/Reconciliation: `packages/reconciliation/dmt_misc_receipt_results_pkg`
- Loader wiring: `dmt_loader_pkg.RUN_MISC_RECEIPTS` -> `run_one_object_type('MiscReceipts')`

## Pipeline Configuration
- CEMLI Code: `MiscReceipts`
- Orchestration: P2P (runs last, after Requisitions)
- UCM Account: prc/receiving/import
- ESS Job: RcvTxnProcessorJob (ERP_INTERFACE_OPTIONS_ID=32)
- ParameterList: `NULL`
- Auth User: calvin.roth

## Reference Files
- `RcvHeadersInterface.ctl` -- CTL file for RCV_HEADERS_INTERFACE loader
- `RcvTransactionsInterface.ctl` -- CTL file for RCV_TRANSACTIONS_INTERFACE loader

## BIP Artifacts
- Data Model: `bip/MiscReceipts/MISC_RECEIPT_DM.xdm`
- Report: `bip/MiscReceipts/MISC_RECEIPT_RPT.xdo`
- Query: `bip/MiscReceipts/query.sql`
- Deployed to `/Custom/DMT/MiscReceipts/`

## Status
WIRED INTO PIPELINE. Code built. Now in P2P scheduler sequence (last position).
Needs first E2E test with real data.

## History
- 2026-03-25: Added to scope for On Hand Qty migration via Misc Receipts.
- Code built: validator, transformer, FBDI gen, reconciliation.
- Wired into dmt_loader_pkg (RUN_MISC_RECEIPTS) and scheduler dispatch.
- 2026-05-21: Added to P2P scheduler sequence (was only in individual dispatch).
