# PaymentTerms

## Overview
AP Payment Terms header definitions that specify standard payment conditions (Net 30, 2/10 Net 30, etc.) used on invoices and purchase orders. Each header can carry installment lines. Must be created before its lines.

## Load Method
REST API
- Header endpoint: `fscmRestApi/resources/11.13.18.05/standardTerms`
- Line endpoint: `fscmRestApi/resources/11.13.18.05/standardTerms/{TermId}/child/installments`
- Pipeline: LOCAL exec (`DMT_AP_PAY_TERM_RUNNER_PKG.RUN_STANDARD`), REST POST per record

## Parent/Child
- Parent: None (standalone; header is parent for installment lines)
- Linkage: line SOURCE_GROUP_ID = header SOURCE_GROUP_ID; the confirmed Fusion TERM_ID is the child-URL key.

## Staging Tables
- Header STG: `DMT_AP_PAY_TERM_HDR_STG_TBL` / TFM: `DMT_AP_PAY_TERM_HDR_TFM_TBL`
- Line STG: `DMT_AP_PAY_TERM_LINE_STG_TBL` / TFM: `DMT_AP_PAY_TERM_LINE_TFM_TBL`

## Key Columns
- NAME (natural key, = report RECORD_KEY and DISPLAY_KEY)
- PAY_TERM_TYPE, ENABLED_FLAG, DESCRIPTION

## Reconciliation (NEW standard, backlog #11 — DMT_DESIGN.html PROPOSED 2026-09)
Reconciliation is a BIP report over the Fusion BASE table, not the REST response.
- Base table: `AP_TERMS`; surrogate id: `TERM_ID` (== the REST `TermId`); natural key: `NAME`.
- LOAD: `DMT_AP_PAY_TERM_RESULTS_PKG.LOAD_TERMS` POSTs each header; a non-2xx is stashed into ERROR_TEXT (accumulate, never overwrite) but the header stays GENERATED.
- RECONCILE: `DMT_APTERMS_RECON_RPT` (BIP report `/Custom/DMT2/APPaymentTerms/`, param `P_TERM_NAMES`) is the sole authority for LOADED. A NAME found in AP_TERMS -> header LOADED with FUSION_TERM_ID = TERM_ID; a NAME not found stays FAILED on the stashed real error, else UNACCOUNTED. Lines are POSTed under confirmed terms only.
- Registered in `DMT_BIP_REPORT_TBL` under CEMLI_CODE `PaymentTerms` (id 100000042).

## Status
BUILT — REST load + base-table BIP reconciliation proven end-to-end on local Docker (backlog #11).
