# Bank Accounts

## Overview
Cash Management bank account records at the bottom of the three-level bank hierarchy. Each account is linked to both a parent bank and a parent branch.

## Load Method
REST API
- Endpoint: `POST /fscmRestApi/resources/11.13.18.05/cashBankAccounts`
- Pipeline: REST pipeline (part of CEMLI_CODE `CashBanks`, runner `DMT_CE_BANK_RUNNER_PKG`)

## Parent/Child
- Parent: BankBranches (and grandparent Banks)
- Linkage: SOURCE_GROUP_ID (links to Bank), SOURCE_LINE_ID (links to Branch)

## Staging Tables
- STG: `DMT_CE_BANK_ACCT_STG_TBL`
- TFM: `DMT_CE_BANK_ACCT_TFM_TBL`

## Key Columns
- ACCOUNT_NAME
- ACCOUNT_NUMBER
- CURRENCY_CODE
- LEGAL_ENTITY_NAME

## Reconciliation
Base-table BIP report (`DMT_CEBANK_RECON_RPT`), not the REST response. An account is
marked LOADED only when it is found in `CE_BANK_ACCOUNTS`, with
`FUSION_BANK_ACCOUNT_ID` set to the real `BANK_ACCOUNT_ID`. An account is POSTed only
under a base-table-confirmed parent branch; one not found and carrying a real Fusion
error is marked FAILED on that error.

## Status
BUILT — REST pipeline. Accounts are POSTed to the `cashBankAccounts` resource after
their parent branch is confirmed, then reconciled against `CE_BANK_ACCOUNTS`. The old
FBL flat-file generator was retired (backlog #39).

## Run prefix and parent-not-created rule (2026-10-07)
`ACCOUNT_NAME` (Fusion limit 80) and the parent `BANK_NAME` carry the run prefix. An account
whose parent branch was not created is not sent and gets no error text, so it ends
UNACCOUNTED (see `objects/Banks/README.md`). The 2026-10-06 `[PARENT_FAILED]` stamp was a
composed sentence, not a Fusion error, and was removed.
