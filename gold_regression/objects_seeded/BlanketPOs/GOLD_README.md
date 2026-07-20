# BlanketPOs — v2 seeded gold fixture (Import Blanket Agreements / ImportBPAJob)

Converted from the frozen v1 fixture (`../../objects/BlanketPOs/`). Same two good + one
bad blanket purchase agreements (four CSVs: header, line, price-break location, BU
assignment), loaded via `loadAndImportData` under `fin_impl`, then imported by
**ImportBPAJob (Import Blanket Agreements)** submitted under `calvin.roth`, with read-only
BIP verification. The one difference from v1: every upstream reference (supplier, site,
Business Unit, buyer, buyer email, currency, line type, category) is **hard-coded to a
standard seeded value** instead of discovered at load time. The discovery block is removed
from `recipe.json`.

Do not confuse this with `objects_seeded/PurchaseOrders/` — that is standard orders
(ImportSPOJob, 9-arg). Blanket agreements share the PO interface tables but use a separate
FBDI template, a different UCM account (`prc/blanketPurchaseAgreement/import`), a different
interface id (`23`, not `21`), and a different ESS job (`ImportBPAJob`, 8-arg).

## The hard-coded seeds (what v1 discovered → now literals)

All confirmed live via read-only BIP on `fa-esew-dev28` — every one is standard seeded demo
data we never loaded (supplier number `1252` is numeric seeded data, not an `RT-` key):

| Reference | Literal value | Where used |
|---|---|---|
| Procurement / Requisitioning BU name | `US1 Business Unit` | header pos 9; GA-org-assign pos 3 & 7 |
| Procurement / Requisitioning BU id | `300000046987012` | ParameterList args 1 and 8-prefix |
| Buyer name | `Roth, Calvin` | header pos 10 |
| Buyer person id | `300000047340498` | ParameterList arg 2 |
| Buyer email | `CALVIN.ROTH_esew-dev28@oraclepdemos.com` | header pos 98 |
| Supplier name | `Lee Supplies` | header pos 13 |
| Supplier number | `1252` | header pos 14 |
| Supplier site (good rows) | `Lee US1` | header pos 15 |
| Currency | `USD` | header pos 11 |
| Purchasing line type | `Goods` | line pos 5 |
| Purchasing category | `Computer Supplies` | line pos 9 |

`${PREFIX}` stays on the natural keys only: the agreement number (`${PREFIX}RT-BPA-G1/G2/BAD1`),
the interface source keys that chain the four CSVs together, the header `BATCH_ID` (a NUMBER
column — must be the numeric prefix, header pos 3), the `RT${PREFIX}` import source (pos 4),
and the ParameterList args 5/6/8. The BU id in the arg-8 group tag is a literal now; only the
prefix is stamped.

The four templates were regenerated from the v1 templates by pure literal token substitution,
so column order and counts are byte-identical to v1:

| Member | Fields |
|---|---:|
| `PoHeadersInterfaceBlanket.csv` | 122 |
| `PoLinesInterfaceBlanket.csv` | 108 |
| `PoLineLocationsInterfaceBlanket.csv` | 62 |
| `PoGAOrgAssignInterfaceBlanket.csv` | 10 |

**What makes it a BLANKET, not a STANDARD order** — header pos 7 `DOCUMENT_TYPE_CODE =
BLANKET` and pos 8 `STYLE = "Blanket Purchase Agreement"`. The GA-org-assign CSV assigns the
agreement to the BU with `Enabled = Y`, which leaves the created agreement in
`DOCUMENT_STATUS = OPEN`.

**BATCH_ID gotcha (carried from PurchaseOrders):** `PO_HEADERS_INTERFACE.BATCH_ID` is a
NUMBER column, so header pos 3 must be numeric — the fixture uses `${PREFIX}`. The free-text
arg-8 group tag is separate; putting text into the numeric column throws `ORA-01722`.

## Bad row

BAD-1 differs from the good rows in exactly one field: `VENDOR_SITE_CODE = ZZINVALIDSITE`
(header pos 15). Import Blanket Agreements rejects it into `PO_INTERFACE_ERRORS` with "The
supplier site isn't valid…"; it never reaches `PO_HEADERS_ALL`.

## Two-user ESS orchestration (unchanged from v1)

1. **Load (auth: `fin_impl`)** — `loadAndImportData` uploads the zip and runs the interface
   loaders. `calvin.roth` returns HTTP 401 on this SOAP call, so the load runs as `fin_impl`.
2. **Import Blanket Agreements (auth: `calvin.roth`)** — `submitESSJobRequest` for
   `/oracle/apps/ess/prc/po/pdoi,ImportBPAJob`. `fin_impl` cannot submit this job
   (`FUN-720397`); `calvin.roth` can. Declared as a `downstream_jobs` entry with its own
   `cred_role: calvin.roth`.

The 8-argument ParameterList (both steps, literal BU id / buyer id, prefix stamped):
`300000046987012,300000047340498,N,SUBMIT,${PREFIX},RT${PREFIX},N,300000046987012_${PREFIX}`

| # | Argument | Value |
|---|---|---|
| 1 | Procurement BU id | `300000046987012` |
| 2 | Default Buyer person id | `300000047340498` |
| 3 | Create or Update Item | `N` |
| 4 | Approval Action | `SUBMIT` |
| 5 | Batch ID (pass-through) | `${PREFIX}` |
| 6 | Import Source | `RT${PREFIX}` |
| 7 | Communicate Agreements | `N` |
| 8 | Group tag `{BU_ID}_{BatchID}` | `300000046987012_${PREFIX}` |

## Live evidence (v2, via `GOLD_OBJECTS_SUBDIR=objects_seeded`)

**2026-07-20 — LIVE-PROVEN both directions. PASS (first v2 run).**

| Field | Value |
|---|---|
| Prefix | `14735` |
| Pod | `fa-esew-dev28` |
| Load ESS request (fin_impl, loadAndImportData) | `9766454` → SUCCEEDED |
| Import Blanket Agreements request (calvin.roth, ImportBPAJob) | `9766472` → SUCCEEDED |

Good rows → base `PO_HEADERS_ALL` (TYPE_LOOKUP_CODE = BLANKET), 2/2:

| PO_NUMBER | PO_HEADER_ID | DOCUMENT_STATUS |
|---|---|---|
| `14735RT-BPA-G1` | `674970` | OPEN |
| `14735RT-BPA-G2` | `674971` | OPEN |

Bad row → `PO_INTERFACE_ERRORS`, absent from base (1/1):

| PO_NUMBER | Error |
|---|---|
| `14735RT-BPA-BAD1` | `VENDOR_SITE_CODE=ZZINVALIDSITE: The supplier site isn't valid. Verify that the site is active, has the purchasing purpose assigned, is associated with the procurement business unit, and has an active assignment for the requisitioning business unit.` |

## How to run

```bash
cd gold_regression/harness
GOLD_OBJECTS_SUBDIR=objects_seeded python run_object.py BlanketPOs
```

## Files

- `recipe.json` — FBDI, 4-CSV member list, **no discovery block**, literal 8-arg
  ParameterList, `downstream_jobs` (ImportBPAJob as calvin.roth), verify block.
- `artifact/Po*InterfaceBlanket.csv` — the four templated CSVs (`${PREFIX}` + hard-coded seeds).
- `BlanketPOs_gold.zip` — last assembled ready-to-load artifact.
