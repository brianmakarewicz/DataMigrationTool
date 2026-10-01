# Banks

## Overview
Cash Management bank records representing financial institutions. This is the top level of a three-level hierarchy: Bank > Branch > Account.

## Load Method
REST API
- Endpoint: `POST /fscmRestApi/resources/11.13.18.05/cashBanks`
- Pipeline: REST pipeline (CEMLI_CODE `CashBanks`, runner `DMT_CE_BANK_RUNNER_PKG`)

## Parent/Child
- Parent: None (standalone, top of hierarchy)
- Linkage: N/A (parent to BankBranches via SOURCE_GROUP_ID)

## Staging Tables
- STG: `DMT_CE_BANK_STG_TBL`
- TFM: `DMT_CE_BANK_TFM_TBL`

## Key Columns
- BANK_NAME
- BANK_NUMBER
- COUNTRY_CODE

## Reconciliation
Base-table BIP report (`DMT_CEBANK_RECON_RPT`), not the REST response. A bank is
marked LOADED only when it is found in `CE_BANKS_V`, with `FUSION_BANK_PARTY_ID`
set to the real `BANK_PARTY_ID`. A bank whose POST returned a real Fusion error
and is not found in the base view is marked FAILED on that error.

## Status
BUILT — REST pipeline. The runner transforms, promotes STAGED TFM rows to
GENERATED, POSTs each bank to the `cashBanks` resource, then reconciles against
`CE_BANKS_V`. The old FBL flat-file generator was retired (backlog #39).
