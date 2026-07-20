# Contracts — v2 seeded gold fixture (Import Contract Agreements / ImportCPAJob)

Converted from the frozen v1 fixture (`../../objects/Contracts/`). Same two good + one bad
Contract Purchase Agreements (one headers-only CSV), loaded via `loadAndImportData` under
`fin_impl`, then imported by **ImportCPAJob (Import Contract Agreements)** submitted under
`calvin.roth`, with read-only BIP verification. The one difference from v1: every upstream
reference (Business Unit, buyer, supplier, active purchasing site, currency, buyer email) is
**hard-coded to a standard seeded value** instead of discovered at load time. The discovery
block is removed from `recipe.json`.

## The hard-coded seeds (what v1 discovered → now literals)

All confirmed live via read-only BIP on `fa-esew-dev28` — every one is standard seeded demo
data we never loaded (supplier number `1252` is numeric seeded data, not an `RT-` key):

| Reference | Literal value | Where used |
|---|---|---|
| Procurement BU name | `US1 Business Unit` | header col 9 |
| Procurement BU id | `300000046987012` | ParameterList arg 1, arg 7 prefix |
| Buyer name | `Roth, Calvin` | header col 10 |
| Buyer person id | `300000047340498` | ParameterList arg 2 |
| Buyer email | `CALVIN.ROTH_esew-dev28@oraclepdemos.com` | header col 94 (idx 93) |
| Currency | `USD` | header col 11 |
| Supplier name | `Lee Supplies` | header col 13 |
| Supplier number | `1252` | header col 14 |
| Supplier site (good rows) | `Lee US1` | header col 15 |

`${PREFIX}` stays on the natural keys only: the agreement number (`${PREFIX}RT-CPA-G1/G2/BAD1`),
the interface source key, the numeric header `BATCH_ID` (a NUMBER column), the import-source
label `RT${PREFIX}`, and the ParameterList batch label (`300000046987012_${PREFIX}`, free text —
the BU id in that label is a literal now; only the prefix is stamped).

## Object shape (unchanged from v1)

One object = one FBDI zip = one load job. A Contract Purchase Agreement is **headers-only** —
no lines/locations/distributions. The single position-based CSV
(`PoHeadersInterfaceContract.csv`, no header row) has 105 columns plus a literal unquoted
trailing `END` field that the FBDI CTL requires. `DOCUMENT_TYPE_CODE = CONTRACT`,
`STYLE = Contract Purchase Agreement`.

### Rows in the fixture

| Suffix | Agreement number | Meaning | Expected outcome |
|--------|------------------|---------|------------------|
| `G1`   | `${PREFIX}RT-CPA-G1`   | good | `PO_HEADERS_ALL` (`TYPE_LOOKUP_CODE=CONTRACT`) |
| `G2`   | `${PREFIX}RT-CPA-G2`   | good | `PO_HEADERS_ALL` (`TYPE_LOOKUP_CODE=CONTRACT`) |
| `BAD1` | `${PREFIX}RT-CPA-BAD1` | bad — invalid supplier site `ZZINVALIDSITE` | `PO_INTERFACE_ERRORS`, absent from base |

The bad row differs from the good rows in exactly one field: `VENDOR_SITE_CODE = ZZINVALIDSITE`.

## Two-user ESS orchestration (unchanged from v1)

1. **Load (auth: `fin_impl`)** — `loadAndImportData` uploads the zip to UCM account
   `prc/contractPurchaseAgreement/import` and runs the interface loader into
   `PO_HEADERS_INTERFACE`. `calvin.roth` returns HTTP 401 on this SOAP call, so the load runs
   as `fin_impl`. interfaceDetails = `22` (the CPA SOURCE_ERP_OPTIONS_ID).
2. **Import Contract Agreements (auth: `calvin.roth`)** — `submitESSJobRequest` for
   `/oracle/apps/ess/prc/po/pdoi,ImportCPAJob`. `fin_impl` cannot submit this job
   (`FUN-720397`); `calvin.roth` can. It reads the interface rows for the batch and creates the
   agreements. Declared as a `downstream_jobs` entry with its own `cred_role: calvin.roth`.

The 7-argument ParameterList (both steps):
`300000046987012,300000047340498,SUBMIT,${PREFIX},RT${PREFIX},N,300000046987012_${PREFIX}`

| # | Argument | Value |
|---|---|---|
| 1 | Procurement BU id | `300000046987012` |
| 2 | Default buyer id | `300000047340498` |
| 3 | Approval action | `SUBMIT` |
| 4 | Batch ID | `${PREFIX}` |
| 5 | Import source | `RT${PREFIX}` |
| 6 | Communicate agreements | `N` |
| 7 | Group tag | `300000046987012_${PREFIX}` |

Once ImportCPAJob reaches SUCCEEDED the good agreements are in `PO_HEADERS_ALL`
(`DOCUMENT_STATUS = OPEN`). Reaching the base table is the pass bar; there is no separate
accounting program to wait on.

## Verification (read-only BIP)

- **Good → base:** `SELECT segment1, po_header_id, type_lookup_code, document_status FROM
  po_headers_all WHERE segment1 LIKE :PREFIX || 'RT-CPA-%' AND type_lookup_code='CONTRACT'` —
  two rows with real `po_header_id`s == pass.
- **Bad → interface error / absent from base:** the bad row appears in `PO_HEADERS_INTERFACE`
  with a real `PO_INTERFACE_ERRORS` message and never reaches `PO_HEADERS_ALL`.

## Live evidence (v2, via `GOLD_OBJECTS_SUBDIR=objects_seeded`)

**2026-07-20 — LIVE-PROVEN both directions. PASS.**

| Field | Value |
|---|---|
| Prefix | `69347` |
| Pod | `fa-esew-dev28` |
| Load ESS request (fin_impl, loadAndImportData) | `9766437` → SUCCEEDED |
| Import Contract Agreements request (calvin.roth, ImportCPAJob) | `9766464` → SUCCEEDED |

Good rows → base `PO_HEADERS_ALL` (`TYPE_LOOKUP_CODE=CONTRACT`, 2/2):

| AGREEMENT_NUMBER | PO_HEADER_ID | DOCUMENT_STATUS |
|---|---|---|
| `69347RT-CPA-G1` | `674968` | OPEN |
| `69347RT-CPA-G2` | `674969` | OPEN |

Bad row → `PO_INTERFACE_ERRORS`, absent from base (1/1):

| AGREEMENT_NUMBER | Error |
|---|---|
| `69347RT-CPA-BAD1` | `VENDOR_SITE_CODE=ZZINVALIDSITE: The supplier site isn't valid. Verify that the site is active, has the purchasing purpose assigned, is associated with the procurement business unit, and has an active assignment for the requisitioning business unit.` |

## How to run

```bash
cd gold_regression/harness
GOLD_OBJECTS_SUBDIR=objects_seeded python run_object.py Contracts
```

## Files

- `recipe.json` — FBDI, 1-CSV member list, **no discovery block**, literal 7-arg
  ParameterList, `downstream_jobs` (ImportCPAJob as calvin.roth), verify block.
- `artifact/PoHeadersInterfaceContract.csv` — the templated CSV (`${PREFIX}` + hard-coded
  seeds, 105 cols + `END`).
- `Contracts_gold.zip` — last assembled ready-to-load artifact.
