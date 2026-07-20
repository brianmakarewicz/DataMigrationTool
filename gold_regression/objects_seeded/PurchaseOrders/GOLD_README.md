# PurchaseOrders — v2 seeded gold fixture

Converted from the frozen v1 fixture (`../../objects/PurchaseOrders/`). Same two good + one
bad purchase orders (four CSVs: header, line, shipment, distribution), loaded via
`loadAndImportData` under `fin_impl`, then imported by **ImportSPOJob (Import Orders)**
submitted under `calvin.roth`, with read-only BIP verification. The one difference from v1:
every upstream reference (supplier, site, Business Unit, buyer, ledger legal entity, ship-to
location, category, charge account) is **hard-coded to a standard seeded value** instead of
discovered at load time. The discovery block is removed from `recipe.json`.

## The hard-coded seeds (what v1 discovered → now literals)

All confirmed live via read-only BIP on `fa-esew-dev28` — every one is standard seeded demo
data we never loaded (the supplier number `1252` is numeric seeded data, not an `RT-` key):

| Reference | Literal value | Where used |
|---|---|---|
| Procurement / Requisitioning BU name | `US1 Business Unit` | header cols 9, 12 |
| Procurement / Requisitioning BU id | `300000046987012` | ParameterList args 1, 4, 9-prefix |
| Buyer name | `Roth, Calvin` | header col 13 |
| Buyer person id | `300000047340498` | ParameterList arg 2 |
| Buyer email | `CALVIN.ROTH_esew-dev28@oraclepdemos.com` | header col 94 (idx 93) |
| Sold-to legal entity | `US1 Legal Entity` | header col 11 |
| Supplier name | `Lee Supplies` | header col 21 |
| Supplier number | `1252` | header col 22 |
| Supplier site (good rows) | `Lee US1` | header col 23 |
| Currency | `USD` | header col 14 |
| Purchasing line type | `Goods` | line col 5 |
| Purchasing category | `Computer Supplies` | line col 9 |
| Ship-to / deliver-to location | `Seattle` | shipment col 4, distribution col 4 |
| Charge account segments | `101 / 10 / 63580 / 121 / 000 / 000` | distribution cols 9-14 |

`${PREFIX}` stays on the natural keys only: the PO number (`${PREFIX}RT-PO-G1/G2/BAD1`), the
interface header/line/shipment/distribution source keys that chain the four CSVs together,
the header `BATCH_ID` (a NUMBER column — must be the numeric prefix), and the ParameterList
arg-9 batch label (`300000046987012_${PREFIX}`, free text). The BU id in that label is a
literal now; only the prefix is stamped.

### Two carried-over gotchas (still true in v2)

- **Header email column position is exact.** The buyer email belongs at header index 93
  (the 94th field). This CSV has exactly 99 fields per header row, byte-mirrored from v1.
  During conversion an early draft had one extra empty field, which shifted the email into
  the `MODE_OF_TRANSPORT` column and rejected both good rows with
  `MODE_OF_TRANSPORT=…@oraclepdemos.com: The value of the attribute isn't valid`. The header
  template is now regenerated straight from the v1 layout so the column count is 99.
- **Line ACTION blank; BATCH_ID numeric.** The header ACTION is `ORIGINAL`; the line ACTION
  is blank. Header `BATCH_ID` is the numeric `${PREFIX}` (the text arg-9 label is separate).

## Bad row

BAD-1 differs from the good rows in exactly one field: `VENDOR_SITE_CODE = ZZINVALIDSITE`.
Import Orders rejects it into `PO_INTERFACE_ERRORS` with "The supplier site isn't valid…";
it never reaches `PO_HEADERS_ALL`.

## Two-user ESS orchestration (unchanged from v1)

1. **Load (auth: `fin_impl`)** — `loadAndImportData` uploads the zip and runs the interface
   loaders. `calvin.roth` returns HTTP 401 on this SOAP call, so the load runs as `fin_impl`.
2. **Import Orders (auth: `calvin.roth`)** — `submitESSJobRequest` for
   `/oracle/apps/ess/prc/po/pdoi,ImportSPOJob`. `fin_impl` cannot submit this job
   (`FUN-720397`); `calvin.roth` can. It reads the interface rows for the batch and creates
   the POs. Declared as a `downstream_jobs` entry with its own `cred_role: calvin.roth`.

The 9-argument ParameterList (both steps):
`300000046987012,300000047340498,SUBMIT,300000046987012,,N,,N,300000046987012_${PREFIX}`

## Live evidence (v2, via `GOLD_OBJECTS_SUBDIR=objects_seeded`)

**2026-07-20 — LIVE-PROVEN both directions. PASS.**

| Field | Value |
|---|---|
| Prefix | `65058` |
| Pod | `fa-esew-dev28` |
| Load ESS request (fin_impl, loadAndImportData) | `9766225` → SUCCEEDED |
| Import Orders request (calvin.roth, ImportSPOJob) | `9766234` → SUCCEEDED |

Good rows → base `PO_HEADERS_ALL` (2/2):

| PO_NUMBER | PO_HEADER_ID | DOCUMENT_STATUS |
|---|---|---|
| `65058RT-PO-G1` | `674965` | INCOMPLETE |
| `65058RT-PO-G2` | `674966` | INCOMPLETE |

Bad row → `PO_INTERFACE_ERRORS`, absent from base (1/1):

| PO_NUMBER | Error |
|---|---|
| `65058RT-PO-BAD1` | `VENDOR_SITE_CODE=ZZINVALIDSITE: The supplier site isn't valid. Verify that the site is active, has the purchasing purpose assigned, is associated with the procurement business unit, and has an active assignment for the requisitioning business unit.` |

(POs are created in `DOCUMENT_STATUS = INCOMPLETE` — a functional-user SUBMIT draft. Reaching
the base table is the pass bar.)

## How to run

```bash
cd gold_regression/harness
GOLD_OBJECTS_SUBDIR=objects_seeded python run_object.py PurchaseOrders
```

## Files

- `recipe.json` — FBDI, 4-CSV member list, **no discovery block**, literal 9-arg
  ParameterList, `downstream_jobs` (ImportSPOJob as calvin.roth), verify block.
- `artifact/Po*InterfaceOrder.csv` — the four templated CSVs (`${PREFIX}` + hard-coded seeds).
- `PurchaseOrders_gold.zip` — last assembled ready-to-load artifact.
