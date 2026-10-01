# Bank Branches

## Overview
Bank branch records within the Cash Management bank hierarchy. Each branch belongs to a parent bank and can itself be a parent to bank accounts.

## Load Method
REST API
- Endpoint: `POST /fscmRestApi/resources/11.13.18.05/cashBankBranches`
- Pipeline: REST pipeline (part of CEMLI_CODE `CashBanks`, runner `DMT_CE_BANK_RUNNER_PKG`)

## Parent/Child
- Parent: Banks
- Linkage: SOURCE_GROUP_ID (links to parent Bank); SOURCE_LINE_ID (links to grandchild BankAccounts)

## Staging Tables
- STG: `DMT_CE_BRANCH_STG_TBL`
- TFM: `DMT_CE_BRANCH_TFM_TBL`

## Key Columns
- BRANCH_NAME
- BRANCH_NUMBER
- BIC_CODE

## Reconciliation
Base-table BIP report (`DMT_CEBANK_RECON_RPT`), not the REST response. A branch is
marked LOADED only when it is found in `CE_BANK_BRANCHES_V` (matched on branch name
plus parent bank name so a branch name reused across banks is not mis-attributed),
with `FUSION_BRANCH_PARTY_ID` set to the real `BRANCH_PARTY_ID`. A branch is POSTed
only under a base-table-confirmed parent bank; one not found and carrying a real
Fusion error is marked FAILED on that error.

## Status
BUILT — REST pipeline. Branches are POSTed to the `cashBankBranches` resource after
their parent bank is confirmed, then reconciled against `CE_BANK_BRANCHES_V`. The
old FBL flat-file generator was retired (backlog #39).
